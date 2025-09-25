import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'widgets_task_completion.dart';


const String kUsersCol = 'users';
const String kProgramsCol = 'training_programs';
const String kTaskDeclSubcol = 'task_declarations';

enum _TaskFilter { all, pending, declared }

class ProgramTasksPage extends StatefulWidget {
  const ProgramTasksPage({
    super.key,
    required this.userId,
    required this.programId,
    this.campaignId,
    this.programTitle,
    this.campaignName,
  });

  final String userId;
  final String programId;
  final String? campaignId;
  final String? programTitle;
  final String? campaignName;

  @override
  State<ProgramTasksPage> createState() => _ProgramTasksPageState();
}

class _ProgramTasksPageState extends State<ProgramTasksPage> {
  late Future<_ProgramModel?> _programFuture;
  _TaskFilter _filter = _TaskFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _programFuture = _loadProgram(widget.programId);
  }

  // ----------- DATA -------------
  Future<_ProgramModel?> _loadProgram(String programId) async {
    final doc =
    await FirebaseFirestore.instance.collection(kProgramsCol).doc(programId).get();
    if (!doc.exists) return null;
    final m = doc.data() ?? {};
    final title = (m['title'] as String?) ?? programId;
    final chaptersMap = (m['chapters'] ?? {}) as Map<String, dynamic>;

    // Parse chapters/tasks (map->model) com ordenação natural 1, 1.1, 1.2, 2...
    final chapterKeys = chaptersMap.keys.map((e) => e.toString()).toList()..sort(_naturalCompare);
    final chapters = <_ChapterModel>[];

    for (final chKey in chapterKeys) {
      final tasksMap = chaptersMap[chKey];
      final tasks = <_TaskModel>[];
      if (tasksMap is Map<String, dynamic>) {
        final taskKeys = tasksMap.keys.map((e) => e.toString()).toList()..sort(_naturalCompare);
        for (final tKey in taskKeys) {
          final tVal = tasksMap[tKey];
          if (tVal is Map<String, dynamic>) {
            final title = (tVal['task'] as String?) ?? tKey.toString();
            final qty = (tVal['qty'] is num) ? (tVal['qty'] as num).toInt() : 1;
            tasks.add(_TaskModel(id: tKey.toString(), title: title, qty: qty));
          }
        }
      }
      chapters.add(_ChapterModel(id: chKey, title: 'Chapter $chKey', tasks: tasks));
    }

    return _ProgramModel(id: programId, title: title, chapters: chapters);
  }

  Stream<Set<String>> _declaredTaskIdsStream() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection(kUsersCol).doc(widget.userId)
        .collection(kTaskDeclSubcol)
        .where('programId', isEqualTo: widget.programId);

    if ((widget.campaignId ?? '').isNotEmpty) {
      q = q.where('campaignId', isEqualTo: widget.campaignId);
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

  // ----------- UI -------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.programTitle ?? 'Program ${widget.programId}'),
            if ((widget.campaignName ?? '').isNotEmpty)
              Text(widget.campaignName!,
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.black54)),
          ],
        ),
      ),
      body: FutureBuilder<_ProgramModel?>(
        future: _programFuture,
        builder: (context, psnap) {
          if (psnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final program = psnap.data;
          if (program == null) {
            return const Center(child: Text('Program not found.'));
          }

          return StreamBuilder<Set<String>>(
            stream: _declaredTaskIdsStream(),
            builder: (context, dsnap) {
              final declared = dsnap.data ?? <String>{};

              // Totais gerais
              final totalTasks = program.chapters.fold<int>(0, (sum, c) => sum + c.tasks.length);
              final doneTasks = program.chapters.fold<int>(
                0,
                    (sum, c) => sum + c.tasks.where((t) => declared.contains(t.id)).length,
              );
              final progress = totalTasks == 0 ? 0.0 : doneTasks / totalTasks;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Resumo geral
                  _SummaryCard(
                    title: 'Overall Progress',
                    progress: progress,
                    done: doneTasks,
                    total: totalTasks,
                  ),
                  const SizedBox(height: 16),

                  // Filtros + busca
                  _FiltersBar(
                    filter: _filter,
                    onFilter: (f) => setState(() => _filter = f),
                    onQuery: (q) => setState(() => _query = q.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 12),

                  // Capítulos
                  ...program.chapters.map((ch) {
                    final chTotal = ch.tasks.length;
                    final chDone =
                        ch.tasks.where((t) => declared.contains(t.id)).length;
                    final chProgress = chTotal == 0 ? 0.0 : chDone / chTotal;

                    // aplica busca/filtro por capítulo+task
                    final filteredTasks = ch.tasks.where((t) {
                      final matchesQuery = _query.isEmpty ||
                          t.title.toLowerCase().contains(_query) ||
                          t.id.toLowerCase().contains(_query);
                      final isDone = declared.contains(t.id);
                      final matchesFilter = switch (_filter) {
                        _TaskFilter.all => true,
                        _TaskFilter.pending => !isDone,
                        _TaskFilter.declared => isDone,
                      };
                      return matchesQuery && matchesFilter;
                    }).toList();

                    return _ChapterCard(
                      chapterTitle: ch.title,
                      chapterId: ch.id,
                      progress: chProgress,
                      done: chDone,
                      total: chTotal,
                      tasks: filteredTasks.map((t) {
                        final isDone = declared.contains(t.id);
                        return _TaskTileData(
                          id: t.id,
                          title: t.title,
                          done: isDone,
                        );
                      }).toList(),
                      onDeclare: (chapterId, chapterTitle, task) async {
                        await declareTaskCompletion(
                          context: context,
                          userId: widget.userId,
                          campaignId: widget.campaignId,
                          programId: widget.programId,
                          programTitle: program.title,
                          chapterId: chapterId,
                          chapterTitle: chapterTitle,
                          taskId: task.id,
                          taskTitle: task.title,
                        );
                      },
                    );

                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------- WIDGETS DE UI -----------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.progress,
    required this.done,
    required this.total,
  });

  final String title;
  final double progress;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.insights_outlined),
                    const SizedBox(width: 8),
                    Text(title, style: theme.textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$done / $total completed',
                    style: theme.textTheme.labelMedium?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.filter,
    required this.onFilter,
    required this.onQuery,
  });

  final _TaskFilter filter;
  final ValueChanged<_TaskFilter> onFilter;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: filter == _TaskFilter.all,
          onSelected: (_) => onFilter(_TaskFilter.all),
        ),
        ChoiceChip(
          label: const Text('Pending'),
          selected: filter == _TaskFilter.pending,
          onSelected: (_) => onFilter(_TaskFilter.pending),
        ),
        ChoiceChip(
          label: const Text('Declared'),
          selected: filter == _TaskFilter.declared,
          onSelected: (_) => onFilter(_TaskFilter.declared),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 280,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search tasks…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: onQuery,
          ),
        ),
      ],
    );
  }
}

class _ChapterCard extends StatefulWidget {
  const _ChapterCard({
    required this.chapterTitle,
    required this.chapterId,
    required this.progress,
    required this.done,
    required this.total,
    required this.tasks,
    required this.onDeclare, // <- NOVO
  });

  final String chapterTitle;
  final String chapterId;
  final double progress;
  final int done;
  final int total;
  final List<_TaskTileData> tasks;
  final void Function(String chapterId, String chapterTitle, _TaskTileData task) onDeclare; // <- NOVO

  @override
  State<_ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<_ChapterCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.chapterTitle,
                        style: theme.textTheme.titleMedium),
                  ),
                  Text('${widget.done}/${widget.total}',
                      style: theme.textTheme.labelMedium),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: widget.progress.clamp(0.0, 1.0),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Tasks
            if (_expanded)
              Column(
                children: widget.tasks.map((t) {
                  return ListTile(
                    contentPadding: const EdgeInsets.only(left: 4, right: 4),
                    leading: Icon(
                      t.done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: t.done ? Colors.green : null,
                    ),
                    title: Text(t.title),
                    subtitle: Text(t.id),
                    dense: true,
                    trailing: t.done
                        ? const Text('Declared', style: TextStyle(color: Colors.green))
                        : TextButton.icon(
                      onPressed: () => widget.onDeclare(widget.chapterId, widget.chapterTitle, t),
                      icon: const Icon(Icons.add_task),
                      label: const Text('Declare'),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------- MODELOS & HELPERS -----------------

class _ProgramModel {
  final String id;
  final String title;
  final List<_ChapterModel> chapters;
  _ProgramModel({required this.id, required this.title, required this.chapters});
}

class _ChapterModel {
  final String id;
  final String title;
  final List<_TaskModel> tasks;
  _ChapterModel({required this.id, required this.title, required this.tasks});
}

class _TaskModel {
  final String id;
  final String title;
  final int qty;
  _TaskModel({required this.id, required this.title, required this.qty});
}

class _TaskTileData {
  final String id;
  final String title;
  final bool done;
  _TaskTileData({required this.id, required this.title, required this.done});
}

int _naturalCompare(String a, String b) {
  List<int> parse(String s) =>
      s.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final pa = parse(a), pb = parse(b);
  for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
    final ai = i < pa.length ? pa[i] : 0;
    final bi = i < pb.length ? pb[i] : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  return a.compareTo(b);
}
