import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'trainee/trainee.dart';
import 'supervisor/supervisor.dart';

enum SeafarerMode { trainee, supervisor }

class SeafarerHomePage extends StatefulWidget {
  const SeafarerHomePage({super.key});

  @override
  State<SeafarerHomePage> createState() => _SeafarerHomePageState();
}

class _SeafarerHomePageState extends State<SeafarerHomePage> {
  SeafarerMode _currentMode = SeafarerMode.trainee;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final userType = data['type'] as String? ?? 'seafarer';
        if (userType != 'seafarer') {
          return Scaffold(
            body: Center(child: Text('Usuário do tipo "$userType" não usa esta tela.')),
          );
        }

        final basePage = _currentMode == SeafarerMode.trainee
            ? const TraineeDashboardPage()
            : const OfficerReviewDashboardPage();

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: basePage),

              // --- botão flutuante no canto superior direito ---
              Positioned(
                bottom: 20,
                right: 32,
                child: _GlassSwitcher(
                  currentMode: _currentMode,
                  onModeChanged: (mode) => setState(() => _currentMode = mode),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlassSwitcher extends StatelessWidget {
  final SeafarerMode currentMode;
  final ValueChanged<SeafarerMode> onModeChanged;

  const _GlassSwitcher({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isTrainee = currentMode == SeafarerMode.trainee;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _GlassChip(
                label: 'Trainee',
                selected: isTrainee,
                onTap: () => onModeChanged(SeafarerMode.trainee),
              ),
              const SizedBox(width: 8),
              _GlassChip(
                label: 'Supervisor',
                selected: !isTrainee,
                onTap: () => onModeChanged(SeafarerMode.supervisor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GlassChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF145CF4).withOpacity(0.9) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Icon(Icons.check, size: 16, color: Colors.white),
            if (selected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withOpacity(0.85),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
