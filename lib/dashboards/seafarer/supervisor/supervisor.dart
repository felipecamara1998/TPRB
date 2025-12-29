import 'dart:async';
import 'dart:ui'; // for ImageFilter.blur

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tprb/widgets/widgets.dart';

/// =======================
/// DASHBOARD DO SUPERVISOR
/// =======================
class OfficerReviewDashboardPage extends StatefulWidget {
  const OfficerReviewDashboardPage({super.key});

  @override
  State<OfficerReviewDashboardPage> createState() =>
      _OfficerReviewDashboardPageState();
}

class _OfficerReviewDashboardPageState
    extends State<OfficerReviewDashboardPage> {
  // meta do supervisor
  Future<_SupervisorMeta>? _metaFut;

  // stream dos pendentes
  final _pendingCtrl = StreamController<List<_PendingItem>>.broadcast();

  // listeners vivos
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _declSubs = {};

  // pendentes agrupados
  final Map<String, _PendingItem> _itemsByKey = {};

  // KPIs
  int _kpiPending = 0;
  int _kpiActiveTrainees = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    for (final s in _declSubs.values) {
      s.cancel();
    }
    _pendingCtrl.close();
    super.dispose();
  }

  // -------------------------------- init --------------------------------
  void _bootstrap() {
    _metaFut = _loadMeta().then((meta) {
      _listenTraineesAndDeclarations(meta);
      return meta;
    });
    setState(() {});
  }

  Future<_SupervisorMeta> _loadMeta() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('No logged user');

    final snap =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data() ?? {};

    final vessel = (data['vessel'] ?? data['vesselName'] ?? '').toString();
    final name =
    (data['userName'] ?? data['name'] ?? data['displayName'] ?? '')
        .toString();
    final supervisorRole = (data['userRole'] ?? data['role'] ?? '').toString();

    return _SupervisorMeta(
      supervisorId: uid,
      supervisorName: name.isEmpty
          ? (FirebaseAuth.instance.currentUser?.email ?? 'Supervisor')
          : name,
      vessel: vessel,
      supervisorRole: supervisorRole, // <- importante para o filtro
    );
  }

  // escuta trainees do mesmo vessel e acopla listeners nas declarações
  void _listenTraineesAndDeclarations(_SupervisorMeta meta) {
    _usersSub?.cancel();
    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .where('vessel', isEqualTo: meta.vessel)
        .snapshots()
        .listen((qs) {
      final activeIds = <String>{};
      int activeTrainees = 0;

      for (final d in qs.docs) {
        final m = d.data();
        final hasUserRole = ((m['userRole'] ?? '').toString()).isNotEmpty;
        if (!hasUserRole) continue;

        activeIds.add(d.id);
        activeTrainees++;

        if (!_declSubs.containsKey(d.id)) {
          _attachDeclarationsListener(
            traineeId: d.id,
            traineeName:
            (m['userName'] ?? m['name'] ?? m['email'] ?? 'Trainee')
                .toString(),
            supervisorRole: meta.supervisorRole, // <- passa o cargo do supervisor
          );
        }
      }

      // remove listeners de quem saiu
      final toRemove =
      _declSubs.keys.where((id) => !activeIds.contains(id)).toList();
      for (final id in toRemove) {
        _declSubs[id]?.cancel();
        _declSubs.remove(id);
        _itemsByKey.removeWhere((k, _) => k.startsWith('$id::'));
      }

      _kpiActiveTrainees = activeTrainees;
      _emit();
    });
  }

  void _attachDeclarationsListener({
    required String traineeId,
    required String traineeName,
    required String supervisorRole,
  }) {
    final sub = FirebaseFirestore.instance
        .collection('users')
        .doc(traineeId)
        .collection('task_declarations')
        .where('pendingCount', isGreaterThan: 0)
        .snapshots()
        .listen((qs) {
      final aliveKeys = <String>{};

      for (final d in qs.docs) {
        final m = d.data();

        // filtro client-side pelo cargo do supervisor
        final declaredTo = (m['declaredToRole'] ?? '').toString();
        if (declaredTo.isNotEmpty &&
            supervisorRole.isNotEmpty &&
            declaredTo != supervisorRole) {
          continue;
        }

        final key = '$traineeId::${d.id}';
        final declaredAt = (m['declaredAt'] as Timestamp?)?.toDate();
        final chapterTitle = (m['chapterTitle'] ?? '').toString();
        final programTitle = (m['programTitle'] ?? '').toString();
        final taskTitle = (m['taskTitle'] ?? '').toString();
        final taskId = (m['taskId'] ?? '').toString();

        final pendingCount = (m['pendingCount'] ?? 0) is int
            ? m['pendingCount'] as int
            : int.tryParse('${m['pendingCount']}') ?? 0;

        final approvedCount = (m['approvedCount'] ?? 0) is int
            ? m['approvedCount'] as int
            : int.tryParse('${m['approvedCount']}') ?? 0;

        final requiredQty = (m['requiredQty'] ?? 1) is int
            ? m['requiredQty'] as int
            : int.tryParse('${m['requiredQty']}') ?? 1;

        final evidence = (m['evidence'] ?? '').toString();

        _itemsByKey[key] = _PendingItem(
          key: key,
          ref: d.reference,
          traineeId: traineeId,
          traineeName: traineeName,
          submittedAt: declaredAt,
          chapter: chapterTitle,
          program: programTitle,
          title: taskTitle,
          indexLabel: taskId.isEmpty ? '—' : taskId,
          evidence: evidence.isEmpty ? '—' : evidence,
          requiredQty: requiredQty,
          approvedCount: approvedCount,
          pendingCount: pendingCount,
        );

        aliveKeys.add(key);
      }

      _itemsByKey.removeWhere(
              (k, _) => k.startsWith('$traineeId::') && !aliveKeys.contains(k));
      _emit();
    });

    _declSubs[traineeId] = sub;
  }

  void _emit() {
    final list = _itemsByKey.values.toList()
      ..sort((a, b) {
        final ad = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

    _kpiPending = list.length;
    _pendingCtrl.add(list);
    if (mounted) setState(() {});
  }

  // -------------------------------- approve --------------------------------
  Future<void> _approve(
      _PendingItem it, {
        required bool isFinalApproval,
      }) async {
    final sup = await _metaFut!;

    final remarkController = TextEditingController();

    String? selectedRating; // 'exceeds' | 'meets' | 'needs'
    bool showRatingError = false;

    final _ReviewResult? result = await showDialog<_ReviewResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) {
          Widget ratingTile(String label, String value, double width) {
            final selected = selectedRating == value;

            return SizedBox(
              width: width,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setLocal(() {
                    selectedRating = value;
                    showRatingError = false;
                  });
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE9F0FF)
                        : const Color(0xFFF7F9FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF3B82F6)
                          : Colors.black.withOpacity(.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: value,
                        groupValue: selectedRating,
                        onChanged: (v) {
                          setLocal(() {
                            selectedRating = v;
                            showRatingError = false;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Dialog(
            insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 720,
                minWidth: 320,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review & Sign',
                        style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Trainee: ${it.traineeName}\n'
                            'Program: ${it.program}\n'
                            'Chapter: ${it.chapter}\n'
                            'Task: ${it.title}',
                        style: const TextStyle(height: 1.3),
                      ),
                      const SizedBox(height: 10),

                      FutureBuilder<String>(
                        future: _fetchGuideToAssessor(
                          programTitle: it.program,
                          chapterKey: it.chapter,
                          taskId: it.indexLabel, // ex: CM2.1
                        ),
                        builder: (context, snap) {
                          final guide = (snap.data ?? '').trim();
                          if (guide.isEmpty) return const SizedBox.shrink();

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Guide to assessor',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  guide,
                                  style: const TextStyle(height: 1.35),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Assessment',
                        style:
                        Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, c) {
                          final w = c.maxWidth;
                          final tileW = w >= 780 ? (w - 20) / 3 : w;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ratingTile(
                                  'Exceeds Expectations', 'exceeds', tileW),
                              ratingTile('Meets Expectations', 'meets', tileW),
                              ratingTile(
                                  'Needs Improvement', 'needs', tileW),
                            ],
                          );
                        },
                      ),
                      if (showRatingError) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Please select one assessment option.',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: remarkController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Assessing officer remark',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, null),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              if (selectedRating == null) {
                                setLocal(() => showRatingError = true);
                                return;
                              }
                              Navigator.pop(
                                context,
                                _ReviewResult(
                                  remark: remarkController.text.trim(),
                                  rating: selectedRating!,
                                ),
                              );
                            },
                            child: const Text('Sign'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result == null) return;

    final String remark = result.remark.trim();
    final String rating = result.rating;
    final ref = it.ref;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final m = snap.data() as Map<String, dynamic>? ?? {};
        final requiredQty = (m['requiredQty'] ?? 1) is int
            ? m['requiredQty'] as int
            : int.tryParse('${m['requiredQty']}') ?? 1;
        final prevApproved = (m['approvedCount'] ?? 0) is int
            ? m['approvedCount'] as int
            : int.tryParse('${m['approvedCount']}') ?? 0;
        final prevPending = (m['pendingCount'] ?? 0) is int
            ? m['pendingCount'] as int
            : int.tryParse('${m['pendingCount']}') ?? 0;

        if (prevPending <= 0) return;

        final isNeedsImprovement = (rating == 'needs');

        // If Needs Improvement: do NOT count as approved, but consume one pending submission.
        final approvedDelta = isNeedsImprovement ? 0 : 1;

        final newApproved = prevApproved + approvedDelta;
        final newPending = prevPending - 1;

        final fullyApproved =
            !isNeedsImprovement && (newApproved >= requiredQty) && (newPending <= 0);

        final updateData = <String, dynamic>{
          'approvedCount': newApproved,
          'pendingCount': newPending < 0 ? 0 : newPending,
          // Needs Improvement should allow the trainee to declare again.
          'status': isNeedsImprovement
              ? 'needs_improvement'
              : (fullyApproved ? 'approved' : 'declared'),
          // We keep approvedAt as the "reviewed at" timestamp (works for both outcomes).
          'approvedAt': FieldValue.serverTimestamp(),
          'lastApproverId': sup.supervisorId,
          'lastApproverName': sup.supervisorName,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // remark só na última execução
        if (isFinalApproval && remark.isNotEmpty) {
          updateData['reviewRemark'] = remark;
        }

        // grava o rating (sempre que o supervisor aprova/revisa)
        updateData['performanceRating'] = rating;

        tx.update(ref, updateData);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rating == 'needs'
                ? 'Marked as Needs Improvement.'
                : 'Completion approved.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve: $e')),
      );
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  // -------------------------------- helpers --------------------------------

  Future<String> _fetchGuideToAssessor({
    required String programTitle,
    required String chapterKey,
    required String taskId,
  }) async {
    try {
      // 🔑 NORMALIZA A CHAVE DO CAPÍTULO
      final normalizedChapterKey =
      chapterKey.replaceFirst(RegExp(r'^Chapter\s+'), '').trim();

      final q = await FirebaseFirestore.instance
          .collection('training_programs')
          .where('title', isEqualTo: programTitle)
          .limit(1)
          .get();

      if (q.docs.isEmpty) return '';

      final data = q.docs.first.data();

      final chapters = (data['chapters'] as Map?)?.cast<String, dynamic>() ?? {};
      final chapter = (chapters[normalizedChapterKey] as Map?)?.cast<String, dynamic>() ?? {};
      final task = (chapter[taskId] as Map?)?.cast<String, dynamic>() ?? {};

      return (task['guideToAssessor'] ?? '').toString().trim();
    } catch (e) {
      return '';
    }
  }

  // -------------------------------- UI --------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: CustomTopBar(
        userId: FirebaseAuth.instance.currentUser?.uid,
        email: FirebaseAuth.instance.currentUser?.email,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: FutureBuilder<_SupervisorMeta>(
              future: _metaFut,
              builder: (context, snap) {
                final meta = snap.data;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supervisor Review Dashboard',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta == null
                          ? 'Loading...'
                          : 'Review and approve trainee task submissions for ${meta.vessel.isEmpty ? 'your vessel' : meta.vessel}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black.withOpacity(.62),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // KPI cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = constraints.maxWidth >= 980
                            ? 4
                            : constraints.maxWidth >= 700
                            ? 2
                            : 1;
                        const spacing = 16.0;
                        final totalSpacing = spacing * (cols - 1);
                        final cellWidth =
                            (constraints.maxWidth - totalSpacing) / cols;

                        Widget item(Widget child) =>
                            SizedBox(width: cellWidth, child: child);

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            item(
                              _KpiCard(
                                value: '$_kpiPending',
                                label: 'Pending Review',
                                icon: Icons.timer_outlined,
                                iconBg: const Color(0xFFE9F0FF),
                                iconColor: const Color(0xFF3B82F6),
                              ),
                            ),
                            item(
                              _KpiCard(
                                value: '0',
                                label: 'Approved This Week',
                                icon: Icons.verified_outlined,
                                iconBg: const Color(0xFFEAF7EE),
                                iconColor: const Color(0xFF16A34A),
                              ),
                            ),
                            item(
                              _KpiCard(
                                value: '0',
                                label: 'Returned',
                                icon: Icons.error_outline,
                                iconBg: const Color(0xFFFFF3E6),
                                iconColor: const Color(0xFFF97316),
                              ),
                            ),
                            item(
                              _KpiCard(
                                value: '$_kpiActiveTrainees',
                                label: 'Active Trainees',
                                icon: Icons.person_outline,
                                iconBg: const Color(0xFFF2ECFF),
                                iconColor: const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // main panel
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.auto_awesome,
                                  size: 18,
                                  color: Colors.black.withOpacity(.72)),
                              const SizedBox(width: 8),
                              Text(
                                'Pending Reviews',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              'Task submissions awaiting your review and digital signature',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black.withOpacity(.55),
                              ),
                            ),
                            const SizedBox(height: 14),
                            StreamBuilder<List<_PendingItem>>(
                              stream: _pendingCtrl.stream,
                              builder: (context, snap) {
                                final items =
                                    snap.data ?? const <_PendingItem>[];
                                if (items.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F9FB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'No submissions pending review.',
                                      style: TextStyle(
                                        color: Colors.black.withOpacity(.62),
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  children: [
                                    for (int i = 0; i < items.length; i++) ...[
                                      _PendingItemCard(
                                        item: items[i],
                                        submittedAtStr:
                                        _fmtDate(items[i].submittedAt),
                                        onReviewAndSign: () {
                                          final isFinal = (items[i].pendingCount ==
                                              1) &&
                                              (items[i].approvedCount +
                                                  items[i].pendingCount ==
                                                  items[i].requiredQty);
                                          _approve(items[i],
                                              isFinalApproval: isFinal);
                                        },
                                      ),
                                      if (i < items.length - 1)
                                        const SizedBox(height: 12),
                                    ]
                                  ],
                                );
                              },
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
        ),
      ),
    );
  }
}

// ─────────────────────────── MODELOS ───────────────────────────

class _SupervisorMeta {
  final String supervisorId;
  final String supervisorName;
  final String vessel;
  final String supervisorRole;

  _SupervisorMeta({
    required this.supervisorId,
    required this.supervisorName,
    required this.vessel,
    required this.supervisorRole,
  });
}

class _ReviewResult {
  final String remark;
  final String rating; // 'exceeds' | 'meets' | 'needs'

  const _ReviewResult({
    required this.remark,
    required this.rating,
  });
}

class _PendingItem {
  final String key; // traineeId::docId
  final DocumentReference<Map<String, dynamic>> ref;
  final String traineeId;
  final String traineeName;
  final String program;
  final String chapter;
  final String title;
  final String indexLabel;
  final String evidence;
  final DateTime? submittedAt;
  final int requiredQty;
  final int approvedCount;
  final int pendingCount;

  const _PendingItem({
    required this.key,
    required this.ref,
    required this.traineeId,
    required this.traineeName,
    required this.program,
    required this.chapter,
    required this.title,
    required this.indexLabel,
    required this.evidence,
    required this.submittedAt,
    required this.requiredQty,
    required this.approvedCount,
    required this.pendingCount,
  });
}

// ─────────────────────────── UI WIDGETS ───────────────────────────

class _KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _KpiCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black.withOpacity(.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingItemCard extends StatelessWidget {
  final _PendingItem item;
  final String submittedAtStr;
  final VoidCallback onReviewAndSign;

  const _PendingItemCard({
    required this.item,
    required this.submittedAtStr,
    required this.onReviewAndSign,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F0FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.indexLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF3B82F6),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Submitted',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF16A34A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text('Trainee: ${item.traineeName}',
                  style: theme.textTheme.bodySmall),
              Text(
                'Submitted: $submittedAtStr',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black.withOpacity(.58),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Evidence Provided:',
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(.06)),
            ),
            child: Text(
              item.evidence,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black.withOpacity(.70),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: onReviewAndSign,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Review & Sign'),
              ),
            ],
          )
        ],
      ),
    );
  }
}
