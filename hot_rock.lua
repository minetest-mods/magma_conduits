if magma_conduits.config.glowing_rock then

local modpath = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(modpath.."/intllib.lua")

minetest.register_node("magma_conduits:hot_cobble", {
	description = S("Hot Cobble"),
	_doc_items_longdesc = S("Hot stone riven with cracks and seeping traces of lava."),
	_doc_items_usagehelp = S("When normal stone is heated by lava it is converted into this. Beware when digging here!"),
	tiles = {"magma_conduits_hot_cobble.png"},
	is_ground_content = false,
	groups = {cracky = 3, stone = 2, hot=1},
	sounds = default.node_sound_stone_defaults(),
	light_source = 6,
	drop = "default:cobble",
})

minetest.register_node("magma_conduits:glow_obsidian", {
	description = S("Hot Obsidian"),
	_doc_items_longdesc = S("Obsidian heated to a dull red glow."),
	_doc_items_usagehelp = S("When normal obsidian is heated by lava it is converted into this. Beware when digging here!"),
	tiles = {"magma_conduits_glow_obsidian.png"},
	is_ground_content = true,
	sounds = default.node_sound_stone_defaults(),
	groups = {cracky=1, hot=1, level=2},
	light_source = 6,
	drop = "default:obsidian",
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
