# Wiz's ClickTips (DaylightUI Plugin)

**Your click-cast spells, right in the tooltip.**

A plugin for **DaylightUI** on **WoW: Forever** (tested with DaylightUI 1.9.5). Hover a party
or raid frame to see the spell each mouse button casts through DaylightUI's click-casting,
HealBot-style. Hold Shift, Ctrl or Alt and the list switches to that modifier's spells
instantly:

![Tooltip with the click lines](docs/screenshots/tooltip.png)

Hold a modifier and the lines switch to that set, here Shift for lower ranks:

![The same tooltip with Shift held](docs/screenshots/tooltip-shift.png)

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

![The ClickTips page in /dui](docs/screenshots/options.png)

Heal amounts and mana cost can be turned off for a shorter tooltip:

![Heal amounts and mana cost off](docs/screenshots/options-switches-off.png)

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
- v1.0.2 - CurseForge project ID in the TOC, and packaging settings (.pkgmeta) for
  CurseForge's automatic releases.
- v1.0.1 - Its own icon: a tooltip bubble with a heal cross.
- v1.0.0 - First release: click lines in unit frame tooltips, heal amounts, mana cost,
  options in /dui and /clicktips.
