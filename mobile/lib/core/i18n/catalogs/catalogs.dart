import 'vi_catalog.dart';
import 'en_catalog.dart';
import 'fr_catalog.dart';
import 'de_catalog.dart';
import 'es_catalog.dart';
import 'pt_catalog.dart';
import 'ru_catalog.dart';
import 'ja_catalog.dart';
import 'ko_catalog.dart';
import 'zh_catalog.dart';
import 'th_catalog.dart';
import 'id_catalog.dart';
import 'ar_catalog.dart';
import 'hi_catalog.dart';
import 'it_catalog.dart';
import 'nl_catalog.dart';
import 'pl_catalog.dart';
import 'tr_catalog.dart';
import 'uk_catalog.dart';
import 'el_catalog.dart';
import 'sv_catalog.dart';
import 'no_catalog.dart';
import 'da_catalog.dart';
import 'fi_catalog.dart';
import 'cs_catalog.dart';
import 'hu_catalog.dart';
import 'ro_catalog.dart';
import 'bg_catalog.dart';
import 'hr_catalog.dart';
import 'sr_catalog.dart';
import 'sk_catalog.dart';
import 'sl_catalog.dart';
import 'lt_catalog.dart';
import 'lv_catalog.dart';
import 'et_catalog.dart';
import 'he_catalog.dart';
import 'fa_catalog.dart';
import 'ur_catalog.dart';
import 'bn_catalog.dart';
import 'ta_catalog.dart';
import 'te_catalog.dart';
import 'mr_catalog.dart';
import 'ms_catalog.dart';
import 'tl_catalog.dart';
import 'my_catalog.dart';
import 'km_catalog.dart';
import 'lo_catalog.dart';
import 'am_catalog.dart';
import 'sw_catalog.dart';
import 'af_catalog.dart';
import 'ca_catalog.dart';
import 'eu_catalog.dart';
import 'gl_catalog.dart';
import 'is_catalog.dart';
import 'ga_catalog.dart';
import 'cy_catalog.dart';
import 'mn_catalog.dart';
import 'kk_catalog.dart';
import 'uz_catalog.dart';
import 'az_catalog.dart';

export 'vi_catalog.dart';
export 'en_catalog.dart';
export 'fr_catalog.dart';
export 'de_catalog.dart';
export 'es_catalog.dart';
export 'pt_catalog.dart';
export 'ru_catalog.dart';
export 'ja_catalog.dart';
export 'ko_catalog.dart';
export 'zh_catalog.dart';
export 'th_catalog.dart';
export 'id_catalog.dart';
export 'ar_catalog.dart';
export 'hi_catalog.dart';
export 'it_catalog.dart';
export 'nl_catalog.dart';
export 'pl_catalog.dart';
export 'tr_catalog.dart';
export 'uk_catalog.dart';
export 'el_catalog.dart';
export 'sv_catalog.dart';
export 'no_catalog.dart';
export 'da_catalog.dart';
export 'fi_catalog.dart';
export 'cs_catalog.dart';
export 'hu_catalog.dart';
export 'ro_catalog.dart';
export 'bg_catalog.dart';
export 'hr_catalog.dart';
export 'sr_catalog.dart';
export 'sk_catalog.dart';
export 'sl_catalog.dart';
export 'lt_catalog.dart';
export 'lv_catalog.dart';
export 'et_catalog.dart';
export 'he_catalog.dart';
export 'fa_catalog.dart';
export 'ur_catalog.dart';
export 'bn_catalog.dart';
export 'ta_catalog.dart';
export 'te_catalog.dart';
export 'mr_catalog.dart';
export 'ms_catalog.dart';
export 'tl_catalog.dart';
export 'my_catalog.dart';
export 'km_catalog.dart';
export 'lo_catalog.dart';
export 'am_catalog.dart';
export 'sw_catalog.dart';
export 'af_catalog.dart';
export 'ca_catalog.dart';
export 'eu_catalog.dart';
export 'gl_catalog.dart';
export 'is_catalog.dart';
export 'ga_catalog.dart';
export 'cy_catalog.dart';
export 'mn_catalog.dart';
export 'kk_catalog.dart';
export 'uz_catalog.dart';
export 'az_catalog.dart';

class DynamicCatalogs {
  DynamicCatalogs._();

  /// 14 Tier-1 pre-bundled languages with full key parity
  static const Map<String, Map<String, String>> _catalogs = {
    'en': enCatalog,
    'vi': viCatalog,
    'fr': frCatalog,
    'de': deCatalog,
    'es': esCatalog,
    'pt': ptCatalog,
    'ru': ruCatalog,
    'ja': jaCatalog,
    'ko': koCatalog,
    'zh': zhCatalog,
    'th': thCatalog,
    'id': idCatalog,
    'ar': arCatalog,
    'hi': hiCatalog,
  };

  /// 46 Extended world language catalogs
  static const Map<String, Map<String, String>> extendedCatalogs = {
    'it': itCatalog,
    'nl': nlCatalog,
    'pl': plCatalog,
    'tr': trCatalog,
    'uk': ukCatalog,
    'el': elCatalog,
    'sv': svCatalog,
    'no': noCatalog,
    'da': daCatalog,
    'fi': fiCatalog,
    'cs': csCatalog,
    'hu': huCatalog,
    'ro': roCatalog,
    'bg': bgCatalog,
    'hr': hrCatalog,
    'sr': srCatalog,
    'sk': skCatalog,
    'sl': slCatalog,
    'lt': ltCatalog,
    'lv': lvCatalog,
    'et': etCatalog,
    'he': heCatalog,
    'fa': faCatalog,
    'ur': urCatalog,
    'bn': bnCatalog,
    'ta': taCatalog,
    'te': teCatalog,
    'mr': mrCatalog,
    'ms': msCatalog,
    'tl': tlCatalog,
    'my': myCatalog,
    'km': kmCatalog,
    'lo': loCatalog,
    'am': amCatalog,
    'sw': swCatalog,
    'af': afCatalog,
    'ca': caCatalog,
    'eu': euCatalog,
    'gl': glCatalog,
    'is': isCatalog,
    'ga': gaCatalog,
    'cy': cyCatalog,
    'mn': mnCatalog,
    'kk': kkCatalog,
    'uz': uzCatalog,
    'az': azCatalog,
  };

  /// All 60 raw catalogs without fallback merging
  static const Map<String, Map<String, String>> allRawCatalogs = {
    ..._catalogs,
    ...extendedCatalogs,
  };

  /// Retrieve catalog map for language code. Returns null if not registered in Tier 1.
  static Map<String, String>? getCatalog(String code) {
    final lower = code.toLowerCase();
    final raw = _catalogs[lower];
    if (raw == null) return null;
    if (lower == 'vi' || lower == 'en') return raw;
    return <String, String>{...enCatalog, ...raw};
  }

  /// Retrieve any catalog map (Tier 1 or extended Tier 2).
  static Map<String, String>? getAnyCatalog(String code) {
    final lower = code.toLowerCase();
    final tier1 = getCatalog(lower);
    if (tier1 != null) return tier1;
    final ext = extendedCatalogs[lower];
    if (ext == null) return null;
    return <String, String>{...enCatalog, ...ext};
  }
}
