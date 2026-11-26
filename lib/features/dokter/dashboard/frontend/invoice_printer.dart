import 'invoice_printer_stub.dart'
    if (dart.library.js_interop) 'invoice_printer_web.dart';

void printInvoice(String jsonData) => printInvoiceHtml(jsonData);
