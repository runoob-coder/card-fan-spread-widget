// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Card Fan by noob-coder';

  @override
  String get replayTooltip => '다시 재생';

  @override
  String get modeTableSpread => '테이블 펼치기';

  @override
  String get modeFan => '부채 펴기';

  @override
  String get modeSFan => 'S 팬';

  @override
  String get modeTwoHandFan => '양손 팬';

  @override
  String get play => '재생';

  @override
  String get replay => '다시 보기';

  @override
  String get close => '접기';

  @override
  String get reshuffle => '다시 섞기';

  @override
  String get back => '뒷면';

  @override
  String get face => '앞면';

  @override
  String get dragTopHint => '가장 위 카드를 드래그할 수도 있습니다';

  @override
  String get doubleTapHint => '캔버스를 두 번 탭하면 펼치기 / 접기';

  @override
  String get tableDragHint => '테이블 펼치기: 맨 위 카드를 드래그해 펼치기 / 접기';

  @override
  String get direction => '방향';

  @override
  String get leftToRight => '왼쪽→오른쪽';

  @override
  String get rightToLeft => '오른쪽→왼쪽';

  @override
  String get offsetDistance => '오프셋 거리';

  @override
  String get endsUp => '양끝 위로';

  @override
  String get endsDown => '양끝 아래로';

  @override
  String get cardCount => '카드 수';

  @override
  String get animDuration => '애니메이션 시간';

  @override
  String get stagger => '카드별 시차';

  @override
  String get fanTierRatio => '단차';

  @override
  String get fanAngle => '부채 각도';

  @override
  String get fanPivotX => '축 위치';

  @override
  String get fanPivotLift => '축 깊이';

  @override
  String get language => '언어';

  @override
  String get systemLanguage => '시스템 따르기';

  @override
  String get githubRepo => 'GitHub에서 소스 보기';
}
