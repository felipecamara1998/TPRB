import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChapterTasksPage extends StatelessWidget {
  final String programId;
  final String chapterNo;
  const ChapterTasksPage({super.key, required this.programId, required this.chapterNo});

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
          final chapter = ((data['chapters'] as Map?)?[chapterNo] as Map?)?.cast<String, dynamic>() ?? {};

          if (chapter.isEmpty) {
            return const Center(child: Text('No tasks yet.'));
          }

          final keys = chapter.keys.toList()..sort((a, b) {
            // keep numeric-like order (e.g., 1.1, 1.2, 1.10)
            int toSortable(String s) {
              final parts = s.split('.');
              final a = int.tryParse(parts.first) ?? 0;
              final b = (parts.length > 1) ? int.tryParse(parts[1]) ?? 0 : 0;
              return a * 10000 + b;
            }
            return toSortable(a).compareTo(toSortable(b));
          });

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemBuilder: (_, i) {
              final taskNo = keys[i];
              final map = (chapter[taskNo] as Map?) ?? {};
              final text = (map['task'] ?? '').toString();
              final qty = (map['qty'] ?? 1);

              return Card(
                child: ListTile(
                  title: Text('$taskNo  —  $text'),
                  subtitle: Text('Times to perform: $qty'),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    await _doc.update({'chapters.$chapterNo.$taskNo': FieldValue.delete()});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
  }

  Future<void> _addOrEditTask(BuildContext context, {String? taskNo, Map? existing}) async {
    final noCtrl = TextEditingController(text: taskNo ?? '');
    final textCtrl = TextEditingController(text: (existing?['task'] ?? '').toString());
    final qtyCtrl = TextEditingController(text: (existing?['qty'] ?? 1).toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(taskNo == null ? 'Add task' : 'Edit task $taskNo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: noCtrl, decoration: const InputDecoration(labelText: 'Task number (e.g. 1.1)'),),
            TextField(controller: textCtrl, decoration: const InputDecoration(labelText: 'Task text'),),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Times to perform (qty)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final number = noCtrl.text.trim();
    final text = textCtrl.text.trim();
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
    if (number.isEmpty || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task number and text are required')));
      return;
    }

    await _doc.set({
      'chapters': {
        chapterNo: {
          number: {'task': text, 'qty': qty}
        }
      }
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task saved')));
  }
}
