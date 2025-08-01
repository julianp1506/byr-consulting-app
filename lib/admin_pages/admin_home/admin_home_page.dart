// admin_home_page.dart

// ignore_for_file: unnecessary_import

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:namer_app/admin_pages/admin_home/admin_employee.dart';
import 'package:namer_app/admin_pages/admin_reports/admin_reports_page.dart';
import 'package:namer_app/admin_pages/admin_settings/admin_settings_page.dart';
import 'admin_workspace.dart';
import 'admin_supervisor.dart';
import 'admin_arrow.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;
  final Color _mainOrange = const Color(0xFFFF8902);

  final List<Widget> _screens = [
    const AdminDashboardView(),
    const AdminReportsPage(),
    const AdminSettingsPage(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: _mainOrange,
        unselectedItemColor: Colors.black54,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Admin'.tr()),
          BottomNavigationBarItem(
              icon: Icon(Icons.insert_chart), label: 'Reportes'.tr()),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Ajustes'.tr()),
        ],
      ),
    );
  }
}

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({Key? key}) : super(key: key);

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final Color _mainOrange = const Color(0xFFFF8902);
  String nombreUsuario = '';
  String? fotoUrl;
  int activeUsersCount = 0;
  int totalUsersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPerfil();
    _loadActiveUsers();
    _loadTotalUsers();
  }

  Future<void> _loadPerfil() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Asegúrate de usar la colección correcta ('users' o 'usuarios')
    final doc = await FirebaseFirestore.instance
        .collection('users') // ó 'usuarios', según tu base
        .doc(uid)
        .get();

    // Si no existe, salir
    if (!doc.exists) return;

    final data = doc.data();
    if (data == null) return;

    if (!mounted) return;
    setState(() {
      nombreUsuario =
          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
      fotoUrl = data['photoUrl'] as String?;
    });
  }

  Future<void> _loadActiveUsers() async {
    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('estado', isEqualTo: 'abierto')
        .get();
    if (!mounted) return;
    setState(() => activeUsersCount = snap.docs.length);
  }

  Future<void> _loadTotalUsers() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('rol', isEqualTo: 'usuario')
        .get();
    if (!mounted) return;
    setState(() => totalUsersCount = snap.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayShort = DateFormat('dd/MM/yy').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER extendido hasta status bar
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 30,
            20,
            20,
          ),
          color: _mainOrange,
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: fotoUrl != null
                    ? NetworkImage(fotoUrl!)
                    : const AssetImage('assets/avatar_admin.jpg')
                        as ImageProvider,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nombreUsuario.isEmpty ? 'Administrador'.tr() : nombreUsuario,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.check_circle, size: 32, color: Colors.white70),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // RESUMEN: Usuarios activos / inactivos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildSummaryCard('Usuarios activos'.tr(), activeUsersCount),
              const SizedBox(width: 12),
              _buildSummaryCard('Usuarios inactivos'.tr(),
                  totalUsersCount - activeUsersCount),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // BOTONES
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Empresa
              SizedBox(
                width: 64,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminWorkspacePage()),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child:
                            Icon(Icons.business, size: 30, color: _mainOrange),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Añadir empresa'.tr(),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 9.8, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

              // Supervisor
              SizedBox(
                width: 64,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminSupervisorPage()),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child: Icon(Icons.supervisor_account,
                            size: 30, color: _mainOrange),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Añadir supervisor'.tr(),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 9.8, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

              // Flecha
              SizedBox(
                width: 64,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminArrowPage()),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child: Icon(Icons.compare_arrows_sharp,
                            size: 30, color: _mainOrange),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Añadir flecha'.tr(),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 9.8, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

              // Empleados
              SizedBox(
                width: 64,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminEmployeePage()),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child: Icon(Icons.group, size: 30, color: _mainOrange),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Añadir empleado'.tr(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 9.8, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ASISTENCIA POR FLECHA
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Asistencia por flecha'.tr(),
            style:
                GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('arrow_board_options')
                .doc('config')
                .snapshots(),
            builder: (context, cfgSnap) {
              if (!cfgSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final cfgDoc = cfgSnap.data!;
              if (!cfgDoc.exists) {
                return Center(
                    child: Text('No hay configuración de flechas'.tr()));
              }
              final data = cfgDoc.data()! as Map<String, dynamic>;
              final flechasArr =
                  List<String>.from(data['flechas'] as List<dynamic>? ?? []);

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('registros')
                    .where('estado', isEqualTo: 'abierto')
                    .snapshots(),
                builder: (context, regSnap) {
                  if (!regSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final counts = <String, int>{};
                  for (final doc in regSnap.data!.docs) {
                    final ts = doc.get('fecha_entrada');
                    DateTime entryDate;
                    if (ts is Timestamp) {
                      entryDate = ts.toDate();
                    } else if (ts is DateTime) {
                      entryDate = ts;
                    } else {
                      continue;
                    }
                    if (entryDate.year == now.year &&
                        entryDate.month == now.month &&
                        entryDate.day == now.day) {
                      for (final f
                          in (doc.get('flechas') as List<dynamic>? ?? [])) {
                        final id = f.toString();
                        counts[id] = (counts[id] ?? 0) + 1;
                      }
                    }
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: flechasArr.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final id = flechasArr[i];
                      final cnt = counts[id] ?? 0;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(id,
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('Asistencia'.tr(),
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(todayShort,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: Colors.grey[700])),
                                const SizedBox(height: 4),
                                Text('$cnt',
                                    style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

Widget _buildSummaryCard(String label, int value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(label,
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
            const SizedBox(height: 6),
            Text('$value',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
// This file is part of the ByR Control project.
