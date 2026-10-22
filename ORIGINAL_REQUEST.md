# Original User Request

## 2026-10-15T08:53:50Z

Perform a comprehensive architectural and feature analysis of the full-stack repository (`backend/`, `mobile/`, and technical documentation) and build a production-grade, interactive, zero-build Landing Page for **Evernear** in `/home/tnuc/project/Carely/landing` using HTML5, Tailwind CSS, and Vanilla JavaScript.

Working directory: /home/tnuc/project/Carely
Integrity mode: development

## Requirements

### R1. Deep System Analysis & Feature Alignment
Analyze the complete system across `backend/` (NestJS 12, PostgreSQL 16, Redis 7, WebSocket, Multi-channel FCM/SMS/Telegram alerts, Composite Risk Score 0–100, 8-state Monitoring State Machine, 3 Core Axioms) and `mobile/` (Flutter 3.47 Dual-View Dashboard, Passive Activity vs. Heartbeat vs. Check-in separation, Quiet Hours / Sleep Windows, QR Pairing, Offline Sync Queue, GDPR Privacy & Right to Erasure). Ensure all technical claims, metrics, and user flows presented on the landing page accurately reflect the real system capabilities and the **Evernear** brand identity (including existing logo assets in `landing/assets/images/` and `logo_options/`).

### R2. Interactive Multi-Mode App Simulator & State Machine Visualizer
Upgrade the landing page (`/home/tnuc/project/Carely/landing/index.html` and supporting static assets if needed) with rich interactive experiences:
1. **Dual-Mode Interactive Phone Simulator**: Allow visitors to switch between **Monitored Mode (Người được bảo vệ)** (featuring the "Tôi vẫn ổn" check-in button, passive activity simulation like charging/screen unlock, Quiet Hours status, and pause monitoring) and **Guardian Mode (Người giám hộ)** (displaying family member safety status, non-diagnostic risk score indicator, incident acknowledgement, and QR pairing preview).
2. **Interactive 8-State Monitoring Visualizer**: Allow visitors to explore and trigger transitions across the authoritative server state machine (`INITIALIZING`, `ACTIVE`, `CHECK_IN_REQUIRED`, `GRACE_PERIOD`, `ALERT_TRIGGERED`, `ACKNOWLEDGED`, `RESOLVED`, `PAUSED`) and compare signal weights (`Heartbeat = 0.0`, `Activity = 0.2–0.8`, `Check-in = 1.0`).

### R3. Comprehensive Content Sections, Calm UX Design & Bilingual Support (VI / EN)
Preserve and elevate Evernear's **Calm UX** philosophy (warm, reassuring copy, emerald/teal/amber palette, responsive modern glassmorphism, smooth micro-animations, accessible contrast) while covering: Hero & Value Proposition, Target Audiences, 3 Core Axioms & Signal Weight Comparison, Interactive State Machine & Risk Scoring Explainer, Privacy-by-Default Comparison Table & GDPR Guarantees, 3-Step Onboarding & QR Pairing, Testimonials, FAQ Accordion, and Download CTA. Provide an instant **Vietnamese / English (VI / EN)** language switcher that dynamically localizes all visible sections without page reload.

## Acceptance Criteria

### Functional & Interactive Verification
- [ ] Serving `/home/tnuc/project/Carely/landing` over HTTP returns HTTP 200 for `index.html` and all referenced local images/icons/scripts with zero 404 network errors and zero uncaught JavaScript console errors.
- [ ] The **Dual-Mode Phone Simulator** interactively toggles between Monitored Mode and Guardian Mode, updating the rendered screen UI and responding to user actions (e.g., tapping "Tôi vẫn ổn", simulating passive charging/unlock activity, or acknowledging an alert).
- [ ] The **State Machine & Signal Weight Visualizer** interactively displays and switches between the server monitoring states (`ACTIVE`, `CHECK_IN_REQUIRED`, `GRACE_PERIOD`, `ALERT_TRIGGERED`, `ACKNOWLEDGED`, `RESOLVED`, `PAUSED`) and explains the 3 Core Axioms (`Heartbeat 0.0` vs `Activity 0.2–0.8` vs `Check-in 1.0`).
- [ ] The **VI / EN Language Switcher** toggles all primary UI headings, navigation links, simulator labels, and section copy between Vietnamese and English cleanly without layout breakage.
- [ ] The **FAQ Accordion** and mobile responsive navigation menu open/close smoothly on click/tap.

### Layout, Accessibility & Integrity Verification
- [ ] Responsive layout renders cleanly with zero horizontal overflow (`document.documentElement.scrollWidth <= window.innerWidth`) across both Mobile (`375x812`) and Desktop (`1440x900`) viewports.
- [ ] All copy strictly adheres to Evernear's Calm UX guidelines (no sensationalist or alarming medical/death phrasing; risk scoring clearly presented as non-diagnostic operational prioritization).
- [ ] Existing backend (`backend/`) and mobile (`mobile/`) codebases remain untouched and clean (`git status` shows changes confined to `landing/` or documentation artifacts).

## 2026-10-16T02:58:30Z

Redesign the entire Carely (Evernear) Flutter application UI to match the clean Coral-Red and Pure White UI kit style shown in the reference image, then overhaul the Landing Page layout and visual theme across both the static web landing (`landing/`) and the Flutter web landing screen (`mobile/lib/features/landing/landing_screen.dart`). All existing product functionality, multi-language support (36 languages), and existing automated test suites must remain fully functional.

Working directory: /home/tnuc/project/Carely
Integrity mode: development

Reference image: /home/tnuc/.gemini/antigravity/brain/db91d643-8040-4c45-927a-bf2ef1047eeb/.user_uploaded/media_1792119071715.png

## Requirements

### R1. Flutter App UI & Theme Redesign (`mobile/`)
Redesign the Flutter app's theme, color palette, shared widgets, and all feature screens (Auth/Login/Register, Dashboard — Monitored & Monitor/Guardian views, Check-in, Incidents List & Detail, Devices, Monitoring Settings, QR Pairing/Scanner, and Account/Language Settings) to match the visual aesthetic of the reference image:
- **Color Palette**: Transition from the current forest-green/teal palette to the reference image's vibrant Coral-Red primary palette (primary coral/red `#FF5252` / `#F25252`, deep coral `#E53935`, soft blush/coral tint `#FFECEC` / `#FFF0F3` for icon badges and highlights) paired with pure white surfaces (`#FFFFFF`), soft cool-grey input/background fills (`#F5F6F8` / `#F8F9FB`), and crisp dark charcoal typography (`#1E2022` primary, `#6C757D` secondary).
- **Component & Layout Style**: Use pill-shaped (`StadiumBorder` / full-rounded) primary CTA buttons in Coral-Red with soft red drop shadows, borderless or subtle-bordered light-grey rounded input fields with prefix icons, clean white elevated cards and bottom-sheet-style panels with generous whitespace, circular coral-tinted icon badges, and a clean bottom/top navigation treatment matching the reference UI kit.
- **Functional & Test Preservation**: Preserve all existing state management, routing, localization keys, accessibility semantics, and interactive widgets so all existing Flutter unit and widget tests pass without regression.

### R2. Landing Page Layout & Theme Overhaul (`landing/` & `mobile/lib/features/landing/`)
After completing the App UI redesign, redesign the layout and visual styling of the Landing Page (both the static site in `landing/` and the Flutter landing screen in `mobile/lib/features/landing/landing_screen.dart`, plus any synced assets in `mobile/web/site/`):
- **Visual & Brand Alignment**: Synchronize the landing page color system and typography with the new Coral-Red & Pure White app aesthetic (replacing the old teal/emerald theme variables and hardcoded colors across HTML, CSS, SVG/mockup illustrations, and Flutter landing widgets).
- **Modernized Layout**: Restructure the landing page layout (Hero section, interactive phone mockups / app screens showcase, feature Bento/cards, step-by-step workflow, Google/Apple trust sections, FAQ, and footer) to showcase the newly redesigned Coral-Red & White app screens with clean card hierarchy, balanced whitespace, and responsive mobile/desktop breakpoints.
- **Legal & Auxiliary Pages**: Ensure `/privacy`, `/terms`, and `/delete-account` pages (both static HTML and `SitePageType` views in Flutter) reflect the updated Coral-Red & White design language and navigation layout.

### R3. Verification Resources & Non-Regression
Use and maintain compatibility with the repository's existing test suites:
- Flutter static analysis and test suite in `mobile/` (`flutter analyze` and `flutter test`).
- Landing page automated verification scripts in `landing/test/` (updating any theme-color assertions in tests if they explicitly check for old hex codes, while keeping all structural, i18n 36-language, interactive, and zero-overflow checks strictly passing).

## Acceptance Criteria

### Flutter Application (`mobile/`)
- [ ] `AppColors` and `ThemeData` in `mobile/lib/` use the new Coral-Red (`#FF5252` / `#F25252`) and Pure White (`#FFFFFF`) / Soft Grey (`#F5F6F8`) design system with zero remaining forest-green (`#2E7D32`) primary brand surfaces.
- [ ] All feature screens (Auth, Dashboard Monitor & Monitored views, Check-in, Incidents, Devices, Monitoring Settings, Pairing, Settings) are updated to match the reference UI kit's layout patterns (pill CTA buttons, soft grey rounded inputs, circular coral badges, clean floating/card containers).
- [ ] `flutter analyze` in `mobile/` completes with 0 errors and 0 warnings.
- [ ] `flutter test` in `mobile/` passes 100% of unit and widget tests, including rendering and overflow tests at mobile viewports.

### Landing Page (`landing/` & `mobile/lib/features/landing/`)
- [ ] Both `landing/index.html` (+ `landing/site/evernear.css`, `privacy.html`, `terms.html`, `delete-account.html`, `mobile/web/site/`) and `mobile/lib/features/landing/landing_screen.dart` feature a redesigned layout and Coral-Red & White visual theme matching the reference image.
- [ ] Interactive phone mockups and screen previews on the landing page accurately reflect the new Coral-Red & White app UI.
- [ ] Zero horizontal overflow (`scrollWidth <= clientWidth`) on both mobile (`375x812`) and desktop (`1440x900`) viewports across all landing pages and all 36 supported languages.
- [ ] All automated E2E and stress tests in `landing/test/` pass with 0 failures and 0 HTTP 404 or console errors.

## 2026-10-16T07:56:17Z

Redesign and update 100% of the Evenear Flutter mobile application UI to strictly match all 22 screens, brand identity, typography, Vietnamese copywriting, iconography, custom illustrations, and Material 3 color palette shown in `/home/tnuc/.gemini/antigravity/brain/db91d643-8040-4c45-927a-bf2ef1047eeb/.user_uploaded/media_1792137128085.jpg`, while preserving existing Provider/API functionality and ensuring 100% test pass rate.

Working directory: /home/tnuc/project/Carely/mobile
Integrity mode: development

Reference design image: `/home/tnuc/.gemini/antigravity/brain/db91d643-8040-4c45-927a-bf2ef1047eeb/.user_uploaded/media_1792137128085.jpg`

## Requirements

### R1. Brand Identity, Material 3 Palette & Custom Illustrations
Implement the exact Evenear Material 3 visual language shown in the reference design sheet header and brand card:
- **Color Palette**: Primary Forest Green (`#1E5A46` / `#2D6A4F`), Secondary Sage Green (`#68A67D` / `#73A982`), Mint Teal Accent (`#52B788` / `#58B498`), Neutral Stone (`#D5D6D0` / `#D8D6CE`), Soft Sage Surface (`#EAECE9` / `#F4F6F3`), Alert Coral (`#D9534F`) & Alert Surface (`#FDECEA`).
- **Brand Mark & Illustrations**: Green Heart + White Cross leaf logo (`Evenear`), custom vector illustrations matching the reference artwork (elderly couple sitting on park bench under trees for Onboarding 1 & Brand card, woman holding phone in park for Onboarding 2, privacy camera/mic/GPS badges for Onboarding 6, sunrise hills with checkmark for Onboarding 8, and soft leaf/cloud checkmark for Check-in confirmation).
- **4 Core Value Badges**: `"Không camera / Không microphone / Không theo dõi GPS liên tục"`, `"Bảo vệ quyền riêng tư / Của bạn và người thân"`, `"Tiết kiệm pin / Hoạt động hiệu quả trên nền tảng di động"`, `"Thông báo kịp thời / Khi có bất thường"`.

### R2. Section 1 — Onboarding & Xác thực (8 Screens)
Implement all 8 screens in Section 1 to match the reference design 100% in layout, copywriting, and navigation:
1. **Onboarding 1 (Giới thiệu ứng dụng)**: Evenear Heart+Cross logo, `"Evenear"`, `"Đồng hành & Bảo vệ bình an cho người thân"`, elderly couple on bench illustration, primary pill button `"Bắt đầu"`, 3-dot page indicator (`● ○ ○`).
2. **Onboarding 2 (Tính năng chính)**: Title `"Luôn bên cạnh khi bạn cần"`, subtitle `"Theo dõi hoạt động thông minh, nhắc nhở kịp thời và kết nối người thân trong những lúc quan trọng."`, illustration of woman holding smartphone, primary pill button `"Tiếp tục"`, 3-dot indicator (`○ ● ○`).
3. **Đăng nhập**: Title `"Chào mừng trở lại!"`, subtitle `"Đăng nhập để tiếp tục"`, input fields `"Email hoặc số điện thoại"` and `"Mật khẩu"`, checkbox `"Nhớ tài khoản"`, link `"Quên mật khẩu?"`, primary pill button `"Đăng nhập"`, divider `"hoặc"`, social buttons `"Đăng nhập với Google"` and `"Đăng nhập với Apple"`, bottom prompt `"Chưa có tài khoản? Đăng ký"`.
4. **Đăng ký**: Title `"Tạo tài khoản"`, subtitle `"Bắt đầu hành trình an toàn cùng Evenear"`, input fields `"Họ và tên"`, `"Email hoặc số điện thoại"`, `"Mật khẩu"`, `"Xác nhận mật khẩu"`, primary pill button `"Đăng ký"`, bottom prompt `"Đã có tài khoản? Đăng nhập"`.
5. **Hồ sơ cá nhân**: AppBar `"← Hồ sơ của tôi"` with edit action icon, circular avatar with `"Nguyễn Văn An"` and `"+84 912 345 678"`, 5 list tiles (`"Thông tin cá nhân"`, `"Người thân & người được ủy quyền"`, `"Quản lý thiết bị"`, `"Quyền riêng tư & bảo mật"`, `"Cài đặt"`), bottom navigation (`Trang chủ`, `Hoạt động`, `Thiết bị`, `Cài đặt`).
6. **Giải thích quyền riêng tư**: Heart+Cross logo, title `"Quyền riêng tư của bạn là ưu tiên hàng đầu"`, card with `"Không camera / Không microphone"` and `"Không theo dõi GPS liên tục"`, explanation `"Chúng tôi chỉ thu thập vị trí một lần khi bạn chủ động xác nhận hoặc có sự cố xảy ra (nếu bạn đồng ý)."`, primary pill button `"Tôi đã hiểu"`.
7. **Cấp quyền**: Title `"Cấp quyền cần thiết"`, subtitle `"Để hoạt động chính xác và tiết kiệm pin, Evenear cần một số quyền cơ bản."`, 3 switch cards (`"Thông báo"` — `"Gửi cảnh báo và nhắc nhở"`, `"Vị trí (chỉ khi cần)"` — `"Khi xác nhận hoặc có sự cố"`, `"Hoạt động & sức khỏe"` — `"Theo dõi hoạt động, bước chân"`), primary pill button `"Tiếp tục"`.
8. **Đăng ký thành công**: Sunrise & hills with green checkmark illustration, title `"Sẵn sàng!"`, subtitle `"Bạn đã hoàn tất đăng ký. Bắt đầu khám phá Evenear nhé!"`, primary pill button `"Bắt đầu"`.

### R3. Section 2 — Monitored Mode: Tôi được bảo vệ (5 Screens)
Implement all 5 screens in Section 2 to match the reference design 100%:
1. **Trang chủ (Monitored Mode)**: Header `"Xin chào, An 👋"` and subtitle `"Bạn đang được bảo vệ"` with bell & settings icons; large circular center button with green shield+plus icon, `"Tôi vẫn ổn"`, `"Nhấn để xác nhận"`; 2 side-by-side status cards (`"Lần hoạt động gần nhất"` → `"Hôm nay 08:42"` / `"(Đã đồng bộ)"` and `"Pin thiết bị"` → `"78%"`); bottom card `"Lịch kiểm tra"` (`"09:00 • 12:00 • 15:00 • 18:00"`); bottom navigation (`Trang chủ`, `Hoạt động`, `Thiết bị`, `Cài đặt`).
2. **Xác nhận "Tôi vẫn ổn"**: AppBar `"← Xác nhận an toàn"`, soft cloud/leaf illustration with green checkmark circle, `"Tuyệt vời!\nBạn vẫn ổn!"`, `"Thời gian xác nhận\n08:42 • 15/10/2025"`, primary pill button `"Hoàn tất"`.
3. **Lịch sử hoạt động**: AppBar `"← Hoạt động gần đây"`, section header `"Hôm nay"`, 4 activity cards (`"Mở ứng dụng"` `15/10/2025 • 08:30`, `"Thay đổi trạng thái sạc"` `15/10/2025 • 07:50`, `"Mở khóa thiết bị"` `15/10/2025 • 07:35`, `"Bước chân"` `15/10/2025 • 07:20`).
4. **Quản lý thiết bị**: AppBar `"← Thiết bị của bạn"`, 3 device cards with device icons & battery status (`"iPhone 15 Pro"` `Hoạt động • 78%`, `"iPad (gia đình)"` `Hoạt động • 62%`, `"Samsung Galaxy S24"` `Hoạt động • 45%`), and `"+ Thêm thiết bị"` card/button.
5. **Cài đặt giám sát**: AppBar `"← Cài đặt giám sát"`, cards for `"Khung giờ hoạt động"` (`"07:00 – 22:00"`, `"Hàng ngày"`), `"Nhắc nhở kiểm tra"` (`"3 lần / ngày"`, time chips `"09:00"`, `"15:00"`, `"20:00"`), switch card `"Chế độ tạm dừng"` (`"Tạm dừng khi nghỉ du lịch"`), switch card `"Thông báo pin yếu"` (`"Khi pin < 20%"`).

### R4. Section 3 — Guardian Mode: Theo dõi người thân (3 Screens)
Implement all 3 screens in Section 3 to match the reference design 100%:
1. **Danh sách người thân**: Header `"Danh sách người thân"` with action icon, 4 relative cards with avatars (`"Mẹ"` — `"Đang được bảo vệ"` / `"Lần xác nhận: 08:32"`, `"Bố"` — `"Đang được bảo vệ"` / `"Lần xác nhận: 07:50"`, `"Em gái"` — `"Đang được bảo vệ"` / `"Lần xác nhận: 08:10"`, `"Chú Nam"` — coral/red `"Cần kiểm tra"` / `"Chưa nhận được xác nhận"`), bottom navigation (`Trang chủ`, `Người thân`, `Thông báo`, `Cài đặt`).
2. **Chi tiết người thân**: AppBar `"← Chi tiết người thân"`, profile summary card with avatar `"Mẹ"`, `"Đang được bảo vệ"`, and green pill button `"📞 Liên hệ"`; 3 tabs (`"Thông tin"`, `"Hoạt động"`, `"Thiết bị"`); 3 detail cards (`"Lần xác nhận gần nhất"` `15/10/2025 • 08:32`, `"Vị trí gần nhất"` `Hà Nội (chỉ khi cần)`, `"Thiết bị"` `iPhone 15 Pro`).
3. **Dòng thời gian sự kiện**: AppBar `"← Thông báo & sự kiện"` with `+` action, 4 filter pills (`"Tất cả"`, `"An toàn"`, `"Cảnh báo"`, `"Xử lý"`), 4 event cards (`"Mẹ đã xác nhận an toàn"` `08:32 • 15/10/2025`, `"Bố thay đổi trạng thái sạc"` `07:50 • 15/10/2025`, coral alert card `"Không nhận được xác nhận từ Em gái"` `18:20 • 14/10/2025`, `"Đã gửi thông báo cho người được ủy quyền"` `18:25 • 14/10/2025`).

### R5. Section 4 (Sự kiện & xử lý sự cố — 3 Screens) & Section 5 (Cài đặt & Tùy chỉnh — 4 Screens)
Implement all 7 screens across Sections 4 and 5 to match the reference design 100%:
1. **4.1 Thông báo cảnh báo (`Cảnh báo`)**: Coral alert card (`"Không nhận được xác nhận trong thời gian dự kiến"`, `"Người: Em gái"`, `"Thời gian: 18:20 • 14/10/2025"`), primary pill button `"Xem chi tiết"`, outlined pill button `"Tôi đã liên hệ được"`.
2. **4.2 Chi tiết sự cố**: AppBar `"← Chi tiết sự cố"`, red dot header `"Không nhận được xác nhận"`, vertical timeline (`"18:20 Hết thời gian kiểm tra"`, `"18:21 Gửi thông báo cho người được ủy quyền"`, `"18:25 Đã gửi SMS / Telegram"`), location card (`"Vị trí gần nhất (nếu có)"`, `"Hà Nội, Việt Nam"`), primary pill button `"Xác nhận đã liên hệ"`.
3. **4.3 Khôi phục trạng thái (`Xử lý sự cố`)**: AppBar `"← Xử lý sự cố"`, 2 checked item cards (`"Đã liên hệ với người thân"` `14/10/2025 • 18:45`, `"Đã xác nhận an toàn"` `14/10/2025 • 18:52`), soft green status card (`"Đã khôi phục trạng thái"`, `"Hiện tại: An toàn"`), primary pill button `"Quay lại trang chủ"`.
4. **5.1 Menu cài đặt (`Cài đặt`)**: 7 settings rows (`"Thông tin cá nhân"`, `"Người thân & ủy quyền"`, `"Giám sát & nhắc nhở"`, `"Thiết bị"`, `"Quyền riêng tư & bảo mật"`, `"Thông báo"`, `"Ngôn ngữ"`).
5. **5.2 Bảo mật & quyền riêng tư (`← Quyền riêng tư & bảo mật`)**: 4 cards (`"Dữ liệu vị trí"` — `"Chỉ khi cần (chọn lọc)"`, `"Quyền truy cập"` — `"Camera / Microphone (không sử dụng)"`, `"Sao lưu & khôi phục"` — `"Lưu trữ an toàn"`, `"Xóa tài khoản"` — `"Xóa dữ liệu cá nhân"`).
6. **5.3 Chọn ngôn ngữ (`← Ngôn ngữ`)**: 4 language rows (`"Tiếng Việt"` selected with green check, `"English"`, `"日本語"`, `"中文"`).
7. **5.4 Cài đặt thông báo (`← Thông báo +`)**: 4 switch rows (`"Thông báo đẩy"`, `"Cảnh báo khẩn cấp"`, `"Nhắc nhở kiểm tra"`, `"Cập nhật từ hệ thống"`), section `"Âm thanh"` with row `"Nhạc chuông"`.

## Acceptance Criteria

### Static Analysis & Existing Test Suite
- [ ] `flutter analyze` in `/home/tnuc/project/Carely/mobile` exits with code 0 and reports `No issues found!`.
- [ ] All existing and updated tests in `/home/tnuc/project/Carely/mobile/test/` pass (`flutter test` exits with code 0, 0 failures).

### Objective 22-Screen Design Fidelity Verification
- [ ] A dedicated automated widget test suite verifies that all 22 screens from Sections 1–5 render without layout overflow (`RenderFlex overflowed`) at standard mobile viewport (`375x812`) and contain the exact Vietnamese titles, subtitles, card labels, buttons, and navigation items specified in R1–R5.
- [ ] Independent visual/code audit against `/home/tnuc/.gemini/antigravity/brain/db91d643-8040-4c45-927a-bf2ef1047eeb/.user_uploaded/media_1792137128085.jpg` confirms 100% alignment across all 22 screens (color tokens, pill buttons, illustrations, card hierarchy, and bottom navigation bars).

## 2026-10-19T02:20:55Z

Hoàn thiện hệ thống thực tế (production-ready end-to-end) cho ứng dụng Evenear trên cả Flutter App (`mobile/`) và NestJS Backend (`backend/`): loại bỏ hoàn toàn dữ liệu giả (fake/showcase data) sau khi đăng ký và trên tất cả màn hình, đồng bộ chức năng cài đặt thời gian giám sát và kiểm chứng cơ chế tuân thủ lịch trình cảnh báo thực tế, bổ sung tính năng xóa/dọn sạch thông báo (clear notifications), và hoàn thiện luồng ghép đôi hai chiều (tạo mã mời & quét mã QR / nhập mã).

Working directory: /home/tnuc/project/Carely
Integrity mode: development

## Requirements

### R1. Cài đặt thời gian giám sát & Tuân thủ lịch trình cảnh báo (End-to-End Schedule & Alert Enforcement)
- Đảm bảo chức năng cài đặt thời gian kiểm tra hàng ngày, ngưỡng bất động (`inactivityThresholdMinutes`), thời gian ân hạn (`checkInGracePeriodMinutes`, `escalationGracePeriodMinutes`) và khung giờ nghỉ ngơi / ngủ (`scheduleWindows` / Quiet Hours) hoạt động thực tế end-to-end giữa Flutter App và NestJS Backend.
- Khi người dùng thay đổi và lưu cài đặt thời gian (kể cả khi cấu hình cho bản thân hoặc cho mối quan hệ người thân), dữ liệu phải được lưu bền vững và phản ánh ngay lập tức trên trang chủ và màn hình chi tiết.
- Đảm bảo bộ máy đánh giá trạng thái giám sát (Safety State Machine / Scheduler ở backend và hiển thị trạng thái ở frontend) tuân thủ chính xác khung giờ đã cài đặt: đóng băng bộ đếm trong khung giờ ngủ/tạm dừng, chuyển sang nhắc nhở kiểm tra (`CHECK_IN_REQUIRED` / `WARNING`) và phát cảnh báo (`ALERT_TRIGGERED` / `ESCALATED`) đúng theo ngưỡng thời gian đã cấu hình; hiển thị rõ trạng thái tuân thủ lịch trình và mốc kiểm tra tiếp theo trên UI.

### R2. Xóa / Dọn sạch thông báo (Clear Notifications End-to-End)
- Bổ sung chức năng xóa từng thông báo và xóa toàn bộ thông báo ("Xóa tất cả" / "Clear thông báo") trên màn hình Thông báo / Dòng thời gian sự kiện (`IncidentsListScreen`), đồng bộ với `IncidentsProvider`, `DashboardProvider` và Backend API.
- Khi người dùng xóa thông báo, danh sách thông báo và số lượng badge chưa đọc trên thanh điều hướng phải cập nhật ngay lập tức, không tự động xuất hiện lại dữ liệu giả.

### R3. Loại bỏ toàn bộ dữ liệu giả trên mọi màn hình (Remove All Fake / Hardcoded Showcase Data)
- Xóa bỏ hoàn toàn các dữ liệu mẫu cố định (hardcoded showcase/demo fallback như tên giả `"Nguyễn Văn An"`, `"Mẹ"`, `"Bố"`, `"Em gái"`, `"Chú Nam"`, số điện thoại giả `"+84 912 345 678"`, pin giả `"78%"`, thiết bị giả `"iPhone 15 Pro"`, `"iPad (gia đình)"`, `"Samsung Galaxy S24"`, lịch sử hoạt động giả, sự cố giả, và mã QR mẫu tĩnh) trên tất cả các màn hình Flutter (`MonitoredView`, `MonitorView`, `RelativeDetailScreen`, `RecentActivitiesScreen`, `DevicesScreen`, `MonitoringSettingsScreen`, `IncidentsListScreen`, `IncidentDetailScreen`, `AccountSettingsScreen`, `QrInviteScreen`).
- Mọi màn hình chỉ hiển thị dữ liệu thực tế của tài khoản đang đăng nhập từ Backend / Provider / thiết bị thực. Khi danh sách rỗng (chưa có người thân, chưa có hoạt động, chưa có thiết bị hoặc chưa có cảnh báo), hiển thị giao diện trạng thái trống (Empty State) chuẩn thiết kế cùng nút hành động (CTA) phù hợp.

### R4. Hoàn thiện luồng Tạo mã & Quét mã ghép đôi hai chiều (QR Invite & QR Scanner Flow)
- Trên màn hình Người thân & Ủy quyền (`QrInviteScreen`), màn hình Theo dõi người thân (`MonitorView`) và Cài đặt / Hồ sơ, cung cấp đầy đủ cả 2 chiều kết nối rõ ràng, dễ thao tác:
  1. **Tạo mã mời / Mã QR thực tế** (gọi API tạo mã mời từ backend, hiển thị mã QR thực và mã chữ số, sao chép & chia sẻ).
  2. **Quét mã QR / Nhập mã ghép đôi** (nút chuyển trực tiếp hoặc tab/nút mở `QrScannerScreen` và ô nhập mã ghép đôi thủ công để chấp nhận kết nối với người thân).

### R5. Không tạo dữ liệu giả sau khi Đăng ký tài khoản mới (Clean Registration State)
- Đảm bảo sau khi đăng ký tài khoản mới (`RegisterScreen` -> `OnboardingScreen` / `DashboardScreen`) trên cả Backend lẫn Frontend, tài khoản bắt đầu ở trạng thái hoàn toàn sạch (clean state): hiển thị đúng họ tên, email, số điện thoại của người dùng vừa đăng ký; không tự động tạo hay hiển thị bất kỳ người thân giả, thiết bị giả, lịch sử điểm danh giả hay cảnh báo giả nào.

## Verification Resources

- Flutter test suite: `/home/tnuc/project/Carely/mobile/test/` (chạy bằng `flutter test` và `flutter analyze` tại `/home/tnuc/project/Carely/mobile`).
- Backend test suite: `/home/tnuc/project/Carely/backend/` (chạy bằng `npm test` và `npm run build` tại `/home/tnuc/project/Carely/backend`).
- Cập nhật các bài test hiện tại trong `/home/tnuc/project/Carely/mobile/test/` vốn đang assert các chuỗi dữ liệu mẫu cố định (như `'Mẹ'`, `'Bố'`, `'Chú Nam'`, `'iPhone 15 Pro'`) để kiểm tra đúng hành vi dữ liệu động từ Provider/mock data và trạng thái Empty State thực tế.

## Acceptance Criteria

### Data Integrity & Clean Registration (R3, R5)
- [ ] Không còn bất kỳ danh sách `_showcaseRelatives`, `_showcaseActivities`, `_showcaseDevices`, `_defaultAlerts` hay tên/số điện thoại/pin giả cố định nào hiển thị khi người dùng mới đăng ký hoặc khi dữ liệu từ API trả về rỗng.
- [ ] Đăng ký tài khoản mới hiển thị đúng thông tin hồ sơ vừa đăng ký và hiển thị Empty State sạch sẽ trên các tab Trang chủ, Người thân, Thông báo và Thiết bị.

### Schedule & Alert Timing Enforcement (R1)
- [ ] Thay đổi và lưu cài đặt thời gian kiểm tra / ngưỡng bất động / khung giờ ngủ trên `MonitoringSettingsScreen` gọi API lưu thành công, cập nhật state và hiển thị đúng khung giờ mới trên `MonitoredView` / `MonitorView`.
- [ ] Có bài kiểm thử tự động xác minh logic đánh giá thời gian cảnh báo tuân thủ đúng ngưỡng bất động (`inactivityThresholdMinutes`) và khung giờ nghỉ ngơi (`scheduleWindows` / Quiet Hours).

### Clear Notifications (R2)
- [ ] Màn hình Thông báo (`IncidentsListScreen`) có chức năng xóa thông báo (xóa từng mục và xóa tất cả "Xóa tất cả"), xóa sạch danh sách trên UI/Provider/Backend và đưa badge thông báo về `0`.

### Two-Way QR Invite & Scan Flow (R4)
- [ ] Từ cả màn hình Người thân (`MonitorView`) lẫn màn hình Ghép đôi (`QrInviteScreen`), người dùng đều có thể vừa **Tạo mã QR** vừa chuyển sang **Quét mã QR / Nhập mã ghép đôi** (`QrScannerScreen`) và hoàn tất ghép đôi thành công.

### Automated Verification & Build Health
- [ ] `flutter analyze` trong `/home/tnuc/project/Carely/mobile` đạt 0 lỗi/cảnh báo.
- [ ] Toàn bộ test suite trong `/home/tnuc/project/Carely/mobile/test/` (`flutter test`) và `/home/tnuc/project/Carely/backend` (`npm test`) đều PASS 100%.




## 2026-10-19T06:30:07Z

Hoàn thiện hệ thống đa ngôn ngữ (i18n/l10n) toàn diện và đồng bộ trạng thái ngôn ngữ xuyên suốt trước & sau khi đăng nhập cho ứng dụng Evenear trên Flutter App (`mobile/`) và NestJS Backend (`backend/`).

Working directory: /home/tnuc/project/Carely
Integrity mode: development

## Requirements

### R1. Rà soát & Dịch triệt để 100% từ/cụm từ tiếng Việt còn cứng (Zero Hardcoded Vietnamese Strings Across Entire App)
- Quét toàn bộ mã nguồn Flutter (`mobile/lib/features/**`, `mobile/lib/core/widgets/**`, `mobile/lib/core/models/**`, `mobile/lib/core/constants/**`, `mobile/lib/core/services/**`) để tìm và thay thế **mọi** chuỗi tiếng Việt còn cứng (hardcoded literals hoặc gọi trực tiếp `AppStrings.*` tĩnh thay vì `context.tr(...)` / `AppLocalizations.of(context).translate(...)`), bao gồm nhưng không giới hạn ở:
  - Các màn hình xác thực & khởi tạo: `LoginScreen`, `RegisterScreen`, `OnboardingScreen`.
  - Các màn hình chính & chi tiết: `DashboardScreen`, `MonitoredView`, `MonitorView`, `RelativeDetailScreen`, `RecentActivitiesScreen`, `DevicesScreen`, `MonitoringSettingsScreen` (bao gồm toàn bộ phần cài đặt lịch trình, giờ nghỉ ngơi, cảnh báo ở nửa dưới file), `IncidentsListScreen`, `IncidentDetailScreen`, `QrInviteScreen`, `QrScannerScreen`, `AccountSettingsScreen`.
  - Các hộp thoại (AlertDialog / BottomSheet), thông báo lỗi form validation, `SnackBar`, tooltip, badge trạng thái, nhãn thứ trong tuần (`ScheduleWindow.dayNameShort`), đơn vị thời gian ("phút", "giờ", "ngày trước", "Vừa xong"), và các widget dùng chung (`ActiveAccountChip`, `HoldToSosButton`, `SafetyStatusBadge`, `OfflineBanner`, v.v.).
- Đảm bảo toàn bộ các khóa dịch (translation keys) mới và hiện có trong `mobile/lib/core/i18n/catalogs/` được dịch đầy đủ và chính xác sang tiếng Anh (`en_catalog.dart`) và toàn bộ các ngôn ngữ được hỗ trợ (`vi`, `en`, `ja`, `zh`, `ko`, `fr`, `de`, `es`, `pt`, `ru`, `ar`, `hi`, `th`, `id`, v.v.), **tuyệt đối không để bất kỳ khóa nào ở ngôn ngữ khác bị rơi về (fallback) hiển thị chữ tiếng Việt** khi người dùng đang chọn ngôn ngữ khác tiếng Việt.

### R2. Đồng bộ hóa ngôn ngữ xuyên suốt giữa màn hình Đăng ký / Login và khi đã Login (Pre-Auth & Post-Auth Language Synchronization)
- Cung cấp bộ chọn ngôn ngữ trực quan, thống nhất trên cả màn hình `LoginScreen`, `RegisterScreen` và `OnboardingScreen` (cùng chung trạng thái từ `LocaleProvider` và lưu bền vững vào `LocalStorage`).
- Chính sách đồng bộ ưu tiên: **Giữ ngôn ngữ người dùng đang chọn ở màn hình Login/Register và đồng bộ luôn lên tài khoản sau khi đăng nhập/đăng ký**:
  1. Khi người dùng chọn ngôn ngữ ở `LoginScreen` hoặc `RegisterScreen`, toàn bộ giao diện `LoginScreen`, `RegisterScreen`, `OnboardingScreen` chuyển đổi ngôn ngữ ngay lập tức và lưu vào `LocaleProvider` / `LocalStorage`.
  2. Khi thực hiện **Đăng ký (`register`)**: ngôn ngữ đang chọn trên `LocaleProvider` được truyền thẳng vào `preferredLanguage` khi đăng ký và giữ nguyên xuyên suốt khi vào `OnboardingScreen` / `DashboardScreen` (không bị reset về `'vi'`).
  3. Khi thực hiện **Đăng nhập (`login`)**: giữ nguyên ngôn ngữ người dùng đang chọn ở màn hình Login/Register trên `LocaleProvider`, đồng thời đồng bộ cập nhật `preferredLanguage` đó lên `AuthProvider` và Backend (`PATCH /users/me` nếu khác với giá trị cũ trên server) để khi vào `DashboardScreen`, `AccountSettingsScreen` và toàn bộ ứng dụng đều thống nhất cùng một ngôn ngữ, không bị nhảy ngược về tiếng Việt.
  4. Khi đổi ngôn ngữ ở `AccountSettingsScreen` hoặc trong ứng dụng sau khi đã đăng nhập: cập nhật đồng thời `LocaleProvider`, `LocalStorage`, `AuthProvider.user.preferredLanguage` và Backend API, để khi đăng xuất (`logout`) ra màn hình `LoginScreen` / `RegisterScreen` vẫn giữ nguyên ngôn ngữ đó.

## Verification Resources

- Flutter static analysis & unit/widget tests: chạy `flutter analyze` và `flutter test` tại `/home/tnuc/project/Carely/mobile`.
- Kiểm thử tự động kiểm tra không còn chuỗi tiếng Việt có dấu cứng trong các file UI (`mobile/lib/features/**` và `mobile/lib/core/widgets/**`) và kiểm tra tính đầy đủ 100% của tất cả các khóa trong `enCatalog` và các catalog quốc tế so với `viCatalog` (không có giá trị tiếng Việt nào lọt vào catalog ngoại ngữ).
- Kiểm thử tự động luồng đồng bộ ngôn ngữ: chọn tiếng Anh (`en`) ở `LoginScreen` -> chuyển sang `RegisterScreen` -> đăng ký / đăng nhập -> vào `DashboardScreen` -> kiểm tra toàn bộ UI hiển thị tiếng Anh và `LocaleProvider` / `AuthProvider` giữ nguyên `en`.

## Acceptance Criteria

### Complete Translation & Zero Hardcoded Vietnamese (R1)
- [ ] Khi chuyển ngôn ngữ sang Tiếng Anh (`en`) hoặc ngôn ngữ quốc tế bất kỳ, 100% văn bản trên tất cả các màn hình, nút bấm, tab điều hướng, dialog, snackbar, empty state, và form validation đều hiển thị đúng ngôn ngữ đã chọn, không còn bất kỳ từ/cụm từ tiếng Việt nào sót lại.
- [ ] `enCatalog` và các danh mục ngôn ngữ trong `mobile/lib/core/i18n/catalogs/` phủ 100% các khóa của `viCatalog`, không có khóa nào trả về chuỗi tiếng Việt khi đang ở locale khác `vi`.

### Pre-Auth & Post-Auth Language Synchronization (R2)
- [ ] `LoginScreen`, `RegisterScreen` và `OnboardingScreen` đều có bộ chọn ngôn ngữ và hiển thị đồng bộ cùng một ngôn ngữ theo `LocaleProvider`.
- [ ] Chọn ngôn ngữ ở `LoginScreen` / `RegisterScreen` rồi thực hiện Đăng nhập hoặc Đăng ký sẽ giữ nguyên ngôn ngữ đó khi vào trong app (`DashboardScreen`) và đồng bộ `preferredLanguage` lên tài khoản.
- [ ] Đổi ngôn ngữ khi đã đăng nhập rồi Đăng xuất (`logout`) ra màn hình `LoginScreen` vẫn giữ nguyên ngôn ngữ đã chọn.

### Automated Verification & Build Health
- [ ] Có unit/widget tests tự động kiểm chứng: (1) độ phủ 100% khóa dịch giữa `viCatalog` và `enCatalog`, (2) render các màn hình ở locale `en` không xuất hiện ký tự tiếng Việt, và (3) đồng bộ ngôn ngữ xuyên suốt Login -> Register -> Dashboard -> Logout.
- [ ] `flutter analyze` đạt 0 issues và toàn bộ `flutter test` PASS 100%.


## 2026-10-19T09:22:00Z

Người dùng vừa yêu cầu bổ sung trực tiếp:
"hiện tại chỉ có tiếng anh và tiếng việt là hoàn thiện, những ngôn ngữ khác vẫn chưa hoàn thiện. hoàn thiện nốt toàn bộ ngôn ngữ đi"

Yêu cầu bắt buộc:
1. Không chỉ `vi_catalog.dart` và `en_catalog.dart` có đủ 721 khóa dịch, mà **TOÀN BỘ các file danh mục ngôn ngữ khác** trong `mobile/lib/core/i18n/catalogs/*_catalog.dart` (tất cả 58+ ngôn ngữ hiện có trong thư mục `catalogs/` như `ja`, `zh`, `ko`, `fr`, `de`, `es`, `pt`, `ru`, `ar`, `hi`, `th`, `id`, `it`, `nl`, `pl`, `tr`, `uk`, `cs`, `sv`, `da`, `fi`, `no`, `el`, `he`, `hu`, `ro`, `sk`, `bg`, `hr`, `sr`, `sl`, `et`, `lv`, `lt`, `ms`, `tl`, `my`, `km`, `lo`, `bn`, `ta`, `te`, `mr`, `ur`, `fa`, `sw`, `am`, `az`, `be`, `bs`, `ca`, `cy`, `eu`, `ga`, `gl`, `is`, `ka`, `kk`, `mn`, `ne`, `si`, `sq`, `uz`, v.v.) **phải được dịch và điền đầy đủ 100% toàn bộ 721 khóa dịch sang đúng ngôn ngữ bản địa của catalog đó** (không để thiếu khóa, không để rỗng, không dùng bản copy tiếng Việt và không chỉ dựa vào cơ chế fallback sang `enCatalog`).
2. Thêm bài kiểm thử tự động trong `catalog_parity_and_purity_test.dart` kiểm tra **tất cả các catalog trong `LocaleCatalogRegistry` / `catalogs.dart`** đều có đủ 100% số lượng khóa (721 keys) khớp 1-1 với `viCatalog` và `enCatalog`, không có giá trị rỗng và không chứa chuỗi tiếng Việt có dấu bị rò rỉ.
3. Chuyển tiếp ngay yêu cầu này cho Orchestrator hiện tại để triển khai Milestone mở rộng dịch đầy đủ toàn bộ các file `*_catalog.dart` trước khi kết thúc nhiệm vụ!

## 2026-10-20T05:40:25Z

Perform a comprehensive final production-readiness verification, live browser E2E testing, and bug-fixing/polishing pass across all three components of the Carely (Evenear) project (`backend/`, `mobile/`, and `landing/`) so the entire system is verified and ready for production delivery.

Working directory: /home/tnuc/project/Carely
Integrity mode: development

## Verification Resources

- Backend test suites: `backend/test/` (Vitest / Jest E2E and integration suites)
- Mobile test suites: `mobile/test/` (including `evenear_22_screens_verification_test.dart` and all unit/widget/adversarial tests)
- Landing page E2E test suite: `landing/test/run_e2e_tests.py`
- Project documentation & specs: `README.md`, `ARCHITECTURE.md`, `API.md`, `DATABASE.md`, `MONITORING_STATE_MACHINE.md`, `TEST_READY.md`

## Requirements

### R1. Backend & Infrastructure End-to-End Verification
Verify that PostgreSQL and Redis infrastructure, database migrations/schemas, and the NestJS backend (`backend/`) build cleanly and pass all unit, integration, and E2E tests without errors. Audit all API endpoints, state machine transitions (`ACTIVE`, `WARN`, `ESCALATING`, `ALERTED`, `RESOLVED`, `PAUSED`, etc.), authentication flows, WebSocket/realtime notifications, and rate-limiting/locking behaviors to ensure zero regressions or unhandled edge cases. Fix any defects found.

### R2. Flutter Application Full Verification & Live Browser Testing
Verify that the Flutter application (`mobile/`) passes static analysis (`flutter analyze`), passes the entire test suite in `mobile/test/`, and builds cleanly for Web (`flutter build web`). Serve the Flutter Web build alongside the live NestJS backend and verify core user journeys (Onboarding, Auth, Monitored Mode Check-in `"Tôi vẫn ổn"`, Guardian Mode monitoring, Incident management, Settings & Bilingual VI/EN switching) in a real headless browser with zero uncaught console or network errors. Fix any UI, state, or integration bugs discovered.

### R3. Landing Page Live Browser E2E Verification
Serve the Landing Page (`landing/`) and verify it in a real browser across desktop and mobile viewports, as well as running its automated E2E suite (`python3 landing/test/run_e2e_tests.py`). Confirm all assets load with HTTP 200, zero console/page errors occur, interactive simulators (Dual-Mode Phone Simulator, 8-State Monitoring Visualizer, FAQ accordion, mobile menu, and VI/EN bilingual toggle) work seamlessly, and all Calm UX copy guidelines are strictly respected.

### R4. Codebase Hygiene & Final Readiness Report
Ensure the repository is clean of stray temporary/broken artifacts, all documentation and readiness reports reflect the final verified state of the project, and a comprehensive final verification report is produced summarizing test results across Backend, Mobile/Flutter Web, and Landing Page.

## Acceptance Criteria

### Backend & Infrastructure (`backend/`)
- [ ] Backend TypeScript compilation and build (`npm run build`) succeed with 0 errors.
- [ ] 100% of backend unit and integration/E2E test suites in `backend/` pass against live PostgreSQL and Redis instances with exit code 0.
- [ ] Live HTTP health check and core API flows (register/login, device registration, heartbeat vs. activity vs. check-in `"Tôi vẫn ổn"`, guardian pairing, incident lifecycle) respond with expected status codes and payloads.

### Mobile & Flutter Web (`mobile/`)
- [ ] `flutter analyze` completes with 0 errors and 0 warnings.
- [ ] 100% of Flutter tests in `mobile/test/` (including `evenear_22_screens_verification_test.dart`) pass with exit code 0 and zero `RenderFlex` overflow errors.
- [ ] `flutter build web` succeeds with exit code 0, and loading the built web app in a real headless browser (Playwright/Chromium) renders the application and executes interactive user flows with 0 uncaught JS/console errors.

### Landing Page (`landing/`)
- [ ] `python3 landing/test/run_e2e_tests.py` passes 100% of Tier 1, Tier 2, and Tier 3 tests with exit code 0.
- [ ] Live browser inspection of `landing/` confirms 0 failed network requests (HTTP 404/500), 0 console errors, and working interactive simulators across both Vietnamese (`vi`) and English (`en`) locales.

### Project Completion & Hygiene
- [ ] `git status` shows no unintended leftover debug scripts, broken temp files, or uncommitted build noise, and final verification results are documented clearly.
