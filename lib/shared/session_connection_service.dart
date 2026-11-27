import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/connection_probe.dart';
import 'package:mapotech/shared/supabase_service.dart';

/// Connection status for an authenticated MAPOTECH session.
enum SessionConnectionStatus { connected, disconnected, reconnecting }

/// Immutable snapshot of post-login session connectivity.
class SessionConnectionState {
  final SessionConnectionStatus status;
  final DateTime? disconnectedAt;
  final DateTime? lastConnectedAt;
  final int reconnectVersion;
  final int disconnectCount;
  final bool isBannerDismissed;
  final String? lastError;

  const SessionConnectionState({
    this.status = SessionConnectionStatus.connected,
    this.disconnectedAt,
    this.lastConnectedAt,
    this.reconnectVersion = 0,
    this.disconnectCount = 0,
    this.isBannerDismissed = false,
    this.lastError,
  });

  bool get isConnected => status == SessionConnectionStatus.connected;
  bool get isDisconnected => status == SessionConnectionStatus.disconnected;
  bool get isReconnecting => status == SessionConnectionStatus.reconnecting;

  SessionConnectionState copyWith({
    SessionConnectionStatus? status,
    DateTime? disconnectedAt,
    bool clearDisconnectedAt = false,
    DateTime? lastConnectedAt,
    int? reconnectVersion,
    int? disconnectCount,
    bool? isBannerDismissed,
    String? lastError,
    bool clearLastError = false,
  }) {
    return SessionConnectionState(
      status: status ?? this.status,
      disconnectedAt: clearDisconnectedAt
          ? null
          : (disconnectedAt ?? this.disconnectedAt),
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      reconnectVersion: reconnectVersion ?? this.reconnectVersion,
      disconnectCount: disconnectCount ?? this.disconnectCount,
      isBannerDismissed: isBannerDismissed ?? this.isBannerDismissed,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

/// Monitors connectivity while a user is logged in and supports seamless
/// reconnection without discarding the user's authenticated session.
class SessionConnectionNotifier extends StateNotifier<SessionConnectionState> {
  final Future<bool> Function() _probeReachability;
  final bool Function() _isPlatformOnline;
  final Stream<bool> _onlineStream;
  final Duration _connectedCheckInterval;
  final Duration _disconnectedRetryInterval;
  final bool _previewDisconnectedOnStart;

  StreamSubscription<bool>? _onlineSub;
  Timer? _checkTimer;
  bool _isMonitoring = false;
  bool _isChecking = false;
  DateTime? _lastFailureProbeAt;

  SessionConnectionNotifier({
    Future<bool> Function()? probeReachability,
    bool Function()? isPlatformOnline,
    Stream<bool>? onlineStream,
    Duration connectedCheckInterval = const Duration(seconds: 20),
    Duration disconnectedRetryInterval = const Duration(seconds: 8),
    bool previewDisconnectedOnStart = false,
  })  : _probeReachability =
            probeReachability ?? SupabaseService.checkReachability,
        _isPlatformOnline =
            isPlatformOnline ?? (() => ConnectionProbe.isPlatformOnline),
        _onlineStream =
            onlineStream ?? ConnectionProbe.onOnlineStatusChanged,
        _connectedCheckInterval = connectedCheckInterval,
        _disconnectedRetryInterval = disconnectedRetryInterval,
        _previewDisconnectedOnStart = previewDisconnectedOnStart,
        super(SessionConnectionState(lastConnectedAt: DateTime.now()));

  /// Enables or disables active post-login connection monitoring.
  void setMonitoringActive(bool active) {
    if (!mounted) return;
    if (active == _isMonitoring) return;

    _isMonitoring = active;
    if (!active) {
      _stopMonitoring();
      state = SessionConnectionState(lastConnectedAt: DateTime.now());
      return;
    }

    _onlineSub?.cancel();
    _onlineSub = _onlineStream.listen(_handlePlatformConnectivityEvent);

    if (_previewDisconnectedOnStart) {
      _markDisconnected(reason: 'ui_preview');
      return;
    }

    // Run an immediate connectivity check when entering the logged-in shell.
    if (!_isPlatformOnline()) {
      _markDisconnected(reason: 'offline');
      _scheduleNextCheck();
    } else {
      unawaited(checkConnection());
    }
  }

  void _handlePlatformConnectivityEvent(bool isOnline) {
    if (!mounted || !_isMonitoring) return;
    if (!isOnline) {
      _markDisconnected(reason: 'offline');
      _scheduleNextCheck();
    } else {
      // Browser/OS regained connectivity: transition smoothly and verify server.
      unawaited(checkConnection(userInitiated: !state.isConnected));
    }
  }

  /// Checks server reachability and updates connection state without logging out.
  Future<bool> checkConnection({bool userInitiated = false}) async {
    if (!mounted) return false;
    if (!_isMonitoring) return true;
    if (_isChecking) return state.isConnected;

    _isChecking = true;
    _checkTimer?.cancel();

    final wasDisconnected = !state.isConnected;
    if (userInitiated || wasDisconnected) {
      state = state.copyWith(
        status: SessionConnectionStatus.reconnecting,
        isBannerDismissed: userInitiated ? false : state.isBannerDismissed,
        clearLastError: true,
      );
    }

    bool reachable = false;
    try {
      if (_isPlatformOnline()) {
        reachable = await _probeReachability();
      }
    } catch (_) {
      reachable = false;
    } finally {
      _isChecking = false;
    }

    if (!mounted || !_isMonitoring) return reachable;

    if (reachable) {
      _markConnected(wasDisconnected: wasDisconnected);
    } else {
      _markDisconnected(
        reason: _isPlatformOnline() ? 'server_unreachable' : 'offline',
      );
    }

    _scheduleNextCheck();
    return reachable;
  }

  /// Manually triggered by the user via the "Reconnect" action.
  Future<bool> reconnect() async {
    return checkConnection(userInitiated: true);
  }

  /// Called when an in-app network request fails so disconnect is detected immediately.
  void reportNetworkFailure() {
    if (!mounted || !_isMonitoring || _isChecking) return;
    final now = DateTime.now();
    if (_lastFailureProbeAt != null &&
        now.difference(_lastFailureProbeAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastFailureProbeAt = now;
    unawaited(checkConnection());
  }

  /// Collapses the top disconnect banner while keeping the compact top-bar reconnect pill.
  void dismissBanner() {
    if (!mounted || state.isConnected) return;
    state = state.copyWith(isBannerDismissed: true);
  }

  void _markConnected({required bool wasDisconnected}) {
    final now = DateTime.now();
    state = state.copyWith(
      status: SessionConnectionStatus.connected,
      clearDisconnectedAt: true,
      lastConnectedAt: now,
      reconnectVersion:
          wasDisconnected ? state.reconnectVersion + 1 : state.reconnectVersion,
      isBannerDismissed: false,
      clearLastError: true,
    );
  }

  void _markDisconnected({required String reason}) {
    final isNewDisconnect = state.disconnectedAt == null;
    state = state.copyWith(
      status: SessionConnectionStatus.disconnected,
      disconnectedAt: state.disconnectedAt ?? DateTime.now(),
      disconnectCount:
          isNewDisconnect ? state.disconnectCount + 1 : state.disconnectCount,
      isBannerDismissed: isNewDisconnect ? false : state.isBannerDismissed,
      lastError: reason,
    );
  }

  void _scheduleNextCheck() {
    _checkTimer?.cancel();
    if (!mounted || !_isMonitoring) return;
    final interval = state.isConnected
        ? _connectedCheckInterval
        : _disconnectedRetryInterval;
    _checkTimer = Timer(interval, () {
      if (mounted && _isMonitoring) {
        unawaited(checkConnection());
      }
    });
  }

  void _stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _onlineSub?.cancel();
    _onlineSub = null;
    _isChecking = false;
  }

  @override
  void dispose() {
    _isMonitoring = false;
    _stopMonitoring();
    super.dispose();
  }
}

final sessionConnectionProvider =
    StateNotifierProvider<SessionConnectionNotifier, SessionConnectionState>((
      ref,
    ) {
      // UI preview mode: starts logged-in sessions with the disconnect notification
      // visible first so the UI can be inspected immediately; set to false to restore
      // normal live-probe initial behavior.
      final notifier = SessionConnectionNotifier(
        previewDisconnectedOnStart: true,
      );
      final isLoggedIn = ref.read(landingPageProvider).isLoggedIn;
      notifier.setMonitoringActive(isLoggedIn);

      ref.listen<bool>(
        landingPageProvider.select((s) => s.isLoggedIn),
        (_, nextLoggedIn) {
          notifier.setMonitoringActive(nextLoggedIn);
        },
      );

      return notifier;
    });
