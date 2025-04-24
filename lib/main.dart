import 'dart:io';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canteendesk/Login/LoginScreen.dart';
import 'package:canteendesk/Manager/ManagerScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Skip Firebase initialization on Windows
  if (!Platform.isWindows) {
    // Only initialize Firebase for mobile/web if needed
    // await Firebase.initializeApp(); // Uncomment if supporting Android/iOS
  }
  // doWhenWindowReady(() {
  //   // const initialSize = Size(600, 450);
  //   // appWindow.minSize = initialSize;
  //   appWindow.size = Size.infinite;
  //   appWindow.alignment = Alignment.center;
  //   appWindow.show();
  // });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'canteendesk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else {
            final prefs = snapshot.data as SharedPreferences;
            final role = prefs.getString('userRole');

            if (role == 'student') {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Student profile can only be accessed via the mobile application.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            } else if (role == 'manager') {
              return  ManagerScreen();
            } else {
              return const LoginScreen();
            }
          }
        },
      ),
    );
  }
}
