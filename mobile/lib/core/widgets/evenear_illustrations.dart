import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Custom painted Evenear brand logo: dual-tone forest/mint green heart with a white ECG pulse wave.
class EvenearHeartLogo extends StatelessWidget {
  final double size;
  final bool showHalo;

  const EvenearHeartLogo({
    super.key,
    this.size = 52,
    this.showHalo = false,
  });

  @override
  Widget build(BuildContext context) {
    final logo = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EvenearHeartLogoPainter(),
      ),
    );
    if (!showHalo) return logo;
    return Container(
      width: size * 1.4,
      height: size * 1.4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight.withValues(alpha: 0.7),
      ),
      child: logo,
    );
  }
}

class _EvenearHeartLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final heartPath = Path()
      ..moveTo(w * 0.50, h * 0.88)
      ..cubicTo(
        w * 0.10,
        h * 0.64,
        w * 0.02,
        h * 0.28,
        w * 0.26,
        h * 0.14,
      )
      ..cubicTo(
        w * 0.39,
        h * 0.07,
        w * 0.50,
        h * 0.19,
        w * 0.50,
        h * 0.26,
      )
      ..cubicTo(
        w * 0.50,
        h * 0.19,
        w * 0.61,
        h * 0.07,
        w * 0.74,
        h * 0.14,
      )
      ..cubicTo(
        w * 0.98,
        h * 0.28,
        w * 0.90,
        h * 0.64,
        w * 0.50,
        h * 0.88,
      )
      ..close();

    // Subtle soft drop shadow
    canvas.drawShadow(
      heartPath,
      const Color(0xFF1D5547).withValues(alpha: 0.18),
      4,
      false,
    );

    canvas.save();
    canvas.clipPath(heartPath);

    // 1. Base fill (left lobe & bottom point): lush leaf green -> deep forest teal
    final leftGradientPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF63C184),
          Color(0xFF398D63),
          Color(0xFF1D5646),
        ],
        stops: [0.0, 0.52, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), leftGradientPaint);

    // 2. Soft lower-left leaf facet highlight
    final lowerLeftFacet = Path()
      ..moveTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.34, h * 0.80)
      ..lineTo(w * 0.50, h * 0.90)
      ..lineTo(w * 0.68, h * 0.72)
      ..close();
    canvas.drawPath(
      lowerLeftFacet,
      Paint()..color = const Color(0xFF195142),
    );

    // 3. Top-right lobe upper-inner aqua/mint facet
    final topRightMintFacet = Path()
      ..moveTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.86, h * 0.10)
      ..lineTo(w * 0.50, h * 0.54)
      ..close();
    final mintPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFF8CD2C4),
          Color(0xFF6CB5A6),
        ],
      ).createShader(Rect.fromLTWH(w * 0.48, h * 0.10, w * 0.40, h * 0.46));
    canvas.drawPath(topRightMintFacet, mintPaint);

    // 4. Right lobe deep teal-forest folded leaf facet
    final rightDeepFacet = Path()
      ..moveTo(w * 0.83, h * 0.14)
      ..lineTo(w * 1.0, h * 0.30)
      ..lineTo(w * 0.95, h * 0.74)
      ..lineTo(w * 0.68, h * 0.72)
      ..lineTo(w * 0.50, h * 0.54)
      ..close();
    final rightDeepPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF185145),
          Color(0xFF2B6F60),
        ],
      ).createShader(Rect.fromLTWH(w * 0.50, h * 0.14, w * 0.50, h * 0.60));
    canvas.drawPath(rightDeepFacet, rightDeepPaint);

    // 5. Subtle left-inner vein highlight line
    final leftVeinPaint = Paint()
      ..color = const Color(0xFFA8DFB9).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, w * 0.028)
      ..strokeCap = StrokeCap.round;
    final leftVeinPath = Path()
      ..moveTo(w * 0.36, h * 0.73)
      ..quadraticBezierTo(w * 0.39, h * 0.63, w * 0.42, h * 0.57);
    canvas.drawPath(leftVeinPath, leftVeinPaint);

    // 6. Signature white stem channel from top cleft down to center and out lower-right
    final whiteStemPaint = Paint()
      ..color = const Color(0xFFFBFAF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, w * 0.048)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final whiteStemPath = Path()
      ..moveTo(w * 0.50, h * 0.22)
      ..lineTo(w * 0.50, h * 0.54)
      ..quadraticBezierTo(w * 0.51, h * 0.58, w * 0.74, h * 0.73);
    canvas.drawPath(whiteStemPath, whiteStemPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Scenic nature illustration of an elderly couple sitting peacefully in a green landscape
/// (Matches 01_onboarding_welcome.png).
class OnboardingElderlyCoupleIllustration extends StatelessWidget {
  final double height;

  const OnboardingElderlyCoupleIllustration({
    super.key,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ElderlyCoupleNaturePainter(),
      ),
    );
  }
}

class _ElderlyCoupleNaturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));

    // 1. Warm ivory-cream sky background fading into page background
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFBFAF8),
          Color(0xFFFAF8F2),
          Color(0xFFF6F7F1),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Soft glowing sun on upper right
    final sunCenter = Offset(w * 0.71, h * 0.16);
    canvas.drawCircle(
      sunCenter,
      w * 0.075,
      Paint()..color = const Color(0xFFFEF7E6).withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      sunCenter,
      w * 0.048,
      Paint()..color = const Color(0xFFFDF2D6),
    );

    // 3. Distant misty mountains on the left & center
    final farMistMountain = Path()
      ..moveTo(0, h * 0.08)
      ..quadraticBezierTo(w * 0.07, h * 0.03, w * 0.15, h * 0.11)
      ..quadraticBezierTo(w * 0.25, h * 0.19, w * 0.42, h * 0.24)
      ..quadraticBezierTo(w * 0.56, h * 0.28, w * 0.68, h * 0.38)
      ..lineTo(0, h * 0.45)
      ..close();
    canvas.drawPath(
      farMistMountain,
      Paint()..color = const Color(0xFFEDEFE9),
    );

    final midMistMountain = Path()
      ..moveTo(0, h * 0.17)
      ..quadraticBezierTo(w * 0.12, h * 0.10, w * 0.23, h * 0.22)
      ..quadraticBezierTo(w * 0.36, h * 0.24, w * 0.46, h * 0.39)
      ..lineTo(w * 0.55, h * 0.52)
      ..lineTo(0, h * 0.56)
      ..close();
    canvas.drawPath(
      midMistMountain,
      Paint()..color = const Color(0xFFE3E9E0),
    );

    // Soft white mist band across left midground
    final mistBand = Path()
      ..moveTo(0, h * 0.29)
      ..quadraticBezierTo(w * 0.18, h * 0.26, w * 0.38, h * 0.34)
      ..quadraticBezierTo(w * 0.22, h * 0.37, 0, h * 0.35)
      ..close();
    canvas.drawPath(
      mistBand,
      Paint()..color = const Color(0xFFF7F8F3).withValues(alpha: 0.85),
    );

    // 4. Right background tall pale-olive tree canopy
    final rightBgCanopy = Path()
      ..moveTo(w * 0.77, h * 0.50)
      ..cubicTo(w * 0.73, h * 0.30, w * 0.79, h * 0.11, w * 0.90, h * 0.09)
      ..cubicTo(w * 0.96, h * 0.08, w * 1.0, h * 0.12, w, h * 0.16)
      ..lineTo(w, h * 0.58)
      ..close();
    final rightBgCanopyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFD2DDB5),
          Color(0xFFBDD0A2),
        ],
      ).createShader(Rect.fromLTWH(w * 0.74, h * 0.08, w * 0.26, h * 0.50));
    canvas.drawPath(rightBgCanopy, rightBgCanopyPaint);

    // 5. Center-right soft sage foliage hills behind couple
    final rightMidFoliage = Path()
      ..moveTo(w * 0.54, h * 0.62)
      ..cubicTo(w * 0.55, h * 0.44, w * 0.63, h * 0.34, w * 0.72, h * 0.36)
      ..cubicTo(w * 0.77, h * 0.27, w * 0.87, h * 0.29, w * 0.90, h * 0.44)
      ..lineTo(w * 0.90, h * 0.68)
      ..close();
    canvas.drawPath(
      rightMidFoliage,
      Paint()..color = const Color(0xFFC5DAC2),
    );

    // Distant pale lake/meadow strip in center
    canvas.drawRect(
      Rect.fromLTWH(w * 0.16, h * 0.56, w * 0.68, h * 0.22),
      Paint()..color = const Color(0xFFDCE7DA),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.22, h * 0.66, w * 0.30, h * 0.12),
      Paint()..color = const Color(0xFFF3F5EC),
    );

    // 6. Left midground round sage tree + slender trunk
    final leftMidTreeCenter = Offset(w * 0.22, h * 0.49);
    canvas.drawOval(
      Rect.fromCenter(
        center: leftMidTreeCenter,
        width: w * 0.17,
        height: h * 0.24,
      ),
      Paint()..color = const Color(0xFFA3C7A6),
    );
    final midTrunkPaint = Paint()
      ..color = const Color(0xFF53865B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final midTrunkPath = Path()
      ..moveTo(w * 0.22, h * 0.74)
      ..lineTo(w * 0.22, h * 0.45)
      ..moveTo(w * 0.22, h * 0.55)
      ..lineTo(w * 0.19, h * 0.49)
      ..moveTo(w * 0.22, h * 0.52)
      ..lineTo(w * 0.25, h * 0.47);
    canvas.drawPath(midTrunkPath, midTrunkPaint);

    // 7. Left foreground tall lush green bush/tree
    final leftFgTree = Path()
      ..moveTo(0, h * 0.46)
      ..cubicTo(w * 0.02, h * 0.30, w * 0.11, h * 0.28, w * 0.14, h * 0.45)
      ..cubicTo(w * 0.19, h * 0.50, w * 0.20, h * 0.66, w * 0.16, h * 0.77)
      ..lineTo(0, h * 0.75)
      ..close();
    final leftFgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF6BA262),
          Color(0xFF52884F),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.28, w * 0.20, h * 0.50));
    canvas.drawPath(leftFgTree, leftFgPaint);

    // Left foreground secondary lower bush mound
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.19, h * 0.75),
        width: w * 0.15,
        height: h * 0.13,
      ),
      Paint()..color = const Color(0xFF78AA69),
    );

    // Left foreground botanical trunk & branches
    final darkBranchPaint = Paint()
      ..color = const Color(0xFF2D5B34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final leftTreeBranches = Path()
      ..moveTo(w * 0.095, h * 0.75)
      ..lineTo(w * 0.095, h * 0.44)
      ..moveTo(w * 0.095, h * 0.64)
      ..lineTo(w * 0.055, h * 0.56)
      ..moveTo(w * 0.095, h * 0.59)
      ..lineTo(w * 0.135, h * 0.52)
      ..moveTo(w * 0.095, h * 0.52)
      ..lineTo(w * 0.065, h * 0.46);
    canvas.drawPath(leftTreeBranches, darkBranchPaint);

    // 8. Right foreground lush green bushes & branches
    // Upper-right branch lines in background tree
    final rightBgBranchPaint = Paint()
      ..color = const Color(0xFF6B8E67)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final rightBgBranches = Path()
      ..moveTo(w * 0.90, h * 0.44)
      ..lineTo(w * 0.90, h * 0.24)
      ..moveTo(w * 0.90, h * 0.36)
      ..lineTo(w * 0.86, h * 0.29)
      ..moveTo(w * 0.90, h * 0.33)
      ..lineTo(w * 0.94, h * 0.26);
    canvas.drawPath(rightBgBranches, rightBgBranchPaint);

    final rightFgTree = Path()
      ..moveTo(w * 0.76, h * 0.78)
      ..cubicTo(w * 0.75, h * 0.65, w * 0.81, h * 0.58, w * 0.84, h * 0.55)
      ..cubicTo(w * 0.84, h * 0.40, w * 0.92, h * 0.35, w, h * 0.37)
      ..lineTo(w, h * 0.76)
      ..close();
    final rightFgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF72A666),
          Color(0xFF538651),
        ],
      ).createShader(Rect.fromLTWH(w * 0.75, h * 0.35, w * 0.25, h * 0.44));
    canvas.drawPath(rightFgTree, rightFgPaint);

    // Soft mint-sage bush behind man's left shoulder
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.74, h * 0.67),
        width: w * 0.16,
        height: h * 0.16,
      ),
      Paint()..color = const Color(0xFF83B796),
    );

    final rightFgBranches = Path()
      ..moveTo(w * 0.92, h * 0.73)
      ..lineTo(w * 0.96, h * 0.53)
      ..moveTo(w * 0.94, h * 0.64)
      ..lineTo(w * 0.90, h * 0.56);
    canvas.drawPath(rightFgBranches, darkBranchPaint);

    // 9. Warm golden-sand stones/cushion beside the couple
    final leftStone = Path()
      ..moveTo(w * 0.22, h * 0.76)
      ..quadraticBezierTo(w * 0.27, h * 0.69, w * 0.35, h * 0.77)
      ..lineTo(w * 0.34, h * 0.83)
      ..lineTo(w * 0.22, h * 0.80)
      ..close();
    canvas.drawPath(leftStone, Paint()..color = const Color(0xFFC8BA84));

    final rightStone = Path()
      ..moveTo(w * 0.68, h * 0.76)
      ..quadraticBezierTo(w * 0.72, h * 0.73, w * 0.74, h * 0.78)
      ..lineTo(w * 0.68, h * 0.81)
      ..close();
    canvas.drawPath(rightStone, Paint()..color = const Color(0xFFD5BE82));

    // 10. THE ELDERLY COUPLE (Center focal point)
    // --- Elderly Man (Right, facing left toward woman) ---
    // Neck & head skin
    final manNeck = Path()
      ..moveTo(w * 0.565, h * 0.54)
      ..lineTo(w * 0.605, h * 0.54)
      ..lineTo(w * 0.61, h * 0.61)
      ..lineTo(w * 0.56, h * 0.61)
      ..close();
    canvas.drawPath(manNeck, Paint()..color = const Color(0xFFD0936A));

    // Man's head (three-quarter profile facing left)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.582, h * 0.495),
        width: w * 0.072,
        height: h * 0.115,
      ),
      Paint()..color = const Color(0xFFD99E74),
    );
    // Man's silver/white hair
    final manHair = Path()
      ..moveTo(w * 0.552, h * 0.465)
      ..cubicTo(w * 0.55, h * 0.41, w * 0.61, h * 0.41, w * 0.622, h * 0.465)
      ..cubicTo(w * 0.632, h * 0.495, w * 0.625, h * 0.535, w * 0.608, h * 0.54)
      ..cubicTo(w * 0.608, h * 0.50, w * 0.595, h * 0.475, w * 0.552, h * 0.465)
      ..close();
    canvas.drawPath(manHair, Paint()..color = const Color(0xFFF1F2EE));

    // Man's subtle facial details (brow, eye, warm smile facing left)
    final faceFeaturePaint = Paint()
      ..color = const Color(0xFF7D5035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.566, h * 0.492),
        width: w * 0.016,
        height: h * 0.012,
      ),
      0.1,
      math.pi * 0.8,
      false,
      faceFeaturePaint,
    );

    // Man's light undershirt at collar
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.582, h * 0.605),
        width: w * 0.05,
        height: h * 0.04,
      ),
      Paint()..color = const Color(0xFFE0EFE5),
    );

    // Man's sage-teal sweater/cardigan torso & sleeves
    final manTorso = Path()
      ..moveTo(w * 0.515, h * 0.78)
      ..cubicTo(w * 0.52, h * 0.65, w * 0.54, h * 0.585, w * 0.568, h * 0.585)
      ..lineTo(w * 0.582, h * 0.62)
      ..lineTo(w * 0.602, h * 0.585)
      ..cubicTo(w * 0.655, h * 0.59, w * 0.685, h * 0.66, w * 0.695, h * 0.81)
      ..lineTo(w * 0.515, h * 0.81)
      ..close();
    final manSweaterPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF7AB8A1),
          Color(0xFF5E9A84),
        ],
      ).createShader(Rect.fromLTWH(w * 0.51, h * 0.58, w * 0.19, h * 0.24));
    canvas.drawPath(manTorso, manSweaterPaint);

    // Man's sleeve & fold lines
    final manFoldPaint = Paint()
      ..color = const Color(0xFF497D6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final manFolds = Path()
      ..moveTo(w * 0.64, h * 0.66)
      ..lineTo(w * 0.645, h * 0.79)
      ..moveTo(w * 0.555, h * 0.67)
      ..lineTo(w * 0.535, h * 0.76)
      ..moveTo(w * 0.582, h * 0.62)
      ..lineTo(w * 0.578, h * 0.76);
    canvas.drawPath(manFolds, manFoldPaint);

    // --- Elderly Woman (Left, facing right toward man) ---
    // Woman's neck & face profile
    final womanNeck = Path()
      ..moveTo(w * 0.445, h * 0.55)
      ..lineTo(w * 0.48, h * 0.55)
      ..lineTo(w * 0.475, h * 0.62)
      ..lineTo(w * 0.435, h * 0.61)
      ..close();
    canvas.drawPath(womanNeck, Paint()..color = const Color(0xFFD2956A));

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.472, h * 0.51),
        width: w * 0.068,
        height: h * 0.11,
      ),
      Paint()..color = const Color(0xFFDC9F73),
    );

    // Woman's dark hair & low bun on left
    final womanHair = Path()
      ..moveTo(w * 0.498, h * 0.475)
      ..cubicTo(w * 0.49, h * 0.43, w * 0.435, h * 0.43, w * 0.43, h * 0.49)
      ..cubicTo(w * 0.425, h * 0.53, w * 0.435, h * 0.565, w * 0.455, h * 0.565)
      ..cubicTo(w * 0.465, h * 0.53, w * 0.475, h * 0.49, w * 0.498, h * 0.475)
      ..close();
    canvas.drawPath(womanHair, Paint()..color = const Color(0xFF233B30));
    // Woman's low bun
    canvas.drawCircle(
      Offset(w * 0.422, h * 0.542),
      w * 0.028,
      Paint()..color = const Color(0xFF233B30),
    );

    // Woman's eye/lash looking right
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.488, h * 0.505),
        width: w * 0.015,
        height: h * 0.012,
      ),
      0.1,
      math.pi * 0.8,
      false,
      faceFeaturePaint,
    );

    // Woman's warm mustard-ochre sweater & arm reaching toward man
    final womanTorso = Path()
      ..moveTo(w * 0.33, h * 0.83)
      ..cubicTo(w * 0.34, h * 0.69, w * 0.37, h * 0.60, w * 0.43, h * 0.59)
      ..cubicTo(w * 0.465, h * 0.59, w * 0.495, h * 0.63, w * 0.51, h * 0.74)
      ..lineTo(w * 0.53, h * 0.77)
      ..lineTo(w * 0.485, h * 0.83)
      ..close();
    final womanSweaterPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE0C56E),
          Color(0xFFD2B35B),
        ],
      ).createShader(Rect.fromLTWH(w * 0.33, h * 0.59, w * 0.20, h * 0.25));
    canvas.drawPath(womanTorso, womanSweaterPaint);

    // Woman's sleeve fold line
    final womanFoldPaint = Paint()
      ..color = const Color(0xFFB89943)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final womanFoldPath = Path()
      ..moveTo(w * 0.42, h * 0.67)
      ..quadraticBezierTo(w * 0.44, h * 0.75, w * 0.49, h * 0.78)
      ..moveTo(w * 0.38, h * 0.69)
      ..lineTo(w * 0.365, h * 0.81);
    canvas.drawPath(womanFoldPath, womanFoldPaint);

    // Couple's joined hands in the center
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.515, h * 0.775),
        width: w * 0.048,
        height: h * 0.035,
      ),
      Paint()..color = const Color(0xFFD89D72),
    );

    // Man's dark forest trousers in center foreground
    final trousersPath = Path()
      ..moveTo(w * 0.485, h * 0.83)
      ..quadraticBezierTo(w * 0.56, h * 0.78, w * 0.66, h * 0.80)
      ..lineTo(w * 0.64, h * 0.85)
      ..lineTo(w * 0.485, h * 0.85)
      ..close();
    canvas.drawPath(trousersPath, Paint()..color = const Color(0xFF234038));

    // 11. Sweeping white/cream foreground hills framing the bottom
    final fgSnowHill = Path()
      ..moveTo(0, h * 0.73)
      ..quadraticBezierTo(w * 0.16, h * 0.81, w * 0.35, h * 0.825)
      ..quadraticBezierTo(w * 0.50, h * 0.84, w * 0.66, h * 0.82)
      ..quadraticBezierTo(w * 0.84, h * 0.79, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final fgHillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF3F6F0),
          Color(0xFFFBFCFA),
          Color(0xFFFBFAF8),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.72, w, h * 0.28));
    canvas.drawPath(fgSnowHill, fgHillPaint);

    // Subtle sage contour strokes on the foreground white hill
    final contourPaint = Paint()
      ..color = const Color(0xFFB7CEBE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final contours = Path()
      ..moveTo(w * 0.08, h * 0.81)
      ..quadraticBezierTo(w * 0.14, h * 0.84, w * 0.21, h * 0.845)
      ..moveTo(w * 0.14, h * 0.86)
      ..quadraticBezierTo(w * 0.17, h * 0.875, w * 0.21, h * 0.875)
      ..moveTo(w * 0.74, h * 0.84)
      ..quadraticBezierTo(w * 0.79, h * 0.825, w * 0.84, h * 0.80)
      ..moveTo(w * 0.86, h * 0.85)
      ..quadraticBezierTo(w * 0.88, h * 0.835, w * 0.90, h * 0.825);
    canvas.drawPath(contours, contourPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Onboarding 2 illustration (`02_onboarding_intro.png`):
/// Woman in sage sweater holding smartphone in a serene botanical landscape.
class OnboardingPersonPhoneIllustration extends StatelessWidget {
  final double height;

  const OnboardingPersonPhoneIllustration({
    super.key,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _PersonPhoneNaturePainter(),
      ),
    );
  }
}

class _PersonPhoneNaturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Rounded organic vignette clip with curved bottom
    final vignettePath = Path()
      ..moveTo(w * 0.04, h * 0.25)
      ..cubicTo(w * 0.04, h * 0.06, w * 0.22, h * 0.02, w * 0.50, h * 0.02)
      ..cubicTo(w * 0.78, h * 0.02, w * 0.96, h * 0.06, w * 0.96, h * 0.25)
      ..lineTo(w * 0.96, h * 0.74)
      ..cubicTo(w * 0.96, h * 0.92, w * 0.75, h * 0.98, w * 0.50, h * 0.98)
      ..cubicTo(w * 0.25, h * 0.98, w * 0.04, h * 0.92, w * 0.04, h * 0.74)
      ..close();

    canvas.save();
    canvas.clipPath(vignettePath);

    // 1. Soft cream-sage sky background
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFAF9F5),
          Color(0xFFF1F5EE),
          Color(0xFFF3F2EC),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Left tall misty sage tree canopy &distant hills
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.19, h * 0.36),
        width: w * 0.28,
        height: h * 0.54,
      ),
      Paint()..color = const Color(0xFFDCE9DD),
    );
    // Left background tree trunk & branches
    final bgBranchPaint = Paint()
      ..color = const Color(0xFFB4CCB8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final leftBgTreeTrunk = Path()
      ..moveTo(w * 0.19, h * 0.65)
      ..lineTo(w * 0.19, h * 0.26)
      ..moveTo(w * 0.19, h * 0.42)
      ..lineTo(w * 0.15, h * 0.34)
      ..moveTo(w * 0.19, h * 0.38)
      ..lineTo(w * 0.23, h * 0.31);
    canvas.drawPath(leftBgTreeTrunk, bgBranchPaint);

    // Distant right mountain slope
    final rightMountain = Path()
      ..moveTo(w * 0.52, h * 0.38)
      ..quadraticBezierTo(w * 0.72, h * 0.12, w * 0.96, h * 0.26)
      ..lineTo(w * 0.96, h * 0.65)
      ..lineTo(w * 0.50, h * 0.65)
      ..close();
    canvas.drawPath(rightMountain, Paint()..color = const Color(0xFFECF2EB));

    // Right midground soft sage tree canopy
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.80, h * 0.48),
        width: w * 0.26,
        height: h * 0.34,
      ),
      Paint()..color = const Color(0xFFCDE0CE),
    );
    final rightBgTrunk = Path()
      ..moveTo(w * 0.80, h * 0.68)
      ..lineTo(w * 0.80, h * 0.42)
      ..moveTo(w * 0.80, h * 0.52)
      ..lineTo(w * 0.77, h * 0.46)
      ..moveTo(w * 0.80, h * 0.49)
      ..lineTo(w * 0.83, h * 0.44);
    canvas.drawPath(rightBgTrunk, bgBranchPaint);

    // Midground soft green hills on left
    final leftMidHill = Path()
      ..moveTo(w * 0.04, h * 0.52)
      ..quadraticBezierTo(w * 0.22, h * 0.36, w * 0.38, h * 0.58)
      ..lineTo(w * 0.38, h * 0.80)
      ..lineTo(w * 0.04, h * 0.80)
      ..close();
    canvas.drawPath(leftMidHill, Paint()..color = const Color(0xFFC7DEC8));

    // Warm cream path/meadow at bottom center
    canvas.drawRect(
      Rect.fromLTWH(w * 0.25, h * 0.68, w * 0.55, h * 0.30),
      Paint()..color = const Color(0xFFF3F1E8),
    );

    // 3. Foreground left & right lush green bushes with branch lines
    final leftBush1 = Path()
      ..moveTo(w * 0.02, h * 0.95)
      ..cubicTo(w * 0.02, h * 0.64, w * 0.14, h * 0.56, w * 0.18, h * 0.72)
      ..cubicTo(w * 0.22, h * 0.62, w * 0.30, h * 0.68, w * 0.29, h * 0.96)
      ..close();
    canvas.drawPath(leftBush1, Paint()..color = const Color(0xFF7CB182));

    final fgBranchPaint = Paint()
      ..color = const Color(0xFF3E6F48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final leftFgBranches = Path()
      ..moveTo(w * 0.11, h * 0.92)
      ..lineTo(w * 0.09, h * 0.70)
      ..moveTo(w * 0.10, h * 0.80)
      ..lineTo(w * 0.07, h * 0.74)
      ..moveTo(w * 0.22, h * 0.94)
      ..lineTo(w * 0.22, h * 0.72)
      ..moveTo(w * 0.22, h * 0.83)
      ..lineTo(w * 0.19, h * 0.77)
      ..moveTo(w * 0.22, h * 0.80)
      ..lineTo(w * 0.25, h * 0.75);
    canvas.drawPath(leftFgBranches, fgBranchPaint);

    // Right foreground bush
    final rightBush = Path()
      ..moveTo(w * 0.66, h * 0.98)
      ..cubicTo(w * 0.67, h * 0.72, w * 0.76, h * 0.64, w * 0.81, h * 0.75)
      ..cubicTo(w * 0.83, h * 0.55, w * 0.95, h * 0.52, w * 0.97, h * 0.95)
      ..close();
    canvas.drawPath(rightBush, Paint()..color = const Color(0xFF5D9662));

    final rightFgBranches = Path()
      ..moveTo(w * 0.74, h * 0.96)
      ..lineTo(w * 0.74, h * 0.76)
      ..moveTo(w * 0.74, h * 0.86)
      ..lineTo(w * 0.71, h * 0.80)
      ..moveTo(w * 0.88, h * 0.94)
      ..lineTo(w * 0.90, h * 0.68)
      ..moveTo(w * 0.89, h * 0.82)
      ..lineTo(w * 0.85, h * 0.74)
      ..moveTo(w * 0.895, h * 0.77)
      ..lineTo(w * 0.93, h * 0.71);
    canvas.drawPath(rightFgBranches, fgBranchPaint);

    // 4. CENTRAL PERSON (Woman in sage sweater holding smartphone)
    // Back hair wave (dark forest charcoal)
    final backHair = Path()
      ..moveTo(w * 0.42, h * 0.18)
      ..cubicTo(w * 0.37, h * 0.22, w * 0.36, h * 0.32, w * 0.37, h * 0.37)
      ..cubicTo(w * 0.38, h * 0.42, w * 0.45, h * 0.43, w * 0.53, h * 0.41)
      ..cubicTo(w * 0.56, h * 0.36, w * 0.57, h * 0.22, w * 0.50, h * 0.16)
      ..close();
    canvas.drawPath(backHair, Paint()..color = const Color(0xFF213C30));

    // Skirt / lower garment at bottom of frame
    final skirtPath = Path()
      ..moveTo(w * 0.35, h * 0.86)
      ..lineTo(w * 0.54, h * 0.86)
      ..lineTo(w * 0.55, h * 1.0)
      ..lineTo(w * 0.34, h * 1.0)
      ..close();
    canvas.drawPath(skirtPath, Paint()..color = const Color(0xFF5D8E6B));

    // Woman's left forearm raised to hold smartphone
    final raisedArm = Path()
      ..moveTo(w * 0.52, h * 0.68)
      ..lineTo(w * 0.60, h * 0.54)
      ..lineTo(w * 0.64, h * 0.57)
      ..lineTo(w * 0.58, h * 0.75)
      ..close();
    canvas.drawPath(raisedArm, Paint()..color = const Color(0xFFC29B61));

    // Woman's sage green sweater torso & right sleeve
    final sweaterPath = Path()
      ..moveTo(w * 0.35, h * 0.87)
      ..cubicTo(w * 0.30, h * 0.80, w * 0.30, h * 0.62, w * 0.35, h * 0.47)
      ..cubicTo(w * 0.38, h * 0.40, w * 0.43, h * 0.39, w * 0.49, h * 0.40)
      ..cubicTo(w * 0.54, h * 0.42, w * 0.56, h * 0.50, w * 0.55, h * 0.87)
      ..close();
    final sweaterPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF98C39C),
          Color(0xFF7CAB83),
        ],
      ).createShader(Rect.fromLTWH(w * 0.30, h * 0.39, w * 0.27, h * 0.48));
    canvas.drawPath(sweaterPath, sweaterPaint);

    // Sweater sleeve folds & shading
    final sweaterFoldPaint = Paint()
      ..color = const Color(0xFF5D8F68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final sweaterFolds = Path()
      ..moveTo(w * 0.39, h * 0.54)
      ..lineTo(w * 0.38, h * 0.72)
      ..lineTo(w * 0.49, h * 0.74)
      ..moveTo(w * 0.35, h * 0.80)
      ..lineTo(w * 0.48, h * 0.79);
    canvas.drawPath(sweaterFolds, sweaterFoldPaint);

    // Right hand resting gently near left forearm
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.53, h * 0.75),
        width: w * 0.08,
        height: h * 0.055,
      ),
      Paint()..color = const Color(0xFFE7C49E),
    );

    // Neck & face (warm ivory-cream skin)
    final neckPath = Path()
      ..moveTo(w * 0.45, h * 0.33)
      ..lineTo(w * 0.50, h * 0.33)
      ..lineTo(w * 0.50, h * 0.42)
      ..lineTo(w * 0.44, h * 0.41)
      ..close();
    canvas.drawPath(neckPath, Paint()..color = const Color(0xFFDDC8AB));

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.495, h * 0.285),
        width: w * 0.095,
        height: h * 0.16,
      ),
      Paint()..color = const Color(0xFFE8D7BD),
    );

    // Front hair bangs sweeping across forehead
    final frontHair = Path()
      ..moveTo(w * 0.44, h * 0.25)
      ..quadraticBezierTo(w * 0.49, h * 0.17, w * 0.55, h * 0.23)
      ..quadraticBezierTo(w * 0.51, h * 0.23, w * 0.46, h * 0.28)
      ..close();
    canvas.drawPath(frontHair, Paint()..color = const Color(0xFF213C30));

    // Ear & gentle facial features looking at the phone
    canvas.drawCircle(
      Offset(w * 0.455, h * 0.285),
      w * 0.015,
      Paint()..color = const Color(0xFFE2CEB2),
    );
    final faceLinePaint = Paint()
      ..color = const Color(0xFF42584B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final faceDetails = Path()
      ..moveTo(w * 0.495, h * 0.268)
      ..quadraticBezierTo(w * 0.508, h * 0.262, w * 0.518, h * 0.268)
      ..moveTo(w * 0.525, h * 0.275)
      ..lineTo(w * 0.532, h * 0.302)
      ..lineTo(w * 0.522, h * 0.306)
      ..moveTo(w * 0.508, h * 0.325)
      ..quadraticBezierTo(w * 0.516, h * 0.330, w * 0.524, h * 0.324);
    canvas.drawPath(faceDetails, faceLinePaint);

    // Smartphone in left hand (tilted slightly)
    canvas.save();
    canvas.translate(w * 0.635, h * 0.485);
    canvas.rotate(0.24);
    final phoneBody = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: w * 0.072,
        height: h * 0.165,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(phoneBody, Paint()..color = const Color(0xFF1A4734));
    final phoneScreen = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: w * 0.058,
        height: h * 0.145,
      ),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(
      phoneScreen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF88D19B),
            Color(0xFF4B9E65),
          ],
        ).createShader(
          Rect.fromCenter(
            center: Offset.zero,
            width: w * 0.058,
            height: h * 0.145,
          ),
        ),
    );
    canvas.restore();

    // Hand fingers holding phone
    canvas.drawCircle(
      Offset(w * 0.648, h * 0.535),
      w * 0.018,
      Paint()..color = const Color(0xFFE7C49E),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Registration Success ("Sẵn sàng!" - `08_registration_complete.png`) top illustration:
/// Warm golden sun over misty mountains and lush valley trees.
class ReadySunHillsIllustration extends StatelessWidget {
  final double height;

  const ReadySunHillsIllustration({
    super.key,
    this.height = 175,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ReadySunHillsPainter(),
      ),
    );
  }
}

class _ReadySunHillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Soft clouds on left & right
    final cloudPaint = Paint()..color = const Color(0xFFE1F0EA);
    final rightCloud = Path()
      ..moveTo(w * 0.72, h * 0.36)
      ..quadraticBezierTo(w * 0.73, h * 0.28, w * 0.77, h * 0.29)
      ..quadraticBezierTo(w * 0.80, h * 0.20, w * 0.85, h * 0.28)
      ..quadraticBezierTo(w * 0.89, h * 0.29, w * 0.88, h * 0.36)
      ..close();
    canvas.drawPath(rightCloud, cloudPaint);

    // 2. Large warm golden sun at top center
    final sunCenter = Offset(w * 0.51, h * 0.24);
    final sunRadius = math.min(w, h) * 0.21;
    final sunPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF9DD9C),
          Color(0xFFF5CF84),
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // 3. Distant misty teal-sage mountains behind the valley
    final leftPeak = Path()
      ..moveTo(w * 0.14, h * 0.65)
      ..quadraticBezierTo(w * 0.26, h * 0.42, w * 0.35, h * 0.48)
      ..quadraticBezierTo(w * 0.46, h * 0.30, w * 0.62, h * 0.56)
      ..lineTo(w * 0.14, h * 0.68)
      ..close();
    canvas.drawPath(leftPeak, Paint()..color = const Color(0xFFDCEEE7));

    final rightPeak = Path()
      ..moveTo(w * 0.48, h * 0.60)
      ..quadraticBezierTo(w * 0.69, h * 0.32, w * 0.80, h * 0.50)
      ..quadraticBezierTo(w * 0.86, h * 0.50, w * 0.90, h * 0.60)
      ..lineTo(w * 0.48, h * 0.68)
      ..close();
    canvas.drawPath(rightPeak, Paint()..color = const Color(0xFFCEE6DD));

    // 4. Valley clipped inside sweeping snow banks
    final valleyClip = Path()
      ..moveTo(w * 0.10, h * 0.0)
      ..lineTo(w * 0.90, h * 0.0)
      ..lineTo(w * 0.90, h * 0.58)
      ..quadraticBezierTo(w * 0.68, h * 0.92, w * 0.53, h * 0.92)
      ..quadraticBezierTo(w * 0.38, h * 0.92, w * 0.14, h * 0.56)
      ..close();

    canvas.save();
    canvas.clipPath(valleyClip);

    // Cluster of stylized pine/cypress trees in center valley
    void drawCypress(double cx, double topY, double treeW, double treeH, Color color) {
      final path = Path()
        ..moveTo(cx - treeW * 0.5, topY + treeH)
        ..quadraticBezierTo(cx - treeW * 0.45, topY + treeH * 0.2, cx, topY)
        ..quadraticBezierTo(cx + treeW * 0.45, topY + treeH * 0.2, cx + treeW * 0.5, topY + treeH)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    drawCypress(w * 0.37, h * 0.54, w * 0.06, h * 0.30, const Color(0xFF3E9474));
    drawCypress(w * 0.43, h * 0.47, w * 0.08, h * 0.36, const Color(0xFF3A8F70));
    drawCypress(w * 0.51, h * 0.45, w * 0.10, h * 0.38, const Color(0xFF328266));
    drawCypress(w * 0.58, h * 0.47, w * 0.08, h * 0.36, const Color(0xFF38896B));
    drawCypress(w * 0.64, h * 0.51, w * 0.07, h * 0.34, const Color(0xFF2D785C));
    drawCypress(w * 0.70, h * 0.62, w * 0.05, h * 0.24, const Color(0xFF3F8E6F));
    drawCypress(w * 0.515, h * 0.60, w * 0.075, h * 0.26, const Color(0xFF1D5642));

    // Green rolling foreground hills inside valley
    final valleyHillLeft = Path()
      ..moveTo(w * 0.28, h * 0.88)
      ..quadraticBezierTo(w * 0.44, h * 0.66, w * 0.56, h * 0.88)
      ..close();
    canvas.drawPath(valleyHillLeft, Paint()..color = const Color(0xFF5C9D61));

    final valleyHillRight = Path()
      ..moveTo(w * 0.48, h * 0.92)
      ..quadraticBezierTo(w * 0.60, h * 0.65, w * 0.76, h * 0.88)
      ..close();
    canvas.drawPath(valleyHillRight, Paint()..color = const Color(0xFF4D8E54));

    canvas.restore();

    // 5. Sweeping off-white snow/cloud banks framing bottom-left & bottom-right
    final leftBank = Path()
      ..moveTo(w * 0.14, h * 0.55)
      ..quadraticBezierTo(w * 0.34, h * 0.68, w * 0.49, h * 0.91)
      ..quadraticBezierTo(w * 0.28, h * 0.93, w * 0.14, h * 0.55)
      ..close();
    canvas.drawPath(leftBank, Paint()..color = const Color(0xFFF3F6F1));

    // Decorative floating sage leaves & wind lines on left & right
    final leafPaint = Paint()..color = const Color(0xFF9AC5AF);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.05, h * 0.68), width: 12, height: 8),
      leafPaint,
    );
    final windStroke = Paint()
      ..color = const Color(0xFFABD0BE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final windPath = Path()
      ..moveTo(w * 0.18, h * 0.73)
      ..quadraticBezierTo(w * 0.25, h * 0.71, w * 0.32, h * 0.72)
      ..moveTo(w * 0.76, h * 0.87)
      ..quadraticBezierTo(w * 0.86, h * 0.80, w * 0.96, h * 0.66);
    canvas.drawPath(windPath, windStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom panoramic hills banner on Registration Success (`08_registration_complete.png`).
class ReadyBottomHillsIllustration extends StatelessWidget {
  final double height;

  const ReadyBottomHillsIllustration({
    super.key,
    this.height = 110,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ReadyBottomHillsPainter(),
      ),
    );
  }
}

class _ReadyBottomHillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final clipRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(18),
    );
    canvas.save();
    canvas.clipRRect(clipRRect);

    // Distant soft mountain ridge
    final farRidge = Path()
      ..moveTo(0, h * 0.68)
      ..quadraticBezierTo(w * 0.16, h * 0.44, w * 0.30, h * 0.56)
      ..quadraticBezierTo(w * 0.52, h * 0.36, w * 0.72, h * 0.18)
      ..quadraticBezierTo(w * 0.86, h * 0.24, w, h * 0.38)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(farRidge, Paint()..color = const Color(0xFFDFECE3));

    // Midground sage hill
    final midRidge = Path()
      ..moveTo(w * 0.16, h * 0.86)
      ..quadraticBezierTo(w * 0.38, h * 0.52, w * 0.60, h * 0.76)
      ..lineTo(w * 0.60, h)
      ..lineTo(w * 0.16, h)
      ..close();
    canvas.drawPath(midRidge, Paint()..color = const Color(0xFFB3D5BF));

    // Foreground right lush green foliage canopy
    final fgCanopy = Path()
      ..moveTo(w * 0.44, h)
      ..quadraticBezierTo(w * 0.55, h * 0.76, w * 0.68, h * 0.74)
      ..quadraticBezierTo(w * 0.76, h * 0.54, w * 0.86, h * 0.58)
      ..quadraticBezierTo(w * 0.94, h * 0.42, w, h * 0.52)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(fgCanopy, Paint()..color = const Color(0xFF7FB392));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Check-in Confirmation ("Tuyệt vời! Bạn vẫn ổn!" - `10_check_in_success.png`) cloud & checkmark illustration.
class CheckInCloudCheckIllustration extends StatelessWidget {
  final double size;

  const CheckInCloudCheckIllustration({
    super.key,
    this.size = 185,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.35,
      height: size,
      child: CustomPaint(
        painter: _CheckInCloudCheckPainter(),
      ),
    );
  }
}

class _CheckInCloudCheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Soft organic cloud-landscape backdrop
    final cloudPaint = Paint()..color = const Color(0xFFEAF3EC);
    canvas.drawCircle(Offset(w * 0.48, h * 0.46), h * 0.42, cloudPaint);
    canvas.drawCircle(Offset(w * 0.28, h * 0.40), h * 0.26, cloudPaint);
    canvas.drawCircle(Offset(w * 0.68, h * 0.38), h * 0.27, cloudPaint);
    canvas.drawCircle(Offset(w * 0.34, h * 0.68), h * 0.24, cloudPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.66), h * 0.25, cloudPaint);

    // Subtle mid-sage hills inside the cloud
    final innerHill = Path()
      ..moveTo(w * 0.16, h * 0.76)
      ..quadraticBezierTo(w * 0.48, h * 0.56, w * 0.84, h * 0.76)
      ..quadraticBezierTo(w * 0.50, h * 0.90, w * 0.16, h * 0.76)
      ..close();
    canvas.drawPath(innerHill, Paint()..color = const Color(0xFFDDECE1));

    // Left & right soft sage trees with delicate trunks
    final treePaint = Paint()..color = const Color(0xFFCDE3D2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.18, h * 0.62),
        width: w * 0.17,
        height: h * 0.28,
      ),
      treePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.81, h * 0.60),
        width: w * 0.17,
        height: h * 0.28,
      ),
      treePaint,
    );

    final trunkPaint = Paint()
      ..color = const Color(0xFF9EC4A9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final trunks = Path()
      ..moveTo(w * 0.18, h * 0.76)
      ..lineTo(w * 0.18, h * 0.58)
      ..moveTo(w * 0.18, h * 0.66)
      ..lineTo(w * 0.15, h * 0.61)
      ..moveTo(w * 0.81, h * 0.75)
      ..lineTo(w * 0.81, h * 0.56)
      ..moveTo(w * 0.81, h * 0.64)
      ..lineTo(w * 0.84, h * 0.59);
    canvas.drawPath(trunks, trunkPaint);

    // 2. Central glowing emerald-forest circle with white ring & checkmark
    final center = Offset(w * 0.49, h * 0.48);
    final circleRadius = h * 0.26;

    // White outer border ring
    canvas.drawCircle(
      center,
      circleRadius + 3,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    final greenCirclePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF3E9165),
          Color(0xFF28754F),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: circleRadius));
    canvas.drawCircle(center, circleRadius, greenCirclePaint);

    // Crisp rounded white checkmark
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = circleRadius * 0.18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(center.dx - circleRadius * 0.36, center.dy + circleRadius * 0.02)
      ..lineTo(center.dx - circleRadius * 0.08, center.dy + circleRadius * 0.30)
      ..lineTo(center.dx + circleRadius * 0.38, center.dy - circleRadius * 0.26);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Illustrated portrait avatar matching the personas in the Evenear design sheet
/// (`Nguyễn Văn An`, `Mẹ`, `Bố`, `Em gái`, `Chú Nam`).
class EvenearAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;
  final bool showStatusDot;
  final Color? statusColor;

  const EvenearAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 24,
    this.showStatusDot = false,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final lower = name.toLowerCase();
    Color bgColor = const Color(0xFFD8E8DF);
    Color hairColor = const Color(0xFF2B3530);
    Color shirtColor = const Color(0xFF2D6A4F);
    bool isFemale = false;
    bool isElderly = false;

    if (lower.contains('mẹ') || lower.contains('mother') || lower.contains('bà')) {
      bgColor = const Color(0xFFE4EFE9);
      hairColor = const Color(0xFF4A4E4D);
      shirtColor = const Color(0xFF3D7A5A);
      isFemale = true;
      isElderly = true;
    } else if (lower.contains('bố') || lower.contains('father') || lower.contains('ông')) {
      bgColor = const Color(0xFFE8ECE6);
      hairColor = const Color(0xFF8C928E);
      shirtColor = const Color(0xFF4A6B5D);
      isFemale = false;
      isElderly = true;
    } else if (lower.contains('em gái') || lower.contains('sister') || lower.contains('lan') || lower.contains('hương')) {
      bgColor = const Color(0xFFE6F2EC);
      hairColor = const Color(0xFF232926);
      shirtColor = const Color(0xFF52B788);
      isFemale = true;
    } else if (lower.contains('chú') || lower.contains('nam') || lower.contains('bác')) {
      bgColor = const Color(0xFFF2E9E4);
      hairColor = const Color(0xFF595959);
      shirtColor = const Color(0xFF6C757D);
    }

    Widget avatarContent;
    if (avatarUrl != null && avatarUrl!.startsWith('http')) {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    } else {
      avatarContent = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _PersonaPortraitPainter(
            hairColor: hairColor,
            shirtColor: shirtColor,
            isFemale: isFemale,
            isElderly: isElderly,
          ),
        ),
      );
    }

    if (!showStatusDot) return avatarContent;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarContent,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.58,
            height: radius * 0.58,
            decoration: BoxDecoration(
              color: statusColor ?? AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              Icons.check,
              size: radius * 0.34,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonaPortraitPainter extends CustomPainter {
  final Color hairColor;
  final Color shirtColor;
  final bool isFemale;
  final bool isElderly;

  _PersonaPortraitPainter({
    required this.hairColor,
    required this.shirtColor,
    required this.isFemale,
    required this.isElderly,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back hair for female
    if (isFemale) {
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.44),
        w * 0.28,
        Paint()..color = hairColor,
      );
    }

    // Shoulders / shirt
    final shirtPath = Path()
      ..moveTo(w * 0.14, h)
      ..quadraticBezierTo(w * 0.20, h * 0.66, w * 0.5, h * 0.66)
      ..quadraticBezierTo(w * 0.80, h * 0.66, w * 0.86, h)
      ..close();
    canvas.drawPath(shirtPath, Paint()..color = shirtColor);

    // Collar V-neck
    final collarPath = Path()
      ..moveTo(w * 0.40, h * 0.66)
      ..lineTo(w * 0.50, h * 0.78)
      ..lineTo(w * 0.60, h * 0.66)
      ..close();
    canvas.drawPath(collarPath, Paint()..color = Colors.white.withValues(alpha: 0.9));

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.62), width: w * 0.16, height: h * 0.16),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFF1C2A0),
    );

    // Face
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.42),
      w * 0.21,
      Paint()..color = const Color(0xFFF5CBA7),
    );

    // Hair top
    final hairTop = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(w * 0.5, h * 0.40), radius: w * 0.22),
        math.pi * 0.92,
        math.pi * 1.16,
      );
    canvas.drawPath(hairTop, Paint()..color = hairColor);

    // Gentle smile & eyes
    final eyePaint = Paint()..color = const Color(0xFF2B3530);
    canvas.drawCircle(Offset(w * 0.43, h * 0.42), w * 0.022, eyePaint);
    canvas.drawCircle(Offset(w * 0.57, h * 0.42), w * 0.022, eyePaint);

    final smilePaint = Paint()
      ..color = const Color(0xFFB57C60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.46), width: w * 0.10, height: h * 0.06),
      0.1,
      math.pi - 0.2,
      false,
      smilePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
