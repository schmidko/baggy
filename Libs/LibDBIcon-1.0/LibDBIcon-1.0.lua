--- **LibDBIcon-1.0** creates minimap icons.
-- @class file
-- @name LibDBIcon-1.0.lua

local MAJOR, MINOR = "LibDBIcon-1.0", 52
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.notCreated = lib.notCreated or {}

local next, Minimap, CreateFrame = next, Minimap, CreateFrame
local math_sin, math_cos = math.sin, math.cos

local function getAnchors(frame)
    local x, y = frame:GetCenter()
    if not x or not y then return "CENTER" end
    local xFrom, xTo = "", ""
    local yFrom, yTo = "", ""
    if y > _G.UIParent:GetHeight() / 2 then
        yFrom = "TOP"
        yTo = "BOTTOM"
    else
        yFrom = "BOTTOM"
        yTo = "TOP"
    end
    if x > _G.UIParent:GetWidth() / 2 then
        xFrom = "RIGHT"
        xTo = "LEFT"
    else
        xFrom = "LEFT"
        xTo = "RIGHT"
    end
    return yFrom..xFrom, yTo..xTo
end

local function onEnter(self)
    if self.isMoving then return end
    local obj = self.dataObject
    if obj.OnTooltipShow then
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        local from, to = getAnchors(self)
        GameTooltip:SetPoint(from, self, to)
        obj.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    elseif obj.OnEnter then
        obj.OnEnter(self)
    end
end

local function onLeave(self)
    local obj = self.dataObject
    GameTooltip:Hide()
    if obj.OnLeave then
        obj.OnLeave(self)
    end
end

local function onClick(self, button)
    local obj = self.dataObject
    if obj.OnClick then
        obj.OnClick(self, button)
    end
end

local function onDragStart(self)
    self.isMoving = true
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.atan2(py - my, px - mx)
        local radius = self.db and self.db.radius or 80
        local x = math_cos(angle) * radius
        local y = math_sin(angle) * radius
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", x, y)
        if self.db then
            self.db.minimapPos = math.deg(angle)
        end
    end)
end

local function onDragStop(self)
    self.isMoving = false
    self:SetScript("OnUpdate", nil)
end

local function updatePosition(button, db)
    local angle = math.rad(db.minimapPos or 225)
    local radius = db.radius or 80
    local x = math_cos(angle) * radius
    local y = math_sin(angle) * radius
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function lib:Register(name, obj, db)
    if not obj then
        error("LibDBIcon-1.0: No dataobject provided.", 2)
    end

    if not db then db = {} end
    if not db.minimapPos then db.minimapPos = 225 end
    if not db.radius then db.radius = 80 end

    local button = CreateFrame("Button", "LibDBIcon10_"..name, Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture(136477) -- Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(50, 50)
    overlay:SetTexture(136430) -- Interface\\Minimap\\MiniMap-TrackingBorder
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetTexture(136467) -- Interface\\Minimap\\UI-Minimap-Background
    background:SetPoint("CENTER", button, "CENTER", 0, 1)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", button, "CENTER", 0, 1)
    icon:SetTexture(obj.icon)

    button.icon = icon
    button.dataObject = obj
    button.db = db

    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", onLeave)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnDragStart", onDragStart)
    button:SetScript("OnDragStop", onDragStop)

    lib.objects[name] = button
    updatePosition(button, db)

    if db.hide then
        button:Hide()
    else
        button:Show()
    end
end

function lib:Show(name)
    if lib.objects[name] then
        lib.objects[name]:Show()
    end
end

function lib:Hide(name)
    if lib.objects[name] then
        lib.objects[name]:Hide()
    end
end

function lib:IsRegistered(name)
    return lib.objects[name] and true or false
end

function lib:GetMinimapButton(name)
    return lib.objects[name]
end
