magma_conduits = {}

--grab a shorthand for the filepath of the mod
local modpath = minetest.get_modpath(minetest.get_current_modname())

--load companion lua files
dofile(modpath.."/config.lua")
dofile(modpath.."/voxelarea_iterator.lua")

if magma_conduits.config.remove_default_lava then
	minetest.register_alias_force("mapgen_lava_source", "air") -- veins of lava are far more realistic
end


minetest.register_ore({
	ore_type = "vein",
	ore = "default:lava_source",
	wherein = {
		"default:stone",
		"default:desert_stone",
		"default:sandstone",
		"default:sand",
		"default:desert_sand",
		"default:silver_sand",
		"default:gravel",
		"default:stone_with_coal",
		"default:stone_with_iron",
		"default:stone_with_copper",
		"default:stone_with_tin",
		"default:stone_with_gold",
		"default:stone_with_diamond",
		"default:dirt",
		"default:dirt_with_grass",
		"default:dirt_with_dry_grass",
		"default:dirt_with_snow",
		},
	column_height_min = 2,
	column_height_max = 6,
	height_min = magma_conduits.config.lower_limit,
	height_max = magma_conduits.config.upper_limit,
	noise_threshold = 0.9,
	noise_params = {
		offset = 0,
		scale = 3,
		spread = {x=magma_conduits.config.spread, y=magma_conduits.config.spread*2, z=magma_conduits.config.spread},
		seed = 25391,
		octaves = 4,
		persist = 0.5,
		flags = "eased",
	},
	random_factor = 0,
})

if magma_conduits.config.glowing_rock then

local S, NS = dofile(modpath.."/intllib.lua")

minetest.register_node("magma_conduits:hot_cobble", {
	description = S("Hot Cobble"),
	tiles = {"magma_conduits_hot_cobble.png"},
	is_ground_content = false,
	groups = {cracky = 3, stone = 2, hot=1},
	sounds = default.node_sound_stone_defaults(),
	light_source = 6,
	drops = "default:cobble",
})

minetest.register_node("magma_conduits:glow_obsidian", {
	description = S("Hot Obsidian"),
	tiles = {"magma_conduits_glow_obsidian.png"},
	is_ground_content = true,
	sounds = default.node_sound_stone_defaults(),
	groups = {cracky=1, hot=1, level=2},
	light_source = 6,
	drops = "default:obsidian",
})

minetest.register_abm{
    label = "stone heating",
	nodenames = {"default:stone", "default:cobble", "default:mossycobble"},
	neighbors = {"default:lava_source", "default:lava_flowing"},
	interval = 10,
	chance = 5,
	action = function(pos)
		minetest.set_node(pos, {name = "magma_conduits:hot_cobble"})
	end,
}

minetest.register_abm{
    label = "obsidian heating",
	nodenames = {"default:obsidian"},
	neighbors = {"default:lava_source", "default:lava_flowing"},
	interval = 10,
	chance = 5,
	action = function(pos)
		minetest.set_node(pos, {name = "magma_conduits:glow_obsidian"})
	end,
}

minetest.register_abm{
    label = "stone cooling",
	nodenames = {"magma_conduits:hot_cobble"},
	interval = 100,
	chance = 10,
	action = function(pos)
		if not minetest.find_node_near(pos, 2, {"default:lava_source", "default:lava_flowing"}, false) then
			minetest.set_node(pos, {name = "default:cobble"})
		end
	end,
}

minetest.register_abm{
    label = "obsidian cooling",
	nodenames = {"magma_conduits:glow_obsidian"},
	interval = 100,
	chance = 10,
	action = function(pos)
		if not minetest.find_node_near(pos, 2, {"default:lava_source", "default:lava_flowing"}, false) then
			minetest.set_node(pos, {name = "default:obsidian"})
		end
	end,
}

else

minetest.register_alias("magma_conduits:hot_cobble", "default:cobble")
minetest.register_alias("magma_conduits:glow_obsidian", "default:obsidian")

end


-------------------------------------------------------------------------------------------------
-- Ameliorate lava floods on the surface world by removing lava that's poised to spill

if not (magma_conduits.config.ameliorate_floods or magma_conduits.config.obsidian_lining) then return end

local ameliorate_floods = magma_conduits.config.ameliorate_floods
local obsidian_lining = magma_conduits.config.obsidian_lining

local c_air = minetest.get_content_id("air")
local c_lava = minetest.get_content_id("default:lava_source")
local c_stone = minetest.get_content_id("default:stone")
local c_obsidian = minetest.get_content_id("default:obsidian")

local water_level = tonumber(minetest.get_mapgen_setting("water_level"))

local is_adjacent_to_air = function(area, data, x, y, z)
	return (data[area:index(x+1, y, z)] == c_air
		or data[area:index(x-1, y, z)] == c_air
		or data[area:index(x, y, z+1)] == c_air
		or data[area:index(x, y, z-1)] == c_air
		or data[area:index(x, y-1, z)] == c_air)
end

local remove_unsupported_lava
remove_unsupported_lava = function(area, data, vi, x, y, z)
	--if too far from water level, abort. Caverns are on their own.
	if y < water_level or y > 512 or not area:contains(x, y, z) then return end

	if data[vi] == c_lava then
		if is_adjacent_to_air(area, data, x, y, z) then
			data[vi] = c_air
			for pi, x2, y2, z2 in area:iter_xyz(x-1, y, z-1, x+1, y+1, z+1) do
				if pi ~= vi and area:containsi(pi) then
					remove_unsupported_lava(area, data, pi, x2, y2, z2)
				end
			end
		end
	end
end

local obsidianize = function(area, data, vi, x, y, z, minp, maxp)
	if data[vi] == c_lava then
		for pi in area:iter(math.max(x-1, minp.x), math.max(y-1, minp.y), math.max(z-1, minp.z),
							math.min(x+1, maxp.x), math.min(y+1, maxp.y), math.min(z+1, maxp.z)) do
			if data[pi] == c_stone then
				data[pi] = c_obsidian
			end
		end
	end
end

local data = {}

minetest.register_on_generated(function(minp, maxp, seed)
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	vm:get_data(data)
	
	for vi, x, y, z in area:iterp_xyz(minp, maxp) do
		if ameliorate_floods then
			remove_unsupported_lava(area, data, vi, x, y, z)
		end
		if obsidian_lining then
			obsidianize(area, data, vi, x, y, z, minp, maxp)
		end
	end
		
	--send data back to voxelmanip
	vm:set_data(data)
	--calc lighting
	vm:set_lighting({day = 0, night = 0})
	vm:calc_lighting()
	vm:update_liquids()
	--write it to world
	vm:write_to_map()
end)