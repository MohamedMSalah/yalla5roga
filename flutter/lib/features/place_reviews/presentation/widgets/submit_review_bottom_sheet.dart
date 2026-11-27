import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../../domain/entities/place_review.dart';
import '../providers/place_reviews_provider.dart';
import 'rating_stars_widget.dart';

class SubmitReviewBottomSheet extends StatefulWidget {
  const SubmitReviewBottomSheet({
    super.key,
    required this.provider,
    this.initial,
  });

  final PlaceReviewsProvider provider;
  final PlaceReview? initial;

  static Future<bool?> show(
    BuildContext context,
    PlaceReviewsProvider provider,
  ) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
    builder: (_) =>
        SubmitReviewBottomSheet(provider: provider, initial: provider.mine),
  );

  @override
  State<SubmitReviewBottomSheet> createState() =>
      _SubmitReviewBottomSheetState();
}

class _SubmitReviewBottomSheetState extends State<SubmitReviewBottomSheet> {
  late int _rating = widget.initial?.rating ?? 0;
  late final _text = TextEditingController(text: widget.initial?.text);
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_rating == 0 || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final text = _text.text.trim();
    final failure = await widget.provider.save(
      _rating,
      text.isEmpty ? null : text,
    );
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = FailureMessageMapper.localize(failure, context.l10n);
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.md,
            children: [
              Text(
                widget.initial == null
                    ? l10n.placeRateThis
                    : l10n.placeEditRating,
                style: context.texts.titleLarge,
              ),
              AbsorbPointer(
                absorbing: _saving,
                child: RatingStarsWidget(
                  rating: _rating,
                  onChanged: (value) {
                    if (!_saving) setState(() => _rating = value);
                  },
                ),
              ),
              TextField(
                controller: _text,
                enabled: !_saving,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: l10n.placeReviewOptional,
                ),
              ),
              if (_error case final message?)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: TextStyle(color: context.palette.danger),
                  ),
                ),
              FilledButton(
                onPressed: _saving || _rating == 0 ? null : _save,
                child: Text(
                  _saving ? l10n.placeSavingRating : l10n.placeSaveRating,
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
