import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Página principal do Trainee (Dashboard)
class TraineeDashboardPage extends StatelessWidget {
  const TraineeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ---- Mock de dados (substitua por Firebase depois) ----
    const traineeName = 'Ana Souza';
    const traineeRole = 'Deck Cadet • Flumar Brasil';

    final chapters = <ChapterProgressModel>[
      ChapterProgressModel('Chapter 1: Safety Basics', 2, 8),
      ChapterProgressModel('Chapter 2: Navigation', 0, 12),
      ChapterProgressModel('Chapter 3: Cargo Operations', 0, 15),
      ChapterProgressModel('Chapter 4: Engineering', 0, 10),
    ];

    final tasks = <TaskItemModel>[
      TaskItemModel(
        number: '1.1',
        title: 'Enclosed space entry briefing',
        chapter: '1 – Safety Basics',
        status: TaskStatus.submitted,
        submittedAt: DateTime(2024, 1, 14),
      ),
      TaskItemModel(
        number: '1.2',
        title: 'Muster list duties familiarization',
        chapter: '1 – Safety Basics',
        status: TaskStatus.approved,
        submittedAt: DateTime(2024, 1, 9),
      ),
      TaskItemModel(
        number: '1.3',
        title: 'Personal protective equipment usage',
        chapter: '1 – Safety Basics',
        status: TaskStatus.pending,
      ),
      TaskItemModel(
        number: '2.1',
        title: 'Bridge watchkeeping procedures',
        chapter: '2 – Navigation',
        status: TaskStatus.returned,
        submittedAt: DateTime(2024, 1, 7),
      ),
    ];

    final approved = tasks.where((t) => t.status == TaskStatus.approved).length;
    final submitted =
        tasks.where((t) => t.status == TaskStatus.submitted).length;
    final returned = tasks.where((t) => t.status == TaskStatus.returned).length;
    final pending = tasks.where((t) => t.status == TaskStatus.pending).length;

    final totalDone = chapters.fold<int>(0, (a, c) => a + c.done);
    final totalAll = chapters.fold<int>(0, (a, c) => a + c.total);
    final overallPct = totalAll == 0 ? 0.0 : totalDone / totalAll;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFE9EEF6),
          foregroundColor: Colors.black87,
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2A4E),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.book, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('TPRB',
                      style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Training Performance Record Book',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(traineeName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(traineeRole,
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
            const SizedBox(width: 12),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFDDE6F3),
              child: Text('AS', style: TextStyle(color: Colors.black87)),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'Training Dashboard',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),

                // Linha de cards
                _ResponsiveRow(
                  isWide: isWide,
                  children: [
                    Expanded(
                      child: _CardShell(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                icon: Icons.stacked_bar_chart_rounded,
                                title: 'Overall Progress'
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: _DonutProgress(
                                  percent: overallPct,
                                  label: '',
                                  size: 150,         // ↑ maior
                                  strokeWidth: 16,   // ↑ mais grosso
                                  // progressColor: Color(0xFFEF4444), // já é o default
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _CardShell(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                icon: Icons.insights_outlined,
                                title: 'Quick Stats',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _StatPill(
                                    icon: Icons.verified_rounded,
                                    label: 'Approved Tasks',
                                    value: approved,
                                    color: Colors.green.shade600,
                                  ),
                                  _StatPill(
                                    icon: Icons.schedule_rounded,
                                    label: 'Pending Review',
                                    value: pending,
                                    color: Colors.amber.shade700,
                                  ),
                                  _StatPill(
                                    icon: Icons.report_gmailerrorred_rounded,
                                    label: 'Needs Action',
                                    value: returned,
                                    color: Colors.red.shade600,
                                  ),
                                  _StatPill(
                                    icon: Icons.outbox_rounded,
                                    label: 'Submitted',
                                    value: submitted,
                                    color: Colors.blue.shade700,
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _CardShell(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                icon: Icons.flag_outlined,
                                title: 'Next Steps',
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.add),
                                  label:
                                  const Text('Log New Task Completion'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    backgroundColor:
                                    const Color(0xFF3B5CAA), // azul mais próximo do mock
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const _Bullet('Complete pending tasks from Chapter 1'),
                              const _Bullet('Review returned submissions'),
                              const _Bullet('Start Chapter 2 preparations'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Chapter Progress
                _CardShell(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.menu_book_outlined,
                          title: 'Chapter Progress',
                          subtitleRight:
                          'Your advancement through each training chapter',
                        ),
                        const SizedBox(height: 12),
                        for (final ch in chapters) ...[
                          _ChapterProgressRow(model: ch),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // My Tasks
                _CardShell(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.tune,
                          title: 'My Tasks',
                          subtitleRight:
                          'Track and manage your task submissions',
                        ),
                        const SizedBox(height: 6),
                        TabBar(
                          isScrollable: true,
                          indicator: _UnderlineIndicator(),
                          labelColor: Colors.black87,
                          unselectedLabelColor: Colors.black54,
                          tabs: const [
                            Tab(text: 'All'),
                            Tab(text: 'Pending'),
                            Tab(text: 'Submitted'),
                            Tab(text: 'Approved'),
                            Tab(text: 'Returned'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 440,
                          child: TabBarView(
                            children: [
                              _TaskList(tasks: tasks),
                              _TaskList(
                                  tasks: tasks
                                      .where((t) =>
                                  t.status == TaskStatus.pending)
                                      .toList()),
                              _TaskList(
                                  tasks: tasks
                                      .where((t) =>
                                  t.status == TaskStatus.submitted)
                                      .toList()),
                              _TaskList(
                                  tasks: tasks
                                      .where((t) =>
                                  t.status == TaskStatus.approved)
                                      .toList()),
                              _TaskList(
                                  tasks: tasks
                                      .where((t) =>
                                  t.status == TaskStatus.returned)
                                      .toList()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ====== MODELOS ======
enum TaskStatus { approved, pending, submitted, returned }

class ChapterProgressModel {
  final String title;
  final int done;
  final int total;
  ChapterProgressModel(this.title, this.done, this.total);
}

class TaskItemModel {
  final String number;
  final String title;
  final String chapter;
  final DateTime? submittedAt;
  final TaskStatus status;
  TaskItemModel({
    required this.number,
    required this.title,
    required this.chapter,
    required this.status,
    this.submittedAt,
  });
}

/// ====== COMPONENTES E ESTILOS ======

/// Casca de Card com borda suave (sem elevação) — reproduz visual do mock
class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF2)),
      ),
      child: child,
    );
  }
}

/// Seção com título e subtítulo à direita
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitleRight;
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.subtitleRight,
  });

  @override
  Widget build(BuildContext context) {
    // Limita o subtítulo e permite elipse em telas estreitas
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0D2A4E)),
        const SizedBox(width: 8),

        // Título ocupa o espaço natural sem quebrar
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),

        if (subtitleRight != null) ...[
          const SizedBox(width: 8),

          // Subtítulo ocupa o restante, com elipse e alinhado à direita
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                subtitleRight!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black45),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Indicador sublinhado arredondado para TabBar (estilo web)
class _UnderlineIndicator extends Decoration {
  const _UnderlineIndicator();
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _UnderlinePainter();
}

class _UnderlinePainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    if (cfg.size == null) return;
    final rect = Offset(offset.dx, cfg.size!.height - 3) &
    Size(cfg.size!.width, 3);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    final paint = Paint()..color = const Color(0xFF3B82F6);
    canvas.drawRRect(rrect, paint);
  }
}

class _ResponsiveRow extends StatelessWidget {
  final bool isWide;
  final List<Widget> children;
  const _ResponsiveRow({required this.isWide, required this.children});

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Flexible(flex: 1, child: children[i]),
            if (i != children.length - 1) const SizedBox(width: 12),
          ]
        ],
      );
    }
    return Column(
      children: [
        for (final c in children) ...[
          c,
          const SizedBox(height: 12),
        ]
      ],
    );
  }
}

class _DonutProgress extends StatelessWidget {
  final double percent;              // 0..1
  final String label;
  final double size;                 // diâmetro
  final double strokeWidth;          // espessura do anel
  final Color backgroundColor;
  final Color progressColor;
  final double minSweepDegrees;      // ângulo mínimo para não “sumir” em % muito baixo

  const _DonutProgress({
    required this.percent,
    required this.label,
    this.size = 190,
    this.strokeWidth = 16,
    this.backgroundColor = const Color(0xFFEDF1F6),
    this.progressColor = const Color(0xFFEF4444), // vermelho do mock
    this.minSweepDegrees = 6, // dá uma “cápsula” visível para 1–3%
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final pct = percent.clamp(0, 1).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              pct: pct,
              strokeWidth: strokeWidth,
              bg: backgroundColor,
              fg: progressColor,
              minSweepRad: minSweepDegrees * math.pi / 180,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Complete',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.black45),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double pct;
  final double strokeWidth;
  final Color bg;
  final Color fg;
  final double minSweepRad;

  _DonutPainter({
    required this.pct,
    required this.strokeWidth,
    required this.bg,
    required this.fg,
    required this.minSweepRad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Anel de fundo
    final bgPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = bg;
    canvas.drawArc(rect.deflate(strokeWidth / 2), 0, 2 * math.pi, false, bgPaint);

    // Progresso (começa no topo)
    if (pct > 0) {
      final sweep = math.max(pct * 2 * math.pi, minSweepRad);
      final fgPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = fg;
      // -pi/2 = 12h
      canvas.drawArc(rect.deflate(strokeWidth / 2), -math.pi / 2,
          math.min(sweep, 2 * math.pi - 0.01), false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.pct != pct ||
          oldDelegate.strokeWidth != strokeWidth ||
          oldDelegate.bg != bg ||
          oldDelegate.fg != fg;
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatPill(
      {required this.icon,
        required this.label,
        required this.value,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label,
              style:
              const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$value',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ChapterProgressRow extends StatelessWidget {
  final ChapterProgressModel model;
  const _ChapterProgressRow({required this.model});

  @override
  Widget build(BuildContext context) {
    final pct = model.total == 0 ? 0.0 : model.done / model.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          model.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: const Color(0xFFF0F3F8),
            color: const Color(0xFF2C4C86),
          ),
        ),
        const SizedBox(height: 4),
        Text('${model.done} / ${model.total}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black45)),
      ],
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<TaskItemModel> tasks;
  const _TaskList({required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks to show'));
    }
    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _TaskTile(task: tasks[i]),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskItemModel task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final pill = _statusPill(task.status);
    final trailing = _trailingForStatus(task.status);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF2)),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NumberBadge(task.number),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(task.chapter,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    pill,
                    const SizedBox(width: 8),
                    if (task.submittedAt != null)
                      Text(
                        'Submitted: ${_fmtDate(task.submittedAt!)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.black54),
                      ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (trailing != null) trailing,
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {},
                child: const Text('View Details'),
              ),
            ],
          )
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static Widget? _trailingForStatus(TaskStatus s) {
    switch (s) {
      case TaskStatus.pending:
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: () {},
          child: const Text('Submit Evidence'),
        );
      case TaskStatus.returned:
        return FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: () {},
          child: const Text('Resubmit'),
        );
      default:
        return null;
    }
  }

  static Widget _statusPill(TaskStatus s) {
    late final String label;
    late final Color color;
    switch (s) {
      case TaskStatus.approved:
        label = 'Approved';
        color = Colors.green;
        break;
      case TaskStatus.pending:
        label = 'Pending';
        color = Colors.amber.shade800;
        break;
      case TaskStatus.submitted:
        label = 'Submitted';
        color = Colors.blue;
        break;
      case TaskStatus.returned:
        label = 'Returned';
        color = Colors.red;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final String text;
  const _NumberBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E6F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
