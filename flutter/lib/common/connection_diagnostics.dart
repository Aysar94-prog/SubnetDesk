import 'dart:async';
import 'dart:io';

class DiagnosticEndpoint {
  const DiagnosticEndpoint(this.host, this.port);
  final String host;
  final int port;

  static DiagnosticEndpoint parse(String input) {
    final text = input.trim();
    if (text.isEmpty || RegExp(r'\s').hasMatch(text)) {
      throw const FormatException('Enter an IP address or hostname');
    }
    if (InternetAddress.tryParse(text) != null) {
      return DiagnosticEndpoint(text, 21118);
    }
    final uri = Uri.parse('tcp://$text');
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (text.contains(':') &&
            !text.startsWith('[') &&
            text.split(':').length > 2)) {
      throw const FormatException('Use hostname:port or [IPv6]:port');
    }
    final match = RegExp(
      r'^(\[[^\]]+\]|[^:]+)(?::([0-9]+))?$',
    ).firstMatch(text);
    if (match == null) {
      throw const FormatException('Use hostname:port or [IPv6]:port');
    }
    final port = match.group(2) == null
        ? 21118
        : int.tryParse(match.group(2)!) ?? 0;
    if (port < 1 || port > 65535 || text.endsWith(':')) {
      throw const FormatException('Port must be between 1 and 65535');
    }
    return DiagnosticEndpoint(
      uri.host.replaceAll('[', '').replaceAll(']', ''),
      port,
    );
  }
}

enum DiagnosticState { reachable, invalid, dnsFailed, refused, timeout, failed }

class ConnectionDiagnostic {
  const ConnectionDiagnostic(this.state, this.message, {this.elapsedMs});
  final DiagnosticState state;
  final String message;
  final int? elapsedMs;
}

/// A TCP probe only. It sends no credentials and cannot prove app identity,
/// authentication, or whether a firewall caused a timeout.
Future<ConnectionDiagnostic> diagnoseConnection(
  String input, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  late DiagnosticEndpoint endpoint;
  try {
    endpoint = DiagnosticEndpoint.parse(input);
  } on FormatException catch (e) {
    return ConnectionDiagnostic(DiagnosticState.invalid, e.message);
  }
  final watch = Stopwatch()..start();
  try {
    final addresses = await InternetAddress.lookup(
      endpoint.host,
    ).timeout(timeout);
    if (addresses.isEmpty) {
      return const ConnectionDiagnostic(
        DiagnosticState.dnsFailed,
        'The hostname could not be resolved. Check the name or use an IP address.',
      );
    }
    var refused = false;
    var timedOut = false;
    for (var index = 0; index < addresses.length; index++) {
      final address = addresses[index];
      final remaining = timeout - watch.elapsed;
      if (remaining <= Duration.zero) {
        timedOut = true;
        break;
      }
      try {
        final attemptTimeout = Duration(
          microseconds: remaining.inMicroseconds ~/ (addresses.length - index),
        );
        final socket = await Socket.connect(
          address,
          endpoint.port,
          timeout: attemptTimeout,
        );
        socket.destroy();
        return ConnectionDiagnostic(
          DiagnosticState.reachable,
          'TCP port is reachable. Device identity and access still need verification when connecting.',
          elapsedMs: watch.elapsedMilliseconds,
        );
      } on SocketException catch (e) {
        refused |= [61, 111, 1225, 10061].contains(e.osError?.errorCode);
        timedOut |=
            [110, 10060].contains(e.osError?.errorCode) ||
            e.message.toLowerCase().contains('timed out');
      } on TimeoutException {
        timedOut = true;
      }
    }
    if (timedOut) {
      return const ConnectionDiagnostic(
        DiagnosticState.timeout,
        'No response before the timeout. Check the network, receiver service and firewall rules.',
      );
    }
    if (refused) {
      return const ConnectionDiagnostic(
        DiagnosticState.refused,
        'The connection was refused. Check that the receiver service is running on this port.',
      );
    }
    return const ConnectionDiagnostic(
      DiagnosticState.failed,
      'Could not reach this port. Check the address and network connection.',
    );
  } on TimeoutException {
    return const ConnectionDiagnostic(
      DiagnosticState.timeout,
      'The network lookup timed out.',
    );
  } on SocketException {
    return const ConnectionDiagnostic(
      DiagnosticState.dnsFailed,
      'The hostname could not be resolved. Check the name or use an IP address.',
    );
  }
}
