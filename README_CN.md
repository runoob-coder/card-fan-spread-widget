# 🃏 纸牌开扇组件

<div align="center">
  <a href="https://runoob-coder.github.io/card-fan-spread-widget/" target="_blank" rel="noopener">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/example/web/icons/playing-cards-fan-dark.svg">
      <img src="https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/example/web/icons/playing-cards-fan.svg" width="200" style="width: 200px;" alt="card_fan_spread">
    </picture>
  </a>
</div>

模拟魔术师开牌动作的 Flutter 纸牌组件：**展牌（桌面摊开）**、**开扇**、**S 扇**、
**双手开扇**四种方式，左右方向由统一的 `direction` 控制（开扇取 `rightToLeft`
就是**反开扇**），均带逐张级联动画。开扇还支持可调的**双层错落**——打开后就是花切（Cardistry）里的
「大扇（Giant Fan）」，比普通圆扇大得多；开扇的**圆心（枢轴）**也可以沿牌边挪动
或沉到牌边下方，得到偏轴 / 垂挂等不同的扇形。

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/runoob-coder/card-fan-spread-widget)
[![Flutter Demo](https://img.shields.io/badge/demo-Flutter-brightgreen.svg)][preview]
[![CI](https://img.shields.io/github/actions/workflow/status/runoob-coder/card-fan-spread-widget/deploy_web.yml?label=CI)](https://github.com/runoob-coder/card-fan-spread-widget/actions/workflows/deploy_web.yml)
[![GitHub stars](https://img.shields.io/github/stars/runoob-coder/card-fan-spread-widget.svg?style=social)](https://github.com/runoob-coder/card-fan-spread-widget)

Language: [English](README.md) | 中文

| [![开扇][fan-img]][preview] | [![反开扇][reverse-fan-img]][preview] | [![开扇（牌面）][fan-face-img]][preview] | [![偏轴开扇（枢轴贴在左边缘）][fan-pivot-left-img]][preview] |
|---------------------------------------------------------------|--------------------------------------------------|--------------------------------------------------------|------------------------------------------|
| [![大扇（开扇 + 双层错落）][giant-fan-img]][preview] | [![垂挂开扇（枢轴沉到牌边下方）][fan-pivot-drop-img]][preview] | [![双手开扇（牌面）][two-hand-fan-face-img]][preview] | [![双手开扇][two-hand-fan-img]][preview] |
| [![展牌][table-spread-img]][preview] | [![展牌（牌面）][table-spread-face-img]][preview] | [![S 扇][s-fan-img]][preview] | [![S 扇（牌面）][s-fan-face-img]][preview] |

## ✨ 功能特性

- **四种开牌方式 × 两个方向** — `FanSpreadMode`：`tableSpread`（桌面摊牌）、`fan`（开扇）、
  `sFan`（S 扇）、`twoHandFan`（双手开扇）；左右方向由统一的 `direction`
  （`SpreadDirection.leftToRight` / `rightToLeft`）控制，四种模式通用。
- **双手开扇** — 左右手各捏半叠、各自朝外侧扇开，两扇**各绕自己的手握点**旋转
  （收拢时仍是左右两叠），扇面在上下两端交叉。参数与开扇一致（`fanAngle` 是
  **每一边**的摆幅，上限 `kMaxTwoHandFanAngle` = 220°），摆幅 ≥90° 后以正左右为中心、
  上下平分空间；不支持双层错落。
- **S 扇** — Cardistry 里的 *S Fan*：牌柄沿一条 **S 形脊线**依次排开、牌垂直于脊线
  朝外辐射，整叠摊成一条竖立的 S 形牌带。反弯幅度由 `fanAngle` 控制（0°–540°，
  能卷过一整圈）；拖顶牌可开合，灵敏度是开扇的两倍。
- **双层错落（大扇）** — `fanTierRatio` 把奇数下标的牌向外推出一层，得到内 / 外两层错落的
  **大扇（Giant Fan / Giant Pressure Fan）**。仅开扇支持。
- **枢轴（圆心）可调** — `fanPivotX` / `fanPivotLift` 让圆心沿牌宽方向挪到任意一侧
  （偏轴扇形）或沉到牌边下方（牌像从枢轴上垂挂下来），所有牌仍绕同一个相对位置旋转。
  支持开扇 / 双手开扇，S 扇忽略。
- **级联动画** — 每张牌错峰出发，可反向播放收拢。
- **几何可调** — 开扇角度 `fanAngle`（开扇 0°–360°，S 扇 0°–540°，
  双手开扇每边 0°–220°）、双层错落 `fanTierRatio`、枢轴 `fanPivotX` / `fanPivotLift`、
  展牌密度 `tableStepRatio` 与弧度 `tableArcLift`。
- **图片由调用方提供** — 一张牌背（可选）+ 可选 52 张牌面（不足循环取用），`showFace`
  随时切换；无图（未解码 / 解码失败）时每张牌画成白底空白牌。
- **过渡全部平滑** — 牌背 ↔ 牌面交叉淡入淡出；阴影与描边随相邻牌的实际错位连续淡入淡出。
- **精灵图预合成** — 牌面 / 牌背 + 圆角 + 阴影 + 描边离屏预合成，52 张牌也能稳 60fps。
- **双击开合** — 双击画布即可播放 / 收拢（`doubleTapToToggle`，默认开启）。
- **拖动跟手** — 展牌拖顶牌即跟手摊开 / 收拢（`tableDragToSpread`，默认开启），
  拖动方向决定展牌方向（`onDirectionChanged`）；扇模式拖顶牌调角度
  （`onFanAngleChanged`）。
- **拖动调角度** — 开扇 / 双手开扇模式下，可直接拖动最顶的那张牌调整开扇角度。

## 🚀 快速开始

[在线演示][preview] — 立即体验

图片：**一张牌背（`cardBack`，可选）**；可选传入 52 张牌面（`cardFaces`，
数量不足会循环取用）用于切换牌面 / 牌背。不传牌背、或图片尚未解码完成
（资源缺失 / 加载中）时，每张牌按一张背面朝上的白底空白牌绘制。

## 📖 使用

### 🃏 基础用法

```dart
final controller = CardFanSpreadController();

CardFanSpread(
  mode: FanSpreadMode.fan,      // 或 tableSpread / sFan / twoHandFan
  direction: SpreadDirection.leftToRight, // rightToLeft = 反开扇 / 镜像的 S / 右手先动
  controller: controller,
  cardBack: const AssetImage('assets/cards/card_back.png'),
  cardFaces: faceAssets.map(AssetImage.new).toList(), // 52 张
  showFace: true,          // true 显示牌面，false 显示牌背
  fanAngle: 200,           // 开扇的角度范围
  fanTierRatio: 0.22,      // 双层错落（大扇）：0 = 单层扇，>0 = 内外两层错落
  fanPivotX: 0.5,          // 枢轴（圆心）沿牌边的位置：0 = 左边缘，1 = 右边缘
  fanPivotLift: -0.06,     // 枢轴相对牌底边的沉深（牌高倍数）：负 = 牌面内，正 = 牌边下方
  duration: const Duration(milliseconds: 1800),
  stagger: 0.55,           // 逐张错峰程度
);

controller.play();   // 展开（已是展开态则重播）
controller.close();  // 收拢
controller.toggle(); // 开 / 合
```

不传 `controller` 也可以——组件会自行驱动动画，是否挂载后自动播放由
`autoPlay` 决定。

### 🎮 控制动画

`CardFanSpreadController` 驱动开合动画：

```dart
controller.play();   // 展开（已是展开态则重播）
controller.replay(); // 无论当前状态，从收拢态重新展开
controller.close();  // 收拢
controller.toggle(); // 开 / 合
controller.reset();  // 立刻回到收拢状态
controller.seekTo(0.5); // 定位到指定进度并停住动画（拖动跟手用）
```

通过 `controller.progress`（0 = 收拢，1 = 完全展开）、`controller.isAnimating`、
`controller.isOpened` 读取当前状态。

同一个 controller 可以同时绑定多个 `CardFanSpread` 组件（例如「缩略预览 +
主视图」）：控制命令作用于全部绑定的组件，读取类接口取最近绑定的那一个。

### 👆 双击画布

默认双击画布就切换「播放 / 收拢」：已完全展开 → 收拢，否则 → 展开
（正在收拢时顺势转回展开）。传了 `controller` 时，双击作用于该 controller
绑定的**全部**组件；`doubleTapToToggle: false` 可关掉内置切换，此时仍可用
`onDoubleTap` 收到双击回调。

```dart
CardFanSpread(
  controller: controller,
  doubleTapToToggle: true,      // 默认就是这个
  onDoubleTap: () => debugPrint('double tapped'),
);
```

### 🖐️ 展牌：拖动最顶的牌跟手开合

展牌模式下拖动最顶那张牌，牌会跟着手指摊开 / 收拢（`tableDragToSpread`，
默认开启）：手指位移投影到「收拢位置 → 最终位置」这条轴上，占整段行程的
比例就是顶牌该到的进度，再反解回总进度（含逐张错峰与缓动曲线）。
**松手后画面停在当前进度、不会自己播完**——要继续就再拖、双击或调 controller。
传 `tableDragToSpread: false` 可关掉。

```dart
// 代码里想直接把进度定到某个值（并停掉正在跑的动画）：
controller.seekTo(0.5); // 摊到一半停住
```

### 🧭 收拢态拖动定方向

**展牌**收拢时，拖动方向会决定叠压方向（顶牌跟着手指走）：往右拖 → **从左往右**
（顶牌换成最右那张、牌带朝右铺），往左拖 → **从右往左**；手指继续往原方向走
就继续摊开。

**开扇**同理：画面收拢时拖动顶牌，手指把它往顺时针带 → **leftToRight**、
往逆时针带 → **rightToLeft**，换向后同一个手势继续把扇子朝另一侧张开。
「画面收拢」有两种：`fanAngle` 本来就是 0°，或者按过「收拢」进度归零
（此时 `fanAngle` 可能还是 220°）。张开的扇往里拖、手指**推过收拢角**后
同样会换向接着张开——不会被钳在 0° 拖不动；只是拖到 0° 停住不再推，则不会翻。

方向由组件建议、调用方回写：

```dart
CardFanSpread(
  direction: _direction, // 你的 state
  onDirectionChanged: (d) => setState(() => _direction = d),
);
```

接了回调就以调用方为准；**不接回调组件也会自己翻**（生效方向），否则收拢态
往另一侧拖会被钳在 0° 完全没反应。展牌只在收拢态起拖时定方向，已经摊开的牌
再拖只跟手收放；开扇在收拢角上、或往里推过收拢角后才换向，一次拖动最多换
一次向。S 扇 / 双手开扇不参与（顶牌在牌带末端 / 本来左右各一扇，
「另一侧」没有明确含义）。

开扇张开后的拖动是调 `fanAngle`（见 `onFanAngleChanged`）。

### 🖼️ 牌面 / 牌背

只有 `cardBack` 是选传项（通常都会传一张牌背）。要显示牌面，传入 `cardFaces`
（52 张或任意数量，不足循环取用）并把 `showFace` 置为 true：

```dart
CardFanSpread(
  cardBack: const AssetImage('assets/cards/card_back.png'),
  cardFaces: faceAssets.map(AssetImage.new).toList(),
  showFace: true,
);
```

没有图也能用：不传 `cardBack`（或图片还在解码中、解码失败）时，每张牌画成
一张背面朝上的**白底空白牌**（底色常量 `kCardBlankColor`），
而不是透明或黑块——所以资源缺失时你看到的是一副白牌，而不是一叠黑牌。

切换 `showFace` 时牌背 ↔ 牌面以 280ms 交叉淡入淡出过渡，避免整幅画面明暗跳变。

### 📐 布局注意

组件需要**有界约束**——请用 `SizedBox` / `Expanded` / `AspectRatio` 等包裹，
或放在普通盒子布局里。在 `Row` 这类提供无界宽度的父组件中直接使用时，
会退回内置的 400×600 画布而不是崩溃。

### 🎛️ 参数

| 参数 | 说明 | 适用模式 |
| --- | --- | --- |
| `fanAngle` | 扇形角度范围（**0° = 完全收拢**：所有牌目标角为 0，展开后仍是一叠重合的牌）。上限随模式不同：开扇 0–360°（`kMaxFanAngle`，超过一整圈只是绕回来盖住自己）；S 扇 0–540°（`kMaxSFanAngle`）——它指**牌带的反弯幅度**：脊线切向先转出 `fanAngle` 的一半再转回来，牌垂直于脊线所以摆出同样的幅度，这个幅度本身能卷过一整圈（360° 是最标准的 S、450° 附近最饱满、540° 是快卷成「8」字前仍认得出 S 的极限）。双手开扇下指**每一边**的摆幅，上限 `kMaxTwoHandFanAngle`（220°）；0° 时两扇都没张开，但双手各捏一半，所以展开后是**左右两叠**竖牌而不是一叠；≥90° 后两扇以正左右为中心、上下平分空间 | 开扇 / S 扇 / 双手开扇 |
| `fanTierRatio` | 双层错落：外层沿牌长轴向外推出的距离 / 牌高（0–0.65，0 = 单层扇） | 开扇（S 扇 / 双手开扇忽略） |
| `fanPivotX` | 枢轴（开扇的「圆心」）沿牌宽方向的位置（0 = 左边缘，0.5 = 牌边中心，1 = 右边缘）。所有牌绕同一个相对位置旋转，挪到一侧即得偏轴扇形 | 开扇 / 双手开扇（S 扇忽略） |
| `fanPivotLift` | 枢轴相对牌底边的沉深 / 牌高（0 = 底边；正值沉到牌边下方，牌像垂挂下来；负值抬到牌面内，默认 -0.06 = 拇指捏位）。范围 -0.5–1.0 | 开扇 / 双手开扇（S 扇忽略） |
| `direction` | 展开的左右方向，四种模式通用：展牌下是叠压顺序（`leftToRight` 时右半部分的牌在上层）；开扇下是扇形从哪端长出（`rightToLeft` 即反开扇）；S 扇下是水平镜像的 S；双手开扇下是「哪只手先动 + 哪半叠压在上层」（`leftToRight` = 左手先动、右半叠在上） | 全部 |
| `tableStepRatio` | 相邻牌错位距离 / 牌宽（越小重叠越深） | 展牌 |
| `tableArcLift` | 两端相对中间的翘起幅度 / 牌高，**正值两端上翘，负值两端下翘** | 展牌 |
| `stagger` | 逐张错峰系数，0 为所有牌同时运动 | 全部 |
| `shadowColor` | 牌与牌之间的投影，默认 14% 黑；传 `Colors.transparent` 关闭 | 全部 |
| `spriteMemoryBudget` | 预合成精灵图的显存预算（字节），默认 `kSpriteMemoryBudget` = 64MB。超出预算时自动下调合成倍率（清晰度换内存）。牌面不重复且张数多时可调大，内存紧张的平台（如 Web）可调小 | 全部 |
| `curve` | 整体缓动曲线 | 全部 |
| `autoPlay` | 挂载后是否自动播放展开动画 | 全部 |
| `doubleTapToToggle` | 双击画布是否切换「播放 / 收拢」（默认 true） | 全部 |
| `tableDragToSpread` | 展牌模式下拖动最顶那张牌是否跟手摊开 / 收拢（默认 true） | 展牌 |
| `onDirectionChanged` | 收拢态往另一侧拖时回调并给出建议方向，回填给 `direction` 即生效。展牌：往右拖 → `leftToRight`、往左拖 → `rightToLeft`（一次拖动只定一次）；开扇：收拢态下把顶牌往顺时针带 → `leftToRight`、逆时针 → `rightToLeft`（顶牌跟着手指走），**每穿过一次收拢角就换一次向**，往复拖动可以来回翻 | 展牌 / 开扇 |
| `onFanAngleChanged` | 拖动最顶的牌调整角度时回调（角度钳在 `kMinFanAngle` – 当前模式的上限：S 扇 540°、双手开扇 220°、开扇 360°）；把值回填给 `fanAngle` 即可。牌堆未展开时会同时播放展开动画 | 开扇 / 双手开扇 / S 扇（S 扇的顶牌在牌带末端，灵敏度是开扇的两倍：它转 1°、开扇角变 4°） |

阴影刻意做得轻：52 张牌高度重叠时投影会层层累积，层次主要靠描边交代。

## ⚡ 性能

52 张牌 × 60fps 很容易掉帧，所以绘制做了四层优化：

- **精灵图预合成**：把「牌面 / 牌背 + 圆角裁剪 + 阴影模糊 + 描边」先离屏合成成一张位图，
  动画每帧只对每张牌做一次 `drawImageRect`。所有牌共用同一批源图，所以缓存条目数
  等于「不同源图的张数」，而不是牌的数量。
- **几何只在 build 阶段算**：牌尺寸、包围盒拟合、每张牌的目标位置 / 角度在
  `src/card_layout.dart` 中完成，`paint` 阶段只做变换与贴图。
- **动画不触发 rebuild**：进度由 `Animation<double>` 直接驱动 painter 重绘
  （`super.repaint: animation`），不重建 widget 树；画笔对象复用，避免每帧分配
  几十个 `Paint`。
- **贴图抗锯齿**：所有 `drawImageRect` 均使用 `FilterQuality.medium`
  （mipmap + 双线性），精灵图路径与精灵就绪前的逐帧回退路径（大图缩小）都覆盖。
  开扇的旋转牌、分数尺寸缩放因此都有平滑边缘，不会出现阶梯状锯齿。
- **完全重合的牌只贴一次**：收拢态整叠牌（以及逐张错峰还没轮到的那些牌）变换与
  图层完全相同，重复画只是重复同样的像素，因此直接跳过——52 张开扇的贴图次数在
  进度 0 时从 52 次降到 2 次、进度 0.1 时 14 次、进度 0.3 时 44 次（牌散开后
  自然回到 52 次）。牌背 / 牌面交叉淡入淡出进行中不跳过：那两层是半透明叠上去的，
  少画一层会改变混合结果。

画面尺寸变化（窗口缩放、滑块调整牌数）时精灵图会按新尺寸重新合成一次，
合成期间沿用逐帧绘制路径，因此不会出现闪烁或空白。

## 📚 API 参考

### 🧩 `CardFanSpread`

| 属性                   | 类型                          | 默认值                          | 说明                                                                                   |
|----------------------------|-------------------------------|--------------------------------|---------------------------------------------------------------------------------------------------|
| `cardBack`                 | `ImageProvider?`              | `null`                          | 牌背图片。不传或图片未解码完成时，每张牌画成白底空白牌（`kCardBlankColor`）。            |
| `cardFaces`                | `List<ImageProvider>?`        | `null`                          | 牌面图片列表（通常 52 张，不足循环取用）。为空或 `showFace` 为 false 时全部显示牌背。   |
| `mode`                     | `FanSpreadMode`               | `FanSpreadMode.fan`           | 展开模式（四类布局）。                                                                  |
| `direction`                | `SpreadDirection`             | `SpreadDirection.leftToRight` | 展开的左右方向，四种模式通用（展牌 = 叠压顺序；开扇 = 从哪端长出；S 扇 = 是否水平镜像；双手开扇 = 哪只手先动、哪半叠在上）。 |
| `controller`               | `CardFanSpreadController?`    | `null`                          | 可选的外部控制器；不传时组件自行驱动动画。                                                |
| `showFace`                 | `bool`                        | `false`                         | true 显示牌面，false 显示牌背。                                                          |
| `cardCount`                | `int`                         | `52`                            | 参与展开的牌数（≥ 2）。                                                                 |
| `fanAngle`                 | `double`                      | `220`                           | 开扇 / S 扇 / 双手开扇的角度范围（角度制，0 为完全收拢）。上限按模式不同：开扇 0–[`kMaxFanAngle`]=360，S 扇 0–[`kMaxSFanAngle`]=540（脊线切向的总摆幅，能卷过一整圈），双手开扇下指**每一边**的摆幅、上限 [`kMaxTwoHandFanAngle`]=220（超出部分被布局钳掉）。      |
| `fanTierRatio`              | `double`                      | `0`                             | 双层错落（大扇）：外层相对内层向外推出的距离 / 牌高（0–[`kMaxFanTierRatio`]=0.65；0 = 单层扇）。仅开扇，S 扇 / 双手开扇忽略该参数。 |
| `fanPivotX`                 | `double`                      | `0.5`                           | 枢轴（开扇的「圆心」）沿牌宽方向的位置（0–1：0 = 左边缘，0.5 = 牌边中心，1 = 右边缘）。所有牌绕同一个相对位置旋转，挪到一侧即得偏轴扇形。仅开扇 / 双手开扇，S 扇忽略该参数。 |
| `fanPivotLift`              | `double`                      | `-0.06`                         | 枢轴相对牌底边的沉深 / 牌高（[`kMinFanPivotLift`]–[`kMaxFanPivotLift`] = -0.5–1.0：0 = 底边，正值沉到牌边下方，负值抬到牌面内；默认 -0.06 即拇指捏住扇骨的位置）。仅开扇 / 双手开扇，S 扇忽略该参数。 |
| `tableStepRatio`           | `double`                      | `0.09`                          | 相邻牌错位距离 / 牌宽（越小重叠越深）。仅展牌。                                           |
| `tableArcLift`             | `double`                      | `-0.6`                          | 两端相对中间的翘起幅度 / 牌高，正值两端上翘，负值两端下翘。仅展牌。                       |
| `shadowColor`              | `Color`                       | `Color(0x24000000)`            | 牌与牌之间的投影颜色（默认 14% 黑）；传 `Colors.transparent` 关闭。                       |
| `spriteMemoryBudget`       | `int`                         | [`kSpriteMemoryBudget`] = 64MB | 预合成精灵图的显存预算：估算超过预算时自动按比例下调合成倍率（清晰度换内存），避免被系统因内存压力杀掉。牌面不重复且张数多时可调大，内存紧张的平台（如 Web）可调小。 |
| `duration`                 | `Duration`                    | `Duration(milliseconds: 1800)` | 完整展开动画时长。                                                                      |
| `curve`                    | `Curve`                       | `Curves.easeOutCubic`          | 整体缓动曲线。                                                                          |
| `stagger`                  | `double`                      | `0.55`                          | 逐张错峰系数（0–2），0 为所有牌同时运动。                                                 |
| `autoPlay`                 | `bool`                        | `true`                          | 挂载后是否自动播放展开动画。                                                             |
| `doubleTapToToggle`         | `bool`                        | `true`                          | 双击画布是否切换「播放 / 收拢」（已展开 → 收拢，否则 → 展开）。传 `false` 关掉内置切换。 |
| `tableDragToSpread`         | `bool`                        | `true`                          | 展牌模式下拖动最顶那张牌是否跟手摊开 / 收拢（松手停在当前进度，不继续播放）。仅展牌模式。 |
| `onDirectionChanged`       | `ValueChanged<SpreadDirection>?` | `null`                   | 收拢态往另一侧拖时给出建议方向（回填给 `direction` 生效）：展牌往右拖 → `leftToRight`、往左拖 → `rightToLeft`（一次拖动只定一次）；开扇在收拢态下把顶牌往顺时针带 → `leftToRight`、逆时针 → `rightToLeft`（顶牌跟着手指走），每穿过一次收拢角就换一次向，往复拖动可来回翻。S 扇 / 双手开扇不参与。 |
| `onDoubleTap`               | `VoidCallback?`               | `null`                          | 双击画布时触发（在播放 / 收拢切换之后），与 `doubleTapToToggle` 无关。                   |
| `onFanAngleChanged`         | `ValueChanged<double>?`       | `null`                          | 拖动最顶的牌调整角度时回调（受控组件模式，把值回填给 `fanAngle`）。牌堆未展开（进度 < 1）时拖动会一并播放展开动画；正在收拢时拖动则顺势转为展开。仅四种扇模式（S 扇的顶牌在牌带末端，灵敏度是开扇的两倍：它转 1°、开扇角变 4°），触摸需落在最顶的牌上。 |

### 🎮 `CardFanSpreadController`

| 成员          | 类型      | 说明                                                       |
|--------------|-----------|----------------------------------------------------------|
| `play()`     | 方法      | 展开；已是完全展开态则从头重播。                           |
| `replay()`   | 方法      | 无论当前进度如何，都从收拢状态重新展开。                   |
| `close()`    | 方法      | 收拢（反向播放到 0）。                                     |
| `toggle()`   | 方法      | 已展开则收拢，否则展开。                                   |
| `reset()`    | 方法      | 立刻回到收拢状态。                                         |
| `progress`   | `double`  | 当前展开进度，0 = 收拢，1 = 完全展开（读取最近绑定的组件）。 |
| `isAnimating`| `bool`    | 是否正在播放动画。                                         |
| `isOpened`   | `bool`    | 是否已完全展开。                                           |

### 🔀 枚举

| 值               | 枚举              | 说明                                                                                                       |
|-------------------|-------------------|------------------------------------------------------------------------------------------------------------|
| `tableSpread`     | `FanSpreadMode`   | 展牌摊开（桌面弧形长带）。                                                                                 |
| `fan`             | `FanSpreadMode`   | 开扇：所有牌钉在同一个圆心上，只靠朝向角散开成圆扇（`direction` 决定从哪端长出）。                         |
| `sFan`            | `FanSpreadMode`   | S 扇：牌柄沿 S 形脊线排开，牌带反弯成 S 形（Cardistry 的 S Fan）。                                         |
| `twoHandFan`      | `FanSpreadMode`   | 双手开扇：左右手各捏半叠牌，一半朝左扇开、一半朝右扇开，两扇各绕自己的手握点旋转。                         |
| `leftToRight`     | `SpreadDirection` | 展牌：右半部分的牌压在上层；开扇：从左往右；S 扇；双手开扇：左手先动、右半叠在上。                         |
| `rightToLeft`     | `SpreadDirection` | 展牌：左半部分的牌压在上层；开扇：从右往左（反开扇）；S 扇：水平镜像的 S；双手开扇：右手先动、左半叠在上。 |

## ℹ️ 其他信息

- **仓库地址**: [github.com/runoob-coder/card-fan-spread-widget](https://github.com/runoob-coder/card-fan-spread-widget)
- **问题反馈**: [github.com/runoob-coder/card-fan-spread-widget/issues](https://github.com/runoob-coder/card-fan-spread-widget/issues)
- **示例工程**: `example/` 目录提供完整交互演示，可实时调节全部参数：四种模式切换、播放 / 重播 / 收拢、牌面与牌背
  切换，以及开扇角度 / 双层错落 / 枢轴位置 / 枢轴沉深 / 叠加密度 / 弧度 / 牌数 /
  时长 / 错峰滑块。
- **欢迎贡献**: 欢迎提交 Pull Request 与 Issue！
- **图片来源**: `example/` 演示中的牌背图片来源于
  [bicyclecards.com](https://bicyclecards.com/)。"Bicycle" 及 Bicycle 牌背设计为
  美国扑克公司（The United States Playing Card Company, USPCC）所有的商标，
  此处仅用于演示。本包自身不携带任何素材——牌面 / 牌背始终由调用方提供。

## 💛 支持

如果 `card_fan_spread` 对你有帮助，欢迎点个 Star 支持：
这只需要几秒钟，就能帮助更多 Flutter 开发者发现这个库。

- ⭐ [Star on GitHub](https://github.com/runoob-coder/card-fan-spread-widget)

## [☕️ 请我喝奶茶](https://www.noob-coder.com/buy-me-a-coffee)

<table>
<thead>
<tr>
    <th style="text-align:center;">赞赏码 WeChat</th>
    <th style="text-align:center;">支付宝 Alipay</th>
</tr>
</thead>
<tbody>
<tr>
    <td width="50%"><img src="https://raw.githubusercontent.com/runoob-coder/runoob-coder/main/public/appreciate.avif" alt="赞赏码WeChat" /></td>
    <td width="50%"><img src="https://raw.githubusercontent.com/runoob-coder/runoob-coder/main/public/alipay.avif" alt="支付宝Alipay" /></td>
  </tr>
</tbody>
</table>

[preview]: https://runoob-coder.github.io/card-fan-spread-widget/
[table-spread-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/table-spread.png
[fan-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/fan.png
[reverse-fan-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/reverse-fan.png
[two-hand-fan-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/two-hand-fan.png
[giant-fan-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/giant-fan.png
[s-fan-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/s-fan.png
[fan-pivot-left-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/fan-pivot-left.png
[fan-pivot-drop-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/fan-pivot-drop.png
[table-spread-face-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/table-spread-face.png
[fan-face-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/fan-face.png
[two-hand-fan-face-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/two-hand-fan-face.png
[s-fan-face-img]: https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/screenshots/s-fan-face.png
