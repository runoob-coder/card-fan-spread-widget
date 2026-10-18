// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Card Fan by noob-coder';

  @override
  String get replayTooltip => '重新播放';

  @override
  String get modeTableSpread => '展牌';

  @override
  String get modeFan => '开扇';

  @override
  String get modeSFan => 'S 扇';

  @override
  String get modeTwoHandFan => '双手开扇';

  @override
  String get play => '播放';

  @override
  String get replay => '重播';

  @override
  String get close => '收拢';

  @override
  String get reshuffle => '换一副';

  @override
  String get back => '牌背';

  @override
  String get face => '牌面';

  @override
  String get dragTopHint => '也可以直接拖动最顶的那张牌';

  @override
  String get doubleTapHint => '双击画布：播放 / 收拢';

  @override
  String get tableDragHint => '展牌：拖动最顶那张牌可跟手摊开 / 收拢';

  @override
  String get direction => '方向';

  @override
  String get leftToRight => '左→右';

  @override
  String get rightToLeft => '右→左';

  @override
  String get offsetDistance => '错位距离';

  @override
  String get endsUp => '两端上翘';

  @override
  String get endsDown => '两端下翘';

  @override
  String get cardCount => '牌数';

  @override
  String get animDuration => '动画时长';

  @override
  String get stagger => '逐张错峰';

  @override
  String get fanTierRatio => '双层错落';

  @override
  String get fanAngle => '开扇角度';

  @override
  String get fanPivotX => '枢轴位置';

  @override
  String get fanPivotLift => '枢轴沉深';

  @override
  String get language => '语言';

  @override
  String get systemLanguage => '跟随系统';

  @override
  String get githubRepo => '在 GitHub 上查看源码';
}
