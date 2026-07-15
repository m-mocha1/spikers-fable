// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'سبايكرز القدس';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get emailHint => 'أدخل بريدك الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordHint => 'أدخل كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get confirmPasswordHint => 'أعد إدخال كلمة المرور';

  @override
  String get name => 'الاسم الكامل';

  @override
  String get nameHint => 'أدخل اسمك الكامل';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get sendResetEmail => 'إرسال رابط الاستعادة';

  @override
  String get noAccount => 'ليس لديك حساب؟';

  @override
  String get haveAccount => 'لديك حساب بالفعل؟';

  @override
  String get male => 'ذكر';

  @override
  String get female => 'أنثى';

  @override
  String get mixed => 'مختلط';

  @override
  String get gender => 'الجنس';

  @override
  String get audience => 'الفئة المستهدفة';

  @override
  String get optional => 'اختياري';

  @override
  String get notSet => 'غير محدد';

  @override
  String get completeProfile => 'إكمال الملف الشخصي';

  @override
  String get dateOfBirth => 'تاريخ الميلاد';

  @override
  String get selectDate => 'اختر التاريخ';

  @override
  String get role => 'الدور';

  @override
  String get player => 'لاعب';

  @override
  String get coach => 'مدرب';

  @override
  String get coachKey => 'رمز المدرب';

  @override
  String get coachKeyHint => 'أدخل رمز المدرب';

  @override
  String get sessions => 'الجلسات';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get createSession => 'إنشاء جلسة';

  @override
  String get availableCoaches => 'المدربون المتاحون';

  @override
  String get customSession => 'جلسة مخصصة';

  @override
  String get customSessionSubtitle =>
      'الأعضاء المحددون فقط يمكنهم رؤية هذه الجلسة';

  @override
  String get chooseMembers => 'اختيار الأعضاء';

  @override
  String membersSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محدد',
      many: '$count محدداً',
      few: '$count محددين',
      two: '$count محددان',
      one: '$count محدد',
      zero: '$count محدد',
    );
    return '$_temp0';
  }

  @override
  String get selectMembersError => 'اختر عضوًا واحدًا على الأقل';

  @override
  String get adminTesting => 'المشرف · اختبار';

  @override
  String get notifyOnCreate => 'إشعار اللاعبين والمدربين';

  @override
  String get notifyOnCreateSubtitle =>
      'أوقفه لإنشاء وإلغاء هذه الجلسة بصمت — لن يتم إرسال أي إشعارات';

  @override
  String get sessionArt => 'تصميم البطاقة';

  @override
  String get sessionArtRandom => 'عشوائي';

  @override
  String sessionArtCard(int number) {
    return 'بطاقة $number';
  }

  @override
  String get searchMembers => 'البحث عن الأعضاء';

  @override
  String get membersOnly => 'للأعضاء المحددين فقط';

  @override
  String get done => 'تم';

  @override
  String get editMembers => 'تعديل الأعضاء';

  @override
  String get membersUpdated => 'تم تحديث الأعضاء';

  @override
  String get makePublic => 'جعلها عامة';

  @override
  String get makePublicSubtitle => 'اختر من يمكنه رؤية هذه الجلسة الآن';

  @override
  String get sessionMadePublic => 'أصبحت الجلسة عامة الآن';

  @override
  String get sessionTitle => 'عنوان الجلسة';

  @override
  String get sessionTitleHint => 'مثال: تدريب الصباح';

  @override
  String get location => 'الموقع';

  @override
  String get locationHint => 'مثال: قاعة القدس الرياضية';

  @override
  String get minAge => 'أقل عمر';

  @override
  String get maxAge => 'أكبر عمر';

  @override
  String get startTime => 'وقت البداية';

  @override
  String get endTime => 'وقت الانتهاء';

  @override
  String get maxPlayers => 'أقصى عدد لاعبين';

  @override
  String get joinSession => 'الانضمام';

  @override
  String get leaveSession => 'مغادرة';

  @override
  String get cancelSession => 'إلغاء الجلسة';

  @override
  String get sessionFull => 'الجلسة ممتلئة';

  @override
  String spotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكان متبقي',
      many: '$count مكاناً متبقياً',
      few: '$count أماكن متبقية',
      two: 'مكانان متبقيان',
      one: 'مكان واحد متبقٍ',
      zero: 'لا أماكن متبقية',
    );
    return '$_temp0';
  }

  @override
  String get attendees => 'المشاركون';

  @override
  String get noSessions => 'لا توجد جلسات متاحة';

  @override
  String get noSessionsDesc => 'تحقق لاحقاً من الجلسات القادمة';

  @override
  String get completeProfileForSessions => 'أكمل ملفك الشخصي';

  @override
  String get completeProfileForSessionsDesc =>
      'أضف الجنس وتاريخ الميلاد حتى نعرض لك الجلسات المناسبة لك.';

  @override
  String get sessionCreated => 'تم إنشاء الجلسة بنجاح';

  @override
  String get sessionCancelled => 'تم إلغاء الجلسة';

  @override
  String get sessionEnded => 'انتهت الجلسة';

  @override
  String get sessionEndedSubtitle => 'أحسنتم!';

  @override
  String get newSession => 'جلسة جديدة';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get switchLanguage => 'English';

  @override
  String get requiredField => 'هذا الحقل مطلوب';

  @override
  String get invalidEmail => 'أدخل بريداً إلكترونياً صحيحاً';

  @override
  String get passwordTooShort => 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get invalidCoachKey => 'رمز المدرب غير صحيح';

  @override
  String get emailAlreadyInUse => 'هذا البريد مسجّل مسبقاً. جرّب تسجيل الدخول.';

  @override
  String get userNotFound => 'لا يوجد حساب بهذا البريد الإلكتروني.';

  @override
  String get wrongPassword => 'بريد إلكتروني أو كلمة مرور غير صحيحة';

  @override
  String get tooManyRequests => 'محاولات كثيرة. انتظر لحظة وحاول مجدداً.';

  @override
  String get userDisabled => 'تم تعطيل هذا الحساب. تواصل مع الدعم.';

  @override
  String get networkError => 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة.';

  @override
  String get unknownError => 'حدث خطأ ما. حاول مجدداً.';

  @override
  String get cameraPermissionTitle => 'إذن الكاميرا مطلوب';

  @override
  String get cameraPermissionMessage =>
      'اسمح بالوصول إلى الكاميرا من الإعدادات لالتقاط صورة الملف الشخصي.';

  @override
  String get permissionDenied =>
      'تم رفض الإذن. يمكنك تفعيله في أي وقت من الإعدادات.';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get myAccount => 'حسابي';

  @override
  String get age => 'العمر';

  @override
  String get years => 'سنة';

  @override
  String ageYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سنة',
      many: '$count سنة',
      few: '$count سنوات',
      two: 'سنتان',
      one: 'سنة واحدة',
      zero: '$count سنة',
    );
    return '$_temp0';
  }

  @override
  String get upcoming => 'قادم';

  @override
  String get ongoing => 'جارٍ';

  @override
  String get startsIn => 'يبدأ خلال';

  @override
  String get endsIn => 'ينتهي في';

  @override
  String countdownDays(int days) {
    return '$daysي';
  }

  @override
  String countdownHoursMinutes(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String countdownMinutes(int minutes) {
    return '$minutes د';
  }

  @override
  String get unitDays => 'يوم';

  @override
  String get unitHours => 'ساعة';

  @override
  String get unitMinutes => 'دقيقة';

  @override
  String get unitSeconds => 'ثانية';

  @override
  String get confirm => 'تأكيد';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirmCancelSession => 'إلغاء الجلسة';

  @override
  String get confirmCancelMessage =>
      'هل أنت متأكد من رغبتك في إلغاء هذه الجلسة؟ سيتم إخطار المشاركين.';

  @override
  String get ageRange => 'الفئة العمرية';

  @override
  String ageRangeYears(int min, int max) {
    return '$min – $max سنة';
  }

  @override
  String players(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لاعب',
      many: 'لاعباً',
      few: 'لاعبين',
      two: 'لاعبان',
      one: 'لاعب',
      zero: 'لاعبين',
    );
    return '$_temp0';
  }

  @override
  String get full => 'ممتلئة';

  @override
  String get live => 'مباشر';

  @override
  String get sessionInfo => 'معلومات الجلسة';

  @override
  String get coachLabel => 'المدرب';

  @override
  String joinedCount(int count, int max) {
    return '$count/$max لاعب';
  }

  @override
  String get sessionDate => 'التاريخ';

  @override
  String get genderMixed => 'مختلط';

  @override
  String get coachSessions => 'جلساتي';

  @override
  String get endTimeError => 'وقت الانتهاء يجب أن يكون بعد وقت البدء';

  @override
  String get invalidAgeRange =>
      'الحد الأدنى للعمر لا يمكن أن يتجاوز الحد الأقصى';

  @override
  String get errorOccurred => 'حدث خطأ';

  @override
  String get quickSession => 'جلسة سريعة';

  @override
  String get selectTemplate => 'اختر نموذجاً';

  @override
  String get saveAsTemplate => 'حفظ كنموذج';

  @override
  String get noTemplates => 'لا توجد نماذج بعد';

  @override
  String get noTemplatesDesc => 'أنشئ جلسة وفعّل خيار حفظ كنموذج لحفظها هنا';

  @override
  String get templateSaved => 'تم حفظ النموذج';

  @override
  String get chat => 'الدردشة';

  @override
  String get typeMessage => 'اكتب رسالة...';

  @override
  String get chatEmpty => 'لا توجد رسائل بعد. ابدأ المحادثة!';

  @override
  String get attended => 'حضر';

  @override
  String get notAttended => 'غائب';

  @override
  String attendedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حضر $count',
      many: 'حضر $count',
      few: 'حضر $count',
      two: 'حضر اثنان',
      one: 'حضر واحد',
      zero: 'لم يحضر أحد',
    );
    return '$_temp0';
  }

  @override
  String sessionsAttended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حضر $count جلسة',
      many: 'حضر $count جلسة',
      few: 'حضر $count جلسات',
      two: 'حضر جلستين',
      one: 'حضر جلسة واحدة',
      zero: 'لم يحضر أي جلسة',
    );
    return '$_temp0';
  }

  @override
  String get exportAttendance => 'تصدير قائمة الحضور';

  @override
  String get sessionsAttendedTitle => 'عدد مرات الحضور';

  @override
  String get registrationDate => 'تاريخ التسجيل';

  @override
  String get lastSessionDate => 'تاريخ آخر حضور';

  @override
  String get lastPaidDate => 'تاريخ آخر دفعة';

  @override
  String get membershipStatus => 'حالة العضوية';

  @override
  String get membershipExpiry => 'تاريخ انتهاء العضوية';

  @override
  String get membershipLifetime => 'عضوية دائمة';

  @override
  String get export => 'تصدير';

  @override
  String get exportColumns => 'الأعمدة المضمّنة';

  @override
  String playersWillBeExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سيتم تصدير $count لاعب',
      many: 'سيتم تصدير $count لاعبًا',
      few: 'سيتم تصدير $count لاعبين',
      two: 'سيتم تصدير لاعبين',
      one: 'سيتم تصدير لاعب واحد',
      zero: 'لن يتم تصدير أي لاعب',
    );
    return '$_temp0';
  }

  @override
  String get addPhoto => 'أضف صورة';

  @override
  String get changePhoto => 'تغيير الصورة';

  @override
  String get pickFromGallery => 'المعرض';

  @override
  String get takePhoto => 'الكاميرا';

  @override
  String get photoUpdated => 'تم تحديث صورة الملف الشخصي';

  @override
  String get playersTab => 'اللاعبون';

  @override
  String get coachesTab => 'المدربون';

  @override
  String get allGenders => 'الكل';

  @override
  String get noPlayers => 'لا يوجد لاعبون';

  @override
  String get noPlayersMatch => 'لا يوجد لاعبون مطابقون لبحثك';

  @override
  String get searchPlayers => 'ابحث عن لاعبين';

  @override
  String get noCoaches => 'لا يوجد مدربون';

  @override
  String coachesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مدرب',
      many: '$count مدربًا',
      few: '$count مدربين',
      two: 'مدربان',
      one: 'مدرب واحد',
      zero: 'لا مدربين',
    );
    return '$_temp0';
  }

  @override
  String get viewProfile => 'عرض الملف الشخصي';

  @override
  String get paid => 'نشط';

  @override
  String get unpaid => 'غير نشط';

  @override
  String get lifetime => 'عضوية دائمة';

  @override
  String get lifetimeMember => 'هذا العضو يملك عضوية دائمة.';

  @override
  String get injured => 'مصاب';

  @override
  String get payment => 'العضوية';

  @override
  String get paymentRequired => 'العضوية غير نشطة';

  @override
  String get paymentRequiredDesc =>
      'عضويتك في النادي غير نشطة. تواصل مع المدرب للتجديد.';

  @override
  String confirmMarkPaid(String name) {
    return 'تفعيل عضوية $name؟';
  }

  @override
  String confirmMarkUnpaid(String name) {
    return 'إلغاء تفعيل عضوية $name؟';
  }

  @override
  String get delete => 'حذف';

  @override
  String get deleteAccountTitle => 'حذف الحساب';

  @override
  String deleteAccountConfirm(String name) {
    return 'حذف حساب $name نهائياً؟ سيؤدي ذلك إلى إزالة تسجيل دخوله وجميع بياناته ولا يمكن التراجع عن ذلك.';
  }

  @override
  String get accountDeleted => 'تم حذف الحساب';

  @override
  String get deleteMyAccountTitle => 'حذف حسابي';

  @override
  String get deleteMyAccountConfirm =>
      'حذف حسابك نهائياً؟ سيؤدي ذلك إلى إزالة تسجيل دخولك وجميع بياناتك ولا يمكن التراجع عن ذلك.';

  @override
  String get deleteMyAccountError => 'تعذّر حذف حسابك. يرجى المحاولة مرة أخرى.';

  @override
  String get remove => 'إزالة';

  @override
  String get removePlayer => 'إزالة لاعب';

  @override
  String confirmRemovePlayer(String name) {
    return 'إزالة ⁨$name⁩ من هذه الجلسة؟';
  }

  @override
  String daysLeft(int days) {
    return '$days يوم متبقي';
  }

  @override
  String get verifyEmailTitle => 'تأكيد البريد الإلكتروني';

  @override
  String verifyEmailBody(String email) {
    return 'أرسلنا رابط تأكيد إلى ⁨$email⁩. اضغط عليه، ثم عُد واضغط متابعة.';
  }

  @override
  String get verifyEmailContinue => 'لقد أكدت — متابعة';

  @override
  String get verifyEmailResend => 'إعادة إرسال البريد';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'إعادة الإرسال خلال $seconds ثانية';
  }

  @override
  String get verifyEmailNotYet => 'لم يتم التأكيد بعد. تحقق من بريدك.';

  @override
  String get verifyEmailSent => 'تم إرسال بريد التأكيد.';

  @override
  String get changeEmail => 'بريد خاطئ؟ غيّره';

  @override
  String get changeEmailTitle => 'تغيير البريد';

  @override
  String get changeEmailHint => 'أدخل البريد الصحيح';

  @override
  String get changeEmailUpdate => 'تحديث';

  @override
  String get emailChangeNoticeTitle => 'تحقق من بريدك';

  @override
  String emailChangeNoticeBody(String email) {
    return 'أرسلنا رابط تأكيد إلى $email. اضغط على الرابط، ثم عُد وسجّل الدخول بالبريد الجديد.';
  }

  @override
  String get emailChangeNoticeButton => 'الذهاب إلى تسجيل الدخول';

  @override
  String get sessionExpired => 'انتهت الجلسة. يرجى تسجيل الدخول مجددًا.';

  @override
  String get waitlistSize => 'حجم قائمة الانتظار';

  @override
  String get waitlist => 'قائمة الانتظار';

  @override
  String get joinWaitlist => 'انضم لقائمة الانتظار';

  @override
  String get leaveWaitlist => 'غادر قائمة الانتظار';

  @override
  String get waitlistFull => 'قائمة الانتظار ممتلئة';

  @override
  String get waitlistedSnack => 'تمت إضافتك إلى قائمة الانتظار';

  @override
  String waitlistedSnackPos(int pos) {
    return 'تمت إضافتك إلى قائمة الانتظار — أنت في المركز $pos';
  }

  @override
  String waitlistStanding(int pos) {
    return 'أنت في المركز $pos بقائمة الانتظار — سنعلمك فور توفر مكان.';
  }

  @override
  String get joinedBadge => 'منضم';

  @override
  String get sessionStartedLeaveBlocked =>
      'بدأت الجلسة — تم إغلاق قائمة المشاركين.';

  @override
  String get markAllAttended => 'تحديد حضور الجميع';

  @override
  String get markAll => 'تحديد الكل';

  @override
  String get editRoster => 'تعديل القائمة';

  @override
  String get editCapacity => 'تعديل السعة';

  @override
  String get games => 'المباريات';

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get sendMessage => 'إرسال الرسالة';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get haveCoachKey => 'لديك رمز مدرب؟';

  @override
  String get coachPromotedSnack => 'أصبحت مدرباً الآن!';

  @override
  String get leaderboardMensBoard => 'لوحة الرجال — عدد الحصص';

  @override
  String get leaderboardWomensBoard => 'لوحة السيدات — عدد الحصص';

  @override
  String get leaderboardSubtitle => 'عدد الحصص';

  @override
  String get audienceMen => 'للرجال';

  @override
  String get audienceWomen => 'للسيدات';

  @override
  String get increaseCapacity => 'زيادة السعة';

  @override
  String get newMaxPlayers => 'الحد الأقصى الجديد للاعبين';

  @override
  String get newWaitlistSize => 'الحجم الجديد لقائمة الانتظار';

  @override
  String get capacityMustNotDecrease => 'لا يمكن تقليل السعة';

  @override
  String mustBeAtLeast(int count) {
    return 'يجب أن يكون $count على الأقل';
  }

  @override
  String get sessionMissing => 'لم تعد هذه الجلسة موجودة';

  @override
  String get notSignedIn => 'يرجى تسجيل الدخول مجددًا';

  @override
  String get notYourSession => 'فقط مدرّب الجلسة يمكنه فعل ذلك';

  @override
  String get nothingToUpdate => 'لا يوجد ما يتم تحديثه';

  @override
  String get height => 'الطول';

  @override
  String get weight => 'الوزن';

  @override
  String get heightHint => 'سم';

  @override
  String get weightHint => 'كغ';

  @override
  String get invalidHeight => 'أدخل طولاً صحيحاً (100–250 سم)';

  @override
  String get invalidWeight => 'أدخل وزناً صحيحاً (20–200 كغ)';

  @override
  String get editBodyMetrics => 'تعديل الطول والوزن';

  @override
  String get save => 'حفظ';

  @override
  String get post => 'نشر';

  @override
  String get announcements => 'الإعلانات';

  @override
  String get noAnnouncements => 'لا توجد إعلانات بعد';

  @override
  String get justNow => 'الآن';

  @override
  String minutesAgo(int minutes) {
    return 'قبل $minutes د';
  }

  @override
  String hoursAgo(int hours) {
    return 'قبل $hours س';
  }

  @override
  String daysAgo(int days) {
    return 'قبل $days ي';
  }

  @override
  String get newAnnouncement => 'إعلان جديد';

  @override
  String get announcementTitle => 'العنوان';

  @override
  String get announcementBody => 'الرسالة';

  @override
  String get announcementCreated => 'تم نشر الإعلان';

  @override
  String get editAnnouncement => 'تعديل الإعلان';

  @override
  String get announcementUpdated => 'تم تحديث الإعلان';

  @override
  String get announcementDeleted => 'تم حذف الإعلان';

  @override
  String get confirmDeleteAnnouncement => 'حذف الإعلان؟';

  @override
  String get confirmDeleteAnnouncementBody => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get sessionsHistory => 'سجل الجلسات';

  @override
  String get noSessionsHistory => 'لا توجد جلسات سابقة';

  @override
  String get paymentHistory => 'سجل العضوية';

  @override
  String get noPaymentHistory => 'لا توجد سجلات عضوية بعد';

  @override
  String paymentChangedBy(String name) {
    return 'بواسطة $name';
  }

  @override
  String historyAttendanceSummary(int attended, int joined, int max) {
    return '$attended حضروا · $joined/$max انضموا';
  }

  @override
  String get leaderboard => 'المتصدرون';

  @override
  String get thisMonth => 'هذا الشهر';

  @override
  String get allTime => 'الكل';

  @override
  String get noLeaderboardData => 'لا توجد بيانات حضور بعد';

  @override
  String sessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسة',
      many: '$count جلسة',
      few: '$count جلسات',
      two: 'جلستان',
      one: 'جلسة واحدة',
      zero: 'لا جلسات',
    );
    return '$_temp0';
  }

  @override
  String get recurringSessions => 'جلسات متكررة';

  @override
  String get recurringSessionsDesc => 'إنشاء جلسات تلقائياً حسب جدول';

  @override
  String get createRecurring => 'جلسة متكررة جديدة';

  @override
  String get editRecurring => 'تعديل جلسة متكررة';

  @override
  String get recurrenceDays => 'التكرار في';

  @override
  String get noRecurringSessions => 'لا توجد جلسات متكررة';

  @override
  String get noRecurringSessionsDesc =>
      'اضغط + لإنشاء تدريبات تلقائية حسب جدول';

  @override
  String get recurringCreated => 'تم إنشاء الجلسة المتكررة';

  @override
  String get recurringUpdated => 'تم تحديث الجلسة المتكررة';

  @override
  String get recurringDeleted => 'تم حذف الجلسة المتكررة';

  @override
  String get confirmDeleteRecurring => 'حذف الجلسة المتكررة؟';

  @override
  String get confirmDeleteRecurringBody =>
      'لن يتم إنشاء جلسات مستقبلية تلقائياً.';

  @override
  String get enabled => 'مفعّل';

  @override
  String get paused => 'متوقف';

  @override
  String get selectDays => 'اختر يوماً واحداً على الأقل';

  @override
  String get sun => 'أحد';

  @override
  String get mon => 'إثنين';

  @override
  String get tue => 'ثلاثاء';

  @override
  String get wed => 'أربعاء';

  @override
  String get thu => 'خميس';

  @override
  String get fri => 'جمعة';

  @override
  String get sat => 'سبت';

  @override
  String greetingMorning(String name) {
    return 'صباح الخير يا $name';
  }

  @override
  String greetingAfternoon(String name) {
    return 'نهارك سعيد يا $name';
  }

  @override
  String greetingEvening(String name) {
    return 'مساء الخير يا $name';
  }

  @override
  String get welcomeBack => 'أهلاً بعودتك';

  @override
  String get nextUp => 'التالي';

  @override
  String sessionsThisWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسات هذا الأسبوع',
      one: 'جلسة واحدة هذا الأسبوع',
      zero: 'لا جلسات هذا الأسبوع',
    );
    return '$_temp0';
  }

  @override
  String upcomingSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسات قادمة',
      one: 'جلسة واحدة قادمة',
      zero: 'لا جلسات قادمة',
    );
    return '$_temp0';
  }

  @override
  String get findYourNextGame => 'ابحث عن مباراتك القادمة';

  @override
  String get joinedSuccess => 'تم تسجيلك! نراك في الملعب';

  @override
  String get youLabel => 'أنت';

  @override
  String get gamesPlayed => 'المباريات';

  @override
  String get tierRookie => 'مبتدئ';

  @override
  String get tierRegular => 'منتظم';

  @override
  String get tierVeteran => 'محترف';

  @override
  String get tierLegend => 'أسطورة';

  @override
  String get tierChampion => 'بطل';

  @override
  String weekStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أسبوع متواصل',
      many: '$count أسبوعًا متواصلًا',
      few: '$count أسابيع متواصلة',
      two: 'أسبوعان متواصلان',
      one: 'أسبوع متواصل',
    );
    return '$_temp0';
  }

  @override
  String milestoneUnlocked(int count, String tier) {
    return 'لعبت $count مباراة — أصبحت الآن $tier!';
  }

  @override
  String toNextTier(int count, String tier) {
    return 'بقي $count حتى $tier';
  }

  @override
  String get endorse => 'تأييد';

  @override
  String get endorsed => 'تم التأييد';

  @override
  String get endorsements => 'التأييدات';

  @override
  String endorsedPlayer(String name) {
    return 'تم تأييد ⁨$name⁩';
  }

  @override
  String endorseRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تبقى $count تأييد',
      many: 'تبقى $count تأييدًا',
      few: 'تبقى $count تأييدات',
      two: 'تبقى تأييدان',
      one: 'تبقى تأييد واحد',
      zero: 'لم يتبقَّ تأييد لهذه الجلسة',
    );
    return '$_temp0';
  }

  @override
  String get endorseFailed => 'تعذّر منح التأييد';

  @override
  String endorsementLevelLabel(int level) {
    return 'المستوى $level';
  }

  @override
  String endorsementMilestoneUnlocked(int count, String label) {
    return '$count تأييد — وصلت إلى $label!';
  }

  @override
  String get achievements => 'الإنجازات';

  @override
  String get sectionDetails => 'التفاصيل';

  @override
  String get sectionAccount => 'الحساب';

  @override
  String memberSince(String year) {
    return 'عضو منذ $year';
  }

  @override
  String unlocksAt(int count) {
    return 'يُفتح عند $count';
  }

  @override
  String get topTierReached => 'تم بلوغ أعلى مستوى';

  @override
  String get updateAvailableTitle => 'يتوفر تحديث';

  @override
  String get updateAvailableBody =>
      'يتوفر إصدار جديد من التطبيق يتضمّن أحدث الميزات والإصلاحات.';

  @override
  String get updateNow => 'تحديث الآن';

  @override
  String get updateLater => 'لاحقًا';
}
