import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Box que lista as campanhas destinadas ao usuário logado.
/// Por padrão, mostra apenas campanhas com `campaign.status == 'active'`.
class TraineeActiveCampaignsBox extends StatelessWidget {
  final bool onlyActiveCampaigns;
  const TraineeActiveCampaignsBox({super.key, this.onlyActiveCampaigns = true});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    // assignments na RAIZ (conforme sua estrutura atual)
    final assignmentsQuery = FirebaseFirestore.instance
        .collection('assignments')
        .where('userId', isEqualTo: uid);

    return _Shell(
      title: 'My Campaigns',
      subtitle: onlyActiveCampaigns ? 'Active campaigns assigned to you' : 'All your campaigns',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: assignmentsQuery.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final assignments = (snap.data?.docs ?? [])
              .map((d) => d.data()..['__id'] = d.id)
              .toList();

          if (assignments.isEmpty) {
            return const _EmptyState(message: 'No campaigns assigned to you yet.');
          }

          // Pega todos os campaignIds desses assignments
          final ids = assignments
              .map((a) => (a['campaignId'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          // Se tiver até 10, usa whereIn; caso contrário, cai no modo per-item (evita limite do Firestore)
          if (ids.isEmpty) {
            return const _EmptyState(message: 'No campaigns found for your assignments.');
          } else if (ids.length <= 10) {
            final campaignsQuery = FirebaseFirestore.instance
                .collection('campaigns')
                .where(FieldPath.documentId, whereIn: ids);

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: campaignsQuery.snapshots(),
              builder: (context, csnap) {
                if (csnap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                // Mapa id -> dados da campanha
                final cmap = <String, Map<String, dynamic>>{};
                for (final d in csnap.data?.docs ?? []) {
                  cmap[d.id] = d.data()..['__id'] = d.id;
                }

                // Combina assignment + campaign; filtra se necessário
                final rows = <_RowData>[];
                for (final a in assignments) {
                  final cid = (a['campaignId'] ?? '').toString();
                  final c = cmap[cid];
                  final cStatus = (c?['status'] ?? 'active').toString();
                  if (!onlyActiveCampaigns || cStatus == 'active') {
                    rows.add(_RowData.fromAssignmentAndCampaign(a, c));
                  }
                }

                if (rows.isEmpty) {
                  return const _EmptyState(message: 'No active campaigns for you.');
                }

                return _CampaignList(rows: rows);
              },
            );
          } else {
            // Fallback: muitas campanhas — busca por item (simples e robusto para poucos itens na prática)
            return _PerItemCampaignList(assignments: assignments, onlyActive: onlyActiveCampaigns);
          }
        },
      ),
    );
  }
}

/* ------------------------------ UI widgets ------------------------------ */

class _Shell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Shell({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF2)),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.campaign_outlined, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              // Espaço para um botão "View all" futuramente, se quiser
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: const TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }
}

class _CampaignList extends StatelessWidget {
  final List<_RowData> rows;
  const _CampaignList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFE6EBF2)),
      itemBuilder: (_, i) {
        final r = rows[i];
        return _CampaignTile(row: r);
      },
    );
  }
}

class _PerItemCampaignList extends StatelessWidget {
  final List<Map<String, dynamic>> assignments;
  final bool onlyActive;
  const _PerItemCampaignList({required this.assignments, required this.onlyActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final a in assignments) _AssignmentWithCampaign(a: a, onlyActive: onlyActive),
      ],
    );
  }
}

class _AssignmentWithCampaign extends StatelessWidget {
  final Map<String, dynamic> a;
  final bool onlyActive;
  const _AssignmentWithCampaign({required this.a, required this.onlyActive});

  @override
  Widget build(BuildContext context) {
    final cid = (a['campaignId'] ?? '').toString();
    if (cid.isEmpty) return const SizedBox.shrink();

    final ref = FirebaseFirestore.instance.collection('campaigns').doc(cid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final c = snap.data?.data();
        final cStatus = (c?['status'] ?? 'active').toString();
        if (onlyActive && cStatus != 'active') return const SizedBox.shrink();

        final row = _RowData.fromAssignmentAndCampaign(a, c?..['__id'] = cid);
        return Column(
          children: [
            _CampaignTile(row: row),
            const Divider(height: 16, color: Color(0xFFE6EBF2)),
          ],
        );
      },
    );
  }
}

class _CampaignTile extends StatelessWidget {
  final _RowData row;
  const _CampaignTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final due = row.dueDate != null ? _fmtDate(row.dueDate!) : '—';
    final start = row.startDate != null ? _fmtDate(row.startDate!) : '—';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ícone
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.menu_book_outlined, color: Colors.blue),
        ),
        const SizedBox(width: 12),
        // Conteúdo
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.programTitle ?? row.programId ?? 'Program',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _StatusPill(label: row.campaignStatus ?? 'active'),
                ],
              ),
              const SizedBox(height: 4),
              // Subtítulo
              Text(
                row.campaignName ?? (row.campaignId ?? ''),
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 6),
              // Infos
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InfoRow(icon: Icons.schedule, label: 'Start', value: start),
                  _InfoRow(icon: Icons.event, label: 'Due', value: due),
                  _InfoRow(icon: Icons.flag_outlined, label: 'Assignment', value: row.assignmentStatus ?? '—'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Botão
        TextButton.icon(
          onPressed: () {
            // TODO: navegação para a tela do programa/campanha (quando existir)
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        Text('$label: $value'),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    Color fg;
    Color bg;
    switch (label) {
      case 'paused':
        fg = Colors.orange[800]!;
        bg = Colors.orange.withOpacity(.12);
        break;
      case 'closed':
        fg = Colors.red[800]!;
        bg = Colors.red.withOpacity(.12);
        break;
      default:
        fg = Colors.green[800]!;
        bg = Colors.green.withOpacity(.12);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

/* ------------------------------ helpers ------------------------------ */

class _RowData {
  final String? assignmentId;
  final String? campaignId;
  final String? campaignName;
  final String? campaignStatus;
  final String? programId;
  final String? programTitle;
  final String? assignmentStatus;
  final DateTime? startDate;
  final DateTime? dueDate;

  _RowData({
    this.assignmentId,
    this.campaignId,
    this.campaignName,
    this.campaignStatus,
    this.programId,
    this.programTitle,
    this.assignmentStatus,
    this.startDate,
    this.dueDate,
  });

  factory _RowData.fromAssignmentAndCampaign(
      Map<String, dynamic> assignment,
      Map<String, dynamic>? campaign,
      ) {
    // Lê datas com segurança (sem usar campaign?['...'])
    final tsStart = campaign == null ? null : campaign['startDate'];
    final tsDue   = campaign == null ? null : campaign['dueDate'];

    DateTime? start, due;
    if (tsStart is Timestamp) start = tsStart.toDate();
    if (tsDue   is Timestamp) due   = tsDue.toDate();

    // Id da campanha (usa o do assignment se faltar no map da campanha)
    final String campaignId =
    campaign == null
        ? (assignment['campaignId'] ?? '').toString()
        : ((campaign['__id'] ?? assignment['campaignId'] ?? '').toString());

    // Nome e título do programa (strings opcionais)
    final String campaignNameRaw =
    campaign == null ? '' : (campaign['name'] ?? '').toString();

    final String programTitleRaw =
    campaign == null ? '' : (campaign['programTitle'] ?? '').toString();

    // Status da campanha (default 'active')
    final String campaignStatus =
    campaign == null ? 'active' : (campaign['status'] ?? 'active').toString();

    return _RowData(
      assignmentId: (assignment['__id'] ?? '').toString(),
      programId: (assignment['programId'] ?? '').toString(),
      assignmentStatus: (assignment['status'] ?? 'pending').toString(),
      campaignId: campaignId,
      campaignName: campaignNameRaw.isNotEmpty ? campaignNameRaw : null,
      campaignStatus: campaignStatus,
      programTitle: programTitleRaw.isNotEmpty ? programTitleRaw : null,
      startDate: start,
      dueDate: due,
    );
  }
}

String _fmtDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
