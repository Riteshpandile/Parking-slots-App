import 'package:flutter_test/flutter_test.dart';
import 'package:parkingapp/Features/parking/models/vehiclez_model.dart';

void main() {
  group('Parking Fee Calculation Tests', () {
    test('First 30 minutes fee should be ₹20', () {
      expect(calculateParkingFee(const Duration(minutes: 0)), 20);
      expect(calculateParkingFee(const Duration(minutes: 15)), 20);
      expect(calculateParkingFee(const Duration(minutes: 30)), 20);
    });

    test('31-90 minutes fee should be ₹50', () {
      expect(calculateParkingFee(const Duration(minutes: 31)), 50);
      expect(calculateParkingFee(const Duration(minutes: 60)), 50);
      expect(calculateParkingFee(const Duration(minutes: 90)), 50);
    });

    test('91-150 minutes fee should be ₹80', () {
      expect(calculateParkingFee(const Duration(minutes: 91)), 80);
      expect(calculateParkingFee(const Duration(minutes: 120)), 80);
      expect(calculateParkingFee(const Duration(minutes: 150)), 80);
    });

    test('151+ minutes fee continues +₹30 per hour', () {
      expect(calculateParkingFee(const Duration(minutes: 151)), 110);
      expect(calculateParkingFee(const Duration(minutes: 210)), 110);
      expect(calculateParkingFee(const Duration(minutes: 211)), 140);
    });

    test('Duration formatting works in HH:mm:ss format', () {
      expect(
        formatParkingDuration(const Duration(hours: 1, minutes: 42, seconds: 15)),
        '01:42:15',
      );
    });
  });
}
