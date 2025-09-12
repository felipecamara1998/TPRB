import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tprb/widgets/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OfficerReviewDashboardPage extends StatelessWidget {
  const OfficerReviewDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7), // fundo mais claro
      appBar: CustomTopBar(
        userId: FirebaseAuth.instance.currentUser?.uid,
        email: FirebaseAuth.instance.currentUser?.email,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Officer Review Dashboard',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    )),
                const SizedBox(height: 4),
                Text(
                  'Review and approve trainee task submissions for Flumar Brasil',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withOpacity(.62),
                  ),
                ),
                const SizedBox(height: 18),

                // ==== KPI CARDS (sem recorte) ====
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Mesma lógica de colunas, mas agora calculamos a LARGURA por item.
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
                        item(const _KpiCard(
                          value: '2',
                          label: 'Pending Review',
                          icon: Icons.timer_outlined,
                          iconBg: Color(0xFFE9F0FF),
                          iconColor: Color(0xFF3B82F6),
                        )),
                        item(const _KpiCard(
                          value: '15',
                          label: 'Approved This Week',
                          icon: Icons.verified_outlined,
                          iconBg: Color(0xFFE8F7EE),
                          iconColor: Color(0xFF22C55E),
                        )),
                        item(const _KpiCard(
                          value: '3',
                          label: 'Returned',
                          icon: Icons.error_outline,
                          iconBg: Color(0xFFFFF1EC),
                          iconColor: Color(0xFFF97316),
                        )),
                        item(const _KpiCard(
                          value: '8',
                          label: 'Active Trainees',
                          icon: Icons.person_outline,
                          iconBg: Color(0xFFF2ECFF),
                          iconColor: Color(0xFF8B5CF6),
                        )),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 18),

                // Seção Pending Reviews
                _SectionSurface(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_awesome, size: 18,
                            color: Colors.black.withOpacity(.72)),
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

                      const _PendingItem(
                        indexLabel: '1 . 1',
                        title: 'Enclosed space entry briefing',
                        trainee: 'Ana Souza (Deck Cadet)',
                        submittedAt: '14/01/2024',
                        chapter: '1 – Safety Basics',
                        evidence:
                        'Demonstrated understanding of enclosed space hazards and entry procedures. Explained gas testing requirements and rescue protocols. Showed proper use of ventilation equipment.',
                      ),
                      const SizedBox(height: 12),
                      const _PendingItem(
                        indexLabel: '2 . 3',
                        title: 'Chart correction procedures',
                        trainee: 'Carlos Silva (Navigation Cadet)',
                        submittedAt: '13/01/2024',
                        chapter: '2 – Navigation',
                        evidence:
                        'Applied weekly notices to mariners corrections to chart BA 1234. Verified positions using GPS coordinates and updated depth soundings.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── TOP BAR ───────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const BackButton(color: Colors.black87),
            const SizedBox(width: 2),
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_boat_filled,
                  color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TPRB',
                    style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('Training Performance Record Book',
                    style: TextStyle(
                        fontSize: 12, color: Colors.black.withOpacity(.62))),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Text('C/O Marcos Rodrigues',
                      style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 8),
                  Text('Chief Officer · Flumar Brasil',
                      style: TextStyle(
                          fontSize: 12, color: Colors.black.withOpacity(.62))),
                  const SizedBox(width: 8),
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFF0F172A),
                    child: Text('CMR',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.logout, size: 18),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── KPI CARD ─────────────────────────

class _KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _KpiCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -.2,
    );

    return _Card(
      // sem height fixa: altura se ajusta ao conteúdo
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        // garante um “respiro” mínimo semelhante ao mock
        constraints: const BoxConstraints(minHeight: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // ícone vai ao rodapé
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: valueStyle),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.black.withOpacity(.62),
                    height: 1.2,
                  ),
                ),
              ],
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
      ),
    );
  }
}

// ──────────────────────── PENDING REVIEW ITEM ─────────────────────────

class _PendingItem extends StatelessWidget {
  final String indexLabel;
  final String title;
  final String trainee;
  final String submittedAt;
  final String chapter;
  final String evidence;

  const _PendingItem({
    required this.indexLabel,
    required this.title,
    required this.trainee,
    required this.submittedAt,
    required this.chapter,
    required this.evidence,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Colors.black.withOpacity(.62);

    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: const Color(0xFFF7F9FB), // cinza claro do item
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da linha
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IndexChip(text: indexLabel),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Text(title,
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
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Meta
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Meta(label: 'Trainee', value: trainee),
              _Meta(label: 'Submitted', value: submittedAt),
              _Meta(label: 'Chapter', value: chapter),
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
              evidence,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text('Submitted',
              style: const TextStyle(
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

// ───────────────────────── SUPERFÍCIES BASE ────────────────────────

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
