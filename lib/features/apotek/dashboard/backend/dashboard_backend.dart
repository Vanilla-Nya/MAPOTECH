// Apotek Dashboard Backend State Management
// In the future, this file will manage logic, API services, and state providers for the Apotek Dashboard.

import 'package:flutter_riverpod/flutter_riverpod.dart';

final apotekDashboardBackendProvider = Provider<ApotekDashboardBackend>((ref) {
  return ApotekDashboardBackend();
});

class ApotekDashboardBackend {
  // Placeholder for future database and API integration
}
