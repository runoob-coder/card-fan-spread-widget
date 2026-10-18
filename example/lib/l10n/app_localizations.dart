import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

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
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Card Fan by noob-coder'**
  String get appTitle;

  /// No description provided for @replayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replayTooltip;

  /// No description provided for @modeTableSpread.
  ///
  /// In en, this message translates to:
  /// **'Table Spread'**
  String get modeTableSpread;

  /// No description provided for @modeFan.
  ///
  /// In en, this message translates to:
  /// **'Open Fan'**
  String get modeFan;

  /// No description provided for @modeSFan.
  ///
  /// In en, this message translates to:
  /// **'S Fan'**
  String get modeSFan;

  /// No description provided for @modeTwoHandFan.
  ///
  /// In en, this message translates to:
  /// **'Two-Hand Fan'**
  String get modeTwoHandFan;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @replay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replay;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @reshuffle.
  ///
  /// In en, this message translates to:
  /// **'Reshuffle'**
  String get reshuffle;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @face.
  ///
  /// In en, this message translates to:
  /// **'Face'**
  String get face;

  /// No description provided for @dragTopHint.
  ///
  /// In en, this message translates to:
  /// **'You can also drag the top card'**
  String get dragTopHint;

  /// No description provided for @doubleTapHint.
  ///
  /// In en, this message translates to:
  /// **'Double-tap the canvas to play / collapse'**
  String get doubleTapHint;

  /// No description provided for @tableDragHint.
  ///
  /// In en, this message translates to:
  /// **'Table spread: drag the top card to open / close'**
  String get tableDragHint;

  /// No description provided for @direction.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get direction;

  /// No description provided for @leftToRight.
  ///
  /// In en, this message translates to:
  /// **'Left → Right'**
  String get leftToRight;

  /// No description provided for @rightToLeft.
  ///
  /// In en, this message translates to:
  /// **'Right → Left'**
  String get rightToLeft;

  /// No description provided for @offsetDistance.
  ///
  /// In en, this message translates to:
  /// **'Offset Distance'**
  String get offsetDistance;

  /// No description provided for @endsUp.
  ///
  /// In en, this message translates to:
  /// **'Both Ends Up'**
  String get endsUp;

  /// No description provided for @endsDown.
  ///
  /// In en, this message translates to:
  /// **'Both Ends Down'**
  String get endsDown;

  /// No description provided for @cardCount.
  ///
  /// In en, this message translates to:
  /// **'Card Count'**
  String get cardCount;

  /// No description provided for @animDuration.
  ///
  /// In en, this message translates to:
  /// **'Animation Duration'**
  String get animDuration;

  /// No description provided for @stagger.
  ///
  /// In en, this message translates to:
  /// **'Stagger'**
  String get stagger;

  /// No description provided for @fanTierRatio.
  ///
  /// In en, this message translates to:
  /// **'Tier Offset'**
  String get fanTierRatio;

  /// No description provided for @fanAngle.
  ///
  /// In en, this message translates to:
  /// **'Fan Angle'**
  String get fanAngle;

  /// No description provided for @fanPivotX.
  ///
  /// In en, this message translates to:
  /// **'Pivot Position'**
  String get fanPivotX;

  /// No description provided for @fanPivotLift.
  ///
  /// In en, this message translates to:
  /// **'Pivot Depth'**
  String get fanPivotLift;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get systemLanguage;

  /// No description provided for @githubRepo.
  ///
  /// In en, this message translates to:
  /// **'View source on GitHub'**
  String get githubRepo;
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
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
