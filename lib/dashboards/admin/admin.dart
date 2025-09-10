import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'new_user.dart';
import 'admin_vessels.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  late final TabController _tabController;
  static const double _maxContentWidth = 1100;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleAddUser() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewUserPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.book_outlined, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(
              'TPRB Admin',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.indigo,
                unselectedLabelColor: Colors.black87,
                indicatorColor: Colors.indigo,
                tabs: const [
                  Tab(text: 'TPRB Editions'),
                  Tab(text: 'Chapters'),
                  Tab(text: 'Tasks'),
                  Tab(text: 'Vessels'),
                  Tab(text: 'Users'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          // ✅ Uma ÚNICA área de conteúdo: corrige o “segundo bloco”.
          child: TabBarView(
            controller: _tabController,
            children: [
              const _EditionsTab(),
              const _ChaptersTab(),
              const _TasksTab(),
              const _VesselsTab(),
              _UsersTab(onAddUser: _handleAddUser),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------- Widgets auxiliares de estrutura/estilo ----------

class _CardSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  const _CardSection({
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // Header com título + ações
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.folder_copy_outlined, color: Colors.blueGrey.shade300),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                      )
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 12),
          // Cartão principal
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color fg;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFF1F6FEB),
    this.fg = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: fg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// ---------- Conteúdo das Abas (placeholders mantidos) ----------

class _EditionsTab extends StatelessWidget {
  const _EditionsTab();

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      title: 'TPRB Editions',
      subtitle: 'Manage training content versions and publish updates to the fleet',
      actions: [
        _PillButton(
          label: 'New Edition',
          icon: Icons.add,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('New Edition tapped')),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _EditionItem(
            version: 'Version 1.0',
            statusText: 'published',
            statusColor: Color(0xFF2E7D32),
            tasksCount: 45,
            description: 'Initial TPRB edition with all core competencies',
            created: '14/12/2023',
            effective: '31/12/2023',
            author: 'Training Admin',
            showPublish: false,
          ),
          SizedBox(height: 12),
          _EditionItem(
            version: 'Version 1.1',
            statusText: 'draft',
            statusColor: Color(0xFF455A64),
            tasksCount: 48,
            description: 'Added new safety protocols and updated navigation procedures',
            created: '09/01/2024',
            effective: '29/02/2024',
            author: 'Training Admin',
            showPublish: true,
          ),
          SizedBox(height: 16),
          _ImpactBox(
            bulletPoints: [
              '4 active vessels will receive the new edition',
              '14 trainees will be notified of content updates',
              '8 officers will need to review mapping changes',
              'Existing progress will be preserved with migration mapping',
            ],
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EditionItem extends StatelessWidget {
  final String version;
  final String statusText;
  final Color statusColor;
  final int tasksCount;
  final String description;
  final String created;
  final String effective;
  final String author;
  final bool showPublish;

  const _EditionItem({
    required this.version,
    required this.statusText,
    required this.statusColor,
    required this.tasksCount,
    required this.description,
    required this.created,
    required this.effective,
    required this.author,
    required this.showPublish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EDF3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            children: [
              Text(version,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              _statusChip(statusText, statusColor),
              const SizedBox(width: 8),
              _countChip('$tasksCount tasks'),
              const Spacer(),
              _ghostButton('Edit', Icons.edit, onTap: () {}),
              const SizedBox(width: 8),
              _ghostButton('Clone', Icons.copy_all_outlined, onTap: () {}),
              const SizedBox(width: 8),
              if (showPublish)
                _PillButton(
                  label: 'Publish',
                  icon: Icons.cloud_upload_outlined,
                  onPressed: () {},
                )
              else
                _ghostButton('Audit Log', Icons.history, onTap: () {}),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _metaText('Created: $created'),
              _metaText('Effective: $effective'),
              _metaText('By: $author'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _countChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F0FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4E0FF)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF1F6FEB), fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _ghostButton(String label, IconData icon, {required VoidCallback onTap}) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _metaText(String text) {
    return Text(text, style: const TextStyle(color: Colors.black54));
  }
}

class _ImpactBox extends StatelessWidget {
  final List<String> bulletPoints;
  const _ImpactBox({required this.bulletPoints});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E7),
        border: Border.all(color: const Color(0xFFFFE1C2)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB26A00)),
              SizedBox(width: 8),
              Text(
                'Publishing Impact',
                style: TextStyle(
                  color: Color(0xFFB26A00),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...bulletPoints.map((b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• $b'),
          )),
        ],
      ),
    );
  }
}

class _ChaptersTab extends StatelessWidget {
  const _ChaptersTab();

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      title: 'Chapters',
      subtitle: 'Create, edit and organize chapters for each edition',
      child: _placeholderList(),
    );
  }

  Widget _placeholderList() {
    return Column(
      children: List.generate(
        3,
            (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7EDF3)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_stories_outlined, color: Colors.blueGrey.shade400),
              const SizedBox(width: 12),
              Expanded(child: Text('Chapter ${i + 1} (placeholder)')),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      title: 'Tasks',
      subtitle: 'Define tasks and competencies for training',
      child: _placeholderGrid(),
    );
  }

  Widget _placeholderGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 700;
      final crossAxisCount = isWide ? 2 : 1;

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isWide ? 2.6 : 2.0,
        ),
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7EDF3)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.task_alt_outlined, color: Colors.blueGrey.shade400),
                const SizedBox(width: 12),
                Expanded(child: Text('Task ${index + 1} (placeholder)')),
              ],
            ),
          );
        },
      );
    });
  }
}

class _VesselsTab extends StatelessWidget {
  const _VesselsTab();

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      title: 'Vessels',
      subtitle: 'Assign editions and monitor vessel training adoption',
      child: Column(
        children: const [
          AdminVesselsTab(),
        ]
      ),
    );
  }
}

/// -------------------- USERS (dinâmico do Firestore) --------------------

class _UsersTab extends StatelessWidget {
  final VoidCallback onAddUser;

  const _UsersTab({required this.onAddUser});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('users')
        .orderBy('email'); // ordena de forma estável; 'email' deve existir

    return _CardSection(
      title: 'Users',
      subtitle: 'Invite admins, officers and trainees, and assign roles.',
      actions: [
        _PillButton(
          label: 'Add User',
          icon: Icons.person_add_alt_1,
          onPressed: onAddUser,
        ),
      ],
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _UsersLoading();
          }
          if (snapshot.hasError) {
            return _UsersError(error: snapshot.error.toString());
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return _UsersEmpty(onAddUser: onAddUser);
          }

          return Column(
            children: [
              for (final doc in docs) _UserRow.fromDoc(doc),
            ],
          );
        },
      ),
    );
  }
}

class _UsersLoading extends StatelessWidget {
  const _UsersLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
            (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7EDF3)),
          ),
          child: Row(
            children: const [
              SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Carregando usuários...')),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsersError extends StatelessWidget {
  final String error;
  const _UsersError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD0D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text('Erro ao carregar usuários: $error')),
        ],
      ),
    );
  }
}

class _UsersEmpty extends StatelessWidget {
  final VoidCallback onAddUser;
  const _UsersEmpty({required this.onAddUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EDF3)),
      ),
      child: Column(
        children: [
          const Text(
            'Nenhum usuário encontrado.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('Clique em "Add User" para cadastrar o primeiro.'),
          const SizedBox(height: 12),
          _PillButton(
            label: 'Add User',
            icon: Icons.person_add_alt_1,
            onPressed: onAddUser,
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String status;

  const _UserRow({
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  /// Constrói a linha a partir de um documento do Firestore
  factory _UserRow.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final email = (data['email'] as String?)?.trim() ?? 'unknown@domain';
    final role = (data['role'] as String?)?.trim() ?? 'Unknown';
    final status = (data['status'] as String?)?.trim() ?? 'active';
    final name = (data['name'] as String?)?.trim() ??
        email.split('@').first; // fallback simples

    return _UserRow(
      name: name,
      email: email,
      role: role,
      status: status,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EDF3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(email, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          _roleChip(role),
          const SizedBox(width: 8),
          _statusChip(status),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              // futuro: abrir menu de ações (editar role/status, reset senha, etc.)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ações do usuário (em breve)')),
              );
            },
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Actions',
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String role) {
    final mapColor = {
      'Admin': const Color(0xFF1F6FEB),
      'Office': const Color(0xFF4E8EEF),
      'Supervisor': const Color(0xFF6C8AAB),
      'Trainee': const Color(0xFF2E7D32),
    };
    final c = mapColor[role] ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(role, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusChip(String status) {
    final isActive = status.toLowerCase() == 'active';
    final c = isActive ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E);
    final label = isActive ? 'Active' : 'Inactive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );
  }
}