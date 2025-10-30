import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:tprb/dashboards/office/create_campaign_page.dart';
import 'package:tprb/widgets/widgets.dart' as ui;
import 'package:tprb/widgets/widgets.dart';

// Mantém seus nomes antigos funcionando, apontando para os públicos do widgets.dart
typedef _Card = ui.CardBox;
typedef _LiveCountCard = ui.LiveCountCard;
typedef _AvgCompletionCard = ui.AvgCompletionCard;
typedef _TotalTasksCard = ui.TotalTasksCard;

/// Use: Navigator.push(context, MaterialPageRoute(builder: (_) => const FleetOverviewPage()));
class FleetOverviewPage extends StatelessWidget {
  const FleetOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = Colors.grey[100];
    return Scaffold(
      backgroundColor: bg,
      appBar: CustomTopBar(
        userId: FirebaseAuth.instance.currentUser?.uid,
        email: FirebaseAuth.instance.currentUser?.email,
      ), // <-- Top bar funcionando com Firebase
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
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time training metrics across fleet and users',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),

                // Filtros rápidos (mantidos)
                // Wrap(
                //   spacing: 12,
                //   runSpacing: 8,
                //   children: const [
                //     _FilterChipLike(label: 'All Vessels', icon: Icons.expand_more),
                //     _FilterChipLike(label: 'Last 30 days', icon: Icons.expand_more),
                //     _OutlineAction(label: 'Export Report', icon: Icons.download),
                //   ],
                // ),
                const SizedBox(height: 16),

                // NEW: Create Training Campaign (lançador para nova página)
                _ResponsiveRow(
                  gap: 16,
                  children: [
                    _Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Create Training Program'),
                            const SizedBox(height: 8),
                            const Text(
                              'Assign existing training programs to users by vessel, role, groups, or individually.',
                              style: TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.campaign_outlined),
                                label: const Text('Open program creator'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const CreateCampaignPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // === Active Campaigns Panel ===
                _ResponsiveRow(
                  gap: 16,
                  children: const [
                    _Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: _CampaignsPanel(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),


                // Cards resumo (dinâmicos do Firestore)
                _ResponsiveRow(
                  gap: 16,
                  children: [
                    _LiveCountCard(
                      title: 'Active Programs',
                      icon: Icons.assignment_turned_in_outlined,
                      // filtra programas publicados (ajuste se usar outro status/campo)
                      query: FirebaseFirestore.instance
                          .collection('training_programs')
                          .where('status', isEqualTo: 'published'),
                    ),
                    _LiveCountCard(
                      title: 'Users Enrolled',
                      icon: Icons.groups_outlined,
                      // usuários ativos (ajuste o filtro conforme seu schema)
                      query: FirebaseFirestore.instance
                          .collection('users')
                          .where('status', isEqualTo: 'active'),
                    ),
                    _AvgCompletionCard(
                      title: 'Avg Completion',
                      icon: Icons.show_chart,
                      // usa assignments na raiz; ajuste se usar subcoleção em campaigns/{id}/assignments
                      assignmentsQuery: FirebaseFirestore.instance.collection('assignments'),
                    ),
                    _TotalTasksCard(
                      title: 'Total Tasks',
                      icon: Icons.menu_book_outlined,
                      // soma tarefas percorrendo chapters dos programas publicados
                      programsQuery: FirebaseFirestore.instance
                          .collection('training_programs')
                          .where('status', isEqualTo: 'published'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // NEW CARD WAS INSERTED ABOVE. A partir daqui, mantive tudo que já existia.

                // // Weekly progress + Task status
                // _ResponsiveRow(
                //   gap: 16,
                //   children: [
                //     _Card(
                //       child: Padding(
                //         padding: const EdgeInsets.all(16),
                //         child: Column(
                //           crossAxisAlignment: CrossAxisAlignment.start,
                //           children: const [
                //             _SectionTitle('Weekly Training Progress'),
                //             SizedBox(height: 8),
                //             _WeekProgressRow(label: 'Jan Week 1', completed: 24, inProgress: 18, total: 42),
                //             _WeekProgressRow(label: 'Jan Week 2', completed: 31, inProgress: 22, total: 53),
                //             _WeekProgressRow(label: 'Jan Week 3', completed: 28, inProgress: 19, total: 47),
                //             _WeekProgressRow(label: 'Current',   completed: 35, inProgress: 20, total: 55),
                //           ],
                //         ),
                //       ),
                //     ),
                //     _Card(
                //       child: Padding(
                //         padding: const EdgeInsets.all(16),
                //         child: Column(
                //           crossAxisAlignment: CrossAxisAlignment.start,
                //           children: const [
                //             _SectionTitle('Fleet Task Status'),
                //             SizedBox(height: 8),
                //             _StatusLegend(label: 'Completed', value: 156),
                //             _StatusLegend(label: 'In progress', value: 112),
                //             _StatusLegend(label: 'Not started', value: 223),
                //           ],
                //         ),
                //       ),
                //     ),
                //   ],
                // ),

                const SizedBox(height: 16),
                // ... (demais seções/quadros existentes no seu arquivo continuam iguais)
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
      elevation: 0,
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 64,
          child: Row(
            children: const [
              _Brand(),
              Spacer(),
              _UserChip(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.directions_boat_filled_outlined, color: Colors.blue),
        ),
        const SizedBox(width: 10),
        const Text('TPRB Office', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ],
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip();

  String _pickName(Map<String, dynamic> data, String? emailFallback) {
    return (data['userName'] ?? data['displayName'] ?? emailFallback ?? 'User') as String;
  }

  String _pickRole(Map<String, dynamic> data) {
    return (data['userRole'] ?? data['role'] ?? 'User') as String;
  }

  String _pickOffice(Map<String, dynamic> data) {
    return (data['vessel'] ?? data['office'] ?? 'Office') as String;
  }

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

          return _Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                  const SizedBox(width: 8),
                  Text('$name — $role · $office'),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signed out')),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return _Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
            const SizedBox(width: 8),
            Text(email ?? 'Not signed'),
          ],
        ),
      ),
    );
  }
}

/* ============================== UI HELPERS ============================== */

class _FilterChipLike extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FilterChipLike({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: Colors.grey[300]!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.fromBorderSide(border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Text(label),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 18),
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final IconData icon;
  const _OutlineAction({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const _ResponsiveRow({required this.children, this.gap = 12});

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width;
    final isNarrow = maxW < 900;
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
  }
}

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (completed / total),
              minHeight: 8,
              backgroundColor: Colors.grey[200],
            ),
          ),
          const SizedBox(width: 8),
          Text('$completed/$total'),
        ],
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  final String label;
  final int value;
  const _StatusLegend({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$value'),
        ],
      ),
    );
  }
}

/* ===================== CREATE CAMPAIGN WIDGETS (SUPORTE) ===================== */

class _ProgramDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _ProgramDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('training_programs')
      // Remova a linha abaixo se quiser listar todos os programas (incluindo rascunhos)
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snap) {
        final items = <DropdownMenuItem<String>>[];
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final id = d.id;
            final data = d.data();
            final title = (data['title'] ?? data['name'] ?? id).toString();
            items.add(DropdownMenuItem(value: id, child: Text(title)));
          }
        }
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Training program',
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: value,
              items: items.isEmpty
                  ? [const DropdownMenuItem(value: null, child: Text('No programs found'))]
                  : items,
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }
}

/* ========== Multi-select util (Vessels/Users), pode ser útil em outras telas também ========== */

class _VesselMultiSelect extends StatelessWidget {
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  const _VesselMultiSelect({required this.selectedIds, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _MultiSelectBox(
      title: 'Select vessels',
      stream: FirebaseFirestore.instance.collection('vessels').snapshots(),
      idSelector: (d) => d.id,
      labelSelector: (d) => d.data()['name'] ?? d.id,
      selected: selectedIds,
      onChanged: onChanged,
    );
  }
}

class _UserMultiSelect extends StatelessWidget {
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  const _UserMultiSelect({required this.selectedIds, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _MultiSelectBox(
      title: 'Select users',
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      idSelector: (d) => d.id,
      labelSelector: (d) => (d.data()['displayName'] ?? d.data()['email'] ?? d.id),
      selected: selectedIds,
      onChanged: onChanged,
    );
  }
}

class _MultiSelectBox extends StatefulWidget {
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String Function(QueryDocumentSnapshot<Map<String, dynamic>>) idSelector;
  final String Function(QueryDocumentSnapshot<Map<String, dynamic>>) labelSelector;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _MultiSelectBox({
    required this.title,
    required this.stream,
    required this.idSelector,
    required this.labelSelector,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_MultiSelectBox> createState() => _MultiSelectBoxState();
}

class _MultiSelectBoxState extends State<_MultiSelectBox> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _search = v.toLowerCase()),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ));
              }
              final docs = snap.data?.docs ?? [];
              final filtered = docs.where((d) {
                final label = widget.labelSelector(d).toLowerCase();
                return _search.isEmpty || label.contains(_search);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No results'),
                ));
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final d = filtered[i];
                  final id = widget.idSelector(d);
                  final label = widget.labelSelector(d);
                  final selected = widget.selected.contains(id);
                  return CheckboxListTile(
                    dense: true,
                    value: selected,
                    title: Text(label),
                    onChanged: (v) {
                      final next = Set<String>.from(widget.selected);
                      if (v == true) {
                        next.add(id);
                      } else {
                        next.remove(id);
                      }
                      widget.onChanged(next);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  const _DateField({required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value == null
              ? 'Select date'
              : '${value!.year.toString().padLeft(4,'0')}-${value!.month.toString().padLeft(2,'0')}-${value!.day.toString().padLeft(2,'0')}',
        ),
      ),
    );
  }
}

/* ===================== CAMPAIGNS PANEL (VIEW/MANAGE) ===================== */

class _CampaignsPanel extends StatefulWidget {
  const _CampaignsPanel();

  @override
  State<_CampaignsPanel> createState() => _CampaignsPanelState();
}

class _CampaignsPanelState extends State<_CampaignsPanel> {
  String _search = '';
  String _statusFilter = 'active'; // active | paused | closed | all

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Active Programs'),
        const SizedBox(height: 8),
        Text(
          'Review current programs, check progress, and manage status.',
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 12),

        // Filters row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by program...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
              ),
            ),
            ChoiceChip(
              label: const Text('Active'),
              selected: _statusFilter == 'active',
              onSelected: (_) => setState(() => _statusFilter = 'active'),
            ),
            ChoiceChip(
              label: const Text('Paused'),
              selected: _statusFilter == 'paused',
              onSelected: (_) => setState(() => _statusFilter = 'paused'),
            ),
            ChoiceChip(
              label: const Text('Closed'),
              selected: _statusFilter == 'closed',
              onSelected: (_) => setState(() => _statusFilter = 'closed'),
            ),
            ChoiceChip(
              label: const Text('All'),
              selected: _statusFilter == 'all',
              onSelected: (_) => setState(() => _statusFilter = 'all'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // List
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(maxHeight: 420),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('campaigns')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ));
              }
              final docs = snap.data?.docs ?? [];

              // client-side filter by status + search
              final filtered = docs.where((d) {
                final data = d.data();
                final status = (data['status'] ?? 'active').toString().toLowerCase();
                final name   = (data['name'] ?? '').toString().toLowerCase();
                final prog   = (data['programTitle'] ?? data['programId'] ?? '').toString().toLowerCase();
                final matchesSearch = _search.isEmpty || name.contains(_search) || prog.contains(_search);
                final matchesStatus = _statusFilter == 'all' ? true : status == _statusFilter;
                return matchesSearch && matchesStatus;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No programs found'),
                ));
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[300]),
                itemBuilder: (context, i) {
                  final d = filtered[i];
                  return _CampaignItemTile(doc: d);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CampaignItemTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _CampaignItemTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final name = (data['name'] ?? '—').toString();
    final status = (data['status'] ?? 'active').toString();
    final programTitle = (data['programTitle'] ?? data['programId'] ?? '—').toString();
    final scope = (data['scope'] ?? data['targetType'] ?? '—').toString();
    final createdAt = data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Row(
        children: [
          Expanded(
            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          _CampaignStatusChip(status: status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.menu_book_outlined, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Text(programTitle, style: const TextStyle(color: Colors.black87)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.segment_outlined, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Text('Scope: $scope'),
            ]),
            if (createdAt != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.schedule, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Text('Created: ${_fmtDate(createdAt)}'),
              ]),

            // Live assignment counts
            _AssignmentsCountBadge(campaignId: doc.id),
          ],
        ),
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => _showDetails(context, data),
            icon: const Icon(Icons.info_outline),
            label: const Text('Details'),
          ),
          if (status == 'active')
            OutlinedButton.icon(
              onPressed: () => _updateStatus(context, 'paused'),
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Pause'),
            ),
          if (status == 'paused')
            OutlinedButton.icon(
              onPressed: () => _updateStatus(context, 'active'),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Resume'),
            ),
          if (status != 'closed')
            ElevatedButton.icon(
              onPressed: () => _updateStatus(context, 'closed'),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Close'),
            ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(doc.id)
          .update({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Program ${doc.id} set to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  void _showDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final startDate = data['startDate'] is Timestamp ? (data['startDate'] as Timestamp).toDate() : null;
        final dueDate   = data['dueDate']   is Timestamp ? (data['dueDate'] as Timestamp).toDate()   : null;

        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Program Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  _CampaignStatusChip(status: (data['status'] ?? 'active').toString()),
                ],
              ),
              const SizedBox(height: 12),
              _detailRow('Name', (data['name'] ?? '—').toString()),
              _detailRow('Program', (data['programTitle'] ?? data['programId'] ?? '—').toString()),
              _detailRow('Scope', (data['scope'] ?? data['targetType'] ?? '—').toString()),
              _detailRow('Notes', (data['notes'] ?? '—').toString()),
              _detailRow('Start', startDate != null ? _fmtDate(startDate) : '—'),
              _detailRow('Due',   dueDate   != null ? _fmtDate(dueDate)   : '—'),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _AssignmentsBreakdown(campaignId: (data['campaignId'] ?? '').toString().isNotEmpty ? (data['campaignId'] as String) : '' , fallbackDocId: doc.id),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _CampaignStatusChip extends StatelessWidget {
  final String status;
  const _CampaignStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'paused':
        bg = Colors.orange.withOpacity(.12);
        fg = Colors.orange[800]!;
        break;
      case 'closed':
        bg = Colors.red.withOpacity(.12);
        fg = Colors.red[800]!;
        break;
      default: // active
        bg = Colors.green.withOpacity(.12);
        fg = Colors.green[800]!;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _AssignmentsCountBadge extends StatelessWidget {
  final String campaignId;
  const _AssignmentsCountBadge({required this.campaignId});

  @override
  Widget build(BuildContext context) {
    // Root 'assignments' (como sugerido nas páginas anteriores)
    final q = FirebaseFirestore.instance
        .collection('assignments')
        .where('campaignId', isEqualTo: campaignId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Row(mainAxisSize: MainAxisSize.min, children: const [
            SizedBox(width: 12),
            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          ]);
        }
        final docs = snap.data!.docs;
        int pending = 0, inProgress = 0, completed = 0;
        for (final d in docs) {
          final s = (d.data()['status'] ?? 'pending').toString();
          if (s == 'completed') {
            completed++;
          } else if (s == 'in_progress') {
            inProgress++;
          } else {
            pending++;
          }
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            _pill('Pending', pending),
            const SizedBox(width: 6),
            _pill('In progress', inProgress),
            const SizedBox(width: 6),
            _pill('Completed', completed),
          ],
        );
      },
    );
  }

  static Widget _pill(String label, int v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $v', style: const TextStyle(fontSize: 12)),
    );
  }
}

class _AssignmentsBreakdown extends StatelessWidget {
  final String campaignId;
  final String fallbackDocId;
  const _AssignmentsBreakdown({required this.campaignId, required this.fallbackDocId});

  @override
  Widget build(BuildContext context) {
    final id = (campaignId.isEmpty) ? fallbackDocId : campaignId;

    final q = FirebaseFirestore.instance
        .collection('assignments')
        .where('campaignId', isEqualTo: id);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data!.docs;
        int pending = 0, inProgress = 0, completed = 0;
        for (final d in docs) {
          final s = (d.data()['status'] ?? 'pending').toString();
          if (s == 'completed') {
            completed++;
          } else if (s == 'in_progress') {
            inProgress++;
          } else {
            pending++;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assignments', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                _badge('Pending', pending, Colors.grey[600]!),
                const SizedBox(width: 8),
                _badge('In progress', inProgress, Colors.blue[700]!),
                const SizedBox(width: 8),
                _badge('Completed', completed, Colors.green[800]!),
              ],
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  static Widget _badge(String label, int value, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: fg),
          const SizedBox(width: 6),
          Text('$label: $value'),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}


