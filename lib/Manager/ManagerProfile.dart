import 'package:flutter/material.dart';

class ManagerProfile extends StatefulWidget {
  @override
  _ManagerProfileState createState() => _ManagerProfileState();
}

class _ManagerProfileState extends State<ManagerProfile> {
  bool isEditing = false;

bool isPasswordEditing = false;

final currentPasswordController = TextEditingController();
final newPasswordController = TextEditingController();
final confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 224, 223, 223),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
      ),
      body: Row(
        children: [
          SizedBox(
            width: 360,
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
                              const CircleAvatar(
                                radius: 80,
                                backgroundImage: AssetImage('assets/img/me.jpg'),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 4,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 14,
                                  child: Icon(Icons.edit, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 260,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              isEditing = !isEditing;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: const Color.fromARGB(255, 245, 245, 245),
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: const VerticalDivider(
              width: 1,
              thickness: 3,
              color: Colors.grey,
            ),
          ),
          Expanded(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              SizedBox(width: 250, child: _buildField('Name', TextEditingController())),
              SizedBox(width: 250, child: _buildField('Role', TextEditingController())),
              SizedBox(width: 250, child: _buildField('Email', TextEditingController())),
              SizedBox(width: 250, child: _buildField('Phone Number', TextEditingController())),
              SizedBox(width: 250, child: _buildField('Location', TextEditingController())),
              SizedBox(width: 250, child: _buildField('Address', TextEditingController())),
            ],
          ),
          const SizedBox(height: 40),
          Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      'Change Password',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    TextButton.icon(
      icon: const Icon(Icons.edit, size: 20, color: Colors.black),
      label: const Text('Edit', style: TextStyle(color: Colors.black)),
      onPressed: () {
        setState(() {
          isPasswordEditing = !isPasswordEditing;
        });
      },
    ),
  ],
),
          const SizedBox(height: 10),
          const Text(
            'Your new password must be different from current password',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _buildPasswordField('Current Password', currentPasswordController, isPasswordEditing),
          _buildPasswordField('New Password', newPasswordController, isPasswordEditing),
          _buildPasswordField('Confirm Password', confirmPasswordController, isPasswordEditing),
          
          if (isPasswordEditing)
  Align(
    alignment: Alignment.centerLeft,
    child: ElevatedButton(
      onPressed: () {
        print('Current: ${currentPasswordController.text}');
        print('New: ${newPasswordController.text}');
        print('Confirm: ${confirmPasswordController.text}');

        // You can add password validation logic here before saving
        setState(() {
          isPasswordEditing = false;
        });
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        backgroundColor: const Color.fromARGB(255, 200, 211, 230),
      ),
      child: const Text(
        'Update Password',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    ),
  ),

          const SizedBox(height: 40),
          const Text(
            'Change Language',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Select your preferred language for the interface',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _buildLanguageTile('English', 'English', 'assets/img/us_image.png', 'en'),
          const SizedBox(height: 10),
          _buildLanguageTile('Hindi', 'हिंदी', 'assets/img/india_image.png', 'hi'),
        ],
      ),
    ),
  ),
),
        ],
      ),
    );
  }

  String selectedLanguage = 'en';

Widget _buildPasswordField(String label, TextEditingController controller, bool isEditable) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SizedBox(
      width: 450,
      child: TextField(
        controller: controller,
        obscureText: true,
        enabled: isEditable,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    ),
  );
}


Widget _buildField(String label, TextEditingController controller) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}
Widget _buildLanguageTile(String title, String subtitle, String iconPath, String code) {
  return SizedBox(
    width: 450, // adjust width as needed
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Image.asset(iconPath, width: 24),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Radio<String>(
          value: code,
          groupValue: selectedLanguage,
          onChanged: (value) {
            setState(() {
              selectedLanguage = value!;
            });
          },
        ),
      ),
    ),
  );
}


  Widget _buildOption(String label, IconData icon) {
    return InkWell(
      onTap: () {
        // Add navigation or action
      },
      child: Row(
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
 }
