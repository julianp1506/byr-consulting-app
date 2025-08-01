// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:namer_app/admin_pages/admin_home/admin_employe_add.dart';

class AdminEmployeePage extends StatefulWidget {
  const AdminEmployeePage({Key? key}) : super(key: key);

  @override
  State<AdminEmployeePage> createState() => _AdminEmployeePageState();
}

class _AdminEmployeePageState extends State<AdminEmployeePage> {
  final _formKey = GlobalKey<FormState>();
  final Color _mainOrange = const Color(0xFFFF8902);

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _securityController = TextEditingController();

  final List<Map<String, String>> _countryCodes = [
    {'flag': '🇨🇴', 'code': '+57'},
    {'flag': '🇲🇽', 'code': '+52'},
    {'flag': '🇦🇷', 'code': '+54'},
    {'flag': '🇺🇸', 'code': '+1'},
    {'flag': '🇪🇸', 'code': '+34'},
    {'flag': '🇧🇷', 'code': '+55'},
  ];
  String _selectedDialCode = '+1';

  late final Stream<List<String>> dailyRoles$;
  String? _selectedDailyRol;

  final List<String> _jobOptions = ['Traffic control', 'Concrete', 'Drilling'];
  String? _selectedJob;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    dailyRoles$ = FirebaseFirestore.instance
        .collection('roles')
        .doc('cargo')
        .snapshots()
        .map((snap) => List<String>.from(snap.data()?['dailyRol'] ?? []));
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _salaryController.dispose();
    _securityController.dispose();
    super.dispose();
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('employees').add({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': '$_selectedDialCode${_phoneController.text.trim()}',
        'address': _addressController.text.trim(),
        'salary': double.parse(_salaryController.text.trim()),
        'dailyRole': _selectedDailyRol,
        'jobRole': _selectedJob,
        'security': _securityController.text.trim(),
        'createdAt': Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('employee_saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('error_saving'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: _mainOrange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Nuevo empleado'.tr(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInputField(
                      label: 'Nombres'.tr(),
                      icon: Icons.person,
                      controller: _firstNameController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'required_field'.tr()
                          : null,
                    ),
                    _buildInputField(
                      label: 'Apellidos'.tr(),
                      icon: Icons.person_outline,
                      controller: _lastNameController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'required_field'.tr()
                          : null,
                    ),
                    _buildPhoneInput(),
                    _buildInputField(
                      label: 'Dirección'.tr(),
                      icon: Icons.home_outlined,
                      controller: _addressController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'required_field'.tr()
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextFormField(
                        controller: _salaryController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        cursorColor: _mainOrange,
                        decoration: InputDecoration(
                          labelText: 'Sueldo'.tr(),
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          prefixIcon: Icon(Icons.monetization_on_outlined,
                              size: 20, color: Colors.grey[700]),
                          prefixText: '\$  ',
                          prefixStyle: GoogleFonts.poppins(
                              fontSize: 13, color: _mainOrange),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: _mainOrange, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'required_field'.tr();
                          }
                          final val = double.tryParse(v.trim());
                          if (val == null || val <= 0) {
                            return 'invalid_number'.tr();
                          }
                          return null;
                        },
                      ),
                    ),
                    //const SizedBox(height: 4),

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
                          hintText: "SSN (123-45-6789)".tr(),
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          prefixIcon: Icon(Icons.security_outlined,
                              size: 20, color: Colors.grey[700]),
                          //prefixText: '\$  ',
                          prefixStyle: GoogleFonts.poppins(
                              fontSize: 13, color: _mainOrange),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: _mainOrange, width: 2),
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

                    const SizedBox(height: 8),

                    // — justo antes del Dropdown de Job Role —
                    Row(
                      children: [
                        // El dropdown ocupa todo el espacio restante
                        Expanded(
                          child: StreamBuilder<List<String>>(
                            stream: dailyRoles$,
                            builder: (ctx, snap) {
                              if (!snap.hasData)
                                return const Center(
                                    child: CircularProgressIndicator());
                              final opciones = snap.data!;
                              return DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: opciones.contains(_selectedDailyRol)
                                    ? _selectedDailyRol
                                    : null,
                                decoration: InputDecoration(
                                  labelText: 'Cargo'.tr(),
                                  labelStyle: GoogleFonts.poppins(fontSize: 13),
                                  prefixIcon: Icon(Icons.work_outline,
                                      size: 20, color: Colors.grey[700]),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: _mainOrange, width: 2),
                                  ),
                                ),
                                items: opciones
                                    .map((r) => DropdownMenuItem(
                                          value: r,
                                          child: Text(r,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedDailyRol = v),
                                validator: (v) =>
                                    v == null ? 'required_field'.tr() : null,
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 12),

                        // El botón circular “+”
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminEmployeesAdd(),
                              ),
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _mainOrange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    DropdownButtonFormField<String>(
                      value: _selectedJob,
                      decoration: InputDecoration(
                        labelText: 'Job Role'.tr(),
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        prefixIcon: Icon(Icons.work_outline,
                            size: 20, color: Colors.grey[700]),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _mainOrange, width: 2),
                        ),
                      ),
                      items: _jobOptions.map((job) {
                        return DropdownMenuItem(
                          value: job,
                          child: Text(job,
                              style: GoogleFonts.poppins(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedJob = val),
                      validator: (val) =>
                          val == null ? 'required_field'.tr() : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveEmployee,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mainOrange,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 6,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Guardar'.tr(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: _mainOrange,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: Colors.grey[700]),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
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
                child: Text(
                  '${country['flag']} ${country['code']}',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedDialCode = value!),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              cursorColor: _mainOrange,
              decoration: InputDecoration(
                labelText: 'Número de teléfono'.tr(),
                labelStyle: GoogleFonts.poppins(fontSize: 13),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _mainOrange, width: 2),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'required_field'.tr();
                }
                // corregido: regex sin escape extra
                final pattern = RegExp(r'^\d{7,15}$');
                if (!pattern.hasMatch(v.trim())) {
                  return 'invalid_phone'.tr();
                }
                return null;
              },
            ),
          ),
        ],
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
