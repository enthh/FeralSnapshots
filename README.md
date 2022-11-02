# FeralSnapshots - Alpha

This World of Warcraft AddOn tracks the talents, buffs and damage modifiers applied for Rake, Rip, Thrash and Lunar Inspiration Moonfire. These damage modifiers are then displayed from WeakAuras, Plater and other addons.

Feral Druid is the only class where damage over time abilities "snapshot". The buffs apply for the full duration of the debuff, even after they have expired. Deciding when to replace a weaker snapshot is what makes Feral so much fun to play.

<div align="center">

![logo](https://raw.githubusercontent.com/enthh/FeralSnapshots/main/icon.jpg "FeralSnapshots Logo")

</div>

## Features

* Debuff snapshots on all targets in combat range.
* Current buffed power and power difference if a debuff is refreshed.
* Uses talent, traits and conduits inside in and out of Shadowlands content.
* Efficient. Updates from events rather than every frame, maximizing FPS
* Provides a total and breakdown of damage modifier by buffs.

### Examples

* Weakaura pack of DoTs attached to the Personal Resource Display: [https://wago.io/MvvDUl_o9](https://wago.io/MvvDUl_o9)

![ExamplePack](https://github.com/enthh/FeralSnapshots/raw/main/examples/WA_text.gif "Example WeakAura pack showing relative power")

* Plater script coloring relative power as stacks: [https://wago.io/bfgPasy27](https://wago.io/bfgPasy27)

![ExamplePlater](https://github.com/enthh/FeralSnapshots/raw/main/examples/Plater_screenshot.png "Example Plater script")

* Weakaura text aura: [https://wago.io/Qy4t8or16](https://wago.io/Qy4t8or16)

## Usage

The global FeralSnapshots table provides functions that return a damage modifier table by buff class.

When buffs are active, the damage modifiers will reflect the power of each buff by spell. For example for rake, with `tigersFury` and a `stealth` spell active.

```lua
-- Snapshot examples with: Tiger's Fury, Sudden Ambush, and Bloodtalons auras

{ -- Rake
    tigersFury = 1.15,
    bloodtalons = 1,
    momentOfClarity = 1,
    stealth = 1.6,
    total = 1.84,
}

{ -- Rip
    tigersFury = 1.15,
    bloodtalons = 1.25,
    momentOfClarity = 1,
    stealth = 1,
    total = 1.4375,
}
```

### API

The API functions return damage modifier tables for the spell per unit.

```lua
-- Next damage modifiers that would snapshot on next application based on
-- current buffs and talents.
--
-- Modifiers are >= 1
--
-- Returns nil if the spell will not snapshot.
FeralSnapshots.Next(spellId)
FeralSnapshots.NextRake()
FeralSnapshots.NextRip()
FeralSnapshots.NextThrash()
FeralSnapshots.NextMoonfire()

-- Current snapshot damage modifier applied to the unit.
--
-- Modifiers are >= 1
--
-- Returns nil if the spell is not applied.
-- Returns nil if the spell will not snapshot.
FeralSnapshots.Current(GUID, spellId)
FeralSnapshots.CurrentRake(GUID)
FeralSnapshots.CurrentRip(GUID)
FeralSnapshots.CurrentThrash(GUID)
FeralSnapshots.CurrentMoonfire(GUID)

-- Relative damage modifiers to the applied snapshot.
--
-- Stronger damage modifiers are > 1
-- Weaker damage modifiers are < 1
--
-- Returns the next damage modifiers if the spell is not applied.
-- Returns nil if the spell will not snapshot.
FeralSnapshots.Relative(GUID, spellId)
FeralSnapshots.RelativeRake(GUID)
FeralSnapshots.RelativeRip(GUID)
FeralSnapshots.RelativeThrash(GUID)
FeralSnapshots.RelativeMoonfire(GUID)
```

Spell IDs cast in Cat Form that snapshot:

```lua
{
    rake = 155722,     -- DoT portion
    rip = 1079,        -- DoT
    thrash = 106830,   -- DoT portion
    moonfire = 155625, -- lunar inspiration DoT portion
}
```

## Usage - WeakAuras

Add a Custom Status Trigger to your aura on events `UNIT_AURA:player:target PLAYER_TARGET_CHANGED` that exposes the relative damage percentage with dynamic stacks info:


![ExampleTrigger](https://github.com/enthh/FeralSnapshots/raw/main/examples/WA_trigger.png "Trigger setup")

Use conditions to.

* Color the text <font color="green">green</font> when `Stacks > 100`
* Color the text <font color="red">red</font> when `Stacks < 100`

![ExampleConditions](https://github.com/enthh/FeralSnapshots/raw/main/examples/WA_conditions.png "Conditions setup")

## Alternatives / Inspiration / Credits

* MoonBunnie's Feral Bleed Power Weakaura for percentage text [https://wago.io/Syz8eBzY-](https://wago.io/Syz8eBzY-)
* Xan's snapshot tracker for corner icons (Wago unknown)

## FAQ

### Where did this project come from?

This project came from asking "What is the minimum information needed to be an amazing Feral Druid?".

Deciding when to cast a bleed is the most dynamic aspect of Feral gameplay. I wanted to aid that decision in any addon, like WeakAuras, Plater or other AddOns, without custom scripts in one addon depending on scripts in another.

### Why AddOn and not WeakAura?

* A versioned addon eases upgrades across patches/expansions and spell changes (/wave Savage Roar).
* A single addon compared to multiple WeakAuras ensures only one controller is active.
* A free and open source addon allows the Feral community to rally around what makes Durid 4 Fite!

### How is this different to MoonBunnie's weakaura?

Similar:

* Uses a global variable to access snapshots.
* Used for text auras of relative power - popular in WeakAura HUDs.

Different:

* This exposes damage modifiers along with totals per buff for corner icon or border color type displays.
* Minimum CPU usage/stutter by using OnEvent instead of OnUpdate (calculations every frame).
* Uses namespaced functions instead of table lookups for a stable and extensible API.