import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Ajuste o import abaixo conforme seu projeto:
import 'package:tprb/dashboards/office/admin/new_user.dart';
import 'package:tprb/widgets/widgets.dart'; // para CardBox

class VesselCrewPage extends StatelessWidget {
  const VesselCrewPage({super.key, required this.vesselName});

  final String vesselName;

  /// Ordem desejada para os cargos a bordo
  static const List<String> roleOrder = [
    'Master',
    'Chief Officer',
    'Second Officer',
    'Third Officer',
    'Chief Engineer',
    'Second Engineer',
    'Third Engineer',
    'ETO',
    'Bosun',
    'AB',
    'Oiler',
    'Cadet (Deck)',
    'Cadet (Engine)',
  ];

  /// Retorna índice na hierarquia; 999 se não conhecido
  static int roleOrderIndex(String? role) {
    final idx = roleOrder.indexOf(role ?? '');
    return idx < 0 ? 999 : idx;
    // mantendo "desconhecidos" no final
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(vesselName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          CardBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho
                  Row(
                    children: [
                      const Icon(Icons.groups_outlined, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Crew assigned',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Users on board — $vesselName',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  /// Lista de tripulantes — compatível com schema antigo e novo.
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    // Pega todos os usuários e filtra no cliente para compatibilidade.
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Error loading crew: ${snap.error}'),
                        );
                      }

                      final all = snap.data?.docs ?? const [];

                      // Compatibilidade:
                      // - tipo: userType == 'seafarer' OU role == 'seafarer' (modelo antigo)
                      // - navio: vesselName == <nome> OU vessel == <nome> (modelo antigo)
                      final crew = all.where((doc) {
                        final d = doc.data();
                        final type =
                        (d['userType'] ?? d['role'] ?? '').toString().toLowerCase();
                        final vessel =
                        (d['vesselName'] ?? d['vessel'] ?? '').toString();
                        final isSeafarer = type == 'seafarer';
                        final sameVessel = vessel == vesselName;
                        return isSeafarer && sameVessel;
                      }).toList();

                      if (crew.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No crew assigned to this vessel.'),
                        );
                      }

                      // Ordena por hierarquia (roleOrder) e depois por nome
                      crew.sort((a, b) {
                        final da = a.data();
                        final db = b.data();

                        // cargo preferencialmente em 'role'; se não bater, tenta 'userRole'
                        String cargoA = (da['role'] ?? '').toString();
                        if (!roleOrder.contains(cargoA)) {
                          cargoA = (da['userRole'] ?? '').toString();
                        }
                        String cargoB = (db['role'] ?? '').toString();
                        if (!roleOrder.contains(cargoB)) {
                          cargoB = (db['userRole'] ?? '').toString();
                        }

                        final ia = roleOrderIndex(cargoA);
                        final ib = roleOrderIndex(cargoB);
                        if (ia != ib) return ia.compareTo(ib);

                        final na = (da['userName'] ?? da['name'] ?? '').toString().toLowerCase();
                        final nb = (db['userName'] ?? db['name'] ?? '').toString().toLowerCase();
                        return na.compareTo(nb);
                      });

                      return Column(
                        children: [
                          for (final d in crew)
                            _CrewTile(
                              id: d.id,
                              email: (d.data()['email'] ?? '').toString(),
                              name: (d.data()['userName'] ?? d.data()['name'] ?? '').toString(),
                              // exibe cargo: 'role' se presente e válido; senão cai para 'userRole'
                              role: (() {
                                final r = (d.data()['role'] ?? '').toString();
                                if (roleOrder.contains(r)) return r;
                                final alt = (d.data()['userRole'] ?? '').toString();
                                return alt.isEmpty ? r : alt;
                              })(),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewTile extends StatelessWidget {
  const _CrewTile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  final String id;
  final String email;
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final displayName = name.isEmpty ? email.split('@').first : name;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFCFD8DC),
            radius: 20,
            child: Text(
              (displayName.isNotEmpty ? displayName[0] : email[0]).toUpperCase(),
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(email, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // badge do cargo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.withOpacity(0.25)),
            ),
            child: Text(
              role.isEmpty ? '—' : role,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo),
            ),
          ),
          const SizedBox(width: 8),
          // botão Edit com o mesmo comportamento da aba Users
          IconButton.outlined(
            tooltip: 'Edit user',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => NewUserPage(userId: id)),
              );
            },
          ),
        ],
      ),
    );
  }
}
