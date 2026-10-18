import 'dart:math' as math;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'src/url_launcher_helper.dart';

/// 本包在 GitHub 上的仓库地址（demo 顶栏的「GitHub」按钮会打开它）。
const String _repositoryUrl =
    'https://github.com/runoob-coder/card-fan-spread-widget';

/// 持久化语言选择的 key。
const String _localePrefKey = 'card_fan_spread_example.locale';

/// 演示用的示例牌背（放在 example/assets/ 下），用于「牌背选择」列表，
/// 任意一张都可以当作牌背使用。默认用 Rider Back，其余几张是 Bicycle 牌背，
/// 用来演示「任意牌背都可替换」。
///
/// 图片来源：https://bicyclecards.com/ ；"Bicycle" 及 Bicycle 牌背设计为
/// USPCC（美国扑克公司）所有的商标，此处仅作演示用途。
///
/// 实际使用时换成自己的资源即可：一张牌背 + 52 张牌面。
const List<String> _backAssets = [
  'assets/back/Back_Rider.webp',
  'assets/back/36-1.webp',
  'assets/back/126.webp',
  'assets/back/132.webp',
  'assets/back/162.webp',
  'assets/back/222.webp',
  'assets/back/354.webp',
  'assets/back/462.webp',
];

/// 默认牌背：Rider Back（经典 Bicycle 牌背）。
const String _defaultBackAsset = 'assets/back/Back_Rider.webp';

/// 演示用的示例牌面（放在 example/assets/rider_cards/ 下）。
///
/// 一套完整的 Rider Back 牌面：四个花色（Clubs / Diamonds / Hearts / Spades）
/// 各 13 张（A、2~10、J、Q、K），共 52 张。切到「牌面」时按这套牌面铺开，
/// 「重洗」按钮会把整副牌洗牌后再铺开。
///
/// 图片来源：https://bicyclecards.com/ ；"Bicycle" 及 Bicycle 牌面 / 牌背设计为
/// USPCC（美国扑克公司）所有的商标，此处仅作演示用途。
/// 一套完整的 Rider 牌面：四个花色 × 13 张，按花色、点数拼出资源路径。
final List<String> _riderFaceAssets = () {
  const List<String> suits = <String>['Clubs', 'Diamonds', 'Hearts', 'Spades'];
  const List<String> ranks = <String>[
    'A',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'J',
    'Q',
    'K',
  ];
  return <String>[
    for (final String suit in suits)
      for (final String rank in ranks) 'assets/rider_cards/${suit}_$rank.webp',
  ];
}();

/// 一副牌的张数。
const int _deckSize = 52;

void main() {
  runApp(const CardFanSpreadExampleApp());
}

class CardFanSpreadExampleApp extends StatefulWidget {
  const CardFanSpreadExampleApp({super.key});

  @override
  State<CardFanSpreadExampleApp> createState() =>
      _CardFanSpreadExampleAppState();
}

class _CardFanSpreadExampleAppState extends State<CardFanSpreadExampleApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _restoreLocale();
  }

  /// 启动时读取上次保存的语言；未保存或读取失败则跟随系统（null）。
  ///
  /// 偏好存储只是锦上添花：读不到（例如 web 插件暂不可用）也不该让 App 崩掉，
  /// 因此这里吞掉异常并回退到跟随系统语言。
  Future<void> _restoreLocale() async {
    String? code;
    try {
      final prefs = await SharedPreferences.getInstance();
      code = prefs.getString(_localePrefKey);
    } catch (_) {
      code = null;
    }
    if (!mounted) return;
    setState(
      () => _locale = code == null || code.isEmpty ? null : Locale(code),
    );
  }

  Future<void> _changeLocale(Locale? locale) async {
    setState(() => _locale = locale);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localePrefKey, locale?.languageCode ?? '');
    } catch (_) {
      // 持久化失败不影响本次语言切换。
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // null 表示跟随系统语言。
      locale: _locale,
      title: 'Card Fan Spread Demo',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D6B),
          brightness: Brightness.dark,
        ),
      ),
      // 注意：这里不用 `AppLocalizations.localizationsDelegates`——它指向的是
      // package:flutter_localizations 里的旧版（`package:flutter/material.dart`）
      // Material/Cupertino 本地化，类型与 material_ui 的 MaterialLocalizations
      // 不匹配，MaterialApp 会静默回退到英文的 DefaultMaterialLocalizations。
      // GlobalMaterialLocalizations.delegates（material_ui）已含 Cupertino 与
      // Widgets 两个 delegate。
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: CardFanSpreadDemoPage(
        locale: _locale,
        onLocaleChanged: _changeLocale,
      ),
    );
  }
}

/// 展开进度条：直接用 CustomPaint 跟随动画重绘，
/// 避免每帧重建 Material 组件（LinearProgressIndicator）。
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.controller});

  final CardFanSpreadController controller;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ProgressPainter(controller));
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter(this.controller) : super(repaint: controller);

  final CardFanSpreadController controller;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x1AFFFFFF),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * controller.progress, size.height),
      Paint()..color = const Color(0xFF4DB6AC),
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.controller != controller;
}

class CardFanSpreadDemoPage extends StatefulWidget {
  const CardFanSpreadDemoPage({
    super.key,
    this.locale,
    required this.onLocaleChanged,
  });

  /// 当前选中的语言；null 表示跟随系统。
  final Locale? locale;

  /// 用户切换语言时回调（null 表示恢复跟随系统）。
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  State<CardFanSpreadDemoPage> createState() => _CardFanSpreadDemoPageState();
}

class _CardFanSpreadDemoPageState extends State<CardFanSpreadDemoPage> {
  final CardFanSpreadController _controller = CardFanSpreadController();

  final math.Random _random = math.Random();

  FanSpreadMode _mode = FanSpreadMode.tableSpread;
  bool _showFace = false;
  String _backAsset = _defaultBackAsset;
  ImageProvider _backProvider = const AssetImage(_defaultBackAsset);
  late List<ImageProvider> _faceProviders;

  /// 开扇角度与展牌方向单独用 ValueNotifier 承载：拖动顶牌调角度时每个
  /// pointer move 都会写一次值，若放在页面级 State 里会连带重建整个控制面板
  /// （十几个滑块），这里让只有牌区那棵子树跟着重建。
  final ValueNotifier<double> _fanAngle = ValueNotifier<double>(220);
  final ValueNotifier<SpreadDirection> _direction = ValueNotifier(
    SpreadDirection.leftToRight,
  );
  late final Listenable _spreadParams;

  double _tierRatio = 0;
  double _fanPivotX = kDefaultFanPivotX;
  double _fanPivotLift = kDefaultFanPivotLift;
  double _stepRatio = 0.09;
  double _arcLift = -0.6;
  double _cardCount = _deckSize.toDouble();
  double _durationMs = 1800;
  double _stagger = 0;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _spreadParams = Listenable.merge(<Listenable>[_fanAngle, _direction]);
    _reshuffleFaces();
  }

  /// 用一套完整的 Rider 牌面铺成一副牌；「重洗」会先洗牌再铺开。
  void _reshuffleFaces() {
    final deck = List<String>.from(_riderFaceAssets)..shuffle(_random);
    _faceProviders = List<ImageProvider>.generate(
      _deckSize,
      (i) => AssetImage(deck[i % deck.length]),
    );
  }

  /// 切换牌背。
  void _selectBack(String asset) {
    setState(() {
      _backAsset = asset;
      _backProvider = AssetImage(asset);
    });
  }

  @override
  void dispose() {
    _fanAngle.dispose();
    _direction.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 用 fanAngle 的模式（S 扇同样由 fanAngle 控制反弯幅度；
  /// 双手开扇下它是每一边的摆幅，上限 kMaxTwoHandFanAngle）。
  bool get _isFanMode =>
      _mode == FanSpreadMode.fan ||
      _mode == FanSpreadMode.sFan ||
      _mode == FanSpreadMode.twoHandFan;

  /// 当前模式下 fanAngle 的上限：S 扇 540°（脊线切向的总摆幅能卷过一整圈）、
  /// 双手开扇每一边 220°、开扇 / 反开扇 360°。
  double get _maxFanAngle => switch (_mode) {
    FanSpreadMode.sFan => kMaxSFanAngle,
    FanSpreadMode.twoHandFan => kMaxTwoHandFanAngle,
    _ => kMaxFanAngle,
  };

  /// 能靠「拖动最顶的牌」调角度的模式：四种扇都行。
  /// S 扇的顶牌在牌带末端（朝向随 fanAngle 以 1/4 的斜率变化），
  /// 所以拖着它也能开合，只是灵敏度是开扇的两倍。
  bool get _canDragFanAngle => _isFanMode;

  /// 有「双层错落（大扇）」的模式——只有开扇，
  /// S 扇 / 双手开扇都没有（两扇盖在一起，错层只会糊成一团）。
  bool get _canTier => _mode == FanSpreadMode.fan;

  /// 有「枢轴（圆心）位置」参数的模式——开扇 / 双手开扇，
  /// S 扇的牌柄钉在脊线上，忽略这两个参数。
  bool get _canPivot =>
      _mode == FanSpreadMode.fan || _mode == FanSpreadMode.twoHandFan;

  void _switchMode(FanSpreadMode mode) {
    setState(() {
      _mode = mode;
      // 各模式的角度语义不同，切过来时各自给一个演示用的初始角度，
      // 而不是继承上一模式残留的值（否则滑块显示与实际生效不一致）。
      if (mode == FanSpreadMode.sFan) {
        // S 扇切过来直接张开到最大（脊线切向的总摆幅能卷过一整圈）。
        _fanAngle.value = kMaxSFanAngle;
      } else if (mode == FanSpreadMode.fan) {
        // 开扇初始张开 220°（半圈出头，是舒展的圆扇观感基准）。
        _fanAngle.value = 220;
      } else if (mode == FanSpreadMode.twoHandFan) {
        // 双手开扇：沿用当前值并钳回该模式上限（每一边 220°）。
        _fanAngle.value = _fanAngle.value.clamp(
          kMinFanAngle,
          kMaxTwoHandFanAngle,
        );
      } else {
        // 展牌不消费 fanAngle，但 CardFanSpread 构造断言要求它落在 0~360°，
        // 否则从 S 扇（可达 540°）切过来时残留的大角度会触发断言。
        _fanAngle.value = _fanAngle.value.clamp(kMinFanAngle, kMaxFanAngle);
      }
    });
    // 换模式后重新演示一次开扇过程。
    _controller.replay();
  }

  /// 模式名（按语言）。
  String _modeLabel(FanSpreadMode mode) => switch (mode) {
    FanSpreadMode.tableSpread => l10n.modeTableSpread,
    FanSpreadMode.fan => l10n.modeFan,
    FanSpreadMode.sFan => l10n.modeSFan,
    FanSpreadMode.twoHandFan => l10n.modeTwoHandFan,
  };

  /// 在外部浏览器 / 新标签页打开本包的 GitHub 仓库。
  ///
  /// Web 上同步 `window.open(..., '_blank')` 打开，避免被弹窗拦截；
  /// 其余平台走 url_launcher。
  void _openRepository() {
    openExternalUrl(_repositoryUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1714),
      appBar: AppBar(
        title: Text(l10n.appTitle),
        backgroundColor: const Color(0xFF10201C),
        actions: [
          Tooltip(
            message: l10n.githubRepo,
            child: TextButton.icon(
              onPressed: _openRepository,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('GitHub'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.replayTooltip,
            icon: const Icon(Icons.replay),
            onPressed: _controller.replay,
          ),
          PopupMenuButton<Locale?>(
            icon: const Icon(Icons.language),
            tooltip: l10n.language,
            onSelected: widget.onLocaleChanged,
            itemBuilder: (context) => <PopupMenuEntry<Locale?>>[
              _languageItem(null, l10n.systemLanguage, widget.locale == null),
              for (final locale in AppLocalizations.supportedLocales)
                _languageItem(
                  locale,
                  _languageName(locale),
                  widget.locale == locale,
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 展开进度（只重绘自身，不触发 rebuild）
          SizedBox(height: 3, child: _ProgressTrack(controller: _controller)),
          // 台面
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.15),
                  radius: 1.1,
                  colors: [Color(0xFF1C3B33), Color(0xFF0B1714)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              // 只让牌区跟着「开扇角度 / 展牌方向」重建：这两个值在拖动时每次
              // pointer move 都会变，放页面级 State 里会把整个控制面板一起重建。
              child: AnimatedBuilder(
                animation: _spreadParams,
                builder: (context, _) => RepaintBoundary(
                  child: CardFanSpread(
                    mode: _mode,
                    controller: _controller,
                    cardBack: _backProvider,
                    cardFaces: _faceProviders,
                    showFace: _showFace,
                    cardCount: _cardCount.round(),
                    direction: _direction.value,
                    fanAngle: _fanAngle.value,
                    fanTierRatio: _tierRatio.clamp(0.0, kMaxFanTierRatio),
                    fanPivotX: _fanPivotX,
                    fanPivotLift: _fanPivotLift,
                    tableStepRatio: _stepRatio,
                    tableArcLift: _arcLift,
                    duration: Duration(milliseconds: _durationMs.round()),
                    stagger: _stagger,
                    onFanAngleChanged: (v) => _fanAngle.value = v,
                    // 收拢态往右拖 → 切成从左往右；往左拖 → 切成从右往左。
                    onDirectionChanged: (d) => _direction.value = d,
                  ),
                ),
              ),
            ),
          ),
          // 控制面板限高，超出可滚动，从而把更多纵向空间让给开扇区域。
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: SingleChildScrollView(child: _buildControlPanel()),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF10201C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 模式（五种）
          SizedBox(
            width: double.infinity,
            // 不用 SegmentedButton：五种模式只放文字也会在窄屏撑破行宽，
            // 改成可换行的 ChoiceChip，一行放不下就折到下一行（标签压到 12sp、
            // 收窄内边距，宽屏下五种模式正好一行，好把高度让给牌区）。
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final mode in FanSpreadMode.values)
                  ChoiceChip(
                    label: Text(_modeLabel(mode)),
                    labelStyle: const TextStyle(fontSize: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    selected: _mode == mode,
                    onSelected: (_) => _switchMode(mode),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 播放 / 牌面切换
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _actionButton(
                Icons.play_arrow_rounded,
                l10n.play,
                _controller.play,
                filled: true,
              ),
              _actionButton(
                Icons.replay_rounded,
                l10n.replay,
                _controller.replay,
              ),
              _actionButton(
                Icons.close_fullscreen,
                l10n.close,
                _controller.close,
              ),
              if (_showFace)
                _actionButton(Icons.shuffle_rounded, l10n.reshuffle, () {
                  setState(_reshuffleFaces);
                }),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.back)),
                  ButtonSegment(value: true, label: Text(l10n.face)),
                ],
                selected: <bool>{_showFace},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _showFace = s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.doubleTapHint,
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ),
          if (!_isFanMode)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l10n.tableDragHint,
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ),
          const SizedBox(height: 10),
          // 牌背选择
          Row(
            children: [
              Text(
                l10n.back,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildBackPicker()),
            ],
          ),
          const Divider(height: 16),
          // 参数（按模式显示）
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 方向放在参数第一位：四种模式通用（展牌 = 叠压顺序 / 顶牌端，
                // 开扇 = 扇形从哪端长出去，S 扇 = 水平镜像，双手开扇 = 哪只手先动），
                // 而且收拢态拖动顶牌也会自动改它，放前面才看得见。
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        l10n.direction,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    Expanded(
                      // 与角度滑块同理：展牌收拢态往哪边拖就往哪边铺开，方向是通过
                      // onDirectionChanged 写 [_direction] 的，
                      // 这里必须订阅它，选中态才会跟着变。
                      child: ValueListenableBuilder<SpreadDirection>(
                        valueListenable: _direction,
                        builder: (context, direction, _) =>
                            SegmentedButton<SpreadDirection>(
                              segments: [
                                ButtonSegment(
                                  value: SpreadDirection.leftToRight,
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                  ),
                                  label: Text(l10n.leftToRight),
                                ),
                                ButtonSegment(
                                  value: SpreadDirection.rightToLeft,
                                  icon: const Icon(Icons.arrow_back, size: 16),
                                  label: Text(l10n.rightToLeft),
                                ),
                              ],
                              selected: <SpreadDirection>{direction},
                              showSelectedIcon: false,
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                              ),
                              onSelectionChanged: (s) {
                                _direction.value = s.first;
                                _controller.replay();
                              },
                            ),
                      ),
                    ),
                  ],
                ),
                if (_isFanMode)
                  // 角度滑块必须**订阅** [_fanAngle]，而不是只在页面 build 时读一次：
                  // 拖动顶牌调角度走的是 onFanAngleChanged，它只写这个
                  // ValueNotifier、不会 setState 整页（否则每次 pointer move 都要
                  // 把十几个滑块一起重建，拖动又变卡），于是只刷新这一行就能让
                  // 「顶牌拖动」与「设置条」联动。
                  ValueListenableBuilder<double>(
                    valueListenable: _fanAngle,
                    builder: (context, angle, _) => _slider(
                      label: l10n.fanAngle,
                      value: angle,
                      min: kMinFanAngle,
                      // 上限随模式不同：S 扇 540°（脊线切向的总摆幅能卷过一整圈）、
                      // 双手开扇每一边 220°（再大两扇在上下两端就会盖成一团）、
                      // 开扇 / 反开扇 360°。
                      max: _maxFanAngle,
                      // 10° 一档（0° = 完全收拢）。
                      divisions: (_maxFanAngle / 10).round(),
                      suffix: '°',
                      // 不必 setState：写 [_fanAngle] 就会让上面的
                      // ValueListenableBuilder 重建，滑块自己跟上。
                      onChanged: (v) => _fanAngle.value = v,
                    ),
                  ),
                if (_canDragFanAngle)
                  Padding(
                    padding: const EdgeInsets.only(left: 72, bottom: 2),
                    child: Text(
                      l10n.dragTopHint,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                if (_canTier)
                  _slider(
                    label: l10n.fanTierRatio,
                    value: _tierRatio,
                    min: 0,
                    max: kMaxFanTierRatio,
                    divisions: 26, // 2.5% 一档（0% = 两层齐平 = 单层扇形）
                    suffix: '',
                    formatValue: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => setState(() => _tierRatio = v),
                  ),
                // 枢轴（圆心）参数：开扇 / 反开扇 / 双手开扇都有（S 扇钉在
                // 脊线上，没有枢轴可调）。
                if (_canPivot) ...[
                  // 枢轴（圆心）沿牌边的位置：0% = 左边缘，50% = 边缘中心，
                  // 100% = 右边缘。所有牌绕同一个相对位置旋转，扇形随之偏轴。
                  _slider(
                    label: l10n.fanPivotX,
                    value: _fanPivotX,
                    min: kMinFanPivotX,
                    max: kMaxFanPivotX,
                    divisions: 20, // 5% 一档
                    suffix: '',
                    formatValue: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => setState(() => _fanPivotX = v),
                  ),
                  // 枢轴相对牌底边的沉深：负值抬到牌面内（默认 -6%，
                  // 即拇指捏住扇骨的位置），0 = 底边，正值沉到牌边下方。
                  _slider(
                    label: l10n.fanPivotLift,
                    value: _fanPivotLift,
                    min: kMinFanPivotLift,
                    max: kMaxFanPivotLift,
                    divisions: 30, // 5% 一档
                    suffix: '',
                    formatValue: (v) =>
                        '${v >= 0 ? '+' : ''}${(v * 100).round()}%',
                    onChanged: (v) => setState(() => _fanPivotLift = v),
                  ),
                ],
                // 以下两项只属于展牌。
                if (!_isFanMode) ...[
                  _slider(
                    label: l10n.offsetDistance,
                    value: _stepRatio,
                    min: 0.01,
                    max: 0.15,
                    divisions: 28,
                    suffix: '',
                    formatValue: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => setState(() => _stepRatio = v),
                  ),
                  _slider(
                    label: _arcLift >= 0 ? l10n.endsUp : l10n.endsDown,
                    value: _arcLift,
                    min: -0.8,
                    max: 0.8,
                    divisions: 32,
                    suffix: '',
                    formatValue: (v) =>
                        '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}',
                    onChanged: (v) => setState(() => _arcLift = v),
                  ),
                ],
                _slider(
                  label: l10n.cardCount,
                  value: _cardCount,
                  min: 2,
                  max: 52,
                  divisions: 50,
                  suffix: '',
                  formatValue: (v) => '${v.round()} 张',
                  onChanged: (v) => setState(() => _cardCount = v),
                ),
                _slider(
                  label: l10n.animDuration,
                  value: _durationMs,
                  min: 600,
                  max: 3000,
                  divisions: 24,
                  suffix: 'ms',
                  onChanged: (v) => setState(() => _durationMs = v),
                ),
                _slider(
                  label: l10n.stagger,
                  value: _stagger,
                  min: 0,
                  max: 1.5,
                  divisions: 15,
                  suffix: '',
                  formatValue: (v) => v.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _stagger = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 横向缩略图列表，用于选择哪一张作为牌背。
  Widget _buildBackPicker() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _backAssets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final asset = _backAssets[index];
          final selected = asset == _backAsset;
          return GestureDetector(
            onTap: () => _selectBack(asset),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.all(selected ? 0 : 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white12,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(asset, fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool filled = false,
  }) {
    final style = filled
        ? FilledButton.styleFrom(visualDensity: VisualDensity.compact)
        : OutlinedButton.styleFrom(visualDensity: VisualDensity.compact);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
    String Function(double)? formatValue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              formatValue?.call(value) ?? '${value.round()}$suffix',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }
}

/// 语言菜单项：选中项左侧显示对勾。
PopupMenuItem<Locale?> _languageItem(
  Locale? locale,
  String label,
  bool selected,
) {
  return PopupMenuItem<Locale?>(
    value: locale,
    child: Row(
      children: [
        SizedBox(
          width: 22,
          child: selected ? const Icon(Icons.check, size: 18) : null,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    ),
  );
}

/// 语言代码的原生名称（无需翻译）。
String _languageName(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return 'English';
    case 'zh':
      return '中文';
    case 'ja':
      return '日本語';
    case 'ko':
      return '한국어';
    default:
      return locale.languageCode;
  }
}
