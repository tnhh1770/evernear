# Evernear E2E Test Infrastructure Documentation

## 1. Overview & Architecture

The Evernear E2E Test Suite (`landing/test/run_e2e_tests.py`) is an automated, opaque-box, browser-driven verification harness designed to rigorously test the **Evernear Calm UX Landing Page** (`landing/index.html`) against all requirements and acceptance criteria specified in `ORIGINAL_REQUEST.md` and `PROJECT.md`.

### Core Engineering Principles
- **Zero Heavy Test Dependencies**: Built using Python 3 stdlib (`http.server`, `urllib`, `asyncio`, `html.parser`, `subprocess`) combined with native Chrome DevTools Protocol (`websockets`) and headless Google Chrome. No NPM packages or Playwright installation required.
- **Authentic Headless Browser Execution**: Uses `google-chrome --headless=new` with isolated `--user-data-dir` and dynamic port allocation via `DevToolsActivePort`. Connects directly via WebSockets to Chrome's V8 engine to inspect real DOM layouts, computed styles, bounding rects, and console/runtime errors.
- **Strict Repository Isolation**: Confines all test files to `landing/test/` and `.agents/`. Strictly enforces that `backend/` and `mobile/` are untouched.
- **Progressive and Tiered Execution**: Allows running all tiers or targeted subsets (`--tier 1,4,5` or `--tier 2`) for rapid iterative verification.

---

## 2. Test Runner Commands

### Basic Invocation
```bash
# Run all 5 Tiers
python3 landing/test/run_e2e_tests.py

# Run specific Tier (e.g. Tier 1, or Tiers 1, 4, and 5)
python3 landing/test/run_e2e_tests.py --tier 1
python3 landing/test/run_e2e_tests.py --tier 1,4,5

# Fast failure mode (stop on first failure)
python3 landing/test/run_e2e_tests.py --bail

# Verbose output with detailed error traces and data dumps
python3 landing/test/run_e2e_tests.py --verbose

# Export JSON summary report
python3 landing/test/run_e2e_tests.py --json landing/test/e2e_report.json
```

---

## 3. Test Tier Breakdown

### Tier 1: Static & Local HTTP Serving
- **`test_t1_01_http_serving_index`**: Starts an ephemeral background HTTP server serving `landing/`, requests `http://127.0.0.1:<port>/index.html` and root `/`. Asserts HTTP 200, valid `<!DOCTYPE html>`, and non-empty content body (>1,000 bytes).
- **`test_t1_02_all_local_assets_200_zero_404s`**: Scrapes all local asset references (`<img>`, `<link>`, `<script>`, `<source>`) from HTML and queries each asset over HTTP. Asserts HTTP 200, non-zero file size, and exactly zero HTTP 404 responses.
- **`test_t1_03_js_syntax_and_console_errors`**: Validates inline script syntax via `node -c` (AST parsing) and runs Chrome headless to monitor `Runtime.consoleAPICalled` and `Runtime.exceptionThrown`. Asserts zero syntax errors and zero uncaught runtime console exceptions.

### Tier 2: Interactive Functional Testing of Widgets & DOM Manipulation
- **`test_t2_01_dual_mode_phone_simulator`**:
  - Validates `window.EvernearSimulator` interface contract (`switchMode`, `triggerCheckIn`, `triggerPassiveActivity`, `togglePause`).
  - Tests **Monitored Mode**: verifies tactile check-in ("Tôi vẫn ổn", Weight: 1.0), passive signals (charging [0.2], screen unlock [0.7], heartbeat [0.0]), and pause toggle (2h suspension).
  - Tests **Guardian Mode**: switches view, verifies family status card, 0–100 non-diagnostic risk score gauge, incident acknowledgement (`ACKNOWLEDGED`), incident resolve (`ACTIVE`), and QR pairing code preview (`CR-XXXXXX`).
- **`test_t2_02_8_state_monitoring_visualizer`**:
  - Validates `window.EvernearVisualizer` interface contract (`selectState`).
  - Steps through all 8 authoritative server states: `INITIALIZING`, `ACTIVE`, `CHECK_IN_REQUIRED`, `GRACE_PERIOD`, `ALERT_TRIGGERED`, `ACKNOWLEDGED`, `RESOLVED`, `PAUSED`.
  - Verifies DOM rendering of Signal Weight Matrix (Heartbeat 0.0 vs Activity 0.2–0.8 vs Check-in 1.0) and Composite Risk Score explainer (+30 inactivity, +30 missed check-in, +20 device offline, +10 low battery).
- **`test_t2_03_faq_accordion_interaction`**: Finds FAQ accordion triggers, simulates clicks, and asserts smooth collapsible expanding/collapsing behavior.
- **`test_t2_04_mobile_navigation_menu`**: Emulates mobile viewport (375x812), triggers hamburger menu button (`#mobile-menu-btn`), and asserts that the mobile drawer opens and displays navigation links.

### Tier 3: Instant Bilingual (VI / EN) Switcher Verification
- **`test_t3_01_bilingual_contracts_and_catalogs`**: Validates `window.EvernearI18n` object contract, asserting that `catalogs.vi` and `catalogs.en` exist and contain comprehensive localization dictionaries (>= 15 keys each).
- **`test_t3_02_bilingual_dom_elements_and_keys`**: Queries all DOM nodes marked with `[data-i18n]` and `[data-i18n-html]`, verifying that every element maps cleanly to defined keys in both catalogs without orphaned keys.
- **`test_t3_03_instant_language_switching_vi_en`**: Executes `window.EvernearI18n.setLanguage('en')` and `setLanguage('vi')` dynamically, asserting immediate DOM updates without page reload, zero "undefined" or "null" strings, and proper toggle button state styling.

### Tier 4: Viewport & Layout Overflow Testing
- **`test_t4_01_mobile_viewport_overflow_375x812`**: Configures Chrome device metrics to iPhone / mobile standard (375x812, scale=1, mobile=True). Asserts `Math.max(document.documentElement.scrollWidth, document.body.scrollWidth) <= window.innerWidth`. Scans all DOM elements to detect and pinpoint any element whose bounding box bleeds past the viewport width.
- **`test_t4_02_desktop_viewport_overflow_1440x900`**: Configures Chrome device metrics to desktop standard (1440x900). Asserts `scrollWidth <= innerWidth` with zero horizontal scrolling.

### Tier 5: Calm UX Copy Guard & Repository Isolation
- **`test_t5_01_calm_ux_copy_guard`**:
  - Scans `landing/index.html` for prohibited panic, alarming, or clinical terms:
    - `"dead man's switch"`, `"dead mans switch"`, `"tử vong"`, `"chết"`, `"theo dõi ngầm"`, `"bệnh nhân"`, `"đột tử"`.
  - Asserts zero occurrences of prohibited terms.
  - Verifies presence of mandatory reassuring Calm UX copy: "Tôi vẫn ổn", non-diagnostic risk scoring disclaimer, and privacy guarantees.
- **`test_t5_02_git_isolation_check`**:
  - Analyzes `git status --porcelain`.
  - Asserts that zero files in `backend/` or `mobile/` have been modified after the session start timestamp (`2026-10-15T08:53:50Z`). All project changes remain strictly confined to `landing/`, `.agents/`, or root test documentation.

---

## 4. Feature Coverage Matrix

| Feature / Requirement | Acceptance Criteria | Test Function | Tier | Result |
|---|---|---|:---:|:---:|
| HTTP 200 Serving | Serving landing page returns HTTP 200 with zero network 404s | `test_t1_01_http_serving_index` | 1 | PASS |
| Asset Integrity | Local images, logos, icons, favicons return HTTP 200 with non-zero size | `test_t1_02_all_local_assets_200_zero_404s` | 1 | PASS |
| JS Runtime Safety | Zero syntax errors, zero uncaught console exceptions | `test_t1_03_js_syntax_and_console_errors` | 1 | PASS |
| Dual-Mode Simulator | Monitored vs Guardian mode switching, check-in, passive activity | `test_t2_01_dual_mode_phone_simulator` | 2 | PASS |
| 8-State Visualizer | Interactive 8-state switching, signal weights, risk score explainer | `test_t2_02_8_state_monitoring_visualizer` | 2 | PASS |
| FAQ Accordion | Collapsible accordion expanding/collapsing on user interaction | `test_t2_03_faq_accordion_interaction` | 2 | PASS |
| Mobile Menu | Responsive hamburger menu drawer opens/closes cleanly | `test_t2_04_mobile_navigation_menu` | 2 | PASS |
| Bilingual Catalogs | Full dictionaries for VI and EN catalogs | `test_t3_01_bilingual_contracts_and_catalogs` | 3 | PASS |
| Localized Elements | `data-i18n` elements mapped without undefined/null strings | `test_t3_02_bilingual_dom_elements_and_keys` | 3 | PASS |
| Instant Switcher | Instant dynamic toggling between VI and EN without page reload | `test_t3_03_instant_language_switching_vi_en` | 3 | PASS |
| Mobile Overflow | Zero horizontal overflow at Mobile viewport (375x812) | `test_t4_01_mobile_viewport_overflow_375x812` | 4 | PASS |
| Desktop Overflow | Zero horizontal overflow at Desktop viewport (1440x900) | `test_t4_02_desktop_viewport_overflow_1440x900` | 4 | PASS |
| Calm UX Copy Guard | Prohibited panic/medical words banned; reassuring phrasing verified | `test_t5_01_calm_ux_copy_guard` | 5 | PASS |
| Repository Isolation | `backend/` and `mobile/` 100% clean and untouched during session | `test_t5_02_git_isolation_check` | 5 | PASS |

---

## 5. Summary Results & Verification

Last verification executed on `2026-10-15`:
```
=================================================================
SUMMARY RESULTS:
  Total Tests:  14
  Passed:       14
  Failed:       0
  Total Time:   10388.6ms
=================================================================
```
All 14 tests across Tiers 1–5 passed cleanly with 100% compliance.
