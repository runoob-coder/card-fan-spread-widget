// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Card Fan by noob-coder';

  @override
  String get replayTooltip => '再生';

  @override
  String get modeTableSpread => 'テーブル展開';

  @override
  String get modeFan => '開扇';

  @override
  String get modeSFan => 'S ファン';

  @override
  String get modeTwoHandFan => '両手ファン';

  @override
  String get play => '再生';

  @override
  String get replay => 'リプレイ';

  @override
  String get close => '閉じる';

  @override
  String get reshuffle => '再シャッフル';

  @override
  String get back => '裏面';

  @override
  String get face => '表面';

  @override
  String get dragTopHint => '一番上のカードをドラッグすることもできます';

  @override
  String get doubleTapHint => 'キャンバスをダブルタップで再生 / 収束';

  @override
  String get tableDragHint => 'テーブル展開：一番上のカードをドラッグで開閉';

  @override
  String get direction => '方向';

  @override
  String get leftToRight => '左→右';

  @override
  String get rightToLeft => '右→左';

  @override
  String get offsetDistance => 'オフセット距離';

  @override
  String get endsUp => '両端上向き';

  @override
  String get endsDown => '両端下向き';

  @override
  String get cardCount => '枚数';

  @override
  String get animDuration => 'アニメーション時間';

  @override
  String get stagger => 'カードごとのずらし';

  @override
  String get fanTierRatio => '段のずらし';

  @override
  String get fanAngle => '開扇角度';

  @override
  String get fanPivotX => '枢軸位置';

  @override
  String get fanPivotLift => '枢軸の沈み';

  @override
  String get language => '言語';

  @override
  String get systemLanguage => 'システムに合わせる';

  @override
  String get githubRepo => 'GitHub でソースを見る';
}
