import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:shimmer/shimmer.dart';
import 'package:qr_flutter/qr_flutter.dart';

// UPI Payment Configuration Model
class UPIDetails {
  final String id;
  String upiId; // e.g. merchant@okicici
  String merchantName; // Name that appears during payment
  String? displayName;
  bool isPrimary;
  bool isActive;
  String? bankName; // Associated bank
  String? upiApp; // e.g. Google Pay, PhonePe, BHIM, etc.

  UPIDetails({
    required this.id,
    required this.upiId,
    required this.merchantName,
    this.displayName,
    this.isPrimary = false,
    this.isActive = true,
    this.bankName,
    this.upiApp,
  });

  // Convert to a Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'upiId': upiId,
      'merchantName': merchantName,
      'displayName': displayName,
      'isPrimary': isPrimary,
      'isActive': isActive,
      'bankName': bankName,
      'upiApp': upiApp,
    };
  }

  // Create from a Map from Firebase
  factory UPIDetails.fromMap(Map<String, dynamic> map) {
    return UPIDetails(
      id: map['id'] ?? const Uuid().v4(),
      upiId: map['upiId'],
      merchantName: map['merchantName'],
      displayName: map['displayName'],
      isPrimary: map['isPrimary'] ?? false,
      isActive: map['isActive'] ?? true,
      bankName: map['bankName'],
      upiApp: map['upiApp'],
    );
  }
}

class ManagerPaymentMethods extends StatefulWidget {
  const ManagerPaymentMethods({Key? key}) : super(key: key);

  @override
  State<ManagerPaymentMethods> createState() => ManagerPaymentMethodsState();
}

class ManagerPaymentMethodsState extends State<ManagerPaymentMethods> with SingleTickerProviderStateMixin {
  List<UPIDetails> _upiAccounts = [];
  String id = '';
  bool _acceptUPI = true; // Global switch to enable/disable UPI payment
  bool _isLoading = true; // Track loading state

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Add a new UPI account
  void _addUPIAccount() async {
    final result = await showDialog<UPIDetails>(
      context: context,
      builder: (context) => AddEditUPIDialog(),
    );

    if (result != null) {
      setState(() {
        // If this is the first UPI account, make it primary
        if (_upiAccounts.isEmpty) {
          result.isPrimary = true;
        }
        // Otherwise, if this is marked primary, update others
        else if (result.isPrimary) {
          for (var account in _upiAccounts) {
            account.isPrimary = false;
          }
        }
        _upiAccounts.add(result);
      });

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
              Text('Saving UPI details...'),
            ],
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Save to Firebase
      try {
        await FirebaseDatabase.instance
            .ref()
            .child(id)
            .child('upi_accounts')
            .child(result.id)
            .set(result.toMap());
            
        // Success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UPI account added successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        // Error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save UPI details. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Edit an existing UPI account
  void _editUPIAccount(UPIDetails account) async {
    final result = await showDialog<UPIDetails>(
      context: context,
      builder: (context) => AddEditUPIDialog(upiDetails: account),
    );

    if (result != null) {
      setState(() {
        final index =
            _upiAccounts.indexWhere((element) => element.id == result.id);
        if (index != -1) {
          // If this is being set as primary, update others
          if (result.isPrimary && !_upiAccounts[index].isPrimary) {
            for (var account in _upiAccounts) {
              account.isPrimary = false;
            }
          }
          _upiAccounts[index] = result;
        }
      });

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
              Text('Updating UPI details...'),
            ],
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Update Firebase
      try {
        await FirebaseDatabase.instance
            .ref()
            .child(id)
            .child('upi_accounts')
            .child(result.id)
            .update(result.toMap());
            
        // Success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UPI account updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        // Error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update UPI details. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Delete a UPI account
  void _deleteUPIAccount(String accountId) async {
    // Check if this is the primary account
    final isPrimary =
        _upiAccounts.firstWhere((element) => element.id == accountId).isPrimary;

    if (isPrimary && _upiAccounts.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Cannot delete primary UPI account. Set another account as primary first.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete UPI Account'),
        content: const Text('Are you sure you want to delete this UPI account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _upiAccounts.removeWhere((element) => element.id == accountId);

        // If we just removed the primary account and others exist, make one primary
        if (isPrimary && _upiAccounts.isNotEmpty) {
          _upiAccounts.first.isPrimary = true;
        }
      });

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
              Text('Deleting UPI account...'),
            ],
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Update Firebase
      try {
        await FirebaseDatabase.instance
            .ref()
            .child(id)
            .child('upi_accounts')
            .child(accountId)
            .remove();
            
        if (isPrimary && _upiAccounts.isNotEmpty) {
          await FirebaseDatabase.instance
              .ref()
              .child(id)
              .child('upi_accounts')
              .child(_upiAccounts.first.id)
              .update({'isPrimary': true});
        }
        
        // Success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UPI account deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        // Error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete UPI account. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Toggle the active status of a UPI account
  void _toggleUPIAccountStatus(String accountId) async {
    setState(() {
      final index = _upiAccounts.indexWhere((element) => element.id == accountId);
      if (index != -1) {
        _upiAccounts[index].isActive = !_upiAccounts[index].isActive;
      }
    });

    // Update Firebase
    try {
      final index = _upiAccounts.indexWhere((element) => element.id == accountId);
      if (index != -1) {
        await FirebaseDatabase.instance
            .ref()
            .child(id)
            .child('upi_accounts')
            .child(accountId)
            .update({'isActive': _upiAccounts[index].isActive});
      }
    } catch (e) {
      // Show error message on failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update UPI account status. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // Set UPI account as primary
  void _setPrimaryUPIAccount(String accountId) async {
    setState(() {
      for (var account in _upiAccounts) {
        account.isPrimary = account.id == accountId;
      }
    });

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
            Text('Setting primary account...'),
          ],
        ),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Update Firebase for all accounts
    try {
      for (var account in _upiAccounts) {
        await FirebaseDatabase.instance
            .ref()
            .child(id)
            .child('upi_accounts')
            .child(account.id)
            .update({'isPrimary': account.isPrimary});
      }
      
      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Primary UPI account updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      // Error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update primary UPI account. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Animation setup for smooth transitions
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );
    
    // Initialize Firebase and load data
    _setIdFromPreference();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setIdFromPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString('createdAt') ?? '';
    
    setState(() {
      id = storedId;
    });
    
    if (storedId.isNotEmpty) {
      _loadData();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    // Set loading state
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Listen for UPI accounts
      FirebaseDatabase.instance
          .ref()
          .child(id)
          .child('upi_accounts')
          .onValue
          .listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        
        setState(() {
          if (data != null) {
            _upiAccounts = data.entries
                .map((e) =>
                    UPIDetails.fromMap(Map<String, dynamic>.from(e.value as Map)))
                .toList();
          } else {
            _upiAccounts = [];
          }
          
          if (_isLoading) {
            _isLoading = false;
            _animationController.forward();
          }
        });
      }, onError: (error) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading UPI accounts: ${error.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
      
      // Listen for global UPI setting
      FirebaseDatabase.instance
          .ref()
          .child(id)
          .child('payment_settings')
          .child('accept_upi')
          .onValue
          .listen((event) {
        final data = event.snapshot.value as bool?;
        if (data != null) {
          setState(() {
            _acceptUPI = data;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to the server. Please check your internet connection.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
  title: const Text('UPI Payment Settings'),
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
),

      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Master switch for UPI
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
                  const Icon(Icons.payments_outlined,
                      color: Colors.blue, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accept UPI Payments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Enable UPI payments for your customers',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Use a custom switch with animations
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    height: 30,
                    width: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _acceptUPI ? Colors.green : Colors.grey.shade300,
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          left: _acceptUPI ? 25 : 0,
                          top: 2.5,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _acceptUPI = !_acceptUPI;
                              });
                              
                              // Update Firebase
                              FirebaseDatabase.instance
                                  .ref()
                                  .child(id)
                                  .child('payment_settings')
                                  .child('accept_upi')
                                  .set(_acceptUPI);
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

            if (_acceptUPI) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      'Your UPI Accounts',
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
              Expanded(
                child: _isLoading
                    ? _buildShimmerLoading() // Show shimmer while loading
                    : _upiAccounts.isEmpty
                        ? _buildEmptyState() // Empty state
                        : _buildUpiAccountsList(), // UPI accounts list
              ),
            ],

            if (!_acceptUPI)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 72,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'UPI Payments are disabled',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enable UPI payments using the switch above',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: Icon(Icons.toggle_on),
                        label: Text('Enable UPI Payments'),
                        onPressed: () {
                          setState(() {
                            _acceptUPI = true;
                          });
                          
                          // Update Firebase
                          FirebaseDatabase.instance
                              .ref()
                              .child(id)
                              .child('payment_settings')
                              .child('accept_upi')
                              .set(true);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _acceptUPI && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _addUPIAccount,
              icon: const Icon(Icons.add),
              label: const Text('Add UPI'),
              tooltip: 'Add new UPI account',
              elevation: 4,
            )
          : null,
    );
  }

  // Shimmer loading effect for UPI accounts
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: 3, // Show 3 placeholder items
        separatorBuilder: (context, index) => SizedBox(height: 16),
        itemBuilder: (context, index) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Container(
              height: 180,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.6,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Divider(),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      4,
                      (index) => Container(
                        width: 60,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Empty state widget
  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: Colors.blue.shade300,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No UPI accounts added yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add your UPI ID to start accepting payments directly to your bank account',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _addUPIAccount,
                icon: const Icon(Icons.add),
                label: const Text('Add UPI Account'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

    // UPI accounts list
  Widget _buildUpiAccountsList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.separated(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _upiAccounts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final account = _upiAccounts[index];
          return AnimatedContainer(
            duration: Duration(milliseconds: 300),
            transform: Matrix4.identity()..translate(0.0, 0.0, 0.0),
            curve: Curves.easeInOut,
            child: UPIAccountItem(
              upiDetails: account,
              onEdit: () => _editUPIAccount(account),
              onDelete: () => _deleteUPIAccount(account.id),
              onToggle: () => _toggleUPIAccountStatus(account.id),
              onSetPrimary: account.isPrimary
                  ? null
                  : () => _setPrimaryUPIAccount(account.id),
            ),
          );
        },
      ),
    );
  }
}

class UPIAccountItem extends StatelessWidget {
  final UPIDetails upiDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  final VoidCallback? onSetPrimary;

  const UPIAccountItem({
    Key? key,
    required this.upiDetails,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    this.onSetPrimary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen width for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Hero(
      tag: 'upi_account_${upiDetails.id}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        elevation: 2,
        shadowColor:
            upiDetails.isPrimary ? Colors.blue.withAlpha(127) : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: upiDetails.isPrimary
                ? Colors.blue.shade300
                : (upiDetails.isActive
                    ? Colors.green.shade100
                    : Colors.grey.shade200),
            width: upiDetails.isPrimary ? 2 : 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: upiDetails.isPrimary
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.blue.shade50],
                  )
                : null,
          ),
          child: Column(
            children: [
              // UPI details section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // UPI App icon with badge for primary
                    Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: upiDetails.isActive
                                ? (upiDetails.isPrimary
                                    ? Colors.blue.shade100
                                    : Colors.blue.shade50)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: upiDetails.isActive && upiDetails.isPrimary
                                ? [
                                    BoxShadow(
                                      color: Colors.blue.withAlpha(76),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Icon(
                            _getIconForUPIApp(upiDetails.upiApp),
                            color: upiDetails.isActive
                                ? (upiDetails.isPrimary
                                    ? Colors.blue.shade800
                                    : Colors.blue.shade600)
                                : Colors.grey,
                            size: 26,
                          ),
                        ),
                        if (upiDetails.isPrimary)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withAlpha(76),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // UPI Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  upiDetails.upiId,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                    color: upiDetails.isActive
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Status switch with improved design
                              Transform.scale(
                                scale: 0.8,
                                child: Switch.adaptive(
                                  value: upiDetails.isActive,
                                  onChanged: (_) => onToggle(),
                                  activeColor: Colors.green,
                                  activeTrackColor: Colors.green.shade100,
                                  inactiveThumbColor: Colors.grey.shade400,
                                  inactiveTrackColor: Colors.grey.shade200,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // Merchant name and bank
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      upiDetails.merchantName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: upiDetails.isActive
                                            ? Colors.black87
                                            : Colors.grey,
                                      ),
                                    ),
                                    if (upiDetails.bankName != null)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.account_balance_outlined,
                                            size: 14,
                                            color: upiDetails.isActive
                                                ? Colors.grey[600]
                                                : Colors.grey[400],
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            upiDetails.bankName!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: upiDetails.isActive
                                                  ? Colors.grey[600]
                                                  : Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),

                              // Primary badge - shown on larger screens inline
                              if (upiDetails.isPrimary && !isSmallScreen)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 12,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 4),
                                      const Text(
                                        'Primary',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (upiDetails.displayName != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text(
                        "Display name: ${upiDetails.displayName!}",
                        style: TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.grey.shade100,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),

              const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),

              // Actions section - Responsive layout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool useCompactLayout = constraints.maxWidth < 400;

                    // For small screens, use a more compact layout with icons
                    if (useCompactLayout) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (onSetPrimary != null)
                            _buildIconButton(
                              Icons.star_outline,
                              'Primary',
                              Colors.amber[700] ?? Colors.amber,
                              onSetPrimary!,
                            ),
                          _buildIconButton(
                            Icons.qr_code,
                            'QR',
                            Colors.purple,
                            () => _showQRCode(context),
                          ),
                          _buildIconButton(
                            Icons.edit_outlined,
                            'Edit',
                            Colors.blue,
                            onEdit,
                          ),
                          _buildIconButton(
                            Icons.delete_outline,
                            'Delete',
                            Colors.red,
                            onDelete,
                          ),
                        ],
                      );
                    }

                    // For larger screens, use text buttons with gradient backgrounds
                    return Row(
                      children: [
                        if (onSetPrimary != null)
                          _buildAnimatedButton(
                            context,
                            Icons.star_outline,
                            'Set Primary',
                            [Colors.amber.shade400, Colors.amber.shade600],
                            onSetPrimary!,
                          ),
                        const Spacer(),
                        _buildAnimatedButton(
                          context,
                          Icons.qr_code,
                          'QR',
                          [Colors.purple.shade300, Colors.purple.shade500],
                          () => _showQRCode(context),
                        ),
                        const SizedBox(width: 8),
                        _buildAnimatedButton(
                          context,
                          Icons.edit_outlined,
                          'Edit',
                          [Colors.blue.shade300, Colors.blue.shade500],
                          onEdit,
                        ),
                        const SizedBox(width: 8),
                        _buildAnimatedButton(
                          context,
                          Icons.delete_outline,
                          'Delete',
                          [Colors.red.shade300, Colors.red.shade500],
                          onDelete,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for compact icon buttons
  Widget _buildIconButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method for animated buttons with gradient
  Widget _buildAnimatedButton(
    BuildContext context,
    IconData icon,
    String label,
    List<Color> colors,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to show QR code dialog with improved UI
  void _showQRCode(BuildContext context) {
     // Format the UPI URI
  final upiUri = 'upi://pay?pa=${upiDetails.upiId}&pn=${upiDetails.merchantName}&cu=INR';
   
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                spreadRadius: 2,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                    Text(
                      'Scan to Pay',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        upiDetails.upiId,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // QR Code section
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // QR code imageholder with animation
                     QrImageView(
                    data: upiUri, // Use the UPI URI as the QR code data
                    version: QrVersions.auto,
                    size: 220.0,
                  ),
                    const SizedBox(height: 24),
                    
                    // UPI app selection hints
                    Text(
                      'Scan with any UPI app',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildUpiAppIcon('Google Pay', Icons.g_mobiledata),
                        _buildUpiAppIcon('PhonePe', Icons.phone_android),
                        _buildUpiAppIcon('Paytm', Icons.account_balance_wallet),
                        _buildUpiAppIcon('BHIM', Icons.payments_outlined),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Share and close buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.share),
                          label: Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            // Share QR code functionality would go here
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sharing QR Code...'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 16),
                        OutlinedButton.icon(
                          icon: Icon(Icons.close),
                          label: Text('Close'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper method to build UPI app icons
  Widget _buildUpiAppIcon(String name, IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20),
          ),
          SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  IconData _getIconForUPIApp(String? app) {
    if (app == null) return Icons.account_balance_wallet_outlined;

    switch (app.toLowerCase()) {
      case 'google pay':
        return Icons.g_mobiledata;
      case 'phonepe':
        return Icons.phone_android;
      case 'paytm':
        return Icons.account_balance_wallet;
      case 'bhim':
        return Icons.payments_outlined;
      case 'amazon pay':
        return Icons.shopping_cart_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

// QR Code Dialog has been integrated into UPIAccountItem class

// Dialog for adding/editing UPI accounts
class AddEditUPIDialog extends StatefulWidget {
  final UPIDetails? upiDetails;

  const AddEditUPIDialog({
    Key? key,
    this.upiDetails,
  }) : super(key: key);

  @override
  State<AddEditUPIDialog> createState() => _AddEditUPIDialogState();
}

class _AddEditUPIDialogState extends State<AddEditUPIDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _upiIdController;
  late TextEditingController _merchantNameController;
  late TextEditingController _displayNameController;
  late TextEditingController _bankNameController;
  bool _isActive = true;
  bool _isPrimary = false;
  String _selectedUpiApp = 'Google Pay';
  late AnimationController _animationController;

  final List<String> _upiApps = [
    'Google Pay',
    'PhonePe',
    'Paytm',
    'BHIM',
    'Amazon Pay',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _animationController.forward();
    
    final account = widget.upiDetails;
    _upiIdController = TextEditingController(text: account?.upiId ?? '');
    _merchantNameController =
        TextEditingController(text: account?.merchantName ?? '');
    _displayNameController =
        TextEditingController(text: account?.displayName ?? '');
    _bankNameController = TextEditingController(text: account?.bankName ?? '');
    _isActive = account?.isActive ?? true;
    _isPrimary = account?.isPrimary ?? false;
    _selectedUpiApp = account?.upiApp ?? 'Google Pay';
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _merchantNameController.dispose();
    _displayNameController.dispose();
    _bankNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _saveUPIAccount() {
    if (_formKey.currentState!.validate()) {
      final account = UPIDetails(
        id: widget.upiDetails?.id ?? const Uuid().v4(),
        upiId: _upiIdController.text,
        merchantName: _merchantNameController.text,
        displayName: _displayNameController.text.isEmpty
            ? null
            : _displayNameController.text,
        isPrimary: _isPrimary,
        isActive: _isActive,
        bankName:
            _bankNameController.text.isEmpty ? null : _bankNameController.text,
        upiApp: _selectedUpiApp,
      );

      Navigator.of(context).pop(account);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.upiDetails != null;
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 600;

    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _animationController, 
        curve: Curves.easeOutBack,
      ),
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEditing ? Icons.edit : Icons.add_circle_outline, 
                  color: isEditing ? Colors.blue : Colors.green,
                ),
                SizedBox(width: 8),
                Text(isEditing ? 'Edit UPI Account' : 'Add UPI Account'),
              ],
            ),
            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.upiDetails!.upiId,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: EdgeInsets.fromLTRB(24, isEditing ? 8 : 20, 24, 10),
        content: Container(
          width: isLargeScreen ? screenSize.width * 0.5 : screenSize.width * 0.9,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _upiIdController,
                    decoration: InputDecoration(
                      labelText: 'UPI ID',
                      hintText: 'e.g. yourname@okbank, phone@upi',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.payment),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your UPI ID';
                      }
                      if (!value.contains('@')) {
                        return 'UPI ID must contain @ symbol';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _merchantNameController,
                    decoration: InputDecoration(
                      labelText: 'Merchant Name',
                      hintText: 'Name that appears during payment',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.storefront),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter merchant name';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _displayNameController,
                    decoration: InputDecoration(
                      labelText: 'Display Name (Optional)',
                      hintText: 'Name displayed in your app',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bankNameController,
                    decoration: InputDecoration(
                      labelText: 'Bank Name (Optional)',
                      hintText: 'e.g. SBI, HDFC, ICICI',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'UPI App:',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedUpiApp,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        prefixIcon: Icon(
                          _getIconForUPIApp(_selectedUpiApp),
                          color: Colors.blue.shade700,
                        ),
                      ),
                      items: _upiApps.map((app) {
                        return DropdownMenuItem<String>(
                          value: app,
                          child: Row(
                            children: [
                              Icon(
                                _getIconForUPIApp(app),
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                              SizedBox(width: 12),
                              Text(
                                app,
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedUpiApp = value;
                          });
                        }
                      },
                      dropdownColor: Colors.white,
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Toggle switches with better UI
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 16),
                        // Primary account toggle
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Primary Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: _isPrimary
                                          ? Colors.amber.shade700
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                  Text(
                                    'Set as default for accepting payments',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isPrimary,
                              onChanged: (value) {
                                setState(() {
                                  _isPrimary = value;
                                });
                              },
                              activeColor: Colors.amber.shade600,
                              activeTrackColor: Colors.amber.shade100,
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        // Active account toggle
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: _isActive
                                          ? Colors.green
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                  Text(
                                    'Account is available for receiving payments',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isActive,
                              onChanged: (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                              activeColor: Colors.green,
                              activeTrackColor: Colors.green.shade100,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, size: 18),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _saveUPIAccount,
                icon: Icon(
                  isEditing ? Icons.save : Icons.check,
                  size: 18,
                ),
                label: Text(isEditing ? 'Update' : 'Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEditing ? Colors.blue : Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  IconData _getIconForUPIApp(String? app) {
    if (app == null) return Icons.account_balance_wallet_outlined;

    switch (app.toLowerCase()) {
      case 'google pay':
        return Icons.g_mobiledata;
      case 'phonepe':
        return Icons.phone_android;
      case 'paytm':
        return Icons.account_balance_wallet;
      case 'bhim':
        return Icons.payments_outlined;
      case 'amazon pay':
        return Icons.shopping_cart_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }
}