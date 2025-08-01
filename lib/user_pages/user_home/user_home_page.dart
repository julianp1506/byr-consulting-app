// ignore_for_file: unnecessary_import, unused_local_variable, deprecated_member_use, unused_element, unused_field

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:namer_app/user_pages/user_home/user_start_page.dart';
import 'package:namer_app/user_pages/user_home/user_end_page.dart';
import 'package:namer_app/user_pages/user_record_page.dart';
import 'package:namer_app/user_pages/user_settings/user_settings_page.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final Color _mainOrange = const Color(0xFFFF8902);
  int _selectedIndex = 0;

  Map<String, dynamic>? actividadHoy;
  String nombreUsuario = 'Trabajador'.tr();
  String? fotoPerfilUrl;
  List<Map<String, dynamic>> ultimosRegistros = [];

  bool _hasOpenRegistro = false;

  @override
  void initState() {
    super.initState();
    _loadNombreUsuario();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _loadActividadHoy() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('registros')
        .where('usuario_id', isEqualTo: userId)
        .where('estado', isEqualTo: 'abierto')
        .orderBy('fecha_entrada', descending: true)
        .limit(1)
        .get();

    // Si ya no estamos en pantalla, salimos sin llamar a setState()
    if (!mounted) return;

    final docs = snapshot.docs;
    // Un único setState para cubrir ambos casos
    setState(() {
      if (docs.isNotEmpty) {
        actividadHoy = docs.first.data();
        _hasOpenRegistro = true;
      } else {
        actividadHoy = null;
        _hasOpenRegistro = false;
      }
    });
  }

  Future<void> _loadUltimosRegistros() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('registros')
        .where('usuario_id', isEqualTo: userId)
        .where('estado', isEqualTo: 'cerrado')
        .orderBy('fecha_salida', descending: true)
        .limit(3)
        .get();

    final registros = snapshot.docs.map((d) {
      final data = d.data();
      final entrada = (data['fecha_entrada'] as Timestamp).toDate();
      final salida = (data['fecha_salida'] as Timestamp).toDate();
      data['salida_hora'] = salida;
      data['duracion'] = salida.difference(entrada);
      return data;
    }).toList();

    if (!mounted) return;
    setState(() => ultimosRegistros = registros);
  }

  Future<void> _loadNombreUsuario() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = doc.data();
    if (data != null) {
      final first = data['firstName'] ?? '';
      final last = data['lastName'] ?? '';
      final photo = data['photoUrl'];
      if (!mounted) return;
      setState(() {
        nombreUsuario = '$first $last'.trim();
        fotoPerfilUrl = photo;
      });
    }
  }

  final List<Widget> _screens = const [
    SizedBox(),
    UserRecordPage(),
    UserSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0 ? _buildInicio() : _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: _mainOrange,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home), label: 'Home'.tr()),
          BottomNavigationBarItem(
              icon: const Icon(Icons.list), label: 'Historial'.tr()),
          BottomNavigationBarItem(
              icon: const Icon(Icons.settings), label: 'Ajustes'.tr()),
        ],
      ),
    );
  }

  Widget _buildInicio() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        // ======= SECCIÓN FIJA (ENCABEZADO) =======
        Container(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
          decoration: BoxDecoration(
            color: _mainOrange,
            image: const DecorationImage(
              image: AssetImage('assets/bg_pattern.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registro de trabajo'.tr(),
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // ======= BOTONES Entrada / Salida con StreamBuilder =======
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('registros')
                    .where('usuario_id', isEqualTo: uid)
                    .where('estado', isEqualTo: 'abierto')
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  final hasOpen =
                      snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                  return Row(
                    children: [
                      Expanded(
                        child: Opacity(
                          opacity: hasOpen ? 0.5 : 1.0,
                          child: GestureDetector(
                            onTap: hasOpen
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const UserStartPage()),
                                    ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.login, color: _mainOrange),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Entrada'.tr(),
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Opacity(
                          opacity: hasOpen ? 1.0 : 0.5,
                          child: GestureDetector(
                            onTap: hasOpen
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const UserEndPage()),
                                    )
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.logout, color: _mainOrange),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Salida'.tr(),
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // ======= SECCIÓN DESLIZABLE (ACTIVIDAD + REGISTROS) =======
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 20, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ======= ACTIVIDAD DE HOY con StreamBuilder =======
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Actividad de Hoy'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('registros')
                      .where('usuario_id', isEqualTo: uid)
                      .where('estado', isEqualTo: 'abierto')
                      .orderBy('fecha_entrada', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasData && snap.data!.docs.isNotEmpty) {
                      final data =
                          snap.data!.docs.first.data() as Map<String, dynamic>;
                      return _buildActividadHoyCard(data);
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'No tienes actividad abierta'.tr(),
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 20),

                // ======= REGISTROS RECIENTES con StreamBuilder =======
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Registros recientes'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('registros')
                      .where('usuario_id', isEqualTo: uid)
                      .where('estado', isEqualTo: 'cerrado')
                      .orderBy('fecha_salida', descending: true)
                      .limit(3)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          'No tienes registros recientes'.tr(),
                          style: GoogleFonts.poppins(color: Colors.grey[600]),
                        ),
                      );
                    }
                    return Column(
                      children: snap.data!.docs.map((doc) {
                        final registro = doc.data() as Map<String, dynamic>;
                        return _buildRegistroItem(registro);
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegistroItem(Map<String, dynamic> registro) {
    // 1) Extraer y normalizar fecha de entrada
    final rawEntrada = registro['fecha_entrada'];
    final DateTime fechaEntrada =
        rawEntrada is Timestamp ? rawEntrada.toDate() : rawEntrada as DateTime;

    // 2) Extraer y normalizar fecha de salida (puede venir en 'salida_hora' o en 'fecha_salida')
    final rawSalida = registro['salida_hora'] ?? registro['fecha_salida'];
    DateTime? fechaSalida;
    if (rawSalida is Timestamp) {
      fechaSalida = rawSalida.toDate();
    } else if (rawSalida is DateTime) {
      fechaSalida = rawSalida;
    }

    // 3) Formatear horas
    final entradaHora = DateFormat('HH:mm').format(fechaEntrada);
    final salidaHora =
        fechaSalida != null ? DateFormat('HH:mm').format(fechaSalida) : '--';

    // 4) Calcular duración (si no viene precalculada en 'duracion')
    Duration? duracion = registro['duracion'] as Duration?;
    if (duracion == null && fechaSalida != null) {
      duracion = fechaSalida.difference(fechaEntrada);
    }
    final tiempoTexto = duracion != null
        ? '${duracion.inHours}h ${(duracion.inMinutes % 60).toString().padLeft(2, '0')}m'
        : '--';

    // 5) Formatear fecha completa
    String fechaFormateada =
        DateFormat('d MMMM, yyyy', context.locale.toString())
            .format(fechaEntrada);
    if (context.locale.languageCode == 'es') {
      fechaFormateada =
          fechaFormateada[0].toUpperCase() + fechaFormateada.substring(1);
    }

    // 6) Campos extra
    final obra = registro['flechas'] ?? '--';
    final empresa = registro['empresa'] ?? '--';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fecha y duración
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fechaFormateada,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  tiempoTexto,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Horario de entrada - salida y ubicación
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$entradaHora - $salidaHora',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    registro['ubicacion_salida_texto'.tr()] ?? '--',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 0),

            // Opcional: mostrar obra y empresa
            /*Text(
              '$obra • $empresa',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),*/
          ],
        ),
      ),
    );
  }

  Widget _buildActividadHoyCard(Map<String, dynamic> actividadHoy) {
    final fechaEntrada = (actividadHoy['fecha_entrada'] as Timestamp).toDate();
    final obra = actividadHoy['nombre_obra'] ?? 'Sin nombre';
    final ubicacion = actividadHoy['ubicacion_entrada_texto'.tr()] ??
        'Ubicación desconocida'.tr();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + nombre + obra
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: fotoPerfilUrl != null
                      ? NetworkImage(fotoPerfilUrl!)
                      : const AssetImage('assets/worker_avatar.jpg')
                          as ImageProvider,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreUsuario,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        obra,
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Horario y ubicación
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bloque “Entrada”
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entrada'.tr(),
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                    Text(
                      DateFormat('HH:mm').format(fechaEntrada),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),

                // Bloque “Ubicación”
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Ubicación'.tr(),
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        ubicacion,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
