import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web implementation using browser navigator.onLine and online/offline events.
class ConnectionProbe {
  static bool get isPlatformOnline {
    try {
      return web.window.navigator.onLine;
    } catch (_) {
      return true;
    }
  }

  static Stream<bool> get onOnlineStatusChanged {
    late StreamController<bool> controller;
    JSFunction? onOnlineJs;
    JSFunction? onOfflineJs;

    controller = StreamController<bool>.broadcast(
      onListen: () {
        onOnlineJs = ((web.Event _) {
          if (!controller.isClosed) {
            controller.add(true);
          }
        }).toJS;
        onOfflineJs = ((web.Event _) {
          if (!controller.isClosed) {
            controller.add(false);
          }
        }).toJS;
        web.window.addEventListener('online', onOnlineJs);
        web.window.addEventListener('offline', onOfflineJs);
      },
      onCancel: () {
        if (onOnlineJs != null) {
          web.window.removeEventListener('online', onOnlineJs);
          onOnlineJs = null;
        }
        if (onOfflineJs != null) {
          web.window.removeEventListener('offline', onOfflineJs);
          onOfflineJs = null;
        }
      },
    );

    return controller.stream;
  }
}
