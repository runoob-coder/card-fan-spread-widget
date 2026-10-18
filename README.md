<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information on how to write a package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# 🃏 Card Fan Spread

<div align="center">
  <a href="https://runoob-coder.github.io/card-fan-spread-widget/" target="_blank" rel="noopener">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/example/web/icons/playing-cards-fan-dark.svg">
      <img src="https://raw.githubusercontent.com/runoob-coder/card-fan-spread-widget/main/example/web/icons/playing-cards-fan.svg" width="200" style="width: 200px;" alt="card_fan_spread">
    </picture>
  </a>
</div>

A Flutter card component that reproduces how a magician spreads a deck:
**table spread** (dealer style), **fan**, **S fan** (a cardistry fan whose
packet bends into an S) and **two-hand fan** (one hand holds each half, each
fanning outwards) — four layouts whose left/right direction is a single
`direction` (`rightToLeft` turns the fan into the **reverse fan**), all with a
per-card cascading animation. The fan modes also support a tunable
**double-tier offset** — turn it on and you get cardistry's **giant fan**,
far bigger than an ordinary round fan — plus a movable **pivot**: the fan's
centre of rotation no longer has to sit at the middle of the card edge, so the
same deck can fan off-axis or hang from a point below the cards.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/runoob-coder/card-fan-spread-widget)
[![Flutter Demo](https://img.shields.io/badge/demo-Flutter-brightgreen.svg)][preview]
[![CI](https://img.shields.io/github/actions/workflow/status/runoob-coder/card-fan-spread-widget/deploy_web.yml?label=CI)](https://github.com/runoob-coder/card-fan-spread-widget/actions/workflows/deploy_web.yml)
[![GitHub stars](https://img.shields.io/github/stars/runoob-coder/card-fan-spread-widget.svg?style=social)](https://github.com/runoob-coder/card-fan-spread-widget)

Language: English | [中文](https://github.com/runoob-coder/card-fan-spread-widget/blob/main/README_CN.md)

| [![Table Spread][table-spread-img]][preview] | [![Fan][fan-img]][preview] | [![Reverse Fan][reverse-fan-img]][preview] | [![Two-hand fan][two-hand-fan-img]][preview] | [![Giant fan (fan + double-tier offset)][giant-fan-img]][preview] | [![S fan][s-fan-img]][preview] | [![Off-axis fan (pivot at the left edge)][fan-pivot-left-img]][preview] | [![Hanging fan (pivot below the cards)][fan-pivot-drop-img]][preview] |
|---------------------------------------------------------------|--------------------------------------------------|--------------------------------------------------------|------------------------------------------|--------------------------------------------------|------------------------------------------|------------------------------------------|------------------------------------------|
| [![Table Spread (card faces)][table-spread-face-img]][preview] | [![Fan (card faces)][fan-face-img]][preview] | | [![Two-hand fan (card faces)][two-hand-fan-face-img]][preview] | | [![S fan (card faces)][s-fan-face-img]][preview] | | |

## ✨ Features

- **Four spreading styles × two directions** — `FanSpreadMode`: `tableSpread`
  (dealer style), `fan`, `sFan` and `twoHandFan`, switchable at any time; the
  left/right direction is a single `direction` (`SpreadDirection.leftToRight` /
  `rightToLeft`) shared by all four.
- **Two-hand fan** — one hand holds each half and each half fans outwards about
  **its own hand**, staying a separate stack even when collapsed; the two fans
  cross at the top and the bottom. Same parameters as the fan modes (`fanAngle`
  is the sweep of *each* side, capped at `kMaxTwoHandFanAngle` = 220°), and past
  90° each fan stays centred on its own side and splits the space evenly. No
  double-tier offset.
- **S fan** — cardistry's *S Fan*: instead of pinning every card to one pivot,
  the pinches march along an **S-shaped spine** and the cards radiate
  perpendicular to it, spreading the packet into an upright S-shaped band. Its
  bend is tuned with `fanAngle` (0°–540°: it can coil past a full turn), and
  dragging the top card opens / closes it at twice the sensitivity.
- **Double-tier offset (giant fan)** — one extra parameter (`fanTierRatio`) on
  the fan modes pushes every odd-indexed card outwards, turning the fan into an
  inner / outer double-tier spread: cardistry's **giant fan (Giant Fan / Giant
  Pressure Fan)**, two Faro-interleaved packets fanned out. (The S fan and the
  two-hand fan ignore it.)
- **Movable pivot** — `fanPivotX` / `fanPivotLift` move the fan's centre of
  rotation: slide it along the card edge for an off-axis fan, or sink it below
  the edge so the cards hang from the pivot. Every card still rotates about the
  same relative point. Fan / two-hand fan; the S fan ignores them.
- **Cascading animation** — cards leave the stack one after another, and the
  whole sequence can be played in reverse to collapse the deck back.
- **Adjustable geometry** — fan sweep `fanAngle` (0°–360° for the fan modes,
  0°–540° for the S fan, 0°–220° per side for the two-hand fan), double-tier
  offset `fanTierRatio`, pivot `fanPivotX` / `fanPivotLift`, plus table spread
  density `tableStepRatio` and arc `tableArcLift`.
- **Images are supplied by you** — one card back (optional) + optional 52 faces
  (reused cyclically), switchable at any time via `showFace`. With no image (or
  while it is still decoding / failed to decode) every card is drawn as a blank
  white card instead of a black block.
- **Smooth transitions everywhere** — cross-fade when switching back/face, and
  shadows/borders that fade in and out with the actual overlap instead of
  popping in and out.
- **Sprite pre-compositing** — card image + rounded corners + shadow blur +
  border are rendered once off-screen; 52 cards stay smooth at 60fps.
- **Double-tap to open / close** — double-tapping the canvas toggles the spread
  (`doubleTapToToggle`, on by default); no button wiring needed.
- **Drag to control** — in the table spread, drag the top card and the deck
  follows your finger (`tableDragToSpread`, on by default), and the drag
  direction picks the spread direction (`onDirectionChanged`); in the
  fan modes, drag the top card to change the angle (`onFanAngleChanged`).

## 🚀 Getting started

[Live Demo][preview] — try it out online

Images: **one card back (`cardBack`, optional)**. Optionally pass 52 card faces
(`cardFaces`; fewer images are reused cyclically) to enable face/back switching.
Without a back image — or before it finishes decoding (missing asset, still
loading) — every card is drawn as a blank white card.

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
  fanAngle: 220,           // fan sweep in degrees (0 = fully collapsed; up to 360,
                           // or 540 for the S fan, whose bend coils past a full turn)
  fanTierRatio: 0.22,      // double-tier offset (giant fan): 0 = single tier
  fanPivotX: 0.5,          // pivot along the card edge: 0 = left edge, 1 = right edge
  fanPivotLift: -0.06,     // pivot depth below the bottom edge / card height (negative = inside the card)
  duration: const Duration(milliseconds: 1800),
  stagger: 0.55,           // how much each card trails the previous one
);

controller.play();   // spread (replays if already fully open)
controller.close();  // collapse
controller.toggle(); // open / close
```

Passing no `controller` is fine too — the widget then drives its own animation
(and `autoPlay` decides whether it spreads on mount).

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

Read the current state with `controller.progress` (0 = collapsed, 1 = fully
spread), `controller.isAnimating` and `controller.isOpened`.

The same controller can be bound to multiple `CardFanSpread` widgets at once
(e.g. a thumbnail preview + the main view): commands apply to all of them,
while the getters read the most recently bound one.

### 👆 Double-tapping the canvas

By default a double-tap on the canvas toggles play / collapse: it collapses when
the deck is fully spread, otherwise it spreads (and turns a collapse back into a
spread). With a `controller` bound, the double-tap drives **every** widget bound
to that controller. Pass `doubleTapToToggle: false` to switch the built-in
behaviour off — `onDoubleTap` still fires, so you can hook your own logic.

```dart
CardFanSpread(
  controller: controller,
  doubleTapToToggle: true,      // this is the default
  onDoubleTap: () => debugPrint('double tapped'),
);
```

### 🖐️ Dragging the top card (table spread)

In the table spread you can drag the top card and the deck follows your finger
(`tableDragToSpread`, on by default): the finger movement is projected onto the
"collapsed position → final position" axis, and that fraction of the whole travel
is how far the top card has gone — which is then mapped back onto the overall
progress (stagger and easing included). **Letting go leaves the deck exactly
where it is** — it does not finish the animation on its own. Pass
`tableDragToSpread: false` to switch it off.

```dart
// From code: jump the progress to a value and stop any running animation.
controller.seekTo(0.5); // half spread, held there
```

### 🧭 A collapsed drag picks the direction

**Table spread** — while it is collapsed, the drag direction decides which way
it fans out, and the top card follows your finger: drag right →
**left-to-right** (the top card becomes the rightmost one and the ribbon opens
to the right), drag left → **right-to-left**. The deck keeps opening as your
finger keeps moving that way.

**Fan** — the same rule whenever the fan *looks* collapsed: drag the top card
clockwise → **left-to-right**, anticlockwise → **right-to-left**, and the same
gesture then keeps opening the fan on the other side. "Looks collapsed" covers
both `fanAngle = 0` and a deck closed with the controller (progress 0, while
`fanAngle` may still read 220°). Dragging an open fan closed and pushing on in
the same direction flips it too, so it is never stuck at 0°; merely closing it
to 0° and stopping there does not flip.

The widget *suggests* the direction — you feed it back:

```dart
CardFanSpread(
  direction: _direction, // your state
  onDirectionChanged: (d) => setState(() => _direction = d),
);
```

Wire the callback and your state wins; **without it the widget flips its own
effective direction**, otherwise a collapsed fan dragged the other way would be
pinned at 0° and do nothing at all. The table spread only decides while
collapsed — an already-spread deck just opens / closes under your finger. The fan
decides at the collapsed angle, or when you push past it, and dragging back and
forth flips it every time the top card crosses the collapsed position (the
accumulated rotation resets on each flip, so a still finger never flips
repeatedly). The S fan and the two-hand fan opt out: the S fan's top card sits
at the end of the packet and the two-hand fan already has one fan per hand, so
"the other side" has no clear meaning.

An open fan drags the top card to change `fanAngle` instead (see
`onFanAngleChanged`).

### 🖼️ Card images

Only `cardBack` is optional (though you will normally pass one). To show faces,
pass `cardFaces` (52 images, or any number — they are reused cyclically) and
flip `showFace`:

```dart
CardFanSpread(
  cardBack: const AssetImage('assets/cards/card_back.png'),
  cardFaces: faceAssets.map(AssetImage.new).toList(),
  showFace: true,
);
```

It also works with no image at all: when `cardBack` is omitted (or the image is
still decoding / failed to decode) every card is drawn as a **blank white card**
(`kCardBlankColor`) instead of a black block — a missing asset gives you a white
deck, not a black one.

Switching `showFace` cross-fades back ↔ face over 280ms, so the whole picture
never jumps in brightness.

### 📐 Layout

The component needs **bounded constraints** — wrap it in `SizedBox` /
`Expanded` / `AspectRatio`, or place it in an ordinary box layout. When used
directly inside a parent that offers unbounded width (e.g. a `Row`), it falls
back to a built-in 400×600 canvas instead of crashing.

### 🎛️ Parameters

| Parameter | Description | Applies to |
| --- | --- | --- |
| `fanAngle` | Fan sweep (`0` = fully collapsed: every card's target angle is 0, so the spread ends up as one stacked deck). The cap depends on the mode: 0–360° for the fan modes (`kMaxFanAngle` — beyond a full turn the fan merely wraps back onto itself), 0–540° for the S fan (`kMaxSFanAngle`). For the S fan it is the **bend of the packet**: the spine's tangent turns out by half of it and comes back, and the cards (perpendicular to the spine) swing by the same amount — that bend can coil past a full turn (360° is the canonical S, ~450° is the fullest, and 540° is the limit before the two bows close into an "8"). For the two-hand fan it is the sweep of **each side**, capped at `kMaxTwoHandFanAngle` (220°); at 0° neither fan is open, but each hand still holds its own half, so the spread ends up as **two stacks** rather than one, and from 90° up each fan is centred on its own side (dividing the space evenly above and below) | fan / S fan / two-hand fan |
| `fanTierRatio` | Double-tier offset: how far the outer tier is pushed along the card's long axis / card height (0–0.65, 0 = single-tier fan) | fan (ignored by the S fan / two-hand fan) |
| `fanPivotX` | Pivot (the fan's centre of rotation) along the card's width: 0 = left edge, 0.5 = middle of the edge (default), 1 = right edge. Every card rotates about the same relative point, so sliding it to one side gives an off-axis fan | fan / two-hand fan (ignored by the S fan) |
| `fanPivotLift` | Pivot depth relative to the bottom edge / card height: 0 = exactly on the edge; positive sinks it below the edge (the cards hang from the pivot); negative lifts it into the card (default −0.06, where a thumb pinches the fan). Range −0.5–1.0 | fan / two-hand fan (ignored by the S fan) |
| `direction` | Left/right direction, shared by all four modes: table spread → stacking order (with `leftToRight` the right half is on top); fan → which end the fan grows from (`rightToLeft` is the reverse fan); S fan → the mirrored S; two-hand fan → which hand moves first and which half ends up on top (`leftToRight` = left hand first, right half on top) | all |
| `tableStepRatio` | Offset between neighbours / card width (smaller = deeper overlap) | table spread |
| `tableArcLift` | How much the ends lift relative to the middle / card height. Positive lifts the ends, negative dips them | table spread |
| `stagger` | Per-card delay factor, 0 = all cards move together | all |
| `shadowColor` | Drop shadow between cards, ~14% black by default. Pass `Colors.transparent` to disable | all |
| `spriteMemoryBudget` | Memory budget (bytes) for the pre-composited sprites, `kSpriteMemoryBudget` = 64&nbsp;MB by default. When the estimate exceeds it, the compositing ratio is scaled down (sharpness for memory). Raise it for many distinct faces, lower it on memory-tight targets such as the web | all |
| `curve` | Overall easing curve | all |
| `autoPlay` | Whether the spread plays automatically on mount | all |
| `doubleTapToToggle` | Whether double-tapping the canvas toggles play / collapse (default true) | all |
| `tableDragToSpread` | Whether dragging the top card opens / closes the spread under your finger in the table spread (default true) | table spread |
| `onDirectionChanged` | Suggests a direction when a collapsed spread is dragged the other way; feed it back into `direction`. Table spread: drag right → `leftToRight`, drag left → `rightToLeft`. Fan: dragging the collapsed top card clockwise → `leftToRight`, anticlockwise → `rightToLeft` (the top card follows your finger). One flip per drag; a fan that is already open only changes its angle | table spread / fan |
| `onFanAngleChanged` | Called when the top card is dragged to change the fan angle (clamped to `kMinFanAngle` … the current mode's cap: 540° for the S fan, 220° for the two-hand fan, 360° otherwise); feed the value back into `fanAngle`. If the deck is not spread yet, dragging also plays the spread animation | fan / two-hand fan / S fan (the S fan's top card sits at the end of the packet, so its sensitivity is double: it turns 1° per 4° of fan angle) |

Shadows are deliberately light: with 52 heavily overlapping cards the shadows
would otherwise stack up into a dark frame, so the separation is carried mostly
by the card borders.

## ⚡ Performance

52 cards at 60fps is easy to drop frames on, so rendering is optimized on four
levels:

- **Pre-composited sprites**: card image + rounded corners + shadow blur + border
  are rendered once off-screen into a single bitmap; each frame then only does one
  `drawImageRect` per card. Because all cards share the same source images, the
  cache holds one entry per *distinct* source image, not per card.
- **Geometry computed at build time**: card size, bounding-box fit and every
  card's target position/angle are resolved once in `src/card_layout.dart`; the
  paint phase only applies transforms and blits.
- **No rebuilds while animating**: progress is read live from the
  `Animation<double>` driving the painter (`super.repaint: animation`), so the
  widget tree is never rebuilt; `Paint` objects are reused instead of allocating
  dozens per frame.
- **Coincident cards are blitted once**: while the deck is still stacked (and for
  the cards the stagger has not released yet) every card shares the same
  transform and the same layer, so the duplicates are skipped — a collapsed
  52-card fan goes from 52 blits per frame to 2. (Skipped during the back/face
  cross-fade, where the two layers are stacked semi-transparently.)
- **Anti-aliased blitting**: every `drawImageRect` uses `FilterQuality.medium`
  (mipmap + bilinear) — both for the sprites and for the per-frame fallback path
  that downscales the source image before sprites are ready. Rotated cards (fan
  modes) and fractional-size scaling therefore keep smooth edges instead of
  stair-stepping.

When the available size changes (window resize, card-count slider), sprites are
re-composited at the new size; until they are ready the per-frame path is used,
so there is no flicker or blank frame.

That re-compositing is **rung-based** rather than per-pixel: dragging the fan
angle changes the card size continuously (306px → 614px over a full 0–360°
sweep), and re-compositing every 4px would mean ~50 full rebuilds of the sprite
set per drag — thousands of off-screen renders with 52 distinct faces. Instead
the size snaps **up** the next rung of a geometric ladder when it grows (so
cards are always over-sampled, never blurry) and only drops a rung once the
cards have shrunk by more than 1/1.35: a full drag now re-composites ~3–5 times
instead of ~50. Sources that are no longer used (faces turned off, another card
back, fewer cards) are evicted from the cache instead of staying resident, and
the budget above keeps the peak in check.

## 📚 API reference

### 🧩 `CardFanSpread`

| Property                   | Type                          | Default                        | Description                                                                                                   |
|----------------------------|-------------------------------|--------------------------------|---------------------------------------------------------------------------------------------------------------|
| `cardBack`                 | `ImageProvider?`              | `null`                         | Card back image. When omitted (or while it is still decoding) every card is drawn as a blank white card (`kCardBlankColor`). |
| `cardFaces`                | `List<ImageProvider>?`        | `null`                         | Card face images (typically 52, reused cyclically). When empty or `showFace` is `false`, all cards show the back. |
| `mode`                     | `FanSpreadMode`               | `FanSpreadMode.fan`           | Spreading style (four layouts).                                                                               |
| `direction`                | `SpreadDirection`             | `SpreadDirection.leftToRight` | Left/right direction shared by all four modes: table spread → stacking order; fan → which end it grows from; S fan → mirrored S; two-hand fan → which hand moves first and which half ends up on top. |
| `controller`               | `CardFanSpreadController?`    | `null`                         | Optional external controller. Without one, the widget drives its own animation.                              |
| `showFace`                 | `bool`                        | `false`                        | `true` shows card faces, `false` shows the back.                                                              |
| `cardCount`                | `int`                         | `52`                           | Number of cards taking part in the spread (≥ 2).                                                              |
| `fanAngle`                 | `double`                      | `220`                          | Fan sweep in degrees (`0` = fully collapsed). Capped per mode: 0–[`kMaxFanAngle`] = 360 for the fan modes, 0–[`kMaxSFanAngle`] = 540 for the S fan, whose bend coils past a full turn.                               |
| `fanTierRatio`             | `double`                      | `0`                            | Double-tier offset (giant fan): how far the outer tier is pushed along the card's long axis / card height (0–[`kMaxFanTierRatio`] = 0.65; `0` = single-tier fan). Fan only; ignored by the S fan. |
| `fanPivotX`                | `double`                      | `0.5`                          | Pivot (the fan's centre of rotation) along the card's width, 0–1 (0 = left edge, 0.5 = middle of the edge, 1 = right edge). Every card rotates about the same relative point, so sliding the pivot to one side gives an off-axis fan. Fan only; ignored by the S fan. |
| `fanPivotLift`             | `double`                      | `-0.06`                        | Pivot depth relative to the bottom edge / card height ([`kMinFanPivotLift`]–[`kMaxFanPivotLift`] = −0.5–1.0: 0 = on the edge, positive sinks below it, negative lifts into the card; the default −0.06 is where a thumb pinches the fan). Fan only; ignored by the S fan. |
| `tableStepRatio`           | `double`                      | `0.09`                         | Neighbour offset / card width (smaller = deeper overlap). Table spread only.                                  |
| `tableArcLift`             | `double`                      | `-0.6`                         | How much the ends lift relative to the middle / card height. Positive lifts the ends, negative dips them. Table spread only. |
| `shadowColor`              | `Color`                       | `Color(0x24000000)`            | Drop shadow between cards (~14% black). Pass `Colors.transparent` to disable.                                |
| `spriteMemoryBudget`       | `int`                         | [`kSpriteMemoryBudget`] = 64 MB | Memory budget for the pre-composited sprites. When the estimate exceeds it, the compositing ratio is scaled down (sharpness for memory) so the app is not killed under memory pressure. Raise it when many distinct faces are shown, lower it on memory-tight targets such as the web. |
| `duration`                 | `Duration`                    | `Duration(milliseconds: 1800)` | Duration of a full spread.                                                                                    |
| `curve`                    | `Curve`                       | `Curves.easeOutCubic`          | Overall easing curve.                                                                                         |
| `stagger`                  | `double`                      | `0.55`                         | Per-card delay factor (0–2). 0 = all cards move together.                                                     |
| `autoPlay`                 | `bool`                        | `true`                         | Whether the spread plays automatically on mount.                                                             |
| `doubleTapToToggle`         | `bool`                        | `true`                         | Whether double-tapping the canvas toggles play / collapse (collapses when fully open, otherwise spreads). Pass `false` to turn the built-in toggle off. |
| `tableDragToSpread`         | `bool`                        | `true`                         | Table spread only: dragging the top card opens / closes the spread under your finger (it stays where you let go instead of finishing the animation). |
| `onDirectionChanged`       | `ValueChanged<SpreadDirection>?` | `null`                  | Suggests a direction when a collapsed spread is dragged the other way (feed it back into `direction`). Table spread: drag right → `leftToRight`, drag left → `rightToLeft`. Fan: dragging the collapsed top card clockwise → `leftToRight`, anticlockwise → `rightToLeft`. One flip per drag; the S fan / two-hand fan never infer it. |
| `onDoubleTap`               | `VoidCallback?`               | `null`                         | Called on double-tap (after the play / collapse toggle). Fires regardless of `doubleTapToToggle`.            |
| `onFanAngleChanged`         | `ValueChanged<double>?`       | `null`                         | Called when the top card is dragged to adjust the fan angle (clamped to `kMinFanAngle` … the current mode's cap: 540° for the S fan, 220° for the two-hand fan, 360° otherwise; controlled component: feed the value back into `fanAngle`). If the deck is not fully spread yet, the drag also plays the spread animation (and turns a collapse back into a spread). All four fan modes (the S fan's top card sits at the far end of the packet, so its sensitivity is double: 1° of card rotation is 4° of fan angle); the touch must land on the top card. |

### 🎮 `CardFanSpreadController`

| Member       | Type   | Description                                                                 |
|--------------|--------|-----------------------------------------------------------------------------|
| `play()`     | method | Spread; replays from the start if already fully open.                       |
| `replay()`   | method | Always spread from the collapsed state.                                     |
| `close()`    | method | Collapse (reverse the animation to 0).                                      |
| `toggle()`   | method | Open if collapsed, collapse if open.                                        |
| `reset()`    | method | Jump back to the collapsed state instantly.                                 |
| `progress`   | `double` | Current spread progress, 0 = collapsed, 1 = fully spread (most recently bound widget). |
| `isAnimating`| `bool` | Whether an animation is currently playing.                                  |
| `isOpened`   | `bool` | Whether the deck is fully spread.                                           |

### 🔀 Enums

| Value             | Enum            | Description                              |
|-------------------|-----------------|------------------------------------------|
| `tableSpread`     | `FanSpreadMode` | Dealer-style spread into an arc.         |
| `fan`             | `FanSpreadMode` | Fan: every card is pinned to one pivot and spreads by rotation alone (`direction` picks which end it grows from). |
| `sFan`            | `FanSpreadMode` | S fan: the pinches march along an S-shaped spine and the packet bends into a reversed curve. |
| `twoHandFan`      | `FanSpreadMode` | Two-hand fan: one hand holds each half — the left half fans out to the left, the right half to the right, each about its own hand. |
| `leftToRight`     | `SpreadDirection` | Table spread: right half on top. Fan: opens from the left. S fan: the default S. Two-hand fan: left hand first, right half on top. |
| `rightToLeft`     | `SpreadDirection` | Table spread: left half on top. Fan: opens from the right (the reverse fan). S fan: the horizontally mirrored S. Two-hand fan: right hand first, left half on top. |

## ℹ️ Additional information

- **Repository**: [github.com/runoob-coder/card-fan-spread-widget](https://github.com/runoob-coder/card-fan-spread-widget)
- **Issue tracker**: [github.com/runoob-coder/card-fan-spread-widget/issues](https://github.com/runoob-coder/card-fan-spread-widget/issues)
- **Example app**: See the `example/` directory for a full interactive demo
  that lets you tweak every property in real time: mode switching, play /
  replay / collapse, face and back switching, plus live sliders for fan angle,
  giant tier offset, pivot position, pivot depth, overlap density, arc lift,
  card count, duration and stagger.
- **Contributions**: Pull requests and issues are welcome!
- **Image credits**: The card back images used in the `example/` demo come from
  [bicyclecards.com](https://bicyclecards.com/). "Bicycle" and the Bicycle card
  back designs are trademarks of The United States Playing Card Company (USPCC)
  and are used here for demonstration purposes only. The package itself ships no
  assets — card images are always supplied by the caller.

## 💛 Support

If `card_fan_spread` helps you build better UIs, please consider supporting it.  
It only takes a few seconds and helps other Flutter developers discover the library.

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
