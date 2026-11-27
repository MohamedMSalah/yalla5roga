import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../../domain/entities/place_review.dart';
import '../providers/place_reviews_provider.dart';

class ReportReviewDialog extends StatefulWidget {
  const ReportReviewDialog({
    super.key,
    required this.provider,
    required this.review,
  });

  final PlaceReviewsProvider provider;
  final PlaceReview review;

  @override
  State<ReportReviewDialog> createState() => _ReportReviewDialogState();
}

class _ReportReviewDialogState extends State<ReportReviewDialog> {
  ReviewReportReason? _reason;
  bool _pending = false;
  String? _error;

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    final failure = await widget.provider.report(widget.review, reason);
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _pending = false;
        _error = FailureMessageMapper.localize(failure, context.l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_pending,
      child: AlertDialog(
        title: Text(l10n.placeReportReview),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ReviewReportReason>(
              initialValue: _reason,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.placeReportReason),
              items: [
                for (final reason in ReviewReportReason.values)
                  DropdownMenuItem(
                    value: reason,
                    child: Text(l10n.placeReviewReason(reason.name)),
                  ),
              ],
              onChanged: _pending
                  ? null
                  : (reason) => setState(() => _reason = reason),
            ),
            if (_error case final message?)
              Semantics(liveRegion: true, child: Text(message)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _pending ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _pending || _reason == null ? null : _send,
            child: Text(
              _pending ? l10n.placeSendingReport : l10n.placeReportReview,
            ),
          ),
        ],
      ),
    );
  }
}
