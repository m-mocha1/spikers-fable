// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Jerusalem Spikers';

  @override
  String get signIn => 'Sign In';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'Enter your email';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get confirmPasswordHint => 'Re-enter your password';

  @override
  String get name => 'Full Name';

  @override
  String get nameHint => 'Enter your full name';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get sendResetEmail => 'Send Reset Email';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get haveAccount => 'Already have an account?';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get mixed => 'Mixed';

  @override
  String get gender => 'Gender';

  @override
  String get audience => 'Audience';

  @override
  String get optional => 'Optional';

  @override
  String get notSet => 'Not set';

  @override
  String get completeProfile => 'Complete profile';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get selectDate => 'Select date';

  @override
  String get role => 'Role';

  @override
  String get player => 'Player';

  @override
  String get coach => 'Coach';

  @override
  String get coachKey => 'Coach Access Key';

  @override
  String get coachKeyHint => 'Enter the coach key';

  @override
  String get sessions => 'Sessions';

  @override
  String get profile => 'Profile';

  @override
  String get createSession => 'Create Session';

  @override
  String get availableCoaches => 'Available Coaches';

  @override
  String get customSession => 'Custom session';

  @override
  String get customSessionSubtitle =>
      'Only selected members can see this session';

  @override
  String get chooseMembers => 'Choose members';

  @override
  String membersSelected(int count) {
    return '$count selected';
  }

  @override
  String get selectMembersError => 'Select at least one member';

  @override
  String get adminTesting => 'Admin · Testing';

  @override
  String get notifyOnCreate => 'Notify players & coaches';

  @override
  String get notifyOnCreateSubtitle =>
      'Off = create and cancel this session silently — no notifications sent';

  @override
  String get sessionArt => 'Card art';

  @override
  String get sessionArtRandom => 'Random';

  @override
  String sessionArtCard(int number) {
    return 'Card $number';
  }

  @override
  String get searchMembers => 'Search members';

  @override
  String get membersOnly => 'Members only';

  @override
  String get done => 'Done';

  @override
  String get editMembers => 'Edit members';

  @override
  String get membersUpdated => 'Members updated';

  @override
  String get makePublic => 'Make public';

  @override
  String get makePublicSubtitle => 'Choose who can now see this session';

  @override
  String get sessionMadePublic => 'Session is now public';

  @override
  String get sessionTitle => 'Session Title';

  @override
  String get sessionTitleHint => 'e.g. Morning Practice';

  @override
  String get location => 'Location';

  @override
  String get locationHint => 'e.g. Jerusalem Sports Hall';

  @override
  String get minAge => 'Min Age';

  @override
  String get maxAge => 'Max Age';

  @override
  String get startTime => 'Start Time';

  @override
  String get endTime => 'End Time';

  @override
  String get maxPlayers => 'Max Players';

  @override
  String get joinSession => 'Join';

  @override
  String get leaveSession => 'Leave';

  @override
  String get cancelSession => 'Cancel Session';

  @override
  String get sessionFull => 'Session Full';

  @override
  String spotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots left',
      one: '1 spot left',
    );
    return '$_temp0';
  }

  @override
  String get attendees => 'Attendees';

  @override
  String get noSessions => 'No sessions available';

  @override
  String get noSessionsDesc => 'Check back later for upcoming sessions';

  @override
  String get completeProfileForSessions => 'Complete your profile';

  @override
  String get completeProfileForSessionsDesc =>
      'Add your gender and date of birth so we can show the sessions that match you.';

  @override
  String get sessionCreated => 'Session created successfully';

  @override
  String get sessionCancelled => 'Session has been cancelled';

  @override
  String get sessionEnded => 'Session has ended';

  @override
  String get sessionEndedSubtitle => 'Good job!';

  @override
  String get newSession => 'New Session';

  @override
  String get signOut => 'Sign Out';

  @override
  String get switchLanguage => 'عربي';

  @override
  String get requiredField => 'This field is required';

  @override
  String get invalidEmail => 'Enter a valid email address';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get invalidCoachKey => 'Invalid coach key';

  @override
  String get emailAlreadyInUse =>
      'This email is already registered. Try signing in instead.';

  @override
  String get userNotFound => 'No account found with this email.';

  @override
  String get wrongPassword => 'Wrong email or password';

  @override
  String get tooManyRequests =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get userDisabled => 'This account has been disabled. Contact support.';

  @override
  String get networkError => 'No internet connection. Check your network.';

  @override
  String get unknownError => 'Something went wrong. Please try again.';

  @override
  String get cameraPermissionTitle => 'Camera access needed';

  @override
  String get cameraPermissionMessage =>
      'Allow camera access in Settings to take a profile photo.';

  @override
  String get permissionDenied =>
      'Permission denied. You can enable it anytime in Settings.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String get myAccount => 'My Account';

  @override
  String get age => 'Age';

  @override
  String get years => 'years';

  @override
  String ageYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String get upcoming => 'Upcoming';

  @override
  String get ongoing => 'Ongoing';

  @override
  String get startsIn => 'Starts in';

  @override
  String get endsIn => 'Ends in';

  @override
  String countdownDays(int days) {
    return '${days}d';
  }

  @override
  String countdownHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String countdownMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get unitDays => 'days';

  @override
  String get unitHours => 'hours';

  @override
  String get unitMinutes => 'min';

  @override
  String get unitSeconds => 'sec';

  @override
  String get confirm => 'Confirm';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmCancelSession => 'Cancel Session';

  @override
  String get confirmCancelMessage =>
      'Are you sure you want to cancel this session? Attendees will be notified.';

  @override
  String get ageRange => 'Age Range';

  @override
  String ageRangeYears(int min, int max) {
    return '$min – $max years';
  }

  @override
  String players(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'players',
      one: 'player',
    );
    return '$_temp0';
  }

  @override
  String get full => 'Full';

  @override
  String get live => 'Live';

  @override
  String get sessionInfo => 'Session Info';

  @override
  String get coachLabel => 'Coach';

  @override
  String joinedCount(int count, int max) {
    return '$count/$max players';
  }

  @override
  String get sessionDate => 'Date';

  @override
  String get genderMixed => 'Mixed';

  @override
  String get coachSessions => 'My Sessions';

  @override
  String get endTimeError => 'End time must be after start time';

  @override
  String get invalidAgeRange => 'Min age can\'t exceed max age';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get quickSession => 'Quick Session';

  @override
  String get selectTemplate => 'Pick a template';

  @override
  String get saveAsTemplate => 'Save as Template';

  @override
  String get noTemplates => 'No templates yet';

  @override
  String get noTemplatesDesc =>
      'Create a session and check \"Save as Template\" to save it here';

  @override
  String get templateSaved => 'Template saved';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get chatEmpty => 'No messages yet. Say something!';

  @override
  String get attended => 'Attended';

  @override
  String get notAttended => 'Absent';

  @override
  String attendedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attended',
      one: '1 attended',
    );
    return '$_temp0';
  }

  @override
  String sessionsAttended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions attended',
      one: '1 session attended',
    );
    return '$_temp0';
  }

  @override
  String get exportAttendance => 'Export attendance';

  @override
  String get sessionsAttendedTitle => 'Sessions Attended';

  @override
  String get registrationDate => 'Registration Date';

  @override
  String get lastSessionDate => 'Last Session Attended';

  @override
  String get lastPaidDate => 'Last Payment Date';

  @override
  String get membershipStatus => 'Membership Status';

  @override
  String get membershipExpiry => 'Membership Expiry';

  @override
  String get membershipLifetime => 'Lifetime';

  @override
  String get export => 'Export';

  @override
  String get exportColumns => 'Columns to include';

  @override
  String playersWillBeExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count players will be exported',
      one: '1 player will be exported',
    );
    return '$_temp0';
  }

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get changePhoto => 'Change Photo';

  @override
  String get pickFromGallery => 'Gallery';

  @override
  String get takePhoto => 'Camera';

  @override
  String get photoUpdated => 'Profile photo updated';

  @override
  String get playersTab => 'Players';

  @override
  String get coachesTab => 'Coaches';

  @override
  String get allGenders => 'All';

  @override
  String get noPlayers => 'No players found';

  @override
  String get noPlayersMatch => 'No players match your search';

  @override
  String get searchPlayers => 'Search players';

  @override
  String get noCoaches => 'No coaches found';

  @override
  String coachesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coaches',
      one: '$count coach',
    );
    return '$_temp0';
  }

  @override
  String get viewProfile => 'View profile';

  @override
  String get paid => 'Active';

  @override
  String get unpaid => 'Inactive';

  @override
  String get lifetime => 'LIFETIME';

  @override
  String get lifetimeMember => 'This member has lifetime membership.';

  @override
  String get injured => 'Injured';

  @override
  String get payment => 'Membership';

  @override
  String get paymentRequired => 'Membership inactive';

  @override
  String get paymentRequiredDesc =>
      'Your club membership isn\'t active. Contact your coach to renew.';

  @override
  String confirmMarkPaid(String name) {
    return 'Activate membership for $name?';
  }

  @override
  String confirmMarkUnpaid(String name) {
    return 'Deactivate membership for $name?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String deleteAccountConfirm(String name) {
    return 'Permanently delete $name\'s account? This removes their login and all data and cannot be undone.';
  }

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get deleteMyAccountTitle => 'Delete my account';

  @override
  String get deleteMyAccountConfirm =>
      'Permanently delete your account? This removes your login and all your data and cannot be undone.';

  @override
  String get deleteMyAccountError =>
      'Couldn\'t delete your account. Please try again.';

  @override
  String get remove => 'Remove';

  @override
  String get removePlayer => 'Remove player';

  @override
  String confirmRemovePlayer(String name) {
    return 'Remove $name from this session?';
  }

  @override
  String daysLeft(int days) {
    return '${days}d left';
  }

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String verifyEmailBody(String email) {
    return 'We sent a verification link to $email. Tap it, then come back and press Continue.';
  }

  @override
  String get verifyEmailContinue => 'I verified — Continue';

  @override
  String get verifyEmailResend => 'Resend email';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get verifyEmailNotYet => 'Not verified yet. Check your inbox.';

  @override
  String get verifyEmailSent => 'Verification email sent.';

  @override
  String get changeEmail => 'Wrong email? Change it';

  @override
  String get changeEmailTitle => 'Change email';

  @override
  String get changeEmailHint => 'Enter the correct email';

  @override
  String get changeEmailUpdate => 'Update';

  @override
  String get emailChangeNoticeTitle => 'Check your email';

  @override
  String emailChangeNoticeBody(String email) {
    return 'We sent a verification link to $email. Click the link, then come back and sign in with the new email.';
  }

  @override
  String get emailChangeNoticeButton => 'Go to sign in';

  @override
  String get sessionExpired => 'Session expired. Please sign in again.';

  @override
  String get waitlistSize => 'Waitlist Size';

  @override
  String get waitlist => 'Waitlist';

  @override
  String get joinWaitlist => 'Join Waitlist';

  @override
  String get leaveWaitlist => 'Leave Waitlist';

  @override
  String get waitlistFull => 'Waitlist Full';

  @override
  String get waitlistedSnack => 'You\'ve been added to the waitlist';

  @override
  String waitlistedSnackPos(int pos) {
    return 'You\'ve been added to the waitlist — you\'re #$pos in line';
  }

  @override
  String waitlistStanding(int pos) {
    return 'You\'re #$pos in line — we\'ll notify you the moment a spot opens.';
  }

  @override
  String get joinedBadge => 'Joined';

  @override
  String get sessionStartedLeaveBlocked =>
      'The session has started — the roster is locked.';

  @override
  String get markAllAttended => 'Mark all attended';

  @override
  String get markAll => 'Mark all';

  @override
  String get editRoster => 'Edit roster';

  @override
  String get editCapacity => 'Edit capacity';

  @override
  String get games => 'Games';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get sendMessage => 'Send message';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get haveCoachKey => 'Have a coach key?';

  @override
  String get coachPromotedSnack => 'You\'re a coach now!';

  @override
  String get leaderboardMensBoard => 'Men\'s board — sessions attended';

  @override
  String get leaderboardWomensBoard => 'Women\'s board — sessions attended';

  @override
  String get leaderboardSubtitle => 'Sessions attended';

  @override
  String get audienceMen => 'For men';

  @override
  String get audienceWomen => 'For women';

  @override
  String get increaseCapacity => 'Increase Capacity';

  @override
  String get newMaxPlayers => 'New max players';

  @override
  String get newWaitlistSize => 'New waitlist size';

  @override
  String get capacityMustNotDecrease => 'Capacity cannot be decreased';

  @override
  String mustBeAtLeast(int count) {
    return 'Must be at least $count';
  }

  @override
  String get sessionMissing => 'This session no longer exists';

  @override
  String get notSignedIn => 'Please sign in again';

  @override
  String get notYourSession => 'Only the session\'s coach can do that';

  @override
  String get nothingToUpdate => 'Nothing to update';

  @override
  String get height => 'Height';

  @override
  String get weight => 'Weight';

  @override
  String get heightHint => 'cm';

  @override
  String get weightHint => 'kg';

  @override
  String get invalidHeight => 'Enter a valid height (100–250 cm)';

  @override
  String get invalidWeight => 'Enter a valid weight (20–200 kg)';

  @override
  String get editBodyMetrics => 'Edit height & weight';

  @override
  String get save => 'Save';

  @override
  String get post => 'Post';

  @override
  String get announcements => 'Announcements';

  @override
  String get noAnnouncements => 'No announcements yet';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get newAnnouncement => 'New Announcement';

  @override
  String get announcementTitle => 'Title';

  @override
  String get announcementBody => 'Message';

  @override
  String get announcementCreated => 'Announcement posted';

  @override
  String get editAnnouncement => 'Edit Announcement';

  @override
  String get announcementUpdated => 'Announcement updated';

  @override
  String get announcementDeleted => 'Announcement deleted';

  @override
  String get confirmDeleteAnnouncement => 'Delete announcement?';

  @override
  String get confirmDeleteAnnouncementBody => 'This cannot be undone.';

  @override
  String get sessionsHistory => 'Session History';

  @override
  String get noSessionsHistory => 'No past sessions yet';

  @override
  String get paymentHistory => 'Membership History';

  @override
  String get noPaymentHistory => 'No membership records yet';

  @override
  String paymentChangedBy(String name) {
    return 'by $name';
  }

  @override
  String historyAttendanceSummary(int attended, int joined, int max) {
    return '$attended attended · $joined/$max joined';
  }

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String get thisMonth => 'This Month';

  @override
  String get allTime => 'All Time';

  @override
  String get noLeaderboardData => 'No attendance data yet';

  @override
  String sessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String get recurringSessions => 'Recurring Sessions';

  @override
  String get recurringSessionsDesc => 'Auto-create sessions on a schedule';

  @override
  String get createRecurring => 'New Recurring Session';

  @override
  String get editRecurring => 'Edit Recurring Session';

  @override
  String get recurrenceDays => 'Repeat On';

  @override
  String get noRecurringSessions => 'No recurring sessions';

  @override
  String get noRecurringSessionsDesc =>
      'Tap + to auto-create practices on a schedule';

  @override
  String get recurringCreated => 'Recurring session created';

  @override
  String get recurringUpdated => 'Recurring session updated';

  @override
  String get recurringDeleted => 'Recurring session deleted';

  @override
  String get confirmDeleteRecurring => 'Delete recurring session?';

  @override
  String get confirmDeleteRecurringBody =>
      'Future sessions will no longer be auto-created.';

  @override
  String get enabled => 'Enabled';

  @override
  String get paused => 'Paused';

  @override
  String get selectDays => 'Select at least one day';

  @override
  String get sun => 'Sun';

  @override
  String get mon => 'Mon';

  @override
  String get tue => 'Tue';

  @override
  String get wed => 'Wed';

  @override
  String get thu => 'Thu';

  @override
  String get fri => 'Fri';

  @override
  String get sat => 'Sat';

  @override
  String greetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String greetingAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get nextUp => 'Next up';

  @override
  String sessionsThisWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions this week',
      one: '1 session this week',
      zero: 'No sessions this week',
    );
    return '$_temp0';
  }

  @override
  String upcomingSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count upcoming sessions',
      one: '1 upcoming session',
      zero: 'No upcoming sessions',
    );
    return '$_temp0';
  }

  @override
  String get findYourNextGame => 'Find your next game';

  @override
  String get joinedSuccess => 'You\'re in! See you on court';

  @override
  String get youLabel => 'You';

  @override
  String get gamesPlayed => 'Games played';

  @override
  String get tierRookie => 'Rookie';

  @override
  String get tierRegular => 'Regular';

  @override
  String get tierVeteran => 'Veteran';

  @override
  String get tierLegend => 'Legend';

  @override
  String get tierChampion => 'Champion';

  @override
  String weekStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-week streak',
      one: '1-week streak',
    );
    return '$_temp0';
  }

  @override
  String milestoneUnlocked(int count, String tier) {
    return '$count games played — you\'re now a $tier!';
  }

  @override
  String toNextTier(int count, String tier) {
    return '$count to $tier';
  }

  @override
  String get endorse => 'Endorse';

  @override
  String get endorsed => 'Endorsed';

  @override
  String get endorsements => 'Endorsements';

  @override
  String endorsedPlayer(String name) {
    return 'Endorsed $name';
  }

  @override
  String endorseRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endorsements left',
      one: '1 endorsement left',
      zero: 'No endorsements left this session',
    );
    return '$_temp0';
  }

  @override
  String get endorseFailed => 'Couldn\'t give endorsement';

  @override
  String endorsementLevelLabel(int level) {
    return 'Level $level';
  }

  @override
  String endorsementMilestoneUnlocked(int count, String label) {
    return '$count endorsements — you reached $label!';
  }

  @override
  String get achievements => 'Achievements';

  @override
  String get sectionDetails => 'Details';

  @override
  String get sectionAccount => 'Account';

  @override
  String memberSince(String year) {
    return 'Member since $year';
  }

  @override
  String unlocksAt(int count) {
    return 'Unlocks at $count';
  }

  @override
  String get topTierReached => 'Top tier reached';

  @override
  String get updateAvailableTitle => 'Update Available';

  @override
  String get updateAvailableBody =>
      'A new version of the app is ready with the latest features and fixes.';

  @override
  String get updateNow => 'Update Now';

  @override
  String get updateLater => 'Later';
}
