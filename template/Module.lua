local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")


local passthrough = {
    __index = {
        RegisterCallback = ns.RegisterCallback,
        UnregisterCallback = ns.UnregisterCallback,
        UnregisterAllCallbacks = ns.UnregisterAllCallbacks,
        RegisterEvent = ns.RegisterEvent,
        RegisterEvents = ns.RegisterEvents,
        UnregisterEvent = ns.UnregisterEvent,
        UnregisterEvents = ns.UnregisterEvents,
        HookScript = ns.HookScript,
        Print = ns.Print,
        Debug = ns.Debug,
        InitDB = ns.InitDB,
        FlushDB = ns.FlushDB,
        AddTooltipLine = ns.AddTooltipLine,
    },
}
local modules = {}

function ns:NewModule(name)
    local mod = {
        name = name,
    }
    setmetatable(mod, passthrough)

    modules[name] = mod

    return mod
end
function ns:GetModule(name)
    return modules[name]
end
function ns:ModCall(event, ...)
    for name,mod in pairs(modules) do
        if mod[event] then
            mod[event](mod, ...)
        end
    end
end

function ns:ADDON_LOADED(event, addon)
    if addon ~= myname then return end

    self:ModCall("OnLoad")

    self:UnregisterEvent("ADDON_LOADED")
    self.ADDON_LOADED = nil

    if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
end
ns:RegisterEvent("ADDON_LOADED")

function ns:PLAYER_LOGIN()
    self:RegisterEvent("PLAYER_LOGOUT")

    self:ModCall("OnLogin")

    self:UnregisterEvent("PLAYER_LOGIN")
    self.PLAYER_LOGIN = nil
end

function ns:PLAYER_LOGOUT()
    self:ModCall("OnLogout")
    self:ModCall("FlushDB")
end
