enum RemoteConnectionState { connecting, connected, disconnected }

const connectionAutoRetryWindow = Duration(seconds: 60);
const _resumeDisconnectGrace = Duration(seconds: 5);
const _transientConnectionErrors = [
  'timeout',
  'reset by the peer',
  'failed to lookup address information',
  'no address associated with hostname',
  'failed to look up host',
  'temporary failure in name resolution',
];

class MobileConnectionRetryPolicy {
  var _state = RemoteConnectionState.connecting;
  var _peerInfoReceived = false;
  DateTime? _retryStartedAt;
  DateTime? _lastTransientDisconnectAt;

  void reset() {
    _state = RemoteConnectionState.connecting;
    _peerInfoReceived = false;
    _retryStartedAt = null;
    _lastTransientDisconnectAt = null;
  }

  void onPeerInfo() => _peerInfoReceived = true;

  void onConnected() {
    _state = RemoteConnectionState.connected;
    _retryStartedAt = null;
    _lastTransientDisconnectAt = null;
  }

  void onReconnect() => _state = RemoteConnectionState.connecting;

  bool handlesConnectionError(String type, String title, String text) {
    final normalized = text.toLowerCase();
    return _peerInfoReceived &&
        type == 'error' &&
        title == 'Connection Error' &&
        _transientConnectionErrors.any(normalized.contains);
  }

  void onConnectionError(String type, String title, String text, DateTime now) {
    if (title != 'Connection Error') return;
    _state = RemoteConnectionState.disconnected;
    _lastTransientDisconnectAt =
        handlesConnectionError(type, title, text) ? now : null;
  }

  bool shouldAutoRetry(String type, String title, String text, DateTime now) {
    if (!handlesConnectionError(type, title, text)) return false;
    _retryStartedAt ??= now;
    return now.difference(_retryStartedAt!) < connectionAutoRetryWindow;
  }

  bool reconnectOnResume(DateTime? backgroundedAt, DateTime now) {
    if (_state != RemoteConnectionState.disconnected ||
        backgroundedAt == null ||
        _lastTransientDisconnectAt == null ||
        _lastTransientDisconnectAt!
            .isBefore(backgroundedAt.subtract(_resumeDisconnectGrace))) {
      return false;
    }
    // Background suspension must not consume the foreground recovery window.
    _retryStartedAt = now;
    onReconnect();
    return true;
  }
}
