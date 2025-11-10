import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';

import '../model/program_pdf_report.dart';

class ProgramPdfExportButton extends StatefulWidget {
  /// Pode ser ProgramModel ou Map
  final dynamic program;

  /// Pode ser Map<String, TaskStatus> ou Map<String, dynamic>
  final Map<String, dynamic> statusByTaskId;

  final String? traineeName;

  const ProgramPdfExportButton({
    super.key,
    required this.program,
    required this.statusByTaskId,
    this.traineeName,
  });

  @override
  State<ProgramPdfExportButton> createState() =>
      _ProgramPdfExportButtonState();
}

class _ProgramPdfExportButtonState extends State<ProgramPdfExportButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: _busy
          ? const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : const Icon(Icons.picture_as_pdf),
      label: const Text('Export PDF'),
      onPressed: _busy ? null : () => _onExport(context),
    );
  }

  Future<void> _onExport(BuildContext context) async {
    setState(() => _busy = true);
    try {
      // 1. trainee
      final trainee = await _resolveTraineeName(widget.traineeName);

      // 2. normaliza programa (ProgramModel -> Map)
      final programMap = _normalizeProgram(widget.program);

      // 3. busca status completo no Firestore (usa o que já veio da tela como fallback)
      final statusMap = await _fetchFullStatusMapFromFirestore(
        programMap: programMap,
        fallback: widget.statusByTaskId,
      );

      // 4. gera PDF
      final bytes = await buildProgramReportPdf(
        program: programMap,
        statusByTaskId: statusMap,
        traineeName: trainee,
      );

      final programTitle =
      (programMap['title'] ?? 'Program').toString().replaceAll('/', '-');

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Program-$programTitle.pdf',
      );
    } catch (e, st) {
      debugPrint('Erro ao exportar PDF: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível gerar o PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _resolveTraineeName(String? provided) async {
    final p = (provided ?? '').trim();
    if (p.isNotEmpty) return p;

    final user = FirebaseAuth.instance.currentUser;
    String? candidate = user?.displayName ?? user?.email;

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
              candidate;
        }
      }
    } catch (_) {}

    return candidate ?? '';
  }

  /// Busca no Firestore as declarações daquele programa e monta
  /// um mapa por taskId com declaredAt/approvedAt/lastApproverName/remark.
  ///
  /// Se não achar no Firestore, usa o que veio em [fallback].
  Future<Map<String, dynamic>> _fetchFullStatusMapFromFirestore({
    required Map<String, dynamic> programMap,
    required Map<String, dynamic> fallback,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _normalizeStatusMap(fallback);
    }

    final programId = programMap['programId']?.toString();
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('task_declarations');

    QuerySnapshot<Map<String, dynamic>> snap;
    if (programId != null && programId.isNotEmpty) {
      snap = await col.where('programId', isEqualTo: programId).get();
    } else {
      snap = await col.get();
    }

    final result = <String, dynamic>{};

    for (final doc in snap.docs) {
      final d = doc.data();

      final taskId =
      (d['taskId'] ?? d['task_id'] ?? d['task'] ?? doc.id).toString();

      result[taskId] = {
        'declaredAt': d['declaredAt'],
        'approvedAt': d['approvedAt'],
        'lastApproverName': d['lastApproverName'],
        'approvedCount': d['approvedCount'],
        'pendingCount': d['pendingCount'],
        // 👇 pega o mesmo nome que está no Firestore
        'reviewRemark': d['reviewRemark'],
      };
    }

    // mistura com o fallback
    final normalizedFallback = _normalizeStatusMap(fallback);
    normalizedFallback.forEach((taskId, value) {
      if (!result.containsKey(taskId)) {
        result[taskId] = value;
      } else {
        // se o Firestore não tinha remark mas o fallback tinha, aproveita
        final existing = result[taskId] as Map<String, dynamic>;
        final fb = value as Map<String, dynamic>;
        if ((existing['reviewRemark'] == null || existing['reviewRemark'] == '') &&
            (fb['reviewRemark'] != null && fb['reviewRemark'] != '')) {
          existing['reviewRemark'] = fb['reviewRemark'];
        }
      }
    });

    return result;
  }

  /// Converte ProgramModel -> Map<String, dynamic>
  Map<String, dynamic> _normalizeProgram(dynamic program) {
    if (program is Map<String, dynamic>) return program;

    try {
      final chapters = (program.chapters as List).map((chapter) {
        final tasks = (chapter.tasks as List).map((task) {
          return {
            'id': task.id,
            'title': task.title,
            'qty': task.qty,
          };
        }).toList();

        return {
          'id': chapter.id,
          'title': chapter.title,
          'tasks': tasks,
        };
      }).toList();

      return {
        'programId': program.programId,
        'title': program.title,
        'chapters': chapters,
      };
    } catch (e) {
      throw Exception(
          'ProgramPdfExportButton: não consegui converter ${program.runtimeType} para Map. Detalhe: $e');
    }
  }

  /// Converte Map<String, TaskStatus> -> Map<String, Map<String, dynamic>>
  /// e agora leva junto o reviewRemark.
  Map<String, dynamic> _normalizeStatusMap(Map<String, dynamic> original) {
    final result = <String, dynamic>{};

    original.forEach((taskId, value) {
      if (value == null) {
        result[taskId] = {};
        return;
      }

      if (value is Map<String, dynamic>) {
        // garante que a chave exista mesmo assim
        result[taskId] = {
          ...value,
          if (!value.containsKey('reviewRemark')) 'reviewRemark': value['reviewRemark'],
        };
        return;
      }

      // tentar tratar como TaskStatus (o que você usa na ProgramTasksPage)
      try {
        final map = <String, dynamic>{};
        // ignore: avoid_dynamic_calls
        map['status'] = value.status;
        // ignore: avoid_dynamic_calls
        map['requiredQty'] = value.requiredQty;
        // ignore: avoid_dynamic_calls
        map['approvedCount'] = value.approvedCount;
        // ignore: avoid_dynamic_calls
        map['pendingCount'] = value.pendingCount;
        // ignore: avoid_dynamic_calls
        map['approvedAt'] = value.approvedAt;
        // ignore: avoid_dynamic_calls
        map['declaredAt'] = value.declaredAt;
        // ignore: avoid_dynamic_calls
        map['lastApproverName'] =
            value.lastApproverName ??
                value.approvedBy ??
                value.declaredBy ??
                value.lastBy;
        // 👇 este é o campo novo vindo do objeto
        // ignore: avoid_dynamic_calls
        map['reviewRemark'] = value.reviewRemark;
        result[taskId] = map;
      } catch (_) {
        result[taskId] = {
          'status': value.toString(),
        };
      }
    });

    return result;
  }
}
