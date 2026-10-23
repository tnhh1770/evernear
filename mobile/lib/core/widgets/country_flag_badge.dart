import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders an accurate, crisp vector national flag for a 2-letter ISO 3166-1
/// alpha-2 country code (or language code fallback) on all platforms
/// (including Windows, Linux, and Web where Unicode flag emojis often render
/// as plain 2-letter ASCII codes).
class CountryFlagBadge extends StatelessWidget {
  final String countryCode;
  final double width;
  final double height;
  final double borderRadius;

  const CountryFlagBadge({
    super.key,
    required this.countryCode,
    this.width = 24,
    this.height = 16,
    this.borderRadius = 4,
  });

  /// Resolves an ISO 639-1 language code to its canonical ISO 3166-1 alpha-2 country code.
  static String countryForLanguage(String langCode) {
    switch (langCode.toLowerCase().trim()) {
      case 'en':
        return 'US';
      case 'vi':
        return 'VN';
      case 'fr':
        return 'FR';
      case 'de':
        return 'DE';
      case 'es':
      case 'eu':
      case 'gl':
        return 'ES';
      case 'pt':
        return 'PT';
      case 'ru':
        return 'RU';
      case 'ja':
        return 'JP';
      case 'ko':
        return 'KR';
      case 'zh':
        return 'CN';
      case 'th':
        return 'TH';
      case 'id':
        return 'ID';
      case 'ar':
        return 'SA';
      case 'hi':
      case 'ta':
      case 'te':
      case 'mr':
        return 'IN';
      case 'it':
        return 'IT';
      case 'nl':
        return 'NL';
      case 'pl':
        return 'PL';
      case 'tr':
        return 'TR';
      case 'uk':
        return 'UA';
      case 'el':
        return 'GR';
      case 'sv':
        return 'SE';
      case 'no':
        return 'NO';
      case 'da':
        return 'DK';
      case 'fi':
        return 'FI';
      case 'cs':
        return 'CZ';
      case 'hu':
        return 'HU';
      case 'ro':
        return 'RO';
      case 'bg':
        return 'BG';
      case 'hr':
        return 'HR';
      case 'sr':
        return 'RS';
      case 'sk':
        return 'SK';
      case 'sl':
        return 'SI';
      case 'lt':
        return 'LT';
      case 'lv':
        return 'LV';
      case 'et':
        return 'EE';
      case 'he':
        return 'IL';
      case 'fa':
        return 'IR';
      case 'ur':
        return 'PK';
      case 'bn':
        return 'BD';
      case 'ms':
        return 'MY';
      case 'tl':
      case 'fil':
        return 'PH';
      case 'my':
        return 'MM';
      case 'km':
        return 'KH';
      case 'lo':
        return 'LA';
      case 'am':
        return 'ET';
      case 'sw':
        return 'KE';
      case 'af':
        return 'ZA';
      case 'ca':
        return 'AD';
      case 'is':
        return 'IS';
      case 'ga':
        return 'IE';
      case 'cy':
        return 'GB';
      case 'mn':
        return 'MN';
      case 'kk':
        return 'KZ';
      case 'uz':
        return 'UZ';
      case 'az':
        return 'AZ';
      default:
        return 'US';
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalized = countryCode.trim().toUpperCase();
    return Semantics(
      label: 'Flag $normalized',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: const Color(0x26000000),
            width: 0.75,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            (borderRadius - 0.5).clamp(0.0, borderRadius),
          ),
          child: CustomPaint(
            size: Size(width, height),
            painter: _NationalFlagPainter(normalized),
          ),
        ),
      ),
    );
  }
}

class _NationalFlagPainter extends CustomPainter {
  final String code;

  const _NationalFlagPainter(this.code);

  void _hStripes(Canvas c, Size s, List<Color> colors, [List<double>? weights]) {
    final total = weights != null
        ? weights.fold<double>(0, (a, b) => a + b)
        : colors.length.toDouble();
    double y = 0;
    final p = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < colors.length; i++) {
      final h = s.height * ((weights != null ? weights[i] : 1.0) / total);
      p.color = colors[i];
      c.drawRect(Rect.fromLTWH(0, y, s.width, h + 0.4), p);
      y += h;
    }
  }

  void _vStripes(Canvas c, Size s, List<Color> colors, [List<double>? weights]) {
    final total = weights != null
        ? weights.fold<double>(0, (a, b) => a + b)
        : colors.length.toDouble();
    double x = 0;
    final p = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < colors.length; i++) {
      final w = s.width * ((weights != null ? weights[i] : 1.0) / total);
      p.color = colors[i];
      c.drawRect(Rect.fromLTWH(x, 0, w + 0.4, s.height), p);
      x += w;
    }
  }

  void _nordicCross(
    Canvas c,
    Size s, {
    required Color bg,
    required Color cross,
    Color? border,
  }) {
    final p = Paint()..style = PaintingStyle.fill;
    p.color = bg;
    c.drawRect(Offset.zero & s, p);
    final cx = s.width * 0.34;
    final cy = s.height * 0.5;
    if (border != null) {
      p.color = border;
      final bw = s.height * 0.28;
      c.drawRect(Rect.fromLTWH(cx - bw / 2, 0, bw, s.height), p);
      c.drawRect(Rect.fromLTWH(0, cy - bw / 2, s.width, bw), p);
    }
    p.color = cross;
    final cw = s.height * 0.16;
    c.drawRect(Rect.fromLTWH(cx - cw / 2, 0, cw, s.height), p);
    c.drawRect(Rect.fromLTWH(0, cy - cw / 2, s.width, cw), p);
  }

  void _drawStar(Canvas c, Offset center, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final rad = (i.isEven ? r : r * 0.4) * 1.0;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(
        center.dx + rad * math.cos(angle),
        center.dy + rad * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    c.drawPath(path, Paint()..color = color);
  }

  void _drawCrescentAndStar(
    Canvas c,
    Offset center,
    double outerR,
    Color bgColor,
    Color fgColor,
  ) {
    final p = Paint()..style = PaintingStyle.fill;
    p.color = fgColor;
    c.drawCircle(center, outerR, p);
    p.color = bgColor;
    c.drawCircle(
      Offset(center.dx + outerR * 0.28, center.dy),
      outerR * 0.8,
      p,
    );
    _drawStar(
      c,
      Offset(center.dx + outerR * 0.72, center.dy),
      outerR * 0.42,
      fgColor,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    switch (code) {
      case 'US':
        // 13 red & white stripes + blue canton with stars
        final stripes = List<Color>.generate(
          13,
          (i) => i.isEven ? const Color(0xFFB22234) : Colors.white,
        );
        _hStripes(canvas, size, stripes);
        p.color = const Color(0xFF3C3B6E);
        final cw = size.width * 0.44;
        final ch = size.height * (7 / 13);
        canvas.drawRect(Rect.fromLTWH(0, 0, cw, ch), p);
        p.color = Colors.white;
        for (int r = 0; r < 3; r++) {
          for (int col = 0; col < 4; col++) {
            canvas.drawCircle(
              Offset(cw * (0.16 + col * 0.22), ch * (0.22 + r * 0.28)),
              size.height * 0.032,
              p,
            );
          }
        }
        break;

      case 'VN':
        p.color = const Color(0xFFDA251D);
        canvas.drawRect(Offset.zero & size, p);
        _drawStar(
          canvas,
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.32,
          const Color(0xFFFFCD00),
        );
        break;

      case 'FR':
        _vStripes(canvas, size, const [
          Color(0xFF002395),
          Colors.white,
          Color(0xFFED2939),
        ]);
        break;

      case 'DE':
        _hStripes(canvas, size, const [
          Color(0xFF000000),
          Color(0xFFDD0000),
          Color(0xFFFFCE00),
        ]);
        break;

      case 'ES':
        _hStripes(
          canvas,
          size,
          const [Color(0xFFAA151B), Color(0xFFF1BF00), Color(0xFFAA151B)],
          const [1, 2, 1],
        );
        p.color = const Color(0xFFAA151B);
        canvas.drawCircle(
          Offset(size.width * 0.32, size.height * 0.5),
          size.height * 0.13,
          p,
        );
        break;

      case 'PT':
        _vStripes(
          canvas,
          size,
          const [Color(0xFF006600), Color(0xFFFF0000)],
          const [2, 3],
        );
        p.color = const Color(0xFFFFCC00);
        canvas.drawCircle(
          Offset(size.width * 0.4, size.height * 0.5),
          size.height * 0.2,
          p,
        );
        p.color = Colors.white;
        canvas.drawCircle(
          Offset(size.width * 0.4, size.height * 0.5),
          size.height * 0.11,
          p,
        );
        break;

      case 'BR':
        p.color = const Color(0xFF009B3A);
        canvas.drawRect(Offset.zero & size, p);
        final diamond = Path()
          ..moveTo(size.width * 0.5, size.height * 0.14)
          ..lineTo(size.width * 0.88, size.height * 0.5)
          ..lineTo(size.width * 0.5, size.height * 0.86)
          ..lineTo(size.width * 0.12, size.height * 0.5)
          ..close();
        p.color = const Color(0xFFFEDF00);
        canvas.drawPath(diamond, p);
        p.color = const Color(0xFF002776);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.21,
          p,
        );
        break;

      case 'RU':
        _hStripes(canvas, size, const [
          Colors.white,
          Color(0xFF0039A6),
          Color(0xFFD52B1E),
        ]);
        break;

      case 'JP':
        p.color = Colors.white;
        canvas.drawRect(Offset.zero & size, p);
        p.color = const Color(0xFFBC002D);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.3,
          p,
        );
        break;

      case 'KR':
        p.color = Colors.white;
        canvas.drawRect(Offset.zero & size, p);
        final center = Offset(size.width * 0.5, size.height * 0.5);
        final r = size.height * 0.26;
        p.color = const Color(0xFFCD2E3A);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          math.pi,
          math.pi,
          true,
          p,
        );
        p.color = const Color(0xFF0047A0);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          0,
          math.pi,
          true,
          p,
        );
        break;

      case 'CN':
        p.color = const Color(0xFFEE1C25);
        canvas.drawRect(Offset.zero & size, p);
        _drawStar(
          canvas,
          Offset(size.width * 0.22, size.height * 0.32),
          size.height * 0.18,
          const Color(0xFFFFFF00),
        );
        for (final pos in const [
          Offset(0.38, 0.16),
          Offset(0.44, 0.26),
          Offset(0.44, 0.40),
          Offset(0.38, 0.50),
        ]) {
          _drawStar(
            canvas,
            Offset(size.width * pos.dx, size.height * pos.dy),
            size.height * 0.06,
            const Color(0xFFFFFF00),
          );
        }
        break;

      case 'TH':
        _hStripes(
          canvas,
          size,
          const [
            Color(0xFFA51931),
            Colors.white,
            Color(0xFF2D2A4A),
            Colors.white,
            Color(0xFFA51931),
          ],
          const [1, 1, 2, 1, 1],
        );
        break;

      case 'ID':
        _hStripes(canvas, size, const [Color(0xFFFF0000), Colors.white]);
        break;

      case 'SA':
        p.color = const Color(0xFF006C35);
        canvas.drawRect(Offset.zero & size, p);
        p.color = Colors.white;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * 0.22,
              size.height * 0.32,
              size.width * 0.56,
              size.height * 0.16,
            ),
            const Radius.circular(1),
          ),
          p,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.26,
            size.height * 0.62,
            size.width * 0.48,
            size.height * 0.07,
          ),
          p,
        );
        break;

      case 'EG':
        _hStripes(canvas, size, const [
          Color(0xFFCE1126),
          Colors.white,
          Color(0xFF000000),
        ]);
        p.color = const Color(0xFFC09300);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.1,
          p,
        );
        break;

      case 'IN':
        _hStripes(canvas, size, const [
          Color(0xFFFF9933),
          Colors.white,
          Color(0xFF138808),
        ]);
        p.color = const Color(0xFF000080);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.13,
          p,
        );
        break;

      case 'IT':
        _vStripes(canvas, size, const [
          Color(0xFF009246),
          Colors.white,
          Color(0xFFCE2B37),
        ]);
        break;

      case 'NL':
        _hStripes(canvas, size, const [
          Color(0xFFAE1C28),
          Colors.white,
          Color(0xFF21468B),
        ]);
        break;

      case 'PL':
        _hStripes(canvas, size, const [Colors.white, Color(0xFFDC143C)]);
        break;

      case 'TR':
        const bg = Color(0xFFE30A17);
        p.color = bg;
        canvas.drawRect(Offset.zero & size, p);
        _drawCrescentAndStar(
          canvas,
          Offset(size.width * 0.42, size.height * 0.5),
          size.height * 0.24,
          bg,
          Colors.white,
        );
        break;

      case 'UA':
        _hStripes(canvas, size, const [Color(0xFF0057B7), Color(0xFFFFD700)]);
        break;

      case 'GR':
        final stripes = List<Color>.generate(
          9,
          (i) => i.isEven ? const Color(0xFF0D5EAF) : Colors.white,
        );
        _hStripes(canvas, size, stripes);
        final cw = size.height * (5 / 9);
        p.color = const Color(0xFF0D5EAF);
        canvas.drawRect(Rect.fromLTWH(0, 0, cw, cw), p);
        p.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(cw * 0.4, 0, cw * 0.2, cw), p);
        canvas.drawRect(Rect.fromLTWH(0, cw * 0.4, cw, cw * 0.2), p);
        break;

      case 'SE':
        _nordicCross(
          canvas,
          size,
          bg: const Color(0xFF006AA7),
          cross: const Color(0xFFFECC02),
        );
        break;

      case 'NO':
        _nordicCross(
          canvas,
          size,
          bg: const Color(0xFFBA0C2F),
          cross: const Color(0xFF00205B),
          border: Colors.white,
        );
        break;

      case 'DK':
        _nordicCross(
          canvas,
          size,
          bg: const Color(0xFFC8102E),
          cross: Colors.white,
        );
        break;

      case 'FI':
        _nordicCross(
          canvas,
          size,
          bg: Colors.white,
          cross: const Color(0xFF003580),
        );
        break;

      case 'IS':
        _nordicCross(
          canvas,
          size,
          bg: const Color(0xFF02529C),
          cross: const Color(0xFFDC1E35),
          border: Colors.white,
        );
        break;

      case 'CZ':
        _hStripes(canvas, size, const [Colors.white, Color(0xFFD7141A)]);
        final tri = Path()
          ..moveTo(0, 0)
          ..lineTo(size.width * 0.48, size.height * 0.5)
          ..lineTo(0, size.height)
          ..close();
        p.color = const Color(0xFF11457E);
        canvas.drawPath(tri, p);
        break;

      case 'HU':
        _hStripes(canvas, size, const [
          Color(0xFFCE2939),
          Colors.white,
          Color(0xFF477050),
        ]);
        break;

      case 'RO':
        _vStripes(canvas, size, const [
          Color(0xFF002B7F),
          Color(0xFFFCD116),
          Color(0xFFCE1126),
        ]);
        break;

      case 'AD':
        _vStripes(canvas, size, const [
          Color(0xFF10069F),
          Color(0xFFFEDD00),
          Color(0xFFD50032),
        ]);
        p.color = const Color(0xFFD50032);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.13,
          p,
        );
        break;

      case 'BG':
        _hStripes(canvas, size, const [
          Colors.white,
          Color(0xFF00966E),
          Color(0xFFD62612),
        ]);
        break;

      case 'HR':
        _hStripes(canvas, size, const [
          Color(0xFFFF0000),
          Colors.white,
          Color(0xFF171796),
        ]);
        p.color = const Color(0xFFFF0000);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.16,
          p,
        );
        break;

      case 'RS':
        _hStripes(canvas, size, const [
          Color(0xFFC6363C),
          Color(0xFF0C4076),
          Colors.white,
        ]);
        p.color = const Color(0xFFC6363C);
        canvas.drawCircle(
          Offset(size.width * 0.34, size.height * 0.5),
          size.height * 0.16,
          p,
        );
        break;

      case 'SK':
      case 'SI':
        _hStripes(canvas, size, const [
          Colors.white,
          Color(0xFF0B4EA2),
          Color(0xFFEE1C25),
        ]);
        p.color = const Color(0xFFEE1C25);
        canvas.drawCircle(
          Offset(size.width * 0.3, size.height * 0.45),
          size.height * 0.15,
          p,
        );
        break;

      case 'LT':
        _hStripes(canvas, size, const [
          Color(0xFFFDB913),
          Color(0xFF006A44),
          Color(0xFFC1272D),
        ]);
        break;

      case 'LV':
        _hStripes(
          canvas,
          size,
          const [Color(0xFF9E3039), Colors.white, Color(0xFF9E3039)],
          const [2, 1, 2],
        );
        break;

      case 'EE':
        _hStripes(canvas, size, const [
          Color(0xFF0072CE),
          Color(0xFF000000),
          Colors.white,
        ]);
        break;

      case 'IL':
        p.color = Colors.white;
        canvas.drawRect(Offset.zero & size, p);
        p.color = const Color(0xFF0038B8);
        canvas.drawRect(
          Rect.fromLTWH(0, size.height * 0.12, size.width, size.height * 0.15),
          p,
        );
        canvas.drawRect(
          Rect.fromLTWH(0, size.height * 0.73, size.width, size.height * 0.15),
          p,
        );
        _drawStar(
          canvas,
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.18,
          const Color(0xFF0038B8),
        );
        break;

      case 'IR':
        _hStripes(canvas, size, const [
          Color(0xFF239F40),
          Colors.white,
          Color(0xFFDA0000),
        ]);
        p.color = const Color(0xFFDA0000);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.12,
          p,
        );
        break;

      case 'PK':
        const bg = Color(0xFF01411C);
        p.color = bg;
        canvas.drawRect(Offset.zero & size, p);
        p.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.25, size.height), p);
        _drawCrescentAndStar(
          canvas,
          Offset(size.width * 0.58, size.height * 0.5),
          size.height * 0.24,
          bg,
          Colors.white,
        );
        break;

      case 'BD':
        p.color = const Color(0xFF006A4E);
        canvas.drawRect(Offset.zero & size, p);
        p.color = const Color(0xFFF42A41);
        canvas.drawCircle(
          Offset(size.width * 0.45, size.height * 0.5),
          size.height * 0.28,
          p,
        );
        break;

      case 'MY':
        final stripes = List<Color>.generate(
          14,
          (i) => i.isEven ? const Color(0xFFCC0001) : Colors.white,
        );
        _hStripes(canvas, size, stripes);
        const canton = Color(0xFF010066);
        p.color = canton;
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width * 0.5, size.height * (8 / 14)),
          p,
        );
        _drawCrescentAndStar(
          canvas,
          Offset(size.width * 0.22, size.height * 0.28),
          size.height * 0.18,
          canton,
          const Color(0xFFFFCC00),
        );
        break;

      case 'PH':
        _hStripes(canvas, size, const [Color(0xFF0038A8), Color(0xFFCE1126)]);
        final tri = Path()
          ..moveTo(0, 0)
          ..lineTo(size.width * 0.46, size.height * 0.5)
          ..lineTo(0, size.height)
          ..close();
        p.color = Colors.white;
        canvas.drawPath(tri, p);
        p.color = const Color(0xFFFCD116);
        canvas.drawCircle(
          Offset(size.width * 0.16, size.height * 0.5),
          size.height * 0.12,
          p,
        );
        break;

      case 'MM':
        _hStripes(canvas, size, const [
          Color(0xFFFECB00),
          Color(0xFF34B233),
          Color(0xFFEA2839),
        ]);
        _drawStar(
          canvas,
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.3,
          Colors.white,
        );
        break;

      case 'KH':
        _hStripes(
          canvas,
          size,
          const [Color(0xFF032EA1), Color(0xFFE00025), Color(0xFF032EA1)],
          const [1, 2, 1],
        );
        p.color = Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.35,
            size.height * 0.36,
            size.width * 0.3,
            size.height * 0.28,
          ),
          p,
        );
        break;

      case 'LA':
        _hStripes(
          canvas,
          size,
          const [Color(0xFFCE1126), Color(0xFF002868), Color(0xFFCE1126)],
          const [1, 2, 1],
        );
        p.color = Colors.white;
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.2,
          p,
        );
        break;

      case 'ET':
        _hStripes(canvas, size, const [
          Color(0xFF078930),
          Color(0xFFFCDD09),
          Color(0xFFDA121A),
        ]);
        p.color = const Color(0xFF0F47AF);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.22,
          p,
        );
        _drawStar(
          canvas,
          Offset(size.width * 0.5, size.height * 0.5),
          size.height * 0.15,
          const Color(0xFFFCDD09),
        );
        break;

      case 'KE':
        _hStripes(
          canvas,
          size,
          const [
            Color(0xFF000000),
            Colors.white,
            Color(0xFFBB0000),
            Colors.white,
            Color(0xFF006600),
          ],
          const [4, 1, 4, 1, 4],
        );
        p.color = const Color(0xFFBB0000);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * 0.5, size.height * 0.5),
            width: size.width * 0.2,
            height: size.height * 0.45,
          ),
          p,
        );
        break;

      case 'TZ':
        p.color = const Color(0xFF1EB53A);
        canvas.drawRect(Offset.zero & size, p);
        final lower = Path()
          ..moveTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        p.color = const Color(0xFF00A3DD);
        canvas.drawPath(lower, p);
        final band = Paint()
          ..color = const Color(0xFF000000)
          ..strokeWidth = size.height * 0.26
          ..style = PaintingStyle.stroke;
        final borderBand = Paint()
          ..color = const Color(0xFFFCD116)
          ..strokeWidth = size.height * 0.36
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), borderBand);
        canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), band);
        break;

      case 'ZA':
        _hStripes(canvas, size, const [
          Color(0xFFE03C31),
          Colors.white,
          Color(0xFF007749),
          Colors.white,
          Color(0xFF001489),
        ], const [3, 1, 2, 1, 3]);
        final tri = Path()
          ..moveTo(0, 0)
          ..lineTo(size.width * 0.4, size.height * 0.5)
          ..lineTo(0, size.height)
          ..close();
        p.color = const Color(0xFF007749);
        canvas.drawPath(tri, p);
        final innerTri = Path()
          ..moveTo(0, size.height * 0.18)
          ..lineTo(size.width * 0.25, size.height * 0.5)
          ..lineTo(0, size.height * 0.82)
          ..close();
        p.color = const Color(0xFF000000);
        canvas.drawPath(innerTri, p);
        break;

      case 'IE':
        _vStripes(canvas, size, const [
          Color(0xFF169B62),
          Colors.white,
          Color(0xFFFF883E),
        ]);
        break;

      case 'GB':
        p.color = const Color(0xFF012169);
        canvas.drawRect(Offset.zero & size, p);
        final diagW = Paint()
          ..color = Colors.white
          ..strokeWidth = size.height * 0.22;
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), diagW);
        canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), diagW);
        final diagR = Paint()
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = size.height * 0.1;
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), diagR);
        canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), diagR);
        p.color = Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.38, 0, size.width * 0.24, size.height),
          p,
        );
        canvas.drawRect(
          Rect.fromLTWH(0, size.height * 0.34, size.width, size.height * 0.32),
          p,
        );
        p.color = const Color(0xFFC8102E);
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.43, 0, size.width * 0.14, size.height),
          p,
        );
        canvas.drawRect(
          Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2),
          p,
        );
        break;

      case 'MN':
        _vStripes(canvas, size, const [
          Color(0xFFDA2032),
          Color(0xFF0066B3),
          Color(0xFFDA2032),
        ]);
        p.color = const Color(0xFFFFD900);
        canvas.drawCircle(
          Offset(size.width * 0.16, size.height * 0.5),
          size.height * 0.14,
          p,
        );
        break;

      case 'KZ':
        p.color = const Color(0xFF00AFCA);
        canvas.drawRect(Offset.zero & size, p);
        p.color = const Color(0xFFFEC50C);
        canvas.drawCircle(
          Offset(size.width * 0.52, size.height * 0.5),
          size.height * 0.22,
          p,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.08,
            size.height * 0.12,
            size.width * 0.06,
            size.height * 0.76,
          ),
          p,
        );
        break;

      case 'UZ':
        _hStripes(
          canvas,
          size,
          const [
            Color(0xFF0099B5),
            Color(0xFFCE1126),
            Colors.white,
            Color(0xFFCE1126),
            Color(0xFF1EB53A),
          ],
          const [5, 1, 5, 1, 5],
        );
        break;

      case 'AZ':
        _hStripes(canvas, size, const [
          Color(0xFF0092BC),
          Color(0xFFE4002B),
          Color(0xFF00AF66),
        ]);
        _drawCrescentAndStar(
          canvas,
          Offset(size.width * 0.48, size.height * 0.5),
          size.height * 0.15,
          const Color(0xFFE4002B),
          Colors.white,
        );
        break;

      default:
        p.color = const Color(0xFF2D6A4F);
        canvas.drawRect(Offset.zero & size, p);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _NationalFlagPainter oldDelegate) =>
      oldDelegate.code != code;
}
