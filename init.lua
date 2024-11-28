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
 

ie = minetest.request_insecure_environment()

local function insecure_load_file()
    local mod_path = minetest.get_modpath("latticesurgery")
    -- local json_file_path = mod_path .. "/crossings/grover_3.json"
    -- cp ~/CLionProjects/liblsqecc/cmake-build-debug/n_output.json .
    local json_file_path = mod_path .. "/n_output.json"
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
    if cell['patch_type'] == "Ancilla" and
        cell['edges']['Top'] == "None" and
        cell['edges']['Bottom'] == "None" and
        cell['edges']['Left'] == "None" and
        cell['edges']['Right'] == "None" 
    then
        return true
    end
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
                if value and (not is_dead_cell(value)) and value['patch_type'] ~= 'DistillationQubit' then
                    

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
        --groups = {cracky = 1}, -- , falling_node=2},
        groups = {oddly_breakable_by_hand = 1, dig_immediate = 3},  -- Break instantly by hand
        -- The on_dig callback to remove the node and break neighboring nodes
        on_dig = function(pos, node, digger)
            -- Break the original routing node
            --local start_id = core.get_meta(pos):get_int("id")
            --local start_id = routingRegionId
            --minetest.remove_node(pos)
            --local coords = minetest.pos_to_string(pos)

            --minetest.chat_send_all("Start from" .. start_id )
            
            --break_neighbors(pos, start_id)
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

    -- Function to check all neighbors for qubit or routing nodes and break them
    break_neighbors = function(pos, start_id, visited)
        visited = visited or {}

        -- Convert position to string for tracking visited nodes
        local spos = minetest.pos_to_string(pos)
        if visited[spos] then
            return  -- Skip if already visited
        end
        visited[spos] = true  -- Mark this node as visited

        -- Define the six neighbor positions (left, right, above, below, front, back)
        local neighbors = {
            {x = pos.x + 1, y = pos.y, z = pos.z},  -- Right
            {x = pos.x - 1, y = pos.y, z = pos.z},  -- Left
            {x = pos.x, y = pos.y + 1, z = pos.z},  -- Above
            {x = pos.x, y = pos.y - 1, z = pos.z},  -- Below
            {x = pos.x, y = pos.y, z = pos.z + 1},  -- Front
            {x = pos.x, y = pos.y, z = pos.z - 1},  -- Back
        }

        -- Loop through all neighbors and check for qubit or routing nodes
        for _, neighbor_pos in ipairs(neighbors) do
            break_node(neighbor_pos, start_id, visited)  -- Break qubit or routing neighbors recursively
        end
    end

    -- Function to check if a node is a qubit or routing node and break it if it is
    break_node = function(pos, start_id, visited)
        -- Convert position to string for logging
        local spos = minetest.pos_to_string(pos)  
        
        local node = minetest.get_node(pos)

        -- Check if the node is a routing node
        -- if node.name:match("^latticesurgery:qubit") or 
        if node.name:match("^latticesurgery:routing") then
            local rid = -1
            -- check if key is available
            if (core.get_meta(pos):contains("id")) then
                 rid = core.get_meta(pos):get_int("id")
                minetest.chat_send_all("Node id: " .. rid .. " " .. start_id .. " " .. node.name)
            else
                minetest.chat_send_all("nothing here !! :(" .. spos)
            end
                   

            if rid == start_id then
                minetest.chat_send_all("Routing id: broke here and it was " .. rid )
                minetest.remove_node(pos)

                break_neighbors(pos, start_id, visited)
            end

            -- Recursively break all neighbors of this node
        end
    end

    -- Loop to register routing nodes
    for i = 1, 12, 1 do
        local node_name = string.format("latticesurgery:routing_%i_%s", i, array_to_s(bitstring))

        -- Register the routing node
        minetest.register_node(node_name, {
            description = string.format("Routing Volume color variation %i %s", i, array_to_s(bitstring)),
            tiles = {string.format("routing_%i.png", i)},
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
            groups = {oddly_breakable_by_hand = 1, dig_immediate = 3},  -- Break instantly by hand
            drop = "latticesurgery:routing_item",

            -- The on_dig callback to remove the node and break neighboring nodes
            on_dig = function(pos, node, digger)
                -- Break the original routing node

                visited  = {}
                break_node(pos, core.get_meta(pos):get_int("id"), visited)

                --local start_id = core.get_meta(pos):get_int("id")
                --minetest.remove_node(pos)
                --local coords = minetest.pos_to_string(pos)
                --minetest.chat_send_all("Start from" .. start_id )
                --break_neighbors(pos, start_id)
            end
        })
    end
end
minetest.register_node("latticesurgery:dead_cell", {
    description = "Dead Cell",
    tiles = {"dead.png"},
    drawtype = "glasslike",
    groups = {cracky = 1} -- , falling_node=2}
})


-- initialize an empty vector
LS_LOCAL_START_POS = vector.new(0,0,0)

local function set_pos(name, param)
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
