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

setting("int", "spread", 400, "Approximate spacing between magma conduits")
setting("bool", "remove_default_lava", true, "Removes default mapgen lava")
setting("bool", "ameliorate_floods", true, "Ameliorate lava floods on the surface")
setting("int", "upper_limit", 512, "Upper extent of magma conduits")
setting("int", "lower_limit", -31000, "Lower extent of magma conduits")
