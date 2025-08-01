// admin_reports_detail.dart

// ignore_for_file: unnecessary_cast, depend_on_referenced_packages, unnecessary_import, use_build_context_synchronously, deprecated_member_use, prefer_interpolation_to_compose_strings, unnecessary_brace_in_string_interps, avoid_types_as_parameter_names, must_call_super, unused_element, curly_braces_in_flow_control_structures, unused_local_variable, unused_field, unused_import, control_flow_in_finally

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:namer_app/admin_pages/admin_reports/date_filter_section.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Modelo de un registro de asistencia (para PDF/Excel)
class _Registro {
  final String fechaEntradaStr;
  final String fechaSalidaStr;
  final DateTime fechaEntradaTs;
  final DateTime fechaSalidaTs;
  final String empresa;
  final List<String> flechas;
  final String supervisor;
  final List<String> companeros;
  final String imagenTimesheetUrl;
  final String comentarioEntrada;
  final String comentarioEntradaImgUrl;
  final String comentarioSalida;
  final String comentarioSalidaImgUrl;
  final String ubicacionEntrada;

  _Registro({
    required this.fechaEntradaStr,
    required this.fechaSalidaStr,
    required this.fechaEntradaTs,
    required this.fechaSalidaTs,
    required this.empresa,
    required this.flechas,
    required this.supervisor,
    required this.companeros,
    required this.imagenTimesheetUrl,
    required this.comentarioEntrada,
    required this.comentarioEntradaImgUrl,
    required this.comentarioSalida,
    required this.comentarioSalidaImgUrl,
    required this.ubicacionEntrada,
  });
}

class AdminReportsDetail extends StatefulWidget {
  final String userId;
  final String nombre;
  final String photoUrl;

  const AdminReportsDetail({
    Key? key,
    required this.userId,
    required this.nombre,
    required this.photoUrl,
  }) : super(key: key);

  @override
  State<AdminReportsDetail> createState() => _AdminReportsDetailState();
}

class _AdminReportsDetailState extends State<AdminReportsDetail>
    with AutomaticKeepAliveClientMixin {
  final Color _mainOrange = const Color(0xFFFF8902);

  DateTime? _createdAt;
  String _email = '';
  String _phone = '';

  late final Stream<List<String>> dailyRoles$;
  String? _selectedDailyRol;
  String? _selectedJob;
  final TextEditingController _salaryController = TextEditingController();

  late int _selectedMonth;
  late int _selectedYear;
  String _address = '';
  String _security = '';

  bool _showAllRecords = false;
  bool _isExporting = false; // ← nuevo
  final Set<String> _expandedIds = {};

  @override
  bool get wantKeepAlive => true;

  // Para el tipo de reporte (semanal/mensual/bimestral)
  ReportType _reportType = ReportType.monthly;

// Para el rango de fechas seleccionado
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    _selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    _selectedMonth = now.month;
    _selectedYear = now.year;
    dailyRoles$ = FirebaseFirestore.instance
        .collection('roles')
        .doc('cargo')
        .snapshots()
        .map((snap) => List<String>.from(snap.data()?['dailyRol'] ?? []));

    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (!mounted) return;
    final data = doc.data();
    if (data == null) return;

    final ts = data['createdAt'];
    DateTime? created = (ts is Timestamp) ? ts.toDate() : (ts as DateTime?);

    setState(() {
      _createdAt = created;
      _email = data['email'] ?? '';
      _phone = data['phone'] ?? '';
      _selectedDailyRol = data['dailyRole'] as String?;
      _selectedJob = data['jobRole'] as String?;
      _salaryController.text = (data['salary']?.toString() ?? '');
      _address = data['address'] ?? '';
      _security = data['security'] ?? '';
    });
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Confirmar borrado'.tr()),
          content: Text('¿Eliminar usuario y todos sus registros?'.tr()),
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

    final batch = FirebaseFirestore.instance.batch();

    // Borra registros
    final registros = await FirebaseFirestore.instance
        .collection('registros')
        .where('usuario_id', isEqualTo: widget.userId)
        .get();
    for (var d in registros.docs) {
      batch.delete(d.reference);
    }

    // Borra usuario
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(widget.userId);
    batch.delete(userRef);

    await batch.commit();
// Devuelve “true” para indicar que borramos algo
    Navigator.of(context).pop(true);
  }

  Future<void> _pickMonthYear() async {
    final now = DateTime.now();
    final picked = await showMonthPicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
      firstDate: DateTime(now.year - 5, 1),
      lastDate: DateTime(now.year, now.month),
      // si necesitas forzar otro idioma, descomenta builder:
      // builder: (ctx, child) => Localizations.override(
      //   context: ctx,
      //   locale: Locale('es','ES'),
      //   child: child,
      // ),
    );
    if (picked != null) {
      setState(() {
        _selectedYear = picked.year;
        _selectedMonth = picked.month;
      });
    }
  }

  /// Para PDF/Excel
  Future<List<_Registro>> _loadMonthlyRecords() async {
    // 1) Calculamos rangos de fecha
    final inicioMesUtc = DateTime.utc(_selectedYear, _selectedMonth, 1);
    final inicioProxUtc = _selectedMonth == 12
        ? DateTime.utc(_selectedYear + 1, 1, 1)
        : DateTime.utc(_selectedYear, _selectedMonth + 1, 1);

    final tsInicio = Timestamp.fromDate(inicioMesUtc);
    final tsFin = Timestamp.fromDate(inicioProxUtc);

    // 2) Traemos TODOS los registros del mes (sin filtrar 'cerrado')
    final snapshot = await FirebaseFirestore.instance
        .collection('registros')
        .where('usuario_id', isEqualTo: widget.userId)
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedRange!.start))
        .where('fecha_entrada',
            isLessThanOrEqualTo: Timestamp.fromDate(_selectedRange!.end))
        .orderBy('fecha_entrada', descending: true)
        .get();

    // 3) Filtramos en memoria sólo los documentos con fecha_salida no nula
    final closedDocs = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['fecha_salida'] != null;
    });

    // 4) Mapeamos a nuestra clase _Registro
    return closedDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      return _Registro(
        fechaEntradaStr: data['fecha_entrada'] is Timestamp
            ? DateFormat('dd/MM/yy – HH:mm')
                .format((data['fecha_entrada'] as Timestamp).toDate())
            : (data['fecha_entrada'] ?? '').toString(),
        fechaSalidaStr: data['fecha_salida'] is Timestamp
            ? DateFormat('dd/MM/yy – HH:mm')
                .format((data['fecha_salida'] as Timestamp).toDate())
            : (data['fecha_salida'] ?? '').toString(),
        fechaEntradaTs: (data['fecha_entrada'] as Timestamp).toDate(),
        fechaSalidaTs: (data['fecha_salida'] as Timestamp).toDate(),
        empresa: data['empresa'] ?? '',
        flechas: List<String>.from(data['flechas'] ?? []),
        supervisor: data['supervisor'] ?? '',
        companeros: List<String>.from(data['companeros'] ?? []),
        imagenTimesheetUrl: data['imagen_timesheet_url'] ?? '',
        comentarioEntrada: data['comentarios'] ?? '',
        comentarioEntradaImgUrl: data['comentario_imagen_url'] ?? '',
        comentarioSalida: data['comentarios_salida'] ?? '',
        comentarioSalidaImgUrl: data['comentario_salida_imagen_url'] ?? '',
        ubicacionEntrada: data['ubicacion_entrada_texto'] ?? '',
      );
    }).toList();
  }

  /// Para tarjetas: trae doc.raw con id
  Future<List<Map<String, dynamic>>> _loadMonthlyRecordsRaw() async {
    // 1) Consulta sin el filtro 'cerrado'
    final inicioMesUtc = DateTime.utc(_selectedYear, _selectedMonth, 1);
    final inicioProxUtc = _selectedMonth == 12
        ? DateTime.utc(_selectedYear + 1, 1, 1)
        : DateTime.utc(_selectedYear, _selectedMonth + 1, 1);
    final tsInicio = Timestamp.fromDate(inicioMesUtc);
    final tsFin = Timestamp.fromDate(inicioProxUtc);

    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('usuario_id', isEqualTo: widget.userId)
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedRange!.start))
        .where('fecha_entrada',
            isLessThanOrEqualTo: Timestamp.fromDate(_selectedRange!.end))
        .orderBy('fecha_entrada', descending: true)
        .get();

    // 2) Filtramos fecha_salida != null (o cerrado == true)
    final closedDocs = snap.docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['fecha_salida'] != null; // o data['cerrado'] == true
    });

    return closedDocs.map((d) {
      final m = Map<String, dynamic>.from(d.data() as Map);
      m['id'] = d.id;
      return m;
    }).toList();
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedIds.contains(id))
        _expandedIds.remove(id);
      else
        _expandedIds.add(id);
    });
  }

  void _showImageFullscreen(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final id = record['id'] as String;
    final entradaTs = (record['fecha_entrada'] as Timestamp).toDate();
    final salidaTs = (record['fecha_salida'] as Timestamp).toDate();
    final dur = salidaTs.difference(entradaTs);

    final fechaStr =
        DateFormat('d MMMM, yyyy', context.locale.toString()).format(entradaTs);
    final horaStr = '${DateFormat('HH:mm').format(entradaTs)} - '
        '${DateFormat('HH:mm').format(salidaTs)}';
    final durStr = '${dur.inHours}h ${dur.inMinutes % 60}m';

    final empresa = record['empresa'] as String? ?? '--';
    final flechas = (record['flechas'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .join(', ') ??
        '';
    final supervisor = record['supervisor'] as String? ?? '--';
    final List<String> companerosList =
        (record['companeros'] as List<dynamic>?)?.cast<String>() ?? [];

    final timesheetUrl = record['imagen_timesheet_url'] as String? ?? '';
    final commentIn = record['comentarios'] as String? ?? '';
    final commentInUrl = record['comentario_imagen_url'] as String? ?? '';
    final commentOut = record['comentarios_salida'] as String? ?? '';
    final commentOutUrl =
        record['comentario_salida_imagen_url'] as String? ?? '';
    final salidaUrl = record['imagen_salida_url'] as String? ?? '';
    final ubicacionSalida = record['ubicacion_salida_texto'] as String? ?? '';

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
              offset: const Offset(0, 2),
            )
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
                  child: Text(empresa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[800])),
                ),
              ],
            ),
          ),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          children: [
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
            _detailRow('Supervisor:', supervisor),
            if (flechas.isNotEmpty) _detailRow('Flechas:', flechas),
            if (companerosList.isNotEmpty) ...[
              // Título "Compañeros:"
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Compañeros:'.tr(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Una fila por cada compañero, con guion
              ...companerosList.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '- ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[800],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            c,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],
            if (commentIn.isNotEmpty) ...[
              // Comentarios de entrada
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Comentarios entrada:'.tr(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 4),
// Texto del comentario
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  commentIn,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 12),

// Foto comentario entrada
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(value, style: GoogleFonts.poppins(fontSize: 13))),
        ],
      ),
    );
  }

  Future<List<WeeklySummary>> _loadWeeklySummary() async {
    // 1) Defino rango completo del día
    final start = DateTime(
      _selectedRange!.start.year,
      _selectedRange!.start.month,
      _selectedRange!.start.day,
    );
    final end = DateTime(
      _selectedRange!.end.year,
      _selectedRange!.end.month,
      _selectedRange!.end.day,
      23,
      59,
      59,
    );

    // 2) Traigo solo los registros cerrados de este usuario en el rango
    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('usuario_id', isEqualTo: widget.userId)
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha_entrada', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

// filtrar en memoria
    final recs = snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((r) => r['fecha_salida'] != null)
        .toList();
    // 3) Acumulo horas por día y cálculos
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

    // 4) Traigo nombre y salario del usuario
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final data = userDoc.data()!;
    final name = '${data['firstName']} ${data['lastName']}';
    final salary = (data['salary'] as num?)?.toDouble() ?? 0;

    // 5) Construyo el resumen único
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
      _selectedRange!.start.year,
      _selectedRange!.start.month,
      _selectedRange!.start.day,
    );
    final end = DateTime(
      _selectedRange!.end.year,
      _selectedRange!.end.month,
      _selectedRange!.end.day,
      23,
      59,
      59,
    );

    // 2) Traer solo los registros cerrados de este usuario en el rango
    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('usuario_id', isEqualTo: widget.userId)
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha_entrada', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

// filtrar en memoria
    final recs = snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((r) => r['fecha_salida'] != null)
        .toList();
    // 3) Inicializar acumuladores por semana (1 a 5)
    final hoursPerWeek = <int, double>{for (var i = 1; i <= 5; i++) i: 0.0};
    double weightedDays = 0;

    // 4) Recorrer registros y acumular horas/días
    for (final r in recs) {
      final fe = (r['fecha_entrada'] as Timestamp).toDate();
      final fs = (r['fecha_salida'] as Timestamp).toDate();
      final h = fs.difference(fe).inMinutes / 60.0;
      final week = ((fe.day - 1) ~/ 7) + 1;
      if (week >= 1 && week <= 5) {
        hoursPerWeek[week] = hoursPerWeek[week]! + h;
      }
      if (h <= 5)
        weightedDays += 0.5;
      else if (h <= 10)
        weightedDays += 1;
      else
        weightedDays += 1.5;
    }

    // 5) Obtener nombre y salario del usuario
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final data = userDoc.data()!;
    final name = '${data['firstName']} ${data['lastName']}';
    final salary = (data['salary'] as num?)?.toDouble() ?? 0.0;

    // 6) Construir resumen mensual individual
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
      _selectedRange!.start.year,
      _selectedRange!.start.month,
      _selectedRange!.start.day,
    );
    final end = DateTime(
      _selectedRange!.end.year,
      _selectedRange!.end.month,
      _selectedRange!.end.day,
      23,
      59,
      59,
    );

    // 2) Traer solo los registros cerrados de este usuario en el rango
    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('usuario_id', isEqualTo: widget.userId)
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha_entrada', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

// filtrar en memoria
    final recs = snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((r) => r['fecha_salida'] != null)
        .toList();
    // 3) Inicializar acumuladores por cada una de las 8 semanas
    final hoursPerWeek = <int, double>{for (var i = 1; i <= 8; i++) i: 0.0};
    double weightedDays = 0;

    // 4) Recorrer registros y acumular horas y días ponderados
    for (final r in recs) {
      final fe = (r['fecha_entrada'] as Timestamp).toDate();
      final fs = (r['fecha_salida'] as Timestamp).toDate();
      final h = fs.difference(fe).inMinutes / 60.0;
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

    // 5) Obtener nombre y salario del usuario
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final data = userDoc.data()!;
    final name = '${data['firstName']} ${data['lastName']}';
    final salary = (data['salary'] as num?)?.toDouble() ?? 0.0;

    // 6) Construir y devolver un único BimonthlySummary
    final summary = BimonthlySummary(
      name: name,
      salary: salary,
      days: weightedDays,
      hoursPerWeek: hoursPerWeek,
    );

    return [summary];
  }

  /// PDF export
  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      switch (_reportType) {
        case ReportType.weekly:
          await _exportPdfWeekly();
          break;
        case ReportType.monthly:
          await _exportPdfMonthly(); // si tu PDF mensual está en otro método, ajústalo
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

  Future<void> _exportPdfWeekly() async {
    // 1. Cargar el resumen semanal del usuario actual
    final List<WeeklySummary> summary = await _loadWeeklySummary();

    // 2. Formatear el periodo
    final start = _selectedRange!.start;
    final end = _selectedRange!.end;
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
              'REPORTE SEMANAL INDIVIDUAL'.tr(),
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          pw.SizedBox(height: 8),

          // Datos del usuario y del periodo
          pw.Text('Usuario: ${widget.nombre}'.tr(),
              style: pw.TextStyle(fontSize: 12)),
          pw.Text('Semana: $periodo'.tr(), style: pw.TextStyle(fontSize: 12)),

          pw.SizedBox(height: 8),

          // Nota de la regla de días
          pw.Text(
            'FULL DAY IF THEY WORK MORE THAN 5 HOURS. HALF DAY IF THEY WORK 5 HOURS OR LESS. (DIA COMPLETO SI TRABAJAN MAS DE 5 HORAS. MEDIO DIA SI TRABAJAN 5 HORAS O MENOS.)'
                .tr(),
            style:
                pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#555555')),
          ),

          pw.SizedBox(height: 16),

          // Tabla con horas por día, días totales, salario y total a pagar
          pw.Table.fromTextArray(
            headers: [
              'Usuario'.tr(),
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
  }

  Future<void> _exportPdfMonthly() async {
    // 1. Cargar el resumen mensual (solo del usuario actual)
    final List<MonthlySummary> summary = await _loadMonthlySummary();

    // 2. Preparar texto de cabecera
    final start = _selectedRange!.start;
    final end = _selectedRange!.end;
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
              'REPORTE MENSUAL INDIVIDUAL'.tr(),
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          pw.SizedBox(height: 8),

          // Información del usuario y del periodo
          pw.Text('Usuario: ${widget.nombre}'.tr(),
              style: pw.TextStyle(fontSize: 12)),
          pw.Text('Periodo: $periodo'.tr(), style: pw.TextStyle(fontSize: 12)),

          pw.SizedBox(height: 8),

          // Nota de la regla de días
          pw.Text(
            'FULL DAY IF THEY WORK MORE THAN 5 HOURS. HALF DAY IF THEY WORK 5 HOURS OR LESS. (DÍA COMPLETO SI TRABAJAN MÁS DE 5 HORAS. MEDIO DÍA SI TRABAJAN 5 HORAS O MENOS.)'
                .tr(),
            style:
                pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#555555')),
          ),

          pw.SizedBox(height: 16),

          // Tabla de horas por semana para este usuario
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
  }

  Future<void> _exportPdfBimonthly() async {
    // 1. Cargar el resumen bimestral del usuario actual
    final List<BimonthlySummary> summary = await _loadBimonthlySummary();

    // 2. Preparar texto de cabecera
    final start = _selectedRange!.start;
    final end = _selectedRange!.end;
    final periodo = '${DateFormat('dd/MM/yyyy').format(start)} - '
        '${DateFormat('dd/MM/yyyy').format(end)}';

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
              'REPORTE BIMESTRAL INDIVIDUAL (8 SEMANAS)'.tr(),
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          pw.SizedBox(height: 8),

          // Datos del usuario y del periodo
          pw.Text('Usuario: ${widget.nombre}'.tr(),
              style: pw.TextStyle(fontSize: 12)),
          pw.Text('Periodo: $periodo'.tr(), style: pw.TextStyle(fontSize: 12)),

          pw.SizedBox(height: 8),

          // Nota de la regla de días
          pw.Text(
            'FULL DAY IF THEY WORK MORE THAN 5 HOURS. HALF DAY IF THEY WORK 5 HOURS OR LESS. (DÍA COMPLETO SI TRABAJAN MÁS DE 5 HORAS. MEDIO DÍA SI TRABAJAN 5 HORAS O MENOS.)'
                .tr(),
            style:
                pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#555555')),
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
  }

  /// Excel export

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

  Future<void> _exportExcelWeekly() async {
    // 1. Cargar el resumen semanal del usuario actual
    final List<WeeklySummary> summary = await _loadWeeklySummary();

    // 2. Crear un nuevo workbook de Excel
    final excel = Excel.createExcel();
    final sheet = excel['Semanal'];

    // 3. Preparar periodo
    final start = _selectedRange!.start;
    final end = _selectedRange!.end;
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
  }

  Future<void> _exportExcelMonthly() async {
    // 1. Cargar el resumen mensual del usuario actual
    final List<MonthlySummary> summary = await _loadMonthlySummary();

    // 2. Crear un nuevo workbook de Excel
    final excel = Excel.createExcel();
    final sheet = excel['Mensual'];

    // 3. Preparar periodo
    final start = _selectedRange!.start;
    final end = _selectedRange!.end;
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
  }

  Future<void> _exportExcelBimonthly() async {
    // 1. Cargar el resumen bimestral del usuario actual
    final List<BimonthlySummary> summary = await _loadBimonthlySummary();

    // 2. Crear un nuevo workbook de Excel
    final excel = Excel.createExcel();
    final sheet = excel['Bimestral'];

    // 3. Preparar periodo
    final start = _selectedRange!.start;
    final end = _selectedRange!.end;
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
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final createdStr = _createdAt != null
        ? DateFormat('dd/MM/yyyy', context.locale.toString())
            .format(_createdAt!)
        : '...';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F3),

      // --- CABECERA NARANJA en todo el top ---
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
              child: Text(widget.nombre,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.black),
              onPressed: _deleteUser,
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              key: const PageStorageKey('admin_reports_list'),
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 16),

                // INFO CARD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Info Card Usuario'.tr(),
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
                            // 1ª fila: Fecha de inicio / Teléfono
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Fecha de inicio'.tr(),
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[700])),
                                      const SizedBox(height: 4),
                                      Text(createdStr,
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Teléfono'.tr(),
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[700])),
                                      const SizedBox(height: 4),
                                      Text(_phone,
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 24),

                            // 2ª fila: Email / Dirección
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email'.tr(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _email,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Dirección'.tr(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _address,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 24),

                            // 3ª fila: Job Role / Daily Role
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Job Role'.tr(),
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[700])),
                                      const SizedBox(height: 4),
                                      Text(_selectedJob ?? '-',
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Daily Role'.tr(),
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[700])),
                                      const SizedBox(height: 4),
                                      Text(_selectedDailyRol ?? '-',
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 24),

                            // 4ª fila: Seguridad / Salario
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Seguridad'.tr(),
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[700])),
                                      const SizedBox(height: 4),
                                      Text(_security,
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Sueldo por día'.tr(),
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[700])),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 100,
                                        child: TextFormField(
                                          controller: _salaryController,
                                          textAlign: TextAlign.right,
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                  decimal: true),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 4, horizontal: 8),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            suffixText: 'USD'.tr(),
                                            suffixStyle: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: Colors.grey[600]),
                                          ),
                                          onFieldSubmitted: (val) async {
                                            final num? newSalary =
                                                num.tryParse(val);
                                            if (newSalary != null) {
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(widget.userId)
                                                  .update(
                                                      {'salary': newSalary});
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Salary updated'.tr()),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'invalid_number'.tr()),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
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
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // SELECTOR MES/AÑO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DateFilterSection(
                    onTypeChanged: (type) {
                      setState(() {
                        _reportType = type;
                      });
                    },
                    onPeriodChanged: (range) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() {
                          _selectedRange = range;
                        });
                      });
                    },
                  ),
                ),

                const SizedBox(height: 4),

                // BOTONES EXPORTACIÓN
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text(
                            'Exportar PDF'.tr(),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                              iconColor: Colors.white,
                              backgroundColor: _mainOrange,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: _isExporting ? null : _exportPdf,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.table_chart),
                          label: Text(
                            'Exportar Excel'.tr(),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                              iconColor: Colors.white,
                              backgroundColor: _mainOrange,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: _isExporting ? null : _exportExcel,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Reportes generales'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Sección de asistencia: tarjetas
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadMonthlyRecordsRaw(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError)
                      return Text('    Error al cargar registros'.tr(),
                          style: GoogleFonts.poppins(color: Colors.red));

                    final regs = snapshot.data ?? [];
                    if (regs.isEmpty)
                      return Text('    No hay registros para este mes.'.tr(),
                          style: GoogleFonts.poppins(fontSize: 14));

                    // Aquí definimos la lista visible según el flag:
                    final visibleRegs =
                        _showAllRecords ? regs : regs.take(5).toList();

                    return Column(
                      children: [
                        // Dibujamos sólo los visibles:
                        ...visibleRegs
                            .map((record) => _buildRecordCard(record)),
                        // Si hay más de 5, mostramos el botón Ver más / Ver menos:
                        if (regs.length > 5)
                          TextButton(
                            onPressed: () => setState(
                                () => _showAllRecords = !_showAllRecords),
                            child: Text(
                              _showAllRecords
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

            // Overlay bloqueante mientras exporta
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
