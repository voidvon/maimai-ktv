import 'dart:io';

class WebDavNetworkPolicy {
  const WebDavNetworkPolicy._();

  static bool allows(Uri uri) {
    if (uri.host.isEmpty) {
      return false;
    }
    if (uri.scheme == 'https') {
      return true;
    }
    return uri.scheme == 'http' && isLocalHost(uri.host);
  }

  static bool isLocalHost(String host) {
    final String normalized = host.trim().toLowerCase();
    if (normalized == 'localhost' || normalized.endsWith('.local')) {
      return true;
    }
    final InternetAddress? address = InternetAddress.tryParse(normalized);
    if (address == null) {
      return false;
    }
    if (address.isLoopback) {
      return true;
    }
    final List<int> bytes = address.rawAddress;
    if (bytes.length == 4) {
      return _isPrivateIpv4(bytes);
    }
    if (bytes.length != 16) {
      return false;
    }
    if ((bytes[0] & 0xfe) == 0xfc ||
        (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80)) {
      return true;
    }
    final bool isIpv4Mapped =
        bytes.take(10).every((int byte) => byte == 0) &&
        bytes[10] == 0xff &&
        bytes[11] == 0xff;
    return isIpv4Mapped && _isPrivateIpv4(bytes.sublist(12));
  }

  static bool _isPrivateIpv4(List<int> bytes) {
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 169 && bytes[1] == 254);
  }
}
