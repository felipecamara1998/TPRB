import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import 'excel_bytes_picker.dart'; // ✅ novo picker condicional (web/desktop)

const String kProgramsCollection = 'training_programs';

class ExcelImportResult {
  final String programId;
  final String sheetName;
  final int chaptersTouched;
  final int tasksImported;

  const ExcelImportResult({
    required this.programId,
    required this.sheetName,
    required this.chaptersTouched,
    required this.tasksImported,
  });
}

class ExcelProgramImportService {
  const ExcelProgramImportService();

  static bool isSilentCancel(Object e) => e is _SilentCancelException;

  Future<ExcelImportResult> importExcelToProgram({
    required BuildContext context,
    required String programId,
  }) async {
    final id = programId.trim();
    if (id.isEmpty) throw Exception('Save the program first to enable import.');

    final programRef =
    FirebaseFirestore.instance.collection(kProgramsCollection).doc(id);

    final programSnap = await programRef.get();
    if (!programSnap.exists) {
      throw Exception('Program not found. Save the program first.');
    }

    // ✅ Picker confiável (web via FileReader / desktop via file_picker bytes)
    final Uint8List? bytes = await pickExcelBytes();
    if (bytes == null) throw _SilentCancelException();

    // ✅ Sanity check: XLSX é um ZIP -> começa com "PK"
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw Exception('Selected file is not a valid .xlsx (ZIP header not found).');
    }

    // ✅ Decode Excel
    late final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception('Failed to decode Excel file. Details: $e');
    }

    final sheetNames = excel.tables.keys.toList();
    if (sheetNames.isEmpty) throw Exception('No sheets found in the Excel file.');

    final selectedSheetName = sheetNames.length == 1
        ? sheetNames.first
        : await _promptSheet(context, sheetNames);

    if (selectedSheetName == null) throw _SilentCancelException();

    final sheet = excel.tables[selectedSheetName];
    if (sheet == null) throw Exception('Selected sheet not found.');

    final chaptersByTitle = _parseTrainingSheet(sheet);
    if (chaptersByTitle.isEmpty) throw Exception('No valid tasks found in this sheet.');

    final stats = await _applyImportToFirestore(
      programId: id,
      chaptersByTitle: chaptersByTitle,
    );

    return ExcelImportResult(
      programId: id,
      sheetName: selectedSheetName,
      chaptersTouched: stats.chaptersTouched,
      tasksImported: stats.tasksImported,
    );
  }

  // ---------------- Excel parsing ----------------

  Map<String, List<Map<String, dynamic>>> _parseTrainingSheet(Sheet sheet) {
    if (sheet.maxRows < 2) return {};

    final headerRow = sheet.row(0);
    final headerIndex = <String, int>{};

    for (int i = 0; i < headerRow.length; i++) {
      final value = headerRow[i]?.value?.toString().trim().toLowerCase();
      if (value != null && value.isNotEmpty) headerIndex[value] = i;
    }

    int idxFunction = _findHeader(headerIndex, ['function']) ?? 0;
    int idxCode = _findHeader(headerIndex, ['code', 'task number', 'task']) ?? 1;
    int idxCompetence =
        _findHeader(headerIndex, ['competence area', 'competence']) ?? 2;
    int idxTaskPerformed =
        _findHeader(headerIndex, ['task to be performed']) ?? 3;
    int idxGuide =
        _findHeader(headerIndex, ['guide to assessor', 'guide to ass']) ?? 4;

    String lastFunction = '';
    String lastCompetence = '';

    final result = <String, List<Map<String, dynamic>>>{};

    for (int r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);

      final function = _cell(row, idxFunction);
      final code = _cell(row, idxCode);
      final competence = _cell(row, idxCompetence);
      final taskPerformed = _cell(row, idxTaskPerformed);
      final guide = _cell(row, idxGuide);

      if (function.isNotEmpty) lastFunction = function;
      if (competence.isNotEmpty) lastCompetence = competence;

      if (lastFunction.isEmpty || lastCompetence.isEmpty || code.isEmpty) continue;

      final chapterTitle = '$lastFunction - $lastCompetence';

      result.putIfAbsent(chapterTitle, () => []).add({
        'taskNumber': code,
        'taskText': taskPerformed,
        'taskToBePerformed': taskPerformed,
        'guideToAssessor': guide,
        'qty': 1,
      });
    }

    return result;
  }

  int? _findHeader(Map<String, int> headers, List<String> keys) {
    for (final k in keys) {
      if (headers.containsKey(k)) return headers[k];
    }
    return null;
  }

  String _cell(List<Data?> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    final v = row[idx]?.value;
    return v?.toString().trim() ?? '';
  }

  // ---------------- Firestore apply (seu modelo atual) ----------------

  Future<_ImportStats> _applyImportToFirestore({
    required String programId,
    required Map<String, List<Map<String, dynamic>>> chaptersByTitle,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection(kProgramsCollection)
        .doc(programId);

    return FirebaseFirestore.instance.runTransaction<_ImportStats>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>? ?? {};

      int chaptersTouched = 0;
      int tasksImported = 0;

      final updates = <String, dynamic>{};

      for (final entry in chaptersByTitle.entries) {
        final chapterTitle = entry.key;
        final tasks = entry.value;

        final chapter =
            (data[chapterTitle] as Map?)?.cast<String, dynamic>() ?? {};

        bool changed = false;

        for (final t in tasks) {
          final taskNumber = (t['taskNumber'] ?? '').toString().trim();
          if (taskNumber.isEmpty) continue;

          if (chapter.containsKey(taskNumber)) continue;

          chapter[taskNumber] = {
            'task': t['taskText'],
            'taskToBePerformed': t['taskToBePerformed'],
            'guideToAssessor': t['guideToAssessor'],
            'qty': t['qty'],
            'importedFromExcel': true,
            'createdAt': Timestamp.now(),
          };

          tasksImported++;
          changed = true;
        }

        if (changed) {
          updates[chapterTitle] = chapter;
          chaptersTouched++;
        }
      }

      if (updates.isNotEmpty) {
        tx.set(ref, updates, SetOptions(merge: true));
      }

      return _ImportStats(
        chaptersTouched: chaptersTouched,
        tasksImported: tasksImported,
      );
    });
  }

  // ---------------- UI sheet picker ----------------

  Future<String?> _promptSheet(BuildContext context, List<String> sheetNames) async {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select a sheet'),
        content: SizedBox(
          width: 420,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sheetNames.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(sheetNames[i]),
              onTap: () => Navigator.pop(context, sheetNames[i]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _ImportStats {
  final int chaptersTouched;
  final int tasksImported;

  const _ImportStats({
    required this.chaptersTouched,
    required this.tasksImported,
  });
}

class _SilentCancelException implements Exception {}
