import 'package:canteendesk/API/Cred.dart';
import 'package:canteendesk/Firebase/FirebaseManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// API service class for handling HTTP requests
class ApiService {
  // Base URL of your REST API
  static const String baseUrl = Cred.FIREBASE_DATABASE_URL; // No trailing slash
  Future<String?> idToken = FirebaseManager().refreshIdTokenAndSave();
  // Get store timings
  static Future<Map<String, dynamic>> getStoreTimings(String storeId, String s) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$storeId/store_timings.json?auth=$s'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load store timings: ${response.statusCode}');
    }
  }
  
  // Get store settings
  static Future<Map<String, dynamic>> getStoreSettings(String storeId, String s) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$storeId/store_settings.json?auth=$s'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load store settings: ${response.statusCode}');
    }
  }
  
  // Update store timings
  static Future<bool> updateStoreTimings(String storeId, Map<String, dynamic> data, String s) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$storeId/store_timings.json?auth=$s'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    
    return response.statusCode == 200;
  }
  
  // Update store settings
  static Future<bool> updateStoreSettings(String storeId, Map<String, dynamic> data, String s) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$storeId/store_settings.json?auth=$s'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    
    return response.statusCode == 200;
  }
}

class StoreTiming {
  final String day;
  final bool isOpen;
  final TimeOfDay openTime;
  final TimeOfDay closeTime;
  final bool is24Hours;

  StoreTiming({
    required this.day,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
    this.is24Hours = false,
  });

  // Convert to a Map for REST API
  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'isOpen': isOpen,
      'openTimeHour': openTime.hour,
      'openTimeMinute': openTime.minute,
      'closeTimeHour': closeTime.hour,
      'closeTimeMinute': closeTime.minute,
      'is24Hours': is24Hours,
    };
  }

  // Create from a Map from REST API
  factory StoreTiming.fromMap(Map<String, dynamic> map) {
    return StoreTiming(
      day: map['day'],
      isOpen: map['isOpen'] ?? false,
      openTime: TimeOfDay(hour: map['openTimeHour'] ?? 9, minute: map['openTimeMinute'] ?? 0),
      closeTime: TimeOfDay(hour: map['closeTimeHour'] ?? 18, minute: map['closeTimeMinute'] ?? 0),
      is24Hours: map['is24Hours'] ?? false,
    );
  }

  // Create a copy with modifications
  StoreTiming copyWith({
    bool? isOpen,
    TimeOfDay? openTime,
    TimeOfDay? closeTime,
    bool? is24Hours,
  }) {
    return StoreTiming(
      day: this.day,
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      is24Hours: is24Hours ?? this.is24Hours,
    );
  }
}

class ManagerOperatingHours extends StatefulWidget {
  const ManagerOperatingHours({Key? key}) : super(key: key);

  @override
  ManagerOperatingHoursState createState() => ManagerOperatingHoursState();
}

class ManagerOperatingHoursState extends State<ManagerOperatingHours> with SingleTickerProviderStateMixin {
  late List<StoreTiming> _storeTimings;
  StoreTiming? _selectedDayTiming;
  bool _isLoading = true;
  String _storeId = '';
  bool _storeOpen = true;
  bool _hasChanges = false;
  
  // For animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Keyboard shortcuts
  final Map<ShortcutActivator, VoidCallback> _shortcuts = {};

  // Day names
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  
  // Controllers for the batch edit mode
  late TimeOfDay _batchOpenTime;
  late TimeOfDay _batchCloseTime;
  bool _batchIs24Hours = false;
  List<String> _selectedDaysForBatch = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );
    
    // Initialize with default values
    _storeTimings = _days.map((day) {
      return StoreTiming(
        day: day,
        isOpen: true,
        openTime: TimeOfDay(hour: 9, minute: 0),
        closeTime: TimeOfDay(hour: 18, minute: 0),
        is24Hours: false,
      );
    }).toList();
    
    // Set default batch times
    _batchOpenTime = TimeOfDay(hour: 9, minute: 0);
    _batchCloseTime = TimeOfDay(hour: 18, minute: 0);
    
    // Setup keyboard shortcuts
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS)] = _saveStoreTimings;
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR)] = _loadStoreTimings;
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB)] = _showBatchEditDialog;
    
    // Load data from API
    _loadStoreId();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storeId = prefs.getString('createdAt') ?? '';
    });
    
    if (_storeId.isNotEmpty) {
      _loadStoreTimings();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStoreTimings() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final idToken = await FirebaseManager().refreshIdTokenAndSave();
      // Load global store open setting using REST API
      final settingsResponse = await ApiService.getStoreSettings(_storeId, idToken!);
      
      if (settingsResponse.containsKey('is_open')) {
        setState(() {
          _storeOpen = settingsResponse['is_open'];
        });
      }

      final timingsResponse = await ApiService.getStoreTimings(_storeId, idToken!);
      
      if (timingsResponse.containsKey('timings')) {
        final Map<String, dynamic> data = timingsResponse['timings'];
        List<StoreTiming> timings = [];
        
        for (String day in _days) {
          if (data[day] != null) {
            timings.add(StoreTiming.fromMap(data[day]));
          } else {
            // Default timing if not set
            timings.add(StoreTiming(
              day: day,
              isOpen: true,
              openTime: TimeOfDay(hour: 9, minute: 0),
              closeTime: TimeOfDay(hour: 18, minute: 0),
            ));
          }
        }
        
        setState(() {
          _storeTimings = timings;
          
          // Set initially selected day (current day or Monday)
          final now = DateTime.now();
          final today = DateFormat('EEEE').format(now);
          _selectedDayTiming = timings.firstWhere(
            (timing) => timing.day == today,
            orElse: () => timings.first
          );
          
          _isLoading = false;
          _hasChanges = false;
          _animationController.forward();
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasChanges = false;
          _animationController.forward();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
        duration: Duration(seconds: 5),
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

  Future<void> _saveStoreTimings() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              Text('Saving store hours...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      final idToken = await FirebaseManager().refreshIdTokenAndSave();
      // Save global store open setting using REST API
      await ApiService.updateStoreSettings(_storeId, {'is_open': _storeOpen}, idToken!);

      // Save each day's timing using REST API
      final Map<String, dynamic> timingsMap = {};
      
      for (StoreTiming timing in _storeTimings) {
        timingsMap[timing.day] = timing.toMap();
      }
      
      final result = await ApiService.updateStoreTimings(_storeId, {'timings': timingsMap}, idToken);

      if (result) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Store hours updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        setState(() {
          _hasChanges = false;
        });
      } else {
        throw Exception('Failed to update store hours');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update store hours: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: _saveStoreTimings,
          ),
        ),
      );
    }
  }

  void _updateStoreTiming(int index, StoreTiming newTiming) {
    setState(() {
      _storeTimings[index] = newTiming;
      _hasChanges = true;
      
      // If this is the selected day, update the selection
      if (_selectedDayTiming?.day == newTiming.day) {
        _selectedDayTiming = newTiming;
      }
    });
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    return DateFormat.jm().format(dateTime);
  }

  void _showBatchEditDialog() {
    // Reset batch selections
    _batchOpenTime = TimeOfDay(hour: 9, minute: 0);
    _batchCloseTime = TimeOfDay(hour: 18, minute: 0);
    _batchIs24Hours = false;
    _selectedDaysForBatch = [];
    
    showDialog(
      context: context,
      builder: (context) => BatchEditDialog(
        days: _days,
        onApply: _applyBatchEdit,
      ),
    );
  }
  
  void _applyBatchEdit(List<String> selectedDays, bool is24Hours, TimeOfDay? openTime, TimeOfDay? closeTime) {
    if (selectedDays.isEmpty) return;
    
    setState(() {
      for (String day in selectedDays) {
        final index = _storeTimings.indexWhere((timing) => timing.day == day);
        if (index != -1) {
          _storeTimings[index] = _storeTimings[index].copyWith(
            is24Hours: is24Hours,
            openTime: openTime ?? _storeTimings[index].openTime,
            closeTime: closeTime ?? _storeTimings[index].closeTime,
          );
        }
      }
      
      _hasChanges = true;
      
      // If the selected day was updated, refresh it
      if (_selectedDayTiming != null && selectedDays.contains(_selectedDayTiming!.day)) {
        final index = _storeTimings.indexWhere((timing) => timing.day == _selectedDayTiming!.day);
        if (index != -1) {
          _selectedDayTiming = _storeTimings[index];
        }
      }
    });
  }

  // Select a day from the sidebar
  void _selectDay(StoreTiming timing) {
    setState(() {
      _selectedDayTiming = timing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Operating Hours'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: false,
        actions: [
          // Toolbar actions for desktop
          if (!_isLoading) ...[
            // Refresh button
            Tooltip(
              message: 'Refresh (Ctrl+R)',
              child: IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _loadStoreTimings,
              ),
            ),
            
            // Batch edit button
            Tooltip(
              message: 'Batch Edit Hours (Ctrl+B)',
              child: IconButton(
                icon: Icon(Icons.edit_calendar_outlined),
                onPressed: _showBatchEditDialog,
              ),
            ),
            
            // Save button
            Tooltip(
              message: 'Save Changes (Ctrl+S)',
              child: IconButton(
                icon: Icon(Icons.save),
                onPressed: _hasChanges ? _saveStoreTimings : null,
                color: _hasChanges ? Colors.blue : Colors.grey,
              ),
            ),
            
            // Divider
            VerticalDivider(
              color: Colors.grey.shade300,
              thickness: 1,
              indent: 8,
              endIndent: 8,
            ),
            
            // Help button
            IconButton(
              icon: Icon(Icons.help_outline),
              onPressed: () {
                // Show help dialog
              },
              tooltip: 'Help',
            ),
          ],
          SizedBox(width: 16),
        ],
      ),
      body: FocusableActionDetector(
        child: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Global store status bar
        Container(
          color: Colors.grey.shade50,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Store Status:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 16),
              
              // Store open/closed switch
              ToggleButtons(
                isSelected: [_storeOpen, !_storeOpen],
                onPressed: (index) {
                  setState(() {
                    _storeOpen = index == 0;
                    _hasChanges = true;
                  });
                },
                borderRadius: BorderRadius.circular(30),
                selectedBorderColor: _storeOpen ? Colors.green.shade300 : Colors.red.shade300,
                selectedColor: Colors.white,
                fillColor: _storeOpen ? Colors.green : Colors.red.shade400,
                constraints: BoxConstraints(
                  minWidth: 120,
                  minHeight: 40,
                ),
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline),
                      SizedBox(width: 8),
                      Text('Open'),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.cancel_outlined),
                      SizedBox(width: 8),
                      Text('Closed'),
                    ],
                  ),
                ],
              ),
              
              Spacer(),
              
              // Notification about unsaved changes
              if (_hasChanges)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade800, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Unsaved changes',
                        style: TextStyle(
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              
              SizedBox(width: 16),
              
              // Save button
              ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text('Save Changes'),
                onPressed: _hasChanges ? _saveStoreTimings : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Main content - Split view for desktop
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _buildSplitView(),
        ),
      ],
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading store hours...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSplitView() {
    // Calculate today's day
    final now = DateTime.now();
    final today = DateFormat('EEEE').format(now);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left sidebar - Days of the week
        Container(
          width: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                spreadRadius: 0,
                blurRadius: 4,
                offset: Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sidebar header
              Container(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue.shade800),
                    SizedBox(width: 8),
                    Text(
                      'Days of Week',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              
              // Days list
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: _storeTimings.length,
                  itemBuilder: (context, index) {
                    final timing = _storeTimings[index];
                    final isSelected = _selectedDayTiming?.day == timing.day;
                    final isToday = timing.day == today;
                    
                    return Material(
                      color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectDay(timing),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: isSelected ? Colors.blue.shade700 : Colors.transparent,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: timing.isOpen ? Colors.green : Colors.red,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  timing.day,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.blue.shade700 : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              if (isToday)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Today',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Quick actions
              Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _showBatchEditDialog,
                  icon: Icon(Icons.edit_calendar_outlined),
                  label: Text('Batch Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.grey.shade800,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    minimumSize: Size(double.infinity, 45),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Main content area - Day details
        Expanded(
          child: _selectedDayTiming == null
              ? Center(child: Text('Select a day from the sidebar'))
              : _buildDayDetailsPanel(),
        ),
      ],
    );
  }
  
  Widget _buildDayDetailsPanel() {
    final timing = _selectedDayTiming!;
    final dayIndex = _storeTimings.indexWhere((element) => element.day == timing.day);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header with card
          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.blue.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 36,
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timing.day,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: timing.isOpen ? Colors.green : Colors.red,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            timing.isOpen ? 'Store is open' : 'Store is closed',
                            style: TextStyle(
                              fontSize: 16,
                              color: timing.isOpen ? Colors.green.shade800 : Colors.red.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Spacer(),
                  // Is Open switch
                  Row(
                    children: [
                      Text(
                        'Status:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(width: 16),
                      ToggleButtons(
                        isSelected: [timing.isOpen, !timing.isOpen],
                        onPressed: (index) {
                          setState(() {
                            _storeTimings[dayIndex] = timing.copyWith(
                              isOpen: index == 0,
                            );
                            _selectedDayTiming = _storeTimings[dayIndex];
                            _hasChanges = true;
                          });
                        },
                        borderRadius: BorderRadius.circular(30),
                        selectedBorderColor: timing.isOpen ? Colors.green.shade300 : Colors.red.shade300,
                        selectedColor: Colors.white,
                        fillColor: timing.isOpen ? Colors.green : Colors.red.shade400,
                        constraints: BoxConstraints(
                          minWidth: 100,
                          minHeight: 40,
                        ),
                        children: [
                          Text('Open'),
                          Text('Closed'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Hours configuration - only shown if store is open on this day
          AnimatedCrossFade(
            duration: Duration(milliseconds: 300),
            crossFadeState: timing.isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: _buildHoursConfigPanel(dayIndex, timing),
            secondChild: _buildClosedDayPanel(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildClosedDayPanel() {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 60),
        padding: EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store_mall_directory_outlined,
              size: 80,
              color: Colors.red.shade300,
            ),
            SizedBox(height: 24),
            Text(
              'Store is closed on this day',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'No operating hours needed when store is closed.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final dayIndex = _storeTimings.indexWhere((t) => t.day == _selectedDayTiming!.day);
                if (dayIndex != -1) {
                  setState(() {
                    _storeTimings[dayIndex] = _storeTimings[dayIndex].copyWith(isOpen: true);
                    _selectedDayTiming = _storeTimings[dayIndex];
                    _hasChanges = true;
                  });
                }
              },
              icon: Icon(Icons.check_circle_outline),
              label: Text('Mark as Open'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHoursConfigPanel(int dayIndex, StoreTiming timing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time configuration cards in a grid
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                spreadRadius: 1,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.blue),
                  SizedBox(width: 12),
                  Text(
                    'Operating Hours Configuration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              // 24 hours toggle with improved styling
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: timing.is24Hours ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: timing.is24Hours ? Colors.blue.shade200 : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: timing.is24Hours ? Colors.blue.shade100 : Colors.grey.shade200,
                      ),
                      child: Icon(
                        Icons.access_time_filled,
                        color: timing.is24Hours ? Colors.blue.shade700 : Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Open 24 Hours',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: timing.is24Hours ? Colors.blue.shade700 : Colors.grey.shade800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Store remains open 24 hours a day',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: timing.is24Hours,
                      onChanged: (value) {
                        setState(() {
                          _storeTimings[dayIndex] = timing.copyWith(is24Hours: value);
                          _selectedDayTiming = _storeTimings[dayIndex];
                          _hasChanges = true;
                        });
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ),
              
              if (!timing.is24Hours) ...[
                SizedBox(height: 24),
                
                // Hours selection grid with improved styling
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Opening time card
                    Expanded(
                      child: _buildTimeSelectionCard(
                        title: 'Opening Time',
                        iconData: Icons.wb_sunny_outlined,
                        iconColor: Colors.amber,
                        time: timing.openTime,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: timing.openTime,
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          
                          if (picked != null) {
                            setState(() {
                              _storeTimings[dayIndex] = timing.copyWith(openTime: picked);
                              _selectedDayTiming = _storeTimings[dayIndex];
                              _hasChanges = true;
                            });
                          }
                        },
                      ),
                    ),
                    
                    SizedBox(width: 24),
                    
                    // Closing time card
                    Expanded(
                      child: _buildTimeSelectionCard(
                        title: 'Closing Time',
                        iconData: Icons.nights_stay_outlined, 
                        iconColor: Colors.indigo,
                        time: timing.closeTime,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: timing.closeTime,
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          
                          if (picked != null) {
                            setState(() {
                              _storeTimings[dayIndex] = timing.copyWith(closeTime: picked);
                              _selectedDayTiming = _storeTimings[dayIndex];
                              _hasChanges = true;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // Duration indicator
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, color: Colors.grey.shade700),
                        SizedBox(width: 12),
                        Text(
                          'Duration: ${_getHoursDuration(timing.openTime, timing.closeTime)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        SizedBox(height: 24),
        
        // Copy settings panel
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                spreadRadius: 1,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.content_copy, color: Colors.purple),
                  SizedBox(width: 12),
                  Text(
                    'Copy Settings to Other Days',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Copy this day\'s settings to other days of the week.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 20),
              
              // Copy buttons in a row
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _days
                    .where((day) => day != timing.day)
                    .map((day) => _buildCopyDayChip(timing, day))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimeSelectionCard({
    required String title,
    required IconData iconData,
    required Color iconColor,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconData,
                      color: iconColor,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatTimeOfDay(time),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 16, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Text(
                        'Change Time',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCopyDayChip(StoreTiming sourceTiming, String targetDay) {
    return ElevatedButton.icon(
      icon: Icon(Icons.copy),
      label: Text(targetDay),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade800,
        elevation: 0,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16),
      ),
      onPressed: () {
        // Find the index of the target day
        final targetIndex = _storeTimings.indexWhere((timing) => timing.day == targetDay);
        if (targetIndex != -1) {
          setState(() {
            _storeTimings[targetIndex] = StoreTiming(
              day: targetDay,
              isOpen: sourceTiming.isOpen,
              openTime: sourceTiming.openTime,
              closeTime: sourceTiming.closeTime,
              is24Hours: sourceTiming.is24Hours,
            );
            _hasChanges = true;
          });
          
          // Show feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied hours from ${sourceTiming.day} to $targetDay'),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
    );
  }

  // Calculate and format the duration between opening and closing times
  String _getHoursDuration(TimeOfDay open, TimeOfDay close) {
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;
    
    // Handle overnight hours (close time is earlier than open time)
    int durationMinutes = closeMinutes >= openMinutes 
        ? closeMinutes - openMinutes 
        : (24 * 60 - openMinutes) + closeMinutes;
    
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    
    if (hours == 0) {
      return '$minutes minutes';
    } else if (minutes == 0) {
      return '$hours hours';
    } else {
      return '$hours hours, $minutes minutes';
    }
  }
}

// Batch Edit Dialog for desktop
class BatchEditDialog extends StatefulWidget {
  final List<String> days;
  final Function(List<String>, bool, TimeOfDay?, TimeOfDay?) onApply;
  
  const BatchEditDialog({
    Key? key,
    required this.days,
    required this.onApply,
  }) : super(key: key);

  @override
  State<BatchEditDialog> createState() => _BatchEditDialogState();
}

class _BatchEditDialogState extends State<BatchEditDialog> {
  List<String> _selectedDays = [];
  bool _is24Hours = false;
  TimeOfDay _openTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = TimeOfDay(hour: 18, minute: 0);
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.edit_calendar, size: 28, color: Colors.blue.shade700),
                SizedBox(width: 16),
                Text(
                  'Batch Edit Hours',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // Content in a scrollable container (for smaller screens)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Select days section
                    Text(
                      'Select Days to Edit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: widget.days.map((day) {
                        final isSelected = _selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                          },
                          selectedColor: Colors.blue.shade100,
                          checkmarkColor: Colors.blue.shade700,
                          backgroundColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          labelStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Quick actions
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDays = List.from(widget.days);
                            });
                          },
                          child: Text('Select All'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blue.shade300),
                          ),
                        ),
                        SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDays.clear();
                            });
                          },
                          child: Text('Clear Selection'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDays = widget.days
                                  .where((day) => ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
                                  .contains(day))
                                  .toList();
                            });
                          },
                          child: Text('Weekdays Only'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blue.shade300),
                          ),
                        ),
                        SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDays = widget.days
                                  .where((day) => ['Saturday', 'Sunday']
                                  .contains(day))
                                  .toList();
                            });
                          },
                          child: Text('Weekends Only'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blue.shade300),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 24),
                    
                    // Hours section
                    Text(
                      'Set Hours',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // 24 Hours toggle
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _is24Hours ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _is24Hours ? Colors.blue.shade200 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_filled,
                            color: _is24Hours ? Colors.blue : Colors.grey.shade600,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Open 24 Hours',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _is24Hours ? Colors.blue.shade700 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          Switch(
                            value: _is24Hours,
                            onChanged: (value) {
                              setState(() {
                                _is24Hours = value;
                              });
                            },
                            activeColor: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                    
                    if (!_is24Hours) ...[
                      SizedBox(height: 24),
                      
                      // Time selection
                      Row(
                        children: [
                          // Opening time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Opening Time',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _openTime,
                                      builder: (context, child) {
                                        return Theme(
                                          data: ThemeData.light().copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: Colors.blue,
                                              onPrimary: Colors.white,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    
                                    if (picked != null) {
                                      setState(() {
                                        _openTime = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time, color: Colors.green.shade600),
                                        SizedBox(width: 12),
                                        Text(
                                          _formatTimeOfDay(_openTime),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Spacer(),
                                        Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(width: 16),
                          
                          // Closing time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Closing Time',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _closeTime,
                                      builder: (context, child) {
                                        return Theme(
                                          data: ThemeData.light().copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: Colors.blue,
                                              onPrimary: Colors.white,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    
                                    if (picked != null) {
                                      setState(() {
                                        _closeTime = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time, color: Colors.red.shade600),
                                        SizedBox(width: 12),
                                        Text(
                                          _formatTimeOfDay(_closeTime),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Spacer(),
                                        Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            Divider(),
            SizedBox(height: 16),
            
            // Action buttons
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
                ElevatedButton(
                  onPressed: _selectedDays.isEmpty
                      ? null
                      : () {
                          widget.onApply(
                            _selectedDays,
                            _is24Hours,
                            _is24Hours ? null : _openTime,
                            _is24Hours ? null : _closeTime,
                          );
                          Navigator.pop(context);
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check),
                      SizedBox(width: 8),
                      Text('Apply to ${_selectedDays.length} day(s)'),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    return DateFormat.jm().format(dateTime);
  }
}