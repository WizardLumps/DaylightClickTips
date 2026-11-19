# Wiz's ClickTips (DaylightUI Plugin)

A plugin for **DaylightUI** on **WoW: Forever**. Hover a unit frame and its tooltip lists
what each mouse click casts, HealBot-style:

```
Clicks (Shift)
Left: Flash Heal (Rank 3)        307-353  125
Right: Power Word: Shield         absorbs 48  80
Middle: Dispel Magic             out of range
```

- One line per mouse button, for the Shift / Ctrl / Alt you're holding right now. Press or
  release a modifier and the lines change.
- Spell colors: **white** ready, **orange** out of range, **red** no mana or on cooldown,
  **grey** can't be cast right now.
- Right side: the heal or absorb amount (green) and the mana cost (blue).
- Uses your bindings from DaylightUI's own click-casting (Unit Frames > Click-casting). It
  only reads them: nothing is changed, and it's safe in combat.

## Install
1. Install DaylightUI first.
2. Copy the `DaylightClickTips` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
3. Enable **Wiz's ClickTips (DaylightUI Plugin)** on the character screen.

## Options
In `/dui`: the **ClickTips** plugin page, or **Unit Frames > Click-casting > Tooltips**.
Or type:
- `/clicktips` - version and current switches
- `/clicktips tip` - click lines on or off
- `/clicktips amounts` - heal amounts on or off
- `/clicktips cost` - mana cost on or off

Settings are account-wide.

## Notes
- Heal amounts are read from the spell's description, which works on English clients.
  On other languages the amount is left out; everything else works.
- Only DaylightUI's unit frames get the lines (party, raid, party pets, player, target, focus).

## License
MIT (see `LICENSE`). Made by WizardLumps. Not affiliated with DaylightUI; it needs
DaylightUI installed and holds none of its code or art.

## Changelog
- v1.0.1 - Its own icon: a tooltip bubble with a heal cross.
- v1.0.0 - First release: click lines in unit frame tooltips, heal amounts, mana cost,
  options in /dui and /clicktips.
