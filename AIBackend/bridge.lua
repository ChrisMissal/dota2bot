local Config = require(GetScriptDirectory()..'/AIBackend/config')

local X = {}
local stateByPlayer = {}

local function Log(message)
	if Config.debug then
		print('[AIBackend] '..message)
	end
end

local function Number(value, fallback)
	if value == nil then return fallback end
	local n = tonumber(value)
	if n == nil then return fallback end
	return n
end

local function EscapeJson(value)
	value = tostring(value or '')
	value = string.gsub(value, '\\', '\\\\')
	value = string.gsub(value, '"', '\\"')
	value = string.gsub(value, '\n', '\\n')
	value = string.gsub(value, '\r', '\\r')
	return value
end

local function VectorJson(location)
	if location == nil then
		return '{"x":0,"y":0,"z":0}'
	end

	return string.format(
		'{"x":%.1f,"y":%.1f,"z":%.1f}',
		Number(location.x, 0),
		Number(location.y, 0),
		Number(location.z, 0)
	)
end

local function UnitJson(unit)
	local location = unit:GetLocation()
	local playerID = -1
	if unit:IsHero() then
		playerID = unit:GetPlayerID()
	end

	return string.format(
		'{"name":"%s","player_id":%d,"team":%d,"health":%d,"max_health":%d,"mana":%d,"max_mana":%d,"location":%s,"attack_range":%d,"is_hero":%s}',
		EscapeJson(unit:GetUnitName()),
		Number(playerID, -1),
		Number(unit:GetTeam(), -1),
		Number(unit:GetHealth(), 0),
		Number(unit:GetMaxHealth(), 0),
		Number(unit:GetMana(), 0),
		Number(unit:GetMaxMana(), 0),
		VectorJson(location),
		Number(unit:GetAttackRange(), 0),
		unit:IsHero() and 'true' or 'false'
	)
end

local function UnitListJson(units, limit)
	local parts = {}
	local count = 0
	for _, unit in pairs(units or {}) do
		if unit ~= nil and unit:IsAlive() and count < limit then
			count = count + 1
			parts[#parts + 1] = UnitJson(unit)
		end
	end

	return '['..table.concat(parts, ',')..']'
end

local function BuildSnapshot(bot)
	local target = bot:GetAttackTarget()
	local targetPlayerID = -1
	if target ~= nil and target:IsHero() then
		targetPlayerID = target:GetPlayerID()
	end

	local enemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local allyHeroes = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local enemyCreeps = bot:GetNearbyCreeps(900, true)

	return string.format(
		'{"bot_id":%d,"hero":"%s","team":%d,"time":%.2f,"game_time":%.2f,"mode":%d,"mode_desire":%.3f,"health":%d,"max_health":%d,"mana":%d,"max_mana":%d,"attack_range":%d,"location":%s,"attack_target_player_id":%d,"nearby_enemy_heroes":%s,"nearby_ally_heroes":%s,"nearby_enemy_creeps":%s}',
		Number(bot:GetPlayerID(), -1),
		EscapeJson(bot:GetUnitName()),
		Number(GetTeam(), -1),
		Number(DotaTime(), 0),
		Number(GameTime(), 0),
		Number(bot:GetActiveMode(), -1),
		Number(bot:GetActiveModeDesire(), 0),
		Number(bot:GetHealth(), 0),
		Number(bot:GetMaxHealth(), 0),
		Number(bot:GetMana(), 0),
		Number(bot:GetMaxMana(), 0),
		Number(bot:GetAttackRange(), 0),
		VectorJson(bot:GetLocation()),
		Number(targetPlayerID, -1),
		UnitListJson(enemyHeroes, Config.max_units_per_team),
		UnitListJson(allyHeroes, Config.max_units_per_team),
		UnitListJson(enemyCreeps, Config.max_units_per_team)
	)
end

local function ParseDecision(body)
	if body == nil or body == '' then
		return nil
	end

	local decision = {
		action = string.match(body, '"action"%s*:%s*"([^"]+)"'),
		target_player_id = Number(string.match(body, '"target_player_id"%s*:%s*(-?%d+)'), nil),
		x = Number(string.match(body, '"x"%s*:%s*(-?%d+%.?%d*)'), nil),
		y = Number(string.match(body, '"y"%s*:%s*(-?%d+%.?%d*)'), nil),
		z = Number(string.match(body, '"z"%s*:%s*(-?%d+%.?%d*)'), 0),
	}

	if decision.action == nil then
		return nil
	end

	return decision
end

local function GetState(playerID)
	if stateByPlayer[playerID] == nil then
		stateByPlayer[playerID] = {
			pending = false,
			last_request_time = -999,
			last_action_time = -999,
			decision = nil,
			decision_time = -999,
		}
	end

	return stateByPlayer[playerID]
end

local function IsControlled(bot)
	if not Config.enabled then return false end
	if bot == nil or not bot:IsHero() or bot:IsIllusion() or not bot:IsAlive() then return false end

	return Config.controlled_player_ids[bot:GetPlayerID()] == true
end

local function SendRequest(bot, state)
	if type(CreateHTTPRequest) ~= 'function' then
		return
	end

	local ok, request = pcall(function()
		return CreateHTTPRequest('POST', Config.endpoint)
	end)

	if not ok or request == nil then
		ok, request = pcall(function()
			return CreateHTTPRequest(Config.endpoint)
		end)
	end

	if not ok or request == nil then
		Log('failed to create HTTP request')
		return
	end

	local snapshot = BuildSnapshot(bot)
	local playerID = bot:GetPlayerID()

	if type(request.SetHTTPRequestGetOrPostParameter) == 'function' then
		request:SetHTTPRequestGetOrPostParameter('bot_id', tostring(playerID))
		request:SetHTTPRequestGetOrPostParameter('snapshot', snapshot)
	end

	state.pending = true
	state.last_request_time = DotaTime()

	local sent = pcall(function()
		request:Send(function(response)
			state.pending = false

			if response == nil then
				Log('empty response')
				return
			end

			local status = Number(response.StatusCode, 0)
			if status < 200 or status >= 300 then
				Log('HTTP status '..tostring(status))
				return
			end

			local decision = ParseDecision(response.Body)
			if decision == nil then
				Log('invalid decision body')
				return
			end

			state.decision = decision
			state.decision_time = DotaTime()
		end)
	end)

	if not sent then
		state.pending = false
		Log('failed to send HTTP request')
	end
end

local function FindEnemyHeroByPlayerID(playerID)
	if playerID == nil or playerID < 0 then return nil end

	local enemyHeroes = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	for _, enemy in pairs(enemyHeroes or {}) do
		if enemy ~= nil
		and enemy:IsAlive()
		and enemy:IsHero()
		and enemy:GetPlayerID() == playerID
		then
			return enemy
		end
	end

	return nil
end

local function ExecuteDecision(bot, state)
	local decision = state.decision
	if decision == nil then return false end
	if DotaTime() > state.decision_time + Config.response_stale_seconds then return false end
	if DotaTime() < state.last_action_time + Config.action_interval then return true end
	if bot:IsChanneling() or bot:GetAnimActivity() == ACTIVITY_ATTACK then return true end

	if decision.action == 'none' then
		return false
	end

	if decision.action == 'move_to_location' then
		if decision.x == nil or decision.y == nil then return false end
		bot:Action_MoveToLocation(Vector(decision.x, decision.y, decision.z))
		state.last_action_time = DotaTime()
		return true
	end

	if decision.action == 'attack_move' then
		if decision.x == nil or decision.y == nil then return false end
		bot:Action_AttackMove(Vector(decision.x, decision.y, decision.z))
		state.last_action_time = DotaTime()
		return true
	end

	if decision.action == 'attack_unit' then
		local target = FindEnemyHeroByPlayerID(decision.target_player_id)
		if target == nil then return false end
		bot:SetTarget(target)
		bot:Action_AttackUnit(target, false)
		state.last_action_time = DotaTime()
		return true
	end

	return false
end

function X.Think(bot)
	if not IsControlled(bot) then return false end
	if bot:IsUsingAbility() or bot:IsChanneling() then return false end

	local state = GetState(bot:GetPlayerID())
	local now = DotaTime()

	if not state.pending and now >= state.last_request_time + Config.request_interval then
		SendRequest(bot, state)
	end

	return ExecuteDecision(bot, state)
end

return X
