import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../app/providers/app_providers.dart';
import '../widgets/shipment_card.dart';
import 'client_home_screen.dart';

class ClientHistoryScreen extends ConsumerWidget {
  const ClientHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('User not signed in')));
    }

    final shipmentsAsync = ref.watch(clientShipmentsProvider(currentUser.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipment History'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade50,
      body: shipmentsAsync.when(
        data: (shipments) {
          final historyShipments = shipments.where((s) => s.isCleared).toList();

          if (historyShipments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: AppColors.textHint.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No history found.',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: historyShipments.length,
            itemBuilder: (context, index) {
              return ShipmentCard(shipment: historyShipments[index]);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
