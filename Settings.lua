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
        borderColor = { r = 0.6, g = 0.2, b = 0.8, a = 0.8 },
    },
}

-----------------------------------------------------------
-- Color Picker Creation
-----------------------------------------------------------

function Baggy:CreateColorPickerFrame()
    local picker = CreateFrame("Frame", "BaggyColorPicker", UIParent, "BackdropTemplate")
    picker:SetSize(350, 420)
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(250)
    picker:EnableMouse(true)
    picker:SetMovable(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", picker.StartMoving)
    picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
    picker:SetClampedToScreen(true)
    
    picker:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    picker:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    picker:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", picker, "TOP", 0, -15)
    title:SetText("Select Color")
    
    -- Current color state
    local r, g, b = 1, 1, 1
    local currentA = 1
    
    -- ------------------------------------------------------
    -- Custom Spectrum Square (Hue x Lightness)
    -- ------------------------------------------------------
    local spectrum = CreateFrame("Button", nil, picker)
    spectrum:SetSize(250, 250)
    spectrum:SetPoint("TOP", picker, "TOP", 0, -50)
    
    -- 1. Horizontal Rainbow Gradient (Hue)
    -- We need 6 segments for smooth R-Y-G-C-B-M-R transition
    local segmentWidth = 250 / 6
    local colors = {
        {1,0,0}, {1,1,0}, {0,1,0}, {0,1,1}, {0,0,1}, {1,0,1}, {1,0,0}
    }
    
    for i = 1, 6 do
        local tex = spectrum:CreateTexture(nil, "BACKGROUND")
        tex:SetPoint("TOPLEFT", spectrum, "TOPLEFT", (i-1)*segmentWidth, 0)
        tex:SetSize(segmentWidth, 250)
        
        local c1 = colors[i]
        local c2 = colors[i+1]
        
        -- Modern SetGradient (Dragonflight+)
        if tex.SetGradient then 
             tex:SetColorTexture(1, 1, 1, 1) -- Base white texture required
             tex:SetGradient("HORIZONTAL", CreateColor(c1[1], c1[2], c1[3], 1), CreateColor(c2[1], c2[2], c2[3], 1))
        else
             -- Fallback
             tex:SetColorTexture(1, 1, 1, 1) 
        end
    end
    
    -- 2. Vertical Lightness Gradients
    -- Top Half: White -> Transparent
    local whiteOverlay = spectrum:CreateTexture(nil, "BORDER")
    whiteOverlay:SetPoint("TOPLEFT", spectrum, "TOPLEFT", 0, 0)
    whiteOverlay:SetPoint("TOPRIGHT", spectrum, "TOPRIGHT", 0, 0)
    whiteOverlay:SetHeight(125)
    whiteOverlay:SetColorTexture(1, 1, 1, 1) -- Base white texture required
    whiteOverlay:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1)) 
    
    -- Bottom Half: Black -> Transparent
    local blackOverlay = spectrum:CreateTexture(nil, "BORDER")
    blackOverlay:SetPoint("BOTTOMLEFT", spectrum, "BOTTOMLEFT", 0, 0)
    blackOverlay:SetPoint("BOTTOMRIGHT", spectrum, "BOTTOMRIGHT", 0, 0)
    blackOverlay:SetHeight(125)
    blackOverlay:SetColorTexture(1, 1, 1, 1) -- Base white texture required
    blackOverlay:SetGradient("VERTICAL", CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 0))
    
    -- Selection Crosshair
    local crosshair = spectrum:CreateTexture(nil, "OVERLAY")
    crosshair:SetSize(16, 16)
    crosshair:SetTexture("Interface\\Buttons\\UI-ColorPicker-Buttons")
    crosshair:SetTexCoord(0.25, 1.0, 0.875, 1.0) -- Ring shape
    crosshair:SetPoint("CENTER", spectrum, "BOTTOMLEFT", 0, 0) -- Initial pos
    
    -- Helper: Hue Extraction from X (0-1)
    local function GetHueColor(x)
        local h = x * 6
        local i = math.floor(h)
        local f = h - i
        local r, g, b = 0, 0, 0
        
        -- i maps to 0..5 based on segments
        if i == 0 then r=1; g=f; b=0       -- R->Y
        elseif i == 1 then r=1-f; g=1; b=0 -- Y->G
        elseif i == 2 then r=0; g=1; b=f   -- G->C
        elseif i == 3 then r=0; g=1-f; b=1 -- C->B
        elseif i == 4 then r=f; g=0; b=1   -- B->M
        elseif i == 5 then r=1; g=0; b=1-f -- M->R
        else r=1; g=0; b=0 end -- edge case 1.0
        
        return r, g, b
    end
    
    -- Update Preview
    local preview = picker:CreateTexture(nil, "ARTWORK")
    
    local function UpdatePreview()
        picker.preview:SetColorTexture(r, g, b, currentA)
    end
    
    -- Interaction Logic
    local function SelectColor(self)
        local mx, my = GetCursorPosition()
        local s = self:GetEffectiveScale()
        mx, my = mx/s, my/s
        
        local left, bottom = self:GetLeft(), self:GetBottom()
        local width, height = self:GetWidth(), self:GetHeight()
        
        local x = (mx - left) / width
        local y = (my - bottom) / height
        
        -- Clamp
        x = math.max(0, math.min(1, x))
        y = math.max(0, math.min(1, y))
        
        -- Move Crosshair
        crosshair:SetPoint("CENTER", self, "BOTTOMLEFT", x*width, y*height)
        
        -- Calculate Color
        -- 1. Get Pure Hue color
        local hr, hg, hb = GetHueColor(x)
        
        -- 2. Apply Lightness (y)
        -- y=0.5 -> Pure
        -- y=1.0 -> White
        -- y=0.0 -> Black
        
        if y > 0.5 then
            -- Mix with White
            local pct = (y - 0.5) * 2
            r = hr + (1 - hr) * pct
            g = hg + (1 - hg) * pct
            b = hb + (1 - hb) * pct
        else
            -- Mix with Black
            local pct = y * 2 -- 0 at bottom, 1 at center
            r = hr * pct
            g = hg * pct
            b = hb * pct
        end
        
        UpdatePreview()
    end
    
    spectrum:SetScript("OnMouseDown", function(self)
        self:SetScript("OnUpdate", SelectColor)
        SelectColor(self)
    end)
    
    spectrum:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    
    
    -- Preview Swatch
    preview:SetSize(40, 40)
    preview:SetPoint("TOPLEFT", spectrum, "BOTTOMLEFT", 10, -20)
    preview:SetColorTexture(r, g, b, 1)
    picker.preview = preview
    
    -- Alpha Slider
    local alphaSlider = CreateFrame("Slider", "BaggyColorPickerAlpha", picker, "OptionsSliderTemplate")
    alphaSlider:SetPoint("LEFT", preview, "RIGHT", 30, 0)
    alphaSlider:SetWidth(150)
    alphaSlider:SetMinMaxValues(0, 1)
    alphaSlider:SetValueStep(0.01)
    alphaSlider:SetOrientation("HORIZONTAL")
    _G[alphaSlider:GetName().."Low"]:SetText("0%")
    _G[alphaSlider:GetName().."High"]:SetText("100%")
    _G[alphaSlider:GetName().."Text"]:SetText("Opacity")
    
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        currentA = value
        UpdatePreview()
    end)
    
    -- Buttons
    local okBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    okBtn:SetSize(100, 30)
    okBtn:SetPoint("BOTTOMLEFT", picker, "BOTTOMLEFT", 40, 20)
    okBtn:SetText("OK")
    
    okBtn:SetScript("OnClick", function()
        Baggy.db.profile.borderColor.r = r
        Baggy.db.profile.borderColor.g = g
        Baggy.db.profile.borderColor.b = b
        Baggy.db.profile.borderColor.a = currentA
        Baggy:UpdateColors()
        
        if BaggySettingsFrame and BaggySettingsFrame.swatch then
            BaggySettingsFrame.swatch:SetBackdropColor(r, g, b, currentA)
        end
        picker:Hide()
    end)
    
    local cancelBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 30)
    cancelBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -40, 20)
    cancelBtn:SetText("Cancel")
    
    cancelBtn:SetScript("OnClick", function()
        picker:Hide()
    end)
    
    -- Setup Function
    picker.Setup = function(self)
        local c = Baggy.db.profile.borderColor
        r, g, b, currentA = c.r, c.g, c.b, c.a
        alphaSlider:SetValue(currentA)
        UpdatePreview()
        
        -- Note: We don't reverse-engineer position from RGB perfectly here (lossy)
        -- Reset crosshair to center just to be safe, or leave it
        crosshair:SetPoint("CENTER", spectrum, "CENTER", 0, 0)
    end
    
    picker:Hide()
    return picker
end

-----------------------------------------------------------
-- Settings UI Creation
-----------------------------------------------------------

function Baggy:CreateSettingsFrame()
    local settings = CreateFrame("Frame", "BaggySettingsFrame", UIParent, "BackdropTemplate")
    settings:SetSize(400, 450) -- Reduced height since sliders are gone
    settings:SetPoint("CENTER")
    
    -- FIX: Settings should be above the bag window
    settings:SetFrameStrata("FULLSCREEN_DIALOG") 
    settings:SetFrameLevel(200) 
    
    settings:EnableMouse(true)
    settings:SetMovable(true)
    settings:RegisterForDrag("LeftButton")
    settings:SetScript("OnDragStart", settings.StartMoving)
    settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
    settings:SetClampedToScreen(true)
    
    -- Apply opaque style
    if self.ApplyOpaqueStyle then
        self:ApplyOpaqueStyle(settings)
    end
    
    -- Title
    local title = settings:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", settings, "TOP", 0, -15)
    title:SetText("Baggy Settings")
    title:SetTextColor(self.db.profile.borderColor.r, self.db.profile.borderColor.g, self.db.profile.borderColor.b, 1)
    settings.title = title
    
    -- Close Button
    local close = CreateFrame("Button", nil, settings, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", settings, "TOPRIGHT", -2, -2)
    
    -- Content Anchor
    local startY = -60
    
    -- Slot Size Slider
    local slotSizeLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slotSizeLabel:SetPoint("TOPLEFT", settings, "TOPLEFT", 20, startY)
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
    opacitySlider:SetMinMaxValues(0.1, 1.0)
    opacitySlider:SetValueStep(0.05)
    opacitySlider:SetObeyStepOnDrag(true)
    opacitySlider:SetWidth(350)
    opacitySlider:SetValue(self.db.profile.bagOpacity)
    _G[opacitySlider:GetName().."Low"]:SetText("10%")
    _G[opacitySlider:GetName().."High"]:SetText("100%")
    _G[opacitySlider:GetName().."Text"]:SetText(math.floor(self.db.profile.bagOpacity * 100) .. "%")
    
    opacitySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 100 + 0.5) / 100
        _G[self:GetName().."Text"]:SetText(math.floor(value * 100) .. "%")
        Baggy.db.profile.bagOpacity = value
        if Baggy.MainFrame then
            Baggy.MainFrame:SetBackdropColor(0, 0, 0, value)
        end
    end)

    -- Border Color Selector
    local colorLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", opacitySlider, "BOTTOMLEFT", 0, -40)
    colorLabel:SetText("Border Color:")
    
    -- Color Swatch (Clickable Button)
    local colorSwatch = CreateFrame("Button", nil, settings, "BackdropTemplate")
    colorSwatch:SetSize(200, 40)
    colorSwatch:SetPoint("LEFT", colorLabel, "RIGHT", 15, 0)
    
    colorSwatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    colorSwatch:SetBackdropColor(self.db.profile.borderColor.r, self.db.profile.borderColor.g, self.db.profile.borderColor.b, self.db.profile.borderColor.a)
    colorSwatch:SetBackdropBorderColor(1, 1, 1, 1)
    
    -- Text hint on button
    local btnText = colorSwatch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnText:SetPoint("CENTER")
    btnText:SetText("Click to Change Color")
    
    colorSwatch:SetScript("OnClick", function()
        if not Baggy.colorPicker then
            Baggy.colorPicker = Baggy:CreateColorPickerFrame()
        end
        Baggy.colorPicker:Setup()
        Baggy.colorPicker:Show()
    end)
    
    settings.swatch = colorSwatch
    
    settings:Hide()
    return settings
end
