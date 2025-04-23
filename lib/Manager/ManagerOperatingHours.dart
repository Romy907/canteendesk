import 'package:canteendesk/API/Cred.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// API service class for handling HTTP requests
class ApiService {
  // Base URL of your REST API
  static const String baseUrl = Cred.FIREBASE_DATABASE_URL; // No trailing slash
  
  // Get store timings
  static Future<Map<String, dynamic>> getStoreTimings(String storeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/stores/$storeId/timings'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load store timings: ${response.statusCode}');
    }
  }
  
  // Get store settings
  static Future<Map<String, dynamic>> getStoreSettings(String storeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/stores/$storeId/settings'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load store settings: ${response.statusCode}');
    }
  }
  
  // Update store timings
  static Future<bool> updateStoreTimings(String storeId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/stores/$storeId/timings'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    
    return response.statusCode == 200;
  }
  
  // Update store settings
  static Future<bool> updateStoreSettings(String storeId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/stores/$storeId/settings'),
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
  bool _isLoading = true;
  String _storeId = '';
  bool _storeOpen = true;
  
  // For animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
  
  // Currently selected day for copying schedule
  String _selectedDayToCopy = 'Monday';
  
  // Controllers for the batch edit bottom sheet
  late TimeOfDay _batchOpenTime;
  late TimeOfDay _batchCloseTime;
  bool _batchIs24Hours = false;

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

      // Load global store open setting using REST API
      final settingsResponse = await ApiService.getStoreSettings(_storeId);
      
      if (settingsResponse.containsKey('is_open')) {
        setState(() {
          _storeOpen = settingsResponse['is_open'];
        });
      }

      // Load store timings using REST API
      final timingsResponse = await ApiService.getStoreTimings(_storeId);
      
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
          _isLoading = false;
          _animationController.forward();
        });
      } else {
        setState(() {
          _isLoading = false;
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
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Save global store open setting using REST API
      await ApiService.updateStoreSettings(_storeId, {'is_open': _storeOpen});

      // Save each day's timing using REST API
      final Map<String, dynamic> timingsMap = {};
      
      for (StoreTiming timing in _storeTimings) {
        timingsMap[timing.day] = timing.toMap();
      }
      
      final result = await ApiService.updateStoreTimings(_storeId, {'timings': timingsMap});

      if (result) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Store hours updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        throw Exception('Failed to update store hours');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update store hours: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _updateStoreTiming(int index, StoreTiming newTiming) {
    setState(() {
      _storeTimings[index] = newTiming;
    });
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    return DateFormat.jm().format(dateTime);
  }

 void _showBatchEditSheet() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true, // Important to handle keyboard
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        // Get available height and account for keyboard
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final availableHeight = MediaQuery.of(context).size.height;
        
        return SingleChildScrollView(
          // This physics prevents the scroll from bouncing
          physics: ClampingScrollPhysics(),
          child: Padding(
            // Add padding for keyboard
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: Container(
              // Limit max height to avoid overflow
              constraints: BoxConstraints(
                maxHeight: availableHeight * 0.85,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Important to take only needed space
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with drag handle
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(76),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Batch Edit Hours',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Apply the same hours to multiple days',
                          style: TextStyle(
                            color: Colors.white.withAlpha(204),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Make this section scrollable to handle overflow
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Select Hours',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // 24 hours toggle
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _batchIs24Hours ? Colors.blue.shade50 : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _batchIs24Hours ? Colors.blue.shade200 : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time_filled,
                                  color: _batchIs24Hours ? Colors.blue : Colors.grey.shade600,
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Open 24 Hours',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _batchIs24Hours,
                                  onChanged: (value) {
                                    setState(() {
                                      _batchIs24Hours = value;
                                    });
                                  },
                                  activeColor: Colors.blue,
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 20),
                          
                          if (!_batchIs24Hours) ...[
                            Text(
                              'Operating Hours',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 12),
                            
                            // Use row for larger screens, column for smaller screens
                            LayoutBuilder(
                              builder: (context, constraints) {
                                // Adjust layout based on available width
                                final useColumn = constraints.maxWidth < 400;
                                
                                if (useColumn) {
                                  return Column(
                                    children: [
                                      _buildTimePicker(
                                        context,
                                        setState,
                                        label: 'Opening Time',
                                        time: _batchOpenTime,
                                        color: Colors.green.shade600,
                                        onChanged: (time) {
                                          setState(() {
                                            _batchOpenTime = time;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 12),
                                      _buildTimePicker(
                                        context,
                                        setState,
                                        label: 'Closing Time',
                                        time: _batchCloseTime,
                                        color: Colors.red.shade600,
                                        onChanged: (time) {
                                          setState(() {
                                            _batchCloseTime = time;
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                } else {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _buildTimePicker(
                                          context,
                                          setState,
                                          label: 'Opening Time',
                                          time: _batchOpenTime,
                                          color: Colors.green.shade600,
                                          onChanged: (time) {
                                            setState(() {
                                              _batchOpenTime = time;
                                            });
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: _buildTimePicker(
                                          context,
                                          setState,
                                          label: 'Closing Time',
                                          time: _batchCloseTime,
                                          color: Colors.red.shade600,
                                          onChanged: (time) {
                                            setState(() {
                                              _batchCloseTime = time;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                          
                          SizedBox(height: 24),
                          
                          Text(
                            'Select Days to Apply',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          // Days selection - more compact design
                          ...List.generate(_days.length, (index) {
                            final day = _days[index];
                            
                            return CheckboxListTile(
                              title: Text(
                                day,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              value: day == _selectedDayToCopy,
                              onChanged: (bool? value) {
                                if (value == true) {
                                  setState(() {
                                    _selectedDayToCopy = day;
                                  });
                                }
                              },
                              activeColor: Colors.blue,
                              checkColor: Colors.white,
                              controlAffinity: ListTileControlAffinity.trailing,
                              dense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 0,
                              ),
                              visualDensity: VisualDensity(
                                horizontal: VisualDensity.minimumDensity,
                                vertical: VisualDensity.minimumDensity,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Find the index of the selected day
                              final selectedIndex = _days.indexOf(_selectedDayToCopy);
                              
                              if (selectedIndex != -1) {
                                // Update the timing for the selected day
                                final updatedTiming = StoreTiming(
                                  day: _selectedDayToCopy,
                                  isOpen: true,
                                  openTime: _batchOpenTime,
                                  closeTime: _batchCloseTime,
                                  is24Hours: _batchIs24Hours,
                                );
                                
                                _updateStoreTiming(selectedIndex, updatedTiming);
                                Navigator.pop(context);
                              }
                            },
                            child: Text('Apply'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

// Helper method for time pickers
Widget _buildTimePicker(
  BuildContext context,
  StateSetter setState,
  {
    required String label,
    required TimeOfDay time,
    required Color color,
    required Function(TimeOfDay) onChanged,
  }
) {
  return InkWell(
    onTap: () async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: time,
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.blue,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );
      
      if (picked != null) {
        onChanged(picked);
      }
    },
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: color,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                _formatTimeOfDay(time),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Icon(
            Icons.edit,
            color: Colors.blue,
            size: 18,
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
  title: const Text('Store Hours'),
  centerTitle: true,
  backgroundColor: Colors.white,
  foregroundColor: Colors.black87,
  elevation: 1,
  leading: IconButton(
    icon: Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(25),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black87),
    ),
    onPressed: () => Navigator.of(context).pop(),
  ),
  actions: [
    if (!_isLoading)
      IconButton(
        icon: Icon(Icons.edit_calendar_outlined),
        onPressed: _showBatchEditSheet,
        tooltip: 'Batch Edit Hours',
      ),
  ],
),

      body: RefreshIndicator(
        onRefresh: _loadStoreTimings,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store open/closed master switch
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade100,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _storeOpen ? Colors.green.shade50 : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _storeOpen ? Icons.storefront : Icons.storefront_outlined,
                      color: _storeOpen ? Colors.green : Colors.red,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _storeOpen 
                              ? 'Your store is open for business' 
                              : 'Your store is currently closed',
                          style: TextStyle(
                            color: _storeOpen ? Colors.green.shade700 : Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Custom switch with animations
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    height: 30,
                    width: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _storeOpen ? Colors.green : Colors.red.shade300,
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          left: _storeOpen ? 25 : 0,
                          top: 2.5,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _storeOpen = !_storeOpen;
                              });
                            },
                            child: Container(
                              width: 25,
                              height: 25,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Store hours heading
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Store Hours',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  if (_isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                ],
              ),
            ),
            
            // Store hours list
            Expanded(
              child: _isLoading
                  ? _buildShimmerLoading()
                  : _buildStoreHoursList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _saveStoreTimings,
            child: Text(
              'Save Hours',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: 7, // One for each day of the week
        separatorBuilder: (context, index) => SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Container(
              height: 120,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 120,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Spacer(),
                      Container(
                        width: 40,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreHoursList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: _storeTimings.length,
        separatorBuilder: (context, index) => SizedBox(height: 12),
        itemBuilder: (context, index) {
          final timing = _storeTimings[index];
          return _buildDayCard(index, timing);
        },
      ),
    );
  }

    Widget _buildDayCard(int index, StoreTiming timing) {
    // Highlight today's card
    final now = DateTime.now();
    final today = DateFormat('EEEE').format(now);
    final isToday = timing.day == today;
    
    return Card(
      elevation: isToday ? 2 : 1,
      shadowColor: isToday ? Colors.blue.withAlpha(76) : Colors.black12,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isToday 
              ? Colors.blue.shade200 
              : (timing.isOpen ? Colors.grey.shade200 : Colors.grey.shade300),
          width: isToday ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isToday ? LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
        ),
        child: Column(
          children: [
            // Day header with today indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isToday ? Colors.blue.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: isToday ? Colors.blue.shade100 : Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          timing.day,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Colors.blue.shade800 : Colors.black87,
                          ),
                        ),
                        if (isToday)
                          Container(
                            margin: EdgeInsets.only(left: 8),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Today',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Is Open switch
                  Row(
                    children: [
                      Text(
                        timing.isOpen ? 'Open' : 'Closed',
                        style: TextStyle(
                          color: timing.isOpen ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 8),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: timing.isOpen,
                          onChanged: (value) {
                            setState(() {
                              _storeTimings[index] = timing.copyWith(isOpen: value);
                            });
                          },
                          activeColor: Colors.green,
                          activeTrackColor: Colors.green.shade100,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Hours content
            AnimatedCrossFade(
              duration: Duration(milliseconds: 300),
              firstChild: _buildClosedState(),
              secondChild: _buildOpenHours(index, timing),
              crossFadeState: timing.isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildClosedState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'Closed',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
  
  Widget _buildOpenHours(int index, StoreTiming timing) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 24 hours toggle
          InkWell(
            onTap: () {
              setState(() {
                _storeTimings[index] = timing.copyWith(is24Hours: !timing.is24Hours);
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: timing.is24Hours ? Colors.blue.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: timing.is24Hours ? Colors.blue.shade200 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_filled,
                    color: timing.is24Hours ? Colors.blue : Colors.grey.shade600,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Open 24 Hours',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: timing.is24Hours ? Colors.blue.shade700 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: timing.is24Hours,
                      onChanged: (value) {
                        setState(() {
                          _storeTimings[index] = timing.copyWith(is24Hours: value);
                        });
                      },
                      activeColor: Colors.blue,
                      activeTrackColor: Colors.blue.shade100,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (!timing.is24Hours) ...[
            SizedBox(height: 16),
            
            // Time selectors
            Row(
              children: [
                // Opening time
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: timing.openTime,
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Colors.blue,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      
                      if (picked != null) {
                        setState(() {
                          _storeTimings[index] = timing.copyWith(openTime: picked);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade100,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Colors.green.shade600,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Opens',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatTimeOfDay(timing.openTime),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Arrow
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ),
                
                // Closing time
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: timing.closeTime,
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Colors.blue,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      
                      if (picked != null) {
                        setState(() {
                          _storeTimings[index] = timing.copyWith(closeTime: picked);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade100,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Colors.red.shade600,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Closes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatTimeOfDay(timing.closeTime),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Duration indicator
            SizedBox(height: 12),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getHoursDuration(timing.openTime, timing.closeTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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