import 'package:flutter/material.dart';

import '../constants/app_gradients.dart';

/// Paints the shared [AppGradients.scaffoldBg] behind its [child] so screens
/// gain subtle vertical depth instead of a single flat navy fill.
///
/// Usage: set the host `Scaffold(backgroundColor: Colors.transparent)` and wrap
/// its body in a [GradientBackground]. Placing it on the home shell's body
/// covers the Sessions / Players / Profile tabs at once.
class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Fills all available space (not just the child's height): scroll views
    // like SingleChildScrollView size to their content, and without the
    // expansion a short page would leave the transparent scaffold showing
    // through below the gradient.
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: AppGradients.scaffoldBg),
      child: child,
    );
  }
}
