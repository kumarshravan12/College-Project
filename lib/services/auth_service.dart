import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up
  Future<void> signUp(String email, String password, String name, String dob) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Save all details in Firebase backend (Firestore)
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email,
        'name': name,
        'dob': dob,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Sign out immediately so they have to manually log in
      await _auth.signOut();
      
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An unknown error occurred during sign up.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Sign In
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An unknown error occurred during sign in.';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email address.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Incorrect email or password. Please try again.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled. Please contact support.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Too many attempts. Please try again later.';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Error signing out: ${e.toString()}');
    }
  }

  // Get Current User
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An unknown error occurred.';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email address.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
