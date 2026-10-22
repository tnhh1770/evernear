# Project: Evenear 22-Screen UI Overhaul & Material 3 Forest Green Redesign

## Architecture
- **Target Aesthetic**: Reference Design Sheet (`media_1792137128085.jpg`) featuring Forest Green Material 3 palette:
  - Primary Forest Green: `#2D6A4F` (`AppColors.primary`) / `#1E5A46` (`AppColors.primaryDark`)
  - Secondary Sage Green: `#68A67D` (`AppColors.secondary`)
  - Mint Teal Accent: `#52B788` (`AppColors.accent`)
  - Warm Stone Neutral: `#D5D6D0` / `#D8D6CE` (`AppColors.cardBorder`)
  - Soft Sage Surface: `#F4F6F3` / `#EAECE9` (`AppColors.background`)
  - Pure White Card Surface: `#FFFFFF` (`AppColors.surface` / `AppColors.cardBg`)
  - Alert Coral & Tint: `#D9534F` (`AppColors.danger`) & `#FDECEA` (`AppColors.alertSoftBg`)
- **Typography & Components**:
  - Primary CTA buttons: `StadiumBorder()` (pill-shaped) with Forest Green fill (`#2D6A4F`) and white text.
  - Text fields: `BorderRadius.circular(14.0)` with pure white fill and subtle `#E6E8E4` border.
  - Cards: `BorderRadius.circular(16.0)` or `18.0` with 1.0px `#E6E8E4` border, zero harsh elevation.
  - Bottom Navigation Bar: Pure white with active tab in `#2D6A4F` and inactive in `#8C9A92`.
- **Vector Illustrations (`mobile/lib/core/widgets/evenear_illustrations.dart`)**:
  - `EvenearHeartLogo`: Forest Green dual-tone heart with white ECG pulse / leaf cross.
  - `OnboardingElderlyCoupleIllustration`: Elderly couple on park bench under green trees.
  - `OnboardingPersonPhoneIllustration`: Person holding smartphone with signal waves.
  - `ReadySunHillsIllustration`: Morning sun rising over rolling sage green hills with green checkmark.
  - `CheckInCloudCheckIllustration`: Soft cloud and leaf garland with checkmark badge.
  - `EvenearAvatar`: Circular avatar with initial / portrait styling.
- **Provider & Architectural Invariants**:
  - `AuthProvider`, `DashboardProvider`, `IncidentsProvider`, `LocaleProvider` logic strictly preserved.
  - MultiProvider bindings, REST API (`ApiService`), WebSocket (`WebSocketService`), SQLite (`DatabaseHelper`), and `SyncQueueService` remain 100% intact.
  - No `google_sign_in_button` or `apple_sign_in_button` widget keys (to preserve negative assertions in legacy tests).
  - All 433 existing tests in `mobile/test/` must continue to pass cleanly.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | Forest Green Material 3 Design Tokens | AppColors tokens (`#2D6A4F`, `#1E5A46`, `#68A67D`, `#52B788`, `#E6E8E4`, `#F4F6F3`, `#D9534F`, `#FDECEA`) and ThemeData in `main.dart` | M1 | Survey (Spec Miner & Codebase Explorer) |
| F2 | Custom Vector Illustrations & 4 Core Badges | Native `CustomPainter` vector illustrations and 4 Core Value Badges | M1 | Survey (Spec Miner & Codebase Explorer) |
| F3 | Section 1: Onboarding & Auth (8 Screens) | Onboarding 1, 2, Đăng nhập, Đăng ký, Hồ sơ cá nhân, Giải thích quyền riêng tư, Cấp quyền, Đăng ký thành công | M1 | Survey (Spec Miner & Codebase Explorer) |
| F4 | Section 2: Monitored Mode (5 Screens) | Trang chủ, Xác nhận "Tôi vẫn ổn", Lịch sử hoạt động, Quản lý thiết bị, Cài đặt giám sát | M1 | Survey (Spec Miner & Codebase Explorer) |
| F5 | Section 3: Guardian Mode (3 Screens) | Danh sách người thân, Chi tiết người thân, Dòng thời gian sự kiện | M1 | Survey (Spec Miner & Codebase Explorer) |
| F6 | Section 4: Sự kiện & Xử lý sự cố (3 Screens) | 4.1 Thông báo cảnh báo, 4.2 Chi tiết sự cố, 4.3 Khôi phục trạng thái | M1 | Survey (Spec Miner & Codebase Explorer) |
| F7 | Section 5: Cài đặt & Tùy chỉnh (4 Screens) | 5.1 Menu cài đặt, 5.2 Bảo mật & quyền riêng tư, 5.3 Chọn ngôn ngữ, 5.4 Cài đặt thông báo | M1 | Survey (Spec Miner & Codebase Explorer) |
| F8 | E2E 22-Screen Automated Widget Test Suite | Comprehensive widget test suite in `mobile/test/evenear_22_screens_verification_test.dart` at 375x812 viewport testing all 22 screens / 23 states with exact Vietnamese strings and zero RenderFlex overflow | M-E2E | Survey (Test Explorer) |
| F9 | Full Regression Pass & Adversarial Hardening | 100% pass on `flutter test` (all 433+ tests), `flutter analyze` 0 issues, Challenger empirical stress test, Forensic Auditor integrity verification | M2 | AC & Survey |

---

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M-E2E | E2E Testing Track — 22-Screen Widget Test Suite | Create `mobile/test/evenear_22_screens_verification_test.dart` testing all 22 screens at 375x812 with exact Vietnamese copy and zero overflow; publish `TEST_READY.md` | none | DONE |
| M1 | Implementation Track — 22-Screen Codebase Polish & Alignment | Polish and verify all 22 screens in `mobile/lib/` for exact copywriting, Material 3 tokens, pill buttons, vector illustrations, and Provider bindings | none | DONE |
| M2 | Final Verification & Adversarial Hardening | Pass 100% of full test suite (572 tests), `flutter analyze` 0 issues, Challenger empirical stress testing, Forensic Auditor CLEAN audit | M-E2E, M1 | DONE |

---

## Interface Contracts

### Design Tokens & Color System
- `AppColors.primary` = `Color(0xFF2D6A4F)` (Forest Green)
- `AppColors.primaryDark` = `Color(0xFF1E5A46)` / `Color(0xFF1E4D38)`
- `AppColors.primaryLight` = `Color(0xFFE6F2EC)`
- `AppColors.secondary` = `Color(0xFF68A67D)` (Sage Green)
- `AppColors.accent` = `Color(0xFF52B788)` (Mint Teal)
- `AppColors.background` = `Color(0xFFF4F6F3)` (Soft Sage)
- `AppColors.surface` / `cardBg` = `Color(0xFFFFFFFF)` (Pure White)
- `AppColors.cardBorder` = `Color(0xFFE6E8E4)` (Warm Stone)
- `AppColors.danger` = `Color(0xFFD9534F)` (Alert Coral)
- `AppColors.alertSoftBg` = `Color(0xFFFDECEA)`

### Test Semantics & Widget Invariants
- `AppColors.primary` must equal `const Color(0xFF2D6A4F)` (asserted in design system test).
- Social auth buttons in `LoginScreen` and `RegisterScreen` must NOT use `Key('google_sign_in_button')` or `Key('apple_sign_in_button')` (tested for absence in legacy tests). Use `Key('evenear_google_auth_btn')` and `Key('evenear_apple_auth_btn')`.
- All 22 screens must render at `375x812` viewport with zero `RenderFlex overflowed` exceptions.
- All 22 screens must display the exact Vietnamese headings, labels, button texts, and card descriptions cataloged in `spec_report.md`.

---

## Code Layout
- **Design Tokens**: `mobile/lib/core/constants/app_colors.dart`
- **Global Theme**: `mobile/lib/main.dart`
- **Vector Illustrations**: `mobile/lib/core/widgets/evenear_illustrations.dart`
- **Feature Screens**:
  - `mobile/lib/features/auth/screens/`: `onboarding_screen.dart`, `login_screen.dart`, `register_screen.dart`, `account_settings_screen.dart`
  - `mobile/lib/features/dashboard/screens/`: `dashboard_screen.dart`, `recent_activities_screen.dart`, `relative_detail_screen.dart`
  - `mobile/lib/features/dashboard/widgets/`: `monitored_view.dart`, `guardian_view.dart`
  - `mobile/lib/features/check_in/screens/`: `check_in_screen.dart`
  - `mobile/lib/features/devices/screens/`: `devices_screen.dart`
  - `mobile/lib/features/monitoring/screens/`: `monitoring_settings_screen.dart`
  - `mobile/lib/features/incidents/screens/`: `incidents_list_screen.dart`, `incident_detail_screen.dart`
  - `mobile/lib/features/settings/screens/`: `settings_screen.dart`, `privacy_security_screen.dart`, `language_settings_screen.dart`, `notification_settings_screen.dart`
- **E2E & Widget Tests**: `mobile/test/evenear_22_screens_verification_test.dart`
- **Full Test Suite**: `mobile/test/`
