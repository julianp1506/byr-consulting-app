import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';

class AdminAccountInfoPage extends StatefulWidget {
  const AdminAccountInfoPage({Key? key}) : super(key: key);

  @override
  State<AdminAccountInfoPage> createState() => _AdminAccountInfoPageState();
}

class _AdminAccountInfoPageState extends State<AdminAccountInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final Color _mainOrange = const Color(0xFFFF8902);
  final Color _black = Colors.black;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isSaving = false;
  bool _isUploadingImage = false;

  /// Referencia al usuario actual de Firebase Auth
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  /// Stream para escuchar cambios en el documento del usuario
  Stream<DocumentSnapshot> get _userDocStream {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .snapshots();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Sube la nueva foto de perfil a Firebase Storage y actualiza Firestore
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    File file = File(pickedFile.path);
    setState(() => _isUploadingImage = true);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures/${_currentUser!.uid}.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'photoUrl': downloadUrl});

      _showMessage('profile_picture_updated'.tr(), isError: false);
    } catch (e) {
      _showMessage('error_uploading_image'.tr(), isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  /// Guarda cambios de FirstName, LastName y Phone en Firestore
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      _showMessage('profile_updated_successfully'.tr(), isError: false);
    } catch (e) {
      _showMessage('error_updating_profile'.tr(), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F3),
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: _mainOrange,
        title: Text(
          'Account info'.tr(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userDocStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // Cargando datos del usuario
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final firstName = data['firstName'] as String? ?? '';
          final lastName = data['lastName'] as String? ?? '';
          final phone = data['phone'] as String? ?? '';
          final email = data['email'] as String? ?? _currentUser!.email ?? '';
          final photoUrl = data['photoUrl'] as String?;

          // Inicializar controllers solo la primera vez (evitar sobreescritura continua)
          _firstNameController.text = firstName;
          _lastNameController.text = lastName;
          _phoneController.text = phone;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Fot o de perfil
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/worker_avatar.jpg')
                              as ImageProvider,
                    ),
                    Positioned(
                      child: GestureDetector(
                        onTap: _isUploadingImage ? null : _pickAndUploadImage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _mainOrange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: _isUploadingImage
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Formulario
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInputField(
                        label: 'First name'.tr(),
                        icon: Icons.person,
                        controller: _firstNameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'first_name_required'.tr();
                          }
                          return null;
                        },
                      ),
                      _buildInputField(
                        label: 'Last name'.tr(),
                        icon: Icons.person,
                        controller: _lastNameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'last_name_required'.tr();
                          }
                          return null;
                        },
                      ),
                      _buildInputField(
                        label: 'Email'.tr(),
                        icon: Icons.email,
                        controller:
                            TextEditingController(text: email), // no editable
                        readOnly: true,
                        validator: null,
                      ),
                      _buildInputField(
                        label: 'Phone'.tr(),
                        icon: Icons.phone,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null; // Opcional, si no se quiere obligar
                          }
                          // Permitir un “+” al inicio seguido de entre 7 y 15 dígitos
                          final phonePattern = RegExp(r'^\+?\d{7,15}$');
                          if (!phonePattern.hasMatch(value.trim())) {
                            return 'invalid_phone'.tr();
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Botón de “Save changes”
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _saveChanges(),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: _isSaving
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
                            'Save changes'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSaving ? Colors.grey : _mainOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Construye cada campo de entrada con validación
  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        cursorColor: _mainOrange,
        style: TextStyle(color: _black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: _black,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: _black),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _mainOrange),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _mainOrange, width: 2),
          ),
        ),
        validator: validator,
      ),
    );
  }
}
