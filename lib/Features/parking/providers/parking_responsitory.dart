import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parkingapp/Features/parking/models/vehiclez_model.dart';
import 'package:uuid/uuid.dart';

class ParkingRepository {
  final FirebaseFirestore db;
  ParkingRepository(this.db);

  CollectionReference<Map<String, dynamic>> get _slotsCollection =>
      db.collection('parkingSlots');
  CollectionReference<Map<String, dynamic>> get _transactionsCollection =>
      db.collection('parkingTransactions');

  static const Map<String, VehicleType> initialSlots = {
    'A1': VehicleType.BIKE,
    'A2': VehicleType.BIKE,
    'B1': VehicleType.CAR,
    'B2': VehicleType.CAR,
    'C1': VehicleType.EV,
  };

  /// Ensures initial 5 slots exist in Firestore.
  Future<void> initializeSlotsIfEmpty() async {
    try {
      final snapshot = await _slotsCollection.limit(1).get();
      if (snapshot.docs.isEmpty) {
        final batch = db.batch();
        initialSlots.forEach((slotId, type) {
          final docRef = _slotsCollection.doc(slotId);
          batch.set(docRef, {
            'id': slotId,
            'slotType': type.name,
            'type': type.name,
            'isOccupied': false,
            'numberPlate': null,
            'vehicleNumber': null,
            'vehicleType': null,
            'startTime': null,
          });
        });
        await batch.commit();
      }
    } catch (e) {
      // In offline mode or if permissions prevent initial check, slots will load from cache
    }
  }

  /// Streams real-time parking slots ordered by ID.
  Stream<List<ParkingSlot>> watchSlots() {
    return _slotsCollection.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        // Fallback default slots in memory if Firestore is empty / initializing
        return initialSlots.entries.map((e) {
          return ParkingSlot(
            id: e.key,
            slotType: e.value,
            isOccupied: false,
          );
        }).toList();
      }

      final slots = snapshot.docs.map((doc) => ParkingSlot.fromFireStore(doc)).toList();
      // Natural sort by Slot ID (A1, A2, B1, B2, C1)
      slots.sort((a, b) => a.id.compareTo(b.id));
      return slots;
    });
  }

  /// Parks a vehicle into the appropriate slot atomically.
  /// Handles Concurrency / Race Condition using Firestore transactions.
  Future<String> parkVehicle({
    required String numberPlate,
    required VehicleType vehicleType,
  }) async {
    final cleanPlate = numberPlate.trim().toUpperCase();
    if (cleanPlate.isEmpty) {
      throw Exception('Vehicle number cannot be empty.');
    }

    return await db.runTransaction<String>((transaction) async {
      // 1. Read all slot documents atomically
      final slotDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      final slotList = <ParkingSlot>[];

      for (final slotId in initialSlots.keys) {
        final docRef = _slotsCollection.doc(slotId);
        final docSnapshot = await transaction.get(docRef);
        slotDocs[slotId] = docSnapshot;

        if (docSnapshot.exists) {
          slotList.add(ParkingSlot.fromFireStore(docSnapshot));
        } else {
          slotList.add(
            ParkingSlot(
              id: slotId,
              slotType: initialSlots[slotId]!,
              isOccupied: false,
            ),
          );
        }
      }

      // Sort slots by ID ascending (A1, A2, B1, B2, C1) for Rule 3: lowest slot number
      slotList.sort((a, b) => a.id.compareTo(b.id));

      // 2. Check duplicate active parking (Edge case: Vehicle already parked)
      final alreadyParked = slotList.where(
        (slot) => slot.isOccupied && slot.numberPlate?.toUpperCase() == cleanPlate,
      );
      if (alreadyParked.isNotEmpty) {
        throw Exception(
          'Vehicle $cleanPlate is already parked in Slot ${alreadyParked.first.id}.',
        );
      }

      // 3. Apply Slot Allocation Rules:
      // Filter for available slots
      final availableSlots = slotList.where((slot) => !slot.isOccupied).toList();

      ParkingSlot? selectedSlot;

      // Rule 1 — Exact Match: Prefer a slot whose type exactly matches vehicle type
      final exactMatches = availableSlots
          .where((slot) => slot.slotType == vehicleType)
          .toList();

      if (exactMatches.isNotEmpty) {
        // Rule 3: Lowest slot number (list is pre-sorted)
        selectedSlot = exactMatches.first;
      } else if (vehicleType == VehicleType.EV) {
        // Rule 2 — EV Fallback: An EV can use a normal CAR slot if no EV slot is available
        final carSlots = availableSlots
            .where((slot) => slot.slotType == VehicleType.CAR)
            .toList();

        if (carSlots.isNotEmpty) {
          // Rule 3: Lowest slot number
          selectedSlot = carSlots.first;
        }
      }

      if (selectedSlot == null) {
        throw Exception(
          'No suitable parking slot available for ${vehicleType.displayName}.',
        );
      }

      // 4. Update the selected slot atomically in Firestore
      final targetRef = _slotsCollection.doc(selectedSlot.id);
      final now = DateTime.now();

      transaction.set(
        targetRef,
        {
          'id': selectedSlot.id,
          'slotType': selectedSlot.slotType.name,
          'type': selectedSlot.slotType.name,
          'isOccupied': true,
          'numberPlate': cleanPlate,
          'vehicleNumber': cleanPlate,
          'vehicleType': vehicleType.name,
          'startTime': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );

      return selectedSlot.id;
    });
  }

  /// Removes vehicle from slot atomically, calculates duration and fee,
  /// writes transaction record to history, and returns receipt data.
  Future<Map<String, dynamic>> exitVehicle(String slotId) async {
    return await db.runTransaction<Map<String, dynamic>>((transaction) async {
      final docRef = _slotsCollection.doc(slotId);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Slot $slotId not found.');
      }

      final slot = ParkingSlot.fromFireStore(snapshot);
      if (!slot.isOccupied || slot.startTime == null) {
        throw Exception('Slot $slotId is not occupied.');
      }

      final exitTime = DateTime.now();
      final duration = exitTime.difference(slot.startTime!);
      final fee = calculateParkingFee(duration);
      final vehicleNumber = slot.numberPlate ?? 'Unknown';
      final vehicleType = slot.vehicleType ?? slot.slotType;

      // Free the parking slot
      transaction.update(docRef, {
        'isOccupied': false,
        'numberPlate': null,
        'vehicleNumber': null,
        'vehicleType': null,
        'startTime': null,
      });

      // Persist transaction record in Firebase
      final transactionId = const Uuid().v4();
      final recordRef = _transactionsCollection.doc(transactionId);
      final record = ParkingTransaction(
        id: transactionId,
        vehicleNumber: vehicleNumber,
        slotId: slotId,
        vehicleType: vehicleType,
        startTime: slot.startTime!,
        exitTime: exitTime,
        duration: duration,
        fee: fee,
      );

      transaction.set(recordRef, record.toMap());

      return {
        'slotId': slotId,
        'vehicleNumber': vehicleNumber,
        'vehicleType': vehicleType,
        'startTime': slot.startTime!,
        'exitTime': exitTime,
        'duration': duration,
        'fee': fee,
      };
    });
  }

  /// Efficient query to search vehicle by number plate without scanning large datasets.
  Future<ParkingSlot?> searchVehicle(String numberPlate) async {
    final cleanPlate = numberPlate.trim().toUpperCase();
    if (cleanPlate.isEmpty) return null;

    try {
      // Query Firestore directly for occupied slot with matching vehicle number
      final querySnapshot = await _slotsCollection
          .where('isOccupied', isEqualTo: true)
          .where('vehicleNumber', isEqualTo: cleanPlate)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return ParkingSlot.fromFireStore(querySnapshot.docs.first);
      }

      // Also check fallback query on numberPlate field for compatibility
      final fallbackSnapshot = await _slotsCollection
          .where('isOccupied', isEqualTo: true)
          .where('numberPlate', isEqualTo: cleanPlate)
          .limit(1)
          .get();

      if (fallbackSnapshot.docs.isNotEmpty) {
        return ParkingSlot.fromFireStore(fallbackSnapshot.docs.first);
      }

      return null;
    } catch (e) {
      // In case composite index is missing or offline, fallback to reading active slots
      final allDocs = await _slotsCollection.get();
      for (final doc in allDocs.docs) {
        final slot = ParkingSlot.fromFireStore(doc);
        if (slot.isOccupied && slot.numberPlate?.toUpperCase() == cleanPlate) {
          return slot;
        }
      }
      return null;
    }
  }

  /// Sync snapshot from simulated gate sensor API (Part B.1)
  Future<void> syncSnapshot(List<ParkingSlot> snapshot) async {
    final batch = db.batch();
    for (final slot in snapshot) {
      final docRef = _slotsCollection.doc(slot.id);
      batch.set(docRef, slot.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Reset all slots to available state for demo/testing convenience
  Future<void> resetAllSlots() async {
    final batch = db.batch();
    initialSlots.forEach((slotId, type) {
      final docRef = _slotsCollection.doc(slotId);
      batch.set(docRef, {
        'id': slotId,
        'slotType': type.name,
        'type': type.name,
        'isOccupied': false,
        'numberPlate': null,
        'vehicleNumber': null,
        'vehicleType': null,
        'startTime': null,
      });
    });
    await batch.commit();
  }
}