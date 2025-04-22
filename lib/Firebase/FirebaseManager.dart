import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<void> logout() async {
    try {
      await _auth.signOut();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('User logged out successfully');
    } catch (e) {
      print('An error occurred during logout: $e');
    }
  }
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? email = prefs.getString('email');

      if (email == null) {
        print('No email found in SharedPreferences');
        return;
      }

      String sanitizedEmail = email.replaceAll(RegExp(r'[.#$[\]]'), '');
      DatabaseReference userRef = FirebaseDatabase.instance.ref().child('User').child(sanitizedEmail);

      await userRef.update(userData);

      print('User data saved successfully');
    } catch (e) {
      print('An error occurred while saving user data: $e');
    }
  }
  Future<void> addUniversityDetails(String universityName, String stores) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? email = prefs.getString('email');
      
      if (email == null) {
        print('No email found in SharedPreferences');
        return;
      }

      String sanitizedEmail = email.replaceAll(RegExp(r'[.#$[\]]'), '');
      DatabaseReference userRef = FirebaseDatabase.instance.ref().child('User').child(sanitizedEmail);

      await userRef.update({
        'selectedUniversity': universityName,
        'stores': stores,
      });

      print('University details added successfully');
    } catch (e) {
      print('An error occurred while adding university details: $e');
    }
  }
  Future<Map<String, dynamic>> login(String email, String password) async {
    print('Login attempt with email: $email');
    try {
      print('Login attempt with email: $email');
      email = email.trim(); 

      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        print('Invalid email address: $email');
        return {
          'status': 'error',
          'message': 'Please enter a valid email address',
        };
      }

      // Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Firebase authentication successful for user: ${userCredential.user?.uid}');

      // Sanitize email for Firebase Realtime Database
      String sanitizedEmail = email.replaceAll(RegExp(r'[.#$[\]]'), '');
      print('Sanitized email: $sanitizedEmail');

      // Fetch user data
      print('Fetching user data from database for user: ${userCredential.user?.uid}');
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref().child('User').child(sanitizedEmail);
      DataSnapshot snapshot = await userRef.get();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<dynamic, dynamic> userData = snapshot.value as Map<dynamic, dynamic>;
      userData.forEach((key, value) async {
        await prefs.setString(key, value.toString());
      });
      print('User data snapshot: ${snapshot.value}');

      if (snapshot.exists && snapshot.value != null) {
        print('User data found in database for user: ${userCredential.user?.uid}');
        return {
          'status': 'success',
          'message': 'Login successful',
          'userId': userCredential.user?.uid,
          'role': snapshot.child('role').value.toString(),
        };
      } else {
        print('No user data found in database for user: ${userCredential.user?.uid}');
        return {
          'status': 'error',
          'message': 'No user data found in database',
          'userId': userCredential.user?.uid,
        };
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'User not found';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else {
        errorMessage = 'Login failed: ${e.message}';
      }
      print('FirebaseAuthException: $errorMessage');
      return {
        'status': 'error',
        'message': errorMessage,
      };
    } catch (e) {
      print('An unexpected error occurred: $e');
      return {
        'status': 'error',
        'message': 'An unexpected error occurred: $e',
      };
    }
  }
 
}
