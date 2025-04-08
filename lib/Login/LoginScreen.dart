import 'dart:async';
import 'package:canteendesk/Manager/ManagerScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:canteendesk/Login/ForgotPasswordScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late FocusNode _emailFocusNode;
  late FocusNode _passwordFocusNode;
  bool _isChecked = false;
  bool isLoading = false;
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _timer;

  final List<String> _imagePaths = [
    "assets/img/images.jpg",
    "assets/img/image-18.png",
    "assets/img/depositphotos_150990618-stock-photo-concept-of-online-food-ordering.jpg",
  ];

  @override
  void initState() {
    super.initState();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _startImageAutoSlide();
  }

  void _startImageAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_pageController.hasClients) {
        _currentIndex++;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Row(
          children: [
            // Left Side - Login Form
            Expanded(
              flex: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Hello!",
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 25),
                    _buildTextField(
                      controller: _emailController,
                      hintText: "E-mail",
                      icon: Icons.email,
                      focusNode: _emailFocusNode,
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: "Password",
                      icon: Icons.lock,
                      isPassword: true,
                      focusNode: _passwordFocusNode,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _isChecked,
                              onChanged: (value) {
                                setState(() {
                                  _isChecked = value ?? false;
                                });
                              },
                            ),
                            const Text("Remember me"),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text(
                            "Forgot password?",
                            style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("LOGIN",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Side - Welcome Panel with Swiping Images
            Expanded(
              flex: 1,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _imagePaths.length +
                        1, // Add extra slide for smooth looping
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });

                      // If last extra page is reached, reset to the first image
                      if (index == _imagePaths.length) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _pageController.jumpToPage(0);
                        });
                      }
                    },
                    itemBuilder: (context, index) {
                      return Image.asset(
                        _imagePaths[index % _imagePaths.length], // Loop images
                        width: screenWidth * 0.5,
                        height: screenHeight,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                  Container(
                    width: screenWidth * 0.5,
                    height: screenHeight,
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 50),
                        child: Text(
                          "Welcome to Campus Cuisine!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
    
     void _login() async {
  String email = _emailController.text.trim();
  String password = _passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please enter email and password")),
    );
    return;
  }

  setState(() {
    isLoading = true;
  });

  await Future.delayed(const Duration(seconds: 2));

  setState(() {
    isLoading = false;
  });

  if (email == "manageraccount@goatmail.uk" && password == "asdfg123") {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true); // Save login state

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ManagerScreen()),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invalid email or password")),
    );
  }
}

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required FocusNode focusNode,
    bool isPassword = false,
  }) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.tab) {
            FocusScope.of(context).nextFocus(); // Move to next field
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            FocusScope.of(context).previousFocus(); // Move to previous field
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            _login(); // Trigger login on Enter key
          }
        }
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: isPassword,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          hintText: hintText,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
