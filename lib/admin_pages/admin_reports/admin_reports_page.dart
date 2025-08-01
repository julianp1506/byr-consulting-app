// admin_reports_page.dart

// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'admin_reports_general.dart';
import 'admin_reports_detail.dart';
import 'admin_reports_detail_employees.dart';
import 'admin_reports_detail_admin.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({Key? key}) : super(key: key);

  @override
  _AdminReportsPageState createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final Color _mainOrange = const Color(0xFFFF8902);

  // filtros
  String searchText = '';
  final List<String> _typeOptions = [
    'Usuarios'.tr(),
    'Empleados'.tr(),
    'Administradores'.tr()
  ];
  String _selectedType = 'Usuarios'.tr();

  final List<String> _jobOptions = ['Traffic control', 'Concrete', 'Drilling'];
  String? _selectedJob;

  // datos de la lista
  List<Map<String, dynamic>> usuarios = [];
  bool _loading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadUsuarios();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUsuarios({bool loadMore = false}) async {
    if (_loading || (!_hasMore && loadMore)) return;
    setState(() => _loading = true);

    // Elige la colección y filtro según el tipo seleccionado
    Query query;
    final auth = FirebaseAuth.instance;
    switch (_selectedType) {
      case 'Usuarios':
        query = FirebaseFirestore.instance
            .collection('users')
            .where('rol', isEqualTo: 'usuario');
        break;
      case 'Empleados':
        query = FirebaseFirestore.instance.collection('employees');
        break;
      case 'Administradores':
        query = FirebaseFirestore.instance
            .collection('users')
            .where('rol', isEqualTo: 'admin')
            .where(FieldPath.documentId, isNotEqualTo: auth.currentUser!.uid);
        break;
      default:
        query = FirebaseFirestore.instance
            .collection('users')
            .where('rol', isEqualTo: 'usuario');
    }

    query = query.orderBy('firstName').limit(10);

    if (loadMore && _lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    final snapshot = await query.get();
    final nuevos = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'firstName': data['firstName'] ?? '',
        'lastName': data['lastName'] ?? '',
        'photoUrl': data['photoUrl'] ?? '',
        'jobRole': data['jobRole'] ?? '',
      };
    }).toList();

    if (!mounted) return;
    setState(() {
      if (!loadMore) usuarios.clear();
      usuarios.addAll(nuevos);
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
      _hasMore = snapshot.docs.length == 10;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final lower = searchText.toLowerCase();
    return usuarios.where((u) {
      final fullName = '${u['firstName']} ${u['lastName']}'.toLowerCase();
      if (!fullName.contains(lower)) return false;
      if (_selectedType != 'Administradores') {
        return _selectedJob == null || u['jobRole'] == _selectedJob;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F3),
      appBar: AppBar(
        backgroundColor: _mainOrange,
        title: Text(
          'Empleados'.tr(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // --- filtros ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Filtro de Tipo
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Tipo'.tr(),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _typeOptions
                      .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t.tr())))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedType = val!;
                      usuarios.clear();
                      _lastDoc = null;
                      _hasMore = true;
                      _selectedJob = null;
                      _loadUsuarios();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Filtro de Job Role (si no es Administradores)
                if (_selectedType != 'Administradores') ...[
                  DropdownButtonFormField<String>(
                    value: _selectedJob,
                    decoration: InputDecoration(
                      labelText: 'Job Role'.tr(),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    hint: Text('Seleccionar'.tr()),
                    items: _jobOptions
                        .map((role) =>
                            DropdownMenuItem(value: role, child: Text(role)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedJob = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Filtro de Nombre
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Nombre'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (text) {
                    setState(() {
                      searchText = text;
                    });
                  },
                ),
              ],
            ),
          ),

          // botón Reportes generales
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bar_chart, color: Colors.white),
                label: Text(
                  'Reportes'.tr(),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mainOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminReportsGeneral(),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Lista de trabajadores
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '${'Lista de'.tr()} ${_selectedType.tr()}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: lista.length,
              itemBuilder: (ctx, i) {
                final u = lista[i];
                final nombre = '${u['firstName']} ${u['lastName']}';
                final photo = u['photoUrl'] as String;
                final jobRole = u['jobRole'] as String;

                return GestureDetector(
                  onTap: () async {
                    // Decide qué página de detalle instanciar
                    Widget detailPage;
                    if (_selectedType == 'Usuarios') {
                      detailPage = AdminReportsDetail(
                        userId: u['id'],
                        nombre: nombre,
                        photoUrl: photo,
                      );
                    } else if (_selectedType == 'Empleados') {
                      detailPage = AdminReportsDetailEmployees(
                        userId: u['id'],
                        nombre: nombre,
                        photoUrl: photo,
                      );
                    } else {
                      detailPage = AdminReportsDetailAdmin(
                        userId: u['id'],
                        nombre: nombre,
                        photoUrl: photo,
                      );
                    }

                    // Empuja la página de detalle y espera un bool de vuelta
                    final didDelete = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => detailPage),
                    );

                    // Si devolvió true, significa que borró el usuario → recarga la lista
                    if (didDelete == true) {
                      setState(() {
                        usuarios.clear();
                        _lastDoc = null;
                        _hasMore = true;
                        // opcional: limpia también filtros si quieres
                      });
                      _loadUsuarios();
                    }
                  },
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: _selectedType == 'Empleados'
                          ? null
                          : CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.grey[300],
                              backgroundImage:
                                  (u['photoUrl'] as String).isNotEmpty
                                      ? NetworkImage(u['photoUrl'])
                                      : null,
                              child: (u['photoUrl'] as String).isEmpty
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                      title: Text(nombre,
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      subtitle: _selectedType != 'Administradores'
                          ? Text(
                              jobRole,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey[600]),
                            )
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                );
              },
            ),
          ),

          // botón Ver más
          if (_hasMore && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mainOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => _loadUsuarios(loadMore: true),
                child: Text('Ver más'.tr(),
                    style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
