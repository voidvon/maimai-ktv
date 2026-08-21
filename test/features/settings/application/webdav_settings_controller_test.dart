import 'dart:convert';
import 'dart:io';

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

  test('browses directories with the current form credentials', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    String? seenAuthorization;
    String? seenPath;
    server.listen((HttpRequest request) async {
      seenAuthorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      seenPath = request.uri.path;
      await request.drain<void>();
      request.response.statusCode = HttpStatus.multiStatus;
      request.response.headers.contentType = ContentType('application', 'xml');
      request.response.write(_directoryListing);
      await request.response.close();
    });
    final _MemoryConfigStore configStore = _MemoryConfigStore();
    final _MemoryCredentialStore credentialStore = _MemoryCredentialStore();
    final WebDavSettingsController controller = _buildController(
      configStore,
      credentialStore,
    );
    addTearDown(controller.dispose);

    final List<WebDavRemoteFile> directories = await controller.listDirectories(
      serverUrl: 'http://127.0.0.1:${server.port}/dav',
      username: 'alice',
      password: 'typed-secret',
      path: '/KTV',
    );

    expect(directories.single.path, '/KTV/Mandarin');
    expect(seenPath, '/dav/KTV/');
    expect(
      seenAuthorization,
      'Basic ${base64Encode(utf8.encode('alice:typed-secret'))}',
    );
    expect(controller.isBrowsing, isFalse);
  });
}

const String _directoryListing = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/KTV/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection /></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/KTV/Mandarin/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection /></d:resourcetype></d:prop></d:propstat>
  </d:response>
</d:multistatus>''';

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
