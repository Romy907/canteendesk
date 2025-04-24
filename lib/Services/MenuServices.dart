import 'dart:async';
import 'dart:convert';
import 'package:canteendesk/Firebase/FirebaseManager.dart';
import 'package:canteendesk/Services/ImgBBService.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canteendesk/API/Cred.dart';
class MenuService {
  String baseUrl = Cred.FIREBASE_DATABASE_URL;

  String? _storeId;
  bool _isInitialized = false;

  // For simulating real-time updates with polling
  Timer? _pollingTimer;
  final StreamController<List<Map<String, dynamic>>> _menuStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // Initialize the service - must be called before using any methods
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final String? createdAt = await getCreatedAt();
      if (createdAt == null || createdAt.isEmpty) {
        throw Exception('createdAt is null or empty');
      }

      _storeId = createdAt;
      _isInitialized = true;
      print('MenuService initialized successfully with storeId: $_storeId');

      // Start polling for real-time updates
      _startPolling();
    } catch (e) {
      print('Error initializing MenuService: $e');
      throw Exception('Failed to initialize MenuService: $e');
    }
  }

  // Start polling for real-time updates
  void _startPolling() {
    // Poll every 30 seconds (adjust as needed)
    _pollingTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_isInitialized) {
        try {
          final items = await fetchMenuItems();
          _menuStreamController.add(items);
        } catch (e) {
          print('Error during polling: $e');
        }
      }
    });

    // Immediately fetch data once
    fetchMenuItems().then((items) {
      _menuStreamController.add(items);
    }).catchError((error) {
      print('Initial fetch error: $error');
    });
  }

  Future<String?> getCreatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final createdAt = prefs.getString('createdAt');
    print('Retrieved createdAt: $createdAt');
    return createdAt;
  }

  // Check if the service is initialized
  bool get isInitialized => _isInitialized;

  // Helper to ensure we're initialized
  void _checkInitialization() {
    if (!_isInitialized || _storeId == null) {
      throw Exception('MenuService not initialized. Call initialize() first.');
    }
  }

  // Get menu items stream for real-time updates
  Stream<List<Map<String, dynamic>>> getMenuItemsStream() {
    _checkInitialization();
    return _menuStreamController.stream;
  }

  // Fetch menu items once
  Future<List<Map<String, dynamic>>> fetchMenuItems() async {
    _checkInitialization();
    String? idToken = await FirebaseManager().refreshIdTokenAndSave();

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/$_storeId/menu.json?auth=$idToken'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Convert the Map into a List of Maps
        List<Map<String, dynamic>> dataList = data.entries.map((entry) {
          final id = entry.key;
          final valueMap = Map<String, dynamic>.from(entry.value);
          valueMap['id'] = id;
          return valueMap;
        }).toList();

        return dataList;
      } else {
        print('Error fetching menu items. Status code: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('catch error:');
      print('Error fetching menu items: $e');
      return [];
    }
  }

  // Add a new menu item
  Future<void> addMenuItem(
    Map<String, dynamic> item,
    String currentDate,
    String userLogin,
  ) async {
    _checkInitialization();
    String? idToken = await FirebaseManager().refreshIdTokenAndSave();
    final payload = {
      'name': item['name'],
      'price': item['price'],
      'category': item['category'],
      'preparationTime': item['preparationTime'] ?? '0',
      'ingredients': item['ingredients'] ?? '',
      'description': item['description'] ?? '',
      'available': item['available'] ?? true,
      'isVegetarian': item['isVegetarian'] ?? false,
      'isPopular': item['isPopular'] ?? false,
      'hasDiscount': item['hasDiscount'] ?? false,
      'discount': item['hasDiscount'] ? item['discount'] ?? '0' : '0',
      'image': item['image']?? '',
      'lastUpdated': currentDate,
      'updatedBy': userLogin,
    };

    final response = await http.post(
        Uri.parse('$baseUrl/$_storeId/menu.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload) // Add the missing payload
        );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to add menu item. Status code: ${response.statusCode}');
    }

    _refreshMenuItems();
  }

  Future<void> updateMenuItem(
    String id,
    Map<String, dynamic> item,
    String currentDate,
    String userLogin,
  ) async {
    _checkInitialization();
    String? idToken = await FirebaseManager().refreshIdTokenAndSave();
    final payload = {
      'name': item['name'],
      'price': item['price'],
      'category': item['category'],
      'preparationTime': item['preparationTime'] ?? '0',
      'description': item['description'] ?? '',
      'available': item['available'] ?? true,
      'isVegetarian': item['isVegetarian'] ?? false,
      'isPopular': item['isPopular'] ?? false,
      'hasDiscount': item['hasDiscount'] ?? false,
      'discount': item['hasDiscount'] ? item['discount'] ?? '0' : '0',
      'image': item['image'] ?? '',
      'lastUpdated': currentDate,
      'updatedBy': userLogin,
    };

    final response = await http.put(
        Uri.parse('$baseUrl/$_storeId/menu/$id.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload));

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to update menu item. Status code: ${response.statusCode}');
    }

    _refreshMenuItems();
  }

  Future<void> deleteMenuItem(String id) async {
    _checkInitialization();

    String? idToken = await FirebaseManager().refreshIdTokenAndSave();
    final response = await http
        .delete(Uri.parse('$baseUrl/$_storeId/menu/$id.json?auth=$idToken'));

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to delete menu item. Status code: ${response.statusCode}');
    }

    _refreshMenuItems();
  }

  Future<void> toggleItemAvailability(
    String id,
    bool newStatus,
    String currentDate,
    String userLogin,
  ) async {
    _checkInitialization();
    String? idToken = await FirebaseManager().refreshIdTokenAndSave();
    final payload = {
      'available': newStatus,
      'lastUpdated': currentDate,
      'updatedBy': userLogin,
    };

    final response = await http.patch(
        Uri.parse('$baseUrl/$_storeId/menu/$id.json?auth=$idToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload));

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to toggle item availability. Status code: ${response.statusCode}');
    }

    _refreshMenuItems();
  }

  // Helper to refresh the menu items in the stream
  Future<void> _refreshMenuItems() async {
    try {
      final items = await fetchMenuItems();
      _menuStreamController.add(items);
    } catch (e) {
      print('Error refreshing menu items: $e');
    }
  }

  // Dispose resources when done
  void dispose() {
    _pollingTimer?.cancel();
    _menuStreamController.close();
  }
}
