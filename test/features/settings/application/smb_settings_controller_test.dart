import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/features/media_library/data/smb/smb_client.dart';
import 'package:maimai_ktv/features/media_library/data/smb/smb_connection.dart';
import 'package:maimai_ktv/features/media_library/data/smb/smb_credential_store.dart';
import 'package:maimai_ktv/features/media_library/data/smb/smb_models.dart';
import 'package:maimai_ktv/features/media_library/data/smb/smb_source_config_store.dart';
import 'package:maimai_ktv/features/settings/application/smb_settings_controller.dart';

void main() {
  test('saves normalized SMB metadata separately from password', () async {
    final _MemoryConfigStore configStore = _MemoryConfigStore();
    final _MemoryCredentialStore credentialStore = _MemoryCredentialStore();
    final SmbSettingsController controller = _buildController(
      configStore,
      credentialStore,
    );
    addTearDown(controller.dispose);

    final bool saved = await controller.saveSettings(
      host: ' nas.local ',
      share: 'media',
      username: 'alice',
      password: 'secret',
      domain: 'WORKGROUP',
      rootPath: r'\KTV\Mandarin\',
    );

    expect(saved, isTrue);
    expect(configStore.config?.host, 'nas.local');
    expect(configStore.config?.rootPath, '/KTV/Mandarin');
    expect(configStore.config?.sourceRootId, startsWith('smb:'));
    expect(credentialStore.password, 'secret');
    expect(controller.isConfigured, isTrue);
  });

  test('allows guest configuration without username or password', () async {
    final _MemoryConfigStore configStore = _MemoryConfigStore();
    final _MemoryCredentialStore credentialStore = _MemoryCredentialStore();
    final SmbSettingsController controller = _buildController(
      configStore,
      credentialStore,
    );
    addTearDown(controller.dispose);

    final bool saved = await controller.saveSettings(
      host: '192.168.1.10',
      share: 'public',
      username: '',
      password: '',
      domain: '',
      rootPath: '/',
    );

    expect(saved, isTrue);
    expect(configStore.config?.username, isEmpty);
    expect(credentialStore.password, isNull);
    expect(controller.isConfigured, isTrue);
  });

  test('guest configuration clears credentials from an older server', () async {
    final _MemoryConfigStore configStore = _MemoryConfigStore();
    final _MemoryCredentialStore credentialStore = _MemoryCredentialStore()
      ..password = 'old-secret';
    final SmbSettingsController controller = _buildController(
      configStore,
      credentialStore,
    );
    addTearDown(controller.dispose);

    final bool saved = await controller.saveSettings(
      host: '192.168.1.10',
      share: 'public',
      username: '',
      password: '',
      domain: '',
      rootPath: '/',
    );

    expect(saved, isTrue);
    expect(credentialStore.password, isNull);
    expect(controller.hasPassword, isFalse);
  });

  test('rejects a share value containing a path', () async {
    final _MemoryConfigStore configStore = _MemoryConfigStore();
    final _MemoryCredentialStore credentialStore = _MemoryCredentialStore();
    final SmbSettingsController controller = _buildController(
      configStore,
      credentialStore,
    );
    addTearDown(controller.dispose);

    final bool saved = await controller.saveSettings(
      host: 'nas.local',
      share: 'media/KTV',
      username: '',
      password: '',
      domain: '',
      rootPath: '/',
    );

    expect(saved, isFalse);
    expect(configStore.config, isNull);
    expect(controller.errorMessage, contains('共享名称'));
  });

  test('browses directories with the current form values', () async {
    final _MemoryConfigStore configStore = _MemoryConfigStore();
    final _MemoryCredentialStore credentialStore = _MemoryCredentialStore();
    SmbSourceConfig? seenConfig;
    String? seenPassword;
    String? seenPath;
    _RecordingSmbConnection? connection;
    final SmbSettingsController controller = SmbSettingsController(
      configStore: configStore,
      credentialStore: credentialStore,
      client: SmbClient(
        configStore: configStore,
        credentialStore: credentialStore,
        connectionFactory:
            ({required SmbSourceConfig config, required String password}) {
              seenConfig = config;
              seenPassword = password;
              connection = _RecordingSmbConnection((String path) {
                seenPath = path;
                return <SmbRemoteFile>[_directory('/KTV/Mandarin')];
              });
              return Future<SmbConnection>.value(connection);
            },
      ),
    );
    addTearDown(controller.dispose);

    final List<SmbRemoteFile> directories = await controller.listDirectories(
      host: ' nas.local ',
      share: 'media',
      username: 'alice',
      password: 'typed-secret',
      domain: 'WORKGROUP',
      path: r'\KTV\Mandarin\',
    );

    expect(directories.single.path, '/KTV/Mandarin');
    expect(seenConfig?.host, 'nas.local');
    expect(seenConfig?.share, 'media');
    expect(seenConfig?.username, 'alice');
    expect(seenConfig?.domain, 'WORKGROUP');
    expect(seenConfig?.rootPath, '/KTV/Mandarin');
    expect(seenPassword, 'typed-secret');
    expect(seenPath, '/KTV/Mandarin');
    expect(connection?.closed, isTrue);
    expect(controller.isBrowsing, isFalse);
  });

  test('anonymous share discovery does not reuse a stored password', () async {
    final _MemoryConfigStore configStore = _MemoryConfigStore();
    final _MemoryCredentialStore credentialStore = _MemoryCredentialStore()
      ..password = 'stored-secret';
    String? seenUsername;
    String? seenPassword;
    final SmbSettingsController controller = SmbSettingsController(
      configStore: configStore,
      credentialStore: credentialStore,
      client: SmbClient(
        configStore: configStore,
        credentialStore: credentialStore,
        shareLister:
            ({
              required String host,
              required String username,
              required String password,
              required String domain,
            }) async {
              seenUsername = username;
              seenPassword = password;
              return const <SmbShare>[SmbShare(name: 'Music')];
            },
      ),
    );
    addTearDown(controller.dispose);

    final List<SmbShare> shares = await controller.listShares(
      host: '192.168.1.10',
      username: '',
      password: '',
      domain: '',
      useStoredPassword: false,
    );

    expect(shares.single.name, 'Music');
    expect(seenUsername, isEmpty);
    expect(seenPassword, isEmpty);
  });
}

SmbRemoteFile _directory(String path) {
  return SmbRemoteFile(
    fileId: path,
    path: path,
    serverFilename: path.split('/').last,
    isDirectory: true,
    size: 0,
    modifiedAtMillis: 1000,
  );
}

SmbSettingsController _buildController(
  _MemoryConfigStore configStore,
  _MemoryCredentialStore credentialStore,
) {
  return SmbSettingsController(
    configStore: configStore,
    credentialStore: credentialStore,
    client: SmbClient(
      configStore: configStore,
      credentialStore: credentialStore,
      connectionFactory:
          ({required SmbSourceConfig config, required String password}) {
            throw UnimplementedError();
          },
    ),
  );
}

class _MemoryConfigStore extends SmbSourceConfigStore {
  SmbSourceConfig? config;

  @override
  Future<void> clearConfig() async {
    config = null;
  }

  @override
  Future<SmbSourceConfig?> loadConfig() async => config;

  @override
  Future<void> saveConfig(SmbSourceConfig config) async {
    this.config = config;
  }
}

class _MemoryCredentialStore implements SmbCredentialStore {
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

class _RecordingSmbConnection implements SmbConnection {
  _RecordingSmbConnection(this._onListDirectory);

  final List<SmbRemoteFile> Function(String path) _onListDirectory;
  bool closed = false;

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<List<SmbRemoteFile>> listDirectory(String path) async {
    return _onListDirectory(path);
  }

  @override
  Future<Stream<Uint8List>> openRead(String path, {int start = 0}) {
    throw UnimplementedError();
  }

  @override
  Future<SmbRemoteFile> stat(String path) {
    throw UnimplementedError();
  }
}
