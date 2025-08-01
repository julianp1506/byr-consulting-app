// ignore_for_file: deprecated_member_use, unused_element, use_build_context_synchronously

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

class UserStartPage extends StatefulWidget {
  const UserStartPage({Key? key}) : super(key: key);

  @override
  State<UserStartPage> createState() => _UserStartPageState();
}

class _UserStartPageState extends State<UserStartPage> {
  final Color _mainOrange = const Color(0xFFFF8902);

  // Ubicación
  Position? _position;
  String? _address;

  // Estado de carga
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _userId = FirebaseAuth.instance.currentUser?.uid;

  // Selección única de "flecha"
  String? _selectedFlecha;
  late final Stream<DocumentSnapshot> _flechasStream;

  // Notas + foto opcional
  final TextEditingController _commentsController = TextEditingController();
  File? _commentPhoto;

  @override
  void initState() {
    super.initState();
    _getLocation();

    // Escuchar el documento que contiene el arreglo "flechas"
    _flechasStream = FirebaseFirestore.instance
        .collection('arrow_board_options')
        .doc('config')
        .snapshots();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  /// Obtiene la ubicación actual (lat/lng + dirección de texto)
  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() => _position = pos);

      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final placemark = placemarks.first;
      setState(() {
        _address =
            '${placemark.street}, ${placemark.locality} - ${placemark.administrativeArea}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _address = 'location_unavailable'.tr());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('location_error'.tr())),
      );
    }
  }

  /// Toma una foto con la cámara
  Future<File?> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    return picked != null ? File(picked.path) : null;
  }

  /// Sube la imagen a Firebase Storage y retorna la URL
  Future<String> _uploadImage(File file, String folder) async {
    final ref = FirebaseStorage.instance
        .ref('$folder/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = ref.putFile(file);
    await uploadTask.timeout(const Duration(seconds: 20));
    return await ref.getDownloadURL();
  }

  /// Muestra un modal para seleccionar solo UNA flecha (RadioListTile)
  Future<void> _showFlechasSelector(List<String> available) async {
    // Copia temporal de la flecha actualmente seleccionada
    String? tempSelected = _selectedFlecha;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Seleccionar flecha'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cada opción como un RadioListTile
                  ...available.map((f) {
                    return RadioListTile<String>(
                      title: Text(f, style: GoogleFonts.poppins(fontSize: 14)),
                      value: f,
                      groupValue: tempSelected,
                      onChanged: (value) {
                        setModalState(() {
                          tempSelected = value;
                        });
                      },
                      activeColor: _mainOrange,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    );
                  }).toList(),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Guardar la flecha seleccionada definitivamente
                        setState(() {
                          _selectedFlecha = tempSelected;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mainOrange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Guardar'.tr(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Envía el formulario y crea el documento en Firestore
  Future<void> _submit() async {
    // Validaciones:
    // - Debe haber ubicación
    // - Debe haber UID
    // - Debe haber UNA flecha seleccionada
    if (_position == null || _userId == null || _selectedFlecha == null) {
      String mensaje = 'complete_fields'.tr();
      if (_selectedFlecha == null) {
        mensaje = 'Selecciona una flecha'.tr();
      } else if (_position == null) {
        mensaje = 'location_unavailable'.tr();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Comprobar si existe registro abierto
    final existing = await FirebaseFirestore.instance
        .collection('registros')
        .where('usuario_id', isEqualTo: _userId)
        .where('estado', isEqualTo: 'abierto')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ya tienes una entrada abierta. Marca salida antes de registrar otra.'
                .tr(),
          ),
        ),
      );
      return;
    }

    try {
      final Map<String, dynamic> payload = {
        'usuario_id': _userId,
        'fecha_entrada': Timestamp.now(),
        // Guardamos la única flecha dentro de un arreglo:
        'flechas': [_selectedFlecha!],
        'comentarios': _commentsController.text.trim(),
        'ubicacion_entrada_texto': _address,
        'ubicacion_entrada_geo': {
          'lat': _position!.latitude,
          'lng': _position!.longitude,
        },
        'estado': 'abierto',
      };

      // Si hay foto de comentario, súbela
      if (_commentPhoto != null) {
        final commentUrl = await _uploadImage(_commentPhoto!, 'comments');
        payload['comentario_imagen_url'] = commentUrl;
      }

      await FirebaseFirestore.instance
          .collection('registros')
          .add(payload)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_saving'.tr() + e.toString())),
      );
    }
  }

  /// Construye el label con estilo consistente
  Widget _buildLabel(String label) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 6),
        child: Text(
          label.tr(),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return WillPopScope(
      onWillPop: () async => !_isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F3), // gris claro
        appBar: AppBar(
          backgroundColor: _mainOrange,
          title: Text(
            'entry_record'.tr(),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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
                  // ----- Encabezado "Datos" + check verde -----
                  Row(
                    children: [
                      Text(
                        'Datos'.tr(),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                    ],
                  ),

                  // ----- Fecha y Hora -----
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 6),
                    child: Text(
                      'date_time'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // Campo Date/Time con borde y sombra
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          '${now.day}/${now.month}/${now.year}, '
                          '${(now.hour == 0 || now.hour == 12) ? 12 : now.hour % 12}:'
                          '${now.minute.toString().padLeft(2, '0')} '
                          '${now.hour < 12 ? 'am' : 'pm'}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ----- Arrow Board (dropdown visual + modal single-select) -----
                  StreamBuilder<DocumentSnapshot>(
                    stream: _flechasStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            'Error al cargar flechas'.tr(),
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      if (!snapshot.hasData ||
                          snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final List<String> flechas = data?['flechas'] != null
                          ? List<String>.from(data!['flechas'])
                          : [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 24, bottom: 6),
                            child: Text(
                              'arrow_board_label'.tr(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),

                          // Contenedor estilo dropdown con borde y sombra
                          GestureDetector(
                            onTap: () {
                              if (flechas.isNotEmpty) {
                                _showFlechasSelector(flechas);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedFlecha == null
                                          ? 'Seleccionar flecha'.tr()
                                          : _selectedFlecha!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: _selectedFlecha == null
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // ----- Campo de Notas -----
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 6),
                    child: Text(
                      'comments_label'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // Wrap TextFormField en Container con borde y sombra
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
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _commentsController,
                      enabled: !_isLoading,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'comments_hint'.tr(),
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        suffixIcon: IconButton(
                          icon:
                              const Icon(Icons.camera_alt, color: Colors.grey),
                          onPressed: () async {
                            if (_isLoading) return;
                            final image = await _pickImage();
                            if (image != null) {
                              setState(() => _commentPhoto = image);
                            }
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // ----- Placeholder para el mini-mapa -----
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 6),
                    child: Text(
                      'location_label'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Abre pantalla de selección de ubicación si lo deseas
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
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Press to set location'.tr(),
                          style: GoogleFonts.poppins(
                              color: Colors.grey[700], fontSize: 14),
                        ),
                      ),
                    ),
                  ),

                  // ----- Dirección en texto -----
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
                          ),
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
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 60,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ----- Botón de Enviar -----
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
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'submit'.tr(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
