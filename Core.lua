-----------------------------------------------------------
-- Baggy - Modern Glassy Bag Addon
-----------------------------------------------------------

local addonName, addonTable = ...
local Baggy = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceHook-3.0")

-- Libraries
local AceDB = LibStub("AceDB-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

-- Constants
local SLOTS_PER_ROW = 10
local SLOT_SIZE = 37
local SLOT_SPACING = 4
local PADDING = 15
local HEADER_SIZE = 60
local FOOTER_SIZE = 40

-- Main Frame
local BaggyFrame = nil
local SlotPool = {}
local containerItems = {}

-----------------------------------------------------------
-- Glass Design Helpers
-----------------------------------------------------------

local function ApplyGlassStyle(frame, alpha)
    if not frame.backdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
    end
    alpha = alpha or 0.5
    frame:SetBackdropColor(0, 0, 0, alpha)
    frame:SetBackdropBorderColor(0.6, 0.2, 0.8, 0.8) -- Purple Border

    -- Outer Glow (Simulated with a larger frame behind or shadow textures)
    if not frame.glow then
        -- Create glow as a child of the frame so it inherits visibility
        local glow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, 5)
        glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 5, -5)
        glow:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
        glow:SetBackdrop({
            edgeFile = "Interface\\GLOWS\\Gold_Glow", -- Using Blizzard glow texture
            edgeSize = 12,
        })
        glow:SetBackdropBorderColor(0.6, 0.2, 0.8, 0.5)
        frame.glow = glow
    end
end

local function ApplyOpaqueStyle(frame)
    if not frame.backdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
    end
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95) -- Nearly opaque dark background
    frame:SetBackdropBorderColor(0.6, 0.2, 0.8, 0.8) -- Purple Border

    -- Outer Glow
    if not frame.glow then
        local glow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, 5)
        glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 5, -5)
        glow:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
        glow:SetBackdrop({
            edgeFile = "Interface\\GLOWS\\Gold_Glow",
            edgeSize = 12,
        })
        glow:SetBackdropBorderColor(0.6, 0.2, 0.8, 0.5)
        frame.glow = glow
    end
end

-----------------------------------------------------------
-- Slot Handling
-----------------------------------------------------------

local function GetSlot(parent)
    local slot = tremove(SlotPool)
    if not slot then
        local slotID = #containerItems + 1
        -- Standard template needs a globally unique name for some internal Blizzard logic
        slot = CreateFrame("ItemButton", "BaggyItemButton"..slotID, parent, "ContainerFrameItemButtonTemplate")
    end
    slot:SetParent(parent)
    slot:Show()
    return slot
end


local function ReleaseSlot(slot)
    slot:Hide()
    slot:ClearAllPoints()
    tinsert(SlotPool, slot)
end

-----------------------------------------------------------
-- Update Function
-----------------------------------------------------------

local BagFrames = {}

function Baggy:UpdateBags()
    if not BaggyFrame or not BaggyFrame:IsShown() then return end

    local COLS = self.db.profile.slotsPerRow
    local slotSize = self.db.profile.slotSize
    local items = {}
    local bags = {0, 1, 2, 3, 4, 5}

    for _, bagID in ipairs(bags) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots > 0 then
            for slotID = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bagID, slotID)
                tinsert(items, { bagID = bagID, slotID = slotID, info = info })
            end
        end
    end

    local numItems = #items
    local numRows = math.ceil(numItems / COLS)
    
    local width = (COLS * slotSize) + ((COLS - 1) * SLOT_SPACING) + (PADDING * 2)
    local height = (numRows * slotSize) + ((numRows - 1) * SLOT_SPACING) + PADDING + HEADER_SIZE + FOOTER_SIZE
    BaggyFrame:SetSize(width, height)

    if not self.slots then self.slots = {} end
    
    for i, data in ipairs(items) do
        local row = math.floor((i - 1) / COLS)
        local col = (i - 1) % COLS

        local slot = self.slots[i]
        if not slot then
            -- Create a raw ItemButton to avoid Blizzard's template logic
            slot = CreateFrame("ItemButton", "BaggySlot"..i, BaggyFrame, "BackdropTemplate")
            slot:SetSize(slotSize, slotSize)
            
            -- Glass Slot Look
            slot:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            slot:SetBackdropColor(1, 1, 1, 0.05)
            slot:SetBackdropBorderColor(1, 1, 1, 0.1)
            
            -- Icon Texture
            slot.icon = slot:CreateTexture(nil, "ARTWORK")
            slot.icon:SetAllPoints()
            slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Zoom in to hide blizzard borders
            
            -- Count Text
            slot.count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            slot.count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
            
            -- Border/Quality - Create a frame overlay for quality border
            slot.qualityBorder = CreateFrame("Frame", nil, slot, "BackdropTemplate")
            slot.qualityBorder:SetAllPoints(slot)
            slot.qualityBorder:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            slot.qualityBorder:SetFrameLevel(slot:GetFrameLevel() + 1)
            slot.qualityBorder:Hide()
            
            -- Scripts for interaction
            slot:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetBagItem(self.bagID, self.slotID)
                GameTooltip:Show()
            end)
            slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- Enable all mouse buttons
            slot:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
            slot:RegisterForDrag("LeftButton")
            
            -- Pick up item when mouse is pressed down
            slot:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" then
                    C_Container.PickupContainerItem(self.bagID, self.slotID)
                end
            end)
            
            -- Drop item when dragged to this slot
            slot:SetScript("OnReceiveDrag", function(self)
                C_Container.PickupContainerItem(self.bagID, self.slotID)
            end)
            
            -- Handle clicks
            slot:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    C_Container.UseContainerItem(self.bagID, self.slotID)
                end
            end)

            self.slots[i] = slot
        end
        
        slot.bagID = data.bagID
        slot.slotID = data.slotID
        
        slot:ClearAllPoints()
        slot:SetSize(slotSize, slotSize)
        slot:SetPoint("TOPLEFT", BaggyFrame, "TOPLEFT", 
            PADDING + (col * (slotSize + SLOT_SPACING)), 
            -(HEADER_SIZE + (row * (slotSize + SLOT_SPACING))))
        
        slot:Show()
        
        -- Update Content
        if data.info then
            slot.icon:SetTexture(data.info.iconFileID)
            slot.icon:SetAlpha(1)
            if data.info.stackCount > 1 then
                slot.count:SetText(data.info.stackCount)
            else
                slot.count:SetText("")
            end
            
            if self.db.profile.showQualityBorder and data.info.quality and data.info.quality > 1 then
                local r, g, b = C_Item.GetItemQualityColor(data.info.quality)
                slot.qualityBorder:SetBackdropBorderColor(r, g, b, 0.6)
                slot.qualityBorder:Show()
            else
                slot.qualityBorder:Hide()
            end
        else
            slot.icon:SetTexture(nil)
            slot.icon:SetAlpha(0)
            slot.count:SetText("")
            slot.qualityBorder:Hide()
        end
    end

    for i = numItems + 1, #self.slots do
        if self.slots[i] then self.slots[i]:Hide() end
    end
end








-----------------------------------------------------------
-- Search Logic
-----------------------------------------------------------

function Baggy:UpdateSearch(text)
    if not text or text == "" then
        for _, slot in ipairs(containerItems) do
            slot:SetAlpha(1)
            slot:EnableMouse(true)
        end
        return
    end

    text = text:lower()
    for _, slot in ipairs(containerItems) do
        local bagID = slot:GetParent():GetID()
        local slotID = slot:GetID()
        local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)

        
        local match = false
        if itemInfo and itemInfo.hyperlink then
            local itemName = C_Item.GetItemInfo(itemInfo.hyperlink)
            if itemName and itemName:lower():find(text, 1, true) then
                match = true
            end
        end

        if match then
            slot:SetAlpha(1)
            slot:EnableMouse(true)
        else
            slot:SetAlpha(0.2)
            slot:EnableMouse(false)
        end
    end
end

-----------------------------------------------------------
-- Settings UI
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
    
    ApplyOpaqueStyle(settings)
    
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

-----------------------------------------------------------
-- UI Construction
-----------------------------------------------------------

function Baggy:CreateFrame()
    local frame = CreateFrame("Frame", "BaggyMainFrame", UIParent, "BackdropTemplate")
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")


    ApplyGlassStyle(frame, self.db.profile.bagOpacity)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -15)
    title:SetText("Baggy")
    title:SetTextColor(0.8, 0.4, 1, 1) -- Purple Title

    -- Capture Key Bindings
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    
    -- Visibility logic
    frame:SetScript("OnShow", function()
        Baggy:UpdateBags()
        if ContainerFrameCombinedBags then ContainerFrameCombinedBags:Hide() end
        for i = 1, 10 do
            local f = _G["ContainerFrame"..i]
            if f then f:Hide() end
        end
    end)

    local searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -70, -12)
    searchBox:SetSize(150, 20)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        Baggy:UpdateSearch(self:GetText())
    end)

    -- Settings Button
    local settingsBtn = CreateFrame("Button", nil, frame)
    settingsBtn:SetSize(24, 24)
    settingsBtn:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    
    -- Use custom TGA icon from assets folder
    local normalTex = settingsBtn:CreateTexture(nil, "ARTWORK")
    normalTex:SetAllPoints()
    normalTex:SetTexture("Interface\\AddOns\\Baggy\\assets\\settings")
    normalTex:SetTexCoord(0.05, 0.95, 0.05, 0.95) -- Crop edges slightly for cleaner look
    
    local highlightTex = settingsBtn:CreateTexture(nil, "HIGHLIGHT")
    highlightTex:SetAllPoints()
    highlightTex:SetTexture("Interface\\AddOns\\Baggy\\assets\\settings")
    highlightTex:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    highlightTex:SetAlpha(0.5)
    highlightTex:SetBlendMode("ADD")
    
    settingsBtn:SetScript("OnClick", function()
        if not Baggy.settingsFrame then
            Baggy.settingsFrame = Baggy:CreateSettingsFrame()
        end
        if Baggy.settingsFrame:IsShown() then
            Baggy.settingsFrame:Hide()
        else
            Baggy.settingsFrame:Show()
        end
    end)


    -- Close Button
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    -- Money Frame
    local money = CreateFrame("Frame", "BaggyMoneyFrame", frame, "SmallMoneyFrameTemplate")
    money:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    MoneyFrame_SetType(money, "PLAYER")


    C_Timer.NewTicker(0.2, function()
        if BaggyFrame and BaggyFrame:IsShown() then
            -- Force hide blizzard containers if they pop up (e.g. at vendors)
            if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then 
                ContainerFrameCombinedBags:Hide() 
            end
            for i = 1, 10 do
                local f = _G["ContainerFrame"..i]
                if f and f:IsShown() then f:Hide() end
            end
        end
    end)


    frame:Hide()
    BaggyFrame = frame
end



-----------------------------------------------------------
-- Toggles and Hooks
-----------------------------------------------------------

function Baggy:Toggle()
    if BaggyFrame:IsShown() then
        BaggyFrame:Hide()
    else
        BaggyFrame:Show()
    end
end
function Baggy:OnEnable()
    -- Wait a bit after Enable to ensure we overwrite Blizzard's functions
    C_Timer.After(1, function()
        ToggleAllBags = function() self:Toggle() end
        ToggleBackpack = ToggleAllBags
        OpenAllBags = function() if not BaggyFrame:IsShown() then self:Toggle() end end
        OpenBackpack = OpenAllBags
        
        -- Hook bag bar buttons for clicks
        local bagButtons = {
            MainMenuBarBackpackButton,
            CharacterBag0Slot, CharacterBag1Slot, CharacterBag2Slot, CharacterBag3Slot,
            CharacterReagentBag0Slot
        }
        for _, btn in ipairs(bagButtons) do
            if btn then
                btn:SetScript("OnClick", function() self:Toggle() end)
            end
        end

        -- Hook the combined bag frame if it exists
        if ContainerFrameCombinedBags then
            self:RawHook(ContainerFrameCombinedBags, "Show", function() 
                ContainerFrameCombinedBags:Hide()
                if not BaggyFrame:IsShown() then self:Toggle() end
            end, true)
        end

        print("|cFF00FF00Baggy:|r Late Hooks applied.")
    end)
    
    print("|cFF00FF00Baggy:|r Enabled.")
end



function Baggy:OnInitialize()
    print("|cFF00FF00Baggy:|r OnInitialize called")

    self.db = AceDB:New("BaggyDB", {
        profile = {
            minimap = { hide = false },
            slotSize = 37,
            slotsPerRow = 18,
            showQualityBorder = true,
            bagOpacity = 0.5,
        },
    }, "Default")

    self:CreateFrame()
    print("|cFF00FF00Baggy:|r Frame created")

    -- Events
    self:RegisterEvent("BAG_UPDATE", "UpdateBags")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "UpdateBags")
    
    -- Slash Command for debugging
    SLASH_BAGGY1 = "/baggy"
    SlashCmdList["BAGGY"] = function() self:Toggle() end
end



