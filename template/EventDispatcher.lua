local myname, ns = ...

-- local events = {}
-- setmetatable(events, {
--     __index = function(t, i)
--         t[i] = {}
--         return t[i]
--     end,
-- })

local events = {}
ns.callbacks = LibStub("CallbackHandler-1.0"):New(events)
ns.RegisterCallback = events.RegisterCallback
ns.UnregisterCallback = events.UnregisterCallback
ns.UnregisterAllCallbacks = events.UnregisterAllCallbacks

local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...)
    ns.callbacks:Fire(event, ...)
    -- for i,handler in ipairs(events[event]) do
    --     if handler[event] then
    --         handler[event](handler, event, ...)
    --     end
    -- end
end)

function ns:RegisterEvent(...)
    for i=1,select("#", ...) do
        -- table.insert(events[select(i, ...)], ns)
        local event = select(i, ...)
        self:RegisterCallback(event)
        f:RegisterEvent(event)
    end
end
function ns:UnregisterEvent(...)
    for i=1,select("#", ...) do
        local event = select(i, ...)
        self:UnregisterCallback(event)
        -- local handlers = events[select(i, ...)]
        -- for ii=#handlers,1,-1 do
        --     if handlers[ii] == ns then
        --         table.remove(handlers, ii)
        --     end
        -- end
        -- events[select(i, ...)] = nil
        -- if #handlers == 0 then
        --     f:UnregisterEvent((select(i, ...)))
        -- end
    end
end
ns.RegisterEvents, ns.UnregisterEvents = ns.RegisterEvent, ns.UnregisterEvent

function ns:HookScript(frame, ...)
    for i=1,select('#', ...) do
        local script = select(i, ...)
        frame:HookScript(script, function(...) self[script](self, ...) end)
    end
end
