import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';

/// Discovers other Cyborg instances on the local network.
///
/// Strategy:
/// 1. Broadcast a UDP probe to the local subnet on port 17173 (Cyborg discovery port)
/// 2. Any Windows Cyborg instance responds with its HTTP API base URL
/// 3. Verify the endpoint is alive with a /health check
///
/// This enables Android → Windows cross-device inference offload as described in the PRD.
class DeviceDiscoveryService {
  static const int _discoveryPort = 17173;
  static const String _probeMessage = 'CYBORG_DISCOVERY_PROBE_v1';
  static const String _responsePrefix = 'CYBORG_DISCOVERY_RESPONSE_v1:';
  static const Duration _scanTimeout = Duration(seconds: 8);

  RawDatagramSocket? _socket;
  final _discoveredDevices = StreamController<CyborgDevice>.broadcast();
  Stream<CyborgDevice> get devices => _discoveredDevices.stream;

  // ── Scan for Windows Cyborg instances ─────────────────────────────────────
  /// Returns the base URL of the first healthy Windows Cyborg instance found,
  /// or null if none respond within [_scanTimeout].
  Future<String?> findWindowsCyborgInstance() async {
    debugPrint('[DeviceDiscovery] Scanning local network for Windows Cyborg…');

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // OS assigns ephemeral port
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;

      final completer = Completer<String?>();
      Timer? timeout;

      _socket!.listen((event) async {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket!.receive();
        if (datagram == null) return;

        final message = utf8.decode(datagram.data, allowMalformed: true);
        if (!message.startsWith(_responsePrefix)) return;

        final url = message.substring(_responsePrefix.length).trim();
        debugPrint('[DeviceDiscovery] Got response from ${datagram.address.address}: $url');

        // Verify the endpoint is alive
        if (await _isAlive(url)) {
          // Setup API constants globally for the Android client
          ApiConstants.baseUrl = '$url/api/v1';
          ApiConstants.wsBaseUrl = url.replaceFirst('http', 'ws') + '/api/v1';

          _discoveredDevices.add(CyborgDevice(
            address: datagram.address.address,
            baseUrl: url,
            platform: 'windows',
          ));

          if (!completer.isCompleted) {
            completer.complete(url);
          }
        }
      });

      // Send UDP probe to broadcast address
      final probe = utf8.encode(_probeMessage);
      _socket!.send(probe, InternetAddress('255.255.255.255'), _discoveryPort);
      debugPrint('[DeviceDiscovery] Probe sent → 255.255.255.255:$_discoveryPort');

      timeout = Timer(_scanTimeout, () {
        if (!completer.isCompleted) {
          debugPrint('[DeviceDiscovery] Scan timed out — no Windows Cyborg found');
          completer.complete(null);
        }
      });

      final result = await completer.future;
      timeout.cancel();
      _socket?.close();
      return result;
    } catch (e) {
      debugPrint('[DeviceDiscovery] Scan error: $e');
      return null;
    }
  }

  Future<bool> _isAlive(String baseUrl) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(Uri.parse('$baseUrl/health'));
      final resp = await req.close();
      await resp.drain<void>();
      client.close();
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _socket?.close();
    _discoveredDevices.close();
  }
}

// ── Windows Cyborg discovery responder (runs on Windows side) ─────────────────
/// On Windows, the Python backend also starts a UDP listener that responds
/// to discovery probes, announcing its HTTP API URL.
/// This Dart class mirrors that logic so Flutter on Windows can also respond.
class CyborgDiscoveryResponder {
  static const int _discoveryPort = 17173;
  static const String _probeMessage = 'CYBORG_DISCOVERY_PROBE_v1';
  static const String _responsePrefix = 'CYBORG_DISCOVERY_RESPONSE_v1:';

  RawDatagramSocket? _socket;

  Future<void> start({required String apiBaseUrl}) async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
      );

      debugPrint('[DiscoveryResponder] Listening on port $_discoveryPort');

      _socket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket!.receive();
        if (datagram == null) return;

        final message = utf8.decode(datagram.data, allowMalformed: true).trim();
        if (message != _probeMessage) return;

        debugPrint(
            '[DiscoveryResponder] Probe from ${datagram.address.address} — responding with $apiBaseUrl');

        final response = utf8.encode('$_responsePrefix$apiBaseUrl');
        _socket!.send(response, datagram.address, datagram.port);
      });
    } catch (e) {
      debugPrint('[DiscoveryResponder] Failed to start: $e');
    }
  }

  void stop() => _socket?.close();
}

// ── Data model ────────────────────────────────────────────────────────────────
class CyborgDevice {
  final String address;
  final String baseUrl;
  final String platform;

  const CyborgDevice({
    required this.address,
    required this.baseUrl,
    required this.platform,
  });

  @override
  String toString() => 'CyborgDevice($platform @ $address → $baseUrl)';
}
