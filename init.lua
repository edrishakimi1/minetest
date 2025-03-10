minetest.register_node("latticesurgery:flat", {
    description = "white flat tile",
    tiles = {"white.png"}, -- is white
    groups = {cracky = 3},

    drawtype = "nodebox",
    node_box = {
        type = "connected",
        fixed = {
            -0.5, -0.5, -0.5, 0.5, 0.5, 0.5
        }
    }, 

    sounds = default.node_sound_stone_defaults(),
})

local storage_ref = minetest.get_mod_storage()
local stored_centerpos = {}
local check = storage_ref:get_string("spawnbuilder_centerpos_x")
if check ~= "" then
	stored_centerpos.x = storage_ref:get_int("spawnbuilder_centerpos_x")
	stored_centerpos.y = storage_ref:get_int("spawnbuilder_centerpos_y")
	stored_centerpos.z = storage_ref:get_int("spawnbuilder_centerpos_z")
	minetest.log("action", "[spawnbuilder] Spawn platform position loaded: "..minetest.pos_to_string(stored_centerpos))
else
	stored_centerpos = minetest.setting_get_pos("static_spawnpoint")
	-- Default position
	if not stored_centerpos then
		stored_centerpos = { x=0, y=-1, z=0 }
	end
	storage_ref:set_int("spawnbuilder_centerpos_x", stored_centerpos.x)
	storage_ref:set_int("spawnbuilder_centerpos_y", stored_centerpos.y)
	storage_ref:set_int("spawnbuilder_centerpos_z", stored_centerpos.z)
	minetest.log("action", "[spawnbuilder] Initial spawn platform position registered and saved: "..minetest.pos_to_string(stored_centerpos))
end

-- Width of the stored_centerpos platform
local WIDTH
check = storage_ref:get_string("spawnbuilder_width")
if check ~= "" then
	WIDTH = check
else
	WIDTH = tonumber(minetest.settings:get("spawnbuilder_width"))
	if type(WIDTH) == "number" then
		WIDTH = math.floor(WIDTH)
	else
		WIDTH = 100
	end
end
minetest.log("action", "[spawnbuilder] Using spawn platform width of "..WIDTH..".")

-- Height of the platform
local HEIGHT = 2

-- Number of air layers above the platform
local AIRSPACE = 3

-- Generates the platform or platform piece within minp and maxp with the center at centerpos
local function generate_platform(minp, maxp, centerpos)
	-- Get stone and cobble nodes, based on the mapgen aliases. This allows for great compability with practically
	-- all subgames!
	-- local c_stone = minetest.get_content_id("mapgen_stone")
	-- local c_cobble 
	-- if minetest.registered_aliases["mapgen_cobble"] == "air" or minetest.registered_aliases["mapgen_cobble"] == nil then
	-- 	-- Fallback option: If cobble mapgen alias is inappropriate or missing, use stone instead.
	-- 	c_cobble = c_stone
	-- else
	-- 	c_cobble = minetest.get_content_id("mapgen_cobble")
	-- end

    local c_cobble = minetest.get_content_id("latticesurgery:flat")
    local c_stone = minetest.get_content_id("latticesurgery:flat")

	local w_neg, w_pos
	w_pos = math.floor(WIDTH / 2)
	if math.fmod(WIDTH, 2) == 0 then
		w_neg = -w_pos + 1
	else
		w_neg = -w_pos
	end

	local xmin = math.max(centerpos.x + w_neg, minp.x)
	local xmax = math.min(centerpos.x + w_pos, maxp.x)
	local zmin = math.max(centerpos.z + w_neg, minp.z)
	local zmax = math.min(centerpos.z + w_pos, maxp.z)
	local ymin = math.max(centerpos.y - (HEIGHT-1), minp.y)
	local ymax = math.min(centerpos.y + AIRSPACE, maxp.y)

	if maxp.x >= xmin and minp.x <= xmax and maxp.y >= ymin and minp.y <= ymax and maxp.z >= zmin and minp.z <= zmax then
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local data = vm:get_data()
		local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})

		for x = xmin, xmax do
			for y = ymin, ymax do
				for z = zmin, zmax do
					local p_pos = area:index(x, y, z)
					local pos = {x=x,y=y,z=z}
					if minetest.registered_nodes[minetest.get_node(pos).name].is_ground_content == true then
						if y <= centerpos.y then
							if x == centerpos.x and y == centerpos.y and z == centerpos.z then
								data[p_pos] = c_cobble
								minetest.log("action", "[spawnbuilder] Spawn platform center generated at "..minetest.pos_to_string(pos)..".")
							else
								data[p_pos] = c_stone
							end
						elseif y >= centerpos.y + 1 and y <= ymax then
							data[p_pos] = core.CONTENT_AIR
						end
					end
				end
			end
		end

		vm:set_data(data)
		vm:calc_lighting()
		vm:write_to_map()
	end
end

minetest.register_on_generated(function(minp, maxp, seed)
	local centerpos = table.copy(stored_centerpos)

	if minp.x <= centerpos.x and maxp.x >= centerpos.x and minp.y <= centerpos.y and maxp.y >= centerpos.y and minp.z <= centerpos.z and maxp.z >= centerpos.z then
		if not WIDTH or WIDTH <= 0 then
			minetest.log("warning", "[spawnbuilder] Invalid spawnbuilder_width. Spawn platform will NOT be generated.")
			return
		end

		local ground = false
		local air = true
		-- Check for solid ground
		for y = 3, -6, -1 do
			local nn = minetest.get_node({x=centerpos.x, y=centerpos.y+y, centerpos.z}).name
			local walkable = minetest.registered_nodes[nn].walkable
			if y >= 0 and nn ~= "air" then
				air = false
			elseif y < 0 and walkable then
				ground = true
			end
		end
		-- Player has enough space and ground to spawn safely. No change required
		if air and ground then
			minetest.log("action", "[spawnbuilder] Safe player spawn detected. Spawn platform will NOT be generated.")
			return
		end
	end

	generate_platform(minp, maxp, centerpos)
end)

local function add_vectors(vector1, vector2)
    if type(vector1) == "table" and type(vector2) == "table" then
        local result = {
            x = (vector1.x or 0) + (vector2.x or 0),
            y = (vector1.y or 0) + (vector2.y or 0),
            z = (vector1.z or 0) + (vector2.z or 0)
        }
        return result
    else
        error("Both arguments must be tables representing vectors")
    end
end

function split(inputstr, sep)
    if sep == nil then
      sep = "%s" -- Default to whitespace
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
      table.insert(t, str)
    end
    return t
end

ie = minetest.request_insecure_environment()

local function insecure_load_file()
    local mod_path = minetest.get_modpath("latticesurgery")
    -- local json_file_path = mod_path .. "/crossings/grover_3.json"
    -- cp ~/CLionProjects/liblsqecc/cmake-build-debug/n_output.json .
    local json_file_path = mod_path .. "/n_output.json"
    -- local json_file_path = "/Users/palera1/repos/liblsqecc/cmake-build-debug/pandora.json"
    f = ie.io.open(json_file_path)
    s = f:read("a")
    ie.io.close(f)
    return minetest.parse_json(s)
    
end

local function insecure_load_crossings(index)
    local mod_path = minetest.get_modpath("latticesurgery")
    local json_file_path = mod_path .. "/crossings/crossings_3d_" .. index ..".json"
    f = ie.io.open(json_file_path)
    s = f:read("a")
    ie.io.close(f)
    return minetest.parse_json(s)
    
end


local function sleep(n)
    ie.os.execute("sleep " .. tonumber(n))
end

local function array_to_s(a)
    local r = ""
    for i, k in pairs(a) do
        r = r .. k
    end
    return r
end

local function stitch_border(border, patch_type)
    if border == "AncillaJoin" then return true end
    if border == "SolidStiched" then return true end
    if border == "DashedStiched" then return true end
    if border == "Solid" then return false end
    if border == "Dashed" then return false end
    if border == "None" and patch_type == "DistillationQubit" then return true end

    return false
end

local function is_dead_cell(cell)
    return false
end

local function max(a,b)
    if a > b then
        return a
    else 
        return b
    end
end

local function max_key(start, ll)
    acc = start
    for k,v in pairs(ll) do
        acc = max(acc, k)
    end
    return acc
end
local routingRegionId = -1;
local function place_layers(starting_point, slices)
    for t = 1, #slices do
        for r, rval in pairs(slices[t]) do
            for c, cval in  pairs(slices[t][r]) do
                local value = slices[t][r][c]
                --minetest.chat_send_all("Adding block at "..tostring(t).." "..tostring(r).." "..tostring(c) .. " " .. "") 
                if value and (not is_dead_cell(value)) and value['patch_type'] ~= 'DistillationQubit' then
                    minetest.chat_send_all("ok")

                    -- minetest.chat_send_all("id ->"..vid.." ---- "..value['text'])

                    
                    local connections = {0, 0, 0, 0, 1, 1};
                    if stitch_border(value['edges']['Top'], value['patch_type']) then connections[1] = 1 end
                    if stitch_border(value['edges']['Bottom'], value['patch_type']) then connections[2] = 1 end
                    if stitch_border(value['edges']['Left'], value['patch_type']) then connections[3] = 1 end
                    if stitch_border(value['edges']['Right'], value['patch_type']) then connections[4] = 1 end

                    if value['patch_type'] == 'Ancilla' then
                        if not value['routing_connect_to_prec'] then
                            connections[5] = 0;
                        end
                        if not value['routing_connect_to_next'] then
                            connections[6] = 0;
                        end
                    end

                    local name = string.format("latticesurgery:routing_%i_%s",t%12+1, array_to_s(connections))
                    if is_dead_cell(value) then
                        name = "latticesurgery:dead_cell"
                    elseif value['patch_type'] == 'DistillationQubit' then
                        name = string.format("latticesurgery:distillation_%s", array_to_s(connections))
                    elseif value['patch_type'] == 'Qubit' then
                        name = string.format("latticesurgery:qubit_%s", array_to_s(connections))
                    end

                    -- t-1 seems wrong ... why??
                    local position = add_vectors(starting_point, { x = r, y = t -1 , z = c })
                    local existing_node = minetest.get_node(position)
                    if existing_node.name ~= "air" then
                        minetest.remove_node(position)
                    end
                    minetest.place_node(position,  { name = name})

                    if value['patch_type'] == 'Ancilla' and value['routing_region_id'] ~= "Not bound"then
                        routingRegionId = value['routing_region_id']

                        local meta = core.get_meta(position)
                        meta:set_int("id", routingRegionId)
                        --minetest.chat_send_all("Set id: " .. routingRegionId .. " at position: " .. minetest.pos_to_string(position))

                    end
                    if(core.get_meta(position):contains("id")) then
                        
                        local mid = tostring(core.get_meta(position):get_int("id") .. " at " .. minetest.pos_to_string(position))
                        minetest.chat_send_all(mid)
                    else
                        minetest.chat_send_all("not found")
                    end                 
                end
            end
        end
    end
    
end


NUM_ROUTING_COLOURS = 12

for j = 0, 63, 1 do
    -- j to bit string
    local bitstring = {
        math.floor(j / 32) % 2,
        math.floor(j / 16) % 2,
        math.floor(j / 8) % 2,
        math.floor(j / 4) % 2,
        math.floor(j / 2) % 2,
        math.floor(j / 1) % 2
    }

    -- Register qubit node
    minetest.register_node(string.format("latticesurgery:qubit_%s", array_to_s(bitstring)), {
        description = string.format("Qubit %s", array_to_s(bitstring)),
        tiles = {"qubit.png"},
        drawtype = "nodebox",
        node_box = {
            type = "connected",
            drawtype = "nodebox",
            fixed = {
                -3/8 - bitstring[1] * 1/8,
                -3/8 - bitstring[5] * 1/8,
                -3/8 - bitstring[3] * 1/8,
                3/8 + bitstring[2] * 1/8,
                3/8 + bitstring[6] * 1/8,
                3/8 + bitstring[4] * 1/8
            }
        },
        groups = {oddly_breakable_by_hand = 1, dig_immediate = 3},  
        on_dig = function(pos, node, digger)
            
        end
    })

    -- Register distillation node
    minetest.register_node(string.format("latticesurgery:distillation_%s", array_to_s(bitstring)), {
        description = string.format("Distillation volume", array_to_s(bitstring)),
        tiles = {"distillation.png"},
        drawtype = "nodebox",
        node_box = {
            type = "connected",
            drawtype = "nodebox",
            fixed = {
                -3/8 - bitstring[1] * 1/8,
                -3/8 - bitstring[5] * 1/8,
                -3/8 - bitstring[3] * 1/8,
                3/8 + bitstring[2] * 1/8,
                3/8 + bitstring[6] * 1/8,
                3/8 + bitstring[4] * 1/8
            }
        },
        groups = {cracky = 1} -- , falling_node=2}
    })
    -- Forward declarations
    local break_node
    local break_neighbors
    local break_node_landing
    local broken_nodes = {}
    local has_neighbor
    local check_and_fall_above
   -- Initialize an empty vector
LS_LOCAL_START_POS = vector.new(0, 0, 0)

-- Initialize the broken_nodes table
local broken_nodes = {}


function check_and_fall(pos, visited)
    visited = visited or {} 
    local pos_key = minetest.pos_to_string(pos)
    if visited[pos_key] then
        return 
    end
    visited[pos_key] = true 

    local rid = -1
    local meta = core.get_meta(pos)
    if meta:contains("id") then
        rid = meta:get_int("id")
    else
        return 
    end


    local below = {x = pos.x, y = pos.y - 1, z = pos.z}
    local below_meta = core.get_meta(below)

    if below_meta:contains("id") and below_meta:get_int("id") == rid then
        return 
    end

    local neighbors = {
        {x = pos.x + 1, y = pos.y, z = pos.z}, 
        {x = pos.x - 1, y = pos.y, z = pos.z}, 
        {x = pos.x,     y = pos.y, z = pos.z + 1}, 
        {x = pos.x,     y = pos.y, z = pos.z - 1}  
    }

    for _, neighbor_pos in ipairs(neighbors) do
        local neighbor_meta = core.get_meta(neighbor_pos)

        if neighbor_meta:contains("id") and neighbor_meta:get_int("id") == rid then
            local neighbor_below = {x = neighbor_pos.x, y = neighbor_pos.y - 1, z = neighbor_pos.z}
            local neighbor_below_meta = core.get_meta(neighbor_below)

            if neighbor_below_meta:contains("id") then
                return 
            end
        end
    end

    local node = minetest.get_node(pos)
    minetest.add_entity(pos, "__builtin:falling_node")

    for _, neighbor_pos in ipairs(neighbors) do
        check_and_fall(neighbor_pos, visited)
    end
end

    


local function break_node(pos, start_id, visited)
    local node = minetest.get_node(pos)

    if node.name:match("^latticesurgery:routing") then
        local rid = -1
        local meta = core.get_meta(pos)
        local pos_2 = { x = -1, y = -1, z = -1 }
        if meta:contains("id") then
            rid = meta:get_int("id")
        end
        minetest.chat_send_all("Node ID: " .. rid)

        if tostring(rid) == tostring(start_id) then
            minetest.remove_node(pos)
            local pos_above = {x = pos.x, y = pos.y + 1, z = pos.z}
            break_neighbors(pos, start_id, visited)
            check_and_fall(pos_above, visited)

        end
    end
end

function break_neighbors(pos, start_id, visited)
    visited = visited or {}

    local spos = minetest.pos_to_string(pos)
    if visited[spos] then
        return  
    end
    visited[spos] = true 

    local neighbors = {
        { x = pos.x + 1, y = pos.y, z = pos.z }, 
        { x = pos.x - 1, y = pos.y, z = pos.z },  
        { x = pos.x, y = pos.y + 1, z = pos.z },  
        { x = pos.x, y = pos.y - 1, z = pos.z },  
        { x = pos.x, y = pos.y, z = pos.z + 1 },  
        { x = pos.x, y = pos.y, z = pos.z - 1 }, 
    }

 
    for _, neighbor_pos in ipairs(neighbors) do
        local meta = core.get_meta(neighbor_pos)
        if meta:contains("id") and tostring(meta:get_int("id")) == tostring(start_id) then
            break_node(neighbor_pos, start_id, visited)
        end
    end
end


for i = 1, 12, 1 do
    local node_name = string.format("latticesurgery:routing_%i_%s", i, array_to_s(bitstring))

    minetest.register_node(node_name, {
        description = string.format("Routing Volume color variation %i %s", i, array_to_s(bitstring)),
        tiles = { string.format("routing_%i.png", i) },
        -- top, bottom, right, left, front, back
        -- tiles = { "time.png", "time.png", "red.png", "red.png", "blue.png", "blue.png" },
        drawtype = "nodebox",
        node_box = {
            type = "connected",
            fixed = {
                -3/8 - bitstring[1] * 1/8,
                -3/8 - bitstring[5] * 1/8,
                -3/8 - bitstring[3] * 1/8,
                3/8 + bitstring[2] * 1/8,
                3/8 + bitstring[6] * 1/8,
                3/8 + bitstring[4] * 1/8
            }
        },
        -- groups = { oddly_breakable_by_hand = 1, dig_immediate = 3, falling_node = 10 },  -- Break instantly by hand
        
        --dig_immediate: (player can always pick up node without tool wear)
        --#2: node is removed without tool wear after 0.5 seconds (rail, sign)
        --#3: node is removed without tool wear after 0.15 seconds (torch)
        
        groups = { oddly_breakable_by_hand = 1, dig_immediate = 3 },  -- Break instantly by hand

        drop = "latticesurgery:routing_item",

        on_dig = function(pos)
            local visited = {}
            local start_id = core.get_meta(pos):get_int("id")
            break_node(pos, start_id, visited)
        end,

        on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            if not meta:contains("id") then
                meta:set_int("id", i)
            end
        end,
    })
end
end

minetest.register_node("latticesurgery:dead_cell", {
    description = "Dead Cell",
    tiles = {"dead.png"},
    drawtype = "glasslike",
    groups = {cracky = 1} -- , falling_node=2}
})


--
-- TOP, BOTTOM, RIGHT, LEFT, FRONT, BACK
--
local position = {"TOP", "BOTTOM", "RIGHT", "LEFT", "FRONT", "BACK"}
function string_cube_config(config)

    local r = ""
    for i, k in pairs(config) do
        r = r .. position[i] .. "/" .. k:gsub(".png"," ")
    end
    return r
end

local cubetextures={
    {-- 1
        {
            {"time.png", "time.png", "red.png", "red.png", "blue.png", "blue.png"},
            {"time.png", "time.png", "blue.png", "blue.png", "red.png", "red.png"}
        },
        {
            {"time.png", "time.png", "red.png", "blue.png", "red.png", "blue.png"},
            {"time.png", "time.png", "blue.png", "red.png", "blue.png", "red.png"}
        },
        {
            {"time.png", "time.png", "red.png", "blue.png", "blue.png", "red.png"},
            {"time.png", "time.png", "blue.png", "red.png", "red.png", "blue.png"},
        },
    },
    {-- 2
        {
            {"time.png", "red.png", "time.png", "red.png", "blue.png", "blue.png"},
            {"time.png", "blue.png", "time.png", "blue.png", "red.png", "red.png"},
        },
        {
            {"time.png", "red.png", "time.png", "blue.png", "red.png", "blue.png"},
            {"time.png", "blue.png", "time.png", "red.png", "blue.png", "red.png"},
        },
        {
            {"time.png", "red.png", "time.png", "blue.png", "blue.png", "red.png"},
            {"time.png", "blue.png", "time.png", "red.png", "red.png", "blue.png"},
        },
    },
    {-- 3
        {
            {"time.png", "red.png", "red.png", "time.png", "blue.png", "blue.png"},
            {"time.png", "blue.png", "blue.png", "time.png", "red.png", "red.png"},
        },
        {
            {"time.png", "red.png", "blue.png", "time.png", "red.png", "blue.png"},
            {"time.png", "blue.png", "red.png", "time.png", "blue.png", "red.png"},
        },
        {
            {"time.png", "red.png", "blue.png", "time.png", "blue.png", "red.png"},
            {"time.png", "blue.png", "red.png", "time.png", "red.png", "blue.png"},
        },
    },
    {-- 4
        {
            {"time.png", "red.png", "red.png", "blue.png", "time.png", "blue.png"},
            {"time.png", "blue.png", "blue.png", "red.png", "time.png", "red.png"},
        },
        {
            {"time.png", "red.png", "blue.png", "red.png", "time.png", "blue.png"},
            {"time.png", "blue.png", "red.png", "blue.png", "time.png", "red.png"},
        },
        {
            {"time.png", "red.png", "blue.png", "blue.png", "time.png", "red.png"},
            {"time.png", "blue.png", "red.png", "red.png", "time.png", "blue.png"},
        },
    },
    {-- 5
        {
            {"time.png", "red.png", "red.png", "blue.png", "blue.png", "time.png"},
            {"time.png", "blue.png", "blue.png", "red.png", "red.png", "time.png"},
        },
        {
            {"time.png", "red.png", "blue.png", "red.png", "blue.png", "time.png"},
            {"time.png", "blue.png", "red.png", "blue.png", "red.png", "time.png"},
        },
        {
            {"time.png", "red.png", "blue.png", "blue.png", "red.png", "time.png"},
            {"time.png", "blue.png", "red.png", "red.png", "blue.png", "time.png"},
        },
    },
    {-- 6
        {
            {"red.png", "time.png", "time.png", "red.png", "blue.png", "blue.png"},
            {"blue.png", "time.png", "time.png", "blue.png", "red.png", "red.png"},
        },
        {
            {"red.png", "time.png", "time.png", "blue.png", "red.png", "blue.png"},
            {"blue.png", "time.png", "time.png", "red.png", "blue.png", "red.png"},
        },
        {
            {"red.png", "time.png", "time.png", "blue.png", "blue.png", "red.png"},
            {"blue.png", "time.png", "time.png", "red.png", "red.png", "blue.png"},
        }
    },
    {-- 7
        {
            {"red.png", "time.png", "red.png", "time.png", "blue.png", "blue.png"},
            {"blue.png", "time.png", "blue.png", "time.png", "red.png", "red.png"},
        },
        {
            {"red.png", "time.png", "blue.png", "time.png", "red.png", "blue.png"},
            {"blue.png", "time.png", "red.png", "time.png", "blue.png", "red.png"},
        },
        {
            {"red.png", "time.png", "blue.png", "time.png", "blue.png", "red.png"},
            {"blue.png", "time.png", "red.png", "time.png", "red.png", "blue.png"},
        }
    },
    {-- 8
        {
            {"red.png", "time.png", "red.png", "blue.png", "time.png", "blue.png"},
            {"blue.png", "time.png", "blue.png", "red.png", "time.png", "red.png"},
        },
        {
            {"red.png", "time.png", "blue.png", "red.png", "time.png", "blue.png"},
            {"blue.png", "time.png", "red.png", "blue.png", "time.png", "red.png"},
        },
        {
            {"red.png", "time.png", "blue.png", "blue.png", "time.png", "red.png"},
            {"blue.png", "time.png", "red.png", "red.png", "time.png", "blue.png"},
        },
    },
    {-- 9
        {
            {"red.png", "time.png", "red.png", "blue.png", "blue.png", "time.png"},
            {"blue.png", "time.png", "blue.png", "red.png", "red.png", "time.png"},
        },
        {
            {"red.png", "time.png", "blue.png", "red.png", "blue.png", "time.png"},
            {"blue.png", "time.png", "red.png", "blue.png", "red.png", "time.png"},
        },
        {
            {"red.png", "time.png", "blue.png", "blue.png", "red.png", "time.png"},
            {"blue.png", "time.png", "red.png", "red.png", "blue.png", "time.png"},
        },
    },
    {-- 10
        {
            {"red.png", "red.png", "time.png", "time.png", "blue.png", "blue.png"},
            {"blue.png", "blue.png", "time.png", "time.png", "red.png", "red.png"},
        },
        {
            {"red.png", "blue.png", "time.png", "time.png", "red.png", "blue.png"},
            {"blue.png", "red.png", "time.png", "time.png", "blue.png", "red.png"},
        },
        {
            {"red.png", "blue.png", "time.png", "time.png", "blue.png", "red.png"},
            {"blue.png", "red.png", "time.png", "time.png", "red.png", "blue.png"},
        },
    },
    {-- 11
        {
            {"red.png", "red.png", "time.png", "blue.png", "time.png", "blue.png"},
            {"blue.png", "blue.png", "time.png", "red.png", "time.png", "red.png"},
        },
        {
            {"red.png", "blue.png", "time.png", "red.png", "time.png", "blue.png"},
            {"blue.png", "red.png", "time.png", "blue.png", "time.png", "red.png"},
        },
        {
            {"red.png", "blue.png", "time.png", "blue.png", "time.png", "red.png"},
            {"blue.png", "red.png", "time.png", "red.png", "time.png", "blue.png"},
        }
    },
    {-- 12
        {
            {"red.png", "red.png", "time.png", "blue.png", "blue.png", "time.png"},
            {"blue.png", "blue.png", "time.png", "red.png", "red.png", "time.png"},
        },
        {
            {"red.png", "blue.png", "time.png", "red.png", "blue.png", "time.png"},
            {"blue.png", "red.png", "time.png", "blue.png", "red.png", "time.png"},
        },
        {
            {"red.png", "blue.png", "time.png", "blue.png", "red.png", "time.png"},
            {"blue.png", "red.png", "time.png", "red.png", "blue.png", "time.png"},
        }
    },
    {-- 13
        {
            {"red.png", "red.png", "blue.png", "time.png", "time.png", "blue.png"},
            {"blue.png", "blue.png", "red.png", "time.png", "time.png", "red.png"},
        },
        {
            {"red.png", "blue.png", "red.png", "time.png", "time.png", "blue.png"},
            {"blue.png", "red.png", "blue.png", "time.png", "time.png", "red.png"},
        },
        {
            {"red.png", "blue.png", "blue.png", "time.png", "time.png", "red.png"},
            {"blue.png", "red.png", "red.png", "time.png", "time.png", "blue.png"},
        }
    },
    {-- 14
        {
            {"red.png", "red.png", "blue.png", "time.png", "blue.png", "time.png"},
            {"blue.png", "blue.png", "red.png", "time.png", "red.png", "time.png"},
        },
        {
            {"red.png", "blue.png", "red.png", "time.png", "blue.png", "time.png"},
            {"blue.png", "red.png", "blue.png", "time.png", "red.png", "time.png"},
        },
        {
            {"red.png", "blue.png", "blue.png", "time.png", "red.png", "time.png"},
            {"blue.png", "red.png", "red.png", "time.png", "blue.png", "time.png"},
        }
    },
    {-- 15
        {
            {"red.png", "red.png", "blue.png", "blue.png", "time.png", "time.png"},
            {"blue.png", "blue.png", "red.png", "red.png", "time.png", "time.png"},
        },
        {
            {"red.png", "blue.png", "red.png", "blue.png", "time.png", "time.png"},
            {"blue.png", "red.png", "blue.png", "red.png", "time.png", "time.png"},
        },
        {
            {"red.png", "blue.png", "blue.png", "red.png", "time.png", "time.png"},
            {"blue.png", "red.png", "red.png", "blue.png", "time.png", "time.png"},
        }
    },
}

---
--- Add nodes for the possible positions of logical operators
---
local current_node_type = "latticesurgery:cube_1_1_1"

for io = 1, 15, 1 do
    for ops = 1, 3, 1 do
        for fl = 1, 2, 1 do
            local c_name = string.format("latticesurgery:cube_%i_%i_%i", io, ops, fl)

            minetest.register_node(c_name, {
                description = "The cube for " .. c_name,
                tiles = cubetextures[io][ops][fl],
                drawtype = "nodebox",
                node_box = {
                    type = "connected",
                    fixed = {
                        -0.5, -0.5, -0.5, 0.5, 0.5, 0.5
                    }
                },  
                groups = { oddly_breakable_by_hand = 1, dig_immediate = 2 },

                drop = "latticesurgery:tube",

                on_punch = function(pos, node, puncher, pointed_thing)

                    local wielded_item = puncher:get_wielded_item()
                    if wielded_item then
                        local item_name = wielded_item:get_name()
                        -- minetest.chat_send_all("You used: " .. item_name .. " for " .. node.name)

                        local vals = split(node.name, "_")
                        
                        local n_io = tonumber(vals[2])
                        local n_op = tonumber(vals[3])
                        local n_flip = tonumber(vals[4])
                        
                        if item_name == "latticesurgery:tool_io" then
                            n_io = (n_io + 1) 
                            if n_io > 15 then
                                n_io = n_io - 15
                            end
                        elseif item_name == "latticesurgery:tool_op" then
                            n_op = (n_op + 1)
                            if n_op > 3 then
                                n_op = n_op - 3
                            end
                        elseif item_name == "latticesurgery:tool_flip" then
                            n_flip = (n_flip + 1)
                            if n_flip > 2 then
                                n_flip = n_flip - 2
                            end
                        elseif item_name == "latticesurgery:tool_pick" then
                            
                        end

                        n_name = string.format("latticesurgery:cube_%i_%i_%i", n_io, n_op, n_flip)
                        current_node_type = n_name
                        minetest.swap_node(pos, { name = n_name})

                        minetest.chat_send_all("current cube: " .. n_name .. "-> " .. string_cube_config(cubetextures[n_io][n_op][n_flip]))
                    end
                end,

                -- on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
                --     if clicker:is_player() then
                --         core.chat_send_player(clicker:get_player_name(), "Hello world!")
                --     end
                -- end,
                -- on_construct = function(pos, node)
                --     local meta = core.get_meta(pos)
                --     meta:set_string("infotext", "My node!")
                -- end,

                after_place_node = function(pos, placer, itemstack, pointed_thing)
                    -- Make sure to check placer
                    -- if placer and placer:is_player() then
                    --     local meta = core.get_meta(pos)
                    --     meta:set_string("owner", placer:get_player_name())
                    -- end
                    minetest.swap_node(pos, { name = current_node_type})
                end,
            })
        end
    end
end

local function set_pos(name, param)

    minetest.chat_send_all(name)

    local player = minetest.get_player_by_name(name)
    LS_LOCAL_START_POS = vector.round(player:get_pos())

    -- minetest.chat_send_all(minetest.pos_to_string(LS_LOCAL_START_POS))
end

local function crossings(name, param)
    local slices = insecure_load_crossings(param)

    --set the position of the player with name
    set_pos(name)

    place_layers(LS_LOCAL_START_POS, slices)
end

local function do_compile(name, param)
    local slices = insecure_load_file()

    --set the position of the player with name
    set_pos(name)

    place_layers(LS_LOCAL_START_POS, slices)
end


-- Register the following commands in the console

minetest.register_chatcommand("make", {
    func = do_compile
})

minetest.register_chatcommand("set_pos", {
    func = set_pos
})

minetest.register_chatcommand("crossings", {
    func = crossings
})

--local mod_path = minetest.get_modpath("latticesurgery")
--dofile(mod_path .. "/script.lua")

local http = minetest.request_http_api()
assert(http)


local function load_slices(name, param)
    local t = "-1"
    
    http.fetch({
            url = "http://127.0.0.1:5000/get_nr_slices"
    }, function(res)
            print(dump(res.data))
            t = res.data
                        
            set_pos(name)
    
            local nr_slices = tonumber(t)
            for t = 1, nr_slices do
                http.fetch({
                    url = "http://127.0.0.1:5000/get_slice/" .. tostring(t)
                }, function(res)
                    -- print(dump(res))
                    place_layers(LS_LOCAL_START_POS, minetest.parse_json(res.data))

                    LS_LOCAL_START_POS = add_vectors(LS_LOCAL_START_POS, { x = 0, y = 1 , z = 0 })
                end)

            end
    end) 

end

minetest.register_chatcommand("load", {
    func = load_slices
})

local function add_tool(name, param)
    local player = minetest.get_player_by_name(name)
    player:get_inventory():add_item("main", "latticesurgery:tool_io 99")
    player:get_inventory():add_item("main", "latticesurgery:tool_op 99")
    player:get_inventory():add_item("main", "latticesurgery:tool_flip 99")
    player:get_inventory():add_item("main", "latticesurgery:tool_pick 99")
    player:get_inventory():add_item("main", "latticesurgery:cube_1_1_1 99")
end

minetest.register_chatcommand("tool",{
    func = add_tool
})

core.register_tool("latticesurgery:tool_io", {
    description = "IO Tool",
    inventory_image = "tool_io.png",
    tool_capabilities = {
        full_punch_interval = 1.5,
        max_drop_level = 1,
        groupcaps = {
            crumbly = {
                maxlevel = 2,
                uses = 20,
                times = { [1]=1.60, [2]=1.20, [3]=0.80 }
            },
        },
        damage_groups = {fleshy=2},
    },
})

core.register_tool("latticesurgery:tool_op", {
    description = "Op Tool",
    inventory_image = "tool_op.png",
    tool_capabilities = {
        full_punch_interval = 1.5,
        max_drop_level = 1,
        groupcaps = {
            crumbly = {
                maxlevel = 2,
                uses = 20,
                times = { [1]=1.60, [2]=1.20, [3]=0.80 }
            },
        },
        damage_groups = {fleshy=2},
    },
})

core.register_tool("latticesurgery:tool_flip", {
    description = "Flip Tool",
    inventory_image = "tool_flip.png",
    tool_capabilities = {
        full_punch_interval = 1.5,
        max_drop_level = 1,
        groupcaps = {
            crumbly = {
                maxlevel = 2,
                uses = 20,
                times = { [1]=1.60, [2]=1.20, [3]=0.80 }
            },
        },
        damage_groups = {fleshy=2},
    },
})

core.register_tool("latticesurgery:tool_pick", {
    description = "Flip Tool",
    inventory_image = "tool_pick.png",
    tool_capabilities = {
        full_punch_interval = 1.5,
        max_drop_level = 1,
        groupcaps = {
            crumbly = {
                maxlevel = 2,
                uses = 20,
                times = { [1]=1.60, [2]=1.20, [3]=0.80 }
            },
        },
        damage_groups = {fleshy=2},
    },
})