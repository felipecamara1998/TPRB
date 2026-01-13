import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tprb/dashboards/seafarer/trainee/program_tasks_page.dart';

// ✅ Ajuste o import conforme seu projeto
import 'package:tprb/dashboards/office/create_campaign_page.dart';

class ProgramAssigneesPage extends StatefulWidget {
  const ProgramAssigneesPage({
    super.key,
    required this.campaignId,
    required this.programId,
    required this.programTitle,
  });

  final String campaignId;
  final String programId;
  final String programTitle;

  @override
  State<ProgramAssigneesPage> createState() => _ProgramAssigneesPageState();
}

class _ProgramAssigneesPageState extends State<ProgramAssigneesPage> {
  Future<_CampaignMeta>? _campaignMetaFut;
  Future<List<_UserItem>>? _usersFut;
  Future<int>? _programTotalQtyFut;

  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _campaignMetaFut = _loadCampaignMeta();
    _usersFut = _loadUsers();
    _programTotalQtyFut = _loadProgramTotalRequiredQty();
  }

  // ───────────────────────── Campaign meta ─────────────────────────

  Future<_CampaignMeta> _loadCampaignMeta() async {
    final snap = await FirebaseFirestore.instance
        .collection('campaigns')
        .doc(widget.campaignId)
        .get();

    final d = snap.data() ?? {};
    return _CampaignMeta(name: (d['name'] ?? '').toString());
  }

  // ───────────────────────── Users ─────────────────────────

  Future<List<_UserItem>> _loadUsers() async {
    final campSnap = await FirebaseFirestore.instance
        .collection('campaigns')
        .doc(widget.campaignId)
        .get();

    final data = campSnap.data() ?? {};
    final List<dynamic> ids = (data['targetUserIds'] ?? []) as List<dynamic>;
    final userIds = ids.map((e) => e.toString()).toList();

    final users = await Future.wait(userIds.map((uid) async {
      final u = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final d = u.data() ?? {};
      return _UserItem(
        uid: u.id,
        name: (d['userName'] ?? d['displayName'] ?? d['name'] ?? 'Unnamed').toString(),
        email: (d['email'] ?? '').toString(),
        role: (d['userRole'] ?? d['role'] ?? '').toString(),
        vessel: (d['vessel'] ?? '').toString(),
      );
    }));

    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  // ───────────────────────── Program total qty ─────────────────────────

  Future<int> _loadProgramTotalRequiredQty() async {
    final snap = await FirebaseFirestore.instance
        .collection('training_programs')
        .doc(widget.programId)
        .get();

    if (!snap.exists) return 0;

    final data = snap.data()!;
    final chapters = data['chapters'];

    if (chapters is! Map<String, dynamic>) return 0;

    int total = 0;
    for (final chapter in chapters.values) {
      if (chapter is Map<String, dynamic>) {
        for (final task in chapter.values) {
          if (task is Map<String, dynamic>) {
            final qty = task['qty'];
            if (qty is num) total += qty.toInt();
          }
        }
      }
    }
    return total;
  }

  // ───────────────────────── Approved qty per user ─────────────────────────

  Future<int> _loadUserApprovedQty(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('task_declarations')
        .where('programId', isEqualTo: widget.programId)
        .get();

    int approved = 0;
    for (final doc in snap.docs) {
      final d = doc.data();
      final status = (d['status'] ?? '').toString().toLowerCase();

      final num? approvedQty = d['approvedQty'] as num?;
      final num? approvedCount = d['approvedCount'] as num?;

      if (approvedQty != null) {
        approved += approvedQty.toInt();
      } else if (approvedCount != null) {
        approved += approvedCount.toInt();
      } else if (status == 'approved' || d['approved'] == true) {
        approved += 1;
      }
    }
    return approved;
  }

  // ───────────────────────── Navigation ─────────────────────────

  Future<void> _openAddUsersToExistingCampaign(_CampaignMeta meta) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateCampaignPage(
          existingCampaignId: widget.campaignId,
          existingCampaignName: meta.name.isEmpty ? null : meta.name,
          initialProgramId: widget.programId,
          initialProgramTitle: widget.programTitle,
        ),
      ),
    );

    if (!mounted) return;
    setState(_reload);
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CampaignMeta>(
      future: _campaignMetaFut,
      builder: (context, metaSnap) {
        final meta = metaSnap.data ?? const _CampaignMeta(name: '');

        return Scaffold(
          appBar: AppBar(
            title: Text('Assigned — ${widget.programTitle}'),
            actions: [
              IconButton(
                tooltip: 'Add users to this campaign',
                icon: const Icon(Icons.person_add_alt_1),
                onPressed: metaSnap.connectionState == ConnectionState.waiting
                    ? null
                    : () => _openAddUsersToExistingCampaign(meta),
              ),
            ],
          ),
          body: Column(
            children: [
              // 🔍 SEARCH BAR
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, role, vessel or email',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),

              Expanded(
                child: FutureBuilder<List<_UserItem>>(
                  future: _usersFut,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Erro: ${snap.error}'));
                    }

                    final allUsers = snap.data ?? [];

                    final users = allUsers.where((u) {
                      final key =
                      '${u.name} ${u.role} ${u.vessel} ${u.email}'.toLowerCase();
                      return _search.isEmpty || key.contains(_search);
                    }).toList();

                    if (users.isEmpty) {
                      return const Center(child: Text('No matching users.'));
                    }

                    return FutureBuilder<int>(
                      future: _programTotalQtyFut,
                      builder: (context, totalSnap) {
                        final total = totalSnap.data ?? 0;

                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: users.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final u = users[i];

                            void openUser() {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProgramTasksPage(
                                    programTitle: widget.programTitle,
                                    programId: widget.programId,
                                    userId: u.uid,
                                    readOnly: true,
                                  ),
                                ),
                              );
                            }

                            final line2 = [
                              if (u.role.isNotEmpty) u.role,
                              if (u.vessel.isNotEmpty) u.vessel,
                            ].join(' • ');

                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: InkWell(
                                onTap: openUser,
                                child: Text(
                                  u.name,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              subtitle: _AssigneeProgressSubtitle(
                                line2: line2,
                                email: u.email,
                                programTotalQty: total,
                                approvedQtyFuture: _loadUserApprovedQty(u.uid),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: openUser,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────── Widgets auxiliares ─────────────────────────

class _AssigneeProgressSubtitle extends StatelessWidget {
  const _AssigneeProgressSubtitle({
    required this.line2,
    required this.email,
    required this.programTotalQty,
    required this.approvedQtyFuture,
  });

  final String line2;
  final String email;
  final int programTotalQty;
  final Future<int> approvedQtyFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: approvedQtyFuture,
      builder: (context, snap) {
        final approved = snap.data ?? 0;
        final total = programTotalQty;

        final progress = total <= 0 ? 0.0 : (approved / total).clamp(0.0, 1.0);
        final percent = (progress * 100).toStringAsFixed(0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (line2.isNotEmpty) Text(line2),
            if (email.isNotEmpty) Text(email),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: snap.connectionState == ConnectionState.waiting ? null : progress,
                minHeight: 7,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              total <= 0
                  ? 'Progress unavailable'
                  : '$approved / $total  •  $percent%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── Models ─────────────────────────

class _UserItem {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String vessel;

  _UserItem({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.vessel,
  });
}

class _CampaignMeta {
  final String name;
  const _CampaignMeta({required this.name});
}
