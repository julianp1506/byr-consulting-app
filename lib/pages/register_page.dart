// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:namer_app/user_pages/user_settings/user_account_info_page.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback showLoginPage;
  const RegisterPage({Key? key, required this.showLoginPage}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final Color _black = Colors.black;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final List<Map<String, String>> _countryCodes = [
    {'flag': '🇨🇴', 'code': '+57'},
    {'flag': '🇲🇽', 'code': '+52'},
    {'flag': '🇦🇷', 'code': '+54'},
    {'flag': '🇺🇸', 'code': '+1'},
    {'flag': '🇪🇸', 'code': '+34'},
    {'flag': '🇧🇷', 'code': '+55'},
  ];
  String _selectedDialCode = '+1';

  final List<String> _jobOptions = ['Traffic control', 'Concrete', 'Drilling'];
  String? _selectedJob;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool isValidEmail(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
  }

  bool isValidPhone(String phone) {
    return RegExp(r'^[0-9]{7,15}$').hasMatch(phone);
  }

  bool _validateFields() {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _selectedJob == null) {
      showMessage('All fields required'.tr(), isError: true);
      return false;
    }

    if (!isValidEmail(_emailController.text.trim())) {
      showMessage('Invalid email'.tr(), isError: true);
      return false;
    }

    if (!isValidPhone(_phoneController.text.trim())) {
      showMessage('Invalid phone'.tr(), isError: true);
      return false;
    }

    if (_passwordController.text.length < 6) {
      showMessage('Password min length'.tr(), isError: true);
      return false;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      showMessage('Passwords do not match'.tr(), isError: true);
      return false;
    }

    return true;
  }

  Future<void> signUp() async {
    if (!_validateFields()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': '$_selectedDialCode${_phoneController.text.trim()}',
          'jobRole': _selectedJob, // guardamos jobRole
          'createdAt': Timestamp.now(),
          'rol': 'usuario',
        });

        showMessage('user_created_success'.tr());

        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const UserAccountInfoPage()),
          );
        });
      }
    } on FirebaseAuthException catch (e) {
      showMessage('error: ${e.message}', isError: true);
    } catch (e) {
      showMessage('unexpected_error'.tr(), isError: true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainOrange = Color(0xFFFF8902);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F3),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 60, bottom: 90),
                decoration: BoxDecoration(
                  color: mainOrange,
                  image: const DecorationImage(
                    image: AssetImage('assets/bg_pattern.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Column(
                  children: [
                    Image.asset('assets/logo_white.png', height: 55),
                    const SizedBox(height: 2),
                    Text(
                      'B&R Consulting'.tr(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Create account subtitle'.tr(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 200,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nuevo campo: selección única de Job Role

                  _buildInput(
                    'First name'.tr(),
                    _firstNameController,
                    Icons.person,
                    iconColor: _black,
                  ),
                  _buildInput(
                    'Last name'.tr(),
                    _lastNameController,
                    Icons.person,
                    iconColor: _black,
                  ),
                  _buildPhoneInput(),
                  _buildInput('email'.tr(), _emailController, Icons.email,
                      iconColor: _black, keyboard: TextInputType.emailAddress),
                  _buildInput('Password'.tr(), _passwordController, Icons.lock,
                      iconColor: _black,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      toggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword)),
                  _buildInput(
                    'Confirm password'.tr(),
                    _confirmPasswordController,
                    Icons.lock_outline,
                    iconColor: _black,
                    isPassword: true,
                    obscureText: _obscureConfirmPassword,
                    toggleObscure: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: _selectedJob,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.black87),
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Área de trabajo'.tr(),
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      prefixIcon: const Icon(Icons.work_outline,
                          color: Colors.black, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _jobOptions.map((job) {
                      return DropdownMenuItem(
                        value: job,
                        child:
                            Text(job, style: GoogleFonts.poppins(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedJob = val),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : signUp,
                      icon: const Icon(Icons.login, color: Colors.white),
                      label: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Register'.tr(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading ? Colors.grey : mainOrange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿No tienes una cuenta?'.tr(),
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      TextButton(
                        onPressed: widget.showLoginPage,
                        child: Text(
                          'Login'.tr(),
                          style: TextStyle(
                            color: mainOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    String labelText,
    TextEditingController controller,
    IconData icon, {
    Color iconColor = Colors.black,
    bool isPassword = false,
    bool obscureText = false,
    TextInputType keyboard = TextInputType.text,
    VoidCallback? toggleObscure,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboard,
        style: GoogleFonts.poppins(fontSize: 13),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          prefixIcon: Icon(icon, color: iconColor, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: toggleObscure,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          DropdownButton<String>(
            value: _selectedDialCode,
            items: _countryCodes.map((country) {
              return DropdownMenuItem<String>(
                value: country['code'],
                child: Text('${country['flag']} ${country['code']}'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedDialCode = value!;
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Phone'.tr(),
                labelStyle: GoogleFonts.poppins(fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
