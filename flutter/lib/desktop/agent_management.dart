import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// The admin credential is only available to local administrators. Agent
/// enrollment files contain a separate, expiring, one-device credential.
class AgentManagementClient {
  AgentManagementClient(this.config) {
    final pin = config['certificateSha256'] as String;
    _http = HttpClient(context: SecurityContext(withTrustedRoots: false));
    _http.connectionTimeout = const Duration(seconds: 15);
    _http.findProxy = (_) => 'DIRECT';
    _http.badCertificateCallback = (certificate, host, port) =>
        sha256.convert(certificate.der).toString().toUpperCase() ==
            pin.toUpperCase() &&
        DateTime.now().isAfter(certificate.startValidity) &&
        DateTime.now().isBefore(certificate.endValidity);
  }
  final Map<String, dynamic> config;
  late final HttpClient _http;

  static Future<AgentManagementClient> local() async {
    final root = Platform.environment['ProgramData'] ?? r'C:\ProgramData';
    final text = await File(
      '$root\\SubnetDesk Deployment\\Management\\config.json',
    ).readAsString();
    final config =
        jsonDecode(text.replaceFirst('\uFEFF', '')) as Map<String, dynamic>;
    final server = Uri.parse(config['server'] as String);
    if (server.scheme != 'https' ||
        server.path != '/subnetdesk/' ||
        !RegExp(
          r'^[A-Fa-f0-9]{64}$',
        ).hasMatch(config['certificateSha256'] as String)) {
      throw const FormatException('Invalid management configuration.');
    }
    return AgentManagementClient(config);
  }

  Future<Map<String, dynamic>> call(
    String route, {
    Object? body,
    File? file,
  }) async {
    final uri = Uri.parse(config['server'] as String).resolve('admin/$route');
    final request = await _http.openUrl(
      body == null && file == null ? 'GET' : 'POST',
      uri,
    );
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${config['adminToken']}',
    );
    if (file != null) {
      request.headers.contentType = ContentType.binary;
      request.contentLength = await file.length();
      await request.addStream(file.openRead());
    } else if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close().timeout(const Duration(minutes: 3));
    final text = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      String message =
          'Management request failed (${response.statusCode}). Check service status and configuration.';
      try {
        final error = jsonDecode(text);
        if (error is Map && error['error'] is String)
          message = error['error'] as String;
      } catch (_) {}
      throw HttpException(message);
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  void close() => _http.close(force: true);
}
