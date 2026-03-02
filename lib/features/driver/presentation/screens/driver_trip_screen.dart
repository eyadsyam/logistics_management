import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/map_marker_util.dart';
import '../../../shipment/domain/models/shipment_model.dart';
import '../../../shipment/domain/usecases/accept_shipment_usecase.dart';
import '../../domain/models/driver_model.dart';

/// Driver active trip screen with GPS tracking and shipment status controls.
class DriverTripScreen extends ConsumerStatefulWidget {
  final String shipmentId;
  final String driverId;

  const DriverTripScreen({
    super.key,
    required this.shipmentId,
    required this.driverId,
  });

  @override
  ConsumerState<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends ConsumerState<DriverTripScreen> {
  MapboxMap? _mapController;
  PointAnnotationManager? _poiPointManager;
  PolylineAnnotationManager? _polylineManager;
  PointAnnotationManager? _driverPointManager;
  PointAnnotation? _driverAnnotation;
  String? _drawnShipmentId;
  String? _drawnPolyline;
  String? _drawnDeliveryPolyline;
  String? _drawnTripPhase;

  bool _isTripStarted = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupLocationTracking();
  }

  /// Setup location tracking with dead zone handling.
  void _setupLocationTracking() {
    final locationService = ref.read(locationServiceProvider);
    final networkInfo = ref.read(networkInfoProvider);

    locationService.onLocationUpdate = (LocationPoint point) async {
      // Update driver location in Firestore
      final isOnline = await networkInfo.isConnected;

      if (isOnline) {
        // Sync any cached points first
        final cachedPoints = await locationService.getCachedPoints();
        for (final cached in cachedPoints) {
          await ref
              .read(shipmentRepositoryProvider)
              .addLocationPoint(shipmentId: widget.shipmentId, point: cached);
        }

        // Send current point
        await ref
            .read(driverRepositoryProvider)
            .updateLocation(
              driverId: widget.driverId,
              location: GeoPoint(
                latitude: point.latitude,
                longitude: point.longitude,
              ),
            );

        _updateDriverMarker(point.latitude, point.longitude);

        await ref
            .read(shipmentRepositoryProvider)
            .addLocationPoint(shipmentId: widget.shipmentId, point: point);

        // Update ETA
        _updateETA(point.latitude, point.longitude);
      } else {
        // Dead zone: cache locally
        await locationService.cacheLocationPoint(point);
      }
    };
  }

  Future<void> _updateDriverMarker(double lat, double lng) async {
    if (_mapController == null) return;
    try {
      _driverPointManager ??= await _mapController!.annotations
          .createPointAnnotationManager();

      final point = Point(coordinates: Position(lng, lat));
      if (_driverAnnotation == null) {
        final iconBytes = await MapMarkerUtil.getCarMarkerBytes(size: 150);
        _driverAnnotation = await _driverPointManager!.create(
          PointAnnotationOptions(
            geometry: point,
            image: iconBytes,
            iconSize: 1.0,
          ),
        );
      } else {
        _driverAnnotation?.geometry = point;
        await _driverPointManager!.update(_driverAnnotation!);
      }
    } catch (e) {
      debugPrint('Error updating driver local marker: $e');
    }
  }

  /// Update ETA based on current position — **phase-aware**.
  /// During pickup: routes driver → factory.
  /// During delivery: routes driver → destination.
  Future<void> _updateETA(double lat, double lng) async {
    final shipmentResult = await ref
        .read(shipmentRepositoryProvider)
        .getShipment(widget.shipmentId);

    shipmentResult.fold((_) => null, (shipment) async {
      final isPickup = shipment.tripPhase == 'pickup';
      final factoryLoc = shipment.factoryLocation ?? shipment.origin;
      final targetLat = isPickup
          ? factoryLoc.latitude
          : shipment.destination.latitude;
      final targetLng = isPickup
          ? factoryLoc.longitude
          : shipment.destination.longitude;

      final eta = await ref
          .read(mapboxServiceProvider)
          .calculateETA(
            currentLat: lat,
            currentLng: lng,
            destLat: targetLat,
            destLng: targetLng,
          );

      if (eta != null) {
        final directions = await ref
            .read(mapboxServiceProvider)
            .getDirections(
              originLat: lat,
              originLng: lng,
              destLat: targetLat,
              destLng: targetLng,
            );

        if (directions != null) {
          await ref
              .read(shipmentRepositoryProvider)
              .updateShipmentRoute(
                shipmentId: widget.shipmentId,
                polyline: directions.polyline,
                distanceMeters: directions.distanceMeters,
                durationSeconds: directions.durationSeconds,
                etaTimestamp: eta,
              );
        }
      }
    });
  }

  /// Start the trip — begin GPS tracking.
  Future<void> _startTrip() async {
    setState(() => _isProcessing = true);

    final result = await ref
        .read(startShipmentUseCaseProvider)
        .call(widget.shipmentId);

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      (_) async {
        setState(() => _isTripStarted = true);
        final locService = ref.read(locationServiceProvider);
        locService.startTracking();

        // 🚀 Fix: immediately pulse a location update to calculate route and ETA
        // without waiting for the driver to move 40 meters.
        final currentPos = await locService.getCurrentPosition();
        if (currentPos != null && locService.onLocationUpdate != null) {
          locService.onLocationUpdate!(
            LocationPoint(
              latitude: currentPos.latitude,
              longitude: currentPos.longitude,
              speed: currentPos.speed,
              accuracy: currentPos.accuracy,
              timestamp: currentPos.timestamp,
            ),
          );
        }
      },
    );

    setState(() => _isProcessing = false);
  }

  /// Complete the trip — stop GPS tracking.
  Future<void> _completeTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Trip'),
        content: const Text(
          'Are you sure you want to mark this shipment as delivered?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    // Stop tracking
    ref.read(locationServiceProvider).stopTracking();

    // Sync remaining cached points
    final cachedPoints = await ref
        .read(locationServiceProvider)
        .getCachedPoints();
    for (final point in cachedPoints) {
      await ref
          .read(shipmentRepositoryProvider)
          .addLocationPoint(shipmentId: widget.shipmentId, point: point);
    }

    final result = await ref
        .read(completeShipmentUseCaseProvider)
        .call(widget.shipmentId);

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      (_) {
        // Clear driver's current shipment
        ref
            .read(driverRepositoryProvider)
            .updateCurrentShipment(driverId: widget.driverId, shipmentId: null);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shipment completed!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      },
    );

    setState(() => _isProcessing = false);
  }

  @override
  void dispose() {
    // Don't stop tracking here — it should continue in background
    super.dispose();
  }

  Future<void> _drawShipmentRoute(ShipmentModel shipment) async {
    if (_mapController == null) return;
    try {
      _poiPointManager ??= await _mapController!.annotations
          .createPointAnnotationManager();
      _polylineManager ??= await _mapController!.annotations
          .createPolylineAnnotationManager();

      await _poiPointManager!.deleteAll();
      await _polylineManager!.deleteAll();

      final factoryLoc = shipment.factoryLocation ?? shipment.origin;
      final isPickupPhase = shipment.tripPhase == 'pickup';

      debugPrint('=== _drawShipmentRoute ===');
      debugPrint('tripPhase: ${shipment.tripPhase}, isPickup: $isPickupPhase');
      debugPrint(
        'factoryLoc: ${factoryLoc.latitude}, ${factoryLoc.longitude} (${factoryLoc.address})',
      );
      debugPrint(
        'destination: ${shipment.destination.latitude}, ${shipment.destination.longitude}',
      );
      debugPrint('polyline: ${shipment.polyline?.length ?? 0} chars');
      debugPrint(
        'deliveryPolyline: ${shipment.deliveryPolyline?.length ?? 0} chars',
      );

      final factoryIconBytes = await MapMarkerUtil.getLabeledMarkerBytes(
        label: 'Factory ${shipment.factoryId ?? 'Edita'}',
        color: AppColors.info,
        size: 180,
      );
      final destIconBytes = await MapMarkerUtil.getLabeledMarkerBytes(
        label: 'Delivery',
        color: AppColors.accent,
        size: 180,
      );

      // Factory marker
      final factoryMarker = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(factoryLoc.longitude, factoryLoc.latitude),
        ),
        image: factoryIconBytes,
        iconAnchor: IconAnchor.BOTTOM,
      );

      // Destination marker
      final destMarker = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            shipment.destination.longitude,
            shipment.destination.latitude,
          ),
        ),
        image: destIconBytes,
        iconAnchor: IconAnchor.BOTTOM,
      );

      await _poiPointManager!.createMulti([factoryMarker, destMarker]);

      // ── Draw pickup leg (driver → factory) — BLUE ──
      if (isPickupPhase &&
          shipment.polyline != null &&
          shipment.polyline!.isNotEmpty) {
        final pickupPoints = _decodePolyline(shipment.polyline!, precision: 6);
        if (pickupPoints.length >= 2) {
          await _polylineManager!.create(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: pickupPoints),
              lineColor: AppColors.info.toARGB32(),
              lineWidth: 6.0,
              lineJoin: LineJoin.ROUND,
            ),
          );
        }
      }

      // ── Draw delivery leg (factory → destination) — ORANGE ──
      if (shipment.deliveryPolyline != null &&
          shipment.deliveryPolyline!.isNotEmpty) {
        final deliveryPoints = _decodePolyline(
          shipment.deliveryPolyline!,
          precision: 6,
        );
        if (deliveryPoints.length >= 2) {
          await _polylineManager!.create(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: deliveryPoints),
              lineColor: AppColors.accent.toARGB32(),
              lineWidth: isPickupPhase ? 4.0 : 6.0,
              lineJoin: LineJoin.ROUND,
            ),
          );
        }
      }

      // ── During delivery phase, polyline = driver→destination ──
      if (!isPickupPhase &&
          (shipment.deliveryPolyline == null ||
              shipment.deliveryPolyline!.isEmpty) &&
          shipment.polyline != null &&
          shipment.polyline!.isNotEmpty) {
        final pts = _decodePolyline(shipment.polyline!, precision: 6);
        if (pts.length >= 2) {
          await _polylineManager!.create(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: pts),
              lineColor: AppColors.accent.toARGB32(),
              lineWidth: 6.0,
              lineJoin: LineJoin.ROUND,
            ),
          );
        }
      }

      // ── Fallback: straight line if no polylines at all ──
      final hasAnyPolyline =
          (shipment.polyline != null && shipment.polyline!.isNotEmpty) ||
          (shipment.deliveryPolyline != null &&
              shipment.deliveryPolyline!.isNotEmpty);
      if (!hasAnyPolyline) {
        await _polylineManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(
              coordinates: [
                Position(factoryLoc.longitude, factoryLoc.latitude),
                Position(
                  shipment.destination.longitude,
                  shipment.destination.latitude,
                ),
              ],
            ),
            lineColor: AppColors.accent.toARGB32(),
            lineWidth: 4.0,
            lineJoin: LineJoin.ROUND,
          ),
        );
      }

      // ── Camera bounds to fit all points ──
      final allLats = [factoryLoc.latitude, shipment.destination.latitude];
      final allLngs = [factoryLoc.longitude, shipment.destination.longitude];

      final bounds = CoordinateBounds(
        southwest: Point(
          coordinates: Position(
            allLngs.reduce(math.min),
            allLats.reduce(math.min),
          ),
        ),
        northeast: Point(
          coordinates: Position(
            allLngs.reduce(math.max),
            allLats.reduce(math.max),
          ),
        ),
        infiniteBounds: true,
      );
      final cameraOptions = await _mapController!.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 150, left: 60, bottom: 280, right: 60),
        null,
        null,
        null,
        null,
      );
      _mapController!.flyTo(cameraOptions, MapAnimationOptions(duration: 800));
    } catch (e) {
      debugPrint('Error drawing map elements: $e');
    }
  }

  List<Position> _decodePolyline(String encoded, {int precision = 6}) {
    List<Position> coordinates = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    final factor = math.pow(10, precision);

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      coordinates.add(Position(lng / factor, lat / factor));
    }
    return coordinates;
  }

  /// Compute initial routes when the driver first opens the screen.
  Future<void> _computeInitialRoutes(ShipmentModel shipment) async {
    debugPrint('=== _computeInitialRoutes START ===');
    debugPrint(
      'factoryLocation: ${shipment.factoryLocation?.latitude}, ${shipment.factoryLocation?.longitude}',
    );
    debugPrint(
      'origin: ${shipment.origin.latitude}, ${shipment.origin.longitude}',
    );
    debugPrint(
      'destination: ${shipment.destination.latitude}, ${shipment.destination.longitude}',
    );
    debugPrint('factoryId: ${shipment.factoryId}');
    debugPrint('existing polyline length: ${shipment.polyline?.length ?? 0}');
    debugPrint(
      'existing deliveryPolyline length: ${shipment.deliveryPolyline?.length ?? 0}',
    );

    final pos = await ref.read(locationServiceProvider).getCurrentPosition();
    if (pos == null) {
      debugPrint('ERROR: Could not get driver position');
      return;
    }
    debugPrint('Driver position: ${pos.latitude}, ${pos.longitude}');

    final mapboxService = ref.read(mapboxServiceProvider);
    final factoryLoc = shipment.factoryLocation ?? shipment.origin;
    debugPrint(
      'Using factory coords: ${factoryLoc.latitude}, ${factoryLoc.longitude}',
    );

    final updateData = <String, dynamic>{};

    // Leg 1: Driver → Factory (pickup)
    debugPrint(
      'Computing Leg 1: Driver(${pos.latitude}, ${pos.longitude}) → Factory(${factoryLoc.latitude}, ${factoryLoc.longitude})',
    );
    final pickupDirections = await mapboxService.getDirections(
      originLat: pos.latitude,
      originLng: pos.longitude,
      destLat: factoryLoc.latitude,
      destLng: factoryLoc.longitude,
    );

    if (pickupDirections != null) {
      debugPrint(
        'Leg 1 SUCCESS: ${pickupDirections.distanceMeters}m, ${pickupDirections.durationSeconds}s, polyline=${pickupDirections.polyline.length} chars',
      );
      final eta = DateTime.now().add(
        Duration(seconds: pickupDirections.durationSeconds),
      );
      updateData['polyline'] = pickupDirections.polyline;
      updateData['distanceMeters'] = pickupDirections.distanceMeters;
      updateData['durationSeconds'] = pickupDirections.durationSeconds;
      updateData['etaTimestamp'] = eta.toIso8601String();
    } else {
      debugPrint('Leg 1 FAILED: getDirections returned null');
    }

    // Leg 2: Factory → Destination (delivery) — only if missing
    if (shipment.deliveryPolyline == null ||
        shipment.deliveryPolyline!.isEmpty) {
      debugPrint(
        'Computing Leg 2: Factory(${factoryLoc.latitude}, ${factoryLoc.longitude}) → Dest(${shipment.destination.latitude}, ${shipment.destination.longitude})',
      );
      final deliveryDirections = await mapboxService.getDirections(
        originLat: factoryLoc.latitude,
        originLng: factoryLoc.longitude,
        destLat: shipment.destination.latitude,
        destLng: shipment.destination.longitude,
      );

      if (deliveryDirections != null) {
        debugPrint(
          'Leg 2 SUCCESS: ${deliveryDirections.distanceMeters}m, ${deliveryDirections.durationSeconds}s',
        );
        updateData['deliveryPolyline'] = deliveryDirections.polyline;
        updateData['deliveryDistanceMeters'] =
            deliveryDirections.distanceMeters;
        updateData['deliveryDurationSeconds'] =
            deliveryDirections.durationSeconds;
      } else {
        debugPrint('Leg 2 FAILED: getDirections returned null');
      }
    } else {
      debugPrint('Leg 2 SKIPPED: deliveryPolyline already exists');
    }

    // Save everything in one Firestore update
    if (updateData.isNotEmpty) {
      try {
        debugPrint('Saving to Firestore: ${updateData.keys.join(', ')}');
        await ref
            .read(firestoreProvider)
            .collection('shipments')
            .doc(widget.shipmentId)
            .update(updateData);
        debugPrint('Firestore update SUCCESS');
      } catch (e) {
        debugPrint('Firestore update ERROR: $e');
      }
    }

    debugPrint('=== _computeInitialRoutes END ===');
  }

  @override
  Widget build(BuildContext context) {
    final shipmentStream = ref
        .watch(shipmentRepositoryProvider)
        .streamShipment(widget.shipmentId);

    return Scaffold(
      body: StreamBuilder<ShipmentModel>(
        stream: shipmentStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          final shipment = snapshot.data!;
          _isTripStarted = shipment.status == AppConstants.statusInProgress;

          if (_drawnShipmentId != shipment.id ||
              _drawnPolyline != shipment.polyline ||
              _drawnDeliveryPolyline != shipment.deliveryPolyline ||
              _drawnTripPhase != shipment.tripPhase ||
              (_drawnShipmentId == shipment.id && _polylineManager == null)) {
            _drawnShipmentId = shipment.id;
            _drawnPolyline = shipment.polyline;
            _drawnDeliveryPolyline = shipment.deliveryPolyline;
            _drawnTripPhase = shipment.tripPhase;
            _drawShipmentRoute(shipment);
          }

          return Stack(
            children: [
              // ── Map ──
              Positioned.fill(
                child: MapWidget(
                  key: const ValueKey('driver_trip_map'),
                  mapOptions: MapOptions(
                    pixelRatio: MediaQuery.of(context).devicePixelRatio,
                  ),
                  styleUri: AppConstants.mapboxStyleUrl,
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    _mapController!.location.updateSettings(
                      LocationComponentSettings(enabled: false),
                    );
                    // Draw the initial route once the map is ready
                    _drawShipmentRoute(shipment);

                    // Show current location for preview
                    final pos = await ref
                        .read(locationServiceProvider)
                        .getCurrentPosition();
                    if (pos != null) {
                      _updateDriverMarker(pos.latitude, pos.longitude);
                    }

                    // Compute routes from driver→factory & factory→destination
                    _computeInitialRoutes(shipment);
                  },
                  cameraOptions: CameraOptions(
                    center: Point(
                      coordinates: Position(
                        shipment.origin.longitude,
                        shipment.origin.latitude,
                      ),
                    ),
                    zoom: 15.5,
                  ),
                ),
              ),

              // ── Back Button ──
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardLight.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),

              // ── My Location Button ──
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.primary,
                    ),
                    tooltip: 'My Location',
                    onPressed: () async {
                      final pos = await ref
                          .read(locationServiceProvider)
                          .getCurrentPosition();
                      if (pos != null) {
                        _mapController?.flyTo(
                          CameraOptions(
                            center: Point(
                              coordinates: Position(
                                pos.longitude,
                                pos.latitude,
                              ),
                            ),
                            zoom: AppConstants.mapTrackingZoom,
                          ),
                          MapAnimationOptions(duration: 1000),
                        );
                      }
                    },
                  ),
                ),
              ),

              // ── Bottom Controls ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomControls(context, shipment),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, ShipmentModel shipment) {
    if (!_isTripStarted) {
      return _buildStartTripPanel(context, shipment);
    }
    return _buildNavigationPanel(context, shipment);
  }

  Widget _buildStartTripPanel(BuildContext context, ShipmentModel shipment) {
    final factoryLoc = shipment.factoryLocation ?? shipment.origin;
    final isPickupPhase = shipment.tripPhase == 'pickup';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Phase indicator ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPickupPhase
                  ? AppColors.info.withValues(alpha: 0.1)
                  : AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPickupPhase
                      ? Icons.factory_rounded
                      : Icons.local_shipping_rounded,
                  size: 16,
                  color: isPickupPhase ? AppColors.info : AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  isPickupPhase
                      ? 'PHASE 1 — FACTORY PICKUP'
                      : 'PHASE 2 — DELIVERY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: isPickupPhase ? AppColors.info : AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Route info ──
          // Leg 1: Factory
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.factory_rounded,
                  color: AppColors.info,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Factory: ${shipment.factoryId ?? 'Edita'}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.info,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      factoryLoc.address,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 15),
            child: SizedBox(
              height: 12,
              child: VerticalDivider(
                width: 1,
                thickness: 1.5,
                color: AppColors.glassBorder,
              ),
            ),
          ),
          // Leg 2: Destination
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DELIVERY DESTINATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      shipment.destination.address,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Distance / Duration for both legs ──
          if (shipment.distanceMeters > 0 ||
              shipment.deliveryDistanceMeters > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pickup leg info
                if (shipment.distanceMeters > 0)
                  Expanded(
                    child: _buildLegChip(
                      'Pickup',
                      '${(shipment.distanceMeters / 1000).toStringAsFixed(1)} km',
                      '${(shipment.durationSeconds / 60).round()} min',
                      AppColors.info,
                    ),
                  ),
                if (shipment.distanceMeters > 0 &&
                    shipment.deliveryDistanceMeters > 0)
                  const SizedBox(width: 8),
                // Delivery leg info
                if (shipment.deliveryDistanceMeters > 0)
                  Expanded(
                    child: _buildLegChip(
                      'Delivery',
                      '${(shipment.deliveryDistanceMeters / 1000).toStringAsFixed(1)} km',
                      '${(shipment.deliveryDurationSeconds / 60).round()} min',
                      AppColors.accent,
                    ),
                  ),
              ],
            ),
          ],

          // ── Price ──
          if (shipment.price > 0) ...[
            const SizedBox(height: 8),
            Text(
              'EGP ${shipment.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],

          // ── Total Trip ETA ──
          if (shipment.durationSeconds > 0 ||
              shipment.deliveryDurationSeconds > 0) ...[
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final totalSeconds =
                    shipment.durationSeconds + shipment.deliveryDurationSeconds;
                final eta = DateTime.now().add(Duration(seconds: totalSeconds));
                final etaStr =
                    '${eta.hour > 12 ? eta.hour - 12 : (eta.hour == 0 ? 12 : eta.hour)}:${eta.minute.toString().padLeft(2, '0')} ${eta.hour >= 12 ? 'PM' : 'AM'}';
                return Text(
                  'Full trip completes ~$etaStr',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 14),

          // ── Action Button ──
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : (shipment.status == AppConstants.statusPending
                        ? _acceptShipment
                        : _startTrip),
              icon: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      shipment.status == AppConstants.statusPending
                          ? Icons.check_circle_rounded
                          : Icons.play_arrow_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
              label: Text(
                shipment.status == AppConstants.statusPending
                    ? 'Accept Shipment'
                    : 'Start Trip',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegChip(
    String label,
    String distance,
    String duration,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.straighten_rounded, color: Colors.grey, size: 13),
            const SizedBox(width: 2),
            Text(
              distance,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.timer_outlined, color: Colors.grey, size: 13),
            const SizedBox(width: 2),
            Text(
              duration,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptShipment() async {
    setState(() => _isProcessing = true);

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      setState(() => _isProcessing = false);
      return;
    }

    final result = await ref
        .read(acceptShipmentUseCaseProvider)
        .call(
          AcceptShipmentParams(
            shipmentId: widget.shipmentId,
            driverId: widget.driverId,
            driverName: currentUser.name,
          ),
        );

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      (shipmentModel) {
        ref
            .read(driverRepositoryProvider)
            .updateCurrentShipment(
              driverId: widget.driverId,
              shipmentId: widget.shipmentId,
            );

        // Setup initial ETA and Tracking
        final locService = ref.read(locationServiceProvider);
        locService.startTracking();

        locService.getCurrentPosition().then((pos) {
          if (pos != null) {
            _updateETA(pos.latitude, pos.longitude);
            if (locService.onLocationUpdate != null) {
              locService.onLocationUpdate!(
                LocationPoint(
                  latitude: pos.latitude,
                  longitude: pos.longitude,
                  speed: pos.speed,
                  accuracy: pos.accuracy,
                  timestamp: pos.timestamp,
                ),
              );
            }
          }
        });
      },
    );

    setState(() => _isProcessing = false);
  }

  Widget _buildNavigationPanel(BuildContext context, ShipmentModel shipment) {
    final isPickupPhase = shipment.tripPhase == 'pickup';

    // Determine ETA time dynamically
    final bool hasData =
        shipment.durationSeconds > 0 && shipment.distanceMeters > 0;
    String minStr = 'Calculating...';
    String kmStr = '- km';

    if (hasData) {
      minStr = '${(shipment.durationSeconds / 60).round()} min';
      kmStr = '${(shipment.distanceMeters / 1000).toStringAsFixed(1)} km';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardLight.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(
          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Phase label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isPickupPhase
                  ? AppColors.info.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPickupPhase
                  ? '🏭  HEADING TO FACTORY'
                  : '🚚  DELIVERING TO CLIENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: isPickupPhase ? AppColors.info : AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.error, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    minStr,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasData)
                    Text(
                      kmStr,
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const Text(
                      'Fetching route...',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.alt_route,
                  color: AppColors.accent,
                  size: 28,
                ),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Phase-Aware Action Button ──
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : (isPickupPhase ? _markPickedUp : _completeTrip),
              icon: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isPickupPhase
                          ? Icons.inventory_rounded
                          : Icons.check_circle_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
              label: Text(
                isPickupPhase
                    ? 'Picked Up — Start Delivery'
                    : 'Complete Delivery',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPickupPhase
                    ? AppColors.accent
                    : AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mark shipment as picked up from factory and transition to delivery phase.
  Future<void> _markPickedUp() async {
    setState(() => _isProcessing = true);

    await ref
        .read(shipmentRepositoryProvider)
        .updateTripPhase(shipmentId: widget.shipmentId, tripPhase: 'delivery');

    setState(() => _isProcessing = false);
  }
}
