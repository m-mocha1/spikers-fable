import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stored credentials for silent session restore.
class StoredCredentials {
  final String email;
  final String password;
  const StoredCredentials(this.email, this.password);
}

abstract class CredentialStore {
  Future<StoredCredentials?> read();
  Future<void> save(String email, String password);
  Future<void> clear();
}

/// Keeps credentials in the platform keystore (Keychain /
/// EncryptedSharedPreferences). Migrates values saved by older builds out of
/// plain SharedPreferences (where the password was only base64-encoded).
class SecureCredentialStore implements CredentialStore {
  static const _kEmail = '_se';
  static const _kPass = '_sp';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<StoredCredentials?> read() async {
    await _migrateLegacy();
    final email = await _storage.read(key: _kEmail);
    final password = await _storage.read(key: _kPass);
    if (email == null || password == null) return null;
    return StoredCredentials(email, password);
  }

  Future<void> _migrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_kEmail);
    final encoded = prefs.getString(_kPass);
    if (email != null && encoded != null) {
      await _storage.write(key: _kEmail, value: email);
      await _storage.write(
          key: _kPass, value: utf8.decode(base64.decode(encoded)));
    }
    await prefs.remove(_kEmail);
    await prefs.remove(_kPass);
  }

  @override
  Future<void> save(String email, String password) async {
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kPass, value: password);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kPass);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEmail);
    await prefs.remove(_kPass);
    await prefs.remove('debug_last_uid');
  }
}
