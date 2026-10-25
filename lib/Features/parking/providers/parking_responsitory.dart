import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingRespository {
  final FirebaseFirestore db;
  ParkingRespository(this.db);
  CollectionReference <Map<String, dynamic>> get _slots => db.collection('parking_slots');
  

} 