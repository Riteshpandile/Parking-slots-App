



import 'package:cloud_firestore/cloud_firestore.dart';

enum VehicleType {
  CAR,
  BIKE,
  EV
}

class ParkingSlot {
  final String id;
  final String numberPlate;
   VehicleType? vehicleType;
   final DateTime? startTime;


  ParkingSlot({
    required this.id,
    required this.numberPlate,
     this.vehicleType,
     this.startTime,
  });
bool get isOccupied =>  numberPlate != null;
String get status => isOccupied ? 'Occupied' : 'Available';
factory ParkingSlot.fromFireStore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    if (data == null){
      throw Exception('Document data is null');
    }
    return ParkingSlot(
      id: doc.id,
      numberPlate: data['numberPlate'] ?? '',
      vehicleType: VehicleType.values.firstWhere((v) => v.name == '${data['type']}', orElse: () => throw Exception('Invalid vehicle type: ${data['type']}')),
      startTime: data['startTime'] != null ? DateTime.parse(data['startTime']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'numberPlate': numberPlate,
      'vehicleType': vehicleType?.toString().split('.').last,
      'startTime': startTime,
    };
  } 


}