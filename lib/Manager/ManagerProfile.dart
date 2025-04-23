import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ManagerProfile extends StatefulWidget {
  @override
  _ManagerProfileState createState() => _ManagerProfileState();
}

class _ManagerProfileState extends State<ManagerProfile> {
  bool isEditing = false;
  bool showSaveMessage = false;
  bool showPasswordMessage = false;
  bool showLanguageMessage = false;

  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

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
      });
    }
  }

  bool isCurrentPasswordVisible = false;
  bool isNewPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  String selectedLanguage = 'en';
  Map<String, String> savedInfo = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 161, 159, 159),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
      ),
      body: Stack(
        children: [
          Row(
            children: [
              Container(
               width: 360,
               color:  const Color.fromARGB(255, 234, 229, 241), // Set the deep blue background here
               child: Align(
                  alignment: Alignment.topLeft,
                    child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 80),
                    child: Container(
                      width: 300,
                      margin: const EdgeInsets.only(left: 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Transform.translate(
                                offset: const Offset(0, -20),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 80,
                                      backgroundColor:
                                          Colors.deepPurple.shade100,
                                      backgroundImage: _pickedImage != null
                                          ? FileImage(_pickedImage!)
                                          : null,
                                      child: _pickedImage == null
                                          ? (nameController.text.isNotEmpty
                                              ? Text(
                                                  nameController.text[0]
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 40,
                                                      color: Colors.black),
                                                )
                                              : const Icon(Icons.person,
                                                  size: 40,
                                                  color: Colors.black))
                                          : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 4,
                                      child: Row(
                                        children: [
                                          // Camera icon
                                          CircleAvatar(
                                            backgroundColor: Colors.white,
                                            radius: 14,
                                            child: IconButton(
                                              icon: const Icon(Icons.camera_alt,
                                                  size: 14,
                                                  color: Colors.black),
                                              onPressed: _pickImage,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // ❌ Remove icon
                                          if (_pickedImage != null)
                                            CircleAvatar(
                                              backgroundColor: Colors.white,
                                              radius: 14,
                                              child: IconButton(
                                                icon: const Icon(Icons.close,
                                                    size: 14,
                                                    color: Colors.red),
                                                onPressed: () {
                                                  setState(() {
                                                    _pickedImage = null;
                                                  });
                                                },
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )),
                          ),
                          const SizedBox(height: 12),
                          if (savedInfo.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: savedInfo.entries
                                  .where((entry) => entry.value.isNotEmpty)
                                  .map((entry) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 260,
                            child: OutlinedButton(
                              onPressed: () {
                                if (isEditing) {
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

                                  Future.delayed(const Duration(seconds: 3),
                                      () {
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
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                backgroundColor:
                                    const Color.fromARGB(255, 245, 245, 245),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 14),
                              ),
                              child: Text(
                                isEditing ? 'Save Profile' : 'Edit Profile',
                                style: const TextStyle(
                                  color: Colors.black87,
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
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            SizedBox(
                                width: 220,
                                child: _buildField('Name', nameController)),
                            SizedBox(
                                width: 200,
                                child: _buildField('Role', roleController)),
                            SizedBox(
                                width: 280,
                                child: _buildField('Email', emailController)),
                            SizedBox(
                                width: 220,
                                child: _buildField(
                                    'Phone Number', phoneController)),
                            SizedBox(
                                width: 200,
                                child: _buildField(
                                    'Location', locationController)),
                            SizedBox(
                                width: 280,
                                child:
                                    _buildField('Address', addressController)),
                          ],
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Change Password',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Your new password must be different from current password.',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        const SizedBox(height: 20),
                        _buildPasswordField(
                            'Current Password', currentPasswordController),
                        _buildPasswordField(
                            'New Password', newPasswordController),
                        _buildPasswordField(
                            'Confirm Password', confirmPasswordController),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: isEditing
                                ? () {
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
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              backgroundColor:
                                  const Color.fromARGB(255, 200, 211, 230),
                            ),
                            child: const Text(
                              'Update Password',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Change Language',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Select your preferred language for the interface.',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        const SizedBox(height: 20),
                        _buildLanguageTile('English', 'English',
                            'assets/img/us_image.png', 'en'),
                        const SizedBox(height: 10),
                        _buildLanguageTile('Hindi', 'हिंदी',
                            'assets/img/india_image.png', 'hi'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showSaveMessage)
            Positioned(
              bottom: 20, // Adjust the position from top
              left: 20, // Move the message to the left layout
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text(
                  'Profile successfully saved!!',
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
            ),
          if (showPasswordMessage)
            Positioned(
              bottom: 20,
              right: 620,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text(
                  'Password updated successfully!!',
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
            ),
          if (showLanguageMessage)
            Positioned(
              bottom: 20,
              right: 620,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text(
                  'Language changed successfully!!',
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
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
      child: SizedBox(
        width: 450,
        child: TextField(
          controller: controller,
          obscureText: !isVisible,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: IconButton(
              icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
              onPressed: isEditing ? toggleVisibility : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
  return TextField(
    controller: controller,
    enabled: isEditing,
    style: TextStyle(
      color: isEditing ? Colors.black : Colors.black, // Can customize differently if needed
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      border: const OutlineInputBorder(),
      // Optional: make the background a little different in non-edit mode
      filled: !isEditing,
      fillColor: !isEditing ? const Color.fromARGB(255, 245, 245, 245) : null,
    ),
  );
}


  Widget _buildLanguageTile(
      String title, String subtitle, String iconPath, String code) {
    return SizedBox(
      width: 450,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Image.asset(iconPath, width: 24),
          title: Text(title, style: const TextStyle(fontSize: 14)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: IgnorePointer(
            ignoring: !isEditing,
            child: Radio<String>(
              value: code,
              groupValue: selectedLanguage,
              onChanged: (value) {
                setState(() {
                  selectedLanguage = value!;
                  showLanguageMessage = true;
                });

                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() {
                      showLanguageMessage = false;
                    });
                  }
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
