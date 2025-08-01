// lib/admin_pages/admin_reports/admin_reports_detail_employees.dart

// ignore_for_file: unused_import, curly_braces_in_flow_control_structures, unnecessary_cast, unused_field, depend_on_referenced_packages, use_build_context_synchronously, deprecated_member_use, unnecessary_import, unused_element, control_flow_in_finally

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';

// Ajusta la ruta a tu DateFilterSection y ReportType
import 'package:namer_app/admin_pages/admin_reports/date_filter_section.dart';

class AdminReportsDetailEmployees extends StatefulWidget {
  final String userId;
  final String nombre;
  final String photoUrl;

  const AdminReportsDetailEmployees({
    Key? key,
    required this.userId,
    required this.nombre,
    required this.photoUrl,
  }) : super(key: key);

  @override
  State<AdminReportsDetailEmployees> createState() =>
      _AdminReportsDetailEmployeesState();
}

class _AdminReportsDetailEmployeesState
    extends State<AdminReportsDetailEmployees> {
  final Color _mainOrange = const Color(0xFFFF8902);

  // Info Card
  DateTime? _createdAt;
  String _phone = '';
  String _address = '';
  late final Stream<List<String>> _dailyRoles$;
  final List<String> _jobOptions = ['Traffic control', 'Concrete', 'Drilling'];
  String? _selectedJob;
  String? _selectedDailyRole;
  bool _showAllCompanionRecords = false;
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _securityController = TextEditingController();
  bool _isExporting = false; // ← nuevo

  // Filtros de fecha
  ReportType _reportType = ReportType.monthly;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  DateTimeRange _selectedRange = DateTimeRange(
    // Un rango trivial que evite el late init error
    start: DateTime.now(),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _dailyRoles$ = FirebaseFirestore.instance
        .collection('roles')
        .doc('cargo')
        .snapshots()
        .map((snap) => List<String>.from(snap.data()?['dailyRol'] ?? []));
    _loadUserInfo();

    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedRange = DateTimeRange(
      start: DateTime(_selectedYear, _selectedMonth, 1),
      end: DateTime(_selectedYear, _selectedMonth + 1, 0),
    );
  }

  Future<void> _loadUserInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.userId)
        .get();
    if (!mounted || !doc.exists) return;
    final data = doc.data()!;
    final ts = data['createdAt'];
    DateTime? created;
    if (ts is Timestamp)
      created = ts.toDate();
    else if (ts is DateTime) created = ts;
    setState(() {
      _createdAt = created;
      _phone = data['phone'] ?? '';
      _address = data['address'] ?? '';
      _selectedJob = data['jobRole'] as String?;
      _selectedDailyRole = data['dailyRole'] as String?;
      _salaryController.text = data['salary']?.toString() ?? '';
      _securityController.text = data['security'] ?? '';
    });
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Confirmar borrado'.tr()),
          content: Text('¿Eliminar empleado y todos sus datos?'.tr()),
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

  Future<void> _deleteUser() async {
    final ok = await _confirmDelete();
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.userId)
        .delete();
    Navigator.of(context).pop(true);
  }

  InputDecoration _fieldDecoration() => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _buildInfoCard() {
    final createdStr = _createdAt != null
        ? DateFormat('dd/MM/yyyy', context.locale.toString())
            .format(_createdAt!)
        : '...';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Row 1
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fecha de inicio'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text(createdStr,
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Teléfono'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text(_phone,
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Row 2
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dirección'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text(_address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Row 3
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Job Role'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        decoration: _fieldDecoration(),
                        isDense: true,
                        value: _selectedJob,
                        items: _jobOptions
                            .map((j) => DropdownMenuItem(
                                  value: j,
                                  child:
                                      Text(j, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) async {
                          setState(() => _selectedJob = v);
                          await FirebaseFirestore.instance
                              .collection('employees')
                              .doc(widget.userId)
                              .update({'jobRole': v});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Daily Role'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      StreamBuilder<List<String>>(
                        stream: _dailyRoles$,
                        builder: (ctx, snap) {
                          if (!snap.hasData)
                            return const Center(
                                child: CircularProgressIndicator());
                          final opts = snap.data!;
                          return DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: _fieldDecoration(),
                            value: _selectedDailyRole,
                            items: opts
                                .map((r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            selectedItemBuilder: (ctx) => opts
                                .map((r) => Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(r,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right),
                                    ))
                                .toList(),
                            onChanged: (v) async {
                              setState(() => _selectedDailyRole = v);
                              await FirebaseFirestore.instance
                                  .collection('employees')
                                  .doc(widget.userId)
                                  .update({'dailyRole': v});
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Row 4
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Security'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _securityController,
                        decoration: _fieldDecoration(),
                        onFieldSubmitted: (val) async {
                          await FirebaseFirestore.instance
                              .collection('employees')
                              .doc(widget.userId)
                              .update({'security': val});
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Security actualizado'.tr())));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Sueldo por día'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _salaryController,
                          textAlign: TextAlign.right,
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            suffixText: 'USD'.tr(),
                            suffixStyle: GoogleFonts.poppins(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                          onFieldSubmitted: (val) async {
                            final num? newSalary = num.tryParse(val);
                            if (newSalary != null) {
                              await FirebaseFirestore.instance
                                  .collection('employees')
                                  .doc(widget.userId)
                                  .update({'salary': newSalary});
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Salary updated'.tr()),
                                      backgroundColor: Colors.green));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('invalid_number'.tr()),
                                      backgroundColor: Colors.red));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadCompanionRecordsRaw() async {
    final tsInicio = Timestamp.fromDate(_selectedRange.start);
    final tsFin = Timestamp.fromDate(_selectedRange.end);

    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('companeros', arrayContains: widget.nombre)
        .where('estado', isEqualTo: 'cerrado')
        .get();

    // trae los IDs de los dueños (usuario_id) para luego mapear nombres
    final ownerIds = snap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['usuario_id'] as String)
        .toSet()
        .toList();

    final ownerMap = <String, String>{};
    if (ownerIds.isNotEmpty) {
      final ownersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: ownerIds)
          .get();
      for (var d in ownersSnap.docs) {
        final data = d.data();
        ownerMap[d.id] = '${data['firstName']} ${data['lastName']}';
      }
    }

    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;

      return {
        'id': d.id,
        'fecha_entrada': data['fecha_entrada'] as Timestamp,
        'fecha_salida': data['fecha_salida'] as Timestamp,
        'empresa': data['empresa'] ?? '',
        'flechas': List<String>.from(data['flechas'] ?? []),
        'supervisor': data['supervisor'] ?? '',
        'companeros': List<String>.from(data['companeros'] ?? []),
        'comentarios': data['comentarios'] ?? '',
        'comentario_imagen_url': data['comentario_imagen_url'] ?? '',
        'comentarios_salida': data['comentarios_salida'] ?? '',
        'comentario_salida_imagen_url':
            data['comentario_salida_imagen_url'] ?? '',
        'ubicacion_salida_texto': data['ubicacion_salida_texto'] ?? '',
        'imagen_timesheet_url': data['imagen_timesheet_url'] ?? '',
        'imagen_salida_url': data['imagen_salida_url'] ?? '',
        // Éste es el nombre real del usuario que creó el registro:
        'ownerName': ownerMap[data['usuario_id']] ?? '--',
      };
    }).where((r) {
      // filtrado rango fechas en memoria:
      final te = (r['fecha_entrada'] as Timestamp);
      return te.compareTo(tsInicio) >= 0 && te.compareTo(tsFin) <= 0;
    }).toList()
      // opcional: orden descendente por fecha
      ..sort((a, b) {
        final aTs = (a['fecha_entrada'] as Timestamp).toDate();
        final bTs = (b['fecha_entrada'] as Timestamp).toDate();
        return bTs.compareTo(aTs);
      });
  }

  //Widget _buildCompanionCard(Map<String, dynamic> r) {
  Widget _buildCompanionCard(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final entrada = (r['fecha_entrada'] as Timestamp).toDate();
    final salida = (r['fecha_salida'] as Timestamp).toDate();
    final dur = salida.difference(entrada);

    final fechaStr =
        DateFormat('d MMMM, yyyy', context.locale.toString()).format(entrada);
    final horaStr = '${DateFormat('HH:mm').format(entrada)} – '
        '${DateFormat('HH:mm').format(salida)}';
    final durStr = '${dur.inHours}h ${dur.inMinutes % 60}m';

    final ownerName = r['ownerName'] as String? ?? '--';
    final empresa = r['empresa'] as String? ?? '--';
    final supervisor = r['supervisor'] as String? ?? '--';
    final flechas = (r['flechas'] as List<String>).join(', ');
    final companeros = (r['companeros'] as List<String>)
        .where((c) => c != widget.nombre)
        .toList();
    final commentIn = r['comentarios'] as String? ?? '';
    final commentInUrl = r['comentario_imagen_url'] as String? ?? '';
    final commentOut = r['comentarios_salida'] as String? ?? '';
    final commentOutUrl = r['comentario_salida_imagen_url'] as String? ?? '';

    final ubicacionSalida = r['ubicacion_salida_texto'] as String? ?? '';
    final timesheetUrl = r['imagen_timesheet_url'] as String? ?? '';
    final salidaUrl = r['imagen_salida_url'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black12.withOpacity(0.1),
                blurRadius: 6,
                offset: Offset(0, 2))
          ],
        ),
        child: ExpansionTile(
          key: PageStorageKey(id),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fechaStr,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(durStr,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(horaStr,
                    style: GoogleFonts.poppins(
                        color: Colors.grey[700], fontSize: 13)),
                Flexible(
                  child: Text(
                    empresa,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                        color: Colors.grey[800], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          children: [
            // ————————————————
            //   Aquí tu nuevo orden
            // ————————————————
            _detailRow('Reporte de:'.tr(), ownerName),
            const Divider(),

            if (timesheetUrl.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Time sheet:'.tr(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => _showImageFullscreen(timesheetUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      timesheetUrl,
                      height: 200,
                      width: 250,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            _detailRow('Supervisor:'.tr(), supervisor),
            if (flechas.isNotEmpty) _detailRow('Flechas:'.tr(), flechas),

            if (companeros.isNotEmpty) ...[
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Compañeros:'.tr(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 13))),
              const SizedBox(height: 4),
              ...companeros.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('- ',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.grey[800])),
                        Expanded(
                            child: Text(c,
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: Colors.grey[800]))),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            if (commentIn.isNotEmpty) ...[
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Comentarios entrada:'.tr(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 13))),
              const SizedBox(height: 4),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(commentIn,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[800]))),
              const SizedBox(height: 12),
              if (commentInUrl.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Foto comentario entrada:'.tr(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => _showImageFullscreen(commentInUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        commentInUrl,
                        height: 200,
                        width: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

// Comentarios de salida
              if (commentOut.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Comentarios salida:'.tr(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    commentOut,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

// Foto comentario salida
              if (commentOutUrl.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Foto comentario salida:'.tr(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => _showImageFullscreen(commentOutUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        commentOutUrl,
                        height: 200,
                        width: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
            if (ubicacionSalida.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.pin_drop, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(' $ubicacionSalida',
                        style: GoogleFonts.poppins(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (salidaUrl.isNotEmpty) ...[
              Text('Foto salida (ampliada):'.tr(),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showImageFullscreen(salidaUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(salidaUrl,
                      height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text('$label ',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(value, style: GoogleFonts.poppins(fontSize: 12))),
        ]),
      );

  void _showImageFullscreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  //
  //

  Future<List<WeeklySummary>> _loadWeeklySummary() async {
    // 1) Defino rango completo del día
    final start = DateTime(
      _selectedRange.start.year,
      _selectedRange.start.month,
      _selectedRange.start.day,
    );
    final end = DateTime(
      _selectedRange.end.year,
      _selectedRange.end.month,
      _selectedRange.end.day,
      23,
      59,
      59,
    );

    // 2) Traigo todos los registros donde este empleado fue compañero
    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('companeros', arrayContains: widget.nombre)
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha_entrada', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    // 3) Filtrar en memoria sólo los cerrados
    final recs = snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((r) => r['fecha_salida'] != null)
        .toList();

    // 4) Acumulo horas por día y cálculos
    final hoursPerDay = {
      'lun'.tr(): 0.0,
      'mar'.tr(): 0.0,
      'mie'.tr(): 0.0,
      'jue'.tr(): 0.0,
      'vie'.tr(): 0.0,
      'sab'.tr(): 0.0,
      'dom'.tr(): 0.0,
    };
    double totalH = 0, weighted = 0;
    final comments = <String>[];

    for (final r in recs) {
      final fe = (r['fecha_entrada'] as Timestamp).toDate();
      final fs = (r['fecha_salida'] as Timestamp).toDate();
      final h = fs.difference(fe).inMinutes / 60.0;
      totalH += h;

      final dow = [
        'lun'.tr(),
        'mar'.tr(),
        'mie'.tr(),
        'jue'.tr(),
        'vie'.tr(),
        'sab'.tr(),
        'dom'.tr()
      ][fe.weekday - 1];
      hoursPerDay[dow] = hoursPerDay[dow]! + h;

      if ((r['comentarios_salida'] as String?)?.isNotEmpty == true)
        comments.add(r['comentarios_salida'] as String);

      if (h <= 5)
        weighted += 0.5;
      else if (h <= 10)
        weighted += 1;
      else
        weighted += 1.5;
    }

    // 5) Traigo nombre y salario del empleado
    final empDoc = await FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.userId)
        .get();
    final data = empDoc.data()!;
    final name = '${data['firstName']} ${data['lastName']}';
    final salary = (data['salary'] as num?)?.toDouble() ?? 0;

    // 6) Construyo el resumen único
    final summary = WeeklySummary(
      name: name,
      salary: salary,
      days: weighted,
      hoursPerDay: hoursPerDay,
      totalHours: totalH,
      comments: comments.join('\n'),
    );

    return [summary];
  }

  Future<List<MonthlySummary>> _loadMonthlySummary() async {
    // 1) Definir rango completo del día
    final start = DateTime(
      _selectedRange.start.year,
      _selectedRange.start.month,
      _selectedRange.start.day,
    );
    final end = DateTime(
      _selectedRange.end.year,
      _selectedRange.end.month,
      _selectedRange.end.day,
      23,
      59,
      59,
    );

    // 2) Traer todos los registros donde este empleado fue compañero en el rango
    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('companeros', arrayContains: widget.nombre)
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha_entrada', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    // 3) Filtrar en memoria sólo los cerrados
    final recs = snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((r) => r['fecha_salida'] != null)
        .toList();

    // 4) Inicializar acumuladores por semana (1 a 5)
    final hoursPerWeek = <int, double>{for (var i = 1; i <= 5; i++) i: 0.0};
    double weightedDays = 0;

    // 5) Recorrer registros y acumular horas/días
    for (final r in recs) {
      final fe = (r['fecha_entrada'] as Timestamp).toDate();
      final fs = (r['fecha_salida'] as Timestamp).toDate();
      final h = fs.difference(fe).inMinutes / 60.0;
      final wk = ((fe.day - 1) ~/ 7) + 1;
      if (wk >= 1 && wk <= 5) {
        hoursPerWeek[wk] = hoursPerWeek[wk]! + h;
      }
      if (h <= 5)
        weightedDays += 0.5;
      else if (h <= 10)
        weightedDays += 1;
      else
        weightedDays += 1.5;
    }

    // 6) Obtener nombre y salario del empleado
    final empDoc = await FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.userId)
        .get();
    final data = empDoc.data()!;
    final name = '${data['firstName']} ${data['lastName']}';
    final salary = (data['salary'] as num?)?.toDouble() ?? 0.0;

    // 7) Construir resumen mensual individual
    final summary = MonthlySummary(
      name: name,
      salary: salary,
      days: weightedDays,
      hoursPerWeek: hoursPerWeek,
    );

    return [summary];
  }

  Future<List<BimonthlySummary>> _loadBimonthlySummary() async {
    // 1) Definir rango completo del día
    final start = DateTime(
      _selectedRange.start.year,
      _selectedRange.start.month,
      _selectedRange.start.day,
    );
    final end = DateTime(
      _selectedRange.end.year,
      _selectedRange.end.month,
      _selectedRange.end.day,
      23,
      59,
      59,
    );

    // 2) Cargar todos los registros en los que este empleado aparece como compañero
    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('companeros', arrayContains: widget.nombre)
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha_entrada', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    // 3) Filtrar en memoria sólo los registros con salida no nula
    final recs = snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((r) => r['fecha_salida'] != null)
        .toList();

    // 4) Inicializar acumuladores para las 8 semanas
    final hoursPerWeek = <int, double>{for (var i = 1; i <= 8; i++) i: 0.0};
    double weightedDays = 0;

    // 5) Recorrer registros y acumular horas + días ponderados
    for (final r in recs) {
      final fe = (r['fecha_entrada'] as Timestamp).toDate();
      final fs = (r['fecha_salida'] as Timestamp).toDate();
      final h = fs.difference(fe).inMinutes / 60.0;
      // calcular índice de semana dentro del bimestre
      final idx = (fe.difference(start).inDays ~/ 7) + 1;
      if (idx >= 1 && idx <= 8) {
        hoursPerWeek[idx] = hoursPerWeek[idx]! + h;
      }
      if (h <= 5)
        weightedDays += 0.5;
      else if (h <= 10)
        weightedDays += 1;
      else
        weightedDays += 1.5;
    }

    // 6) Obtener nombre y salario del empleado
    final empDoc = await FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.userId)
        .get();
    final data = empDoc.data()!;
    final name = '${data['firstName']} ${data['lastName']}';
    final salary = (data['salary'] as num?)?.toDouble() ?? 0.0;

    // 7) Construir y devolver un único BimonthlySummary
    final summary = BimonthlySummary(
      name: name,
      salary: salary,
      days: weightedDays,
      hoursPerWeek: hoursPerWeek,
    );

    return [summary];
  }

  //
  //
  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      switch (_reportType) {
        case ReportType.weekly:
          await _exportPdfWeekly();
          break;
        case ReportType.monthly:
          await _exportPdfMonthly();
          break;
        case ReportType.bimonthly:
          await _exportPdfBimonthly();
          break;
      }
    } finally {
      if (!mounted) return;
      setState(() => _isExporting = false);
    }
  }

  //
  Future<void> _exportPdfWeekly() async {
    // Deshabilitar botón mientras exporta
    setState(() => _isExporting = true);
    try {
      // 1. Cargar el resumen semanal del empleado actual
      final List<WeeklySummary> summary = await _loadWeeklySummary();

      // 2. Formatear el periodo
      final start = _selectedRange.start;
      final end = _selectedRange.end;
      final periodo = '${DateFormat('dd/MM/yyyy').format(start)} - '
          '${DateFormat('dd/MM/yyyy').format(end)}';

      // 3. Crear documento PDF
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            // Cabecera naranja
            pw.Container(
              width: double.infinity,
              color: PdfColor.fromHex('#FF8902'),
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: pw.Text(
                'REPORTE SEMANAL EMPLEADO'.tr(),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 8),

            // Datos del empleado y del periodo
            pw.Text('Empleado: ${widget.nombre}'.tr(),
                style: pw.TextStyle(fontSize: 12)),
            pw.Text('Semana: $periodo'.tr(), style: pw.TextStyle(fontSize: 12)),

            pw.SizedBox(height: 8),

            // Nota de la regla de días
            pw.Text(
              'FULL DAY IF THEY WORK MORE THAN 5 HOURS. HALF DAY IF THEY WORK 5 HOURS OR LESS. '
                      '(DÍA COMPLETO SI TRABAJAN MÁS DE 5 HORAS. MEDIO DÍA SI TRABAJAN 5 HORAS O MENOS.)'
                  .tr(),
              style: pw.TextStyle(
                  fontSize: 10, color: PdfColor.fromHex('#555555')),
            ),

            pw.SizedBox(height: 16),

            // Tabla con horas por día, días totales, salario y total a pagar
            pw.Table.fromTextArray(
              headers: [
                'Empleado'.tr(),
                'Vie'.tr(),
                'Sáb'.tr(),
                'Dom'.tr(),
                'Lun'.tr(),
                'Mar'.tr(),
                'Mié'.tr(),
                'Jue'.tr(),
                'Días Trab'.tr(),
                'Salario'.tr(),
                'Total Pagar'.tr(),
                'Comentarios'.tr(),
              ],
              data: summary.map((w) {
                return [
                  w.name,
                  w.hoursPerDay['vie']!.toStringAsFixed(1),
                  w.hoursPerDay['sab']!.toStringAsFixed(1),
                  w.hoursPerDay['dom']!.toStringAsFixed(1),
                  w.hoursPerDay['lun']!.toStringAsFixed(1),
                  w.hoursPerDay['mar']!.toStringAsFixed(1),
                  w.hoursPerDay['mie']!.toStringAsFixed(1),
                  w.hoursPerDay['jue']!.toStringAsFixed(1),
                  w.days.toStringAsFixed(1),
                  w.salary.toStringAsFixed(2),
                  (w.salary * w.days).toStringAsFixed(2),
                  w.comments,
                ];
              }).toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: pw.TextStyle(fontSize: 9),
              headerDecoration:
                  pw.BoxDecoration(color: PdfColor.fromHex('#F2F2F2')),
            ),

            pw.SizedBox(height: 12),

            // Pie con total de registros
            pw.Text(
              'Total registros: ${summary.length}'.tr(),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

      // 4. Guardar y compartir
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final fileName =
          'ReporteSemanal_${widget.nombre}_${DateFormat('yyyyMMdd').format(start)}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        text: 'Reporte Semanal - ${widget.nombre}'.tr(),
      );
    } finally {
      // Volver a habilitar botones
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdfMonthly() async {
    // Deshabilitar botones mientras exporta
    setState(() => _isExporting = true);
    try {
      // 1. Cargar el resumen mensual del empleado actual
      final List<MonthlySummary> summary = await _loadMonthlySummary();

      // 2. Preparar texto de cabecera
      final start = _selectedRange.start;
      final end = _selectedRange.end;
      final periodo =
          '${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';

      // 3. Crear el documento PDF
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            // Cabecera naranja
            pw.Container(
              width: double.infinity,
              color: PdfColor.fromHex('#FF8902'),
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: pw.Text(
                'REPORTE MENSUAL EMPLEADO'.tr(),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 8),

            // Datos del empleado y del periodo
            pw.Text('Empleado: ${widget.nombre}'.tr(),
                style: pw.TextStyle(fontSize: 12)),
            pw.Text('Periodo: $periodo'.tr(),
                style: pw.TextStyle(fontSize: 12)),

            pw.SizedBox(height: 8),

            // Nota de la regla de días
            pw.Text(
              'FULL DAY IF THEY WORK MORE THAN 5 HOURS. HALF DAY IF THEY WORK 5 HOURS OR LESS. '
                      '(DÍA COMPLETO SI TRABAJAN MÁS DE 5 HORAS. MEDIO DÍA SI TRABAJAN 5 HORAS O MENOS.)'
                  .tr(),
              style: pw.TextStyle(
                  fontSize: 10, color: PdfColor.fromHex('#555555')),
            ),

            pw.SizedBox(height: 16),

            // Tabla de horas por semana para este empleado
            pw.Table.fromTextArray(
              headers: [
                'Sem 1'.tr(),
                'Sem 2'.tr(),
                'Sem 3'.tr(),
                'Sem 4'.tr(),
                'Sem 5'.tr(),
                'Días Trab'.tr(),
                'Salario'.tr(),
                'Total Pagar'.tr(),
              ],
              data: summary.map((m) {
                return [
                  m.hoursPerWeek[1]!.toStringAsFixed(1),
                  m.hoursPerWeek[2]!.toStringAsFixed(1),
                  m.hoursPerWeek[3]!.toStringAsFixed(1),
                  m.hoursPerWeek[4]!.toStringAsFixed(1),
                  m.hoursPerWeek[5]!.toStringAsFixed(1),
                  m.days.toStringAsFixed(1),
                  m.salary.toStringAsFixed(2),
                  (m.salary * m.days).toStringAsFixed(2),
                ];
              }).toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: pw.TextStyle(fontSize: 9),
              headerDecoration:
                  pw.BoxDecoration(color: PdfColor.fromHex('#F2F2F2')),
            ),

            pw.SizedBox(height: 12),

            // Pie con total de semanas registradas
            pw.Text(
              'Semanas registradas: ${summary.length}'.tr(),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

      // 4. Guardar y compartir en un archivo individual
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final suffix = DateFormat('yyyyMM').format(start);
      final fileName = 'ReporteMensual_${widget.nombre}_$suffix.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        text: 'Reporte Mensual - ${widget.nombre}'.tr(),
      );
    } finally {
      // Volver a habilitar botones
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdfBimonthly() async {
    // Deshabilitar botones mientras exporta
    setState(() => _isExporting = true);
    try {
      // 1. Cargar el resumen bimestral del empleado actual
      final List<BimonthlySummary> summary = await _loadBimonthlySummary();

      // 2. Preparar texto de cabecera
      final start = _selectedRange.start;
      final end = _selectedRange.end;
      final periodo =
          '${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';

      // 3. Crear el documento PDF
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            // Cabecera naranja
            pw.Container(
              width: double.infinity,
              color: PdfColor.fromHex('#FF8902'),
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: pw.Text(
                'REPORTE BIMESTRAL EMPLEADO (8 SEMANAS)'.tr(),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 8),

            // Datos del empleado y del periodo
            pw.Text('Empleado: ${widget.nombre}'.tr(),
                style: pw.TextStyle(fontSize: 12)),
            pw.Text('Periodo: $periodo'.tr(),
                style: pw.TextStyle(fontSize: 12)),

            pw.SizedBox(height: 8),

            // Nota de la regla de días
            pw.Text(
              'FULL DAY IF THEY WORK MORE THAN 5 HOURS. HALF DAY IF THEY WORK 5 HOURS OR LESS. '
                      '(DÍA COMPLETO SI TRABAJAN MÁS DE 5 HORAS. MEDIO DÍA SI TRABAJAN 5 HORAS O MENOS.)'
                  .tr(),
              style: pw.TextStyle(
                  fontSize: 10, color: PdfColor.fromHex('#555555')),
            ),

            pw.SizedBox(height: 16),

            // Tabla de las 8 semanas
            pw.Table.fromTextArray(
              headers: [
                'Sem 1'.tr(),
                'Sem 2'.tr(),
                'Sem 3'.tr(),
                'Sem 4'.tr(),
                'Sem 5'.tr(),
                'Sem 6'.tr(),
                'Sem 7'.tr(),
                'Sem 8'.tr(),
                'Días Trab'.tr(),
                'Salario'.tr(),
                'Total Pagar'.tr(),
              ],
              data: summary.map((b) {
                return [
                  for (var i = 1; i <= 8; i++)
                    b.hoursPerWeek[i]!.toStringAsFixed(1),
                  b.days.toStringAsFixed(1),
                  b.salary.toStringAsFixed(2),
                  (b.salary * b.days).toStringAsFixed(2),
                ];
              }).toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: pw.TextStyle(fontSize: 9),
              headerDecoration:
                  pw.BoxDecoration(color: PdfColor.fromHex('#F2F2F2')),
            ),

            pw.SizedBox(height: 12),

            // Pie con total de semanas registradas
            pw.Text(
              'Semanas registradas: ${summary.length}'.tr(),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

      // 4. Guardar y compartir
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final suffix =
          '${DateFormat('yyyyMMdd').format(start)}-${DateFormat('yyyyMMdd').format(end)}';
      final fileName = 'ReporteBimestral_${widget.nombre}_$suffix.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        text: 'Reporte Bimestral - ${widget.nombre}'.tr(),
      );
    } finally {
      // Volver a habilitar botones
      if (mounted) setState(() => _isExporting = false);
    }
  }

  //

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      switch (_reportType) {
        case ReportType.weekly:
          await _exportExcelWeekly();
          break;
        case ReportType.monthly:
          await _exportExcelMonthly();
          break;
        case ReportType.bimonthly:
          await _exportExcelBimonthly();
          break;
      }
    } finally {
      if (!mounted) return;
      setState(() => _isExporting = false);
    }
  }

  //
  //
  Future<void> _exportExcelWeekly() async {
    setState(() => _isExporting = true);
    try {
      // 1. Cargar el resumen semanal del empleado actual
      final List<WeeklySummary> summary = await _loadWeeklySummary();

      // 2. Crear un nuevo workbook de Excel
      final excel = Excel.createExcel();
      final sheet = excel['Semanal'];

      // 3. Preparar periodo
      final start = _selectedRange.start;
      final end = _selectedRange.end;
      final periodo =
          '${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';

      // 4. Título y periodo en la hoja
      sheet.appendRow(['Reporte Semanal - ${widget.nombre}'.tr()]);
      sheet.appendRow(['Periodo'.tr(), periodo]);
      sheet.appendRow([]);

      // 5. Cabecera de columnas (sin columna "Nombre")
      sheet.appendRow([
        'Vie'.tr(),
        'Sáb'.tr(),
        'Dom'.tr(),
        'Lun'.tr(),
        'Mar'.tr(),
        'Mié'.tr(),
        'Jue'.tr(),
        'Días Trab'.tr(),
        'Salario'.tr(),
        'Total Pagar'.tr(),
        'Comentarios'.tr(),
      ]);

      // 6. Filas de datos
      for (var w in summary) {
        sheet.appendRow([
          w.hoursPerDay['vie']!.toStringAsFixed(1),
          w.hoursPerDay['sab']!.toStringAsFixed(1),
          w.hoursPerDay['dom']!.toStringAsFixed(1),
          w.hoursPerDay['lun']!.toStringAsFixed(1),
          w.hoursPerDay['mar']!.toStringAsFixed(1),
          w.hoursPerDay['mie']!.toStringAsFixed(1),
          w.hoursPerDay['jue']!.toStringAsFixed(1),
          w.days.toStringAsFixed(1),
          w.salary.toStringAsFixed(2),
          (w.salary * w.days).toStringAsFixed(2),
          w.comments,
        ]);
      }

      // 7. Guardar y compartir
      final bytes = excel.encode()!;
      final dir = await getTemporaryDirectory();
      final suffix = DateFormat('yyyyMMdd').format(start);
      final fileName = 'ReporteSemanal_${widget.nombre}_$suffix.xlsx';
      final filePath = '${dir.path}/$fileName';
      File(filePath).writeAsBytesSync(bytes);

      await Share.shareXFiles(
        [XFile(filePath, name: fileName)],
        text: 'Reporte Semanal - ${widget.nombre}'.tr(),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExcelMonthly() async {
    setState(() => _isExporting = true);
    try {
      // 1. Cargar el resumen mensual del empleado actual
      final List<MonthlySummary> summary = await _loadMonthlySummary();

      // 2. Crear un nuevo workbook de Excel
      final excel = Excel.createExcel();
      final sheet = excel['Mensual'];

      // 3. Preparar periodo
      final start = _selectedRange.start;
      final end = _selectedRange.end;
      final periodo =
          '${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';

      // 4. Título y periodo
      sheet.appendRow(['Reporte Mensual - ${widget.nombre}'.tr()]);
      sheet.appendRow(['Periodo'.tr(), periodo]);
      sheet.appendRow([]);

      // 5. Cabecera de columnas (sin columna "Nombre")
      sheet.appendRow([
        'Sem 1'.tr(),
        'Sem 2'.tr(),
        'Sem 3'.tr(),
        'Sem 4'.tr(),
        'Sem 5'.tr(),
        'Días Trab'.tr(),
        'Salario'.tr(),
        'Total Pagar'.tr(),
      ]);

      // 6. Filas de datos
      for (var m in summary) {
        sheet.appendRow([
          m.hoursPerWeek[1]!.toStringAsFixed(1),
          m.hoursPerWeek[2]!.toStringAsFixed(1),
          m.hoursPerWeek[3]!.toStringAsFixed(1),
          m.hoursPerWeek[4]!.toStringAsFixed(1),
          m.hoursPerWeek[5]!.toStringAsFixed(1),
          m.days.toStringAsFixed(1),
          m.salary.toStringAsFixed(2),
          (m.salary * m.days).toStringAsFixed(2),
        ]);
      }

      // 7. Guardar y compartir
      final bytes = excel.encode()!;
      final dir = await getTemporaryDirectory();
      final suffix = DateFormat('yyyyMM').format(start);
      final fileName = 'ReporteMensual_${widget.nombre}_$suffix.xlsx';
      final filePath = '${dir.path}/$fileName';
      File(filePath).writeAsBytesSync(bytes);

      await Share.shareXFiles(
        [XFile(filePath, name: fileName)],
        text: 'Reporte Mensual - ${widget.nombre}'.tr(),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExcelBimonthly() async {
    setState(() => _isExporting = true);
    try {
      // 1. Cargar el resumen bimestral del empleado actual
      final List<BimonthlySummary> summary = await _loadBimonthlySummary();

      // 2. Crear un nuevo workbook de Excel
      final excel = Excel.createExcel();
      final sheet = excel['Bimestral'];

      // 3. Preparar periodo
      final start = _selectedRange.start;
      final end = _selectedRange.end;
      final periodo =
          '${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';

      // 4. Título y periodo
      sheet.appendRow(['Reporte Bimestral - ${widget.nombre}'.tr()]);
      sheet.appendRow(['Periodo'.tr(), periodo]);
      sheet.appendRow([]);

      // 5. Cabecera de columnas (sin "Nombre")
      sheet.appendRow([
        'Sem 1'.tr(),
        'Sem 2'.tr(),
        'Sem 3'.tr(),
        'Sem 4'.tr(),
        'Sem 5'.tr(),
        'Sem 6'.tr(),
        'Sem 7'.tr(),
        'Sem 8'.tr(),
        'Días Trab'.tr(),
        'Salario'.tr(),
        'Total Pagar'.tr(),
      ]);

      // 6. Filas de datos
      for (var b in summary) {
        sheet.appendRow([
          for (var i = 1; i <= 8; i++) b.hoursPerWeek[i]!.toStringAsFixed(1),
          b.days.toStringAsFixed(1),
          b.salary.toStringAsFixed(2),
          (b.salary * b.days).toStringAsFixed(2),
        ]);
      }

      // 7. Guardar y compartir
      final bytes = excel.encode()!;
      final dir = await getTemporaryDirectory();
      final suffix = DateFormat('yyyyMMdd').format(start);
      final fileName = 'ReporteBimestral_${widget.nombre}_$suffix.xlsx';
      final filePath = '${dir.path}/$fileName';
      File(filePath).writeAsBytesSync(bytes);

      await Share.shareXFiles(
        [XFile(filePath, name: fileName)],
        text: 'Reporte Bimestral - ${widget.nombre}'.tr(),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F3),
      appBar: AppBar(
        backgroundColor: _mainOrange,
        elevation: 0,
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: widget.photoUrl.isNotEmpty
                ? NetworkImage(widget.photoUrl)
                : null,
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.nombre,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          IconButton(
              icon: const Icon(Icons.delete, color: Colors.black),
              onPressed: _deleteUser),
        ]),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 16),

                // Info Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Info Card Empleado'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                _buildInfoCard(),

                // Date filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DateFilterSection(
                    onTypeChanged: (type) => setState(() => _reportType = type),
                    onPeriodChanged: (range) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _selectedRange = range);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Export buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text('Exportar PDF'.tr(),
                            style: GoogleFonts.poppins(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _mainOrange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: _isExporting ? null : _exportPdf,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.table_chart),
                        label: Text('Exportar Excel'.tr(),
                            style: GoogleFonts.poppins(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _mainOrange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: _isExporting ? null : _exportExcel,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Registros como compañero
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Registros como compañero'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadCompanionRecordsRaw(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (snap.hasError)
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Error al cargar registros'.tr(),
                            style: GoogleFonts.poppins(color: Colors.red)),
                      );

                    final regs = snap.data ?? [];
                    if (regs.isEmpty)
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('No hay registros como compañero.'.tr(),
                            style: GoogleFonts.poppins()),
                      );

                    return Column(
                      children: [
                        ...regs.map((r) => _buildCompanionCard(r)).toList(),
                        if (regs.length > 5)
                          TextButton(
                            onPressed: () => setState(() =>
                                _showAllCompanionRecords =
                                    !_showAllCompanionRecords),
                            child: Text(
                              _showAllCompanionRecords
                                  ? 'Ver menos'.tr()
                                  : 'Ver más'.tr(),
                              style: GoogleFonts.poppins(color: _mainOrange),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),

            // overlay bloqueante durante exportación
            if (_isExporting)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WeeklySummary {
  final String name;
  final double salary;
  final double days; // días ponderados 0.5/1/1.5
  final Map<String, double> hoursPerDay; // {'vie':2.5, 'sab':0,...}
  final double totalHours;
  final String comments; // concatenación de comentarios_salida

  WeeklySummary({
    required this.name,
    required this.salary,
    required this.days,
    required this.hoursPerDay,
    required this.totalHours,
    required this.comments,
  });
}

class MonthlySummary {
  final String name;
  final double salary;
  final double days; // días ponderados 0.5/1/1.5
  final Map<int, double> hoursPerWeek; // semana 1…5
  MonthlySummary({
    required this.name,
    required this.salary,
    required this.days,
    required this.hoursPerWeek,
  });
}

class BimonthlySummary {
  final String name;
  final double salary;
  final double days; // días ponderados
  final Map<int, double>
      hoursPerWeek; // ahora guarda las 8 semanas: {1:hrs, 2:hrs, …, 8:hrs}

  BimonthlySummary({
    required this.name,
    required this.salary,
    required this.days,
    required this.hoursPerWeek,
  });
}
