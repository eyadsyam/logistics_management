import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../../driver/domain/models/driver_model.dart';
import '../../../shipment/domain/models/shipment_model.dart';

/// Stream providers for admin
final allActiveShipmentsProvider = StreamProvider<List<ShipmentModel>>((ref) {
  return ref.read(shipmentRepositoryProvider).streamAllActiveShipments();
});

final onlineDriversProvider = StreamProvider<List<DriverModel>>((ref) {
  return ref.read(driverRepositoryProvider).streamOnlineDrivers();
});

/// Admin dashboard showing fleet overview, active shipments, and online drivers.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipmentsAsync = ref.watch(allActiveShipmentsProvider);
    final driversAsync = ref.watch(onlineDriversProvider);

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
              _buildHeader(context, ref).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // ── Stats Summary ──
              _buildStatsRow(context, shipmentsAsync, driversAsync)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 24),

              // ── Tab System ──
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: TabBar(
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textHint,
                          indicator: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: const [
                            Tab(text: 'LIVE SHIPMENTS'),
                            Tab(text: 'ACTIVE FLEET'),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildShipmentsList(context, shipmentsAsync),
                            _buildDriversList(context, driversAsync),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EDITA FMCG NETWORK',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '26 Hubs | 27 Govs | 1,191 Vehicles',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    AsyncValue<List<ShipmentModel>> shipmentsAsync,
    AsyncValue<List<DriverModel>> driversAsync,
  ) {
    final activeCount = shipmentsAsync.valueOrNull?.length ?? 0;
    final driversCount = driversAsync.valueOrNull?.length ?? 0;
    final inTransitCount =
        shipmentsAsync.valueOrNull
            ?.where((sh) => sh.status == AppConstants.statusInProgress)
            .length ??
        0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _AdminStatItem(
              label: 'PENDING',
              value: '$activeCount',
              color: AppColors.accent,
              icon: Icons.hourglass_empty_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AdminStatItem(
              label: 'TRANSIT',
              value: '$inTransitCount',
              color: AppColors.primary,
              icon: Icons.moving_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AdminStatItem(
              label: 'DRIVERS',
              value: '$driversCount',
              color: AppColors.success,
              icon: Icons.people_alt_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentsList(
    BuildContext context,
    AsyncValue<List<ShipmentModel>> shipmentsAsync,
  ) {
    return shipmentsAsync.when(
      data: (shipments) {
        if (shipments.isEmpty) {
          return _buildEmptyState(context, 'No active shipments currently');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: shipments.length,
          itemBuilder: (context, index) {
            return _AdminShipmentCard(
              shipment: shipments[index],
            ).animate().slideX(
              begin: 0.1,
              duration: 300.ms,
              delay: Duration(milliseconds: 50 * index),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildDriversList(
    BuildContext context,
    AsyncValue<List<DriverModel>> driversAsync,
  ) {
    return driversAsync.when(
      data: (drivers) {
        if (drivers.isEmpty) {
          return _buildEmptyState(context, 'No drivers are currently online');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            return _AdminDriverCard(driver: drivers[index]).animate().slideX(
              begin: 0.1,
              duration: 300.ms,
              delay: Duration(milliseconds: 50 * index),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildEmptyState(BuildContext context, String title) {
    return Center(
      child: Opacity(
        opacity: 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_graph_rounded,
              size: 60,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _AdminStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _AdminStatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminShipmentCard extends StatelessWidget {
  final ShipmentModel shipment;
  const _AdminShipmentCard({required this.shipment});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getCol(shipment.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_shipping_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shipment.origin.address,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'To: ${shipment.destination.address}',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              shipment.status.split('_').last.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCol(String s) {
    if (s == AppConstants.statusInProgress) return AppColors.primary;
    if (s == AppConstants.statusAccepted) return AppColors.info;
    return AppColors.accent;
  }
}

class _AdminDriverCard extends StatelessWidget {
  final DriverModel driver;
  const _AdminDriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final bool isBusy = driver.currentShipmentId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  driver.phone,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isBusy ? AppColors.accent : AppColors.success)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isBusy ? 'ON TRIP' : 'AVAILABLE',
                  style: TextStyle(
                    color: isBusy ? AppColors.accent : AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
