import 'package:canteendesk/API/Cred.dart';
import 'package:canteendesk/Firebase/FirebaseManager.dart';
import 'package:canteendesk/Services/UPIPaymentManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class ManagerPaymentMethodsState extends State<ManagerPaymentMethods>
    with SingleTickerProviderStateMixin {
  List<UPIDetails> _upiAccounts = [];
  UPIDetails? _selectedAccount;
  String storeId = '';
  bool _acceptUPI = true; // Global switch to enable/disable UPI payment
  bool _isLoading = true; // Track loading state

  // REST API client
  late UPIPaymentManager _apiClient;

  // Set in initState after getting store ID from preferences
  Future<void> _initializeApiClient() async {
    // These would typically come from your configuration or auth system
    final baseUrl =
        Cred.FIREBASE_DATABASE_URL; // Firebase URL without trailing slash
    final idToken = await FirebaseManager()
        .refreshIdTokenAndSave(); // You'd get this from your authentication system

    _apiClient = UPIPaymentManager(
      baseUrl: baseUrl,
      idToken: idToken ?? '', // Provide a fallback in case idToken is null
      storeId: storeId,
    );
  }

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Keyboard shortcuts
  final Map<ShortcutActivator, VoidCallback> _shortcuts = {};

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
        _selectedAccount = result; // Select the newly added account
      });

      // Show loading indicator
      _showSnackBar('Saving UPI details...', Colors.blue.shade700);

      // Save to Firebase using REST API
      try {
        await _apiClient.addUPIAccount(result);

        // If this is a primary account, update all others
        if (result.isPrimary && _upiAccounts.length > 1) {
          await _apiClient.setPrimaryUPIAccount(result.id, _upiAccounts);
        }

        // Success message
        _showSnackBar('UPI account added successfully', Colors.green);
      } catch (e) {
        // Error message
        _showSnackBar(
            'Failed to save UPI details. Please try again.', Colors.red);
      }
    }
  }

  // Helper method to show snackbars
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (backgroundColor == Colors.blue.shade700)
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            if (backgroundColor == Colors.blue.shade700) SizedBox(width: 16),
            Text(message),
          ],
        ),
        duration:
            Duration(seconds: backgroundColor == Colors.blue.shade700 ? 1 : 3),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  // Edit an existing UPI account
  void _editUPIAccount(UPIDetails account) async {
    final result = await showDialog<UPIDetails>(
      context: context,
      builder: (context) => AddEditUPIDialog(upiDetails: account),
    );

    if (result != null) {
      final bool primaryChanged = result.isPrimary != account.isPrimary;

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
          _selectedAccount = result; // Update the selected account
        }
      });

      _showSnackBar('Updating UPI details...', Colors.blue.shade700);

      // Update Firebase using REST API
      try {
        await _apiClient.updateUPIAccount(result);

        // If primary status changed, update all accounts
        if (primaryChanged) {
          await _apiClient.setPrimaryUPIAccount(
              result.isPrimary
                  ? result.id
                  : _upiAccounts.firstWhere((a) => a.isPrimary).id,
              _upiAccounts);
        }

        _showSnackBar('UPI account updated successfully', Colors.green);
      } catch (e) {
        _showSnackBar(
            'Failed to update UPI details. Please try again.', Colors.red);
      }
    }
  }

  // Delete a UPI account
  void _deleteUPIAccount(String accountId) async {
    // Check if this is the primary account
    final accountToDelete =
        _upiAccounts.firstWhere((element) => element.id == accountId);
    final isPrimary = accountToDelete.isPrimary;

    if (isPrimary && _upiAccounts.length > 1) {
      _showSnackBar(
          'Cannot delete primary UPI account. Set another account as primary first.',
          Colors.red);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Delete UPI Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this UPI account?'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accountToDelete.upiId,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (accountToDelete.merchantName.isNotEmpty)
                          Text(accountToDelete.merchantName),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

        // If we removed the selected account, select another one or null
        if (_selectedAccount?.id == accountId) {
          _selectedAccount =
              _upiAccounts.isNotEmpty ? _upiAccounts.first : null;
        }
      });

      _showSnackBar('Deleting UPI account...', Colors.blue.shade700);

      // Delete from Firebase using REST API
      try {
        await _apiClient.deleteUPIAccount(accountId);

        // If we deleted the primary and have others, set a new primary
        if (isPrimary && _upiAccounts.isNotEmpty) {
          await _apiClient.updateUPIAccount(_upiAccounts.first);
        }

        _showSnackBar('UPI account deleted successfully', Colors.green);
      } catch (e) {
        _showSnackBar(
            'Failed to delete UPI account. Please try again.', Colors.red);
      }
    }
  }

  void _toggleUPIAccountStatus(String accountId) async {
    setState(() {
      final index =
          _upiAccounts.indexWhere((element) => element.id == accountId);
      if (index != -1) {
        _upiAccounts[index].isActive = !_upiAccounts[index].isActive;

        // Also update the selected account if needed
        if (_selectedAccount?.id == accountId) {
          _selectedAccount = _upiAccounts[index];
        }
      }
    });

    // Update Firebase using REST API
    try {
      final index =
          _upiAccounts.indexWhere((element) => element.id == accountId);
      if (index != -1) {
        await _apiClient.updateUPIAccountStatus(
            accountId, _upiAccounts[index].isActive);
      }
    } catch (e) {
      _showSnackBar(
          'Failed to update UPI account status. Please try again.', Colors.red);
    }
  }

  // Set UPI account as primary
  void _setPrimaryUPIAccount(String accountId) async {
    setState(() {
      for (var account in _upiAccounts) {
        account.isPrimary = account.id == accountId;

        // Also update the selected account if needed
        if (_selectedAccount?.id == account.id) {
          _selectedAccount = account;
        }
      }
    });

    _showSnackBar('Setting primary account...', Colors.blue.shade700);

    // Update Firebase for all accounts using REST API
    try {
      await _apiClient.setPrimaryUPIAccount(accountId, _upiAccounts);
      _showSnackBar('Primary UPI account updated successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to update primary UPI account. Please try again.',
          Colors.red);
    }
  }

  // Select a UPI account
  void _selectUPIAccount(UPIDetails account) {
    setState(() {
      _selectedAccount = account;
    });
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
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Setup keyboard shortcuts
    _shortcuts[LogicalKeySet(
        LogicalKeyboardKey.control, LogicalKeyboardKey.keyN)] = _addUPIAccount;

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
      storeId = storedId;
    });

    if (storedId.isNotEmpty) {
      _initializeApiClient();
      _loadData();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load UPI accounts from REST API
      final accounts = await _apiClient.loadUPIAccounts();

      // Load UPI setting from REST API
      final acceptUPI = await _apiClient.loadAcceptUPI();

      setState(() {
        _upiAccounts = accounts;
        _acceptUPI = acceptUPI;

        // Set selected account
        _selectedAccount = _upiAccounts.isNotEmpty ? _upiAccounts.first : null;

        _isLoading = false;
        _animationController.forward();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showSnackBar('Failed to load data: ${e.toString()}', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Payment Settings'),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Help button
          IconButton(
            icon: Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () {
              // Show help dialog
            },
          ),
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          SizedBox(width: 16),
        ],
      ),
      body: FocusableActionDetector(
        // shortcuts: _shortcuts,
        // actions: {
        //   for (final entry in _shortcuts.entries)
        //     entry.key: CallbackAction(
        //       onInvoke: (_) => entry.value(),
        //     ),
        // },
        child: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left sidebar - Navigation and Account List
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    Icon(Icons.payments, color: Colors.blue.shade700),
                    SizedBox(width: 12),
                    Text(
                      'Payment Methods',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // UPI Master Switch
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: _acceptUPI ? Colors.blue : Colors.grey,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Accept UPI Payments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Switch(
                      value: _acceptUPI,
                      onChanged: (value) {
                        setState(() {
                          _acceptUPI = value;
                        });

                        // Using REST API instead of direct Firebase
                        _apiClient.updateAcceptUPI(value).catchError((error) {
                          _showSnackBar(
                              'Failed to update UPI settings. Please try again.',
                              Colors.red);

                          // Revert state on failure
                          setState(() {
                            _acceptUPI = !value;
                          });
                        });
                      },
                    ),
                  ],
                ),
              ),

              Divider(height: 32),

              // UPI Accounts List Title
              if (_acceptUPI)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your UPI Accounts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      if (_isLoading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                    ],
                  ),
                ),

              // UPI Accounts List
              if (_acceptUPI)
                Expanded(
                  child: _isLoading
                      ? _buildSidebarShimmerLoading()
                      : _upiAccounts.isEmpty
                          ? _buildSidebarEmptyState()
                          : _buildSidebarAccountList(),
                ),

              // Add UPI Account Button (only if UPI payments are accepted)
              if (_acceptUPI)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _addUPIAccount,
                    icon: Icon(Icons.add),
                    label: Text('Add UPI Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Main content area - Account details
        Expanded(
          child: !_acceptUPI
              ? _buildUpiDisabledView()
              : _selectedAccount == null
                  ? _buildNoSelectionView()
                  : _buildAccountDetailsView(),
        ),
      ],
    );
  }

  // Sidebar UPI account list
  Widget _buildSidebarAccountList() {
    return ListView.builder(
      itemCount: _upiAccounts.length,
      padding: EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final account = _upiAccounts[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color:
              _selectedAccount?.id == account.id ? Colors.blue.shade50 : null,
          elevation: _selectedAccount?.id == account.id ? 0 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: _selectedAccount?.id == account.id
                  ? Colors.blue.shade300
                  : Colors.transparent,
            ),
          ),
          child: ListTile(
            onTap: () => _selectUPIAccount(account),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: account.isActive
                    ? (account.isPrimary
                        ? Colors.blue.shade100
                        : Colors.blue.shade50)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconForUPIApp(account.upiApp),
                color: account.isActive
                    ? (account.isPrimary
                        ? Colors.blue.shade800
                        : Colors.blue.shade600)
                    : Colors.grey,
              ),
            ),
            title: Text(
              account.upiId,
              style: TextStyle(
                fontWeight: _selectedAccount?.id == account.id
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              account.merchantName,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (account.isPrimary)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.star, size: 16, color: Colors.amber),
                  ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: account.isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Empty state for the sidebar
  Widget _buildSidebarEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            'No UPI accounts',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addUPIAccount,
            icon: Icon(Icons.add),
            label: Text('Add First Account'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  // Shimmer loading for the sidebar
  Widget _buildSidebarShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 5,
        padding: EdgeInsets.all(16),
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              title: Container(
                height: 14,
                width: double.infinity,
                color: Colors.white,
              ),
              subtitle: Container(
                height: 10,
                width: 100,
                margin: EdgeInsets.only(top: 8),
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  // Account details view for the main content area
  Widget _buildAccountDetailsView() {
    final account = _selectedAccount!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with account info
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: account.isActive
                      ? (account.isPrimary
                          ? Colors.blue.shade100
                          : Colors.blue.shade50)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getIconForUPIApp(account.upiApp),
                  color: account.isActive
                      ? (account.isPrimary
                          ? Colors.blue.shade800
                          : Colors.blue.shade600)
                      : Colors.grey,
                  size: 32,
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          account.upiId,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 12),
                        if (account.isPrimary)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber.shade800,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Primary Account',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      account.merchantName,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              // Account status switch
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    account.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: account.isActive ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: account.isActive,
                    onChanged: (_) => _toggleUPIAccountStatus(account.id),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 32),

          // Account details cards in a grid layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column - Basic info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailCard(
                      title: 'Account Information',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailItem('UPI ID', account.upiId),
                          _buildDetailItem(
                              'Merchant Name', account.merchantName),
                          if (account.displayName != null)
                            _buildDetailItem(
                                'Display Name', account.displayName!),
                          if (account.bankName != null)
                            _buildDetailItem('Bank', account.bankName!),
                          if (account.upiApp != null)
                            _buildDetailItem('UPI App', account.upiApp!),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    _buildDetailCard(
                      title: 'Primary Status',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.isPrimary
                                ? 'This is your primary account and will be used as the default for accepting payments.'
                                : 'This is a secondary account. You can set it as primary to use it as the default for accepting payments.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 16),
                          if (!account.isPrimary)
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _setPrimaryUPIAccount(account.id),
                              icon: Icon(Icons.star_outline),
                              label: Text('Set as Primary'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 24),

              // Right column - QR Code and actions
              Expanded(
                child: Column(
                  children: [
                    _buildDetailCard(
                      title: 'UPI Payment QR Code',
                      content: Column(
                        children: [
                          Container(
                            height: 250,
                            width: 250,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: QrImageView(
                              data:
                                  'upi://pay?pa=${account.upiId}&pn=${account.merchantName}&cu=INR',
                              version: QrVersions.auto,
                              size: 200.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Scan this QR code to pay directly to this UPI account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  // Download QR code functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Downloading QR Code...'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: Icon(Icons.download),
                                label: Text('Download'),
                              ),
                              SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  // Share QR code functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Sharing QR Code...'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: Icon(Icons.share),
                                label: Text('Share'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Actions card
                    _buildDetailCard(
                      title: 'Account Actions',
                      content: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editUPIAccount(account),
                              icon: Icon(Icons.edit),
                              label: Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size(0, 48),
                                side: BorderSide(color: Colors.blue),
                                foregroundColor: Colors.blue,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _deleteUPIAccount(account.id),
                              icon: Icon(Icons.delete_outline),
                              label: Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size(0, 48),
                                side: BorderSide(color: Colors.red),
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build detail items
  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label + ':',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build detail cards
  Widget _buildDetailCard({required String title, required Widget content}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
          // Title with gradient background
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          // Content area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: content,
          ),
        ],
      ),
    );
  }

  // View for when UPI is disabled
  Widget _buildUpiDisabledView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 96,
            color: Colors.grey[300],
          ),
          SizedBox(height: 32),
          Text(
            'UPI Payments are disabled',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Enable UPI payments using the switch in the sidebar',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            icon: Icon(Icons.toggle_on),
            label: Text('Enable UPI Payments'),
            onPressed: () {
              setState(() {
                _acceptUPI = true;
              });

              // Using REST API instead of direct Firebase
              _apiClient.updateAcceptUPI(true).catchError((error) {
                _showSnackBar(
                    'Failed to enable UPI payments. Please try again.',
                    Colors.red);

                // Revert state on failure
                setState(() {
                  _acceptUPI = false;
                });
              });
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // View for when no account is selected
  Widget _buildNoSelectionView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app,
            size: 72,
            color: Colors.blue[200],
          ),
          SizedBox(height: 24),
          Text(
            _upiAccounts.isEmpty
                ? 'No UPI accounts have been added yet'
                : 'Select an account from the sidebar',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Add New UPI Account'),
            onPressed: _addUPIAccount,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Shimmer loading effect for UPI accounts (unused in this version, but kept for reference)
 
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

// UPI Account Item Card (unused in this desktop version, but kept for reference)
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
    return Card(
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
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upiDetails.upiId,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        upiDetails.merchantName,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (upiDetails.bankName != null) ...[
                        SizedBox(height: 4),
                        Text(
                          upiDetails.bankName!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: upiDetails.isActive,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (onSetPrimary != null)
                  TextButton.icon(
                    icon: Icon(Icons.star_outline),
                    label: Text('Set Primary'),
                    onPressed: onSetPrimary,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          'Primary',
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.qr_code),
                      onPressed: () => _showQRCode(context),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQRCode(BuildContext context) {
    final upiUri =
        'upi://pay?pa=${upiDetails.upiId}&pn=${upiDetails.merchantName}&cu=INR';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Scan to Pay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(upiDetails.upiId),
            SizedBox(height: 24),
            QrImageView(
              data: upiUri,
              version: QrVersions.auto,
              size: 200.0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
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

class _AddEditUPIDialogState extends State<AddEditUPIDialog>
    with SingleTickerProviderStateMixin {
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
    final screenWidth = MediaQuery.of(context).size.width;

    // Width calculation for desktop dialog
    final dialogWidth = screenWidth > 1200 ? 800.0 : (screenWidth * 0.6);

    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title bar
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add_circle_outline,
                    color: isEditing ? Colors.blue : Colors.green,
                    size: 28,
                  ),
                  SizedBox(width: 16),
                  Text(
                    isEditing ? 'Edit UPI Account' : 'Add UPI Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Desktop-specific two-column layout
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left column - Basic information
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // UPI ID field
                                  TextFormField(
                                    controller: _upiIdController,
                                    decoration: InputDecoration(
                                      labelText: 'UPI ID',
                                      hintText:
                                          'e.g. yourname@okbank, phone@upi',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
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
                                  SizedBox(height: 16),

                                  // Merchant Name field
                                  TextFormField(
                                    controller: _merchantNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Merchant Name',
                                      hintText:
                                          'Name that appears during payment',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
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
                                  SizedBox(height: 16),

                                  // Display Name field
                                  TextFormField(
                                    controller: _displayNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Display Name (Optional)',
                                      hintText: 'Name displayed in your app',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: Icon(Icons.badge_outlined),
                                    ),
                                    textInputAction: TextInputAction.next,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 24),

                            // Right column - Additional information
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Additional Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 16),

                                  // Bank Name field
                                  TextFormField(
                                    controller: _bankNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Bank Name (Optional)',
                                      hintText: 'e.g. SBI, HDFC, ICICI',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: Icon(Icons.account_balance),
                                    ),
                                    textInputAction: TextInputAction.done,
                                  ),
                                  SizedBox(height: 16),

                                  // UPI App dropdown
                                  Text(
                                    'UPI App:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedUpiApp,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16),
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
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w500),
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
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Toggle switches section
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              // Primary Account toggle
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.star,
                                        color: Colors.amber.shade800,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Set as Primary',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: _isPrimary
                                                  ? Colors.amber.shade800
                                                  : Colors.grey.shade800,
                                            ),
                                          ),
                                          Text(
                                            'Default account for accepting payments',
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
                              ),

                              SizedBox(width: 24),

                              // Active Account toggle
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade800,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Active Account',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: _isActive
                                                  ? Colors.green.shade800
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
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 32),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Text('Cancel'),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _saveUPIAccount,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isEditing ? Icons.save : Icons.check),
                          SizedBox(width: 8),
                          Text(isEditing
                              ? 'Update UPI Account'
                              : 'Add UPI Account'),
                        ],
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEditing ? Colors.blue : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
