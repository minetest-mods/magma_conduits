local worldpath = minetest.get_worldpath()
local areastore_filename = worldpath.."/volcano_areastore.txt"
local area_file = io.open(areastore_filename, "r")
local areastore = AreaStore()
if area_file then
	areastore:from_file(areastore_filename)
end
local function volcano_save()
	areastore:to_file(areastore_filename)
end

magma_conduits.name_volcano = function(pos, name, override)
	local existing_area = areastore:get_areas_for_pos(pos, true, true)
	local id = next(existing_area)
	if id and not override then
		return
	end	
	local data
	if id then
		local data = minetest.deserialize(existing_area[id].data)
		data.name = name
		areastore:remove_area(id)
	else
		data = {name = name, discovered_by = {}}
	end
	areastore:insert_area(pos, pos, minetest.serialize(data), id)
	volcano_save()
end

if not minetest.settings:get_bool("magma_conduits_show_volcanoes_in_hud", true) then
	return
end

local modpath = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(modpath.."/intllib.lua")

local requires_mappingkit = minetest.settings:get_bool("magma_conduits_hud_requires_mapping_kit", true)
	and minetest.registered_items["map:mapping_kit"] -- rather than test for the map modpath, test whether the mapping_kit has been registered.

local discovery_range = tonumber(minetest.settings:get("magma_conduits_volcano_discovery_range")) or 60
local visual_range = tonumber(minetest.settings:get("magma_conduits_volcano_visibility_range")) or 1200
local test_interval = 5 -- check every test_interval seconds

local player_huds = {}
-- Each player will have a table of [position_hash] = hud_id pairs in here

local add_hud_marker = function(player, player_name, pos, label)
	local waypoints = player_huds[player_name] or {}
	player_huds[player_name] = waypoints
	local pos_hash = minetest.hash_node_position(pos)
	if waypoints[pos_hash] then
		return
	end
	local hud_id = player:hud_add({
		hud_elem_type = "waypoint",
		name = label,
		text = "m",
		number = 0xFFFFFF,
		world_pos = pos})
	waypoints[pos_hash] = hud_id
end

local remove_distant_hud_markers = function()
	local players_to_remove = {}
	for player_name, waypoints in pairs(player_huds) do
		local player = minetest.get_player_by_name(player_name)
		if player then
			local has_map = (not requires_mappingkit) or (player:get_inventory():contains_item("main", "map:mapping_kit"))
			local player_pos = player:get_pos()
			local waypoints_to_remove = {}
			for pos_hash, hud_id in pairs(waypoints) do
				local pos = minetest.get_position_from_hash(pos_hash)
				if (not has_map) or vector.distance(pos, player_pos) > visual_range then
					table.insert(waypoints_to_remove, pos_hash)
					player:hud_remove(hud_id)
				end
			end
			for _, pos_hash in ipairs(waypoints_to_remove) do
				waypoints[pos_hash] = nil
			end
			if not next(waypoints) then -- player's waypoint list is empty, remove it
				table.insert(players_to_remove, player_name)
			end
		else
			table.insert(players_to_remove, player_name)
		end
	end
	for _, player_name in ipairs(players_to_remove) do
		player_huds[player_name] = nil
	end
end

-- For flushing outdated HUD markers when certain admin commands are performed.
local remove_all_hud_markers = function()
	for player_name, waypoints in pairs(player_huds) do
		local player = minetest.get_player_by_name(player_name)
		if player then
			for pos_hash, hud_id in pairs(waypoints) do
				player:hud_remove(hud_id)
			end
		end
	end
	player_huds = {}
end

local elapsed = 0
minetest.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < test_interval then
		return
	end
	elapsed = 0

	local connected_players = minetest.get_connected_players()
	local new_discovery = false
	for _, player in ipairs(connected_players) do
		local player_pos = player:get_pos()
		local player_name = player:get_player_name()

		local min_visual_edge = vector.subtract(player_pos, visual_range)
		local max_visual_edge = vector.add(player_pos, visual_range)
		local visual_volcanos = areastore:get_areas_in_area(min_visual_edge, max_visual_edge, true, true, true)
		for id, volcano in pairs(visual_volcanos) do

			local data = minetest.deserialize(volcano.data)
			local distance = vector.distance(player_pos, volcano.min)
			local discovered_by = data.discovered_by
			local volcano_pos = vector.add(volcano.min, {x=0, y=2, z=0})

			if distance < discovery_range and not discovered_by[player_name] then
				-- Update areastore
				data.discovered_by[player_name] = true
				areastore:remove_area(id)
				areastore:insert_area(volcano.min, volcano.min, minetest.serialize(data), id)

				-- Mark that we'll need to save volcanoes
				new_discovery = true

				-- Notify player of their find
				local note_name = data.name or "a volcano"
				local discovery_note = S("You've discovered @1!", note_name)
				local formspec = "size[4,1]" ..
					"label[1.0,0.0;" .. minetest.formspec_escape(discovery_note) ..
					"]button_exit[0.5,0.75;3,0.5;btn_ok;".. S("OK") .."]"
				minetest.show_formspec(player_name, "magma_conduits:discovery_popup",
					formspec)
				minetest.chat_send_player(player_name, discovery_note)
				minetest.log("action", "[magma_conduits] " .. player_name .. " discovered " .. note_name)
				minetest.sound_play({name = "magma_conduits_chime01", gain = 0.25}, {to_player=player_name})
			end

			local has_map = (not requires_mappingkit) or (player:get_inventory():contains_item("main", "map:mapping_kit"))
			if has_map and distance < visual_range and discovered_by[player_name] then
				local volcano_name = data.name or "Volcano"
				add_hud_marker(player, player_name, volcano_pos, volcano_name)
			end
		end
	end
	remove_distant_hud_markers()

	if new_discovery then
		volcano_save()
	end
end)

----------------------------------------------------------------------
-- Chatcommands

local function get_nearest_volcano_within_range(pos, range, name)
	local min_edge = vector.subtract(pos, range)
	local max_edge = vector.add(pos, range)
	local volcano_list = areastore:get_areas_in_area(min_edge, max_edge, true, true, true)

	local min_dist = range + 1 -- start with number beyond range
	local min_id = nil
	local min_data = nil
	local min_pos = nil
	for id, volcano in pairs(volcano_list) do
		local data = minetest.deserialize(volcano.data)
		local distance = vector.distance(pos, volcano.min)
		if distance < min_dist and data.discovered_by[name] then
			min_dist = distance
			min_id = id
			min_data = data
			min_pos = volcano.min
		end
	end

	return min_pos, min_id, min_data
end


minetest.register_chatcommand("volcano_rename_nearest", {
	description = S("Change the name of the nearest volcano within visible range"),
	param = S("The new name for this volcano"),
	privs = {["server"]=true},
	func = function(name, param)
		if param == "" then
			minetest.chat_send_player(name, S("Please enter a new name"))
			return
		end
		local player = minetest.get_player_by_name(name)
		local player_pos = player:get_pos()

		local min_pos, min_id, min_data = get_nearest_volcano_within_range(player_pos, visual_range, name)

		if min_id ~= nil then
			local oldname = min_data.name
			min_data.name = param
			areastore:remove_area(min_id)
			areastore:insert_area(min_pos, min_pos, minetest.serialize(min_data), min_id)
			volcano_save()
			minetest.log("action", "[magma_conduits] Renamed " .. oldname .. " to " .. param)
			minetest.chat_send_player(name, S("Volcano successfully renamed from @1 to @2.", oldname, param))
			remove_all_hud_markers()
			return
		end

		minetest.chat_send_player(name, S("No known volcanoes within @1m found.", visual_range))
	end,
})

local function set_all_discovered(player_name, state)
	local volcano_list = areastore:get_areas_in_area(
		{x=-32000, y=-32000, z=-32000}, {x=32000, y=32000, z=32000}, true, true, true)
	for id, volcano in pairs(volcano_list) do
		local data = minetest.deserialize(volcano.data)
		data.discovered_by[player_name] = state
		areastore:remove_area(id)
		areastore:insert_area(volcano.min, volcano.min, minetest.serialize(data), id)
	end
	volcano_save()
end

minetest.register_chatcommand("volcano_discover_all", {
	description = S("Set all volcanoes as known to you or another player"),
	param = S("player_name, or nothing for yourself"),
	privs = {["server"]=true},
	func = function(name, param)
		if param ~= "" then
			name = param
		end
		set_all_discovered(name, true)
	end,
})

minetest.register_chatcommand("volcano_undiscover_all", {
	description = S("Set all volcanoes as unknown to you or another player"),
	param = S("player_name, or nothing for yourself"),
	privs = {["server"]=true},
	func = function(name, param)
		if param ~= "" then
			name = param
		end
		set_all_discovered(name, nil)
	end,
})
