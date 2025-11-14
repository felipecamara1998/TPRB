import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tprb/dashboards/office/create_campaign_page.dart';
import 'admin/program_editor_page.dart';
import 'program_assignees_page.dart';

import 'admin/new_user.dart';

import 'admin/admin_vessels.dart';
import 'admin/vessel_crew_page.dart';

import 'package:tprb/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Página unificada com 4 abas:
/// 0) Fleet Training Overview (principal)
/// 1) TPRB Editions
/// 2) Vessels
/// 3) Users
class OfficePage extends StatefulWidget {
  const OfficePage({super.key});
  @override
  State<OfficePage> createState() => _OfficePageState();
}

class _OfficePageState extends State<OfficePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _tab;
  static const _maxWidth = 1100.0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const bg = Color(0xFFF6F8FB);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: bg,
      appBar: CustomTopBar(
        userId: user?.uid,
        email: user?.email,
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: Colors.blueGrey[900],
          indicatorColor: Colors.blueGrey[700],
          tabs: const [
            Tab(
              icon: Icon(Icons.leaderboard_outlined),
              text: 'Fleet Training Overview',
            ),
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'TPRB editions'),
            Tab(icon: Icon(Icons.directions_boat_outlined), text: 'Vessels'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Users'),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: TabBarView(
            controller: _tab,
            children: const [
              _FleetOverviewTab(),
              _EditionsTab(),
              _VesselsTab(),
              _UsersTab(),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── TAB 1 — Fleet Training Overview ───────────────────────── */

class _FleetOverviewTab extends StatefulWidget {
  const _FleetOverviewTab();
  @override
  State<_FleetOverviewTab> createState() => _FleetOverviewTabState();
}

class _FleetOverviewTabState extends State<_FleetOverviewTab> {
  String _status = 'active'; // active | paused | closed | all
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final campaigns = FirebaseFirestore.instance.collection('campaigns');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const Text(
          'Fleet Training Overview',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Real-time training metrics across fleet and users',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),

        // ===== KPI CARDS (corrigido layout)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            final cards = [
              Expanded(
                child: LiveCountCard(
                  title: 'Active Programs',
                  icon: Icons.check_circle_outline,
                  query: campaigns.where('status', isEqualTo: 'active'),
                ),
              ),
              Expanded(
                child: LiveCountCard(
                  title: 'Users Enrolled',
                  icon: Icons.groups_outlined,
                  query: FirebaseFirestore.instance.collection('assignments'),
                ),
              ),
              Expanded(
                child: AvgCompletionCard(
                  title: 'Avg Completion',
                  icon: Icons.trending_up_outlined,
                  assignmentsQuery: FirebaseFirestore.instance.collection(
                    'assignments',
                  ),
                ),
              ),
              Expanded(
                child: TotalTasksCard(
                  title: 'Total Tasks',
                  icon: Icons.menu_book_outlined,
                  programsQuery: FirebaseFirestore.instance.collection(
                    'training_programs',
                  ),
                ),
              ),
            ];
            if (isNarrow) {
              // empilha em 2 linhas se espaço pequeno
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: cards
                    .map((c) => SizedBox(width: 260, child: c))
                    .toList(),
              );
            } else {
              // uma linha dividindo espaço
              return Row(
                children: [
                  ...cards
                      .expand((c) => [c, const SizedBox(width: 16)])
                      .toList()
                    ..removeLast(),
                ],
              );
            }
          },
        ),

        const SizedBox(height: 28),
        // ===== CREATE PROGRAM CARD =====
        _CreateProgramCard(),
        const SizedBox(height: 16),

        // ===== ACTIVE PROGRAMS
        CardBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  icon: Icons.list_alt_outlined,
                  title: 'Active Programs',
                  subtitle:
                      'Review current programs, check progress, and manage status.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search by program...',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) =>
                            setState(() => _search = v.trim().toLowerCase()),
                      ),
                    ),
                    _ChipFilter(
                      selected: _status == 'active',
                      label: 'Active',
                      onTap: () => setState(() => _status = 'active'),
                    ),
                    _ChipFilter(
                      selected: _status == 'paused',
                      label: 'Paused',
                      onTap: () => setState(() => _status = 'paused'),
                    ),
                    _ChipFilter(
                      selected: _status == 'closed',
                      label: 'Closed',
                      onTap: () => setState(() => _status = 'closed'),
                    ),
                    _ChipFilter(
                      selected: _status == 'all',
                      label: 'All',
                      onTap: () => setState(() => _status = 'all'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: campaigns
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
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
                        child: Text('Error loading campaigns: ${snap.error}'),
                      );
                    }

                    final docs = snap.data?.docs ?? const [];
                    final filtered = docs.where((d) {
                      final data = d.data();
                      final status = (data['status'] ?? 'active')
                          .toString()
                          .toLowerCase();
                      final name = (data['name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final okStatus = _status == 'all'
                          ? true
                          : status == _status;
                      final okSearch = _search.isEmpty
                          ? true
                          : name.contains(_search);
                      return okStatus && okSearch;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No programs found for the selected filters.',
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final d in filtered)
                          _CampaignTile(id: d.id, data: d.data()),
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
  }
}

class _CreateProgramCard extends StatelessWidget {
  const _CreateProgramCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
      child: Row(
        children: [
          const Icon(
            Icons.playlist_add_rounded,
            color: Color(0xFF1F2937),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Training Program',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assign published programs to users by vessel, role, groups, or individually.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black.withOpacity(.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open program creator'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateCampaignPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _pickAndOpenProgramAssignees(BuildContext context) async {
  // carrega os programas existentes
  final qs = await FirebaseFirestore.instance
      .collection('training_programs')
      .orderBy('title')
      .get();

  if (qs.docs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No training programs found. Create one first.')),
    );
    return;
  }

  // mostra um diálogo para escolher o programa
  final selected = await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>?>(
    context: context,
    builder: (dialogCtx) => SimpleDialog(
      title: const Text('Select a training program'),
      children: [
        SizedBox(
          width: 420,
          height: 360,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: qs.docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = qs.docs[i];
              final title = (d.data()['title'] ?? '').toString();
              return ListTile(
                title: Text(title.isEmpty ? d.id : title),
                onTap: () => Navigator.pop(dialogCtx, d), // << aqui a correção
              );
            },
          ),
        ),
      ],
    ),
  );

  if (selected == null) return;

  final programId   = selected.id;
  final programTitle= (selected.data()['title'] ?? '').toString();

  // campaignId vazio => fluxo de criação de uma nova assignment dentro da página
  // (a ProgramAssigneesPage decide como lidar com isso)
  // Ajuste aqui se a sua page exigir algum padrão diferente.
  // Ex.: campaignId: 'NEW'
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProgramAssigneesPage(
        campaignId: '',
        programId: programId,
        programTitle: programTitle.isEmpty ? 'Untitled program' : programTitle,
      ),
    ),
  );
}

class _CampaignTile extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const _CampaignTile({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Untitled').toString();
    String created = '';
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      created =
          '${raw.toDate().day.toString().padLeft(2, '0')}/${raw.toDate().month.toString().padLeft(2, '0')}/${raw.toDate().year}';
    } else if (raw is String && raw.isNotEmpty) {
      created = raw;
    } else {
      created = '—';
    }
    final status = (data['status'] ?? 'active').toString();
    final assignments = (data['assignments'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Created: $created',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          _StatusChip(status: status),
          const SizedBox(width: 12),
          _Badge(text: '$assignments assigned'),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () {
              final programId = (data['programId'] ?? '').toString();
              final programTitle =
                  (data['programTitle'] ?? data['name'] ?? 'Program')
                      .toString();

              if (programId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Campaign missing programId.')),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProgramAssigneesPage(
                    campaignId: id,
                    programId: programId,
                    programTitle: programTitle,
                  ),
                ),
              );
            },
            child: const Text('Details'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Pause',
            onPressed: () => FirebaseFirestore.instance
                .collection('campaigns')
                .doc(id)
                .update({'status': 'paused'}),
            icon: const Icon(Icons.pause_circle_outline),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => FirebaseFirestore.instance
                .collection('campaigns')
                .doc(id)
                .update({'status': 'closed'}),
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── TAB 2 — TPRB Editions ───────────────────────── */

class _EditionsTab extends StatelessWidget {
  const _EditionsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        CardBox(
          child: Padding(
            // mesmo padding lateral do admin
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TPRB Editions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Manage training content versions and publish updates to the fleet',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('New Edition'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const ProgramEditorPage(programId: null),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('training_programs')
                      .orderBy('dateCreated', descending: true)
                      .snapshots(),
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
                        child: Text('Error loading editions: ${snap.error}'),
                      );
                    }

                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No editions created yet.'),
                      );
                    }

                    // mesma contagem do admin
                    int countTasksIn(dynamic node) {
                      int count = 0;
                      if (node is Map) {
                        node.forEach((_, value) {
                          if (value is Map) {
                            if (value.containsKey('task')) count += 1;
                            count += countTasksIn(value);
                          }
                        });
                      }
                      return count;
                    }

                    return Column(
                      children: [
                        for (final d in docs)
                          Builder(
                            builder: (_) {
                              final data = d.data();
                              final chapters =
                                  (data['chapters'] as Map?)
                                      ?.cast<String, dynamic>() ??
                                  {};
                              final tasksCount = countTasksIn(chapters);

                              final title = (data['title'] ?? 'Untitled')
                                  .toString();
                              final description = (data['description'] ?? '')
                                  .toString();
                              final created = (data['dateCreated'] ?? '')
                                  .toString();
                              final effective =
                                  (data['dateOfImplementation'] ?? '')
                                      .toString();
                              final author = (data['createdBy'] ?? '')
                                  .toString();

                              // status igual ao admin: published / draft
                              final statusRaw = (data['status'] ?? 'published')
                                  .toString()
                                  .toLowerCase();
                              final isPublished =
                                  statusRaw == 'published' ||
                                  statusRaw == 'active';
                              final statusColor = isPublished
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF455A64);
                              final statusText = isPublished
                                  ? 'published'
                                  : 'draft';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.menu_book_outlined,
                                      color: Colors.blueGrey,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: statusColor
                                                        .withOpacity(0.35),
                                                  ),
                                                ),
                                                child: Text(
                                                  statusText,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _Badge(text: '$tasksCount tasks'),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (description.isNotEmpty)
                                            Text(
                                              description,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Created: $created    Effective: $effective    By: $author',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Edit'),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ProgramEditorPage(
                                              programId: d.id,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
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
    );
  }
}

// ——— Item de edição (cópia do admin.dart, mantendo só o botão Edit) ———
class _EditionItem extends StatelessWidget {
  final String title;
  final String statusText;
  final Color statusColor;
  final int tasksCount;
  final String description;
  final String created;
  final String effective;
  final String author;
  final bool showPublish;
  final String version;
  final String docId;

  const _EditionItem({
    required this.title,
    required this.statusText,
    required this.statusColor,
    required this.tasksCount,
    required this.description,
    required this.created,
    required this.effective,
    required this.author,
    required this.showPublish,
    required this.version,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.menu_book_outlined, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // status e tasks — mesmo visual
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withOpacity(0.35),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(text: '$tasksCount tasks'),
                  ],
                ),
                const SizedBox(height: 8),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black87),
                  ),
                const SizedBox(height: 12),
                _metaText(
                  'Created: $created    Effective: $effective    By: $author',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // apenas o Edit (como solicitado)
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProgramEditorPage(programId: docId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metaText(String text) =>
      Text(text, style: const TextStyle(color: Colors.black54));
}

/* ───────────────────────── TAB 3 — Vessels ───────────────────────── */

class _VesselsTab extends StatelessWidget {
  const _VesselsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        CardBox(
          child: Padding(
            // >>> mesmo espaçamento lateral do admin
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho com botão "Adicionar"
                Row(
                  children: [
                    const Icon(
                      Icons.directions_boat_outlined,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vessels',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Assign editions and monitor vessel training adoption',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar'),
                      onPressed: () {
                        // Abra a tela do admin exatamente como no admin.dart
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminVesselsTab(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Grid de vessels (mesmo padrão visual do admin)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('vessels')
                      .orderBy('name')
                      .snapshots(),
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
                        child: Text('Error loading vessels: ${snap.error}'),
                      );
                    }

                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No vessels registered.'),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, c) {
                        // Quebra responsiva como no admin: 1→400, 2→700, 3→1000, 4+ acima
                        int cross = 1;
                        if (c.maxWidth >= 1000)
                          cross = 4;
                        else if (c.maxWidth >= 700)
                          cross = 3;
                        else if (c.maxWidth >= 400)
                          cross = 2;

                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            // altura do card (80–92 fica ótimo). Ajuste se quiser.
                            mainAxisExtent: 84,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final d = docs[i];
                            final data = d.data();
                            final name = (data['name'] ?? 'Unnamed').toString();

                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F5FA),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.directions_boat_outlined, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.open_in_new, size: 16),
                                    label: const Text('Open'),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      minimumSize: const Size(0, 32),           // altura mínima menor
                                      visualDensity: VisualDensity.compact,     // ainda mais compacto
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => VesselCrewPage(vesselName: name),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────── TAB 4 — Users ───────────────────────── */

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
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
                    const Icon(Icons.people_outline, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Users',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Invite admins, officers and trainees, and assign roles.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add User'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NewUserPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lista de usuários
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .orderBy('email')
                      .snapshots(),
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
                        child: Text('Error loading users: ${snap.error}'),
                      );
                    }

                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No users found.'),
                      );
                    }

                    return Column(
                      children: [
                        for (final d in docs)
                          Builder(builder: (_) {
                            final data = d.data();
                            final email = (data['email'] ?? '').toString();
                            final name = (data['userName'] ?? data['name'] ?? '').toString();
                            final role = (data['role'] ?? '').toString().toLowerCase();

                            Color roleColor;
                            switch (role) {
                              case 'admin':
                                roleColor = const Color(0xFF1565C0);
                                break;
                              case 'office':
                                roleColor = const Color(0xFF6A1B9A);
                                break;
                              case 'seafarer':
                                roleColor = const Color(0xFF00796B);
                                break;
                              default:
                                roleColor = Colors.grey;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFCFD8DC),
                                    radius: 20,
                                    child: Text(
                                      (name.isNotEmpty ? name[0] : email[0]).toUpperCase(),
                                      style: const TextStyle(color: Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isEmpty ? email.split('@')[0] : name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(email, style: const TextStyle(color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: roleColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          role.isEmpty ? 'User' : role[0].toUpperCase() + role.substring(1),
                                          style: TextStyle(fontWeight: FontWeight.w600, color: roleColor),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        label: const Text('Edit'),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => NewUserPage(userId: d.id), // << modo Edit
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
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
  }
}

class _UserRow extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  const _UserRow({required this.name, required this.email, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person_outline)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? email : name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          _RoleTag(role: role),
        ],
      ),
    );
  }
}

/* ───────────────────────── Auxiliares ───────────────────────── */

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueGrey.shade300),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipFilter extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const _ChipFilter({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colors.blueGrey : Colors.grey.shade300,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.blueGrey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color c;
    switch (s) {
      case 'active':
        c = const Color(0xFF4CAF50);
        break;
      case 'paused':
        c = const Color(0xFFFFB300);
        break;
      case 'closed':
        c = const Color(0xFF9E9E9E);
        break;
      default:
        c = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        s,
        style: TextStyle(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  final String role;
  const _RoleTag({required this.role});
  @override
  Widget build(BuildContext context) {
    final mapColor = <String, Color>{
      'Admin': const Color(0xFF1565C0),
      'Office': const Color(0xFF5E35B1),
      'Supervisor': const Color(0xFF6C8AAB),
      'Trainee': const Color(0xFF2E7D32),
      'Seafarer': const Color(0xFF0D47A1),
    };
    final c = mapColor[role] ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        role,
        style: TextStyle(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }
}
