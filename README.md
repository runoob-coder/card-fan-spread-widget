# 🃏 Card Fan Spread

<div align="center">
  <a href="https://runoob-coder.github.io/card-fan-spread-widget/" target="_blank" rel="noopener">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/example/web/icons/playing-cards-fan-dark.svg">
      <img src="https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/example/web/icons/playing-cards-fan.svg" width="200" style="width: 200px;" alt="card_fan_spread">
    </picture>
  </a>
</div>

A Flutter card component that reproduces how a magician spreads a deck: **table
spread** (dealer style), **fan**, **S fan** (cardistry: the packet bends into an
S) and **two-hand fan** (one hand holds each half, each fanning outwards) — all
with a per-card cascading animation. One `direction` flips all four
(`rightToLeft` gives the **reverse fan**); the fan modes also take a **double-tier
offset** for cardistry's **giant fan**, and a **movable pivot**, so the same deck
can fan off-axis or hang from a point below the cards.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/runoob-coder/card-fan-spread-widget)
[![API Reference](https://img.shields.io/badge/API-Reference-0175C2.svg)](https://pub.dev/documentation/card_fan_spread/latest/)
[![Flutter Demo](https://img.shields.io/badge/demo-Flutter-brightgreen.svg)][preview]
[![CI](https://img.shields.io/github/actions/workflow/status/runoob-coder/card-fan-spread-widget/deploy_web.yml?label=CI)](https://github.com/runoob-coder/card-fan-spread-widget/actions/workflows/deploy_web.yml)
[![GitHub stars](https://img.shields.io/github/stars/runoob-coder/card-fan-spread-widget.svg?style=social)](https://github.com/runoob-coder/card-fan-spread-widget)

Language: English | [中文](https://github.com/runoob-coder/card-fan-spread-widget/blob/main/README_CN.md)

| [![Fan][fan-img]][preview] | [![Reverse Fan][reverse-fan-img]][preview] | [![Fan (card faces)][fan-face-img]][preview] | [![Off-axis fan (pivot at the left edge)][fan-pivot-left-img]][preview] |
|---------------------------------------------------------------|--------------------------------------------------|--------------------------------------------------------|------------------------------------------|
| [![Giant fan (fan + double-tier offset)][giant-fan-img]][preview] | [![Hanging fan (pivot below the cards)][fan-pivot-drop-img]][preview] | [![Two-hand fan (card faces)][two-hand-fan-face-img]][preview] | [![Two-hand fan][two-hand-fan-img]][preview] |
| [![Table Spread][table-spread-img]][preview] | [![Table Spread (card faces)][table-spread-face-img]][preview] | [![S fan][s-fan-img]][preview] | [![S fan (card faces)][s-fan-face-img]][preview] |

## ✨ Features

- **Four styles × two directions** — `FanSpreadMode.tableSpread` / `fan` /
  `sFan` / `twoHandFan`, sharing `SpreadDirection.leftToRight` / `rightToLeft`.
- **Two-hand fan** — each hand holds its own half and fans outwards about its own
  grip (it stays two stacks when collapsed); the two fans cross at the top and the
  bottom. `fanAngle` is the sweep of *each* side, capped at `kMaxTwoHandFanAngle`
  = 220°, and past 90° each fan is centred on its own side. No double-tier offset.
- **S fan** — the pinches march along an **S-shaped spine** and the cards radiate
  perpendicular to it; `fanAngle` (0°–540°) is the bend, so it can coil past a
  full turn.
- **Giant fan** — `fanTierRatio` pushes every odd-indexed card outwards into an
  inner / outer double-tier spread. Fan modes only.
- **Movable pivot** — `fanPivotX` / `fanPivotLift` move the centre of rotation
  along (or below) the card edge, for off-axis or hanging fans. Every card still
  rotates about the same relative point. Fan / two-hand fan; the S fan ignores
  them.
- **Cascading animation** — cards leave the stack one after another, and the whole
  sequence can be played in reverse to collapse the deck.
- **Gestures** — double-tap toggles play / collapse; in the table spread, drag the
  top card and the deck follows your finger (the drag direction also picks the
  spread direction); in the fan modes, drag the top card to change `fanAngle`.
- **Images are yours** — one card back (optional) plus optional 52 faces (reused
  cyclically), switchable via `showFace`; with no image — or before it decodes —
  every card is a blank white card, never a black block.
- **Smooth at 60fps** — image + rounded corners + shadow + border are
  pre-composited once into a sprite, so each frame blits 52 cards and nothing
  else; back ↔ face cross-fades and shadows fade with the real overlap instead of
  popping.

## 🚀 Getting started

[Live Demo][preview] — try it out online

Wrap it in bounded constraints, hand it a card back, and you have a spread:

```dart
CardFanSpread(
  mode: FanSpreadMode.fan,
  cardBack: const AssetImage('assets/cards/card_back.png'),
);
```

## 📖 Usage

### 🃏 Basic

```dart
final controller = CardFanSpreadController();

CardFanSpread(
  mode: FanSpreadMode.fan, // or tableSpread / sFan / twoHandFan
  direction: SpreadDirection.leftToRight, // rightToLeft = reverse fan / mirrored S / right hand first
  controller: controller,
  cardBack: const AssetImage('assets/cards/card_back.png'),
  cardFaces: faceAssets.map(AssetImage.new).toList(), // 52 cards
  showFace: true,          // true = faces, false = back
  fanAngle: 220,           // sweep in degrees (0 = collapsed; cap 360 / 540 / 220 by mode)
  fanTierRatio: 0.22,      // double-tier offset (giant fan): 0 = single tier
  fanPivotX: 0.5,          // pivot along the card edge: 0 = left edge, 1 = right edge
  fanPivotLift: -0.06,     // pivot depth / card height (negative = inside the card)
  duration: const Duration(milliseconds: 1800),
  stagger: 0.55,           // how much each card trails the previous one
);
```

Omit `controller` and the widget drives its own animation (with `autoPlay`
deciding whether it spreads on mount).

### 🎮 Controlling the animation

`CardFanSpreadController` drives the open/close animation:

```dart
controller.play();   // spread (replays if already fully open)
controller.replay(); // always spread from the collapsed state
controller.close();  // collapse
controller.toggle(); // open / close
controller.reset();  // jump back to collapsed instantly
controller.seekTo(0.5); // jump the progress to a value and stop the animation
```

Read the state with `controller.progress` (0 = collapsed, 1 = fully spread),
`controller.isAnimating` and `controller.isOpened`. One controller can be bound to
several `CardFanSpread` widgets at once (e.g. a thumbnail + the main view):
commands reach all of them, the getters read the most recently bound one.

### 👆 Gestures

- **Double-tap** the canvas to toggle play / collapse (`doubleTapToToggle`, on by
  default). With a controller bound it drives every widget bound to that
  controller; switch it off and `onDoubleTap` still fires.
- **Table spread drag** — drag the top card and the deck follows your finger
  (`tableDragToSpread`): the finger travel is projected onto the "collapsed →
  final" axis and mapped back onto the overall progress. **Letting go leaves the
  deck where it is** — it does not finish the animation on its own.
- **A collapsed drag picks the direction** — drag right (table spread) or
  clockwise (fan) → `leftToRight`, the other way → `rightToLeft`; a fan pushed
  past the collapsed angle flips as well, so it is never stuck at 0°. The widget
  *suggests* the direction through `onDirectionChanged`; feed it back into
  `direction` and your state wins. The S fan and the two-hand fan opt out.
- **Fan angle drag** — an open fan's top card drags the angle instead
  (`onFanAngleChanged`); feed the value back into `fanAngle`.

### 🖼️ Card images

Only `cardBack` is optional (though you will normally pass one). To show faces,
pass `cardFaces` (52 images, or any number — reused cyclically) and set
`showFace: true`; switching it cross-fades back ↔ face over 280ms, so the picture
never jumps in brightness. With no image at all — `cardBack` omitted, still
decoding, or failed to decode — every card is drawn as a **blank white card**
(`kCardBlankColor`): a missing asset gives you a white deck, not a black one.

### 📐 Layout

The component needs **bounded constraints** — wrap it in `SizedBox` /
`Expanded` / `AspectRatio`, or place it in an ordinary box layout. Inside a parent
that offers unbounded width (e.g. a `Row`) it falls back to a built-in 400×600
canvas instead of crashing.

## 📚 [API reference](https://pub.dev/documentation/card_fan_spread/latest/)

### 🧩 [`CardFanSpread`](https://pub.dev/documentation/card_fan_spread/latest/card_fan_spread/CardFanSpread-class.html)

| Property | Type | Default | Modes | Description |
| --- | --- | --- | --- | --- |
| `cardBack` | `ImageProvider?` | `null` | all | Card back. Omitted (or still decoding) → every card is drawn as a blank white card (`kCardBlankColor`). |
| `cardFaces` | `List<ImageProvider>?` | `null` | all | Face images (typically 52, reused cyclically). Empty or `showFace: false` → all cards show the back. |
| `mode` | `FanSpreadMode` | `FanSpreadMode.fan` | — | Spreading style (four layouts). |
| `direction` | `SpreadDirection` | `SpreadDirection.leftToRight` | all | Table spread → stacking order (right half on top); fan → which end it grows from (`rightToLeft` = reverse fan); S fan → the mirrored S; two-hand fan → which hand moves first and which half ends up on top. |
| `controller` | `CardFanSpreadController?` | `null` | all | External controller. Without one, the widget drives its own animation. |
| `showFace` | `bool` | `false` | all | `true` shows card faces, `false` shows the back. |
| `cardCount` | `int` | `52` | all | Cards taking part in the spread (≥ 2). |
| `fanAngle` | `double` | `220` | fan / S fan / two-hand | Sweep in degrees; `0` = fully collapsed (every card's target angle is 0, so it ends up as one stacked deck). Cap: `kMaxFanAngle` 360 (fan — beyond a full turn it just wraps onto itself), `kMaxSFanAngle` 540 (S fan: the bend of the spine, which can coil past a full turn), `kMaxTwoHandFanAngle` 220 per side (two-hand: at 0° the result is two stacks, one per hand). |
| `fanTierRatio` | `double` | `0` | fan | Double-tier offset (giant fan): how far the outer tier is pushed along the card's long axis / card height, 0–`kMaxFanTierRatio` (0.65); `0` = single tier. |
| `fanPivotX` | `double` | `0.5` | fan / two-hand | Pivot (centre of rotation) along the card width, 0–1 (0 = left edge, 0.5 = middle, 1 = right edge); sliding it to one side gives an off-axis fan. |
| `fanPivotLift` | `double` | `-0.06` | fan / two-hand | Pivot depth relative to the bottom edge / card height, `kMinFanPivotLift`–`kMaxFanPivotLift` (−0.5–1.0): 0 = on the edge, positive sinks below it (cards hang from the pivot), negative lifts it into the card (the default is where a thumb pinches the fan). |
| `tableStepRatio` | `double` | `0.09` | table | Offset between neighbours / card width (smaller = deeper overlap). |
| `tableArcLift` | `double` | `-0.6` | table | How much the ends lift relative to the middle / card height. Positive lifts the ends, negative dips them. |
| `shadowColor` | `Color` | `Color(0x24000000)` | all | Drop shadow between cards (~14% black). `Colors.transparent` disables it. |
| `spriteMemoryBudget` | `int` | `kSpriteMemoryBudget` = 64 MB | all | Memory budget for the pre-composited sprites; past it the compositing ratio is scaled down (sharpness for memory). Raise it for many distinct faces, lower it on memory-tight targets such as the web. |
| `duration` | `Duration` | `Duration(milliseconds: 1800)` | all | Duration of a full spread. |
| `curve` | `Curve` | `Curves.easeOutCubic` | all | Overall easing curve. |
| `stagger` | `double` | `0.55` | all | Per-card delay factor (0–2). `0` = all cards move together. |
| `autoPlay` | `bool` | `true` | all | Whether the spread plays automatically on mount. |
| `doubleTapToToggle` | `bool` | `true` | all | Whether double-tapping the canvas toggles play / collapse. |
| `tableDragToSpread` | `bool` | `true` | table | Whether dragging the top card opens / closes the spread under your finger. |
| `onDirectionChanged` | `ValueChanged<SpreadDirection>?` | `null` | table / fan | Suggests a direction when a collapsed spread is dragged the other way (feed it back into `direction`): right / clockwise → `leftToRight`, the other way → `rightToLeft`. One flip per crossing of the collapsed position; the S fan / two-hand fan never infer it. |
| `onDoubleTap` | `VoidCallback?` | `null` | all | Called on double-tap, whether or not `doubleTapToToggle` is on. |
| `onFanAngleChanged` | `ValueChanged<double>?` | `null` | fan / two-hand / S | Called when the top card is dragged to change the angle (clamped to `kMinFanAngle` … the mode's cap); feed it back into `fanAngle`. If the deck is not spread yet, the drag plays the spread too. The S fan's top card sits at the end of the packet, so it is twice as sensitive (1° of card = 4° of angle). The touch must land on the top card. |

Shadows are deliberately light: with 52 heavily overlapping cards they would
stack up into a dark frame, so the separation is carried mostly by the card
borders.

### 🎮 [`CardFanSpreadController`](https://pub.dev/documentation/card_fan_spread/latest/card_fan_spread/CardFanSpreadController-class.html)

| Member | Type | Description |
| --- | --- | --- |
| `play()` | method | Spread; replays from the start if already fully open. |
| `replay()` | method | Always spread from the collapsed state. |
| `close()` | method | Collapse (reverse the animation to 0). |
| `toggle()` | method | Open if collapsed, collapse if open. |
| `reset()` | method | Jump back to the collapsed state instantly. |
| `seekTo(value)` | method | Jump the progress to a value and stop the animation. |
| `progress` | `double` | Current progress, 0 = collapsed, 1 = fully spread (most recently bound widget). |
| `isAnimating` | `bool` | Whether an animation is playing. |
| `isOpened` | `bool` | Whether the deck is fully spread. |

### 🔀 [Enums](https://pub.dev/documentation/card_fan_spread/latest/card_fan_spread/FanSpreadMode.html)

| Value | Enum | Description |
| --- | --- | --- |
| `tableSpread` | `FanSpreadMode` | Dealer-style spread into an arc. |
| `fan` | `FanSpreadMode` | Every card is pinned to one pivot and spreads by rotation alone. |
| `sFan` | `FanSpreadMode` | The pinches march along an S-shaped spine and the packet bends into a reversed curve. |
| `twoHandFan` | `FanSpreadMode` | One hand holds each half — the left half fans left, the right half fans right, each about its own hand. |
| `leftToRight` | `SpreadDirection` | Table spread: right half on top. Fan: opens from the left. S fan: the default S. Two-hand fan: left hand first, right half on top. |
| `rightToLeft` | `SpreadDirection` | Table spread: left half on top. Fan: opens from the right (the reverse fan). S fan: the mirrored S. Two-hand fan: right hand first, left half on top. |

## ⚡ Performance

52 cards at 60fps is easy to drop frames on, so rendering is optimized:

- **Pre-composited sprites**: card image + rounded corners + shadow blur + border
  are rendered once off-screen into a single bitmap, so each frame does one
  `drawImageRect` per card. All cards share the same sources, so the cache holds
  one entry per *distinct* source image, not per card.
- **Geometry computed at build time**: card size, bounding-box fit and every
  card's target position / angle are resolved once in `src/card_layout.dart`; the
  paint phase only applies transforms and blits.
- **No rebuilds while animating**: progress is read live from the
  `Animation<double>` driving the painter (`super.repaint: animation`), and
  `Paint` objects are reused instead of being allocated per frame.
- **Coincident cards are blitted once**: while the deck is stacked (and for the
  cards the stagger has not released yet) the duplicates share one transform and
  are skipped — a collapsed 52-card fan drops from 52 blits per frame to 2. Not
  skipped during the back/face cross-fade, where the two layers blend.
- **Anti-aliased blitting**: every `drawImageRect` uses `FilterQuality.medium`
  (mipmap + bilinear), so rotated and fractionally scaled cards keep smooth edges
  instead of stair-stepping.

When the available size changes (window resize, card-count slider) the sprites are
re-composited at the new size, on a geometric ladder of size rungs rather than per
pixel: a full fan-angle drag re-composites ~3–5 times instead of ~50, and cards
are always over-sampled, never blurry. Sources that are no longer used are evicted,
and `spriteMemoryBudget` keeps the peak in check. Until a re-composite is ready the
per-frame path is used, so there is no flicker or blank frame.

## ℹ️ Additional information

- **Repository**: [github.com/runoob-coder/card-fan-spread-widget](https://github.com/runoob-coder/card-fan-spread-widget)
- **Issue tracker**: [github.com/runoob-coder/card-fan-spread-widget/issues](https://github.com/runoob-coder/card-fan-spread-widget/issues)
- **Example app**: the `example/` directory is a full interactive demo that lets
  you tweak every property in real time — mode, play / replay / collapse, face
  and back, plus sliders for fan angle, tier offset, pivot position and depth,
  overlap density, arc lift, card count, duration and stagger.
- **Contributions**: Pull requests and issues are welcome!
- **Image credits**: the card back images used in the `example/` demo come from
  [bicyclecards.com](https://bicyclecards.com/). "Bicycle" and the Bicycle card
  back designs are trademarks of The United States Playing Card Company (USPCC)
  and are used here for demonstration purposes only. The package itself ships no
  assets — card images are always supplied by the caller.

## 📄 License

This package is **dual-licensed**:

- **MIT License** (see [`LICENSE`](LICENSE)) — covers all uses **except** magic-related commercial activities.
- **Commercial License for magic-related activities** (see
  [`LICENSE-COMMERCIAL`](LICENSE-COMMERCIAL)) — any commercial activity involving
  magic, conjuring, illusion, cardistry or other magic-related commercial endeavors
  (including but not limited to the sale, promotion, or monetization of magic
  performances, magic products, or magic services) requires prior written
  permission from the copyright holder.

For everything outside the magic commercial scope, the MIT License applies.

## 💛 Support

If `card_fan_spread` helps you build better UIs, please consider supporting it.

- ⭐ [Star on GitHub](https://github.com/runoob-coder/card-fan-spread-widget)

## ☕️ [Buy Me a Coffee](https://www.noob-coder.com/buy-me-a-coffee)

|                                                                                   Buy Me a Coffee                                                                                   |                                                                                    Donate with PayPal                                                                                     |
|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
| <a href="https://ko-fi.com/noob_coder" target="_blank"><img src="https://github.com/runoob-coder/runoob-coder/raw/main/public/kofi6.webp" alt="Buy Me a Coffee at ko-fi.com" /></a> | <a href="https://paypal.me/runoobcoder" target="_blank"><img src="https://github.com/runoob-coder/runoob-coder/raw/main/public/paypal-donate-button.avif" alt="Donate with PayPal" /></a> |

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
