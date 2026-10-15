import 'package:flutter/widgets.dart';

/// Single source for every on-screen string.
/// Getter names match the copy they return.
class L10n {
  const L10n(this.locale);

  final Locale locale;

  bool get _ar => locale.languageCode == 'ar';

  String _t(String en, String ar) => _ar ? ar : en;

  /// Locale digit display: Arabic-Indic when locale is Arabic (phones, OTP, counts).
  /// API payloads must use [DigitUtils.toWestern] / Validators.normalize* instead.
  String digits(String input) {
    if (!_ar) return input;
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final persianIndex = persian.indexOf(char);
      if (persianIndex >= 0) {
        buffer.write(eastern[persianIndex]);
        continue;
      }
      final unit = rune;
      if (unit >= 0x30 && unit <= 0x39) {
        buffer.write(eastern[unit - 0x30]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Locale-aware number for badges, counts, prices, etc.
  String n(num value) {
    if (value is int || value == value.roundToDouble()) {
      return digits('${value.round()}');
    }
    return digits('$value');
  }

  /// Amount with optional currency (e.g. prices).
  String formatPrice(num amount, [String currency = 'EGP']) =>
      '${n(amount)} $currency';

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n) ?? const L10n(Locale('en'));
  }

  static const supportedLocales = [Locale('en'), Locale('ar')];

  static const delegate = _L10nDelegate();

  // --- Shared ---
  String get appName => _t('Yalla 5roga', 'يلا خروجة');
  String get arabic => _t('العربية', 'العربية');
  String get english => _t('English', 'English');
  String get cancel => _t('Cancel', 'إلغاء');
  String get confirm => _t('Confirm', 'تأكيد');
  String get ok => _t('OK', 'حسناً');
  String get share => _t('Share', 'مشاركة');
  String get search => _t('Search', 'بحث');
  String get searchGroups => _t('Search groups', 'ابحث عن مجموعة');
  String get back => _t('Back', 'رجوع');
  String get edit => _t('Edit', 'تعديل');
  String get change => _t('Change', 'تغيير');
  String get today => _t('Today', 'اليوم');
  String get all => _t('All', 'الكل');
  String get owner => _t('Owner', 'المالك');
  String get member => _t('Member', 'عضو');
  String get members => _t('Members', 'الأعضاء');
  String get nothingHere => _t('Nothing here yet', 'لا يوجد شيء هنا بعد');
  String get nothingHereHint => _t(
    'When something new shows up, you’ll see it here.',
    'لما يظهر شيء جديد، هتشوفه هنا.',
  );
  String get noOutings => _t('No outings yet', 'لا توجد خروجات بعد');
  String get noOutingsHint => _t(
    'Plan something with your group to get started.',
    'خطّط خروجة مع مجموعتك للبدء.',
  );
  String get noOutingsInFilter =>
      _t('No outings in this tab', 'لا توجد خروجات في هذا التبويب');
  String get noOutingsInFilterHint => _t(
    'Try another filter or create a new plan.',
    'جرّب فلترًا آخر أو أنشئ خطة جديدة.',
  );
  String get noGroups => _t('No groups yet', 'لا توجد مجموعات بعد');
  String get noGroupsHint => _t(
    'Create a group and invite your friends.',
    'أنشئ مجموعة وادعُ أصحابك.',
  );
  String get noGroupsFound => _t('No groups found', 'لا توجد مجموعات');
  String get noGroupsFoundHint => _t(
    'Try a different name or clear the search.',
    'جرّب اسمًا آخر أو امسح البحث.',
  );
  String get noNotifications => _t('No notifications', 'لا توجد إشعارات');
  String get noNotificationsHint => _t(
    'You’re all caught up. New updates will land here.',
    'أنت على اطلاع. التحديثات الجديدة ستظهر هنا.',
  );
  String get noUnreadNotifications =>
      _t('No unread notifications', 'لا توجد إشعارات غير مقروءة');
  String get noUnreadNotificationsHint => _t(
    'Everything’s been read. Check All for the full feed.',
    'تمت قراءة الكل. راجع تبويب الكل للسجل الكامل.',
  );
  String get noChatMessages => _t('No messages yet', 'لا توجد رسائل بعد');
  String get noChatMessagesHint => _t(
    'Say hi and start planning the details.',
    'قل مرحباً وابدأوا ترتيب التفاصيل.',
  );
  String get noPlaces => _t('No places to show', 'لا أماكن للعرض');
  String get noPlacesHint => _t(
    'Try another vibe filter to explore nearby spots.',
    'جرّب فلتر أجواء آخر لاستكشاف أماكن قريبة.',
  );
  String get noFeaturedOuting =>
      _t('No featured outing', 'لا توجد خروجة مميزة');
  String get noFeaturedOutingHint =>
      _t('Your next plan will show up here.', 'خطتك القادمة ستظهر هنا.');
  String get noGoingYet => _t('No one listed yet', 'لا أحد مدرج بعد');
  String get noGoingYetHint => _t(
    'Members will appear here once they’re in.',
    'سيظهر الأعضاء هنا بعد الانضمام.',
  );
  String get noPlaceResultsHint => _t(
    'Try another name or pick a pin on the map.',
    'جرّب اسمًا آخر أو ضع علامة على الخريطة.',
  );
  String get date => _t('Date', 'التاريخ');
  String get time => _t('Time', 'الوقت');

  // --- Splash ---
  String get plansMadeSimple => _t('Plans made simple', 'خطط أسهل');
  String get splashHeadline1 => _t('Less “where?”', 'أقل «هنروح فين؟»');
  String get splashHeadline2 => _t('More “we’re there.”', 'أكثر «يلا بينا».');
  String get splashBody => _t(
    'Create a group, vote on the plan, and make the outing actually happen.',
    'كوّن مجموعة، صوّتوا على الخطة، وخلّوا الخروجة تحصل بجد.',
  );
  String get getStarted => _t('Get Started', 'ابدأ الآن');
  String get alreadyHaveAccount => _t(
    'I already have an account · Log in',
    'لدي حساب بالفعل · تسجيل الدخول',
  );
  String get splashPreviewBadge => _t('OUTING PLAN', 'خطة خروجة');
  String get splashPreviewTitle => _t('Your next outing', 'خروجتكم الجاية');
  String get splashPreviewSubtitle => _t('Friends are in', 'الأصحاب مشاركون');
  String get splashPreviewVoted => _t('Group voted ✓', 'المجموعة صوّتت ✓');
  String get seeYouThere => _t('See you there!', 'نشوفك هناك!');

  // --- Auth ---
  String get login => _t('Log In', 'تسجيل الدخول');
  String get register => _t('Sign Up', 'إنشاء حساب');
  String get createAccount => _t('Create Account', 'إنشاء حساب');
  String get password => _t('Password', 'كلمة المرور');
  String get name => _t('Full name', 'الاسم الكامل');
  String get phone => _t('Phone number', 'رقم الهاتف');
  String get phoneHint => digits(_t('100 123 4567', '100 123 4567'));
  String get phoneCountryCode => digits('+20');
  String get email => _t('Email', 'البريد الإلكتروني');
  String get emailHint => _t('name@example.com', 'name@example.com');
  String get nameTooShort => digits(
    _t(
      'Name must be at least 3 characters',
      'يجب أن يكون الاسم 3 أحرف على الأقل',
    ),
  );
  String get nameTooLong => digits(
    _t('Name must be at most 30 characters', 'يجب ألا يزيد الاسم عن 30 حرفاً'),
  );
  String get outingNameTooLong => digits(
    _t(
      'Outing name must be at most 20 characters',
      'يجب ألا يزيد اسم الخروجة عن 20 حرفاً',
    ),
  );
  String get passwordRequirements => digits(
    _t(
      'Use at least 8 characters with 1 uppercase, 1 lowercase, 1 number, and 1 symbol',
      'استخدم 8 أحرف على الأقل مع حرف كبير وحرف صغير ورقم ورمز',
    ),
  );
  String get editPassword => _t('Edit password', 'تعديل كلمة المرور');
  String get cancelEditPassword =>
      _t('Cancel password edit', 'إلغاء تعديل كلمة المرور');
  String get confirmWithPassword => _t(
    'Enter your current password to confirm changes',
    'أدخل كلمة المرور الحالية لتأكيد التغييرات',
  );
  String get invalidEmail =>
      _t('Enter a valid email address', 'أدخل بريداً إلكترونياً صالحاً');
  String get passwordHint => digits(
    _t(
      '8+ chars, upper, lower, number, symbol',
      '8+ أحرف، كبير وصغير ورقم ورمز',
    ),
  );
  String get nameHint => _t('Ahmed Hassan', 'أحمد حسن');
  String get forgotPassword => _t('Forgot password?', 'نسيت كلمة المرور؟');
  String get orContinueWith => _t('Or continue with', 'أو المتابعة عبر');
  String get continueWithGoogle =>
      _t('Continue with Google', 'المتابعة مع Google');
  String get continueWithApple =>
      _t('Continue with Apple', 'المتابعة مع Apple');
  String get verifyPhoneFirst => _t(
    'Verify your phone number before creating the account',
    'تحقق من رقم هاتفك قبل إنشاء الحساب',
  );
  String get emailAlreadyInUse => _t(
    'This email is already registered. Try logging in instead.',
    'هذا البريد مسجّل بالفعل. جرّب تسجيل الدخول.',
  );
  String get phoneAlreadyInUse => _t(
    'This phone number is already linked to another account.',
    'رقم الهاتف هذا مرتبط بحساب آخر بالفعل.',
  );
  String get accountExistsDifferentMethod => _t(
    'An account already exists with a different sign-in method. Try Google, Apple, or email login.',
    'يوجد حساب بنفس البيانات بطريقة دخول مختلفة. جرّب Google أو Apple أو البريد.',
  );
  String get accountDisabled => _t(
    'This account has been disabled. Contact support if you need help.',
    'تم تعطيل هذا الحساب. تواصل مع الدعم إذا احتجت مساعدة.',
  );
  String get signInMethodNotEnabled => _t(
    'This sign-in method is not available right now.',
    'طريقة تسجيل الدخول هذه غير متاحة حالياً.',
  );
  String get incorrectEmailOrPassword => _t(
    'Incorrect email or password. Check your details and try again.',
    'البريد الإلكتروني أو كلمة المرور غير صحيحة. راجع بياناتك وحاول مرة أخرى.',
  );
  String get socialSignInCancelled =>
      _t('Sign in cancelled', 'تم إلغاء تسجيل الدخول');
  String get appleSignInUnavailable => _t(
    'Apple Sign In is not available on this device',
    'تسجيل الدخول بـ Apple غير متاح على هذا الجهاز',
  );
  String get otp => _t('OTP code', 'رمز التحقق');
  String get otpHint => digits(_t('6-digit code', 'رمز من 6 أرقام'));
  String get invalidOtp => digits(
    _t(
      'Enter the 6-digit code sent to your phone',
      'أدخل الرمز المكوّن من 6 أرقام المرسل إلى هاتفك',
    ),
  );
  String otpSent(String phone) =>
      _t('OTP sent to $phone', 'تم إرسال رمز التحقق إلى $phone');
  String get resendOtp => _t('Resend code', 'إعادة إرسال الرمز');
  String get sendOtp => _t('Send OTP', 'إرسال رمز التحقق');
  String get requiredField => _t('This field is required', 'هذا الحقل مطلوب');
  String get invalidPhone =>
      _t('Enter a valid Egyptian phone number', 'أدخل رقم هاتف مصري صالح');
  String get passwordTooShort => passwordRequirements;
  String get loginFailed => _t('Login failed', 'فشل تسجيل الدخول');
  String get registerFailed => _t('Registration failed', 'فشل إنشاء الحساب');
  String get welcomeBack => _t('Welcome back', 'أهلاً بعودتك');
  String get welcomeNew => _t('Welcome', 'أهلاً بك');
  String get guestFallback => _t('Guest', 'ضيف');
  String get noInternet =>
      _t('No internet connection', 'لا يوجد اتصال بالإنترنت');
  String get connectionErrorTitle => _t('Connection error', 'خطأ في الاتصال');
  String get connectionErrorHint => _t(
    'Please check your Wi‑Fi or mobile data and try again.',
    'تحقق من الواي فاي أو بيانات الموبايل وحاول مرة أخرى.',
  );
  String get unexpectedError =>
      _t('Something went wrong. Please try again.', 'حدث خطأ. حاول مرة أخرى.');
  String get dataLoadFailed => _t(
    'Could not load data. Please try again.',
    'تعذّر تحميل البيانات. حاول مرة أخرى.',
  );
  String get dataSendFailed => _t(
    'Could not send data. Please try again.',
    'تعذّر إرسال البيانات. حاول مرة أخرى.',
  );
  String get letsGetYouOut => _t('Let’s get you out.', 'يلا نخرج.');
  String get joinTheFun => _t('Join the fun.', 'انضم للمتعة.');
  String get authLoginSubtitle => _t(
    'Sign in with your email to keep planning with friends.',
    'سجّل دخولك ببريدك الإلكتروني وكمّل التخطيط مع أصحابك.',
  );
  String get authSignupSubtitle => _t(
    'Create an account, verify your phone, and start making plans.',
    'أنشئ حساباً، تحقق من هاتفك، وابدأ التخطيط مع أصحابك.',
  );
  String get newHere => _t('New here?', 'جديد هنا؟');
  String get createYourAccount => _t('Create your account', 'أنشئ حسابك');
  String get alreadyMember => _t('Already a member?', 'لديك حساب بالفعل؟');
  String get agreeTerms => _t(
    'I agree to the Terms and Privacy Policy.',
    'أوافق على الشروط وسياسة الخصوصية.',
  );
  String get resetLinkSent => _t(
    'A reset code will be sent to your phone',
    'سيتم إرسال رمز الاستعادة إلى هاتفك',
  );
  String welcomeBackName(String name) =>
      _t('Welcome back, $name!', 'أهلاً بعودتك، $name!');
  String get accountCreated =>
      _t('Account created successfully!', 'تم إنشاء الحساب بنجاح!');
  String get termsRequired =>
      _t('Please agree to the Terms first', 'وافق على الشروط أولاً');

  // --- Navigation ---
  String get navHome => _t('Home', 'الرئيسية');
  String get navGroups => _t('Groups', 'المجموعات');
  String get navOutings => _t('Outings', 'الخروجات');
  String get navProfile => _t('Profile', 'الملف الشخصي');
  String get navSettings => _t('Settings', 'الإعدادات');
  String get settings => _t('Settings', 'الإعدادات');

  // --- Home ---
  String get goodMorning => _t('Good morning,', 'صباح الخير،');
  String get goodAfternoon => _t('Good afternoon,', 'مساء الخير،');
  String get goodEvening => _t('Good evening,', 'مساء الخير،');
  String greetingForHour(int hour) {
    if (hour < 12) return goodMorning;
    if (hour < 17) return goodAfternoon;
    return goodEvening;
  }

  String get nextUp => _t('Next up', 'الخروجة القادمة');
  String get quickActions => _t('Quick actions', 'إجراءات سريعة');
  String get makeItHappen => _t('Make it happen', 'خلّيها تحصل');
  String get newOuting => _t('New outing', 'خروجة جديدة');
  String get createSpecialEvent =>
      _t('Create a special event', 'إنشاء مناسبة خاصة');
  String get specialEventSubtitle => _t(
    'Plan a birthday, wedding, or celebration',
    'خطط لعيد ميلاد أو فرح أو احتفال',
  );
  String get newGroup => _t('New group', 'مجموعة جديدة');
  String get discover => _t('Discover', 'استكشف');
  String get invite => _t('Invite', 'ادعُ أصدقاءك');
  String get happeningNow => _t('Happening now', 'يحدث الآن');
  String get seeAll => _t('See all', 'عرض الكل');
  String get twoHoursLeft => digits(_t('2h left', 'متبقي ساعتان'));
  String get exploreNearby =>
      _t('Explore nearby places', 'استكشف الأماكن القريبة');
  String get inviteFriends => _t('Invite your friends', 'ادعُ أصدقاءك');
  String inviteDownloadMessage(String url) => _t(
    'Hey! Come plan outings with me on Yalla 5roga. Download the app: $url',
    'تعالى نخطط خروجتنا مع بعض على يلا خروجة. نزّل التطبيق من هنا: $url',
  );
  String get couldNotOpenWhatsApp =>
      _t('Could not open WhatsApp', 'تعذّر فتح واتساب');
  String get tryThis => _t('Try this', 'جرّب دي');
  String get suggestedForYou => _t('Suggested for you', 'مقترحة لك');
  String get discoverSubtitle => _t(
    'Browse places with vibes, prices, and hours',
    'تصفح أماكن بأجواء وأسعار ومواعيد',
  );
  String get nearbyPlaces => _t('Nearby places', 'أماكن قريبة');
  String get featuredPlaces => _t('Featured places', 'أماكن مميزة');
  String get allPlaces => _t('All places', 'كل الأماكن');
  String get aboutPlace => _t('About', 'عن المكان');
  String get prices => _t('Prices', 'الأسعار');
  String get workingHours => _t('Working hours', 'مواعيد العمل');
  String get closed => _t('Closed', 'مغلق');
  String get planOutingHere => _t('Plan an outing here', 'خطط خروجة هنا');
  String get otpSendFailed =>
      _t('Could not send verification code', 'تعذّر إرسال رمز التحقق');
  String get otpIncorrect => _t(
    'Wrong verification code. Please try again.',
    'رمز التحقق غير صحيح. حاول مرة أخرى.',
  );
  String get otpExpired => _t(
    'Verification code expired. Request a new one.',
    'انتهت صلاحية رمز التحقق. اطلب رمزاً جديداً.',
  );
  String get otpTooManyRequests => _t(
    'Too many attempts. Please try again later.',
    'محاولات كثيرة جداً. حاول لاحقاً.',
  );
  String get otpQuotaExceeded => _t(
    'SMS limit reached. Please try again later.',
    'تم الوصول لحد الرسائل. حاول لاحقاً.',
  );
  String get otpVerificationFailed => _t(
    'Phone verification failed. Please try again.',
    'فشل التحقق من الهاتف. حاول مرة أخرى.',
  );
  String get otpTimedOut => _t(
    'Timed out waiting for the verification code.',
    'انتهت مهلة انتظار رمز التحقق.',
  );
  String get otpAppNotConfigured => _t(
    'App verification failed. Check Firebase Phone Auth setup (SHA keys).',
    'فشل التحقق من التطبيق. راجع إعدادات Firebase Phone Auth (مفاتيح SHA).',
  );
  String get otpMissingSession =>
      _t('Request a verification code first.', 'اطلب رمز التحقق أولاً.');

  /// Maps Firebase / local auth error codes to localized copy.
  String phoneAuthError(String? code, {String? fallback}) =>
      authError(code, fallback: fallback);

  /// Maps Firebase / local auth error codes to localized copy.
  String authError(String? code, {String? fallback}) {
    return switch (code) {
      'invalid-phone-number' => invalidPhone,
      'invalid-verification-code' => otpIncorrect,
      'session-expired' || 'invalid-verification-id' => otpExpired,
      'too-many-requests' => otpTooManyRequests,
      'quota-exceeded' => otpQuotaExceeded,
      'network-request-failed' => noInternet,
      'verification-timeout' => otpTimedOut,
      'missing-verification' => otpMissingSession,
      'app-not-authorized' ||
      'captcha-check-failed' ||
      'missing-client-identifier' ||
      'invalid-app-credential' => otpAppNotConfigured,
      'verification-failed' => otpVerificationFailed,
      'invalid-email' => invalidEmail,
      'email-already-in-use' => emailAlreadyInUse,
      'credential-already-in-use' ||
      'provider-already-linked' => phoneAlreadyInUse,
      'account-exists-with-different-credential' =>
        accountExistsDifferentMethod,
      'user-disabled' => accountDisabled,
      'operation-not-allowed' => signInMethodNotEnabled,
      'weak-password' => passwordTooShort,
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => incorrectEmailOrPassword,
      'cancelled' => socialSignInCancelled,
      'apple-unavailable' => appleSignInUnavailable,
      'requires-recent-login' => requiresRecentLogin,
      _ =>
        fallback?.trim().isNotEmpty == true
            ? fallback!.trim()
            : unexpectedError,
    };
  }

  String get useThisIdea => _t('Use this idea', 'استخدم الفكرة');
  String get planThisOuting => _t('Plan this outing', 'خطط الخروجة');
  String get allVibes => _t('All vibes', 'كل الأجواء');
  String outingAtPlace(String place, String time) =>
      digits(_t('$place · $time', '$place · $time'));

  String priceLevelLabel(String level) => switch (level) {
    'free' => _t('Free', 'مجاني'),
    'budget' => _t('Budget', 'اقتصادي'),
    'moderate' => _t('Moderate', 'متوسط'),
    'expensive' => _t('Expensive', 'مرتفع'),
    'luxury' => _t('Luxury', 'فاخر'),
    _ => level,
  };

  String weekdayLabel(String day) => switch (day) {
    'monday' => _t('Monday', 'الاثنين'),
    'tuesday' => _t('Tuesday', 'الثلاثاء'),
    'wednesday' => _t('Wednesday', 'الأربعاء'),
    'thursday' => _t('Thursday', 'الخميس'),
    'friday' => _t('Friday', 'الجمعة'),
    'saturday' => _t('Saturday', 'السبت'),
    'sunday' => _t('Sunday', 'الأحد'),
    _ => day,
  };

  String discoverPriceLabel(String key) => switch (key) {
    'entry' => _t('Entry', 'دخول'),
    'parking' => _t('Parking', 'انتظار'),
    'brunch_set' => _t('Brunch set', 'وجبة برانش'),
    'coffee' => _t('Coffee', 'قهوة'),
    'games' => _t('Games', 'ألعاب'),
    'drinks' => _t('Drinks', 'مشروبات'),
    'bowling' => _t('Bowling', 'بولينج'),
    'food' => _t('Food', 'أكل'),
    'ticket' => _t('Ticket', 'تذكرة'),
    'combo' => _t('Combo', 'كومبو'),
    'dinner' => _t('Dinner', 'عشاء'),
    _ => key,
  };

  String vibeLabel(String vibe) => switch (vibe) {
    'food' => food,
    'activity' => activity,
    'outdoor' => outdoor,
    'movie' => movie,
    _ => all,
  };

  String suggestedArea(String area) => switch (area) {
    'New Cairo' => _t('New Cairo', 'القاهرة الجديدة'),
    'Maadi' => _t('Maadi', 'المعادي'),
    'Zamalek' => _t('Zamalek', 'الزمالك'),
    'Heliopolis' => _t('Heliopolis', 'مصر الجديدة'),
    'Islamic Cairo' => _t('Islamic Cairo', 'القاهرة الإسلامية'),
    'Garden City' => _t('Garden City', 'جاردن سيتي'),
    'Downtown' => _t('Downtown', 'وسط البلد'),
    'Cairo Festival City' => _t('Cairo Festival City', 'كايرو فستيفال سيتي'),
    _ => area,
  };

  // --- Groups ---
  String get yourCircles => _t('Your circles', 'دوائرك');
  String get groupsTitle => _t('Groups', 'المجموعات');
  String activeGroupsFriends(int groups, int friends) {
    final g = n(groups);
    final f = n(friends);
    return _t('$g active groups · $f friends', '$g مجموعات نشطة · $f صديقاً');
  }

  String get allGroups => _t('All groups', 'كل المجموعات');
  String get mostActive => _t('Most active', 'الأكثر نشاطاً');
  String get recentlyAdded => _t('Recently added', 'المضافة حديثاً');
  String get activeNow => _t('ACTIVE NOW', 'نشطة الآن');
  String get currentDecision => _t('CURRENT DECISION', 'القرار الحالي');
  String get whereShouldWeGo => _t('Where should we go?', 'هنروح فين؟');
  String votedCount(int voted, int total) {
    final v = n(voted);
    final t = n(total);
    return _t('$v/$t voted', 'صوّت $v/$t');
  }

  String get voteNow => _t('Vote now', 'صوّت الآن');
  String get startNewCircle => _t('Start a new circle', 'ابدأ مجموعة جديدة');
  String get inviteWithLink =>
      _t('Invite friends with one link', 'ادعُ أصدقاءك برابط واحد');
  String membersOutings(int members, int outings) {
    final m = n(members);
    final o = n(outings);
    return _t('$m members · $o outings', '$m أعضاء · $o خروجة');
  }

  String get createGroup => _t('Create a group', 'إنشاء مجموعة');
  String get groupName => _t('Group name', 'اسم المجموعة');
  String get groupNameHint => _t('Friday friends', 'أصدقاء الجمعة');
  String get invitePeople => _t('Invite people', 'دعوة أشخاص');
  String get addPeople => _t('Add people', 'إضافة أشخاص');
  String get addByPhone =>
      _t('Add people by phone number', 'إضافة أشخاص برقم الهاتف');
  String get addPhone => _t('Add', 'إضافة');
  String get phoneAlreadyAdded =>
      _t('This number is already added', 'هذا الرقم مضاف بالفعل');
  String get changeGroupImage =>
      _t('Choose a group photo', 'اختر صورة المجموعة');
  String get groupImageUpdated =>
      _t('Group photo updated', 'تم تحديث صورة المجموعة');
  String memberAdded(String name) =>
      _t('$name added to the group', 'تمت إضافة $name إلى المجموعة');
  String memberRemoved(String name) =>
      _t('$name removed from the group', 'تمت إزالة $name من المجموعة');
  String get noMorePeople => _t(
    'Everyone you know is already in this group',
    'كل من تعرفه موجود بالفعل في هذه المجموعة',
  );
  String get groupCreated => _t('Group created', 'تم إنشاء المجموعة');
  String get groupOutings => _t('Group outings', 'خروجات المجموعة');
  String get noGroupOutings => _t(
    'No outings yet. Create the first one.',
    'لا توجد خروجات بعد. أنشئ الأولى.',
  );
  String get chooseGroup => _t('Choose a group', 'اختر مجموعة');
  String get groupInfo => _t('Group info', 'معلومات المجموعة');
  String get groupActions => _t('Group actions', 'إجراءات المجموعة');
  String get groupBio => _t('About', 'عن المجموعة');
  String get groupBioHint =>
      _t('What is this group about?', 'عن ماذا تدور هذه المجموعة؟');
  String get noGroupBio => _t('No description yet', 'لا يوجد وصف بعد');
  String get activeVotes => _t('Active votes', 'التصويتات النشطة');
  String get activeVoting => _t('Active voting', 'التصويت النشط');
  String get noActiveVotes => _t(
    'No active votes yet. Start an outing to vote together.',
    'لا توجد تصويتات نشطة بعد. ابدأ خرجة للتصويت معاً.',
  );
  String get noActiveVotesHint => _t(
    'When a group starts voting, it will show up here.',
    'لما تبدأ مجموعة تصويت، هيظهر هنا.',
  );
  String get removeMember => _t('Remove', 'إزالة');
  String get removeMemberTitle => _t('Remove Member?', 'إزالة العضو؟');
  String removeMemberMessage(String name) => _t(
    'Are you sure you want to remove $name from this group?',
    'هل أنت متأكد أنك تريد إزالة $name من هذه المجموعة؟',
  );
  String get leaveGroup => _t('Leave Group', 'مغادرة المجموعة');
  String get leaveGroupTitle => _t('Leave Group?', 'مغادرة المجموعة؟');
  String get leaveGroupMessage => _t(
    'Are you sure you want to leave this group?',
    'هل أنت متأكد أنك تريد مغادرة هذه المجموعة؟',
  );
  String get leftGroup => _t('You left the group', 'غادرت المجموعة');

  // --- Outings ---
  String get makeAMemory => _t('Make a memory', 'اصنع ذكرى');
  String get outingsTitle => _t('Outings', 'الخروجات');
  String get plan => _t('New plan', 'خطّط جديدة');
  String get upcoming => _t('Upcoming', 'القادمة');
  String get voting => _t('Voting', 'التصويت');
  String get past => _t('Past', 'السابقة');
  String get thisWeekend => _t('This weekend', 'نهاية هذا الأسبوع');
  String get confirmed => _t('CONFIRMED', 'مؤكدة');
  String get youreIn => _t("You're in", 'أنت مشارك');
  String get viewPlan => _t('View plan', 'عرض الخطة');
  String get viewLocation => _t('View location', 'عرض الموقع');
  String get needsYourVote => _t('Needs your vote', 'تحتاج تصويتك');
  String endsInDuration(int hours, int minutes) {
    final h = n(hours);
    final m = n(minutes);
    return _t('Ends in ${h}h ${m}m', 'ينتهي خلال $h س $m د');
  }

  String get voteEnded => _t('Voting ended', 'انتهى التصويت');
  String get pickFavoritePlace =>
      _t('Pick one or more places', 'اختر مكاناً أو أكثر');
  String suggestedForVibe(String vibe) =>
      _t('Suggested for $vibe', 'مقترحات لـ $vibe');
  String get confirmVote => _t('Confirm vote', 'تأكيد التصويت');
  String get voteLocked => _t(
    'Your vote is locked and can no longer be changed',
    'تم قفل تصويتك ولا يمكن تغييره',
  );
  String get pickImInToVote =>
      _t("Pick I'm In to choose places", 'اختر "أنا مشارك" لاختيار الأماكن');
  String get notInCannotVotePlaces => _t(
    'Not In — place voting is disabled',
    'لن أحضر — تصويت الأماكن غير متاح',
  );
  String votesPercent(int votes, int percent) {
    final v = n(votes);
    final p = n(percent);
    return _t('$v votes · $p%', '$v أصوات · $p٪');
  }

  String get pickMultiplePlaces => digits(
    _t(
      'Pick 2 or more places for the group to vote on',
      'اختر مكانين أو أكثر لتصوّت عليهم المجموعة',
    ),
  );
  String placesSelected(int count) {
    final c = n(count);
    return _t('$c places selected', 'تم اختيار $c أماكن');
  }

  String get pickAtLeastTwoPlaces =>
      digits(_t('Please pick at least 2 places', 'اختر مكانين على الأقل'));
  String get voteDeadlineHours => _t('Vote closes after', 'يغلق التصويت بعد');
  String get voteDeadlineHint => _t(
    'Set how many hours members have to vote',
    'حدد عدد الساعات المتاحة للتصويت',
  );
  String hoursCount(int hours) {
    final h = n(hours);
    return _t('$h h', '$h س');
  }

  String voteClosesInHours(int hours) {
    final h = n(hours);
    return _t('Vote closes in $h hours', 'يغلق التصويت خلال $h ساعات');
  }

  String get suggestPlaces => _t('Suggest places', 'اقتراح أماكن');
  String get suggest => _t('Suggest', 'اقترح');
  String get suggestPlacesHint => _t(
    'Share place options and set a voting countdown for the group.',
    'شارك خيارات الأماكن وحدد عدّاد التصويت للمجموعة.',
  );
  String get suggestPlacesSheetHint => _t(
    'Pick places and how many hours the vote stays open.',
    'اختر الأماكن وعدد ساعات بقاء التصويت مفتوحاً.',
  );
  String get noPlaceSuggestions => _t(
    'No place suggestions yet. Be the first to add options.',
    'لا توجد اقتراحات أماكن بعد. كن أول من يضيف خيارات.',
  );
  String get publishSuggestion => _t('Publish suggestion', 'نشر الاقتراح');
  String get placesSuggested => _t(
    'Places suggested — group can vote now',
    'تم اقتراح الأماكن — المجموعة يمكنها التصويت الآن',
  );
  String suggestedBy(String name) => _t('Suggested by $name', 'اقترحه $name');
  String placesCount(int count) {
    final c = n(count);
    return _t('$c places', '$c أماكن');
  }

  String get youVoted => _t('You voted', 'صوّتّ');
  String get createOuting => _t('Create an outing', 'إنشاء خروجة');
  String get funStartsHere => _t('The fun starts here', 'المتعة تبدأ هنا');
  String get saveDraft => _t('Save draft', 'حفظ المسودة');
  String stepOf(int current, int total) {
    final c = n(current);
    final t = n(total);
    return _t('$c of $t', '$c من $t');
  }

  String get theBasics => _t('The basics', 'الأساسيات');
  String get whatAreWeDoing => _t('What are we doing?', 'هنعمل إيه؟');
  String get addEssentials => _t(
    'Add the essentials now. Your group can vote on the details next.',
    'أضف الأساسيات الآن، وبعدها المجموعة تصوّت على التفاصيل.',
  );
  String get outingName => _t('Outing name', 'اسم الخروجة');
  String get defaultOutingName => _t('New outing', 'خروجة جديدة');
  String get you => _t('You', 'أنت');
  String get now => _t('Now', 'الآن');
  String get lookingUpLocation =>
      _t('Finding this place…', 'جارٍ التعرف على المكان…');
  String get shareStarted => _t('Opening share…', 'جارٍ فتح المشاركة…');
  String get pickAVibe => _t('Pick a vibe', 'اختر الجو');
  String get food => _t('Food', 'أكل');
  String get activity => _t('Activity', 'نشاط');
  String get outdoor => _t('Outdoor', 'في الخارج');
  String get movie => _t('Movie', 'سينما');
  String get inviteAGroup => _t('Invite a group', 'ادعُ مجموعة');
  String membersWillBeInvited(int count) {
    final c = n(count);
    return _t('$c members will be invited', 'سيتم دعوة $c أعضاء');
  }

  String get saturday => _t('Saturday', 'السبت');
  String get startsAt => _t('Starts at', 'تبدأ الساعة');
  String get letGroupVote =>
      _t('Let the group vote on the place', 'دع المجموعة تصوّت على المكان');
  String get addPlacesForVoting =>
      _t('Add places for voting', 'أضف أماكن للتصويت');
  String get addPlacesForVotingHint => digits(
    _t(
      'Optional. Add 2–5 places so the group can vote.',
      'اختياري. أضف من 2 إلى 5 أماكن لتصوّت عليها المجموعة.',
    ),
  );
  String get everyoneCanSuggest => _t(
    'Everyone can suggest and vote before the deadline.',
    'يمكن للجميع الاقتراح والتصويت قبل الموعد.',
  );
  String get pickAtMostFivePlaces => digits(
    _t('You can pick up to 5 places', 'يمكنك اختيار 5 أماكن كحد أقصى'),
  );
  String placesSelectedMax(int count, int max) {
    final c = n(count);
    final m = n(max);
    return _t('$c of $m places selected', 'تم اختيار $c من $m أماكن');
  }

  String get chatClosed => _t('Chat is closed', 'المحادثة مغلقة');
  String get chatClosedHint => _t(
    'This outing has ended. You can still read past messages.',
    'انتهت هذه الخروجة. يمكنك قراءة الرسائل السابقة.',
  );
  String get locationAfterVoting => _t(
    'Location will be revealed when voting ends',
    'سيُكشف المكان عند انتهاء التصويت',
  );
  String get imIn => _t("I'm In", 'أنا مشارك');
  String get notIn => _t('Not In', 'لن أحضر');
  String get stillNotVoted => _t('Still Not Voted', 'لم يصوّت بعد');
  String get attendanceUpdated => _t('Attendance updated', 'تم تحديث الحضور');
  String get attendanceClosed =>
      _t('Attendance voting is closed', 'تصويت الحضور مغلق');
  String get attendanceTitle => _t('Are you going?', 'هل ستحضر؟');
  String get contactsAccessTitle =>
      _t('Allow contacts access?', 'السماح بالوصول لجهات الاتصال؟');
  String get contactsAccessBody => _t(
    'Yalla 5roga uses your contacts to show names you already saved for group members. Your contacts stay on this device.',
    'يلا خروجة تستخدم جهات اتصالك لعرض الأسماء المحفوظة لأعضاء المجموعة. تبقى جهات الاتصال على جهازك فقط.',
  );
  String get contactsOpenSettingsBody => _t(
    'Contacts access is turned off. Open app settings and enable contacts to see saved names.',
    'إذن جهات الاتصال مغلق. افتح إعدادات التطبيق وفعّل جهات الاتصال لعرض الأسماء المحفوظة.',
  );
  String get allowContacts => _t('Allow', 'السماح');
  String get continueToLocation =>
      _t('Continue to location', 'متابعة لاختيار المكان');
  String get draftSaved => _t('Draft saved', 'تم حفظ المسودة');
  String get outingSaved => _t('Outing saved', 'تم حفظ الخروجة');
  String get outingRemoved =>
      _t('Removed from saved', 'تمت الإزالة من المحفوظات');
  String get draftRemoved => _t('Draft deleted', 'تم حذف المسودة');
  String get mySaved => _t('My saved', 'محفوظاتي');
  String get mySavedSubtitle => _t(
    'Reuse a saved outing as a new plan',
    'استخدم خروجة محفوظة كخطة جديدة',
  );
  String savedCount(int count) {
    final c = n(count);
    return _t('$c saved', '$c محفوظ');
  }

  String get noSavedOutings => _t(
    'No saved outings yet. Bookmark one to reuse it later.',
    'لا توجد خروجات محفوظة. احفظ واحدة لتعيد استخدامها لاحقاً.',
  );
  String get drafts => _t('Drafts', 'المسودات');
  String get noDrafts => _t(
    'No drafts yet. Save a plan from the review step.',
    'لا توجد مسودات. احفظ خطة من خطوة المراجعة.',
  );
  String get specialEvent => _t('Special event', 'مناسبة خاصة');
  String get specialEventHint => _t(
    'Pick the occasion, then invite people from your groups.',
    'اختر المناسبة ثم ادعُ أشخاصاً من مجموعاتك.',
  );
  String get regularOuting => _t('Outing', 'خروجة');
  String get birthday => _t('Birthday', 'عيد ميلاد');
  String get wedding => _t('Wedding', 'فرح');
  String get eventName => _t('Event name', 'اسم المناسبة');
  String get invitePeopleHint =>
      _t('Choose people from your groups', 'اختر أشخاصاً من مجموعاتك');
  String get selectAll => _t('Select all', 'اختيار الكل');
  String get clearSelection => _t('Clear', 'مسح');
  String guestsInvited(int count) {
    final c = n(count);
    return _t('$c guests invited', 'تمت دعوة $c ضيوف');
  }

  /// Summary under the invite button on create special event.
  String youInvitedPeopleToEvent(int count, String occasionLabel) {
    final c = n(count);
    return _t(
      'You invited $c people to your $occasionLabel',
      'لقد دعوت $c أشخاص إلى $occasionLabel',
    );
  }

  String get guestsRequired =>
      _t('Please invite at least one person', 'ادعُ شخصاً واحداً على الأقل');
  String get searchPlace => _t('Search for a place', 'ابحث عن مكان');
  String get searchPlaceHint =>
      _t('Café, park, street…', 'كافيه، حديقة، شارع…');
  String get noPlaceResults => _t('No places found', 'لا توجد أماكن');
  String get currentLocation =>
      _t('Use current location', 'استخدم موقعي الحالي');
  String get locationPermissionDenied => _t(
    'Location permission is needed to pin where you are',
    'نحتاج إذن الموقع لتحديد مكانك',
  );
  String get locationDisabled => _t(
    'Turn on location services to use your current place',
    'فعّل خدمات الموقع لاستخدام مكانك الحالي',
  );
  String get couldNotGetLocation =>
      _t('Could not get your current location', 'تعذّر تحديد موقعك الحالي');
  String get locationAccessTitle =>
      _t('Allow location access?', 'السماح بالوصول للموقع؟');
  String get locationAccessBody => _t(
    'Yalla 5roga uses your location to pin where you are on the map when you pick a place.',
    'يلا خروجة تستخدم موقعك لتحديد مكانك على الخريطة عند اختيار المكان.',
  );
  String get allow => _t('Allow', 'السماح');
  String get allowLocation => _t('Allow', 'السماح');
  String get notNow => _t('Not now', 'ليس الآن');
  String get openAppSettings => _t('Open settings', 'فتح الإعدادات');
  String get permissionNeededTitle => _t('Permission required', 'إذن مطلوب');
  String get notificationAccessTitle =>
      _t('Allow notifications?', 'السماح بالإشعارات؟');
  String get notificationAccessBody => _t(
    'Yalla 5roga sends updates about outings, votes, and group activity. Allow notifications so you don’t miss anything.',
    'يلا خروجة ترسل تحديثات عن الخروجات والتصويت ونشاط المجموعات. اسمح بالإشعارات حتى لا يفوتك شيء.',
  );
  String get locationOpenSettingsBody => _t(
    'Location access is turned off. Open app settings and enable location to pin where you are.',
    'إذن الموقع مغلق. افتح إعدادات التطبيق وفعّل الموقع لتحديد مكانك.',
  );
  String get useSavedOuting => _t('Use this outing', 'استخدم هذه الخروجة');
  String get whoIsGoing => _t("Who's going", 'من سيذهب');
  String votedFor(String place) => _t('Voted for $place', 'صوّت لـ $place');
  String get votedGoing => _t('Going', 'سيذهب');
  String get notVotedYet => _t('Not voted yet', 'لم يصوّت بعد');
  // Prefer stillNotVoted / imIn / notIn for attendance UI.
  String get openingChat => _t('Opening outing chat', 'فتح محادثة الخروجة');
  String get voteUpdated => _t('Your vote has been updated', 'تم تحديث تصويتك');
  String get chooseLocationNext =>
      _t('Great! Let’s choose the location', 'رائع! لنختار المكان الآن');
  String get outingChat => _t('Outing chat', 'محادثة الخروجة');
  String get comingSoonFeature =>
      _t('Coming Soon feature', 'ميزة قادمة قريباً');
  String get writeMessage => _t('Write a message', 'اكتب رسالة');
  String get mentionSomeone => _t('Mention someone', 'أشّر على شخص');
  String get mentionAll => _t('Mention all', 'أشّر على الجميع');
  String get mentionAllLabel => _t('Everyone', 'الجميع');
  String get noMembersToMention =>
      _t('No group members to mention', 'لا يوجد أعضاء للإشارة إليهم');
  String get chooseLocation => _t('Choose a location', 'اختر المكان');
  String get pickAPlace => _t('Where should we meet?', 'هنتقابل فين؟');
  String get locationHint =>
      _t('Pick a custom place on the map', 'اختر مكاناً خاصاً من الخريطة');
  String get customPlace => _t('Custom place', 'مكان خاص');
  String get continueToReview => _t('Continue to review', 'متابعة للمراجعة');
  String get reviewOuting => _t('Review & create', 'مراجعة وإنشاء');
  String get almostThere => _t(
    'Check the plan, then publish it to the group.',
    'راجع الخطة ثم انشرها للمجموعة.',
  );
  String get createAndGo => _t('Create outing', 'إنشاء الخروجة');
  String get outingCreated => _t('Outing created', 'تم إنشاء الخروجة');
  String get photoRequired =>
      _t('Please upload an outing photo', 'ارفع صورة للخروجة');
  String get nameRequired => _t('Please add an outing name', 'أضف اسم الخروجة');
  String get locationRequired => _t('Please choose a location', 'اختر مكاناً');
  String get pickLocation => _t('Pick location', 'تحديد الموقع');
  String get pickOnMap =>
      _t('Pick this place on the map', 'حدّد المكان على الخريطة');
  String get locationPinned => _t('Location set', 'تم تحديد الموقع');
  String get changeMapLocation =>
      _t('Tap to change the pin', 'اضغط لتغيير العلامة');
  String get pickLocationRequired => _t(
    'Please pin this new place on the map',
    'حدّد المكان الجديد على الخريطة',
  );
  String get tapToPin =>
      _t('Tap the map to drop a pin', 'اضغط على الخريطة لوضع العلامة');
  String get confirmLocation => _t('Confirm location', 'تأكيد الموقع');
  String get groupRequired => _t('Please choose a group', 'اختر مجموعة');
  String hoursLeft(int hours) {
    final h = n(hours);
    return _t('${h}h left', 'متبقي $h س');
  }

  String goingCount(int count) {
    final c = n(count);
    return _t('$c going', '$c مشاركون');
  }

  // --- Notifications ---
  String get notifications => _t('Notifications', 'الإشعارات');
  String unreadUpdates(int count) {
    final c = n(count);
    return _t('$c unread updates', '$c إشعارات غير مقروءة');
  }

  String get markAllRead => _t('Mark all read', 'تعليم الكل كمقروء');
  String get allRead => _t('All read', 'تمت القراءة');
  String get unread => _t('Unread', 'غير المقروءة');
  String get earlier => _t('Earlier', 'سابقاً');
  String get allNotificationsRead =>
      _t('All notifications marked as read', 'تم تعليم كل الإشعارات كمقروءة');
  String get pushNotificationsReady => _t(
    'Push notifications are ready on this device',
    'إشعارات الدفع جاهزة على هذا الجهاز',
  );
  String get pushPermissionDenied => _t(
    'Notifications are turned off. Enable them in settings to get outing updates.',
    'الإشعارات مغلقة. فعّلها من الإعدادات لاستلام تحديثات الخروجات.',
  );
  String get pushTokenUnavailable => _t(
    'Could not get a push token right now. Try again later.',
    'تعذّر الحصول على رمز الإشعارات الآن. حاول لاحقاً.',
  );
  String get pushOpenFailed =>
      _t('Could not open that notification', 'تعذّر فتح هذا الإشعار');

  // --- Profile ---
  String get yourSpace => _t('Your space', 'مساحتك');
  String get profile => _t('Profile', 'الملف الشخصي');
  String get outingsStat => _t('Outings', 'الخروجات');
  String get groupsStat => _t('Groups', 'المجموعات');
  String get showUp => _t('Show-up', 'الحضور');
  String get about => _t('About', 'حول');
  String get activityTab => _t('Activity', 'النشاط');
  String get personalDetails => _t('Personal details', 'البيانات الشخصية');
  String get accountSettings => _t('Account setting', 'إعدادات الحساب');
  String get language => _t('Language', 'اللغة');
  String get support => _t('Support', 'الدعم');
  String get helpAndFaq => _t('Help & FAQ', 'المساعدة والأسئلة');
  String get contactUs => _t('Contact Us', 'تواصل معنا');
  String get aboutYalla5roga => _t('About Yalla 5roga', 'عن يلا خروجة');
  String get privacyPolicy => _t('Privacy Policy', 'سياسة الخصوصية');
  String get termsAndConditions => _t('Terms & Conditions', 'الشروط والأحكام');
  String get developer => _t('Developer', 'المطوّر');
  String get faqCreateOuting =>
      _t('How do I create an outing?', 'إزاي أعمل خروجة؟');
  String get faqCreateOutingAnswer => _t(
    'Open Outings or a group, tap Plan or Create outing, then add a photo, place, date, and invite your group.',
    'افتح الخروجات أو مجموعة، اضغط خطّط أو إنشاء خروجة، ثم أضف صورة ومكان وتاريخ وادعُ مجموعتك.',
  );
  String get faqGroups => _t('How do groups work?', 'المجموعات بتشتغل إزاي؟');
  String get faqGroupsAnswer => _t(
    'Create a group, add people by phone, then plan outings together and vote on the details.',
    'أنشئ مجموعة، أضف الناس برقم الهاتف، ثم خططوا الخروجات مع بعض وصوّتوا على التفاصيل.',
  );
  String get faqInvite => _t('How do I invite friends?', 'إزاي أدعو أصحابي؟');
  String get faqInviteAnswer => _t(
    'From a group, tap Add people and enter an Egyptian phone number. They will be invited to that group.',
    'من صفحة المجموعة اضغط إضافة أشخاص وأدخل رقم هاتف مصري. هيتضافوا للمجموعة.',
  );
  String get aboutAppBody => _t(
    'Yalla 5roga helps friends plan real outings. Create a group, vote on the place and time, and make the plan actually happen.',
    'يلا خروجة بتساعد الأصحاب يخططوا خروجات بجد. كوّنوا مجموعة، صوّتوا على المكان والوقت، وخلّوا الخطة تحصل.',
  );
  String get privacyPolicyBody => _t(
    'We store your name, phone number, and the photos you choose to upload so you can sign in and plan outings with your groups. We do not sell your personal data. You can delete your account from Profile at any time.',
    'بنحفظ اسمك ورقم هاتفك والصور اللي ترفعها عشان تسجّل وتخطط الخروجات مع مجموعاتك. مش بنبيع بياناتك. تقدر تحذف حسابك من الملف الشخصي في أي وقت.',
  );
  String get termsBody => _t(
    'By using Yalla 5roga you agree to use the app respectfully, invite only people you know, and keep group chats and photos appropriate. Plans and votes are for coordinating outings, not for commercial spam.',
    'باستخدام يلا خروجة بتوافق تستخدم التطبيق باحترام، وتدعو ناس تعرفهم، وتحافظ على المحادثات والصور بشكل لائق. الخطط والتصويت للتنسيق على الخروجات مش للإعلانات.',
  );
  String get memberSince => _t('Member since', 'عضو منذ');
  String get preferences => _t('Preferences', 'التفضيلات');
  String get pushNotifications => _t('Push notifications', 'الإشعارات');
  String get votesPlansReminders =>
      _t('Votes, plans, reminders', 'التصويتات والخطط والتذكيرات');
  String get locationSuggestions =>
      _t('Location suggestions', 'اقتراحات الأماكن');
  String get betterNearby =>
      _t('Better nearby recommendations', 'اقتراحات أفضل بالقرب منك');
  String get darkTheme => _t('Dark theme', 'الوضع الداكن');
  String get useDarkColors => _t(
    'Use dark colors across the app',
    'استخدام الألوان الداكنة في التطبيق',
  );
  String get appLanguage => _t('App language', 'لغة التطبيق');
  String get englishUS => _t('English (US)', 'الإنجليزية (US)');
  String get themeChanged => _t('Theme updated', 'تم تحديث المظهر');
  String get languageChanged => _t('Language updated', 'تم تحديث اللغة');
  String get logOut => _t('Log out', 'تسجيل الخروج');
  String get signedOut => _t('Signed out safely', 'تم تسجيل الخروج بأمان');
  String get editProfile => _t('Edit profile', 'تعديل الملف');
  String get profileSettings => _t('Profile settings', 'إعدادات الملف');
  String get currentPassword => _t('Current password', 'كلمة المرور الحالية');
  String get newPassword => _t('New password', 'كلمة المرور الجديدة');
  String get confirmNewPassword =>
      _t('Confirm new password', 'تأكيد كلمة المرور الجديدة');
  String get passwordsDoNotMatch =>
      _t('Passwords do not match', 'كلمتا المرور غير متطابقتين');
  String get emailChangeSent => _t(
    'Check your new email and confirm the change',
    'تحقق من بريدك الجديد وأكّد التغيير',
  );
  String get passwordUpdated => _t('Password updated', 'تم تحديث كلمة المرور');
  String get phoneVerified =>
      _t('Phone number verified', 'تم التحقق من رقم الهاتف');
  String get phoneUpdated => _t('Phone number updated', 'تم تحديث رقم الهاتف');
  String get socialAccountHint => _t(
    'Signed in with Google or Apple — email and password are managed by that provider.',
    'سجّلت الدخول عبر Google أو Apple — البريد وكلمة المرور يديرهما مزوّد الحساب.',
  );
  String get logoutConfirmTitle => _t('Log out?', 'تسجيل الخروج؟');
  String get logoutConfirmBody => _t(
    'You can sign back in anytime with your email or social account.',
    'يمكنك العودة في أي وقت ببريدك أو حساب التواصل الاجتماعي.',
  );
  String get changeProfileImage =>
      _t('Choose a profile photo', 'اختر صورة الملف');
  String get saveChanges => _t('Save changes', 'حفظ التغييرات');
  String get profileUpdated => _t('Profile updated', 'تم تحديث الملف');
  String get requiresRecentLogin => _t(
    'Please sign in again to change this info',
    'سجّل الدخول مرة أخرى لتغيير هذه البيانات',
  );
  String get deleteAccount => _t('Delete account', 'حذف الحساب');
  String get deleteAccountTitle => _t('Delete account?', 'حذف الحساب؟');
  String get deleteAccountBody => _t(
    'This will remove your account from this device. You can create a new one anytime.',
    'سيتم حذف حسابك من هذا الجهاز. يمكنك إنشاء حساب جديد في أي وقت.',
  );
  String get accountDeleted => _t('Account deleted', 'تم حذف الحساب');
  String get aboutDeveloper => _t('About Developer', 'عن المطوّر');
  String get developerName => _t('Mohamed Mohamed Salah', 'محمد محمد صلاح');
  String get developerInitials => _t('MS', 'مس');
  String get developerTitle =>
      _t('Full-Stack Mobile App Developer', 'مطوّر تطبيقات موبايل متكامل');
  String get developerTagline => _t(
    'Building complete mobile experiences from frontend to backend.',
    'بناء تجارب موبايل كاملة من الواجهة إلى الخادم.',
  );
  String get developerDescription => _t(
    'Yalla 5roga is designed and developed by Mohamed Mohamed Salah, a Full-Stack Mobile App Developer focused on building modern mobile applications, robust backend APIs, and scalable database systems.',
    'يلا خروجة صمّمها وطوّرها محمد محمد صلاح، مطوّر تطبيقات موبايل متكامل يركّز على بناء تطبيقات حديثة وواجهات برمجية قوية وأنظمة قواعد بيانات قابلة للتوسّع.',
  );
  String get developerShortDescription => _t(
    'Yalla 5roga is designed and developed by Mohamed Mohamed Salah, a Flutter Developer focused on building modern mobile applications and scalable backend systems.',
    'يلا خروجة صمّمها وطوّرها محمد صلاح، مطوّر فلاتر يركّز على بناء تطبيقات موبايل حديثة وأنظمة خلفية قابلة للتوسّع.',
  );
  String get github => _t('GitHub', 'GitHub');
  String get viewMyProjects => _t('View my projects', 'عرض مشاريعي');
  String get portfolio => _t('Portfolio', 'معرض الأعمال');
  String get viewMyPortfolio => _t('View my portfolio', 'عرض معرض أعمالي');
  String get contactDeveloper => _t('Contact Developer', 'تواصل مع المطوّر');
  String get getInTouch => _t('Get in touch', 'تواصل معي');
  String get couldNotOpenLink =>
      _t('Could not open this link', 'تعذّر فتح هذا الرابط');

  // --- Images ---
  String get uploadPhoto =>
      _t('Upload photo from device', 'رفع صورة من الجهاز');
  String get chooseFromGallery => _t('Choose from gallery', 'اختيار من المعرض');
  String get takePhoto => _t('Take a photo', 'التقاط صورة');
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<L10n> load(Locale locale) async => L10n(locale);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}
