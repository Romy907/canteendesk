import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MenuService {
  DatabaseReference? _menuRef;
  bool _isInitialized = false;
  
  // Initialize the service - must be called before using any methods
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final String? createdAt = await getCreatedAt();
      if (createdAt == null || createdAt.isEmpty) {
        throw Exception('createdAt is null or empty');
      }
      
      _menuRef = FirebaseDatabase.instance.ref().child(createdAt).child('menu');
      _isInitialized = true;
      print('MenuService initialized successfully with path: ${createdAt}/menu');
    } catch (e) {
      print('Error initializing MenuService: $e');
      throw Exception('Failed to initialize MenuService: $e');
    }
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
    if (!_isInitialized || _menuRef == null) {
      throw Exception('MenuService not initialized. Call initialize() first.');
    }
  }
  
  // Get menu items stream for real-time updates
  Stream<DatabaseEvent> getMenuItemsStream() {
    _checkInitialization();
    return _menuRef!.onValue;
  }
  
  // Fetch menu items once
  Future<List<Map<String, dynamic>>> fetchMenuItems() async {
    _checkInitialization();
    
    try {
      DatabaseEvent event = await _menuRef!.once();
      
      List<Map<String, dynamic>> items = [];
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> values = event.snapshot.value as Map<dynamic, dynamic>;
        values.forEach((key, value) {
          Map<String, dynamic> item = Map<String, dynamic>.from(value);
          item['id'] = key;
          items.add(item);
        });
      }
      
      return items;
    } catch (e) {
      print('Error fetching menu items: $e');
      return [];
    }
  }
  
  // Add a new menu item
  Future<void> addMenuItem(Map<String, dynamic> item, String currentDate, String userLogin) async {
    _checkInitialization();
    
    DatabaseReference newItemRef = _menuRef!.push();
    return newItemRef.set({
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
      'image': item['image'] ?? '',
      'lastUpdated': currentDate,
      'updatedBy': userLogin
    });
  }
  
  // Update existing menu item
  Future<void> updateMenuItem(String id, Map<String, dynamic> item, String currentDate, String userLogin) async {
    _checkInitialization();
    
    return _menuRef!.child(id).update({
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
      'updatedBy': userLogin
    });
  }
  
  // Delete menu item
  Future<void> deleteMenuItem(String id) async {
    _checkInitialization();
    return _menuRef!.child(id).remove();
  }
  
  // Toggle item availability
  Future<void> toggleItemAvailability(String id, bool newStatus, String currentDate, String userLogin) async {
    _checkInitialization();
    return _menuRef!.child(id).update({
      'available': newStatus,
      'lastUpdated': currentDate,
      'updatedBy': userLogin
    });
  }
}