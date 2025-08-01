// ignore_for_file: depend_on_referenced_packages, library_private_types_in_public_api

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum ReportType { weekly, monthly, bimonthly }

extension ReportTypeExtension on ReportType {
  String get label {
    switch (this) {
      case ReportType.weekly:
        return 'Weekly'.tr();
      case ReportType.monthly:
        return 'Monthly'.tr();
      case ReportType.bimonthly:
        return 'Bimonthly'.tr();
    }
  }
}

class DateFilterSection extends StatefulWidget {
  final ValueChanged<ReportType> onTypeChanged;
  final ValueChanged<DateTimeRange> onPeriodChanged;

  const DateFilterSection({
    Key? key,
    required this.onTypeChanged,
    required this.onPeriodChanged,
  }) : super(key: key);

  @override
  _DateFilterSectionState createState() => _DateFilterSectionState();
}

class _DateFilterSectionState extends State<DateFilterSection> {
  DateTime now = DateTime.now();
  int _selectedYear = DateTime.now().year;
  ReportType _selectedType = ReportType.monthly;
  int _selectedMonth = DateTime.now().month;

  List<DateTimeRange> _periodOptions = [];
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  // Colores y estilos
  final Color backgroundGrey = const Color(0xFFF5F5F5);
  final Color textGrey = const Color(0xFF424242);
  final Color borderColor = const Color(0xFFFFA726); // borde naranja

  @override
  void initState() {
    super.initState();
    _updateOptions();
  }

  void _updateOptions() {
    List<DateTimeRange> options = [];
    if (_selectedType == ReportType.weekly) {
      DateTime firstDay = DateTime(_selectedYear, 1, 1);
      DateTime weekStart =
          firstDay.subtract(Duration(days: firstDay.weekday - 1));
      while (weekStart.year <= _selectedYear) {
        DateTime weekEnd = weekStart.add(Duration(days: 6));
        options.add(DateTimeRange(start: weekStart, end: weekEnd));
        weekStart = weekStart.add(Duration(days: 7));
      }
      options = options.where((r) => r.start.month == _selectedMonth).toList();
    } else if (_selectedType == ReportType.monthly) {
      for (int m = 1; m <= 12; m++) {
        DateTime start = DateTime(_selectedYear, m, 1);
        DateTime end = DateTime(_selectedYear, m + 1, 0);
        options.add(DateTimeRange(start: start, end: end));
      }
    } else {
      for (int m = 1; m <= 12; m += 2) {
        DateTime start = DateTime(_selectedYear, m, 1);
        DateTime end = DateTime(_selectedYear, m + 2, 0);
        options.add(DateTimeRange(start: start, end: end));
      }
    }

    DateTime today = DateTime.now();
    DateTimeRange defaultRange = options.firstWhere(
      (r) => today.isAfter(r.start) && today.isBefore(r.end),
      orElse: () => options.first,
    );

    setState(() {
      _periodOptions = options;
      _selectedRange = defaultRange;
    });
    widget.onPeriodChanged(_selectedRange);
  }

  void _onYearChanged(int? year) {
    if (year == null) return;
    setState(() {
      _selectedYear = year;
      _selectedMonth = 1;
    });
    widget.onTypeChanged(_selectedType);
    _updateOptions();
  }

  void _onTypeChanged(ReportType? type) {
    if (type == null) return;
    setState(() => _selectedType = type);
    widget.onTypeChanged(type);
    _updateOptions();
  }

  void _onMonthChanged(int? month) {
    if (month == null) return;
    setState(() => _selectedMonth = month);
    _updateOptions();
  }

  void _onRangeChanged(DateTimeRange? range) {
    if (range == null) return;
    setState(() => _selectedRange = range);
    widget.onPeriodChanged(range);
  }

  String _label(DateTimeRange r) {
    final loc = Localizations.localeOf(context).toString();
    String start = DateFormat('dd MMM', loc).format(r.start);
    String endFmt = r.start.year == r.end.year && r.end.year == _selectedYear
        ? 'dd MMM'
        : 'dd MMM yyyy';
    String end = DateFormat(endFmt, loc).format(r.end);
    return '$start – $end';
  }

  @override
  Widget build(BuildContext context) {
    List<int> years = List.generate(5, (i) => now.year - i);
    List<int> months = List.generate(12, (i) => i + 1);

    return Padding(
      // SOLO padding vertical: el horizontal lo controla el padre
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asistencia'.tr(),
            style:
                GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // FILA AÑO + TIPO
          Row(children: [
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: backgroundGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedYear,
                    items: years
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text('$y',
                                  style: GoogleFonts.poppins(color: textGrey)),
                            ))
                        .toList(),
                    onChanged: _onYearChanged,
                    icon: Icon(Icons.keyboard_arrow_down, color: textGrey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: backgroundGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ReportType>(
                    isExpanded: true,
                    value: _selectedType,
                    items: ReportType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label,
                                  style: GoogleFonts.poppins(color: textGrey)),
                            ))
                        .toList(),
                    onChanged: _onTypeChanged,
                    icon: Icon(Icons.keyboard_arrow_down, color: textGrey),
                  ),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // SEMANAL
          if (_selectedType == ReportType.weekly) ...[
            Row(children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: backgroundGrey,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedMonth,
                      items: months
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  DateFormat(
                                          'MMMM',
                                          Localizations.localeOf(context)
                                              .toString())
                                      .format(DateTime(0, m)),
                                  style: GoogleFonts.poppins(color: textGrey),
                                ),
                              ))
                          .toList(),
                      onChanged: _onMonthChanged,
                      icon: Icon(Icons.keyboard_arrow_down, color: textGrey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: backgroundGrey,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTimeRange>(
                      isExpanded: true,
                      value: _selectedRange,
                      items: _periodOptions
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(_label(r),
                                    style:
                                        GoogleFonts.poppins(color: textGrey)),
                              ))
                          .toList(),
                      onChanged: _onRangeChanged,
                      icon: Icon(Icons.keyboard_arrow_down, color: textGrey),
                    ),
                  ),
                ),
              ),
            ]),
          ]
          // MENSUAL / BIMESTRAL
          else ...[
            Row(children: [
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: backgroundGrey,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTimeRange>(
                      isExpanded: true,
                      value: _selectedRange,
                      items: _periodOptions
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(_label(r),
                                    style:
                                        GoogleFonts.poppins(color: textGrey)),
                              ))
                          .toList(),
                      onChanged: _onRangeChanged,
                      icon: Icon(Icons.keyboard_arrow_down, color: textGrey),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
