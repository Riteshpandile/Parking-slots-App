// ignore_for_file: constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';

enum VehicleType {
  BIKE,
  CAR,
  EV;

  static VehicleType fromString(String? value) {
    if (value == null) return VehicleType.CAR;
    final normalized = value.trim().toUpperCase();
    if (normalized.contains('BIKE')) return VehicleType.BIKE;
    if (normalized.contains('EV')) return VehicleType.EV;
    return VehicleType.CAR;
  }

  String get displayName {
    switch (this) {
      case VehicleType.BIKE:
        return 'BIKE';
      case VehicleType.CAR:
        return 'CAR';
      case VehicleType.EV:
        return 'EV';
    }
  }
}

/// Calculates parking fee according to interview specifications:
/// - First 30 minutes: ₹20
/// - Every additional hour (or partial hour): ₹30
/// Examples:
/// - 0–30 mins = ₹20
/// - 31–90 mins = ₹50
/// - 91–150 mins = ₹80
int calculateParkingFee(Duration duration) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds <= 0) return 20;

  // First 30 minutes (0 to 1800 seconds) -> ₹20
  if (totalSeconds <= 30 * 60) {
    return 20;
  }

  // Any started hour after the first 30 minutes -> +₹30 per hour
  final remainingSeconds = totalSeconds - (30 * 60);
  final additionalHours = (remainingSeconds / 3600.0).ceil();
  return 20 + (additionalHours * 30);
}

/// Formats a Duration into HH:mm:ss format (e.g. 01:42:15)
String formatParkingDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

class ParkingSlot {
  final String id;
  final VehicleType slotType;
  final bool isOccupied;
  final String? numberPlate;
  final VehicleType? vehicleType;
  final DateTime? startTime;

  ParkingSlot({
    required this.id,
    required this.slotType,
    this.isOccupied = false,
    this.numberPlate,
    this.vehicleType,
    this.startTime,
  });

  String get status => isOccupied ? 'OCCUPIED' : 'AVAILABLE';

  Duration get currentDuration {
    if (startTime == null) return Duration.zero;
    return DateTime.now().difference(startTime!);
  }

  int get currentFee => calculateParkingFee(currentDuration);

  ParkingSlot copyWith({
    String? id,
    VehicleType? slotType,
    bool? isOccupied,
    String? numberPlate,
    VehicleType? vehicleType,
    DateTime? startTime,
  }) {
    return ParkingSlot(
      id: id ?? this.id,
      slotType: slotType ?? this.slotType,
      isOccupied: isOccupied ?? this.isOccupied,
      numberPlate: numberPlate ?? this.numberPlate,
      vehicleType: vehicleType ?? this.vehicleType,
      startTime: startTime ?? this.startTime,
    );
  }

  factory ParkingSlot.fromFireStore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final id = doc.id;

    // Slot type fallback based on id if not explicitly set
    final rawSlotType = data['slotType'] ?? data['type'];
    final slotType = rawSlotType != null
        ? VehicleType.fromString(rawSlotType.toString())
        : (id.startsWith('A')
            ? VehicleType.BIKE
            : id.startsWith('B')
                ? VehicleType.CAR
                : VehicleType.EV);

    final numPlate = (data['numberPlate'] ?? data['vehicleNumber']) as String?;
    final rawIsOccupied = data['isOccupied'];
    final isOccupied = rawIsOccupied is bool
        ? rawIsOccupied
        : (numPlate != null && numPlate.trim().isNotEmpty);

    DateTime? startTime;
    final rawStartTime = data['startTime'];
    if (rawStartTime is Timestamp) {
      startTime = rawStartTime.toDate();
    } else if (rawStartTime is String && rawStartTime.isNotEmpty) {
      startTime = DateTime.tryParse(rawStartTime);
    }

    final rawVehicleType = data['vehicleType'] ?? data['type'];
    final vehicleType = rawVehicleType != null
        ? VehicleType.fromString(rawVehicleType.toString())
        : null;

    return ParkingSlot(
      id: id,
      slotType: slotType,
      isOccupied: isOccupied,
      numberPlate: numPlate?.trim().isNotEmpty == true ? numPlate!.trim().toUpperCase() : null,
      vehicleType: isOccupied ? (vehicleType ?? slotType) : null,
      startTime: startTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'slotType': slotType.name,
      'isOccupied': isOccupied,
      'numberPlate': numberPlate,
      'vehicleNumber': numberPlate,
      'vehicleType': vehicleType?.name,
      'type': vehicleType?.name ?? slotType.name,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
    };
  }
}

class ParkingTransaction {
  final String id;
  final String vehicleNumber;
  final String slotId;
  final VehicleType vehicleType;
  final DateTime startTime;
  final DateTime exitTime;
  final Duration duration;
  final int fee;

  ParkingTransaction({
    required this.id,
    required this.vehicleNumber,
    required this.slotId,
    required this.vehicleType,
    required this.startTime,
    required this.exitTime,
    required this.duration,
    required this.fee,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleNumber': vehicleNumber,
      'slotId': slotId,
      'vehicleType': vehicleType.name,
      'startTime': Timestamp.fromDate(startTime),
      'exitTime': Timestamp.fromDate(exitTime),
      'durationMinutes': duration.inMinutes,
      'durationFormatted': formatParkingDuration(duration),
      'fee': fee,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ParkingTransaction.fromMap(Map<String, dynamic> map, String id) {
    final startTime = (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final exitTime = (map['exitTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final durationMinutes = map['durationMinutes'] as int? ?? exitTime.difference(startTime).inMinutes;

    return ParkingTransaction(
      id: id,
      vehicleNumber: map['vehicleNumber'] as String? ?? '',
      slotId: map['slotId'] as String? ?? '',
      vehicleType: VehicleType.fromString(map['vehicleType'] as String?),
      startTime: startTime,
      exitTime: exitTime,
      duration: Duration(minutes: durationMinutes),
      fee: map['fee'] as int? ?? 0,
    );
  }
}