// Verification suite for MonitoringSettingsScreen
// Validates:
// 1. Inactivity threshold preset chips (15p, 30p, 1h, 2h, 4h, 8h, 12h, 24h, custom)
// 2. Non-standard thresholds (1m, 45m, 90m, 137m, 500m, 10080m) assertion safety
// 3. Sleep schedule windows and day of week transitions
// 4. Time picker selection and apply-to-all-days batch update

import 'inactivity_threshold_sleep_test.dart' as inactivity_test;

void main() {
  inactivity_test.main();
}
