import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.placeholder,
    this.placeholderIcon = Icons.image_outlined,
    this.placeholderColor = AppColors.brand100,
    this.placeholderIconColor = AppColors.brand600,
    this.fade = true,
  });

  /// Avatar-friendly constructor — empty/broken URLs show a person icon.
  const AppNetworkImage.avatar({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.fade = true,
  }) : placeholder = null,
       placeholderIcon = Icons.person_rounded,
       placeholderColor = AppColors.brand100,
       placeholderIconColor = AppColors.brand600;

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double? radius;
  final Widget? placeholder;
  final IconData placeholderIcon;
  final Color placeholderColor;
  final Color placeholderIconColor;

  /// Fade-in after decode. Off for Hero children so a live-API cache miss
  /// does not pop the photo in after the shared-element flight lands.
  final bool fade;

  bool get _isRemote => url.startsWith('http://') || url.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final finiteWidth = width != null && width!.isFinite ? width! : null;
    final finiteHeight = height != null && height!.isFinite ? height! : null;
    final needsLayout =
        _isRemote &&
        url.trim().isNotEmpty &&
        (finiteWidth == null || finiteHeight == null);

    if (needsLayout) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w =
              finiteWidth ??
              (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
          final h =
              finiteHeight ??
              (constraints.maxHeight.isFinite ? constraints.maxHeight : null);
          return _image(context, w, h);
        },
      );
    }
    return _image(context, finiteWidth, finiteHeight);
  }

  /// Decode at display size, not the source CDN original. Full-res decode of
  /// every home cover is what skipped ~100 frames after `home_feed_ready`.
  static int? _decodePx(double? logical, double dpr) {
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    return (logical * dpr).round().clamp(1, 1080);
  }

  Widget _image(
    BuildContext context,
    double? layoutWidth,
    double? layoutHeight,
  ) {
    final shortest = [
      layoutWidth,
      layoutHeight,
    ].whereType<double>().fold<double>(24, (a, b) => a < b ? a : b);
    final iconSize = (shortest * 0.38).clamp(16.0, 56.0);
    final fallback =
        placeholder ??
        Container(
          width: width,
          height: height,
          color: placeholderColor,
          alignment: Alignment.center,
          child: Icon(
            placeholderIcon,
            color: placeholderIconColor,
            size: iconSize,
          ),
        );

    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    // Only one cache dimension so the codec keeps aspect ratio.
    final memW = _decodePx(layoutWidth, dpr);
    final memH = memW == null ? _decodePx(layoutHeight, dpr) : null;

    final image = url.trim().isEmpty
        ? fallback
        : _isRemote
        ? CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: memW,
            memCacheHeight: memH,
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
            fadeInDuration: fade
                ? AppMotion.of(context, const Duration(milliseconds: 180))
                : Duration.zero,
            fadeOutDuration: fade
                ? AppMotion.of(context, const Duration(milliseconds: 120))
                : Duration.zero,
          )
        : Image.file(
            File(url),
            width: width,
            height: height,
            fit: fit,
            cacheWidth: memW,
            cacheHeight: memH,
            errorBuilder: (_, _, _) => fallback,
          );

    if (radius == null) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius!),
      child: image,
    );
  }
}
