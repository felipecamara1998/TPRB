import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tprb/widgets/widgets.dart';
import 'widgets_trainee.dart';
import 'widgets_task_completion.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Página principal do Trainee (Dashboard)
class TraineeDashboardPage extends StatelessWidget {
  const TraineeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: 'MOB drill familiarization',
        chapter: '1 – Safety Basics',
        status: TaskStatus.approved,
        submittedAt: DateTime(2024, 1, 10),
      ),
      TaskItemModel(
        number: '1.3',
        title: 'Personal protective equipment usage',
        chapter: '1 – Safety Basics',
        status: TaskStatus.pending,
      ),
      TaskItemModel(
        number: '2.1',
        title: 'ECDIS basic route creation',
        chapter: '2 – Navigation',
        status: TaskStatus.returned,
      ),
    ];

    final approved =
        tasks.where((t) => t.status == TaskStatus.approved).length;
    final submitted =
        tasks.where((t) => t.status == TaskStatus.submitted).length;
    final returned =
        tasks.where((t) => t.status == TaskStatus.returned).length;
    final pending = tasks.where((t) => t.status == TaskStatus.pending).length;

    final totalDone = chapters.fold<int>(0, (a, c) => a + c.done);
    final totalAll = chapters.fold<int>(0, (a, c) => a + c.total);
    final overallPct = totalAll == 0 ? 0.0 : totalDone / totalAll;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6FA),
        appBar: CustomTopBar(
          userId: FirebaseAuth.instance.currentUser?.uid,
          email: FirebaseAuth.instance.currentUser?.email,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final uid = FirebaseAuth.instance.currentUser?.uid;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'Training Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),

                // Linha de cards
                _CardShell(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            Text(
                              'Overall Progress',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: (uid == null)
                                  ? _DonutProgress(
                                percent: 0,
                                label: '',
                                size: 150,
                                strokeWidth: 16,
                              )
                                  : OverallDonutProgress(
                                userId: uid,
                                size: 150,
                                strokeWidth: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Expanded(
                //   child: _CardShell(
                //     child: Padding(
                //       padding: const EdgeInsets.all(16),
                //       child: Column(
                //         crossAxisAlignment: CrossAxisAlignment.start,
                //         children: [
                //           const _SectionTitle(
                //             icon: Icons.insights_outlined,
                //             title: 'Quick Stats',
                //           ),
                //           const SizedBox(height: 12),
                //           Wrap(
                //             spacing: 12,
                //             runSpacing: 12,
                //             children: [
                //               _StatPill(
                //                 icon: Icons.verified_rounded,
                //                 label: 'Approved Tasks',
                //                 value: approved,
                //                 color: Colors.green.shade600,
                //               ),
                //               _StatPill(
                //                 icon: Icons.schedule_rounded,
                //                 label: 'Pending Review',
                //                 value: pending,
                //                 color: Colors.orange.shade600,
                //               ),
                //               _StatPill(
                //                 icon: Icons.outlined_flag_rounded,
                //                 label: 'Returned',
                //                 value: returned,
                //                 color: Colors.red.shade600,
                //               ),
                //               _StatPill(
                //                 icon: Icons.outbox_rounded,
                //                 label: 'Submitted',
                //                 value: submitted,
                //                 color: Colors.blue.shade700,
                //               ),
                //             ],
                //           ),
                //         ],
                //       ),
                //     ),
                //   ),
                // ),

                const SizedBox(height: 12),

                // Box: Next Steps
                _CardShell(
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
                            onPressed: () async {
                              if (uid == null) {
                                // ignore: use_build_context_synchronously
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Not logged in'),
                                    content: const Text(
                                      'You must be logged in.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              showTaskCompletionPicker(
                                context: context,
                                userId: uid,
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Log New Task Completion'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              backgroundColor: const Color(0xFF3B5CAA),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Box: My Campaigns (usuário logado)
                const SizedBox(height: 8),
                const TraineeActiveCampaignsBox(onlyActiveCampaigns: true),
                const SizedBox(height: 16),

                // (aqui no seu arquivo original você tinha mais coisas comentadas,
                // como chapter progress, etc. Vamos manter igual.)

                // Chapter Progress
                // _CardShell(
                //   child: Padding(
                //     padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                //     child: Column(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: [
                //         const _SectionTitle(
                //           icon: Icons.menu_book_outlined,
                //           title: 'Chapter Progress',
                //         ),
                //         const SizedBox(height: 12),
                //         Column(
                //           children: chapters
                //               .map((c) => _ChapterProgressTile(model: c))
                //               .toList(),
                //         ),
                //       ],
                //     ),
                //   ),
                // ),

                // Você tinha também a lista de tasks em outro arquivo (widgets_trainee),
                // então vamos deixar como estava.
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ====== MODELOS MOCK USADOS NA PÁGINA ======
class ChapterProgressModel {
  final String title;
  final int done;
  final int total;
  ChapterProgressModel(this.title, this.done, this.total);
}

enum TaskStatus { submitted, approved, pending, returned }

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

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

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
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.blueGrey.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (subtitleRight != null)
          Text(
            subtitleRight!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

/// Donut progress usado quando não há dados do Firebase
class _DonutProgress extends StatelessWidget {
  final String? userId;
  final double percent; // 0..1
  final String label;
  final double size; // diâmetro
  final double strokeWidth; // espessura do anel
  final Color backgroundColor;
  final Color progressColor;
  final double minSweepDegrees;

  const _DonutProgress({
    this.userId,
    required this.percent,
    required this.label,
    this.size = 190,
    this.strokeWidth = 16,
    this.backgroundColor = const Color(0xFFEDF1F6),
    this.progressColor = const Color(0xFFEF4444),
    this.minSweepDegrees = 6,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    double pct = percent;
    if (pct.isNaN || !pct.isFinite) pct = 0;
    pct = pct.clamp(0.0, 1.0);

    final double safeSize =
    (size.isNaN || !size.isFinite || size <= 0) ? 150.0 : size;
    final double maxStroke = (safeSize / 2) - 1;
    double safeStroke =
    (strokeWidth.isNaN || !strokeWidth.isFinite || strokeWidth <= 0)
        ? 12.0
        : strokeWidth.clamp(1.0, maxStroke);

    return SizedBox(
      width: safeSize,
      height: safeSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(safeSize),
            painter: _DonutPainter(
              pct: pct,
              backgroundColor: backgroundColor,
              progressColor: progressColor,
              strokeWidth: safeStroke,
              minSweepDegrees: minSweepDegrees,
            ),
          ),
          Text(
            '${(pct * 100).round()}%',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double pct;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;
  final double minSweepDegrees;

  _DonutPainter({
    required this.pct,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
    required this.minSweepDegrees,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    double sweep = pct * 360;
    if (pct > 0 && sweep < minSweepDegrees) sweep = minSweepDegrees;

    final fgPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startAngle = -math.pi / 2;
    final sweepRads = sweep * math.pi / 180;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepRads,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.pct != pct ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// ====== WIDGET QUE BUSCA NO FIREBASE E MONTA O DONUT ======
class OverallDonutProgress extends StatelessWidget {
  const OverallDonutProgress({
    super.key,
    this.userId,
    this.size = 150,
    this.strokeWidth = 16,
    this.debug = true,
  });

  final String? userId;
  final double size;
  final double strokeWidth;
  final bool debug;

  void _log(Object msg) {
    if (debug) print('[OverallDonutProgress] $msg');
  }

  @override
  Widget build(BuildContext context) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    _log('uid = $uid');
    if (uid == null) {
      _log('Sem usuário logado → percent=0');
      return _DonutProgress(
          percent: 0, label: '', size: size, strokeWidth: strokeWidth);
    }

    final userRef =
    FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, usnap) {
        if (!usnap.hasData || !usnap.data!.exists) {
          _log('Doc users/$uid não existe ou sem dados.');
          return _DonutProgress(
              percent: 0, label: '', size: size, strokeWidth: strokeWidth);
        }

        final root = usnap.data!.data() ?? {};
        final Map<String, dynamic> programsMap =
        Map<String, dynamic>.from(
          root['programs'] ?? <String, dynamic>{},
        );
        _log('programs (keys) = ${programsMap.keys.toList()}');

        if (programsMap.isEmpty) {
          _log('Usuário sem programs → percent=0');
          return _DonutProgress(
              percent: 0, label: '', size: size, strokeWidth: strokeWidth);
        }

        final assignments = <({String programId, String? campaignId})>[];
        programsMap.forEach((pid, raw) {
          String? campaignId;
          if (raw is Map) {
            final meta =
            raw.map((k, v) => MapEntry(k.toString(), v));
            final cid = (meta['campaignId'] ??
                meta['campaignID'] ??
                '')
                .toString();
            if (cid.isNotEmpty) campaignId = cid;
          }
          assignments.add(
              (programId: pid.toString(), campaignId: campaignId));
        });
        _log(
            'assignments = ${assignments.map((a) => '{p:${a.programId}, c:${a.campaignId}}').toList()}');

        return FutureBuilder<int>(
          future: _sumTotalTasks(assignments),
          builder: (context, totalSnap) {
            final total = totalSnap.data ?? 0;
            _log('TOTAL tasks (somando por assignment) = $total');

            return StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: userRef
                  .collection('task_declarations')
                  .snapshots(),
              builder: (context, dsnap) {
                int done = 0;
                if (dsnap.hasData) {
                  final declared =
                  dsnap.data!.docs.map((d) => d.data()).toList();
                  _log('declared docs = ${declared.length}');

                  final assignedPrograms = assignments
                      .map((a) => a.programId)
                      .toSet();
                  _log('assignedPrograms = $assignedPrograms');

                  for (final m in declared) {
                    final pid = (m['programId'] ?? '').toString();
                    final cid = (m['campaignId'] ?? '').toString();
                    if (assignedPrograms.contains(pid)) {
                      done++;
                      _log(
                          '✔ conta: decl {programId=$pid, campaignId=$cid}');
                    } else {
                      _log(
                          '✖ ignora: decl {programId=$pid, campaignId=$cid} (não atribuído)');
                    }
                  }
                }

                final pct = (total == 0) ? 0.0 : (done / total);
                return _DonutProgress(
                  percent: pct,
                  label: '',
                  size: size,
                  strokeWidth: strokeWidth,
                );
              },
            );
          },
        );
      },
    );
  }

  Future<int> _sumTotalTasks(
      List<({String programId, String? campaignId})> assigns) async {
    final cache = <String, int>{};

    Future<int> countForProgram(String programId) async {
      if (cache.containsKey(programId)) return cache[programId]!;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('training_programs')
            .doc(programId)
            .get();
        if (!doc.exists) {
          _log('program=$programId não existe.');
          cache[programId] = 0;
          return 0;
        }
        final data = doc.data() ?? {};
        final chapters = data['chapters'];
        if (chapters is! Map) {
          _log('program=$programId sem chapters válidos.');
          cache[programId] = 0;
          return 0;
        }

        int total = 0;
        (chapters as Map).forEach((chKey, tasksMap) {
          if (tasksMap is Map) {
            int chapterCount = 0;
            (tasksMap as Map).forEach((taskKey, v) {
              if (v is Map) {
                chapterCount += 1;
              } else {
                _log(
                    '• ignora task $taskKey em chapter $chKey (tipo ${v.runtimeType})');
              }
            });
            total += chapterCount;
            _log(
                'program=$programId chapter=$chKey → tasks=$chapterCount');
          } else {
            _log(
                '• ignora chapter $chKey (tipo ${tasksMap.runtimeType})');
          }
        });

        cache[programId] = total;
        _log('program=$programId → totalTasks=$total');
        return total;
      } catch (e, st) {
        _log('❌ erro ao ler $programId: $e');
        _log(st);
        cache[programId] = 0;
        return 0;
      }
    }

    int sum = 0;
    for (final a in assigns) {
      final n = await countForProgram(a.programId);
      sum += n;
      _log(
          'assignment {p:${a.programId}, c:${a.campaignId}} contribui $n (acumulado=$sum)');
    }
    _log('Soma final (por assignment) = $sum');
    return sum;
  }
}
