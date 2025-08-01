// admin_employees_add.dart

// ignore_for_file: sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminEmployeesAdd extends StatefulWidget {
  const AdminEmployeesAdd({Key? key}) : super(key: key);

  @override
  State<AdminEmployeesAdd> createState() => _AdminEmployeesAddState();
}

class _AdminEmployeesAddState extends State<AdminEmployeesAdd> {
  final Color _mainOrange = const Color(0xFFFF8902);
  List<String> _dailyRoles = [];

  @override
  void initState() {
    super.initState();
    _loadDailyRoles();
  }

  Future<void> _loadDailyRoles() async {
    final doc =
        await FirebaseFirestore.instance.collection('roles').doc('cargo').get();
    final data = doc.data() ?? {};
    final list = List<String>.from(data['dailyRol'] ?? []);
    setState(() => _dailyRoles = list);
  }

  Future<void> _addDailyRole() async {
    final ctrl = TextEditingController();
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Agregar cargo diario'.tr()),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: 'Cargo'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('Agregar'.tr()),
          ),
        ],
      ),
    );

    if (nuevo?.isNotEmpty ?? false) {
      await FirebaseFirestore.instance.collection('roles').doc('cargo').update({
        'dailyRol': FieldValue.arrayUnion([nuevo!])
      });
      await _loadDailyRoles();
    }
  }

  Future<void> _removeDailyRole(String role) async {
    await FirebaseFirestore.instance.collection('roles').doc('cargo').update({
      'dailyRol': FieldValue.arrayRemove([role])
    });
    await _loadDailyRoles();
  }

  Future<void> _confirmRemove(String role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirmar borrado'.tr()),
        content: Text("¿Eliminar el cargo '$role'?".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Borrar'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) _removeDailyRole(role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cargos diarios'.tr(),
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _mainOrange,
      ),
      body: _dailyRoles.isEmpty
          ? Center(
              child: Text('No hay cargos'.tr(),
                  style: GoogleFonts.poppins(fontSize: 16)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _dailyRoles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final role = _dailyRoles[i];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(role,
                            style: GoogleFonts.poppins(fontSize: 14)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _confirmRemove(role),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _mainOrange,
        child: const Icon(Icons.add),
        onPressed: _addDailyRole,
      ),
    );
  }
}
