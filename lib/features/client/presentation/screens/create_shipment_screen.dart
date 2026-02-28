import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/map_marker_util.dart';
import '../../../map/data/services/mapbox_service.dart';
import '../../../shipment/domain/models/shipment_model.dart';
import '../../../shipment/domain/usecases/create_shipment_usecase.dart';

// ── Package type definitions ──
enum PackageType {
  molto(
    'Molto',
    Icons.bakery_dining,
    'Sweet Baked',
    'assets/images/brands/molto.png',
  ),
  todo('TODO', Icons.cake, 'Cakes', 'assets/images/brands/todo.png'),
  bakeRolz(
    'Bake Rolz',
    Icons.breakfast_dining,
    'Salty Snacks',
    'assets/images/brands/bakerolz.png',
  ),
  freska('Freska', Icons.icecream, 'Wafers', 'assets/images/brands/freska.png'),
  mixedPallet('Mixed Pallet', Icons.view_in_ar_rounded, 'Various', null),
  other('Other', Icons.inventory_2_outlined, 'Custom', null);

  const PackageType(this.label, this.icon, this.description, this.brandAsset);
  final String label;
  final IconData icon;
  final String description;
  final String? brandAsset;
}

enum ShipmentPriority {
  standard('Standard', '3-5 business days', 1.0, Icons.schedule),
  express('Express', '1-2 business days', 1.8, Icons.local_shipping_rounded),
  sameDay('Same Day', 'Within hours', 3.0, Icons.flash_on_rounded);

  const ShipmentPriority(
    this.label,
    this.description,
    this.multiplier,
    this.icon,
  );
  final String label;
  final String description;
  final double multiplier;
  final IconData icon;
}

/// Screen for creating a new shipment with interactive map,
/// package details, priority selection, and cost estimation.
class CreateShipmentScreen extends ConsumerStatefulWidget {
  const CreateShipmentScreen({super.key});

  @override
  ConsumerState<CreateShipmentScreen> createState() =>
      _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends ConsumerState<CreateShipmentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();

  int _currentStep = 0; // 0=Route, 1=Package, 2=Review
  ShipmentLocation? _origin;
  ShipmentLocation? _destination;
  List<GeocodingResult> _originSuggestions = [];
  List<GeocodingResult> _destSuggestions = [];
  bool _isLoading = false;
  bool _showOriginSuggestions = false;
  bool _showDestSuggestions = false;
  bool _isSelectingOriginOnMap = false;
  bool _isSelectingDestOnMap = false;

  DirectionsResult? _routeInfo;
  MapboxMap? _mapController;
  PointAnnotationManager? _poiPointManager;
  PointAnnotationManager? _fleetManager;
  PolylineAnnotationManager? _polylineManager;

  // Map search bar
  final _mapSearchController = TextEditingController();
  List<GeocodingResult> _mapSearchResults = [];
  bool _showMapSearchResults = false;
  bool _isSearchingMap = false;

  PackageType _selectedPackage = PackageType.molto;
  ShipmentPriority _selectedPriority = ShipmentPriority.standard;
  int _packageCount = 1;
  bool _requireSignature = false;
  bool _insuranceEnabled = false;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Auto-fetch current location when opening the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCurrentLocation();
    });
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _mapSearchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Auto Location ──
  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLoading = true);

    final position = await ref
        .read(locationServiceProvider)
        .getCurrentPosition();

    if (position != null) {
      final address = await ref
          .read(mapboxServiceProvider)
          .reverseGeocode(lat: position.latitude, lng: position.longitude);

      if (address != null && mounted) {
        setState(() {
          _origin = ShipmentLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            address: address,
          );
          _originController.text = address;
        });
        _updateMapForRoute();
        _calculateRoute();
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ── Set location from map search ──
  void _setLocationFromSearch(
    GeocodingResult result, {
    required bool isOrigin,
  }) {
    final location = ShipmentLocation(
      latitude: result.latitude,
      longitude: result.longitude,
      address: result.placeName,
    );

    setState(() {
      if (isOrigin) {
        _origin = location;
        _originController.text = result.placeName;
        _isSelectingOriginOnMap = false;
      } else {
        _destination = location;
        _destinationController.text = result.placeName;
        _isSelectingDestOnMap = false;
      }
    });

    _updateMapForRoute();
    _drawMapElements();
    _calculateRoute();
  }

  // ── Geocoding ──
  Future<void> _searchOrigin(String query) async {
    if (query.length < 3) {
      setState(() {
        _originSuggestions = [];
        _showOriginSuggestions = false;
      });
      return;
    }

    final pos = await ref.read(locationServiceProvider).getCurrentPosition();

    final results = await ref
        .read(mapboxServiceProvider)
        .forwardGeocode(
          query,
          proximityLat: pos?.latitude,
          proximityLng: pos?.longitude,
        );
    setState(() {
      _originSuggestions = results;
      _showOriginSuggestions = results.isNotEmpty;
    });
  }

  Future<void> _searchDestination(String query) async {
    if (query.length < 3) {
      setState(() {
        _destSuggestions = [];
        _showDestSuggestions = false;
      });
      return;
    }

    final pos = await ref.read(locationServiceProvider).getCurrentPosition();

    final results = await ref
        .read(mapboxServiceProvider)
        .forwardGeocode(
          query,
          proximityLat: pos?.latitude ?? _origin?.latitude,
          proximityLng: pos?.longitude ?? _origin?.longitude,
        );
    setState(() {
      _destSuggestions = results;
      _showDestSuggestions = results.isNotEmpty;
    });
  }

  void _selectOrigin(GeocodingResult result) {
    setState(() {
      _origin = ShipmentLocation(
        latitude: result.latitude,
        longitude: result.longitude,
        address: result.placeName,
      );
      _originController.text = result.placeName;
      _originSuggestions = [];
      _showOriginSuggestions = false;
    });
    _updateMapForRoute();
    _drawMapElements();
    _calculateRoute();
  }

  void _selectDestination(GeocodingResult result) {
    setState(() {
      _destination = ShipmentLocation(
        latitude: result.latitude,
        longitude: result.longitude,
        address: result.placeName,
      );
      _destinationController.text = result.placeName;
      _destSuggestions = [];
      _showDestSuggestions = false;
    });
    _updateMapForRoute();
    _drawMapElements();
    _calculateRoute();
  }

  // ── Map tap to pick location ──
  void _onMapTap(MapContentGestureContext gestureContext) async {
    final point = gestureContext.point;
    final lat = point.coordinates.lat.toDouble();
    final lng = point.coordinates.lng.toDouble();

    final address = await ref
        .read(mapboxServiceProvider)
        .reverseGeocode(lat: lat, lng: lng);

    if (address == null) return;

    if (_isSelectingOriginOnMap) {
      setState(() {
        _origin = ShipmentLocation(
          latitude: lat,
          longitude: lng,
          address: address,
        );
        _originController.text = address;
        _isSelectingOriginOnMap = false;
      });
      _drawMapElements();
      _calculateRoute();
    } else if (_isSelectingDestOnMap) {
      setState(() {
        _destination = ShipmentLocation(
          latitude: lat,
          longitude: lng,
          address: address,
        );
        _destinationController.text = address;
        _isSelectingDestOnMap = false;
      });
      _drawMapElements();
      _calculateRoute();
    }
  }

  void _updateMapForRoute() async {
    if (_mapController == null) return;
    if (_origin != null && _destination != null) {
      final bounds = CoordinateBounds(
        southwest: Point(
          coordinates: Position(
            math.min(_origin!.longitude, _destination!.longitude),
            math.min(_origin!.latitude, _destination!.latitude),
          ),
        ),
        northeast: Point(
          coordinates: Position(
            math.max(_origin!.longitude, _destination!.longitude),
            math.max(_origin!.latitude, _destination!.latitude),
          ),
        ),
        infiniteBounds: true,
      );
      try {
        final cameraOptions = await _mapController!.cameraForCoordinateBounds(
          bounds,
          MbxEdgeInsets(top: 100, left: 60, bottom: 250, right: 60),
          null,
          null,
          null,
          null,
        );
        _mapController!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 800),
        );
      } catch (e) {
        debugPrint('Error animating bounds: $e');
      }
    } else {
      final target = _destination ?? _origin;
      if (target != null) {
        _mapController!.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(target.longitude, target.latitude),
            ),
            zoom: AppConstants.mapDefaultZoom,
          ),
          MapAnimationOptions(duration: 800),
        );
      }
    }
  }

  Future<void> _calculateRoute() async {
    if (_origin == null || _destination == null) return;

    final result = await ref
        .read(mapboxServiceProvider)
        .getDirections(
          originLat: _origin!.latitude,
          originLng: _origin!.longitude,
          destLat: _destination!.latitude,
          destLng: _destination!.longitude,
        );

    setState(() => _routeInfo = result);
    _drawMapElements();
  }

  Future<void> _drawMapElements() async {
    if (_mapController == null) return;
    try {
      _poiPointManager ??= await _mapController!.annotations
          .createPointAnnotationManager();
      _fleetManager ??= await _mapController!.annotations
          .createPointAnnotationManager();
      _polylineManager ??= await _mapController!.annotations
          .createPolylineAnnotationManager();

      await _poiPointManager!.deleteAll();
      await _polylineManager!.deleteAll();

      final List<PointAnnotationOptions> pois = [];

      if (_origin != null) {
        final originIcon = await MapMarkerUtil.getOriginMarkerBytes(size: 80);
        pois.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(_origin!.longitude, _origin!.latitude),
            ),
            image: originIcon,
          ),
        );

        // 🚗 Simulate Uber-like nearby drivers roaming
        await _fleetManager!.deleteAll();
        final carIcon = await MapMarkerUtil.getCarMarkerBytes(size: 150);
        final List<PointAnnotationOptions> fleet = [];
        final rnd = math.Random();
        for (int i = 0; i < 4; i++) {
          final double offsetLat = (rnd.nextDouble() - 0.5) * 0.015;
          final double offsetLng = (rnd.nextDouble() - 0.5) * 0.015;
          fleet.add(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(
                  _origin!.longitude + offsetLng,
                  _origin!.latitude + offsetLat,
                ),
              ),
              image: carIcon,
            ),
          );
        }
        await _fleetManager!.createMulti(fleet);
      }

      if (_destination != null) {
        final destIcon = await MapMarkerUtil.getDestinationMarkerBytes(
          size: 80,
        );
        pois.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                _destination!.longitude,
                _destination!.latitude,
              ),
            ),
            image: destIcon,
          ),
        );
      }

      if (pois.isNotEmpty) {
        await _poiPointManager!.createMulti(pois);
      }

      List<Position> linePoints = [];
      if (_routeInfo != null && _routeInfo!.polyline.isNotEmpty) {
        linePoints = _decodePolyline(_routeInfo!.polyline, precision: 6);
      }

      // 🔄 Fallback: Always draw a straight line if route is missing
      if (linePoints.isEmpty && (_origin != null && _destination != null)) {
        linePoints = [
          Position(_origin!.longitude, _origin!.latitude),
          Position(_destination!.longitude, _destination!.latitude),
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

  // ── Cost estimation ──
  double get _estimatedCost {
    double baseCost = 100.0; // Base rate in EGP
    if (_routeInfo != null) {
      baseCost +=
          (_routeInfo!.distanceMeters / 1000) * 15.0; // Per KM rate in EGP
    }
    // Package type multiplier
    switch (_selectedPackage) {
      case PackageType.molto:
      case PackageType.todo:
      case PackageType.bakeRolz:
      case PackageType.freska:
        break; // Standard box weight
      case PackageType.mixedPallet:
        baseCost *= 3.0; // Heavy
        break;
      case PackageType.other:
        baseCost *= 1.5; // Custom size
        break;
    }
    baseCost *= _selectedPriority.multiplier;
    baseCost *= _packageCount;
    if (_insuranceEnabled) baseCost += 750.0; // Flat EGP 750 for insurance
    if (_requireSignature) baseCost += 250.0; // Flat EGP 250 for signature
    return baseCost;
  }

  // ── Step navigation ──
  void _nextStep() {
    if (_currentStep == 0) {
      if (_origin == null || _destination == null) {
        _showError('Please select both pickup and drop-off locations');
        return;
      }
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showError(String message) {
    AppErrorHandler.showError(context, message);
  }

  // ── Submit ──
  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final result = await ref
        .read(createShipmentUseCaseProvider)
        .call(
          CreateShipmentParams(
            clientId: currentUser.id,
            origin: _origin!,
            destination: _destination!,
            notes: _buildNotesString(),
          ),
        );

    setState(() => _isLoading = false);

    result.fold((failure) => _showError(failure.message), (shipment) {
      if (_routeInfo != null) {
        ref
            .read(shipmentRepositoryProvider)
            .updateShipmentRoute(
              shipmentId: shipment.id,
              polyline: _routeInfo!.polyline,
              distanceMeters: _routeInfo!.distanceMeters,
              durationSeconds: _routeInfo!.durationSeconds,
              etaTimestamp: DateTime.now().add(
                Duration(seconds: _routeInfo!.durationSeconds),
              ),
            );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 20),
              SizedBox(width: 8),
              Text('Shipment created successfully!'),
            ],
          ),
          backgroundColor: AppColors.cardElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      Navigator.of(context).pop();
    });
  }

  String _buildNotesString() {
    final parts = <String>[];
    parts.add('Package: ${_selectedPackage.label} x$_packageCount');
    parts.add('Priority: ${_selectedPriority.label}');
    if (_recipientNameController.text.isNotEmpty) {
      parts.add('Recipient: ${_recipientNameController.text}');
    }
    if (_recipientPhoneController.text.isNotEmpty) {
      parts.add('Phone: ${_recipientPhoneController.text}');
    }
    if (_requireSignature) parts.add('Signature required');
    if (_insuranceEnabled) parts.add('Insurance enabled');
    if (_notesController.text.trim().isNotEmpty) {
      parts.add('Notes: ${_notesController.text.trim()}');
    }
    return parts.join(' | ');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ──
              _buildAppBar(),

              // ── Step Indicator ──
              _buildStepIndicator().animate().fadeIn(duration: 400.ms),

              // ── Content ──
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1Route(),
                    _buildStep2Package(),
                    _buildStep3Review(),
                  ],
                ),
              ),

              // ── Bottom Action Bar ──
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _currentStep > 0
                ? _prevStep
                : () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Shipment',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  [
                    'Route',
                    'Package Details',
                    'Review & Confirm',
                  ][_currentStep],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Step counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '${_currentStep + 1}/3',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STEP INDICATOR
  // ═══════════════════════════════════════════
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isActive || isCompleted
                          ? AppColors.primary
                          : AppColors.cardElevated,
                    ),
                  ),
                ),
                if (index < 2) const SizedBox(width: 6),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STEP 1 — ROUTE (with Map)
  // ═══════════════════════════════════════════
  Widget _buildStep1Route() {
    return Stack(
      children: [
        // ── Map ──
        Positioned.fill(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: MapWidget(
                  key: const ValueKey('create_shipment_map'),
                  mapOptions: MapOptions(
                    pixelRatio: MediaQuery.of(context).devicePixelRatio,
                  ),
                  styleUri: AppConstants.mapboxStyleUrl,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _mapController!.location.updateSettings(
                      LocationComponentSettings(
                        enabled: true,
                        pulsingEnabled: true,
                        pulsingColor: AppColors.primary.toARGB32(),
                      ),
                    );
                    controller.setOnMapTapListener(_onMapTap);
                  },
                  cameraOptions: CameraOptions(
                    center: Point(
                      coordinates: Position(31.235, 30.045), // Default: Cairo
                    ),
                    zoom: 11,
                  ),
                ),
              ),
              // ── My Location ──
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
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
              // ── Map Search Bar ──
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _mapSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search for a place...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primary,
                          ),
                          suffixIcon: _mapSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _mapSearchController.clear();
                                    setState(() {
                                      _mapSearchResults = [];
                                      _showMapSearchResults = false;
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (query) async {
                          if (query.length < 3) {
                            setState(() {
                              _mapSearchResults = [];
                              _showMapSearchResults = false;
                            });
                            return;
                          }
                          setState(() => _isSearchingMap = true);
                          final pos = await ref
                              .read(locationServiceProvider)
                              .getCurrentPosition();
                          final results = await ref
                              .read(mapboxServiceProvider)
                              .forwardGeocode(
                                query,
                                proximityLat: pos?.latitude,
                                proximityLng: pos?.longitude,
                              );
                          if (mounted) {
                            setState(() {
                              _mapSearchResults = results;
                              _showMapSearchResults = results.isNotEmpty;
                              _isSearchingMap = false;
                            });
                          }
                        },
                      ),
                    ),
                    if (_isSearchingMap)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    if (_showMapSearchResults && _mapSearchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _mapSearchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final result = _mapSearchResults[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.place,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              title: Text(
                                result.placeName,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                _mapSearchController.text = result.placeName;
                                setState(() {
                                  _showMapSearchResults = false;
                                  _mapSearchResults = [];
                                });
                                // Fly to location on map
                                _mapController?.flyTo(
                                  CameraOptions(
                                    center: Point(
                                      coordinates: Position(
                                        result.longitude,
                                        result.latitude,
                                      ),
                                    ),
                                    zoom: 15,
                                  ),
                                  MapAnimationOptions(duration: 1500),
                                );
                                // If selecting origin or dest, also set it
                                if (_isSelectingOriginOnMap) {
                                  _setLocationFromSearch(
                                    result,
                                    isOrigin: true,
                                  );
                                } else if (_isSelectingDestOnMap) {
                                  _setLocationFromSearch(
                                    result,
                                    isOrigin: false,
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              if (_isSelectingOriginOnMap || _isSelectingDestOnMap)
                Positioned(
                  top: 70,
                  left: 0,
                  right: 0,
                  child: Center(
                    child:
                        Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardLight.withValues(
                                  alpha: 0.95,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: _isSelectingOriginOnMap
                                      ? AppColors.success
                                      : AppColors.error,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    color: _isSelectingOriginOnMap
                                        ? AppColors.success
                                        : AppColors.error,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isSelectingOriginOnMap
                                        ? 'Tap to set pickup location'
                                        : 'Tap to set drop-off location',
                                    style: TextStyle(
                                      color: _isSelectingOriginOnMap
                                          ? AppColors.success
                                          : AppColors.error,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .fadeIn()
                            .then()
                            .shimmer(
                              duration: 1500.ms,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                  ),
                ),
              // Removed route overlay to put inside bottom sheet
            ],
          ),
        ),

        // ── Draggable Bottom Sheet for Inputs ──
        DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.15,
          maxChildSize: 0.85,
          snap: true,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundGradient.last,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Handle Bar
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 20),
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.textHint.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (_routeInfo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.glassBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _miniRouteInfo(
                                Icons.straighten_rounded,
                                _formatDistance(_routeInfo!.distanceMeters),
                                'Distance',
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: AppColors.glassBorder,
                              ),
                              _miniRouteInfo(
                                Icons.timer_outlined,
                                _formatDuration(_routeInfo!.durationSeconds),
                                'Duration',
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: AppColors.glassBorder,
                              ),
                              _miniRouteInfo(
                                Icons.attach_money_rounded,
                                'EGP ${_estimatedCost.toStringAsFixed(0)}',
                                'Est. Cost',
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2),
                      _buildLocationInput(
                        controller: _originController,
                        label: 'Pickup Location',
                        hint: 'Search or tap map...',
                        iconColor: AppColors.success,
                        icon: Icons.my_location_rounded,
                        suggestions: _originSuggestions,
                        showSuggestions: _showOriginSuggestions,
                        onChanged: _searchOrigin,
                        onSelect: _selectOrigin,
                        onMapPick: () {
                          setState(() {
                            _isSelectingOriginOnMap = true;
                            _isSelectingDestOnMap = false;
                          });
                        },
                        onMyLocationPick: _fetchCurrentLocation,
                      ),
                      const SizedBox(height: 10),
                      _buildLocationInput(
                        controller: _destinationController,
                        label: 'Drop-off Location',
                        hint: 'Search or tap map...',
                        iconColor: AppColors.error,
                        icon: Icons.location_on_rounded,
                        suggestions: _destSuggestions,
                        showSuggestions: _showDestSuggestions,
                        onChanged: _searchDestination,
                        onSelect: _selectDestination,
                        onMapPick: () {
                          setState(() {
                            _isSelectingDestOnMap = true;
                            _isSelectingOriginOnMap = false;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 48), // Bottom safe space
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _miniRouteInfo(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textHint, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildLocationInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color iconColor,
    required IconData icon,
    required List<GeocodingResult> suggestions,
    required bool showSuggestions,
    required Function(String) onChanged,
    required Function(GeocodingResult) onSelect,
    required VoidCallback onMapPick,
    VoidCallback? onMyLocationPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  prefixIcon: Icon(icon, color: iconColor, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onMyLocationPick != null)
                        IconButton(
                          icon: Icon(
                            Icons.my_location_rounded,
                            color: iconColor.withValues(alpha: 0.8),
                            size: 20,
                          ),
                          tooltip: 'Current Location',
                          onPressed: onMyLocationPick,
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.map_rounded,
                          color: iconColor.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        tooltip: 'Pick on map',
                        onPressed: onMapPick,
                      ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        if (showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 140),
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = suggestions[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: iconColor,
                    size: 18,
                  ),
                  title: Text(
                    s.placeName,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelect(s),
                );
              },
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // STEP 2 — PACKAGE DETAILS
  // ═══════════════════════════════════════════
  Widget _buildStep2Package() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Package Type ──
          Text(
            'Package Type',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          _buildPackageTypeGrid().animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ── Package Count ──
          _buildPackageCount().animate().fadeIn(
            duration: 400.ms,
            delay: 100.ms,
          ),

          const SizedBox(height: 24),

          // ── Priority Selection ──
          Text(
            'Delivery Priority',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          _buildPrioritySelection().animate().fadeIn(
            duration: 400.ms,
            delay: 200.ms,
          ),

          const SizedBox(height: 24),

          // ── Extras ──
          Text(
            'Additional Services',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          _buildExtras().animate().fadeIn(duration: 400.ms, delay: 300.ms),

          const SizedBox(height: 24),

          // ── Recipient Info ──
          Text(
            'Recipient Info',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          _buildRecipientInfo().animate().fadeIn(
            duration: 400.ms,
            delay: 350.ms,
          ),

          const SizedBox(height: 24),

          // ── Notes ──
          Text(
            'Special Instructions',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          _buildNotesField().animate().fadeIn(duration: 400.ms, delay: 400.ms),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPackageTypeGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: PackageType.values.map((type) {
        final isSelected = _selectedPackage == type;
        return GestureDetector(
          onTap: () => setState(() => _selectedPackage = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: (MediaQuery.of(context).size.width - 52) / 3,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.cardLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.glassBorder,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type.brandAsset != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      type.brandAsset!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Icon(
                    type.icon,
                    color: isSelected ? AppColors.primary : AppColors.textHint,
                    size: 26,
                  ),
                const SizedBox(height: 8),
                Text(
                  type.label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  type.description,
                  style: TextStyle(color: AppColors.textHint, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPackageCount() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: AppColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Number of Packages',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          // Stepper
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: _packageCount > 1
                      ? () => setState(() => _packageCount--)
                      : null,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
                Container(
                  width: 36,
                  alignment: Alignment.center,
                  child: Text(
                    '$_packageCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: _packageCount < 20
                      ? () => setState(() => _packageCount++)
                      : null,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritySelection() {
    return Column(
      children: ShipmentPriority.values.map((priority) {
        final isSelected = _selectedPriority == priority;
        return GestureDetector(
          onTap: () => setState(() => _selectedPriority = priority),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.cardLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.glassBorder,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    priority.icon,
                    color: isSelected ? AppColors.primary : AppColors.textHint,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        priority.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        priority.description,
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${priority.multiplier}x',
                  style: TextStyle(
                    color: isSelected ? AppColors.accent : AppColors.textHint,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textHint,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExtras() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        children: [
          _buildToggleOption(
            icon: Icons.draw_rounded,
            title: 'Require Signature',
            subtitle: 'Recipient must sign on delivery (+EGP 250)',
            value: _requireSignature,
            onChanged: (v) => setState(() => _requireSignature = v),
          ),
          const Divider(height: 1),
          _buildToggleOption(
            icon: Icons.shield_outlined,
            title: 'Shipping Insurance',
            subtitle: 'Cover loss or damage up to EGP 50,000 (+EGP 750)',
            value: _insuranceEnabled,
            onChanged: (v) => setState(() => _insuranceEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _recipientNameController,
            decoration: const InputDecoration(
              labelText: 'Recipient Name',
              hintText: 'Who receives the package?',
              prefixIcon: Icon(Icons.person_outline, size: 20),
              filled: false,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _recipientPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Recipient Phone',
              hintText: '+20 xxx xxx xxxx',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
              filled: false,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: const InputDecoration(
        hintText: 'E.g., Leave at the front door, call before arrival...',
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: 40),
          child: Icon(Icons.notes_rounded, color: AppColors.textHint, size: 20),
        ),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  // ═══════════════════════════════════════════
  // STEP 3 — REVIEW & CONFIRM
  // ═══════════════════════════════════════════
  Widget _buildStep3Review() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Route Summary ──
          _buildReviewSection(
            'Route',
            Icons.route_rounded,
            Column(
              children: [
                _buildReviewRow(
                  Icons.circle,
                  AppColors.success,
                  'Pickup',
                  _origin?.address ?? 'Not set',
                ),
                const SizedBox(height: 10),
                _buildReviewRow(
                  Icons.location_on,
                  AppColors.error,
                  'Drop-off',
                  _destination?.address ?? 'Not set',
                ),
                if (_routeInfo != null) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _reviewInfoChip(
                        Icons.straighten_rounded,
                        _formatDistance(_routeInfo!.distanceMeters),
                      ),
                      _reviewInfoChip(
                        Icons.timer_outlined,
                        _formatDuration(_routeInfo!.durationSeconds),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 16),

          // ── Package Summary ──
          _buildReviewSection(
            'Package',
            Icons.inventory_2_outlined,
            Column(
              children: [
                _buildReviewDetail('Type', _selectedPackage.label),
                _buildReviewDetail('Quantity', '$_packageCount'),
                _buildReviewDetail(
                  'Weight Range',
                  _selectedPackage.description,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

          const SizedBox(height: 16),

          // ── Delivery Summary ──
          _buildReviewSection(
            'Delivery',
            Icons.local_shipping_rounded,
            Column(
              children: [
                _buildReviewDetail('Priority', _selectedPriority.label),
                _buildReviewDetail('ETA', _selectedPriority.description),
                if (_requireSignature)
                  _buildReviewDetail('Signature', 'Required'),
                if (_insuranceEnabled)
                  _buildReviewDetail('Insurance', 'Enabled'),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          if (_recipientNameController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildReviewSection(
              'Recipient',
              Icons.person_outline,
              Column(
                children: [
                  _buildReviewDetail('Name', _recipientNameController.text),
                  if (_recipientPhoneController.text.isNotEmpty)
                    _buildReviewDetail('Phone', _recipientPhoneController.text),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
          ],

          const SizedBox(height: 20),

          // ── Cost Breakdown ──
          Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      AppColors.accent.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Total',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'EGP ${_estimatedCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedPriority.label.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 300.ms)
              .shimmer(
                duration: 2000.ms,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  Widget _buildReviewRow(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.textHint, fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewInfoChip(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // BOTTOM BAR
  // ═══════════════════════════════════════════
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: const Border(
          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.glassBorder),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : _currentStep == 2
                  ? _handleSubmit
                  : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep == 2
                    ? AppColors.primary
                    : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentStep == 2
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentStep == 2 ? 'Confirm & Ship' : 'Continue',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
