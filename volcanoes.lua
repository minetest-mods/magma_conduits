local depth_root = -3000 -- TODO: should add some kind of optional magma chamber down there
local depth_base = -50 -- point where the mountain root starts expanding
local depth_maxwidth = -30 -- point of maximum width

local radius_vent = 3 -- approximate minimum radius of vent - noise adds a lot to this
local radius_lining = 5 -- the difference between this and the vent radius is about how thick the layer of lining nodes is, though noise will affect it
local caldera_min = 5 -- minimum radius of caldera
local caldera_max = 20 -- maximum radius of caldera
local chunk_size = 1000

local snow_line = 120 -- above this elevation snow is added to the dirt type
local snow_border = 15 -- transitional zone where there's dirt with snow on it

local state_extinct = 0.25
local state_dormant = 0.5

local depth_maxpeak = magma_conduits.config.volcano_max_height
local depth_minpeak = magma_conduits.config.volcano_min_height
local slope_min = magma_conduits.config.volcano_min_slope
local slope_max = magma_conduits.config.volcano_max_slope


local c_air = minetest.get_content_id("air")
local c_lava = minetest.get_content_id("default:lava_source")
local c_water = minetest.get_content_id("default:water_source")

local c_lining = minetest.get_content_id("default:obsidian")
local c_hot_lining = minetest.get_content_id("default:obsidian")
local c_cone = minetest.get_content_id("default:stone")

local c_ash = minetest.get_content_id("default:gravel")
local c_soil = minetest.get_content_id("default:dirt")
local c_soil_grass = minetest.get_content_id("default:dirt_with_grass")
local c_soil_snow = minetest.get_content_id("default:dirt_with_snow")
local c_snow = minetest.get_content_id("default:snow")
local c_snow_block = minetest.get_content_id("default:snowblock")

local c_underwater_soil = minetest.get_content_id("default:sand")
local c_plug = minetest.get_content_id("default:obsidian")

if magma_conduits.config.glowing_rock then
	c_hot_lining = minetest.get_content_id("magma_conduits:glow_obsidian")
end

local water_level = tonumber(minetest.get_mapgen_setting("water_level"))
local mapgen_seed = tonumber(minetest.get_mapgen_setting("seed"))

-- derived values

local radius_cone_max = (depth_maxpeak-depth_maxwidth)/(2*slope_min)
local depth_maxwidth_dist = depth_maxwidth-depth_base
local depth_maxpeak_dist = depth_maxpeak-depth_maxwidth

local scatter_2d = function(min_xz, gridscale, border_width)
	local bordered_scale = gridscale - 2 * border_width
	local point = {}
	point.x = math.random() * bordered_scale + min_xz.x + border_width
	point.y = 0
	point.z = math.random() * bordered_scale + min_xz.z + border_width
	return point
end

local get_volcano = function(pos)
	local corner_xz = {x = math.floor(pos.x / chunk_size) * chunk_size, z = math.floor(pos.z / chunk_size) * chunk_size}

	local next_seed = math.random(1, 1000000000)
	math.randomseed(corner_xz.x + corner_xz.z * 2 ^ 8 + mapgen_seed)

	local location = scatter_2d(corner_xz, chunk_size, radius_cone_max)
	--local location = {x=corner_xz.x+chunk_size/2, z = corner_xz.z+chunk_size/2} -- For testing, puts volcanoes in a consistent grid
	local depth_peak = math.random(depth_minpeak, depth_maxpeak)
	local depth_lava = math.random(depth_peak - 25, depth_peak)
	local slope = math.random() * (slope_max - slope_min) + slope_min
	local caldera = math.random() * (caldera_max - caldera_min) + caldera_min
	
	local state = math.random() -- 0-0.25 = extinct, 0.25-0.5 = dormant, 0.5-1.0 active
	
	math.randomseed(next_seed)
	return {location = location, depth_peak = depth_peak, depth_lava = depth_lava, slope = slope, state = state, caldera = caldera}
end

local perlin_params = {
	offset = 0,
	scale = 1,
	spread = {x=30, y=30, z=30},
	seed = -40901,
	octaves = 3,
	persist = 0.67
}
local nvals_perlin_buffer = {}
local nobj_perlin = nil
local data = {}

minetest.register_on_generated(function(minp, maxp, seed)
	if minp.y > depth_maxpeak or maxp.y < depth_root then
		return
	end

	local volcano = get_volcano(minp)
	local depth_peak = volcano.depth_peak
	local base_radius = (depth_peak - depth_maxwidth) * volcano.slope + radius_lining
	local sidelen = maxp.x - minp.x + 1 --length of a mapblock

	-- early out if the volcano is too far away to matter
	if vector.distance(volcano.location, {x=minp.x+sidelen/2, y=0, z=minp.z+sidelen/2}) > base_radius * 2.5 then
		return
	end
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	vm:get_data(data)
	
	local chunk_lengths = {x = sidelen, y = sidelen, z = sidelen} --table of chunk edges

	nobj_perlin = nobj_perlin or minetest.get_perlin_map(perlin_params, chunk_lengths)
	local nvals_perlin = nobj_perlin:get3dMap_flat(minp, nvals_perlin_buffer) -- switch to get_3d_map_flat for minetest v0.5
	local noise_area = VoxelArea:new{MinEdge=minp, MaxEdge=maxp}
	local noise_iterator = noise_area:iterp(minp, maxp)
	
	local x_coord = volcano.location.x
	local z_coord = volcano.location.z
	local depth_lava = volcano.depth_lava
	local caldera = volcano.caldera
	
	local state = volcano.state
	
	for vi, x, y, z in area:iterp_xyz(minp, maxp) do

		local vi3d = noise_iterator()

		local distance_perturbation = (nvals_perlin[vi3d]+1)*10
		local distance = vector.distance({x=x, y=y, z=z}, {x=x_coord, y=y, z=z_coord}) - distance_perturbation

		local dirtstuff
		local replace_soil = false -- determines if the soil type should be replaced with c_soil if there's layers on top of it
		if state < state_dormant then
			if y < water_level then
				dirtstuff = c_underwater_soil
			elseif y < snow_line then
				dirtstuff = c_soil_grass
				replace_soil = true
			elseif y < snow_line + snow_border then
				dirtstuff = c_soil_snow
				replace_soil = true
			else
				dirtstuff = c_snow_block
			end
		else
			dirtstuff = c_ash
		end
		
		local pipestuff
		local liningstuff
		if y < depth_lava + math.random() * 1.1 then
			if state < state_extinct then
				pipestuff = c_plug -- extinct volcano
				liningstuff = c_lining
			else
				pipestuff = c_lava
				liningstuff = c_hot_lining
			end
		else
			if state < state_dormant then
				pipestuff = c_plug -- dormant volcano
				liningstuff = c_lining
			else
				pipestuff = c_air -- active volcano
				liningstuff = c_lining
			end
		end
		
		if y < depth_base then -- pipe
			if distance < radius_vent then
				data[vi] = pipestuff
			elseif distance < radius_lining then
				if data[vi] ~= c_air and data[vi] ~= c_lava then -- leave holes into caves and into existing lava
					data[vi] = liningstuff
				end
			end
		elseif y < depth_maxwidth then -- root
			if distance < radius_vent then
				data[vi] = pipestuff
			elseif distance < radius_lining then
				data[vi] = liningstuff
			elseif distance < radius_lining + ((y - depth_base)/depth_maxwidth_dist) * base_radius then
				data[vi] = c_cone
			end
		elseif y < depth_peak + 5 then -- cone
			local current_elevation = y - depth_maxwidth
			local peak_elevation = depth_peak - depth_maxwidth
			if current_elevation > peak_elevation - caldera and distance < current_elevation - peak_elevation + caldera then
				data[vi] = c_air -- caldera
			elseif distance < radius_vent then
				data[vi] = pipestuff
			elseif distance < radius_lining then
				data[vi] = liningstuff
			elseif distance <  current_elevation * -volcano.slope + base_radius then
				data[vi] = c_cone
			elseif distance < current_elevation * -volcano.slope + base_radius + nvals_perlin[vi3d]*-4 then
				data[vi] = dirtstuff
				if replace_soil and data[vi - area.ystride] == dirtstuff then
					data[vi - area.ystride] = c_soil -- soil underneath a layer of other soil shouldn't have grass on top
				end
				if y >= snow_line then
					if data[vi + area.ystride] == c_air then
						data[vi + area.ystride] = c_snow -- generation advances in a positive y direction so this will be overwritten if more solid stuff is placed above
					end
				end
			end
		end
	
	end
	
	-- These don't seem to work?
	--minetest.generate_decorations(vm, minp, maxp)
	--minetest.generate_ores(vm, minp, maxp)
		
	--send data back to voxelmanip
	vm:set_data(data)
	--calc lighting
	vm:set_lighting({day = 0, night = 0})
	vm:calc_lighting()
	vm:update_liquids()
	--write it to world
	vm:write_to_map()
end)

minetest.register_privilege("findvolcano", { description = "Allows players to use a console command to find the nearest volcano", give_to_singleplayer = false})

minetest.register_chatcommand("findvolcano", {
    params = "pos", -- Short parameter description
    description = "find the volcano in the player's map region, or in the map region containing pos if provided",
    func = function(name, param)
		if minetest.check_player_privs(name, {findvolcano = true}) then
			pos = tonumber(param)
			if pos ~= nil then
				--TODO
				return true
			else
				playerobj = minetest.get_player_by_name(name)
				volcano = get_volcano(playerobj:get_pos())
				text = "Nearest volcano is at " .. minetest.pos_to_string(volcano.location, 0)
					.. "\nHeight: " .. tostring(volcano.depth_peak) .. " Slope: " .. tostring(volcano.slope)
					.. "\nState: "
				if volcano.state < state_extinct then
					text = text .. "Extinct"
				elseif volcano.state < state_dormant then
					text = text .. "Dormant"
				else
					text = text .. "Active"
				end
				minetest.chat_send_player(name, text)
				return true
			end
		else
			return false, "You need the findvolcano privilege to use this command."
		end
	end,
})
