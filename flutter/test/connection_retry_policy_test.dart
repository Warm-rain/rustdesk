import 'package:flutter_hbb/models/connection_retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 11, 10);

  test('retries established transient failures for at most 60 seconds', () {
    for (final text in [
      'Timeout',
      'Reset by the peer',
      'failed to lookup address information: No address associated with hostname',
      'No address associated with hostname',
      'Failed to look up host',
      'Temporary failure in name resolution',
    ]) {
      final policy = MobileConnectionRetryPolicy();
      expect(policy.shouldAutoRetry('error', 'Connection Error', text, now),
          isFalse);
      policy.onPeerInfo();
      policy.onConnected();
      policy.onConnectionError('error', 'Connection Error', text, now);
      expect(policy.shouldAutoRetry('error', 'Connection Error', text, now),
          isTrue);
      expect(
          policy.shouldAutoRetry('error', 'Connection Error', text,
              now.add(const Duration(seconds: 59))),
          isTrue);
      expect(
          policy.shouldAutoRetry('error', 'Connection Error', text,
              now.add(const Duration(seconds: 60))),
          isFalse);
      policy.onConnected();
      expect(policy.reconnectOnResume(now, now.add(const Duration(minutes: 5))),
          isFalse);
      policy.onConnectionError('error', 'Connection Error', text,
          now.add(const Duration(minutes: 6)));
      expect(
          policy.shouldAutoRetry('error', 'Connection Error', text,
              now.add(const Duration(minutes: 6))),
          isTrue);
    }
  });

  test('long background suspension gets one fresh foreground recovery window',
      () {
    final policy = MobileConnectionRetryPolicy();
    final disconnectedAt = now.add(const Duration(seconds: 30));
    final resumedAt = now.add(const Duration(minutes: 5));
    policy.onPeerInfo();
    policy.onConnected();
    policy.onConnectionError(
        'error', 'Connection Error', 'Timeout', disconnectedAt);
    expect(
        policy.shouldAutoRetry(
            'error', 'Connection Error', 'Timeout', disconnectedAt),
        isTrue);
    expect(
        policy.shouldAutoRetry(
            'error', 'Connection Error', 'Timeout', resumedAt),
        isFalse);
    expect(policy.reconnectOnResume(now, resumedAt), isTrue);
    expect(policy.reconnectOnResume(now, resumedAt), isFalse);
    policy.onConnectionError('error', 'Connection Error',
        'Failed to look up host', resumedAt.add(const Duration(seconds: 10)));
    expect(
        policy.shouldAutoRetry(
            'error',
            'Connection Error',
            'Failed to look up host',
            resumedAt.add(const Duration(seconds: 10))),
        isTrue);
    policy.onReconnect();
    expect(policy.reconnectOnResume(now, resumedAt), isFalse);
  });

  test('does not recover old errors, permanent errors or a new session', () {
    final policy = MobileConnectionRetryPolicy();
    final resumedAt = now.add(const Duration(minutes: 5));
    policy.onPeerInfo();
    policy.onConnectionError('error', 'Connection Error', 'Timeout',
        now.subtract(const Duration(seconds: 20)));
    expect(policy.reconnectOnResume(now, resumedAt), isFalse);
    expect(policy.reconnectOnResume(null, resumedAt), isFalse);
    for (final text in ['Wrong password', 'Key mismatch', 'Manually closed']) {
      policy.onConnectionError('error', 'Connection Error', 'Timeout', now);
      policy.onConnectionError('error', 'Connection Error', text, now);
      expect(policy.shouldAutoRetry('error', 'Connection Error', text, now),
          isFalse);
      expect(policy.reconnectOnResume(now, resumedAt), isFalse);
    }
    policy.reset();
    policy.onConnectionError('error', 'Connection Error', 'Timeout', now);
    expect(policy.shouldAutoRetry('error', 'Connection Error', 'Timeout', now),
        isFalse);
    expect(policy.reconnectOnResume(now, resumedAt), isFalse);
  });
}
