import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class WebDavCredentialStore {
  Future<String?> readPassword();

  Future<void> writePassword(String password);

  Future<void> clearPassword();
}

class SecureWebDavCredentialStore implements WebDavCredentialStore {
  SecureWebDavCredentialStore({
    FlutterSecureStorage? secureStorage,
    this.passwordKey = 'webdav_password',
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;
  final String passwordKey;

  @override
  Future<String?> readPassword() => _secureStorage.read(key: passwordKey);

  @override
  Future<void> writePassword(String password) {
    return _secureStorage.write(key: passwordKey, value: password);
  }

  @override
  Future<void> clearPassword() => _secureStorage.delete(key: passwordKey);
}
