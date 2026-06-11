import 'package:flutter/material.dart';
import 'package:get/get.dart' show Get, GetNavigation, Inst;

import '../../../../controller/auth_controller.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../screens/widgets/branded_button.dart';

class EmailChangeNoticeScreen extends StatelessWidget {
  const EmailChangeNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final newEmail = Get.arguments is String ? Get.arguments as String : '';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(24, 48, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.mark_email_read_outlined,
                          color: AppColors.gold, size: 64),
                      const SizedBox(height: 20),
                      Text(
                        l.emailChangeNoticeTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.emailChangeNoticeBody(newEmail),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 14,
                            height: 1.5),
                      ),
                      const Spacer(),
                      BrandedButton(
                        label: l.emailChangeNoticeButton,
                        // Full sign-out (GetX teardown + navigation) lives on
                        // the shim until the last GetX consumers migrate.
                        onPressed: Get.find<AuthController>().signOut,
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
