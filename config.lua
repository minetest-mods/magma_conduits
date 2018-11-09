local CONFIG_FILE_PREFIX = "magma_conduits_"

magma_conduits.config = {}

local print_settingtypes = false

local function setting(stype, name, default, description)
	local value
	if stype == "bool" then
		value = minetest.setting_getbool(CONFIG_FILE_PREFIX..name)
	elseif stype == "string" then
		value = minetest.setting_get(CONFIG_FILE_PREFIX..name)
	elseif stype == "int" or stype == "float" then
		value = tonumber(minetest.setting_get(CONFIG_FILE_PREFIX..name))
	end
	if value == nil then
		value = default
	end
	magma_conduits.config[name] = value
	
	if print_settingtypes then
		minetest.debug(CONFIG_FILE_PREFIX..name.." ("..description..") "..stype.." "..tostring(default))
	end	
end

setting("bool", "remove_default_lava", true, "Removes default mapgen lava")
setting("bool", "glowing_rock", true, "Cause rock adjacent to lava to convert into glowing form")
setting("bool", "cook_soil", true, "Cause soil and carbon-containing ores to be cooked into other forms by lava")

setting("bool", "magma_veins", true, "Enable magma veins")
setting("int", "spread", 400, "Approximate spacing between magma conduits")
setting("int", "remove_lava_above", 512, "Remove lava above this y level")
setting("bool", "obsidian_lining", true, "Add an obsidian lining to magma conduits")
setting("bool", "ameliorate_floods", true, "Ameliorate lava floods on the surface")

-- Removing this setting on account of issue https://github.com/minetest/minetest/issues/7364
--setting("int", "upper_limit", 512, "Upper extent of magma conduits")
--setting("int", "lower_limit", -31000, "Lower extent of magma conduits")
--from settingtypes.txt:
--magma_conduits_upper_limit (Upper extent of magma conduits) int 512
--magma_conduits_lower_limit (Lower extent of magma conduits) int -31000

setting("bool", "volcanoes", true, "Enable volcanoes")
setting("int", "volcano_min_height", 20, "Minimum volcano peak")
setting("int", "volcano_max_height", 200, "Maximum volcano peak")
setting("float", "volcano_min_slope", 0.5, "Minimum volcano slope")
setting("float", "volcano_max_slope", 1.5, "Maximum volcano slope")
setting("int", "volcano_region_mapblocks", 15, "Map blocks per chunk")

setting("float", "volcano_probability_active", 0.4, "Probability that there's an active volcano in each region")
setting("float", "volcano_probability_dormant", 0.2, "Probability that there's a dormant volcano in each region")
setting("float", "volcano_probability_extinct", 0.2, "Probability that there's an extinct volcano in each region")

