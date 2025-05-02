import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canteendesk/API/Cred.dart';
import 'package:canteendesk/Firebase/FirebaseManager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManagerReport extends StatefulWidget {
  @override
  _ManagerReportState createState() => _ManagerReportState();
}

class _ManagerReportState extends State<ManagerReport> with SingleTickerProviderStateMixin {
  int _selectedChartTypeIndex = 0;
  String selectedTimeFrame = 'Weekly';
  List<String> timeFrames = ['Daily', 'Weekly', 'Monthly', 'Yearly', 'Custom'];
  bool _isLoading = true;
  bool _isComparison = false;
  final List<String> _chartTypes = ['Bar', 'Line', 'Pie', 'Table'];
  String _storeId = ''; // Store ID for Firebase queries
  String? errorMessage;
  
  // Animation controller for insights panel
  late AnimationController _insightsController;
  
  // Date range
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  // For comparison data
  DateTimeRange? _comparisonDateRange;
  
  // For tab controller
  int _currentTabIndex = 0;
  final List<String> _tabNames = ['Sales', 'Orders', 'Customers', 'Items'];

  // Item filter
  String _selectedCategory = 'All Categories';
  List<String> _categories = ['All Categories'];

  // Data structures to hold the fetched data
  List<Map<String, dynamic>> salesData = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> topItems = [];
  List<Map<String, dynamic>> insights = [];
  Map<String, dynamic> summaryMetrics = {
    'totalSales': 0.0,
    'totalOrders': 0,
    'avgOrderValue': 0.0,
    'customerVisits': 0,
  };

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _insightsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Load store ID then fetch data
    _loadStoreId().then((_) {
      _fetchReportData();
    });
  }
  
  @override
  void dispose() {
    _insightsController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          // Use 'createAt' or 'createdAt' depending on what's in your SharedPreferences
          _storeId = prefs.getString('createAt') ?? prefs.getString('createdAt') ?? '';
          print('Loaded store ID for Reports: $_storeId');
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

  // Fetch data from Firebase for reports
  Future<void> _fetchReportData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (_storeId.isEmpty) {
        print('Store ID is empty, using empty data');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Fetch orders data
      final ordersData = await _fetchOrdersFromFirebase();
      
      if (!mounted) return;
      
      // Process data for reports
      if (ordersData != null && ordersData.isNotEmpty) {
        _processReportData(ordersData);
      } else {
        // No data available - set default empty state
        _setEmptyData();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching report data: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        errorMessage = 'Failed to load report data: $e';
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchOrdersFromFirebase() async {
    if (_storeId.isEmpty) {
      return null;
    }
    
    try {
      final baseUrl = Cred.FIREBASE_DATABASE_URL;
      String? tokenId = await FirebaseManager().refreshIdTokenAndSave();
      
      // Calculate date range based on the selected timeframe
      
      // Query orders path with date filtering if your database supports it
      final ordersPath = '$_storeId/orders.json?auth=$tokenId';
      print('Fetching orders from: $baseUrl/$ordersPath');
      
      final response = await http.get(Uri.parse('$baseUrl/$ordersPath'));
      
      if (response.statusCode == 200) {
        if (response.body == 'null') {
          print('No orders found (null response)');
          return null;
        }
        
        final Map<String, dynamic> ordersData = json.decode(response.body);
        if (ordersData.isEmpty) {
          print('No orders found (empty data)');
          return null;
        }
        
        // We'll filter by date in the processing step
        return ordersData;
      } else {
        print('Error response: ${response.statusCode}, ${response.body}');
        
        // Try alternate path as fallback (like in ManagerHome)
        final alternateOrdersPath = '$_storeId/order.json?auth=$tokenId';
        print('Attempting alternate path: $baseUrl$alternateOrdersPath');
        
        final altResponse = await http.get(Uri.parse('$baseUrl$alternateOrdersPath'));
        
        if (altResponse.statusCode == 200 && altResponse.body != 'null') {
          final Map<String, dynamic> ordersData = json.decode(altResponse.body);
          if (ordersData.isNotEmpty) {
            return ordersData;
          }
        }
        
        throw Exception('Failed to load order data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _fetchOrdersFromFirebase: $e');
      throw Exception('Error fetching orders: $e');
    }
  }
  
  DateTime _getStartDateForTimeFrame() {
    final now = DateTime.now();
    
    switch (selectedTimeFrame) {
      case 'Daily':
        return DateTime(now.year, now.month, now.day); // Today
      case 'Weekly':
        return now.subtract(const Duration(days: 7));
      case 'Monthly':
        return DateTime(now.year, now.month - 1, now.day);
      case 'Yearly':
        return DateTime(now.year - 1, now.month, now.day);
      case 'Custom':
        return _dateRange.start;
      default:
        return DateTime(now.year, now.month, now.day - 7); // Default to weekly
    }
  }

  void _processReportData(Map<String, dynamic> ordersData) {
    // Clear existing data
    salesData = [];
    categories = [];
    topItems = [];
    insights = [];
    
    // Track category data
    Map<String, double> categoryTotals = {};
    Map<String, int> categoryItemCount = {};
    
    // Track items data
    Map<String, Map<String, dynamic>> itemsSold = {};
    
    // Track daily sales
    Map<String, double> dailySales = {};
    Map<String, int> dailyOrders = {};
    
    // Calculate start date based on selected time frame
    DateTime startDate = _getStartDateForTimeFrame();
    final endDate = DateTime.now();

    // For comparison data
    Map<String, double> prevPeriodSales = {};
    DateTime? prevStartDate;
    DateTime? prevEndDate;
    
    if (_isComparison && _comparisonDateRange != null) {
      prevStartDate = _comparisonDateRange!.start;
      prevEndDate = _comparisonDateRange!.end;
    }
    
    double totalSales = 0;
    int totalOrders = 0;
    Set<String> customerIds = {}; // For unique customer count
    
    // Day names for the chart
    List<String> dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Initialize daily sales with 0 for all days
    for (var day in dayNames) {
      dailySales[day] = 0;
      dailyOrders[day] = 0;
      
      if (_isComparison) {
        prevPeriodSales[day] = 0;
      }
    }

    // Process each order
    ordersData.forEach((orderId, orderData) {
      try {
        // Parse timestamp
        if (!orderData.containsKey('timestamp')) return;
        
        DateTime orderDate;
        try {
          orderDate = DateTime.parse(orderData['timestamp']);
        } catch (e) {
          try {
            orderDate = DateTime.parse(orderData['timestamp'].replaceAll(' ', 'T'));
          } catch (e) {
            final parts = orderData['timestamp'].toString().split(' ');
            if (parts.isNotEmpty) {
              try {
                orderDate = DateTime.parse(parts[0]);
              } catch (e) {
                print('Error parsing date: ${orderData['timestamp']}');
                return;
              }
            } else {
              print('Error parsing date: ${orderData['timestamp']}');
              return;
            }
          }
        }
        
        // Check if order is within current date range
        bool isInCurrentPeriod = (orderDate.isAfter(startDate) || orderDate.isAtSameMomentAs(startDate)) && 
                                (orderDate.isBefore(endDate) || orderDate.isAtSameMomentAs(endDate));
                                
        // Check if order is within comparison date range
        bool isInPrevPeriod = _isComparison && prevStartDate != null && prevEndDate != null &&
                            (orderDate.isAfter(prevStartDate) || orderDate.isAtSameMomentAs(prevStartDate)) && 
                            (orderDate.isBefore(prevEndDate) || orderDate.isAtSameMomentAs(prevEndDate));
        
        if (!isInCurrentPeriod && !isInPrevPeriod) return;
        
        // Process order data
        double orderAmount = 0.0;
        if (orderData.containsKey('totalAmount')) {
          orderAmount = _parseDouble(orderData['totalAmount']);
        } else if (orderData.containsKey('total')) {
          orderAmount = _parseDouble(orderData['total']);
        }
        
        // Add to totals for the current period
        if (isInCurrentPeriod) {
          totalSales += orderAmount;
          totalOrders++;
          
          // Add to customer IDs if available
          if (orderData.containsKey('userId')) {
            customerIds.add(orderData['userId'].toString());
          }
          
          // Process daily data
          String dayName = dayNames[orderDate.weekday - 1]; // 1-based to 0-based
          dailySales[dayName] = (dailySales[dayName] ?? 0) + orderAmount;
          dailyOrders[dayName] = (dailyOrders[dayName] ?? 0) + 1;
          
          // Process items
          if (orderData.containsKey('items') && orderData['items'] is List) {
            List items = orderData['items'];
            for (var item in items) {
              if (item is Map) {
                // Get item details
                String itemName = item.containsKey('name') ? item['name'].toString() : 'Unknown';
                String category = item.containsKey('category') ? item['category'].toString() : 'Uncategorized';
                double price = _parseDouble(item['price']);
                int quantity = _parseQuantity(item);
                String image = item.containsKey('image') ? item['image'].toString() : '';
                
                // Add to categories
                categoryTotals[category] = (categoryTotals[category] ?? 0) + (price * quantity);
                categoryItemCount[category] = (categoryItemCount[category] ?? 0) + quantity;
                
                // Update item sold data
                if (!itemsSold.containsKey(itemName)) {
                  itemsSold[itemName] = {
                    'name': itemName,
                    'qty': 0,
                    'revenue': 0.0,
                    'category': category,
                    'image': image,
                  };
                }
                
                itemsSold[itemName]!['qty'] = (itemsSold[itemName]!['qty'] as int) + quantity;
                itemsSold[itemName]!['revenue'] = (itemsSold[itemName]!['revenue'] as double) + (price * quantity);
                
                // Make sure we add the category to the categories dropdown
                if (!_categories.contains(category) && category != '') {
                  _categories.add(category);
                }
              }
            }
          }
        }
        
        // Process data for comparison period
        if (isInPrevPeriod) {
          String dayName = dayNames[orderDate.weekday - 1];
          prevPeriodSales[dayName] = (prevPeriodSales[dayName] ?? 0) + orderAmount;
        }
      } catch (e) {
        print('Error processing order $orderId: $e');
      }
    });
    
    // Build salesData array for charts
    salesData = dayNames.map((day) {
      return {
        'day': day,
        'sales': dailySales[day]?.round() ?? 0,
        'prevSales': prevPeriodSales[day]?.round() ?? 0,
        'orders': dailyOrders[day] ?? 0,
        'prevOrders': 0, // We don't have this data currently
      };
    }).toList();
    
    // Calculate total previous period sales for comparison
    double prevTotalSales = 0;
    prevPeriodSales.forEach((day, value) {
      prevTotalSales += value;
    });
    
    // Build categories list
    double totalCategorySales = categoryTotals.values.fold(0, (sum, value) => sum + value);
    categories = categoryTotals.entries.map((entry) {
      double percentage = totalCategorySales > 0 ? (entry.value / totalCategorySales * 100).round().toDouble() : 0;
      
      // Assign colors based on category
      Color categoryColor;
      switch (entry.key) {
        case 'Fast Food':
          categoryColor = Colors.blue;
          break;
        case 'Beverages':
          categoryColor = Colors.orange;
          break;
        case 'Desserts':
          categoryColor = Colors.green;
          break;
        case 'Main Course':
          categoryColor = Colors.purple;
          break;
        default:
          // Generate a random color for other categories
          final colorIndex = entry.key.hashCode % Colors.primaries.length;
          categoryColor = Colors.primaries[colorIndex];
      }
      
      return {
        'name': entry.key,
        'sales': 'Rs. ${NumberFormat('#,###').format(entry.value.round())}',
        'percentage': percentage.toInt(),
        'color': categoryColor,
        'growth': '+0%', // We don't have historical data yet to calculate growth
      };
    }).toList();
    
    // Sort categories by percentage (descending)
    categories.sort((a, b) => b['percentage'].compareTo(a['percentage']));
    
    // Build top items list
    topItems = itemsSold.values.toList();
    topItems.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    
    // Format revenue values and add growth placeholder
    for (var item in topItems) {
      item['revenue'] = 'Rs. ${NumberFormat('#,###').format((item['revenue'] as double).round())}';
      item['growth'] = '+0%'; // Placeholder - would need historical data
    }
    
    // Take top 5 items or less if fewer are available
    if (topItems.length > 5) {
      topItems = topItems.sublist(0, 5);
    }
    
    // Calculate key insights
    String highestSalesDay = 'None';
    double highestSalesAmount = 0;
    dailySales.forEach((day, amount) {
      if (amount > highestSalesAmount) {
        highestSalesDay = day;
        highestSalesAmount = amount;
      }
    });
    
    String bestCategory = categories.isNotEmpty ? categories[0]['name'] : 'None';
    String bestCategoryPercentage = categories.isNotEmpty ? '${categories[0]['percentage']}%' : '0%';
    
    String bestItem = topItems.isNotEmpty ? topItems[0]['name'] : 'None';
    String bestItemSales = topItems.isNotEmpty 
        ? '${topItems[0]['qty']} units (${topItems[0]['revenue']})'
        : '0 units (Rs. 0)';
    
    // Build insights
    insights = [
      {
        'title': 'Highest sales day',
        'value': highestSalesDay,
        'subtitle': 'Rs. ${NumberFormat('#,###').format(highestSalesAmount.round())}',
      },
      {
        'title': 'Best performing category',
        'value': bestCategory,
        'subtitle': '$bestCategoryPercentage of total sales',
      },
      {
        'title': 'Best-selling item',
        'value': bestItem,
        'subtitle': bestItemSales,
      },
      {
        'title': 'Total customers',
        'value': customerIds.length.toString(),
        'subtitle': 'Unique customers in period',
      },
    ];
    
    // Update summary metrics
    summaryMetrics = {
      'totalSales': totalSales,
      'totalOrders': totalOrders,
      'avgOrderValue': totalOrders > 0 ? totalSales / totalOrders : 0,
      'customerVisits': customerIds.length,
    };
    
    // Calculate growth percentages if comparison is active
    if (_isComparison) {
      double salesGrowth = prevTotalSales > 0 
          ? ((totalSales - prevTotalSales) / prevTotalSales * 100)
          : 0;
          
      // Update first insight with comparison
      if (insights.isNotEmpty) {
        insights[0]['subtitle'] = 'Rs. ${NumberFormat('#,###').format(highestSalesAmount.round())} (${_formatGrowth(salesGrowth)}% from last period)';
      }
    }
  }
  
  String _formatGrowth(double growth) {
    return growth >= 0 ? '+${growth.toStringAsFixed(1)}' : growth.toStringAsFixed(1);
  }
  
  void _setEmptyData() {
    // Default data for when no orders are available
    // Initialize with zeros or placeholders
    
    // Create empty sales data for each day
    List<String> dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    salesData = dayNames.map((day) {
      return {
        'day': day,
        'sales': 0,
        'prevSales': 0,
        'orders': 0,
        'prevOrders': 0,
      };
    }).toList();
    
    // Create empty categories
    categories = [
      {'name': 'No data', 'sales': 'Rs. 0', 'percentage': 100, 'color': Colors.grey, 'growth': '0%'},
    ];
    
    // Empty top items
    topItems = [];
    
    // Empty insights
    insights = [
      {'title': 'No data available', 'value': 'No orders found', 'subtitle': 'Try selecting a different date range'},
    ];
    
    // Reset summary metrics
    summaryMetrics = {
      'totalSales': 0.0,
      'totalOrders': 0,
      'avgOrderValue': 0.0,
      'customerVisits': 0,
    };
  }
  
  // Helper method to parse double values
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
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading ? _buildLoadingView() : _buildReportContent(),
        ),
      ),
      floatingActionButton: !_isLoading ? _buildFloatingActionButton() : null,
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showReportOptions(context),
      icon: const Icon(Icons.download),
      label: const Text("Export Report"),
      backgroundColor: Theme.of(context).primaryColor,
    ).animate().scale(delay: 1500.ms, duration: 400.ms);
  }

  void _showReportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export as PDF'),
              subtitle: const Text('Save report as PDF document'),
              onTap: () {
                Navigator.pop(context);
                _generatePdf(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text('Print Report'),
              subtitle: const Text('Send report to printer'),
              onTap: () {
                Navigator.pop(context);
                _printReport(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text('Share Report'),
              subtitle: const Text('Share report with others'),
              onTap: () {
                Navigator.pop(context);
                // Implement share functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sharing report...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context) async {
    final pdf = pw.Document();
    
    // Add content to PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sales Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                DateFormat('MMM d, yyyy').format(_dateRange.start) + 
                ' - ' + 
                DateFormat('MMM d, yyyy').format(_dateRange.end),
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Footer(
          title: pw.Text(
            'Generated on ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())} | Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 20),
          
          // Summary Section
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfSummaryItem('Total Sales', 'Rs. ${NumberFormat('#,###').format(summaryMetrics['totalSales'].round())}'),
                    _pdfSummaryItem('Total Orders', summaryMetrics['totalOrders'].toString()),
                    _pdfSummaryItem('Avg. Order Value', 'Rs. ${NumberFormat('#,###').format(summaryMetrics['avgOrderValue'].round())}'),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Category Distribution
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Category Distribution', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _pdfTableCell('Category', isHeader: true),
                        _pdfTableCell('Revenue', isHeader: true),
                        _pdfTableCell('Percentage', isHeader: true),
                        _pdfTableCell('Growth', isHeader: true),
                      ],
                    ),
                    // Data rows
                    ...categories.map((category) => pw.TableRow(
                      children: [
                        _pdfTableCell(category['name']),
                        _pdfTableCell(category['sales']),
                        _pdfTableCell('${category['percentage']}%'),
                        _pdfTableCell(category['growth']),
                      ],
                    )).toList(),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Top Selling Items
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Top Selling Items', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                topItems.isEmpty
                ? pw.Text('No items data available for this period', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))
                : pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _pdfTableCell('Item', isHeader: true),
                        _pdfTableCell('Category', isHeader: true),
                        _pdfTableCell('Quantity', isHeader: true),
                        _pdfTableCell('Revenue', isHeader: true),
                        _pdfTableCell('Growth', isHeader: true),
                      ],
                    ),
                    // Data rows
                    ...topItems.map((item) => pw.TableRow(
                      children: [
                        _pdfTableCell(item['name']),
                        _pdfTableCell(item['category']),
                        _pdfTableCell(item['qty'].toString()),
                        _pdfTableCell(item['revenue']),
                        _pdfTableCell(item['growth']),
                      ],
                    )).toList(),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Daily Sales
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Daily Sales Breakdown', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _pdfTableCell('Day', isHeader: true),
                        _pdfTableCell('Sales', isHeader: true),
                        _pdfTableCell('Orders', isHeader: true),
                      ],
                    ),
                    // Data rows
                    ...salesData.map((day) => pw.TableRow(
                      children: [
                        _pdfTableCell(day['day']),
                        _pdfTableCell('Rs. ${day['sales']}'),
                        _pdfTableCell(day['orders'].toString()),
                      ],
                    )).toList(),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Key Insights
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Key Insights', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                ...insights.map((insight) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(insight['title'], style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      pw.Text(insight['value'], style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text(insight['subtitle'], style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Divider(),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
    
    // Show PDF preview
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sales Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );
  }
  
  pw.Widget _pdfSummaryItem(String title, String value) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
  
  pw.Widget _pdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  Future<void> _printReport(BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final pdf = pw.Document();
        
        // Add the same content as in _generatePdf method
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            header: (context) => pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sales Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    DateFormat('MMM d, yyyy').format(_dateRange.start) + 
                    ' - ' + 
                    DateFormat('MMM d, yyyy').format(_dateRange.end),
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            footer: (context) => pw.Footer(
              title: pw.Text(
                'Generated on ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())} | Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            build: (context) => [
              pw.SizedBox(height: 20),
              
              // Summary Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _pdfSummaryItem('Total Sales', 'Rs. ${NumberFormat('#,###').format(summaryMetrics['totalSales'].round())}'),
                        _pdfSummaryItem('Total Orders', summaryMetrics['totalOrders'].toString()),
                        _pdfSummaryItem('Avg. Order Value', 'Rs. ${NumberFormat('#,###').format(summaryMetrics['avgOrderValue'].round())}'),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Category Distribution
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Category Distribution', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      children: [
                        // Header
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _pdfTableCell('Category', isHeader: true),
                            _pdfTableCell('Revenue', isHeader: true),
                            _pdfTableCell('Percentage', isHeader: true),
                            _pdfTableCell('Growth', isHeader: true),
                          ],
                        ),
                        // Data rows
                        ...categories.map((category) => pw.TableRow(
                          children: [
                            _pdfTableCell(category['name']),
                            _pdfTableCell(category['sales']),
                            _pdfTableCell('${category['percentage']}%'),
                            _pdfTableCell(category['growth']),
                          ],
                        )).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Top Selling Items
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Top Selling Items', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    topItems.isEmpty
                    ? pw.Text('No items data available for this period', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))
                    : pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      children: [
                        // Header
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _pdfTableCell('Item', isHeader: true),
                            _pdfTableCell('Category', isHeader: true),
                            _pdfTableCell('Quantity', isHeader: true),
                            _pdfTableCell('Revenue', isHeader: true),
                            _pdfTableCell('Growth', isHeader: true),
                          ],
                        ),
                        // Data rows
                        ...topItems.map((item) => pw.TableRow(
                          children: [
                            _pdfTableCell(item['name']),
                            _pdfTableCell(item['category']),
                            _pdfTableCell(item['qty'].toString()),
                            _pdfTableCell(item['revenue']),
                            _pdfTableCell(item['growth']),
                          ],
                        )).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Daily Sales
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Daily Sales Breakdown', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      children: [
                        // Header
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _pdfTableCell('Day', isHeader: true),
                            _pdfTableCell('Sales', isHeader: true),
                            _pdfTableCell('Orders', isHeader: true),
                          ],
                        ),
                        // Data rows
                        ...salesData.map((day) => pw.TableRow(
                          children: [
                            _pdfTableCell(day['day']),
                            _pdfTableCell('Rs. ${day['sales']}'),
                            _pdfTableCell(day['orders'].toString()),
                          ],
                        )).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Key Insights
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Key Insights', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    ...insights.map((insight) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(insight['title'], style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                          pw.Text(insight['value'], style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.Text(insight['subtitle'], style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                          pw.Divider(),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
        
        return pdf.save();
      },
      name: 'Sales Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );
  }

  Widget _buildLoadingView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerHeader(),
          const SizedBox(height: 20),
          _buildShimmerChart(),
          const SizedBox(height: 30),
          _buildShimmerCategoryTitle(),
          const SizedBox(height: 16),
          _buildShimmerCategories(),
          const SizedBox(height: 30),
          _buildShimmerActions(),
        ],
      ),
    );
  }

  Widget _buildShimmerHeader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 30,
            width: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
          ),
          Container(
            height: 30,
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerChart() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildShimmerCategoryTitle() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 24,
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildShimmerCategories() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 16,
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      height: 16,
                      width: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShimmerActions() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return Container(
            height: 40,
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildReportContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader()
            .animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: -0.2, end: 0),
          const SizedBox(height: 20),
          
          // Enhanced filtering options
          _buildFilters()
            .animate()
            .fadeIn(delay: 200.ms, duration: 600.ms),
          const SizedBox(height: 20),
          
          // Insight cards
          _buildInsightCards()
            .animate()
            .fadeIn(delay: 300.ms, duration: 600.ms),
          const SizedBox(height: 20),
          
          // Tab Navigation
          _buildTabNavigation()
            .animate()
            .fadeIn(delay: 400.ms, duration: 600.ms),
          const SizedBox(height: 20),
          
          // Chart & Analytics
          _buildChartSelector()
            .animate()
            .fadeIn(delay: 500.ms, duration: 600.ms),
          const SizedBox(height: 20),
          
          // Side by side chart and top categories
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildChart()
                        .animate()
                        .fadeIn(delay: 600.ms, duration: 800.ms)
                        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Categories',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          )
                              .animate()
                              .fadeIn(delay: 800.ms, duration: 600.ms),
                          const SizedBox(height: 16),
                          _buildCategoryStats()
                              .animate()
                              .fadeIn(delay: 900.ms, duration: 600.ms),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChart()
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 800.ms)
                      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                    const SizedBox(height: 20),
                    Text(
                      'Top Categories',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 800.ms, duration: 600.ms),
                    const SizedBox(height: 16),
                    _buildCategoryStats()
                        .animate()
                        .fadeIn(delay: 900.ms, duration: 600.ms),
                  ],
                );
              }
            }
          ),
          
          const SizedBox(height: 30),
          // Key Metrics summary
          _buildMetricsCards(context)
            .animate()
            .fadeIn(delay: 1000.ms, duration: 600.ms),
          
          const SizedBox(height: 30),
          // Top selling items
          _buildTopItems()
            .animate()
            .fadeIn(delay: 1100.ms, duration: 600.ms),
          
          const SizedBox(height: 30),
          
          // Show current user and date info in footer
          _buildFooterInfo()
            .animate()
            .fadeIn(delay: 1200.ms, duration: 600.ms),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }
  
  Widget _buildFooterInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report generated by: navin280123',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generated on: ${DateFormat('MMMM d, yyyy h:mm a').format(DateTime.now())}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Reports',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Generated on ${DateFormat('EEEE, MMM d, yyyy').format(DateTime.now())}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        _buildDateRangeSelector(),
      ],
    );
  }
  
  Widget _buildDateRangeSelector() {
    return GestureDetector(
      onTap: () => _showDateRangePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(25),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range, size: 20),
            const SizedBox(width: 8),
            Text(
              '${DateFormat('MMM d').format(_dateRange.start)} - ${DateFormat('MMM d').format(_dateRange.end)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
  
  void _showDateRangePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: SfDateRangePicker(
            view: DateRangePickerView.month,
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: PickerDateRange(
              _dateRange.start,
              _dateRange.end,
            ),
            showActionButtons: true,
            onCancel: () => Navigator.pop(context),
            onSubmit: (Object? value) {
              if (value is PickerDateRange) {
                if (value.startDate != null && value.endDate != null) {
                  setState(() {
                    _dateRange = DateTimeRange(
                      start: value.startDate!,
                      end: value.endDate!,
                    );
                    selectedTimeFrame = 'Custom';
                  });
                  
                  // Refresh data with new date range
                  _fetchReportData();
                }
              }
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: [
        // Timeframe selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButton<String>(
            value: selectedTimeFrame,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            underline: const SizedBox(),
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  selectedTimeFrame = newValue;
                  
                  // If custom selected, show date picker
                  if (newValue == 'Custom') {
                    _showDateRangePicker(context);
                  } else {
                    // Otherwise refresh with standard time range
                    _fetchReportData();
                  }
                });
              }
            },
            items: timeFrames.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
        
        // Category filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButton<String>(
            value: _selectedCategory,
            hint: const Text('Select Category'),
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            underline: const SizedBox(),
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedCategory = newValue;
                  // No need to refresh data, just filter the existing data in the UI
                });
              }
            },
            items: _categories.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
        
        // Comparison toggle
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: _isComparison,
                onChanged: (value) {
                  setState(() {
                    _isComparison = value;
                    
                    // If enabling comparison, show date picker for comparison period
                    if (value) {
                      _showComparisonDatePicker();
                    } else {
                      _comparisonDateRange = null;
                    }
                    
                    // Refresh data to include comparison
                                        // Refresh data to include comparison
                    _fetchReportData();
                  });
                },
                activeColor: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Compare',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        
        // Refresh button
        ElevatedButton.icon(
          onPressed: _fetchReportData,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }
  
  void _showComparisonDatePicker() {
    // Calculate default previous period
    final Duration periodDuration = _dateRange.end.difference(_dateRange.start);
    final DateTime defaultPrevStart = _dateRange.start.subtract(periodDuration);
    final DateTime defaultPrevEnd = _dateRange.start.subtract(const Duration(days: 1));
    
    setState(() {
      _comparisonDateRange = DateTimeRange(
        start: defaultPrevStart,
        end: defaultPrevEnd,
      );
    });
    
    // Show dialog to customize the comparison period
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Comparison Period'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: SfDateRangePicker(
            view: DateRangePickerView.month,
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: PickerDateRange(
              defaultPrevStart,
              defaultPrevEnd,
            ),
            showActionButtons: true,
            onCancel: () => Navigator.pop(context),
            onSubmit: (Object? value) {
              if (value is PickerDateRange) {
                if (value.startDate != null && value.endDate != null) {
                  setState(() {
                    _comparisonDateRange = DateTimeRange(
                      start: value.startDate!,
                      end: value.endDate!,
                    );
                  });
                  
                  // Refresh data with comparison
                  _fetchReportData();
                }
              }
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildInsightCards() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: insights.length,
        itemBuilder: (context, index) {
          final insight = insights[index];
          return Container(
            width: 230,
            margin: EdgeInsets.only(right: index < insights.length - 1 ? 12 : 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  insight['title'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  insight['value'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  insight['subtitle'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (300 + index * 100).ms, duration: 400.ms)
           .slideX(begin: 0.2, end: 0);
        },
      ),
    );
  }
  
  Widget _buildTabNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          _tabNames.length,
          (index) => GestureDetector(
            onTap: () {
              setState(() {
                _currentTabIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _currentTabIndex == index
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _tabNames[index],
                style: TextStyle(
                  color: _currentTabIndex == index
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
                .animate(target: _currentTabIndex == index ? 1 : 0)
                .scaleXY(end: 1.05, duration: 200.ms)
                .then()
                .scaleXY(end: 1.0, duration: 200.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildChartSelector() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          _chartTypes.length,
          (index) => GestureDetector(
            onTap: () {
              setState(() {
                _selectedChartTypeIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedChartTypeIndex == index
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _chartTypes[index],
                style: TextStyle(
                  color: _selectedChartTypeIndex == index
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
                .animate(target: _selectedChartTypeIndex == index ? 1 : 0)
                .scaleXY(end: 1.05, duration: 200.ms)
                .then()
                .scaleXY(end: 1.0, duration: 200.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    return Container(
      height: 450,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentTabIndex == 0 ? 'Sales Overview' : 
                _currentTabIndex == 1 ? 'Order Trends' :
                _currentTabIndex == 2 ? 'Customer Activity' : 'Item Performance',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isComparison && _comparisonDateRange != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.compare_arrows, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text(
                        'vs ${DateFormat('MMM d').format(_comparisonDateRange!.start)} - ${DateFormat('MMM d').format(_comparisonDateRange!.end)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Main chart content
          Expanded(
            child: _selectedChartTypeIndex == 3 ? _buildDataTable() : _getSelectedChart(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDataTable() {
    // Different table based on selected tab
    switch (_currentTabIndex) {
      case 0: // Sales
        return SingleChildScrollView(
          child: DataTable(
            columnSpacing: 20,
            horizontalMargin: 10,
            headingRowColor: MaterialStateColor.resolveWith((states) => Colors.grey[100]!),
            columns: const [
              DataColumn(label: Text('Day')),
              DataColumn(label: Text('Sales'), numeric: true),
              DataColumn(label: Text('Orders'), numeric: true),
              DataColumn(label: Text('Avg. Order'), numeric: true),
            ],
            rows: List.generate(
              salesData.length,
              (index) => DataRow(
                cells: [
                  DataCell(Text(salesData[index]['day'])),
                  DataCell(Text('Rs. ${salesData[index]['sales']}')),
                  DataCell(Text('${salesData[index]['orders']}')),
                  DataCell(Text(
                    salesData[index]['orders'] > 0 
                      ? 'Rs. ${(salesData[index]['sales'] / salesData[index]['orders']).round()}'
                      : 'Rs. 0'
                  )),
                ],
              ),
            ),
          ),
        );
      
      case 3: // Items
        return SingleChildScrollView(
          child: topItems.isEmpty
            ? Center(child: Text('No item data available for this period', style: TextStyle(color: Colors.grey[600])))
            : DataTable(
                columnSpacing: 20,
                horizontalMargin: 10,
                headingRowColor: MaterialStateColor.resolveWith((states) => Colors.grey[100]!),
                columns: const [
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Qty'), numeric: true),
                  DataColumn(label: Text('Revenue'), numeric: true),
                ],
                rows: List.generate(
                  topItems.length,
                  (index) => DataRow(
                    cells: [
                      DataCell(Text(topItems[index]['name'])),
                      DataCell(Text(topItems[index]['category'])),
                      DataCell(Text('${topItems[index]['qty']}')),
                      DataCell(Text(topItems[index]['revenue'])),
                    ],
                  ),
                ),
              ),
        );
        
      default:
        return const Center(child: Text('No table data available'));
    }
  }

  Widget _getSelectedChart() {
    switch (_selectedChartTypeIndex) {
      case 0:
        return _buildBarChart();
      case 1:
        return _buildLineChart();
      case 2:
        return _buildPieChart();
      default:
        return _buildBarChart();
    }
  }

  Widget _buildBarChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 6000,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    'Rs. ${salesData[groupIndex]['sales']}',
                    const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(
                      salesData[value.toInt()]['day'],
                      style: TextStyle(
                        color: const Color(0xff7589a2),
                        fontWeight: FontWeight.bold,
                        fontSize: constraints.maxWidth > 800 ? 16 : 12,
                      ),
                    ),
                  ),
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 1000,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(
                      value == 0 ? '0' : '${(value / 1000).toInt()}K',
                      style: TextStyle(
                        color: const Color(0xff7589a2),
                        fontWeight: FontWeight.bold,
                        fontSize: constraints.maxWidth > 800 ? 14 : 10,
                      ),
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: _isComparison 
              ? List.generate(
                  salesData.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: salesData[index]['sales'].toDouble(),
                        color: Theme.of(context).primaryColor,
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: salesData[index]['prevSales'].toDouble(),
                        color: Colors.grey[400],
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                    barsSpace: 4,
                  ),
                )
              : List.generate(
                  salesData.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: salesData[index]['sales'].toDouble(),
                        color: Theme.of(context).primaryColor,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 6000,
                          color: Colors.grey.withAlpha(25),
                        ),
                      ),
                    ],
                  ),
                ),
            gridData: FlGridData(
              show: true,
              checkToShowHorizontalLine: (value) => value % 1000 == 0,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withAlpha(51),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLineChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return LineChart(
          LineChartData(
            lineTouchData: LineTouchData(handleBuiltInTouches: true),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1000,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.withAlpha(51),
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      salesData[value.toInt()]['day'],
                      style: TextStyle(
                        color: const Color(0xff7589a2),
                        fontWeight: FontWeight.bold,
                        fontSize: constraints.maxWidth > 800 ? 16 : 12,
                      ),
                    ),
                  ),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1000,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      value == 0 ? '0' : '${(value / 1000).toInt()}K',
                      style: TextStyle(
                        color: const Color(0xff7589a2),
                        fontWeight: FontWeight.bold,
                        fontSize: constraints.maxWidth > 800 ? 14 : 10,
                      ),
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: salesData.length - 1.0,
            minY: 0,
            maxY: 6000,
            lineBarsData: _isComparison 
              ? [
                  // Current period line
                  LineChartBarData(
                    spots: List.generate(
                      salesData.length,
                      (index) => FlSpot(index.toDouble(), salesData[index]['sales'].toDouble()),
                    ),
                    isCurved: true,
                    color: Theme.of(context).primaryColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).primaryColor.withAlpha(40),
                    ),
                  ),
                  // Previous period line (comparison)
                  LineChartBarData(
                    spots: List.generate(
                      salesData.length,
                      (index) => FlSpot(index.toDouble(), salesData[index]['prevSales'].toDouble()),
                    ),
                    isCurved: true,
                    color: Colors.grey[400],
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                ]
              : [
                  LineChartBarData(
                    spots: List.generate(
                      salesData.length,
                      (index) => FlSpot(index.toDouble(), salesData[index]['sales'].toDouble()),
                    ),
                    isCurved: true,
                    color: Theme.of(context).primaryColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).primaryColor.withAlpha(51),
                    ),
                  ),
                ],
          ),
        );
      },
    );
  }

  Widget _buildPieChart() {
    // No data check
    if (categories.isEmpty || categories.every((category) => category['percentage'] == 0)) {
      return Center(child: Text('No category data available', style: TextStyle(color: Colors.grey[600])));
    }
    
    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 70,
              sections: List.generate(
                categories.length,
                (index) => PieChartSectionData(
                  color: categories[index]['color'],
                  value: categories[index]['percentage'].toDouble(),
                  title: '${categories[index]['percentage']}%',
                  radius: 100,
                  titleStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: categories.map((category) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: category['color'],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  category['name'],
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildMetricsCards(BuildContext context) {
    final List<Map<String, dynamic>> summaries = [
      {
        'title': 'Total Sales',
        'value': 'Rs. ${NumberFormat('#,###').format(summaryMetrics['totalSales'].round())}',
        'change': '+8.2%',
        'isPositive': true,
        'icon': Icons.trending_up,
      },
      {
        'title': 'Orders',
        'value': '${summaryMetrics['totalOrders']}',
        'change': '+12.5%',
        'isPositive': true,
        'icon': Icons.shopping_bag,
      },
      {
        'title': 'Avg. Order Value',
        'value': 'Rs. ${NumberFormat('#,###').format(summaryMetrics['avgOrderValue'].round())}',
        'change': '-2.1%',
        'isPositive': false,
        'icon': Icons.attach_money,
      },
      {
        'title': 'Customer Visits',
        'value': '${summaryMetrics['customerVisits']}',
        'change': '+5.7%',
        'isPositive': true,
        'icon': Icons.people,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Key Metrics',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                _isComparison ? 'vs Previous Period' : DateFormat('MMMM yyyy').format(_dateRange.start),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate how many cards per row based on available width
              int cardsPerRow = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 650 ? 2 : 1;
              
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(summaries.length, (index) {
                  final item = summaries[index];
                  
                  return SizedBox(
                    width: (constraints.maxWidth / cardsPerRow) - (12 * (cardsPerRow - 1) / cardsPerRow),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(25),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['title'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Icon(
                                item['icon'],
                                color: Theme.of(context).primaryColor,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['value'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item['isPositive']
                                      ? Colors.green.withAlpha(25)
                                      : Colors.red.withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item['change'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: item['isPositive']
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().scale(delay: (index * 100).ms, duration: 400.ms, begin: const Offset(0.95, 0.95));
                }),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStats() {
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            'No category data available for this period',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }
    
    return Column(
      children: categories.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> category = entry.value;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(12),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: category['color'],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category['name'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          category['sales'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: category['growth'].toString().contains('-')
                                ? Colors.red.withAlpha(25)
                                : Colors.green.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category['growth'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: category['growth'].toString().contains('-')
                                  ? Colors.red[700]
                                  : Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      width: MediaQuery.of(context).size.width *
                          (category['percentage'] as int) / 100 * 0.83,
                      height: 8,
                      decoration: BoxDecoration(
                        color: category['color'],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ).animate(delay: (100 * index).ms).slideX(
                          begin: -1,
                          end: 0,
                          duration: 600.ms,
                          curve: Curves.easeOut,
                        ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${category['percentage']}% of total sales',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 200).ms, duration: 400.ms)
         .slideY(begin: 0.2, end: 0);
      }).toList(),
    );
  }
  
  Widget _buildTopItems() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Selling Items',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  underline: const SizedBox(),
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    }
                  },
                  items: _categories.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // If no items are available
          if (topItems.isEmpty)
            Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No items data available for the selected period',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: List.generate(
                topItems.length,
                (index) {
                  final item = topItems[index];
                  if (_selectedCategory != 'All Categories' && 
                      item['category'] != _selectedCategory) {
                    return const SizedBox.shrink(); // Skip items that don't match filter
                  }
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: index < topItems.length - 1 ? 12 : 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // Item rank
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: index < 3 ? Theme.of(context).primaryColor : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index < 3 ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Item details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['category'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Item metrics
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item['revenue'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '${item['qty']} units',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item['growth'].toString().contains('-')
                                        ? Colors.red.withAlpha(25)
                                        : Colors.green.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['growth'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: item['growth'].toString().contains('-')
                                          ? Colors.red[700]
                                          : Colors.green[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (index * 100).ms, duration: 400.ms)
                   .slideY(begin: 0.1, end: 0);
                },
              ).where((item) => item is! SizedBox).toList(), // Filter out empty widgets
            ),
          
          // Show message if no items match the filter
          if (_selectedCategory != 'All Categories' && 
              !topItems.any((item) => item['category'] == _selectedCategory) &&
              topItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: Text(
                'No items in the $_selectedCategory category',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
            
          // Last updated timestamp at the bottom
          const SizedBox(height: 16),
          Container(
            alignment: Alignment.centerRight,
            child: Text(
              'Last updated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}