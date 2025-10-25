local function get_default_qb_slots(seablock_enabled)
    local qb_slots
    if seablock_enabled then
        qb_slots = {
                [1]  = prototypes.item["basic-transport-belt"] and "basic-transport-belt" or "transport-belt",
                [2]  = prototypes.item["basic-underground-belt"] and "basic-underground-belt" or "underground-belt",
                [3]  = prototypes.item["basic-transport-belt"] and "basic-splitter" or "splitter",
                [4]  = "inserter",
                [5]  = "assembling-machine-1",
                [6]  = "small-electric-pole",
                [7]  = "stone-pipe",
                [8]  = "stone-pipe-to-ground",
                [9]  = "offshore-pump",
                [10] = "small-lamp",
                [11] = "roboport",
                [12] = "storage-chest",
                [13] = "requester-chest",
                [14] = "passive-provider-chest",
                [15] = "buffer-chest",
                [16] = nil,
                [17] = nil,
                [18] = nil,
                [19] = nil,
                [20] = nil,
                [21] = "angels-electrolyser",
                [22] = "angels-flare-stack",
                [23] = "burner-ore-crusher",
                [24] = "liquifier",
                [25] = "crystallizer",
                [26] = "stone-furnace",
                [27] = "algae-farm"
        }
    else
        qb_slots = {
                [1]  = prototypes.item["basic-transport-belt"] and "basic-transport-belt" or "transport-belt",
                [2]  = prototypes.item["basic-underground-belt"] and "basic-underground-belt" or "underground-belt",
                [3]  = prototypes.item["basic-transport-belt"] and "basic-splitter" or "splitter",
                [4]  = "inserter",
                [5]  = "long-handed-inserter",
                [6]  = "medium-electric-pole",
                [7]  = "assembling-machine-1",
                [8]  = "small-lamp",
                [9]  = "stone-furnace",
                [10] = "electric-mining-drill",
                [11] = "roboport",
                [12] = "storage-chest",
                [13] = "requester-chest",
                [14] = "passive-provider-chest",
                [15] = "buffer-chest",
                [16] = "gun-turret",
                [17] = "stone-wall",
                [18] = nil,
                [19] = nil,
                [20] = "radar",
                [21] = "offshore-pump",
                [22] = "pipe-to-ground",
                [23] = "pipe",
                [24] = "boiler",
                [25] = "steam-engine",
                [26] = "burner-inserter"
        }
    end
    return qb_slots
end

local function itemCountAllowed(name, count, player)
    local item = prototypes.item[name]
    local place_type = item.place_result and item.place_result.type
    if name == "red-wire" or name == "green-wire" then
        -- need these for circuitry, one stack is enough
        return math.min(200, count)
    elseif name == "copper-cable" then
        -- need this for manually connecting poles, but don't want player to manually move stuff around so we'll limit it
        return math.min(20, count)
    elseif item.type == "blueprint" or item.type == "deconstruction-item" or item.type == "blueprint-book" or item.type == "selection-tool" or name == "artillery-targeting-remote" or name == "spidertron-remote" or item.type == "upgrade-item" or item.type == "copy-paste-tool" or item.type == "cut-paste-tool" or name == "tl-adjust-capsule" or name == "tl-draw-capsule" or name == "tl-edit-capsule" then
        -- these only place ghosts or are utility items
        return count
    elseif place_type == "car" or place_type == "spider-vehicle" then
        -- let users put down cars & tanks
        return count
    elseif item.place_as_equipment_result then
        -- let user carry equipment
        return count
    elseif string.match(name, ".*module.*") then
        -- allow modules
        return count
    elseif name == "BlueprintAlignment-blueprint-holder" then
        -- temporary holding location for original blueprint, should only ever be one of these.
        return count
    end
    return 0
end

local function dropItems(player, name, count)
    local entity = player.opened or player.selected
    local inserted = 0
    if entity and entity.insert then
        -- in case picking up items from a limited chest, unset limit, insert, then set limit again
        for _, inventory_id in pairs(defines.inventory) do
            local inventory = entity.get_inventory(inventory_id)
            if inventory then
                local barpos = inventory.supports_bar() and inventory.get_bar() or nil
                if inventory.supports_bar() then
                    inventory.set_bar() -- clear bar (the chest size limiter)
                end
                inserted = inserted + inventory.insert{name = name, count = count}
                count = count - inserted
                if inventory.supports_bar() then
                    inventory.set_bar(barpos) -- reset bar
                end
                if count <= 0 then
                    break
                end
            end
        end
        if count > 0 then
            -- try a generic insert (although code above should make this redundant)
            count = count - entity.insert({name = name, count = count})
        end
    end
    if count > 0 then
        -- now we're forced to spill items
        entity = entity or storage.forces[player.force.name].roboport
        entity.surface.spill_item_stack(entity.position, { name = name, count = count }, false, entity.force, false)
    end
end

local function inventoryChanged(event)
    if storage.creative then
        return
    end
    local player = game.players[event.player_index]
    -- remove any crafted items (and possibly make ghost cursor of item)
    for _, item in pairs(storage.players[event.player_index].crafted) do
        if itemCountAllowed(item.name, item.count, player) == 0 then
            if player.clean_cursor() then
                player.cursor_stack.clear()
            end
        end
        player.cursor_ghost = prototypes.item[item.name]
        player.remove_item(item)
    end
    storage.players[event.player_index].crafted = {}

    -- player is only allowed to carry whitelisted items
    -- everything else goes into entity opened or entity beneath mouse cursor
    local inventory_main = player.get_inventory(defines.inventory.god_main)
    if inventory_main == nil then
        return
    end

    local items = {}
    for i = 1, #inventory_main do
        local item_stack = inventory_main[i]
        if item_stack and item_stack.valid_for_read and not item_stack.is_blueprint then
            local name = item_stack.name
            if items[name] then
                items[name].count = items[name].count + item_stack.count
            else
                items[name] = {
                    count = item_stack.count,
                    slot = item_stack
                }
            end
        end
    end
    storage.players[event.player_index].inventory_items = items

    local entity = player.selected or player.opened
    for name, item in pairs(items) do
        local allowed = itemCountAllowed(name, item.count, player)
        local to_remove = item.count - allowed
        if to_remove > 0 then
            dropItems(player, name, to_remove)
            player.remove_item { name = name, count = to_remove }
        end
    end
end

local function setupForce(force, surface, x, y, seablock_enabled)
    if not storage.forces then
        storage.forces = {}
    end
    if storage.forces[force.name] then
        -- force already exist
        return
    end
    storage.forces[force.name] = {}

    -- setup event listeners for creative mode
    if remote.interfaces["creative-mode"] then
        script.on_event(remote.call("creative-mode", "on_enabled"), function(event)
            storage.creative = true
        end)
        script.on_event(remote.call("creative-mode", "on_disabled"), function(event)
            storage.creative = false
        end)
    end

    -- give player the possibility to build robots & logistic chests from the start
    force.technologies["construction-robotics"].researched = true
    force.technologies["logistic-robotics"].researched = true
    force.technologies["logistic-system"].researched = true

    -- research some techs that require manual labour
    local seablock_items = {}
    if seablock_enabled and remote.interfaces["SeaBlock"] then
        seablock_items = remote.call("SeaBlock", "get_starting_items")
        remote.call("SeaBlock", "set_starting_items", nil)

        local unlocks = remote.call("SeaBlock", "get_unlocks")
        for _,techs in pairs(unlocks) do
            for _,tech in pairs(techs) do
                if force.technologies[tech] then
                    force.technologies[tech].researched = true
                end
            end
        end
    end

    -- setup starting location
    local water_replace_tile = "sand-1"
    force.chart(surface, {{x - 192, y - 192}, {x + 192, y + 192}})
    if not seablock_enabled then
        water_replace_tile = "dirt-3"
        -- oil is rare, but mandatory to continue research. add some oil patches near spawn point
        local xx = x + math.random(16, 32) * (math.random(1, 2) == 1 and 1 or -1)
        local yy = y + math.random(16, 32) * (math.random(1, 2) == 1 and 1 or -1)
        local tiles = {}
        surface.create_entity{name = "crude-oil", amount = math.random(100000, 250000), position = {xx, yy}, raise_built = true}
        for xxx = xx - 2, xx + 2 do
            for yyy = yy - 2, yy + 2 do
                local tile = surface.get_tile(xxx, yyy)
                local name = tile.name
                if tile.prototype.layer <= 4 then
                    name = water_replace_tile
                end
                tiles[#tiles + 1] = {name = name, position = {xxx, yyy}}
            end
        end
        xxx = xx + math.random(-8, 8)
        yyy = yy - math.random(4, 8)
        for xxxx = xxx - 2, xxx + 2 do
            for yyyy = yyy - 2, yyy + 2 do
                local tile = surface.get_tile(xxxx, yyyy)
                local name = tile.name
                if tile.prototype.layer <= 4 then
                    name = water_replace_tile
                end
                tiles[#tiles + 1] = {name = name, position = {xxxx, yyyy}}
            end
        end
        surface.create_entity{name = "crude-oil", amount = math.random(100000, 250000), position = {xxx, yyy}, raise_built = true}
        xxx = xx + math.random(-8, 8)
        yyy = yy + math.random(4, 8)
        for xxxx = xxx - 2, xxx + 2 do
            for yyyy = yyy - 2, yyy + 2 do
                local tile = surface.get_tile(xxxx, yyyy)
                local name = tile.name
                if tile.prototype.layer <= 4 then
                    name = water_replace_tile
                end
                tiles[#tiles + 1] = {name = name, position = {xxxx, yyyy}}
            end
        end
        surface.create_entity{name = "crude-oil", amount = math.random(100000, 250000), position = {xxx, yyy}, raise_built = true}
        surface.set_tiles(tiles)
    end

    -- remove trees/stones/resources
    local entities = surface.find_entities_filtered { area = { { x - 16, y - 7 }, { x + 15, y + 9 } }, force = "neutral" }
    for _, entity in pairs(entities) do
        entity.destroy()
    end
    -- place dirt beneath structures
    tiles = {}
    for xx = x - 14, x + 13 do
        for yy = y - 5, y + 7 do
            local tile = surface.get_tile(xx, yy)
            local name = tile.name
            if tile.prototype.layer <= 4 then
                name = water_replace_tile
            end
            tiles[#tiles + 1] = { name = name, position = { xx, yy } }
        end
    end
    surface.set_tiles(tiles)

    -- place walls
    for xx = x - 3, x + 2 do
        surface.create_entity { name = "stone-wall", position = { xx, y - 3 }, force = force, raise_built = true }
        surface.create_entity { name = "stone-wall", position = { xx, y + 5 }, force = force, raise_built = true }
    end
    for yy = y - 3, y + 5 do
        surface.create_entity { name = "stone-wall", position = { x - 3, yy }, force = force, raise_built = true }
        surface.create_entity { name = "stone-wall", position = { x + 2, yy }, force = force, raise_built = true }
    end
    -- roboport
    local config = storage.forces[force.name]
    config.roboport = surface.create_entity { name = "roboport", position = { x, y }, force = force, raise_built = true }
    config.roboport.minable = false
    config.roboport.energy = 100000000
    local roboport_inventory = config.roboport.get_inventory(defines.inventory.roboport_robot)
    if settings.startup["bnw-homeworld-starting-robots"].value then
        roboport_inventory.insert { name = "bnw-homeworld-construction-robot", count = 100 }
    else
        roboport_inventory.insert { name = "construction-robot", count = 100 }
    end
    if settings.startup["bnw-homeworld-starting-robots"].value then
        roboport_inventory.insert { name = "bnw-homeworld-logistic-robot", count = 50 }
    else
        roboport_inventory.insert { name = "logistic-robot", count = 50 }
    end

    roboport_inventory = config.roboport.get_inventory(defines.inventory.roboport_material)
    roboport_inventory.insert { name = "repair-pack", count = 10 }
    -- electric pole
    local electric_pole = surface.create_entity { name = "medium-electric-pole", position = { x + 1, y + 2 }, force = force, raise_built = true }
    -- radar
    surface.create_entity { name = "radar", position = { x - 1, y + 3 }, force = force, raise_built = true }
    -- storage chest, contains the items the force starts with
    local chest1 = surface.create_entity { name = "storage-chest", position = { x + 1, y + 3 }, force = force, raise_built = true }
    local chest2 = surface.create_entity { name = "storage-chest", position = { x + 1, y + 4 }, force = force, raise_built = true }
    local chest_inventory = chest1.get_inventory(defines.inventory.chest)

    if prototypes.item["basic-transport-belt"] then
        chest_inventory.insert { name = "basic-transport-belt", count = 400 }
        chest_inventory.insert { name = "basic-underground-belt", count = 20 }
        chest_inventory.insert { name = "basic-splitter", count = 10 }
    else
        chest_inventory.insert{name = "transport-belt", count = 400}
        chest_inventory.insert{name = "underground-belt", count = 20}
        chest_inventory.insert{name = "splitter", count = 10}
    end
    chest_inventory.insert{name = "inserter", count = 20}
    chest_inventory.insert{name = "stone-furnace", count = 4}
    chest_inventory.insert{name = "offshore-pump", count = 1}
    chest_inventory.insert{name = "assembling-machine-1", count = 4}
    chest_inventory.insert{name = "roboport", count = 4}
    chest_inventory.insert{name = "storage-chest", count = 2}
    chest_inventory.insert{name = "passive-provider-chest", count = 4}
    chest_inventory.insert{name = "requester-chest", count = 4}
    chest_inventory.insert{name = "buffer-chest", count = 4}
    chest_inventory.insert{name = "active-provider-chest", count = 4}
    chest_inventory.insert{name = "lab", count = 2}
    if seablock_enabled then
        -- need some stuff for SeaBlock so we won't get stuck (also slightly accelerate gameplay)
        chest_inventory.insert{name = "offshore-pump", count = 1}
        chest_inventory.insert{name = "wood-pellets", count = 50}
        chest_inventory = chest2.get_inventory(defines.inventory.chest)
        chest_inventory.insert{name = "angels-electrolyser", count = 4}
        chest_inventory.insert{name = "angels-flare-stack", count = 2}
        chest_inventory.insert{name = "burner-ore-crusher", count = 3}
        chest_inventory.insert{name = "liquifier", count = 1}
        chest_inventory.insert{name = "crystallizer", count = 1}
        chest_inventory.insert{name = "algae-farm", count = 2}

        local ignored_items = {
            ["copper-pipe"] = true,
            ["iron-gear-wheel"] = true,
            ["iron-stick"] = true,
            ["pipe"] = true,
            ["pipe-to-ground"] = true,
        }
        for item_name, item_count in pairs(seablock_items) do
            if not ignored_items[item_name] then
              chest_inventory.insert{name = item_name, count = item_count}
            end
        end
    else
        -- only give player this when we're not seablocking
        chest_inventory.insert{name = "electric-mining-drill", count = 4}
        chest_inventory.insert{name = "pipe", count = 20}
        chest_inventory.insert{name = "pipe-to-ground", count = 10}
        chest_inventory.insert{name = "burner-inserter", count = 4}
        chest_inventory.insert{name = "medium-electric-pole", count = 50}
        chest_inventory.insert{name = "small-lamp", count = 10}
        chest_inventory.insert{name = "boiler", count = 1}
        chest_inventory.insert{name = "steam-engine", count = 2}
        chest_inventory.insert{name = "gun-turret", count = 2}
        chest_inventory.insert{name = "firearm-magazine", count = 20}
    end
    -- solar panels and accumulators (left side)
    surface.create_entity{name = "solar-panel", position = {x - 11, y - 2}, force = force, raise_built = true}
    surface.create_entity{name = "solar-panel", position = {x - 11, y + 1}, force = force, raise_built = true}
    surface.create_entity{name = "solar-panel", position = {x - 11, y + 4}, force = force, raise_built = true}
    surface.create_entity{name = "solar-panel", position = {x - 8, y + 4}, force = force, raise_built = true}
    surface.create_entity{name = "solar-panel", position = {x - 5, y - 2}, force = force, raise_built = true}
    surface.create_entity{name = "solar-panel", position = {x - 5, y + 4}, force = force, raise_built = true}
    surface.create_entity{name = "medium-electric-pole", position = {x - 7, y}, force = force, raise_built = true}
    surface.create_entity{name = "small-lamp", position = {x - 6, y}, force = force, raise_built = true}
    local accumulator = surface.create_entity{name = "accumulator", position = {x - 8, y - 2}, force = force, raise_built = true}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 8, y}, force = force, raise_built = true}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 8, y + 2}, force = force, raise_built = true}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 6, y + 2}, force = force, raise_built = true}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 4, y + 2}, force = force, raise_built = true}
    accumulator.energy = 5000000
    -- solar panels and accumulators (right side)
    surface.create_entity{name = "solar-panel", position = {x + 4, y - 2}, force = force, raise_built = true}
    surface.create_entity{name = "solar-panel", position = {x + 4, y + 4}, force = force, raise_built = true}
    surface.create_entity{name = "solar-panel", position = {x + 7, y + 4}, force = force, raise_built = true}
    surface.create_entity{name = "solar-panel", position = {x + 10, y - 2}, force = force, raise_built = true}
    surface.create_entity{name = "solar-panel", position = {x + 10, y + 1}, force = force, raise_built = true}
    surface.create_entity{name = "solar-panel", position = {x + 10, y + 4}, force = force, raise_built = true}
    surface.create_entity{name = "medium-electric-pole", position = {x + 6, y}, force = force, raise_built = true}
    surface.create_entity{name = "small-lamp", position = {x + 5, y}, force = force, raise_built = true}
    accumulator = surface.create_entity{name = "accumulator", position = {x + 4, y + 2}, force = force, raise_built = true}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 6, y + 2}, force = force, raise_built = true}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 8, y - 2}, force = force, raise_built = true}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 8, y}, force = force, raise_built = true}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 8, y + 2}, force = force, raise_built = true}
    accumulator.energy = 5000000
end

local function preventMining(player)
    -- prevent mining (this appeared to be reset when loading a 0.16.26 save in 0.16.27)
    player.force.manual_mining_speed_modifier = -0.99999999 -- allows removing ghosts with right-click
end

script.on_event(defines.events.on_player_created, function(event)
    if not storage.players then
        storage.players = {}
    end
    local player = game.players[event.player_index]
    storage.players[event.player_index] = {
        crafted = {},
        inventory_items = {},
        previous_position = player.position
    }

    if player.character then
        player.character.destroy()
        player.character = nil
    end
    -- disable light
    player.disable_flashlight()
    -- enable cheat mode
    player.cheat_mode = true

    local seablock_enabled = script.active_mods["SeaBlock"] and true or false

    local default_qb_slots = get_default_qb_slots(seablock_enabled)

    -- Set-up a sane default for the quickbar
    for i = 1, 100 do
        if not player.get_quick_bar_slot(i) then
            if default_qb_slots[i] then
                player.set_quick_bar_slot(i, default_qb_slots[i])
            end
        end
    end

    storage.bnw_scenario_version = script.active_mods["brave-new-world"]
    -- setup force
    setupForce(player.force, player.surface, 0, 0, seablock_enabled)
    preventMining(player)
end)

script.on_configuration_changed(function(chgdata)
    local new = script.active_mods["brave-new-world"]
    if new ~= nil then
        local old = storage.bnw_scenario_version
        if old ~= new then
            game.reload_script()
            storage.bnw_scenario_version = new
        end
    end
end)

script.on_event(defines.events.on_player_pipette, function(event)
    if storage.creative then
        return
    end
    game.players[event.player_index].cursor_stack.clear()
    game.players[event.player_index].cursor_ghost = event.item
end)

script.on_event(defines.events.on_player_crafted_item, function(event)
    if storage.creative then
        return
    end
    game.players[event.player_index].cursor_ghost = event.item_stack.prototype
    event.item_stack.count = 0
end)

script.on_event(defines.events.on_player_main_inventory_changed, inventoryChanged)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    if storage.creative then
        return
    end
    local player = game.players[event.player_index]
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read then
        local allowed = itemCountAllowed(cursor.name, cursor.count, player)
        local to_remove = cursor.count - allowed
        if to_remove > 0 then
            dropItems(player, cursor.name, to_remove)
            if allowed > 0 then
                cursor.count = allowed
            else
                player.cursor_ghost = cursor.prototype
                player.cursor_stack.clear()
            end
        end
    end
    -- check if user is in trouble due to insufficient storage
    local alerts = player.get_alerts{type = defines.alert_type.no_storage}
    local out_of_storage = false
    for _, surface in pairs(alerts) do
        for _, alert_type in pairs(surface) do
            for _, alert in pairs(alert_type) do
                local entity = alert.target
                if (entity.name == "bnw-homeworld-construction-robot") or (entity.name == "construction-robot") then
                    out_of_storage = true
                    local inventory = entity.get_inventory(defines.inventory.robot_cargo)
                    if inventory then
                        for name, count in pairs(inventory.get_contents()) do
                            entity.surface.spill_item_stack(entity.position, {name = name, count = count})
                        end
                    end
                    entity.clear_items_inside()
                end
            end
        end
    end
    if out_of_storage then
        player.print({"out-of-storage"})
    end
end)

script.on_event(defines.events.on_entity_died, function(event)
    if storage.creative then
        return
    end
    local entity = event.entity
    -- check if roboport was destroyed
    local config = storage.forces[entity.force.name]
    if config and entity == config.roboport then
        game.set_game_state { game_finished = true, player_won = false, can_continue = false }
    end
end)

script.on_event(defines.events.on_player_changed_position, function(event)
    if storage.creative then
        return
    end
    local player = game.players[event.player_index]
    -- TODO: really shouldn't have to do this so often (can we do it in migrate function?)
    preventMining(player)

    local config = storage.forces[player.force.name]
    local x_chunk = math.floor(player.position.x / 32)
    local y_chunk = math.floor(player.position.y / 32)
    -- prevent player from exploring, unless in a vehicle
    if not player.vehicle then
        local charted = function(x, y)
           return player.force.is_chunk_charted(player.surface, {x, y}) and
              (player.force.is_chunk_charted(player.surface, {x - 2, y - 2}) or not player.surface.is_chunk_generated({x - 2, y - 2})) and
              (player.force.is_chunk_charted(player.surface, {x - 2, y + 2}) or not player.surface.is_chunk_generated({x - 2, y + 2})) and
              (player.force.is_chunk_charted(player.surface, {x + 2, y - 2}) or not player.surface.is_chunk_generated({x + 2, y - 2})) and
              (player.force.is_chunk_charted(player.surface, {x + 2, y + 2}) or not player.surface.is_chunk_generated({x + 2, y + 2}))
        end
        if not charted(math.floor(player.position.x / 32), math.floor(player.position.y / 32)) then
            -- can't move here, chunk not charted
            local prev_pos = storage.players[event.player_index].previous_position
            if charted(math.floor(player.position.x / 32), math.floor(prev_pos.y / 32)) then
                -- we can move here, though
                prev_pos.x = player.position.x
            elseif charted(math.floor(prev_pos.x / 32), math.floor(player.position.y / 32)) then
                -- or here
                prev_pos.y = player.position.y
            end
            -- teleport player to (possibly modified) prev_pos
            player.teleport(prev_pos)
        end
    end
    -- save new player position
    storage.players[event.player_index].previous_position = player.position
end)
