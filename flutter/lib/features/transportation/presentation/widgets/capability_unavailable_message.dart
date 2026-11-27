import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class CapabilityUnavailableMessage extends StatelessWidget {
  const CapabilityUnavailableMessage({super.key, this.reasonCode});

  final String? reasonCode;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.info_outline, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          reasonCode == 'ROUTING_NOT_CONFIGURED'
              ? context.l10n.transportationRoutingNotConfigured
              : context.l10n.transportationRoutingUnavailable,
        ),
      ),
    ],
  );
}
