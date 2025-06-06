-- How to make http server in lua that will listen to custom port and handle requests.
-- it need to handle get and post requests, and it must check if the bearer token is valid.
-- if the token is valid, it should return a 200 status code and the body should be the user id.
-- if the token is invalid, it should return a 401 status code.
-- the server should be able to handle multiple requests concurrently.
-- the server should be able to handle requests from multiple clients.
-- the server should be able to handle requests from multiple clients concurrently.


function GetPluginAuthor()
    return "CS2ServerList"
end

function GetPluginVersion()
    return "1.0.0"
end

function GetPluginName()
    return "CS2ServerList"
end

function GetPluginWebsite()
    return "https://cs2serverlist.com"
end

config:Create("cs2serverlist", {
    server_api_key = "",
})

