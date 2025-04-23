import 'dart:convert';
import 'package:canteendesk/API/Cred.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseManager {
  final String apiKey =
      Cred.FIREBASE_WEB_API_KEY; // Replace with your Firebase Web API Key
  final String databaseUrl = Cred.FIREBASE_DATABASE_URL; // No trailing slash

  Future<void> logout() async {
    try {
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

      String sanitizedEmail = email.replaceAll(RegExp(r'[.#\$\\[\\]]'), '');
      final url = Uri.parse('$databaseUrl/User/$sanitizedEmail.json');
      final response = await http.patch(url, body: jsonEncode(userData));

      if (response.statusCode == 200) {
        print('User data saved successfully');
      } else {
        print('Failed to save user data: ${response.body}');
      }
    } catch (e) {
      print('An error occurred while saving user data: $e');
    }
  }

  Future<void> addUniversityDetails(
      String universityName, String stores) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? email = prefs.getString('email');

      if (email == null) {
        print('No email found in SharedPreferences');
        return;
      }

      String sanitizedEmail = email.replaceAll(RegExp(r'[.#\$\\[\\]]'), '');
      final url = Uri.parse('$databaseUrl/User/$sanitizedEmail.json');
      final response = await http.patch(url,
          body: jsonEncode({
            'selectedUniversity': universityName,
            'stores': stores,
          }));

      if (response.statusCode == 200) {
        print('University details added successfully');
      } else {
        print('Failed to add university details: ${response.body}');
      }
    } catch (e) {
      print('An error occurred while adding university details: $e');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      email = email.trim();

      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        return {
          'status': 'error',
          'message': 'Please enter a valid email address',
        };
      }

      final url = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
      final response = await http.post(url,
          body: jsonEncode({
            'email': email,
            'password': password,
            'returnSecureToken': true,
          }));

      final responseData = jsonDecode(response.body);

      if (response.statusCode != 200) {
        return {
          'status': 'error',
          'message': responseData['error']['message'] ?? 'Login failed',
        };
      }
      print(responseData.toString());
      final idToken = responseData['idToken'];
      final localId = responseData['localId'];
      final sanitizedEmail = email.replaceAll(RegExp(r'[.#$\[\]]'), '');
      print(idToken);
      print(localId);
      print(sanitizedEmail);

      final dbUrl =
          Uri.parse('$databaseUrl/User/$sanitizedEmail.json?auth=$idToken');
      final dbResponse = await http.get(dbUrl);

      if (dbResponse.statusCode != 200) {
        return {
          'status': 'error',
          'message': 'Failed to fetch user data',
        };
      }

      final userData = jsonDecode(dbResponse.body);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      userData.forEach((key, value) async {
        await prefs.setString(key, value.toString());
      });
      prefs.setString("refreshToken", responseData['refreshToken']);
      prefs.setString('userId', localId);
      prefs.setString('idToken', idToken);

      await prefs.setString('email', email);

      final role = userData['role'];
      if (role == 'student') {
        await logout();
        return {
          'status': 'error',
          'message': 'Students are not allowed to log in',
        };
      }

      return {
        'status': 'success',
        'message': 'Login successful',
        'userId': localId,
        'role': role,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  Future<String?> refreshIdTokenAndSave() async {
    final prefs = await SharedPreferences.getInstance();

    // Get stored refresh token and timestamp
    final storedRefreshToken = prefs.getString('refreshToken');
    final lastRefreshTime = prefs.getInt('lastRefreshTime');

    if (storedRefreshToken == null) {
      print('No refresh token found');
      return null;
    }

    // Check if the token was refreshed within the last hour (3600 seconds)
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (lastRefreshTime != null && (currentTime - lastRefreshTime) < 3600000) {
      // Return the stored idToken if it's still valid
      final storedIdToken = prefs.getString('idToken');
      if (storedIdToken != null) {
        print('Using cached ID token');
        return storedIdToken;
      }
    }

    final url = Uri.parse(
        'https://securetoken.googleapis.com/v1/token?key=$apiKey');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': storedRefreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newIdToken = data['id_token'];
        final newRefreshToken = data['refresh_token'];

        // Save new refresh token, idToken, and last refresh time
        await prefs.setString('refreshToken', newRefreshToken);
        await prefs.setString('idToken', newIdToken);
        await prefs.setInt('lastRefreshTime', currentTime);

        print('Token refreshed successfully');
        return newIdToken;
      } else {
        print('Failed to refresh token: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error while refreshing token: $e');
      return null;
    }
  }
}
