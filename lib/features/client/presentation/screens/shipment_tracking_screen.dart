import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/map_marker_util.dart';
import '../../../shipment/domain/models/shipment_model.dart';

/// Real-time shipment tracking screen for the CLIENT.
/// Shows: Factory marker, Destination marker, Driver live icon,
/// both route legs (pickup + delivery), phase-aware info panel.
class ShipmentTrackingScreen extends ConsumerStatefulWidget {
  final String shipmentId;
  const ShipmentTrackingScreen({super.key, required this.shipmentId});

  @override
  ConsumerState<ShipmentTrackingScreen> createState() =>
      _ShipmentTrackingScreenState();
}

class _ShipmentTrackingScreenState
    extends ConsumerState<ShipmentTrackingScreen> {
  MapboxMap? _mapController;
  StreamSubscription? _locationSub;

  PointAnnotationManager? _poiPointManager;
  PolylineAnnotationManager? _polylineManager;
  PointAnnotationManager? _driverPointManager;
  PointAnnotation? _driverAnnotation;
  String? _drawnShipmentId;
  String? _drawnPolyline;
  String? _drawnDeliveryPolyline;
  String? _drawnTripPhase;

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  void _onMapCreated(MapboxMap controller) {
    _mapController = controller;

    _mapController!.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: AppColors.primary.toARGB32(),
      ),
    );

    // Listen for driver's live location updates
    _locationSub = ref
        .read(shipmentRepositoryProvider)
        .streamLocationHistory(widget.shipmentId)
        .listen((points) {
          if (points.isNotEmpty) {
            final latest = points.last;
            _updateDriverPosition(latest.latitude, latest.longitude);
          }
        });
  }

  Future<void> _updateDriverPosition(double lat, double lng) async {
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
      debugPrint('Error updating driver position: $e');
    }
  }

  /// Draws factory marker, destination marker, and both route polylines.
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

      // ── Labeled markers ──
      final factoryIconBytes = await MapMarkerUtil.getLabeledMarkerBytes(
        label: 'Factory ${shipment.factoryId ?? ''}',
        color: AppColors.accent,
        size: 180,
      );
      final destIconBytes = await MapMarkerUtil.getLabeledMarkerBytes(
        label: 'Destination',
        color: AppColors.info,
        size: 180,
      );

      final factoryMarker = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(factoryLoc.longitude, factoryLoc.latitude),
        ),
        image: factoryIconBytes,
        iconAnchor: IconAnchor.BOTTOM,
      );

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

      // ── Pickup leg polyline (driver → factory) — BLUE ──
      if (isPickupPhase &&
          shipment.polyline != null &&
          shipment.polyline!.isNotEmpty) {
        final pickupPts = _decodePolyline(shipment.polyline!, precision: 6);
        if (pickupPts.length >= 2) {
          await _polylineManager!.create(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: pickupPts),
              lineColor: AppColors.info.toARGB32(),
              lineWidth: 5.0,
              lineJoin: LineJoin.ROUND,
            ),
          );
        }
      }

      // ── Delivery leg polyline (factory → destination) — ORANGE ──
      if (shipment.deliveryPolyline != null &&
          shipment.deliveryPolyline!.isNotEmpty) {
        final deliveryPts = _decodePolyline(
          shipment.deliveryPolyline!,
          precision: 6,
        );
        if (deliveryPts.length >= 2) {
          await _polylineManager!.create(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: deliveryPts),
              lineColor: AppColors.accent.toARGB32(),
              lineWidth: isPickupPhase ? 3.5 : 5.0,
              lineJoin: LineJoin.ROUND,
            ),
          );
        }
      }

      // ── During delivery phase, main polyline = driver→destination ──
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
              lineWidth: 5.0,
              lineJoin: LineJoin.ROUND,
            ),
          );
        }
      }

      // ── Fallback straight line ──
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
            lineColor: AppColors.info.toARGB32(),
            lineWidth: 4.0,
            lineJoin: LineJoin.ROUND,
          ),
        );
      }

      // ── Camera bounds ──
      final allLats = [factoryLoc.latitude, shipment.destination.latitude];
      final allLngs = [factoryLoc.longitude, shipment.destination.longitude];

      final bounds = CoordinateBounds(
        southwest: Point(
          coordinates: Position(
            allLngs.reduce(math.min) - 0.01,
            allLats.reduce(math.min) - 0.01,
          ),
        ),
        northeast: Point(
          coordinates: Position(
            allLngs.reduce(math.max) + 0.01,
            allLats.reduce(math.max) + 0.01,
          ),
        ),
        infiniteBounds: true,
      );
      final cameraOptions = await _mapController!.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 160, left: 60, bottom: 320, right: 60),
        null,
        null,
        null,
        null,
      );
      _mapController!.flyTo(cameraOptions, MapAnimationOptions(duration: 800));
    } catch (e) {
      debugPrint('Error drawing tracking route: $e');
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

          // Redraw when route data or phase changes
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

          final isPickupPhase = shipment.tripPhase == 'pickup';
          final isInProgress = shipment.status == AppConstants.statusInProgress;

          return Stack(
            children: [
              // ── Map ──
              Positioned.fill(
                child: MapWidget(
                  key: const ValueKey('tracking_map'),
                  mapOptions: MapOptions(
                    pixelRatio: MediaQuery.of(context).devicePixelRatio,
                  ),
                  styleUri: AppConstants.mapboxStyleUrl,
                  onMapCreated: _onMapCreated,
                  cameraOptions: CameraOptions(
                    center: Point(
                      coordinates: Position(
                        shipment.destination.longitude,
                        shipment.destination.latitude,
                      ),
                    ),
                    zoom: AppConstants.mapDefaultZoom,
                  ),
                ),
              ),

              // ── Back Button ──
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: _buildBackButton(context),
              ),

              // ── Live Tracking Card (when in progress) ──
              if (isInProgress)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 80,
                  right: 16,
                  child: _buildLiveTrackingCard(shipment, isPickupPhase),
                ),

              // ── Bottom Info Panel ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildInfoPanel(context, shipment, isPickupPhase),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Live tracking card at the top ──
  Widget _buildLiveTrackingCard(ShipmentModel shipment, bool isPickup) {
    final hasData = shipment.durationSeconds > 0 && shipment.distanceMeters > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Phase badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isPickup ? AppColors.accent : AppColors.info,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPickup
                      ? Icons.factory_rounded
                      : Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(height: 2),
                Text(
                  hasData
                      ? '${(shipment.durationSeconds / 60).round()} min'
                      : '...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPickup
                      ? 'Driver heading to Factory'
                      : 'Driver delivering to you',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  hasData
                      ? '${(shipment.distanceMeters / 1000).toStringAsFixed(1)} km away • ETA ${shipment.etaTimestamp != null ? DateFormat('hh:mm a').format(shipment.etaTimestamp!) : ''}'
                      : 'Connecting to driver...',
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2);
  }

  Widget _buildBackButton(BuildContext context) {
    return Container(
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
    );
  }

  // ── Bottom info panel ──
  Widget _buildInfoPanel(
    BuildContext context,
    ShipmentModel shipment,
    bool isPickup,
  ) {
    final factoryLoc = shipment.factoryLocation ?? shipment.origin;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(
          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Status + Phase ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatusChip(status: shipment.status),
              // Phase pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isPickup ? AppColors.accent : AppColors.info)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPickup
                          ? Icons.factory_rounded
                          : Icons.local_shipping_rounded,
                      size: 14,
                      color: isPickup ? AppColors.accent : AppColors.info,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPickup ? 'PICKUP' : 'DELIVERY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isPickup ? AppColors.accent : AppColors.info,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Route: Factory → Destination ──
          _buildRouteRow(
            context,
            icon: Icons.factory_rounded,
            iconColor: AppColors.accent,
            label: 'Factory ${shipment.factoryId ?? ''}',
            address: factoryLoc.address,
          ),
          // Connecting line
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Column(
              children: List.generate(
                3,
                (_) => Container(
                  width: 2,
                  height: 6,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  color: AppColors.glassBorder,
                ),
              ),
            ),
          ),
          _buildRouteRow(
            context,
            icon: Icons.location_on_rounded,
            iconColor: AppColors.info,
            label: 'Destination',
            address: shipment.destination.address,
          ),

          // ── Distance/Duration chips ──
          if (shipment.distanceMeters > 0 ||
              shipment.deliveryDistanceMeters > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (shipment.distanceMeters > 0)
                  _buildLegChip(
                    isPickup ? 'To Factory' : 'To Destination',
                    _formatDistance(shipment.distanceMeters),
                    _formatDuration(shipment.durationSeconds),
                    isPickup ? AppColors.accent : AppColors.info,
                  ),
                if (shipment.deliveryDistanceMeters > 0)
                  _buildLegChip(
                    'Delivery Leg',
                    _formatDistance(shipment.deliveryDistanceMeters),
                    _formatDuration(shipment.deliveryDurationSeconds),
                    AppColors.info,
                  ),
              ],
            ),
          ],

          // ── ETA ──
          if (shipment.etaTimestamp != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'ETA: ${DateFormat('hh:mm a').format(shipment.etaTimestamp!)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],

          // ── Driver info ──
          if (shipment.driverName != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.cardElevated,
                  child: Icon(Icons.person, color: AppColors.accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shipment.driverName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        'Driver',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$distance • $duration',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
              Text(
                address,
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
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).round()} min';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    return '${hours}h ${mins}m';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case AppConstants.statusPending:
        color = AppColors.statusPending;
        label = 'Pending';
        break;
      case AppConstants.statusAccepted:
        color = AppColors.statusAccepted;
        label = 'Accepted';
        break;
      case AppConstants.statusInProgress:
        color = AppColors.statusInProgress;
        label = 'In Progress';
        break;
      case AppConstants.statusCompleted:
        color = AppColors.statusCompleted;
        label = 'Completed';
        break;
      case AppConstants.statusCancelled:
        color = AppColors.statusCancelled;
        label = 'Cancelled';
        break;
      default:
        color = AppColors.textHint;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
