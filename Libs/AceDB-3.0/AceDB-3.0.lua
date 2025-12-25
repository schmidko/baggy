--- **AceDB-3.0** manages the SavedVariables for your addon.
-- @class file
-- @name AceDB-3.0.lua

local MAJOR, MINOR = "AceDB-3.0", 27
local AceDB = LibStub:NewLibrary(MAJOR, MINOR)

if not AceDB then return end

local type, pairs, next = type, pairs, next
local rawget, rawset = rawget, rawset
local setmetatable = setmetatable

local DBObjectLib = {}

local function copyTable(src, dest)
    if type(dest) ~= "table" then dest = {} end
    if type(src) == "table" then
        for k, v in pairs(src) do
            if type(v) == "table" then
                v = copyTable(v, dest[k])
            end
            dest[k] = v
        end
    end
    return dest
end

local function copyDefaults(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if not rawget(dest, k) then rawset(dest, k, {}) end
            if type(dest[k]) == "table" then
                copyDefaults(dest[k], v)
            end
        else
            if rawget(dest, k) == nil then
                rawset(dest, k, v)
            end
        end
    end
end

local function removeDefaults(db, defaults)
    if not defaults then return end
    for k, v in pairs(defaults) do
        if type(v) == "table" and type(db[k]) == "table" then
            if next(db[k]) ~= nil then
                removeDefaults(db[k], v)
                if next(db[k]) == nil then
                    db[k] = nil
                end
            else
                db[k] = nil
            end
        elseif db[k] == defaults[k] then
            db[k] = nil
        end
    end
end

function DBObjectLib:RegisterDefaults(defaults)
    if defaults and type(defaults) == "table" then
        if defaults.profile then
            copyDefaults(self.profile, defaults.profile)
        end
    end
end

function DBObjectLib:GetNamespace(name, silent)
    if not silent and not self.children then
        error("Usage: AceDBObject:GetNamespace(name): 'name' - namespace does not exist.", 2)
    end
    if not self.children then self.children = {} end
    return self.children[name]
end

local function initdb(sv, defaults, defaultProfile, olddb, parent)
    local db = olddb or {}

    if not sv then sv = {} end

    local profiles = sv.profiles or {}
    sv.profiles = profiles

    local profileKey = defaultProfile or "Default"
    if not profiles[profileKey] then profiles[profileKey] = {} end
    db.profile = profiles[profileKey]

    db.sv = sv
    db.profiles = profiles

    if defaults and defaults.profile then
        copyDefaults(db.profile, defaults.profile)
    end

    for k, v in pairs(DBObjectLib) do
        db[k] = v
    end

    return db
end

function AceDB:New(tbl, defaults, defaultProfile)
    if type(tbl) == "string" then
        local name = tbl
        tbl = _G[name]
        if not tbl then
            tbl = {}
            _G[name] = tbl
        end
    end

    local db = initdb(tbl, defaults, defaultProfile)
    return db
end
