local _, Private = ...

local -- from global
GetTime, UnitGUID, CombatLogGetCurrentEventInfo, C_UnitAuras, C_ClassTalents, C_Traits =
GetTime, UnitGUID, CombatLogGetCurrentEventInfo, C_UnitAuras, C_ClassTalents, C_Traits

local buff = { -- spellId by name
    tigersFury = 5217,

    bloodtalons = 145152,

    prowl = 5215,
    incarnProwl = 102547,
    shadowmeld = 58984,
    suddenAmbush = 391974,
    suddenAmbushConduit = 340698, -- SL content
    berserk = 106951,
    incarnation = 102543,

    clearcasting = 135700,
}

local debuff = { -- spellId by name
    rake = 155722,
    rip = 1079,
    thrash = 405233,
    moonfire = 155625,
}

local finisher = { -- spellId cast by name
    rip = 1079,
    maim = 22570,
    primalWrath = 285381,
    ferociousBite = 22568,
}

local talent = { -- passive spellId by name
    berserk = 106951,
    bloodtalons = 319439,
    incarnation = 102543,
    momentOfClarity = 236068,
    carnivorousInstinct = 390902,
    tigersTenacity = 391872,
}

local buffId = tInvert(buff)

local debuffId = tInvert(debuff)

local finisherId = tInvert(finisher)

Private.debuff = debuff

function Private:loadTraits()
    self.talents = {}

    -- traits
    local configId = C_ClassTalents.GetActiveConfigID()
    if configId then
        local config = C_Traits.GetConfigInfo(configId)
        if config then
            for _, treeId in ipairs(config.treeIDs) do
                local nodeIds = C_Traits.GetTreeNodes(treeId)
                for _, nodeId in ipairs(nodeIds) do
                    local node = C_Traits.GetNodeInfo(configId, nodeId)
                    if node and node.activeEntry then
                        local entry = C_Traits.GetEntryInfo(configId, node.activeEntry.entryID)
                        local definition = C_Traits.GetDefinitionInfo(entry.definitionID)
                        if definition.spellID then
                            self.talents[definition.spellID] = node.activeEntry.rank
                        end
                    end
                end
            end
        end
    end

    -- conduits don't stack
    local carnivourousInstinct = 340705 -- usable in SL
    if IsPlayerSpell(carnivourousInstinct) and IsUsableSpell(carnivourousInstinct) then
        local talentedRank = self.talents[talent.carnivorousInstinct] or 0
        self.talents[talent.carnivorousInstinct] = max(1, talentedRank)
    end
end

function Private:rank(talentSpellId)
    return self.talents[talentSpellId] or 0
end

function Private:damageModifiers()
    return {
        tigersFury      = 1.15 +
            (self:rank(talent.carnivorousInstinct) * 0.06) +
            (self:rank(talent.tigersTenacity) * 0.10),
        bloodtalons     = 1 + (self:rank(talent.bloodtalons) * 0.25),
        momentOfClarity = 1 + (self:rank(talent.momentOfClarity) * 0.15),
        stealth         = 1.60,
    }
end

-- snapshot returns damage modifiers by ability, talents and current auras for
-- this or next frame based on aura expirationTime
local function snapshot(
    spellId,  -- ID of snapshottable ability
    has,      -- function to assert auras on this or next frame
    aura,     -- table of current auras
    modifiers -- talents or other modifiers
)
    local damage = {
        tigersFury = 1,
        bloodtalons = 1,
        momentOfClarity = 1,
        stealth = 1,
        total = 1,
    }

    if debuff.rake == spellId then
        if has(aura[buff.tigersFury]) then
            damage.tigersFury = modifiers.tigersFury
        end
        if has(aura[buff.suddenAmbush])
            or has(aura[buff.incarnProwl])
            or has(aura[buff.prowl])
            or has(aura[buff.shadowmeld])
            or has(aura[buff.suddenAmbushConduit])
        then
            damage.stealth = modifiers.stealth
        end
        damage.total = damage.tigersFury * damage.stealth

    elseif debuff.rip == spellId then
        if has(aura[buff.tigersFury]) then
            damage.tigersFury = modifiers.tigersFury
        end
        if has(aura[buff.bloodtalons]) then
            damage.bloodtalons = modifiers.bloodtalons
        end
        damage.total = damage.tigersFury * damage.bloodtalons

    elseif debuff.thrash == spellId then
        if has(aura[buff.tigersFury]) then
            damage.tigersFury = modifiers.tigersFury
        end
        if has(aura[buff.clearcasting]) then
            damage.momentOfClarity = modifiers.momentOfClarity
        end
        damage.total = damage.tigersFury * damage.momentOfClarity

    elseif debuff.moonfire == spellId then
        if has(aura[buff.tigersFury]) then
            damage.tigersFury = modifiers.tigersFury
        end
        damage.total = damage.tigersFury

    else
        assert(nil, "Snapshot requested for unknown debuff")

    end

    --print("--snapshot", spellId, GetTime())
    --DevTools_Dump(aura)
    --DevTools_Dump(damage)
    return damage
end

local function activeThisFrame(expirationTime) -- test same-frame aura activation
    return expirationTime and (expirationTime == 0 or expirationTime >= GetTime())
end

local function activeNextFrame(expirationTime) -- test next-frame/GCD aura activation
    return expirationTime and (expirationTime == 0 or expirationTime > GetTime())
end

function Private:load()
    self.snapshots = self.snapshots or {}

    self:loadTraits()
    self.modifiers = self:damageModifiers()

    self.buffs = {}
    for _, spellId in pairs(buff) do
        self:refreshBuff(spellId)
    end

    self.next = {}
    self:updateNextSnapshots()
end

function Private:updateNextSnapshots()
    for _, spellId in pairs(debuff) do
        self.next[spellId] = snapshot(spellId, activeNextFrame, self.buffs, self.modifiers)
    end
end

function Private:refreshBuff(spellId)
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
    if aura then
        self.buffs[spellId] = aura.expirationTime
    end
end

function Private:removeBuff(spellId)
    self.buffs[spellId] = GetTime()
end

function Private:removeSnapshot(destGUID, spellId)
    local unit = self.snapshots[destGUID]
    if unit then
        unit[spellId] = nil
        if not next(unit) then
            self.snapshots[destGUID] = nil
        end
    end
end

function Private:refreshSnapshot(destGUID, spellId)
    local unit = self.snapshots[destGUID]
    if not unit then
        unit = {}
        self.snapshots[destGUID] = unit
    end
    unit[spellId] = snapshot(spellId, activeThisFrame, self.buffs, self.modifiers)
end

--
-- Events
--

local events = {}

local playerGUID = UnitGUID("player")

function events:COMBAT_LOG_EVENT_UNFILTERED()
    local _, msg, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()

    if sourceGUID == playerGUID then
        if msg == "SPELL_AURA_REFRESH" or msg == "SPELL_AURA_APPLIED" then
            if buffId[spellId] then
                self:refreshBuff(spellId)
                self:updateNextSnapshots()
            elseif debuffId[spellId] then
                self:refreshSnapshot(destGUID, spellId)
            end
        elseif msg == "SPELL_AURA_REMOVED" then
            if buffId[spellId] then
                self:removeBuff(spellId)
                self:updateNextSnapshots()
            elseif debuffId[spellId] then
                self:removeSnapshot(destGUID, spellId)
            end
        elseif msg == "SPELL_CAST_SUCCESS" then -- finisher + buff interactions
            if finisherId[spellId] then
                self:refreshBuff(buff.tigersFury) -- Raging Fury does not emit SPELL_AURA_REFRESH
                self:updateNextSnapshots()
            end
        end
    end
end

events.PLAYER_ENTERING_WORLD = Private.load
events.PLAYER_TALENT_UPDATE = Private.load
events.ACTIVE_TALENT_GROUP_CHANGED = Private.load
events.PLAYER_PVP_TALENT_UPDATE = Private.load
events.TRAIT_CONFIG_CREATED = Private.load
events.TRAIT_CONFIG_UPDATED = Private.load

local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, event, ...)
    events[event](Private, ...)
end)

for k, _ in pairs(events) do
    f:RegisterEvent(k)
end

-- UIParentLoadAddOn("Blizzard_DebugTools"); DisplayTableInspectorWindow(Private)
