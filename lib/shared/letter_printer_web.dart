import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:convert';
import 'package:web/web.dart' as web;
import 'package:mapotech/shared/letter_models.dart';

Future<bool> printMedicalLetterHtml(MedicalLetterData data) async {
  try {
    final htmlContent = MedicalLetterData.buildPrintableHtml(data);
    final bytes = Uint8List.fromList(utf8.encode(htmlContent));
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
    );
    final blobUrl = web.URL.createObjectURL(blob);

    final existing = web.document.getElementById('mapotech-letter-print-iframe');
    existing?.remove();

    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
    iframe.id = 'mapotech-letter-print-iframe';
    iframe.style.position = 'fixed';
    iframe.style.top = '-9999px';
    iframe.style.left = '-9999px';
    iframe.style.width = '820px';
    iframe.style.height = '1px';
    iframe.style.border = 'none';
    iframe.src = blobUrl;

    final completer = Completer<bool>();
    late JSFunction loadListener;
    loadListener = ((web.Event _) {
      Timer(const Duration(milliseconds: 350), () {
        try {
          iframe.contentWindow?.focus();
          iframe.contentWindow?.print();
          if (!completer.isCompleted) completer.complete(true);
        } catch (_) {
          if (!completer.isCompleted) completer.complete(false);
        } finally {
          Timer(const Duration(seconds: 15), () {
            web.URL.revokeObjectURL(blobUrl);
            iframe.remove();
          });
        }
      });
    }).toJS;

    iframe.addEventListener('load', loadListener);
    web.document.body?.append(iframe);

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => true,
    );
  } catch (_) {
    return false;
  }
}
