import 'package:firebase_auth/firebase_auth.dart';

class AuthRespository {
  final FirebaseAuth _firebaseAuth;

  AuthRespository(this._firebaseAuth);

 Stream <User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

Future<UserCredential> signin({required String email, required String password}) async {
    return await _firebaseAuth.signInWithEmailAndPassword(email: email.trim(), password: password);
    
  }

  Future<UserCredential> register({required String email, required String password}) async {
    return await _firebaseAuth.createUserWithEmailAndPassword(email: email.trim(), password: password);
  }


}