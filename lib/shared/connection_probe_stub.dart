/// Non-web fallback for platform network status probing.
class ConnectionProbe {
  static bool get isPlatformOnline => true;

  static Stream<bool> get onOnlineStatusChanged => const Stream<bool>.empty();
}
