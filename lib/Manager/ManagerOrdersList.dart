import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:canteendesk/API/Cred.dart'; // Assuming this has your API credentials

class ManagerOrderList extends StatefulWidget {
  const ManagerOrderList({Key? key}) : super(key: key);

  @override
  _ManagerOrderListState createState() => _ManagerOrderListState();
}

class _ManagerOrderListState extends State<ManagerOrderList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // REST API base URL
  final String apiBaseUrl = Cred.FIREBASE_DATABASE_URL;

  // Timer for polling the API
  Timer? _pollingTimer;

  // Order lists
  List<Map<String, dynamic>> pendingOrders = [];
  List<Map<String, dynamic>> onGoingOrders = [];
  List<Map<String, dynamic>> readyOrders = [];
  List<Map<String, dynamic>> completedOrders = [];

  // Lists for filtered results
  late List<Map<String, dynamic>> filteredPendingOrders;
  late List<Map<String, dynamic>> filteredOnGoingOrders;
  late List<Map<String, dynamic>> filteredReadyOrders;
  late List<Map<String, dynamic>> filteredCompletedOrders;

  // Maps to store order timers and estimated delivery times
  Map<String, Timer> orderTimers = {};
  Map<String, DateTime> orderStartTimes = {};
  Map<String, Duration> orderEstimatedTimes = {};

  // Filter options
  String? _selectedPaymentFilter;
  String? _selectedSortOption = 'Newest First';
  String? id;

  // Selected order for details panel (desktop UI)
  Map<String, dynamic>? _selectedOrder;
  OrderStatus? _selectedOrderStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Set up filtered lists
    filteredPendingOrders = List.from(pendingOrders);
    filteredOnGoingOrders = List.from(onGoingOrders);
    filteredReadyOrders = List.from(readyOrders);
    filteredCompletedOrders = List.from(completedOrders);

    // Load ID first, which will trigger loading data
    _loadIdFromSharedPrefs();

    _tabController.addListener(() {
      // Close search when switching tabs
      if (_isSearching) {
        setState(() {
          _isSearching = false;
        });
      }

      // Clear selected order when switching tabs
      setState(() {
        _selectedOrder = null;
        _selectedOrderStatus = null;
      });
    });
  }

  void _loadIdFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      id = prefs.getString('createdAt');

      // Only load order data after id is available
      if (id != null) {
        _loadOrderData();
        _setupOrderPolling(); // Set up polling for real-time updates
      } else {
        // Handle the case where id is not available
        _isLoading = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Store ID not found. Please login again.')),
        );
      }
    });
  }

  void _setupOrderPolling() {
    // Cancel any existing timer
    _pollingTimer?.cancel();

    // Poll the API every 10 seconds
    _pollingTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _loadOrderData(showLoading: false);
    });
  }

  Future<void> _loadOrderData({bool showLoading = true}) async {
    if (id == null) return; // Safety check

    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Get orders from REST API
      final response = await http.get(
        Uri.parse('$apiBaseUrl/${id}/orders.json'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null) {
          _updateOrdersFromData(data);
        } else {
          setState(() {
            pendingOrders.clear();
            onGoingOrders.clear();
            readyOrders.clear();
            completedOrders.clear();

            filteredPendingOrders = [];
            filteredOnGoingOrders = [];
            filteredReadyOrders = [];
            filteredCompletedOrders = [];

            _isLoading = false;
          });
        }
      } else {
        print('Error loading orders: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error loading orders: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateOrdersFromData(Map<String, dynamic> data) {
    setState(() {
      // Clear current lists
      pendingOrders.clear();
      onGoingOrders.clear();
      readyOrders.clear();
      completedOrders.clear();

      // Process each order
      data.forEach((key, value) {
        final orderData = Map<String, dynamic>.from(value);
        // Ensure the order has its key/ID
        orderData['id'] = key;

        final status = orderData['status'] ?? 'pending';

        // Add to appropriate list based on status
        switch (status) {
          case 'pending':
            pendingOrders.add(orderData);
            break;
          case 'accepted':
          case 'confirmed':
            onGoingOrders.add(orderData);
            break;
          case 'ready':
            readyOrders.add(orderData);
            break;
          case 'completed':
            completedOrders.add(orderData);
            break;
          case 'rejected':
            // Rejected orders are not shown in the UI
            break;
        }
      });

      // Update filtered lists
      filteredPendingOrders = List.from(pendingOrders);
      filteredOnGoingOrders = List.from(onGoingOrders);
      filteredReadyOrders = List.from(readyOrders);
      filteredCompletedOrders = List.from(completedOrders);

      // Apply filters if any
      if (_searchQuery.isNotEmpty ||
          _selectedPaymentFilter != null ||
          _selectedSortOption != null) {
        _filterOrders();
      }

      _isLoading = false;

      // Update selected order if it was modified
      if (_selectedOrder != null) {
        _updateSelectedOrderIfChanged();
      }
    });
  }

  void _updateSelectedOrderIfChanged() {
    if (_selectedOrder == null || _selectedOrderStatus == null) return;

    String orderId = _selectedOrder!['id'] ?? _selectedOrder!['orderId'];
    List<Map<String, dynamic>> relevantList;

    switch (_selectedOrderStatus) {
      case OrderStatus.pending:
        relevantList = pendingOrders;
        break;
      case OrderStatus.ongoing:
        relevantList = onGoingOrders;
        break;
      case OrderStatus.ready:
        relevantList = readyOrders;
        break;
      case OrderStatus.completed:
        relevantList = completedOrders;
        break;
      default:
        return;
    }

    // Find the updated order in the appropriate list
    int index = relevantList
        .indexWhere((order) => (order['id'] ?? order['orderId']) == orderId);

    if (index != -1) {
      // Update the selected order
      setState(() {
        _selectedOrder = relevantList[index];
      });
    } else {
      // Order may have moved to a different status
      _selectedOrder = null;
      _selectedOrderStatus = null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();

    // Cancel all active timers
    orderTimers.forEach((key, timer) {
      timer.cancel();
    });

    super.dispose();
  }

  void _filterOrders() {
    setState(() {
      // First filter by search query
      filteredPendingOrders = _filterOrdersByQuery(pendingOrders);
      filteredOnGoingOrders = _filterOrdersByQuery(onGoingOrders);
      filteredReadyOrders = _filterOrdersByQuery(readyOrders);
      filteredCompletedOrders = _filterOrdersByQuery(completedOrders);

      // Then filter by payment method if selected
      if (_selectedPaymentFilter != null &&
          _selectedPaymentFilter!.isNotEmpty) {
        filteredPendingOrders = _filterOrdersByPayment(filteredPendingOrders);
        filteredOnGoingOrders = _filterOrdersByPayment(filteredOnGoingOrders);
        filteredReadyOrders = _filterOrdersByPayment(filteredReadyOrders);
        filteredCompletedOrders =
            _filterOrdersByPayment(filteredCompletedOrders);
      }

      // Apply sorting
      _applySorting();
    });
  }

  List<Map<String, dynamic>> _filterOrdersByQuery(
      List<Map<String, dynamic>> orders) {
    if (_searchQuery.isEmpty) return List.from(orders);

    return orders
        .where((order) =>
            order['id']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            order['orderId']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (order['customer']
                    ?.toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false) ||
            (order['userId']
                    ?.toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false) ||
            (order['items']?.any((item) => item['name']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase())) ??
                false))
        .toList();
  }

  List<Map<String, dynamic>> _filterOrdersByPayment(
      List<Map<String, dynamic>> orders) {
    return orders
        .where((order) => order['paymentMethod'] == _selectedPaymentFilter)
        .toList();
  }

  void _applySorting() {
    if (_selectedSortOption == 'Highest Amount') {
      _sortOrdersByAmount(filteredPendingOrders, isAscending: false);
      _sortOrdersByAmount(filteredOnGoingOrders, isAscending: false);
      _sortOrdersByAmount(filteredReadyOrders, isAscending: false);
      _sortOrdersByAmount(filteredCompletedOrders, isAscending: false);
    } else if (_selectedSortOption == 'Lowest Amount') {
      _sortOrdersByAmount(filteredPendingOrders, isAscending: true);
      _sortOrdersByAmount(filteredOnGoingOrders, isAscending: true);
      _sortOrdersByAmount(filteredReadyOrders, isAscending: true);
      _sortOrdersByAmount(filteredCompletedOrders, isAscending: true);
    } else {
      // Default: Newest First - assuming the order IDs are sequential
      filteredPendingOrders.sort((a, b) =>
          (b['id'] ?? b['orderId']).compareTo(a['id'] ?? a['orderId']));
      filteredOnGoingOrders.sort((a, b) =>
          (b['id'] ?? b['orderId']).compareTo(a['id'] ?? a['orderId']));
      filteredReadyOrders.sort((a, b) =>
          (b['id'] ?? b['orderId']).compareTo(a['id'] ?? a['orderId']));
      filteredCompletedOrders.sort((a, b) =>
          (b['id'] ?? b['orderId']).compareTo(a['id'] ?? a['orderId']));
    }
  }

  void _sortOrdersByAmount(List<Map<String, dynamic>> orders,
      {required bool isAscending}) {
    orders.sort((a, b) {
      String aTotal = (a['totalAmount'] ?? a['total'] ?? '0')
          .toString()
          .replaceAll('Rs. ', '');
      String bTotal = (b['totalAmount'] ?? b['total'] ?? '0')
          .toString()
          .replaceAll('Rs. ', '');
      double aValue = double.tryParse(aTotal) ?? 0;
      double bValue = double.tryParse(bTotal) ?? 0;
      return isAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.grey[50]
            : Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          toolbarHeight: _isSearching ? kToolbarHeight + 8 : kToolbarHeight,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search orders...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                          filteredPendingOrders = List.from(pendingOrders);
                          filteredOnGoingOrders = List.from(onGoingOrders);
                          filteredReadyOrders = List.from(readyOrders);
                          filteredCompletedOrders = List.from(completedOrders);
                          _isSearching = false;
                        });
                      },
                    ),
                  ),
                  style: TextStyle(fontSize: 16),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterOrders();
                    });
                  },
                )
              : Text('Order Management',
                  style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            if (!_isSearching)
              IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
                tooltip: 'Search orders',
              ),
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: _showFilterOptions,
              tooltip: 'Filter orders',
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () => _loadOrderData(),
              tooltip: 'Refresh orders',
            ),
            SizedBox(width: 16),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            unselectedLabelColor:
                Theme.of(context).brightness == Brightness.light
                    ? Colors.black54
                    : Colors.white70,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pending_actions),
                    SizedBox(width: 8),
                    Text('Pending (${filteredPendingOrders.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delivery_dining),
                    SizedBox(width: 8),
                    Text('On Going (${filteredOnGoingOrders.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant),
                    SizedBox(width: 8),
                    Text('Ready (${filteredReadyOrders.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle),
                    SizedBox(width: 8),
                    Text('Completed (${filteredCompletedOrders.length})'),
                  ],
                ),
              ),
            ],
          ),
          elevation: 0,
        ),
        body: _isLoading ? _buildLoadingIndicator() : _buildDesktopLayout(),
      ),
    );
  }

  // New method for desktop layout with split view
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left panel - Orders list
        Expanded(
          flex: 2,
          child: _buildTabBarView(),
        ),

        // Right panel - Order details (only shown when an order is selected)
        if (_selectedOrder != null && _selectedOrderStatus != null)
          Expanded(
            flex: 3,
            child: Card(
              margin: EdgeInsets.all(12),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildOrderDetailsPanel(),
            ),
          ),
      ],
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOrdersScreen(filteredPendingOrders, OrderStatus.pending),
        _buildOrdersScreen(filteredOnGoingOrders, OrderStatus.ongoing),
        _buildOrdersScreen(filteredReadyOrders, OrderStatus.ready),
        _buildOrdersScreen(filteredCompletedOrders, OrderStatus.completed),
      ],
    );
  }

  Widget _buildOrdersScreen(
      List<Map<String, dynamic>> orders, OrderStatus status) {
    // Empty state
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getStatusIcon(status),
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              _getEmptyStateText(status),
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            if (_searchQuery.isNotEmpty || _selectedPaymentFilter != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                    _selectedPaymentFilter = null;
                    filteredPendingOrders = List.from(pendingOrders);
                    filteredOnGoingOrders = List.from(onGoingOrders);
                    filteredReadyOrders = List.from(readyOrders);
                    filteredCompletedOrders = List.from(completedOrders);
                  });
                },
                child: Text('Clear filters'),
              ),
          ],
        ).animate().fadeIn(duration: 600.ms),
      );
    }

    // Content state - Showing a table for desktop view
    return RefreshIndicator(
      onRefresh: _loadOrderData,
      child: _buildOrdersTable(orders, status),
    );
  }

  // Orders table for desktop view
  Widget _buildOrdersTable(
      List<Map<String, dynamic>> orders, OrderStatus status) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table headers
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                _tableHeader('Order ID', 1),
                _tableHeader('Customer', 2),
                _tableHeader('Time', 1),
                _tableHeader('Amount', 1),
                _tableHeader('Payment', 1),
                _tableHeader('Actions', 1),
              ],
            ),
          ),

          // Table rows
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              return _buildTableRow(orders[index], status);
            },
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String title, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> order, OrderStatus status) {
    final isSelected = _selectedOrder != null &&
        (_selectedOrder!['id'] ?? _selectedOrder!['orderId']) ==
            (order['id'] ?? order['orderId']);

    return Material(
      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedOrder = order;
            _selectedOrderStatus = status;
          });
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 600;

              return isSmallScreen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  _getStatusIcon(status),
                                  size: 16,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '#${order['orderId'] ?? order['id']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            Text(
                              _getTimeText(order, status),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Customer: ${order['userId'] ?? 'Unknown'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount: ${order['totalAmount'].toString() ?? order['total'] ?? '0'}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                _getPaymentMethodIcon(
                                    order['paymentMethod'] ?? 'Unknown'),
                                SizedBox(width: 4),
                                Text(order['paymentMethod'] ?? 'Unknown'),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildRowActionButton(order, status),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Order ID
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withAlpha(25),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    _getStatusIcon(status),
                                    size: 16,
                                    color: _getStatusColor(status),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '#${order['orderId'] ?? order['id']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Customer
                        Expanded(
                          flex: 2,
                          child: Text(
                            order['userId'] ?? 'Unknown',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Time
                        Expanded(
                          child: Text(_getTimeText(order, status)),
                        ),

                        // Amount
                        Expanded(
                          child: Text(
                            order['totalAmount'].toString() ??
                                order['total'] ??
                                '0',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),

                        // Payment
                        Expanded(
                          child: Row(
                            children: [
                              _getPaymentMethodIcon(
                                  order['paymentMethod'] ?? 'Unknown'),
                              SizedBox(width: 4),
                              Text(order['paymentMethod'] ?? 'Unknown'),
                            ],
                          ),
                        ),

                        // Actions
                        Expanded(
                          child: _buildRowActionButton(order, status),
                        ),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRowActionButton(Map<String, dynamic> order, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return ElevatedButton.icon(
          icon: Icon(Icons.check, size: 16),
          label: Text('Accept'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () => _acceptOrder(order),
        );

      case OrderStatus.ongoing:
        return ElevatedButton.icon(
          icon: Icon(Icons.restaurant, size: 16),
          label: Text('Ready'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () => _markOrderReady(order),
        );

      case OrderStatus.ready:
        return ElevatedButton.icon(
          icon: Icon(Icons.check_circle, size: 16),
          label: Text('Complete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () => _showOtpVerificationDialog(order),
        );

      case OrderStatus.completed:
        return Row(
          children: [
            IconButton(
              icon: Icon(Icons.print, size: 16),
              tooltip: 'Print Receipt',
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.history, size: 16),
              tooltip: 'Order History',
              onPressed: () => _showOrderHistory(order),
            ),
          ],
        );
    }
  }

  // New method for showing detailed order information in the right panel
  Widget _buildOrderDetailsPanel() {
    final order = _selectedOrder!;
    final status = _selectedOrderStatus!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withAlpha(25),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order['orderId'] ?? order['id']}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getStatusText(status),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedOrder = null;
                    _selectedOrderStatus = null;
                  });
                },
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order information
                _buildInfoSection(
                  title: 'Order Information',
                  children: [
                    _buildInfoRow('Customer ID', order['userId'] ?? 'Unknown'),
                    _buildInfoRow(
                        'Order Time', order['timestamp'] ?? _getCurrentTime()),
                    if (status == OrderStatus.ongoing)
                      _buildInfoRow('Accepted At',
                          order['acceptedAt'] ?? _getCurrentTime()),
                    if (status == OrderStatus.ready)
                      _buildInfoRow(
                          'Ready At', order['readyAt'] ?? _getCurrentTime()),
                    if (status == OrderStatus.completed)
                      _buildInfoRow('Completed At',
                          order['completedAt'] ?? _getCurrentTime()),
                    _buildInfoRow(
                        'Payment Method', order['paymentMethod'] ?? 'Unknown'),
                    if (order['estimatedTime'] != null)
                      _buildInfoRow('Estimated Time', order['estimatedTime']),
                  ],
                ),

                SizedBox(height: 24),

                // Order items
                _buildOrderItemsSection(order),

                SizedBox(height: 24),

                // Order notes
                if (order['notes'] != null &&
                    order['notes'].toString().isNotEmpty)
                  _buildNotesSection(order['notes']),

                SizedBox(height: 24),

                // Payment summary
                _buildPaymentSummarySection(order),

                SizedBox(height: 32),

                // Action buttons
                _buildDetailedActionButtons(order, status),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsSection(Map<String, dynamic> order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text('Item',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                        child: Text('Qty',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                        child: Text('Price',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              Divider(height: 1),

              // Items
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: order['items']?.length ?? 0,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = order['items'][index];
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['name'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            (item['quantity'] ?? '1').toString(),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item['price']?.toString() ?? '0',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(String notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Notes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber[100]!),
          ),
          child: Text(notes),
        ),
      ],
    );
  }

  Widget _buildPaymentSummarySection(Map<String, dynamic> order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              _buildPaymentDetail(
                  'Subtotal', order['subtotal']?.toString() ?? '0'),
              if (order['discount'] != null)
                _buildPaymentDetail('Discount', '- ${order['discount']}'),
              _buildPaymentDetail('Tax', order['tax']?.toString() ?? '0'),
              if (order['platformCharge'] != null)
                _buildPaymentDetail(
                    'Platform Charge', order['platformCharge'].toString()),
              Divider(height: 16, thickness: 1),
              _buildPaymentDetail(
                  'Total Amount',
                  order['totalAmount']?.toString() ??
                      order['total']?.toString() ??
                      '0',
                  isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedActionButtons(
      Map<String, dynamic> order, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(Icons.check),
                label: Text('Accept Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => _acceptOrder(order),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(Icons.close, color: Colors.red),
                label:
                    Text('Reject Order', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.red),
                ),
                onPressed: () => _showRejectDialog(order),
              ),
            ),
          ],
        );

      case OrderStatus.ongoing:
        return ElevatedButton.icon(
          icon: Icon(Icons.restaurant),
          label: Text('Mark as Ready'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 50),
          ),
          onPressed: () => _markOrderReady(order),
        );

      case OrderStatus.ready:
        return ElevatedButton.icon(
          icon: Icon(Icons.check_circle),
          label: Text('Complete Order'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 50),
          ),
          onPressed: () => _showOtpVerificationDialog(order),
        );

      case OrderStatus.completed:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(Icons.print),
                label: Text('Print Receipt'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {},
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(Icons.history),
                label: Text('Order Timeline'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => _showOrderHistory(order),
              ),
            ),
          ],
        );
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending_actions;
      case OrderStatus.ongoing:
        return Icons.delivery_dining;
      case OrderStatus.ready:
        return Icons.restaurant;
      case OrderStatus.completed:
        return Icons.check_circle;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending Approval';
      case OrderStatus.ongoing:
        return 'Order in Progress';
      case OrderStatus.ready:
        return 'Ready for Pickup';
      case OrderStatus.completed:
        return 'Order Completed';
    }
  }

  String _getEmptyStateText(OrderStatus status) {
    final filterText = _searchQuery.isNotEmpty || _selectedPaymentFilter != null
        ? 'matching '
        : '';

    switch (status) {
      case OrderStatus.pending:
        return 'No ${filterText}pending orders';
      case OrderStatus.ongoing:
        return 'No ${filterText}ongoing orders';
      case OrderStatus.ready:
        return 'No ${filterText}ready orders';
      case OrderStatus.completed:
        return 'No ${filterText}completed orders';
    }
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 6,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading orders...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _acceptOrder(Map<String, dynamic> order) async {
    final String orderId = order['orderId'] ?? order['id'];
    final String storeId = order['storeId'] ?? id!;

    // Show loading indicator
    _showLoadingDialog('Accepting order...');

    try {
      // Update order status using REST API
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/$storeId/orders/$orderId.json'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': 'accepted',
          'acceptedAt': _getCurrentTime(),
          'acceptedBy': 'navin280123', // Using current user's login
          'acceptedDate': DateTime.now().toString()
        }),
      );

      // Close loading indicator
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        // Success handling
        _showNotification(
          message: 'Order $orderId accepted and moved to On Going!',
          isSuccess: true,
        );

        // Switch to ongoing tab
        _tabController.animateTo(1);

        // Refresh data
        _loadOrderData(showLoading: false);

        // Start the delivery timer
        _startDeliveryTimer(order);
      } else {
        throw Exception(
            'Failed to update order status: ${response.statusCode}');
      }
    } catch (error) {
      // Close loading indicator if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error accepting order: $error');
      _showNotification(
        message: 'Failed to accept order: $error',
        isSuccess: false,
      );
    }
  }

  void _startDeliveryTimer(Map<String, dynamic> order) {
    final String orderId = order['orderId'] ?? order['id'];
    orderStartTimes[orderId] = DateTime.now();

    // Parse the estimated delivery time
    if (order['estimatedTime'] != null) {
      final String estTime = order['estimatedTime'];
      final RegExp regex = RegExp(r'(\d+)(?:-(\d+))?\s*mins?');
      final match = regex.firstMatch(estTime);

      if (match != null) {
        int minTime = int.parse(match.group(1)!);
        int maxTime =
            match.group(2) != null ? int.parse(match.group(2)!) : minTime;

        // Use average
        int avgTime = (minTime + maxTime) ~/ 2;
        orderEstimatedTimes[orderId] = Duration(minutes: avgTime);
      } else {
        orderEstimatedTimes[orderId] = Duration(minutes: 30); // Default
      }
    } else {
      orderEstimatedTimes[orderId] = Duration(minutes: 30); // Default
    }

    // Start timer to update UI
    orderTimers[orderId] = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _markOrderReady(Map<String, dynamic> order) async {
    final String orderId = order['orderId'] ?? order['id'];
    final String storeId = order['storeId'] ?? id!;

    // Show loading indicator
    _showLoadingDialog('Marking order as ready...');

    try {
      // Update order status using REST API
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/$storeId/orders/$orderId.json'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': 'ready',
          'readyAt': _getCurrentTime(),
          'readyBy': 'navin280123',
          'readyDate': DateTime.now().toString()
        }),
      );

      // Close loading indicator
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        // Success handling
        _showNotification(
          message: 'Order $orderId marked as ready!',
          isSuccess: true,
        );

        // Switch to ready tab
        _tabController.animateTo(2);

        // Refresh data
        _loadOrderData(showLoading: false);
      } else {
        throw Exception(
            'Failed to update order status: ${response.statusCode}');
      }
    } catch (error) {
      // Close loading indicator if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error marking order as ready: $error');
      _showNotification(
        message: 'Failed to mark order as ready: $error',
        isSuccess: false,
      );
    }
  }

  void _completeOrder(Map<String, dynamic> order) async {
    final String orderId = order['orderId'] ?? order['id'];
    final String storeId = order['storeId'] ?? id!;
    final String studEmail = order['userId'];

    // Cancel the timer if it exists
    if (orderTimers.containsKey(orderId)) {
      orderTimers[orderId]!.cancel();
      orderTimers.remove(orderId);
    }

    // Show loading indicator
    _showLoadingDialog('Completing order...');

    try {
      // Update order status using REST API
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/$storeId/orders/$orderId.json'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': 'completed',
          'completedAt': _getCurrentTime(),
          'completedBy': 'navin280123',
          'completedDate': DateTime.now().toString()
        }),
      );

      if (response.statusCode == 200) {
        // Move from liveOrder to completedOrder
        try {
          // 1. Get the live order data
          final liveOrderResponse = await http.get(
            Uri.parse('$apiBaseUrl/User/$studEmail/liveOrder/$orderId.json'),
          );

          if (liveOrderResponse.statusCode == 200 &&
              liveOrderResponse.body != 'null') {
            final liveOrderData = json.decode(liveOrderResponse.body);

            // 2. Create completed order
            await http.put(
              Uri.parse(
                  '$apiBaseUrl/User/$studEmail/completedOrder/$orderId.json'),
              headers: {'Content-Type': 'application/json'},
              body: liveOrderResponse.body,
            );

            // 3. Delete live order
            await http.delete(
              Uri.parse('$apiBaseUrl/User/$studEmail/liveOrder/$orderId.json'),
            );
          }
        } catch (e) {
          print('Error moving order data: $e');
          // Continue anyway since the main operation succeeded
        }

        // Close loading indicator
        Navigator.of(context).pop();

        // Success handling
        _showNotification(
          message: 'Order $orderId completed successfully!',
          isSuccess: true,
        );

        // Switch to completed tab
        _tabController.animateTo(3);

        // Refresh data
        _loadOrderData(showLoading: false);
      } else {
        throw Exception(
            'Failed to update order status: ${response.statusCode}');
      }
    } catch (error) {
      // Close loading indicator if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error completing order: $error');
      _showNotification(
        message: 'Failed to complete order: $error',
        isSuccess: false,
      );
    }
  }

  void _rejectOrder(Map<String, dynamic> order, String reason) async {
    final String orderId = order['orderId'] ?? order['id'];
    final String storeId = order['storeId'] ?? id!;

    // Show loading indicator
    _showLoadingDialog('Rejecting order...');

    try {
      // Update order status using REST API
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/$storeId/orders/$orderId.json'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': 'rejected',
          'rejectedAt': _getCurrentTime(),
          'rejectedBy': 'navin280123',
          'rejectReason': reason
        }),
      );

      // Close loading indicator
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        // Success handling
        _showNotification(
          message: 'Order $orderId rejected: $reason',
          isSuccess: false,
        );

        // Refresh data
        _loadOrderData(showLoading: false);

        // Clear selected order if it was rejected
        if (_selectedOrder != null &&
            (_selectedOrder!['id'] ?? _selectedOrder!['orderId']) == orderId) {
          setState(() {
            _selectedOrder = null;
            _selectedOrderStatus = null;
          });
        }
      } else {
        throw Exception(
            'Failed to update order status: ${response.statusCode}');
      }
    } catch (error) {
      // Close loading indicator if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error rejecting order: $error');
      _showNotification(
        message: 'Failed to reject order: $error',
        isSuccess: false,
      );
    }
  }

  void _showOrderHistory(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: Colors.blue),
                  SizedBox(width: 12),
                  Text(
                    'Order Timeline',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(),
              SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTimelineItem(
                          'Order Placed',
                          'Customer placed the order',
                          order['timestamp'] ?? _getCurrentTime(),
                          Icons.shopping_cart,
                          Colors.blue),
                      if (order['acceptedAt'] != null)
                        _buildTimelineItem(
                            'Order Accepted',
                            'Accepted by ${order['acceptedBy'] ?? 'staff'}',
                            order['acceptedAt'],
                            Icons.thumb_up,
                            Colors.green),
                      if (order['readyAt'] != null)
                        _buildTimelineItem(
                            'Order Ready',
                            'Marked ready by ${order['readyBy'] ?? 'staff'}',
                            order['readyAt'],
                            Icons.restaurant,
                            Colors.amber),
                      if (order['completedAt'] != null)
                        _buildTimelineItem(
                            'Order Completed',
                            'Completed and delivered to customer',
                            order['completedAt'],
                            Icons.check_circle,
                            Colors.purple),
                      if (order['rejectedAt'] != null)
                        _buildTimelineItem(
                            'Order Rejected',
                            'Reason: ${order['rejectReason'] ?? 'Not specified'}',
                            order['rejectedAt'],
                            Icons.cancel,
                            Colors.red),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  child: Text('Close'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
      String title, String subtitle, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : now.hour;
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${now.minute.toString().padLeft(2, '0')} $amPm';
  }

  Widget _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash on delivery':
        return Icon(Icons.money, size: 16, color: Colors.green[700]);
      case 'card':
        return Icon(Icons.credit_card, size: 16, color: Colors.blue[700]);
      case 'upi':
        return Icon(Icons.account_balance_wallet,
            size: 16, color: Colors.purple[700]);
      default:
        return Icon(Icons.payment, size: 16, color: Colors.grey[700]);
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showNotification({required String message, required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showFilterOptions() {
    final List<String> paymentMethods = [
      'All',
      'Cash on Delivery',
      'Card',
      'UPI'
    ];
    final List<String> sortOptions = [
      'Newest First',
      'Highest Amount',
      'Lowest Amount'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 500,
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_list, color: Colors.blue),
                      SizedBox(width: 16),
                      Text(
                        'Filter & Sort Orders',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(),

                  // Payment Method Filter
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: paymentMethods.map((method) {
                      bool isSelected = method == 'All'
                          ? _selectedPaymentFilter == null
                          : _selectedPaymentFilter == method;
                      return FilterChip(
                        label: Text(method),
                        selected: isSelected,
                        checkmarkColor: Colors.white,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedPaymentFilter =
                                selected && method != 'All' ? method : null;
                          });
                        },
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 24),

                  // Sort Options
                  Text(
                    'Sort By',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: sortOptions.map((option) {
                      bool isSelected = _selectedSortOption == option;
                      return FilterChip(
                        label: Text(option),
                        selected: isSelected,
                        checkmarkColor: Colors.white,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedSortOption =
                                selected ? option : 'Newest First';
                          });
                        },
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedPaymentFilter = null;
                            _selectedSortOption = 'Newest First';
                          });
                        },
                        child: Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Apply filters
                          this.setState(() {
                            _filterOrders();
                          });
                        },
                        child: Text('Apply Filters'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
void _showRejectDialog(Map<String, dynamic> order) {
    String rejectReason = 'Out of stock';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 450,
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 16),
                    Text(
                      'Reject Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(),
                SizedBox(height: 16),
                
                Text(
                  'Please select a reason for rejecting this order:',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                
                StatefulBuilder(
                  builder: (context, setDropdownState) {
                    return DropdownButtonFormField<String>(
                      value: rejectReason,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: [
                        'Out of stock',
                        'Restaurant too busy',
                        'Kitchen closed',
                        'Items unavailable',
                        'Technical issues',
                        'Other reason'
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDropdownState(() {
                          rejectReason = value!;
                        });
                      },
                    );
                  }
                ),
                
                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.cancel_outlined),
                      label: Text('Reject Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _rejectOrder(order, rejectReason);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOtpVerificationDialog(Map<String, dynamic> order) {
    final TextEditingController otpController = TextEditingController();
    bool isVerifying = false;
    String errorMessage = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 450,
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Theme.of(context).colorScheme.primary),
                        SizedBox(width: 16),
                        Text(
                          'Verify Order Completion',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        if (!isVerifying)
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 16),
                    
                    Text(
                      'Please ask the customer for the OTP sent to their phone to complete the order.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 24),
                    
                    // OTP input with improved styling for desktop
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Enter OTP',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: errorMessage.isNotEmpty ? errorMessage : null,
                        prefixIcon: Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: Colors.grey[50],
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: TextStyle(fontSize: 18, letterSpacing: 2),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: 24),
                    
                    if (isVerifying)
                      Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Verifying OTP...'),
                          ],
                        ),
                      ),
                    
                    if (!isVerifying) ...[
                      Divider(),
                      SizedBox(height: 16),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                          SizedBox(width: 16),
                          ElevatedButton.icon(
                            icon: Icon(Icons.check_circle),
                            label: Text('Verify & Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () async {
                              // Validate OTP input
                              if (otpController.text.length < 4) {
                                setState(() {
                                  errorMessage = 'Please enter a valid OTP';
                                });
                                return;
                              }

                              setState(() {
                                isVerifying = true;
                                errorMessage = '';
                              });

                              // Simulate OTP verification
                              await Future.delayed(Duration(seconds: 2));
                              
                              // For demo, any 6-digit code works
                              if (otpController.text.length == 6 && 
                                  RegExp(r'^\d{6}$').hasMatch(otpController.text)) {
                                Navigator.pop(context);
                                _completeOrder(order);
                              } else {
                                setState(() {
                                  isVerifying = false;
                                  errorMessage = 'Invalid OTP. Please try again.';
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Row _buildPaymentDetail(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
  
  String _getTimeText(Map<String, dynamic> order, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return order['timestamp'] ?? _getCurrentTime();
      case OrderStatus.ongoing:
        return order['acceptedAt'] ?? _getCurrentTime();
      case OrderStatus.ready:
        return order['readyAt'] ?? _getCurrentTime();
      case OrderStatus.completed:
        return order['completedAt'] ?? _getCurrentTime();
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.ongoing:
        return Colors.blue;
      case OrderStatus.ready:
        return Colors.amber;
      case OrderStatus.completed:
        return Colors.green;
    }
  }

  Widget _buildDeliveryTimer(Map<String, dynamic> order) {
    final String orderId = order['orderId'] ?? order['id'];

    // If no timer is running for this order, start one
    if (!orderTimers.containsKey(orderId)) {
      // Record the start time if not already set
      orderStartTimes[orderId] = orderStartTimes[orderId] ?? DateTime.now();

      // Parse the estimated delivery time (e.g., "20-30 mins")
      if (order['estimatedTime'] != null) {
        final String estTime = order['estimatedTime'];
        final RegExp regex = RegExp(r'(\d+)(?:-(\d+))?\s*mins?');
        final match = regex.firstMatch(estTime);

        if (match != null) {
          int minTime = int.parse(match.group(1)!);
          int maxTime = match.group(2) != null ? int.parse(match.group(2)!) : minTime;

          // Use average for display
          int avgTime = (minTime + maxTime) ~/ 2;
          orderEstimatedTimes[orderId] = Duration(minutes: avgTime);
        }
      } else {
        // Default to 30 minutes if no estimate is provided
        orderEstimatedTimes[orderId] = Duration(minutes: 30);
      }

      // Start the timer to update the UI every second
      orderTimers[orderId] = Timer.periodic(Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }

    // Calculate elapsed time
    final Duration elapsed = DateTime.now().difference(orderStartTimes[orderId]!);
    final Duration estimated = orderEstimatedTimes[orderId]!;

    // Calculate progress (0.0 to 1.0)
    final double progress = elapsed.inSeconds / estimated.inSeconds;
    final bool isOverdue = progress > 1.0;

    // Format the remaining/overdue time
    String timeText;
    Color timeColor;

    if (isOverdue) {
      final Duration overdue = elapsed - estimated;
      timeText = '+${_formatDuration(overdue)} over';
      timeColor = Colors.red;
    } else {
      final Duration remaining = estimated - elapsed;
      timeText = '${_formatDuration(remaining)} left';
      timeColor = progress > 0.8 ? Colors.orange : Colors.green;
    }

    // Desktop-optimized timer display
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 160,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: timeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: timeColor.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOverdue ? Icons.timer_off : Icons.timer,
                size: 16,
                color: timeColor,
              ),
              SizedBox(width: 8),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 14,
                  color: timeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              // Progress indicator
              Container(
                width: 40,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress > 1.0 ? 1.0 : progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: timeColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    int minutes = duration.inMinutes;
    int seconds = (duration.inSeconds % 60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// Enum to represent order status
enum OrderStatus { pending, ongoing, ready, completed }