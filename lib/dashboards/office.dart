import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // kIsWeb (se quiser usar em outra parte)

/// Use: Navigator.push(context, MaterialPageRoute(builder: (_) => const FleetOverviewPage()));
class FleetOverviewPage extends StatelessWidget {
  const FleetOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = Colors.grey[100];
    return Scaffold(
      backgroundColor: bg,
      appBar: const _TopBar(), // <-- Top bar funcionando com Firebase
      body: LayoutBuilder(
        builder: (context, c) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título grande da página + subtítulo
                const Text(
                  'Fleet Training Overview',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor training progress and performance across your fleet',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),

                // FILTROS em linha (iguais aos do topo, mas opcionais – pode remover)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: const [
                    _FilterChipLike(label: 'All Vessels', icon: Icons.expand_more),
                    _FilterChipLike(label: 'Last 30 days', icon: Icons.expand_more),
                    _OutlineAction(label: 'Export Report', icon: Icons.download),
                  ],
                ),
                const SizedBox(height: 16),

                // Cards resumo
                _ResponsiveRow(
                  gap: 16,
                  children: const [
                    _SummaryCard(title: 'Active Vessels', value: '4', icon: Icons.directions_boat),
                    _SummaryCard(title: 'Active Trainees', value: '14', icon: Icons.people),
                    _SummaryCard(title: 'Avg Completion', value: '53%', icon: Icons.show_chart),
                    _SummaryCard(title: 'Total Tasks', value: '491', icon: Icons.menu_book_outlined),
                  ],
                ),
                const SizedBox(height: 16),

                // Weekly progress + Task status
                _ResponsiveRow(
                  gap: 16,
                  children: [
                    _Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _SectionTitle('Weekly Training Progress'),
                            SizedBox(height: 8),
                            _WeekProgressRow(label: 'Jan Week 1', completed: 24, inProgress: 18, total: 42),
                            _WeekProgressRow(label: 'Jan Week 2', completed: 31, inProgress: 22, total: 53),
                            _WeekProgressRow(label: 'Jan Week 3', completed: 28, inProgress: 19, total: 47),
                            _WeekProgressRow(label: 'Current',   completed: 35, inProgress: 25, total: 60),
                          ],
                        ),
                      ),
                    ),
                    _Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _SectionTitle('Fleet Task Status'),
                            SizedBox(height: 8),
                            _LegendItem(label: 'Completed', value: 156, color: Colors.green),
                            _LegendItem(label: 'In Progress', value: 89, color: Colors.blue),
                            _LegendItem(label: 'Not Started', value: 234, color: Colors.grey),
                            _LegendItem(label: 'Overdue', value: 12, color: Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Vessel Progress Overview
                const _SectionTitle('Vessel Progress Overview'),
                const SizedBox(height: 8),
                _Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: const [
                        _VesselRow(name: 'Flumar Brasil', imo: '1234567', trainees: 3, completion: 45, barColor: Colors.orange),
                        Divider(height: 24),
                        _VesselRow(name: 'Bow Flora', imo: '7654321', trainees: 5, completion: 67, barColor: Colors.green),
                        Divider(height: 24),
                        _VesselRow(name: 'Ocean Pioneer', imo: '9876543', trainees: 2, completion: 23, barColor: Colors.redAccent),
                        Divider(height: 24),
                        _VesselRow(name: 'Maritime Express', imo: '1122334', trainees: 4, completion: 78, barColor: Colors.green),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Chapter Performance Analytics
                _Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _SectionTitle('Chapter Performance Analytics'),
                        SizedBox(height: 12),
                        _ChapterRow(title: 'Chapter 1: Safety Basics', completion: 78, avgDays: 14),
                        _ChapterRow(title: 'Chapter 2: Navigation', completion: 45, avgDays: 21),
                        _ChapterRow(title: 'Chapter 3: Cargo Operations', completion: 32, avgDays: 28),
                        _ChapterRow(title: 'Chapter 4: Engineering', completion: 18, avgDays: 35),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ============================== TOP BAR ============================== */

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0.5,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: preferredSize.height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Logo + título/subtítulo
              const _LogoAndTitle(),
              const Spacer(),
              // Filtros + Export
              const _FilterChipLike(label: 'All Vessels', icon: Icons.expand_more),
              const SizedBox(width: 8),
              const _FilterChipLike(label: 'Last 30 days', icon: Icons.expand_more),
              const SizedBox(width: 8),
              const _OutlineAction(label: 'Export Report', icon: Icons.download),
              const SizedBox(width: 16),
              // Usuário (Firebase) com mesmo layout da sua barra
              const _OfficeUserFromFirebase(),
              // Logout
              _OutlineAction(
                label: 'Logout',
                icon: Icons.logout,
                onTap: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                  } catch (_) {}
                  if (context.mounted) {
                    // redireciona para login; ajuste a rota se necessário
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoAndTitle extends StatelessWidget {
  const _LogoAndTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.directions_boat_filled, color: Color(0xFF1A73E8)),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('TPRB', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Training Performance Record Book', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String initials;
  const _UserAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF0F172A),
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FilterChipLike extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _FilterChipLike({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap ?? () {},
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Text(label),
            const SizedBox(width: 6),
            Icon(icon, size: 18),
          ],
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _OutlineAction({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap ?? () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        side: BorderSide(color: Colors.grey[300]!),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 36),
      ),
    );
  }
}

/* ========================== BUILDING BLOCKS ========================== */

class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const _ResponsiveRow({required this.children, this.gap = 12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        int columns = 1;
        if (maxW >= 1200) columns = children.length;
        else if (maxW >= 900) columns = (children.length / 2).ceil();
        else if (maxW >= 700) columns = 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map((w) => SizedBox(
            width: (maxW - (gap * (columns - 1))) / columns,
            child: w,
          ))
              .toList(),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }
}

/* ----------------------------- Summary ------------------------------- */

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _SummaryCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Colors.blue.withOpacity(.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(title, style: TextStyle(color: Colors.grey[700])),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------- Weekly Progress --------------------------- */

class _WeekProgressRow extends StatelessWidget {
  final String label;
  final int completed;
  final int inProgress;
  final int total;

  const _WeekProgressRow({
    required this.label,
    required this.completed,
    required this.inProgress,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final completedRatio = completed / total;
    final inProgressRatio = inProgress / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
            Text('$total total', style: TextStyle(color: Colors.grey[700])),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(flex: (completedRatio * 1000).round(), child: Container(color: Colors.green)),
                Expanded(flex: (inProgressRatio * 1000).round(), child: Container(color: Colors.blue)),
                Expanded(flex: (1000 - (completedRatio + inProgressRatio) * 1000).round(), child: Container(color: Colors.grey[200])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('$completed completed • $inProgress in progress', style: TextStyle(color: Colors.grey[700])),
      ]),
    );
  }
}

/* ------------------------- Task Status legend ------------------------ */

class _LegendItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _LegendItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$value'),
        ],
      ),
    );
  }
}

/* --------------------------- Vessels block --------------------------- */

class _VesselRow extends StatelessWidget {
  final String name;
  final String imo;
  final int trainees;
  final int completion;
  final Color barColor;

  const _VesselRow({
    required this.name,
    required this.imo,
    required this.trainees,
    required this.completion,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = completion >= 60 ? Colors.green[50] : (completion >= 30 ? Colors.orange[50] : Colors.red[50]);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  _Pill('IMO $imo'),
                  const SizedBox(width: 10),
                  _Pill('$completion% Complete', bg: badgeColor, txt: Colors.black87),
                ]),
                const SizedBox(height: 6),
                Text('$trainees trainees • Last updated: 14/01/2024', style: TextStyle(color: Colors.grey[700])),
              ]),
            ),
            Wrap(spacing: 8, children: [
              TextButton.icon(onPressed: () {}, icon: const Icon(Icons.remove_red_eye), label: const Text('View Details')),
              TextButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text('Export')),
            ]),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: completion / 100,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            color: barColor,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color? bg;
  final Color? txt;
  const _Pill(this.text, {this.bg, this.txt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg ?? Colors.grey[200], borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 12, color: txt ?? Colors.black87)),
    );
  }
}

/* ----------------------------- Chapters ------------------------------ */

class _ChapterRow extends StatelessWidget {
  final String title;
  final int completion;
  final int avgDays;

  const _ChapterRow({required this.title, required this.completion, required this.avgDays});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: completion / 100,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text('$completion% fleet completion   ~$avgDays days avg', style: TextStyle(color: Colors.grey[700])),
      ]),
    );
  }
}

/* =================== FIREBASE: Usuário na Top Bar =================== */

class _OfficeUserFromFirebase extends StatelessWidget {
  const _OfficeUserFromFirebase();

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final uid = auth.currentUser?.uid;
    final email = auth.currentUser?.email;

    if (uid != null) {
      final docStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docStream,
        builder: (context, snap) {
          final data = snap.data?.data() ?? <String, dynamic>{};
          final name   = _pickName(data, email);
          final role   = _pickRole(data);
          final office = _pickOffice(data);
          final inits  = _pickInitials(data, name);
          return _UserChip(name: name, role: role, office: office, initials: inits);
        },
      );
    } else if (email != null) {
      final qStream = FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .snapshots();

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: qStream,
        builder: (context, snap) {
          final data = (snap.data?.docs.isNotEmpty ?? false)
              ? snap.data!.docs.first.data()
              : <String, dynamic>{};
          final name   = _pickName(data, email);
          final role   = _pickRole(data);
          final office = _pickOffice(data);
          final inits  = _pickInitials(data, name);
          return _UserChip(name: name, role: role, office: office, initials: inits);
        },
      );
    } else {
      return const _UserChip(name: 'User', role: '', office: '', initials: 'U');
    }
  }

  static String _pickName(Map<String, dynamic> data, String? email) {
    final v = (data['userName'] ?? data['name'] ?? email ?? 'User').toString().trim();
    return v.isEmpty ? 'User' : v;
  }

  static String _pickRole(Map<String, dynamic> data) {
    return (data['userRole'] ?? data['role'] ?? '').toString().trim();
  }

  static String _pickOffice(Map<String, dynamic> data) {
    return (data['vessel'] ?? data['office'] ?? '').toString().trim();
  }

  static String _pickInitials(Map<String, dynamic> data, String name) {
    final saved = (data['initials'] ?? '').toString().trim();
    if (saved.isNotEmpty) return saved.toUpperCase();
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    final f = parts.first.isNotEmpty ? parts.first[0] : '';
    final l = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    final s = (f + l).toUpperCase();
    return s.isEmpty ? 'U' : s;
  }
}

class _UserChip extends StatelessWidget {
  final String name;
  final String role;
  final String office;
  final String initials;

  const _UserChip({
    required this.name,
    required this.role,
    required this.office,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Texto (nome/cargo/escritório) alinhado à direita como no layout atual
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            if (role.isNotEmpty)
              Text(role, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (office.isNotEmpty)
              Text(office, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(width: 10),
        _UserAvatar(initials: initials),
        const SizedBox(width: 8),
      ],
    );
  }
}
