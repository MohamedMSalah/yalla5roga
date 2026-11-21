import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_info_l10n.dart';

class OutingPlaceGallery extends StatefulWidget {
  const OutingPlaceGallery({
    super.key,
    required this.images,
    required this.art,
    this.firstPhoto,
    this.height = 158,
    this.canViewFullscreen,
    this.border,
    this.candidateLabels = const [],
  });

  final List<String> images;
  final List<String> candidateLabels;
  final PlanningCoverArt art;
  final Widget? firstPhoto;
  final double height;
  final bool Function(BuildContext)? canViewFullscreen;
  final Color? border;

  @override
  State<OutingPlaceGallery> createState() => _OutingPlaceGalleryState();
}

class _OutingPlaceGalleryState extends State<OutingPlaceGallery> {
  int _index = 0;

  List<String> get _images => widget.candidateLabels.isNotEmpty
      ? widget.images
      : widget.images.where((url) => url.trim().isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final page = images.isEmpty ? 0 : _index.clamp(0, images.length - 1);
    final gallery = Stack(
      fit: StackFit.expand,
      children: [
        if (images.length < 2)
          widget.firstPhoto ?? _cover(images.firstOrNull ?? '')
        else
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) =>
                index == 0 && widget.firstPhoto != null
                ? widget.firstPhoto!
                : _cover(images[index]),
          ),
        if (widget.candidateLabels.length > 1 &&
            page < widget.candidateLabels.length)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 16, 76, 8),
                child: Text(
                  widget.candidateLabels[page],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (images.length > 1 ||
            (images.isNotEmpty && (widget.canViewFullscreen != null)))
          PositionedDirectional(
            end: 8,
            bottom: 6,
            child: _GalleryCounter(
              index: page,
              total: images.length,
              onTap: (widget.canViewFullscreen != null)
                  ? () => _showPhotos(images, page)
                  : null,
            ),
          ),
      ],
    );
    return SizedBox(
      height: widget.height,
      child: widget.border == null
          ? gallery
          : Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: widget.border!),
              ),
              child: gallery,
            ),
    );
  }

  Widget _cover(String image) => PlanningCover(
    url: image,
    art: widget.art,
    width: double.infinity,
    height: widget.height,
  );

  void _showPhotos(List<String> images, int index) {
    final canView = widget.canViewFullscreen!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _OutingPhotoViewer(
          images: images,
          initialIndex: index,
          canView: canView,
        ),
      ),
    );
  }
}

class _GalleryCounter extends StatelessWidget {
  const _GalleryCounter({required this.index, required this.total, this.onTap});
  final int index, total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final counter = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_outlined, color: Colors.white, size: 15),
            const SizedBox(width: 5),
            Text(
              '${l10n.n(index + 1)}/${l10n.n(total)}',
              style: context.texts.labelMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return counter;
    return Tooltip(
      message: l10n.outingPhotosLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(child: counter),
          ),
        ),
      ),
    );
  }
}

class _OutingPhotoViewer extends StatefulWidget {
  const _OutingPhotoViewer({
    required this.images,
    required this.initialIndex,
    required this.canView,
  });
  final List<String> images;
  final int initialIndex;
  final bool Function(BuildContext) canView;

  @override
  State<_OutingPhotoViewer> createState() => _OutingPhotoViewerState();
}

class _OutingPhotoViewerState extends State<_OutingPhotoViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = widget.canView(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.l10n.outingPhotosLabel),
        actions: allowed
            ? [
                _GalleryCounter(index: _index, total: widget.images.length),
                const SizedBox(width: 12),
              ]
            : null,
      ),
      body: !allowed
          ? Center(
              child: Text(
                context.l10n.dataLoadFailed,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : SafeArea(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => AppNetworkImage(
                  url: widget.images[index],
                  fit: BoxFit.contain,
                ),
              ),
            ),
    );
  }
}
