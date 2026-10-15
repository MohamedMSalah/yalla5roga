import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';

class DiscoverPlaceDetailsPage extends StatelessWidget {
  const DiscoverPlaceDetailsPage({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final place = context.read<DiscoverProvider>().placeById(placeId);
    final gallery = place.images.isNotEmpty
        ? place.images
        : [DiscoverPlaceImage(imageUrl: place.coverImageUrl)];

    return Scaffold(
      appBar: AppPageBar(title: place.localizedName(l10n)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: Responsive.pagePadding(),
              children: [
                SizedBox(
                  height: 210.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: gallery.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == gallery.length - 1
                              ? 0
                              : Responsive.spaceSm,
                        ),
                        child: PlaceCoverImage(
                          url: gallery[index].imageUrl,
                          vibe: place.vibe,
                          width: 280.w,
                          height: 210.h,
                          radius: 18.r,
                        ),
                      );
                    },
                  ),
                ),
                Responsive.spaceMd.gapH,
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.localizedName(l10n),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontLg,
                        ),
                      ),
                    ),
                    AppBadge(
                      label: l10n.vibeLabel(place.vibe.name),
                      color: palette.brandSoft,
                      textColor: palette.brandStrong,
                    ),
                  ],
                ),
                Responsive.spaceXs.gapH,
                Text(
                  '${place.localizedArea(l10n)} · ${l10n.priceLevelLabel(place.priceLevel.name)}',
                  style: TextStyle(
                    color: palette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: Responsive.fontSm,
                  ),
                ),
                if (place.localizedDescription(l10n).trim().isNotEmpty) ...[
                  Responsive.spaceMd.gapH,
                  Text(
                    l10n.aboutPlace,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.fontMd,
                    ),
                  ),
                  Responsive.spaceXs.gapH,
                  Text(
                    place.localizedDescription(l10n),
                    style: TextStyle(
                      color: palette.textSecondary,
                      height: 1.45,
                      fontSize: Responsive.fontSm,
                    ),
                  ),
                ],
                if (place.prices.isNotEmpty) ...[
                  Responsive.spaceLg.gapH,
                  Text(
                    l10n.prices,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.fontMd,
                    ),
                  ),
                  Responsive.spaceSm.gapH,
                  for (final price in place.prices) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.discoverPriceLabel(price.labelKey),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.fontSm,
                            ),
                          ),
                        ),
                        Text(
                          l10n.formatPrice(price.amount, price.currency),
                          style: TextStyle(
                            color: AppColors.brand600,
                            fontWeight: FontWeight.w800,
                            fontSize: Responsive.fontSm,
                          ),
                        ),
                      ],
                    ),
                    Responsive.spaceXs.gapH,
                  ],
                ],
                if (place.hours.isNotEmpty) ...[
                  Responsive.spaceLg.gapH,
                  Text(
                    l10n.workingHours,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.fontMd,
                    ),
                  ),
                  Responsive.spaceSm.gapH,
                  for (final hour in place.hours) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.weekdayLabel(hour.day.name),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.fontSm,
                            ),
                          ),
                        ),
                        Text(
                          hour.isClosed
                              ? l10n.closed
                              : l10n.digits(
                                  '${hour.opensAt} – ${hour.closesAt}',
                                ),
                          style: TextStyle(
                            color: hour.isClosed
                                ? palette.textMuted
                                : palette.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: Responsive.fontSm,
                          ),
                        ),
                      ],
                    ),
                    Responsive.spaceXs.gapH,
                  ],
                ],
                Responsive.spaceXl.gapH,
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: Responsive.padding(horizontal: 16, top: 8, bottom: 8),
              child: CustomButton(
                label: l10n.planOutingHere,
                icon: Icons.event_available_outlined,
                onPressed: () =>
                    Get.to(() => CreateOutingPage(suggestedPlace: place)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
