---@class PlayerEntry
---@field username string Player name
---@field steamId number Steam ID of the player
---@field kills number Number of kills
---@field deaths number Number of deaths
---@field headshots number Number of headshots
---@field assists number Number of assists
---@field playtime number Total playtime in seconds
---@field rounds_wins number Number of rounds won
---@field rounds_lost number Number of rounds lost
---@field team number Team ID
---@field team_string string Team name (T/CT/none)
---@field timeJoined number Time when player joined
---@field avatar_hash string Avatar hash from Steam
---@field avatar_cached number Time when avatar was cached
---@field teamJoinTime number Time when player joined current team
---@field current_kills number Current kills
---@field current_deaths number Current deaths
---@field current_assists number Current assists
---@field current_headshots number Current headshots
---@field _controller CCSPlayerController Player controller reference
---@function reset
---@function updatePlaytime
---@function updateTeam
---@function getData
---@function getAvatarHash
---@function getAll
---@function remove
-- Player class for CS2 Server List

PlayerEntry = {} -- Make it global by removing local
PlayerEntry.__index = PlayerEntry

---@param controller CCSPlayerController
---@param username string
---@param steamId number
---@param team number
---@param timeJoined number
---@return PlayerEntry
function PlayerEntry.new(controller, username, steamId, team, timeJoined)
    local steamId = steamId


    local team_string = "none";
    if team == Team.T then
        team_string = "t"
    elseif team == Team.CT then
        team_string = "ct"
    elseif team == Team.Spectator then
        team_string = "spectator"
    end
   
    -- Create new player object
    local self = setmetatable({
        username = username,
        steamId = steamId,
        kills = 0,
        deaths = 0,
        headshots = 0,
        assists = 0,
        playtime = 0,
        rounds_wins = 0,
        rounds_lost = 0,
        team = team,
        team_string = team_string,
        timeJoined = timeJoined,
        avatar_hash = "",
        avatar_cached = 0,
        teamJoinTime = 0,
        _controller = controller,
    }, PlayerEntry)


    return self
end

-- Reset player statistics
function PlayerEntry:reset()
    self.kills = 0
    self.deaths = 0
    self.headshots = 0
    self.assists = 0
    self.playtime = 0
    self.rounds_wins = 0
    self.rounds_lost = 0
end

-- Update player's playtime
function PlayerEntry:updatePlaytime()
    -- Only count playtime for players on CT or T teams
    if self.team == 2 or self.team == 3 then
        local secondsInTeam = (os.time() - self.teamJoinTime)
        self.playtime = self.playtime + secondsInTeam
    end
    self.teamJoinTime = os.time()
end

-- Update player team information
---@param teamId integer
function PlayerEntry:updateTeam(teamId)
    self:updatePlaytime() -- Update playtime when changing teams
    self.team = teamId

    if teamId == Team.T then
        self.team_string = "t"
    elseif teamId == Team.CT then
        self.team_string = "ct"
    elseif teamId == Team.Spectator then
        self.team_string = "spectator"
    else
        self.team_string = "none"
    end
end

-- Get player data as table
function PlayerEntry:getData()
    ---@type CSPerRoundStats_t
    local matchStats = self._controller.ActionTrackingServices.MatchStats.Parent

    local team_string = "none";
    if self.team == Team.T then
        team_string = "t"
    elseif self.team == Team.CT then
        team_string = "ct"
    elseif self.team == Team.Spectator then
        team_string = "spectator"
    end 

    return {
        username = self.username,
        steamId = self.steamId,
        kills = self.kills,
        deaths = self.deaths,
        headshots = self.headshots,
        assists = self.assists,
        playtime = self.playtime,
        rounds_wins = self.rounds_wins,
        rounds_lost = self.rounds_lost,
        team = self.team,
        team_string = team_string,
        timeJoined = self.timeJoined,
        avatar_hash = self.avatar_hash,
        avatar_cached = self.avatar_cached,
        current_kills = matchStats.Kills,
        current_deaths = matchStats.Deaths,
        current_assists = matchStats.Assists,
        current_headshots = matchStats.HeadShotKills,
    }
end

function PlayerEntry:getAvatarHash()
    return self.avatar_hash
end

-- Get all players
function PlayerEntry.getAll()
    return PLAYER_DATA
end

-- Remove player by steam ID
function PlayerEntry.remove(steamId)
    PLAYER_DATA[steamId] = nil
end
