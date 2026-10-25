import 'package:flutter/material.dart';
import 'package:parkingapp/Features/Auth/screens/login_screen.dart';
import 'package:parkingapp/Features/parking/screens/parking_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parkingapp/Features/parking/providers/parking_providers.dart';
import 'package:parkingapp/firebase_options.dart';


  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,



    );
    runApp(const ProviderScope(
      child: ParkingApp(),
    ));
}

class ParkingApp extends ConsumerWidget {
  const ParkingApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Parking App',
      theme: ThemeData(
     
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const parkingScreen();
          } else {
            return const loginScreen();
          }
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => Scaffold(
          body: Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}
