# Smart Parking Lot System

A robust, enterprise-grade Flutter application simulating a **Smart Parking Lot** with real-time Firebase Cloud Firestore persistence, Firebase Authentication, deterministic slot allocation rules, live timer & dynamic fee calculation, vehicle lookup, and simulated Gate Sensor API.

---

## 🏛️ Architecture & Project Structure

The project strictly follows a **Feature-First Layered Architecture** with distinct separation of concerns:

```
lib/
├── Apiservices/
│   └── parking_api.dart                 # Part B.1: Simulated Gate Sensor API & Mock implementation
├── Features/
│   ├── Auth/
│   │   └── screens/
│   │       └── login_screen.dart        # Firebase Auth Sign-In & Registration
│   └── parking/
│       ├── models/
│       │   └── vehiclez_model.dart      # ParkingSlot, VehicleType, ParkingTransaction, & Fee logic
│       ├── providers/
│       │   ├── parking_providers.dart   # Riverpod Providers (Auth, Slot Stream, Sensor Notifier)
│       │   └── parking_responsitory.dart# Data Repository with Firestore Transactions & Business Rules
│       └── screens/
│           └── parking_screen.dart      # Smart Parking UI, Live Timer, Receipt Dialogs, Search
├── Models/
│   └── auth_respository.dart            # Firebase Authentication Repository
├── firebase_options.dart                # Generated FlutterFire configuration
└── main.dart                            # App Entry point & Reactive Auth gate
```

### Key Libraries Used
- **`flutter_riverpod`**: State management, reactive streams, and DI across widgets and business logic.
- **`cloud_firestore`**: Real-time cloud persistence, offline cache, and ACID atomic transactions.
- **`firebase_auth`**: User authentication state management.
- **`uuid`**: Unique transaction identification.
- **`intl`**: Formatting date & time.

---

## 🅿️ Core Requirements & Business Logic

### 1. Parking Slots
5 initial slots pre-configured and auto-seeded:
| Slot ID | Slot Type | Status |
|:---:|:---:|:---:|
| **A1** | `BIKE` | AVAILABLE |
| **A2** | `BIKE` | AVAILABLE |
| **B1** | `CAR` | AVAILABLE |
| **B2** | `CAR` | AVAILABLE |
| **C1** | `EV` | AVAILABLE |

### 2. Slot Allocation Rules
Implemented in `ParkingRepository.parkVehicle`:
1. **Rule 1 — Exact Match**: Prioritizes slots matching the vehicle type (`BIKE` → `BIKE`, `CAR` → `CAR`, `EV` → `EV`).
2. **Rule 2 — EV Fallback**: If `EV` slot `C1` is occupied, an EV can fallback to an available `CAR` slot (`B1` or `B2`).
3. **Rule 3 — Lowest Slot Number**: When multiple matching slots are open, assigns the lowest slot ID (e.g. `B1` before `B2`).

### 3. Pricing Rule Interpretation
- **First 30 minutes**: ₹20
- **Every additional hour**: +₹30 per started hour
- **Breakdown**:
  - `0 – 30 mins` = **₹20**
  - `31 – 90 mins` = **₹50** (₹20 + 1 × ₹30)
  - `91 – 150 mins` = **₹80** (₹20 + 2 × ₹30)
  - `151 – 210 mins` = **₹110** (₹20 + 3 × ₹30)

Formula:
```dart
int calculateParkingFee(Duration duration) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds <= 30 * 60) return 20;
  final remainingSeconds = totalSeconds - (30 * 60);
  final additionalHours = (remainingSeconds / 3600.0).ceil();
  return 20 + (additionalHours * 30);
}
```

### 4. Live Parking Timer & Fee Calculation
Occupied slots display a live updating timer (`HH:mm:ss`) alongside real-time fee recalculation using `_LiveSlotTimerWidget`. Timers are bounded to widget lifecycle and disposed cleanly in `dispose()` to prevent memory leaks.

---

## 🚀 Part B — Advanced Architecture & Edge Cases

### 1. Simulated Real-Time Gate Sensor API
Implements the required interface:
```dart
abstract class ParkingApi {
  Future<List<ParkingSlot>> getParkingSnapshot();
}
```
Available via the top AppBar sensor icon (`Icons.sensors`). It features:
- Network latency simulation (2s delay).
- UI loading indicator.
- Error handling & toast feedback.
- Guarding against duplicate concurrent sync requests.
- Batch write into Firestore to synchronize UI state.

### 2. Concurrency & Race Condition Prevention
When multiple users attempt to park in the last remaining slot concurrently:
- Firestore atomic **`db.runTransaction`** is utilized.
- Both read and write operations are executed atomically.
- If two users attempt to allocate the same slot at the same time, Firestore aborts the second transaction and safely rejects the double booking with a friendly error.

### 3. Duplicate & Invalid Entry Handling
- Validates non-empty license plate numbers.
- Checks whether the vehicle is already parked in any occupied slot before assigning a new one.

### 4. Scalability for Large Datasets (100,000+ Records)
- Active slots are constrained to the current lot size.
- Vehicle search executes a targeted Firestore indexed query: `where('isOccupied', isEqualTo: true).where('vehicleNumber', isEqualTo: query).limit(1)`.
- Exit receipts write to a decoupled `parkingTransactions` history collection so active slot polling remains lightweight and snappy.

### 5. Offline Persistence
- Firestore's built-in offline caching automatically persists cached slot snapshots.
- UI gracefully handles network drops, displaying cached state and syncing once reconnected.

---

## 🧪 Testing

Run automated unit tests for fee calculation and duration formatting:
```bash
flutter test
```

Run static code analysis:
```bash
flutter analyze
```

---

## 🏃 Setup & Run Instructions

1. Ensure Flutter 3.x and Dart 3.x are installed.
2. Get dependencies:
   ```bash
   flutter pub get
   ```
3. Run on connected Android device or emulator:
   ```bash
   flutter run
   ```
