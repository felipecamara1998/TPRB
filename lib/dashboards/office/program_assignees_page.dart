import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tprb/dashboards/seafarer/trainee/program_tasks_page.dart';

class ProgramAssigneesPage extends StatelessWidget {
  const ProgramAssigneesPage({
    super.key,
    required this.campaignId,
    required this.programId,
    required this.programTitle,
  });

  final String campaignId;
  final String programId;
  final String programTitle;

  Future<List<_UserItem>> _loadUsers() async {
    final campSnap = await FirebaseFirestore.instance
        .collection('campaigns')
        .doc(campaignId)
        .get();

    final data = campSnap.data() ?? {};
    final List<dynamic> ids = (data['targetUserIds'] ?? []) as List<dynamic>;
    final userIds = ids.map((e) => e.toString()).toList();

    // Busca direta por docId (funciona para lista > 10 ids sem limite do whereIn)
    final users = await Future.wait(userIds.map((uid) async {
      final u = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final d = u.data() ?? {};
      return _UserItem(
        uid: u.id,
        name: (d['userName'] ?? d['name'] ?? 'Sem nome') as String,
        email: (d['email'] ?? '') as String,
      );
    }));

    // Ordena por nome
    users.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Assigned — $programTitle')),
      body: FutureBuilder<List<_UserItem>>(
        future: _loadUsers(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          final users = snap.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('Nenhum usuário definido em targetUserIds.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProgramTasksPage(
                          programTitle: programTitle,
                          programId: programId,
                          userId: u.uid,
                          readOnly: true, // monitor
                        ),
                      ),
                    );
                  },
                  child: Text(
                    u.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                subtitle: u.email.isEmpty ? null : Text(u.email),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProgramTasksPage(
                          programTitle: programTitle,
                          programId: programId,
                          userId: u.uid,
                          readOnly: true,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _UserItem {
  _UserItem({required this.uid, required this.name, required this.email});
  final String uid;
  final String name;
  final String email;
}
