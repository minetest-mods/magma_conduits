-- These nodes are only present to work around https://github.com/minetest/minetest/issues/7864
-- Once that issue is resolved, this whole file should be got rid of.

local simple_copy
simple_copy = function(t)
	local r = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			r[k] = simple_copy(v)
		else
			r[k] = v
		end
	end
	return r
end

local source_def = simple_copy(minetest.registered_nodes["default:lava_source"])
source_def.light_source = nil
source_def.liquid_alternative_flowing = "magma_conduits:lava_flowing"
source_def.liquid_alternative_source = "magma_conduits:lava_source"
source_def.groups.not_in_creative_inventory = 1

minetest.register_node("magma_conduits:lava_source", source_def)

local flowing_def = simple_copy(minetest.registered_nodes["default:lava_flowing"])
flowing_def.light_source = nil
flowing_def.liquid_alternative_flowing = "magma_conduits:lava_flowing"
flowing_def.liquid_alternative_source = "magma_conduits:lava_source"

minetest.register_node("magma_conduits:lava_flowing", flowing_def)

minetest.register_lbm({
	label = "convert magma_conduits lava",
	name = "magma_conduits:convert_lava",
	nodenames = {"magma_conduits:lava_source"},
	run_at_every_load = true,
	action = function(pos, node)
		minetest.set_node(pos, {name="default:lava_source"})
	end,
})

minetest.register_abm({
	label = "convert magma_conduits lava",
	nodenames = {"magma_conduits:lava_source"},
	interval = 1.0,
	chance = 1,
	action = function(pos)
		minetest.set_node(pos, {name="default:lava_source"})
	end,
})