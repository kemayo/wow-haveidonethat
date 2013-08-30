local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

HIDT = ns

local core = ns:NewModule("core")

core.defaults = {
    achievements = true,
    done_achievements = true,
    done_criteria = true,
    commendations = true,
}
core.defaultsPC = {}

function core:OnLoad()
    self:InitDB()
    LibStub("tekKonfig-AboutPanel").new(myfullname, myname) -- Make first arg nil if no parent config panel
end
