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

/// Real-time shipment tracking screen using Mapbox.
/// Shows driver position, route polyline, origin/destination markers, and ETA.
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

    // Listen for location history updates to animate map
    _locationSub = ref
        .read(shipmentRepositoryProvider)
        .streamLocationHistory(widget.shipmentId)
        .listen((points) {
          if (points.isNotEmpty) {
            final latest = points.last;
            _mapController?.flyTo(
              CameraOptions(
                center: Point(
                  coordinates: Position(latest.longitude, latest.latitude),
                ),
                zoom: AppConstants.mapTrackingZoom,
              ),
              MapAnimationOptions(duration: 1000),
            );
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
          lineWidth: 4.0,
          lineJoin: LineJoin.ROUND,
        );
        await _polylineManager!.create(lineOptions);
      }

      // Automatically bound camera to the origin and destination upon drawing
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

  /// Decode Mapbox polyline6 geometry back to a list of Coordinates.
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

          if (_drawnShipmentId != shipment.id ||
              (_drawnShipmentId == shipment.id && _polylineManager == null)) {
            _drawnShipmentId = shipment.id;
            _drawShipmentRoute(shipment);
          }

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
                        shipment.origin.longitude,
                        shipment.origin.latitude,
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

              // ── My Location Button ──
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child:
                    Container(
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
                                    zoom: 15,
                                  ),
                                  MapAnimationOptions(duration: 1500),
                                );
                              }
                            },
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .shimmer(
                          duration: 3000.ms,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
              ),

              // ── Uber-style Live Tracking Card ──
              if (shipment.status == AppConstants.statusInProgress)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 80,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(shipment.durationSeconds / 60).round()} min',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Driver is on the way',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${(shipment.distanceMeters / 1000).toStringAsFixed(1)} km away • ETA ${shipment.etaTimestamp != null ? DateFormat('hh:mm a').format(shipment.etaTimestamp!) : ''}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
                ),

              // ── Bottom Info Panel ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildInfoPanel(context, shipment),
              ),
            ],
          );
        },
      ),
    );
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

  Widget _buildInfoPanel(BuildContext context, ShipmentModel shipment) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 20,
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
          // Handle indicator
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
          const SizedBox(height: 16),

          // Status and ETA + Delivery icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusChip(status: shipment.status),
                ],
              ),
              if (shipment.etaTimestamp != null)
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ETA: ${DateFormat('HH:mm').format(shipment.etaTimestamp!)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Route info
          _buildRouteRow(
            context,
            icon: Icons.circle,
            iconColor: AppColors.success,
            label: 'Pickup',
            address: shipment.origin.address,
          ),
          const SizedBox(height: 12),
          _buildRouteRow(
            context,
            icon: Icons.location_on,
            iconColor: AppColors.error,
            label: 'Drop-off',
            address: shipment.destination.address,
          ),

          if (shipment.distanceMeters > 0) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoPill(
                  icon: Icons.straighten_rounded,
                  label: 'Distance',
                  value: _formatDistance(shipment.distanceMeters),
                ),
                _InfoPill(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: _formatDuration(shipment.durationSeconds),
                ),
              ],
            ),
          ],

          if (shipment.driverName != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.cardElevated,
                  child: Icon(Icons.person, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shipment.driverName!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Driver',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ],
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
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                address,
                style: Theme.of(context).textTheme.titleMedium,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textHint, size: 18),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
