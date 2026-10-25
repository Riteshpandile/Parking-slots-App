import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parkingapp/Features/parking/models/vehiclez_model.dart';
import 'package:parkingapp/Features/parking/providers/parking_providers.dart';

// ignore: camel_case_types
typedef parkingScreen = ParkingScreen;

class ParkingScreen extends ConsumerStatefulWidget {
  const ParkingScreen({super.key});

  @override
  ConsumerState<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends ConsumerState<ParkingScreen> {
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(parkingRepositoryProvider).initializeSlotsIfEmpty();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to log out of the Smart Parking system?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isBusy = true);
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signOut();
    } catch (e) {
      _showMessage('Error logging out: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _parkVehicle([VehicleType? preselectedType]) async {
    if (_isBusy) return;

    final input = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) =>
          _ParkVehicleDialog(initialType: preselectedType ?? VehicleType.CAR),
    );

    if (input == null || !mounted || _isBusy) return;

    setState(() => _isBusy = true);
    try {
      final slotId = await ref
          .read(parkingRepositoryProvider)
          .parkVehicle(
            numberPlate: input['number'] as String,
            vehicleType: input['type'] as VehicleType,
          );
      _showMessage('Vehicle ${input['number']} assigned to Slot $slotId');
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      _showMessage(message, isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _exitVehicle(ParkingSlot slot) async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Vehicle Exit'),
        content: Text(
          'Remove vehicle ${slot.numberPlate ?? 'in Slot ${slot.id}'} and generate final parking receipt?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Exit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final result = await ref
          .read(parkingRepositoryProvider)
          .exitVehicle(slot.id);
      if (!mounted) return;

      final duration = result['duration'] as Duration;
      final fee = result['fee'] as int;
      final vehicleNumber = result['vehicleNumber'] as String;
      final slotId = result['slotId'] as String;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Exit Receipt'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReceiptRow('Vehicle:', vehicleNumber, isBold: true),
                    const Divider(height: 16),
                    _buildReceiptRow('Slot ID:', slotId),
                    const SizedBox(height: 6),
                    _buildReceiptRow(
                      'Duration:',
                      formatParkingDuration(duration),
                    ),
                    const SizedBox(height: 6),
                    _buildReceiptRow(
                      'Pricing Rule:',
                      duration.inMinutes <= 30
                          ? 'First 30m (₹20)'
                          : '₹20 + ₹30/addl. hr',
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Fee:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹$fee',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Transaction successfully stored to Cloud Firebase.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      _showMessage('Vehicle $vehicleNumber exited. Fee: ₹$fee');
    } catch (e) {
      _showMessage('Error exiting vehicle: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _searchVehicle() async {
    final number = await showDialog<String>(
      context: context,
      builder: (context) => const _SearchVehicleDialog(),
    );

    if (number == null || number.isEmpty || !mounted || _isBusy) return;

    setState(() => _isBusy = true);
    try {
      final slot = await ref
          .read(parkingRepositoryProvider)
          .searchVehicle(number);
      if (!mounted) return;

      if (slot == null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Search Result'),
            content: Row(
              children: [
                const Icon(Icons.info, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No active parked vehicle found with number: $number',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        final duration = slot.currentDuration;
        final fee = slot.currentFee;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Vehicle Found'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReceiptRow(
                  'Vehicle Number:',
                  slot.numberPlate ?? number,
                  isBold: true,
                ),
                const Divider(height: 16),
                _buildReceiptRow('Assigned Slot:', slot.id),
                const SizedBox(height: 6),
                _buildReceiptRow('Slot Type:', slot.slotType.displayName),
                const SizedBox(height: 6),
                _buildReceiptRow(
                  'Vehicle Type:',
                  slot.vehicleType?.displayName ?? slot.slotType.displayName,
                ),
                const SizedBox(height: 6),
                _buildReceiptRow(
                  'Parked Duration:',
                  formatParkingDuration(duration),
                ),
                const SizedBox(height: 6),
                _buildReceiptRow('Live Fee:', '₹$fee'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showMessage('Error searching vehicle: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Part B.1 — Fetch snapshot from simulated gate sensor API
  Future<void> _syncGateSensorApi() async {
    final isSyncing = ref.read(isSyncingSensorProvider);
    if (isSyncing || _isBusy) {
      _showMessage('Sync already in progress. Please wait.');
      return;
    }

    ref.read(isSyncingSensorProvider.notifier).setSyncing(true);
    _showMessage('Connecting to Real-Time Gate Sensor API...');

    try {
      final api = ref.read(parkingApiProvider);
      final snapshot = await api.getParkingSnapshot();

      // Persist snapshot to Firestore and update UI
      await ref.read(parkingRepositoryProvider).syncSnapshot(snapshot);
      _showMessage('Sensor snapshot synchronized successfully!');
    } catch (e) {
      _showMessage('Gate Sensor API error: $e', isError: true);
    } finally {
      if (mounted) {
        ref.read(isSyncingSensorProvider.notifier).setSyncing(false);
      }
    }
  }

  Future<void> _resetLot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Slots'),
        content: const Text(
          'Are you sure you want to reset all 5 slots to AVAILABLE?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isBusy = true);
      await ref.read(parkingRepositoryProvider).resetAllSlots();
      _showMessage('All slots reset to available.');
    } catch (e) {
      _showMessage('Error resetting slots: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  static Color _getSlotColor(VehicleType type) {
    switch (type) {
      case VehicleType.BIKE:
        return Colors.blue.shade700;
      case VehicleType.CAR:
        return Colors.deepPurple;
      case VehicleType.EV:
        return Colors.teal.shade700;
    }
  }

  static IconData _getVehicleIcon(VehicleType type) {
    switch (type) {
      case VehicleType.BIKE:
        return Icons.two_wheeler;
      case VehicleType.CAR:
        return Icons.directions_car;
      case VehicleType.EV:
        return Icons.electric_car;
    }
  }

  Widget _buildSummaryCard(int available, int total) {
    final occupied = total - available;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade800, Colors.deepPurple.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SMART PARKING SYSTEM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Available: $available / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatPill('Available', '$available', Colors.greenAccent),
              const SizedBox(width: 12),
              _buildStatPill('Occupied', '$occupied', Colors.amberAccent),
              const SizedBox(width: 12),
              _buildStatPill('Total', '$total', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsyncValue = ref.watch(parkingSlotsProvider);
    final isSyncingSensor = ref.watch(isSyncingSensorProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Smart Parking',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Search Vehicle',
            icon: const Icon(Icons.search),
            onPressed: _searchVehicle,
          ),
          IconButton(
            tooltip: 'Sync Gate Sensor API (Part B)',
            icon: isSyncingSensor
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.sensors),
            onPressed: isSyncingSensor ? null : _syncGateSensorApi,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'reset') {
                _resetLot();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('Reset All Slots'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          slotsAsyncValue.when(
            loading: () => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 12),
                  Text('Loading parking lot...'),
                ],
              ),
            ),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 54, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading parking slots: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(parkingSlotsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (slots) {
              final availableCount = slots.where((s) => !s.isOccupied).length;
              final totalCount = slots.length;

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(parkingSlotsProvider);
                  await Future<void>.delayed(const Duration(milliseconds: 300));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummaryCard(availableCount, totalCount),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Parking Slots',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${slots.length} Slots Total',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final slot in slots)
                      _SlotCard(
                        slot: slot,
                        onParkPressed: () => _parkVehicle(slot.slotType),
                        onExitPressed: () => _exitVehicle(slot),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          ),
          if (_isBusy)
            Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Park Vehicle'),
        onPressed: _isBusy ? null : () => _parkVehicle(),
      ),
    );
  }
}

/// A dedicated Slot Card displaying slot ID, type, status, vehicle info,
/// and live updating timer and fee for occupied slots (Requirement 6).
class _SlotCard extends StatelessWidget {
  final ParkingSlot slot;
  final VoidCallback onParkPressed;
  final VoidCallback onExitPressed;

  const _SlotCard({
    required this.slot,
    required this.onParkPressed,
    required this.onExitPressed,
  });

  Color _typeColor(VehicleType type) {
    switch (type) {
      case VehicleType.BIKE:
        return Colors.blue.shade700;
      case VehicleType.CAR:
        return Colors.deepPurple;
      case VehicleType.EV:
        return Colors.teal.shade700;
    }
  }

  IconData _typeIcon(VehicleType type) {
    switch (type) {
      case VehicleType.BIKE:
        return Icons.two_wheeler;
      case VehicleType.CAR:
        return Icons.directions_car;
      case VehicleType.EV:
        return Icons.electric_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOccupied = slot.isOccupied;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isOccupied ? Colors.amber.shade300 : Colors.green.shade200,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Slot ID, Slot Type Badge, and Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    slot.id,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _typeColor(slot.slotType).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _typeColor(slot.slotType).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _typeIcon(slot.slotType),
                        size: 14,
                        color: _typeColor(slot.slotType),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        slot.slotType.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _typeColor(slot.slotType),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOccupied
                        ? Colors.amber.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOccupied
                          ? Colors.amber.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOccupied ? Icons.lock : Icons.check_circle,
                        size: 13,
                        color: isOccupied
                            ? Colors.amber.shade900
                            : Colors.green.shade900,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        slot.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOccupied
                              ? Colors.amber.shade900
                              : Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Middle: Vehicle info & Live Timer OR Available Prompt
            if (isOccupied) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.pin,
                              size: 16,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              slot.numberPlate ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        if (slot.vehicleType != null)
                          Text(
                            'Vehicle: ${slot.vehicleType!.displayName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _typeColor(slot.vehicleType!),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Live Parking Timer & Fee Widget (Requirement 6)
                    _LiveSlotTimerWidget(startTime: slot.startTime),
                  ],
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Ready to accept ${slot.slotType == VehicleType.CAR ? "CAR or EV" : slot.slotType.displayName} vehicles',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bottom Action Button
            SizedBox(
              width: double.infinity,
              child: isOccupied
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Exit Vehicle (Calculate Fee)'),
                      onPressed: onExitPressed,
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.local_parking),
                      label: Text('Park Here (${slot.slotType.displayName})'),
                      onPressed: onParkPressed,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stateful widget that runs a 1-second periodic timer
/// to display live duration and dynamically recalculate parking fee.
/// Resources are properly disposed to prevent memory leaks (Requirement 6).
class _LiveSlotTimerWidget extends StatefulWidget {
  final DateTime? startTime;

  const _LiveSlotTimerWidget({required this.startTime});

  @override
  State<_LiveSlotTimerWidget> createState() => _LiveSlotTimerWidgetState();
}

class _LiveSlotTimerWidgetState extends State<_LiveSlotTimerWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = widget.startTime;
    if (startTime == null) {
      return const SizedBox.shrink();
    }

    final duration = DateTime.now().difference(startTime);
    final fee = calculateParkingFee(duration);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: Colors.deepPurple,
              ),
              const SizedBox(width: 6),
              Text(
                'Parked: ${formatParkingDuration(duration)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Text(
              'Fee: ₹$fee',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParkVehicleDialog extends StatefulWidget {
  final VehicleType initialType;

  const _ParkVehicleDialog({required this.initialType});

  @override
  State<_ParkVehicleDialog> createState() => _ParkVehicleDialogState();
}

class _ParkVehicleDialogState extends State<_ParkVehicleDialog> {
  String _numberPlate = '';
  late VehicleType _selectedType;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.local_parking, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Park a Vehicle'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter vehicle details to assign an optimal slot according to allocation rules.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Vehicle Number',
                  hintText: 'e.g. GJ01AB1234',
                  prefixIcon: const Icon(Icons.pin),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter vehicle number';
                  }
                  if (value.trim().length < 3) {
                    return 'Vehicle number is too short';
                  }
                  return null;
                },
                onChanged: (value) => _numberPlate = value,
                onSaved: (value) => _numberPlate = value ?? '',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<VehicleType>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Vehicle Type',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: VehicleType.values.map((VehicleType type) {
                  return DropdownMenuItem<VehicleType>(
                    value: type,
                    child: Row(
                      children: [
                        Icon(
                          _ParkingScreenState._getVehicleIcon(type),
                          size: 20,
                          color: _ParkingScreenState._getSlotColor(type),
                        ),
                        const SizedBox(width: 8),
                        Text(type.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (VehicleType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedType = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Allocation: Exact Match first, EV fallback to CAR slot if EV slot full, lowest slot number prioritized.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.pop(context, {
                'number': _numberPlate.trim().toUpperCase(),
                'type': _selectedType,
              });
            }
          },
          child: const Text('Park Vehicle'),
        ),
      ],
    );
  }
}

class _SearchVehicleDialog extends StatefulWidget {
  const _SearchVehicleDialog();

  @override
  State<_SearchVehicleDialog> createState() => _SearchVehicleDialogState();
}

class _SearchVehicleDialogState extends State<_SearchVehicleDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.search, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Search Vehicle'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Look up parked vehicle by license numberplate:',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          TextField(
            textCapitalization: TextCapitalization.characters,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Vehicle Number',
              hintText: 'e.g. GJ01AB1234',
              prefixIcon: const Icon(Icons.directions_car),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (val) => _searchQuery = val,
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                Navigator.pop(context, val.trim().toUpperCase());
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          onPressed: () =>
              Navigator.pop(context, _searchQuery.trim().toUpperCase()),
          child: const Text('Search'),
        ),
      ],
    );
  }
}
