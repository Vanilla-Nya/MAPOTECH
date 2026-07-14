# Walkthrough - Puskesmas & Ponkesdes Dashboard Alignment with Doctor EMR

Successfully updated and unified the **Puskesmas** and **Ponkesdes** dashboards to route to the doctor's full EMR suite and aligned their profile tab selections.

## Changes Made

### 1. Routing & Unified EMR Pages
- Updated `_buildRoleDashboardBody` in [dashboard_shell.dart](file:///c:/Project/mapotech/lib/features/dashboard/dashboard_shell.dart) to route Puskesmas and Ponkesdes roles to the exact same EMR components used by the private practice (`dokter`):
  - **Dashboard**: `DokterDashboard`
  - **Patients list**: `DokterPasien`
  - **Medicines**: `DokterObat`
  - **Queues**: `DokterAntrian`
  - **Examinations**: `DokterPemeriksaan`
  - **Bookkeeping**: `DokterPembukuan`
  - **Practice Assistant**: `DokterAsisten`
  - **Settings**: `DokterSettings`
- Since these pages dynamically fetch data using the provider's `activeDoctorId` (which falls back to the logged in user ID), they load their respective Puskesmas or Ponkesdes data seamlessly.

### 2. Drawer Items Alignment
- Updated [dashboard_drawer.dart](file:///c:/Project/mapotech/lib/features/dashboard/widgets/dashboard_drawer.dart) to display the identical EMR items list for Puskesmas and Ponkesdes roles.

### 3. Subscription & Settings Card
- Updated `_checkSubscription` in [dashboard_shell.dart](file:///c:/Project/mapotech/lib/features/dashboard/dashboard_shell.dart) to validate Puskesmas and Ponkesdes subscriptions from the `public.user` table columns (`subscription_status`, `subscription_expires_at`).
- Puskesmas and Ponkesdes profiles now display a fully functional **Subscription Status Card** in Tab 0, letting users review remaining days and renew their portal subscription for 30 days.

## Verification

- Tested all routes; dashboard, patient search, queues, bookkeeping, and settings render correctly for Puskesmas and Ponkesdes roles.
- `flutter analyze` completed with no compile errors.
