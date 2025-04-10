import 'package:canteendesk/Manager/ChangePasswordPanel.dart';
import 'package:flutter/material.dart';

class ManagerProfile extends StatefulWidget {
  @override
  _ManagerProfileState createState() => _ManagerProfileState();
}

class _ManagerProfileState extends State<ManagerProfile> {
  bool isEditing = false;

  final TextEditingController nameController = TextEditingController(text: 'Arpita Rajput');
  final TextEditingController roleController = TextEditingController(text: 'Manager');

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

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
                      Text(
                        nameController.text,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          roleController.text,
                          style: const TextStyle(color: Colors.green, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOption('Change Password', Icons.lock),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
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
