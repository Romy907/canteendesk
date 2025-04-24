import 'package:canteendesk/Firebase/FirebaseManager.dart';
import 'package:canteendesk/Services/ImgBBService.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ManagerProfile extends StatefulWidget {
  final String userLogin;
  
  const ManagerProfile({Key? key, this.userLogin = "navin280123"}) : super(key: key);
  
  @override
  _ManagerProfileState createState() => _ManagerProfileState();
}

class _ManagerProfileState extends State<ManagerProfile> {
  bool isEditing = false;
  bool showSaveMessage = false;
  bool showPasswordMessage = false;

  File? _pickedImage;
  String? _imagePath;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _imageUrlController = TextEditingController();
  bool _isImageFromUrl = false;
  String _currentDateTime = "2025-04-24 12:15:47"; // Default value

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final nameController = TextEditingController();
  final roleController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final locationController = TextEditingController();
  final addressController = TextEditingController();

  
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
        _imagePath = pickedFile.path;
        _isImageFromUrl = false;
      });
      
      // Upload the image and get the URL
      final url = await ImgBBService().uploadImage(File(pickedFile.path));
      
      setState(() {
        _imageUrl = url;
      });
      
      // Save image info to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('profileImageUrl', url!); // Save the URL returned from upload
    }
  }

  void _setImageFromUrl() {
    if (_imageUrlController.text.isNotEmpty) {
      setState(() async {
        final prefs = await SharedPreferences.getInstance();
        _imageUrl = prefs.getString('profile_image_url') ?? _imageUrlController.text;
        _isImageFromUrl = true;
        _pickedImage = null;
        _imagePath = null;
      });
      // Save image URL to SharedPreferences
      _saveImageUrlToPrefs();
    }
  }

  Future<void> _saveImageUrlToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('profileImageUrl', _imageUrl ?? '');
;
  }

  void _updateCurrentDateTime() {
    setState(() {
      _currentDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    });
  }

  bool isCurrentPasswordVisible = false;
  bool isNewPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  Map<String, String> savedInfo = {};

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _updateCurrentDateTime();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      nameController.text = prefs.getString('name') ?? '';
      roleController.text = prefs.getString('role') ?? '';
      emailController.text = prefs.getString('email') ?? '';
      phoneController.text = prefs.getString('phone') ?? '';
      locationController.text = prefs.getString('location') ?? '';
      addressController.text = prefs.getString('university') ?? '';
      
      _isImageFromUrl = prefs.getBool('is_image_from_url') ?? false;
      _imageUrl = prefs.getString('profileImageUrl');
      
      if (!_isImageFromUrl) {
        _imagePath = prefs.getString('profile_image_path');
        if (_imagePath != null) {
          _pickedImage = File(_imagePath!);
        }
      }
      
      if (_imageUrl != null) {
        _imageUrlController.text = _imageUrl!;
      }
      
      savedInfo = {
        'Name': nameController.text,
        'Role': roleController.text,
        'Email': emailController.text,
        'Phone': phoneController.text,
        'Location': locationController.text,
        'Address': addressController.text,
      };
    });
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    
    prefs.setString('name', nameController.text);
    prefs.setString('role', roleController.text);
    prefs.setString('email', emailController.text);
    prefs.setString('phone', phoneController.text);
    prefs.setString('location', locationController.text);
    prefs.setString('address', addressController.text);
    
    // Save the current image source state
    if (_imageUrl != null) {
      prefs.setString('profile_image_url', _imageUrl!);
      prefs.setBool('is_image_from_url', _isImageFromUrl);
      
      if (!_isImageFromUrl && _imagePath != null) {
        prefs.setString('profile_image_path', _imagePath!);
      } else {
        prefs.remove('profile_image_path');
      }
    }

    // Prepare user data to send
    final userData = {
      'name': nameController.text,
      'role': roleController.text,
      'email': emailController.text,
      'phone': phoneController.text,
      'location': locationController.text,
      'address': addressController.text,
      'profileImageUrl': _imageUrl,
    };

    // Call the saveUserData method
    await FirebaseManager().saveUserData(userData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0), // Windows-like background color
      appBar: AppBar(
        backgroundColor: const Color(0xFF0078D7), // Windows blue
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('User Profile', style: TextStyle(color: Colors.white)),
      ),
      body: Row(
        children: [
          // Left sidebar
          Container(
            width: 260,
            color: const Color(0xFFE6E6E6), // Light gray sidebar
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: _imageUrl != null
                              ? NetworkImage(_imageUrl!)
                              : _pickedImage != null
                                  ? FileImage(_pickedImage!)
                                  : null,
                          child: (_imageUrl == null && _pickedImage == null)
                              ? (nameController.text.isNotEmpty
                                  ? Text(
                                      nameController.text[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 40,
                                        color: Color(0xFF0078D7),
                                      ),
                                    )
                                  : const Icon(Icons.person,
                                      size: 40, color: Color(0xFF0078D7)))
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Camera icon
                                IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Color(0xFF0078D7),
                                  ),
                                  onPressed: isEditing ? _pickImage : null,
                                  tooltip: 'Choose picture',
                                ),
                                // Web URL icon
                                IconButton(
                                  icon: const Icon(
                                    Icons.link,
                                    size: 18,
                                    color: Color(0xFF0078D7),
                                  ),
                                  onPressed: isEditing
                                      ? () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Enter Image URL'),
                                              content: TextField(
                                                controller: _imageUrlController,
                                                decoration: const InputDecoration(
                                                  hintText: 'https://example.com/image.jpg',
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    _setImageFromUrl();
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: const Text('Set Image'),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      : null,
                                  tooltip: 'Image from URL',
                                ),
                                // Delete icon
                                if (_pickedImage != null || _imageUrl != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: isEditing
                                        ? () {
                                            setState(() {
                                              _pickedImage = null;
                                              _imagePath = null;
                                              _imageUrl = null;
                                              _isImageFromUrl = false;
                                            });
                                          }
                                        : null,
                                    tooltip: 'Remove',
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // User login and date display
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Color(0xFF555555),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Login: ${widget.userLogin}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 16,
                                color: Color(0xFF555555),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'UTC: $_currentDateTime',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Display saved info
                    if (!isEditing && savedInfo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: savedInfo.entries
                                  .where((entry) => entry.value.isNotEmpty)
                                  .map((entry) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.key}: ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          entry.value,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Edit/Save button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF0078D7),
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () {
                          if (isEditing) {
                            _saveProfileData(); // Save to SharedPreferences
                            setState(() {
                              savedInfo = {
                                'Name': nameController.text,
                                'Role': roleController.text,
                                'Email': emailController.text,
                                'Phone': phoneController.text,
                                'Location': locationController.text,
                                'Address': addressController.text,
                              };
                              isEditing = false;
                              showSaveMessage = true;
                            });

                            Future.delayed(const Duration(seconds: 3), () {
                              if (mounted) {
                                setState(() {
                                  showSaveMessage = false;
                                });
                              }
                            });
                          } else {
                            setState(() {
                              isEditing = true;
                              showSaveMessage = false;
                            });
                          }
                        },
                        child: Text(
                          isEditing ? 'Save Profile' : 'Edit Profile',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Main content area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Personal Information Section
                        Row(
                          children: [
                            Icon(Icons.person,
                                color: const Color(0xFF0078D7), size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFFDDDDDD)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            SizedBox(
                              width: 320,
                              child: _buildField('Name', nameController),
                            ),
                            SizedBox(
                              width: 320,
                              child: _buildField('Role', roleController),
                            ),
                            SizedBox(
                              width: 320,
                              child: _buildField('Email', emailController),
                            ),
                            SizedBox(
                              width: 320,
                              child: _buildField(
                                  'Phone Number', phoneController),
                            ),
                            SizedBox(
                              width: 320,
                              child: _buildField(
                                  'Location', locationController),
                            ),
                            SizedBox(
                              width: 320,
                              child: _buildField('Address', addressController),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Password Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Row(
                          children: [
                          Icon(Icons.lock,
                            color: const Color(0xFF0078D7), size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Change Password',
                            style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                            ),
                          ),
                          ],
                        ),
                        const Divider(color: Color(0xFFDDDDDD)),
                        const SizedBox(height: 8),
                        const Text(
                          'Your new password must be different from current password.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(
                          'Current Password', currentPasswordController),
                        _buildPasswordField(
                          'New Password', newPasswordController),
                        _buildPasswordField(
                          'Confirm Password', confirmPasswordController),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: isEditing
                            ? () async {
                              if (newPasswordController.text ==
                                confirmPasswordController.text) {
                              await FirebaseManager().changePassword(
                                newPasswordController.text);
                              setState(() {
                                showPasswordMessage = true;
                              });

                              Future.delayed(const Duration(seconds: 2),
                                () {
                                if (mounted) {
                                setState(() {
                                  showPasswordMessage = false;
                                });
                                }
                              });
                              } else {
                              // Handle password mismatch
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                content: Text(
                                  'New password and confirm password do not match.'),
                                ),
                              );
                              }
                            }
                            : null,
                          style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF0078D7),
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          ),
                          child: const Text(
                          'Update Password',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Notification messages
      bottomSheet: showSaveMessage || showPasswordMessage
          ? Container(
              width: double.infinity,
              color: const Color(0xFF0078D7),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                showPasswordMessage
                    ? 'Password updated successfully!'
                    : 'Profile successfully saved!',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    bool isVisible;
    VoidCallback toggleVisibility;

    if (label == 'Current Password') {
      isVisible = isCurrentPasswordVisible;
      toggleVisibility = () {
        setState(() {
          isCurrentPasswordVisible = !isCurrentPasswordVisible;
        });
      };
    } else if (label == 'New Password') {
      isVisible = isNewPasswordVisible;
      toggleVisibility = () {
        setState(() {
          isNewPasswordVisible = !isNewPasswordVisible;
        });
      };
    } else {
      isVisible = isConfirmPasswordVisible;
      toggleVisibility = () {
        setState(() {
          isConfirmPasswordVisible = !isConfirmPasswordVisible;
        });
      };
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        enabled: isEditing,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isEditing ? const Color(0xFF0078D7) : Colors.grey,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF0078D7), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          filled: !isEditing,
          fillColor: !isEditing ? Colors.grey.shade100 : Colors.transparent,
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: isEditing ? const Color(0xFF0078D7) : Colors.grey,
              size: 20,
            ),
            onPressed: isEditing ? toggleVisibility : null,
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      enabled: isEditing,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isEditing ? const Color(0xFF0078D7) : Colors.grey,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF0078D7), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: !isEditing,
        fillColor: !isEditing ? Colors.grey.shade100 : Colors.transparent,
      ),
    );
  }
}