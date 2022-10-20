local playerGUID = UnitGUID("player")

local talent = { -- passive spellId by name
    berserk = 106951,
    bloodtalons = 319439,
    incarnation = 102543,
    momentOfClarity = 236068,
    carnivorousInstincts = 390902,
}

local spell = { -- spellId by name
    tigersFury = 5217,
    bloodtalons = 145152,

    prowl = 5215,
    incarnProwl = 102547,
    shadowmeld = 58984,
    suddenAmbush = 391974,
    berserk = 106951,
    incarnation = 102543,

    clearcasting = 135700,

    rakeDot = 155722,
    rip = 1079,
    thrash = 106830,
    moonfire = 155625,
}

-- expiration delays allow active tests to succeed for consumed auras in the
-- same frame as removal but not for the next GCD
local trackingDuration = 3600
local consumedDelay = 0.100
local gcdDelay = 0.250
local consumed = {
    [spell.prowl] = consumedDelay,
    [spell.suddenAmbush] = consumedDelay,
    [spell.shadowmeld] = consumedDelay,
    [spell.clearcasting] = consumedDelay,
    [spell.bloodtalons] = consumedDelay,
}

local trackingSpell = {} -- set of spellIds to filter
for name, id in pairs(spell) do
    trackingSpell[id] = name
end

aura_env.auras = aura_env.auras or {} -- auras by GUID
local auras = aura_env.auras

aura_env.talents = aura_env.talents or {} -- rank by spellId with damage modifiers
local talents = aura_env.talents

local function active(timestamp, aura) -- test same-frame aura activation
    if aura and aura.expirationTime then
        return aura.expirationTime == 0 or aura.expirationTime > timestamp
    end
    return false
end

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

    self.damage = self:DamageModifiers()
end

function talents:DamageModifiers()
    return {
        tigersFury      = 1.15 + (self:Rank(talent.carnivorousInstincts) * 0.06),
        bloodTalons     = self:Rank(talent.bloodtalons) > 0 and 1.25 or 1,
        momentOfClarity = self:Rank(talent.momentOfClarity) > 0 and 1.15 or 1,
        stealth         = 1.60,
    }
end

--
-- Unit/Spell/Arua/Snapshot Tracking
--

function auras:snapshot(t, spellId) -- snapshot state by spell from damage modifier logic
    local dmg = {
        tigersFury = 1,
        stealth = 1,
        bloodtalons = 1,
        momentOfClarity = 1,
        snapshot = 1,
    }

    local player = self.units[playerGUID]
    local tf = (active(t, player[spell.tigersFury]) and talents.damage.tigersFury or dmg.tigersFury)

    if (spell.rakeDot == spellId) then
        if active(t, player[spell.suddenAmbush])
            or active(t, player[spell.berserk])
            or active(t, player[spell.incarnation])
            or active(t, player[spell.incarnProwl])
            or active(t, player[spell.prowl])
            or active(t, player[spell.shadowmeld])
            then
            dmg.stealth = talents.damage.stealth
        end
        dmg.tigersFury = tf
        dmg.snapshot   = dmg.tigersFury * dmg.stealth

    elseif spell.rip == spellId then
        if active(t, player[spell.bloodtalons]) then
            dmg.bloodtalons = talents.damage.bloodtalons
        end
        dmg.tigersFury = tf
        dmg.snapshot = dmg.tigersFury * dmg.bloodtalons

    elseif spell.thrash == spellId then
        if active(t, player[spell.clearcasting]) then
            dmg.momentOfClarity = talents.damage.momentOfClarity
        end
        dmg.tigersFury = tf
        dmg.snapshot = dmg.tigersFury * dmg.momentOfClarity

    elseif spell.moonfire == spellId then
        dmg.tigersFury = tf
        dmg.snapshot = dmg.tigersFury
    end

    return dmg
end

function auras:Load()
    self.units = setmetatable(self.units or {}, {
        __index = function(t, guid) t[guid] = {}; return t[guid] end,
    })

    -- apply existing player buffs
    local aura = C_UnitAuras.GetPlayerAuraBySpellID
    for _, spellId in pairs(spell) do
        local info = aura(spellId)
        if info then
            local expirationTime, castByPlayer = select(6, info), select(12, info)
            if castByPlayer then
                self:Apply(playerGUID, spellId, expirationTime)
            end
        end
    end
    -- TODO refresh player buffs
end

function auras:Track(sourceGUID, spellId)
    return sourceGUID == playerGUID and trackingSpell[spellId]
end

function auras:Apply(ts, guid, spellId)
    local aura = {
        expirationTime = ts + trackingDuration,
    }

    if guid ~= playerGUID then
        aura.snapshot = self:snapshot(ts, spellId)
    end

    self.units[guid][spellId] = aura
end

function auras:Remove(timestamp, guid, spellId)
    local aura = self.units[guid][spellId]
    if aura then
        aura.expirationTime = timestamp + (consumed[spellId] or 0)
    end

    self:GarbageCollect(timestamp, guid)
end

function auras:GarbageCollect(timestamp, guid)
    local unit = self.units[guid]
    for id, aura in pairs(unit) do
        if not active(timestamp, aura) then
            unit[id] = nil
        end
    end

    if not next(unit) then -- zero auras
        self.units[guid] = nil
    end
end

--- WA/TSU integration

function auras:TriggerStateUpdate(ts, states)
    -- TODO OPTION for trigger number states
    local matches = WeakAuras.GetTriggerStateForTrigger(aura_env.id, 1)

    for cloneId, clone in pairs(matches) do
        local current = self:snapshot(ts + gcdDelay, clone.spellId)
        local state = {
            show = clone.show,
            changed = true,

            spellId = clone.spellId,
            icon = clone.icon,
            name = clone.name,

            hasTigersFury = current.tigersFury > 1,
            hasStealth = current.stealth > 1,
            hasBloodtalons = current.bloodtalons > 1,
            hasMomentOfClarity = current.momentOfClarity > 1,

            currentDamage = current.snapshot,

            reapplyDamage = 1,
            reapplyDamagePercent = 100,
        }

        local aura = self.units[clone.GUID][clone.spellId]
        if aura and aura.snapshot then
            local dmg = aura.snapshot

            state.active = true

            -- project damage modifiers to WA condition/text fields
            state.tigersFuryDamage = dmg.tigersFury
            state.hadTigersFury = dmg.tigersFury > 1

            state.stealthDamage = dmg.stealth
            state.hadStealth = dmg.stealth > 1

            state.bloodtalonsDamage = dmg.bloodtalons
            state.hadBloodtalons = dmg.bloodtalons > 1

            state.momentOfClarityDamage = dmg.momentOfClarity
            state.hadMomentOfClarity = dmg.momentOfClarity > 1

            state.snapshotDamage = dmg.snapshot

            state.reapplyDamage = state.currentDamage / state.snapshotDamage
            state.reapplyDamagePercent = math.floor(state.reapplyDamage * 100 + 0.5)
        end

        -- TODO OPTION to emulate feralSnapshots or xan_feralsnapshots

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

aura_env.SPELL_AURA_APPLIED = function(states, _, _, msg, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId)
    if auras:Track(sourceGUID, spellId) then
        local time = GetTime()
        DebugPrint(msg, ">", time, destGUID, spellId)

        auras:Apply(time, destGUID, spellId)
        DebugPrint(msg, "<", time, destGUID, active(time, auras.units[destGUID][spellId]))

        auras:TriggerStateUpdate(time, states)
        DebugPrint(msg, "=", time, states)

        return true
    end
end

aura_env.SPELL_AURA_REFRESH = aura_env.SPELL_AURA_APPLIED

aura_env.SPELL_AURA_REMOVED = function(states, _, _, msg, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId)
    if auras:Track(sourceGUID, spellId) then
        local time = GetTime()
        DebugPrint(msg, ">", time, destGUID, spellId)

        auras:Remove(time, destGUID, spellId)
        DebugPrint(msg, "<", time, destGUID, active(time, auras.units[destGUID][spellId]))

        auras:TriggerStateUpdate(time, states)
        DebugPrint(msg, "=", time, states)

        return true
    end
end

aura_env.TRIGGER = function(states)
    local time = GetTime()
    auras:TriggerStateUpdate(time, states)
    DebugPrint("TRIGGER", "=", time, states)
    return true
end

--
-- Init
--
talents:Load()
auras:Load()

-- UIParentLoadAddOn("Blizzard_DebugTools")
-- DisplayTableInspectorWindow(aura_env)
