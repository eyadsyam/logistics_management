import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../shipment/domain/models/shipment_model.dart';
import '../screens/shipment_tracking_screen.dart';

/// Reusable shipment card widget used by both Client and Admin.
class ShipmentCard extends ConsumerWidget {
  final ShipmentModel shipment;
  final bool isClient;

  const ShipmentCard({
    super.key,
    required this.shipment,
    this.isClient = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShipmentTrackingScreen(shipmentId: shipment.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row: Status + Time ──
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
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: shipment.status),
                  ],
                ),
                Text(
                  shipment.createdAt != null
                      ? DateFormat('MMM dd, HH:mm').format(shipment.createdAt!)
                      : '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Package Info Badges (Beyond MVP) ──
            if (shipment.notes != null && shipment.notes!.contains('|'))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _parseDetails(shipment.notes!),
                ),
              ),

            // ── Route ──
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppColors.glassBorder,
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shipment.origin.address,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        shipment.destination.address,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Footer: Distance + Action ──
            if (shipment.distanceMeters > 0 ||
                shipment.status == AppConstants.statusPending) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (shipment.distanceMeters > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.straighten_rounded,
                          color: AppColors.textHint,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(shipment.distanceMeters),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (shipment.durationSeconds > 0) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.timer_outlined,
                            color: AppColors.textHint,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(shipment.durationSeconds),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  // Cancel button for pending shipments (client only)
                  if (isClient && shipment.status == AppConstants.statusPending)
                    TextButton.icon(
                      onPressed: () => _cancelShipment(context, ref),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  if (shipment.status == AppConstants.statusInProgress)
                    const Icon(
                          Icons.navigation_rounded,
                          color: AppColors.primary,
                          size: 18,
                        )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 1200.ms),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancelShipment(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Shipment'),
        content: const Text('Are you sure you want to cancel this shipment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ref
          .read(cancelShipmentUseCaseProvider)
          .call(shipment.id);

      if (context.mounted) {
        result.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: AppColors.error,
            ),
          ),
          (_) => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shipment cancelled'),
              backgroundColor: AppColors.warning,
            ),
          ),
        );
      }
    }
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

  List<Widget> _parseDetails(String notes) {
    if (!notes.contains('|')) return [];
    final parts = notes.split('|').map((p) => p.trim()).toList();
    final widgets = <Widget>[];

    for (var part in parts) {
      if (part.startsWith('Package:')) {
        widgets.add(
          _DetailBadge(
            icon: Icons.inventory_2_outlined,
            label: part.replaceFirst('Package:', '').trim(),
            color: AppColors.textSecondary,
          ),
        );
      } else if (part.startsWith('Priority:')) {
        final label = part.replaceFirst('Priority:', '').trim();
        Color color = AppColors.primary;
        if (label.contains('Express')) color = AppColors.accent;
        if (label.contains('Same Day')) color = AppColors.error;

        widgets.add(
          _DetailBadge(
            icon: Icons.bolt_rounded,
            label: label.toUpperCase(),
            color: color,
          ),
        );
      }
    }
    return widgets;
  }
}

class _DetailBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    final label = _getStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusPending:
        return AppColors.statusPending;
      case AppConstants.statusAccepted:
        return AppColors.statusAccepted;
      case AppConstants.statusInProgress:
        return AppColors.statusInProgress;
      case AppConstants.statusCompleted:
        return AppColors.statusCompleted;
      case AppConstants.statusCancelled:
        return AppColors.statusCancelled;
      default:
        return AppColors.textHint;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case AppConstants.statusPending:
        return 'PENDING';
      case AppConstants.statusAccepted:
        return 'ACCEPTED';
      case AppConstants.statusInProgress:
        return 'IN PROGRESS';
      case AppConstants.statusCompleted:
        return 'COMPLETED';
      case AppConstants.statusCancelled:
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }
}
