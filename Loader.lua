--[[
    Abysall Hub (Doors) on JustLib
    ------------------------------------------------------------
    Usage (executor):
        getgenv().AbysallConfig = {
            BaseUrl = "https://raw.githubusercontent.com/<you>/<repo>/main/AbysallJustLib/",
            -- or run from files in your executor's workspace folder:
            -- LocalFolder = "AbysallJustLib",
        }
        loadstring(game:HttpGet(getgenv().AbysallConfig.BaseUrl .. "Loader.lua"))()

    Optional config keys:
        JustLibUrl    - raw URL of JustLib.lua (default: JustUser-ALT/JustLib main)
        ComponentsUrl - base URL for Components/Environment.luau + ESP.luau
                        (default: the copies in BaseUrl / LocalFolder)
]]

local Env = getgenv()
local Config = Env.AbysallConfig or {}

if Env.Abysall then
    warn("[Abysall] already loaded")
    return
end

local function Fetch(Path)
    if Config.LocalFolder and readfile then
        return readfile(Config.LocalFolder .. "/" .. Path)
    end
    local Base = Config.BaseUrl
    assert(Base, "Set getgenv().AbysallConfig.BaseUrl (or LocalFolder) before running the loader")
    return game:HttpGet(Base .. Path)
end

local function FetchComponent(Name)
    if Config.ComponentsUrl then
        return game:HttpGet(Config.ComponentsUrl .. "Components/" .. Name)
    end
    return Fetch("Components/" .. Name)
end

Env.Abysall = {
    Environment = loadstring(FetchComponent("Environment.luau"))(),
    ESPLibrary = loadstring(FetchComponent("ESP.luau"))(),
    Interface = loadstring(Fetch("Interface.lua"))(),
}

if game.PlaceId ~= 6516141723 then
    loadstring(Fetch("Games/Doors/Main.luau"))()
else
    loadstring(Fetch("Games/Doors/Lobby.luau"))()
end
