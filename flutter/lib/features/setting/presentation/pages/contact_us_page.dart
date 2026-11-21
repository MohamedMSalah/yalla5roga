import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/support_email.dart';

enum SupportTopic {
  general,
  bug,
  feature,
  privacyAndSafety,
  deletion,
  privacyPolicy,
  terms;

  String label(L10n l10n) => switch (this) {
    general => l10n.generalSupport,
    bug => l10n.bugReport,
    feature => l10n.featureSuggestion,
    privacyAndSafety => l10n.privacyAndSafety,
    deletion => l10n.accountAndDataDeletion,
    privacyPolicy => l10n.privacyPolicy,
    terms => l10n.termsAndConditions,
  };
}

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key, this.initialTopic = SupportTopic.general});

  final SupportTopic initialTopic;

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  late SupportTopic _topic = widget.initialTopic;
  bool _openingEmail = false;
  bool _emailUnavailable = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _compose() async {
    if (_openingEmail || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    final category = _topic.label(l10n);
    final subject = _subject.text.trim();
    setState(() {
      _openingEmail = true;
      _emailUnavailable = false;
    });
    final opened = await openSupportEmail(
      subject: subject.isEmpty ? '${l10n.appName} – $category' : subject,
      body: '${l10n.supportCategory}: $category\n\n${_message.text.trim()}',
    );
    if (!mounted) return;
    setState(() {
      _openingEmail = false;
      _emailUnavailable = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppPageBar(title: l10n.contactUs),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: ListView(
              padding: Responsive.pagePadding(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                AppCard(
                  padding: EdgeInsets.all(Responsive.spaceLg),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SupportEmailAddress(),
                        const CopySupportEmail(),
                        Responsive.spaceLg.gapH,
                        DropdownButtonFormField<SupportTopic>(
                          initialValue: _topic,
                          decoration: InputDecoration(
                            labelText: l10n.supportCategory,
                          ),
                          isExpanded: true,
                          itemHeight: null,
                          items: [
                            for (final topic in SupportTopic.values)
                              DropdownMenuItem(
                                value: topic,
                                child: Text(topic.label(l10n)),
                              ),
                          ],
                          onChanged: (topic) {
                            if (topic != null) setState(() => _topic = topic);
                          },
                        ),
                        Responsive.spaceMd.gapH,
                        CustomTextField(
                          controller: _subject,
                          label: l10n.supportSubject,
                          hint: '${l10n.appName} – ${_topic.label(l10n)}',
                          textInputAction: TextInputAction.next,
                        ),
                        Responsive.spaceMd.gapH,
                        CustomTextField(
                          controller: _message,
                          label: l10n.supportMessage,
                          keyboardType: TextInputType.multiline,
                          minLines: 4,
                          maxLines: 8,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? l10n.supportMessageRequired
                              : null,
                        ),
                        Responsive.spaceLg.gapH,
                        CustomButton(
                          label: l10n.openEmailApp,
                          icon: Icons.open_in_new,
                          isLoading: _openingEmail,
                          onPressed: _openingEmail ? null : _compose,
                        ),
                        if (_emailUnavailable) ...[
                          Responsive.spaceMd.gapH,
                          Semantics(
                            liveRegion: true,
                            child: Text(l10n.noEmailApp),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
