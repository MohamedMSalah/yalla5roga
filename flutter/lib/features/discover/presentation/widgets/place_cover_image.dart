import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_category_style.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

/// Place cover: API image when present, otherwise a clear category icon.
class PlaceCoverImage extends StatelessWidget {
  const PlaceCoverImage({
    super.key,
    required this.url,
    required this.vibe,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
  });

  PlaceCoverImage.fromSuggested({
    super.key,
    required SuggestedPlace place,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
  }) : url = place.coverImageUrl,
       vibe = place.vibe;

  PlaceCoverImage.fromOutingPlace({
    super.key,
    required Place place,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
  }) : url = place.imageUrl,
       vibe = place.vibe;

  final String url;
  final OutingVibe vibe;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return AppNetworkImage(
      url: url,
      width: width,
      height: height,
      fit: fit,
      radius: radius,
      placeholderIcon: vibe.icon,
      placeholderColor: vibe.softBackground,
      placeholderIconColor: vibe.accent,
    );
  }
}
