import 'dart:async';
import 'dart:ui';

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
    (data['userName'] ?? data['name'] ?? data['displayName'] ?? '').toString();

    return _SupervisorMeta(
      supervisorId: uid,
      supervisorName: name.isEmpty
          ? (FirebaseAuth.instance.currentUser?.email ?? 'Supervisor')
          : name,
      vessel: vessel,
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
        final roleRaw =
        (m['role'] ?? m['userRole'] ?? '').toString().toLowerCase();
        final isTrainee = roleRaw.contains('trainee');
        if (!isTrainee) continue;

        activeIds.add(d.id);
        activeTrainees++;

        // novo trainee, acopla
        if (!_declSubs.containsKey(d.id)) {
          _attachDeclarationsListener(
            traineeId: d.id,
            traineeName:
            (m['userName'] ?? m['name'] ?? m['email'] ?? 'Trainee').toString(),
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

      // limpa o que morreu
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

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Review & Sign'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trainee: ${it.traineeName}\n'
                  'Program: ${it.program}\n'
                  'Chapter: ${it.chapter}\n'
                  'Task: ${it.title}',
              style: const TextStyle(height: 1.3),
            ),
            if (isFinalApproval) ...[
              const SizedBox(height: 16),
              TextField(
                controller: remarkController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Assessing officer remark',
                  hintText: 'Ex.: The trainee exceeded expectations when describing his/her duties.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final String remark = remarkController.text.trim();
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

        final newApproved = prevApproved + 1;
        final newPending = prevPending - 1;
        final fullyApproved = (newApproved >= requiredQty) && (newPending <= 0);

        final updateData = <String, dynamic>{
          'approvedCount': newApproved,
          'pendingCount': newPending < 0 ? 0 : newPending,
          'status': fullyApproved ? 'approved' : 'declared',
          'approvedAt': FieldValue.serverTimestamp(),
          'lastApproverId': sup.supervisorId,
          'lastApproverName': sup.supervisorName,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // grava o remark só na última execução
        if (isFinalApproval && remark.isNotEmpty) {
          updateData['reviewRemark'] = remark;
        }

        tx.update(ref, updateData);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completion approved.')),
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
      body: ConstrainedBox(
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

                  // ===== KPI CARDS =====
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
                            const _KpiCard(
                              value: '0',
                              label: 'Approved This Week',
                              icon: Icons.verified_outlined,
                              iconBg: Color(0xFFE8F7EE),
                              iconColor: Color(0xFF22C55E),
                            ),
                          ),
                          item(
                            const _KpiCard(
                              value: '0',
                              label: 'Returned',
                              icon: Icons.error_outline,
                              iconBg: Color(0xFFFFF1EC),
                              iconColor: Color(0xFFF97316),
                            ),
                          ),
                          item(
                            _KpiCard(
                              value: '$_kpiActiveTrainees',
                              label: 'Active Trainees',
                              icon: Icons.person_outline,
                              iconBg: const Color(0xFFF2ECFF),
                              iconColor: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // ===== PENDING LIST =====
                  _SectionSurface(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.auto_awesome,
                              size: 18, color: Colors.black.withOpacity(.72)),
                          const SizedBox(width: 8),
                          Text('Pending Reviews',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              )),
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
                            final items = snap.data ?? const <_PendingItem>[];
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
                                      color: Colors.black.withOpacity(.62)),
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
                                      // última execução = remark
                                      final isFinal = (items[i].pendingCount == 1) &&
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
                ],
              );
            },
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
  _SupervisorMeta({
    required this.supervisorId,
    required this.supervisorName,
    required this.vessel,
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

  _PendingItem({
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

// ─────────────────────────── UI ───────────────────────────
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
    final valueStyle = Theme.of(context)
        .textTheme
        .headlineSmall
        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: valueStyle),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _SectionSurface({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
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
    final muted = Colors.black.withOpacity(.62);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IndexChip(text: item.indexLabel),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Text(item.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const _SubmittedChip(),
                  ],
                ),
              ),
              TextButton(
                onPressed: onReviewAndSign,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF2FF),
                  foregroundColor: const Color(0xFF374151),
                  shape: const StadiumBorder(),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text(
                  'Review & Sign',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Meta
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Meta(label: 'Trainee', value: item.traineeName),
              _Meta(label: 'Submitted', value: submittedAtStr),
              _Meta(label: 'Chapter', value: item.chapter),
              _Meta(
                label: 'Qty',
                value:
                '${item.approvedCount} approved · ${item.pendingCount} pending · min ${item.requiredQty}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Evidence Provided:',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: Colors.black.withOpacity(.82))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6EAF0)),
            ),
            child: Text(
              item.evidence,
              style: TextStyle(color: muted, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexChip extends StatelessWidget {
  final String text;
  const _IndexChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _SubmittedChip extends StatelessWidget {
  const _SubmittedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF2563EB)),
          SizedBox(width: 6),
          Text(
            'Submitted',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final String label;
  final String value;
  const _Meta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final muted = Colors.black.withOpacity(.62);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: muted,
            height: 1,
          ),
        ),
        Text(
          value,
          style: TextStyle(color: muted),
        ),
      ],
    );
  }
}
