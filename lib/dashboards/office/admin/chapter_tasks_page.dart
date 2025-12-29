import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChapterTasksPage extends StatelessWidget {
  final String programId;
  final String chapterNo;
  const ChapterTasksPage({
    super.key,
    required this.programId,
    required this.chapterNo,
  });

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('training_programs').doc(programId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chapter $chapterNo · Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditTask(context),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _doc.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final data = snap.data!.data() ?? {};
          final chapter =
              ((data['chapters'] as Map?)?[chapterNo] as Map?)?.cast<String, dynamic>() ?? {};

          if (chapter.isEmpty) {
            return const Center(child: Text('No tasks yet.'));
          }

          final keys = chapter.keys.toList()
            ..sort((a, b) {
              // keep numeric-like order (e.g., 1.1, 1.2, 1.10)
              int toSortable(String s) {
                final parts = s.split('.');
                final a0 = int.tryParse(parts.first.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                final b0 = (parts.length > 1)
                    ? int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0
                    : 0;
                return a0 * 10000 + b0;
              }

              final cmp = toSortable(a).compareTo(toSortable(b));
              return cmp != 0 ? cmp : a.compareTo(b);
            });

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemBuilder: (_, i) {
              final taskNo = keys[i];
              final map = (chapter[taskNo] as Map?) ?? {};
              final text = (map['task'] ?? '').toString();
              final qty = (map['qty'] ?? 1);

              final taskToBePerformed = (map['taskToBePerformed'] ?? '').toString().trim();
              final guideToAssessor = (map['guideToAssessor'] ?? '').toString().trim();

              return Card(
                child: ListTile(
                  title: Text('$taskNo  —  $text'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Times to perform: $qty'),
                      if (taskToBePerformed.isNotEmpty)
                        Text('Task to be performed: $taskToBePerformed'),
                      if (guideToAssessor.isNotEmpty)
                        Text('Guide to assessor: $guideToAssessor'),
                    ],
                  ),
                  onTap: () => _addOrEditTask(context, taskNo: taskNo, existing: map),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteTask(context, taskNo),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: keys.length,
          );
        },
      ),
    );
  }

  Future<void> _deleteTask(BuildContext context, String taskNo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete task $taskNo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _doc.update({'chapters.$chapterNo.$taskNo': FieldValue.delete()});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
  }

  Future<void> _addOrEditTask(
      BuildContext context, {
        String? taskNo,
        Map? existing,
      }) async {
    final noCtrl = TextEditingController(text: taskNo ?? '');
    final textCtrl = TextEditingController(text: (existing?['task'] ?? '').toString());
    final qtyCtrl = TextEditingController(text: (existing?['qty'] ?? 1).toString());

    // NEW fields
    final toBePerformedCtrl =
    TextEditingController(text: (existing?['taskToBePerformed'] ?? '').toString());
    final guideCtrl =
    TextEditingController(text: (existing?['guideToAssessor'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(taskNo == null ? 'Add task' : 'Edit task $taskNo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noCtrl,
                decoration: const InputDecoration(labelText: 'Task number (e.g. 1.1)'),
              ),
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(labelText: 'Task text'),
              ),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Times to perform (qty)'),
                keyboardType: TextInputType.number,
              ),

              // -------- NEW INPUTS --------
              TextField(
                controller: toBePerformedCtrl,
                decoration: const InputDecoration(labelText: 'Task to be performed'),
              ),
              TextField(
                controller: guideCtrl,
                decoration: const InputDecoration(labelText: 'Guide to assessor'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final number = noCtrl.text.trim();
    final text = textCtrl.text.trim();
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;

    final taskToBePerformed = toBePerformedCtrl.text.trim();
    final guideToAssessor = guideCtrl.text.trim();

    if (number.isEmpty || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task number and text are required')),
      );
      return;
    }

    // If you want these new fields mandatory, keep this validation.
    // If you want them optional, remove this block.
    if (taskToBePerformed.isEmpty || guideToAssessor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task to be performed and Guide to assessor are required')),
      );
      return;
    }

    // If editing and task number changed, move the data (delete old key + write new key)
    final batch = FirebaseFirestore.instance.batch();

    if (taskNo != null && taskNo != number) {
      batch.update(_doc, {'chapters.$chapterNo.$taskNo': FieldValue.delete()});
    }

    batch.set(
      _doc,
      {
        'chapters': {
          chapterNo: {
            number: {
              'task': text,
              'qty': qty,
              'taskToBePerformed': taskToBePerformed,
              'guideToAssessor': guideToAssessor,
            }
          }
        }
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task saved')));
  }
}
