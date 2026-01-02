-----------------------------------------------------------
-- Baggy - Classic Design Module
-- "Classic" styling mimicking original WoW bags
-----------------------------------------------------------

local addonName, addonTable = ...
local Baggy = LibStub("AceAddon-3.0"):GetAddon(addonName)

-- Local Constants
local SLOT_SIZE = 37
local SLOT_SPACING = 2 -- Tighter spacing for classic look
local PADDING = 10
local HEADER_SIZE = 60
local FOOTER_SIZE = 30

-- State
local ClassicFrame = nil
local SlotPool = {}
local ClassicSlots = {}

-----------------------------------------------------------
-- Slot Handling (Independent pool)
-----------------------------------------------------------

local function GetSlot(parent)
    local slot = tremove(SlotPool)
    if not slot then
        local slotID = #ClassicSlots + 1
        -- Use standard ContainerFrameItemButtonTemplate
        slot = CreateFrame("ItemButton", "BaggyClassicItemButton"..slotID, parent, "ContainerFrameItemButtonTemplate")
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
-- Main Update Logic
-----------------------------------------------------------

function Baggy:UpdateClassicBags()
    if not ClassicFrame or not ClassicFrame:IsShown() then return end

    local COLS = self.db.profile.slotsPerRow
    -- Use fixed size for classic or allow scaling?
    -- User said "same functions", so we should respect slot size settings if possible, 
    -- but "Classic" might imply fixed blizzard size (37). 
    -- Let's use the settings but default to standard look.
    local slotSize = self.db.profile.slotSize or 37
    
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
    
    ClassicFrame:SetSize(width, height)

    -- Ensure we have enough slots
    for i = 1, numItems do
        if not ClassicSlots[i] then
            local slot = CreateFrame("ItemButton", "BaggyClassicSlot"..i, ClassicFrame, "ContainerFrameItemButtonTemplate")
            -- We reuse the template, but we need to ensure secure click works
            -- ContainerFrameItemButtonTemplate inherits ItemButtonTemplate which has some logic, 
            -- but for full bag interaction we might need specific attributes or scripts similar to Core.lua
            -- The user wants "same functions".
            
            -- Re-implementing secure logic similar to Core.lua for consistency
            slot:RegisterForClicks("AnyUp")
            slot:RegisterForDrag("LeftButton")
            slot:SetAttribute("type2", "item") -- Default
            slot:SetAttribute("type1", nil)
            
            slot:SetScript("OnDragStart", function(self)
                C_Container.PickupContainerItem(self.bagID, self.slotID)
            end)
            
            slot:SetScript("OnReceiveDrag", function(self)
                C_Container.PickupContainerItem(self.bagID, self.slotID)
            end)
            
            slot:SetScript("PreClick", function(self, button)
                 if button == "LeftButton" then
                    local itemLink = C_Container.GetContainerItemLink(self.bagID, self.slotID)
                    if GetCursorInfo() then
                        C_Container.PickupContainerItem(self.bagID, self.slotID)
                        return
                    end
                    if itemLink and IsModifiedClick() then
                        HandleModifiedItemClick(itemLink)
                    else
                        C_Container.PickupContainerItem(self.bagID, self.slotID)
                    end
                 end
            end)
            
            slot:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetBagItem(self.bagID, self.slotID)
                GameTooltip:Show()
                -- Explicitly manage highlight to ensure only hover shows it
                if self.GetHighlightTexture then
                    self:GetHighlightTexture():SetAlpha(1)
                end
            end)
            slot:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                if self.GetHighlightTexture then
                    self:GetHighlightTexture():SetAlpha(0)
                end
            end)

            -- Hide template extras that might cause persistent glowing
            if slot.NewItemTexture then slot.NewItemTexture:Hide() end
            if slot.flash then slot.flash:Hide() end
            if slot.SearchOverlay then slot.SearchOverlay:Hide() end
            if slot.ExtendedSlot then slot.ExtendedSlot:Hide() end
            if slot.ItemContextOverlay then slot.ItemContextOverlay:Hide() end
            if slot.BattlepayItemTexture then slot.BattlepayItemTexture:Hide() end
            
            -- Replace the glowing NormalTexture with a simple slot border
            local normalTex = slot:GetNormalTexture()
            if normalTex then
                normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                normalTex:SetTexCoord(0, 1, 0, 1)
            end
            
            -- Ensure highlight is invisible by default
            if slot.GetHighlightTexture and slot:GetHighlightTexture() then
                slot:GetHighlightTexture():SetAlpha(0)
            end

            ClassicSlots[i] = slot
        end
        
        local slot = ClassicSlots[i]
        local data = items[i]
        local row = math.floor((i - 1) / COLS)
        local col = (i - 1) % COLS
        
        slot.bagID = data.bagID
        slot.slotID = data.slotID
        
        if not InCombatLockdown() then
             slot:SetAttribute("type2", "macro")
             slot:SetAttribute("macrotext2", "/use " .. data.bagID .. " " .. data.slotID)
        end
        
        slot:ClearAllPoints()
        slot:SetSize(slotSize, slotSize)
        slot:SetPoint("TOPLEFT", ClassicFrame, "TOPLEFT", 
            PADDING + (col * (slotSize + SLOT_SPACING)), 
            -(HEADER_SIZE + (row * (slotSize + SLOT_SPACING))))
            
        slot:Show()
        
        -- Update Visuals
        SetItemButtonTexture(slot, data.info and data.info.iconFileID or nil)
        SetItemButtonCount(slot, data.info and data.info.stackCount or 0)
        SetItemButtonDesaturated(slot, false) -- Reset dimming
        
        -- Quality Border (Blizzard Default Style)
        if data.info and data.info.quality and data.info.quality > 1 then
             SetItemButtonQuality(slot, data.info.quality, data.info.hyperlink)
        else
             SetItemButtonQuality(slot, nil)
        end
        
        -- Reset Alpha from Search
        slot:SetAlpha(1)
    end
    
    -- Hide extra slots
    for i = numItems + 1, #ClassicSlots do
        ClassicSlots[i]:Hide()
    end
end

-----------------------------------------------------------
-- Search Logic
-----------------------------------------------------------

function Baggy:UpdateClassicSearch(text)
    if not ClassicFrame or not ClassicFrame:IsShown() then return end
    
    if not text or text == "" then
        for _, slot in ipairs(ClassicSlots) do
            slot:SetAlpha(1)
            SetItemButtonDesaturated(slot, false)
        end
        return
    end
    
    text = text:lower()
    
    for _, slot in ipairs(ClassicSlots) do
        if slot:IsShown() then
            local match = false
            if slot.bagID and slot.slotID then
                local info = C_Container.GetContainerItemInfo(slot.bagID, slot.slotID)
                if info and info.hyperlink then
                    local name = C_Item.GetItemInfo(info.hyperlink)
                    if name and name:lower():find(text, 1, true) then
                        match = true
                    end
                end
            end
            
            if match then
                slot:SetAlpha(1)
                SetItemButtonDesaturated(slot, false)
            else
                slot:SetAlpha(0.3)
                SetItemButtonDesaturated(slot, true)
            end
        end
    end
end


-----------------------------------------------------------
-- Frame Construction
-----------------------------------------------------------

function Baggy:CreateClassicFrame()
    -- Use BasicFrameTemplateWithInset for a standard window without a portrait
    local frame = CreateFrame("Frame", "BaggyClassicFrame", UIParent, "BasicFrameTemplateWithInset")
    
    -- Remove portrait hacks as we changed template
    
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    
    -- Standard Title
    if frame.SetTitle then
        frame:SetTitle("Baggy")
    end
    
    -- Note: We rely on the frame's OnDragStart for movement, so we don't need
    -- to add specific scripts to the title region unless we can safely identify it.

    
    -- Background
    -- PortraitFrameTemplate handles the background and border (standard UI)
    -- We just need to handle content background if needed or leave as is.
    
    -- Settings Toggle (Settings Button) at the top right
    local settingsBtn = CreateFrame("Button", "BaggyClassicSettingsButton", frame, "UIPanelButtonTemplate")
    settingsBtn:SetSize(22, 22)
    settingsBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -28)
    
    local gearIcon = settingsBtn:CreateTexture(nil, "ARTWORK")
    gearIcon:SetTexture("Interface\\AddOns\\Baggy\\assets\\settings")
    gearIcon:SetAllPoints()
    gearIcon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    settingsBtn:SetNormalTexture(gearIcon)
    
    settingsBtn:SetScript("OnClick", function()
        if not Baggy.settingsFrame then
             Baggy.settingsFrame = Baggy:CreateSettingsFrame()
        end
        Baggy.settingsFrame:SetShown(not Baggy.settingsFrame:IsShown())
    end)

    -- Search Box to the left of the settings button
    local searchBox = CreateFrame("EditBox", "BaggyClassicSearchBox", frame, "BagSearchBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("RIGHT", settingsBtn, "LEFT", -8, 0)
    searchBox:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        Baggy:UpdateClassicSearch(self:GetText())
    end)
    
    -- Money Frame
    local money = CreateFrame("Frame", "BaggyClassicMoneyFrame", frame, "SmallMoneyFrameTemplate")
    money:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 8)
    MoneyFrame_SetType(money, "PLAYER")
    
    -- Events
    frame:SetScript("OnShow", function()
        Baggy:UpdateClassicBags()
    end)
    
    ClassicFrame = frame
    self.ClassicFrame = frame
    tinsert(UISpecialFrames, "BaggyClassicFrame")
    
    return frame
end
