-----------------------------------------------------------
-- Baggy - Modern Glassy Bag Addon
-----------------------------------------------------------

local addonName, addonTable = ...
local Baggy = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceHook-3.0")

-- Libraries
local AceDB = LibStub("AceDB-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

-- Constants (loaded from Settings.lua)
local SLOT_SPACING = 4  -- Keep local for now, will be referenced from Settings module
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

function Baggy:ApplyOpaqueStyle(frame)
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
            -- Create a SecureActionButton for native right-click handling without overlays
            slot = CreateFrame("Button", "BaggySlot"..i, BaggyFrame, "SecureActionButtonTemplate, BackdropTemplate")
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
            
            -- Setup Secure Button Attributes
            slot:RegisterForClicks("AnyUp")
            slot:RegisterForDrag("LeftButton")
            
            -- Right-Click: Secure Item Use (type2)
            slot:SetAttribute("type2", "item")
            
            -- Left-Click: Manual Handling (type1 = nil)
            slot:SetAttribute("type1", nil)
            
            -- Drag Support
            slot:SetScript("OnDragStart", function(self)
                C_Container.PickupContainerItem(self.bagID, self.slotID)
            end)
            slot:SetScript("OnReceiveDrag", function(self)
                C_Container.PickupContainerItem(self.bagID, self.slotID)
            end)
            
            -- Manual Click Handler (Left-Click Only) using PreClick
            -- We use PreClick instead of OnClick to not overwrite the SecureActionButton's internal handler
            slot:SetScript("PreClick", function(self, button)
                if button == "LeftButton" then
                    local itemLink = C_Container.GetContainerItemLink(self.bagID, self.slotID)
                    
                    -- Check cursor for drop
                    if GetCursorInfo() then
                        C_Container.PickupContainerItem(self.bagID, self.slotID)
                        return
                    end
                    
                    -- Modifier & Normal Click
                    if itemLink and IsModifiedClick() then
                        HandleModifiedItemClick(itemLink)
                    else
                        C_Container.PickupContainerItem(self.bagID, self.slotID)
                    end
                end
                -- Right-click falls through to SecureActionButton logic (type2=macro)
            end)

            self.slots[i] = slot
        end
        
        -- Update Secure Attributes and IDs
        slot.bagID = data.bagID
        slot.slotID = data.slotID
        
        -- Use Macro for reliable item usage (/use bagID slotID)
        -- This works better than type=item for container slots
        if not InCombatLockdown() then
            slot:SetAttribute("type2", "macro")
            slot:SetAttribute("macrotext2", "/use " .. data.bagID .. " " .. data.slotID)
        end
        
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
-- Settings UI (moved to Settings.lua)
-----------------------------------------------------------
-- The CreateSettingsFrame function is now defined in Settings.lua

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
        -- Close all Blizzard bags before showing Baggy
        CloseAllBags()
        
        -- Show Baggy
        BaggyFrame:Show()
    end
end
function Baggy:OnEnable()
    -- No hooks to Blizzard functions - let B key work normally
    -- Baggy is accessible via minimap icon or /baggy command
    print("|cFF00FF00Baggy:|r Enabled. Click the minimap icon to open Baggy, or use /baggy command.")
end



function Baggy:OnInitialize()
    print("|cFF00FF00Baggy:|r OnInitialize called")

    -- Initialize database with defaults from Settings module
    self.db = AceDB:New("BaggyDB", self.DB_DEFAULTS, "Default")

    self:CreateFrame()
    print("|cFF00FF00Baggy:|r Frame created")

    -- Create LibDataBroker object
    local BaggyLDB = LDB:NewDataObject("Baggy", {
        type = "launcher",
        text = "Baggy",
        icon = "Interface\\Icons\\INV_Misc_Bag_08", -- Purple bag icon
        OnClick = function(self, button)
            if button == "LeftButton" then
                Baggy:Toggle()
            elseif button == "RightButton" then
                -- Right click opens settings
                if not Baggy.settingsFrame then
                    Baggy.settingsFrame = Baggy:CreateSettingsFrame()
                end
                if Baggy.settingsFrame:IsShown() then
                    Baggy.settingsFrame:Hide()
                else
                    Baggy.settingsFrame:Show()
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cFF9966FFBaggy|r")
            tooltip:AddLine("|cFFFFFFFFLeft-click:|r Toggle bags")
            tooltip:AddLine("|cFFFFFFFFRight-click:|r Settings")
        end,
    })

    -- Register minimap icon
    LDBIcon:Register("Baggy", BaggyLDB, self.db.profile.minimap)

    -- Events
    self:RegisterEvent("BAG_UPDATE", "UpdateBags")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "UpdateBags")
    
    -- Slash Command for debugging
    SLASH_BAGGY1 = "/baggy"
    SlashCmdList["BAGGY"] = function() self:Toggle() end
    
    print("|cFF00FF00Baggy:|r Minimap icon created. Left-click to toggle bags, right-click for settings.")
end



