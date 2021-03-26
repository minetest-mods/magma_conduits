magma_conduits = {}

local modname = minetest.get_current_modname()

magma_conduits.S = minetest.get_translator(modname)

local modpath = minetest.get_modpath(modname)
dofile(modpath.."/config.lua")
dofile(modpath.."/voxelarea_iterator.lua")
dofile(modpath.."/hot_rock.lua")

if magma_conduits.config.remove_default_lava then
	minetest.register_alias_force("mapgen_lava_source", "air")

	-- Newer mapgens define cave liquids in biomes. There isn't an easy way to override biomes
	-- yet (https://github.com/minetest/minetest/issues/9161) so this clears and recreates all biomes.
	-- decorations and ores also need to be re-registered since reregistering the biomes reassigns their
	-- biome IDs.
	
	local registered_biomes_copy = {}
	for old_biome_key, old_biome_def in pairs(minetest.registered_biomes) do
		registered_biomes_copy[old_biome_key] = old_biome_def
		
		if old_biome_def.node_cave_liquid == "default:lava_source" then
			old_biome_def.node_cave_liquid = "air"
		elseif type(old_biome_def.node_cave_liquid) == "table" then
			for i, liquid in ipairs(old_biome_def.node_cave_liquid) do
				if liquid == "default:lava_source" then
					old_biome_def.node_cave_liquid[i] = "air"
				end
			end
		end
		
	end
	local registered_decorations_copy = {}
	for old_decoration_key, old_decoration_def in pairs(minetest.registered_decorations) do
		registered_decorations_copy[old_decoration_key] = old_decoration_def
	end
	local registered_ores_copy = {}
	for old_ore_key, old_ore_def in pairs(minetest.registered_ores) do
		registered_ores_copy[old_ore_key] = old_ore_def
	end
	
	minetest.clear_registered_ores()
	minetest.clear_registered_decorations()
	minetest.clear_registered_biomes()
	for biome_key, new_biome_def in pairs(registered_biomes_copy) do
		minetest.register_biome(new_biome_def)
	end
	for decoration_key, new_decoration_def in pairs(registered_decorations_copy) do
		minetest.register_decoration(new_decoration_def)
	end
	for ore_key, new_ore_def in pairs(registered_ores_copy) do
		minetest.register_ore(new_ore_def)
	end	
end

if magma_conduits.config.magma_veins then
	dofile(modpath.."/magma_veins.lua")
end
if magma_conduits.config.volcanoes then
	dofile(modpath.."/volcanoes.lua")
end
if magma_conduits.config.cook_soil then
	dofile(modpath.."/cook_soil.lua")
end

