local Config = {}

Config.enabled = true
Config.endpoint = 'http://127.0.0.1:8765/decide'
Config.health_endpoint = 'http://127.0.0.1:8765/health'

-- Dota player IDs are 0-9. Start with one bot; add more IDs to scale out.
Config.controlled_player_ids = {
	[0] = true,
}

Config.request_interval = 0.35
Config.response_stale_seconds = 0.9
Config.action_interval = 0.25
Config.max_units_per_team = 5
Config.debug = false

return Config
