--[[
    Just X Hub — Main module. return function(Core, Lib, Win, MainTab)
--]]
return function(Core, Lib, Win, MainTab)
    local LP = Core.LP
    local RunService = Core.RunService
    local crouchEvent = Core.crouchEvent
    local LT = game:GetService("Lighting")

    local MainSec = MainTab:Section({ Title="Main", Column="left" })

    local speedHackEnabled = false
    local customSpeedValue = 16
    local defaultSpeed = 16
    local speedConn = nil
    local spamConn = nil

    MainSec:Toggle({
        Name = "WalkSpeed & Crouch Lock",
        Default = false,
        Flag = "Speed_Enabled",
        Callback = function(state)
            speedHackEnabled = state
            if state then
                speedConn = RunService.Stepped:Connect(function()
                    local char = LP.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.WalkSpeed ~= customSpeedValue then
                        hum.WalkSpeed = customSpeedValue
                    end
                end)
                -- Пока включён Anti Figure Hearing (в Hotel/Mines), он сам спамит
                -- Crouch(true, nil) 10 раз/сек — если мы ОДНОВРЕМЕННО спамим
                -- Crouch(false, true) 60 раз/сек, наш спам почти всегда
                -- "перебивает" его, и Figure всё равно слышит. Поэтому пока
                -- Anti Figure Hearing активен — не трогаем этот ремоут вообще.
                spamConn = RunService.RenderStepped:Connect(function()
                    if speedHackEnabled and crouchEvent and not Core.isAntiFigureHearingEnabled() then
                        crouchEvent:FireServer(false, true)
                    end
                end)
            else
                if speedConn then speedConn:Disconnect(); speedConn = nil end
                if spamConn then spamConn:Disconnect(); spamConn = nil end
                local char = LP.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = defaultSpeed end
            end
        end
    })

    MainSec:Slider({
        Name = "Speed Value", Min = 16, Max = 200, Default = 16,
        Flag = "Speed_Modifier_Val",
        Callback = function(v) customSpeedValue = v end
    })

    MainSec:Slider({
        Name = "Loot Reach Distance", Min = 5, Max = 20, Default = 15,
        Flag = "AutoLoot_Reach_Val",
        Callback = function(v) Core.setLootReachDistance(v) end
    })

    MainSec:Toggle({ Name = "Instant Interact", Default = false, Flag = "InstantInteract_Enabled",
        Callback = function(v) Core.setInstantInteract(v) end })

    local doorReachEnabled = false
    MainSec:Toggle({ Name = "Door Reach", Default = false, Flag = "DoorReach_Enabled", Callback = function(v) doorReachEnabled = v end })

    task.spawn(function()
        while true do
            task.wait(0.2)
            if doorReachEnabled then
                local room = Core.getPlayerCurrentRoom()
                local doorFolder = room and room:FindFirstChild("Door")
                local clientOpen = doorFolder and doorFolder:FindFirstChild("ClientOpen")
                if clientOpen then pcall(function() clientOpen:FireServer() end) end
            end
        end
    end)

    ---------------------------------------------------------
    -- [Visual]
    ---------------------------------------------------------
    local VisSec = MainTab:Section({ Title="Visual", Column="mid" })

    local _fbConnections = {}
    local _fbSaved = {}
    local fullbrightEnabled = false
    local customBrightness = 2

    local function setFullbright()
        LT.Brightness = customBrightness
        LT.ClockTime = 14
        LT.FogEnd = 100000
        LT.GlobalShadows = false
        LT.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        LT.Ambient = Color3.fromRGB(128, 128, 128)
    end

    VisSec:Toggle({ Name="Fullbright", Default=false, Flag="Fullbright_Enabled", Callback=function(on)
        fullbrightEnabled = on
        if on then
            _fbSaved = { B=LT.Brightness, C=LT.ClockTime, F=LT.FogEnd, S=LT.GlobalShadows, O=LT.OutdoorAmbient, A=LT.Ambient }
            setFullbright()
            table.insert(_fbConnections, LT:GetPropertyChangedSignal("Brightness"):Connect(function() if fullbrightEnabled then setFullbright() end end))
            table.insert(_fbConnections, LT:GetPropertyChangedSignal("ClockTime"):Connect(function() if fullbrightEnabled then setFullbright() end end))
            table.insert(_fbConnections, LT:GetPropertyChangedSignal("Ambient"):Connect(function() if fullbrightEnabled then setFullbright() end end))
        else
            for _, conn in ipairs(_fbConnections) do conn:Disconnect() end
            _fbConnections = {}
            if _fbSaved.B then
                LT.Brightness=_fbSaved.B; LT.ClockTime=_fbSaved.C; LT.FogEnd=_fbSaved.F
                LT.GlobalShadows=_fbSaved.S; LT.OutdoorAmbient=_fbSaved.O; LT.Ambient=_fbSaved.A
            end
        end
    end })

    VisSec:Slider({
        Name = "Fullbright Brightness", Min = 1, Max = 10, Default = 2,
        Flag = "Fullbright_Brightness_Val",
        Callback = function(v) customBrightness = v; if fullbrightEnabled then setFullbright() end end
    })

    local _fogConn=nil; local _fogPropConns={}; local _fogSaved={}
    local _atmosPropConns={}; local _atmosSaved=nil; local _atmosAddedConn=nil

    local function enforceNoFog()
        LT.FogEnd=9e8; LT.FogStart=9e8
        local atmos = LT:FindFirstChildOfClass("Atmosphere")
        if atmos then pcall(function() atmos.Density=0; atmos.Offset=0; atmos.Glare=0; atmos.Haze=0 end) end
    end

    local function hookAtmosphere(atmos)
        for _, c in ipairs(_atmosPropConns) do c:Disconnect() end
        _atmosPropConns = {}
        if not atmos then return end
        for _, prop in ipairs({"Density","Offset","Glare","Haze"}) do
            table.insert(_atmosPropConns, atmos:GetPropertyChangedSignal(prop):Connect(function()
                local ok, val = pcall(function() return atmos[prop] end)
                if ok and val and val > 0 then pcall(function() atmos[prop] = 0 end) end
            end))
        end
    end

    VisSec:Toggle({ Name="No Fog", Default=false, Flag="NoFog_Enabled", Callback=function(on)
        if on then
            _fogSaved={E=LT.FogEnd,S=LT.FogStart,C=LT.FogColor}
            local atmos = LT:FindFirstChildOfClass("Atmosphere")
            _atmosSaved = atmos and {D=atmos.Density, O=atmos.Offset, G=atmos.Glare, H=atmos.Haze} or nil
            enforceNoFog()
            _fogConn=RunService.Heartbeat:Connect(enforceNoFog)
            table.insert(_fogPropConns, LT:GetPropertyChangedSignal("FogEnd"):Connect(function() if LT.FogEnd < 9e8 then enforceNoFog() end end))
            table.insert(_fogPropConns, LT:GetPropertyChangedSignal("FogStart"):Connect(function() if LT.FogStart < 9e8 then enforceNoFog() end end))
            if atmos then hookAtmosphere(atmos) end
            _atmosAddedConn = LT.ChildAdded:Connect(function(c)
                if c:IsA("Atmosphere") then
                    task.wait()
                    pcall(function() c.Density=0; c.Offset=0; c.Glare=0; c.Haze=0 end)
                    hookAtmosphere(c)
                end
            end)
        else
            if _fogConn then _fogConn:Disconnect(); _fogConn=nil end
            for _, c in ipairs(_fogPropConns) do c:Disconnect() end
            _fogPropConns = {}
            for _, c in ipairs(_atmosPropConns) do c:Disconnect() end
            _atmosPropConns = {}
            if _atmosAddedConn then _atmosAddedConn:Disconnect(); _atmosAddedConn=nil end
            if _fogSaved.E then LT.FogEnd=_fogSaved.E; LT.FogStart=_fogSaved.S; LT.FogColor=_fogSaved.C end
            local atmos = LT:FindFirstChildOfClass("Atmosphere")
            if atmos and _atmosSaved then
                pcall(function() atmos.Density=_atmosSaved.D; atmos.Offset=_atmosSaved.O; atmos.Glare=_atmosSaved.G; atmos.Haze=_atmosSaved.H end)
            end
        end
    end })

    ---------------------------------------------------------
    -- [Utility]
    ---------------------------------------------------------
    local UtilSec = MainTab:Section({ Title="Utility", Column="right" })
    local bridgeGapEnabled = false
    local bridgeGapPlatforms = {}

    local function findBridgeParts()
        local found = {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if d.Name == "Bridge" and d:IsA("BasePart") then table.insert(found, d) end
        end
        return found
    end

    local function coverBridgeGaps()
        local bridges = findBridgeParts()
        for i = 1, #bridges do
            local a = bridges[i]
            if a.Parent and not bridgeGapPlatforms[a] then
                local closest, closestDist = nil, math.huge
                for j = 1, #bridges do
                    if i ~= j and bridges[j].Parent then
                        local b = bridges[j]
                        local dist = (a.Position - b.Position).Magnitude
                        if dist > 4 and dist < 80 and dist < closestDist then closest = b; closestDist = dist end
                    end
                end
                if closest then
                    pcall(function()
                        local mid = a.Position:Lerp(closest.Position, 0.5)
                        local platform = Instance.new("Part")
                        platform.Name = "BridgeGapCover"
                        platform.Size = Vector3.new(math.max(a.Size.X, closest.Size.X, 6), 0.5, closestDist + 4)
                        platform.CFrame = CFrame.lookAt(mid, closest.Position)
                        platform.Anchored = true; platform.CanCollide = true; platform.Transparency = 1
                        platform.Parent = workspace
                        bridgeGapPlatforms[a] = platform
                    end)
                end
            end
        end
    end

    local function removeBridgeGapPlatforms()
        for _, platform in pairs(bridgeGapPlatforms) do
            if platform and platform.Parent then pcall(function() platform:Destroy() end) end
        end
        bridgeGapPlatforms = {}
    end

    UtilSec:Toggle({
        Name = "Bridge Gap Cover", Default = false, Flag = "BridgeGapCover_Enabled",
        Callback = function(v)
            bridgeGapEnabled = v
            if v then pcall(coverBridgeGaps) else removeBridgeGapPlatforms() end
        end
    })

    task.spawn(function()
        while true do
            task.wait(1)
            if bridgeGapEnabled then pcall(coverBridgeGaps) end
        end
    end)
end
