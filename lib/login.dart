import 'dart:ui'; // para o ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// importe suas páginas reais
import 'package:tprb/dashboards/seafarer/trainee/trainee.dart';
import 'package:tprb/dashboards/seafarer/supervisor/supervisor.dart';
import 'package:tprb/dashboards/office/admin/admin.dart';
import 'package:tprb/dashboards/office/office.dart';
import 'package:tprb/dashboards/seafarer/seafarer.dart';
import 'package:tprb/dashboards/office/office_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _busy = true);
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      await _routeUser(cred.user!);
    } on FirebaseAuthException catch (e) {
      final map = <String, String>{
        'invalid-email': 'E-mail inválido.',
        'user-disabled': 'Usuário desativado.',
        'user-not-found': 'Usuário não encontrado.',
        'wrong-password': 'Senha incorreta.',
        'too-many-requests': 'Muitas tentativas. Tente mais tarde.',
        'network-request-failed': 'Sem conexão à internet.',
      };
      _showSnack(map[e.code] ?? 'Falha ao entrar. ${e.message ?? ''}');
    } catch (e) {
      _showSnack('Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _routeUser(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      final role = (data['role'] as String?)?.trim() ?? '';
      final mustChange = data['mustChangePassword'] as bool? ?? false;

      if (role.isEmpty) {
        _showSnack('Seu perfil ainda não possui um papel definido.');
        return;
      }

      if (mustChange) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ChangePasswordPage(user: user, role: role),
          ),
              (_) => false,
        );
        return;
      }

      final page = _pageForRole(role);
      if (page == null) {
        _showSnack('Role desconhecido: $role');
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => page),
            (_) => false,
      );
    } catch (e) {
      _showSnack('Não foi possível carregar seu perfil. $e');
    }
  }

  Widget? _pageForRole(String role) {
    switch (role.toLowerCase()) {
      case 'seafarer':
        return const SeafarerHomePage();
      case 'admin':
        return const AdminPage();
      case 'office':
        return const OfficePage();
      default:
        return null;
    }
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnack('Informe seu e-mail.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack('E-mail de redefinição enviado para $email');
    } on FirebaseAuthException catch (e) {
      final map = <String, String>{
        'invalid-email': 'E-mail inválido.',
        'user-not-found': 'Usuário não encontrado.',
      };
      _showSnack(map[e.code] ?? 'Erro ao enviar e-mail.');
    } catch (e) {
      _showSnack('Erro inesperado: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LADO ESQUERDO (imagem + blur + glass + logo)
              if (isWide)
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/DJI_0005.jpg'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.20),
                      ),
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                        child:
                        Container(color: Colors.black.withOpacity(0.01)),
                      ),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter:
                            ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                            child: Container(
                              margin:
                              const EdgeInsets.symmetric(horizontal: 32),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 28),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1.4,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.20),
                                    Colors.white.withOpacity(0.03),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'TPRB\nTraining & Performance Record Book',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.4,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Odfjell Management',
                                    style: TextStyle(
                                      color:
                                      Colors.white.withOpacity(0.75),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // LADO DIREITO (form de login)
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sign in',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(
                                    fontWeight: FontWeight.w800),
                              ),
                              SizedBox(
                                height: 30,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailCtrl,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Informe seu e-mail';
                              final rx = RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                              if (!rx.hasMatch(value)) {
                                return 'E-mail inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordCtrl,
                            focusNode: _passwordFocus,
                            obscureText: _obscure,
                            onFieldSubmitted: (_) => _signIn(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: const OutlineInputBorder(),
                              prefixIcon:
                              const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => setState(
                                        () => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? '').isEmpty) {
                                return 'Inform your password';
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _sendReset,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _signIn,
                            child: _busy
                                ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text('Sign in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Tela para forçar o usuário a alterar a senha
/// ─────────────────────────────────────────────
class ChangePasswordPage extends StatefulWidget {
  final User user;
  final String role;
  const ChangePasswordPage({
    super.key,
    required this.user,
    required this.role,
  });

  @override
  State<ChangePasswordPage> createState() =>
      _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// IMPORTANTE: agora usa os mesmos roles que o LoginPage
  Widget? _pageForRole(String role) {
    switch (role.toLowerCase()) {
      case 'seafarer':
        return const SeafarerHomePage();
      case 'admin':
        return const AdminPage();
      case 'office':
        return const OfficePage();
      default:
        return null;
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (widget.user.email == null) {
      _showSnack(
          'No email, it is not possible to change the password.');
      return;
    }

    setState(() => _busy = true);
    try {
      final email = widget.user.email!;
      final currentPassword = _currentCtrl.text.trim();
      final newPassword = _newCtrl.text.trim();

      // reautenticar
      final cred = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await widget.user.reauthenticateWithCredential(cred);

      // atualizar senha
      await widget.user.updatePassword(newPassword);

      // deletar campo mustChangePassword e atualizar updatedAt
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'mustChangePassword': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final page = _pageForRole(widget.role);
      if (!mounted) return;
      if (page != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => page),
              (_) => false,
        );
      } else {
        _showSnack('It was not possible to display dashboard.');
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error when changing password.';
      if (e.code == 'wrong-password') {
        msg = 'Incorrect current password.';
      }
      if (e.code == 'weak-password') {
        msg = 'The new password is weak.';
      }
      if (e.code == 'requires-recent-login') {
        msg = 'Log in again to change the password.';
      }
      _showSnack(msg);
    } catch (e) {
      _showSnack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _currentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) {
                        if ((v ?? '').isEmpty) {
                          return 'Inform the current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newCtrl,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) {
                        if ((v ?? '').isEmpty) {
                          return 'Inform the new password';
                        }
                        if ((v ?? '').length < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) {
                        if ((v ?? '').isEmpty) {
                          return 'Confirm new password';
                        }
                        if (v != _newCtrl.text) {
                          return 'The password do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text('Save new password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
