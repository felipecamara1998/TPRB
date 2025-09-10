import 'package:flutter/material.dart';
import 'package:tprb/dashboards/supervisor.dart';
import 'dashboards/trainee.dart';
import 'dashboards/admin/admin.dart';
import 'dashboards/office.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  void initState() {
    super.initState();
    // Se já estiver logado, pula direto para o dashboard correspondente
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _routeUser(user);
      });
    }
  }

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

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _routeUser(cred.user!);
    } on FirebaseAuthException catch (e) {
      final map = <String, String>{
        'invalid-email': 'E-mail inválido.',
        'user-disabled': 'Usuário desativado.',
        'user-not-found': 'Usuário não encontrado.',
        'wrong-password': 'Senha incorreta.',
        'too-many-requests': 'Muitas tentativas. Tente mais tarde.',
        'network-request-failed': 'Sem conexão com a internet.',
        // genérico
      };
      final msg = map[e.code] ?? 'Falha no login. (code: ${e.code})';
      _showSnack(msg);
    } catch (e) {
      _showSnack('Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _routeUser(User user) async {
    try {
      // Busca role no Firestore
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final role = (doc.data()?['role'] as String?)?.trim() ?? '';

      if (role.isEmpty) {
        _showSnack(
            'Seu perfil ainda não possui um papel (role) definido. Contate o administrador.');
        return;
      }

      // Navega e remove a tela de login do histórico
      Widget page;
      switch (role.toLowerCase()) {
        case 'admin':
          page = const AdminPage();
          break;
        case 'supervisor':
          page = const OfficerReviewDashboardPage();
          break;
        case 'office':
          page = const FleetOverviewPage();
          break;
        case 'trainee':
          page = const TraineeDashboardPage();
          break;
        default:
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

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnack('Informe seu e-mail para recuperar a senha.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack('E-mail de redefinição de senha enviado para $email');
    } on FirebaseAuthException catch (e) {
      final map = <String, String>{
        'invalid-email': 'E-mail inválido.',
        'user-not-found': 'Esse e-mail não está cadastrado.',
      };
      final msg = map[e.code] ?? 'Não foi possível enviar o e-mail. (code: ${e.code})';
      _showSnack(msg);
    } catch (e) {
      _showSnack('Erro inesperado: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isWide ? _buildWide(theme) : _buildNarrow(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildNarrow(ThemeData theme) {
    return SingleChildScrollView(
      child: _LoginCard(
        child: _form(theme),
      ),
    );
  }

  Widget _buildWide(ThemeData theme) {
    return Row(
      children: [
        // Lado esquerdo com branding
        Expanded(
          child: _BrandingPanel(
            title: 'TPRB',
            subtitle: 'Training Program • Odfjell',
          ),
        ),
        const SizedBox(width: 16),
        // Lado direito: card de login
        Expanded(
          child: SingleChildScrollView(
            child: _LoginCard(
              child: _form(theme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _form(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign in',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailCtrl,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'user@company.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Informe seu e-mail';
              final rx = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
              if (!rx.hasMatch(value)) return 'E-mail inválido';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Password
          TextFormField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            obscureText: _obscure,
            onFieldSubmitted: (_) => _signIn(),
            decoration: InputDecoration(
              labelText: 'Senha',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              final value = v ?? '';
              if (value.isEmpty) return 'Informe sua senha';
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Esqueci minha senha
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _sendReset,
              child: const Text('Esqueci minha senha'),
            ),
          ),
          const SizedBox(height: 8),

          // Botão entrar
          FilledButton.icon(
            onPressed: _busy ? null : _signIn,
            icon: _busy
                ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: Text(_busy ? 'Entrando...' : 'Entrar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- UI Auxiliar ----------

class _LoginCard extends StatelessWidget {
  final Widget child;
  const _LoginCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}

class _BrandingPanel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BrandingPanel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 520,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F6FEB), Color(0xFF3B82F6)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.directions_boat_filled, color: Colors.white),
                  SizedBox(width: 8),
                  Icon(Icons.school, color: Colors.white),
                ],
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  )),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
