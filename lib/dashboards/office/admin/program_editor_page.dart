import 'dart:async'; // ✅ TimeoutException / timeout()
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tprb/dashboards/office/admin/chapter_tasks_page.dart';

// >>> Excel import service
import 'package:tprb/features/services/excel_program_import_service.dart';

/// Firestore collection root
const _kProgramsCol = 'training_programs';

class ProgramEditorPage extends StatefulWidget {
  final String? programId;
  const ProgramEditorPage({super.key, required this.programId});

  @override
  State<ProgramEditorPage> createState() => _ProgramEditorPageState();
}

class _ProgramEditorPageState extends State<ProgramEditorPage> {
  final _formKey = GlobalKey<FormState>();

  // metadata
  final _idCtrl = TextEditingController(); // allow custom ID when creating
  final _titleCtrl = TextEditingController(); // <- shown as "version" in admin
  final _descCtrl = TextEditingController();
  final _createdByCtrl = TextEditingController();
  final _dateCreatedCtrl = TextEditingController();
  final _dateImplCtrl = TextEditingController();
  final _statusCtrl = TextEditingController(text: 'draft');

  String? _cachedProgramId;
  bool _programIdLocked = false;

  // Enable Excel import only after the program has been saved/created.
  bool _programCreated = false;
  bool _importing = false;

  DocumentReference<Map<String, dynamic>> get _doc {
    final col = FirebaseFirestore.instance.collection(_kProgramsCol);

    // 1) If editing, use provided id
    if (widget.programId != null && widget.programId!.isNotEmpty) {
      return col.doc(widget.programId);
    }

    // 2) If user typed an ID, use it
    final typed = _idCtrl.text.trim();
    if (typed.isNotEmpty) {
      _cachedProgramId = typed;
      return col.doc(typed);
    }

    // 3) Otherwise generate once and reuse
    _cachedProgramId ??= col.doc().id;
    if (_idCtrl.text.isEmpty) {
      _idCtrl.text = _cachedProgramId!;
    }
    return col.doc(_cachedProgramId);
  }

  @override
  void initState() {
    super.initState();
    if (widget.programId != null && widget.programId!.isNotEmpty) {
      _programCreated = true;
      _load();
    } else {
      debugPrint('ProgramId null');
    }
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection(_kProgramsCol)
        .doc(widget.programId)
        .get();
    debugPrint('Opening editor for programId=${widget.programId}');

    final data = snap.data() ?? {};
    _idCtrl.text = snap.id;
    _titleCtrl.text = (data['title'] ?? '').toString();
    _descCtrl.text = (data['description'] ?? '').toString();
    _createdByCtrl.text = (data['createdBy'] ?? '').toString();
    _dateCreatedCtrl.text = (data['dateCreated'] ?? '').toString();
    _dateImplCtrl.text = (data['dateOfImplementation'] ?? '').toString();
    _statusCtrl.text = (data['status'] ?? 'published').toString();

    _programCreated = true;
    setState(() {});
  }

  void _materializeAndLockProgramId() {
    // forces materialize _doc (auto id) and locks Program ID editing
    final _ = _doc;
    if (!_programIdLocked) {
      setState(() => _programIdLocked = true);
    }
  }

  Future<void> _saveProgram() async {
    if (!_formKey.currentState!.validate()) return;

    _materializeAndLockProgramId();

    final ref = _doc;
    final isNew = widget.programId == null;

    final payload = <String, dynamic>{
      'docID': _idCtrl.text.trim(),
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'createdBy': _createdByCtrl.text.trim(),
      'dateCreated': _dateCreatedCtrl.text.trim(),
      'dateOfImplementation': _dateImplCtrl.text.trim(),
      'status': _statusCtrl.text.trim().toLowerCase(), // 'published' | 'draft'
    };

    await ref.set(payload, SetOptions(merge: true));

    // ✅ from this point doc exists -> enable import
    _programCreated = true;

    if (isNew && _idCtrl.text.trim().isEmpty) {
      // nothing
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program saved')),
      );
      setState(() {});
    }
  }

  String _currentProgramId() => (widget.programId ?? _idCtrl.text.trim()).trim();

  // ✅ Updated: timeout + debugPrintStack + doc exists guard + always reset importing
  Future<void> _importExcel() async {
    if (_importing) return;

    if (!_programCreated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the program first to enable import.')),
      );
      return;
    }

    final programId = _currentProgramId();
    if (programId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the program first to enable import.')),
      );
      return;
    }

    setState(() => _importing = true);

    try {
      // 🔒 Extra guard: ensure doc exists
      final doc = await FirebaseFirestore.instance
          .collection(_kProgramsCol)
          .doc(programId)
          .get();

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save the program first to enable import.')),
        );
        return;
      }

      // ⏱️ Timeout to avoid staying stuck in "Importing..."
      final result = await const ExcelProgramImportService()
          .importExcelToProgram(context: context, programId: programId)
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.tasksImported} tasks into ${result.chaptersTouched} chapters (${result.sheetName})',
          ),
        ),
      );

      setState(() {});
    } on TimeoutException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import timed out. Try again (or a smaller file).'),
        ),
      );
    } catch (e, st) {
      debugPrint('IMPORT ERROR: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;

      if (ExcelProgramImportService.isSilentCancel(e)) {
        return; // user cancelled picker/sheet dialog
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );

      // Optional: make failure obvious
      // ignore: use_build_context_synchronously
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Import failed'),
          content: SingleChildScrollView(
            child: Text('$e\n\n(See console for stack trace)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // ----- Chapters helpers -----------------------------------------------------

  Stream<DocumentSnapshot<Map<String, dynamic>>> _programStream() {
    final id = widget.programId ?? _idCtrl.text.trim();
    if (id.isEmpty) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }
    return FirebaseFirestore.instance.collection(_kProgramsCol).doc(id).snapshots();
  }

  Future<void> _addChapter() async {
    final chapterNo = await _promptText(
      context,
      title: 'Add chapter',
      label: 'Chapter number (e.g. 1, 2, 3)',
    );
    if (chapterNo == null || chapterNo.trim().isEmpty) return;

    _materializeAndLockProgramId();

    await _doc.set({
      'chapters': {chapterNo.trim(): {}}
    }, SetOptions(merge: true));
  }

  Future<void> _deleteChapter(String chapterNo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete chapter $chapterNo'),
        content: const Text('All tasks inside will be removed. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    await _doc.update({'chapters.$chapterNo': FieldValue.delete()});
  }

  void _openChapterTasks(String chapterNo) {
    final id = widget.programId ?? _idCtrl.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the program first to edit chapters')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterTasksPage(programId: id, chapterNo: chapterNo),
      ),
    );
  }

  Future<void> _deleteProgram() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete program'),
        content: const Text(
          'This will permanently delete the program and all its chapters/tasks. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _doc.delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Program deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete program: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.programId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit program' : 'New program'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete program',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteProgram,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (!isEditing)
                  TextFormField(
                    controller: _idCtrl,
                    enabled: !_programIdLocked,
                    readOnly: _programIdLocked,
                    decoration: InputDecoration(
                      labelText: 'Program ID',
                      suffixIcon: Icon(_programIdLocked ? Icons.lock_outline : Icons.lock_open),
                    ),
                  ),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                TextFormField(
                  controller: _createdByCtrl,
                  decoration: const InputDecoration(labelText: 'Created by'),
                ),
                TextFormField(
                  controller: _dateCreatedCtrl,
                  decoration: const InputDecoration(labelText: 'Date created (dd/mm/yyyy)'),
                ),
                TextFormField(
                  controller: _dateImplCtrl,
                  decoration: const InputDecoration(labelText: 'Date of implementation (dd/mm/yyyy)'),
                ),
                TextFormField(
                  controller: _statusCtrl,
                  decoration: const InputDecoration(labelText: 'Status (published | draft)'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _saveProgram,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _addChapter,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Add chapter'),
                    ),
                    OutlinedButton.icon(
                      // ✅ inativo até o programa ser salvo/criado
                      onPressed: (_programCreated && !_importing) ? _importExcel : null,
                      icon: _importing
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.upload_file),
                      label: Text(_importing ? 'Importing...' : 'Import Excel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Chapters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _programStream(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Save the program to start adding chapters.'),
                );
              }
              final data = snap.data!.data() ?? {};
              final chapters = (data['chapters'] as Map?)?.cast<String, dynamic>() ?? {};
              if (chapters.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No chapters yet.'),
                );
              }

              final items = chapters.keys.toList()
                ..sort((a, b) {
                  final ai = int.tryParse(a) ?? 0;
                  final bi = int.tryParse(b) ?? 0;
                  return ai.compareTo(bi);
                });

              return Column(
                children: [
                  for (final ch in items)
                    Card(
                      child: ListTile(
                        title: Text('Chapter $ch'),
                        subtitle: Text('${_countTasks((chapters[ch] as Map?) ?? {})} tasks'),
                        onTap: () => _openChapterTasks(ch),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteChapter(ch),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  int _countTasks(Map chapterMap) {
    var count = 0;
    chapterMap.forEach((_, v) {
      if (v is Map && v.containsKey('task')) count++;
    });
    return count;
  }
}

/// Simple text prompt
Future<String?> _promptText(
    BuildContext context, {
      required String title,
      String? label,
      String? initial,
    }) async {
  final ctrl = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('OK')),
      ],
    ),
  );
}
