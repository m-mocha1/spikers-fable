class Validators {
  static String? required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value, {required String emptyMsg, required String invalidMsg}) {
    if (value == null || value.trim().isEmpty) return emptyMsg;
    final valid = RegExp(r'^[\w\-.]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(value.trim());
    return valid ? null : invalidMsg;
  }

  static String? password(String? value, {required String emptyMsg, required String shortMsg}) {
    if (value == null || value.trim().isEmpty) return emptyMsg;
    if (value.length < 6) return shortMsg;
    return null;
  }

  static String? confirmPassword(String? value, String original, {required String mismatchMsg}) {
    if (value != original) return mismatchMsg;
    return null;
  }

  static String? intInRange(
    String? value, {
    required int min,
    required int max,
    required String emptyMsg,
    required String invalidMsg,
  }) {
    if (value == null || value.trim().isEmpty) return emptyMsg;
    final n = int.tryParse(value.trim());
    if (n == null || n < min || n > max) return invalidMsg;
    return null;
  }

  /// Like [intInRange] but treats an empty value as valid (the field is
  /// optional). A non-empty value must still be a number within range.
  static String? optionalIntInRange(
    String? value, {
    required int min,
    required int max,
    required String invalidMsg,
  }) {
    if (value == null || value.trim().isEmpty) return null;
    final n = int.tryParse(value.trim());
    if (n == null || n < min || n > max) return invalidMsg;
    return null;
  }
}
