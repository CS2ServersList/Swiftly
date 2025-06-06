
--Fix for the when player change teams ct->spec or t->spec
AddEventHandler("OnPostPlayerTeam", function(p_Event)
    if p_Event:GetBool("disconnect") then
        return EventResult.Continue
    end

    local l_PlayerId = p_Event:GetInt("userid")
    local l_Player = GetPlayer(l_PlayerId)

    if not l_Player or not l_Player:IsValid() then
        return
    end

    local l_Team = p_Event:GetInt("team")

    NextTick(function()
        if not l_Player:IsValid() then
            return
        end

        l_Player:CBaseEntity().TeamNum = l_Team
    end)
end)

AddEventHandler("OnPluginStart", function(event)
    print("CS2 Server List loaded")

    -- For backward compatibility, synchronize with PLAYER_DATA
    for i = 1, playermanager:GetPlayerCap() do
        ---@type Player
        local player = GetPlayer(i - 1)
        if isValidPlayer(player) then
            local steamId = player:GetSteamID()
         
            ---@type PlayerEntry
            local playerEntity = PLAYER_DATA[steamId]
            if not playerEntity then
                PLAYER_DATA[steamId] = PlayerEntry.new(player:CCSPlayerController(), player:CBasePlayerController().PlayerName, steamId,
                    player:CBaseEntity().TeamNum, os.time())

                --fetch avatar data for newly added players
                FetchAvatarData(PLAYER_DATA[steamId])
            end
        end
    end

    return EventResult.Continue
end)

AddEventHandler("OnPluginStop", function(event)
    --we need to send all players data to the api with event server_unload

    return EventResult.Continue
end)

--map end?

AddEventHandler("OnPlayerDeath", function(event)
    if (IS_WARMUP_ROUND) then return EventResult.Continue end

    ---@type Player
    local victim = GetPlayer(event:GetInt("userid"))
    if isValidPlayer(victim) then
        ---@type PlayerEntry
        local victimEntity = PLAYER_DATA[victim:GetSteamID()];
        victimEntity.deaths = victimEntity.deaths + 1
    end

    ---@type Player
    local attacker = GetPlayer(event:GetInt("attacker"))
    if isValidPlayer(attacker) and attacker:GetSteamID() ~= victim:GetSteamID() then
        ---@type PlayerEntry
        local attackerEntity = PLAYER_DATA[attacker:GetSteamID()];
        attackerEntity.kills = attackerEntity.kills + 1

        local headshot = event:GetBool("headshot")
        if headshot then
            attackerEntity.headshots = attackerEntity.headshots + 1
        end
    end


    ---@type Player
    local assister = GetPlayer(event:GetInt("assister"))
    if isValidPlayer(assister) and assister:GetSteamID() ~= victim:GetSteamID() then
        ---@type PlayerEntry
        local assisterEntity = PLAYER_DATA[assister:GetSteamID()];
        assisterEntity.assists = assisterEntity.assists + 1
    end

    return EventResult.Continue
end)

AddEventHandler("OnServerShutdown", function(event)
    SendPlayerDataToApi("server_shutdown", nil)
    return EventResult.Continue
end)

AddEventHandler("OnPlayerConnectFull", function(event)
    local player = GetPlayer(event:GetInt("userid"))
    if not isValidPlayer(player) then return EventResult.Continue end

    local playerEntity = PlayerEntry.new(player:CCSPlayerController(), player:CBasePlayerController().PlayerName, player:GetSteamID(), player:CBaseEntity().TeamNum,
        os.time())
    PLAYER_DATA[player:GetSteamID()] = playerEntity
    FetchAvatarData(playerEntity)
    return EventResult.Continue
end)

AddEventHandler("OnPlayerDisconnect", function(event)
    local reason = event:GetInt("reason")
    if reason ~= 1 then
        local player = GetPlayer(event:GetInt("userid"))
        if not isValidPlayer(player) then return EventResult.Continue end

        ---@type PlayerEntry
        local playerEntity = PLAYER_DATA[player:GetSteamID()]
        playerEntity:updatePlaytime();

        if HasPlayerStatsChanged(playerEntity) then
            SendPlayerDataToApi("player_disconnect", playerEntity)
        end
    end

    return EventResult.Continue
end)

AddEventHandler("OnPostPlayerTeam", function(event)

    local player = GetPlayer(event:GetInt("userid"))
    if not isValidPlayer(player) then return EventResult.Continue end
    
    ---@type PlayerEntry
    local playerEntity = PLAYER_DATA[player:GetSteamID()]

    if not playerEntity then
        PLAYER_DATA[player:GetSteamID()] = PlayerEntry.new(player:CCSPlayerController(), player:CBasePlayerController().PlayerName, player:GetSteamID(),
        event:GetInt("team"), os.time())
    else    
        playerEntity:updatePlaytime();
        playerEntity:updateTeam(event:GetInt("team"))
    end

    SendPlayerDataToApi("player_team", playerEntity)

    return EventResult.Continue
end)

AddEventHandler("OnRoundEnd", function(event)
    if IS_WARMUP_ROUND then return EventResult.Continue end

    -- For backward compatibility, synchronize with PLAYER_DATA
    for i = 1, playermanager:GetPlayerCap() do
        ---@type Player
        local player = GetPlayer(i - 1)
        if isValidPlayer(player) then
            local steamId = player:GetSteamID()
            ---@type PlayerEntry
            local playerEntity = PLAYER_DATA[steamId]
            if not playerEntity then
                PLAYER_DATA[steamId] = PlayerEntry.new(player:CCSPlayerController(), player:CBasePlayerController().PlayerName, steamId,
                    player:CBaseEntity().TeamNum, os.time())

                --fetch avatar data for newly added players
                FetchAvatarData(PLAYER_DATA[steamId])
            end
        end
    end


    local winnerTeam = event:GetInt("winner")

    --for PLAYER_DATA, update the rounds_wins and rounds_lost

    ---@type PlayerEntry
    for steamId, playerData in pairs(PLAYER_DATA) do
        ---@type PlayerEntry
        local playerEntity = playerData
        if playerEntity.team == winnerTeam then
            playerEntity.rounds_wins = playerEntity.rounds_wins + 1
        elseif (playerEntity.team == Team.CT or playerEntity.team == Team.T) and playerEntity.team ~= winnerTeam then
            playerEntity.rounds_lost = playerEntity.rounds_lost + 1
        end
    end

    SendPlayerDataToApi("rounds_end", nil)

    return EventResult.Continue
end)

AddEventHandler("OnBeginNewMatch", function(event)
    IS_WARMUP_ROUND = false

    return EventResult.Continue
end)

AddEventHandler("OnWarmUpEnd", function(event)
    IS_WARMUP_ROUND = false


    --reset player data

    for steamId, playerData in pairs(PLAYER_DATA) do
        ---@type PlayerEntry
        local playerEntity = playerData
        playerEntity:reset()
    end

    return EventResult.Continue
end)



AddEventHandler("OnWeaponFire", function(event)
    --[[ ... ]]
    return EventResult.Continue
end)

AddEventHandler("OnPlayerHurt", function(event)
    --[[ ... ]]
    return EventResult.Continue
end)


---@param player PlayerEntry
function FetchAvatarData(player)
    PerformHTTPRequest("https://steamcommunity.com/profiles/" .. player.steamId .. "/?xml=1",
        function(status, body, headers, err)
            if status ~= 200 then
                print("Could not connect to Steam API")
                return;
            end
            --Extract hash from URL like https://avatars.fastly.steamstatic.com/7171bcaccc769c6734461e7263ea5af80ccc2c9c_full.jpg
            --we need need only the hash
            local avatarHash = string.match(body, "<avatarFull>(.-)</avatarFull>")
            player.avatar_hash = string.match(avatarHash, "https://avatars.fastly.steamstatic.com/(.-)_full.jpg")
            player.avatar_cached = os.time()
        end, "GET", "", {}, {})
end

function SendPlayerDataToApi(eventType, specificPlayer)
    -- For global events like round_end, always send data
    -- For specific player events, check if we can make a request now
    if specificPlayer ~= nil and eventType ~= "rounds_end" and eventType ~= "server_unload" and not CanMakeRequest() then
        print("Request skipped for " .. eventType .. ": Another request is in progress or cooldown period not elapsed")
        return
    end

    -- Always allow round_end events, only throttle individual player events
    if specificPlayer ~= nil and eventType ~= "rounds_end" and eventType ~= "server_unload" then
        REQUEST_IN_PROGRESS = true
        LAST_REQUEST_TIME = os.time()
    end

    -- Prepare player data to send
    local playerDataList = {}
    
    if specificPlayer ~= nil then
        -- For specific player events, check if any stats have changed
        if eventType ~= "player_disconnect" and
           eventType ~= "player_team" and
           not HasPlayerStatsChanged(specificPlayer) then
            -- No stats have changed, don't send the request
            if specificPlayer ~= nil then 
                REQUEST_IN_PROGRESS = false
            end
            return
        end
        
        -- Send data for a specific player only
        table.insert(playerDataList, specificPlayer)
    else
        -- Send data for all valid players
        for steamId, playerData in pairs(PLAYER_DATA) do
            ---@type PlayerEntry
            local playerEntity = playerData
            -- Only include players with valid controllers
            table.insert(playerDataList, playerEntity)
        end
    end

    if #playerDataList == 0 then
        if specificPlayer ~= nil then 
            REQUEST_IN_PROGRESS = false
        end
        return
    end

    -- Create URL-encoded form data
    local formData = "event_type=" .. eventType .. 
                     "&map=" .. (GetMapName() or "") .. 
                     "&server_ip=" .. (GetServerIp() or "") .. 
                     "&max_players=" .. server:GetMaxPlayers() .. 
                     "&online_players=" .. GetOnlinePlayers() .. 
                     "&bots_count=" .. GetBotsCount()
    
    -- Add player data as individual form fields
    for i, playerInfo in ipairs(playerDataList) do

        ---@type PlayerEntry
        local playerData =playerInfo:getData()
        
        formData = formData .. 
                  "&players[" .. (i-1) .. "][username]=" .. tostring(playerData.username) ..
                  "&players[" .. (i-1) .. "][steam_id]=" .. tostring(playerData.steamId) ..
                  "&players[" .. (i-1) .. "][kills]=" .. tostring(playerData.kills) ..
                  "&players[" .. (i-1) .. "][deaths]=" .. tostring(playerData.deaths) ..
                  "&players[" .. (i-1) .. "][headshots]=" .. tostring(playerData.headshots) ..
                  "&players[" .. (i-1) .. "][assists]=" .. tostring(playerData.assists) ..
                  "&players[" .. (i-1) .. "][rounds_wins]=" .. tostring(playerData.rounds_wins) ..
                  "&players[" .. (i-1) .. "][rounds_loses]=" .. tostring(playerData.rounds_lost) ..
                  "&players[" .. (i-1) .. "][playtime]=" .. tostring(playerData.playtime) ..
                  "&players[" .. (i-1) .. "][team]=" .. tostring(playerData.team) ..
                  "&players[" .. (i-1) .. "][team_string]=" .. tostring(playerData.team_string) ..
                  "&players[" .. (i-1) .. "][current_kills]=" .. tostring(playerData.current_kills) ..
                  "&players[" .. (i-1) .. "][current_deaths]=" .. tostring(playerData.current_deaths) ..
                  "&players[" .. (i-1) .. "][current_assists]=" .. tostring(playerData.current_assists) ..
                  "&players[" .. (i-1) .. "][current_headshots]=" .. tostring(playerData.current_headshots)

        if playerData.avatar_hash and playerData.avatar_hash ~= "" then
            formData = formData .. "&players[" .. (i-1) .. "][avatar_hash]=" .. playerData.avatar_hash
        end
    end
    
    -- Send the HTTP request
    PerformHTTPRequest(API_END_POINT .. "/server-data", function(status, body, headers, err)
        if status ~= 200 and status ~= 201 then
            print("Failed to send server data. Status: " .. status .. ", Response: " .. (body or ""))
        else
            print("Successfully sent " .. #playerDataList .. " player records for event: " .. eventType)
            
            -- Reset stats after successful API send if it's a round end or team change event
            if eventType == "rounds_end" or eventType == "player_team" or eventType == "server_unload" then
                if specificPlayer ~= nil then
                    specificPlayer:reset()
                else
                    for steamId, playerData in pairs(PLAYER_DATA) do
                        ---@type PlayerEntry
                        local playerEntity = playerData
                        playerEntity:reset()
                    end
                end
            end
        end
        
        -- Only reset the flag if this was a specific player event (not rounds_end)
        if specificPlayer ~= nil and eventType ~= "rounds_end" and eventType ~= "server_unload" then
            REQUEST_IN_PROGRESS = false
        end
    end, "POST", formData, { 
        ["Authorization"] = "Bearer " .. config:Fetch("cs2serverlist.server_api_key"), 
        ["Content-Type"] = "application/x-www-form-urlencoded" 
    }, {})
end

-- Helper function to check if player stats have changed
function HasPlayerStatsChanged(player)
    -- Check if any key stats have non-zero values
    return player.kills > 0 or
           player.deaths > 0 or
           player.assists > 0 or
           player.headshots > 0 or
           player.rounds_wins > 0 or
           player.rounds_lost > 0 or
           player.playtime > 0
end

-- Helper functions for server data
function GetMapName()
    return server:GetMap();
end

function GetServerIp()
    return server:GetIP()..':'..convar:Get("hostport");
end

function GetOnlinePlayers()
    local count = 0
    for i = 1, playermanager:GetPlayerCap() do
        local player = GetPlayer(i - 1)
        if isValidPlayer(player) then
            count = count + 1
        end
    end
    return count
end

function GetBotsCount()
    local count = 0
    for i = 1, playermanager:GetPlayerCap() do
        local player = GetPlayer(i - 1)
        if player and player:IsValid() and player:IsFakeClient() then
            count = count + 1
        end
    end
    return count
end

function CanMakeRequest()
    if REQUEST_IN_PROGRESS then return false end
    if (os.time() - LAST_REQUEST_TIME) < REQUEST_COOLDOWN then return false end
    return true
end

---@param player Player
function isValidPlayer(player)
    if not player or not player:IsValid() then return false end
    if player:IsFakeClient() then return false end
    return true
end


SetTimer(30000, function ()
    for steamId, playerData in pairs(PLAYER_DATA) do
        ---@type PlayerEntry
        local playerEntity = playerData
        playerEntity:updatePlaytime();
    end
end)