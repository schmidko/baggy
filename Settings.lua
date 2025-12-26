-----------------------------------------------------------
-- Baggy - Settings Module
-----------------------------------------------------------

local addonName, addonTable = ...
local Baggy = LibStub("AceAddon-3.0"):GetAddon(addonName)

-----------------------------------------------------------
-- Constants / Default Values
-----------------------------------------------------------

Baggy.CONSTANTS = {
    SLOTS_PER_ROW = 10,
    SLOT_SIZE = 37,
    SLOT_SPACING = 4,
    PADDING = 15,
    HEADER_SIZE = 60,
    FOOTER_SIZE = 40,
}

-----------------------------------------------------------
-- Database Defaults
-----------------------------------------------------------

Baggy.DB_DEFAULTS = {
    profile = {
        minimap = { hide = false },
        slotSize = 37,
        slotsPerRow = 18,
        showQualityBorder = true,
        bagOpacity = 0.5,
    },
}

-----------------------------------------------------------
-- Settings UI Creation
-----------------------------------------------------------

function Baggy:CreateSettingsFrame()
    local settings = CreateFrame("Frame", "BaggySettingsFrame", UIParent, "BackdropTemplate")
    settings:SetSize(400, 420)
    settings:SetPoint("CENTER")
    settings:SetFrameStrata("FULLSCREEN_DIALOG")
    settings:SetFrameLevel(100)
    settings:EnableMouse(true)
    settings:SetMovable(true)
    settings:RegisterForDrag("LeftButton")
    settings:SetScript("OnDragStart", settings.StartMoving)
    settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
    settings:SetClampedToScreen(true)
    
    -- Apply opaque style (defined in Core.lua)
    if self.ApplyOpaqueStyle then
        self:ApplyOpaqueStyle(settings)
    end
    
    -- Title
    local title = settings:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", settings, "TOP", 0, -15)
    title:SetText("Baggy Settings")
    title:SetTextColor(0.8, 0.4, 1, 1)
    
    -- Close Button
    local close = CreateFrame("Button", nil, settings, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", settings, "TOPRIGHT", -2, -2)
    
    -- Slot Size Slider
    local slotSizeLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slotSizeLabel:SetPoint("TOPLEFT", settings, "TOPLEFT", 20, -50)
    slotSizeLabel:SetText("Item Slot Size:")
    
    local slotSizeSlider = CreateFrame("Slider", "BaggySlotSizeSlider", settings, "OptionsSliderTemplate")
    slotSizeSlider:SetPoint("TOPLEFT", slotSizeLabel, "BOTTOMLEFT", 0, -10)
    slotSizeSlider:SetMinMaxValues(25, 50)
    slotSizeSlider:SetValueStep(1)
    slotSizeSlider:SetObeyStepOnDrag(true)
    slotSizeSlider:SetWidth(350)
    slotSizeSlider:SetValue(self.db.profile.slotSize)
    _G[slotSizeSlider:GetName().."Low"]:SetText("25")
    _G[slotSizeSlider:GetName().."High"]:SetText("50")
    _G[slotSizeSlider:GetName().."Text"]:SetText(self.db.profile.slotSize .. " px")
    
    slotSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        _G[self:GetName().."Text"]:SetText(value .. " px")
        Baggy.db.profile.slotSize = value
        Baggy:UpdateBags()
    end)
    
    -- Slots Per Row Slider
    local slotsPerRowLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slotsPerRowLabel:SetPoint("TOPLEFT", slotSizeSlider, "BOTTOMLEFT", 0, -30)
    slotsPerRowLabel:SetText("Slots Per Row:")
    
    local slotsPerRowSlider = CreateFrame("Slider", "BaggySlotsPerRowSlider", settings, "OptionsSliderTemplate")
    slotsPerRowSlider:SetPoint("TOPLEFT", slotsPerRowLabel, "BOTTOMLEFT", 0, -10)
    slotsPerRowSlider:SetMinMaxValues(4, 20)
    slotsPerRowSlider:SetValueStep(1)
    slotsPerRowSlider:SetObeyStepOnDrag(true)
    slotsPerRowSlider:SetWidth(350)
    slotsPerRowSlider:SetValue(self.db.profile.slotsPerRow)
    _G[slotsPerRowSlider:GetName().."Low"]:SetText("4")
    _G[slotsPerRowSlider:GetName().."High"]:SetText("20")
    _G[slotsPerRowSlider:GetName().."Text"]:SetText(self.db.profile.slotsPerRow .. " slots")
    
    slotsPerRowSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        _G[self:GetName().."Text"]:SetText(value .. " slots")
        Baggy.db.profile.slotsPerRow = value
        Baggy:UpdateBags()
    end)
    
    -- Quality Border Checkbox
    local qualityCheckbox = CreateFrame("CheckButton", "BaggyQualityBorderCheckbox", settings, "UICheckButtonTemplate")
    qualityCheckbox:SetPoint("TOPLEFT", slotsPerRowSlider, "BOTTOMLEFT", 0, -40)
    qualityCheckbox:SetSize(24, 24)
    qualityCheckbox:SetChecked(self.db.profile.showQualityBorder)
    
    local qualityLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualityLabel:SetPoint("LEFT", qualityCheckbox, "RIGHT", 5, 0)
    qualityLabel:SetText("Show Quality Border Colors")
    
    qualityCheckbox:SetScript("OnClick", function(self)
        Baggy.db.profile.showQualityBorder = self:GetChecked()
        Baggy:UpdateBags()
    end)
    
    -- Bag Opacity Slider
    local opacityLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityLabel:SetPoint("TOPLEFT", qualityCheckbox, "BOTTOMLEFT", 0, -30)
    opacityLabel:SetText("Bag Window Transparency:")
    
    local opacitySlider = CreateFrame("Slider", "BaggyOpacitySlider", settings, "OptionsSliderTemplate")
    opacitySlider:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -10)
    opacitySlider:SetMinMaxValues(0.1, 0.9)
    opacitySlider:SetValueStep(0.05)
    opacitySlider:SetObeyStepOnDrag(true)
    opacitySlider:SetWidth(350)
    opacitySlider:SetValue(self.db.profile.bagOpacity)
    _G[opacitySlider:GetName().."Low"]:SetText("10%")
    _G[opacitySlider:GetName().."High"]:SetText("90%")
    _G[opacitySlider:GetName().."Text"]:SetText(math.floor(self.db.profile.bagOpacity * 100) .. "%")
    
    opacitySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 100 + 0.5) / 100
        _G[self:GetName().."Text"]:SetText(math.floor(value * 100) .. "%")
        Baggy.db.profile.bagOpacity = value
        if BaggyFrame then
            BaggyFrame:SetBackdropColor(0, 0, 0, value)
        end
    end)
    
    settings:Hide()
    return settings
end
