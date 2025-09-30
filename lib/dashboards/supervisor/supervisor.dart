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
  State<OfficerReviewDashboardPage> createState() => _OfficerReviewDashboardPageState();
}

class _OfficerReviewDashboardPageState extends State<OfficerReviewDashboardPage> {
  // --- Meta do supervisor (nome, vessel, uid)
  Future<_SupervisorMeta>? _metaFut;

  // --- Stream dos pendentes para a UI
  final _pendingCtrl = StreamController<List<_PendingItem>>.broadcast();

  // --- Subscriptions vivas
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _declSubs = {};

  // --- Acúmulo/dedup dos itens pendentes
  final Map<String, _PendingItem> _itemsByKey = {};

  // --- KPIs dinâmicos
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

  // ------------------------------
  // BOOTSTRAP: carrega meta e liga os listeners
  // ------------------------------
  void _bootstrap() {
    _metaFut = _loadMeta().then((meta) {
      _listenTraineesAndDeclarations(meta);
      return meta;
    });
    setState(() {});
  }

  Future<_SupervisorMeta> _loadMeta() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('No logged user');
    }
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data() ?? {};
    final vessel = (data['vessel'] ?? data['vesselName'] ?? '').toString();
    final name = (data['userName'] ?? data['name'] ?? data['displayName'] ?? '').toString();
    return _SupervisorMeta(
      supervisorId: uid,
      supervisorName: name.isEmpty ? (FirebaseAuth.instance.currentUser?.email ?? 'Supervisor') : name,
      vessel: vessel,
    );
  }

  // Escuta a lista de trainees do mesmo vessel, e para cada um, escuta as declarações pendentes
  void _listenTraineesAndDeclarations(_SupervisorMeta meta) {
    // 1) Quem é trainee no mesmo vessel?
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
        final roleRaw = (m['role'] ?? m['userRole'] ?? '').toString().toLowerCase();
        final isTrainee = roleRaw.contains('trainee');
        if (!isTrainee) continue;

        activeIds.add(d.id);
        activeTrainees++;

        if (!_declSubs.containsKey(d.id)) {
          // Novo trainee: acoplar listener nas declarações pendentes
          _attachDeclarationsListener(
            traineeId: d.id,
            traineeName: (m['userName'] ?? m['name'] ?? m['email'] ?? 'Trainee').toString(),
          );
        }
      }

      // Remover listeners de trainees que saíram
      final toRemove = _declSubs.keys.where((id) => !activeIds.contains(id)).toList();
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
        final key = '$traineeId::${d.id}'; // chave global para dedup

        final declaredAt = (m['declaredAt'] as Timestamp?)?.toDate();
        final chapterTitle = (m['chapterTitle'] ?? '').toString();
        final programTitle = (m['programTitle'] ?? '').toString();
        final taskTitle = (m['taskTitle'] ?? '').toString();
        final taskId = (m['taskId'] ?? '').toString(); // ex.: "1.1" (se for esse o id)

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
          // referência do doc para aprovar
          ref: d.reference,
          // dados de exibição
          traineeId: traineeId,
          traineeName: traineeName,
          submittedAt: declaredAt,
          chapter: chapterTitle,
          program: programTitle,
          title: taskTitle,
          indexLabel: taskId.isEmpty ? '—' : taskId,
          evidence: evidence.isEmpty ? '—' : evidence,
          // contadores
          requiredQty: requiredQty,
          approvedCount: approvedCount,
          pendingCount: pendingCount,
        );

        aliveKeys.add(key);
      }

      // Remover qualquer item deste trainee que não veio no snapshot atual
      _itemsByKey.removeWhere((k, _) => k.startsWith('$traineeId::') && !aliveKeys.contains(k));

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

  // ------------------------------
  // Aprovar (Review & Sign)
  // ------------------------------
  Future<void> _approve(_PendingItem it) async {
    final sup = await _metaFut!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Review & Sign'),
        content: Text(
          'Approve this completion?\n\n'
              'Trainee: ${it.traineeName}\n'
              'Program: ${it.program}\n'
              'Chapter: ${it.chapter}\n'
              'Task: ${it.title}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );
    if (ok != true) return;

    final ref = it.ref;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw StateError('Declaration no longer exists.');
        }
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

        if (prevPending <= 0) {
          // nada para aprovar
          return;
        }

        final newApproved = prevApproved + 1;
        final newPending = prevPending - 1;
        final fullyApproved = (newApproved >= requiredQty) && (newPending <= 0);

        tx.update(ref, {
          'approvedCount': newApproved,
          'pendingCount': newPending < 0 ? 0 : newPending,
          'status': fullyApproved ? 'approved' : 'declared',
          'approvedAt': FieldValue.serverTimestamp(),
          'lastApproverId': sup.supervisorId,
          'lastApproverName': sup.supervisorName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
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
                  Text('Supervisor Review Dashboard',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.2,
                      )),
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

                  // ==== KPI CARDS ====
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 500;

                      if (isMobile) {
                        // labels CURTAS para evitar corte: Pending / Approved / Returned / Active
                        return Row(
                          children: [
                            Expanded(
                              child: _KpiMiniCard(
                                value: '$_kpiPending',
                                label: 'Pending',
                                icon: Icons.timer_outlined,
                                iconBg: const Color(0xFFE9F0FF),
                                iconColor: const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: _KpiMiniCard(
                                value: '0',
                                label: 'Approved',
                                icon: Icons.verified_outlined,
                                iconBg: Color(0xFFE8F7EE),
                                iconColor: Color(0xFF22C55E),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: _KpiMiniCard(
                                value: '0',
                                label: 'Returned',
                                icon: Icons.error_outline,
                                iconBg: Color(0xFFFFF1EC),
                                iconColor: Color(0xFFF97316),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _KpiMiniCard(
                                value: '$_kpiActiveTrainees',
                                label: 'Active',
                                icon: Icons.person_outline,
                                iconBg: const Color(0xFFF2ECFF),
                                iconColor: const Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        );
                      }

                      // --- DESKTOP/TABLET: mantém sua grade original de cards grandes ---
                      final cols = constraints.maxWidth >= 980
                          ? 4
                          : constraints.maxWidth >= 700
                          ? 2
                          : 1;

                      const spacing = 16.0;
                      final totalSpacing = spacing * (cols - 1);
                      final cellWidth = (constraints.maxWidth - totalSpacing) / cols;

                      Widget item(Widget child) => SizedBox(width: cellWidth, child: child);

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          item(_KpiCard(
                            value: '$_kpiPending',
                            label: 'Pending Review',
                            icon: Icons.timer_outlined,
                            iconBg: const Color(0xFFE9F0FF),
                            iconColor: const Color(0xFF3B82F6),
                          )),
                          item(const _KpiCard(
                            value: '0',
                            label: 'Approved This Week',
                            icon: Icons.verified_outlined,
                            iconBg: Color(0xFFE8F7EE),
                            iconColor: Color(0xFF22C55E),
                          )),
                          item(const _KpiCard(
                            value: '0',
                            label: 'Returned',
                            icon: Icons.error_outline,
                            iconBg: Color(0xFFFFF1EC),
                            iconColor: Color(0xFFF97316),
                          )),
                          item(_KpiCard(
                            value: '$_kpiActiveTrainees',
                            label: 'Active Trainees',
                            icon: Icons.person_outline,
                            iconBg: const Color(0xFFF2ECFF),
                            iconColor: const Color(0xFF8B5CF6),
                          )),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // ========= Pending Reviews =========
                  _SectionSurface(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.auto_awesome, size: 18, color: Colors.black.withOpacity(.72)),
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
                                  style: TextStyle(color: Colors.black.withOpacity(.62)),
                                ),
                              );
                            }

                            return Column(
                              children: [
                                for (int i = 0; i < items.length; i++) ...[
                                  _PendingItemCard(
                                    item: items[i],
                                    submittedAtStr: _fmtDate(items[i].submittedAt),
                                    onReviewAndSign: () => _approve(items[i]),
                                  ),
                                  if (i < items.length - 1) const SizedBox(height: 12),
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

// ─────────────────────────── META ───────────────────────────

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

// ─────────────────────────── MODELO PENDENTE ───────────────────────────

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

// ─────────────────────────── UI COMPONENTES ───────────────────────────

class _KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  /// NOVO: quando `compact == true`, renderiza um quadradinho (ícone + número)
  final bool compact;

  /// NOVO: tamanho do lado no modo compacto (default 76)
  final double size;

  const _KpiCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.compact = false,
    this.size = 76,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // ---- MODO COMPACTO (ícone + contador) ----
      return Tooltip(
        message: label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EBF2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ---- MODO PADRÃO (o seu cartão grande) ----
    final valueStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -.2,
    );

    return _Card(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: valueStyle),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: const BorderSide(color: Color(0xFFE6EBF2)),
                    foregroundColor: const Color(0xFF374151),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
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

class _KpiMiniCard extends StatelessWidget {
  final String value;
  final String label; // aparece 1 linha (curta) + tooltip completo
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _KpiMiniCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EBF2)),
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            // legenda curta, 1 linha, sem quebrar layout
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BoxBorder? border;
  final double? height;

  const _Card({
    required this.child,
    this.padding,
    this.color,
    this.border,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: border,
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PillButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: const Color(0xFFEFF2FF),
        foregroundColor: const Color(0xFF374151),
        shape: const StadiumBorder(),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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

    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: const Color(0xFFF7F9FB),
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
              _PillButton(
                label: 'Review & Sign',
                onPressed: onReviewAndSign,
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
                  fontWeight: FontWeight.w800,
                  color: Colors.black.withOpacity(.82))),
          const SizedBox(height: 6),
          _Card(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE6EAF0)),
            padding: const EdgeInsets.all(12),
            child: Text(
              item.evidence,
              style: TextStyle(color: Colors.black.withOpacity(.8), height: 1.3),
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
          Text('Submitted',
              style: TextStyle(
                  color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
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
        Text('$label: ',
            style:
            TextStyle(fontWeight: FontWeight.w700, color: muted, height: 1)),
        Text(value, style: TextStyle(color: muted)),
      ],
    );
  }
}
