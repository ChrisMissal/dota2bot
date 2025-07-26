local Logger = {}

if DecisionLog == nil then
    DecisionLog = { enable = false }
end

local last = {}

function Logger.Log(hero, msg)
    if not DecisionLog.enable or hero == nil or msg == nil then return end
    local id = hero:entindex()
    if last[id] == msg then return end
    local name = string.gsub(hero:GetUnitName(), 'npc_dota_hero_', '')
    GameRules:SendCustomMessage('[Bot] '..name..': '..msg, 0, 0)
    last[id] = msg
end

return Logger
