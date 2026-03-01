import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../driver/domain/models/driver_model.dart';
import '../../../shipment/domain/models/shipment_model.dart';
import '../../../shipment/domain/usecases/accept_shipment_usecase.dart';
import 'driver_trip_screen.dart';
import '../../../auth/presentation/screens/driver_profile_screen.dart';

enum ShipmentSortOption {
  dateNewest,
  dateOldest,
  distanceShortest,
  distanceLongest,
  priceHighest,
  priceLowest,
}

/// Driver stream provider
final driverStreamProvider = StreamProvider.family<DriverModel, String>((
  ref,
  driverId,
) {
  return ref.read(driverRepositoryProvider).streamDriver(driverId);
});

/// Pending shipments stream for driver acceptance
final pendingShipmentsStreamProvider = StreamProvider<List<ShipmentModel>>((
  ref,
) {
  return ref.read(shipmentRepositoryProvider).streamPendingShipments();
});

/// Returns distance in meters from driver's current position to a target location
final distanceFromDriverProvider =
    FutureProvider.family<double?, ShipmentLocation>((ref, target) async {
      final pos = await ref.read(locationServiceProvider).getCurrentPosition();
      if (pos == null) return null;
      return Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        target.latitude,
        target.longitude,
      );
    });

/// Driver home screen with online/offline toggle and shipment requests.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  ShipmentSortOption _sortOption = ShipmentSortOption.dateNewest;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final driverAsync = ref.watch(driverStreamProvider(currentUser.id));
    final pendingAsync = ref.watch(pendingShipmentsStreamProvider);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              _buildHeader(
                context,
                currentUser.name,
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 20),

              // ── Online/Offline Toggle ──
              driverAsync.when(
                data: (driver) => _buildStatusToggle(context, driver)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .slideY(begin: 0.1, end: 0),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),

              const SizedBox(height: 24),

              // ── Section Title ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nearby Shipments',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    Text(
                      'Refreshes live',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<ShipmentSortOption>(
                      icon: const Icon(
                        Icons.sort,
                        color: AppColors.textSecondary,
                      ),
                      onSelected: (ShipmentSortOption result) {
                        setState(() {
                          _sortOption = result;
                        });
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<ShipmentSortOption>>[
                            const PopupMenuItem<ShipmentSortOption>(
                              value: ShipmentSortOption.dateNewest,
                              child: Text('Date: Newest to Oldest'),
                            ),
                            const PopupMenuItem<ShipmentSortOption>(
                              value: ShipmentSortOption.dateOldest,
                              child: Text('Date: Oldest to Newest'),
                            ),
                            const PopupMenuItem<ShipmentSortOption>(
                              value: ShipmentSortOption.distanceShortest,
                              child: Text('Distance: Shortest to Longest'),
                            ),
                            const PopupMenuItem<ShipmentSortOption>(
                              value: ShipmentSortOption.distanceLongest,
                              child: Text('Distance: Longest to Shortest'),
                            ),
                            const PopupMenuItem<ShipmentSortOption>(
                              value: ShipmentSortOption.priceHighest,
                              child: Text('Price: Highest to Lowest'),
                            ),
                            const PopupMenuItem<ShipmentSortOption>(
                              value: ShipmentSortOption.priceLowest,
                              child: Text('Price: Lowest to Highest'),
                            ),
                          ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 12),

              // ── Shipment Requests ──
              Expanded(
                child: pendingAsync.when(
                  data: (shipments) {
                    if (shipments.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    // Apply sorting
                    final sortedShipments = List<ShipmentModel>.from(shipments);
                    sortedShipments.sort((a, b) {
                      switch (_sortOption) {
                        case ShipmentSortOption.dateNewest:
                          return b.createdAt?.compareTo(
                                a.createdAt ?? DateTime.now(),
                              ) ??
                              0;
                        case ShipmentSortOption.dateOldest:
                          return a.createdAt?.compareTo(
                                b.createdAt ?? DateTime.now(),
                              ) ??
                              0;
                        case ShipmentSortOption.distanceShortest:
                          return a.distanceMeters.compareTo(b.distanceMeters);
                        case ShipmentSortOption.distanceLongest:
                          return b.distanceMeters.compareTo(a.distanceMeters);
                        case ShipmentSortOption.priceHighest:
                          return b.price.compareTo(a.price);
                        case ShipmentSortOption.priceLowest:
                          return a.price.compareTo(b.price);
                      }
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: sortedShipments.length,
                      itemBuilder: (context, index) {
                        return _ShipmentRequestCard(
                              shipment: sortedShipments[index],
                              driverId: currentUser.id,
                              driverName: currentUser.name,
                            )
                            .animate()
                            .fadeIn(
                              duration: 300.ms,
                              delay: Duration(milliseconds: 100 * index),
                            )
                            .scale(begin: const Offset(0.95, 0.95));
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),

              // ── Active Trip Button (Only if has current shipment) ──
              driverAsync.whenOrNull(
                    data: (driver) {
                      if (driver.currentShipmentId != null) {
                        return _buildActiveTripOverlay(context, driver);
                      }
                      return null;
                    },
                  ) ??
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edita Driver',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(name, style: Theme.of(context).textTheme.displaySmall),
            ],
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DriverProfileScreen()),
              );
            },
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusToggle(BuildContext context, DriverModel driver) {
    final isOnline = driver.isOnline;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isOnline
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.glassBorder,
            width: 1,
          ),
          boxShadow: [
            if (isOnline)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isOnline
                        ? Icons.sensors_rounded
                        : Icons.sensors_off_rounded,
                    color: isOnline ? AppColors.primary : AppColors.textHint,
                    size: 24,
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 4,
                    top: 4,
                    child:
                        Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 1000.ms),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'You are Online' : 'You are Offline',
                    style: TextStyle(
                      color: isOnline ? AppColors.primary : AppColors.textHint,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    isOnline
                        ? 'Searching for loads nearby'
                        : 'Go online to start earning',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isOnline,
              activeColor: AppColors.primary,
              onChanged: (value) {
                ref
                    .read(driverRepositoryProvider)
                    .setOnlineStatus(driverId: driver.id, isOnline: value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripOverlay(BuildContext context, DriverModel driver) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DriverTripScreen(
                shipmentId: driver.currentShipmentId!,
                driverId: driver.id,
              ),
            ),
          );
        },
        child: Row(
          children: [
            const Icon(Icons.navigation_rounded, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Shipment Found',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Tap to continue delivery',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 400.ms);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.explore_outlined,
            size: 64,
            color: AppColors.textHint.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Quiet day on the road...',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _ShipmentRequestCard extends ConsumerWidget {
  final ShipmentModel shipment;
  final String driverId;
  final String driverName;

  const _ShipmentRequestCard({
    required this.shipment,
    required this.driverId,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _parsePriority(shipment.notes ?? ''),
              Consumer(
                builder: (context, childRef, _) {
                  final distanceAsync = childRef.watch(
                    distanceFromDriverProvider(shipment.origin),
                  );
                  return distanceAsync.when(
                    data: (distance) {
                      if (distance == null) {
                        return const Text(
                          'N/A',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }
                      return Text(
                        '${(distance / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                    loading: () => const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAddressRow(
            Icons.radio_button_checked_rounded,
            AppColors.success,
            shipment.origin.address,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 11),
            child: SizedBox(
              height: 16,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.glassBorder,
              ),
            ),
          ),
          _buildAddressRow(
            Icons.location_on_rounded,
            AppColors.error,
            shipment.destination.address,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'ID: REQUEST-8A',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _acceptShipment(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'ACCEPT LOAD',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, Color color, String address) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _parsePriority(String notes) {
    bool isExpress =
        notes.contains('Priority: Express') ||
        notes.contains('Priority: Same Day');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isExpress
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isExpress ? 'HIGH PRIORITY' : 'STANDARD',
        style: TextStyle(
          color: isExpress ? AppColors.error : AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Future<void> _acceptShipment(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(acceptShipmentUseCaseProvider)
        .call(
          AcceptShipmentParams(
            shipmentId: shipment.id,
            driverId: driverId,
            driverName: driverName,
          ),
        );

    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (shipment) {
        ref
            .read(driverRepositoryProvider)
            .updateCurrentShipment(driverId: driverId, shipmentId: shipment.id);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                DriverTripScreen(shipmentId: shipment.id, driverId: driverId),
          ),
        );
      },
    );
  }
}
