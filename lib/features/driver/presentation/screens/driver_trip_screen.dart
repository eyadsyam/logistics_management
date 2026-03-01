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

  /// Update ETA based on current position.
  Future<void> _updateETA(double lat, double lng) async {
    // Get shipment destination
    final shipmentResult = await ref
        .read(shipmentRepositoryProvider)
        .getShipment(widget.shipmentId);

    shipmentResult.fold((_) => null, (shipment) async {
      final eta = await ref
          .read(mapboxServiceProvider)
          .calculateETA(
            currentLat: lat,
            currentLng: lng,
            destLat: shipment.destination.latitude,
            destLng: shipment.destination.longitude,
          );

      if (eta != null) {
        final directions = await ref
            .read(mapboxServiceProvider)
            .getDirections(
              originLat: lat,
              originLng: lng,
              destLat: shipment.destination.latitude,
              destLng: shipment.destination.longitude,
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

      final originIconBytes = await MapMarkerUtil.getOriginMarkerBytes(
        size: 80,
      );
      final destIconBytes = await MapMarkerUtil.getDestinationMarkerBytes(
        size: 80,
      );

      final originMarker = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            shipment.origin.longitude,
            shipment.origin.latitude,
          ),
        ),
        image: originIconBytes,
      );

      final destMarker = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            shipment.destination.longitude,
            shipment.destination.latitude,
          ),
        ),
        image: destIconBytes,
      );

      await _poiPointManager!.createMulti([originMarker, destMarker]);

      List<Position> linePoints = [];
      if (shipment.polyline != null && shipment.polyline!.isNotEmpty) {
        linePoints = _decodePolyline(shipment.polyline!, precision: 6);
      }

      // 🔄 Fallback: Always draw a straight line if route is missing
      if (linePoints.isEmpty) {
        linePoints = [
          Position(shipment.origin.longitude, shipment.origin.latitude),
          Position(
            shipment.destination.longitude,
            shipment.destination.latitude,
          ),
        ];
      }

      if (linePoints.isNotEmpty) {
        final lineOptions = PolylineAnnotationOptions(
          geometry: LineString(coordinates: linePoints),
          lineColor: AppColors.primary.toARGB32(),
          lineWidth: 5.0,
          lineJoin: LineJoin.ROUND,
        );
        await _polylineManager!.create(lineOptions);
      }

      final bounds = CoordinateBounds(
        southwest: Point(
          coordinates: Position(
            math.min(shipment.origin.longitude, shipment.destination.longitude),
            math.min(shipment.origin.latitude, shipment.destination.latitude),
          ),
        ),
        northeast: Point(
          coordinates: Position(
            math.max(shipment.origin.longitude, shipment.destination.longitude),
            math.max(shipment.origin.latitude, shipment.destination.latitude),
          ),
        ),
        infiniteBounds: true,
      );
      final cameraOptions = await _mapController!.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 150, left: 60, bottom: 250, right: 60),
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
              (_drawnShipmentId == shipment.id && _polylineManager == null)) {
            _drawnShipmentId = shipment.id;
            _drawnPolyline = shipment.polyline;
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
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _mapController!.location.updateSettings(
                      LocationComponentSettings(
                        enabled:
                            false, // Turn off native dot so only Custom Car shows up
                      ),
                    );
                    // Draw the initial route once the map is ready
                    _drawShipmentRoute(shipment);
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
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 20,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      shipment.origin.address,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Drop-off',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      shipment.destination.address,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (shipment.distanceMeters > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.straighten_rounded,
                  color: Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(shipment.distanceMeters / 1000).toStringAsFixed(1)} km',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.timer_outlined, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${(shipment.durationSeconds / 60).round()} min',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _startTrip,
              icon: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.play_arrow_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
              label: const Text(
                'Start Trip',
                style: TextStyle(
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

  Widget _buildNavigationPanel(BuildContext context, ShipmentModel shipment) {
    // Determine ETA time dynamically (if 0 or uncalculated, we show placeholders)
    final bool hasData =
        shipment.durationSeconds > 0 && shipment.distanceMeters > 0;
    String minStr = 'Calculating...';
    String kmStr = '- km';
    String formatTime = '--:--';

    if (hasData) {
      final etaTime = DateTime.now().add(
        Duration(seconds: shipment.durationSeconds),
      );
      formatTime =
          '${etaTime.hour > 12 ? etaTime.hour - 12 : (etaTime.hour == 0 ? 12 : etaTime.hour)}:${etaTime.minute.toString().padLeft(2, '0')} ${etaTime.hour >= 12 ? 'pm' : 'am'}';
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
        color: AppColors.cardLight.withValues(alpha: 0.95), // Bright App Theme
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
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        minStr,
                        style: const TextStyle(
                          color: AppColors.primary, // Orange primary text
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Small delivery truck icon
                      if (hasData)
                        const Icon(
                          Icons.local_shipping,
                          color: AppColors.success,
                          size: 24,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (hasData)
                    Text(
                      '$kmStr • $formatTime',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const Text(
                      'Fetching actual route...',
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _completeTrip,
              icon: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.check_circle_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
              label: const Text(
                'Complete Delivery',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
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
}
