local myname, ns = ...

local function isEmpty(t)
    for k,v in pairs(t) do
        return false
    end
    return true
end
local function setDefaults(options, defaults)
    setmetatable(options, { __index = function(t, k)
        if type(defaults[k]) == "table" then
            t[k] = setDefaults({}, defaults[k])
            return t[k]
        end
        return defaults[k]
    end, })
    return options
end
local function cleanOptions(options, defaults)
    if not defaults then
        return
    end
    for k,v in pairs(defaults) do
        if options[k] == v then
            options[k] = nil
        end
        if type(options[k]) == "table" then
            cleanOptions(options[k], v)
            if isEmpty(options[k]) then
                options[k] = nil
            end
        end
    end
end

function ns:InitDB()
    _G[myname.."DB"] = _G[myname.."DB"] or {}
    _G[myname.."DB"][self.name] = setDefaults(_G[myname.."DB"][self.name] or {}, self.defaults)
    self.db = _G[myname.."DB"][self.name]

    _G[myname.."DBPC"] = _G[myname.."DBPC"] or {}
    _G[myname.."DBPC"][self.name] = setDefaults(_G[myname.."DBPC"][self.name] or {}, self.defaultsPC)
    self.dbpc = _G[myname.."DBPC"][self.name]
end

function ns:FlushDB()
    cleanOptions(self.db, self.defaults)
    cleanOptions(self.dbpc, self.defaultsPC)
end
