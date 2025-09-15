import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? userId;        // de preferência, UID
  final String? email;         // fallback por e-mail
  final VoidCallback? onLogout;
  final PreferredSizeWidget? bottom; // <<< NOVO: suporte a TabBar/aba inferior

  const CustomTopBar({
    super.key,
    this.userId,
    this.email,
    this.onLogout,
    this.bottom,
  });

  // soma a altura do bottom ao AppBar padrão
  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  Stream<Map<String, dynamic>?> _userStream() {
    final col = FirebaseFirestore.instance.collection('users');

    if (userId != null && userId!.isNotEmpty) {
      return col.doc(userId).snapshots().map((d) => d.data());
    }
    if (email != null && email!.isNotEmpty) {
      return col.where('email', isEqualTo: email).limit(1).snapshots().map(
            (qs) => qs.docs.isEmpty ? null : qs.docs.first.data(),
      );
    }
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      return col.doc(current.uid).snapshots().map((d) => d.data());
    }
    return const Stream<Map<String, dynamic>?>.empty();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _userStream(),
      builder: (context, snap) {
        final data = snap.data ?? const {};
        final userName = (data['userName'] ?? data['name'] ?? '') as String;
        final userRole = (data['userRole'] ?? data['role'] ?? '') as String;
        final vessel   = (data['vessel'] ?? '') as String;
        final initials = _initials(
          data['initials'] as String?,
          userName,
          email ?? FirebaseAuth.instance.currentUser?.email,
        );

        final subtitle = [
          if (userRole.isNotEmpty) userRole,
          if (vessel.isNotEmpty) vessel,
        ].join(' • ');

        return AppBar(
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
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Training Performance Record Book',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    userName.isNotEmpty ? userName : (email ?? 'User'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.isNotEmpty ? subtitle : '—',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFDDE6F3),
                child: Text(initials, style: const TextStyle(color: Colors.black87)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onLogout ?? () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    print('Logout');
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
              ),
              const SizedBox(width: 8),
            ],
          ],
          bottom: bottom, // <<< usa o bottom recebido
        );
      },
    );
  }

  static String _initials(String? fromDb, String name, String? mail) {
    if (fromDb != null && fromDb.trim().isNotEmpty) return fromDb.trim();
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) return (words.first[0] + words.last[0]).toUpperCase();
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    if (mail != null && mail.isNotEmpty) return mail.substring(0, 1).toUpperCase();
    return '?';
  }
}

const double kAdminMaxContentWidth = 1180;

/// Builder de TabBar com largura máxima e (opcional) badges dinâmicos de contagem.
/// Você pode substituir os streams de exemplo pelos seus streams/queries existentes.
class AdminBottomTabs extends StatelessWidget
    implements PreferredSizeWidget {
  final TabController controller;

  /// Streams (opcionais) para mostrar contagens por aba (ex.: Users, Vessels…)
  final Stream<int>? editionsCount;
  final Stream<int>? vesselsCount;
  final Stream<int>? usersCount;

  const AdminBottomTabs({
    super.key,
    required this.controller,
    this.editionsCount,
    this.vesselsCount,
    this.usersCount,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kAdminMaxContentWidth),
          child: TabBar(
            controller: controller,
            isScrollable: true,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.black87,
            indicatorColor: Colors.indigo,
            tabs: [
              _TabWithCount(label: 'TPRB Editions', countStream: editionsCount),
              _TabWithCount(label: 'Vessels',        countStream: vesselsCount),
              _TabWithCount(label: 'Users',          countStream: usersCount),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aba com badge de contagem (se houver stream); caso contrário, mostra só o texto.
class _TabWithCount extends StatelessWidget {
  final String label;
  final Stream<int>? countStream;

  const _TabWithCount({required this.label, this.countStream});

  @override
  Widget build(BuildContext context) {
    if (countStream == null) return Tab(text: label);

    return Tab(
      child: StreamBuilder<int>(
        stream: countStream,
        builder: (context, snap) {
          final count = snap.data;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ]
            ],
          );
        },
      ),
    );
  }
}

/// UTILIDADE simples: converte uma Query em stream de contagem.
/// Pode trocar por sua própria fonte de dados/Provider.
Stream<int> countOf(Query query) =>
    query.snapshots().map((s) => s.size);

/* ===================== SUMMARY CARDS FOR OFFICE USER(LIVE) ===================== */

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveCountCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Query<Map<String, dynamic>> query;

  const _LiveCountCard({
    required this.title,
    required this.icon,
    required this.query,
  });

  @override
  State<_LiveCountCard> createState() => _LiveCountCardState();
}

class _LiveCountCardState extends State<_LiveCountCard> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _SummaryCard(title: widget.title, value: '—', icon: widget.icon);
        }
        final count = snap.data?.docs.length ?? 0;
        return _SummaryCard(title: widget.title, value: '$count', icon: widget.icon);
      },
    );
  }
}

class _AvgCompletionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Query<Map<String, dynamic>> assignmentsQuery;

  const _AvgCompletionCard({
    required this.title,
    required this.icon,
    required this.assignmentsQuery,
  });

  @override
  State<_AvgCompletionCard> createState() => _AvgCompletionCardState();
}

class _AvgCompletionCardState extends State<_AvgCompletionCard> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.assignmentsQuery.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _SummaryCard(title: widget.title, value: '—', icon: widget.icon);
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _SummaryCard(title: widget.title, value: '0%', icon: widget.icon);
        }
        int completed = 0;
        for (final d in docs) {
          final s = (d.data()['status'] ?? 'pending').toString();
          if (s == 'completed') completed++;
        }
        final pct = ((completed / docs.length) * 100).round();
        return _SummaryCard(title: widget.title, value: '$pct%', icon: widget.icon);
      },
    );
  }
}

class _TotalTasksCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Query<Map<String, dynamic>> programsQuery;

  const _TotalTasksCard({
    required this.title,
    required this.icon,
    required this.programsQuery,
  });

  @override
  State<_TotalTasksCard> createState() => _TotalTasksCardState();

  static int _countTasksDeep(dynamic node) {
    if (node == null) return 0;
    if (node is Map) {
      final map = node as Map;
      // Se for um "nó tarefa" (possui 'task'), usa qty se houver, senão conta como 1
      if (map.containsKey('task')) {
        final qty = map['qty'];
        if (qty is num) return qty.toInt();
        return 1;
      }
      // Caso contrário, soma recursivamente os filhos
      int sum = 0;
      for (final v in map.values) {
        sum += _countTasksDeep(v);
      }
      return sum;
    }
    // Qualquer outro tipo não conta
    return 0;
  }
}

class _TotalTasksCardState extends State<_TotalTasksCard> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.programsQuery.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _SummaryCard(title: widget.title, value: '—', icon: widget.icon);
        }
        final docs = snap.data?.docs ?? const [];
        int totalTasks = 0;
        for (final d in docs) {
          totalTasks += _TotalTasksCard._countTasksDeep(d.data()['chapters']);
        }
        return _SummaryCard(title: widget.title, value: '$totalTasks', icon: widget.icon);
      },
    );
  }
}

// == PUBLIC WRAPPERS (expor as versões privadas para outros arquivos) ==

// Expor o _Card
class CardBox extends StatelessWidget {
  final Widget child;
  const CardBox({super.key, required this.child});
  @override
  Widget build(BuildContext context) => _Card(child: child);
}

// Expor _LiveCountCard
class LiveCountCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Query<Map<String, dynamic>> query;
  const LiveCountCard({
    super.key,
    required this.title,
    required this.icon,
    required this.query,
  });
  @override
  Widget build(BuildContext context) =>
      _LiveCountCard(title: title, icon: icon, query: query);
}

// Expor _AvgCompletionCard
class AvgCompletionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Query<Map<String, dynamic>> assignmentsQuery;
  const AvgCompletionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.assignmentsQuery,
  });
  @override
  Widget build(BuildContext context) =>
      _AvgCompletionCard(title: title, icon: icon, assignmentsQuery: assignmentsQuery);
}

// Expor _TotalTasksCard
class TotalTasksCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Query<Map<String, dynamic>> programsQuery;
  const TotalTasksCard({
    super.key,
    required this.title,
    required this.icon,
    required this.programsQuery,
  });
  @override
  Widget build(BuildContext context) =>
      _TotalTasksCard(title: title, icon: icon, programsQuery: programsQuery);
}


