import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ───────────────────────── Models ─────────────────────────

class ProgramModel {
  final String programId;
  final String title;
  final List<ChapterModel> chapters;
  const ProgramModel({
    required this.programId,
    required this.title,
    required this.chapters,
  });
}

class ChapterModel {
  final String id;
  final String title;
  final List<TaskModel> tasks;
  const ChapterModel({required this.id, required this.title, required this.tasks});
}

class TaskModel {
  final String id;
  final String title;
  final int qty;
  const TaskModel({required this.id, required this.title, required this.qty});
}

class TaskStatus {
  final String status; // '', declared, partial, approved
  final int requiredQty;
  final int approvedCount;
  final int pendingCount;
  final DateTime? approvedAt;
  final DateTime? declaredAt;
  final String? lastApproverName;

  const TaskStatus({
    required this.status,
    required this.requiredQty,
    required this.approvedCount,
    required this.pendingCount,
    this.approvedAt,
    this.declaredAt,
    this.lastApproverName,
  });

  bool get isDone => approvedCount >= requiredQty;
  int get remaining => (requiredQty - (approvedCount + pendingCount)).clamp(0, 9999);
}

// ───────────────────────── Page ─────────────────────────

class ProgramTasksPage extends StatefulWidget {
  final String userId;
  final String programId;
  final String programTitle;
  final String? campaignId;
  final String? campaignName;

  const ProgramTasksPage({
    super.key,
    required this.userId,
    required this.programId,
    required this.programTitle,
    this.campaignId,
    this.campaignName,
  });

  @override
  State<ProgramTasksPage> createState() => _ProgramTasksPageState();
}

class _ProgramTasksPageState extends State<ProgramTasksPage> {
  final _search = TextEditingController();
  int _tab = 0; // 0=All, 1=Pending, 2=Declared

  late final Stream<ProgramModel> _program$;
  late final Stream<Map<String, TaskStatus>> _status$;

  @override
  void initState() {
    super.initState();
    _program$ = _watchProgram(widget.programId);
    _status$ = _watchAggregatedStatus(widget.userId, widget.programId);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ───────────────── Firestore: program (chapters/tasks) ─────────────────

  Stream<ProgramModel> _watchProgram(String programId) {
    final ref = FirebaseFirestore.instance.collection('training_programs').doc(programId);
    return ref.snapshots().map((ds) {
      final d = ds.data() ?? {};
      final title = (d['title'] ?? '').toString();

      final chaps = <ChapterModel>[];
      final chMap = (d['chapters'] ?? {}) as Map? ?? {};
      for (final e in chMap.entries) {
        final chId = e.key.toString();
        final tMap = (e.value ?? {}) as Map? ?? {};
        final tasks = <TaskModel>[];
        for (final te in tMap.entries) {
          final tid = te.key.toString();
          final tm = (te.value ?? {}) as Map? ?? {};
          final tTitle = (tm['task'] ?? '').toString();
          final qty = (tm['qty'] is num) ? (tm['qty'] as num).toInt() : 1;
          if (tTitle.isEmpty) continue;
          tasks.add(TaskModel(id: tid, title: tTitle, qty: qty < 1 ? 1 : qty));
        }
        tasks.sort((a, b) => a.id.compareTo(b.id));
        chaps.add(ChapterModel(id: chId, title: 'Chapter $chId', tasks: tasks));
      }
      chaps.sort((a, b) => a.id.compareTo(b.id));
      return ProgramModel(programId: programId, title: title, chapters: chaps);
    });
  }

  // ─────────── Firestore: status agregado por task (reage a updates) ───────────
  //
  // Estratégia: lemos APENAS o doc agregado em task_declarations.
  // Supervisor, ao aprovar, atualiza approvedCount/pendingCount/approvedAt/lastApproverName,
  // então o trainee reage em tempo real sem precisar "ouvir" a subcoleção.

  Stream<Map<String, TaskStatus>> _watchAggregatedStatus(String uid, String programId) {
    final q = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('task_declarations')
        .where('programId', isEqualTo: programId);

    return q.snapshots().map((qs) {
      final out = <String, TaskStatus>{};
      for (final d in qs.docs) {
        final m = d.data();
        final taskId = (m['taskId'] ?? '').toString();
        if (taskId.isEmpty) continue;
        final req = (m['requiredQty'] is num) ? (m['requiredQty'] as num).toInt() : 1;
        final appr = (m['approvedCount'] is num) ? (m['approvedCount'] as num).toInt() : 0;
        final pend = (m['pendingCount'] is num) ? (m['pendingCount'] as num).toInt() : 0;
        final approvedAt = (m['approvedAt'] is Timestamp) ? (m['approvedAt'] as Timestamp).toDate() : null;
        final declaredAt = (m['declaredAt'] is Timestamp) ? (m['declaredAt'] as Timestamp).toDate() : null;
        final status = (m['status'] ?? '').toString();
        final approver = (m['lastApproverName'] ?? '').toString().trim().isEmpty
            ? null
            : (m['lastApproverName'] as String);

        out[taskId] = TaskStatus(
          status: status,
          requiredQty: req < 1 ? 1 : req,
          approvedCount: appr,
          pendingCount: pend,
          approvedAt: approvedAt,
          declaredAt: declaredAt,
          lastApproverName: approver,
        );
      }
      return out;
    });
  }

  // ───────────────────────── Declare (com transação) ─────────────────────────
  // Impede declarar acima do mínimo e previne toques repetidos.

  Future<void> _declareOnce({
    required String userId,
    required String programId,
    required String programTitle,
    required String chapterId,
    required String chapterTitle,
    required TaskModel task,
    String? campaignId,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm declaration'),
        content: Text(
          'Do you want to declare this task as completed?\n\n'
              'Program: $programTitle\n'
              'Chapter: $chapterTitle\n'
              'Task: ${task.title}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Declare')),
        ],
      ),
    );
    if (ok != true) return;

    final safeTask = task.id.replaceAll('.', '·');
    final docId = (campaignId != null && campaignId.isNotEmpty)
        ? '${campaignId}__${programId}__${chapterId}__${safeTask}'
        : '${programId}__${chapterId}__${safeTask}';

    final declRef = FirebaseFirestore.instance
        .collection('users').doc(userId)
        .collection('task_declarations').doc(docId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(declRef);

        int requiredQty = task.qty;
        int approved = 0;
        int pending = 0;

        if (snap.exists) {
          final m = snap.data() as Map<String, dynamic>;
          requiredQty = (m['requiredQty'] is num) ? (m['requiredQty'] as num).toInt() : requiredQty;
          approved   = (m['approvedCount'] is num) ? (m['approvedCount'] as num).toInt() : 0;
          pending    = (m['pendingCount']  is num) ? (m['pendingCount']  as num).toInt() : 0;
        }

        if (approved + pending >= requiredQty) {
          throw StateError('Required minimum already reached.');
        }

        if (!snap.exists) {
          tx.set(declRef, {
            'userId'        : userId,
            'programId'     : programId,
            'programTitle'  : programTitle,
            'chapterId'     : chapterId,
            'chapterTitle'  : chapterTitle,
            'taskId'        : task.id,
            'taskTitle'     : task.title,
            'requiredQty'   : requiredQty,
            'approvedCount' : 0,
            'pendingCount'  : 0,
            'status'        : '',
            'createdAt'     : FieldValue.serverTimestamp(),
            'updatedAt'     : FieldValue.serverTimestamp(),
          });
        }

        tx.update(declRef, {
          'pendingCount'  : FieldValue.increment(1),
          'declaredAt'    : FieldValue.serverTimestamp(),
          'status'        : 'declared',
          'updatedAt'     : FieldValue.serverTimestamp(),
        });

        // histórico opcional
        final compRef = declRef.collection('completions').doc();
        tx.set(compRef, {
          'status'     : 'declared',
          'declaredAt' : FieldValue.serverTimestamp(),
          'programId'  : programId,
          'chapterId'  : chapterId,
          'taskId'     : task.id,
          'userId'     : userId,
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task declared as completed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to declare: $e')),
      );
    }
  }

  // ───────────────────────── Helpers/UI ─────────────────────────

  String _fmtD(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)} ${m[d.month-1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.programTitle),
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: StreamBuilder<ProgramModel>(
        stream: _program$,
        builder: (context, progSnap) {
          if (!progSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final program = progSnap.data!;

          return StreamBuilder<Map<String, TaskStatus>>(
            stream: _status$,
            builder: (context, stSnap) {
              final statusMap = stSnap.data ?? const <String, TaskStatus>{};

              final totalTasks = program.chapters.fold<int>(0, (s, c) => s + c.tasks.length);
              final doneTasks  = program.chapters.fold<int>(0, (s, c) {
                for (final t in c.tasks) {
                  final st = statusMap[t.id];
                  if (st != null && st.isDone) s++;
                }
                return s;
              });
              final overall = totalTasks == 0 ? 0.0 : doneTasks / totalTasks;

              return Column(
                children: [
                  // Overall
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _OverallBar(
                      label: 'Overall Progress',
                      percent: overall,
                      suffix: '$doneTasks / $totalTasks completed',
                    ),
                  ),

                  // Filtros + busca
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        _FilterChip(label: 'All', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Pending', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Declared', selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _search,
                            decoration: InputDecoration(
                              isDense: true,
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Search tasks…',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: program.chapters.length,
                      itemBuilder: (_, i) {
                        final ch = program.chapters[i];

                        // chapter progress: tasks concluídas (aprovadas)
                        int chDone = 0;
                        for (final t in ch.tasks) {
                          if ((statusMap[t.id]?.isDone ?? false)) chDone++;
                        }
                        final chTotal = ch.tasks.length;
                        final chPct   = chTotal == 0 ? 0.0 : chDone / chTotal;

                        // filtro
                        final q = _search.text.trim().toLowerCase();
                        final filtered = ch.tasks.where((t) {
                          if (q.isNotEmpty &&
                              !t.title.toLowerCase().contains(q) &&
                              !t.id.toLowerCase().contains(q)) return false;
                          final st = statusMap[t.id];
                          if (_tab == 1) return !(st?.isDone ?? false);                // pending
                          if (_tab == 2) return (st?.pendingCount ?? 0) > 0;           // declared/pending
                          return true;
                        }).toList();

                        return _ChapterCard(
                          chapterTitle: ch.title,
                          chapterId: ch.id,
                          progress: chPct,
                          done: chDone,
                          total: chTotal,
                          tasks: filtered.map((t) {
                            final st  = statusMap[t.id];
                            final req = t.qty;
                            final appr = st?.approvedCount ?? 0;
                            final pend = st?.pendingCount ?? 0;
                            final done = st?.isDone ?? false;

                            // Permitir declarar somente se (aprovadas + pendentes) < required
                            final canDeclare = !done && (appr + pend) < req;

                            // ícone
                            IconData icon;
                            Color iconColor;
                            if (done) {
                              icon = Icons.check_circle_rounded;
                              iconColor = Colors.green.shade600;
                            } else if (pend > 0) {
                              icon = Icons.schedule_rounded;
                              iconColor = Colors.amber.shade700;
                            } else {
                              icon = Icons.radio_button_unchecked;
                              iconColor = Colors.black.withOpacity(.45);
                            }

                            // label direita
                            String right = '';
                            Color rightColor = Colors.black.withOpacity(.6);
                            if (done) {
                              final dt = st?.approvedAt ?? st?.declaredAt;
                              final who = (st?.lastApproverName ?? '').isNotEmpty
                                  ? ' • by ${st!.lastApproverName}'
                                  : '';
                              right = 'Approved${dt != null ? ' • ${_fmtD(dt)}' : ''}$who';
                              rightColor = Colors.green.shade700;
                            } else if (req > 1) {
                              final parts = <String>['Approved $appr/$req'];
                              if (pend > 0) parts.add('$pend submitted');
                              final dt = st?.declaredAt ?? st?.approvedAt;
                              if (dt != null) parts.add(_fmtD(dt));
                              right = parts.join(' • ');
                            } else if (pend > 0) {
                              final dt = st?.declaredAt;
                              right = 'Submitted${dt != null ? ' • ${_fmtD(dt)}' : ''}';
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F8FB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Icon(icon, color: iconColor),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(t.id, style: TextStyle(color: Colors.black.withOpacity(.55))),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (right.isNotEmpty) Text(right, style: TextStyle(color: rightColor)),
                                      if (req > 1 && !done)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text('Remaining: ${st?.remaining ?? (req)}',
                                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                        ),
                                      if (canDeclare) ...[
                                        const SizedBox(height: 6),
                                        TextButton.icon(
                                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                                          label: const Text('Declare'),
                                          onPressed: () => _declareOnce(
                                            userId: widget.userId,
                                            programId: widget.programId,
                                            programTitle: widget.programTitle,
                                            chapterId: ch.id,
                                            chapterTitle: ch.title,
                                            task: t,
                                            campaignId: widget.campaignId,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ────────────────────── Visual helpers ──────────────────────

class _OverallBar extends StatelessWidget {
  final String label;
  final double percent;
  final String suffix;
  const _OverallBar({required this.label, required this.percent, required this.suffix});

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: const Color(0xFFF7F8FB), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.insights_outlined, size: 18),
          const SizedBox(width: 8),
          const Text('Overall Progress', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: p,
            backgroundColor: Colors.black.withOpacity(.08),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade600),
          ),
        ),
        const SizedBox(height: 8),
        Text(suffix, style: TextStyle(color: Colors.black.withOpacity(.6))),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFE8EEFF),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final String chapterTitle;
  final String chapterId;
  final double progress;
  final int done;
  final int total;
  final List<Widget> tasks;
  const _ChapterCard({
    required this.chapterTitle,
    required this.chapterId,
    required this.progress,
    required this.done,
    required this.total,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final pct = progress.clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF3F5FA), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(children: [
            const Icon(Icons.menu_book_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(chapterTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            Text('$done/$total', style: TextStyle(color: Colors.black.withOpacity(.55))),
            const SizedBox(width: 10),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: pct,
                  backgroundColor: Colors.black.withOpacity(.08),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade600),
                ),
              ),
            ),
          ]),
        ),
        if (tasks.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(children: tasks)),
      ]),
    );
  }
}
