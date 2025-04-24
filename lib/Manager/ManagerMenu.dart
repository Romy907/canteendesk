import 'package:canteendesk/Manager/AddMenuItems.dart';
import 'package:canteendesk/Services/MenuServices.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManagerManageMenu extends StatefulWidget {
  const ManagerManageMenu({Key? key}) : super(key: key);

  @override
  _ManagerManageMenuState createState() => _ManagerManageMenuState();
}

class _ManagerManageMenuState extends State<ManagerManageMenu> {
  final MenuService _menuService = MenuService();
  final Color _primaryColor = const Color.fromARGB(255, 136, 107, 175);
  final Color _accentColor = const Color(0xFF26C6DA);

  // Menu items data
  List<Map<String, dynamic>> _menuItems = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final List<String> _categories = [
    'All',
    'Main Course',
    'Appetizers',
    'Beverages',
    'Desserts',
    'Sides',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks'
  ];

  // Selected item for detail view
  Map<String, dynamic>? _selectedItem;

  // Sort settings
  String _sortField = 'name';
  bool _sortAscending = true;

  // Current date and user
  String _currentDate = "2025-04-23 17:15:29";
  String _currentUserLogin = "navin280123";

  @override
  void initState() {
    super.initState();
    _initializeService();
    
    // Register keyboard shortcuts
    _registerKeyboardShortcuts();
  }
  
  @override
  void dispose() {
    // Unregister keyboard handlers when disposing
    ServicesBinding.instance.keyboard.removeHandler(_keyboardHandler);
    super.dispose();
  }
  
  void _registerKeyboardShortcuts() {
    // Add keyboard shortcuts for common actions
    ServicesBinding.instance.keyboard.addHandler(_keyboardHandler);
  }
  
  bool _keyboardHandler(KeyEvent event) {
    if (event is KeyDownEvent) {
      if ((event.logicalKey == LogicalKeyboardKey.keyN) && 
          (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight)) {
        // Ctrl+N - New item
        _navigateToAddEditScreen(null);
        return true;
      } else if ((event.logicalKey == LogicalKeyboardKey.keyF) && 
                (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight)) {
        // Ctrl+F - Focus search
        _focusSearchField();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        // Escape - Clear selection
        setState(() {
          _selectedItem = null;
        });
        return true;
      }
    }
    return false;
  }
  
  void _focusSearchField() {
    // Would set focus to search field
    // Requires a focus node implementation
  }

  Future<void> _initializeService() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      await _menuService.initialize();
      await _loadMenuItemsFromDatabase();
    } catch (e) {
      print('Error initializing service: $e');
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = 'Failed to initialize: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _initializeService,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadMenuItemsFromDatabase() async {
    if (!_menuService.isInitialized) {
      await _initializeService();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _menuService.fetchMenuItems();
      setState(() {
        _menuItems = items;
        _isLoading = false;
        _sortMenuItems();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = 'Failed to load menu items: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading menu items: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _sortMenuItems() {
    _menuItems.sort((a, b) {
      var aVal = a[_sortField];
      var bVal = b[_sortField];
      
      int result;
      if (aVal is String && bVal is String) {
        result = aVal.compareTo(bVal);
      } else if (aVal is num && bVal is num) {
        result = aVal.compareTo(bVal);
      } else if (aVal is bool && bVal is bool) {
        result = aVal ? 1 : -1;
      } else {
        result = 0;
      }
      
      return _sortAscending ? result : -result;
    });
  }

  // Filter menu items based on category and search
  List<Map<String, dynamic>> get _filteredMenuItems {
    return _menuItems.where((item) {
      // Filter by category
      if (_selectedCategory != 'All' && item['category'] != _selectedCategory) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final name = item['name'].toString().toLowerCase();
        final id = item['id'].toString().toLowerCase();
        final category = item['category'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();

        return name.contains(query) ||
            id.contains(query) ||
            category.contains(query);
      }

      return true;
    }).toList();
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 100,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializeService,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      floatingActionButton: _isError
          ? null
          : FloatingActionButton(
              onPressed: () => _navigateToAddEditScreen(null),
              backgroundColor: _accentColor,
              tooltip: 'Add New Menu Item (Ctrl+N)',
              child: const Icon(Icons.add),
            ),
      body: _isError
          ? _buildErrorView()
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : _buildDesktopLayout(),
    );
  }
  
 

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sidebar with filters
              _buildFilterSidebar(),
              
              // Main content area - Table of menu items
              Expanded(
                flex: _selectedItem != null ? 3 : 5,
                child: _buildMenuItemsTable(),
              ),
              
              // Detail panel (shown when item is selected)
              if (_selectedItem != null)
                Expanded(
                  flex: 2,
                  child: _buildDetailPanel(),
                ),
            ],
          ),
        ),
        _buildStatusBar(),
      ],
    );
  }
  
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search menu items... (Ctrl+F)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          
          // Action buttons
          _buildActionButton(
            icon: Icons.refresh,
            label: 'Refresh',
            onPressed: _loadMenuItemsFromDatabase,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.add,
            label: 'Add Item',
            onPressed: () => _navigateToAddEditScreen(null),
            isPrimary: true,
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? _accentColor : Colors.grey[200],
        foregroundColor: isPrimary ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
  
  Widget _buildFilterSidebar() {
    return Container(
      width: 220,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'FILTERS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          
          // Category filters
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildCategoryHeader(),
                ..._categories.map(_buildCategoryTile),
                
                const Divider(),
                
                // Additional filters
                _buildFilterTile(
                  title: 'Vegetarian Only',
                  icon: Icons.eco_outlined,
                  onTap: () {},
                ),
                _buildFilterTile(
                  title: 'Available Items Only',
                  icon: Icons.check_circle_outline,
                  onTap: () {},
                ),
                _buildFilterTile(
                  title: 'Popular Items',
                  icon: Icons.star_outline,
                  onTap: () {},
                ),
                _buildFilterTile(
                  title: 'Discounted Items',
                  icon: Icons.discount_outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        'CATEGORIES',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
          fontSize: 13,
        ),
      ),
    );
  }
  
  Widget _buildCategoryTile(String category) {
    final isSelected = _selectedCategory == category;
    
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: _primaryColor.withOpacity(0.1),
      leading: isSelected
          ? Icon(Icons.folder, color: _primaryColor)
          : Icon(Icons.folder_outlined, color: Colors.grey[600]),
      title: Text(
        category,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? _primaryColor : Colors.black87,
        ),
      ),
      trailing: category != 'All'
          ? Text(
              _menuItems.where((item) => item['category'] == category).length.toString(),
              style: TextStyle(color: Colors.grey[600]),
            )
          : Text(
              _menuItems.length.toString(),
              style: TextStyle(color: Colors.grey[600]),
            ),
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
    );
  }
  
  Widget _buildFilterTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget _buildMenuItemsTable() {
    final filteredItems = _filteredMenuItems;
    
    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }
    
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          _buildTableHeader(),
          
          // Table content
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                final isSelected = _selectedItem != null && 
                                  _selectedItem!['id'] == item['id'];
                
                return _buildTableRow(item, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _buildTableCell('Image', flex: 1, isHeader: true),
          _buildSortableHeader('name', 'Name', flex: 3),
          _buildSortableHeader('category', 'Category', flex: 2),
          _buildSortableHeader('price', 'Price', flex: 1),
          _buildTableCell('Vegetarian', flex: 1, isHeader: true),
          _buildTableCell('Available', flex: 1, isHeader: true),
          _buildTableCell('Actions', flex: 2, isHeader: true),
        ],
      ),
    );
  }
  
  Widget _buildSortableHeader(String field, String label, {int flex = 1}) {
    final isCurrentSortField = _sortField == field;
    
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isCurrentSortField) {
              _sortAscending = !_sortAscending;
            } else {
              _sortField = field;
              _sortAscending = true;
            }
            _sortMenuItems();
          });
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (isCurrentSortField)
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTableRow(Map<String, dynamic> item, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedItem = isSelected ? null : item;
        });
      },
      hoverColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.1) : null,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _buildTableImageCell(item['image']),
            _buildTableCell(item['name'], flex: 3),
            _buildTableCell(item['category'], flex: 2),
            _buildTableCell('\₹${item['price']}', flex: 1, alignment: Alignment.center),
            _buildVegetarianCell(item['isVegetarian']),
            _buildAvailabilityCell(item['available']),
            _buildActionsCell(item),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTableCell(String text, {
    int flex = 1, 
    bool isHeader = false,
    Alignment alignment = Alignment.center,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            fontSize: isHeader ? 14 : 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
  
  Widget _buildTableImageCell(String? imageUrl) {
    return Expanded(
      flex: 1,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 20),
                  ),
                )
              : Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[200],
                  child: Icon(Icons.restaurant, size: 20, color: _primaryColor),
                ),
        ),
      ),
    );
  }
  
  Widget _buildVegetarianCell(bool isVegetarian) {
    return Expanded(
      flex: 1,
      child: Container(
        alignment: Alignment.center,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isVegetarian ? Colors.green[50] : Colors.red[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.circle,
            size: 14,
            color: isVegetarian ? Colors.green[800] : Colors.red[800],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAvailabilityCell(bool isAvailable) {
    return Expanded(
      flex: 1,
      child: Container(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isAvailable ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isAvailable ? 'Yes' : 'No',
            style: TextStyle(
              color: isAvailable ? Colors.green[800] : Colors.red[800],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionsCell(Map<String, dynamic> item) {
    return Expanded(
      flex: 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: 'Edit Item',
            onPressed: () => _navigateToAddEditScreen(item),
          ),
          IconButton(
            icon: Icon(
              item['available'] ? Icons.visibility_off : Icons.visibility,
              size: 20,
            ),
            tooltip: item['available'] ? 'Mark Unavailable' : 'Mark Available',
            onPressed: () => _toggleItemAvailability(item),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            tooltip: 'Delete Item',
            onPressed: () => _showDeleteConfirmation(item),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailPanel() {
    final item = _selectedItem!;
    final isAvailable = item['available'] as bool;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with close button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryColor.withAlpha(20),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Item Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedItem = null;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item image
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item['image'] != null && (item['image'] as String).isNotEmpty
                        ? Image.network(
                            item['image'] as String,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 180,
                                width: 180,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.broken_image,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                          )
                        : Container(
                            height: 180,
                            width: 180,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.restaurant,
                              size: 60,
                              color: _primaryColor.withAlpha(127),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Item name and badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] as String,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (item['isPopular'] as bool)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'POPULAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Category and tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag(item['category'] as String),
                      _buildTag(
                        item['isVegetarian'] as bool ? 'Vegetarian' : 'Non-vegetarian',
                        color: item['isVegetarian'] as bool ? Colors.green : Colors.red,
                      ),
                      _buildTag(
                        isAvailable ? 'Available' : 'Unavailable',
                        color: isAvailable ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Price section
                  _buildSectionHeader('Price Details'),
                  const SizedBox(height: 8),
                  if (item.containsKey('hasDiscount') && item['hasDiscount'] == true)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Original Price:'),
                            const SizedBox(width: 8),
                            Text(
                              '₹${item['price']}',
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Discount:'),
                            const SizedBox(width: 8),
                            Text(
                              '${item['discount']}%',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Final Price:'),
                            const SizedBox(width: 8),
                            Text(
                              '₹${((num.tryParse(item['price']?.toString() ?? '0') ?? 0) * (1 - (num.tryParse(item['discount']?.toString() ?? '0') ?? 0) / 100)).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Text(
                      '₹${item['price']}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Description section
                  _buildSectionHeader('Description'),
                  const SizedBox(height: 8),
                  Text(
                    item['description'] as String? ?? 'No description available',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  
                  // Item details section
                  _buildSectionHeader('Item Details'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Item ID', item['id'] as String),
                  _buildDetailRow('Updated By', item['updatedBy'] as String? ?? _currentUserLogin),
                  _buildDetailRow('Last Updated', _formatDate(item['updatedAt'] as String? ?? _currentDate)),
                ],
              ),
            ),
          ),
          
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToAddEditScreen(item),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleItemAvailability(item),
                    icon: Icon(
                      isAvailable ? Icons.visibility_off : Icons.visibility,
                    ),
                    label: Text(
                      isAvailable ? 'Mark Unavailable' : 'Mark Available',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable ? Colors.orange : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(String dateString) {
    // Simple date formatting for display purposes
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
  
  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 1,
          color: Colors.grey[300],
        ),
      ],
    );
  }
  
  Widget _buildTag(String text, {Color color = Colors.blue}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBar() {
    final itemCount = _filteredMenuItems.length;
    final totalItems = _menuItems.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Showing $itemCount of $totalItems items',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            'Last updated: $_currentDate',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.no_food,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'No menu items found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != 'All'
                ? 'Try a different search term or category'
                : 'Start by adding your first menu item',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddEditScreen(null),
            icon: const Icon(Icons.add),
            label: const Text('Add Menu Item', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddEditScreen(Map<String, dynamic>? item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditMenuItemScreen(
          item: item,
          currentDate: _currentDate,
          userLogin: _currentUserLogin,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Refresh the list if changes were made
        _loadMenuItemsFromDatabase();
      }
    });
  }

  void _toggleItemAvailability(Map<String, dynamic> item) async {
    try {
      final bool newStatus = !(item['available'] as bool);
      await _menuService.toggleItemAvailability(
        item['id'],
        newStatus,
        _currentDate,
        _currentUserLogin
      );

      // Refresh the list
      _loadMenuItemsFromDatabase();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${item['name']} marked as ${newStatus ? 'available' : 'unavailable'}'),
          backgroundColor: newStatus ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Menu Item'),
          content: Text(
            'Are you sure you want to delete "${item['name']}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _menuService.deleteMenuItem(item['id']);
                  Navigator.of(context).pop();

                  // If the deleted item was selected, clear the selection
                  if (_selectedItem != null && _selectedItem!['id'] == item['id']) {
                    setState(() {
                      _selectedItem = null;
                    });
                  }

                  // Refresh the list
                  _loadMenuItemsFromDatabase();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item['name']} has been deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting item: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

class _KeyboardShortcutRow extends StatelessWidget {
  final String shortcut;
  final String description;
  
  const _KeyboardShortcutRow({
    required this.shortcut,
    required this.description,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(description),
        ],
      ),
    );
  }
}