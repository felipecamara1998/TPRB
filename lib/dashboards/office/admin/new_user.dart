import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Tela dual:
/// - Create (userId == null)
/// - Edit   (userId != null)  -> email e user name bloqueados + botão Delete
class NewUserPage extends StatefulWidget {
  const NewUserPage({super.key, this.userId});
  final String? userId;

  @override
  State<NewUserPage> createState() => _NewUserPageState();
}

class _NewUserPageState extends State<NewUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _initialsCtrl = TextEditingController();

  bool _loading = false;
  bool get _isEdit => widget.userId != null;

  // senha temporária padrão para novos usuários
  // (ajuste isso depois para a política que você quiser)
  static const String _tempPassword = 'password';

  // User type e roles
  static const List<String> _userTypes = ['seafarer', 'office'];
  String _userType = 'seafarer';

  static const List<String> _seafarerRoles = [
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

  static const List<String> _officeRoles = [
    'Superintendent',
    'HR',
  ];

  String? _role;

  // Vessels
  List<String> _vesselNames = [];
  String? _vesselName; // somente o nome, conforme sua necessidade

  @override
  void initState() {
    super.initState();
    _fetchVessels();
    if (_isEdit) _loadUser();
    // valor default do role na criação
    _role = _seafarerRoles.first;
  }

  Future<void> _fetchVessels() async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('vessels')
          .orderBy('name')
          .get();
      final names = <String>[];
      for (final d in q.docs) {
        final n = (d.data()['name'] ?? '').toString().trim();
        if (n.isNotEmpty) names.add(n);
      }
      setState(() {
        _vesselNames = names;
        // se ainda não havia escolhido nada, define primeira (para seafarer)
        if (!_isEdit && _userType == 'seafarer' && names.isNotEmpty) {
          _vesselName = names.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar vessels: $e')),
        );
      }
    }
  }

  String _roleLabelFromType(String role) => role; // labels já estão prontos

  List<String> get _rolesForCurrentType =>
      _userType == 'seafarer' ? _seafarerRoles : _officeRoles;

  void _ensureRoleFitsType() {
    final list = _rolesForCurrentType;
    if (_role == null || !list.contains(_role)) {
      _role = list.first;
    }
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final d = snap.data() ?? {};

      _emailCtrl.text = (d['email'] ?? '').toString();
      _nameCtrl.text = (d['userName'] ?? d['name'] ?? '').toString();
      _initialsCtrl.text = (d['initials'] ?? '').toString();

      _userType = (d['userType'] ?? d['type'] ?? 'seafarer')
          .toString()
          .toLowerCase();
      if (!_userTypes.contains(_userType)) _userType = 'seafarer';

      _role = (d['role'] ?? '').toString();
      _vesselName = (d['vesselName'] ?? d['vessel'] ?? '').toString();

      // garante consistência com o tipo
      _ensureRoleFitsType();

      // se office, vessel fica desabilitado; se seafarer sem valor, tenta primeira da lista
      if (_userType == 'seafarer' &&
          (_vesselName == null || _vesselName!.isEmpty)) {
        if (_vesselNames.isNotEmpty) _vesselName = _vesselNames.first;
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar usuário: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // validações específicas
    if (_userType == 'seafarer') {
      if (_role == null || _role!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione o role.')),
        );
        return;
      }
      if (_vesselName == null || _vesselName!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione o vessel.')),
        );
        return;
      }
    } else {
      // office
      if (_role == null || !_officeRoles.contains(_role)) {
        _role = _officeRoles.first;
      }
      _vesselName = 'Office';
    }

    setState(() => _loading = true);
    try {
      final users = FirebaseFirestore.instance.collection('users');

      final payload = <String, dynamic>{
        'email': _emailCtrl.text.trim(),
        'userName': _nameCtrl.text.trim(),
        'initials': _initialsCtrl.text.trim(),
        'role': _userType,
        'status': 'active',// seafarer | office
        'userRole': _role, // conforme o tipo
        'vessel': _userType == 'seafarer'
            ? (_vesselName ?? '')
            : 'Office', // somente nome
      };

      if (_isEdit) {
        // EDIT: não mexe em mustChangePassword
        await users.doc(widget.userId).update(payload);
      } else {
        // CREATE:
        // 1) cria usuário no Firebase Auth
        final auth = FirebaseAuth.instance;
        final cred = await auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _tempPassword,
        );
        final uid = cred.user!.uid;

        // 2) salva documento em users/<uid> no Firestore
        await users.doc(uid).set({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
          'mustChangePassword': true,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'User updated.' : 'User created.')),
      );
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      String msg = 'Erro ao criar usuário no Auth.';
      if (e.code == 'email-already-in-use') {
        msg = 'Já existe uma conta com este email.';
      } else if (e.code == 'invalid-email') {
        msg = 'Email inválido.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (!_isEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user?'),
        content: const Text(
          'This will remove the user document from Firestore. '
              'A conta no Firebase Auth (se existir) não será removida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) _delete();
  }

  Future<void> _delete() async {
    if (!_isEdit) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User deleted.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao deletar: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _initialsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit User' : 'Create User';
    final action = _isEdit ? 'Save changes' : 'Create';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _loading ? null : _confirmDelete,
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            enabled: !_isEdit, // bloqueado no modo edição
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (s.isEmpty) return 'Required';
                              if (!s.contains('@')) return 'Invalid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'User name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            enabled: !_isEdit, // bloqueado no modo edição
                            validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _initialsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Initials (optional)',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // User Type
                          DropdownButtonFormField<String>(
                            value: _userTypes.contains(_userType)
                                ? _userType
                                : 'seafarer',
                            items: _userTypes
                                .map(
                                  (t) => DropdownMenuItem<String>(
                                value: t,
                                child: Text(
                                  t[0].toUpperCase() + t.substring(1),
                                ),
                              ),
                            )
                                .toList(growable: false),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _userType = v;
                                _ensureRoleFitsType();
                                // se virou office, zera vessel; se seafarer, garante um vessel
                                if (_userType == 'office') {
                                  _vesselName = '';
                                } else {
                                  if ((_vesselName ?? '').isEmpty &&
                                      _vesselNames.isNotEmpty) {
                                    _vesselName = _vesselNames.first;
                                  }
                                }
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'User type',
                              prefixIcon:
                              Icon(Icons.verified_user_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Role dependente do tipo
                          DropdownButtonFormField<String>(
                            value: _rolesForCurrentType.contains(_role)
                                ? _role
                                : _rolesForCurrentType.first,
                            items: _rolesForCurrentType
                                .map(
                                  (r) => DropdownMenuItem<String>(
                                value: r,
                                child: Text(_roleLabelFromType(r)),
                              ),
                            )
                                .toList(growable: false),
                            onChanged: (v) =>
                                setState(() => _role = v),
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              prefixIcon:
                              Icon(Icons.workspace_premium_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Vessel (só seafarer)
                          DropdownButtonFormField<String>(
                            value: (_userType == 'seafarer' &&
                                _vesselName != null &&
                                _vesselName!.isNotEmpty &&
                                _vesselNames.contains(_vesselName))
                                ? _vesselName
                                : (_userType == 'seafarer' &&
                                _vesselNames.isNotEmpty
                                ? _vesselNames.first
                                : null),
                            items: _vesselNames
                                .map(
                                  (n) => DropdownMenuItem<String>(
                                value: n,
                                child: Text(n),
                              ),
                            )
                                .toList(growable: false),
                            onChanged: _userType == 'seafarer'
                                ? (v) =>
                                setState(() => _vesselName = v)
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Vessel',
                              prefixIcon:
                              Icon(Icons.directions_boat_outlined),
                            ),
                            disabledHint:
                            const Text('Not applicable for Office'),
                          ),

                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _save,
                              child: Text(action),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_loading)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color(0x33FFFFFF),
                    child:
                    Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
