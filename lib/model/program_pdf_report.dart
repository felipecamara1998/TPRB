import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Gera o PDF do relatório do programa (clean, sem fundos, com header-card).
Future<Uint8List> buildProgramReportPdf({
  required Map<String, dynamic> program,
  required Map<String, dynamic> statusByTaskId,
  String traineeName = '',
  String supervisorName = '',
  /// Passe o status direto do Firestore (users/{uid}/programs/{pid}.status) se quiser
  /// sobrepor o status derivado pelo progresso.
  String? programStatus,
  /// Caso queira forçar um título diferente do que veio em `program['title']`
  String? programTitleOverride,
  DateTime? generatedAt,
}) async {
  // Paleta e estilos
  const primary = PdfColor.fromInt(0xFF365AA9);
  const border  = PdfColor.fromInt(0xFFE2E8F0);
  const stripBg = PdfColor.fromInt(0xFFF2F5F9);
  const success = PdfColor.fromInt(0xFF10B981);
  const warn    = PdfColor.fromInt(0xFFF59E0B);
  const danger  = PdfColor.fromInt(0xFFEF4444);

  final hTitle = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
  final small  = const pw.TextStyle(fontSize: 9, color: PdfColors.grey700);

  // Datas
  final now   = generatedAt ?? DateTime.now();
  final dfDay = DateFormat('dd MMM yyyy');
  final dfFull= DateFormat('dd MMM yyyy HH:mm');

  // Programa
  final programTitle = _safeString(programTitleOverride ?? program['title']);
  final startDate    = _safeDateTime(program['startDate']);
  final dueDate      = _safeDateTime(program['dueDate']);
  final chapters     = _safeList(program['chapters']);

  // Totais / Progresso
  int totalRequired = 0, totalApproved = 0, totalTasks = 0, totalChapters = chapters.length;
  for (final ch in chapters) {
    final tasks = _safeList(ch['tasks']);
    totalTasks += tasks.length;
    for (final t in tasks) {
      final id   = _safeString(t['id']);
      final qty  = _safeInt(t['qty'], 0);
      final s    = statusByTaskId[id] ?? {};
      final req  = _safeInt(s['requiredQty'], qty);
      final appr = _safeInt(s['approvedCount'], 0);
      totalRequired += req;
      totalApproved += appr;
    }
  }
  final completionRatio = totalRequired == 0 ? 0.0 : totalApproved / totalRequired;
  final completionPct   = (completionRatio * 100).toStringAsFixed(0);

  // Status do programa (derivado vs fornecido)
  final derivedStatus = _deriveProgramStatus(
    now: now,
    dueDate: dueDate,
    totalRequired: totalRequired,
    totalApproved: totalApproved,
  );
  final statusLabel = _normalizeStatus(programStatus) ?? derivedStatus;
  final statusColor = {
    'Completed': success,
    'In progress': primary,
    'Pending': warn,
    'Overdue': danger,
  }[statusLabel] ?? primary;

  // Documento
  final doc = pw.Document(
    title: 'Program Report',
    author: traineeName.isEmpty ? 'TPRB' : traineeName,
    subject: programTitle,
  );

  doc.addPage(
    pw.MultiPage(
      // Fundo BRANCO e sem foreground
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
        buildBackground: (_) => pw.Container(color: PdfColors.white),
        buildForeground: (_) => pw.SizedBox(),
      ),

      // HEADER (na faixa reservada da página) – não é coberto por nada
      header: (ctx) => ctx.pageNumber == 1
          ? _headerCard(
        primary: primary,
        border: border,
        stripBg: stripBg,
        reportTitle: 'Program Report',
        programTitle: programTitle,
        traineeName: traineeName,
        statusLabel: statusLabel,
        statusColor: statusColor,
        startLabel: startDate != null ? dfDay.format(startDate) : '-',
        dueLabel:   dueDate   != null ? dfDay.format(dueDate)   : '-',
        generatedLabel: dfFull.format(now),
      )
          : pw.SizedBox(height: 0),

      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Generated: ${dfFull.format(now)}   •   Page ${ctx.pageNumber}/${ctx.pagesCount}',
          style: small,
        ),
      ),

      // CONTEÚDO
      build: (context) => [
        // (Opcional) título textual – pode remover se quiser apenas o card no header
        pw.Text('Program Report', style: hTitle),
        pw.SizedBox(height: 12),

        // ==== OVERVIEW ====
        _card(
          border: border,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionHeader('Overview', stripBg, primary),
              pw.SizedBox(height: 10),
              _statRow(
                primary: primary,
                items: [
                  _Stat('Chapters', '$totalChapters'),
                  _Stat('Tasks',    '$totalTasks'),
                  _Stat('Completion', '$completionPct%'),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 16),

        // ==== CAPÍTULOS ====
        for (final ch in chapters) ...[
          _card(
            border: border,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionHeader(_safeString(ch['title']), stripBg, primary),
                pw.SizedBox(height: 8),
                _chapterTable(ch, statusByTaskId, border),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],

        pw.SizedBox(height: 18),

        // ==== ASSINATURAS ====
        _card(
          border: border,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 12),
            child: pw.Row(
              children: [
                pw.Expanded(child: _signatureBlock('Trainee', traineeName)),
                pw.SizedBox(width: 24),
                pw.Expanded(child: _signatureBlock('Supervisor', supervisorName)),
                pw.SizedBox(width: 24),
                pw.Container(
                  width: 130,
                  child: pw.Column(
                    children: [
                      pw.SizedBox(height: 48),
                      pw.Container(height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 6),
                      pw.Text('Date', style: const pw.TextStyle(fontSize: 10)),
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

  return doc.save();
}

// ========================== HEADER CARD =============================

pw.Widget _headerCard({
  required PdfColor primary,
  required PdfColor border,
  required PdfColor stripBg,
  required String reportTitle,
  required String programTitle,
  required String traineeName,
  required String statusLabel,
  required PdfColor statusColor,
  required String startLabel,
  required String dueLabel,
  required String generatedLabel,
}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: border, width: 0.7),
    ),
    padding: const pw.EdgeInsets.all(12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader(reportTitle, stripBg, primary),
        pw.SizedBox(height: 10),

        // Linha: Program Title + Status (pill)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Text(
                programTitle.isEmpty ? '-' : programTitle,
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
              ),
            ),
            _statusPill(statusLabel, statusColor),
          ],
        ),
        pw.SizedBox(height: 8),

        // Linha: Trainee
        pw.Row(
          children: [
            pw.Text('Trainee: ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(
              traineeName.isEmpty ? '-' : traineeName,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primary),
            ),
          ],
        ),
        pw.SizedBox(height: 8),

        // Chips de datas
        pw.Wrap(
          spacing: 10, runSpacing: 8,
          children: [
            _chip('Start', startLabel, primary),
            _chip('Due',   dueLabel,   primary),
            _chip('Generated', generatedLabel, primary),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _statusPill(String text, PdfColor color) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(999),
      border: pw.Border.all(color: color, width: 0.8),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
  );
}

// ============================ UI HELPERS ============================

pw.Widget _card({required pw.Widget child, required PdfColor border}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.7),
    ),
    padding: const pw.EdgeInsets.all(12),
    child: child,
  );
}

pw.Widget _sectionHeader(String title, PdfColor bg, PdfColor fg) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: bg,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 12, color: fg, fontWeight: pw.FontWeight.bold)),
  );
}

pw.Widget _chip(String label, String value, PdfColor primary) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(999),
      border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.7),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label: ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primary)),
      ],
    ),
  );
}

class _Stat { final String label; final String value; _Stat(this.label, this.value); }

pw.Widget _statRow({required PdfColor primary, required List<_Stat> items}) {
  return pw.Row(
    children: [
      for (int i = 0; i < items.length; i++) ...[
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.7),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(items[i].label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text(items[i].value,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primary)),
              ],
            ),
          ),
        ),
        if (i != items.length - 1) pw.SizedBox(width: 10),
      ]
    ],
  );
}

// ======================= TABELA DE CAPÍTULO ========================

pw.Widget _chapterTable(dynamic ch, Map<String, dynamic> statusByTaskId, PdfColor border) {
  final tasks   = _safeList(ch['tasks']);
  final dfDay   = DateFormat('dd/MM/yy');
  final headerBg= PdfColor.fromInt(0xFFF1F5F9);

  return pw.Table(
    border: pw.TableBorder.all(color: border, width: 0.7),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    columnWidths: const {
      0: pw.FlexColumnWidth(3.8),
      1: pw.FlexColumnWidth(1.0),
      2: pw.FlexColumnWidth(1.0),
      3: pw.FlexColumnWidth(1.5),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: headerBg),
        children: [
          _th('Task'),
          _th('Req.'),
          _th('Appr.'),
          _th('Last Update'),
        ],
      ),
      for (final t in tasks)
            () {
          final id    = _safeString(t['id']);
          final title = _safeString(t['title']);
          final qty   = _safeInt(t['qty'], 0);
          final s     = statusByTaskId[id] ?? {};
          final req   = _safeInt(s['requiredQty'], qty);
          final appr  = _safeInt(s['approvedCount'], 0);
          final dt    = _safeDateTime(s['approvedAt']) ?? _safeDateTime(s['declaredAt']);

          return pw.TableRow(
            children: [
              _td(title),
              _td('$req', align: pw.TextAlign.center),
              _td('$appr', align: pw.TextAlign.center),
              _td(dt != null ? dfDay.format(dt) : '-', align: pw.TextAlign.center),
            ],
          );
        }(),
    ],
  );
}

pw.Widget _th(String text) => pw.Padding(
  padding: const pw.EdgeInsets.all(6),
  child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
);

pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9), textAlign: align),
    );

// ============================ ASSINATURA ===========================

pw.Widget _signatureBlock(String label, String name) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: 48),
      pw.Container(height: 1, color: PdfColors.black),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label Signature', style: const pw.TextStyle(fontSize: 10)),
          if (name.trim().isNotEmpty)
            pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    ],
  );
}

// ============================= HELPERS =============================

String _deriveProgramStatus({
  required DateTime now,
  required DateTime? dueDate,
  required int totalRequired,
  required int totalApproved,
}) {
  if (totalRequired > 0 && totalApproved >= totalRequired) return 'Completed';
  if (dueDate != null && now.isAfter(dueDate)) return 'Overdue';
  if (totalApproved > 0) return 'In progress';
  return 'Pending';
}

/// Converte valores comuns de status do Firestore para os rótulos do PDF
String? _normalizeStatus(String? raw) {
  if (raw == null) return null;
  final v = raw.toLowerCase().trim();
  if (v == 'approved' || v == 'complete' || v == 'completed') return 'Completed';
  if (v == 'pending') return 'Pending';
  if (v == 'overdue' || v == 'late') return 'Overdue';
  if (v == 'in_progress' || v == 'progress' || v == 'partial' || v == 'declared') return 'In progress';
  return raw; // fallback
}

List _safeList(dynamic v) => v is List ? v : const [];
String _safeString(dynamic v, [String def = '']) => v == null ? def : v.toString();
int _safeInt(dynamic v, [int def = 0]) => v is int ? v : int.tryParse(v.toString()) ?? def;
DateTime? _safeDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  // Firestore Timestamp compat.
  try { final toDate = (v as dynamic).toDate; if (toDate is Function) return toDate() as DateTime?; } catch (_) {}
  return null;
}
