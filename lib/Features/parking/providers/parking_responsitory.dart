import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parkingapp/Features/parking/models/vehiclez_model.dart';

class ParkingRespository {
  final FirebaseFirestore db;
  ParkingRespository(this.db);
  CollectionReference <Map<String, dynamic>> get _slots => db.collection('parkingSlots');
  CollectionReference <Map<String, dynamic>> get _activevehicles => db.collection('activeVehicles');
  CollectionReference <Map<String, dynamic>> get _transactions => db.collection('parkingTransactions');

  static const Map<String, VehicleType> 
    initialSlots {
    'A1': VehicleType.CAR;
    'A2': VehicleType.CAR;
    'B1': VehicleType.BIKE,
    'B2': VehicleType.BIKE,
    'C1' : VehicleType.EV,  
  }


} 