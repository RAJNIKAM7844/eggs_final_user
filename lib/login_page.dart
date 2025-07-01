import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'google_sign.dart';
import 'package:flutter/gestures.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;

  static const String _emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const int _minPasswordLength = 8;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Input validation
    if (!_validateInputs(email, password)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Invalid credentials');
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on AuthException catch (e) {
      _showSnackBar('Login failed: ${e.message}');
    } catch (e) {
      _showSnackBar('Login failed: An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateInputs(String email, String password) {
    if (email.isEmpty) {
      _showSnackBar('Please enter your email');
      return false;
    }

    if (!RegExp(_emailPattern).hasMatch(email)) {
      _showSnackBar('Please enter a valid email address');
      return false;
    }

    if (password.isEmpty) {
      _showSnackBar('Please enter your password');
      return false;
    }

    if (password.length < _minPasswordLength) {
      _showSnackBar('Password must be at least $_minPasswordLength characters');
      return false;
    }

    return true;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text("Welcome Back",
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text("Sign in to continue",
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 30),
                _buildTextField(Icons.email, "Email Address",
                    controller: _emailController),
                _buildTextField(Icons.lock, "Password",
                    obscureText: true, controller: _passwordController),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) =>
                              setState(() => _rememberMe = value ?? false),
                        ),
                        const Text("Remember me"),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/reset'),
                      child: const Text("Forgot Password?",
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.black,
                  ),
                  onPressed: _isLoading ? null : _signIn,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Sign In",
                          style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 25),
                const Center(
                    child: Text("Or sign in with",
                        style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialButton("assets/google.png", onTap: () async {
                      try {
                        await googleSignIn();
                        if (mounted)
                          Navigator.pushReplacementNamed(context, '/home');
                      } catch (e) {
                        _showSnackBar('Google Sign-In Error: $e');
                      }
                    }),
                    const SizedBox(width: 20),
                    _socialButton("assets/ios.png"),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: const TextStyle(color: Colors.black),
                      children: [
                        TextSpan(
                          text: "Register",
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap =
                                () => Navigator.pushNamed(context, '/signup'),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(IconData icon, String hint,
      {bool obscureText = false, required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: 50,
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey),
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
          ),
        ),
      ),
    );
  }

  Widget _socialButton(String imagePath, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Image.asset(imagePath, width: 35, height: 35),
      ),
    );
  }
}
