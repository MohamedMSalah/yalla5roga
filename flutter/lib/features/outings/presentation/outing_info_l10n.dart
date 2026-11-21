import 'package:yalla_5roga/core/localization/l10n.dart';

extension OutingInfoL10n on L10n {
  bool get _arabic => locale.languageCode == 'ar';
  String get outingGroupLabel => _arabic ? 'المجموعة' : 'Group';
  String get outingActionsLabel =>
      _arabic ? 'خيارات الخروجة' : 'Outing actions';
  String get outingPhotosLabel => _arabic ? 'صور الخروجة' : 'Outing photos';
  String get outingAboutTitle => _arabic ? 'عن الخروجة' : 'About this outing';
  String get outingGuestPrompt =>
      _arabic ? 'بلّغ منظّم المناسبة.' : 'Let the organizer know.';
  String get outingRosterUnavailable => _arabic
      ? 'قائمة المشاركين غير متاحة.'
      : 'The participant list is unavailable.';
  String get outingRsvpPreview =>
      _arabic ? 'الرد متاح للمشاركين.' : 'Participants can respond here.';
  String get outingArrivalPrompt => _arabic
      ? 'سجّل وصولك عند الوصول إلى المكان.'
      : 'Check in when you reach the place.';
  String get outingArrivalSubmitting =>
      _arabic ? 'جاري تسجيل الوصول…' : 'Submitting check-in…';
  String get outingArrivalSubmitFailed => _arabic
      ? 'تعذّر تسجيل الوصول. حاول مرة أخرى.'
      : 'Could not check in. Try again.';
  String get outingArrivalUnavailable =>
      _arabic ? 'تسجيل الوصول غير متاح.' : 'Check-in is unavailable.';
  String get outingArrivalLocationSettings =>
      _arabic ? 'إعدادات الموقع' : 'Location settings';
  String get outingLocationPending =>
      _arabic ? 'لم يتأكد المكان بعد' : 'Location pending';
  String get outingTieBadge =>
      _arabic ? 'تعادل، القرار مطلوب' : 'Tie — Decision needed';
  String get outingTieTitle => _arabic ? 'التصويت تعادل!' : 'It’s a tie!';
  String get outingTieSubtitle => _arabic
      ? 'حصل أكثر من مكان على نفس عدد الأصوات.'
      : 'Multiple places received the same number of votes.';
  String get outingTied => _arabic ? 'متعادل' : 'Tied';
  String get outingRevoteTitle =>
      _arabic ? 'ابدأ إعادة التصويت' : 'Start a re-vote';
  String get outingRevoteSubtitle => _arabic
      ? 'صوّت مرة أخرى بين الأماكن المتعادلة.'
      : 'Vote again between the tied places.';
  String get outingDiceSubtitle => _arabic
      ? 'دع القرعة تختار المكان النهائي.'
      : 'Let chance choose the final place.';
  String get outingDiceChoosing => _arabic
      ? 'جاري اختيار وجهتكم التالية…'
      : 'Choosing your next destination…';
  String get outingWinnerTitle =>
      _arabic ? 'تم اختيار المكان!' : 'We have a winner!';
  String get outingViewPlace => _arabic ? 'عرض المكان' : 'View place';
  String get outingWinnerLoadFailed =>
      _arabic ? 'تعذّر تأكيد نتيجة القرعة.' : 'Could not confirm the result.';

  String outingResponses(int count) {
    final value = n(count);
    if (!_arabic) return count == 1 ? '1 response' : '$value responses';
    if (count == 1) return 'رد واحد';
    if (count == 2) return 'ردّان';
    return count >= 3 && count <= 10 ? '$value ردود' : '$value رد';
  }

  String outingArrivalRatio(int arrived, int total) => _arabic
      ? 'وصل ${n(arrived)} من ${n(total)}'
      : '${n(arrived)} / ${n(total)} arrived';
}
