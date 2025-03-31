// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
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

    try {
      // await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen Layout
          SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: Row(
              children: [
                // Left Side - Reset Password Form
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.1, // Responsive padding
                    ),
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
                            icon: Icons.email),
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
                        const SizedBox(height: 15),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context); // Goes to the previous screen
                            },
                            child: const Text(
                              "Back to Previous",
                              style: TextStyle(
                                  color: Colors.blue, decoration: TextDecoration.underline),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Side - Welcome Panel
                Expanded(
                  flex: 1,
                  child: Container(
                    width: screenWidth * 0.5,
                    height: screenHeight,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 50),
                        child: Text(
                          "Reset Your Password!\n\n"
                          "Enter your registered email to receive a password reset link.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Back Arrow Button - Navigates to the previous screen
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.pop(context); // Goes back to the previous screen
              },
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
    );
  }
}