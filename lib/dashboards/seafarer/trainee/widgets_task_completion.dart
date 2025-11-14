import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// -------------------------
/// CONFIG – ajuste se preciso
/// -------------------------
const String kUsersCol = 'users';
const String kProgramsCol = 'training_programs';
const String kAssignmentsCol = 'assignments';
const String kCampaignsCol = 'campaigns';
const String kTaskDeclSubcol = 'task_declarations';

Future<void> declareTaskCompletion({
  required BuildContext context,
  required String userId,
  String? campaignId,
  required String programId,
  required String programTitle,
  required String chapterId,
  required String chapterTitle,
  required String taskId,
  required String taskTitle,
  int? requiredQty, // <- OPCIONAL (mantém compatibilidade). Se null, busco no training_programs; fallback = 1.
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Confirm declaration'),
      content: Text(
        'Do you want to declare this task as completed?\n\n'
            'Program: $programTitle\n'
            'Chapter: $chapterTitle\n'
            'Task: $taskTitle',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Declare')),
      ],
    ),
  );
  if (ok != true) return;

  if (userId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot declare: userId is empty.')),
    );
    return;
  }

  final db = FirebaseFirestore.instance;
  final usersCol = db.collection(kUsersCol);

  // 0) Pega metadados do usuário (para denormalização e filtro do supervisor)
  final uSnap = await usersCol.doc(userId).get();
  final uData = uSnap.data() ?? {};
  final traineeVessel = (uData['vessel'] ?? '').toString();
  final traineeName  = (uData['userName'] ?? '').toString();
  final traineeRole  = (uData['userRole'] ?? uData['role'] ?? '').toString();

  // 1) Resolve requiredQty (se não veio por parâmetro)
  final int reqQty = requiredQty ?? await _resolveRequiredQty(
    programId: programId,
    chapterId: chapterId,
    taskId: taskId,
  );

  // 2) Doc pai deduplicado por campaign/program/chapter/task
  final safeTask = taskId.replaceAll('.', '·');
  final declId = (campaignId != null && campaignId.isNotEmpty)
      ? '${campaignId}__${programId}__${chapterId}__${safeTask}'
      : '${programId}__${chapterId}__${safeTask}';

  final declRef = usersCol.doc(userId).collection(kTaskDeclSubcol).doc(declId);
  final compsCol = declRef.collection('completions');

  // 3) Transação: garante doc pai + cria NOVA completion
  try {
    await db.runTransaction((tx) async {
      final now = FieldValue.serverTimestamp();

      final declSnap = await tx.get(declRef);
      int declaredCount = 0;
      int approvedCount = 0;
      int currentReqQty = reqQty;

      if (!declSnap.exists) {
        // Doc pai novo
        tx.set(declRef, {
          'userId': userId,
          'traineeName': traineeName,
          'traineeRole': traineeRole,
          'vessel': traineeVessel,

          'campaignId': campaignId ?? '',
          'programId': programId,
          'programTitle': programTitle,
          'chapterId': chapterId,
          'chapterTitle': chapterTitle,
          'taskId': taskId,
          'taskTitle': taskTitle,

          'requiredQty': currentReqQty,
          'declaredCount': 0,
          'approvedCount': 0,
          'status': 'declared', // haverá uma completion pendente já já

          'keyReadable': '$programId::$chapterId::$taskId',
          'createdAt': now,
          'updatedAt': now,
        });
      } else {
        final m = declSnap.data() ?? {};
        declaredCount = (m['declaredCount'] ?? 0) as int;
        approvedCount = (m['approvedCount'] ?? 0) as int;
        currentReqQty = (m['requiredQty'] ?? currentReqQty) as int;

        // Se o doc antigo não tinha esses campos, garante a existência
        final patch = <String, Object?>{};
        if (!m.containsKey('vessel'))       patch['vessel'] = traineeVessel;
        if (!m.containsKey('traineeName'))  patch['traineeName'] = traineeName;
        if (!m.containsKey('traineeRole'))  patch['traineeRole'] = traineeRole;
        if (!m.containsKey('requiredQty'))  patch['requiredQty'] = currentReqQty;
        if (!m.containsKey('declaredCount')) patch['declaredCount'] = declaredCount;
        if (!m.containsKey('approvedCount')) patch['approvedCount'] = approvedCount;
        if (patch.isNotEmpty) {
          patch['updatedAt'] = now;
          tx.update(declRef, patch);
        } else {
          tx.update(declRef, {'updatedAt': now});
        }
      }

      // Índice desta ocorrência = já declaradas + aprovadas + 1
      final nextIndex = declaredCount + approvedCount + 1;

      // 4) Cria a completion "declared"
      final compRef = compsCol.doc();
      tx.set(compRef, {
        'index': nextIndex,
        'status': 'declared',
        'declaredAt': now,

        // denormalização p/ supervisor (collectionGroup)
        'userId': userId,
        'traineeName': traineeName,
        'vessel': traineeVessel,

        'campaignId': campaignId ?? '',
        'programId': programId,
        'programTitle': programTitle,
        'chapterId': chapterId,
        'chapterTitle': chapterTitle,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'requiredQty': currentReqQty,
      });

      // 5) Atualiza agregados do pai
      tx.update(declRef, {
        'declaredCount': FieldValue.increment(1),
        'status': 'declared',
        'updatedAt': now,
      });
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task declared as completed.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to declare task: $e')),
      );
    }
  }
}

/// Busca qty em training_programs/{programId}.chapters[{chapterId}][{taskId}].qty
/// Se não achar, retorna 1.
Future<int> _resolveRequiredQty({
  required String programId,
  required String chapterId,
  required String taskId,
}) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('training_programs')
        .doc(programId)
        .get();
    if (!doc.exists) return 1;
    final data = doc.data() ?? {};
    final chapters = data['chapters'];
    if (chapters is! Map) return 1;

    final ch = chapters[chapterId];
    if (ch is! Map) return 1;

    final t = ch[taskId];
    if (t is! Map) return 1;

    final q = t['qty'];
    if (q is num) return q.toInt();
    return 1;
  } catch (_) {
    return 1;
  }
}

/// --------- PUBLIC API ----------
/// Chame esta função ao tocar no botão “Log New Task Completion”
Future<void> showTaskCompletionPicker({
  required BuildContext context,
  required String userId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaskCompletionSheet(userId: userId),
  );
}

/// ------------------------------------
/// UI principal (bottom sheet em 3 passos)
/// ------------------------------------
class _TaskCompletionSheet extends StatefulWidget {
  const _TaskCompletionSheet({required this.userId});
  final String userId;

  @override
  State<_TaskCompletionSheet> createState() => _TaskCompletionSheetState();
}

class _TaskCompletionSheetState extends State<_TaskCompletionSheet> {
  String? _selectedProgramId;
  String? _selectedChapterId;
  String? _selectedTaskId;
  String? _selectedProgramTitle;
  String? _selectedChapterTitle;
  String? _selectedTaskTitle;

  String? _selectedCampaignId;
  String? _selectedCampaignName;

  String _taskQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44, height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12, borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.flag),
                    const SizedBox(width: 8),
                    Text('Declare Task Completion',
                        style: theme.textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _Breadcrumb(
                program: _selectedProgramTitle ??
                    (_selectedProgramId != null ? 'Program ${_selectedProgramId!}' : null),
                chapter: _selectedChapterTitle ??
                    (_selectedChapterId != null ? 'Chapter ${_selectedChapterId!}' : null),
                task: _selectedTaskTitle,
                onResetProgram: () {
                  setState(() {
                    _selectedProgramId = null;
                    _selectedProgramTitle = null;
                    _selectedChapterId = null;
                    _selectedChapterTitle = null;
                    _selectedTaskId = null;
                    _selectedTaskTitle = null;
                    _selectedCampaignId = null;
                    _selectedCampaignName = null;
                  });
                },
                onResetChapter: () {
                  setState(() {
                    _selectedChapterId = null;
                    _selectedChapterTitle = null;
                    _selectedTaskId = null;
                    _selectedTaskTitle = null;
                  });
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedProgramId == null)
                        _ProgramsStep(
                          userId: widget.userId,
                          onSelect: (programId, programTitle, campaignId, campaignName) {
                            setState(() {
                              _selectedProgramId = programId;
                              _selectedProgramTitle =
                              (programTitle?.trim().isNotEmpty ?? false)
                                  ? programTitle
                                  : programId;
                              _selectedCampaignId = campaignId;
                              _selectedCampaignName = campaignName;
                            });
                          },
                        )
                      else if (_selectedChapterId == null)
                        _ChaptersStep(
                          programId: _selectedProgramId!,
                          onSelect: (cid, title) {
                            setState(() {
                              _selectedChapterId = cid;
                              _selectedChapterTitle = title ?? cid;
                            });
                          },
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TaskSearchBar(
                              onChanged: (q) => setState(() {
                                _taskQuery = q.trim().toLowerCase();
                              }),
                            ),
                            const SizedBox(height: 8),
                            _TasksStep(
                              userId: widget.userId,
                              campaignId: _selectedCampaignId,
                              programId: _selectedProgramId!,
                              chapterId: _selectedChapterId!,
                              query: _taskQuery,
                              onSelect: (tid, title) async {
                                setState(() {
                                  _selectedTaskId = tid;
                                  _selectedTaskTitle = title ?? tid;
                                });
                                await _confirmAndDeclare(
                                  context: context,
                                  userId: widget.userId,
                                  campaignId: _selectedCampaignId,
                                  programId: _selectedProgramId!,
                                  programTitle: _selectedProgramTitle ?? '',
                                  chapterId: _selectedChapterId!,
                                  chapterTitle: _selectedChapterTitle ?? '',
                                  taskId: tid,
                                  taskTitle: title ?? tid,
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ------------------------------------
/// STEP 1 – Programas do usuário a partir de users/{uid}.programs (MAP)
/// Estrutura esperada:
/// users/{uid} {
///   programs: {
///     tprb1: { campaignId, title | programTitle | programName, status, ... },
///     tprb2: { ... }
///   }
/// }
/// ------------------------------------
class _ProgramsStep extends StatelessWidget {
  const _ProgramsStep({
    required this.userId,
    required this.onSelect,
  });

  final String userId;
  final void Function(
      String programId,
      String? programTitle,
      String? campaignId,
      String? campaignName,
      ) onSelect;

  Future<String?> _fetchProgramTitle(String programId) async {
    final doc = await FirebaseFirestore.instance
        .collection(kProgramsCol)
        .doc(programId)
        .get();
    if (doc.exists) {
      final m = doc.data() ?? {};
      // fallback de nomes possíveis de título no programa
      final t = ((m['title'] ??
          m['programTitle'] ??
          m['name']) as String?)
          ?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  Future<String?> _fetchCampaignName(String? campaignId) async {
    if (campaignId == null || campaignId.isEmpty) return null;
    final doc = await FirebaseFirestore.instance
        .collection(kCampaignsCol)
        .doc(campaignId)
        .get();
    if (doc.exists) {
      final m = doc.data() ?? {};
      final n = (m['name'] as String?)?.trim();
      if (n != null && n.isNotEmpty) return n;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userRef =
    FirebaseFirestore.instance.collection(kUsersCol).doc(userId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Busy(message: 'Loading assigned programs…');
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const _Empty(message: 'No user data found.');
        }

        final data = snap.data!.data() ?? {};
        final programs = (data['programs'] ?? {}) as Map<String, dynamic>;
        if (programs.isEmpty) {
          return const _Empty(message: 'No assigned programs.');
        }

        // Ordena por chave para ficar estável (tprb1, tprb2…)
        final ids = programs.keys.toList()..sort();

        final tiles = <Widget>[];
        for (final programId in ids) {
          final raw = programs[programId];
          Map<String, dynamic> meta = {};
          if (raw is Map) {
            meta = raw.map((k, v) => MapEntry(k.toString(), v));
          }

          // tenta vários campos possíveis para o título
          String? programTitle = (meta['programTitle'] ??
              meta['title'] ??
              meta['name']) as String?;
          programTitle = programTitle?.trim();

          final campaignId = (meta['campaignId'] ?? '').toString();

          tiles.add(FutureBuilder<List<dynamic>>(
            future: Future.wait([
              if (programTitle == null || programTitle.isEmpty)
                _fetchProgramTitle(programId)
              else
                Future.value(programTitle),
              _fetchCampaignName(campaignId.isEmpty ? null : campaignId),
            ]),
            builder: (context, snap) {
              final resolvedTitle =
                  (snap.data != null ? (snap.data![0] as String?) : null) ??
                      programTitle ??
                      programId;
              final campaignName =
              (snap.data != null ? (snap.data![1] as String?) : null);

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.library_books),
                  title: Text(resolvedTitle),
                  subtitle: Text(
                    campaignName != null && campaignName.isNotEmpty
                        ? 'Program: $programId • Campaign: $campaignName'
                        : 'Program: $programId',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelect(
                    programId,
                    resolvedTitle,
                    campaignId.isNotEmpty ? campaignId : null,
                    campaignName,
                  ),
                ),
              );
            },
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select a program',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...tiles,
          ],
        );
      },
    );
  }
}

class _ProgramAssignmentTile extends StatelessWidget {
  const _ProgramAssignmentTile({
    required this.programId,
    required this.campaignId,
    required this.onTap,
  });

  final String programId;
  final String? campaignId;
  final void Function(
      String programId,
      String? programTitle,
      String? campaignId,
      String? campaignName,
      ) onTap;

  Future<String?> _fetchProgramTitle() async {
    final doc =
    await FirebaseFirestore.instance.collection(kProgramsCol).doc(programId).get();
    if (doc.exists) {
      final m = doc.data() ?? {};
      final t = (m['title'] as String?)?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  Future<String?> _fetchCampaignName() async {
    if (campaignId == null) return null;
    final doc =
    await FirebaseFirestore.instance.collection(kCampaignsCol).doc(campaignId!).get();
    if (doc.exists) {
      final m = doc.data() ?? {};
      final t = (m['name'] as String?)?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_fetchProgramTitle(), _fetchCampaignName()]),
      builder: (context, snap) {
        final programTitle = (snap.data != null ? snap.data![0] as String? : null) ?? programId;
        final campaignName = (snap.data != null ? snap.data![1] as String? : null);

        return Card(
          child: ListTile(
            leading: const Icon(Icons.library_books),
            title: Text(programTitle),
            subtitle: Text(campaignName != null
                ? 'Program: $programId • Campaign: $campaignName'
                : 'Program: $programId'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTap(programId, programTitle, campaignId, campaignName),
          ),
        );
      },
    );
  }
}

/// ------------------------------------
/// STEP 2 – Capítulos do programa (map `chapters`)
/// ------------------------------------
class _ChaptersStep extends StatelessWidget {
  const _ChaptersStep({required this.programId, required this.onSelect});
  final String programId;
  final void Function(String chapterId, String? title) onSelect;

  Future<List<_Chapter>> _loadChapters() async {
    final progRef =
    FirebaseFirestore.instance.collection(kProgramsCol).doc(programId);

    final prog = await progRef.get();
    if (!prog.exists) return [];

    final data = prog.data() ?? {};
    final chaptersMap = (data['chapters'] ?? {}) as Map<String, dynamic>;
    if (chaptersMap.isEmpty) return [];

    // Ordenação natural: 1, 1.1, 1.2, 2...
    final chapterKeys = chaptersMap.keys.toList()..sort(_naturalCompare);

    final list = <_Chapter>[];
    for (final chKey in chapterKeys) {
      final tasksMap = chaptersMap[chKey];
      final tasks = <_Task>[];

      if (tasksMap is Map<String, dynamic>) {
        final taskKeys = tasksMap.keys.toList()..sort(_naturalCompare);
        for (final tKey in taskKeys) {
          final tVal = tasksMap[tKey];
          if (tVal is Map<String, dynamic>) {
            final title = (tVal['task'] as String?) ?? tKey;
            tasks.add(_Task(id: tKey, title: title));
          }
        }
      }

      list.add(_Chapter(
        id: chKey,
        title: 'Chapter $chKey',
        tasks: tasks,
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_Chapter>>(
      future: _loadChapters(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Busy(message: 'Loading chapters…');
        }
        final chapters = snap.data ?? [];
        if (chapters.isEmpty) {
          return const _Empty(message: 'No chapters found for this program.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select a chapter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...chapters.map((c) => Card(
              child: ListTile(
                leading: const Icon(Icons.list_alt),
                title: Text(c.title),
                subtitle: Text(c.id),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelect(c.id, c.title),
              ),
            )),
          ],
        );
      },
    );
  }
}

/// ------------------------------------
/// STEP 3 – Tasks + busca + marcação de já declaradas
/// ------------------------------------
class _TasksStep extends StatelessWidget {
  const _TasksStep({
    required this.userId,
    required this.programId,
    required this.chapterId,
    this.campaignId,
    required this.query,
    required this.onSelect,
  });

  final String userId;
  final String programId;
  final String chapterId;
  final String? campaignId;
  final String query;
  final void Function(String taskId, String? title) onSelect;

  Future<List<_Task>> _loadTasks() async {
    final progRef =
    FirebaseFirestore.instance.collection(kProgramsCol).doc(programId);

    final prog = await progRef.get();
    if (!prog.exists) return [];

    final data = prog.data() ?? {};
    final chaptersMap = (data['chapters'] ?? {}) as Map<String, dynamic>;
    final chVal = chaptersMap[chapterId];

    if (chVal is Map<String, dynamic>) {
      final taskKeys = chVal.keys.toList()..sort(_naturalCompare);
      final tasks = <_Task>[];
      for (final tKey in taskKeys) {
        final tVal = chVal[tKey];
        if (tVal is Map<String, dynamic>) {
          final title = (tVal['task'] as String?) ?? tKey;
          tasks.add(_Task(id: tKey, title: title));
        }
      }
      return tasks;
    }
    return [];
  }

  Stream<Set<String>> _declaredTaskIds() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection(kUsersCol).doc(userId)
        .collection(kTaskDeclSubcol)
        .where('programId', isEqualTo: programId)
        .where('chapterId', isEqualTo: chapterId);
    if (campaignId != null && campaignId!.isNotEmpty) {
      q = q.where('campaignId', isEqualTo: campaignId);
    }
    return q.snapshots().map((snap) {
      final ids = <String>{};
      for (final d in snap.docs) {
        final m = d.data();
        final tid = (m['taskId'] ?? '').toString();
        if (tid.isNotEmpty) ids.add(tid);
      }
      return ids;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_Task>>(
      future: _loadTasks(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Busy(message: 'Loading tasks…');
        }
        var tasks = snap.data ?? [];
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          tasks = tasks.where((t) =>
          t.title.toLowerCase().contains(q) ||
              t.id.toLowerCase().contains(q)).toList();
        }
        if (tasks.isEmpty) {
          return const _Empty(message: 'No tasks found.');
        }

        return StreamBuilder<Set<String>>(
          stream: _declaredTaskIds(),
          builder: (context, dsnap) {
            final declared = dsnap.data ?? <String>{};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...tasks.map((t) {
                  final already = declared.contains(t.id);
                  return Opacity(
                    opacity: already ? 0.55 : 1,
                    child: Card(
                      child: ListTile(
                        leading: Icon(already ? Icons.check_circle : Icons.radio_button_unchecked),
                        title: Text(t.title),
                        subtitle: Text(t.id),
                        trailing: already ? const Text('Declared') : null,
                        enabled: !already,
                        onTap: already ? null : () => onSelect(t.id, t.title),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

/// ------------------------------------
/// Confirmação + gravação em users/{uid}/task_declarations/{docId}
/// ------------------------------------
Future<void> _confirmAndDeclare({
  required BuildContext context,
  required String userId,
  String? campaignId,
  required String programId,
  required String programTitle,
  required String chapterId,
  required String chapterTitle,
  required String taskId,
  required String taskTitle,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Confirm declaration'),
      content: Text(
        'Do you want to declare this task as completed?\n\n'
            'Program: $programTitle\n'
            'Chapter: $chapterTitle\n'
            'Task: $taskTitle',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Declare')),
      ],
    ),
  );

  if (confirmed != true) return;

  if (userId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot declare: userId is empty.')),
    );
    return;
  }

  String safeTask = taskId.replaceAll('.', '·');
  final docId = campaignId != null && campaignId.isNotEmpty
      ? '${campaignId}__${programId}__${chapterId}__${safeTask}'
      : '${programId}__${chapterId}__${safeTask}';

  final declRef = FirebaseFirestore.instance
      .collection(kUsersCol)
      .doc(userId)
      .collection(kTaskDeclSubcol)
      .doc(docId);

  try {
    final exists = (await declRef.get()).exists;
    if (exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This task was already declared.')),
        );
      }
      return;
    }

    await declRef.set({
      'userId': userId,
      'campaignId': campaignId,
      'programId': programId,
      'programTitle': programTitle,
      'chapterId': chapterId,
      'chapterTitle': chapterTitle,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'status': 'declared',
      'declaredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'keyReadable': '$programId::$chapterId::$taskId',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task declared as completed.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to declare task: $e')),
      );
    }
  }
}

/// ------------------------------------
/// Widgets auxiliares
/// ------------------------------------
class _TaskSearchBar extends StatelessWidget {
  const _TaskSearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search tasks…',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.program,
    required this.chapter,
    required this.task,
    required this.onResetProgram,
    required this.onResetChapter,
  });

  final String? program;
  final String? chapter;
  final String? task;
  final VoidCallback onResetProgram;
  final VoidCallback onResetChapter;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    chips.add(_Crumb(
      label: program ?? 'Program',
      onClear: program != null ? onResetProgram : null,
    ));
    chips.add(const Icon(Icons.chevron_right, size: 18));
    chips.add(_Crumb(
      label: chapter ?? 'Chapter',
      onClear: (chapter != null) ? onResetChapter : null,
    ));
    chips.add(const Icon(Icons.chevron_right, size: 18));
    chips.add(_Crumb(label: task ?? 'Task'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: chips),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, this.onClear});
  final String label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      deleteIcon: onClear != null ? const Icon(Icons.clear) : null,
      onDeleted: onClear,
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const SizedBox(width: 4),
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(message),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, style: const TextStyle(color: Colors.black54)),
    );
  }
}

/// Modelos simples
class _Chapter {
  final String id;
  final String title;
  final List<_Task> tasks;
  _Chapter({required this.id, required this.title, required this.tasks});
}

class _Task {
  final String id;
  final String title;
  _Task({required this.id, required this.title});
}

/// Ordenação natural para chaves "1", "1.1", "1.10", "2"
int _naturalCompare(String a, String b) {
  List<int> parse(String s) =>
      s.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final pa = parse(a), pb = parse(b);
  for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
    final ai = i < pa.length ? pa[i] : 0;
    final bi = i < pb.length ? pb[i] : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  return a.compareTo(b); // fallback estável
}
