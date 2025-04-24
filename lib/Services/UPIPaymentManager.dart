import 'dart:convert';
import 'package:canteendesk/Manager/ManagerPayment.dart';
import 'package:http/http.dart' as http;

class UPIPaymentManager {
  final String baseUrl;
  final String idToken;
  final String storeId;

  UPIPaymentManager({
    required this.baseUrl,
    required this.idToken,
    required this.storeId,
  });

  // Add a new UPI account
  Future<void> addUPIAccount(UPIDetails account) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$storeId/upi_accounts/${account.id}.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(account.toMap()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add UPI account. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to add UPI account: $e');
    }
  }

  // Update an existing UPI account
  Future<void> updateUPIAccount(UPIDetails account) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$storeId/upi_accounts/${account.id}.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(account.toMap()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update UPI account. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update UPI account: $e');
    }
  }

  // Delete a UPI account
  Future<void> deleteUPIAccount(String accountId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$storeId/upi_accounts/$accountId.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete UPI account. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete UPI account: $e');
    }
  }

  // Update account status (active/inactive)
  Future<void> updateUPIAccountStatus(String accountId, bool isActive) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$storeId/upi_accounts/$accountId.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isActive': isActive}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update UPI account status. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update UPI account status: $e');
    }
  }

  // Set primary UPI account (updates all accounts)
  Future<void> setPrimaryUPIAccount(String primaryAccountId, List<UPIDetails> allAccounts) async {
    try {
      // Create a map of updates for all accounts
      final Map<String, dynamic> updates = {};
      
      for (var account in allAccounts) {
        final bool isPrimary = account.id == primaryAccountId;
        updates['upi_accounts/${account.id}/isPrimary'] = isPrimary;
      }
      
      // Make a single update call with all changes
      final response = await http.patch(
        Uri.parse('$baseUrl/$storeId.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update primary UPI account. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update primary UPI account: $e');
    }
  }

  // Update global UPI setting
  Future<void> updateAcceptUPI(bool acceptUPI) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$storeId/payment_settings.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accept_upi': acceptUPI}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update UPI settings. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update UPI settings: $e');
    }
  }

  // Load UPI accounts
  Future<List<UPIDetails>> loadUPIAccounts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$storeId/upi_accounts.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load UPI accounts. Status code: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>?;
      
      if (data == null) {
        return [];
      }
      
      List<UPIDetails> accounts = [];
      data.forEach((key, value) {
        accounts.add(UPIDetails.fromMap(Map<String, dynamic>.from(value)));
      });
      
      return accounts;
    } catch (e) {
      throw Exception('Failed to load UPI accounts: $e');
    }
  }

  // Load global UPI setting
  Future<bool> loadAcceptUPI() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$storeId/payment_settings/accept_upi.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load UPI settings. Status code: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      return data ?? true; // Default to true if not set
    } catch (e) {
      throw Exception('Failed to load UPI settings: $e');
    }
  }
}