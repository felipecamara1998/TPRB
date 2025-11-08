import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Gera o PDF do programa sem depender da ProgramTasksPage.
/// Ele próprio conta quantas tasks existem e quantas estão concluídas.
Future<Uint8List> buildProgramReportPdf({
  required Map<String, dynamic> program,
  required Map<String, dynamic> statusByTaskId,
  String traineeName = '',
}) async {
  // fontes com suporte a acentos
  final baseFont =
  pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans.ttf'));
  final boldFont =
  pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans.ttf'));

  final pdf = pw.Document();
  final dateFmt = DateFormat('dd MMM yyyy');

  // dados do programa
  final programTitle = _s(program['title']);
  final chapters = (program['chapters'] as List? ?? []).cast<Map>();

  // 1) total de tasks
  final totalTasks = _countTotalTasks(chapters);

  // 2) tasks concluídas usando a mesma regra da página:
  // status == "approved" OU approvedCount >= requiredQty
  final completedTasks = _countCompletedTasks(
    chapters: chapters,
    statusByTaskId: statusByTaskId,
  );

  // 3) percent
  final completionPercent =
  totalTasks == 0 ? 0 : ((completedTasks / totalTasks) * 100).round();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
      build: (context) {
        return [
          // cabeçalho
          pw.Text(
            programTitle,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (traineeName.trim().isNotEmpty)
            pw.Text(
              'Trainee: $traineeName',
              style: const pw.TextStyle(fontSize: 11),
            ),
          pw.Text(
            'Issued: ${dateFmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 16),

          // overview com progresso calculado aqui mesmo
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _overviewBox(title: 'Chapters', value: chapters.length.toString()),
                _overviewBox(title: 'Tasks', value: totalTasks.toString()),
                _overviewBox(
                  title: 'Completion',
                  // value: '$completedTasks / $totalTasks (${completionPercent}%)',
                  value:
                  '${completionPercent}%',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // capítulos e tabelas
          ...chapters.map((chapter) {
            final chapterTitle = _s(chapter['title']);
            final tasks = (chapter['tasks'] as List? ?? []).cast<Map>();

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    chapterTitle,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
                _tasksTable(
                  tasks: tasks,
                  statusByTaskId: statusByTaskId,
                  dateFmt: dateFmt,
                ),
                pw.SizedBox(height: 12),
              ],
            );
          }).toList(),

          // bloco de assinatura
          pw.SizedBox(height: 24),
          _signatureBlock(),
        ];
      },
    ),
  );

  return pdf.save();
}

// ───────────────────────────────── helpers principais ─────────────────────────────────

int _countTotalTasks(List<Map> chapters) {
  var total = 0;
  for (final ch in chapters) {
    total += ((ch['tasks'] as List?)?.length ?? 0);
  }
  return total;
}

/// conta quantas tasks estão concluídas:
/// - se status == 'approved'
/// - ou se approvedCount >= requiredQty
int _countCompletedTasks({
  required List<Map> chapters,
  required Map<String, dynamic> statusByTaskId,
}) {
  var completed = 0;

  for (final chapter in chapters) {
    final tasks = (chapter['tasks'] as List? ?? []).cast<Map>();
    for (final task in tasks) {
      final taskId = _s(task['id']);
      final rawStatus = statusByTaskId[taskId];
      final st = _coerceStatus(rawStatus);

      if (_isTaskDone(st)) {
        completed++;
      }
    }
  }

  return completed;
}

/// mesma regra da página
bool _isTaskDone(_PdfTaskStatus st) {
  // 1. status direto
  if ((st.status ?? '').toLowerCase() == 'approved') return true;

  // 2. contagem
  final rq = st.requiredQty ?? 1;
  final ac = st.approvedCount ?? 0;
  if (ac >= rq) return true;

  return false;
}

// ───────────────────────────────── layout helpers ─────────────────────────────────

pw.Widget _overviewBox({required String title, required String value}) {
  return pw.Container(
    width: 140,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: PdfColors.grey300, width: .5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _tasksTable({
  required List<Map> tasks,
  required Map<String, dynamic> statusByTaskId,
  required DateFormat dateFmt,
}) {
  final headers = ['Task', 'Declared at', 'Approved at'];

  final rows = tasks.map((task) {
    final taskId = _s(task['id']);
    final title = _s(task['title']);

    final rawStatus = statusByTaskId[taskId];
    final st = _coerceStatus(rawStatus);

    return [
      title,
      _fmtDate(st.declaredAt, dateFmt),
      _fmtDate(st.approvedAt, dateFmt),
    ];
  }).toList();

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
    headerStyle: pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellAlignment: pw.Alignment.centerLeft,
    columnWidths: {
      0: const pw.FlexColumnWidth(4),
      1: const pw.FlexColumnWidth(2),
      2: const pw.FlexColumnWidth(2),
    },
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
  );
}

pw.Widget _signatureBlock() {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      _signatureLine('Trainee'),
      _signatureLine('Supervisor'),
      _signatureLine('Master'),
    ],
  );
}

pw.Widget _signatureLine(String label) {
  return pw.Container(
    width: 140,
    child: pw.Column(
      children: [
        pw.SizedBox(height: 30),
        pw.Container(height: 0.6, color: PdfColors.grey600),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );
}

// ───────────────────────────────── status helpers ─────────────────────────────────

class _PdfTaskStatus {
  final DateTime? declaredAt;
  final DateTime? approvedAt;
  final String? status;
  final int? approvedCount;
  final int? requiredQty;

  const _PdfTaskStatus({
    this.declaredAt,
    this.approvedAt,
    this.status,
    this.approvedCount,
    this.requiredQty,
  });
}

_PdfTaskStatus _coerceStatus(dynamic raw) {
  if (raw == null) return const _PdfTaskStatus();

  // caso mais comum: o botão já mandou Map
  if (raw is Map) {
    return _PdfTaskStatus(
      declaredAt: _asDateTime(raw['declaredAt']),
      approvedAt: _asDateTime(raw['approvedAt']),
      status: raw['status']?.toString(),
      approvedCount: _asInt(raw['approvedCount']),
      requiredQty: _asInt(raw['requiredQty']),
    );
  }

  // fallback: objeto TaskStatus
  try {
    // ignore: avoid_dynamic_calls
    return _PdfTaskStatus(
      declaredAt: _asDateTime(raw.declaredAt),
      approvedAt: _asDateTime(raw.approvedAt),
      // ignore: avoid_dynamic_calls
      status: raw.status?.toString(),
      // ignore: avoid_dynamic_calls
      approvedCount: _asInt(raw.approvedCount),
      // ignore: avoid_dynamic_calls
      requiredQty: _asInt(raw.requiredQty),
    );
  } catch (_) {
    return const _PdfTaskStatus();
  }
}

DateTime? _asDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  // Firestore Timestamp tem toDate()
  try {
    // ignore: avoid_dynamic_calls
    if (v is dynamic && v.toDate != null) {
      return v.toDate() as DateTime;
    }
  } catch (_) {}
  return null;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

String _fmtDate(DateTime? dt, DateFormat fmt) {
  if (dt == null) return '-';
  return fmt.format(dt);
}

String _s(dynamic v) => v == null ? '' : v.toString();
