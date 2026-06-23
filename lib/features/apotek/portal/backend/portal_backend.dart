// Apotek Portal Backend State Management
// In the future, this file will manage logic, API services, and state providers for the Apotek Portal.

import 'package:flutter_riverpod/flutter_riverpod.dart';

final apotekPortalBackendProvider = Provider<ApotekPortalBackend>((ref) {
  return ApotekPortalBackend();
});

class ApotekPortalBackend {
  // Placeholder for future database and API integration
}
