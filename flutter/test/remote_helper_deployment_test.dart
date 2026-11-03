import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/remote_helper_deployment.dart';

class FakeDeployer implements RemoteHelperDeployer {
  int active = 0, peak = 0;
  final seen = <RemoteHelperDeploymentRequest>[];
  @override
  Future<RemoteHelperDeploymentResult> deploy(
    RemoteHelperDeploymentRequest request,
  ) async {
    seen.add(request);
    active++;
    if (active > peak) peak = active;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    active--;
    if (request.target == 'bad') throw StateError('unreachable');
    return const RemoteHelperDeploymentResult(
      succeeded: true,
      message: 'verified',
    );
  }
}

List<RemoteHelperDeploymentRequest> requests(List<String> targets) => targets
    .map(
      (target) => RemoteHelperDeploymentRequest(
        target: target,
        username: 'admin',
        administratorPassword: 'secret',
        msiPath: r'C:\Selected versions\Helper-v2.msi',
      ),
    )
    .toList();

void main() {
  test('600 devices can run with a chosen concurrency including 600', () async {
    for (final concurrency in [20, 600]) {
      final fake = FakeDeployer();
      var completed = 0;
      await BulkHelperDeployment().run(
        requests(List.generate(600, (i) => 'pc$i')),
        fake,
        concurrency: concurrency,
        onResult: (_, __) => completed++,
      );
      expect(completed, 600);
      expect(fake.seen.length, 600);
      expect(fake.peak, concurrency);
    }
  });
  test('bulk targets accept common separators and remove duplicate hosts', () {
    expect(parseDeploymentTargets('PC1\npc2,PC1;10.0.0.3  pc2'), [
      'PC1',
      'pc2',
      '10.0.0.3',
    ]);
  });
  test(
    'bulk keeps selected MSI, bounds concurrency and isolates device failures',
    () async {
      final fake = FakeDeployer();
      final results = <String, RemoteHelperDeploymentResult>{};
      await BulkHelperDeployment().run(
        requests(['a', 'b', 'bad', 'c', 'd']),
        fake,
        concurrency: 2,
        onResult: (host, result) => results[host] = result,
      );
      expect(fake.peak, 2);
      expect(results.length, 5);
      expect(results['bad']!.succeeded, false);
      expect(results.values.where((r) => r.succeeded).length, 4);
      expect(
        fake.seen.every(
          (r) => r.msiPath == r'C:\Selected versions\Helper-v2.msi',
        ),
        true,
      );
    },
  );
  test(
    'stop pending finishes current device and leaves others unstarted',
    () async {
      final fake = FakeDeployer();
      var cancelled = false;
      await BulkHelperDeployment().run(
        requests(['a', 'b', 'c']),
        fake,
        concurrency: 1,
        cancelled: () => cancelled,
        onResult: (_, __) => cancelled = true,
      );
      expect(fake.seen.map((r) => r.target), ['a']);
    },
  );
  test(
    'reads selected MSI metadata from a path with spaces and rejects Deploy',
    () async {
      final helper = await HelperMsiPackage.inspect(
        Platform.environment['HELPER_MSI_TEST_PATH']!,
      );
      expect(helper.version, matches(RegExp(r'^\d+\.\d+\.\d+')));
      expect(helper.sha256.length, 64);
      expect(helper.productCode, startsWith('{'));
      await expectLater(
        HelperMsiPackage.inspect(
          Platform.environment['DEPLOY_MSI_TEST_PATH']!,
        ),
        throwsFormatException,
      );
    },
    skip: !Platform.isWindows || !Platform.environment.containsKey('HELPER_MSI_TEST_PATH') ||
        !Platform.environment.containsKey('DEPLOY_MSI_TEST_PATH'),
  );
}
