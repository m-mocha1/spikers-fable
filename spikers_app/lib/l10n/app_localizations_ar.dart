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
    return '$count مكان متبقي';
  }

  @override
  String get attendees => 'المشاركون';

  @override
  String get noSessions => 'لا توجد جلسات متاحة';

  @override
  String get noSessionsDesc => 'تحقق لاحقاً من الجلسات القادمة';

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
  String get upcoming => 'قادم';

  @override
  String get ongoing => 'جارٍ';

  @override
  String get startsIn => 'يبدأ في';

  @override
  String get endsIn => 'ينتهي في';

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
  String get players => 'لاعبون';

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
  String get sessionsAttended => 'جلسة حضرها';

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
  String get noCoaches => 'لا يوجد مدربون';

  @override
  String get paid => 'مدفوع';

  @override
  String get unpaid => 'غير مدفوع';

  @override
  String get lifetime => 'عضوية دائمة';

  @override
  String get lifetimeMember => 'هذا اللاعب يملك عضوية دائمة.';

  @override
  String get payment => 'الدفع';

  @override
  String get paymentRequired => 'الجلسات مقفلة';

  @override
  String get paymentRequiredDesc => 'ادفع رسومك لفتح الجلسات. تواصل مع المدرب.';

  @override
  String confirmMarkPaid(String name) {
    return 'وضع علامة على $name كمدفوع؟';
  }

  @override
  String confirmMarkUnpaid(String name) {
    return 'وضع علامة على $name كغير مدفوع؟';
  }

  @override
  String daysLeft(int days) {
    return '$days يوم متبقي';
  }

  @override
  String get verifyEmailTitle => 'تأكيد البريد الإلكتروني';

  @override
  String verifyEmailBody(String email) {
    return 'أرسلنا رابط تأكيد إلى $email. اضغط عليه، ثم عُد واضغط متابعة.';
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
  String get announcements => 'الإعلانات';

  @override
  String get noAnnouncements => 'لا توجد إعلانات بعد';

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
  String get delete => 'حذف';

  @override
  String get sessionsHistory => 'سجل الجلسات';

  @override
  String get noSessionsHistory => 'لا توجد جلسات سابقة';

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
    return '$count جلسة';
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
}
