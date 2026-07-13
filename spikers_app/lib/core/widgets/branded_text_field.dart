import 'package:flutter/material.dart';

/// The app's single form-field component (Premium Pass Phase 2).
///
/// Renders a persistent small [label] above the filled navy field, so the
/// field keeps its name while the user types. The label is an always-floating
/// `InputDecoration` label rather than a separate [Text], which keeps it
/// linked to the input for screen readers and RTL layouts. [hint] is an
/// example value only ("cm", "you@email.com") — never the field's name.
class BrandedTextField extends StatelessWidget {
  final String label;

  /// Example value shown inside the empty field — never the field's name.
  final String? hint;

  /// Persistent line under the field (e.g. "Optional"). Use this instead of
  /// appending qualifiers to [label], which truncates in half-width fields.
  final String? helperText;

  /// Inline error below the field, for errors produced outside a [Form]
  /// validator (e.g. a backend rejection).
  final String? errorText;

  final TextEditingController? controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int? maxLines;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final VoidCallback? onTap;

  /// Overrides the themed fill. Pass a darker navy inside dialogs and sheets
  /// whose surface already uses the default fill color, so the field stays
  /// visible against its background.
  final Color? fillColor;

  const BrandedTextField({
    super.key,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.onTap,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final multiline = (maxLines ?? 1) > 1;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      maxLines: maxLines,
      readOnly: readOnly,
      enabled: enabled,
      autofocus: autofocus,
      onTap: onTap,
      // Multiline input (and its hint) starts at the top-left instead of
      // vertically centered in the box.
      textAlignVertical: multiline ? TextAlignVertical.top : null,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        alignLabelWithHint: multiline,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        suffixIcon: suffixIcon,
        fillColor: fillColor,
      ),
    );
  }
}
