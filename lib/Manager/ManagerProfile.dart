import 'package:flutter/material.dart';

class ManagerProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
          // LEFT HALF WITH SLIGHTLY INCREASED MARGIN
          SizedBox(
            width: screenWidth * 0.5,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 320,
                margin: const EdgeInsets.only(left: 40), // Slightly increased from 20
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                     child: Transform.translate(
                        offset: const Offset(0, -5), 
                   child :  Stack(
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
                    const Text(
                      'Arpita Rajput',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Manager',
                        style: TextStyle(color: Colors.green, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),
SizedBox(
  width: 260,
  child: OutlinedButton(
    onPressed: () {},
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
    ),
    
    child: const Text(
      'Edit profile',
      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
    ),
  ),
),
                  ],
                ),
              ),
            ),
          ),
          // RIGHT SIDE EMPTY
          Expanded(child: Container()),
        ],
      ),
    );
  }

}
