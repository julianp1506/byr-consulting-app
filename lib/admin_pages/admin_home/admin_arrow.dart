// admin_arrow.dart

// ignore_for_file: sort_child_properties_last

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminArrowPage extends StatefulWidget {
  const AdminArrowPage({Key? key}) : super(key: key);

  @override
  State<AdminArrowPage> createState() => _AdminArrowPageState();
}

class _AdminArrowPageState extends State<AdminArrowPage> {
  final Color _mainOrange = const Color(0xFFFF8902);
  List<String> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final doc = await FirebaseFirestore.instance
        .collection('arrow_board_options')
        .doc('config')
        .get();
    final data = doc.data() ?? {};
    final list = List<String>.from(data['flechas'] ?? []);
    setState(() => _items = list);
  }

  Future<void> _addItem() async {
    final ctrl = TextEditingController();
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Agregar flecha'.tr()),
        content: TextField(
            controller: ctrl,
            decoration: InputDecoration(labelText: 'ID'.tr())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text('Agregar'.tr())),
        ],
      ),
    );
    if (nuevo?.isNotEmpty ?? false) {
      await FirebaseFirestore.instance
          .collection('arrow_board_options')
          .doc('config')
          .update({
        'flechas': FieldValue.arrayUnion([nuevo!])
      });
      await _loadItems();
    }
  }

  Future<void> _removeItem(String item) async {
    await FirebaseFirestore.instance
        .collection('arrow_board_options')
        .doc('config')
        .update({
      'flechas': FieldValue.arrayRemove([item])
    });
    await _loadItems();
  }

  Future<void> _confirmRemoveItem(String item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirmar borrado'.tr()),
        content: Text("¿Seguro que quieres borrar la flecha '$item'?".tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Borrar'.tr())),
        ],
      ),
    );
    if (ok == true) _removeItem(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Flechas'.tr(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: _mainOrange,
      ),
      body: _items.isEmpty
          ? Center(
              child: Text('No hay flechas'.tr(), style: GoogleFonts.poppins()))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e = _items[i];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    children: [
                      Expanded(
                          child: Text(e,
                              style: GoogleFonts.poppins(fontSize: 14))),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _confirmRemoveItem(e),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _mainOrange,
        child: const Icon(Icons.add),
        onPressed: _addItem,
      ),
    );
  }
}
