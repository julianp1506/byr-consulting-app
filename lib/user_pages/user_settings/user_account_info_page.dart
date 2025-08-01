// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';

class UserAccountInfoPage extends StatefulWidget {
  const UserAccountInfoPage({Key? key}) : super(key: key);

  @override
  State<UserAccountInfoPage> createState() => _UserAccountInfoPageState();
}

class _UserAccountInfoPageState extends State<UserAccountInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final Color _mainOrange = const Color(0xFFFF8902);
  final Color _black = Colors.black;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _securityController = TextEditingController();
  //final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _nuevoElementoController =
      TextEditingController();

  final List<String> _jobOptions = ['Traffic control', 'Concrete', 'Drilling'];
  String? _selectedJob;

  late final Stream<List<String>> dailyRoles$;
  String? _selectedRol;

  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _initialized = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  Stream<DocumentSnapshot> get _userStream => FirebaseFirestore.instance
      .collection('users')
      .doc(_currentUser!.uid)
      .snapshots();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _direccionController.dispose();
    _securityController.dispose();
    //_salaryController.dispose();

    _nuevoElementoController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    dailyRoles$ = FirebaseFirestore.instance
        .collection('roles')
        .doc('cargo')
        .snapshots()
        .map((snap) => List<String>.from(snap.data()?['dailyRol'] ?? []));
    //_loadUsuarios();  // si lo tienes
  }

  Future<void> _pickAndUploadImage() async {
    // Evita llamadas simultáneas
    if (_isUploadingImage) return;
    setState(() => _isUploadingImage = true);

    final picker = ImagePicker();
    XFile? pickedFile;
    try {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      // Error al abrir galería
      setState(() => _isUploadingImage = false);
      _showMessage('error_picking_image'.tr(), isError: true);
      return;
    }

    // Usuario canceló
    if (pickedFile == null) {
      setState(() => _isUploadingImage = false);
      return;
    }

    final file = File(pickedFile.path);
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
        'address': _direccionController.text.trim(),
        'security': _securityController.text.trim(),
        //'salary': double.parse(_salaryController.text.trim()),
        'jobRole': _selectedJob,
        'dailyRole': _selectedRol,
      });
      _showMessage('profile_updated_successfully'.tr(), isError: false);
    } catch (_) {
      _showMessage('error_updating_profile'.tr(), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F3),
      appBar: AppBar(
        backgroundColor: _mainOrange,
        toolbarHeight: 50,
        title: Text('Account info'.tr(),
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};
          final String? photoUrl = data['photoUrl'];
          if (!_initialized) {
            _initialized = true;
            _firstNameController.text = data['firstName'] ?? '';
            _lastNameController.text = data['lastName'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _direccionController.text = data['address'] ?? '';
            _securityController.text = (data['security'] ?? '').toString();
            //_salaryController.text = (data['salary'] ?? '').toString();
            _selectedJob = data['jobRole'];
            _selectedRol = data['dailyRole'];
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 45,
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
                  _buildField(
                      'First name'.tr(), Icons.person, _firstNameController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'first_name_required'.tr()
                          : null),
                  _buildField('Last name'.tr(), Icons.person_outline,
                      _lastNameController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'last_name_required'.tr()
                          : null),
                  _buildField(
                      'Email'.tr(),
                      Icons.email,
                      TextEditingController(
                          text: data['email'] ?? _currentUser!.email!),
                      readOnly: true),
                  _buildField(
                    'Phone'.tr(),
                    Icons.phone,
                    _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final pattern = RegExp(r'^\+?\d{7,15}$');
                      if (!pattern.hasMatch(v.trim())) {
                        return 'invalid_phone'.tr();
                      }
                      return null;
                    },
                  ),
                  _buildField(
                      'Direccion'.tr(), Icons.location_on, _direccionController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'direccion_required'.tr()
                          : null),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _securityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _SSNInputFormatter(),
                      ],
                      cursorColor: _mainOrange,
                      decoration: InputDecoration(
                        labelText: 'Seguridad'.tr(),
                        hintText: '123-45-6789',
                        prefixIcon: Icon(Icons.credit_card, color: _black),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'required_field'.tr();
                        final ssnRegex = RegExp(r'^\d{3}-\d{2}-\d{4}$');
                        return ssnRegex.hasMatch(v.trim())
                            ? null
                            : 'invalid_ssn_format'.tr();
                      },
                    ),
                  ),

                  /*_buildField(
                      'Salario'.tr(), Icons.attach_money, _salaryController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                    if (v == null || v.isEmpty) return 'required_field'.tr();
                    final n = double.tryParse(v);
                    return (n != null && n > 0) ? null : 'invalid_number'.tr();
                  }),*/
                  const SizedBox(height: 8),
                  // Dropdown “Cargo” (antes _dailyRol)
                  // Dropdown “Cargo”
                  StreamBuilder<List<String>>(
                    stream: FirebaseFirestore.instance
                        .doc('roles/cargo')
                        .snapshots()
                        .map((snap) =>
                            List<String>.from(snap.data()?['dailyRol'] ?? [])),
                    builder: (ctx, snapRoles) {
                      if (!snapRoles.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final opciones = snapRoles.data!;
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: opciones.contains(_selectedRol)
                            ? _selectedRol
                            : null,
                        hint: Text(
                          'Selecciona un cargo'.tr(),
                          style: GoogleFonts.poppins(color: Colors.black),
                        ),
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.black87),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Cargo'.tr(),
                          prefixIcon: const Icon(Icons.assignment_ind_outlined,
                              color: Colors.black),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: _mainOrange, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: _mainOrange, width: 2),
                          ),
                        ),
                        selectedItemBuilder: (context) {
                          return opciones.map((e) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                e,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }).toList();
                        },
                        items: opciones.map((e) {
                          return DropdownMenuItem(
                            value: e,
                            child: Text(e,
                                style: GoogleFonts.poppins(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedRol = v),
                        validator: (v) =>
                            v == null ? 'required_field'.tr() : null,
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Dropdown “Job Role” (estático, sin cambios)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _jobOptions.contains(_selectedJob)
                        ? _selectedJob
                        : null,
                    hint: Text(
                      'Selecciona un rol'.tr(),
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.black87),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Job Role'.tr(),
                      prefixIcon: const Icon(
                        Icons.work_outline,
                        color: Colors.black,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _mainOrange, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _mainOrange, width: 2),
                      ),
                    ),
                    selectedItemBuilder: (context) {
                      return _jobOptions.map((j) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            j,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    items: _jobOptions.map((j) {
                      return DropdownMenuItem(
                        value: j,
                        child:
                            Text(j, style: GoogleFonts.poppins(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedJob = v),
                    validator: (v) => v == null ? 'required_field'.tr() : null,
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mainOrange,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('Save changes'.tr(),
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(
      String label, IconData icon, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text,
      String? Function(String?)? validator,
      bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        cursorColor: _mainOrange,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _black),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _mainOrange)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _mainOrange, width: 2)),
        ),
        validator: validator,
      ),
    );
  }
}

class _SSNInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Si se está borrando, devolvemos el nuevo valor sin formatear
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }
    // Extraemos sólo dígitos
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) digits = digits.substring(0, 9);
    // Insertamos guiones en las posiciones 3 y 5
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 2 || i == 4) buffer.write('-');
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
