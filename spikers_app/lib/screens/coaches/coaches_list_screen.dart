import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../home/coaches_tab.dart';

class CoachesListScreen extends StatelessWidget {
  const CoachesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.coachesTab)),
      body: const CoachesTab(),
    );
  }
}
