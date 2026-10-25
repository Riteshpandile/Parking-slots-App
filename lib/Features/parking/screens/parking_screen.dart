
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parkingapp/Features/parking/models/vehiclez_model.dart';
import 'package:parkingapp/Features/parking/providers/parking_providers.dart';

class parkingScreen extends ConsumerStatefulWidget {
  const parkingScreen({super.key});

  @override
  ConsumerState<parkingScreen> createState() => _parkingScreenState();
}

class _parkingScreenState extends ConsumerState<parkingScreen> {
   bool _isBusy = false;
   late TextEditingController numberPlateController;

 void _showmessage(String message) {
  if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

Future<void> _logout() async {
  final  configure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Logout'),
      content: const Text('Are you sure you want to log out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop( context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop( context, true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  if (configure == true || !mounted) return;
  try {
    setState(() {
      _isBusy = true;
    });
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signOut();
  } catch (e) {
    _showmessage('Error logging out: $e');
  } finally {
    if (mounted) {
      setState(() {
        _isBusy = false;
      });
    }
  } 
}

Future<void> _parkvehicle() async {
  final numberPlateController = TextEditingController();
  var selectType = VehicleType.Bike; // Default selection
  final formkey = GlobalKey<FormState>();
  final input = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState)  =>
      AlertDialog(
        title: const Text('Park Vehicle'),
        content: Form(
          key: formkey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: numberPlateController,
                decoration: const InputDecoration(labelText: 'Number Plate'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a number plate';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<VehicleType>(
                value: selectType,
                items: VehicleType.values.map((VehicleType type) {
                  return DropdownMenuItem<VehicleType>(
                    value: type,
                    child: Text(type.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (VehicleType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectType = newValue;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: 'Vehicle Type'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formkey.currentState!.validate()) {
                Navigator.pop(context, {
                  'number': numberPlateController.text.trim(),
                  'type': selectType,
                });
              }
            },
            child: const Text('Park'),
          ),
        ],
      ),
    ),
  );
  numberPlateController.dispose();
 if (input == null || !mounted || _isBusy) return;
 setState(() {
    _isBusy = true;
  });
  try {
   
final slotId = await ref. read(parkingRepositoryProvider).parkVehicle(input['number'] as String, input['type'] as VehicleType);
_showmessage('Vehicle parked successfully in slot $slotId');
  } catch (e) {
    _showmessage('Error parking vehicle: $e');
  } finally {
    if (mounted) {
      setState(() {
        _isBusy = false;
      });
    }
  }
} 


Future<void> _exitvehicle(ParkingSlot slot) async {
 if (_isBusy) return;
 final confirmed = await showDialog<bool>(
   context: context,
   builder: (context) => AlertDialog(
     title: const Text('Exit Vehicle'),
     content: const Text('Are you sure you want to exit this vehicle?'),
     actions: [
       TextButton(
         onPressed: () => Navigator.pop(context, false),
         child: const Text('No'),
       ),
       TextButton(
         onPressed: () => Navigator.pop(context, true),
         child: const Text('Yes'),
       ),
     ],
   ),
 );
 if (confirmed == true) {
   try {
     setState(() {
       _isBusy = true;
     });
    final result = await ref.read(parkingRepositoryProvider).exitVehicle(slot.id);
    if (!mounted) return;
    final duration = result['duration'] as Duration;
    final fee = result['fee'] as int;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parking Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vehicle: ${slot.numberPlate}\nDuration: ${duration.inMinutes} minutes\nFee: \$${fee}'),
const SizedBox(height: 20),
             Text('parking fee ${fee}', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),),
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
     _showmessage('Vehicle exited successfully');
   } catch (e) {
     _showmessage('Error exiting vehicle: $e');
   } finally {
     if (mounted) {
       setState(() {
         _isBusy = false;
       });
     }
   }
 }
}

Future<void> _searchvehicle() async {
final controller = TextEditingController();
final number = await showDialog<String>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Search Vehicle'),
    content: TextField(
      controller: controller,
      decoration: const InputDecoration(labelText: 'Enter Number Plate'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, null),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Search'),
      ),
    ],
  ),
);
 controller.dispose();
  if (number == null || number.isEmpty || _isBusy) return;
  try {
    final slot = await ref.read(parkingRepositoryProvider).searchVehicle(number);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
             slot == null ? 'Vehicle not found' : 'Vehicle found for number: ${number}'),
            Text('Type: ${slot.vehicleType.toString().split('.').last}'),
            Text('Slot ID: ${slot.id}'),
            Text('Parked At: ${slot.parkedAt}'),
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
  } catch (e) {
    _showmessage('Error searching vehicle: $e');
  }

}


Widget _buildSummaryCard(int available, int total) {
  final occupied = total - available;
    return Card(
      color: Colors.deepPurple,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parking Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Available Slots: $available', style: TextStyle(fontSize: 16, color: Colors.white)),
            Text('Total Slots: $total', style: TextStyle(fontSize: 16, color: Colors.white)),
            Text('Occupied Slots: $occupied', style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
 final slotsAsyncValue = ref.watch(parkingSlotsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text("Smart Parking"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchvehicle,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: slotsAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error loading parking slots: $error')),
        data: (slots) {
          final available = slots.where((s) => !s.isOccupied).length;
          if (slots.isEmpty) {
            return const Center(child: Text('No vehicles parked.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parkingSlotsProvider);
              await Future<void>.delayed(const Duration(milliseconds: 300));
            },
            child: ListView(
           padding:  EdgeInsets.all(12),
           children: [
            _buildSummaryCard(available, slots.length),
            const SizedBox(height: 12),
            Text('Parking Slots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final slot in slots)
              Card(
                child: ListTile(
                  title: Text('Slot ID: ${slot.id}'),
                  subtitle: Text('Vehicle: ${slot.numberPlate ?? 'Empty'}\nType: ${slot.vehicleType.toString().split('.').last}\nParked At: ${slot.startTime ?? 'N/A'}'),
                  trailing: slot.isOccupied
                      ? ElevatedButton(
                          onPressed: () => _exitvehicle(slot),
                          child: const Text('Exit'),
                        )
                      : ElevatedButton(
                          onPressed: _parkvehicle,
                          child: const Text('Park'),
                        ),
                ),
              ),

           ]
              
            ),
          );
        },
      
      ),
    );
  }
}
