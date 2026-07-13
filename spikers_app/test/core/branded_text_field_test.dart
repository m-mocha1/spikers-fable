import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/core/widgets/branded_text_field.dart';

// The Phase 2 form-field system: one component, persistent label above the
// field (never a disappearing placeholder), hints as example values only.
void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      );

  testWidgets('label stays visible while typing; hint shows when empty',
      (tester) async {
    await tester
        .pumpWidget(wrap(const BrandedTextField(label: 'Height', hint: 'cm')));

    // Empty field: both the persistent label and the example hint render.
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('cm'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '180');
    await tester.pump();

    // The label must not disappear once the user types (a11y requirement).
    expect(find.text('Height'), findsOneWidget);
  });

  testWidgets('multiline variant aligns input and hint to the top',
      (tester) async {
    await tester.pumpWidget(
        wrap(const BrandedTextField(label: 'Message', maxLines: 6)));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textAlignVertical, TextAlignVertical.top);
    expect(field.decoration!.alignLabelWithHint, isTrue);
    expect(field.decoration!.floatingLabelBehavior,
        FloatingLabelBehavior.always);
  });

  testWidgets('errorText renders below the field', (tester) async {
    await tester.pumpWidget(wrap(
        const BrandedTextField(label: 'Coach key', errorText: 'Invalid key')));

    expect(find.text('Invalid key'), findsOneWidget);
    expect(find.text('Coach key'), findsOneWidget);
  });
}
