import 'package:canteendesk/Services/ImgBBService.dart';
import 'package:canteendesk/Services/MenuServices.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io';

class AddEditMenuItemScreen extends StatefulWidget {
  final Map<String, dynamic>? item; // Null if adding new item
  final String currentDate;
  final String userLogin;

  const AddEditMenuItemScreen({
    Key? key,
    this.item,
    required this.currentDate,
    required this.userLogin,
  }) : super(key: key);

  @override
  _AddEditMenuItemScreenState createState() => _AddEditMenuItemScreenState();
}

class _AddEditMenuItemScreenState extends State<AddEditMenuItemScreen>
    with SingleTickerProviderStateMixin {
  final MenuService _menuService = MenuService();
  final ImgBBService _imgBBService = ImgBBService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  String _selectedCategory = 'Main Course';
  String _selectedTime = '10 min';
  bool _isAvailable = true;
  bool _isVegetarian = false;
  bool _isPopular = false;
  bool _hasDiscount = false;
  File? _imageFile;
  String? _currentImageUrl;
  bool _isLoading = false;
  bool _isUploading = false;

  // UI Colors & Theme
  final Color _primaryColor = const Color(0xFF5E35B1); // Deep Purple
  final Color _accentColor = const Color(0xFF00BFA5); // Teal Accent
  final Color _cardColor = Colors.white;
  final Color _backgroundColor = const Color(0xFFF9F9FB);
  final Color _vegetarianColor = const Color(0xFF43A047); // Green
  final Color _popularColor = const Color(0xFFFF9800); // Orange
  final Color _discountColor = const Color(0xFFE91E63); // Pink
  final Color _errorColor = const Color(0xFFD50000); // Red

  // Input form border styling
  late final _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
  );

  late final _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: _primaryColor, width: 2),
  );

  late final _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: _errorColor, width: 1.5),
  );

  List<String> categories = [
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
  
  List<String> times = [
    '5 min',
    '10 min',
    '15 min',
    '20 min',
    '25 min',
    '30 min',
    '35 min',
    '40 min',
    '45 min',
  ];

  @override
  void initState() {
    super.initState();
    _initializeService();

    // Initialize form with existing item data if editing
    if (widget.item != null) {
      _nameController.text = widget.item!['name'] as String;
      _priceController.text = widget.item!['price'] as String;
      _descriptionController.text = widget.item!['description'] as String? ?? '';

      if (widget.item!.containsKey('preparationTime') &&
          widget.item!['preparationTime'] != null) {
        _selectedTime = widget.item!['preparationTime'] as String;
      }

      _selectedCategory = widget.item!['category'] as String;
      _isAvailable = widget.item!['available'] as bool;
      _isVegetarian = widget.item!['isVegetarian'] as bool;
      _isPopular = widget.item!['isPopular'] as bool;
      _currentImageUrl = widget.item!['image'] as String?;

      // Initialize discount fields from existing data
      _hasDiscount = widget.item!['hasDiscount'] as bool? ?? false;
      _discountController.text = widget.item!['discount']?.toString() ?? '0';
    } else {
      _discountController.text = '0';
    }

    // Add listeners to controllers to update UI when values change
    _priceController.addListener(_onFormValueChange);
    _discountController.addListener(_onFormValueChange);
  }

  Future<void> _initializeService() async {
    try {
      await _menuService.initialize();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error initializing service: $e', isError: true);
      }
    }
  }

  // Called when price or discount changes to update the UI
  void _onFormValueChange() {
    if (mounted) {
      setState(() {
        // Trigger rebuild to update discount preview
      });
    }
  }

  @override
  void dispose() {
    _priceController.removeListener(_onFormValueChange);
    _discountController.removeListener(_onFormValueChange);

    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    _scrollController.dispose();
    
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      backgroundColor: isError ? _errorColor : _accentColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(10),
      duration: Duration(seconds: isError ? 4 : 3),
      action: isError
          ? SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _initializeService,
            )
          : null,
    ));
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    // Determine if we're on a small screen (likely mobile) or larger screen (likely desktop)
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    if (isSmallScreen) {
      // Use bottom sheet for mobile-sized screens
      showModalBottomSheet(
        context: context,
        backgroundColor: _cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Add Item Image',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _imageSourceOptionMobile(
                      icon: CupertinoIcons.camera_fill,
                      title: 'Camera',
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? photo = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                        );
                        if (photo != null) {
                          setState(() {
                            _imageFile = File(photo.path);
                          });
                        }
                      },
                    ),
                    _imageSourceOptionMobile(
                      icon: CupertinoIcons.photo_fill,
                      title: 'Gallery',
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (image != null) {
                          setState(() {
                            _imageFile = File(image.path);
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32.0),
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Remove Current Image',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _currentImageUrl = null;
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    } else {
      // Use dialog for desktop-sized screens
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Select Image Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.photo_library, color: _primaryColor),
                    title: const Text('Choose from Gallery'),
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      if (image != null) {
                        setState(() {
                          _imageFile = File(image.path);
                        });
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.camera_alt, color: _primaryColor),
                    title: const Text('Take a Photo'),
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? photo = await picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      if (photo != null) {
                        setState(() {
                          _imageFile = File(photo.path);
                        });
                      }
                    },
                  ),
                  if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: const Text('Remove Current Image'),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _currentImageUrl = null;
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
        },
      );
    }
  }

  Widget _imageSourceOptionMobile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: _primaryColor.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primaryColor.withAlpha(51)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: _primaryColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _uploadImage() async {
    if (_imageFile == null) {
      debugPrint('No image file selected for upload.');
      return _currentImageUrl ?? '';
    }

    try {
      setState(() {
        _isUploading = true;
      });

      debugPrint('Uploading image to ImgBB...');
      // Upload the image file to ImgBB
      final imageUrl = await _imgBBService.uploadImage(_imageFile!);

      if (imageUrl == null || imageUrl.isEmpty) {
        debugPrint('Image upload to ImgBB failed.');
        throw Exception('Failed to upload image to ImgBB');
      }

      debugPrint('Image uploaded successfully. URL: $imageUrl');
      return imageUrl;
    } catch (e) {
      debugPrint('Error during image upload: $e');
      _showSnackBar('Failed to upload image: $e', isError: true);
      return '';
    } finally {
      setState(() {
        _isUploading = false;
      });
      debugPrint('Image upload process completed.');
    }
  }

  // Calculate discounted price for preview
  String _calculateDiscountedPrice() {
    try {
      double price = double.tryParse(_priceController.text) ?? 0.0;
      double discount = double.tryParse(_discountController.text) ?? 0.0;

      // Ensure discount is within valid range
      discount = discount.clamp(0.0, 100.0);

      // Calculate final price
      double finalPrice = price - (price * discount / 100);
      return finalPrice.toStringAsFixed(2);
    } catch (e) {
      return '0.00';
    }
  }

  Future<void> _saveMenuItem() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors in the form', isError: true);
      debugPrint('Form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Starting to save menu item...');
      
      // Upload image if changed
      String imageUrl = _currentImageUrl ?? '';
      if (_imageFile != null) {
        debugPrint('Uploading image...');
        imageUrl = await _uploadImage();
        if (imageUrl.isEmpty) {
          debugPrint('Image upload failed');
          throw Exception('Image upload failed');
        }
        debugPrint('Image uploaded successfully: $imageUrl');
      }

      final Map<String, dynamic> menuData = {
        'name': _nameController.text.trim(),
        'price': _priceController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'preparationTime': _selectedTime,
        'available': _isAvailable,
        'isVegetarian': _isVegetarian,
        'isPopular': _isPopular,
        'hasDiscount': _hasDiscount,
        'discount': _hasDiscount ? _discountController.text.trim() : '0',
        'image': imageUrl,
        'lastUpdated': widget.currentDate,
        'updatedBy': widget.userLogin,
      };

      debugPrint('Menu data prepared: $menuData');

      if (widget.item == null) {
        // Add new item
        debugPrint('Adding new menu item...');
        await _menuService.addMenuItem(
            menuData, widget.currentDate, widget.userLogin);
        _showSnackBar('${menuData['name']} added successfully');
        debugPrint('Menu item added successfully');
      } else {
        // Update existing item
        debugPrint('Updating existing menu item with ID: ${widget.item!['id']}');
        await _menuService.updateMenuItem(
            widget.item!['id'], menuData, widget.currentDate, widget.userLogin);
        _showSnackBar('${menuData['name']} updated successfully');
        debugPrint('Menu item updated successfully');
      }

      Navigator.pop(context, true); // Return success
      debugPrint('Navigation back with success');
    } catch (e) {
      debugPrint('Error occurred: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Save menu item process completed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.item != null;
    final size = MediaQuery.of(context).size;
    
    // Define responsive breakpoints
    final bool isMobile = size.width < 600;
    final bool isTablet = size.width >= 600 && size.width < 960;
    final bool isDesktop = size.width >= 960;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Menu Item' : 'Add New Menu Item',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: isMobile,
          backgroundColor: _primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(isMobile ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (!_isLoading && isMobile)
              TextButton.icon(
                onPressed: _saveMenuItem,
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text(
                  'SAVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            if (!_isLoading && !isMobile)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ElevatedButton.icon(
                  onPressed: _saveMenuItem,
                  icon: const Icon(Icons.save),
                  label: Text(
                    isEditing ? 'UPDATE' : 'SAVE',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Shimmer.fromColors(
                      baseColor: _primaryColor.withAlpha(102),
                      highlightColor: _accentColor.withAlpha(102),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isEditing
                          ? 'Updating menu item...'
                          : 'Creating new menu item...',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : isMobile
                ? _buildMobileLayout(isEditing)
                : _buildResponsiveLayout(isEditing, isDesktop),
      ),
    );
  }

  // Mobile-optimized layout (single column)
  Widget _buildMobileLayout(bool isEditing) {
    return Form(
      key: _formKey,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Image picker card
          _buildImagePickerCardMobile(),

          // Details section
          _buildSectionHeader('Item Details', CupertinoIcons.doc_text_fill),
          _buildDetailsCardMobile(),

          // Pricing section
          _buildSectionHeader('Pricing', CupertinoIcons.money_dollar_circle_fill),
          _buildPriceAndDiscountCardMobile(),

          // Options section
          _buildSectionHeader('Options', CupertinoIcons.settings_solid),
          _buildOptionsCardMobile(),

          // Item history (for editing)

          const SizedBox(height: 24),

          // Save button
          _buildSaveButton(isEditing),
        ],
      ),
    );
  }
  
  // Responsive layout for tablet and desktop
  Widget _buildResponsiveLayout(bool isEditing, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: isDesktop
            ? _buildDesktopLayout(isEditing)
            : _buildTabletLayout(isEditing),
      ),
    );
  }

  // Desktop layout (side-by-side columns)
  Widget _buildDesktopLayout(bool isEditing) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column - Image and Options
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image picker section
                _buildImagePickerSection(),
                const SizedBox(height: 24),
                _buildOptionsCard(),
                if (isEditing) const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 24),
        
        // Right column - Form fields and Save button
        Expanded(
          flex: 3,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item ID if editing
                    if (widget.item != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primaryColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.tag, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ID: ${(widget.item!['id'] as String)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                    Text(
                      'Item Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Main item details using a two-column layout
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First column - Name, Category
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'Item Name',
                                  hint: 'Enter item name',
                                  icon: CupertinoIcons.tag_fill,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter an item name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                _buildDropdown(
                                  label: 'Category',
                                  icon: CupertinoIcons.rectangle_grid_1x2_fill,
                                  value: _selectedCategory,
                                  items: categories,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedCategory = value;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 24),
                          
                          // Second column - Price and Preparation Time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: _priceController,
                                  label: 'Price',
                                  hint: 'Enter price',
                                  icon: CupertinoIcons.money_rubl_circle_fill,
                                  prefixText: '₹ ',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a price';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                _buildDropdown(
                                  label: 'Preparation Time',
                                  icon: CupertinoIcons.time_solid,
                                  value: _selectedTime,
                                  items: times,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedTime = value;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // Description field
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Enter item description (optional)',
                      icon: CupertinoIcons.text_alignleft,
                      maxLines: 4,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Discount section
                    Text(
                      'Discount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _discountColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDiscountSection(),
                    
                    const SizedBox(height: 32),
                    
                    // Save button
                    _buildSaveButton(isEditing),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Tablet layout (scrollable with wider elements)
  Widget _buildTabletLayout(bool isEditing) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with image and options side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker section
              Expanded(
                flex: 1,
                child: _buildImagePickerSection(),
              ),
              
              const SizedBox(width: 16),
              
              // Options and history card
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _buildOptionsCard(),
                    if (isEditing) 
                      const SizedBox(height: 16),
                    
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Details card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item ID if editing
                  if (widget.item != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primaryColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tag, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'ID: ${(widget.item!['id'] as String)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                  Text(
                    'Item Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Two fields per row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _nameController,
                          label: 'Item Name',
                          hint: 'Enter item name',
                          icon: CupertinoIcons.tag_fill,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an item name';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      Expanded(
                        child: _buildTextField(
                          controller: _priceController,
                          label: 'Price',
                          hint: 'Enter price',
                          icon: CupertinoIcons.money_rubl_circle_fill,
                          prefixText: '₹ ',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a price';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Two dropdowns per row
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Category',
                          icon: CupertinoIcons.rectangle_grid_1x2_fill,
                          value: _selectedCategory,
                          items: categories,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            }
                          },
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      Expanded(
                        child: _buildDropdown(
                          label: 'Preparation Time',
                          icon: CupertinoIcons.time_solid,
                          value: _selectedTime,
                          items: times,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedTime = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description field
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Enter item description (optional)',
                    icon: CupertinoIcons.text_alignleft,
                    maxLines: 4,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Discount section
                  Text(
                    'Discount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _discountColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDiscountSection(),
                  
                  const SizedBox(height: 32),
                  
                  // Save button
                  _buildSaveButton(isEditing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        border: _inputBorder,
        focusedBorder: _focusedBorder,
        errorBorder: _errorBorder,
        prefixIcon: Icon(icon, color: _primaryColor),
        floatingLabelStyle: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.sentences,
      validator: validator,
    );
  }
  
  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: _inputBorder,
        focusedBorder: _focusedBorder,
        prefixIcon: Icon(icon, color: _primaryColor),
        floatingLabelStyle: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      value: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(8),
      icon: const Icon(Icons.arrow_drop_down_circle, size: 18),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildImagePickerSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Item Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ),
          InkWell(
            onTap: _isUploading ? null : _pickImage,
            child: Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(
                  color: _imageFile != null ||
                      (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                      ? Colors.transparent
                      : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image or placeholder
                  if (_imageFile != null)
                    Image.file(
                      _imageFile!,
                      fit: BoxFit.contain,
                    )
                  else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                    Image.network(
                      _currentImageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image_rounded,
                                  size: 50, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 64,
                          color: _primaryColor.withAlpha(153),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Add Item Photo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click to browse',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),

                  // Loading indicator
                  if (_isUploading)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: Text(
                    _imageFile != null || (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                    ? 'Change Image'
                    : 'Choose Image',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                if (_imageFile != null || (_currentImageUrl != null && _currentImageUrl!.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _imageFile = null;
                          _currentImageUrl = null;
                        });
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Remove', style: TextStyle(color: Colors.red)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mobile-specific image picker card
  Widget _buildImagePickerCardMobile() {
    return GestureDetector(
      onTap: _isUploading ? null : _pickImage,
      child: Card(
        elevation: 0,
        color: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.only(top: 16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: _imageFile != null ||
                      (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                  ? Colors.transparent
                  : Colors.grey.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image or placeholder
              if (_imageFile != null)
                Image.file(
                  _imageFile!,
                  fit: BoxFit.cover,
                )
              else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                Image.network(
                  _currentImageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image_rounded,
                              size: 50, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.camera_circle_fill,
                      size: 60,
                      color: _primaryColor.withAlpha(153),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add Item Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to select',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),

              // Loading indicator
              if (_isUploading)
                Container(
                  color: Colors.black.withAlpha(127),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),

              // Image controls
              if (_imageFile != null ||
                  (_currentImageUrl != null && _currentImageUrl!.isNotEmpty))
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(178),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(
                            CupertinoIcons.camera_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Change',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: _primaryColor.withAlpha(178),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: _pickImage,
                        ),
                        TextButton.icon(
                          icon: const Icon(
                            CupertinoIcons.trash_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Remove',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.withAlpha(178),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () {
                            setState(() {
                              _imageFile = null;
                              _currentImageUrl = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCardMobile() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: _cardColor,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item ID if editing
            if (widget.item != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tag, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'ID: ${(widget.item!['id'] as String).substring(0, 10)}...',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Item name field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                hintText: 'Enter item name',
                border: _inputBorder,
                focusedBorder: _focusedBorder,
                errorBorder: _errorBorder,
                prefixIcon: Icon(CupertinoIcons.tag_fill, color: _primaryColor),
                floatingLabelStyle: TextStyle(
                    color: _primaryColor, fontWeight: FontWeight.bold),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an item name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Category dropdown
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Category',
                border: _inputBorder,
                focusedBorder: _focusedBorder,
                prefixIcon: Icon(CupertinoIcons.rectangle_grid_1x2_fill,
                    color: _primaryColor),
                floatingLabelStyle: TextStyle(
                    color: _primaryColor, fontWeight: FontWeight.bold),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              value: _selectedCategory,
              isExpanded: true,
              borderRadius: BorderRadius.circular(15),
              icon: const Icon(CupertinoIcons.chevron_down_circle, size: 18),
              items: categories
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(
                          category,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            // Preparation time dropdown
            DropdownButtonFormField<String>(
              key: const Key('preparationTimeDropdown'),
              decoration: InputDecoration(
                labelText: 'Preparation Time',
                border: _inputBorder,
                focusedBorder: _focusedBorder,
                prefixIcon:
                    Icon(CupertinoIcons.time_solid, color: _primaryColor),
                floatingLabelStyle: TextStyle(
                    color: _primaryColor, fontWeight: FontWeight.bold),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              value: _selectedTime,
              isExpanded: true,
              borderRadius: BorderRadius.circular(15),
              icon: const Icon(CupertinoIcons.chevron_down_circle, size: 18),
              items: times
                  .map((time) => DropdownMenuItem(
                        value: time,
                        child: Text(time, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTime = value;
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a preparation time';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Enter item description (optional)',
                border: _inputBorder,
                focusedBorder: _focusedBorder,
                prefixIcon:
                    Icon(CupertinoIcons.text_alignleft, color: _primaryColor),
                floatingLabelStyle: TextStyle(
                    color: _primaryColor, fontWeight: FontWeight.bold),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAndDiscountCardMobile() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: _cardColor,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price field
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Price',
                hintText: 'Enter price',
                prefixText: '₹ ',
                border: _inputBorder,
                focusedBorder: _focusedBorder,
                errorBorder: _errorBorder,
                prefixIcon: Icon(CupertinoIcons.money_rubl_circle_fill,
                    color: _accentColor),
                floatingLabelStyle:
                    TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                if (double.tryParse(value) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Discount Switch
            InkWell(
              onTap: () {
                setState(() {
                  _hasDiscount = !_hasDiscount;
                  if (!_hasDiscount) {
                    _discountController.text = '0';
                  } else if (_discountController.text == '0') {
                    _discountController.text = '10'; // Default value
                  }
                  _onFormValueChange();
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      _hasDiscount
                          ? CupertinoIcons.tag_fill
                          : CupertinoIcons.tag,
                      color: _discountColor,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Apply Discount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: _hasDiscount,
                      activeColor: _discountColor,
                      onChanged: (value) {
                        setState(() {
                          _hasDiscount = value;
                          if (!value) {
                            _discountController.text = '0';
                          } else if (_discountController.text == '0') {
                            _discountController.text = '10'; // Default value
                          }
                          _onFormValueChange();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Discount content - shown only when discount is enabled
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _hasDiscount
                  ? Column(
                      children: [
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _discountController,
                          decoration: InputDecoration(
                            labelText: 'Discount Percentage',
                            hintText: 'Enter discount %',
                            border: _inputBorder,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide:
                                  BorderSide(color: _discountColor, width: 2),
                            ),
                            prefixIcon: Icon(CupertinoIcons.percent,
                                color: _discountColor),
                            suffixText: '%',
                            floatingLabelStyle: TextStyle(
                                color: _discountColor,
                                fontWeight: FontWeight.bold),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _hasDiscount
                              ? (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter discount percentage';
                                  }
                                  int? percent = int.tryParse(value);
                                  if (percent == null) {
                                    return 'Enter a valid number';
                                  }
                                  if (percent < 0 || percent > 100) {
                                    return 'Discount must be between 0-100%';
                                  }
                                  return null;
                                }
                              : null,
                        ),

                        const SizedBox(height: 24),

                        // Discount preview
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: _discountColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(15),
                            border:
                                Border.all(color: _discountColor.withAlpha(76)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _discountColor.withAlpha(38),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(CupertinoIcons.money_dollar_circle,
                                    color: _discountColor),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Original: ',
                                          style: TextStyle(
                                              fontSize: 14, color: Colors.grey),
                                        ),
                                        Text(
                                          '₹${_priceController.text.isEmpty ? '0.00' : _priceController.text}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Final: ',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: _discountColor,
                                          ),
                                        ),
                                        Text(
                                          '₹${_calculateDiscountedPrice()}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: _discountColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                                                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _discountColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_discountController.text}% OFF',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCardMobile() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: _cardColor,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Available option
            _buildOptionTileMobile(
              title: 'Available',
              subtitle: 'Show this item on the menu',
              icon: CupertinoIcons.eye_fill,
              value: _isAvailable,
              color: _primaryColor,
              onChanged: (value) {
                setState(() {
                  _isAvailable = value;
                });
              },
            ),

            const Divider(height: 20, thickness: 1),

            // Vegetarian option
            _buildOptionTileMobile(
              title: 'Vegetarian',
              subtitle: 'Mark as vegetarian option',
              icon: CupertinoIcons.leaf_arrow_circlepath,
              value: _isVegetarian,
              color: _vegetarianColor,
              onChanged: (value) {
                setState(() {
                  _isVegetarian = value;
                });
              },
            ),

            const Divider(height: 20, thickness: 1),

            // Popular option
            _buildOptionTileMobile(
              title: 'Popular',
              subtitle: 'Highlight as popular choice',
              icon: CupertinoIcons.star_fill,
              value: _isPopular,
              color: _popularColor,
              onChanged: (value) {
                setState(() {
                  _isPopular = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionTileMobile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Color color,
    required Function(bool) onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeColor: color,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Options in a row for desktop layout
            Row(
              children: [
                Expanded(
                  child: _buildOptionTile(
                    title: 'Available',
                    subtitle: 'Show on menu',
                    icon: CupertinoIcons.eye_fill,
                    value: _isAvailable,
                    color: _primaryColor,
                    onChanged: (value) {
                      setState(() {
                        _isAvailable = value;
                      });
                    },
                  ),
                ),
                
                Expanded(
                  child: _buildOptionTile(
                    title: 'Vegetarian',
                    subtitle: 'Veg option',
                    icon: CupertinoIcons.leaf_arrow_circlepath,
                    value: _isVegetarian,
                    color: _vegetarianColor,
                    onChanged: (value) {
                      setState(() {
                        _isVegetarian = value;
                      });
                    },
                  ),
                ),
                
                Expanded(
                  child: _buildOptionTile(
                    title: 'Popular',
                    subtitle: 'Highlight item',
                    icon: CupertinoIcons.star_fill,
                    value: _isPopular,
                    color: _popularColor,
                    onChanged: (value) {
                      setState(() {
                        _isPopular = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Color color,
    required Function(bool) onChanged,
  }) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                activeColor: color,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Discount Switch
            Row(
              children: [
                Icon(
                  _hasDiscount ? CupertinoIcons.tag_fill : CupertinoIcons.tag,
                  color: _discountColor,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Apply Discount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _hasDiscount,
                  activeColor: _discountColor,
                  onChanged: (value) {
                    setState(() {
                      _hasDiscount = value;
                      if (!value) {
                        _discountController.text = '0';
                      } else if (_discountController.text == '0') {
                        _discountController.text = '10'; // Default value
                      }
                      _onFormValueChange();
                    });
                  },
                ),
              ],
            ),

            // Discount content - shown only when discount is enabled
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _hasDiscount
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Discount percentage input
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _discountController,
                              decoration: InputDecoration(
                                labelText: 'Discount Percentage',
                                hintText: 'Enter discount %',
                                border: _inputBorder,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: _discountColor, width: 2),
                                ),
                                prefixIcon: Icon(CupertinoIcons.percent, color: _discountColor),
                                suffixText: '%',
                                floatingLabelStyle: TextStyle(
                                  color: _discountColor,
                                  fontWeight: FontWeight.bold
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter discount percentage';
                                }
                                int? percent = int.tryParse(value);
                                if (percent == null) {
                                  return 'Enter a valid number';
                                }
                                if (percent < 0 || percent > 100) {
                                  return 'Discount must be between 0-100%';
                                }
                                return null;
                              },
                            ),
                          ),
                          
                          const SizedBox(width: 24),
                          
                          // Discount preview
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _discountColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _discountColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _discountColor.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(CupertinoIcons.money_dollar_circle,
                                        color: _discountColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'Original: ',
                                              style: TextStyle(fontSize: 14, color: Colors.grey),
                                            ),
                                            Text(
                                              '₹${_priceController.text.isEmpty ? '0.00' : _priceController.text}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'Final: ',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: _discountColor,
                                              ),
                                            ),
                                            Text(
                                              '₹${_calculateDiscountedPrice()}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: _discountColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4
                                    ),
                                    decoration: BoxDecoration(
                                      color: _discountColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_discountController.text}% OFF',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

 

  Widget _buildSaveButton(bool isEditing) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        icon: Icon(
          isEditing
              ? Icons.save
              : Icons.add_circle,
          color: Colors.white,
          size: 22,
        ),
        label: Text(
          isEditing ? 'UPDATE ITEM' : 'ADD TO MENU',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: _saveMenuItem,
      ),
    );
  }
}