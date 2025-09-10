// lib/dashboards/admin/admin_vessels.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tprb/firebase_options.dart';

class AdminVesselsTab extends StatefulWidget {
  const AdminVesselsTab({super.key});

  @override
  State<AdminVesselsTab> createState() => _AdminVesselsTabState();
}

class _AdminVesselsTabState extends State<AdminVesselsTab> {
  final _col = FirebaseFirestore.instance.collection('vessels');

  // Garante Firebase (se já estiver iniciado, não faz nada)
  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  // Evita docs sem 'name' no orderBy
  Query<Map<String, dynamic>> _query() =>
      _col.where('name', isGreaterThan: '').orderBy('name');

  int _colsFor(double w) {
    if (w >= 1200) return 6;
    if (w >= 1000) return 5;
    if (w >= 800) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  String _titleCase(String s) {
    s = s.trim().replaceAll(RegExp(r'[-_]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    return s
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _addVessel() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar navio'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome do navio',
            hintText: 'Ex.: Bow Orion',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Adicionar')),
        ],
      ),
    );
    if (ok != true) return;

    final name = _titleCase(c.text);
    if (name.isEmpty) return _snack('Informe um nome válido.');

    try {
      final dup = await _col.where('name', isEqualTo: name).limit(1).get();
      if (dup.docs.isNotEmpty) return _snack('Já existe um navio com esse nome.');

      await _col.add({'name': name, 'createdAt': FieldValue.serverTimestamp()});
      _snack('Navio adicionado: $name');
    } catch (e) {
      _snack('Erro ao adicionar: $e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ensureFirebase(),
      builder: (context, init) {
        if (init.hasError) return _Error('Erro ao iniciar Firebase: ${init.error}');
        if (init.connectionState != ConnectionState.done) return const _Loading();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _query().snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return _Error('Erro Firestore: ${snap.error}');
            if (!snap.hasData) return const _Loading();

            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const _Empty('Nenhum navio encontrado em “vessels”.');
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cols = _colsFor(width);

                final header = Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Vessels', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      FilledButton.icon(
                        onPressed: _addVessel,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                );

                // MODO 1: Altura É limitada → usa GridView normal (melhor performance)
                if (constraints.hasBoundedHeight) {
                  return Column(
                    children: [
                      header,
                      const SizedBox(height: 8),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 16 / 10,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final data = docs[i].data();
                            final raw = (data['name'] as String?) ?? '';
                            final title = raw.trim().isEmpty ? docs[i].id : raw;
                            return _VesselCard(title: title);
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          primary: false,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 16 / 10,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final data = docs[i].data();
                            final raw = (data['name'] as String?) ?? '';
                            final title = raw.trim().isEmpty ? docs[i].id : raw;
                            return _VesselCard(title: title);
                          },
                        ),
                      ],
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class _VesselCard extends StatelessWidget {
  const _VesselCard({required this.title, this.onTap});
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.directions_boat_filled_outlined, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.msg);
  final String msg;
  @override
  Widget build(BuildContext context) => Center(child: Text(msg));
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class _Error extends StatelessWidget {
  const _Error(this.msg);
  final String msg;
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      msg,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
