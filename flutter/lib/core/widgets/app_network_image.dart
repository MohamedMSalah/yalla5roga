import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/media/media_reference.dart';
import 'package:yalla_5roga/core/media/media_url_resolver.dart';
import 'package:yalla_5roga/core/media/media_url_store.dart';
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
    this.placeholderColor,
    this.placeholderIconColor,
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
       placeholderColor = null,
       placeholderIconColor = null;

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double? radius;
  final Widget? placeholder;
  final IconData placeholderIcon;
  final Color? placeholderColor;
  final Color? placeholderIconColor;

  /// Fade-in after decode. Off for Hero children so a live-API cache miss
  /// does not pop the photo in after the shared-element flight lands.
  final bool fade;

  bool get _isRemote => url.startsWith('http://') || url.startsWith('https://');

  bool get _isMedia => isMediaReference(url);

  @override
  Widget build(BuildContext context) {
    final finiteWidth = width != null && width!.isFinite ? width! : null;
    final finiteHeight = height != null && height!.isFinite ? height! : null;
    final needsLayout =
        (_isRemote || _isMedia) &&
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
          color: placeholderColor ?? AppColors.of(context).brandSoft,
          alignment: Alignment.center,
          child: Icon(
            placeholderIcon,
            color: placeholderIconColor ?? AppColors.of(context).brandStrong,
            size: iconSize,
          ),
        );

    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    // Only one cache dimension so the codec keeps aspect ratio.
    final memW = _decodePx(layoutWidth, dpr);
    final memH = memW == null ? _decodePx(layoutHeight, dpr) : null;

    final image = url.trim().isEmpty
        ? fallback
        : _isMedia
        ? _MediaNetworkImage(
            reference: url.trim(),
            width: width,
            height: height,
            fit: fit,
            fade: fade,
            memCacheWidth: memW,
            memCacheHeight: memH,
            placeholder: fallback,
          )
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

/// Resolves a `media://<uuid>` reference and renders it through the persistent
/// network-image cache keyed by the stable asset id (never the signed URL).
class _MediaNetworkImage extends StatefulWidget {
  const _MediaNetworkImage({
    required this.reference,
    required this.placeholder,
    required this.fit,
    required this.fade,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String reference;
  final Widget placeholder;
  final BoxFit fit;
  final bool fade;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  State<_MediaNetworkImage> createState() => _MediaNetworkImageState();
}

class _MediaNetworkImageState extends State<_MediaNetworkImage> {
  MediaUrlResolver? _resolver;
  MediaUrlEntry? _entry;
  String? _uid;
  bool _revalidated = false;

  String? get _assetId => parseMediaId(widget.reference);

  @override
  void initState() {
    super.initState();
    _resolver = MediaUrlResolver.active;
    _uid = _resolver?.currentUserId;
    _resolver?.addListener(_onResolverChanged);
    _load();
  }

  @override
  void didUpdateWidget(_MediaNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference) {
      _entry = null;
      _revalidated = false;
      _load();
    }
  }

  @override
  void dispose() {
    _resolver?.removeListener(_onResolverChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final resolver = _resolver;
    final assetId = _assetId;
    if (resolver == null || assetId == null) return;
    final uid = resolver.currentUserId;
    if (uid == null) return;

    final cached = resolver.peek(assetId);
    if (mounted && cached != null && cached.url != _entry?.url) {
      setState(() => _entry = cached);
    }
    final entry = await resolver.resolve(assetId);
    if (!mounted || resolver.currentUserId != uid) return;
    if (entry != null && entry.url != _entry?.url) {
      setState(() => _entry = entry);
    }
  }

  void _onResolverChanged() {
    if (!mounted) return;
    final resolver = _resolver;
    final assetId = _assetId;
    if (resolver == null || assetId == null) return;
    final uid = resolver.currentUserId;
    if (uid != _uid) {
      // Account switched (or signed out): never keep rendering another
      // account's private signed URL.
      _uid = uid;
      _revalidated = false;
      setState(() => _entry = uid == null ? null : resolver.peek(assetId));
      _load();
      return;
    }
    final entry = resolver.peek(assetId);
    if (entry != null && entry.url != _entry?.url) {
      setState(() => _entry = entry);
    }
  }

  void _onImageError() {
    if (_revalidated) return;
    _revalidated = true;
    final resolver = _resolver;
    final assetId = _assetId;
    if (resolver == null || assetId == null) return;
    unawaited(() async {
      final entry = await resolver.revalidate(assetId);
      if (!mounted || entry == null) return;
      setState(() => _entry = entry);
    }());
  }

  @override
  Widget build(BuildContext context) {
    final resolver = _resolver;
    final entry = _entry;
    final assetId = _assetId;
    if (resolver == null || entry == null || assetId == null) {
      return widget.placeholder;
    }

    return CachedNetworkImage(
      imageUrl: entry.url,
      cacheKey: resolver.cacheKeyFor(assetId, entry.visibility),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      placeholder: (_, _) => widget.placeholder,
      errorWidget: (_, _, _) {
        _onImageError();
        return widget.placeholder;
      },
      fadeInDuration: widget.fade
          ? AppMotion.of(context, const Duration(milliseconds: 180))
          : Duration.zero,
      fadeOutDuration: widget.fade
          ? AppMotion.of(context, const Duration(milliseconds: 120))
          : Duration.zero,
    );
  }
}
