import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';

import '../../l10n/app_localizations.dart';

/// App-wide "update available" gate.
///
/// Wrap a screen (currently the home screen) with this so `upgrader` checks the
/// App Store / Play Store on launch and, when a newer version exists, shows a
/// localized "Update Available" dialog with two actions: "Update Now" and
/// "Later". The dialog copy comes from the app's own ARB localizations, so it
/// follows the in-app language (English / Arabic).
///
/// ── Making the update mandatory later ─────────────────────────────────────
/// Two independent levers, both already wired up below. Leave them at their
/// defaults for today's soft, skippable prompt.
///
/// 1. [_forceUpdate] — flip to `true` to make EVERY available update mandatory:
///    the "Later" button disappears and the dialog can no longer be dismissed
///    (no tap-outside, no Android back button). In `upgrader` v13 the dismiss
///    control moved from the old `canDismissDialog` to [UpgradeAlert]'s
///    `barrierDismissible` + `shouldPopScope`, both of which this widget drives
///    from the flag.
///
/// 2. [_minAppVersion] — set to a plain semver like `'1.1.0'` to force only
///    users *below* that version. `upgrader` auto-blocks the dialog for them
///    (hides "Later", disables dismiss) while still letting newer users skip.
///    Use the [pubspec] version WITHOUT the build number (`1.1.0`, not
///    `1.1.0+27`).
class AppUpgradeAlert extends StatefulWidget {
  const AppUpgradeAlert({super.key, required this.child});

  final Widget child;

  /// Make every available update mandatory (non-dismissible, no "Later").
  static const bool _forceUpdate = false;

  /// Force only users below this version. `null` = no version floor.
  static const String? _minAppVersion = null;

  @override
  State<AppUpgradeAlert> createState() => _AppUpgradeAlertState();
}

class _AppUpgradeAlertState extends State<AppUpgradeAlert> {
  Upgrader? _upgrader;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Build the Upgrader once — here rather than in initState because
    // AppLocalizations is only available once inherited widgets are ready, and
    // `??=` so the store check isn't re-run on every rebuild. The dialog copy
    // is captured for the language active at first mount; a mid-session
    // language switch is picked up on the next launch.
    _upgrader ??= Upgrader(
      messages: _AppUpgraderMessages(
        AppLocalizations.of(context)!,
        code: Localizations.localeOf(context).languageCode,
      ),
      minAppVersion: AppUpgradeAlert._minAppVersion,
      debugLogging: kDebugMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    const forced = AppUpgradeAlert._forceUpdate;
    return UpgradeAlert(
      upgrader: _upgrader!,
      // Exactly the two requested buttons: "Update Now" + "Later". No "Ignore".
      showIgnore: false,
      // Keep the dialog to the requested title + body only — no store release
      // notes and no extra "Would you like to update now?" prompt line.
      showReleaseNotes: false,
      showPrompt: false,
      // ── Forced-update levers (see class doc) ──
      showLater: !forced,
      barrierDismissible: !forced,
      shouldPopScope: () => !forced,
      child: widget.child,
    );
  }
}

/// Feeds the app's own localized strings into `upgrader`'s dialog. Overriding
/// these getters is `upgrader`'s documented customization hook — its
/// `message(UpgraderMessage)` lookup delegates to them.
class _AppUpgraderMessages extends UpgraderMessages {
  _AppUpgraderMessages(this._l, {required String super.code});

  final AppLocalizations _l;

  @override
  String get title => _l.updateAvailableTitle;

  @override
  String get body => _l.updateAvailableBody;

  @override
  String get buttonTitleUpdate => _l.updateNow;

  @override
  String get buttonTitleLater => _l.updateLater;

  // Not shown while showIgnore is false, but overridden so no English default
  // leaks through if the "Ignore" button is ever re-enabled.
  @override
  String get buttonTitleIgnore => _l.updateLater;
}
