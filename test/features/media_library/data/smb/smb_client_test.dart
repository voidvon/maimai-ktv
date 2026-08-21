import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/features/media_library/data/smb/smb_client.dart';
import 'package:maimai_ktv/features/media_library/data/smb/smb_connection.dart';
import 'package:maimai_ktv/features/media_library/data/smb/smb_credential_store.dart';
import 'package:maimai_ktv/features/media_library/data/smb/smb_models.dart';
import 'package:maimai_ktv/features/media_library/data/smb/smb_source_config_store.dart';

void main() {
  test('recursively scans SMB folders using one connection', () async {
    final _FakeSmbConnection connection = _FakeSmbConnection(
      listings: <String, List<SmbRemoteFile>>{
        '/KTV': <SmbRemoteFile>[
          _file('/KTV/周杰伦-晴天.mp4', size: 1234),
          _directory('/KTV/sub'),
        ],
        '/KTV/sub': <SmbRemoteFile>[_file('/KTV/sub/second.mkv', size: 42)],
      },
    );
    final SmbClient client = _buildClient(connection);

    final List<SmbRemoteFile> files = await client.scanRoot('/KTV');

    expect(files, hasLength(3));
    expect(
      files.map((SmbRemoteFile file) => file.path),
      containsAll(<String>['/KTV/周杰伦-晴天.mp4', '/KTV/sub/second.mkv']),
    );
    expect(connection.closed, isTrue);
  });

  test('resumes SMB downloads from the partial file length', () async {
    final _FakeSmbConnection connection = _FakeSmbConnection(
      files: <String, List<int>>{'/KTV/song.mp4': 'abcdef'.codeUnits},
    );
    final Directory tempDirectory = await Directory.systemTemp.createTemp(
      'smb-client-test-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    final File partial = File('${tempDirectory.path}/song.part');
    await partial.writeAsString('abc');

    await _buildClient(
      connection,
    ).downloadFile(remotePath: '/KTV/song.mp4', targetFile: partial);

    expect(await partial.readAsString(), 'abcdef');
    expect(connection.lastReadStart, 3);
    expect(connection.closed, isTrue);
  });

  test('lists only remote directories for the folder picker', () async {
    final _FakeSmbConnection connection = _FakeSmbConnection(
      listings: <String, List<SmbRemoteFile>>{
        '/KTV': <SmbRemoteFile>[
          _directory('/KTV/Mandarin'),
          _file('/KTV/song.mp4', size: 10),
        ],
      },
    );

    final List<SmbRemoteFile> directories = await _buildClient(
      connection,
    ).listDirectories(path: '/KTV');

    expect(directories.map((SmbRemoteFile file) => file.path), <String>[
      '/KTV/Mandarin',
    ]);
    expect(connection.lastListedPath, '/KTV');
    expect(connection.closed, isTrue);
  });
}

SmbClient _buildClient(_FakeSmbConnection connection) {
  return SmbClient(
    configStore: _MemoryConfigStore(
      const SmbSourceConfig(
        sourceRootId: 'smb:test',
        rootPath: '/KTV',
        displayName: 'SMB',
        host: '192.168.1.10',
        share: 'media',
        username: 'alice',
      ),
    ),
    credentialStore: _MemoryCredentialStore('secret'),
    connectionFactory:
        ({required SmbSourceConfig config, required String password}) async {
          expect(config.share, 'media');
          expect(password, 'secret');
          return connection;
        },
  );
}

SmbRemoteFile _file(String path, {required int size}) {
  return SmbRemoteFile(
    fileId: path,
    path: path,
    serverFilename: path.split('/').last,
    isDirectory: false,
    size: size,
    modifiedAtMillis: 1000,
  );
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

class _FakeSmbConnection implements SmbConnection {
  _FakeSmbConnection({
    this.listings = const <String, List<SmbRemoteFile>>{},
    this.files = const <String, List<int>>{},
  });

  final Map<String, List<SmbRemoteFile>> listings;
  final Map<String, List<int>> files;
  bool closed = false;
  int? lastReadStart;
  String? lastListedPath;

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<List<SmbRemoteFile>> listDirectory(String path) async {
    lastListedPath = path;
    return listings[path] ?? <SmbRemoteFile>[];
  }

  @override
  Future<Stream<Uint8List>> openRead(String path, {int start = 0}) async {
    lastReadStart = start;
    return Stream<Uint8List>.value(
      Uint8List.fromList((files[path] ?? <int>[]).skip(start).toList()),
    );
  }

  @override
  Future<SmbRemoteFile> stat(String path) async {
    final List<int> bytes = files[path] ?? <int>[];
    return _file(path, size: bytes.length);
  }
}

class _MemoryConfigStore extends SmbSourceConfigStore {
  _MemoryConfigStore(this.config);

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
