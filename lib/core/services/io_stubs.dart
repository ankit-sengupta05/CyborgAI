// Web compatibility stubs for dart:io classes
// This file is only used when compiling for web to satisfy the compiler's type checks.

import 'dart:async';

class RawDatagramSocket {
  static Future<dynamic> bind(dynamic host, int port, {bool reuseAddress = true, bool reusePort = false, int ttl = 1}) async => null;
}

class Directory {
  final String path;
  Directory(this.path);
  bool existsSync() => false;
  Future<bool> exists() async => false;
  List<dynamic> listSync({bool recursive = false, bool followLinks = true}) => [];
  static dynamic get current => Directory('.');
  Future<dynamic> create({bool recursive = false}) async => this;
}

class File {
  final String path;
  File(this.path);
  bool existsSync() => false;
  Future<bool> exists() async => false;
  int lengthSync() => 0;
  dynamic parent = null;
}

class Process {
  static Future<dynamic> run(String executable, List<String> arguments, {String? workingDirectory, Map<String, String>? environment, bool includeParentEnvironment = true, bool runInShell = false, dynamic stdoutEncoding, dynamic stderrEncoding}) async => null;
  static Future<dynamic> start(String executable, List<String> arguments, {String? workingDirectory, Map<String, String>? environment, bool includeParentEnvironment = true, bool runInShell = false, dynamic mode}) async => null;
  void kill() {}
  dynamic get stdout => null;
  dynamic get stderr => null;
  Future<int> get exitCode async => 0;
}

class NetworkInterface {
  static Future<List<dynamic>> list({bool includeLoopback = false, bool includeLinkLocal = false, dynamic type}) async => [];
}

class InternetAddress {
  static dynamic anyIPv4 = null;
  static dynamic anyIPv6 = null;
  static dynamic loopbackIPv4 = null;
  static dynamic loopbackIPv6 = null;
  final String address;
  InternetAddress(this.address);
}

class InternetAddressType {
  static const dynamic IPv4 = null;
  static const dynamic IPv6 = null;
  static const dynamic any = null;
}

class RawSocketEvent {
  static const dynamic read = null;
  static const dynamic write = null;
  static const dynamic readClosed = null;
  static const dynamic closed = null;
}

class HttpClient {
  HttpClient();
  Future<HttpClientRequest> postUrl(Uri url) async => HttpClientRequest();
  Future<HttpClientRequest> getUrl(Uri url) async => HttpClientRequest();
  void close({bool force = false}) {}
  dynamic connectionTimeout;
}

class HttpClientRequest {
  final HttpHeaders headers = HttpHeaders();
  void write(dynamic data) {}
  Future<HttpClientResponse> close() async => HttpClientResponse();
}

class HttpClientResponse {
  final int statusCode = 200;
  Future<void> drain<T>([T? value]) async {}
  Stream<dynamic> transform(dynamic transformer) async* {}
}

class HttpHeaders {
  void set(String name, Object value) {}
}

class Platform {
  static int numberOfProcessors = 1;
  static String operatingSystem = 'web';
  static bool isWindows = false;
  static bool isAndroid = false;
  static bool isIOS = false;
  static bool isLinux = false;
  static bool isMacOS = false;
  static String resolvedExecutable = '';
  static Map<String, String> environment = {};
  static String pathSeparator = '/';
}

class SystemEncoding {
  const SystemEncoding();
  dynamic get decoder => null;
}
