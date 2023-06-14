FeralSnapshotsNamePlateDriverMixin = {}

function FeralSnapshotsNamePlateDriverMixin:OnLoad()
    self.pool = CreateFramePool("FRAME", self, "FeralSnapshotsAuraTemplate")

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("NAME_PLATE_CREATED")
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("UNIT_AURA")
end

function FeralSnapshotsNamePlateDriverMixin:OnEvent(event, ...)
    if event == "NAME_PLATE_CREATED" then
        local namePlate = ...
        self:OnNamePlateCreated(namePlate)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unitToken = ...
        self:OnNamePlateAdded(unitToken)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unitToken = ...
        self:OnNamePlateRemoved(unitToken)
    elseif event == "UNIT_AURA" then
        self:OnUnitAuraUpdate(...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:OnUnitAuraUpdate("player")
    end
end

function FeralSnapshotsNamePlateDriverMixin:OnNamePlateCreated(namePlate)
    namePlate.feralSnapshots = CreateAndInitFromMixin(FeralSnapshotsNamePlate, self.pool, FeralSnapshots)
end

function FeralSnapshotsNamePlateDriverMixin:OnNamePlateAdded(unit)
    local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
    namePlate.feralSnapshots:OnAdded(unit, namePlate.UnitFrame.BuffFrame)
    namePlate.feralSnapshots:UpdateAuras()
end

function FeralSnapshotsNamePlateDriverMixin:OnNamePlateRemoved(unit)
    local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
    namePlate.feralSnapshots:OnRemoved()
end

function FeralSnapshotsNamePlateDriverMixin:OnUnitAuraUpdate(unit)
    local updates

    if UnitIsUnit("player", unit) then
        -- player buffs could change snapshot powers
        updates = C_NamePlate.GetNamePlates(false)
    else
        updates = { C_NamePlate.GetNamePlateForUnit(unit) }
    end

    for _, namePlate in ipairs(updates) do
        if namePlate and namePlate.feralSnapshots then
            namePlate.feralSnapshots:UpdateAuras()
        end
    end
end

FeralSnapshotsNamePlate = {}

function FeralSnapshotsNamePlate:Init(pool, snapshots)
    self.pool = pool
    self.active = {}
    self.snapshots = snapshots
end

function FeralSnapshotsNamePlate:Reset()
    for _, aura in ipairs(self.active) do
        self.pool:Release(aura)
    end
    self.active = {}
end

function FeralSnapshotsNamePlate:Acquire()
    local aura = self.pool:Acquire()
    table.insert(self.active, aura)
    return aura
end

function FeralSnapshotsNamePlate:OnAdded(unit, buffFrame)
    self.unitGUID = UnitGUID(unit)
    self.buffFrame = buffFrame
end

function FeralSnapshotsNamePlate:OnRemoved()
    self:Reset()
    self.unit = nil
    self.namePlate = nil
end

function FeralSnapshotsNamePlate:UpdateAuras()
    self:Reset()

    for _, buff in ipairs({ self.buffFrame:GetChildren() }) do
        local spellID = buff.spellID
        if spellID then
            local nextPower = self.snapshots.Next(spellID)
            if nextPower then
                local currentPower = self.snapshots.Current(self.unitGUID, spellID)
                local overlay = self:Acquire()
                overlay:Init(buff, spellID, nextPower, currentPower)
                overlay:Show()
            end
        end
    end
end

FeralSnapshotsAuraMixin = {}

function FeralSnapshotsAuraMixin:Init(parent, spellID, nextSnapshot, currentSnapshot)
    self.spellID = spellID

    self:ClearAllPoints()
    self:SetParent(parent)
    self:SetAllPoints(parent)

    for modifier, nextPower in pairs(nextSnapshot) do
        local indicator = self[modifier]
        if indicator then
            local currentPower = currentSnapshot and currentSnapshot[modifier] or 1
            indicator:Init(nextPower, currentPower)
        end
    end
end

local colors = {
    more = GREEN_FONT_COLOR,
    less = RED_FONT_COLOR,
    even = CreateColor(1, 1, 1, 1),
}

FeralSnapshotsIndicatorMixin = {}

function FeralSnapshotsIndicatorMixin:Init(nextPower, currentPower)
    if currentPower == 1 and nextPower == 1 then
        self:Hide()
    else
        if nextPower > currentPower then
            self:SetVertexColor(colors.more:GetRGBA())
        elseif nextPower < currentPower then
            self:SetVertexColor(colors.less:GetRGBA())
        else
            self:SetVertexColor(colors.even:GetRGBA())
        end

        if currentPower == 1 and nextPower > 1 then
            self:SetAtlas("common-icon-backarrow")
        else
            self:SetAtlas("common-icon-forwardarrow")
        end

        local w, h = self:GetParent():GetSize()
        self:SetSize(w / 2, h / 2)
        self:Show()
    end
end
