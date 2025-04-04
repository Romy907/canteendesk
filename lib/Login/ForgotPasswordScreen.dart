import 'dart:async';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
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
    _emailController.dispose();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent.")),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: Row(
              children: [
                // Left Side - Reset Password Form
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Forgot Password?",
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Enter your email to reset your password.",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 25),
                        _buildTextField(
                          controller: _emailController,
                          hintText: "E-mail",
                          icon: Icons.email,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurpleAccent.shade200,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("SEND RESET LINK",
                                    style: TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Side - Image Slider with Smooth Loop
                Expanded(
                  flex: 1,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: _imagePaths.length + 1, // Extra slide for looping
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });

                          // Reset to first image when reaching the extra slide
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
                        color: Colors.black.withOpacity(0.3), // Dark overlay
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 50),
                            child: Text(
                              "Reset Your Password!\n\n"
                              "Enter your registered email to receive a password reset link.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
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

          // Back Icon in the Top Left with Circular Background
          Positioned(
            top: 40, // Adjust based on your layout
            left: 20,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(25), // Light grey transparent background
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
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
      textInputAction: TextInputAction.done, // Show "Done" or "Enter" key
      onSubmitted: (value) => _resetPassword(), // Trigger reset on Enter key press
    );
  }
}
