import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateCampaignPage extends StatefulWidget {
  const CreateCampaignPage({super.key});

  @override
  State<CreateCampaignPage> createState() => _CreateCampaignPageState();
}

class _CreateCampaignPageState extends State<CreateCampaignPage> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  final TextEditingController _campaignNameCtrl = TextEditingController();
  final TextEditingController _notesCtrl        = TextEditingController();
  DateTime? _startDate;
  DateTime? _dueDate;

  String? _programId;
  String? _programTitle;

  // Target scope
  String _scope = 'all'; // all | users | vessels | roles | groups

  // Multi-select state
  final Set<String> _selectedUserIds   = {};
  final Set<String> _selectedVesselIds = {};
  final Set<String> _selectedRoles     = {};
  final Set<String> _selectedGroups    = {};

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _campaignNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Training Program', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Assign published programs to users (individually, by vessel, roles, or groups).', style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 16),

                // Campaign name
                TextFormField(
                  controller: _campaignNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Program name',
                    hintText: 'e.g., Familiarization verification',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Program selection
                _ProgramPicker(
                  onChanged: (id, title) {
                    setState(() {
                      _programId = id;
                      _programTitle = title;
                    });
                  },
                  selectedId: _programId,
                ),
                const SizedBox(height: 12),

                // Scope chips
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All users'),
                      selected: _scope == 'all',
                      onSelected: (_) => setState(() => _scope = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('By vessel'),
                      selected: _scope == 'vessels',
                      onSelected: (_) => setState(() => _scope = 'vessels'),
                    ),
                    ChoiceChip(
                      label: const Text('By role'),
                      selected: _scope == 'roles',
                      onSelected: (_) => setState(() => _scope = 'roles'),
                    ),
                    ChoiceChip(
                      label: const Text('By groups'),
                      selected: _scope == 'groups',
                      onSelected: (_) => setState(() => _scope = 'groups'),
                    ),
                    ChoiceChip(
                      label: const Text('Specific users'),
                      selected: _scope == 'users',
                      onSelected: (_) => setState(() => _scope = 'users'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_scope == 'vessels')
                  _MultiSelectBox(
                    title: 'Select vessels',
                    stream: FirebaseFirestore.instance.collection('vessels').snapshots(),
                    idSelector: (d) => d.id,
                    labelSelector: (d) => d.data()['name'] ?? d.id,
                    selected: _selectedVesselIds,
                    onChanged: (ids) => setState(() {
                      _selectedVesselIds..clear()..addAll(ids);
                    }),
                  ),

                if (_scope == 'roles')
                  _TextTagBox(
                    title: 'Roles (e.g., "Chief Officer", "Engine Cadet")',
                    selected: _selectedRoles,
                  ),

                if (_scope == 'groups')
                  _TextTagBox(
                    title: 'Groups (e.g., "New Hires 2025", "Pilotage Class")',
                    selected: _selectedGroups,
                  ),

                if (_scope == 'users')
                  _MultiSelectBox(
                    title: 'Select users',
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    idSelector: (d) => d.id,
                    labelSelector: (d) => (d.data()['displayName'] ?? d.data()['email'] ?? d.id),
                    selected: _selectedUserIds,
                    onChanged: (ids) => setState(() {
                      _selectedUserIds..clear()..addAll(ids);
                    }),
                  ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Start date',
                        value: _startDate,
                        onPick: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _startDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'Due date',
                        value: _dueDate,
                        onPick: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _dueDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _previewAssignments,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Preview assignments'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.campaign_outlined),
                      label: Text(_submitting ? 'Creating...' : 'Create campaign'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Campaign'),
      ),
      body: body,
    );
  }

  Future<void> _previewAssignments() async {
    try {
      final uids = await _resolveTargetUserIds();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Preview'),
          content: Text('This campaign will assign the program to ${uids.length} user(s).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      setState(() => _error = 'Preview error: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_programId == null) {
      setState(() => _error = 'Select a training program');
      return;
    }

    if (_scope == 'vessels' && _selectedVesselIds.isEmpty) {
      setState(() => _error = 'Select at least one vessel');
      return;
    }
    if (_scope == 'roles' && _selectedRoles.isEmpty) {
      setState(() => _error = 'Add at least one role');
      return;
    }
    if (_scope == 'groups' && _selectedGroups.isEmpty) {
      setState(() => _error = 'Add at least one group');
      return;
    }
    if (_scope == 'users' && _selectedUserIds.isEmpty) {
      setState(() => _error = 'Select at least one user');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final firebase = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;
      final now = DateTime.now();

      // (1) Cria a campanha
      final cRef = firebase.collection('campaigns').doc();
      final campaignData = <String, dynamic>{
        'campaignId': cRef.id,
        'name': _campaignNameCtrl.text.trim(),
        'programId': _programId,
        'programTitle': _programTitle,
        'scope': _scope, // all | vessels | roles | groups | users
        'targetVesselIds': _selectedVesselIds.toList(),
        'targetRoles': _selectedRoles.toList(),
        'targetGroups': _selectedGroups.toList(),
        'targetUserIds': _selectedUserIds.toList(),
        'startDate': _startDate,
        'dueDate': _dueDate,
        'notes': _notesCtrl.text.trim(),
        'createdAt': now,
        'createdBy': currentUser?.uid,
        'status': 'active',
      };
      await cRef.set(campaignData);

      // (2) Resolve usuários alvo
      final uids = await _resolveTargetUserIds();

      // (3) Cria assignments individuais + atualiza "programs" (Map) no doc do usuário
      final batch = firebase.batch();
      for (final uid in uids) {
        final aDoc = firebase.collection('assignments').doc();
        batch.set(aDoc, {
          'assignmentId': aDoc.id,
          'campaignId': cRef.id,
          'programId': _programId,
          'userId': uid,
          'startDate': _startDate,
          'dueDate': _dueDate,
          'status': 'pending',
          'createdAt': now,
        });

        // Atualiza Map "programs" do usuário
        final userRef = firebase.collection('users').doc(uid);
        batch.set(
          userRef,
          {
            'programs': {
              _programId!: {
                'title': _programTitle,
                'campaignId': cRef.id,
                'startDate': _startDate,
                'dueDate': _dueDate,
                'status': 'pending',
                'assignedAt': now,
              }
            }
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign created')));
      Navigator.pop(context);
    } catch (e) {
      setState(() { _submitting = false; _error = 'Error: $e'; });
      return;
    }

    if (mounted) {
      setState(() { _submitting = false; });
    }
  }

  Future<List<String>> _resolveTargetUserIds() async {
    final f = FirebaseFirestore.instance;
    List<String> uids = [];

    if (_scope == 'all') {
      final usersSnap = await f.collection('users').get();
      uids = usersSnap.docs.map((d) => d.id).toList();
    } else if (_scope == 'users') {
      uids = _selectedUserIds.toList();
    } else if (_scope == 'vessels') {
      // Ajuste o campo caso seu schema seja diferente (ex.: 'vessel', 'vesselCode')
      final usersSnap = await f
          .collection('users')
          .where('vesselId', whereIn: _selectedVesselIds.isEmpty ? ['__none__'] : _selectedVesselIds.toList())
          .get();
      uids = usersSnap.docs.map((d) => d.id).toList();
    } else if (_scope == 'roles') {
      final usersSnap = await f
          .collection('users')
          .where('userRole', whereIn: _selectedRoles.isEmpty ? ['__none__'] : _selectedRoles.toList())
          .get();
      uids = usersSnap.docs.map((d) => d.id).toList();
    } else if (_scope == 'groups') {
      // Espera-se users com 'groups': ['New Hires 2025', 'Bridge Familiarization', ...]
      final usersSnap = await f
          .collection('users')
          .where('groups', arrayContainsAny: _selectedGroups.isEmpty ? ['__none__'] : _selectedGroups.toList())
          .get();
      uids = usersSnap.docs.map((d) => d.id).toList();
    }

    return uids.toSet().toList(); // distinct
  }
}

/* ============================ Supporting widgets ============================ */

class _ProgramPicker extends StatelessWidget {
  final String? selectedId;
  final void Function(String id, String title) onChanged;
  const _ProgramPicker({required this.onChanged, required this.selectedId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('training_programs')
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snap) {
        final List<DropdownMenuItem<String>> items = [];
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
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedId,
              items: items.isEmpty
                  ? [const DropdownMenuItem(value: null, child: Text('No programs found'))]
                  : items,
              onChanged: (id) {
                if (id == null) return;
                final match = snap.data?.docs.firstWhere(
                      (e) => e.id == id,
                  orElse: () => throw Exception('Program not found'),
                );
                final title = (match?.data()['title'] ?? match?.data()['name'] ?? id).toString();
                onChanged(id, title);
              },
            ),
          ),
        );
      },
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
          constraints: const BoxConstraints(maxHeight: 260),
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

class _TextTagBox extends StatefulWidget {
  final String title;
  final Set<String> selected;
  const _TextTagBox({required this.title, required this.selected});

  @override
  State<_TextTagBox> createState() => _TextTagBoxState();
}

class _TextTagBoxState extends State<_TextTagBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Type and press Add',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _add,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in widget.selected)
              Chip(
                label: Text(t),
                onDeleted: () {
                  setState(() => widget.selected.remove(t));
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _add() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    setState(() {
      widget.selected.add(v);
      _controller.clear();
    });
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
