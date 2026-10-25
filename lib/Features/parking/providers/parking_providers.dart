import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parkingapp/Apiservices/parking_api.dart';
import 'package:parkingapp/Features/parking/models/vehiclez_model.dart';
import 'package:parkingapp/Features/parking/providers/parking_responsitory.dart';
import 'package:parkingapp/Models/auth_respository.dart';

final authRepositoryProvider = Provider<AuthRespository>((ref) {
  return AuthRespository(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  final repo = ParkingRepository(FirebaseFirestore.instance);
  repo.initializeSlotsIfEmpty();
  return repo;
});

final parkingSlotsProvider = StreamProvider<List<ParkingSlot>>((ref) {
  final repository = ref.watch(parkingRepositoryProvider);
  return repository.watchSlots();
});

final parkingApiProvider = Provider<ParkingApi>((ref) {
  return MockGateSensorParkingApi();
});

class SensorSyncNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setSyncing(bool value) => state = value;
}

final isSyncingSensorProvider =
    NotifierProvider<SensorSyncNotifier, bool>(SensorSyncNotifier.new);
