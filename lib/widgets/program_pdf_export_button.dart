// FILE: lib/widgets/program_pdf_export_button.dart
// Botão que BUSCA automaticamente o userName do Firestore (users/{uid})
// e gera/compartilha o PDF usando o builder do arquivo program_pdf_report.dart.
//
// Requisitos no pubspec.yaml (você provavelmente já tem):
//   firebase_auth: ^5.1.4
//   cloud_firestore: ^5.4.4
//   printing: ^5.12.0
//
// Ajuste o import abaixo para o caminho real do seu builder:
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';

import '../model/program_pdf_report.dart'; // <- ajuste se seu builder estiver em outro caminho

class ProgramPdfExportButton extends StatefulWidget {
  /// Program model-like (precisa ter: title, chapters[..].title/tasks[..].id/title/qty)
  final dynamic program;

  /// Map de status por taskId (TaskStatus-like):
  /// requiredQty / approvedCount / pendingCount / status / approvedAt / declaredAt / lastApproverName
  final Map<String, dynamic> statusByTaskId;

  /// Opcional. Se não for passado ou vier vazio, o botão busca em:
  /// users/{uid}.{userName|name|fullName|displayName} e cai para o email.
  final String? traineeName;

  const ProgramPdfExportButton({
    super.key,
    required this.program,
    required this.statusByTaskId,
    this.traineeName,
  });

  @override
  State<ProgramPdfExportButton> createState() => _ProgramPdfExportButtonState();
}

class _ProgramPdfExportButtonState extends State<ProgramPdfExportButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: _busy
          ? const SizedBox(
          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.picture_as_pdf),
      label: const Text('Exportar PDF'),
      onPressed: _busy ? null : _onExport,
    );
  }

  Future<void> _onExport() async {
    setState(() => _busy = true);
    try {
      final trainee = await _resolveTraineeName(widget.traineeName);
      final bytes = await buildProgramReportPdf(
        program: widget.program,
        statusByTaskId: widget.statusByTaskId,
        traineeName: trainee,
      );
      final programTitle = _safeString(_sel(widget.program, 'title')).replaceAll('/', '-');
      await Printing.sharePdf(bytes: bytes, filename: 'Program-$programTitle.pdf');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _resolveTraineeName(String? provided) async {
    // 1) Se veio preenchido, usa
    final p = (provided ?? '').trim();
    if (p.isNotEmpty) return p;

    // 2) Tenta FirebaseAuth
    final user = FirebaseAuth.instance.currentUser;
    String? candidate = user?.displayName;
    candidate ??= user?.email;

    // 3) Tenta Firestore users/{uid}
    try {
      if (user != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final m = snap.data();
        if (m != null) {
          candidate = (m['userName'] as String?) ??
              (m['name'] as String?) ??
              (m['fullName'] as String?) ??
              (m['displayName'] as String?) ??
              (m['firstName'] != null && m['lastName'] != null
                  ? '${m['firstName']} ${m['lastName']}'
                  : null) ??
              candidate; // mantém displayName/email como fallback final
        }
      }
    } catch (_) {
      // ignora erros silenciosamente e usa o melhor candidato
    }

    return candidate ?? '';
  }
}

/// Helpers mínimos (espelham os do builder para nome do arquivo)
dynamic _sel(dynamic o, String key) {
  if (o == null) return null;
  if (o is Map) return o[key];
  try {
    return (o as dynamic).toJson()[key];
  } catch (_) {
    return null;
  }
}

String _safeString(dynamic v, [String def = '']) =>
    v == null ? def : v.toString();
