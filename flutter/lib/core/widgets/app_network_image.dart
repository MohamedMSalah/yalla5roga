import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.placeholderIcon = Icons.image_outlined,
    this.placeholderColor = AppColors.brand100,
    this.placeholderIconColor = AppColors.brand600,
  });

  /// Avatar-friendly constructor — empty/broken URLs show a person icon.
  const AppNetworkImage.avatar({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
  }) : placeholderIcon = Icons.person_rounded,
       placeholderColor = AppColors.brand100,
       placeholderIconColor = AppColors.brand600;

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double? radius;
  final IconData placeholderIcon;
  final Color placeholderColor;
  final Color placeholderIconColor;

  bool get _isRemote => url.startsWith('http://') || url.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final finiteWidth = width != null && width!.isFinite ? width! : null;
    final finiteHeight = height != null && height!.isFinite ? height! : null;
    final shortest = [
      finiteWidth,
      finiteHeight,
    ].whereType<double>().fold<double>(24, (a, b) => a < b ? a : b);
    final iconSize = (shortest * 0.38).clamp(16.0, 56.0);
    final placeholder = Container(
      width: width,
      height: height,
      color: placeholderColor,
      alignment: Alignment.center,
      child: Icon(placeholderIcon, color: placeholderIconColor, size: iconSize),
    );

    final image = url.trim().isEmpty
        ? placeholder
        : _isRemote
        ? CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: finiteWidth == null
                ? null
                : (finiteWidth * 2).round(),
            memCacheHeight: finiteHeight == null
                ? null
                : (finiteHeight * 2).round(),
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
            fadeInDuration: const Duration(milliseconds: 180),
            fadeOutDuration: const Duration(milliseconds: 120),
          )
        : Image.file(
            File(url),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => placeholder,
          );

    if (radius == null) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius!),
      child: image,
    );
  }
}
