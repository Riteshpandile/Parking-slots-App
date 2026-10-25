import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parkingapp/Features/parking/models/vehiclez_model.dart';
import 'package:parkingapp/Features/parking/providers/parking_responsitory.dart';
import 'package:parkingapp/Models/auth_respository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';




final authRepositoryProvider = Provider<AuthRespository>((ref) {
  return AuthRespository(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  return ParkingRespository(FirebaseFirestore.instance);
});

final parkingSlotsProvider = StreamProvider<List<ParkingSlot>>((ref) { return ref.watch(parkingRepositoryProvider).watchslots();
});


