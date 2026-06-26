import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_motion.dart';
import 'animations.dart';

class BrandedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const BrandedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Tactile press scale on the whole button, plus a cross-fade between the
    // label and the inline spinner so the loading state doesn't pop.
    return Pressable(
      onTap: (isLoading || onPressed == null) ? null : onPressed,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: AnimatedSwitcher(
            duration: AppMotion.fast,
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.navyBlue,
                    ),
                  )
                : Text(label, key: const ValueKey('label')),
          ),
        ),
      ),
    );
  }
}
