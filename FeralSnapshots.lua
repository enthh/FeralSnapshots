local _, Private = ...

local debuff = Private.debuff

FeralSnapshots = {}

function FeralSnapshots.Current(GUID, spellId)
    local unit = Private.snapshots[GUID]
    if not unit then
        return nil
    end

    return unit[spellId]
end

function FeralSnapshots.CurrentRake(GUID)
    return FeralSnapshots.Current(GUID, debuff.rake)
end

function FeralSnapshots.CurrentRip(GUID)
    return FeralSnapshots.Current(GUID, debuff.rip)
end

function FeralSnapshots.CurrentThrash(GUID)
    return FeralSnapshots.Current(GUID, debuff.thrash)
end

function FeralSnapshots.CurrentMoonfire(GUID)
    return FeralSnapshots.Current(GUID, debuff.moonfire)
end

function FeralSnapshots.Next(spellId)
    return Private.next[spellId]
end

function FeralSnapshots.NextRake()
    return FeralSnapshots.Next(debuff.rake)
end

function FeralSnapshots.NextRip()
    return FeralSnapshots.Next(debuff.rip)
end

function FeralSnapshots.NextThrash()
    return FeralSnapshots.Next(debuff.thrash)
end

function FeralSnapshots.NextMoonfire()
    return FeralSnapshots.Next(debuff.moonfire)
end

function FeralSnapshots.Relative(GUID, spellId)
    local refresh = FeralSnapshots.Next(spellId)
    local applied = FeralSnapshots.Current(GUID, spellId)
    if not applied then
        return refresh
    end

    local diff = {}
    for k, later in pairs(refresh) do
        local current = applied[k]
        if current then
            diff[k] = later / current
        else
            diff[k] = later
        end
    end

    return diff
end

function FeralSnapshots.RelativeRake(GUID)
    return FeralSnapshots.Relative(GUID, debuff.rake)
end

function FeralSnapshots.RelativeRip(GUID)
    return FeralSnapshots.Relative(GUID, debuff.rip)
end

function FeralSnapshots.RelativeThrash(GUID)
    return FeralSnapshots.Relative(GUID, debuff.thrash)
end

function FeralSnapshots.RelativeMoonfire(GUID)
    return FeralSnapshots.Relative(GUID, debuff.moonfire)
end

function FeralSnapshots.debug()
    UIParentLoadAddOn("Blizzard_DebugTools")
    DisplayTableInspectorWindow(Private)
    return Private
end
