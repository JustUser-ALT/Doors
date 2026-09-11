--[[
    Just X Hub — Mines module. return function(Core, Lib, Win, MinesTab)
--]]
return function(Core, Lib, Win, MinesTab)
    local LP = Core.LP

    local MinesMobs = { "Rush", "Ambush", "Giggle", "Figure", "Screech", "Eyes", "Dupe" }
    local MinesLoot = {
        "Gold", "Stardust", "Bandage", "Key", "Lighter", "Flashlight", "Lockpick",
        "Vitamins", "Crucifix", "Glowsticks", "Shears", "Cheese", "Bulklight",
        "Straplight", "BandagePack", "BatteryPack", "Bread", "Fuse", "SkeletonKey"
    }
    -- LargeLocker и CircularVent — только ESP, в Auto Interact не включаю
    local MinesInteractESP = {
        "Door", "Generator", "LargeLocker", "SmallLocker", "CircularVent", "WoodenTable",
        "Toolbox", "SmallToolshed", "Toolshed"
    }
    local MinesInteractAuto = {
        "Generator", "SmallLocker", "WoodenTable", "Toolbox", "SmallToolshed", "Toolshed"
    }

    local MinesAntiSec = Core.buildStandardSections("Mines", MinesTab, MinesMobs, MinesLoot, MinesInteractESP, MinesInteractAuto)

    Core.mkAntiToggle(MinesAntiSec, "Anti Screech", "Mines_AntiScreech", Core.setAntiScreech)
    Core.mkAntiToggle(MinesAntiSec, "Anti Eyes", "Mines_AntiEyes", Core.setAntiEyes)
    Core.mkAntiToggle(MinesAntiSec, "Anti Halt", "Mines_AntiHalt", Core.setAntiHalt)
    Core.mkAntiToggle(MinesAntiSec, "Anti Figure Hearing", "Mines_AntiFigureHearing", Core.setAntiFigureHearing)
    Core.mkAntiToggle(MinesAntiSec, "Anti Giggle", "Mines_AntiGiggle", Core.setAntiGiggle)
    Core.mkAntiToggle(MinesAntiSec, "Anti Dread", "Mines_AntiDread", Core.setAntiDread)
    Core.mkAntiToggle(MinesAntiSec, "Anti Gloombat Egg", "Mines_AntiGloombatEgg", Core.setAntiGloombatEgg)
    Core.mkAntiToggle(MinesAntiSec, "Anti Drown", "Mines_AntiDrown", Core.setAntiDrown)

    ---------------------------------------------------------
    -- [Generator: предохранители + рычаг]
    ---------------------------------------------------------
    local MinesSec = MinesTab:Section({ Title = "Generator", Column = "right" })

    local function playerHasGeneratorFuse()
        local backpack = LP:FindFirstChildOfClass("Backpack")
        if backpack and backpack:FindFirstChild("GeneratorFuse") then return true end
        local char = LP.Character
        if char and char:FindFirstChild("GeneratorFuse") then return true end
        return false
    end

    local generatorPromptBusy = {}
    local function tryInteractGeneratorPrompt(prompt, targetPart)
        if generatorPromptBusy[prompt] then return end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not targetPart then return end
        local ok, dist = pcall(function() return (hrp.Position - targetPart.Position).Magnitude end)
        if not ok or dist > Core.getLootReachDistance() then return end
        generatorPromptBusy[prompt] = true
        pcall(function()
            fireproximityprompt(prompt, 0)
            if prompt.HoldDuration and prompt.HoldDuration > 0 then
                pcall(function() prompt:InputHoldBegin(); task.wait(prompt.HoldDuration + 0.05) end)
                pcall(function() prompt:InputHoldEnd() end)
            end
        end)
        task.delay(1, function() generatorPromptBusy[prompt] = nil end)
    end

    task.spawn(function()
        while true do
            task.wait(0.3)
            if Core.isAutoInteractWanted("Generator") then
                local currentRooms = workspace:FindFirstChild("CurrentRooms")
                if currentRooms then
                    for _, room in ipairs(currentRooms:GetChildren()) do
                        local assets = room:FindFirstChild("Assets")
                        local gen = assets and assets:FindFirstChild("MinesGenerator")
                        if gen then
                            local fusesFolder = gen:FindFirstChild("Fuses")
                            local remainingSlots = 0
                            if fusesFolder then
                                for _, slot in ipairs(fusesFolder:GetChildren()) do
                                    local prompt = slot:FindFirstChild("FusesPrompt")
                                    if prompt and prompt.Enabled then
                                        remainingSlots = remainingSlots + 1
                                        if playerHasGeneratorFuse() then
                                            tryInteractGeneratorPrompt(prompt, Core.getPromptTargetPart(prompt) or slot)
                                        end
                                    end
                                end
                            end
                            if remainingSlots == 0 then
                                local lever = gen:FindFirstChild("Lever")
                                local leverPrompt = lever and lever:FindFirstChild("LeverPrompt")
                                if leverPrompt and leverPrompt.Enabled then
                                    tryInteractGeneratorPrompt(leverPrompt, Core.getPromptTargetPart(leverPrompt) or lever)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    MinesSec:Label({ Text = "Fuse ESP/автолут — в Loot-секциях выше (\"Fuse\")." })
    MinesSec:Label({ Text = "Generator ESP — в Interact ESP. Автовставка", Color = Color3.fromRGB(160,160,165) })
    MinesSec:Label({ Text = "предохранителей/рычаг — через Auto Interact + \"Generator\".", Color = Color3.fromRGB(160,160,165) })

    ---------------------------------------------------------
    -- [PathfindNodes / RunnerNodes — ESP-линия маршрута] (Beta)
    ---------------------------------------------------------
    local pathNodesEnabled = false
    local pathNodeBeams = {}

    local function findPathNodesFolder(room)
        local assets = room:FindFirstChild("Assets")
        local folder = (assets and (assets:FindFirstChild("PathfindNodes") or assets:FindFirstChild("RunnerNodes")))
                     or room:FindFirstChild("PathfindNodes") or room:FindFirstChild("RunnerNodes")
        return folder
    end

    local function getNodeAnchorPart(node)
        if node:IsA("BasePart") then return node end
        if node:IsA("Model") then return node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true) end
        return nil
    end

    local function clearPathBeams()
        for _, v in pairs(pathNodeBeams) do
            pcall(function() if v.beam then v.beam:Destroy() end end)
            pcall(function() if v.att0 then v.att0:Destroy() end end)
            pcall(function() if v.att1 then v.att1:Destroy() end end)
        end
        pathNodeBeams = {}
    end

    local function drawPathForRoom(room)
        local folder = findPathNodesFolder(room)
        if not folder then return end
        local nodes = {}
        for _, n in ipairs(folder:GetChildren()) do
            local num = tonumber(n.Name)
            if num then table.insert(nodes, {num=num, inst=n}) end
        end
        table.sort(nodes, function(a,b) return a.num < b.num end)

        for i = 1, #nodes - 1 do
            local a, b = nodes[i].inst, nodes[i+1].inst
            if not pathNodeBeams[a] then
                local partA, partB = getNodeAnchorPart(a), getNodeAnchorPart(b)
                if partA and partB then
                    pcall(function()
                        local att0 = Instance.new("Attachment"); att0.Parent = partA
                        local att1 = Instance.new("Attachment"); att1.Parent = partB
                        local beam = Instance.new("Beam")
                        beam.Attachment0 = att0
                        beam.Attachment1 = att1
                        beam.Width0 = 0.3
                        beam.Width1 = 0.3
                        beam.FaceCamera = true
                        beam.Color = ColorSequence.new(Color3.fromRGB(0,255,120))
                        beam.Transparency = NumberSequence.new(0.2)
                        beam.Parent = partA
                        pathNodeBeams[a] = { beam=beam, att0=att0, att1=att1 }
                    end)
                end
            end
        end
    end

    MinesSec:Toggle({
        Name = "Path Nodes ESP (Beta)", Default = false, Flag = "Mines_PathNodes_Enabled",
        Callback = function(v)
            pathNodesEnabled = v
            if not v then clearPathBeams() end
        end
    })

    task.spawn(function()
        while true do
            task.wait(1)
            if pathNodesEnabled then
                local currentRooms = workspace:FindFirstChild("CurrentRooms")
                if currentRooms then
                    for _, room in ipairs(currentRooms:GetChildren()) do
                        pcall(drawPathForRoom, room)
                    end
                end
                for a, v in pairs(pathNodeBeams) do
                    if not a.Parent then
                        pcall(function() if v.beam then v.beam:Destroy() end end)
                        pcall(function() if v.att0 then v.att0:Destroy() end end)
                        pcall(function() if v.att1 then v.att1:Destroy() end end)
                        pathNodeBeams[a] = nil
                    end
                end
            end
        end
    end)
end
