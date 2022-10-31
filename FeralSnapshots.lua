local _, Private = ...

local debuff = Private.debuff

FeralSnapshots = {}

function FeralSnapshots:AppliedDebuff(GUID, spellId)
    local unit = Private.snapshots[GUID]
    if not unit then
        return nil
    end

    return unit[spellId]
end

function FeralSnapshots:AppliedRake(GUID)
    return self:AppliedDebuff(GUID, debuff.rake)
end

function FeralSnapshots:AppliedRip(GUID)
    return self:AppliedDebuff(GUID, debuff.rip)
end

function FeralSnapshots:AppliedThrash(GUID)
    return self:AppliedDebuff(GUID, debuff.thrash)
end

function FeralSnapshots:AppliedMoonfire(GUID)
    return self:AppliedDebuff(GUID, debuff.moonfire)
end

function FeralSnapshots:NextDebuff(spellId)
    return Private.next[spellId]
end

function FeralSnapshots:NextRake()
    return self:NextDebuff(debuff.rake)
end

function FeralSnapshots:NextRip()
    return self:NextDebuff(debuff.rip)
end

function FeralSnapshots:NextThrash()
    return self:NextDebuff(debuff.thrash)
end

function FeralSnapshots:NextMoonfire()
    return self:NextDebuff(debuff.moonfire)
end

function FeralSnapshots:RefreshDebuff(GUID, spellId)
    local refresh = self:NextDebuff(spellId)
    local applied = self:AppliedDebuff(GUID, spellId)
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

function FeralSnapshots:RefreshRake(GUID)
    return self:RefreshDebuff(GUID, debuff.rake)
end

function FeralSnapshots:RefreshRip(GUID)
    return self:RefreshDebuff(GUID, debuff.rip)
end

function FeralSnapshots:RefreshThrash(GUID)
    return self:RefreshDebuff(GUID, debuff.thrash)
end

function FeralSnapshots:RefreshMoonfire(GUID)
    return self:RefreshDebuff(GUID, debuff.moonfire)
end

-- FeralSnapshots.private = Private
