// ignore_for_file: unnecessary_import, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';

class UserRecordPage extends StatefulWidget {
  const UserRecordPage({Key? key}) : super(key: key);

  @override
  State<UserRecordPage> createState() => _UserRecordPageState();
}

class _UserRecordPageState extends State<UserRecordPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Main orange color used in the UI
  static const Color _mainOrange = Color(0xFFFF8902);

  /// Límite de documentos por “página”
  final int _limit = 8;

  /// Controlador para filtrar por nombre de empresa
  final TextEditingController _empresaController = TextEditingController();

  /// Fecha seleccionada para filtrar (solo registros de ese día)
  DateTime? _selectedDate;

  /// Lista local de registros ya descargados
  List<Map<String, dynamic>> _records = [];

  bool _loading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();

    // Cada vez que cambie el texto de empresa, recargamos automáticamente
    _empresaController.addListener(() {
      _selectedDate = null; // resetear fecha al cambiar empresa (opcional)
      _fetchRecords();
    });

    _fetchRecords();
  }

  @override
  void dispose() {
    _empresaController.dispose();
    super.dispose();
  }

  /// Obtiene los registros cerrados del usuario, 8 por página
  Future<void> _fetchRecords({bool loadMore = false}) async {
    if (!_hasMore && loadMore) return;
    setState(() => _loading = true);

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    Query query = _firestore
        .collection('registros')
        .where('usuario_id', isEqualTo: userId)
        .where('estado', isEqualTo: 'cerrado')
        .orderBy('fecha_entrada', descending: true)
        .orderBy('fecha_salida', descending: true);

    // Filtrar por nombre de empresa si existe texto
    final empresaText = _empresaController.text.trim();
    if (empresaText.isNotEmpty) {
      query = query.where('empresa', isEqualTo: empresaText);
    }

    // Filtrar por fecha seleccionada (un solo día)
    if (_selectedDate != null) {
      final start = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );
      final end = start.add(const Duration(days: 1));
      query = query
          .where('fecha_entrada', isGreaterThanOrEqualTo: start)
          .where('fecha_entrada', isLessThan: end);
    }

    // Si estamos cargando más páginas, avanzamos el cursor
    if (loadMore && _lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    // Tomar sólo _limit documentos (8)
    final snapshot = await query.limit(_limit).get();
    final docs = snapshot.docs;

    // Convertir cada documento en un mapa, agregando su ID
    final nuevos = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();

    setState(() {
      if (loadMore) {
        _records.addAll(nuevos);
      } else {
        _records = nuevos;
      }
      _lastDocument = docs.isNotEmpty ? docs.last : null;
      // Si Firestore devolvió exactamente 8, puede haber más
      _hasMore = docs.length == _limit;
      _loading = false;
    });
  }

  /// Alterna la expansión de detalles de un registro
  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  /// Muestra una imagen en fullscreen al tocar el thumbnail
  void _showImageFullscreen(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  /// Construye la lista de widgets agrupada por mes
  List<Widget> _buildGroupedRecords() {
    List<Widget> lista = [];
    String? currentMonth;

    for (var record in _records) {
      // Extraer fecha de entrada para determinar mes
      final fechaEntrada = (record['fecha_entrada'] as Timestamp).toDate();
      // Formatear “Abril 2025”
      String monthYear = DateFormat('LLLL yyyy', context.locale.toString())
          .format(fechaEntrada);
      // Capitalizar en español
      if (context.locale.languageCode == 'es') {
        monthYear = monthYear[0].toUpperCase() + monthYear.substring(1);
      }

      // Si cambió el mes, insertamos header
      if (currentMonth == null || currentMonth != monthYear) {
        currentMonth = monthYear;
        lista.add(
          // Header color naranja
          Container(
            width: double.infinity,
            color: _mainOrange,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              monthYear,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }

      // Luego agregamos la card del registro
      lista.add(_buildRecordCard(record));
    }

    // Si no hay registros y no está cargando, mostramos mensaje
    if (!_loading && _records.isEmpty) {
      lista.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'no_records'.tr(),
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
      );
    }

    return lista;
  }

  /// Construye una “card” para cada registro, con resumen y detalle expandible
  Widget _buildRecordCard(Map<String, dynamic> record) {
    final id = record['id'] as String;
    final expanded = _expandedIds.contains(id);

    // -------------------- Extraer datos --------------------
    // Fechas y horas
    final entradaTs = record['fecha_entrada'] as Timestamp;
    final salidaTs = record['fecha_salida'] as Timestamp;
    final entrada = entradaTs.toDate();
    final salida = salidaTs.toDate();
    final duracion = salida.difference(entrada);

    final fechaStr =
        DateFormat('d MMMM, yyyy', context.locale.toString()).format(entrada);
    final horaStr =
        '${DateFormat('HH:mm').format(entrada)} - ${DateFormat('HH:mm').format(salida)}';
    final durStr =
        '${duracion.inHours}h ${(duracion.inMinutes % 60).toString().padLeft(2, '0')}m';

    // Valores de resumen
    final empresa = record['empresa'] as String? ?? '--';

    // Otros campos del documento
    final supervisor = record['supervisor'] as String? ?? '--';
    // ignore: unused_local_variable
    final ubicacionEntrada = record['ubicacion_entrada_texto'] as String? ?? '';
    final ubicacionSalida = record['ubicacion_salida_texto'] as String? ?? '';
    final comentarios = record['comentarios'] as String? ?? '';
    final comentariosSalida = record['comentarios_salida'] as String? ?? '';
    final comentariosFotoSalida =
        record['comentario_salida_imagen_url'] as String? ?? '';
    final comentariosFoto = record['comentario_imagen_url'] as String? ?? '';
    final companerosList = (record['companeros'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final flechasList = (record['flechas'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final timesheetUrl = record['imagen_timesheet_url'] as String? ?? '';
    final salidaUrl = record['imagen_salida_url'] as String? ?? '';

    // -------------------- Construir la tarjeta --------------------
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
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1) RESUMEN COMPACTO: Fecha (izq) y Duración (der)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fechaStr,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    durStr,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // 2) RESUMEN COMPACTO: Horario - Empresa
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    horaStr,
                    style: GoogleFonts.poppins(
                        color: Colors.grey[700], fontSize: 13),
                  ),
                  Flexible(
                    child: Text(
                      empresa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // 3) Botón “Ver detalles” / “Ocultar detalles”
              GestureDetector(
                onTap: () => _toggleExpanded(id),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    expanded
                        ? 'Ocultar detalles ▲'.tr()
                        : 'Ver detalles ▼'.tr(),
                    style:
                        GoogleFonts.poppins(color: _mainOrange, fontSize: 13),
                  ),
                ),
              ),

              // 4) DETALLES EXPANDIBLES
              if (expanded) ...[
                const SizedBox(height: 12),

                // 4.a) IMAGEN TIMESHEET (SI EXISTE)
                if (timesheetUrl.isNotEmpty) ...[
                  Text(
                    'Imagen Time sheet:'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
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
                  const SizedBox(height: 12),
                ],

                // 4.b) OBRA Y SUPERVISOR

                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Supervisor:'.tr(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        supervisor,
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Text(
                      'flechas:'.tr(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        flechasList.join(', '),
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 4.c) LISTA DE COMPAÑEROS (SI HAY)
                if (companerosList.isNotEmpty) ...[
                  Text(
                    'Compañeros:'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: companerosList.map((c) {
                        return Text(
                          '- $c',
                          style: GoogleFonts.poppins(fontSize: 13),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 4.d) LISTA DE FLECHAS (SI HAY)

                // 4.e) COMENTARIOS ENTRADA (SI HAY)
                if (comentarios.isNotEmpty) ...[
                  Text(
                    'Comentarios entrada:'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comentarios,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 12),
                ],

                // FOTO COMENTARIO ENTRADA (si existe)

                if (comentariosFoto.isNotEmpty) ...[
                  Text(
                    'Foto comentario entrada:'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showImageFullscreen(comentariosFoto),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        comentariosFoto,
                        height: 200,
                        width: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 4.f) COMENTARIOS SALIDA (SI HAY)
                if (comentariosSalida.isNotEmpty) ...[
                  Text(
                    'Comentarios salida:'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comentariosSalida,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 12),
                ],

                // FOTO COMENTARIO SALIDA (si existe)
                if (comentariosFotoSalida.isNotEmpty) ...[
                  Text(
                    'Foto comentarios salida:'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showImageFullscreen(comentariosFotoSalida),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        comentariosFotoSalida,
                        height: 200,
                        width: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 4.h) UBICACIÓN DE SALIDA
                if (ubicacionSalida.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.pin_drop, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ' $ubicacionSalida',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 4.j) FOTO DE SALIDA en grande (si aún no la pusimos como thumbnail)
                if (salidaUrl.isNotEmpty) ...[
                  Text(
                    'Foto salida (ampliada):'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showImageFullscreen(salidaUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        salidaUrl,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Encabezado naranja extendido hasta el top (status bar)
          Container(
            width: double.infinity,
            color: _mainOrange,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 16,
              16,
              16,
            ),
            child: Text(
              'Mi Historial de Asistencia'.tr(),
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ),

          // Resto del contenido con SafeArea, pero sin inset en top
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // ======= Filtros =======
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _empresaController,
                            decoration: InputDecoration(
                              hintText: 'Buscar por empresa'.tr(),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon:
                                  const Icon(Icons.search, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                              _fetchRecords();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.today, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ======= Listado deslizable de registros =======
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            children: [
                              ..._buildGroupedRecords(),
                              if (_hasMore && !_loading)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: TextButton(
                                      onPressed: () =>
                                          _fetchRecords(loadMore: true),
                                      child: Text(
                                        'ver_more'.tr(),
                                        style: GoogleFonts.poppins(
                                            color: _mainOrange),
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
          ),
        ],
      ),
    );
  }
}
