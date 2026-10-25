import 'dart:async';
import 'package:parkingapp/Features/parking/models/vehiclez_model.dart';

/// Interface mirroring the interview requirement:
/// ```
/// interface ParkingApi {
///   suspend fun getParkingSnapshot(): List<ParkingSlot>
/// }
/// ```
abstract class ParkingApi {
  Future<List<ParkingSlot>> getParkingSnapshot();
}

/// Simulated Gate Sensor API implementation with network delay,
/// response simulation, and occasional fault tolerance simulation.
class MockGateSensorParkingApi implements ParkingApi {
  bool _shouldFailNext = false;

  void toggleFailureForTesting() {
    _shouldFailNext = !_shouldFailNext;
  }

  @override
  Future<List<ParkingSlot>> getParkingSnapshot() async {
    // Simulate real-world network latency (2 seconds)
    await Future.delayed(const Duration(seconds: 2));

    if (_shouldFailNext) {
      _shouldFailNext = false;
      throw Exception('Gate sensor connectivity timeout. Please retry.');
    }

    final now = DateTime.now();

    // Return a realistic snapshot from the physical lot sensors
    return [
      ParkingSlot(
        id: 'A1',
        slotType: VehicleType.BIKE,
        isOccupied: false,
      ),
      ParkingSlot(
        id: 'A2',
        slotType: VehicleType.BIKE,
        isOccupied: true,
        numberPlate: 'MH12AB1234',
        vehicleType: VehicleType.BIKE,
        startTime: now.subtract(const Duration(minutes: 25)),
      ),
      ParkingSlot(
        id: 'B1',
        slotType: VehicleType.CAR,
        isOccupied: false,
      ),
      ParkingSlot(
        id: 'B2',
        slotType: VehicleType.CAR,
        isOccupied: true,
        numberPlate: 'GJ01AB1234',
        vehicleType: VehicleType.CAR,
        startTime: now.subtract(const Duration(hours: 1, minutes: 42, seconds: 15)),
      ),
      ParkingSlot(
        id: 'C1',
        slotType: VehicleType.EV,
        isOccupied: false,
      ),
    ];
  }
}
