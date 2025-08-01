// admin_reports_general.dart

// ignore_for_file: library_private_types_in_public_api, unnecessary_cast, unused_element, unused_import, unused_local_variable, curly_braces_in_flow_control_structures, unnecessary_import, depend_on_referenced_packages, use_build_context_synchronously, deprecated_member_use
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'date_filter_section.dart' as dfs;

enum ReportFilter { usuario, empleado }

class AdminReportsGeneral extends StatefulWidget {
  const AdminReportsGeneral({Key? key}) : super(key: key);

  @override
  _AdminReportsGeneralState createState() => _AdminReportsGeneralState();
}

class _AdminReportsGeneralState extends State<AdminReportsGeneral> {
  // estados
  bool _isLoading = false;
  bool _isExporting = false;

  final tipoLabel = 'Tipo'.tr(); // Traduce "Tipo"
  final semanaLabel = 'Semana'.tr(); // Traduce "Semana"
  final periodoLabel = 'Periodo'.tr(); // Si quieres usar la misma palabra
  final trabajadoresLabel = 'Total trabajadores'.tr(); // Traduce "Usuario"
  final mesLabel = 'Mes'.tr(); // Traduce "Mes"

  // filtros
  dfs.ReportType _reportType = dfs.ReportType.monthly;
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );
  ReportFilter _selectedFilter = ReportFilter.usuario;

  // datos
  int _totalUsuarios = 0;
  int _totalEmpleados = 0;
  List<Map<String, dynamic>> _userSummary = [];
  List<Map<String, dynamic>> _employeeSummary = [];

  // colores
  static const Color _mainOrange = Color(0xFFFF8902);
  static const Color _bgColor = Color(0xFFF2F5F3);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // por defecto: mes actual
    _selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    // carga inicial
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGeneralData());
  }

  Future<void> _loadGeneralData() async {
    setState(() => _isLoading = true);
    try {
      // limitar al día completo
      final start = DateTime(_selectedRange.start.year,
          _selectedRange.start.month, _selectedRange.start.day);
      final end = DateTime(_selectedRange.end.year, _selectedRange.end.month,
          _selectedRange.end.day, 23, 59, 59);
      final startTs = Timestamp.fromDate(start);
      final endTs = Timestamp.fromDate(end);

      // 1) totales
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('rol', isEqualTo: 'usuario')
          .get();
      final empSnap =
          await FirebaseFirestore.instance.collection('employees').get();

      // 2) resumen según tipo de reporte
      List<Map<String, dynamic>> rows = [];
      switch (_reportType) {
        case dfs.ReportType.weekly:
          final wk = await _loadWeeklySummary();
          for (final w in wk) {
            rows.add({
              'nombre'.tr(): w.name,
              'promedio'.tr(): w.days > 0 ? w.totalHours / w.days : 0.0,
              'dias'.tr(): w.days,
              'horas'.tr(): w.totalHours,
            });
          }
          break;
        case dfs.ReportType.monthly:
          final mon = await _loadMonthlySummary();
          for (final m in mon) {
            final totalH =
                m.hoursPerWeek.values.fold<double>(0, (a, b) => a + b);
            rows.add({
              'nombre'.tr(): m.name,
              'promedio'.tr(): m.days > 0 ? totalH / m.days : 0.0,
              'dias'.tr(): m.days,
              'horas'.tr(): totalH,
            });
          }
          break;
        case dfs.ReportType.bimonthly:
          final bi = await _loadBimonthlySummary();
          for (final b in bi) {
            final totalH =
                b.hoursPerWeek.values.fold<double>(0, (a, b) => a + b);
            rows.add({
              'nombre'.tr(): b.name,
              'promedio'.tr(): b.days > 0 ? totalH / b.days : 0.0,
              'dias'.tr(): b.days,
              'horas'.tr(): totalH,
            });
          }
          break;
      }

      // 3) aplicar a usuario o empleado
      setState(() {
        _totalUsuarios = usersSnap.docs.length;
        _totalEmpleados = empSnap.docs.length;
        if (_selectedFilter == ReportFilter.usuario) {
          _userSummary = rows;
          _employeeSummary = [];
        } else {
          _employeeSummary = rows;
          _userSummary = [];
        }
      });
    } catch (e, st) {
      debugPrint('Error en _loadGeneralData: $e\n$st'.tr());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando datos: $e').tr()),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<WeeklySummary>> _loadWeeklySummary() async {
    final start = _selectedRange.start;
    final end = _selectedRange.end;
    // 1) registros en rango + cerrados
    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha_entrada', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .where('fecha_salida', isNotEqualTo: null)
        .get();
    final docs =
        snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    // 2) agrupar por uid o compañero
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in docs) {
      if (_selectedFilter == ReportFilter.usuario) {
        final uid = r['usuario_id'] as String;
        groups.putIfAbsent(uid, () => []).add(r);
      } else {
        for (final c in List<String>.from(r['companeros'] ?? [])) {
          groups.putIfAbsent(c, () => []).add(r);
        }
      }
    }
    // 3) construir lista
    final List<WeeklySummary> out = [];
    for (final entry in groups.entries) {
      final key = entry.key;
      final recs = entry.value;
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
      // nombre y salary
      String name;
      double salary;
      if (_selectedFilter == ReportFilter.usuario) {
        final u =
            await FirebaseFirestore.instance.collection('users').doc(key).get();
        final d = u.data()!;
        name = '${d['firstName']} ${d['lastName']}';
        salary = (d['salary'] as num?)?.toDouble() ?? 0;
      } else {
        // por simple: usamos key como nombre
        name = key;
        final e = await FirebaseFirestore.instance
            .collection('employees')
            .where('firstName', isEqualTo: key.split(' ')[0])
            .where('lastName', isEqualTo: key.split(' ').last)
            .limit(1)
            .get();
        salary = (e.docs.isNotEmpty
                ? (e.docs.first.data()['salary'] as num?)?.toDouble()
                : 0) ??
            0;
      }
      out.add(WeeklySummary(
        name: name,
        salary: salary,
        days: weighted,
        hoursPerDay: hoursPerDay,
        totalHours: totalH,
        comments: comments.join('\n'),
      ));
    }
    return out;
  }

  Future<List<MonthlySummary>> _loadMonthlySummary() async {
    final start = _selectedRange.start;
    final end = _selectedRange.end;
    // mismo esquema que semanal, pero agrupando por semana del mes
    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha_entrada', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .where('fecha_salida', isNotEqualTo: null)
        .get();
    final docs =
        snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in docs) {
      if (_selectedFilter == ReportFilter.usuario) {
        final uid = r['usuario_id'] as String;
        groups.putIfAbsent(uid, () => []).add(r);
      } else {
        for (final c in List<String>.from(r['companeros'] ?? [])) {
          groups.putIfAbsent(c, () => []).add(r);
        }
      }
    }
    final out = <MonthlySummary>[];
    for (final e in groups.entries) {
      final key = e.key, recs = e.value;
      final hoursPerWeek = {for (var i = 1; i <= 5; i++) i: 0.0};
      double weighted = 0;
      for (final r in recs) {
        final fe = (r['fecha_entrada'] as Timestamp).toDate();
        final fs = (r['fecha_salida'] as Timestamp).toDate();
        final h = fs.difference(fe).inMinutes / 60.0;
        final wk = ((fe.day - 1) ~/ 7) + 1;
        hoursPerWeek[wk] = hoursPerWeek[wk]! + h;
        if (h <= 5)
          weighted += 0.5;
        else if (h <= 10)
          weighted += 1;
        else
          weighted += 1.5;
      }
      // obtener name & salary idéntico a semanal
      String name;
      double salary;
      if (_selectedFilter == ReportFilter.usuario) {
        final u =
            await FirebaseFirestore.instance.collection('users').doc(key).get();
        final d = u.data()!;
        name = '${d['firstName']} ${d['lastName']}';
        salary = (d['salary'] as num?)?.toDouble() ?? 0;
      } else {
        name = key;
        final eSnap = await FirebaseFirestore.instance
            .collection('employees')
            .where('firstName', isEqualTo: key.split(' ')[0])
            .where('lastName', isEqualTo: key.split(' ').last)
            .limit(1)
            .get();
        salary = (eSnap.docs.isNotEmpty
                ? (eSnap.docs.first.data()['salary'] as num?)?.toDouble()
                : 0) ??
            0;
      }
      out.add(MonthlySummary(
        name: name,
        salary: salary,
        days: weighted,
        hoursPerWeek: hoursPerWeek,
      ));
    }
    return out;
  }

  Future<List<BimonthlySummary>> _loadBimonthlySummary() async {
    final start = _selectedRange.start;
    final end = _selectedRange.end;
    // igual que mensual, pero 8 semanas
    final snap = await FirebaseFirestore.instance
        .collection('registros')
        .where('fecha_entrada',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha_entrada', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .where('fecha_salida', isNotEqualTo: null)
        .get();
    final docs =
        snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in docs) {
      if (_selectedFilter == ReportFilter.usuario) {
        final uid = r['usuario_id'] as String;
        groups.putIfAbsent(uid, () => []).add(r);
      } else {
        for (final c in List<String>.from(r['companeros'] ?? [])) {
          groups.putIfAbsent(c, () => []).add(r);
        }
      }
    }
    final out = <BimonthlySummary>[];
    for (final e in groups.entries) {
      final key = e.key, recs = e.value;
      final hoursPerWeek = {for (var i = 1; i <= 8; i++) i: 0.0};
      double weighted = 0;
      for (final r in recs) {
        final fe = (r['fecha_entrada'] as Timestamp).toDate();
        final fs = (r['fecha_salida'] as Timestamp).toDate();
        final h = fs.difference(fe).inMinutes / 60.0;
        final idx = (fe.difference(start).inDays ~/ 7) + 1;
        if (idx >= 1 && idx <= 8) hoursPerWeek[idx] = hoursPerWeek[idx]! + h;
        if (h <= 5)
          weighted += 0.5;
        else if (h <= 10)
          weighted += 1;
        else
          weighted += 1.5;
      }
      // nombre & salary igual
      String name;
      double salary;
      if (_selectedFilter == ReportFilter.usuario) {
        final u =
            await FirebaseFirestore.instance.collection('users').doc(key).get();
        final d = u.data()!;
        name = '${d['firstName']} ${d['lastName']}';
        salary = (d['salary'] as num?)?.toDouble() ?? 0;
      } else {
        name = key;
        final eSnap = await FirebaseFirestore.instance
            .collection('employees')
            .where('firstName', isEqualTo: key.split(' ')[0])
            .where('lastName', isEqualTo: key.split(' ').last)
            .limit(1)
            .get();
        salary = (eSnap.docs.isNotEmpty
                ? (eSnap.docs.first.data()['salary'] as num?)?.toDouble()
                : 0) ??
            0;
      }
      out.add(BimonthlySummary(
        name: name,
        salary: salary,
        days: weighted,
        hoursPerWeek: hoursPerWeek,
      ));
    }
    return out;
  }

  /// Dispatcher para PDF según tipo de reporte
  /// Dispatcher PDF
  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      switch (_reportType) {
        case dfs.ReportType.weekly:
          await _exportPdfWeekly();
          break;
        case dfs.ReportType.monthly:
          await _exportPdfMonthly();
          break;
        case dfs.ReportType.bimonthly:
          await _exportPdfBimonthly();
          break;
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdfWeekly() async {
    // 1. Cargar el resumen semanal
    final List<WeeklySummary> summary = await _loadWeeklySummary();

    // 2. Formatear fechas y tipo
    final start = _selectedRange.start;
    final end = _selectedRange.end;
    final periodo =
        '${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';
    final tipo = _selectedFilter == ReportFilter.usuario
        ? 'USUARIOS'.tr()
        : 'EMPLEADOS'.tr();

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
              'REPORTE SEMANAL'.tr(),
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          // Información del rango y tipo
          // ...
          pw.Text('$tipoLabel: $tipo', style: pw.TextStyle(fontSize: 12)),
          pw.Text('$semanaLabel: $periodo', style: pw.TextStyle(fontSize: 12)),
// ...

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
              'Nombre'.tr(),
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
              'Comentarios'.tr()
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
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: pw.TextStyle(fontSize: 9),
            headerDecoration:
                pw.BoxDecoration(color: PdfColor.fromHex('#F2F2F2')),
          ),
          pw.SizedBox(height: 12),
          // Pie de página con total de registros
          pw.Text(
            '$trabajadoresLabel: ${summary.length}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    // 4. Guardar y compartir
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/reporte_semanal.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Reporte Semanal'.tr(),
    );
  }

  Future<void> _exportPdfMonthly() async {
    // 1. Cargar los datos mensuales
    final List<MonthlySummary> summary = await _loadMonthlySummary();

    // 2. Preparar texto de cabecera
    final start = _selectedRange.start;
    final localeTag = context.locale.toString();
    final mesAno = DateFormat.yMMMM(localeTag).format(start);
    final tipo = _selectedFilter == ReportFilter.usuario
        ? 'USUARIOS'.tr()
        : 'EMPLEADOS'.tr();

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
              'REPORTE MENSUAL'.tr(),
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          // Información de tipo y mes
          pw.Text('$tipoLabel: $tipo', style: pw.TextStyle(fontSize: 12)),
          pw.Text('$mesLabel: $mesAno', style: pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 8),
          // Nota de la regla de días
          pw.Text(
            'FULL DAY IF THEY WORK MORE THAN 5 HOURS. HALF DAY IF THEY WORK 5 HOURS OR LESS. (DIA COMPLETO SI TRABAJAN MAS DE 5 HORAS. MEDIO DIA SI TRABAJAN 5 HORAS O MENOS.)'
                .tr(),
            style:
                pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#555555')),
          ),
          pw.SizedBox(height: 16),
          // Tabla de horas por semana
          pw.Table.fromTextArray(
            headers: [
              'Nombre'.tr(),
              'Sem 1'.tr(),
              'Sem 2'.tr(),
              'Sem 3'.tr(),
              'Sem 4'.tr(),
              'Sem 5'.tr(),
              'Días Trab'.tr(),
              'Salario'.tr(),
              'Total Pagar'.tr()
            ],
            data: summary.map((m) {
              return [
                m.name,
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
          // Pie con total de trabajadores
          pw.Text(
            '$trabajadoresLabel: ${summary.length}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    // 4. Guardar y compartir
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/reporte_mensual.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Reporte Mensual'.tr(),
    );
  }

  Future<void> _exportPdfBimonthly() async {
    // 1. Cargar los datos bimestrales (8 semanas)
    final List<BimonthlySummary> summary = await _loadBimonthlySummary();

    // 2. Preparar texto de cabecera
    final start = _selectedRange.start;
    final end = _selectedRange.end;
    final periodo = '${DateFormat('dd/MM/yyyy').format(start)} - '
        '${DateFormat('dd/MM/yyyy').format(end)}';
    final tipo = _selectedFilter == ReportFilter.usuario
        ? 'USUARIOS'.tr()
        : 'EMPLEADOS'.tr();

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
              'REPORTE BIMESTRAL (8 SEMANAS)'.tr(),
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          // Información de tipo y periodo
          pw.Text('${'Tipo'.tr()}: $tipo', style: pw.TextStyle(fontSize: 12)),
          pw.Text('${'Periodo'.tr()}: $periodo',
              style: pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 8),
          // Nota de la regla de días
          pw.Text(
            'FULL DAY IF THEY WORK MORE THAN 5 HOURS. '
                    'HALF DAY IF THEY WORK 5 HOURS OR LESS. '
                    '(DÍA COMPLETO SI TRABAJAN MÁS DE 5 HORAS. MEDIO DÍA SI TRABAJAN 5 HORAS O MENOS.)'
                .tr(),
            style:
                pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#555555')),
          ),
          pw.SizedBox(height: 16),
          // Tabla de las 8 semanas
          pw.Table.fromTextArray(
            headers: [
              'Nombre'.tr(),
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
              // extraer las 8 semanas
              final row = <String>[
                b.name,
                for (var i = 1; i <= 8; i++)
                  b.hoursPerWeek[i]!.toStringAsFixed(1),
                b.days.toStringAsFixed(1),
                b.salary.toStringAsFixed(2),
                (b.salary * b.days).toStringAsFixed(2),
              ];
              return row;
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: pw.TextStyle(fontSize: 9),
            headerDecoration:
                pw.BoxDecoration(color: PdfColor.fromHex('#F2F2F2')),
          ),
          pw.SizedBox(height: 12),
          // Pie con total de trabajadores
          pw.Text(
            '${'Total trabajadores'.tr()}: ${summary.length}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    // 4. Guardar y compartir
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/reporte_bimestral.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'REPORTE BIMESTRAL (8 SEMANAS)'.tr(),
    );
  }

//
//
//

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      switch (_reportType) {
        case dfs.ReportType.weekly:
          await _exportExcelWeekly();
          break;
        case dfs.ReportType.monthly:
          await _exportExcelMonthly();
          break;
        case dfs.ReportType.bimonthly:
          await _exportExcelBimonthly();
          break;
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExcelWeekly() async {
    // 1. Cargar el resumen semanal
    final List<WeeklySummary> summary = await _loadWeeklySummary();

    // 2. Crear un nuevo workbook de Excel
    final excel = Excel.createExcel();
    final sheet = excel['Semanal'];

    // 3. Cabecera
    sheet.appendRow([
      'Nombre'.tr(),
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

    // 4. Filas por cada entrada en summary
    for (var w in summary) {
      sheet.appendRow([
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
      ]);
    }

    // 5. Guardar bytes y compartir
    final bytes = excel.encode()!;
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/reporte_semanal.xlsx';
    File(filePath).writeAsBytesSync(bytes);

    await Share.shareXFiles(
      [XFile(filePath, name: 'reporte_semanal.xlsx')],
      text: 'Reporte Semanal Excel'.tr(),
    );
  }

  Future<void> _exportExcelMonthly() async {
    // 1. Cargar el resumen mensual
    final List<MonthlySummary> summary = await _loadMonthlySummary();

    // 2. Crear un nuevo workbook de Excel
    final excel = Excel.createExcel();
    final sheet = excel['Mensual'];

    // 3. Cabecera de columnas
    sheet.appendRow([
      'Nombre'.tr(),
      'Sem 1'.tr(),
      'Sem 2'.tr(),
      'Sem 3'.tr(),
      'Sem 4'.tr(),
      'Sem 5'.tr(),
      'Días Trab'.tr(),
      'Salario'.tr(),
      'Total Pagar'.tr(),
    ]);

    // 4. Filas de datos
    for (var m in summary) {
      sheet.appendRow([
        m.name,
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

    // 5. Guardar bytes y compartir
    final bytes = excel.encode()!;
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/reporte_mensual.xlsx';
    File(filePath).writeAsBytesSync(bytes);

    await Share.shareXFiles(
      [XFile(filePath, name: 'reporte_mensual.xlsx')],
      text: 'Reporte Mensual Excel'.tr(),
    );
  }

  Future<void> _exportExcelBimonthly() async {
    // 1. Cargar el resumen bimestral (8 semanas)
    final List<BimonthlySummary> summary = await _loadBimonthlySummary();

    // 2. Crear un nuevo workbook de Excel
    final excel = Excel.createExcel();
    final sheet = excel['Bimestral'];

    // 3. Cabecera de columnas (Semanas 1–8)
    sheet.appendRow([
      'Nombre'.tr(),
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
      'Total a Pagar'.tr(),
    ]);

    // 4. Filas de datos
    for (var b in summary) {
      sheet.appendRow([
        b.name,
        for (var i = 1; i <= 8; i++) b.hoursPerWeek[i]!.toStringAsFixed(1),
        b.days.toStringAsFixed(1),
        b.salary.toStringAsFixed(2),
        (b.salary * b.days).toStringAsFixed(2),
      ]);
    }

    // 5. Guardar bytes y compartir
    final bytes = excel.encode()!;
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/reporte_bimestral.xlsx';
    File(filePath).writeAsBytesSync(bytes);

    await Share.shareXFiles(
      [XFile(filePath, name: 'reporte_bimestral.xlsx')],
      text: 'Reporte Bimestral Excel (8 semanas)'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _mainOrange,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            Text(
              'Reportes de Asistencia'.tr(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // ─── Tarjeta de filtros ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aquí solo onTypeChanged y onPeriodChanged
                    dfs.DateFilterSection(
                      onTypeChanged: (dfs.ReportType t) {
                        if (t == _reportType) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _reportType = t);
                          _loadGeneralData();
                        });
                      },
                      onPeriodChanged: (DateTimeRange r) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _selectedRange = r);
                          _loadGeneralData();
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Selector Usuario / Empleado
                    Row(
                      children: [
                        Text(
                          'Ver reporte de:'.tr(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<ReportFilter>(
                          value: _selectedFilter,
                          items: ReportFilter.values.map((f) {
                            final label = f == ReportFilter.usuario
                                ? 'Usuarios'.tr()
                                : 'Empleados'.tr();
                            return DropdownMenuItem(
                              value: f,
                              child: Text(label,
                                  style: GoogleFonts.poppins(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedFilter = v);
                            _loadGeneralData();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Botones Exportar
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (!_isExporting &&
                                    (_userSummary.isNotEmpty ||
                                        _employeeSummary.isNotEmpty))
                                ? _exportPdf
                                : null,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: Text('Exportar PDF'.tr(),
                                style:
                                    GoogleFonts.poppins(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _mainOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (!_isExporting &&
                                    (_userSummary.isNotEmpty ||
                                        _employeeSummary.isNotEmpty))
                                ? _exportExcel
                                : null,
                            icon: const Icon(Icons.table_chart),
                            label: Text('Exportar Excel'.tr(),
                                style:
                                    GoogleFonts.poppins(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _mainOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── Contadores + Tabla con loader ───
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Contadores
                        Row(
                          children: [
                            Expanded(
                              child: _buildCounterCard(
                                  label: 'Total Usuarios'.tr(),
                                  value: '$_totalUsuarios'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCounterCard(
                                label: 'Total Empleados'.tr(),
                                value:
                                    '${_totalEmpleados > 0 ? _totalEmpleados - 1 : 0}',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Tabla resumen
                        _buildSummaryTable(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // Loader mientras recarga datos
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white70,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),

                  // Overlay exportación
                  if (_isExporting)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
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

  /// Helper para los contadores de arriba
  Widget _buildCounterCard({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Helper para construir la tabla resumen
  Widget _buildSummaryTable() {
    final rows = (_selectedFilter == ReportFilter.usuario
            ? _userSummary
            : _employeeSummary)
        .map((e) => TableRow(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              children: [
                _cell(e['nombre']),
                _cell(e['promedio'].toStringAsFixed(1)),
                _cell(e['dias'].toStringAsFixed(1)),
                _cell('${e['horas'].toStringAsFixed(1)}h'),
              ],
            ))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedFilter == ReportFilter.usuario
                ? 'Resumen de Usuarios'.tr()
                : 'Resumen de Empleados'.tr(),
            style:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
            },
            children: [
              // Cabecera
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF2F2F2)),
                children: [
                  _cell('Nombre'.tr(), isHeader: true),
                  _cell('Promedio Diario'.tr(), isHeader: true),
                  _cell('Días Trabajados'.tr(), isHeader: true),
                  _cell('Total Horas'.tr(), isHeader: true),
                ],
              ),
              // Filas de datos
              ...rows,
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
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
