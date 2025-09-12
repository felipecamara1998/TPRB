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
