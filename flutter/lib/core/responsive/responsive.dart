import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';

/// Scales fonts, paddings, and widget sizes from a 375×812 phone design.
///
/// Also detects foldables (hinge/fold display features + near-square wide
/// heuristic) so an unfolded device scales as a slightly larger phone instead
/// of jumping to tablet sizing.
class Responsive {
  Responsive._();

  static const double designWidth = 375;
  static const double designHeight = 812;

  static const double minScale = 0.82;
  static const double maxScalePhone = 1.12;
  static const double maxScaleFoldOpen = 1.08;
  static const double maxScaleTablet = 1.18;
  static const double maxScaleDesktop = 1.22;

  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 1024;
  static const double foldOpenMinWidth = 540;

  /// Max content width used by wide / fold-open layouts.
  static const double foldContentMaxWidth = 560;
  static const double tabletContentMaxWidth = 640;
  static const double desktopContentMaxWidth = 720;

  static double _width = designWidth;
  static double _height = designHeight;
  static double _shortestSide = designWidth;
  static double _longestSide = designHeight;
  static double _textScale = 1;
  static bool _hasFoldFeature = false;
  static bool _isFoldOpen = false;

  static void init(BuildContext context) {
    final data = MediaQuery.of(context);
    final size = data.size;
    _width = size.width;
    _height = size.height;
    _shortestSide = size.shortestSide;
    _longestSide = size.longestSide;
    _textScale = data.textScaler.scale(1);
    _hasFoldFeature = data.displayFeatures.any(
      (feature) =>
          feature.type == DisplayFeatureType.fold ||
          feature.type == DisplayFeatureType.hinge,
    );
    _isFoldOpen = _detectFoldOpen(data);
  }

  static bool _detectFoldOpen(MediaQueryData data) {
    final size = data.size;
    final shortest = size.shortestSide;
    final longest = size.longestSide;
    final aspect = longest / shortest; // always >= 1

    if (_hasFoldFeature) {
      // Closed fold ≈ phone width; open fold is clearly wider.
      return size.width >= foldOpenMinWidth;
    }

    // Fallback for devices that omit fold display features:
    // unfolded books are wide but near-square, not large tablets.
    final nearSquareWide =
        shortest >= 550 &&
        shortest <= 900 &&
        aspect <= 1.35 &&
        size.width >= foldOpenMinWidth &&
        longest <= 1100;
    return nearSquareWide;
  }

  static double get width => _width;
  static double get height => _height;
  static double get shortestSide => _shortestSide;
  static double get longestSide => _longestSide;

  static bool get hasFoldFeature => _hasFoldFeature;

  /// True when a foldable is unfolded / used on its wide screen.
  static bool get isFoldOpen => _isFoldOpen;

  static bool get isMobile => !_isFoldOpen && _width < tabletBreakpoint;

  static bool get isTablet =>
      !_isFoldOpen && _width >= tabletBreakpoint && _width < desktopBreakpoint;

  static bool get isDesktop => !_isFoldOpen && _width >= desktopBreakpoint;

  /// Wide layout: unfolded fold, tablet, or desktop.
  static bool get isWideLayout => _isFoldOpen || isTablet || isDesktop;

  /// Width used for `.w` / layout scale (capped on fold-open & large screens).
  static double get _layoutWidth {
    if (_isFoldOpen) {
      // Keep fold-open close to phone proportions instead of tablet blow-up.
      return _width.clamp(designWidth * minScale, designWidth * 1.22);
    }
    if (isDesktop) {
      return _width.clamp(designWidth * minScale, designWidth * 1.45);
    }
    if (isTablet) {
      return _width.clamp(designWidth * minScale, designWidth * 1.35);
    }
    return _width;
  }

  /// Height used for `.h` scale.
  static double get _layoutHeight {
    if (_isFoldOpen) {
      return _height.clamp(designHeight * minScale, designHeight * 1.05);
    }
    return _height;
  }

  static double get _maxScale {
    if (_isFoldOpen) return maxScaleFoldOpen;
    if (isDesktop) return maxScaleDesktop;
    if (isTablet) return maxScaleTablet;
    return maxScalePhone;
  }

  /// Width-based layout scale.
  static double get scale =>
      (_layoutWidth / designWidth).clamp(minScale, _maxScale);

  /// Height-based layout scale.
  static double get verticalScale =>
      (_layoutHeight / designHeight).clamp(minScale, _maxScale);

  /// Gentler scale for fonts — uses shortest side so landscape / fold-open
  /// do not inflate text the way raw width would.
  static double get fontScale {
    final reference = _isFoldOpen
        ? (_shortestSide / designWidth)
        : (_layoutWidth / designWidth);
    final maxFont = _isFoldOpen
        ? maxScaleFoldOpen
        : isDesktop
        ? maxScaleTablet
        : isTablet
        ? maxScaleTablet
        : maxScalePhone;
    return reference.clamp(minScale, maxFont);
  }

  /// Optional max width for centering content on wide / fold-open screens.
  static double get contentMaxWidth {
    if (isDesktop) return desktopContentMaxWidth;
    if (isTablet) return tabletContentMaxWidth;
    if (_isFoldOpen) return foldContentMaxWidth;
    return double.infinity;
  }

  /// Width-based size (containers, icons, horizontal padding).
  static double w(num value) => value * scale;

  /// Height-based size (vertical gaps, bar heights).
  static double h(num value) => value * verticalScale;

  /// Font size, lightly respecting system text scale.
  static double sp(num value) {
    return (value * fontScale) * _textScale.clamp(0.9, 1.15);
  }

  /// Radius / border size.
  static double r(num value) => value * scale;

  static EdgeInsets padding({
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    if (all != null) return EdgeInsets.all(w(all));
    return EdgeInsets.only(
      left: w(left ?? horizontal ?? 0),
      right: w(right ?? horizontal ?? 0),
      top: h(top ?? vertical ?? 0),
      bottom: h(bottom ?? vertical ?? 0),
    );
  }

  static EdgeInsets pagePadding({
    double horizontal = 20,
    double top = 12,
    double bottom = 24,
  }) {
    final extra = _isFoldOpen
        ? 28.0
        : isTablet
        ? 16.0
        : isDesktop
        ? 24.0
        : 0.0;
    return padding(horizontal: horizontal + extra, top: top, bottom: bottom);
  }

  // Spacing tokens
  static double get spaceXs => w(4);
  static double get spaceSm => w(8);
  static double get spaceMd => w(16);
  static double get spaceLg => w(20);
  static double get spaceXl => w(24);
  static double get spaceXxl => w(32);

  // Font tokens
  static double get fontXs => sp(8);
  static double get fontCaption => sp(9);
  static double get fontSm => sp(11);
  static double get fontBody => sp(14);
  static double get fontMd => sp(16);
  static double get fontLg => sp(22);
  static double get fontXl => sp(32);

  // Widget tokens
  static double get iconSm => w(14);
  static double get iconMd => w(20);
  static double get iconLg => w(28);
  static double get radiusSm => r(10);
  static double get radiusMd => r(14);
  static double get radiusLg => r(22);
  static double get buttonHeight => h(52);
  static double get navHeight => h(76);
  static double get avatarSm => w(28);
  static double get avatarMd => w(40);
  static double get avatarLg => w(84);

  /// Horizontal active-vote carousel card width.
  static double get voteCardWidth {
    if (isDesktop) return w(300);
    if (isTablet) return w(280);
    return (_width * 0.72).clamp(w(220), w(280));
  }

  /// Horizontal active-vote carousel strip height.
  static double get voteCardHeight {
    final textScale = _textScale.clamp(1.0, 1.2);
    return h(175) * textScale;
  }
}

extension ResponsiveNumX on num {
  double get w => Responsive.w(this);
  double get h => Responsive.h(this);
  double get sp => Responsive.sp(this);
  double get r => Responsive.r(this);

  EdgeInsets get p => EdgeInsets.all(w);
  EdgeInsets get px => EdgeInsets.symmetric(horizontal: w);
  EdgeInsets get py => EdgeInsets.symmetric(vertical: h);

  SizedBox get gapW => SizedBox(width: w);
  SizedBox get gapH => SizedBox(height: h);
}

extension ResponsiveContextX on BuildContext {
  Responsive get responsive {
    Responsive.init(this);
    return Responsive._();
  }

  double rw(num value) => Responsive.w(value);
  double rh(num value) => Responsive.h(value);
  double rsp(num value) => Responsive.sp(value);
  double rr(num value) => Responsive.r(value);

  bool get isFoldOpen => Responsive.isFoldOpen;
  bool get isWideLayout => Responsive.isWideLayout;
}
