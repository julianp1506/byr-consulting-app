// ignore_for_file: use_build_context_synchronously, deprecated_member_use, curly_braces_in_flow_control_structures

import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';

class UserEndPage extends StatefulWidget {
  const UserEndPage({Key? key}) : super(key: key);

  @override
  State<UserEndPage> createState() => _UserEndPageState();
}

class _UserEndPageState extends State<UserEndPage> {
  final Color _mainOrange = const Color(0xFFFF8902);

  // Ubicación
  Position? _position;
  String? _address;

  // Validación / Loading
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  // Campo 1: Empresa
  String? _selectedEmpresa;
  late final Stream<DocumentSnapshot> _empresasStream;

  // Campo 2: Compañeros (multi-select)
  List<String> _selectedCompanerosIds = [];
  List<String> _selectedCompanerosNames = [];
  List<QueryDocumentSnapshot> _allEmployees = [];

  // Campo 3: Supervisor
  String? _selectedSupervisor;
  late final Stream<DocumentSnapshot> _supervisoresStream;

  // Campo 4: Time sheet
  File? _timeSheetImage;

  // Campo 5: Notas + foto
  final TextEditingController _commentsController = TextEditingController();
  File? _commentPhoto;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _empresasStream = FirebaseFirestore.instance
        .collection('name_workspace')
        .doc('name')
        .snapshots();
    _supervisoresStream = FirebaseFirestore.instance
        .collection('name_supervisor')
        .doc('supervisor_name')
        .snapshots();
    FirebaseFirestore.instance
        .collection('employees')
        .orderBy('firstName')
        .orderBy('lastName')
        .get()
        .then((snap) => setState(() => _allEmployees = snap.docs));
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _position = pos);

      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude)
              .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final pm = placemarks.first;
      setState(() {
        _address = '${pm.street}, ${pm.locality} - ${pm.administrativeArea}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _address = 'location_unavailable'.tr());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('location_error'.tr())),
      );
    }
  }

  Future<File?> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    return picked != null ? File(picked.path) : null;
  }

  Future<String> _uploadImage(File file, String folder) async {
    final ref = FirebaseStorage.instance
        .ref('$folder/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final task = ref.putFile(file);
    await task.timeout(const Duration(seconds: 20));
    return await ref.getDownloadURL();
  }

  Future<void> _showEmpresasSelector(List<String> available) async {
    String? temp = _selectedEmpresa;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: MediaQuery.of(ctx).viewInsets.add(const EdgeInsets.all(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Seleccionar empresa'.tr(),
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...available.map((e) => RadioListTile<String>(
                    title: Text(e, style: GoogleFonts.poppins(fontSize: 14)),
                    value: e,
                    groupValue: temp,
                    onChanged: (v) => setModal(() => temp = v),
                    activeColor: _mainOrange,
                  )),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _selectedEmpresa = temp);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _mainOrange),
                child: Text('Guardar'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSupervisoresSelector(List<String> available) async {
    String? temp = _selectedSupervisor;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: MediaQuery.of(ctx).viewInsets.add(const EdgeInsets.all(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Seleccionar supervisor'.tr(),
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...available.map((s) => RadioListTile<String>(
                    title: Text(s, style: GoogleFonts.poppins(fontSize: 14)),
                    value: s,
                    groupValue: temp,
                    onChanged: (v) => setModal(() => temp = v),
                    activeColor: _mainOrange,
                  )),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _selectedSupervisor = temp);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _mainOrange),
                child: Text('Guardar'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCompanerosSelector() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        // 1) Clonamos y ordenamos la lista con toLowerCase()
        final sortedEmployees = List<QueryDocumentSnapshot>.from(_allEmployees)
          ..sort((a, b) {
            final nameA = '${a['firstName']} ${a['lastName']}'.toLowerCase();
            final nameB = '${b['firstName']} ${b['lastName']}'.toLowerCase();
            return nameA.compareTo(nameB);
          });

        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding:
                  MediaQuery.of(ctx).viewInsets.add(const EdgeInsets.all(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Seleccionar compañeros'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  if (sortedEmployees.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator())
                  else
                    // 2) Usamos sortedEmployees en lugar de _allEmployees
                    ...sortedEmployees.map((doc) {
                      final id = doc.id;
                      final name = '${doc['firstName']} ${doc['lastName']}';
                      final sel = _selectedCompanerosIds.contains(id);
                      return CheckboxListTile(
                        title: Text(name,
                            style: GoogleFonts.poppins(fontSize: 14)),
                        value: sel,
                        onChanged: (chk) => setModal(() {
                          if (chk == true &&
                              _selectedCompanerosIds.length < 5) {
                            // Limite de 5 compañeros
                            _selectedCompanerosIds.add(id);
                            _selectedCompanerosNames.add(name);
                          } else if (chk == false) {
                            final idx = _selectedCompanerosIds.indexOf(id);
                            _selectedCompanerosIds.removeAt(idx);
                            _selectedCompanerosNames.removeAt(idx);
                          }
                        }),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: _mainOrange),
                    child: Text('Guardar',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
    setState(() {});
  }

  Future<void> _submit() async {
    if (_userId == null ||
        _selectedEmpresa == null ||
        _selectedSupervisor == null ||
        _timeSheetImage == null ||
        _position == null) {
      String msg = 'complete_fields'.tr();
      if (_selectedEmpresa == null) msg = 'Selecciona una empresa'.tr();
      if (_selectedSupervisor == null) msg = 'Selecciona un supervisor'.tr();
      if (_timeSheetImage == null) msg = 'Toma la foto del Time sheet'.tr();
      if (_position == null) msg = 'location_unavailable'.tr();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final q = await FirebaseFirestore.instance
          .collection('registros')
          .where('usuario_id', isEqualTo: _userId)
          .where('estado', isEqualTo: 'abierto')
          .limit(1)
          .get();
      if (q.docs.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No hay registro abierto para cerrar.')));
        return;
      }
      final docId = q.docs.first.id;
      final tsUrl = await _uploadImage(_timeSheetImage!, 'timesheet');

      final payload = {
        'empresa': _selectedEmpresa!,
        'companeros': _selectedCompanerosNames,
        'supervisor': _selectedSupervisor!,
        'imagen_timesheet_url': tsUrl,
        'fecha_salida': Timestamp.now(),
        'comentarios_salida': _commentsController.text.trim(),
        'ubicacion_salida_texto': _address,
        'ubicacion_salida_geo': {
          'lat': _position!.latitude,
          'lng': _position!.longitude,
        },
        'estado': 'cerrado',
      };
      if (_commentPhoto != null) {
        final cUrl = await _uploadImage(_commentPhoto!, 'comments_out');
        payload['comentario_salida_imagen_url'] = cUrl;
      }
      await FirebaseFirestore.instance
          .collection('registros')
          .doc(docId)
          .update(payload)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_saving'.tr() + e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedCompaneros = List<String>.from(_selectedCompanerosNames)
      ..sort((a, b) => a.compareTo(b));

    return WillPopScope(
      onWillPop: () async => !_isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F3),
        appBar: AppBar(
          backgroundColor: _mainOrange,
          title: Text(
            'exit_record'.tr(),
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          leading:
              _isLoading ? Container() : const BackButton(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Encabezado de sección ---
                  Row(
                    children: [
                      Text(
                        'section_header'.tr(),
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                    ],
                  ),

                  // --- Empresa ---
                  StreamBuilder<DocumentSnapshot>(
                    stream: _empresasStream,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text('Error al cargar empresas'.tr(),
                              style: TextStyle(color: Colors.red)),
                        );
                      }
                      if (!snap.hasData ||
                          snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final data =
                          snap.data!.data() as Map<String, dynamic>? ?? {};
                      final empresas =
                          List<String>.from(data['workspace'] ?? []);
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'company_label'.tr(),
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: empresas.isEmpty
                                  ? null
                                  : () => _showEmpresasSelector(empresas),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedEmpresa == null
                                        ? Colors.red
                                        : Colors.grey.shade300,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedEmpresa ?? 'company_hint'.tr(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: _selectedEmpresa == null
                                              ? Colors.grey
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // --- Compañeros de trabajo ---
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 6),
                    child: Text(
                      'companion_label'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isLoading || _allEmployees.isEmpty
                        ? null
                        : _showCompanerosSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sortedCompaneros.isEmpty
                              ? Colors.red
                              : Colors.grey.shade300,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              sortedCompaneros.isEmpty
                                  ? 'Selecciona maximo 5 compañeros'.tr()
                                  : sortedCompaneros.join(', '),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: sortedCompaneros.isEmpty
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  if (sortedCompaneros.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: sortedCompaneros.map((name) {
                        return Chip(label: Text(name));
                      }).toList(),
                    ),
                  ],

                  // --- Supervisor asignado ---
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 6),
                    child: Text(
                      'supervisor_label'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _supervisoresStream,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text('Error al cargar supervisores'.tr(),
                              style: TextStyle(color: Colors.red)),
                        );
                      }
                      if (!snap.hasData ||
                          snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final data =
                          snap.data!.data() as Map<String, dynamic>? ?? {};
                      final supervisores =
                          List<String>.from(data['supervisor'] ?? []);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: supervisores.isEmpty
                              ? null
                              : () => _showSupervisoresSelector(supervisores),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedSupervisor == null
                                    ? Colors.red
                                    : Colors.grey.shade300,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedSupervisor ??
                                        'supervisor_hint'.tr(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: _selectedSupervisor == null
                                          ? Colors.grey
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // --- Foto del Time Sheet ---
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 6),
                    child: Text(
                      'timesheet_label'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () async {
                            final img = await _pickImage();
                            if (img != null)
                              setState(() => _timeSheetImage = img);
                          },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _timeSheetImage == null
                              ? Colors.red
                              : Colors.grey.shade300,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _timeSheetImage == null
                                  ? 'timesheet_hint'.tr()
                                  : 'image_selected'.tr(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _timeSheetImage == null
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ),
                          const Icon(Icons.camera_alt, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  // --- Notas adicionales ---
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 6),
                    child: Text(
                      'comments_label'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: TextFormField(
                      controller: _commentsController,
                      enabled: !_isLoading,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'comments_hint'.tr(),
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                        suffixIcon: IconButton(
                          icon:
                              const Icon(Icons.camera_alt, color: Colors.grey),
                          onPressed: () async {
                            if (_isLoading) return;
                            final img = await _pickImage();
                            if (img != null)
                              setState(() => _commentPhoto = img);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),

                  // --- Ubicación de salida ---
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 6),
                    child: Text(
                      'location_label'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // lógica para ajustar ubicación
                    },
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'press_set_location'.tr(),
                          style: GoogleFonts.poppins(
                              color: Colors.grey[700], fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  if (_address != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.grey, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _address!,
                              style: GoogleFonts.poppins(
                                  fontSize: 14, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // --- Botón Enviar ---
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mainOrange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'submit'.tr(),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
