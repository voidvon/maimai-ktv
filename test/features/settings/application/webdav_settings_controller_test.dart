import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/features/media_library/data/webdav/webdav_client.dart';
import 'package:maimai_ktv/features/media_library/data/webdav/webdav_credential_store.dart';
import 'package:maimai_ktv/features/media_library/data/webdav/webdav_models.dart';
import 'package:maimai_ktv/features/media_library/data/webdav/webdav_source_config_store.dart';
import 'package:maimai_ktv/features/settings/application/webdav_settings_controller.dart';

void main() {
  test('saves connection metadata separately from the password', () async {
    final _MemoryConfigStore configStore = _MemoryConfigStore();
    final _MemoryCredentialStore credentialStore = _MemoryCredentialStore();
    final WebDavSettingsController controller = _buildController(
      configStore,
      credentialStore,
    );
    addTearDown(controller.dispose);

    final bool saved = await controller.saveSettings(
      serverUrl: 'https://dav.example.com/',
      username: 'alice',
      password: 'secret',
      rootPath: 'KTV/',
    );

    expect(saved, isTrue);
    expect(configStore.config?.serverUrl, 'https://dav.example.com');
    expect(configStore.config?.rootPath, '/KTV');
    expect(configStore.config?.sourceRootId, startsWith('webdav:'));
    expect(credentialStore.password, 'secret');
    expect(controller.isConfigured, isTrue);
  });

  test('rejects an insecure public WebDAV server URL', () async {
    final _MemoryConfigStore configStore = _MemoryConfigStore();
    final _MemoryCredentialStore credentialStore = _MemoryCredentialStore();
    final WebDavSettingsController controller = _buildController(
      configStore,
      credentialStore,
    );
    addTearDown(controller.dispose);

    final bool saved = await controller.saveSettings(
      serverUrl: 'http://dav.example.com',
      username: 'alice',
      password: 'secret',
      rootPath: '/KTV',
    );

    expect(saved, isFalse);
    expect(configStore.config, isNull);
    expect(controller.errorMessage, contains('HTTPS'));
  });

  test('accepts HTTP for a private network WebDAV server', () async {
    final _MemoryConfigStore configStore = _MemoryConfigStore();
    final _MemoryCredentialStore credentialStore = _MemoryCredentialStore();
    final WebDavSettingsController controller = _buildController(
      configStore,
      credentialStore,
    );
    addTearDown(controller.dispose);

    final bool saved = await controller.saveSettings(
      serverUrl: 'http://192.168.10.133:1111',
      username: 'yytest',
      password: '123123',
      rootPath: '/',
    );

    expect(saved, isTrue);
    expect(configStore.config?.serverUrl, 'http://192.168.10.133:1111');
  });
}

WebDavSettingsController _buildController(
  _MemoryConfigStore configStore,
  _MemoryCredentialStore credentialStore,
) {
  return WebDavSettingsController(
    configStore: configStore,
    credentialStore: credentialStore,
    client: WebDavClient(
      configStore: configStore,
      credentialStore: credentialStore,
    ),
  );
}

class _MemoryConfigStore extends WebDavSourceConfigStore {
  WebDavSourceConfig? config;

  @override
  Future<void> clearConfig() async {
    config = null;
  }

  @override
  Future<WebDavSourceConfig?> loadConfig() async => config;

  @override
  Future<void> saveConfig(WebDavSourceConfig config) async {
    this.config = config;
  }
}

class _MemoryCredentialStore implements WebDavCredentialStore {
  String? password;

  @override
  Future<void> clearPassword() async {
    password = null;
  }

  @override
  Future<String?> readPassword() async => password;

  @override
  Future<void> writePassword(String password) async {
    this.password = password;
  }
}
