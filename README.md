# FeralSnapshots - Alpha

FeralSnapshots tracks the talents, buffs and damage modifiers applied for Rake, Rip, Thrash and Lunar Inspiration Moonfire. Snapshot mamage modifiers are usable from WeakAuras, Plater and other addons.

<div align="center">

![logo](https://raw.githubusercontent.com/enthh/FeralSnapshots/main/icon.jpg "FeralSnapshots Logo")

</div>

## Features

* Debuff snapshots on all targets in combat range.
* Current buffed power and power difference if a debuff is refreshed.
* Uses talent, traits and conduits inside in and out of Shadowlands content.
* Efficient. Updates from events rather than every frame, maximizing FPS
* Provides a total and breakdown of damage modifier by buffs.

### Example WeakAuras

Rake relative refresh percentage text aura. [https://wago.io/Qy4t8or16](https://wago.io/Qy4t8or16)

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

Find a unit's GUID with the function [`UnitGUID(unitId)`](https://wowpedia.fandom.com/wiki/API_UnitGUID) like `UnitGUID("nameplate9")`.

### Usage - WeakAuras

Add a Custom Status Trigger to your aura on events: `UNIT_AURA:player:target PLAYER_TARGET_CHANGED`

Trigger with a target using the function.

```lua
function()
    return UnitGUID("target") ~= nil
end
```

Untrigger without a target using the function.

```lua
function()
    return UnitGUID("target") == nil
end
```

Use [stack info](https.//github.com/WeakAuras/WeakAuras2/wiki/Dynamic-Information#stack-info) to display the power if Rake/Rip/Thrash/Moonfire was applied or refreshed:

```lua
function() 
    return FeralSnapshots.RelativeRake(UnitGUID("target")).total * 100
end
```

Display/format/round the power with the text variable. `%s`

Use conditions to.

* Color the text <font color="green">green</font> when `Stacks > 100`
* Color the text <font color="red">red</font> when `Stacks < 100`
