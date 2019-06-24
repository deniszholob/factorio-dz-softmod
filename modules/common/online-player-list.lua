-- Online Player List Soft Module
-- Displays a list of current players
-- Uses locale player-list.cfg
-- @usage require('modules/common/online-player-list')
-- ------------------------------------------------------- --
-- @author Denis Zholob (DDDGamer)
-- github: https://github.com/deniszholob/factorio-softmod-pack
-- ======================================================= --

-- Dependencies --
-- ======================================================= --
local mod_gui = require('mod-gui') -- From `Factorio\data\core\lualib`
local GUI = require('stdlib/GUI')
local Sprites = require('util/Sprites')
local Math = require('util/Math')
local Time = require('util/Time')

-- Constants --
-- ======================================================= --
local Player_List = {
    MENU_BTN_NAME = 'btn_menu_playerlist',
    MASTER_FRAME_NAME = 'frame_playerlist',
    CHECKBOX_OFFLINE_PLAYERS = 'chbx_playerlist_players',
    SPRITE_NAMES = {
        menu = Sprites.character,
        -- inventory = 'utility/grey_rail_signal_placement_indicator'
        -- inventory = 'utility/item_editor_icon'
        inventory = 'utility/slot_icon_armor'
    },
    -- Utf shapes https://www.w3schools.com/charsets/ref_utf_geometric.asp
    -- Utf symbols https://www.w3schools.com/charsets/ref_utf_symbols.asp
    ONLINE_SYMBOL = '●',
    OFFLINE_SYMBOL = '○',
    ADMIN_SYMBOL = '★',
    OWNER = 'DDDGamer',
    BTN_INVENTORY_OWNER_ONLY = false
}

-- Event Functions --
-- ======================================================= --

-- When new player joins add the playerlist btn to their GUI
-- Redraw the playerlist frame to update with the new player
-- @param event on_player_joined_game
function Player_List.on_player_joined_game(event)
    local player = game.players[event.player_index]
    Player_List.draw_playerlist_btn(player)
    Player_List.draw_playerlist_frame()
end

-- On Player Leave
-- Clean up the GUI in case this mod gets removed next time
-- Redraw the playerlist frame to update
-- @param event on_player_left_game
function Player_List.on_player_left_game(event)
    local player = game.players[event.player_index]
    GUI.destroy_element(mod_gui.get_button_flow(player)[Player_List.MENU_BTN_NAME])
    GUI.destroy_element(mod_gui.get_frame_flow(player)[Player_List.MASTER_FRAME_NAME])
    Player_List.draw_playerlist_frame()
end

-- Toggle playerlist is called if gui element is playerlist button
-- @param event on_gui_click
function Player_List.on_gui_click(event)
    local player = game.players[event.player_index]
    local el_name = event.element.name

    if el_name == Player_List.MENU_BTN_NAME then
        GUI.toggle_element(mod_gui.get_frame_flow(player)[Player_List.MASTER_FRAME_NAME])
    end
    if (el_name == Player_List.CHECKBOX_OFFLINE_PLAYERS) then
        player_config = Player_List.getConfig(player)
        player_config.show_offline_players = not player_config.show_offline_players
        Player_List.draw_playerlist_frame()
    end
end

-- Refresh the playerlist after 10 min
-- @param event on_tick
function Player_List.on_tick(event)
    local refresh_period = 1 --(min)
    if (Time.tick_to_min(game.tick) % refresh_period == 0) then
        Player_List.draw_playerlist_frame()
    end
end

-- Event Registration --
-- ======================================================= --
Event.register(defines.events.on_gui_checked_state_changed, Player_List.on_gui_click)
Event.register(defines.events.on_gui_click, Player_List.on_gui_click)
Event.register(defines.events.on_player_joined_game, Player_List.on_player_joined_game)
Event.register(defines.events.on_player_left_game, Player_List.on_player_left_game)
Event.register(defines.events.on_tick, Player_List.on_tick)

-- Helper Functions --
-- ======================================================= --

-- Create button for player if doesnt exist already
-- @param player LuaPlayer
function Player_List.draw_playerlist_btn(player)
    if mod_gui.get_button_flow(player)[Player_List.MENU_BTN_NAME] == nil then
        mod_gui.get_button_flow(player).add(
            {
                type = 'sprite-button',
                name = Player_List.MENU_BTN_NAME,
                sprite = Player_List.SPRITE_NAMES.menu,
                -- caption = 'Online Players',
                tooltip = {'player_list.btn_tooltip'}
            }
        )
    end
end

-- Draws a pane on the left listing all of the players currentely on the server
function Player_List.draw_playerlist_frame()
    local player_list = {}
    -- Copy player list into local list
    for i, player in pairs(game.players) do
        table.insert(player_list, player)
    end

    -- Sort players based on admin role, and time played
    -- Admins first, highest playtime first
    table.sort(player_list, Player_List.sort_players)

    for i, player in pairs(game.players) do
        local master_frame = mod_gui.get_frame_flow(player)[Player_List.MASTER_FRAME_NAME]
        -- Draw the vertical frame on the left if its not drawn already
        if master_frame == nil then
            master_frame =
                mod_gui.get_frame_flow(player).add(
                {type = 'frame', name = Player_List.MASTER_FRAME_NAME, direction = 'vertical'}
            )
        end
        -- Clear and repopulate player list
        GUI.clear_element(master_frame)

        -- Flow
        local flow_header = master_frame.add({type = 'flow', direction = 'horizontal'})
        flow_header.style.horizontal_spacing = 20

        -- Draw checkbox
        flow_header.add(
            {
                type = 'checkbox',
                name = Player_List.CHECKBOX_OFFLINE_PLAYERS,
                caption = {'player_list.checkbox_caption'},
                tooltip = {'player_list.checkbox_tooltip'},
                state = Player_List.getConfig(player).show_offline_players or false
            }
        )

        -- Draw total number
        flow_header.add(
            {
                type = 'label',
                caption = {'player_list.total_players', #game.players}
            }
        )

        -- Add scrollable section to content frame
        local scrollable_content_frame =
            master_frame.add(
            {
                type = 'scroll-pane',
                vertical_scroll_policy = 'auto-and-reserve-space',
                horizontal_scroll_policy = 'never'
            }
        )
        scrollable_content_frame.style.maximal_height = 600

        -- List all players
        for j, list_player in pairs(player_list) do
            if (list_player.connected or Player_List.getConfig(player).show_offline_players) then
                Player_List.add_player_to_list(scrollable_content_frame, player, list_player)
            end
        end
    end
end

-- @tparam LuaPlayer player the one who is doing the opening (display the other player inventory for this player)
-- @tparam LuaPlayer target_player who's inventory to open
function Player_List.open_player_inventory(player, target_player)
    if(player.opened == game.players[target_player.name]) then
        game.print('Opened!')
        player.opened = nil
    elseif(not player.opened) then
        player.opened = game.players[target_player.name]
    end
end

-- Add a player to the GUI list
-- @param player
-- @param target_player
-- @param color
-- @param tag
function Player_List.add_player_to_list(container, player, target_player)
    local played_hrs = Time.tick_to_hour(target_player.online_time)
    played_hrs = tostring(Math.round(played_hrs, 1))
    local played_percentage = 1
    if (game.tick > 0) then
        played_percentage = target_player.online_time / game.tick
    end
    local color = {
        r = target_player.color.r,
        g = target_player.color.g,
        b = target_player.color.b,
        a = 1
    }

    -- Player list entry
    local player_online_status = ''
    local player_admin_status = ''
    if (target_player.admin) then
        player_admin_status = ' ' .. Player_List.ADMIN_SYMBOL
    end
    if (Player_List.getConfig(player).show_offline_players) then
        player_online_status = Player_List.OFFLINE_SYMBOL
        if (target_player.connected) then
            player_online_status = Player_List.ONLINE_SYMBOL
        end
        player_online_status = player_online_status .. ' '
    end
    local caption_str =
        string.format('%s%s hr - %s%s', player_online_status, played_hrs, target_player.name, player_admin_status)

    local flow = container.add({type = 'flow', direction = 'horizontal'})

    -- Add an inventory open button for those with privilages
    if (
        (Player_List.BTN_INVENTORY_OWNER_ONLY and player.name == Player_List.OWNER and not target_player.admin) or
        (not Player_List.BTN_INVENTORY_OWNER_ONLY and player.admin == true and not target_player.admin)
    ) then
        local btn_sprite = GUI.add_sprite_button(
        flow,
        {
            type = 'sprite-button',
            name = 'btn_open_inventory_'..target_player.name,
            sprite = GUI.get_safe_sprite_name(player, Player_List.SPRITE_NAMES.inventory),
            tooltip = 'Open ' .. target_player.name .. ' inventory'
        },
        -- On Click callback function
        function(event)
            Player_List.open_player_inventory(player, target_player)
        end
    )
    GUI.element_apply_style(btn_sprite, Styles.small_button)
    end

    -- Add in the entry to the player list
    local entry = flow.add({type = 'label', name = target_player.name, caption = caption_str})
    entry.style.font_color = color
    entry.style.font = 'default-bold'

    local entry_bar =
        container.add(
        {
            type = 'progressbar',
            name = 'bar_' .. target_player.name,
            value = played_percentage
        }
    )
    entry_bar.style.color = color
    entry_bar.style.height = 2
end

-- Returns the playerlist config for specified player, creates default config if none exist
-- @tparam LuaPlayer player
function Player_List.getConfig(player)
    if (not global.playerlist_config) then
        global.playerlist_config = {}
    end

    if (not global.playerlist_config[player.name]) then
        global.playerlist_config[player.name] = {
            show_offline_players = false
        }
    end

    return global.playerlist_config[player.name]
end

-- Sort players based on connection, admin role, and time played
-- Connected first, Admins first, highest playtime first
-- @tparam LuaPlayer a
-- @tparam LuaPlayer b
function Player_List.sort_players(a, b)
    if ((a.connected and b.connected) or (not a.connected and not b.connected)) then
        if ((a.admin and b.admin) or (not a.admin and not b.admin)) then
            return a.online_time > b.online_time
        else
            return a.admin
        end
    else
        return a.connected
    end
end
