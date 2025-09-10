import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tprb/firebase_options.dart'; // ajuste "tprb" se o name do seu pacote for diferente

/// Reuso de um app secundário para criar usuários sem afetar a sessão atual (evita 'channel-error').
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

class NewUserPage extends StatefulWidget {
  const NewUserPage({super.key});

  @override
  State<NewUserPage> createState() => _NewUserPageState();
}

class _NewUserPageState extends State<NewUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  String _selectedRole = _roles.first;
  bool _busy = false;

  static const List<String> _roles = ['Trainee', 'Supervisor', 'Office', 'Admin'];

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _busy = true);

    try {
      // 1) Cria no Auth via app secundário
      final auth = await _SecondaryAuth.instance();
      final email = _emailCtrl.text.trim();
      const defaultPassword = 'password';

      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: defaultPassword,
      );
      final uid = cred.user!.uid;

      // 2) (Opcional) displayName simples
      await cred.user!.updateDisplayName(email.split('@').first);

      // 3) Persiste o role no Firestore (app principal)
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'email': email,
          'role': _selectedRole,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 4) Mantém a sua sessão (apenas sai do secundário)
      await auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuário criado: $email (role: $_selectedRole)')),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      final messages = <String, String>{
        'email-already-in-use': 'Este e-mail já está em uso.',
        'invalid-email': 'E-mail inválido.',
        'operation-not-allowed': 'Email/Password desativado no projeto.',
        'weak-password': 'Senha padrão não atende a política atual.',
        'channel-error':
        'Falha no canal nativo. Tente novamente (evite criar/deletar apps durante a operação).',
        'network-request-failed': 'Sem conexão com a internet.',
      };
      final msg = messages[e.code] ?? 'Falha ao criar usuário';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$msg (code: ${e.code})')),
      );
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
      appBar: AppBar(
        title: const Text('Add User'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Create a new account',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
                      final rx = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                      if (!rx.hasMatch(value)) return 'E-mail inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Role
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRole,
                        isExpanded: true,
                        items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setState(() => _selectedRole = v ?? _selectedRole),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Info senha
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E7),
                      border: Border.all(color: const Color(0xFFFFE1C2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'A senha padrão será "password". O usuário deverá alterar a senha no primeiro acesso.',
                      style: TextStyle(color: Color(0xFF8A5A00)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botão
                  FilledButton.icon(
                    onPressed: _busy ? null : _createUser,
                    icon: _busy
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.person_add_alt_1),
                    label: Text(_busy ? 'Adding...' : 'Add User'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
