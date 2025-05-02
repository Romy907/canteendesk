import 'package:canteendesk/API/Cred.dart';
import 'package:canteendesk/Firebase/FirebaseManager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManagerHome extends StatefulWidget {
  const ManagerHome({Key? key}) : super(key: key);

  @override
  _ManagerHomeState createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome>
    with SingleTickerProviderStateMixin {
  // Animation controller
  late AnimationController _animationController;
  bool _isLoading = true;
  String _storeId = ''; // Initialize with default value
  String? errorMessage; // Variable to store error messages
  String _name = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Load store ID then fetch data
    _loadStoreId().then((_) {
      _fetchOrderData();
    });
  }

  Future<void> _loadStoreId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          // Use 'createAt' or 'createdAt' depending on what's in your SharedPreferences
          _storeId = prefs.getString('createAt') ?? prefs.getString('createdAt') ?? '';
          _name = prefs.getString('name') ?? '';
          print('Loaded store ID: $_storeId');
        });
      }
    } catch (e) {
      print('Error loading store ID: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load store ID: $e';
        });
      }
    }
  }

  // Date range selection
  String _selectedTimeRange = 'Today';
  final List<String> _timeRanges = [
    'All',
    'Today',
    'Yesterday',
    'This Week',
    'This Month'
  ];

  // Order status filter
  final List<String> orderStatuses = [
    'All',
    'Completed',
    'Pending',
    'Accepted',
    'Cancelled'
  ];
  String _selectedStatus = 'All';

  // Method to handle status filter changes
  void _updateOrderStatus(String status) {
    if (_selectedStatus != status) {
      setState(() {
        _selectedStatus = status;
        _isLoading = true;
      });
      
      // Filter data based on new status
      _fetchOrderData();
    }
  }

  // Method to handle date range filter changes
  void _updateDateRange(String range) {
    if (_selectedTimeRange != range) {
      setState(() {
        _selectedTimeRange = range;
        _isLoading = true;
      });
      
      // Fetch new data with updated time range
      _fetchOrderData();
    }
  }

  // Statistics data
  Map<String, dynamic> statistics = {
    'Total Orders': 0,
    'Completed': 0,
    'Pending': 0,
    'Revenue': 0
  };

  // Trend data (percentage change)
  Map<String, double> trends = {
    'Total Orders': 0.0,
    'Completed': 0.0,
    'Pending': 0.0,
    'Revenue': 0.0
  };

  // Chart data
  List<FlSpot> revenueSpots = [
    FlSpot(0, 0),
    FlSpot(1, 0),
    FlSpot(2, 0),
    FlSpot(3, 0),
    FlSpot(4, 0),
    FlSpot(5, 0),
    FlSpot(6, 0),
  ];

  List<FlSpot> ordersSpots = [
    FlSpot(0, 0),
    FlSpot(1, 0),
    FlSpot(2, 0),
    FlSpot(3, 0),
    FlSpot(4, 0),
    FlSpot(5, 0),
    FlSpot(6, 0),
  ];

  List<Map<String, dynamic>> popularItems = [];

  final List<String> categories = [
    'All',
    'Appetizers',
    'Main Course',
    'Fast Food',
    'Desserts',
    'Beverages'
  ];
  String _selectedCategory = 'All';

  // Selected index for navigation rail
  DateTime _currentDate = DateTime.now();

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Method to fetch orders from Firebase
  Future<void> _fetchOrderData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (_storeId.isEmpty) {
        print('Store ID is empty, using empty data');
        setState(() {
          statistics = _getEmptyData()['statistics'];
          trends = _getEmptyData()['trends'];
          revenueSpots = _getEmptyData()['revenueSpots'];
          ordersSpots = _getEmptyData()['ordersSpots'];
          popularItems = _getEmptyData()['popularItems'];
          _isLoading = false;
        });
        return;
      }
      
      final data = await fetchOrderDataFromFirebase(_selectedTimeRange, _storeId);
      
      if (!mounted) return;
      
      setState(() {
        statistics = data['statistics'];
        trends = data['trends'];
        revenueSpots = data['revenueSpots'];
        ordersSpots = data['ordersSpots'];
        popularItems = data['popularItems'];
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching order data: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        errorMessage = 'Failed to load order data: $e';
      });
    }
  }

  // Firebase data fetching and processing - UPDATED to match ManagerOrderList
  Future<Map<String, dynamic>> fetchOrderDataFromFirebase(
      String timeRange, String storeId) async {
    if (storeId.isEmpty) {
      return _getEmptyData(); // Return empty data if storeId is not available
    }
    
    try {
      // Using the same approach as ManagerOrderList
      final baseUrl = Cred.FIREBASE_DATABASE_URL;
      String? tokenId = await FirebaseManager().refreshIdTokenAndSave();
      // Updated to match path in ManagerOrderList ("orders" instead of "order")
      final ordersPath = '$storeId/orders.json?auth=$tokenId';
      print('Fetching orders from: $baseUrl$ordersPath');
      print('Store ID: $storeId');
      final response = await http.get(Uri.parse('$baseUrl/$ordersPath'));
      
      if (response.statusCode == 200) {
        // Parse JSON response
        print('Response received, length: ${response.body.length}');
        if (response.body == 'null') {
          print('No orders found (null response)');
          return _getEmptyData();
        }
        
        final Map<String, dynamic> ordersData = json.decode(response.body);
        if (ordersData.isEmpty) {
          print('No orders found (empty data)');
          return _getEmptyData();
        }
        
        return processOrderData(ordersData, timeRange);
      } else {
        print('Error response: ${response.statusCode}, ${response.body}');
        
        // Attempt to use alternate path as fallback
        final alternateOrdersPath = '$storeId/order.json';
        print('Attempting alternate path: $baseUrl$alternateOrdersPath');
        
        final altResponse = await http.get(Uri.parse('$baseUrl$alternateOrdersPath'));
        
        if (altResponse.statusCode == 200 && altResponse.body != 'null') {
          final Map<String, dynamic> ordersData = json.decode(altResponse.body);
          if (ordersData.isNotEmpty) {
            return processOrderData(ordersData, timeRange);
          }
        }
        
        throw Exception('Failed to load order data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchOrderDataFromFirebase: $e');
      throw Exception('Error fetching order data: $e');
    }
  }

  Map<String, dynamic> processOrderData(Map<String, dynamic>? ordersData, String timeRange) {
    if (ordersData == null || ordersData.isEmpty) {
      return _getEmptyData();
    }

    DateTime now = DateTime.now();
    DateTime startDate;
    
    // Determine start date based on selected time range
    switch (timeRange) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Yesterday':
        startDate = DateTime(now.year, now.month, now.day - 1);
        break;
      case 'This Week':
        // Start of the week (Monday)
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'All':
        // For "All", set a date far in the past
        startDate = DateTime(2000, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }
    
    // Initialize statistics
    int totalOrders = 0;
    int completedOrders = 0;
    int pendingOrders = 0;
    double totalRevenue = 0;
    
    // Map to track item popularity
    Map<String, int> itemSoldCount = {};
    Map<String, double> itemRevenue = {};
    Map<String, String> itemCategories = {};
    Map<String, String> itemImages = {};
    
    // Daily data for charts
    Map<int, double> dailyRevenue = {};
    Map<int, int> dailyOrders = {};
    
    // Process each order
    ordersData.forEach((orderId, orderData) {
      try {
        // Parse the timestamp - accounts for different formats
        if (!orderData.containsKey('timestamp')) return;
        
        DateTime orderDate;
        try {
          // Try parsing directly
          orderDate = DateTime.parse(orderData['timestamp']);
        } catch (e) {
          try {
            // Try replacing space with T for ISO format
            orderDate = DateTime.parse(orderData['timestamp'].replaceAll(' ', 'T'));
          } catch (e) {
            // Try extracting just the date part
            final parts = orderData['timestamp'].toString().split(' ');
            if (parts.length > 0) {
              try {
                orderDate = DateTime.parse(parts[0]);
              } catch (e) {
                print('Error parsing date for order $orderId: ${orderData['timestamp']}');
                return; // Skip this order if we can't parse the date
              }
            } else {
              print('Error parsing date for order $orderId: ${orderData['timestamp']}');
              return; // Skip this order if we can't parse the date
            }
          }
        }
        
        // Check if order falls within selected time range
        if (orderDate.isAfter(startDate) || orderDate.isAtSameMomentAs(startDate)) {
          // Get order status with a fallback to 'pending'
          final status = orderData.containsKey('status') 
              ? orderData['status'].toString().toLowerCase() 
              : 'pending';
              
          // Apply status filter (if not 'All')
          if (_selectedStatus != 'All' && 
              status.toLowerCase() != _selectedStatus.toLowerCase()) {
            return; // Skip this order if it doesn't match the status filter
          }
          
          totalOrders++;
          
          // Check order status
          if (status == 'completed') {
            completedOrders++;
          } else if (status == 'pending' || status == 'accepted' || status == 'confirmed' || status == 'ready') {
            pendingOrders++;
          }
          
          // Add to total revenue - handle different property names
          double amount = 0.0;
          if (orderData.containsKey('totalAmount')) {
            var totalAmountValue = orderData['totalAmount'];
            amount = _parseDouble(totalAmountValue);
          } else if (orderData.containsKey('total')) {
            var totalValue = orderData['total'];
            amount = _parseDouble(totalValue);
          }
          
          totalRevenue += amount;
          
          // Track daily stats for charts
          int dayOfRange = _getDayOfRange(orderDate, timeRange, startDate);
          dailyRevenue[dayOfRange] = (dailyRevenue[dayOfRange] ?? 0) + amount;
          dailyOrders[dayOfRange] = (dailyOrders[dayOfRange] ?? 0) + 1;
          
          // Process items for popularity
          if (orderData.containsKey('items')) {
            var items = orderData['items'];
            if (items is List) {
              for (var item in items) {
                if (item is Map) {
                  // Get item name with fallback
                  String itemName = '';
                  if (item.containsKey('name')) {
                    itemName = item['name'].toString();
                  } else {
                    continue; // Skip item without name
                  }
                  
                  // Filter by selected category if not 'All'
                  if (_selectedCategory != 'All' && 
                      item.containsKey('category') && 
                      item['category'].toString() != _selectedCategory) {
                    continue; // Skip item if category doesn't match
                  }
                  
                  // Get quantity with fallback to 1
                  int quantity = _parseQuantity(item);
                  
                  // Update item sold count
                  itemSoldCount[itemName] = (itemSoldCount[itemName] ?? 0) + quantity;
                  
                  // Get price with fallback to 0
                  double price = _parsePrice(item);
                  
                  // Calculate item revenue
                  double itemTotal = price * quantity;
                  itemRevenue[itemName] = (itemRevenue[itemName] ?? 0) + itemTotal;
                  
                  // Store category and image safely
                  if (item.containsKey('category')) {
                    itemCategories[itemName] = item['category'].toString();
                  } else {
                    itemCategories[itemName] = '';
                  }
                  
                  if (item.containsKey('image')) {
                    itemImages[itemName] = item['image'].toString();
                  } else {
                    itemImages[itemName] = '';
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        print('Error processing order $orderId: $e');
        // Continue with the next order
      }
    });
    
    // Calculate trends
    Map<String, double> calculatedTrends = _calculateTrends(totalOrders, completedOrders, pendingOrders, totalRevenue);
    
    // Create sorted list of popular items
    List<Map<String, dynamic>> popularItemsList = _createPopularItemsList(
      itemSoldCount, itemRevenue, itemCategories, itemImages, totalOrders);
    
    // Create chart data
    List<FlSpot> revenueSpotsList = _createChartSpots(dailyRevenue, timeRange);
    List<FlSpot> ordersSpotsList = _createChartSpots(dailyOrders.map((k, v) => MapEntry(k, v.toDouble())), timeRange);
    
    // Return processed data
    return {
      'statistics': {
        'Total Orders': totalOrders,
        'Completed': completedOrders,
        'Pending': pendingOrders,
        'Revenue': totalRevenue.round(),
      },
      'trends': calculatedTrends,
      'revenueSpots': revenueSpotsList,
      'ordersSpots': ordersSpotsList,
      'popularItems': popularItemsList,
    };
  }

  // Helper method to parse double values from various formats
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      // Remove currency symbols and commas
      String cleanValue = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleanValue) ?? 0.0;
    }
    return 0.0;
  }

  // Helper to parse quantity values
  int _parseQuantity(Map<dynamic, dynamic> item) {
    if (!item.containsKey('quantity')) return 1;
    
    var quantityValue = item['quantity'];
    if (quantityValue is int) {
      return quantityValue;
    } else if (quantityValue is num) {
      return quantityValue.toInt();
    } else if (quantityValue is String) {
      try {
        return int.parse(quantityValue);
      } catch (e) {
        // Default to 1 if parsing fails
      }
    }
    return 1;
  }

  // Helper to parse price values
  double _parsePrice(Map<dynamic, dynamic> item) {
    if (!item.containsKey('price')) return 0.0;
    
    var priceValue = item['price'];
    if (priceValue is double) {
      return priceValue;
    } else if (priceValue is int) {
      return priceValue.toDouble();
    } else if (priceValue is String) {
      try {
        // Remove currency symbols if present
        String cleanValue = priceValue.replaceAll(RegExp(r'[^\d.]'), '');
        return double.parse(cleanValue);
      } catch (e) {
        // Default to 0 if parsing fails
      }
    }
    return 0.0;
  }

  // Helper method to calculate trends
  Map<String, double> _calculateTrends(
      int totalOrders, int completedOrders, int pendingOrders, double revenue) {
    // In a real app, you would compare with previous periods
    // This is a simplified version for demonstration
    return {
      'Total Orders': totalOrders > 0 ? 5.2 : 0.0,
      'Completed': completedOrders > 0 ? 8.7 : 0.0,
      'Pending': pendingOrders > 0 ? -2.3 : 0.0,
      'Revenue': revenue > 0 ? 12.5 : 0.0,
    };
  }

  // Helper method to create popular items list
  List<Map<String, dynamic>> _createPopularItemsList(
      Map<String, int> itemSoldCount,
      Map<String, double> itemRevenue,
      Map<String, String> itemCategories,
      Map<String, String> itemImages,
      int totalOrders) {
    
    if (itemSoldCount.isEmpty) {
      return [];
    }
    
    List<MapEntry<String, int>> sortedItems = itemSoldCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedItems.take(sortedItems.length < 5 ? sortedItems.length : 5).map((entry) {
      String itemName = entry.key;
      double trend = totalOrders > 0 ? (entry.value / totalOrders) * 10 : 0.0;
      
      // Alternate between positive and negative trends for visual variety
      if (sortedItems.indexOf(entry) % 2 == 1) {
        trend = -trend;
      }
      
      return {
        "name": itemName,
        "sold": entry.value,
        "revenue": itemRevenue[itemName] ?? 0,
        "category": itemCategories[itemName] ?? '',
        "image": itemImages[itemName] ?? '',
        "trend": trend,
      };
    }).toList();
  }

  // Helper method to get the day index for chart data
  int _getDayOfRange(DateTime date, String timeRange, DateTime startDate) {
    if (timeRange == 'Today' || timeRange == 'Yesterday') {
      return 0; // Single day data
    } else if (timeRange == 'This Week') {
      return date.difference(startDate).inDays;
    } else if (timeRange == 'This Month') {
      return date.day - 1; // Days of month are 1-based, array is 0-based
    } else { // All or other cases
      // For 'All', use days from the current date
      int daysAgo = DateTime.now().difference(date).inDays;
      // Limit to last 30 days for chart
      if (daysAgo > 30) daysAgo = 30;
      return 30 - daysAgo;
    }
  }

  // Create chart spots with proper range
  List<FlSpot> _createChartSpots(Map<int, double> data, String timeRange) {
    List<FlSpot> spots = [];
    int maxDays = _getMaxDaysForRange(timeRange);
    
    for (int i = 0; i < maxDays; i++) {
      spots.add(FlSpot(i.toDouble(), data[i] ?? 0));
    }
    
    // Ensure at least 7 spots for consistent chart rendering
    if (spots.length < 7) {
      for (int i = spots.length; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), 0));
      }
    }
    
    return spots;
  }

  // Get maximum number of days for the given time range
  int _getMaxDaysForRange(String timeRange) {
    DateTime now = DateTime.now();
    
    switch (timeRange) {
      case 'Today':
      case 'Yesterday':
        return 1;
      case 'This Week':
        return 7;
      case 'This Month':
        return DateTime(now.year, now.month + 1, 0).day; // Days in current month
      case 'All':
        return 30; // Show last 30 days for 'All'
      default:
        return 7;
    }
  }

  // Return empty data structure when no orders are found
  Map<String, dynamic> _getEmptyData() {
    return {
      'statistics': {
        'Total Orders': 0,
        'Completed': 0,
        'Pending': 0,
        'Revenue': 0,
      },
      'trends': {
        'Total Orders': 0.0,
        'Completed': 0.0,
        'Pending': 0.0,
        'Revenue': 0.0,
      },
      'revenueSpots': List.generate(7, (index) => FlSpot(index.toDouble(), 0)),
      'ordersSpots': List.generate(7, (index) => FlSpot(index.toDouble(), 0)),
      'popularItems': [],
    };
  }

  // Method to safely update state for category changes
  void _updateCategory(String category) {
    if (_selectedCategory != category) {
      setState(() {
        _selectedCategory = category;
        _isLoading = true;
      });

      // Filter items based on selected category
      _filterItemsByCategory();
    }
  }

  // Filter items by selected category
  void _filterItemsByCategory() {
    // In a real app, you would filter based on the selected category
    // For demonstration, we'll simulate loading
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  
  // Method to refresh data
  Future<void> _refreshData() async {
    await _fetchOrderData();
  }

  @override
  Widget build(BuildContext context) {
    // Show error if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        // Clear error after showing
        errorMessage = null;
      }
    });
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return _buildWideLayout();
            } else {
              return _buildNarrowLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateSelector(),
                const SizedBox(height: 20),
                _buildDateRangeFilter(), // Add date range filter here
                const SizedBox(height: 20),
                _isLoading
                    ? _buildStatisticsShimmer()
                    : _buildStatisticsCards(),
                const SizedBox(height: 24),
                _buildStatusFilter(),
                const SizedBox(height: 20),
                _isLoading ? _buildChartsShimmer() : _buildCharts(),
                const SizedBox(height: 24),
                _buildPopularItemsSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateSelector(),
                const SizedBox(height: 20),
                _buildDateRangeFilter(), // Add date range filter here
                const SizedBox(height: 20),
                _isLoading
                    ? _buildStatisticsShimmer()
                    : _buildStatisticsCards(),
                const SizedBox(height: 24),
                _buildStatusFilter(),
                const SizedBox(height: 20),
                _isLoading ? _buildChartsShimmer() : _buildCharts(),
                const SizedBox(height: 24),
                _buildPopularItemsSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // New date range filter UI
  Widget _buildDateRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _timeRanges.length,
            itemBuilder: (context, index) {
              final range = _timeRanges[index];
              final isSelected = range == _selectedTimeRange;

              return GestureDetector(
                onTap: () {
                  _updateDateRange(range);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    range,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[800],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ).animate()
                  .fadeIn(duration: 400.ms, delay: 600.ms + (50.ms * index))
                  .slideX(
                    begin: 0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOutQuad),
              );
            },
          ),
        ),
      ],
    ).animate()
      .fadeIn(duration: 400.ms, delay: 300.ms)
      .moveX(begin: -20, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: orderStatuses.length,
            itemBuilder: (context, index) {
              final status = orderStatuses[index];
              final isSelected = status == _selectedStatus;

              return GestureDetector(
                onTap: () {
                  _updateOrderStatus(status);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[800],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ).animate()
                  .fadeIn(duration: 400.ms, delay: 600.ms + (50.ms * index))
                  .slideX(
                    begin: 0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOutQuad),
              );
            },
          ),
        ),
      ],
    ).animate()
      .fadeIn(duration: 400.ms, delay: 500.ms)
      .moveX(begin: -20, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMM d, yyyy').format(_currentDate),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Welcome back, ${_name.isNotEmpty ? _name : 'Manager'}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          // Keep dropdown for user preference
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.refresh, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _refreshData,
                  child: Text(
                    'Refresh',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).moveX(
              begin: 20, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .moveY(begin: -10, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
  }

  // Helper to get current username
 

  Widget _buildStatisticsShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final List<LinearGradient> gradients = [
      LinearGradient(
          colors: [Color(0xFF6448FE), Color(0xFF5FC6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      LinearGradient(
          colors: [Color(0xFF2ECE7B), Color(0xFF33D890)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      LinearGradient(
          colors: [Color(0xFFFE9A37), Color(0xFFFFB566)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      LinearGradient(
          colors: [Color(0xFFFF5182), Color(0xFFFF7B9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
    ];

    final List<IconData> icons = [
      Icons.shopping_bag_rounded,
      Icons.check_circle_outlined,
      Icons.pending_actions_outlined,
      Icons.currency_rupee_rounded,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: gradients[index],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradients[index].colors.first.withAlpha(76),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            Icon(icons[index], color: Colors.white, size: 22),
                      ),
                      Row(
                        children: [
                          Icon(
                            trends[statistics.keys.elementAt(index)]! >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${trends[statistics.keys.elementAt(index)]!.abs().toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statistics.keys.elementAt(index) == "Revenue"
                        ? "₹${NumberFormat('#,###').format(statistics[statistics.keys.elementAt(index)])}"
                        : statistics[statistics.keys.elementAt(index)]
                            .toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    statistics.keys.elementAt(index),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(229),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildChartsShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: 180,
            height: 28,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCharts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Trends',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800]),
        ).animate().fadeIn(duration: 400.ms).moveX(
            begin: -20, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withAlpha(25),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue (${_selectedTimeRange})',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  const style = TextStyle(
                                      color: Color(0xff68737d),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10);
                                  String text;
                                  switch (value.toInt()) {
                                    case 0:
                                      text = _selectedTimeRange == 'Today' || _selectedTimeRange == 'Yesterday' 
                                          ? 'Day' : 'Mon';
                                      break;
                                    case 3:
                                      text = _selectedTimeRange == 'Today' || _selectedTimeRange == 'Yesterday' 
                                          ? '' : 'Thu';
                                      break;
                                    case 6:
                                      text = _selectedTimeRange == 'Today' || _selectedTimeRange == 'Yesterday' 
                                          ? '' : 'Sun';
                                      break;
                                    default:
                                      text = '';
                                      break;
                                  }
                                  return SideTitleWidget(
                                      meta: meta,
                                      space: 4,
                                      child: Text(text, style: style));
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: revenueSpots,
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                  show: true, color: Colors.blue.withAlpha(51)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideX(
                  begin: -0.2,
                  end: 0,
                  duration: 600.ms,
                  curve: Curves.easeOutQuad),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orders (${_selectedTimeRange})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  const style = TextStyle(
                                    color: Color(0xff68737d),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  );
                                  String text;
                                  switch (value.toInt()) {
                                    case 0:
                                      text = _selectedTimeRange == 'Today' || _selectedTimeRange == 'Yesterday' 
                                          ? 'Day' : 'Mon';
                                      break;
                                    case 3:
                                      text = _selectedTimeRange == 'Today' || _selectedTimeRange == 'Yesterday' 
                                          ? '' : 'Thu';
                                      break;
                                    case 6:
                                      text = _selectedTimeRange == 'Today' || _selectedTimeRange == 'Yesterday' 
                                          ? '' : 'Sun';
                                      break;
                                    default:
                                      text = '';
                                      break;
                                  }
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 4,
                                    child: Text(text, style: style),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: ordersSpots,
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green.withAlpha(51),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideX(
                  begin: 0.2,
                  end: 0,
                  duration: 600.ms,
                  curve: Curves.easeOutQuad),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPopularItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Popular Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms).moveX(
                begin: -20,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutQuad),
            TextButton(
              onPressed: () {
                // Navigate to full menu
              },
              child: Text(
                'View all',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms).moveX(
                begin: 20, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
          ],
        ),
        const SizedBox(height: 8),

        // Categories
        _isLoading ? _buildCategoriesShimmer() : _buildCategories(),
        const SizedBox(height: 16),

        // Popular items horizontal list
        _isLoading ? _buildPopularItemsListShimmer() : _buildPopularItemsList(),
      ],
    );
  }
  
  Widget _buildCategoriesShimmer() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;

          return GestureDetector(
            onTap: () {
              _updateCategory(category);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300]!,
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[800],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 600.ms + (50.ms * index))
                .slideX(
                    begin: 0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOutQuad),
          );
        },
      ),
    );
  }

  Widget _buildPopularItemsListShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularItemsList() {
    if (popularItems.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No orders in this time period',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 700.ms);
    }
    
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularItems.length,
        itemBuilder: (context, index) {
          final item = popularItems[index];
          final isPositiveTrend = item["trend"] >= 0;

          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item image with error handling
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.network(
                        item["image"],
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 120,
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositiveTrend
                              ? Colors.green.withAlpha(229)
                              : Colors.red.withAlpha(229),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositiveTrend
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${item["trend"].abs().toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["name"],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item["category"],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sold: ${item["sold"]}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '₹${NumberFormat('#,###').format(item["revenue"])}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 700.ms + (100.ms * index), duration: 500.ms)
              .slideX(
                  begin: 0.2,
                  end: 0,
                  delay: 700.ms + (100.ms * index),
                  duration: 400.ms,
                  curve: Curves.easeOutQuad);
        },
      ),
    );
  }

}