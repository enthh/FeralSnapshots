local playerGUID = UnitGUID("player")

local talent = { -- passive spellId by name
    berserk = 106951,
    bloodtalons = 319439,
    incarnation = 102543,
    momentOfClarity = 236068,
    carnivorousInstincts = 390902,
}

local spell = { -- spellId by name
    bloodtalons = 145152,
    incarnation = 102543,

    tigersFury = 5217,
    prowl = 5215,
    incarnProwl = 102547,
    shadowmeld = 58984,
    suddenAmbush = 391974,
    berserk = 106951,
    clearcasting = 135700,

    rakeDot = 155722,
    rakeStun = 163505,
    rakeInitial = 1822,
    rip = 1079,
    thrash = 106830,
    moonfire = 155625,
    primalWrath = 285381,
}

local tracking = {} -- set of spellIds
for name, id in pairs(spell) do tracking[id] = name end

aura_env.talents = aura_env.talents or {} -- rank by spellId
local talents = aura_env.talents

aura_env.auras = aura_env.auras or {} -- auras by GUID
local auras = aura_env.auras

---
--- Damage Modifier Logic
---

local function active(aura, time)
    local res = false
    if aura and aura.expirationTime then
        res = aura.expirationTime == 0 or aura.expirationTime >= (time or GetTime())
    end
    return res
end

local function expire(unit, time) -- remove inactive auras
    for id, aura in pairs(unit) do
        if not active(aura, time) then
            unit[id] = nil
        end
    end
end

local buffAdd = { -- modifiers to buffs at time t
    tf = function(s,t) return talents:Rank(talent.carnivorousInstincts) * 0.06 end,
}

local buffed = { -- buff applicability at time t
    tf      = function(s,t) return active(s[spell.tigersFury],t) end,
    bt      = function(s,t) return active(s[spell.bloodtalons],t) and talents:Rank(talent.bloodtalons) > 0 end,
    moc     = function(s,t) return active(s[spell.clearcasting],t) and talents:Rank(talent.momentOfClarity) > 0 end,
    stealth = function(s,t) return active(s[spell.prowl],t) or active(s[spell.incarnProwl],t) or active(s[spell.shadowmeld],t) end,
}

local dmg = { -- damage modifier per buff at time t
    tf      = function(s,t) return buffed.tf(s,t) and 1.15 + buffAdd.tf(s,t) or 1 end,
    bt      = function(s,t) return buffed.bt(s,t) and 1.25 or 1 end,
    moc     = function(s,t) return buffed.moc(s,t) and 1.15 or 1 end,
    stealth = function(s,t) return buffed.stealth(s,t) and 1.60 or 1 end,
}

local debuffs = { -- damage modifier per debuff at time t
    [spell.rakeStun] = function(s,t) return dmg.tf(s,t) * dmg.stealth(s,t) end,
    [spell.rakeDot]  = function(s,t) return dmg.tf(s,t) * dmg.stealth(s,t) end,
    [spell.rip]      = function(s,t) return dmg.tf(s,t) * dmg.bt(s,t) end,
    [spell.thrash]   = function(s,t) return dmg.tf(s,t) * dmg.moc(s,t) end,
    [spell.moonfire] = function(s,t) return dmg.tf(s,t) end,
}

--
-- Talents
--

function talents:Rank(spellId)
    return self[spellId] or 0
end

function talents:Load()
    local CT, T = C_ClassTalents, C_Traits
    local configId = CT.GetActiveConfigID()
    if configId then
        local config = T.GetConfigInfo(configId)
        for _, treeId in ipairs(config.treeIDs) do
            local nodeIds = T.GetTreeNodes(treeId)
            for _, nodeId in ipairs(nodeIds) do
                local node = T.GetNodeInfo(configId, nodeId)
                if node and node.ID ~= 0 then
                    for _, entryId in ipairs(node.entryIDs) do
                        local entry = T.GetEntryInfo(configId, entryId)
                        local definition = T.GetDefinitionInfo(entry.definitionID)
                        if node.activeEntry then
                            self[definition.spellID] = node.currentRank
                        end
                    end
                end
            end
        end
    end
end

--
-- Unit/Spell Tracking
--

local function snapshot(unit) -- copy unit aura refs
    local buffs = {}
    for k, v in pairs(unit) do buffs[k] = v end
    return buffs
end

function auras:Load()
    self.units = setmetatable(self.units or {}, {
        __index = function(t, guid) t[guid] = {}; return t[guid] end,
    })
    -- TODO refresh player buffs
end

function auras:Track(sourceGUID, spellId)
    return sourceGUID == playerGUID and tracking[spellId]
end

function auras:Apply(guid, spellId)
    self.units[guid][spellId] = {
        spellId = spellId,
        expirationTime = GetTime() + 600,
        snapshot = debuffs[spellId] and snapshot(self.units[playerGUID]),
    }

    return true
end

function auras:Remove(guid, spellId)
    local now = GetTime()
    local unit = self.units[guid]

    local aura = unit[spellId]
    if not aura then -- expired or never applied
        return
    end

    unit[spellId] = { -- new ref with original aura snapshot aura refs
        spellId = spellId,
        expirationTime = now,
        snapshot = aura.snapshot,
    }

    if guid ~= playerGUID then -- free units without debuffs
        expire(unit, now)
        if not next(unit) then
            self.units[guid] = nil
        end
    end
end

--- WA integration

function auras:TriggerStateUpdate(states)
    -- TODO use trigger number from custom OPTIONS
    local others = WeakAuras.GetTriggerStateForTrigger(aura_env.id, 1)

    local currentSnapshot = snapshot(self.units[playerGUID])
    expire(currentSnapshot, GetTime() - 0.250) -- next GCD snapshot

    for cloneId, clone in pairs(others) do
        local aura = self.units[clone.GUID][clone.spellId]
        local modifier = debuffs[clone.spellId]

        local state = {
            show = clone.show,
            changed = true,

            icon = clone.icon,
            spellId = clone.spellId,
            active = clone.active,
            name = clone.name,

        }

        if aura and modifier then
            state.hadTigersFury = buffed.tf(aura.snapshot, clone.refreshTime)
            state.hadStealth = buffed.stealth(aura.snapshot, clone.refreshTime)
            state.hadBloodtalons = buffed.bt(aura.snapshot, clone.refreshTime)
            state.hadMomentOfClarity = buffed.moc(aura.snapshot, clone.refreshTime)

            state.snapshotDamage = modifier(aura.snapshot, clone.refreshTime)
            state.currentDamage = modifier(currentSnapshot, GetTime() + 0.250)
            state.reapplyDamage = state.currentDamage / state.snapshotDamage
            state.reapplyDamagePercent = math.floor(state.reapplyDamage * 100 + 0.5)
            print("st", GetTime(), clone.initialTime, "snap", buffed.stealth(aura.snapshot), aura.snapshot[spell.prowl].expirationTime, "current", buffed.stealth(currentSnapshot))
        end

        states[cloneId] = state
    end
end

--
-- Events
--

aura_env.OPTIONS = function()
end

aura_env.COMBAT_LOG_EVENT_UNFILTERED = function(states, ...)
    local subevent = select(3, ...)
    local dispatch = aura_env[subevent]
    if not dispatch then
        return false
    end
    return dispatch(states, ...)
end

aura_env.SPELL_AURA_APPLIED = function(states, _, _, _, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId)
    if auras:Track(sourceGUID, spellId) then
        print("SAA >", destGUID, spellId)
        auras:Apply(destGUID, spellId)
        print("SAA <", destGUID, active(auras.units[destGUID][spellId]))
        auras:TriggerStateUpdate(states)
        return true
    end
end

aura_env.SPELL_AURA_REFRESHED = aura_env.SPELL_AURA_APPLIED

aura_env.SPELL_AURA_REMOVED = function(states, _, _, _, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId)
    if auras:Track(sourceGUID, spellId) then
        print("SAR >", destGUID, spellId)
        auras:Remove(destGUID, spellId)
        print("SAR <", destGUID, active(auras.units[destGUID][spellId]))
        auras:TriggerStateUpdate(states)
        return true
    end
end

aura_env.TRIGGER = function(states)
    auras:TriggerStateUpdate(states)
    return true
end

--
-- Init
--
talents:Load()
auras:Load()

UIParentLoadAddOn("Blizzard_DebugTools")
--DisplayTableInspectorWindow(auras)
--DisplayTableInspectorWindow(aura_env.talents)
