import 'package:canteendesk/Manager/AddMenuItems.dart';
import 'package:flutter/material.dart';

class ManagerManageMenu extends StatefulWidget {
  const ManagerManageMenu({Key? key}) : super(key: key);

  @override
  _ManagerManageMenuState createState() => _ManagerManageMenuState();
}

class _ManagerManageMenuState extends State<ManagerManageMenu> {
  final Color _primaryColor = const Color.fromARGB(255, 136, 107, 175);
  final Color _accentColor = const Color(0xFF26C6DA);

  List<Map<String, dynamic>> _menuItems = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  bool _isGridView = false;
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

  String _currentDate = "2025-03-09 19:21:27";
  String _currentUserLogin = "navin280123";

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _loadMenuItems() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    // Simulate loading data
    await Future.delayed(Duration(seconds: 2));

    // Example data
    _menuItems = [
      {
        'id': '1',
        'name': 'Pizza',
        'price': 9.99,
        'category': 'Main Course',
        'available': true,
        'isVegetarian': false,
        'isPopular': true,
        'image': null,
        'description': 'Delicious cheese pizza'
      },
      // Add more items as needed
    ];

    setState(() {
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredMenuItems {
    return _menuItems.where((item) {
      if (_selectedCategory != 'All' && item['category'] != _selectedCategory) {
        return false;
      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Menu Items',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view,
                color: Colors.white),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      floatingActionButton: _isError
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _navigateToAddEditScreen(null),
              backgroundColor: _accentColor,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              tooltip: 'Add New Menu Item',
            ),
      body: _isError
          ? _buildErrorView()
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 800) {
                      return _buildMobileLayout();
                    } else {
                      return _buildDesktopLayout();
                    }
                  },
                ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildCategorySelector(),
        _buildItemCountHeader(),
        Expanded(
          child: _isGridView ? _buildGridView() : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildSearchBar(),
              _buildCategorySelector(),
              _buildItemCountHeader(),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: _isGridView ? _buildGridView() : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      color: _primaryColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search menu items...',
              hintStyle: TextStyle(color: Colors.white.withAlpha(178)),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withAlpha(51),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1000) {
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      }
                    },
                    backgroundColor: Colors.white.withAlpha(51),
                    selectedColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? _primaryColor
                          : const Color.fromARGB(255, 2, 2, 2),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
              },
            );
          } else {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    }
                  },
                  backgroundColor: Colors.white.withAlpha(51),
                  selectedColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? _primaryColor
                        : const Color.fromARGB(255, 2, 2, 2),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                );
              }).toList(),
            );
          }
        },
      ),
    );
  }

  Widget _buildItemCountHeader() {
    final itemCount = _filteredMenuItems.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'} found',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Sort by: ',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    _buildSortDropdown(),
                  ],
                ),
              ],
            );
          } else {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'} found',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Sort by: ',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    _buildSortDropdown(),
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSortDropdown() {
    return DropdownButton<String>(
      value: 'Name',
      underline: Container(),
      icon: const Icon(Icons.keyboard_arrow_down),
      items: [
        'Name',
        'Price: Low to High',
        'Price: High to Low',
        'Category'
      ].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          if (newValue == 'Name') {
            _menuItems.sort((a, b) =>
                (a['name'] as String).compareTo(b['name'] as String));
          } else if (newValue == 'Price: Low to High') {
            _menuItems.sort((a, b) =>
                (num.tryParse(a['price'].toString()) ?? 0).compareTo(
                    num.tryParse(b['price'].toString()) ?? 0));
          } else if (newValue == 'Price: High to Low') {
            _menuItems.sort((a, b) =>
                (num.tryParse(b['price'].toString()) ?? 0).compareTo(
                    num.tryParse(a['price'].toString()) ?? 0));
          } else if (newValue == 'Category') {
            _menuItems.sort((a, b) => (a['category'] as String)
                .compareTo(b['category'] as String));
          }
        });
      },
    );
  }

  Widget _buildListView() {
    final filteredItems = _filteredMenuItems;

    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildListItem(item);
      },
    );
  }

  Widget _buildGridView() {
    final filteredItems = _filteredMenuItems;

    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width < 800 ? 2 : 4,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildGridItem(item);
      },
    );
  }

  Widget _buildListItemImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        color: Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.restaurant,
            color: _primaryColor,
            size: 30,
          ),
        ),
      );
    }

    return Image.network(
      imageUrl,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 60,
          height: 60,
          color: Colors.grey[200],
          child: Center(
            child: Icon(Icons.broken_image, size: 30, color: Colors.grey),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 60,
          height: 60,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridItemImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: 120,
        width: double.infinity,
        color: Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.restaurant,
            size: 40,
            color: _primaryColor.withAlpha(127),
          ),
        ),
      );
    }

    return Image.network(
      imageUrl,
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 120,
          width: double.infinity,
          color: Colors.grey[200],
          child: Center(
            child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 120,
          width: double.infinity,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    final bool isAvailable = item['available'] as bool;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Card(
          margin: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 16,
            vertical: isDesktop ? 12 : 6,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 16 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildListItemImage(item['image'] as String?),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['name'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 18 : 14,
                                decoration: isAvailable ? null : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          if (item['isPopular'] as bool)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Popular',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (item.containsKey('hasDiscount') && item['hasDiscount'] == true) ...[
                        Row(
                          children: [
                            Text(
                              '₹${item['price'] ?? 0}',
                              style: TextStyle(
                                fontSize: isDesktop ? 16 : 14,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '\₹${((num.tryParse(item['price']?.toString() ?? '0') ?? 0) * (1 - (num.tryParse(item['discount']?.toString() ?? '0') ?? 0) / 100)).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: isDesktop ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          '\₹${item['price'] ?? 0}',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                                            const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isAvailable ? Icons.check_circle_outline : Icons.cancel_outlined,
                            size: isDesktop ? 16 : 14,
                            color: isAvailable ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAvailable ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              fontSize: isDesktop ? 14 : 12,
                              color: isAvailable ? Colors.green : Colors.red,
                            ),
                          ),
                          if (item['isVegetarian'] as bool) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                shape: BoxShape.rectangle,
                              ),
                              child: Icon(
                                Icons.circle,
                                size: isDesktop ? 16 : 14,
                                color: Colors.green[800],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                shape: BoxShape.rectangle,
                              ),
                              child: Icon(
                                Icons.circle,
                                size: isDesktop ? 16 : 14,
                                color: Colors.red[800],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _navigateToAddEditScreen(item);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isAvailable ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(isAvailable ? 'Mark Unavailable' : 'Mark Available'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
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

  Widget _buildGridItem(Map<String, dynamic> item) {
    final bool isAvailable = item['available'] as bool;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: isDesktop ? 4 : 2,
          child: InkWell(
            onTap: () => _showItemDetails(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _buildGridItemImage(item['image'] as String?),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(127),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_vert,
                              color: Colors.white, size: 20),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _navigateToAddEditScreen(item);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  isAvailable
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(isAvailable
                                    ? 'Mark Unavailable'
                                    : 'Mark Available'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isAvailable)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withAlpha(102),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'UNAVAILABLE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 16 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['name'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 16 : 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item['isVegetarian'] as bool)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.eco_outlined,
                                size: isDesktop ? 16 : 14,
                                color: Colors.green[800],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (item.containsKey('hasDiscount') &&
                          item['hasDiscount'] == true) ...[
                        Row(
                          children: [
                            Text(
                              '₹${item['price'] ?? 0}',
                              style: TextStyle(
                                fontSize: isDesktop ? 16 : 14,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${((num.tryParse(item['price']?.toString() ?? '0') ?? 0) * (1 - (num.tryParse(item['discount']?.toString() ?? '0') ?? 0) / 100)).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: isDesktop ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          '₹${item['price'] ?? 0}',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.no_food,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No menu items found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term or category'
                : 'Add your first menu item',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddEditScreen(null),
            icon: const Icon(Icons.add),
            label: const Text('Add Menu Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
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
        _loadMenuItems();
      }
    });
  }

  void _showItemDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 60,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Item header with image
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item['image'] != null &&
                            (item['image'] as String).isNotEmpty
                        ? Image.network(
                            item['image'] as String,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 100,
                                height: 100,
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
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.restaurant,
                                size: 40,
                                color: _primaryColor.withAlpha(127),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['name'] as String,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (item['isPopular'] as bool)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'POPULAR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (item.containsKey('hasDiscount') &&
                            item['hasDiscount'] == true) ...[
                          Text(
                            'Discount: ${item['discount'] ?? 0}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Original Price: ₹${item['price'] ?? 0}',
                            style: TextStyle(
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Discounted Price: ₹${((num.tryParse(item['price']?.toString() ?? '0') ?? 0) * (1 - (num.tryParse(item['discount']?.toString() ?? '0') ?? 0) / 100)).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ] else ...[
                          Text(
                            '₹${item['price'] ?? 0}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item['category'] as String,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (item['isVegetarian'] as bool)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.eco_outlined,
                                      size: 12,
                                      color: Colors.green[800],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Vegetarian',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[800],
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

              const SizedBox(height: 24),

              // Item status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (item['available'] as bool)
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      (item['available'] as bool)
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: (item['available'] as bool)
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (item['available'] as bool)
                          ? 'This item is currently available'
                          : 'This item is currently unavailable',
                      style: TextStyle(
                        color: (item['available'] as bool)
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item['description'] as String? ?? 'No description available',
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 24),

              // Item details
              const Text(
                'Item Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Item ID', item['id'] as String),
              
              _buildDetailRow('Updated By',
                  item['updatedBy'] as String? ?? _currentUserLogin),

              const Spacer(),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToAddEditScreen(item);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Item'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Expanded(
                  //   child: ElevatedButton.icon(
                      // onPressed: () {
                      //   Navigator.pop(context);
                      //   _toggleItemAvailability(item);
                      // },
                      // icon: Icon(
                      //   (item['available'] as bool)
                      //       ? Icons.visibility_off
                      //       : Icons.visibility,
                      // ),
                      // label: Text(
                      //   (item['available'] as bool)
                      //       ? 'Mark Unavailable'
                      //       : 'Mark Available',
                      // ),
                      // style: ElevatedButton.styleFrom(
                      //   backgroundColor: _accentColor,
                      //   padding: const EdgeInsets.symmetric(vertical: 12),
                      // ),
                   // ),
                 // ),
                ],
              ),
            ],
          ),
        );
      },
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
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  _buildErrorView() {}
}
  // void _toggleItemAvailability(Map<String, dynamic> item) async {
  //   try {
  //     final bool newStatus = !(item['available'] as bool);
  //     // Update item availability status
  //     setState(() {
  //       item['available'] = newStatus;
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //             '${item['name']} marked as ${newStatus ? 'available' : 'unavailable'}'),
  //         backgroundColor: newStatus ? Colors.green : Colors.orange,
  //       ),
  //     );
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error updating item: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  // Widget _buildErrorView() {
  //   return Center(
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Icon(Icons.error_outline, size: 80, color: Colors.red),
  //         const SizedBox(height: 16),
  //         Text(
  //           'An error occurred',
  //           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
  //         ),
  //         const SizedBox(height: 8),
  //         Text(
  //           _errorMessage.isNotEmpty ? _errorMessage : 'Something went wrong. Please try again.',
  //           textAlign: TextAlign.center,
  //           style: TextStyle(color: Colors.grey[600]),
  //         ),
  //         const SizedBox(height: 24),
  //         ElevatedButton(
  //           onPressed: _loadMenuItems,
  //           child: const Text('Retry'),
  //           style: ElevatedButton.styleFrom(
  //             primary: _accentColor,
  //             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(30),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // void _showDeleteConfirmation(Map<String, dynamic> item) {
  //   var context;
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Delete Menu Item'),
  //         content: Text(
  //           'Are you sure you want to delete "${item['name']}"? This action cannot be undone.',
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: const Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               // Remove item from the list
  //               setState(() {
  //                 menuItems.remove(item);
  //               });

  //               Navigator.of(context).pop();

  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 SnackBar(
  //                   content: Text('${item['name']} has been deleted'),
  //                   backgroundColor: Colors.red,
  //                   action: SnackBarAction(
  //                     label: 'Undo',
  //                     textColor: Colors.white,
  //                     onPressed: () {
  //                       // This would require storing the deleted item and re-adding it
  //                       // For now, we'll just display a message
  //                       ScaffoldMessenger.of(context).showSnackBar(
  //                         const SnackBar(
  //                           content: Text(
  //                               'Restore functionality would be implemented here'),
  //                         ),
  //                       );
  //                     },
  //                   ),
  //                 ),
  //               );
  //             },
  //             style: TextButton.styleFrom(
  //               foregroundColor: Colors.red,
  //             ),
  //             child: const Text('Delete'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

