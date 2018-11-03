local depth_root = -3000
local depth_base = -50
local depth_maxwidth = -10
local depth_maxpeak = 200
local depth_minpeak = 20
local radius_vent = 5
local radius_lining = 7
local slope_min = 0.25
local slope_max = 1.75
local chunk_size = 1000
	
local c_air = minetest.get_content_id("air")
local c_lava = minetest.get_content_id("default:lava_source")
local c_lining = minetest.get_content_id("default:obsidian")
local c_hot_lining = minetest.get_content_id("default:obsidian")
local c_cone = minetest.get_content_id("default:stone")
local c_ash = minetest.get_content_id("default:gravel")
local c_soil = minetest.get_content_id("default:dirt_with_grass")
local c_plug = minetest.get_content_id("default:obsidian")

local c_stone = minetest.get_content_id("default:stone")
local c_water = minetest.get_content_id("default:water_source")

if magma_conduits.config.glowing_rock then
	c_hot_lining = minetest.get_content_id("magma_conduits:glow_obsidian")
end

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
	local depth_peak = math.random(depth_minpeak, depth_maxpeak)
	local depth_lava = math.random(depth_peak - 50, depth_peak)
	local slope = math.random() * (slope_max - slope_min) + slope_min
	
	local state = math.random()
	
	math.randomseed(next_seed)
	return {location = location, depth_peak = depth_peak, depth_lava = depth_lava, slope = slope, state = state}
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
	
	if minp.y > depth_maxpeak then
		return
	end

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	vm:get_data(data)
	
	local minx = minp.x
	local minz = minp.z
	local sidelen = maxp.x - minp.x + 1 --length of a mapblock
	local chunk_lengths = {x = sidelen, y = sidelen, z = sidelen} --table of chunk edges

	nobj_perlin = nobj_perlin or minetest.get_perlin_map(perlin_params, chunk_lengths)
	local nvals_perlin = nobj_perlin:get3dMap_flat(minp, nvals_perlin_buffer) -- switch to get_3d_map_flat for minetest v0.5
	local noise_area = VoxelArea:new{MinEdge=minp, MaxEdge=maxp}
	local noise_iterator = noise_area:iterp(minp, maxp)

	local volcano = get_volcano(minp)
	
	minetest.debug(dump(volcano))
	
	local x_coord = volcano.location.x
	local z_coord = volcano.location.z
	local depth_lava = volcano.depth_lava
	local depth_peak = volcano.depth_peak
	local base_radius = (depth_peak - depth_maxwidth) * volcano.slope + radius_lining
	
	local state = volcano.state
	
	local dirtstuff
	if state < 0.5 then
		dirtstuff = c_soil
	else
		dirtstuff = c_ash
	end
	
	for vi, x, y, z in area:iterp_xyz(minp, maxp) do

		local vi3d = noise_iterator()

		local distance_perturbation = (nvals_perlin[vi3d]+1)*10
		local distance = vector.distance({x=x, y=y, z=z}, {x=x_coord, y=y, z=z_coord}) - distance_perturbation
		
		if distance > base_radius * 2.5 then
			return
		end

		local pipestuff
		local liningstuff
		if y < depth_lava + math.random() * 1.1 then
			if state < 0.25 then
				pipestuff = c_plug -- extinct volcano
				liningstuff = c_lining
			else
				pipestuff = c_lava
				liningstuff = c_hot_lining
			end
		else
			if state < 0.5 then
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
				if data[vi] == c_stone or data[vi] == c_water then
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
		elseif y < depth_peak then -- cone
			if vector.distance({x=x, y=y, z=z}, {x=x_coord, y=depth_peak, z=z_coord}) - distance_perturbation < radius_lining * 2.5 then
				data[vi] = c_air -- caldera
			elseif distance < radius_vent then
				data[vi] = pipestuff
			elseif distance < radius_lining then
				data[vi] = liningstuff
			elseif distance < y * -volcano.slope + base_radius then
				data[vi] = c_cone
			elseif distance < y * -volcano.slope + base_radius + nvals_perlin[vi3d]*-4 then
				data[vi] = dirtstuff
			end
		end	
	
	end
	
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