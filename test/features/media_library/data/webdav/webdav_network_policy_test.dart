import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/features/media_library/data/webdav/webdav_network_policy.dart';

void main() {
  test('allows HTTP only for local network hosts', () {
    for (final String url in <String>[
      'http://localhost:1111',
      'http://127.0.0.1:1111',
      'http://10.0.0.2:1111',
      'http://172.16.0.2:1111',
      'http://172.31.255.254:1111',
      'http://192.168.10.133:1111',
      'http://169.254.1.2:1111',
      'http://media-server.local:1111',
      'http://[::1]:1111',
      'http://[fd00::2]:1111',
      'http://[fe80::2]:1111',
    ]) {
      expect(WebDavNetworkPolicy.allows(Uri.parse(url)), isTrue, reason: url);
    }
  });

  test('rejects public and non-private HTTP hosts', () {
    for (final String url in <String>[
      'http://example.com:1111',
      'http://8.8.8.8:1111',
      'http://172.15.0.2:1111',
      'http://172.32.0.2:1111',
      'http://0.0.0.0:1111',
    ]) {
      expect(WebDavNetworkPolicy.allows(Uri.parse(url)), isFalse, reason: url);
    }
  });

  test('allows public hosts over HTTPS', () {
    expect(
      WebDavNetworkPolicy.allows(Uri.parse('https://dav.example.com')),
      isTrue,
    );
  });
}
