magma_conduits = {}

--grab a shorthand for the filepath of the mod
local modpath = minetest.get_modpath(minetest.get_current_modname())

--load companion lua files
dofile(modpath.."/config.lua")

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

-------------------------------------------------------------------------------------------------
-- Ameliorate lava floods on the surface world by removing lava that's poised to spill

if not magma_conduits.config.ameliorate_floods then return end

local c_air = minetest.get_content_id("air")
local c_lava = minetest.get_content_id("default:lava_source")

local water_level = tonumber(minetest.get_mapgen_setting("water_level"))

local is_adjacent_to_air = function(area, data, pos)
	return (data[area:index(pos.x+1, pos.y, pos.z)] == c_air
		or data[area:index(pos.x-1, pos.y, pos.z)] == c_air
		or data[area:index(pos.x, pos.y, pos.z+1)] == c_air
		or data[area:index(pos.x, pos.y, pos.z-1)] == c_air
		or data[area:index(pos.x, pos.y-1, pos.z)] == c_air)
end

magma_conduits.remove_unsupported_lava = function(area, data, vi)
	if data[vi] == c_lava then
		local pos = area:position(vi)
		if is_adjacent_to_air(area, data, pos) then
			data[vi] = c_air
			magma_conduits.remove_unsupported_lava(area, data, area:index(pos.x+1, pos.y, pos.z))
			magma_conduits.remove_unsupported_lava(area, data, area:index(pos.x-1, pos.y, pos.z))
			magma_conduits.remove_unsupported_lava(area, data, area:index(pos.x, pos.y, pos.z+1))
			magma_conduits.remove_unsupported_lava(area, data, area:index(pos.x, pos.y, pos.z-1))
			magma_conduits.remove_unsupported_lava(area, data, area:index(pos.x, pos.y+1, pos.z))
		end
	end
end

local data = {}

minetest.register_on_generated(function(minp, maxp, seed)
	--if too far from water level, abort. Caverns are on their own.
	if minp.y > 512 or maxp.y < water_level then
		return
	end
		
	--easy reference to commonly used values
	local t_start = os.clock()
	local x_max = maxp.x
	local y_max = maxp.y
	local z_max = maxp.z
	local x_min = minp.x
	local y_min = minp.y
	local z_min = minp.z
		
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	vm:get_data(data)
		
	for z = z_min, z_max do -- for each xy plane progressing northwards
		--structure loop, hollows out the cavern
		for y = y_min, y_max do -- for each x row progressing upwards
			if y > water_level then
				local vi = area:index(x_min, y, z) --current node index
				for x = x_min, x_max do -- for each node do
					magma_conduits.remove_unsupported_lava(area, data, vi)
					vi = vi + 1
				end
			end
		end
	end
		
	--send data back to voxelmanip
	vm:set_data(data)
	--calc lighting
	vm:set_lighting({day = 0, night = 0})
	vm:calc_lighting()
	vm:update_liquids()
	--write it to world
	vm:write_to_map(data)
end)