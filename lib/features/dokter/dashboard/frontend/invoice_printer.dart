import 'invoice_printer_stub.dart'
    if (dart.library.js) 'invoice_printer_web.dart';

void printInvoice(String jsonData) => printInvoiceHtml(jsonData);
