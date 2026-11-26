import 'package:mapotech/shared/letter_models.dart';
import 'letter_printer_stub.dart'
    if (dart.library.js_interop) 'letter_printer_web.dart';

Future<bool> printMedicalLetter(MedicalLetterData data) =>
    printMedicalLetterHtml(data);
