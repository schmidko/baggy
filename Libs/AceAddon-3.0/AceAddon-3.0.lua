--- **AceAddon-3.0** provides a template for creating addon objects.
-- @class file
-- @name AceAddon-3.0.lua

local MAJOR, MINOR = "AceAddon-3.0", 13
local AceAddon, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceAddon then return end

AceAddon.frame = AceAddon.frame or CreateFrame("Frame", "AceAddon30Frame")
AceAddon.addons = AceAddon.addons or {}
AceAddon.statuses = AceAddon.statuses or {}
AceAddon.initializequeue = AceAddon.initializequeue or {}
AceAddon.enablequeue = AceAddon.enablequeue or {}

local tinsert, tconcat, tremove = table.insert, table.concat, table.remove
local fmt = string.format
local pairs, next, type, unpack = pairs, next, type, unpack
local loadstring, assert, error = loadstring, assert, error
local setmetatable, getmetatable, rawset, rawget = setmetatable, getmetatable, rawset, rawget

local function errorhandler(err)
    return geterrorhandler()(err)
end

local function safecall(func, ...)
    if type(func) == "function" then
        return xpcall(func, errorhandler, ...)
    end
end

local Dispatchers = {}
local function CreateDispatcher(argCount)
    local funcs = {}
    for i = 1, argCount do funcs[i] = "a"..i end
    local code = [[
        local next, xpcall, eh = ...
        return function(handlers, ]] .. tconcat(funcs, ", ") .. [[)
            for k, v in next, handlers do
                xpcall(v, eh, ]] .. tconcat(funcs, ", ") .. [[)
            end
        end
    ]]
    return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(next, xpcall, errorhandler)
end

function AceAddon:NewAddon(objectorname, ...)
    local object, name
    local i = 1

    if type(objectorname) == "table" then
        object = objectorname
        name = ...
        i = 2
    else
        name = objectorname
    end

    if type(name) ~= "string" then
        error(("Usage: NewAddon([object,] name, [lib, ...]): 'name' - string expected got '%s'."):format(type(name)), 2)
    end
    if self.addons[name] then
        error(("Usage: NewAddon([object,] name, [lib, ...]): 'name' - Addon '%s' already exists."):format(name), 2)
    end

    object = object or {}
    object.name = name

    local addonmeta = {}
    local oldmeta = getmetatable(object)
    if oldmeta then
        for k, v in pairs(oldmeta) do addonmeta[k] = v end
    end
    addonmeta.__tostring = addonmeta.__tostring or function() return name end

    setmetatable(object, addonmeta)

    self.addons[name] = object
    object.modules = {}
    object.orderedModules = {}
    object.defaultModuleLibraries = {}

    Embed(object)
    self:EmbedLibraries(object, select(i, ...))

    tinsert(self.initializequeue, object)

    return object
end

function Embed(target)
    for k, v in pairs(AceAddon) do
        if type(v) == "function" and k ~= "NewAddon" and k ~= "GetAddon" and k ~= "IterateAddons" then
            target[k] = v
        end
    end
end

function AceAddon:EmbedLibraries(target, ...)
    for i = 1, select("#", ...) do
        local libname = select(i, ...)
        self:EmbedLibrary(target, libname, false, 4)
    end
end

function AceAddon:EmbedLibrary(target, libname, silent, offset)
    local lib = LibStub:GetLibrary(libname, true)
    if not lib and not silent then
        error(("Usage: EmbedLibrary(target, libname, silent, offset): 'libname' - Cannot find a library instance of %q."):format(tostring(libname)), offset or 2)
    elseif lib and type(lib.Embed) == "function" then
        lib:Embed(target)
    end
end

function AceAddon:GetAddon(name, silent)
    if not silent and not self.addons[name] then
        error(("Usage: GetAddon(name): 'name' - Cannot find an AceAddon '%s'."):format(tostring(name)), 2)
    end
    return self.addons[name]
end

function AceAddon:IterateAddons() return pairs(self.addons) end
function AceAddon:IterateAddonStatus() return pairs(self.statuses) end

local function InitializeAddon(addon)
    safecall(addon.OnInitialize, addon)
    AceAddon.statuses[addon.name] = true
end

local function EnableAddon(addon)
    if AceAddon.statuses[addon.name] then
        safecall(addon.OnEnable, addon)
    end
end

function AceAddon:InitializeAddon(addon)
    InitializeAddon(addon)
end

function AceAddon:EnableAddon(addon)
    EnableAddon(addon)
end

local function OnEvent(this, event, arg1)
    if event == "ADDON_LOADED" then
        for i = #AceAddon.initializequeue, 1, -1 do
            local addon = AceAddon.initializequeue[i]
            if IsAddOnLoaded(addon.name) or IsAddOnLoaded("Baggy") then
                InitializeAddon(addon)
                tremove(AceAddon.initializequeue, i)
                tinsert(AceAddon.enablequeue, addon)
            end
        end
    elseif event == "PLAYER_LOGIN" then
        for i, addon in ipairs(AceAddon.enablequeue) do
            EnableAddon(addon)
        end
        wipe(AceAddon.enablequeue)
    end
end

AceAddon.frame:RegisterEvent("ADDON_LOADED")
AceAddon.frame:RegisterEvent("PLAYER_LOGIN")
AceAddon.frame:SetScript("OnEvent", OnEvent)
