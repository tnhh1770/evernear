/* Evernear marketing & legal site — 36-language i18n + session-aware CTA */
(function () {
  var LANGS = [
    { code: "en", name: "English", en: "English (US)", country: "US" },
    { code: "vi", name: "Tiếng Việt", en: "Vietnamese", country: "VN" },
    { code: "zh", name: "中文", en: "Chinese", country: "CN" },
    { code: "es", name: "Español", en: "Spanish", country: "ES" },
    { code: "fr", name: "Français", en: "French", country: "FR" },
    { code: "de", name: "Deutsch", en: "German", country: "DE" },
    { code: "ja", name: "日本語", en: "Japanese", country: "JP" },
    { code: "ko", name: "한국어", en: "Korean", country: "KR" },
    { code: "pt", name: "Português", en: "Portuguese", country: "PT" },
    { code: "ru", name: "Русский", en: "Russian", country: "RU" },
    { code: "ar", name: "العربية", en: "Arabic", country: "SA", rtl: true },
    { code: "hi", name: "हिन्दी", en: "Hindi", country: "IN" },
    { code: "th", name: "ไทย", en: "Thai", country: "TH" },
    { code: "id", name: "Bahasa Indonesia", en: "Indonesian", country: "ID" },
    { code: "ms", name: "Bahasa Melayu", en: "Malay", country: "MY" },
    { code: "tr", name: "Türkçe", en: "Turkish", country: "TR" },
    { code: "it", name: "Italiano", en: "Italian", country: "IT" },
    { code: "nl", name: "Nederlands", en: "Dutch", country: "NL" },
    { code: "pl", name: "Polski", en: "Polish", country: "PL" },
    { code: "sv", name: "Svenska", en: "Swedish", country: "SE" },
    { code: "no", name: "Norsk", en: "Norwegian", country: "NO" },
    { code: "da", name: "Dansk", en: "Danish", country: "DK" },
    { code: "fi", name: "Suomi", en: "Finnish", country: "FI" },
    { code: "el", name: "Ελληνικά", en: "Greek", country: "GR" },
    { code: "cs", name: "Čeština", en: "Czech", country: "CZ" },
    { code: "hu", name: "Magyar", en: "Hungarian", country: "HU" },
    { code: "ro", name: "Română", en: "Romanian", country: "RO" },
    { code: "uk", name: "Українська", en: "Ukrainian", country: "UA" },
    { code: "he", name: "עברית", en: "Hebrew", country: "IL", rtl: true },
    { code: "fa", name: "فارسی", en: "Persian", country: "IR", rtl: true },
    { code: "bn", name: "বাংলা", en: "Bengali", country: "BD" },
    { code: "ur", name: "اردو", en: "Urdu", country: "PK", rtl: true },
    { code: "ta", name: "தமிழ்", en: "Tamil", country: "IN" },
    { code: "te", name: "తెలుగు", en: "Telugu", country: "IN" },
    { code: "fil", name: "Filipino", en: "Filipino", country: "PH" },
    { code: "sw", name: "Kiswahili", en: "Swahili", country: "KE" }
  ];

  function flagSvg(cc) {
    var b = "";
    switch (cc) {
      case "US": b = '<rect width="24" height="16" fill="#B22234"/><path d="M0 2.5h24M0 5h24M0 7.5h24M0 10h24M0 12.5h24M0 15h24" stroke="#fff" stroke-width="1.2"/><rect width="10.5" height="8.8" fill="#3C3B6E"/><circle cx="2.5" cy="2.5" r=".7" fill="#fff"/><circle cx="5.2" cy="2.5" r=".7" fill="#fff"/><circle cx="8" cy="2.5" r=".7" fill="#fff"/><circle cx="3.8" cy="4.5" r=".7" fill="#fff"/><circle cx="6.6" cy="4.5" r=".7" fill="#fff"/><circle cx="2.5" cy="6.5" r=".7" fill="#fff"/><circle cx="5.2" cy="6.5" r=".7" fill="#fff"/><circle cx="8" cy="6.5" r=".7" fill="#fff"/>'; break;
      case "VN": b = '<rect width="24" height="16" fill="#DA251D"/><polygon points="12,3.2 13.3,6.9 17.2,6.9 14.1,9.1 15.2,12.8 12,10.6 8.8,12.8 9.9,9.1 6.8,6.9 10.7,6.9" fill="#FFCD00"/>'; break;
      case "CN": b = '<rect width="24" height="16" fill="#EE1C25"/><polygon points="5,2.2 5.8,4.6 8.3,4.6 6.3,6 7,8.4 5,7 3,8.4 3.7,6 1.7,4.6 4.2,4.6" fill="#FFFF00"/><circle cx="10" cy="2.2" r=".7" fill="#FFFF00"/><circle cx="11.4" cy="3.8" r=".7" fill="#FFFF00"/><circle cx="11.4" cy="6" r=".7" fill="#FFFF00"/><circle cx="10" cy="7.6" r=".7" fill="#FFFF00"/>'; break;
      case "ES": b = '<rect width="24" height="16" fill="#AA151B"/><rect y="4" width="24" height="8" fill="#F1BF00"/><circle cx="7.5" cy="8" r="1.8" fill="#AA151B"/>'; break;
      case "FR": b = '<rect width="8" height="16" fill="#002395"/><rect x="8" width="8" height="16" fill="#fff"/><rect x="16" width="8" height="16" fill="#ED2939"/>'; break;
      case "DE": b = '<rect width="24" height="5.4" fill="#000"/><rect y="5.3" width="24" height="5.4" fill="#DD0000"/><rect y="10.6" width="24" height="5.4" fill="#FFCE00"/>'; break;
      case "JP": b = '<rect width="24" height="16" fill="#fff"/><circle cx="12" cy="8" r="4.6" fill="#BC002D"/>'; break;
      case "KR": b = '<rect width="24" height="16" fill="#fff"/><path d="M8,8a4,4 0 0,1 8,0Z" fill="#CD2E3A"/><path d="M8,8a4,4 0 0,0 8,0Z" fill="#0047A0"/>'; break;
      case "PT": b = '<rect width="9.6" height="16" fill="#006600"/><rect x="9.6" width="14.4" height="16" fill="#FF0000"/><circle cx="9.6" cy="8" r="3" fill="#FFCC00"/><circle cx="9.6" cy="8" r="1.7" fill="#fff"/>'; break;
      case "RU": b = '<rect width="24" height="5.4" fill="#fff"/><rect y="5.3" width="24" height="5.4" fill="#0039A6"/><rect y="10.6" width="24" height="5.4" fill="#D52B1E"/>'; break;
      case "SA": b = '<rect width="24" height="16" fill="#006C35"/><rect x="5" y="5" width="14" height="2.6" rx="1" fill="#fff"/><rect x="6.5" y="9.8" width="11" height="1.2" fill="#fff"/>'; break;
      case "IN": b = '<rect width="24" height="5.4" fill="#FF9933"/><rect y="5.3" width="24" height="5.4" fill="#fff"/><rect y="10.6" width="24" height="5.4" fill="#138808"/><circle cx="12" cy="8" r="2" fill="#000080"/>'; break;
      case "TH": b = '<rect width="24" height="16" fill="#A51931"/><rect y="2.7" width="24" height="10.6" fill="#fff"/><rect y="5.3" width="24" height="5.4" fill="#2D2A4A"/>'; break;
      case "ID": b = '<rect width="24" height="8" fill="#FF0000"/><rect y="8" width="24" height="8" fill="#fff"/>'; break;
      case "MY": b = '<rect width="24" height="16" fill="#CC0001"/><path d="M0 2.3h24M0 4.6h24M0 6.9h24M0 9.2h24M0 11.5h24M0 13.8h24" stroke="#fff" stroke-width="1.1"/><rect width="12" height="9" fill="#010066"/><circle cx="5.2" cy="4.5" r="2.6" fill="#FFCC00"/><circle cx="6" cy="4.5" r="2.1" fill="#010066"/><circle cx="8.2" cy="4.5" r="1.2" fill="#FFCC00"/>'; break;
      case "TR": b = '<rect width="24" height="16" fill="#E30A17"/><circle cx="10" cy="8" r="3.8" fill="#fff"/><circle cx="11.1" cy="8" r="3" fill="#E30A17"/><circle cx="14.2" cy="8" r="1.4" fill="#fff"/>'; break;
      case "IT": b = '<rect width="8" height="16" fill="#009246"/><rect x="8" width="8" height="16" fill="#fff"/><rect x="16" width="8" height="16" fill="#CE2B37"/>'; break;
      case "NL": b = '<rect width="24" height="5.4" fill="#AE1C28"/><rect y="5.3" width="24" height="5.4" fill="#fff"/><rect y="10.6" width="24" height="5.4" fill="#21468B"/>'; break;
      case "PL": b = '<rect width="24" height="8" fill="#fff"/><rect y="8" width="24" height="8" fill="#DC143C"/>'; break;
      case "SE": b = '<rect width="24" height="16" fill="#006AA7"/><rect x="7" width="2.8" height="16" fill="#FECC02"/><rect y="6.6" width="24" height="2.8" fill="#FECC02"/>'; break;
      case "NO": b = '<rect width="24" height="16" fill="#BA0C2F"/><rect x="6.4" width="4.2" height="16" fill="#fff"/><rect y="5.9" width="24" height="4.2" fill="#fff"/><rect x="7.3" width="2.4" height="16" fill="#00205B"/><rect y="6.8" width="24" height="2.4" fill="#00205B"/>'; break;
      case "DK": b = '<rect width="24" height="16" fill="#C8102E"/><rect x="7" width="2.6" height="16" fill="#fff"/><rect y="6.7" width="24" height="2.6" fill="#fff"/>'; break;
      case "FI": b = '<rect width="24" height="16" fill="#fff"/><rect x="7" width="2.8" height="16" fill="#003580"/><rect y="6.6" width="24" height="2.8" fill="#003580"/>'; break;
      case "GR": b = '<rect width="24" height="16" fill="#0D5EAF"/><path d="M0 2.7h24M0 6.2h24M0 9.8h24M0 13.3h24" stroke="#fff" stroke-width="1.7"/><rect width="9" height="9" fill="#0D5EAF"/><rect x="3.6" width="1.8" height="9" fill="#fff"/><rect y="3.6" width="9" height="1.8" fill="#fff"/>'; break;
      case "CZ": b = '<rect width="24" height="8" fill="#fff"/><rect y="8" width="24" height="8" fill="#D7141A"/><polygon points="0,0 11.5,8 0,16" fill="#11457E"/>'; break;
      case "HU": b = '<rect width="24" height="5.4" fill="#CE2939"/><rect y="5.3" width="24" height="5.4" fill="#fff"/><rect y="10.6" width="24" height="5.4" fill="#477050"/>'; break;
      case "RO": b = '<rect width="8" height="16" fill="#002B7F"/><rect x="8" width="8" height="16" fill="#FCD116"/><rect x="16" width="8" height="16" fill="#CE1126"/>'; break;
      case "UA": b = '<rect width="24" height="8" fill="#0057B7"/><rect y="8" width="24" height="8" fill="#FFD700"/>'; break;
      case "IL": b = '<rect width="24" height="16" fill="#fff"/><rect y="2" width="24" height="2.4" fill="#0038B8"/><rect y="11.6" width="24" height="2.4" fill="#0038B8"/><polygon points="12,5 14.6,9.5 9.4,9.5" fill="none" stroke="#0038B8" stroke-width="1.1"/><polygon points="12,11 14.6,6.5 9.4,6.5" fill="none" stroke="#0038B8" stroke-width="1.1"/>'; break;
      case "IR": b = '<rect width="24" height="5.4" fill="#239F40"/><rect y="5.3" width="24" height="5.4" fill="#fff"/><rect y="10.6" width="24" height="5.4" fill="#DA0000"/><circle cx="12" cy="8" r="1.8" fill="#DA0000"/>'; break;
      case "BD": b = '<rect width="24" height="16" fill="#006A4E"/><circle cx="10.8" cy="8" r="4.2" fill="#F42A41"/>'; break;
      case "PK": b = '<rect width="24" height="16" fill="#01411C"/><rect width="6" height="16" fill="#fff"/><circle cx="14" cy="8" r="3.6" fill="#fff"/><circle cx="15" cy="7.2" r="3" fill="#01411C"/><circle cx="16.8" cy="6.2" r="1.2" fill="#fff"/>'; break;
      case "PH": b = '<rect width="24" height="8" fill="#0038A8"/><rect y="8" width="24" height="8" fill="#CE1126"/><polygon points="0,0 11,8 0,16" fill="#fff"/><circle cx="3.8" cy="8" r="1.8" fill="#FCD116"/>'; break;
      case "KE": b = '<rect width="24" height="16" fill="#fff"/><rect width="24" height="4.6" fill="#000"/><rect y="5.7" width="24" height="4.6" fill="#BB0000"/><rect y="11.4" width="24" height="4.6" fill="#006600"/><ellipse cx="12" cy="8" rx="2.4" ry="3.8" fill="#BB0000" stroke="#fff" stroke-width=".6"/>'; break;
      default: b = '<rect width="24" height="16" fill="#2D6A4F"/>';
    }
    return '<svg class="lang-flag" viewBox="0 0 24 16" aria-hidden="true">' + b + "</svg>";
  }

  var BY_CODE = {};
  for (var i = 0; i < LANGS.length; i++) BY_CODE[LANGS[i].code] = LANGS[i];

  var STORE_KEY = "evernear_site_lang";
  var APP_LOCALE_KEY = "evernear_app_locale";
  var DICT_PREFIX = "evernear_i18n_dict_v2_";
  var cache = {};
  var baseStrings = null;
  var current = "en";

  function readCachedDict(code) {
    if (cache[code]) return cache[code];
    try {
      var raw = localStorage.getItem(DICT_PREFIX + code) ||
                localStorage.getItem("flutter." + DICT_PREFIX + code);
      if (raw) {
        var parsed = JSON.parse(raw);
        if (typeof parsed === "string") parsed = JSON.parse(parsed);
        if (parsed && typeof parsed === "object") {
          cache[code] = parsed;
          return parsed;
        }
      }
    } catch (_) {}
    return null;
  }

  function writeCachedDict(code, dict) {
    if (!dict || typeof dict !== "object") return;
    cache[code] = dict;
    try {
      localStorage.setItem(DICT_PREFIX + code, JSON.stringify(dict));
    } catch (_) {}
  }

  function pagePrefix() {
    var p = (location.pathname || "/").toLowerCase();
    if (p.indexOf("privacy") !== -1) return "p";
    if (p.indexOf("terms") !== -1) return "t";
    if (p.indexOf("delete-account") !== -1) return "d";
    return "i";
  }

  function snapshotBase() {
    if (baseStrings) return;
    baseStrings = {};
    var nodes = document.querySelectorAll("[data-i18n]");
    for (var j = 0; j < nodes.length; j++) {
      var k = nodes[j].getAttribute("data-i18n");
      if (k && !(k in baseStrings)) baseStrings[k] = nodes[j].innerHTML;
    }
    baseStrings[pagePrefix() + ".title"] = document.title;
  }

  function applyScreens(code, dict) {
    function tr(k, fb) {
      if (dict && dict[k]) return dict[k];
      if (cache.en && cache.en[k]) return cache.en[k];
      if (baseStrings && baseStrings[k]) return baseStrings[k];
      return fb || "";
    }
    function topBar(backTitle) {
      var full = tr("app.user_full", "Alex Nguyen");
      var left = backTitle
        ? '<span style="font-size:10px;font-weight:800;color:#1B2A22;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">&larr; ' + backTitle + "</span>"
        : '<span style="display:inline-flex;align-items:center;gap:4px;font-size:10.5px;font-weight:800;color:#1B2A22;"><span style="width:13px;height:13px;border-radius:4px;background:#2D6A4F;color:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:8px;">&hearts;</span>Evernear</span>';
      return '<div style="height:28px;padding:0 8px;background:#fff;border-bottom:1px solid #EEF1EE;display:flex;align-items:center;justify-content:space-between;gap:4px;flex-shrink:0;">' +
        left +
        '<span style="font-size:7px;font-weight:700;color:#1E4D38;background:#EAF3EE;border:1px solid #CDE2D6;border-radius:99px;padding:2px 5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:52%;">' +
        tr("app.account_prefix", "") + full + "</span></div>";
    }
    function bottomNav(activeIdx) {
      var items = [
        tr("app.nav_status", "Status"),
        tr("app.nav_family", "Family"),
        tr("app.nav_incidents", "Alerts"),
        tr("app.nav_settings", "Settings")
      ];
      var icons = ["&#8962;", "&#128101;", "&#128276;", "&#9881;"];
      function cell(i) {
        var c = i === activeIdx ? "#2D6A4F" : "#8A9990";
        var w = i === activeIdx ? "800" : "500";
        return '<div style="flex:1;text-align:center;color:' + c + ";font-weight:" + w + ';font-size:6.8px;line-height:1.15;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"><div style="font-size:9px;">' + icons[i] + "</div>" + items[i] + "</div>";
      }
      return '<div style="position:relative;height:36px;background:#fff;border-top:1px solid #E8ECE8;display:flex;align-items:center;padding:0 4px;flex-shrink:0;">' +
        cell(0) + cell(1) +
        '<div style="width:28px;flex-shrink:0;display:flex;justify-content:center;"><div style="width:24px;height:24px;border-radius:50%;background:#2D6A4F;color:#fff;display:flex;align-items:center;justify-content:center;font-size:10px;margin-top:-10px;border:2px solid #fff;box-shadow:0 3px 8px rgba(45,106,79,0.3);">&hearts;</div></div>' +
        cell(2) + cell(3) + "</div>";
    }

    var frames = document.querySelectorAll(".device-frame");
    for (var i = 0; i < frames.length; i++) {
      var el = frames[i];
      var st = el.getAttribute("data-screen-type");
      if (!st) {
        var img = el.querySelector("img");
        var name = img ? (img.getAttribute("data-img") || img.getAttribute("src") || "") : "";
        if (name.indexOf("guardian_dashboard") !== -1) st = "guardian";
        else if (name.indexOf("incidents") !== -1) st = "incidents";
        else if (name.indexOf("check_in_detail") !== -1) st = "checkin";
        else if (name.indexOf("qr_invite") !== -1) st = "qr";
        else if (name.indexOf("monitoring_settings") !== -1) st = "monitoring";
        else if (name.indexOf("privacy_security") !== -1) st = "privacy";
        else if (name.indexOf("settings") !== -1) st = "settings";
        else st = "monitored";
        el.setAttribute("data-screen-type", st);
      }
      var body = "";
      if (st === "monitored") {
        body = topBar(null) +
          '<div style="flex:1;padding:9px 10px;display:flex;flex-direction:column;justify-content:space-between;overflow:hidden;">' +
            "<div>" +
              '<div style="font-size:11.5px;font-weight:800;color:#184A3E;line-height:1.2;">' + tr("app.greeting", "Hello, Alex 👋") + "</div>" +
              '<div style="font-size:7.8px;color:#4A6B61;margin-top:2px;display:flex;align-items:center;gap:4px;"><span style="width:5px;height:5px;border-radius:50%;background:#43A071;display:inline-block;"></span>' + tr("app.state_active", "You are protected") + "</div>" +
            "</div>" +
            '<div style="margin:6px auto;width:108px;height:108px;border-radius:50%;background:#E3EFE9;padding:7px;box-sizing:border-box;display:flex;align-items:center;justify-content:center;">' +
              '<div style="width:100%;height:100%;border-radius:50%;background:linear-gradient(180deg,#3A8564,#28694C);color:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:6px;box-sizing:border-box;text-align:center;box-shadow:0 4px 10px rgba(40,105,76,0.25);">' +
                '<div style="font-size:14px;line-height:1;">&#10004;</div>' +
                '<div style="font-size:9.5px;font-weight:800;margin-top:3px;line-height:1.15;">' + tr("app.check_in_btn", "I am OK") + "</div>" +
                '<div style="font-size:6.8px;opacity:0.9;margin-top:2px;">' + tr("app.check_in_sub", "Tap to confirm") + "</div>" +
              "</div>" +
            "</div>" +
            '<div style="display:grid;grid-template-columns:1fr 1fr;gap:5px;">' +
              '<div style="background:#fff;border:1px solid #E8ECE8;border-radius:8px;padding:5px 6px;">' +
                '<div style="font-size:6.5px;color:#4A6B61;">' + tr("app.last_activity", "Last activity") + "</div>" +
                '<div style="font-size:7.8px;font-weight:800;color:#184A3E;margin-top:2px;">' + tr("app.today_0830", "Today 08:30") + "</div>" +
                '<div style="font-size:6.3px;color:#4A6B61;">' + tr("app.synced", "(Synced)") + "</div>" +
              "</div>" +
              '<div style="background:#fff;border:1px solid #E8ECE8;border-radius:8px;padding:5px 6px;">' +
                '<div style="font-size:6.5px;color:#4A6B61;">' + tr("app.battery", "Device battery") + "</div>" +
                '<div style="font-size:9.5px;font-weight:800;color:#184A3E;margin-top:3px;">&#128267; 92%</div>' +
              "</div>" +
            "</div>" +
            '<div style="background:#fff;border:1px solid #E8ECE8;border-radius:8px;padding:5px 7px;margin-top:4px;">' +
              '<div style="display:flex;justify-content:space-between;font-size:6.5px;color:#4A6B61;"><span>' + tr("app.schedule_title", "Check-in window") + '</span><span style="color:#2D6A4F;font-weight:700;max-width:58%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">' + tr("app.sleep_action", "Quiet hours") + "</span></div>" +
              '<div style="font-size:8px;font-weight:800;color:#184A3E;margin-top:1px;">06:30 - 22:00</div>' +
              '<div style="font-size:6.5px;color:#2D6A4F;margin-top:1px;">&#9679; ' + tr("app.schedule_active", "Active monitoring window") + "</div>" +
            "</div>" +
            '<div style="background:#fff;border:1px solid #E8ECE8;border-radius:8px;padding:5px 7px;margin-top:4px;display:flex;align-items:center;gap:6px;">' +
              '<div style="width:18px;height:18px;border-radius:50%;background:#E6F2EC;color:#2D6A4F;display:flex;align-items:center;justify-content:center;font-size:8px;font-weight:800;flex-shrink:0;">M</div>' +
              '<div style="min-width:0;flex:1;"><div style="font-size:7.5px;font-weight:800;color:#1B2A22;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">' + tr("app.mom_name", "Mom (Mrs. Lan)") + '</div><div style="font-size:6.5px;color:#2D6A4F;">' + tr("app.auto_active", "Auto-monitoring active") + "</div></div>" +
            "</div>" +
          "</div>" + bottomNav(0);
      } else if (st === "guardian") {
        function relCard(name, conf) {
          return '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:10px;padding:8px;margin-bottom:6px;display:flex;align-items:center;gap:7px;">' +
            '<div style="width:26px;height:26px;border-radius:50%;background:#E6F2EC;color:#2D6A4F;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:800;flex-shrink:0;">&#128100;</div>' +
            '<div style="min-width:0;flex:1;">' +
              '<div style="font-size:8.5px;font-weight:800;color:#1B2A22;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">' + name + "</div>" +
              '<div style="font-size:6.8px;color:#5C6B64;">' + tr("app.family_role", "Family") + "</div>" +
              '<div style="font-size:7.2px;font-weight:700;color:#2D6A4F;margin-top:1px;">' + tr("app.protected_pill", "Protected") + "</div>" +
              '<div style="font-size:6.5px;color:#5C6B64;">' + conf + "</div>" +
              '<div style="font-size:6.2px;color:#8A9990;margin-top:1px;">' + tr("app.risk_zero", "Risk: 0%") + " &middot; " + tr("app.alerts_zero", "0 alerts") + "</div>" +
            "</div>" +
          "</div>";
        }
        body = topBar(null) +
          '<div style="flex:1;padding:10px;overflow:hidden;">' +
            '<div style="font-size:11px;font-weight:800;color:#1B2A22;margin-bottom:8px;">' + tr("app.people_list", "Loved ones") + "</div>" +
            relCard(tr("app.mom_name", "Mom (Mrs. Lan)"), tr("app.confirmed_0830", "08:30")) +
            relCard(tr("app.dad_name", "Dad (Mr. Hung)"), tr("app.confirmed_0745", "07:45")) +
          "</div>" + bottomNav(1);
      } else if (st === "incidents") {
        function feed(title, sub, time) {
          return '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:9px;padding:7px;margin-bottom:6px;">' +
            '<div style="display:flex;justify-content:space-between;align-items:center;gap:4px;">' +
              '<span style="font-size:7.8px;font-weight:800;color:#1B2A22;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">' + title + "</span>" +
              '<span style="font-size:6.2px;font-weight:700;color:#2D6A4F;background:#EAF4EE;padding:1px 5px;border-radius:99px;flex-shrink:0;">' + tr("app.peace_badge", "Safe") + "</span>" +
            "</div>" +
            '<div style="font-size:6.8px;color:#5C6B64;margin-top:2px;line-height:1.3;">' + sub + "</div>" +
            '<div style="font-size:6px;color:#8A9990;margin-top:2px;">' + time + " &middot; " + tr("app.today_tag", "Today") + "</div>" +
          "</div>";
        }
        body = topBar(null) +
          '<div style="flex:1;padding:9px 10px;overflow:hidden;">' +
            '<div style="font-size:10.5px;font-weight:800;color:#1B2A22;margin-bottom:6px;">' + tr("app.incidents_title", "Alerts & activity") + "</div>" +
            '<div style="display:flex;gap:4px;margin-bottom:7px;flex-wrap:wrap;">' +
              '<span style="font-size:6.5px;font-weight:700;background:#2D6A4F;color:#fff;padding:2px 7px;border-radius:99px;">' + tr("app.filter_all", "All") + "</span>" +
              '<span style="font-size:6.5px;background:#fff;border:1px solid #E6ECE8;color:#5C6B64;padding:2px 7px;border-radius:99px;">' + tr("app.filter_safe", "Safe") + "</span>" +
              '<span style="font-size:6.5px;background:#fff;border:1px solid #E6ECE8;color:#5C6B64;padding:2px 7px;border-radius:99px;">' + tr("app.filter_alert", "Alerts") + "</span>" +
            "</div>" +
            feed(tr("app.feed_mom_title", "Safety confirmed"), tr("app.feed_mom_sub", "Mom confirmed she is doing well."), "08:30") +
            feed(tr("app.feed_dad_title", "Safety confirmed"), tr("app.feed_dad_sub", "Passive morning activity recorded."), "07:45") +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:9px;padding:7px;text-align:center;">' +
              '<div style="font-size:8px;font-weight:800;color:#1B2A22;">&#10004; ' + tr("app.empty_peace_title", "All is calm") + "</div>" +
              '<div style="font-size:6.5px;color:#5C6B64;margin-top:2px;">' + tr("app.empty_peace_desc", "No overdue alerts.") + "</div>" +
            "</div>" +
          "</div>" + bottomNav(2);
      } else if (st === "qr") {
        body = topBar(tr("app.qr_title", "Family pairing code")) +
          '<div style="flex:1;padding:10px;display:flex;flex-direction:column;justify-content:space-between;align-items:center;text-align:center;overflow:hidden;">' +
            '<div style="width:100%;background:#fff;border:1px solid #E6ECE8;border-radius:8px;padding:5px 7px;text-align:left;">' +
              '<div style="font-size:8px;font-weight:800;color:#1B2A22;">' + tr("app.user_full", "Alex Nguyen") + "</div>" +
              '<div style="font-size:6.2px;font-weight:700;color:#2D6A4F;">' + tr("app.logged_in", "LOGGED IN") + "</div>" +
            "</div>" +
            '<div style="font-size:6.8px;color:#5C6B64;line-height:1.3;">' + tr("app.qr_desc", "Ask your relative to scan this QR code to pair.") + "</div>" +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:12px;padding:8px;box-shadow:0 4px 10px rgba(0,0,0,0.04);">' +
              '<svg width="88" height="88" viewBox="0 0 44 44" fill="#1B2A22"><rect x="2" y="2" width="12" height="12" fill="none" stroke="#1B2A22" stroke-width="2"/><rect x="5" y="5" width="6" height="6"/><rect x="30" y="2" width="12" height="12" fill="none" stroke="#1B2A22" stroke-width="2"/><rect x="33" y="5" width="6" height="6"/><rect x="2" y="30" width="12" height="12" fill="none" stroke="#1B2A22" stroke-width="2"/><rect x="5" y="33" width="6" height="6"/><rect x="18" y="4" width="4" height="4"/><rect x="24" y="8" width="4" height="4"/><rect x="18" y="16" width="8" height="8"/><rect x="6" y="18" width="8" height="4"/><rect x="30" y="18" width="8" height="4"/><rect x="18" y="28" width="6" height="6"/><rect x="28" y="28" width="10" height="10"/></svg>' +
            "</div>" +
            '<div style="background:#EAF3EE;border:1px solid #CDE2D6;border-radius:9px;padding:4px 10px;font-size:10px;font-weight:800;letter-spacing:1.5px;color:#1E4D38;">CR-849201</div>' +
            '<div style="font-size:6.3px;color:#8A9990;">&#128337; ' + tr("app.qr_expires", "Valid for 48 hours") + "</div>" +
            '<div style="width:100%;background:#2D6A4F;color:#fff;border-radius:99px;padding:6px;font-size:8px;font-weight:800;">' + tr("app.qr_share", "Share invitation") + "</div>" +
          "</div>";
      } else if (st === "monitoring") {
        body = topBar(tr("app.mon_title", "Monitoring settings")) +
          '<div style="flex:1;padding:9px 10px;display:flex;flex-direction:column;justify-content:space-between;overflow:hidden;">' +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:9px;padding:7px;">' +
              '<div style="font-size:8.5px;font-weight:800;color:#1B2A22;">' + tr("app.active_hours", "Active monitoring hours") + "</div>" +
              '<div style="font-size:7px;color:#2D6A4F;font-weight:700;margin-top:1px;">06:30 - 22:00 &middot; ' + tr("app.daily", "Daily") + "</div>" +
              '<div style="background:#EAF3EE;border-radius:7px;padding:5px;margin-top:5px;">' +
                '<div style="font-size:7px;font-weight:800;color:#1E4D38;">&#127769; ' + tr("app.quiet_title", "Quiet Hours (Sleep Window)") + "</div>" +
                '<div style="font-size:6.2px;color:#2D5A47;margin-top:2px;line-height:1.3;">' + tr("app.quiet_desc", "Countdown freezes automatically while you sleep.") + "</div>" +
              "</div>" +
            "</div>" +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:9px;padding:7px;">' +
              '<div style="display:flex;justify-content:space-between;align-items:center;">' +
                '<div><div style="font-size:8px;font-weight:800;color:#1B2A22;">' + tr("app.day_mon", "Monday") + '</div><div style="font-size:6.3px;color:#2D6A4F;">' + tr("app.day_enabled", "Monitoring enabled") + "</div></div>" +
                '<span style="width:24px;height:13px;border-radius:99px;background:#2D6A4F;display:inline-block;"></span>' +
              "</div>" +
              '<div style="display:grid;grid-template-columns:1fr 1fr;gap:5px;margin-top:5px;">' +
                '<div style="background:#F4F6F3;border-radius:6px;padding:4px 5px;"><div style="font-size:6px;color:#5C6B64;">' + tr("app.wake_label", "Wake time") + '</div><div style="font-size:8px;font-weight:800;color:#1B2A22;">&#9728; 06:30</div></div>' +
                '<div style="background:#F4F6F3;border-radius:6px;padding:4px 5px;"><div style="font-size:6px;color:#5C6B64;">' + tr("app.bed_label", "Bedtime") + '</div><div style="font-size:8px;font-weight:800;color:#1B2A22;">&#127769; 22:00</div></div>' +
              "</div>" +
            "</div>" +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:9px;padding:7px;">' +
              '<div style="font-size:7.8px;font-weight:800;color:#1B2A22;margin-bottom:4px;">' + tr("app.threshold_title", "Inactivity threshold") + "</div>" +
              '<div style="display:flex;gap:3px;flex-wrap:wrap;"><span style="font-size:6.2px;padding:2px 5px;background:#F4F6F3;border-radius:99px;">30m</span><span style="font-size:6.2px;padding:2px 5px;background:#F4F6F3;border-radius:99px;">1h</span><span style="font-size:6.2px;padding:2px 5px;background:#F4F6F3;border-radius:99px;">2h</span><span style="font-size:6.2px;padding:2px 6px;background:#2D6A4F;color:#fff;font-weight:700;border-radius:99px;">4h</span><span style="font-size:6.2px;padding:2px 5px;background:#F4F6F3;border-radius:99px;">6h</span></div>' +
            "</div>" +
          "</div>";
      } else if (st === "checkin") {
        body = topBar(tr("app.ci_title", "Confirm safety")) +
          '<div style="flex:1;padding:10px;display:flex;flex-direction:column;justify-content:space-between;overflow:hidden;">' +
            '<div style="background:#EAF3EE;border:1px solid #CDE2D6;border-radius:9px;padding:7px;display:flex;align-items:center;gap:6px;">' +
              '<span style="width:18px;height:18px;border-radius:50%;background:#2D6A4F;color:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:9px;flex-shrink:0;">&#10004;</span>' +
              '<div><div style="font-size:8px;font-weight:800;color:#1E4D38;">' + tr("app.ci_banner_title", "Ready to check in") + '</div><div style="font-size:6.2px;color:#2D5A47;">' + tr("app.ci_banner_sub", "Notify your family that you are safe") + "</div></div>" +
            "</div>" +
            '<div><div style="font-size:7.2px;font-weight:800;color:#1B2A22;margin-bottom:4px;">' + tr("app.ci_mood_label", "How are you feeling?") + "</div>" +
              '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:4px;">' +
                '<div style="background:#EAF3EE;border:1px solid #2D6A4F;border-radius:7px;padding:5px 3px;text-align:center;font-size:6.5px;font-weight:800;color:#1E4D38;">&#128522; ' + tr("app.ci_mood_1", "Great") + "</div>" +
                '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:7px;padding:5px 3px;text-align:center;font-size:6.5px;color:#5C6B64;">&#128578; ' + tr("app.ci_mood_2", "Normal") + "</div>" +
                '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:7px;padding:5px 3px;text-align:center;font-size:6.5px;color:#5C6B64;">&#128564; ' + tr("app.ci_mood_3", "A bit tired") + "</div>" +
              "</div>" +
            "</div>" +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:8px;padding:6px 7px;">' +
              '<div style="font-size:6.5px;color:#8A9990;">' + tr("app.ci_note_label", "Quick note") + "</div>" +
              '<div style="font-size:7.2px;font-weight:700;color:#1B2A22;margin-top:2px;">' + tr("app.ci_note_val", "Just finished breakfast, lovely weather today!") + "</div>" +
            "</div>" +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:8px;padding:6px 7px;display:flex;justify-content:space-between;align-items:center;">' +
              '<span style="font-size:6.8px;font-weight:700;color:#1B2A22;">&#128205; ' + tr("app.ci_loc_label", "Attach single-shot location") + "</span>" +
              '<span style="width:22px;height:12px;border-radius:99px;background:#2D6A4F;display:inline-block;"></span>' +
            "</div>" +
            '<div style="width:100%;background:#2D6A4F;color:#fff;border-radius:99px;padding:6px;text-align:center;font-size:8px;font-weight:800;">' + tr("app.check_in_btn", "I am OK") + "</div>" +
          "</div>";
      } else if (st === "privacy") {
        body = topBar(tr("app.priv_title", "Privacy & security")) +
          '<div style="flex:1;padding:10px;display:flex;flex-direction:column;gap:7px;overflow:hidden;">' +
            '<div style="background:#EAF3EE;border:1px solid #CDE2D6;border-radius:9px;padding:8px;">' +
              '<div style="font-size:8px;font-weight:800;color:#1E4D38;">&#128737; ' + tr("app.priv_h1", "Zero Camera, Zero Mic, Zero Background GPS") + "</div>" +
              '<div style="font-size:6.5px;color:#2D5A47;margin-top:3px;line-height:1.35;">' + tr("app.priv_sub1", "Evernear never records audio, video, or continuous background location.") + "</div>" +
            "</div>" +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:9px;padding:8px;">' +
              '<div style="font-size:7.8px;font-weight:800;color:#1B2A22;">&#128274; ' + tr("i119", "TLS Encryption & bcrypt Password Hashing") + "</div>" +
              '<div style="font-size:6.4px;color:#5C6B64;margin-top:3px;line-height:1.35;">' + tr("i120", "All traffic encrypted in transit via HTTPS/WSS.") + "</div>" +
            "</div>" +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:9px;padding:8px;">' +
              '<div style="font-size:7.8px;font-weight:800;color:#1B2A22;">&#128465; ' + tr("app.priv_h3", "GDPR Right to Erasure & Instant Deletion") + "</div>" +
              '<div style="font-size:6.4px;color:#5C6B64;margin-top:3px;line-height:1.35;">' + tr("app.priv_sub3", "Export or permanently erase your account at any time.") + "</div>" +
            "</div>" +
          "</div>";
      } else if (st === "settings") {
        body = topBar(null) +
          '<div style="flex:1;padding:9px 10px;display:flex;flex-direction:column;justify-content:space-between;overflow:hidden;">' +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:9px;padding:7px;display:flex;align-items:center;gap:7px;">' +
              '<div style="width:24px;height:24px;border-radius:50%;background:#2D6A4F;color:#fff;display:flex;align-items:center;justify-content:center;font-size:9px;font-weight:800;flex-shrink:0;">A</div>' +
              '<div style="min-width:0;flex:1;"><div style="font-size:8.2px;font-weight:800;color:#1B2A22;">' + tr("app.user_full", "Alex Nguyen") + '</div><div style="font-size:6.3px;color:#2D6A4F;">alex.nguyen@evernear.app</div></div>' +
            "</div>" +
            '<div style="background:#fff;border:1px solid #E6ECE8;border-radius:9px;padding:6px 7px;display:grid;gap:5px;">' +
              '<div style="display:flex;justify-content:space-between;font-size:7px;"><span style="font-weight:700;color:#1B2A22;">&#127760; ' + tr("app.set_lang", "Language") + '</span><span style="color:#2D6A4F;font-weight:800;">' + ((BY_CODE[code] && BY_CODE[code].name) || "English") + "</span></div>" +
              '<div style="display:flex;justify-content:space-between;font-size:7px;"><span style="font-weight:700;color:#1B2A22;">&#127769; ' + tr("app.set_theme", "Theme") + '</span><span style="color:#5C6B64;">' + tr("app.set_theme_val", "Warm Light") + "</span></div>" +
              '<div style="display:flex;justify-content:space-between;font-size:7px;"><span style="font-weight:700;color:#1B2A22;">&#128276; ' + tr("app.set_channels", "Alert channels") + '</span><span style="color:#2D6A4F;font-weight:700;">FCM &middot; SMS</span></div>' +
            "</div>" +
            '<div style="background:#FDF2F0;border:1px solid #F3D1C8;border-radius:8px;padding:6px;text-align:center;font-size:7px;font-weight:800;color:#B43E27;">' + tr("i_del_page", "Delete Account Request") + "</div>" +
          "</div>" + bottomNav(3);
      }
      el.innerHTML = '<div style="width:100%;height:100%;aspect-ratio:390/844;background:#F7F9F7;color:#1B2A22;display:flex;flex-direction:column;justify-content:space-between;overflow:hidden;box-sizing:border-box;text-align:left;user-select:none;border-radius:30px;">' + body + "</div>";
    }
  }

  function paint(code, dict) {
    var meta = BY_CODE[code] || BY_CODE.en;
    current = meta.code;
    document.documentElement.setAttribute("lang", meta.code);
    document.documentElement.setAttribute("dir", meta.rtl ? "rtl" : "ltr");

    var nodes = document.querySelectorAll("[data-i18n]");
    for (var j = 0; j < nodes.length; j++) {
      var k = nodes[j].getAttribute("data-i18n");
      var val = (dict && dict[k]) || (baseStrings && baseStrings[k]);
      if (typeof val === "string") nodes[j].innerHTML = val;
    }

    var metaNodes = document.querySelectorAll("[data-i18n-content]");
    for (var mc = 0; mc < metaNodes.length; mc++) {
      var mk = metaNodes[mc].getAttribute("data-i18n-content");
      var mval = (dict && dict[mk]) || (baseStrings && baseStrings[mk]);
      if (typeof mval === "string") metaNodes[mc].setAttribute("content", mval);
    }

    var tk = pagePrefix() + ".title";
    if (dict && dict[tk]) document.title = dict[tk];
    else if (baseStrings && baseStrings[tk]) document.title = baseStrings[tk];

    applyScreens(meta.code, dict || baseStrings);

    var labels = document.querySelectorAll("[data-lang-name]");
    for (var m = 0; m < labels.length; m++) labels[m].textContent = meta.name;

    var flags = document.querySelectorAll("[data-lang-flag]");
    for (var f = 0; f < flags.length; f++) flags[f].innerHTML = flagSvg(meta.country);

    var opts = document.querySelectorAll(".lang-opt");
    for (var n = 0; n < opts.length; n++) {
      opts[n].classList.toggle("active", opts[n].getAttribute("data-code") === meta.code);
    }

    var searchInputs = document.querySelectorAll(".lang-search");
    for (var s = 0; s < searchInputs.length; s++) {
      if (dict && dict["ui.lang.search"]) {
        searchInputs[s].setAttribute("placeholder", dict["ui.lang.search"]);
      }
    }

    var note = document.querySelector(".mt-note");
    if (note) {
      var p = pagePrefix();
      var isLegal = p === "p" || p === "t" || p === "d";
      if (isLegal && meta.code !== "vi" && meta.code !== "en") {
        var msg = (dict && dict["ui.mt.notice"]) ||
          "Automatic translation for convenience. The Vietnamese and English versions are authoritative.";
        var resetLbl = (dict && dict["ui.mt.vi"]) || "Tiếng Việt";
        note.innerHTML = '<div class="shell"><span>' + msg +
          '</span> <a data-set-lang="en">English</a> · <a data-set-lang="vi">' + resetLbl + '</a></div>';
        note.classList.add("show");
      } else {
        note.classList.remove("show");
      }
    }
  }

  function use(code, save) {
    if (!BY_CODE[code]) code = "en";
    snapshotBase();
    if (save) {
      var appCode = code === "fil" ? "tl" : code;
      try {
        localStorage.setItem(STORE_KEY, code);
        localStorage.setItem("flutter." + STORE_KEY, JSON.stringify(code));
        localStorage.setItem(APP_LOCALE_KEY, appCode);
        localStorage.setItem("flutter." + APP_LOCALE_KEY, JSON.stringify(appCode));
      } catch (_) {}
      try {
        var u = new URL(location.href);
        if (code === "en") u.searchParams.delete("lang");
        else u.searchParams.set("lang", code);
        history.replaceState(null, "", u.pathname + u.search + u.hash);
      } catch (_) {}
    }
    if (!cache[code]) {
      var stored = readCachedDict(code);
      if (stored) cache[code] = stored;
    }
    if (cache[code]) {
      paint(code, cache[code]);
      return;
    }
    var i18nPrefix = document.querySelector('script[src*="/site/evernear.js"]') ? "/site/i18n/" : "/i18n/";
    fetch(i18nPrefix + code + ".json", { cache: "force-cache" })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (d) {
          cache[code] = d;
          writeCachedDict(code, d);
        }
        paint(code, d || baseStrings);
      })
      .catch(function () { paint(code, baseStrings); });
  }

  function normTag(tag) {
    if (!tag) return "";
    var cleaned = String(tag).replace(/^["']+|["']+$/g, "").trim();
    if (!cleaned || cleaned === "auto") return "";
    var t = cleaned.toLowerCase().split(/[-_]/)[0];
    if (t === "tl") return "fil";
    if (t === "iw") return "he";
    if (t === "in") return "id";
    if (t === "nb" || t === "nn") return "no";
    return t;
  }

  function detectInitial() {
    try {
      var mig = localStorage.getItem("evernear_en_us_default_v2") ||
                localStorage.getItem("flutter.evernear_en_us_default_v2");
      if (mig !== "true") {
        localStorage.setItem("evernear_en_us_default_v2", "true");
        localStorage.setItem("flutter.evernear_en_us_default_v2", "true");
        localStorage.removeItem(STORE_KEY);
        localStorage.removeItem("flutter." + STORE_KEY);
        localStorage.removeItem(APP_LOCALE_KEY);
        localStorage.removeItem("flutter." + APP_LOCALE_KEY);
        localStorage.removeItem("carely_app_locale");
        localStorage.removeItem("flutter.carely_app_locale");
      }
    } catch (_) {}
    try {
      var q = new URLSearchParams(location.search).get("lang");
      var nq = normTag(q);
      if (nq && BY_CODE[nq]) return nq;
    } catch (_) {}
    try {
      var saved = normTag(
        localStorage.getItem(STORE_KEY) ||
        localStorage.getItem("flutter." + STORE_KEY) ||
        localStorage.getItem(APP_LOCALE_KEY) ||
        localStorage.getItem("flutter." + APP_LOCALE_KEY)
      );
      if (saved && BY_CODE[saved]) return saved;
    } catch (_) {}
    return "en";
  }

  function buildPicker() {
    var navCta = document.querySelector(".nav-cta");
    if (!navCta) return;

    var wrap = document.createElement("div");
    wrap.className = "lang-picker";

    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "lang-btn";
    btn.setAttribute("aria-label", "Language");
    btn.innerHTML =
      '<span data-lang-flag class="lang-flag-wrap">' + flagSvg("US") + "</span>" +
      '<span data-lang-name>English</span>' +
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M6 9l6 6 6-6"/></svg>';

    var pop = document.createElement("div");
    pop.className = "lang-pop";
    pop.setAttribute("role", "dialog");

    var head = document.createElement("div");
    head.className = "lang-pop-head";
    head.innerHTML =
      '<strong data-i18n="ui.lang.label">Languages · 36</strong>' +
      '<input type="search" class="lang-search" placeholder="Search language..." aria-label="Search language">';

    var grid = document.createElement("div");
    grid.className = "lang-grid";

    for (var i = 0; i < LANGS.length; i++) {
      var L = LANGS[i];
      var o = document.createElement("button");
      o.type = "button";
      o.className = "lang-opt" + (L.code === current ? " active" : "");
      o.setAttribute("data-code", L.code);
      o.setAttribute("data-q", (L.name + " " + L.en + " " + L.code + " " + L.country).toLowerCase());
      o.innerHTML =
        '<span class="lang-flag-wrap">' + flagSvg(L.country) + "</span>" +
        '<span class="lang-opt-text"><b>' + L.name + "</b><small>" + L.en + "</small></span>";
      grid.appendChild(o);
    }

    pop.appendChild(head);
    pop.appendChild(grid);
    wrap.appendChild(btn);
    wrap.appendChild(pop);
    navCta.insertBefore(wrap, navCta.firstChild);

    if (!document.querySelector(".mt-note")) {
      var banner = document.createElement("div");
      banner.className = "mt-note";
      document.body.insertBefore(banner, document.body.firstChild);
    }

    btn.addEventListener("click", function (e) {
      e.stopPropagation();
      pop.classList.toggle("open");
      if (pop.classList.contains("open")) {
        var inp = pop.querySelector(".lang-search");
        if (inp) { inp.value = ""; filter(""); inp.focus(); }
      }
    });

    function filter(q) {
      var s = (q || "").trim().toLowerCase();
      var items = grid.querySelectorAll(".lang-opt");
      for (var k = 0; k < items.length; k++) {
        var hay = items[k].getAttribute("data-q") || "";
        items[k].style.display = (!s || hay.indexOf(s) !== -1) ? "" : "none";
      }
    }

    pop.querySelector(".lang-search").addEventListener("input", function (e) {
      filter(e.target.value);
    });

    grid.addEventListener("click", function (e) {
      var t = e.target.closest(".lang-opt");
      if (!t) return;
      pop.classList.remove("open");
      use(t.getAttribute("data-code"), true);
    });

    document.addEventListener("click", function (e) {
      var setLink = e.target.closest("[data-set-lang]");
      if (setLink) {
        e.preventDefault();
        use(setLink.getAttribute("data-set-lang"), true);
        return;
      }
      if (!wrap.contains(e.target)) pop.classList.remove("open");
    });

    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") pop.classList.remove("open");
    });
  }

  function initMobileMenu() {
    var header = document.querySelector(".site-header");
    var nav = header && header.querySelector(".nav");
    var links = header && header.querySelector(".nav-links");
    var cta = header && header.querySelector(".nav-cta");
    if (!header || !nav || !links || !cta) return;

    var toggle = document.createElement("button");
    toggle.type = "button";
    toggle.className = "menu-toggle";
    toggle.setAttribute("aria-label", "Menu");
    toggle.setAttribute("aria-expanded", "false");
    toggle.innerHTML =
      '<svg class="ico-bars" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round">' +
      '<path d="M4 7h16M4 12h16M4 17h16"/></svg>' +
      '<svg class="ico-close" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round">' +
      '<path d="M6 6l12 12M18 6L6 18"/></svg>';
    cta.appendChild(toggle);

    function setOpen(open) {
      header.classList.toggle("menu-open", open);
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    }

    toggle.addEventListener("click", function (e) {
      e.stopPropagation();
      setOpen(!header.classList.contains("menu-open"));
    });

    links.addEventListener("click", function (e) {
      if (e.target.closest("a")) setOpen(false);
    });

    document.addEventListener("click", function (e) {
      if (!header.contains(e.target)) setOpen(false);
    });

    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") setOpen(false);
    });
  }

  function init() {
    buildPicker();
    initMobileMenu();
    snapshotBase();
    var initial = detectInitial();
    if (initial !== "en") {
      var q = null;
      try { q = new URLSearchParams(location.search).get("lang"); } catch (_) {}
      use(initial, Boolean(q));
    } else {
      applyScreens("en", cache.en || baseStrings);
    }

    try {
      var hasToken =
        localStorage.getItem("flutter.access_token") ||
        localStorage.getItem("access_token") ||
        localStorage.getItem("flutter.auth_token");
      if (hasToken) {
        var ctas = document.querySelectorAll("[data-app-cta]");
        for (var i = 0; i < ctas.length; i++) ctas[i].setAttribute("href", "/dashboard");
      }
    } catch (_) {}
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
