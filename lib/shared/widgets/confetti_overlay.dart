import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Wraps [child] with a top-center confetti blast that fires when
/// [controller] is played. Use for goal milestones / streaks.
class ConfettiOverlay extends StatelessWidget {
  final ConfettiController controller;
  final Widget child;

  const ConfettiOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: controller,
            blastDirection: pi / 2,
            emissionFrequency: 0.05,
            numberOfParticles: 22,
            maxBlastForce: 22,
            minBlastForce: 8,
            gravity: 0.25,
            shouldLoop: false,
            colors: const [
              AppColors.accent,
              AppColors.coral,
              AppColors.primaryLight,
              AppColors.success,
            ],
          ),
        ),
      ],
    );
  }
}
