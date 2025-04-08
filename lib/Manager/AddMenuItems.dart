import 'package:canteendesk/Services/ImgBBService.dart';
import 'package:canteendesk/Services/MenuServices.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
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
  bool _isImageExpanded = false;

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
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
  );

  late final _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: _primaryColor, width: 2),
  );

  late final _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
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
      _descriptionController.text =
          widget.item!['description'] as String? ?? '';

      // Make sure to properly handle the preparationTime
      if (widget.item!.containsKey('preparationTime') &&
          widget.item!['preparationTime'] != null) {
        _selectedTime = widget.item!['preparationTime'] as String;
        print('Initialized preparation time: $_selectedTime'); // Debug print
      }

      _selectedCategory = widget.item!['category'] as String;
      _isAvailable = widget.item!['available'] as bool;
      _isVegetarian = widget.item!['isVegetarian'] as bool;
      _isPopular = widget.item!['isPopular'] as bool;
      _currentImageUrl = widget.item!['image'] as String?;

      // Properly initialize discount fields from existing data
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ).animate().fade().slideY(begin: 0.3, end: 0),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageSourceOption(
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
                  ).animate().scale(
                      delay: 200.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutBack),
                  _imageSourceOption(
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
                  ).animate().scale(
                      delay: 400.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutBack),
                ],
              ),
              if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32.0),
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Remove Current Image',
                        style: TextStyle(color: Colors.red)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentImageUrl = null;
                      });
                    },
                  ).animate().fade(delay: 600.ms),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _imageSourceOption({
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
    if (_imageFile == null) return _currentImageUrl ?? '';

    try {
      setState(() {
        _isUploading = true;
      });

      // First compress the image to reduce upload size
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/compressed_menu_image.jpg';

      // Compress the file
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        _imageFile!.path,
        tempPath,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
      );

      if (compressedFile == null) {
        throw Exception('Failed to compress image');
      }

      // Upload compressed file to ImgBB
      final imageUrl =
          await _imgBBService.uploadImage(File(compressedFile.path));

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('Failed to upload image to ImgBB');
      }

      return imageUrl;
    } catch (e) {
      _showSnackBar('Failed to upload image: $e', isError: true);
      return '';
    } finally {
      setState(() {
        _isUploading = false;
      });
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
      // Scroll to the first error field
      _showSnackBar('Please fix the errors in the form', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload image if changed
      String imageUrl = _currentImageUrl ?? '';

      if (_imageFile != null) {
        imageUrl = await _uploadImage();
        if (imageUrl.isEmpty) {
          throw Exception('Image upload failed');
        }
      }

      // Debug print to verify the current selected time
      print('Saving menu item with preparation time: $_selectedTime');

      final Map<String, dynamic> menuData = {
        'name': _nameController.text.trim(),
        'price': _priceController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'preparationTime':
            _selectedTime, // This should contain the correct value
        'available': _isAvailable,
        'isVegetarian': _isVegetarian,
        'isPopular': _isPopular,
        'hasDiscount': _hasDiscount,
        'discount': _hasDiscount ? _discountController.text.trim() : '0',
        'image': imageUrl,
        'lastUpdated': widget.currentDate,
        'updatedBy': widget.userLogin,
      };

      if (widget.item == null) {
        // Add new item
        await _menuService.addMenuItem(
            menuData, widget.currentDate, widget.userLogin);
        _showSnackBar('${menuData['name']} added successfully');
      } else {
        // Update existing item
        await _menuService.updateMenuItem(
            widget.item!['id'], menuData, widget.currentDate, widget.userLogin);
        _showSnackBar('${menuData['name']} updated successfully');
      }

      Navigator.pop(context, true); // Return success
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.item != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Menu Item' : 'Add New Item',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: _primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (!_isLoading)
              TextButton.icon(
                onPressed: _saveMenuItem,
                icon:
                    const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text(
                  'SAVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .move(begin: const Offset(20, 0), curve: Curves.easeOutQuad),
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
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 200,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEditing
                          ? 'Updating menu item...'
                          : 'Creating new menu item...',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).scale(
                    delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  bool isDesktop = constraints.maxWidth > 800;
                  return Stack(
                    children: [
                      // Top curved background
                      // Container(
                      //   height: 60,
                      //   width: double.infinity,
                      //   decoration: BoxDecoration(
                      //     color: _primaryColor,
                      //     borderRadius: const BorderRadius.vertical(
                      //       bottom: Radius.circular(30),
                      //     ),
                      //   ),
                      // ),

                      // Form content
                      SafeArea(
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                                isDesktop ? 50 : 16, 8, isDesktop ? 50 : 16, 32),
                            children: [
                              // Image picker card
                              _buildImagePickerCard(),

                              

                          // Details section
_buildSectionHeader('Item Details', CupertinoIcons.doc_text_fill)
  .animate()
  .fadeIn(delay: 100.ms, duration: 200.ms),
_buildDetailsCard()
  .animate()
  .fadeIn(delay: 100.ms)
  .slideY(begin: 0.2, end: 0, duration: 200.ms),

// Pricing section
_buildSectionHeader('Pricing', CupertinoIcons.money_dollar_circle_fill)
  .animate()
  .fadeIn(delay: 100.ms, duration: 500.ms),
_buildPriceAndDiscountCard()
  .animate()
  .fadeIn(delay: 100.ms)
  .slideY(begin: 0.2, end: 0, duration: 200.ms),

// Options section
_buildSectionHeader('Options', CupertinoIcons.settings_solid)
  .animate()
  .fadeIn(delay: 100.ms, duration: 500.ms),
_buildOptionsCard()
  .animate()
  .fadeIn(delay: 100.ms)
  .slideY(begin: 0.2, end: 0, duration: 200.ms),

// Item history (for editing)
if (isEditing)
  _buildItemHistoryCard()
    .animate()
    .fadeIn(delay: 100.ms)
    .slideY(begin: 0.2, end: 0, duration: 200.ms),

const SizedBox(height: 24),

// Save button
_buildSaveButton(isEditing)
  .animate()
  .fadeIn(delay: 100.ms, duration: 500.ms)
  .scale(delay: 100.ms, duration: 600.ms, curve: Curves.easeOutBack),
                        ],
                      ),
                     ),
                   ),
                  ],
                 );
                }
              
      ),
      )
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

Widget _buildDetailsCard() {
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
key: Key(
'preparationTimeDropdown'), // Add a key for better state management
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
// Optional debugging: print to verify the value is changing
print(
'Selected preparation time changed to: $_selectedTime');
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

Widget _buildImagePickerCard() {
return GestureDetector(
onTap: _isUploading ? null : _pickImage,
child: Card(
elevation: 0,
color: _cardColor,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
margin: const EdgeInsets.only(top: 16),
clipBehavior: Clip.antiAlias,
child: Container(
height: _isImageExpanded ? 300 : 220,
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
              icon: Icon(
                _isImageExpanded
                    ? CupertinoIcons.arrow_down_circle_fill
                    : CupertinoIcons.arrow_up_circle_fill,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                _isImageExpanded ? 'Collapse' : 'Expand',
                style: const TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.black26,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                setState(() {
                  _isImageExpanded = !_isImageExpanded;
                });
              },
            ),
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
          ],
        ),
      ),
    )
],
),
),
)
    .animate()
    .fadeIn(duration: 500.ms)
    .scale(delay: 100.ms, curve: Curves.easeOutBack),
);
}

  Widget _buildPriceAndDiscountCard() {
  return LayoutBuilder(
    builder: (context, constraints) {
      bool isDesktop = constraints.maxWidth > 800;
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: _cardColor,
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: isDesktop
              ? Row(
                  children: [
                    Expanded(child: _buildPriceField()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDiscountSection()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPriceField(),
                    const SizedBox(height: 24),
                    _buildDiscountSection(),
                  ],
                ),
        ),
      );
    },
  );
}

Widget _buildPriceField() {
  return TextFormField(
    controller: _priceController,
    decoration: InputDecoration(
      labelText: 'Price',
      hintText: 'Enter price',
      prefixText: '₹ ',
      border: _inputBorder,
      focusedBorder: _focusedBorder,
      errorBorder: _errorBorder,
      prefixIcon: Icon(CupertinoIcons.money_rubl_circle_fill, color: _accentColor),
      floatingLabelStyle: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
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
  );
}

Widget _buildDiscountSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
                        borderSide: BorderSide(color: _discountColor, width: 2),
                      ),
                      prefixIcon: Icon(CupertinoIcons.percent, color: _discountColor),
                      suffixText: '%',
                      floatingLabelStyle: TextStyle(color: _discountColor, fontWeight: FontWeight.bold),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                  _buildDiscountPreview(),
                ],
              )
            : const SizedBox.shrink(),
      ),
    ],
  );
}

Widget _buildDiscountPreview() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    decoration: BoxDecoration(
      color: _discountColor.withAlpha(20),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _discountColor.withAlpha(76)),
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
          child: Icon(CupertinoIcons.money_dollar_circle, color: _discountColor),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
  );
}

Widget _buildOptionsCard() {
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
          _buildOptionTile(
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
          _buildOptionTile(
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
          _buildOptionTile(
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

Widget _buildOptionTile({
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
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
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

Widget _buildItemHistoryCard() {
  final String lastUpdated = widget.item?['lastUpdated'] ?? widget.currentDate;
  final String updatedBy = widget.item?['updatedBy'] ?? widget.userLogin;

  // Format date for better readability
  String formattedDate;
  try {
    final DateTime dateTime = DateTime.parse(lastUpdated);
    formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  } catch (e) {
    formattedDate = lastUpdated;
  }

  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    color: _cardColor,
    margin: const EdgeInsets.only(top: 24),
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.time, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                'Item History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.calendar, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Last Updated: ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(CupertinoIcons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Updated By: ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      updatedBy,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildSaveButton(bool isEditing) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton.icon(
      icon: Icon(
        isEditing ? CupertinoIcons.checkmark_circle : CupertinoIcons.plus_circle,
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onPressed: _saveMenuItem,
    ),
  );
}
    }