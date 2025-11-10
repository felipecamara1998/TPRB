import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tprb/firebase_options.dart';

class _Vessel {
  final String id;
  final String name;
  const _Vessel(this.id, this.name);
}

Future<List<_Vessel>>? _vesselsFuture;
String? _selectedVesselId;
String? _selectedVesselName;

/// App secundário para criar usuários sem derrubar a sessão atual
class _SecondaryAuth {
  static FirebaseApp? _app;
  static FirebaseAuth? _auth;

  static Future<FirebaseAuth> instance() async {
    if (_auth != null) return _auth!;
    try {
      _app ??= Firebase.app('admin-helper');
    } catch (_) {
      _app = await Firebase.initializeApp(
        name: 'admin-helper',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    _auth = FirebaseAuth.instanceFor(app: _app!);
    return _auth!;
  }
}

// roles do sistema (permissão dentro do app)
const _systemRoles = ['admin', 'supervisor', 'office', 'trainee'];

// roles (para padronizar o campo userRole do teu Firestore)
const _Roles = [
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
  'Oiler',
  'Cadet (Deck)',
  'Cadet (Engine)',
  'Superintendent',
  'HR',
];

class NewUserPage extends StatefulWidget {
  const NewUserPage({super.key});

  @override
  State<NewUserPage> createState() => _NewUserPageState();
}

class _NewUserPageState extends State<NewUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  String _selectedSystemRole = _systemRoles.first;
  String _selectedRole = _Roles.first;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _vesselsFuture = _loadVessels();
  }

  Future<List<_Vessel>> _loadVessels() async {
    final snap = await FirebaseFirestore.instance
        .collection('vessels')
        .orderBy('name')
        .get();

    return snap.docs
        .map((d) => _Vessel(d.id, (d.data()['name'] ?? 'Unnamed') as String))
        .toList();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String _makeInitials(String name, String email) {
    final n = name.trim();
    if (n.isEmpty) {
      final user = email.split('@').first;
      if (user.length >= 2) return user.substring(0, 2).toUpperCase();
      return user.toUpperCase();
    }
    final parts = n.split(' ');
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Future<void> _createUser() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _busy = true);
    try {
      final email = _emailCtrl.text.trim();
      const defaultPassword = 'password';

      // 1) cria no Auth (app secundário)
      final auth = await _SecondaryAuth.instance();
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: defaultPassword,
      );
      final uid = cred.user!.uid;

      final fallbackName = email.split('@').first;
      await cred.user!.updateDisplayName(fallbackName);

      // 2) monta o documento no formato que o resto do app usa
      final userName = _nameCtrl.text.trim().isEmpty
          ? fallbackName
          : _nameCtrl.text.trim();

      final initials = _makeInitials(userName, email);

      final data = <String, dynamic>{
        'email': email,
        'role': _selectedSystemRole,       // role do app (admin/supervisor/...)
        'status': 'active',
        'vessel': _selectedVesselName ?? '',
        'userName': userName,
        'userRole': _selectedRole,  // <- padronizado pelo dropdown
        'initials': initials,
        'programs': <String, dynamic>{},
        'mustChangePassword': true,        // <- força troca no primeiro login
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 3) salva no Firestore principal
      await FirebaseFirestore.instance.collection('users').doc(uid).set(data);

      // 4) sai do app secundário
      await auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário criado com sucesso')),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      final msgs = <String, String>{
        'email-already-in-use': 'Este e-mail já está em uso.',
        'invalid-email': 'E-mail inválido.',
        'weak-password': 'A senha padrão não atende à política.',
        'operation-not-allowed': 'Email/senha desativado no projeto.',
        'network-request-failed': 'Sem conexão.',
      };
      final msg = msgs[e.code] ?? 'Falha ao criar usuário.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro inesperado: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(title: const Text('Create user')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create a new account',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'user@company.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Informe um e-mail';
                          final rx =
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                          if (!rx.hasMatch(value)) {
                            return 'E-mail inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Nome do usuário
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'User name',
                          hintText: 'ex.: Marcelo Degobi',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // User role (onboard) – agora dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'User role',
                          border: OutlineInputBorder(),
                        ),
                        items: _Roles
                            .map(
                              (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r),
                          ),
                        )
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // System role
                      DropdownButtonFormField<String>(
                        value: _selectedSystemRole,
                        decoration: const InputDecoration(
                          labelText: 'System role',
                          border: OutlineInputBorder(),
                        ),
                        items: _systemRoles
                            .map(
                              (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r),
                          ),
                        )
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedSystemRole = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Vessel
                      FutureBuilder<List<_Vessel>>(
                        future: _vesselsFuture,
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }
                          final vessels =
                              snap.data ?? const <_Vessel>[];
                          if (vessels.isEmpty) {
                            return const Text('No vessels found');
                          }
                          return DropdownButtonFormField<String>(
                            value: _selectedVesselId,
                            decoration: const InputDecoration(
                              labelText: 'Vessel',
                              border: OutlineInputBorder(),
                            ),
                            items: vessels
                                .map(
                                  (v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(v.name),
                              ),
                            )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedVesselId = val;
                                _selectedVesselName = vessels
                                    .firstWhere((e) => e.id == val)
                                    .name;
                              });
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _createUser,
                        child: _busy
                            ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text('Create'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
