## 1.0.1

- 📝 **Docs**: improved the documentation.

## 1.0.0

- Four spreading styles — table spread, fan, S fan and two-hand fan — sharing a
  single `direction` (`rightToLeft` gives the reverse fan / mirrored S).
- Giant fan: the fan modes accept an optional double-tier offset
  (`fanTierRatio`).
- Movable fan pivot: `fanPivotX` / `fanPivotLift` move the centre of rotation off
  the card edge (off-axis or hanging fans).
- Per-card cascading animation with a cross-fade between card back and faces.
- Gestures: drag the top card to open/close the table spread or change the fan
  angle, double-tap the canvas to toggle play/collapse, and drag a collapsed deck
  the other way to flip the direction.
- `CardFanSpreadController` drives play / replay / close / toggle / reset and can
  be bound to multiple widgets.
- Pre-composited sprites keep 52 cards at 60fps, with a tunable memory budget.
- Card images are supplied by the caller; without a back image every card is
  drawn as a blank white card.
