import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tprb/firebase_options.dart';
import 'login.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  setUrlStrategy(const HashUrlStrategy());
  runApp(const TPRBLandingApp());
}

class TPRBLandingApp extends StatelessWidget {
  const TPRBLandingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Training Performance Record Book',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF173B6D),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: Color(0xFF0B1221),
          ),
          headlineSmall: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF374151),
          ),
        ),
      ),
      home: const LandingPage(),
      routes: {
        '/login': (_) => const LoginPage(),
      },
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 900;
        final isVeryNarrow = c.maxWidth < 600;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isVeryNarrow ? 16 : 32,
                vertical: 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  const _HeroIcon(),
                  const SizedBox(height: 24),
                  Text(
                    'Training Performance Record Book',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: isVeryNarrow ? 28 : (isNarrow ? 40 : 56),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Text(
                      'Digitalize shipboard training records with real-time progress tracking, digital signatures,\n'
                          'and fleet-wide content management',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isVeryNarrow ? 14 : 16,
                        height: 1.5,
                        color: const Color(0xFF4A5568),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _HeroCTA(),
                  const SizedBox(height: 10),
                  const Text(
                    'Secure access for maritime training professionals',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // GRID
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: const [
                      _FeatureCard(
                        title: 'For Trainees',
                        icon: Icons.person_rounded,
                        bullets: [
                          'Log task completions',
                          'Track progress by chapter',
                          'Submit evidence digitally',
                          'View approval status',
                        ],
                      ),
                      _FeatureCard(
                        title: 'For Officers',
                        icon: Icons.verified_user_rounded,
                        bullets: [
                          'Review submissions',
                          'Digital signing with audit',
                          'Return with feedback',
                          'Vessel-wide oversight',
                        ],
                      ),
                      _FeatureCard(
                        title: 'For Office',
                        icon: Icons.apartment_rounded,
                        bullets: [
                          'Fleet-wide analytics',
                          'Progress monitoring',
                          'Compliance reporting',
                          'Remote endorsement',
                        ],
                      ),
                      _FeatureCard(
                        title: 'For Admins',
                        icon: Icons.menu_book_rounded,
                        bullets: [
                          'Content versioning',
                          'Fleet-wide updates',
                          'User management',
                          'Audit logging',
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B447B), Color(0xFF153961)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173B6D).withOpacity(0.25),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.directions_boat_filled_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }
}

class _HeroCTA extends StatefulWidget {
  const _HeroCTA();

  @override
  State<_HeroCTA> createState() => _HeroCTAState();
}

class _HeroCTAState extends State<_HeroCTA> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: _hover
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        child: FilledButton(
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            ),
            backgroundColor:
            const WidgetStatePropertyAll(Color(0xFF173B6D)),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            elevation: WidgetStatePropertyAll(_hover ? 2 : 0),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          child: const Text(
            'Access TPRB System',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String> bullets;

  const _FeatureCard({
    required this.title,
    required this.icon,
    required this.bullets,
    super.key,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 280),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7ECF3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_hover ? 0.10 : 0.08),
                blurRadius: _hover ? 22 : 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon,
                        size: 20, color: const Color(0xFF173B6D)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...widget.bullets.map(
                    (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: Icon(Icons.circle,
                            size: 6, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Color(0xFF374151),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
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
