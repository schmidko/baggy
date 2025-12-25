--- **LibDataBroker-1.1** provides a data broker framework.
-- @class file
-- @name LibDataBroker-1.1.lua

assert(LibStub, "LibDataBroker-1.1 requires LibStub")

local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4)
if not lib then return end

lib.callbacks = lib.callbacks or LibStub:GetLibrary("CallbackHandler-1.0"):New(lib)
lib.attributestorage = lib.attributestorage or {}
lib.namestorage = lib.namestorage or {}
lib.proxystorage = lib.proxystorage or {}

local attributestorage = lib.attributestorage
local namestorage = lib.namestorage
local proxystorage = lib.proxystorage
local callbacks = lib.callbacks

local domt = {
    __metatable = "access denied",
    __index = function(self, key) return attributestorage[self] and attributestorage[self][key] end,
}

function lib:NewDataObject(name, dataobject)
    if proxystorage[name] then return end

    if dataobject then
        assert(type(dataobject) == "table", "Invalid dataobject provided to NewDataObject, must be nil or a table.")
    end

    dataobject = dataobject or {}
    attributestorage[dataobject] = {}
    namestorage[dataobject] = name
    proxystorage[name] = dataobject

    for k, v in pairs(dataobject) do
        attributestorage[dataobject][k] = v
        dataobject[k] = nil
    end

    setmetatable(dataobject, domt)

    callbacks:Fire("LibDataBroker_DataObjectCreated", name, dataobject)

    return dataobject
end

function lib:GetDataObjectByName(name)
    return proxystorage[name]
end

function lib:GetNameByDataObject(dataobject)
    return namestorage[dataobject]
end

function lib:DataObjectIterator()
    return pairs(proxystorage)
end
