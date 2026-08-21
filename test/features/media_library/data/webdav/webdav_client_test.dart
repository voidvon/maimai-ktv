import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/features/media_library/data/webdav/webdav_client.dart';
import 'package:maimai_ktv/features/media_library/data/webdav/webdav_credential_store.dart';
import 'package:maimai_ktv/features/media_library/data/webdav/webdav_models.dart';
import 'package:maimai_ktv/features/media_library/data/webdav/webdav_source_config_store.dart';

void main() {
  test('recursively scans WebDAV folders and parses file metadata', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    final String expectedAuthorization =
        'Basic ${base64Encode(utf8.encode('alice:secret'))}';
    server.listen((HttpRequest request) async {
      expect(request.method, 'PROPFIND');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        expectedAuthorization,
      );
      await request.drain<void>();
      request.response.statusCode = HttpStatus.multiStatus;
      request.response.headers.contentType = ContentType('application', 'xml');
      if (request.uri.path == '/dav/KTV/') {
        request.response.write(_rootListing);
      } else if (request.uri.path == '/dav/KTV/sub/') {
        request.response.write(_subdirectoryListing);
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final WebDavClient client = _buildClient(server.port);
    final List<WebDavRemoteFile> files = await client.scanRoot('/KTV');

    expect(files, hasLength(3));
    final WebDavRemoteFile song = files.firstWhere(
      (WebDavRemoteFile file) => file.serverFilename == '周杰伦-晴天.mp4',
    );
    expect(song.path, '/KTV/周杰伦-晴天.mp4');
    expect(song.size, 1234);
    expect(song.etag, '"song-etag"');
    expect(song.modifiedAtMillis, greaterThan(0));
  });

  test('resumes downloads when the server accepts byte ranges', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    server.listen((HttpRequest request) async {
      expect(request.method, 'GET');
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=3-');
      request.response.statusCode = HttpStatus.partialContent;
      request.response.contentLength = 3;
      request.response.write('def');
      await request.response.close();
    });
    final Directory tempDirectory = await Directory.systemTemp.createTemp(
      'webdav-client-test-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    final File partial = File('${tempDirectory.path}/song.part');
    await partial.writeAsString('abc');

    await _buildClient(
      server.port,
    ).downloadFile(remotePath: '/KTV/song.mp4', targetFile: partial);

    expect(await partial.readAsString(), 'abcdef');
  });

  test('lists only WebDAV directories for the folder picker', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    server.listen((HttpRequest request) async {
      expect(request.method, 'PROPFIND');
      await request.drain<void>();
      request.response.statusCode = HttpStatus.multiStatus;
      request.response.headers.contentType = ContentType('application', 'xml');
      request.response.write(_rootListing);
      await request.response.close();
    });

    final List<WebDavRemoteFile> directories = await _buildClient(
      server.port,
    ).listDirectories(path: '/KTV');

    expect(directories.map((WebDavRemoteFile file) => file.path), <String>[
      '/KTV/sub',
    ]);
  });
}

WebDavClient _buildClient(int port) {
  return WebDavClient(
    configStore: _MemoryConfigStore(
      WebDavSourceConfig(
        sourceRootId: 'webdav:test',
        rootPath: '/KTV',
        displayName: 'WebDAV',
        serverUrl: 'http://127.0.0.1:$port/dav',
        username: 'alice',
      ),
    ),
    credentialStore: _MemoryCredentialStore('secret'),
  );
}

class _MemoryConfigStore extends WebDavSourceConfigStore {
  _MemoryConfigStore(this.config);

  WebDavSourceConfig? config;

  @override
  Future<WebDavSourceConfig?> loadConfig() async => config;

  @override
  Future<void> saveConfig(WebDavSourceConfig config) async {
    this.config = config;
  }

  @override
  Future<void> clearConfig() async {
    config = null;
  }
}

class _MemoryCredentialStore implements WebDavCredentialStore {
  _MemoryCredentialStore(this.password);

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

const String _rootListing = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/KTV/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection /></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/KTV/%E5%91%A8%E6%9D%B0%E4%BC%A6-%E6%99%B4%E5%A4%A9.mp4</d:href>
    <d:propstat><d:prop>
      <d:resourcetype />
      <d:getcontentlength>1234</d:getcontentlength>
      <d:getlastmodified>Wed, 21 Oct 2015 07:28:00 GMT</d:getlastmodified>
      <d:getetag>"song-etag"</d:getetag>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/KTV/sub/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection /></d:resourcetype></d:prop></d:propstat>
  </d:response>
</d:multistatus>''';

const String _subdirectoryListing = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/KTV/sub/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection /></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/KTV/sub/second.mkv</d:href>
    <d:propstat><d:prop>
      <d:resourcetype />
      <d:getcontentlength>42</d:getcontentlength>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>''';
