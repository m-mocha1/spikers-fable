import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Jerusalem Spikers'**
  String get appName;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get confirmPasswordHint;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get name;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get nameHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @sendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Email'**
  String get sendResetEmail;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccount;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @mixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixed;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @audience.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get audience;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete profile'**
  String get completeProfile;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @coach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coach;

  /// No description provided for @coachKey.
  ///
  /// In en, this message translates to:
  /// **'Coach Access Key'**
  String get coachKey;

  /// No description provided for @coachKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the coach key'**
  String get coachKeyHint;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @createSession.
  ///
  /// In en, this message translates to:
  /// **'Create Session'**
  String get createSession;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Title'**
  String get sessionTitle;

  /// No description provided for @sessionTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Morning Practice'**
  String get sessionTitleHint;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Jerusalem Sports Hall'**
  String get locationHint;

  /// No description provided for @minAge.
  ///
  /// In en, this message translates to:
  /// **'Min Age'**
  String get minAge;

  /// No description provided for @maxAge.
  ///
  /// In en, this message translates to:
  /// **'Max Age'**
  String get maxAge;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// No description provided for @maxPlayers.
  ///
  /// In en, this message translates to:
  /// **'Max Players'**
  String get maxPlayers;

  /// No description provided for @joinSession.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinSession;

  /// No description provided for @leaveSession.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveSession;

  /// No description provided for @cancelSession.
  ///
  /// In en, this message translates to:
  /// **'Cancel Session'**
  String get cancelSession;

  /// No description provided for @sessionFull.
  ///
  /// In en, this message translates to:
  /// **'Session Full'**
  String get sessionFull;

  /// No description provided for @spotsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} spots left'**
  String spotsLeft(int count);

  /// No description provided for @attendees.
  ///
  /// In en, this message translates to:
  /// **'Attendees'**
  String get attendees;

  /// No description provided for @noSessions.
  ///
  /// In en, this message translates to:
  /// **'No sessions available'**
  String get noSessions;

  /// No description provided for @noSessionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Check back later for upcoming sessions'**
  String get noSessionsDesc;

  /// No description provided for @completeProfileForSessions.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get completeProfileForSessions;

  /// No description provided for @completeProfileForSessionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Add your gender and date of birth so we can show the sessions that match you.'**
  String get completeProfileForSessionsDesc;

  /// No description provided for @sessionCreated.
  ///
  /// In en, this message translates to:
  /// **'Session created successfully'**
  String get sessionCreated;

  /// No description provided for @sessionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Session has been cancelled'**
  String get sessionCancelled;

  /// No description provided for @sessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Session has ended'**
  String get sessionEnded;

  /// No description provided for @sessionEndedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Good job!'**
  String get sessionEndedSubtitle;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get newSession;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @switchLanguage.
  ///
  /// In en, this message translates to:
  /// **'عربي'**
  String get switchLanguage;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @invalidCoachKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid coach key'**
  String get invalidCoachKey;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Try signing in instead.'**
  String get emailAlreadyInUse;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email.'**
  String get userNotFound;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password'**
  String get wrongPassword;

  /// No description provided for @tooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get tooManyRequests;

  /// No description provided for @userDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled. Contact support.'**
  String get userDisabled;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network.'**
  String get networkError;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get unknownError;

  /// No description provided for @cameraPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access needed'**
  String get cameraPermissionTitle;

  /// No description provided for @cameraPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in Settings to take a profile photo.'**
  String get cameraPermissionMessage;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied. You can enable it anytime in Settings.'**
  String get permissionDenied;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @myAccount.
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get myAccount;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @ongoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get ongoing;

  /// No description provided for @startsIn.
  ///
  /// In en, this message translates to:
  /// **'Starts in'**
  String get startsIn;

  /// No description provided for @endsIn.
  ///
  /// In en, this message translates to:
  /// **'Ends in'**
  String get endsIn;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirmCancelSession.
  ///
  /// In en, this message translates to:
  /// **'Cancel Session'**
  String get confirmCancelSession;

  /// No description provided for @confirmCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this session? Attendees will be notified.'**
  String get confirmCancelMessage;

  /// No description provided for @ageRange.
  ///
  /// In en, this message translates to:
  /// **'Age Range'**
  String get ageRange;

  /// No description provided for @players.
  ///
  /// In en, this message translates to:
  /// **'players'**
  String get players;

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get full;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @sessionInfo.
  ///
  /// In en, this message translates to:
  /// **'Session Info'**
  String get sessionInfo;

  /// No description provided for @coachLabel.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coachLabel;

  /// No description provided for @joinedCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/{max} players'**
  String joinedCount(int count, int max);

  /// No description provided for @sessionDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get sessionDate;

  /// No description provided for @genderMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get genderMixed;

  /// No description provided for @coachSessions.
  ///
  /// In en, this message translates to:
  /// **'My Sessions'**
  String get coachSessions;

  /// No description provided for @endTimeError.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time'**
  String get endTimeError;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @quickSession.
  ///
  /// In en, this message translates to:
  /// **'Quick Session'**
  String get quickSession;

  /// No description provided for @selectTemplate.
  ///
  /// In en, this message translates to:
  /// **'Pick a template'**
  String get selectTemplate;

  /// No description provided for @saveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as Template'**
  String get saveAsTemplate;

  /// No description provided for @noTemplates.
  ///
  /// In en, this message translates to:
  /// **'No templates yet'**
  String get noTemplates;

  /// No description provided for @noTemplatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Create a session and check \"Save as Template\" to save it here'**
  String get noTemplatesDesc;

  /// No description provided for @templateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get templateSaved;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say something!'**
  String get chatEmpty;

  /// No description provided for @attended.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get attended;

  /// No description provided for @notAttended.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get notAttended;

  /// No description provided for @sessionsAttended.
  ///
  /// In en, this message translates to:
  /// **'sessions attended'**
  String get sessionsAttended;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get changePhoto;

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get pickFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get takePhoto;

  /// No description provided for @photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated'**
  String get photoUpdated;

  /// No description provided for @playersTab.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get playersTab;

  /// No description provided for @coachesTab.
  ///
  /// In en, this message translates to:
  /// **'Coaches'**
  String get coachesTab;

  /// No description provided for @allGenders.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allGenders;

  /// No description provided for @noPlayers.
  ///
  /// In en, this message translates to:
  /// **'No players found'**
  String get noPlayers;

  /// No description provided for @noPlayersMatch.
  ///
  /// In en, this message translates to:
  /// **'No players match your search'**
  String get noPlayersMatch;

  /// No description provided for @searchPlayers.
  ///
  /// In en, this message translates to:
  /// **'Search players'**
  String get searchPlayers;

  /// No description provided for @noCoaches.
  ///
  /// In en, this message translates to:
  /// **'No coaches found'**
  String get noCoaches;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get paid;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get unpaid;

  /// No description provided for @lifetime.
  ///
  /// In en, this message translates to:
  /// **'LIFETIME'**
  String get lifetime;

  /// No description provided for @lifetimeMember.
  ///
  /// In en, this message translates to:
  /// **'This member has lifetime membership.'**
  String get lifetimeMember;

  /// No description provided for @injured.
  ///
  /// In en, this message translates to:
  /// **'Injured'**
  String get injured;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get payment;

  /// No description provided for @paymentRequired.
  ///
  /// In en, this message translates to:
  /// **'Membership inactive'**
  String get paymentRequired;

  /// No description provided for @paymentRequiredDesc.
  ///
  /// In en, this message translates to:
  /// **'Your club membership isn\'t active. Contact your coach to renew.'**
  String get paymentRequiredDesc;

  /// No description provided for @confirmMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Activate membership for {name}?'**
  String confirmMarkPaid(String name);

  /// No description provided for @confirmMarkUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Deactivate membership for {name}?'**
  String confirmMarkUnpaid(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {name}\'s account? This removes their login and all data and cannot be undone.'**
  String deleteAccountConfirm(String name);

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// No description provided for @deleteMyAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteMyAccountTitle;

  /// No description provided for @deleteMyAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account? This removes your login and all your data and cannot be undone.'**
  String get deleteMyAccountConfirm;

  /// No description provided for @deleteMyAccountError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Please try again.'**
  String get deleteMyAccountError;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removePlayer.
  ///
  /// In en, this message translates to:
  /// **'Remove player'**
  String get removePlayer;

  /// No description provided for @confirmRemovePlayer.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this session?'**
  String confirmRemovePlayer(String name);

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days}d left'**
  String daysLeft(int days);

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}. Tap it, then come back and press Continue.'**
  String verifyEmailBody(String email);

  /// No description provided for @verifyEmailContinue.
  ///
  /// In en, this message translates to:
  /// **'I verified — Continue'**
  String get verifyEmailContinue;

  /// No description provided for @verifyEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get verifyEmailResend;

  /// No description provided for @verifyEmailResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String verifyEmailResendIn(int seconds);

  /// No description provided for @verifyEmailNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet. Check your inbox.'**
  String get verifyEmailNotYet;

  /// No description provided for @verifyEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent.'**
  String get verifyEmailSent;

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Wrong email? Change it'**
  String get changeEmail;

  /// No description provided for @changeEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmailTitle;

  /// No description provided for @changeEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the correct email'**
  String get changeEmailHint;

  /// No description provided for @changeEmailUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get changeEmailUpdate;

  /// No description provided for @emailChangeNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get emailChangeNoticeTitle;

  /// No description provided for @emailChangeNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}. Click the link, then come back and sign in with the new email.'**
  String emailChangeNoticeBody(String email);

  /// No description provided for @emailChangeNoticeButton.
  ///
  /// In en, this message translates to:
  /// **'Go to sign in'**
  String get emailChangeNoticeButton;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get sessionExpired;

  /// No description provided for @waitlistSize.
  ///
  /// In en, this message translates to:
  /// **'Waitlist Size'**
  String get waitlistSize;

  /// No description provided for @waitlist.
  ///
  /// In en, this message translates to:
  /// **'Waitlist'**
  String get waitlist;

  /// No description provided for @joinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join Waitlist'**
  String get joinWaitlist;

  /// No description provided for @leaveWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Leave Waitlist'**
  String get leaveWaitlist;

  /// No description provided for @waitlistFull.
  ///
  /// In en, this message translates to:
  /// **'Waitlist Full'**
  String get waitlistFull;

  /// No description provided for @waitlistedSnack.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been added to the waitlist'**
  String get waitlistedSnack;

  /// No description provided for @increaseCapacity.
  ///
  /// In en, this message translates to:
  /// **'Increase Capacity'**
  String get increaseCapacity;

  /// No description provided for @newMaxPlayers.
  ///
  /// In en, this message translates to:
  /// **'New max players'**
  String get newMaxPlayers;

  /// No description provided for @newWaitlistSize.
  ///
  /// In en, this message translates to:
  /// **'New waitlist size'**
  String get newWaitlistSize;

  /// No description provided for @capacityMustNotDecrease.
  ///
  /// In en, this message translates to:
  /// **'Capacity cannot be decreased'**
  String get capacityMustNotDecrease;

  /// No description provided for @mustBeAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Must be at least {count}'**
  String mustBeAtLeast(int count);

  /// No description provided for @sessionMissing.
  ///
  /// In en, this message translates to:
  /// **'This session no longer exists'**
  String get sessionMissing;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get notSignedIn;

  /// No description provided for @notYourSession.
  ///
  /// In en, this message translates to:
  /// **'Only the session\'s coach can do that'**
  String get notYourSession;

  /// No description provided for @nothingToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Nothing to update'**
  String get nothingToUpdate;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @heightHint.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get heightHint;

  /// No description provided for @weightHint.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get weightHint;

  /// No description provided for @invalidHeight.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid height (100–250 cm)'**
  String get invalidHeight;

  /// No description provided for @invalidWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid weight (20–200 kg)'**
  String get invalidWeight;

  /// No description provided for @editBodyMetrics.
  ///
  /// In en, this message translates to:
  /// **'Edit height & weight'**
  String get editBodyMetrics;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// No description provided for @noAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'No announcements yet'**
  String get noAnnouncements;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// No description provided for @newAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'New Announcement'**
  String get newAnnouncement;

  /// No description provided for @announcementTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get announcementTitle;

  /// No description provided for @announcementBody.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get announcementBody;

  /// No description provided for @announcementCreated.
  ///
  /// In en, this message translates to:
  /// **'Announcement posted'**
  String get announcementCreated;

  /// No description provided for @editAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Edit Announcement'**
  String get editAnnouncement;

  /// No description provided for @announcementUpdated.
  ///
  /// In en, this message translates to:
  /// **'Announcement updated'**
  String get announcementUpdated;

  /// No description provided for @announcementDeleted.
  ///
  /// In en, this message translates to:
  /// **'Announcement deleted'**
  String get announcementDeleted;

  /// No description provided for @confirmDeleteAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Delete announcement?'**
  String get confirmDeleteAnnouncement;

  /// No description provided for @confirmDeleteAnnouncementBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get confirmDeleteAnnouncementBody;

  /// No description provided for @sessionsHistory.
  ///
  /// In en, this message translates to:
  /// **'Sessions History'**
  String get sessionsHistory;

  /// No description provided for @noSessionsHistory.
  ///
  /// In en, this message translates to:
  /// **'No past sessions yet'**
  String get noSessionsHistory;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Membership History'**
  String get paymentHistory;

  /// No description provided for @noPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'No membership records yet'**
  String get noPaymentHistory;

  /// No description provided for @paymentChangedBy.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String paymentChangedBy(String name);

  /// No description provided for @historyAttendanceSummary.
  ///
  /// In en, this message translates to:
  /// **'{attended} attended · {joined}/{max} joined'**
  String historyAttendanceSummary(int attended, int joined, int max);

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @noLeaderboardData.
  ///
  /// In en, this message translates to:
  /// **'No attendance data yet'**
  String get noLeaderboardData;

  /// No description provided for @sessionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String sessionsCount(int count);

  /// No description provided for @recurringSessions.
  ///
  /// In en, this message translates to:
  /// **'Recurring Sessions'**
  String get recurringSessions;

  /// No description provided for @recurringSessionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-create sessions on a schedule'**
  String get recurringSessionsDesc;

  /// No description provided for @createRecurring.
  ///
  /// In en, this message translates to:
  /// **'New Recurring Session'**
  String get createRecurring;

  /// No description provided for @editRecurring.
  ///
  /// In en, this message translates to:
  /// **'Edit Recurring Session'**
  String get editRecurring;

  /// No description provided for @recurrenceDays.
  ///
  /// In en, this message translates to:
  /// **'Repeat On'**
  String get recurrenceDays;

  /// No description provided for @noRecurringSessions.
  ///
  /// In en, this message translates to:
  /// **'No recurring sessions'**
  String get noRecurringSessions;

  /// No description provided for @noRecurringSessionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap + to auto-create practices on a schedule'**
  String get noRecurringSessionsDesc;

  /// No description provided for @recurringCreated.
  ///
  /// In en, this message translates to:
  /// **'Recurring session created'**
  String get recurringCreated;

  /// No description provided for @recurringUpdated.
  ///
  /// In en, this message translates to:
  /// **'Recurring session updated'**
  String get recurringUpdated;

  /// No description provided for @recurringDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recurring session deleted'**
  String get recurringDeleted;

  /// No description provided for @confirmDeleteRecurring.
  ///
  /// In en, this message translates to:
  /// **'Delete recurring session?'**
  String get confirmDeleteRecurring;

  /// No description provided for @confirmDeleteRecurringBody.
  ///
  /// In en, this message translates to:
  /// **'Future sessions will no longer be auto-created.'**
  String get confirmDeleteRecurringBody;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @selectDays.
  ///
  /// In en, this message translates to:
  /// **'Select at least one day'**
  String get selectDays;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String greetingMorning(String name);

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String greetingAfternoon(String name);

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String greetingEvening(String name);

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get nextUp;

  /// No description provided for @sessionsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No sessions this week} =1{1 session this week} other{{count} sessions this week}}'**
  String sessionsThisWeek(int count);

  /// No description provided for @upcomingSessionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No upcoming sessions} =1{1 upcoming session} other{{count} upcoming sessions}}'**
  String upcomingSessionsCount(int count);

  /// No description provided for @findYourNextGame.
  ///
  /// In en, this message translates to:
  /// **'Find your next game'**
  String get findYourNextGame;

  /// No description provided for @joinedSuccess.
  ///
  /// In en, this message translates to:
  /// **'You\'re in! See you on court'**
  String get joinedSuccess;

  /// No description provided for @youLabel.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youLabel;

  /// No description provided for @gamesPlayed.
  ///
  /// In en, this message translates to:
  /// **'Games played'**
  String get gamesPlayed;

  /// No description provided for @tierRookie.
  ///
  /// In en, this message translates to:
  /// **'Rookie'**
  String get tierRookie;

  /// No description provided for @tierRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get tierRegular;

  /// No description provided for @tierVeteran.
  ///
  /// In en, this message translates to:
  /// **'Veteran'**
  String get tierVeteran;

  /// No description provided for @tierLegend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get tierLegend;

  /// No description provided for @tierChampion.
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get tierChampion;

  /// No description provided for @weekStreak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1-week streak} other{{count}-week streak}}'**
  String weekStreak(int count);

  /// No description provided for @milestoneUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{count} games played — you\'re now a {tier}!'**
  String milestoneUnlocked(int count, String tier);

  /// No description provided for @toNextTier.
  ///
  /// In en, this message translates to:
  /// **'{count} to {tier}'**
  String toNextTier(int count, String tier);

  /// No description provided for @endorse.
  ///
  /// In en, this message translates to:
  /// **'Endorse'**
  String get endorse;

  /// No description provided for @endorsed.
  ///
  /// In en, this message translates to:
  /// **'Endorsed'**
  String get endorsed;

  /// No description provided for @endorsements.
  ///
  /// In en, this message translates to:
  /// **'Endorsements'**
  String get endorsements;

  /// No description provided for @endorsedPlayer.
  ///
  /// In en, this message translates to:
  /// **'Endorsed {name}'**
  String endorsedPlayer(String name);

  /// No description provided for @endorseRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No endorsements left this session} =1{1 endorsement left} other{{count} endorsements left}}'**
  String endorseRemaining(int count);

  /// No description provided for @endorseFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t give endorsement'**
  String get endorseFailed;

  /// No description provided for @endorsementLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String endorsementLevelLabel(int level);

  /// No description provided for @endorsementMilestoneUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{count} endorsements — you reached {label}!'**
  String endorsementMilestoneUnlocked(int count, String label);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
