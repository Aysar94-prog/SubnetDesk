import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/connection_diagnostics.dart';

void main() {
  test('accepts DNS, IPv4 and bracketed or bare IPv6 endpoints', () {
    expect(DiagnosticEndpoint.parse(' office.local ').port, 21118);
    expect(DiagnosticEndpoint.parse('192.0.2.4:2222').port, 2222);
    expect(DiagnosticEndpoint.parse('[::1]:21118').host, '::1');
    expect(DiagnosticEndpoint.parse('::1').port, 21118);
  });
  test('rejects invalid ports, URL paths and credentials', () {
    for (final value in [
      '',
      'host:0',
      'host:65536',
      'host:',
      'user@host',
      'host/path',
      'a b',
    ]) {
      expect(
        () => DiagnosticEndpoint.parse(value),
        throwsFormatException,
        reason: value,
      );
    }
  });
  test('TCP probe succeeds without sending any bytes', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = <int>[];
    final connections = <Socket>[];
    final subscription = server.listen((socket) {
      connections.add(socket);
      socket.listen(received.addAll);
    });
    try {
      final result = await diagnoseConnection('127.0.0.1:${server.port}');
      expect(result.state, DiagnosticState.reachable);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(received, isEmpty);
      expect(result.message, contains('access still need verification'));
    } finally {
      for (final socket in connections) {
        socket.destroy();
      }
      await subscription.cancel();
      await server.close();
    }
  });
  test('closed port is reported as refused', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    expect(
      (await diagnoseConnection('127.0.0.1:$port')).state,
      DiagnosticState.refused,
    );
  });
}
