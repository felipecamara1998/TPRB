import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateCampaignPage extends StatefulWidget {
  const CreateCampaignPage({
    super.key,
    this.initialProgramId,
    this.initialProgramTitle,
    this.existingCampaignId,
    this.existingCampaignName,
  });

  /// If provided, the program is pre-selected and program picker is locked.
  final String? initialProgramId;
  final String? initialProgramTitle;

  /// If provided, this page will ADD users to an existing campaign instead of creating a new one.
  final String? existingCampaignId;
  final String? existingCampaignName;

  @override
  State<CreateCampaignPage> createState() => _CreateCampaignPageState();
}

class _CreateCampaignPageState extends State<CreateCampaignPage> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  final TextEditingController _campaignNameCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _dueDate;

  // Program selection
  String? _programId;
  String? _programTitle;

  // Target scope
  String _scope = 'users'; // all | users | vessels | roles | groups

  // Target selection
  final Set<String> _selectedUserIds = {};
  final Set<String> _selectedVesselIds = {};
  final Set<String> _selectedRoles = {};
  final Set<String> _selectedGroups = {};

  // For By role dropdown
  String? _pickedRole;

  // Prevent duplicates
  Set<String> _alreadyAssignedUserIds = {};
  bool _loadingAssigned = false;

  bool _loadingExistingCampaign = false;

  bool _submitting = false;
  String? _error;

  bool get _isExtendMode => (widget.existingCampaignId ?? '').trim().isNotEmpty;

  // ✅ Roles list (same idea as your Create User dropdown)
  static const List<String> _kUserRoles = [
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
    'OS',
    'Oiler',
    'Pumpman',
    'Fitter',
    'Motorman',
    'Cadet (Deck)',
    'Cadet (Engine)',
  ];

  @override
  void initState() {
    super.initState();

    // If opened with a program pre-selected, lock it.
    if ((widget.initialProgramId ?? '').trim().isNotEmpty) {
      _programId = widget.initialProgramId!.trim();
      _programTitle = (widget.initialProgramTitle ?? _programId!).trim();
    }

    if (_isExtendMode) {
      // Extend mode = only add users to an existing campaign
      _scope = 'users';
      _campaignNameCtrl.text = (widget.existingCampaignName ?? '').trim();
      _bootstrapFromExistingCampaign();
    } else {
      // Create mode: if program already known, preload assigned list
      if (_programId != null) {
        _refreshAlreadyAssigned();
      }
    }
  }

  @override
  void dispose() {
    _campaignNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Existing campaign bootstrap (extend mode)
  // ─────────────────────────────────────────────────────────────
  Future<void> _bootstrapFromExistingCampaign() async {
    setState(() {
      _loadingExistingCampaign = true;
      _error = null;
    });

    try {
      final campId = widget.existingCampaignId!.trim();
      final snap = await FirebaseFirestore.instance.collection('campaigns').doc(campId).get();
      if (!snap.exists) {
        if (mounted) {
          setState(() {
            _error = 'Existing training not found.';
          });
        }
        return;
      }

      final d = snap.data() ?? {};

      final pid = (d['programId'] ?? _programId ?? '').toString().trim();
      final ptitle = (d['programTitle'] ?? _programTitle ?? pid).toString().trim();

      final Timestamp? sTs = d['startDate'] as Timestamp?;
      final Timestamp? dTs = d['dueDate'] as Timestamp?;

      if (!mounted) return;

      setState(() {
        _programId = pid.isEmpty ? null : pid;
        _programTitle = ptitle.isEmpty ? _programId : ptitle;

        final name = (d['name'] ?? widget.existingCampaignName ?? '').toString();
        if (name.trim().isNotEmpty) _campaignNameCtrl.text = name.trim();

        _notesCtrl.text = (d['notes'] ?? '').toString();
        _startDate = sTs?.toDate();
        _dueDate = dTs?.toDate();

        _scope = 'users';
      });

      if (_programId != null) {
        await _refreshAlreadyAssigned();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to load existing training: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingExistingCampaign = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Already assigned users (for this program) - from assignments
  // ─────────────────────────────────────────────────────────────
  Future<void> _refreshAlreadyAssigned() async {
    final pid = _programId;
    if (pid == null || pid.isEmpty) return;

    setState(() => _loadingAssigned = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('assignments')
          .where('programId', isEqualTo: pid)
          .get();

      final ids = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = (data['userId'] ?? '').toString();
        final status = (data['status'] ?? '').toString().toLowerCase();

        // Treat as assigned unless explicitly cancelled/archived
        if (uid.isNotEmpty && status != 'cancelled' && status != 'archived') {
          ids.add(uid);
        }
      }

      if (mounted) setState(() => _alreadyAssignedUserIds = ids);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load already assigned users: $e');
    } finally {
      if (mounted) setState(() => _loadingAssigned = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Resolve target users (robust, avoids extra indexes)
  // ─────────────────────────────────────────────────────────────
  Future<List<String>> _resolveTargetUserIds() async {
    final f = FirebaseFirestore.instance;

    if (_scope == 'all') {
      final usersSnap = await f.collection('users').get();
      return usersSnap.docs.map((d) => d.id).toList();
    }

    if (_scope == 'users') {
      return _selectedUserIds.toList();
    }

    final usersSnap = await f.collection('users').get();
    final out = <String>[];

    for (final doc in usersSnap.docs) {
      final data = doc.data();

      if (_scope == 'vessels') {
        final vessel = (data['vessel'] ?? data['vesselId'] ?? '').toString();
        if (_selectedVesselIds.contains(vessel)) out.add(doc.id);
      } else if (_scope == 'roles') {
        final role = (data['userRole'] ?? data['role'] ?? '').toString();
        if (_selectedRoles.contains(role)) out.add(doc.id);
      } else if (_scope == 'groups') {
        final g = data['groups'];
        if (g is List) {
          final list = g.map((e) => e.toString()).toSet();
          if (list.intersection(_selectedGroups).isNotEmpty) out.add(doc.id);
        } else {
          final one = (data['group'] ?? data['userGroup'] ?? '').toString();
          if (_selectedGroups.contains(one)) out.add(doc.id);
        }
      }
    }

    return out;
  }

  // ─────────────────────────────────────────────────────────────
  // Submit
  // ─────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    if (_programId == null || _programId!.isEmpty) {
      setState(() => _error = 'Please select a training program.');
      return;
    }

    // Validations
    if (_isExtendMode) {
      if (_selectedUserIds.isEmpty) {
        setState(() => _error = 'Select at least one user.');
        return;
      }
    } else {
      if (_scope == 'users' && _selectedUserIds.isEmpty) {
        setState(() => _error = 'Select at least one user.');
        return;
      }
      if (_scope == 'vessels' && _selectedVesselIds.isEmpty) {
        setState(() => _error = 'Select at least one vessel.');
        return;
      }
      if (_scope == 'roles' && _selectedRoles.isEmpty) {
        setState(() => _error = 'Select at least one role.');
        return;
      }
      if (_scope == 'groups' && _selectedGroups.isEmpty) {
        setState(() => _error = 'Add at least one group.');
        return;
      }
    }

    setState(() => _submitting = true);

    try {
      await _refreshAlreadyAssigned();

      final firebase = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;
      final now = DateTime.now();

      final targets = await _resolveTargetUserIds();

      // Backend anti-duplication
      final filteredTargets =
      targets.where((uid) => !_alreadyAssignedUserIds.contains(uid)).toList();

      if (filteredTargets.isEmpty) {
        setState(() {
          _submitting = false;
          _error = 'All selected users already have this program assigned.';
        });
        return;
      }

      // Campaign id
      final String campaignId;

      if (_isExtendMode) {
        // Extend existing campaign: DO NOT change dates/notes/scope/name.
        campaignId = widget.existingCampaignId!.trim();
        final cRef = firebase.collection('campaigns').doc(campaignId);

        await cRef.update({
          'targetUserIds': FieldValue.arrayUnion(filteredTargets),
          'updatedAt': now,
          'updatedBy': currentUser?.uid,
        });
      } else {
        // Create a new campaign
        final cRef = firebase.collection('campaigns').doc();
        campaignId = cRef.id;

        await cRef.set({
          'campaignId': campaignId,
          'createdAt': now,
          'createdBy': currentUser?.uid,
          'dueDate': _dueDate,
          'name': _campaignNameCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
          'programId': _programId,
          'programTitle': _programTitle,
          'scope': _scope,
          'startDate': _startDate,
          'status': 'active',
          'targetGroups': _selectedGroups.toList(),
          'targetRoles': _selectedRoles.toList(),
          'targetUserIds': _scope == 'users' ? _selectedUserIds.toList() : [],
          'targetVesselIds': _selectedVesselIds.toList(),
        });
      }

      // Create assignments + update users.programs map
      final batch = firebase.batch();

      for (final uid in filteredTargets) {
        final aRef = firebase.collection('assignments').doc();
        batch.set(aRef, {
          'assignmentId': aRef.id,
          'campaignId': campaignId,
          'programId': _programId,
          'programTitle': _programTitle,
          'userId': uid,
          'createdAt': now,
          'createdBy': currentUser?.uid,
          'status': 'active',
          'startDate': _startDate,
          'dueDate': _dueDate,
        });

        // Keep user's programs map updated (your existing structure)
        final uRef = firebase.collection('users').doc(uid);
        batch.set(
          uRef,
          {
            'programs': {
              _programId!: {
                'assignedAt': now,
                'campaignId': campaignId,
                'dueDate': _dueDate,
                'startDate': _startDate,
                'status': 'pending',
              }
            }
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lockedProgram =
        _isExtendMode || (widget.initialProgramId ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isExtendMode ? 'Add users to this training' : 'Create training'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loadingExistingCampaign)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Loading training...'),
                        ],
                      ),
                    ),

                  // Campaign name (locked in extend mode)
                  TextFormField(
                    controller: _campaignNameCtrl,
                    enabled: !_isExtendMode,
                    decoration: InputDecoration(
                      labelText:
                      _isExtendMode ? 'Training (existing)' : 'Training name',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (_isExtendMode) return null;
                      return (v == null || v.trim().isEmpty) ? 'Required' : null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Program selection
                  if (lockedProgram)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Training program',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        (_programTitle ?? _programId ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    _ProgramPicker(
                      selectedId: _programId,
                      onChanged: (id, title) async {
                        setState(() {
                          _programId = id;
                          _programTitle = title;
                          _selectedUserIds.clear();
                          _selectedVesselIds.clear();
                          _selectedRoles.clear();
                          _selectedGroups.clear();
                          _pickedRole = null;
                        });
                        await _refreshAlreadyAssigned();
                      },
                    ),
                  const SizedBox(height: 12),

                  if (_loadingAssigned)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Loading already assigned users...'),
                        ],
                      ),
                    ),

                  // Scope (hidden in extend mode)
                  if (!_isExtendMode) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                  ],

                  // Targets
                  if (!_isExtendMode && _scope == 'vessels')
                    _MultiSelectBox(
                      title: 'Select vessels',
                      stream: FirebaseFirestore.instance
                          .collection('vessels')
                          .snapshots(),
                      idSelector: (d) => (d.data()['name'] ?? d.id).toString(),
                      searchKeySelector: (d) => (d.data()['name'] ?? d.id).toString(),
                      titleBuilder: (d) => Text((d.data()['name'] ?? d.id).toString()),
                      selected: _selectedVesselIds,
                      onChanged: (ids) => setState(() {
                        _selectedVesselIds
                          ..clear()
                          ..addAll(ids);
                      }),
                    ),

                  // ✅ NEW: By role uses a dropdown with all roles
                  if (!_isExtendMode && _scope == 'roles')
                    _RolesDropdownBox(
                      roles: _kUserRoles,
                      selectedRoles: _selectedRoles,
                      pickedRole: _pickedRole,
                      onPickedRoleChanged: (v) => setState(() => _pickedRole = v),
                      onAddRole: () {
                        final r = (_pickedRole ?? '').trim();
                        if (r.isEmpty) return;
                        setState(() {
                          _selectedRoles.add(r);
                        });
                      },
                      onRemoveRole: (r) => setState(() => _selectedRoles.remove(r)),
                    ),

                  if (!_isExtendMode && _scope == 'groups')
                    _TextTagBox(
                      title: 'Groups',
                      hint: 'Ex: New Hires 2025, Cadets, Officers...',
                      selected: _selectedGroups,
                    ),

                  // Users (always shown in extend mode; shown in create mode only when scope==users)
                  if (_isExtendMode || _scope == 'users')
                    _MultiSelectBox(
                      title: 'Select users',
                      stream:
                      FirebaseFirestore.instance.collection('users').snapshots(),
                      idSelector: (d) => d.id,
                      disabledIds: _alreadyAssignedUserIds,
                      disabledLabel: 'Already assigned',
                      selected: _selectedUserIds,
                      onChanged: (ids) => setState(() {
                        _selectedUserIds
                          ..clear()
                          ..addAll(ids);
                      }),
                      searchKeySelector: (d) {
                        final data = d.data();
                        final name =
                        (data['userName'] ?? data['displayName'] ?? '').toString();
                        final role =
                        (data['userRole'] ?? data['role'] ?? '').toString();
                        final vessel = (data['vessel'] ?? '').toString();
                        final email = (data['email'] ?? '').toString();
                        return '$name $role $vessel $email';
                      },
                      titleBuilder: (d) {
                        final data = d.data();
                        final name = (data['userName'] ??
                            data['displayName'] ??
                            data['email'] ??
                            d.id)
                            .toString();
                        final role =
                        (data['userRole'] ?? data['role'] ?? '').toString();
                        final vessel = (data['vessel'] ?? '').toString();
                        final email = (data['email'] ?? '').toString();

                        final line2 = [
                          if (role.isNotEmpty) role,
                          if (vessel.isNotEmpty) vessel,
                        ].join(' • ');

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (line2.isNotEmpty)
                              Text(line2,
                                  style: TextStyle(
                                      color: Colors.grey[700], fontSize: 12)),
                            if (email.isNotEmpty)
                              Text(email,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12)),
                          ],
                        );
                      },
                    ),

                  const SizedBox(height: 12),

                  // Start/Due/Notes
                  // In extend mode: HIDE these fields (we inherit from existing campaign)
                  if (!_isExtendMode) ...[
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
                                initialDate: _dueDate ??
                                    DateTime.now().add(const Duration(days: 30)),
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
                  ],

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),

                  Row(
                    children: [
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Icon(_isExtendMode
                            ? Icons.person_add_alt_1
                            : Icons.campaign_outlined),
                        label: Text(_submitting
                            ? 'Saving...'
                            : (_isExtendMode ? 'Add users' : 'Create')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ============================ Supporting widgets ============================ */

class _ProgramPicker extends StatelessWidget {
  final String? selectedId;
  final void Function(String id, String title) onChanged;

  const _ProgramPicker({
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('training_programs').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final items = docs.map((d) {
          final title = (d.data()['title'] ?? d.data()['name'] ?? d.id).toString();
          return DropdownMenuItem<String>(
            value: d.id,
            child: Text(title),
          );
        }).toList();

        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Training program',
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedId,
              hint: const Text('Select...'),
              items: items,
              onChanged: (id) {
                if (id == null) return;
                final match = docs.firstWhere((e) => e.id == id);
                final title =
                (match.data()['title'] ?? match.data()['name'] ?? id).toString();
                onChanged(id, title);
              },
            ),
          ),
        );
      },
    );
  }
}

class _RolesDropdownBox extends StatelessWidget {
  const _RolesDropdownBox({
    required this.roles,
    required this.selectedRoles,
    required this.pickedRole,
    required this.onPickedRoleChanged,
    required this.onAddRole,
    required this.onRemoveRole,
  });

  final List<String> roles;
  final Set<String> selectedRoles;
  final String? pickedRole;

  final ValueChanged<String?> onPickedRoleChanged;
  final VoidCallback onAddRole;
  final ValueChanged<String> onRemoveRole;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Roles', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Select role',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: pickedRole,
                    hint: const Text('Choose...'),
                    items: roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: onPickedRoleChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: pickedRole == null ? null : onAddRole,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in selectedRoles)
              Chip(
                label: Text(r),
                onDeleted: () => onRemoveRole(r),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _MultiSelectBox extends StatefulWidget {
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  final String Function(QueryDocumentSnapshot<Map<String, dynamic>>) idSelector;

  final String Function(QueryDocumentSnapshot<Map<String, dynamic>>) searchKeySelector;

  final Widget Function(QueryDocumentSnapshot<Map<String, dynamic>>) titleBuilder;

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  final Set<String> disabledIds;
  final String disabledLabel;

  const _MultiSelectBox({
    required this.title,
    required this.stream,
    required this.idSelector,
    required this.searchKeySelector,
    required this.titleBuilder,
    required this.selected,
    required this.onChanged,
    this.disabledIds = const {},
    this.disabledLabel = 'Disabled',
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
          constraints: const BoxConstraints(maxHeight: 360),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final docs = snap.data?.docs ?? [];
              final filtered = docs.where((d) {
                final key = widget.searchKeySelector(d).toLowerCase();
                return _search.isEmpty || key.contains(_search);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No results'),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final d = filtered[i];
                  final id = widget.idSelector(d);
                  final selected = widget.selected.contains(id);
                  final isDisabled = widget.disabledIds.contains(id);

                  return CheckboxListTile(
                    dense: true,
                    value: selected,
                    title: widget.titleBuilder(d),
                    subtitle: isDisabled ? Text(widget.disabledLabel) : null,
                    onChanged: isDisabled
                        ? null
                        : (v) {
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
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TextTagBox extends StatefulWidget {
  final String title;
  final String hint;
  final Set<String> selected;

  const _TextTagBox({
    required this.title,
    required this.hint,
    required this.selected,
  });

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

  void _add() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    setState(() {
      widget.selected.add(v);
      _controller.clear();
    });
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
                decoration: InputDecoration(
                  hintText: widget.hint,
                  border: const OutlineInputBorder(),
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
                onDeleted: () => setState(() => widget.selected.remove(t)),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Select date'
        : '${value!.year.toString().padLeft(4, '0')}-'
        '${value!.month.toString().padLeft(2, '0')}-'
        '${value!.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(text),
      ),
    );
  }
}
