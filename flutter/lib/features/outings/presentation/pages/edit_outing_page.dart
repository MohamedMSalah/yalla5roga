import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/edit_outing_form.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class EditOutingPage extends StatelessWidget {
  const EditOutingPage({super.key, required this.outing});
  final Outing outing;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppPageBar(title: context.l10n.editOuting),
    body: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
        child: EditOutingForm(
          outing: outing,
          onSave: (changes) async {
            final provider = context.read<OutingsProvider>();
            final ok = await provider.update(outing.id, changes);
            if (!context.mounted) return false;
            if (ok) {
              AppSnackBar.show(context.l10n.changesSaved);
              Navigator.of(context).pop();
            } else {
              AppSnackBar.show(provider.errorMessage ?? context.l10n.tryAgain);
            }
            return ok;
          },
        ),
      ),
    ),
  );
}
