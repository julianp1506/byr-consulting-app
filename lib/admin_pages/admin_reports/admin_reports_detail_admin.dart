// admin_reports_detail_admin.dart

// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminReportsDetailAdmin extends StatefulWidget {
  final String userId;
  final String nombre;
  final String photoUrl;

  const AdminReportsDetailAdmin({
    Key? key,
    required this.userId,
    required this.nombre,
    required this.photoUrl,
  }) : super(key: key);

  @override
  State<AdminReportsDetailAdmin> createState() =>
      _AdminReportsDetailAdminState();
}

class _AdminReportsDetailAdminState extends State<AdminReportsDetailAdmin> {
  final Color _mainOrange = const Color(0xFFFF8902);

  DateTime? _createdAt;
  String _email = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (!mounted || !doc.exists) return;
    final data = doc.data()!;
    DateTime? created;
    final ts = data['createdAt'];
    if (ts is Timestamp)
      created = ts.toDate();
    else if (ts is DateTime) created = ts;
    setState(() {
      _createdAt = created;
      _email = data['email'] ?? '';
      _phone = data['phone'] ?? '';
    });
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Confirmar borrado'.tr()),
          content: Text('¿Eliminar administrador y todos sus datos?'.tr()),
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

  Future<void> _deleteUser() async {
    final ok = await _confirmDelete();
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .delete();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final createdStr = _createdAt != null
        ? DateFormat('dd/MM/yyyy', context.locale.toString())
            .format(_createdAt!)
        : '...';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F3),
      appBar: AppBar(
        backgroundColor: _mainOrange,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 20,
              backgroundImage: widget.photoUrl.isNotEmpty
                  ? NetworkImage(widget.photoUrl)
                  : null,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.nombre,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.black),
              onPressed: _deleteUser,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 16),

            // INFO CARD
            // INFO CARD ADMINISTRADOR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Info Card Administrador'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Fila 1: Fecha de inicio / Teléfono
                        Row(
                          children: [
                            Expanded(
                              child: _infoColumn(
                                label: 'Fecha de inicio'.tr(),
                                value: createdStr,
                              ),
                            ),
                            Expanded(
                              child: _infoColumn(
                                label: 'Teléfono'.tr(),
                                value: _phone,
                                alignEnd: true,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Fila 2: Email / Dirección
                        Row(
                          children: [
                            Expanded(
                              child: _infoColumn(
                                label: 'Email'.tr(),
                                value: _email,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoColumn({
    required String label,
    required String value,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 4),
        Text(
          value.isNotEmpty ? value : '-',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }
}
