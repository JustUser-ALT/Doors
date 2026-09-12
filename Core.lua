return function(Lib)
    local Core = {}

    local LP = game:GetService("Players").LocalPlayer
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local remotesFolder = ReplicatedStorage:FindFirstChild("RemotesFolder")
    local crouchEvent = remotesFolder and remotesFolder:FindFirstChild("Crouch")

    Core.LP = LP
    Core.RunService = RunService
    Core.Players = Players
    Core.remotesFolder = remotesFolder
    Core.crouchEvent = crouchEvent

    ---------------------------------------------------------
    -- [Цвета]
    ---------------------------------------------------------
    local MOB_COLORS = {
        Figure        = Color3.fromRGB(255,60,60),
        Rush          = Color3.fromRGB(200,50,255),
        Ambush        = Color3.fromRGB(0,255,150),
        Screech       = Color3.fromRGB(255,50,50),
        Eyes          = Color3.fromRGB(50,220,255),
        Dupe          = Color3.fromRGB(255,100,0),
        Sally         = Color3.fromRGB(255,50,150),
        Giggle        = Color3.fromRGB(255,165,0),
        Door          = Color3.fromRGB(0,200,255),
        Gold          = Color3.fromRGB(255,215,0),
        Stardust      = Color3.fromRGB(180,100,255),
        Pizza         = Color3.fromRGB(255,80,80),
        Bandage       = Color3.fromRGB(100,255,100),
        PaperPlane    = Color3.fromRGB(255,255,255),
        FishFlakes    = Color3.fromRGB(255,200,100),
        LaserPointer  = Color3.fromRGB(255,50,50),
        Battery       = Color3.fromRGB(50,255,255),
        Key           = Color3.fromRGB(255,255,0),
        Chest         = Color3.fromRGB(205,133,63),
        ["Locked Chest"] = Color3.fromRGB(139,69,19),
        Lighter       = Color3.fromRGB(255,140,0),
        Flashlight    = Color3.fromRGB(255,255,150),
        Lockpick      = Color3.fromRGB(190,190,190),
        Vitamins      = Color3.fromRGB(255,100,255),
        Candle        = Color3.fromRGB(255,200,100),
        Smoothie      = Color3.fromRGB(255,105,180),
        AlarmClock    = Color3.fromRGB(255,80,80),
        Books         = Color3.fromRGB(100,200,255),
        Lever         = Color3.fromRGB(0,255,128),
        GlitchCube    = Color3.fromRGB(150,0,255),
        TipJar        = Color3.fromRGB(85,255,127),
        Donut         = Color3.fromRGB(255,170,200),
        Crucifix      = Color3.fromRGB(255,0,255),
        Shears        = Color3.fromRGB(200,200,255),
        Breaker       = Color3.fromRGB(255,255,80),
        SkeletonKey   = Color3.fromRGB(230,190,50),
        SecretCD      = Color3.fromRGB(255,0,127),
        Drawers       = Color3.fromRGB(210,180,140),
        Lockers       = Color3.fromRGB(128,128,128),
        VentGrate     = Color3.fromRGB(150,150,255),
        Toolshed      = Color3.fromRGB(120,200,140),
        SmallToolshed = Color3.fromRGB(140,220,160),
        DoorLock      = Color3.fromRGB(255,140,140),
        Generator     = Color3.fromRGB(255,180,0),
        Fuse          = Color3.fromRGB(255,220,80),
        LargeLocker   = Color3.fromRGB(110,110,120),
        SmallLocker   = Color3.fromRGB(150,150,160),
        CircularVent  = Color3.fromRGB(160,160,255),
        WoodenTable   = Color3.fromRGB(160,110,70),
        Toolbox       = Color3.fromRGB(200,140,40),
        Glowsticks    = Color3.fromRGB(80,255,120),
        Cheese        = Color3.fromRGB(255,220,80),
        Bulklight     = Color3.fromRGB(255,255,200),
        Straplight    = Color3.fromRGB(255,255,150),
        BandagePack   = Color3.fromRGB(120,255,120),
        BatteryPack   = Color3.fromRGB(80,255,255),
        Bread         = Color3.fromRGB(210,160,90),
    }
    Core.MOB_COLORS = MOB_COLORS

    ---------------------------------------------------------
    -- [Реестры выбора по вкладкам]
    ---------------------------------------------------------
    local selESPMobs, selESPLoot, selESPInteract = {}, {}, {}
    local selAutoLoot, selAutoInteract = {}, {}
    local tabAutoLootOn, tabAutoInteractOn = {}, {}

    local function isItemSelected(itemType, targetTable)
        for _, selected in ipairs(targetTable) do
            if selected == itemType then return true end
        end
        return false
    end
    Core.isItemSelected = isItemSelected

    local function isSelectedAnyESP(regTable, name)
        for _, list in pairs(regTable) do
            if isItemSelected(name, list) then return true end
        end
        return false
    end
    Core.isSelectedAnyESP = isSelectedAnyESP

    local function isAutoLootWanted(item)
        for tabId, list in pairs(selAutoLoot) do
            if tabAutoLootOn[tabId] and isItemSelected(item, list) then return true end
        end
        return false
    end
    Core.isAutoLootWanted = isAutoLootWanted

    local function isAutoInteractWanted(item)
        for tabId, list in pairs(selAutoInteract) do
            if tabAutoInteractOn[tabId] and isItemSelected(item, list) then return true end
        end
        return false
    end
    Core.isAutoInteractWanted = isAutoInteractWanted

    ---------------------------------------------------------
    -- [ESP: espData, addESP/removeESP, культинг/ghost-чистка, watchdog]
    ---------------------------------------------------------
    local espData = {}
    local espMaxDistance = 150
    local GHOST_DISTANCE = 2000

    local function isUnderCurrentRooms(inst)
        local anc = inst
        while anc and anc ~= workspace do
            if anc.Name == "CurrentRooms" then return true end
            anc = anc.Parent
        end
        return false
    end
    Core.isUnderCurrentRooms = isUnderCurrentRooms

    local _lastKnownRoom = nil
    local function roomContainsPoint(room, point)
        local ok, cf, size = pcall(function() return room:GetBoundingBox() end)
        if not ok or not cf or not size then return false end
        local rel = cf:PointToObjectSpace(point)
        local half = size * 0.5
        return math.abs(rel.X) <= half.X + 5 and math.abs(rel.Y) <= half.Y + 25 and math.abs(rel.Z) <= half.Z + 5
    end

    local function getPlayerCurrentRoom()
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local currentRooms = workspace:FindFirstChild("CurrentRooms")
        if not hrp or not currentRooms then return _lastKnownRoom end

        if _lastKnownRoom and _lastKnownRoom.Parent and roomContainsPoint(_lastKnownRoom, hrp.Position) then
            return _lastKnownRoom
        end
        for _, room in ipairs(currentRooms:GetChildren()) do
            if roomContainsPoint(room, hrp.Position) then
                _lastKnownRoom = room
                return room
            end
        end
        if _lastKnownRoom and _lastKnownRoom.Parent then return _lastKnownRoom end

        local closestRoom, shortestDist = nil, math.huge
        for _, room in ipairs(currentRooms:GetChildren()) do
            local primary = room.PrimaryPart or room:FindFirstChildWhichIsA("BasePart", true)
            if primary then
                local dist = (hrp.Position - primary.Position).Magnitude
                if dist < shortestDist then shortestDist = dist; closestRoom = room end
            end
        end
        _lastKnownRoom = closestRoom
        return closestRoom
    end
    Core.getPlayerCurrentRoom = getPlayerCurrentRoom

    local function getDoorText(inst)
        local doorModel = inst.Parent
        if doorModel then
            local sign = doorModel:FindFirstChild("Sign")
            if sign then
                local stinker = sign:FindFirstChild("Stinker")
                if stinker then
                    if stinker:IsA("TextLabel") or stinker:IsA("TextBox") then return stinker.Text end
                    for _, child in ipairs(stinker:GetDescendants()) do
                        if child:IsA("TextLabel") or child:IsA("TextBox") then return child.Text end
                    end
                end
            end
        end
        return "Door"
    end

    local removeESP -- forward declaration

    local function addESP(mobType, inst)
        if not inst or not inst.Parent then return end
        if espData[inst] then return end
        local col = MOB_COLORS[mobType] or Color3.new(1,1,1)

        local hi = Instance.new("Highlight")
        hi.Adornee = inst; hi.FillColor = col; hi.OutlineColor = Color3.new(1,1,1)
        hi.FillTransparency = (mobType == "Door") and 0.15 or 0.4
        hi.OutlineTransparency = 0
        hi.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        pcall(function() hi.Parent = game:GetService("CoreGui") end)
        if not hi.Parent then hi.Parent = inst end

        local bb = Instance.new("BillboardGui")
        bb.Adornee = inst; bb.Size = UDim2.new(0,130,0,46)
        bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true
        bb.MaxDistance = math.huge; bb.ResetOnSpawn = false
        pcall(function() bb.Parent = game:GetService("CoreGui") end)
        if not bb.Parent then bb.Parent = inst end

        local displayText = mobType
        if mobType == "Door" then
            displayText = "Door [" .. getDoorText(inst) .. "]"
        else
            displayText = mobType .. "\n[...]"
        end

        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1; lbl.Text = displayText
        lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 16; lbl.TextColor3 = col
        lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.new(0,0,0)
        lbl.TextWrapped = true
        lbl.Parent = bb

        espData[inst] = {hi=hi, bb=bb, lbl=lbl, mobType=mobType}

        local ok, prompt = pcall(function() return inst:FindFirstChildWhichIsA("ProximityPrompt", true) end)
        if ok and prompt then
            prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                if not prompt.Enabled then removeESP(inst) end
            end)
        end
    end
    Core.addESP = addESP

    removeESP = function(inst)
        local d = espData[inst]; if not d then return end
        pcall(function() d.hi:Destroy() end)
        pcall(function() d.bb:Destroy() end)
        espData[inst] = nil
    end
    Core.removeESP = removeESP

    local function removeAllOfType(mobType)
        for inst, d in pairs(espData) do
            if d.mobType == mobType then removeESP(inst) end
        end
    end
    Core.removeAllOfType = removeAllOfType

    local function onMobFound(mobType, inst)
        if mobType == "Door" then
            if isSelectedAnyESP(selESPInteract, "Door") or isSelectedAnyESP(selESPMobs, "Door") then
                addESP("Door", inst)
            end
            return
        end

        local wanted = isSelectedAnyESP(selESPMobs, mobType) or isSelectedAnyESP(selESPLoot, mobType) or isSelectedAnyESP(selESPInteract, mobType)
        if not wanted then return end
        addESP(mobType, inst)

        -- Dupe — только ESP, без нотификации (так было изначально)
        if mobType ~= "Dupe" and isSelectedAnyESP(selESPMobs, mobType) then
            Lib:Notify({ Title = "⚠ "..mobType.." Appeared!", Desc = mobType.." has spawned — stay alert!", Type = "Warn", Duration = 6 })
        end

        inst.AncestryChanged:Connect(function()
            if not inst:IsDescendantOf(workspace) then removeESP(inst) end
        end)
    end

    local identifyMob -- forward declaration, тело ниже

    local function scanAll(mobType)
        for _, d in ipairs(workspace:GetDescendants()) do
            local mt, obj = identifyMob(d)
            if mt == mobType then onMobFound(mt, obj) end
        end
    end
    Core.scanAll = scanAll

    ---------------------------------------------------------
    -- [identifyMob]
    ---------------------------------------------------------
    local function simpleNamedItem(inst, itemName)
        if inst:FindFirstChildWhichIsA("ProximityPrompt", true) then return itemName, inst end
        return nil, nil
    end

    -- RushNew (и, предположительно, аналог у Ambush) — Transparency=1 части,
    -- на которых обычный Highlight иногда вообще не рендерится. По референсу:
    -- сдвиг на 0.999 (визуально всё ещё невидимо) + добавление Humanoid в
    -- модель чинит это.
    local function fixupRushLikeEntity(inst)
        task.spawn(function()
            local target = nil
            for _ = 1, 40 do
                if not inst.Parent then return end
                target = inst:FindFirstChild("RushNew", true) or inst:FindFirstChild("AmbushNew", true) or inst:FindFirstChildWhichIsA("BasePart", true)
                if target then break end
                task.wait(0.05)
            end
            if not target then return end
            if not inst:FindFirstChild("HighlightHumanoid") then
                pcall(function() Instance.new("Humanoid", inst).Name = "HighlightHumanoid" end)
            end
            pcall(function() target.Transparency = 0.999; target.Material = Enum.Material.Plastic end)
            if not inst.PrimaryPart then pcall(function() inst.PrimaryPart = target end) end
        end)
    end

    identifyMob = function(inst)
        local name = inst.Name

        if name == "SallyMoving" or (name == "Sally" and inst.Parent == workspace) then
            return "Sally", inst
        end
        -- Убран широкий матч (name=="Figure" and inst:IsA("Model")) — он
        -- ловил лишний Model-объект где-то ещё, давая вторую ESP/нотификацию
        if name == "FigureRig" or name == "FigureSetup" then
            return "Figure", inst
        end
        if name == "GiggleCeiling" then
            local p1 = inst.Parent
            if p1 and p1.Parent and p1.Parent.Name == "CurrentRooms" then return "Giggle", inst end
        end
        if name == "RushMoving" and inst.Parent == workspace then
            fixupRushLikeEntity(inst)
            return "Rush", inst
        end
        if name == "Eyes" and inst.Parent == workspace then return "Eyes", inst end
        if name == "Screech" then return "Screech", inst end
        if name == "DoorFake" and inst.Parent and inst.Parent.Name == "SideroomDupe" then
            local doorObj = inst:FindFirstChild("Door")
            if doorObj then return "Dupe", doorObj end
        end
        if name == "AmbushMoving" and inst.Parent == workspace then
            fixupRushLikeEntity(inst)
            return "Ambush", inst
        end
        if name == "Door" and inst.Parent and inst.Parent.Name == "Door" and inst.Parent.Parent and inst.Parent.Parent.Parent and inst.Parent.Parent.Parent.Name == "CurrentRooms" then
            return "Door", inst
        end

        if name == "GoldPile" then
            if inst:FindFirstChild("LootPrompt", true) then return "Gold", inst end
            return nil, nil
        end
        if name == "StardustPickup" or name:find("Stardust") then return "Stardust", inst end
        if name == "Pizza" then return "Pizza", inst end
        if name == "Bandage" then return "Bandage", inst end
        if name == "PaperPlane" then return "PaperPlane", inst end
        if name == "FishFlakes" or name:find("Fish") or name:find("Fih") then return "FishFlakes", inst end
        if name == "LaserPointer" or name:find("Laser") then return "LaserPointer", inst end
        if name == "Battery" or name:find("Battery") then return "Battery", inst end
        if name == "KeyObtain" then return "Key", inst end
        if name == "ElectricalKeyObtain" then return "Key", inst end
        if name == "Lighter" then
            if inst:FindFirstChildWhichIsA("ProximityPrompt", true) then return "Lighter", inst end
            return nil, nil
        end
        if name == "ChestBox" then return "Chest", inst end
        if name == "ChestBoxLocked" then return "Locked Chest", inst end
        -- Тот же риск коллизии с декором, что и у Lighter/Bookcase — гвардим
        -- все "однословные" простые имена проксимити-промптом
        if name == "Flashlight" then return simpleNamedItem(inst, "Flashlight") end
        if name == "Lockpick" then return simpleNamedItem(inst, "Lockpick") end
        if name == "Vitamins" then return simpleNamedItem(inst, "Vitamins") end
        if name == "Candle" then return simpleNamedItem(inst, "Candle") end
        if name == "Smoothie" then return simpleNamedItem(inst, "Smoothie") end
        if name == "AlarmClock" then return simpleNamedItem(inst, "AlarmClock") end
        if name == "LiveHintBook" then return "Books", inst end
        if name == "LeverForGate" then return "Lever", inst end
        if name == "GlitchCube" then return simpleNamedItem(inst, "GlitchCube") end
        if name == "TipJar" then return simpleNamedItem(inst, "TipJar") end
        if name == "Donut" then return simpleNamedItem(inst, "Donut") end
        -- Убран общий name=="Crucifix" (по просьбе — оставлен только Wall-вариант,
        -- заодно должен закрыть "призрачный" Crucifix и, вероятно, был как-то
        -- связан с той же причиной, что и лишний Figure-матч)
        if name == "CrucifixWall" then
            if isUnderCurrentRooms(inst) then return "Crucifix", inst end
            return nil, nil
        end
        if name == "Shears" then return "Shears", inst end
        if name == "LiveBreakerPolePickup" then return "Breaker", inst end
        if name == "SkeletonKey" then return "SkeletonKey", inst end
        if name == "SecretCD" then return "SecretCD", inst end

        -- Drawers-семейство: убран слишком общий name=="Table" (ловил
        -- случайные внутренности вроде Bookcase)
        if name == "DrawerContainer" or name == "Dresser" or name == "Rolltop_Desk" or name:find("Backdoor_Table") then
            if inst:FindFirstChild("LootHolder") then return nil, nil end
            return "Drawers", inst
        end
        if string.find(name, "HidingSpot") or name == "Locker" or name == "Wardrobe" or name:find("Backdoor_Wardrobe") then
            return "Lockers", inst
        end
        if name == "VentGrate" then return "VentGrate", inst end
        if name == "Toolshed_Small" then
            if inst:FindFirstChild("LootHolder") then return nil, nil end
            return "Toolshed", inst
        end
        if name == "Lock" and inst.Parent and inst.Parent.Name == "Door" then return "DoorLock", inst end

        if name == "MinesGenerator" then return "Generator", inst end
        if name == "FuseObtain" then return "Fuse", inst end
        if name == "Locker_Large" then return "LargeLocker", inst end
        if name == "Locker_Small" then return "SmallLocker", inst end
        if name == "CircularVent" then return "CircularVent", inst end
        if name == "OldWoodenTable" then
            if inst:FindFirstChild("LootHolder") then return nil, nil end
            return "WoodenTable", inst
        end
        if name == "Toolbox" then
            if inst:FindFirstChild("LootHolder") then return nil, nil end
            return "Toolbox", inst
        end
        if name == "Glowsticks" then return "Glowsticks", inst end
        if name == "Cheese" then return "Cheese", inst end
        if name == "Bulklight" then return "Bulklight", inst end
        if name == "Straplight" then return "Straplight", inst end
        if name == "BandagePack" then return "BandagePack", inst end
        if name == "BatteryPack" then return "BatteryPack", inst end
        if name == "Bread" then return "Bread", inst end

        return nil, nil
    end
    Core.identifyMob = identifyMob

    workspace.DescendantAdded:Connect(function(inst)
        local mobType, obj = identifyMob(inst)
        if mobType then onMobFound(mobType, obj) end
    end)

    local espCullExempt = { Door = true }
    task.spawn(function()
        while true do
            task.wait(0.25)
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for inst, d in pairs(espData) do
                    local ok, pos = pcall(function()
                        if inst:IsA("BasePart") then return inst.Position
                        elseif inst:IsA("Model") then return inst:GetPivot().Position end
                        return nil
                    end)
                    if ok and pos then
                        local dist = (hrp.Position - pos).Magnitude
                        if dist > GHOST_DISTANCE then
                            removeESP(inst)
                        else
                            if d.mobType ~= "Door" and d.lbl then
                                pcall(function() d.lbl.Text = d.mobType .. "\n[" .. math.floor(dist) .. "]" end)
                            end
                            if not espCullExempt[d.mobType] then
                                local vis = dist <= espMaxDistance
                                if d.hi then pcall(function() d.hi.Enabled = vis end) end
                                if d.bb then pcall(function() d.bb.Enabled = vis end) end
                            end
                        end
                    end
                end
            end
        end
    end)

    task.spawn(function()
        while true do
            task.wait(1)
            for inst, d in pairs(espData) do
                if inst and inst.Parent then
                    local broken = true
                    if d.hi then
                        local ok, isFine = pcall(function() return d.hi.Parent ~= nil and d.hi.Adornee == inst end)
                        broken = not (ok and isFine)
                    end
                    if broken then
                        pcall(function() if d.hi then d.hi:Destroy() end end)
                        local col = MOB_COLORS[d.mobType] or Color3.new(1,1,1)
                        local newHi = Instance.new("Highlight")
                        newHi.Adornee = inst; newHi.FillColor = col; newHi.OutlineColor = Color3.new(1,1,1)
                        newHi.FillTransparency = (d.mobType == "Door") and 0.15 or 0.4
                        newHi.OutlineTransparency = 0
                        newHi.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        local pok = pcall(function() newHi.Parent = game:GetService("CoreGui") end)
                        if not pok or not newHi.Parent then newHi.Parent = inst end
                        d.hi = newHi
                    end
                end
            end
        end
    end)

    ---------------------------------------------------------
    -- [Auto Loot / Auto Interact — общий движок промптов]
    ---------------------------------------------------------
    local lootReachDistance = 15
    local instantInteractEnabled = false
    local cachedPrompts = {}
    local promptBusy = {}
    local origHoldDurations = {}
    local lastGlobalInteractTime = 0
    local GLOBAL_INTERACT_COOLDOWN = 0.25 -- не даём двум разным промптам сработать почти одновременно

    local function applyPromptReach(prompt)
        if prompt and prompt:IsA("ProximityPrompt") then
            pcall(function() prompt.MaxActivationDistance = lootReachDistance end)
        end
    end
    Core.applyPromptReach = applyPromptReach

    local function applyInstantHold(prompt)
        if not prompt or not prompt:IsA("ProximityPrompt") then return end
        if instantInteractEnabled then
            if origHoldDurations[prompt] == nil then origHoldDurations[prompt] = prompt.HoldDuration end
            pcall(function() prompt.HoldDuration = 0 end)
        elseif origHoldDurations[prompt] ~= nil then
            pcall(function() prompt.HoldDuration = origHoldDurations[prompt] end)
            origHoldDurations[prompt] = nil
        end
    end
    Core.applyInstantHold = applyInstantHold

    local function getPromptTargetPart(prompt)
        local parent = prompt.Parent
        if not parent then return nil end
        if parent:IsA("BasePart") then return parent
        elseif parent:IsA("Model") then return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true) end
        local current = parent
        while current and not current:IsA("BasePart") do current = current.Parent end
        return current
    end
    Core.getPromptTargetPart = getPromptTargetPart

    local function matchItemByAncestor(inst)
        local curr = inst
        while curr and curr ~= workspace do
            local n = curr.Name
            if n == "StardustPickup" or n:find("Stardust") then return "Stardust" end
            if n == "Pizza" then return "Pizza" end
            if n == "Bandage" then return "Bandage" end
            if n == "PaperPlane" then return "PaperPlane" end
            if n == "FishFlakes" or n:find("Fish") or n:find("Fih") then return "FishFlakes" end
            if n == "LaserPointer" or n:find("Laser") then return "LaserPointer" end
            if n == "Battery" or n:find("Battery") then return "Battery" end
            if n == "KeyObtain" then return "Key" end
            if n == "Lighter" then return "Lighter" end
            if n == "Flashlight" then return "Flashlight" end
            if n == "Lockpick" then return "Lockpick" end
            if n == "Vitamins" then return "Vitamins" end
            if n == "Candle" then return "Candle" end
            if n == "Smoothie" then return "Smoothie" end
            if n == "AlarmClock" then return "AlarmClock" end
            if n == "LiveHintBook" then return "Books" end
            if n == "LeverForGate" then return "Lever" end
            if n == "GlitchCube" then return "GlitchCube" end
            if n == "TipJar" then return "TipJar" end
            if n == "Donut" then return "Donut" end
            -- Crucifix убран отсюда тоже — общий матч больше нигде не должен срабатывать
            curr = curr.Parent
        end
        return nil
    end

    local function isExcludedShopCrucifix(prompt)
        local anc = prompt.Parent
        local sawShop, sawCrucifix = false, false
        while anc and anc ~= workspace do
            if anc.Name == "JeffShop_Hotel" then sawShop = true end
            if anc.Name == "Crucifix" then sawCrucifix = true end
            anc = anc.Parent
        end
        return sawShop and sawCrucifix
    end

    local function detectPromptItem(prompt)
        local pName = prompt.Name
        local parent = prompt.Parent
        if not parent then return nil end
        local grandParent = parent.Parent

        if parent.Name == "ArchivesTerminal" or (grandParent and grandParent.Name == "ArchivesTerminal") then return nil end
        if isExcludedShopCrucifix(prompt) then return nil end

        if pName == "ActivateEventPrompt" and parent.Name == "Toolshed_Small" then return "Toolshed" end
        if pName == "ModulePrompt" and parent.Name == "Shears" then return "Shears" end
        if pName == "ActivateEventPrompt" and parent.Name == "LiveBreakerPolePickup" then return "Breaker" end
        if pName == "ModulePrompt" and parent.Name == "ElectricalKeyObtain" then return "Key" end
        if pName == "UnlockPrompt" and parent.Name == "Lock" then return "DoorLock" end
        if pName == "AwesomePrompt" and parent.Name == "VentGrate" then return "VentGrate" end
        if pName == "ModulePrompt" and parent.Name == "SkeletonKey" then return "SkeletonKey" end
        if pName == "ItemDropPickup" and parent.Name == "SecretCD" then return "SecretCD" end

        if pName == "ModulePrompt" and parent.Name == "FuseObtain" then return "Fuse" end
        if pName == "ActivateEventPrompt" and parent.Name == "Door" and grandParent and grandParent.Name == "Locker_Small" then return "SmallLocker" end
        if pName == "ActivateEventPrompt" and parent.Name == "Metal" then
            local anc = parent.Parent; local depth = 0
            while anc and anc ~= workspace and depth < 4 do
                if anc.Name == "OldWoodenTable" then return "WoodenTable" end
                anc = anc.Parent; depth = depth + 1
            end
        end
        if pName == "ActivateEventPrompt" and parent.Name == "Toolbox" then return "Toolbox" end
        if pName == "ModulePrompt" and parent.Name == "Glowsticks" then return "Glowsticks" end
        if pName == "ModulePrompt" and parent.Name == "Cheese" then return "Cheese" end
        if pName == "ModulePrompt" and parent.Name == "Bulklight" then return "Bulklight" end
        if pName == "ModulePrompt" and parent.Name == "Straplight" then return "Straplight" end
        if pName == "ModulePrompt" and parent.Name == "BandagePack" then return "BandagePack" end
        if pName == "ModulePrompt" and parent.Name == "BatteryPack" then return "BatteryPack" end
        if pName == "ModulePrompt" and parent.Name == "Bread" then return "Bread" end

        if pName == "ActivateEventPrompt" or pName == "InteractPrompt" then
            local curr = parent
            while curr and curr ~= workspace do
                local cn = curr.Name
                if cn == "DrawerContainer" or cn == "DrawerDoors" or cn == "Dresser" or cn == "Rolltop_Desk" or cn == "RolltopContainer" or cn == "Table" or cn == "Knobs" or cn:find("Backdoor_Table") then
                    return "Drawers"
                end
                curr = curr.Parent
            end
        end

        if pName == "LootPrompt" or parent.Name == "GoldPile" or (grandParent and grandParent.Name == "GoldPile") then return "Gold" end
        if pName == "ActivateEventPrompt" and (parent.Name == "ChestBox" or (grandParent and grandParent.Name == "ChestBox")) then return "Chest" end
        if pName == "ActivateEventPrompt" and (parent.Name == "ChestBoxLocked" or (grandParent and grandParent.Name == "ChestBoxLocked")) then return "Locked Chest" end

        if pName == "InteractPrompt" or pName == "HidePrompt" then
            local hidingSpot = parent
            while hidingSpot and not string.find(hidingSpot.Name, "HidingSpot") and hidingSpot.Name ~= "Locker" and hidingSpot.Name ~= "Wardrobe" and not hidingSpot.Name:find("Backdoor_Wardrobe") and hidingSpot.Parent ~= workspace do
                hidingSpot = hidingSpot.Parent
            end
            if hidingSpot and hidingSpot.Name ~= "Wardrobe" then
                local stuff = hidingSpot:FindFirstChild("Stuff")
                if stuff and #stuff:GetChildren() > 0 then return "Lockers" end
            end
        end

        if pName == "ModulePrompt" or pName == "Prompt" or pName == "ActivateEventPrompt" or prompt:IsA("ProximityPrompt") then
            local detectedType = matchItemByAncestor(parent)
            if detectedType then
                if not parent:IsA("Tool") and not Players:GetPlayerFromCharacter(parent.Parent) then
                    return detectedType
                end
            end
        end
        return nil
    end
    Core.detectPromptItem = detectPromptItem

    -- LootHolder-гвард ТОЛЬКО для Auto Interact, и глубина обхода — 1 (только
    -- прямой родитель промпта). Раньше глубина 3 иногда ловила LootHolder
    -- ПЕРВОГО открытого ящика того же контейнера и блокировала соседние —
    -- отсюда "не все 3 ящика открываются".
    local function hasLootHolderNearby(prompt)
        local curr = prompt.Parent
        if curr and curr ~= workspace and curr:FindFirstChild("LootHolder") then return true end
        return false
    end

    local function interactWithPrompt(prompt)
        if promptBusy[prompt] then return end
        if tick() - lastGlobalInteractTime < GLOBAL_INTERACT_COOLDOWN then return end
        lastGlobalInteractTime = tick()
        promptBusy[prompt] = true
        pcall(function()
            fireproximityprompt(prompt, 0)
            if prompt.HoldDuration and prompt.HoldDuration > 0 then
                pcall(function() prompt:InputHoldBegin(); task.wait(prompt.HoldDuration + 0.05) end)
                pcall(function() prompt:InputHoldEnd() end)
            end
        end)
        task.delay(0.6, function() promptBusy[prompt] = nil end)
    end
    Core.interactWithPrompt = interactWithPrompt

    local function registerPrompt(prompt)
        if prompt:IsA("ProximityPrompt") and not cachedPrompts[prompt] then
            cachedPrompts[prompt] = true
            applyPromptReach(prompt)
            applyInstantHold(prompt)
            prompt.AncestryChanged:Connect(function()
                if not prompt:IsDescendantOf(workspace) then
                    cachedPrompts[prompt] = nil
                    origHoldDurations[prompt] = nil
                    promptBusy[prompt] = nil
                end
            end)
        end
    end
    Core.cachedPrompts = cachedPrompts
    Core.registerPrompt = registerPrompt

    for _, desc in ipairs(workspace:GetDescendants()) do registerPrompt(desc) end
    workspace.DescendantAdded:Connect(registerPrompt)

    task.spawn(function()
        while true do
            task.wait(0.1)
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for prompt in pairs(cachedPrompts) do
                    if prompt.Parent and prompt.Enabled and not promptBusy[prompt] then
                        local ok, item = pcall(detectPromptItem, prompt)
                        if ok and item then
                            local wantLoot = isAutoLootWanted(item)
                            local wantInteract = (not wantLoot) and isAutoInteractWanted(item)
                            if wantLoot or (wantInteract and not hasLootHolderNearby(prompt)) then
                                local targetPart = getPromptTargetPart(prompt)
                                if targetPart then
                                    local dist = (hrp.Position - targetPart.Position).Magnitude
                                    if dist <= lootReachDistance then interactWithPrompt(prompt) end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    Core.getLootReachDistance = function() return lootReachDistance end
    Core.setLootReachDistance = function(v)
        lootReachDistance = v
        for prompt in pairs(cachedPrompts) do applyPromptReach(prompt) end
    end
    Core.setInstantInteract = function(v)
        instantInteractEnabled = v
        for prompt in pairs(cachedPrompts) do applyInstantHold(prompt) end
    end

    ---------------------------------------------------------
    -- [Общая Anti-логика]
    ---------------------------------------------------------
    local antiScreechEnabled = false
    local antiEyesEnabled = false
    local antiHaltEnabled = false
    local antiFigureHearingEnabled = false
    local antiSeekObstaclesEnabled = false
    local antiSnareEnabled = false
    local antiGiggleEnabled = false
    local antiDreadEnabled = false
    local antiDrownEnabled = false
    local antiGloombatEggEnabled = false

    -- Anti Screech
    local function destroyScreech(inst)
        if inst and inst.Name == "Screech" then pcall(function() inst:Destroy() end) end
    end
    local function purgeAllScreech()
        local camera = workspace.CurrentCamera or workspace:FindFirstChild("Camera")
        if camera then
            for _, d in ipairs(camera:GetDescendants()) do
                if d.Name == "Screech" then destroyScreech(d) end
            end
        end
        if LP.Character then
            for _, d in ipairs(LP.Character:GetDescendants()) do
                if d.Name == "Screech" then destroyScreech(d) end
            end
        end
    end
    do
        local camera = workspace.CurrentCamera or workspace:FindFirstChild("Camera")
        if camera then
            camera.DescendantAdded:Connect(function(child)
                if antiScreechEnabled and child.Name == "Screech" then destroyScreech(child) end
            end)
        end
    end
    task.spawn(function()
        while true do
            task.wait(0.25)
            if antiScreechEnabled then pcall(purgeAllScreech) end
        end
    end)

    -- Anti Eyes — ПОДТВЕРЖДЕНО: -850 (не -83, это была старая тестовая
    -- прикидка), постоянный прямой FireServer, а не перехват исходящего вызова
    local eyesPresentCount = 0
    local function trackEyesPresence(inst)
        -- "Lookman" на этом этаже — тот же противник, что "Eyes" (по аналогии
        -- с референсом, где это буквально алиас одной и той же сущности)
        if inst.Name == "Eyes" or inst.Name == "Lookman" then
            eyesPresentCount = eyesPresentCount + 1
            inst.AncestryChanged:Connect(function()
                if not inst:IsDescendantOf(workspace) then
                    eyesPresentCount = math.max(0, eyesPresentCount - 1)
                end
            end)
        end
    end
    for _, d in ipairs(workspace:GetDescendants()) do trackEyesPresence(d) end
    workspace.DescendantAdded:Connect(trackEyesPresence)

    task.spawn(function()
        while true do
            task.wait(0.05)
            if antiEyesEnabled and eyesPresentCount > 0 then
                -- Ищем ремоут каждый раз заново, а не полагаемся на значение,
                -- закэшированное при загрузке Core.lua — если MotorReplication
                -- ещё не успел реплицироваться в момент старта скрипта, старое
                -- значение навсегда оставалось nil и цикл молча ничего не делал
                local ev = remotesFolder and remotesFolder:FindFirstChild("MotorReplication")
                if ev then pcall(function() ev:FireServer(-850, 0) end) end
            end
        end
    end)

    -- Anti Halt
    local function purgeShade()
        local cam = workspace.CurrentCamera or workspace:FindFirstChild("Camera")
        local shade = cam and cam:FindFirstChild("Shade")
        if shade then pcall(function() shade:Destroy() end) end
    end
    do
        local cam = workspace.CurrentCamera or workspace:FindFirstChild("Camera")
        if cam then
            cam.ChildAdded:Connect(function(c)
                if antiHaltEnabled and c.Name == "Shade" then pcall(function() c:Destroy() end) end
            end)
        end
    end
    task.spawn(function()
        while true do
            task.wait(0.25)
            if antiHaltEnabled then purgeShade() end
        end
    end)

    -- Anti Figure Hearing — найдено в референсном скрипте: реальная защита
    -- не в гонке за Crouch-ремоут, а в том, чтобы у Figure/FigureRig/FigureSetup
    -- отключить CanTouch на всех частях. Если "слышит" реализовано через
    -- тач-хитбокс (а не только серверный флаг crouch), это убирает саму
    -- причину детекта — и тогда неважно, что там спамит Speed хак.
    -- Crouch-спам оставляю как доп. подстраховку (вдруг сервер всё же
    -- где-то читает флаг crouch напрямую), просто он больше не единственная
    -- линия защиты.
    local function purgeFigureTouch()
        for _, d in ipairs(workspace:GetDescendants()) do
            if d.Name == "FigureRig" or d.Name == "FigureSetup" then
                for _, part in ipairs(d:GetDescendants()) do
                    if part:IsA("BasePart") then pcall(function() part.CanTouch = false end) end
                end
            end
        end
    end
    workspace.DescendantAdded:Connect(function(d)
        if antiFigureHearingEnabled and (d.Name == "FigureRig" or d.Name == "FigureSetup") then
            task.wait(0.1)
            for _, part in ipairs(d:GetDescendants()) do
                if part:IsA("BasePart") then pcall(function() part.CanTouch = false end) end
            end
        end
    end)
    task.spawn(function()
        while true do
            task.wait(0.1)
            if antiFigureHearingEnabled and crouchEvent then
                pcall(function() crouchEvent:FireServer(true, nil) end)
            end
        end
    end)

    -- Anti Seek Obstacles: Seek_Arm + ChandelierObstruction.HurtPart
    local function purgeSeekArmHazards()
        local currentRooms = workspace:FindFirstChild("CurrentRooms")
        if not currentRooms then return end
        for _, room in ipairs(currentRooms:GetChildren()) do
            local assets = room:FindFirstChild("Assets")
            if assets then
                local seekArm = assets:FindFirstChild("Seek_Arm")
                if seekArm then pcall(function() seekArm:Destroy() end) end
                local chandelier = assets:FindFirstChild("ChandelierObstruction")
                if chandelier then
                    local hurtPart = chandelier:FindFirstChild("HurtPart")
                    if hurtPart then pcall(function() hurtPart:Destroy() end) end
                end
            end
        end
    end
    workspace.DescendantAdded:Connect(function(d)
        if not antiSeekObstaclesEnabled then return end
        if d.Name == "Seek_Arm" then
            task.wait(0.05); pcall(function() d:Destroy() end)
        elseif d.Name == "HurtPart" and d.Parent and d.Parent.Name == "ChandelierObstruction" then
            pcall(function() d:Destroy() end)
        end
    end)
    task.spawn(function()
        while true do
            task.wait(0.3)
            if antiSeekObstaclesEnabled then pcall(purgeSeekArmHazards) end
        end
    end)

    -- Anti Snare
    local function purgeSnareTouch(snareInst)
        local hitbox = snareInst:FindFirstChild("Hitbox")
        if hitbox then pcall(function() hitbox:Destroy() end) end
    end
    local function scanAllSnares()
        local currentRooms = workspace:FindFirstChild("CurrentRooms")
        if currentRooms then
            for _, room in ipairs(currentRooms:GetChildren()) do
                local snaresFolder = room:FindFirstChild("Snares")
                if snaresFolder then
                    for _, snare in ipairs(snaresFolder:GetChildren()) do purgeSnareTouch(snare) end
                end
            end
        end
        for _, d in ipairs(workspace:GetDescendants()) do
            if d.Name == "Snare" then purgeSnareTouch(d) end
        end
    end
    workspace.DescendantAdded:Connect(function(d)
        if not antiSnareEnabled then return end
        if d.Parent and d.Parent.Name == "Snares" then
            task.wait(0.1); purgeSnareTouch(d)
        elseif d.Name == "Hitbox" and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == "Snares" then
            pcall(function() d:Destroy() end)
        elseif d.Name == "Snare" then
            task.wait(0.1); purgeSnareTouch(d)
        end
    end)
    task.spawn(function()
        while true do
            task.wait(0.3)
            if antiSnareEnabled then pcall(scanAllSnares) end
        end
    end)

    -- Anti Giggle
    local function purgeGiggleTouch(giggleInst)
        local hitbox = giggleInst:FindFirstChild("Hitbox")
        if hitbox then pcall(function() hitbox:Destroy() end) end
    end
    workspace.DescendantAdded:Connect(function(d)
        if not antiGiggleEnabled then return end
        if d.Name == "GiggleCeiling" then
            task.wait(0.1); purgeGiggleTouch(d)
        elseif d.Name == "Hitbox" and d.Parent and d.Parent.Name == "GiggleCeiling" then
            pcall(function() d:Destroy() end)
        end
    end)
    task.spawn(function()
        while true do
            task.wait(0.3)
            if antiGiggleEnabled then
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d.Name == "GiggleCeiling" then purgeGiggleTouch(d) end
                end
            end
        end
    end)

    -- Anti Gloombat Egg
    local function purgeGloombatEgg(eggInst)
        local ti = eggInst:FindFirstChildOfClass("TouchInterest") or eggInst:FindFirstChild("TouchInterest")
        if ti then pcall(function() ti:Destroy() end) end
    end
    workspace.DescendantAdded:Connect(function(d)
        if not antiGloombatEggEnabled then return end
        if d.Name == "Egg" then
            task.wait(0.1); purgeGloombatEgg(d)
        elseif d.Name == "TouchInterest" and d.Parent and d.Parent.Name == "Egg" then
            pcall(function() d:Destroy() end)
        end
    end)
    task.spawn(function()
        while true do
            task.wait(0.3)
            if antiGloombatEggEnabled then
                local currentRooms = workspace:FindFirstChild("CurrentRooms")
                if currentRooms then
                    for _, room in ipairs(currentRooms:GetChildren()) do
                        for _, d in ipairs(room:GetDescendants()) do
                            if d.Name == "Egg" then purgeGloombatEgg(d) end
                        end
                    end
                end
            end
        end
    end)

    -- Anti Dread (firesignal — локальная подмена, доступна не у всех экзекьюторов)
    task.spawn(function()
        while true do
            task.wait(math.random(1,5))
            if antiDreadEnabled then
                pcall(function()
                    local ev = remotesFolder and remotesFolder:FindFirstChild("Dread")
                    if ev and firesignal then firesignal(ev.OnClientEvent, "clear") end
                end)
            end
        end
    end)

    -- Anti Drown (настоящий FireServer)
    task.spawn(function()
        while true do
            task.wait(1.5)
            if antiDrownEnabled then
                pcall(function()
                    local ev = remotesFolder and remotesFolder:FindFirstChild("Underwater")
                    if ev then ev:FireServer(false) end
                end)
            end
        end
    end)

    -- Сеттеры/геттеры для вкладок
    Core.setAntiScreech = function(v) antiScreechEnabled = v; if v then pcall(purgeAllScreech) end end
    Core.setAntiEyes = function(v) antiEyesEnabled = v end
    Core.setAntiHalt = function(v) antiHaltEnabled = v; if v then purgeShade() end end
    Core.setAntiFigureHearing = function(v)
        antiFigureHearingEnabled = v
        if v then pcall(purgeFigureTouch) end
    end
    Core.isAntiFigureHearingEnabled = function() return antiFigureHearingEnabled end
    Core.setAntiSeekObstacles = function(v) antiSeekObstaclesEnabled = v; if v then pcall(purgeSeekArmHazards) end end
    Core.setAntiSnare = function(v) antiSnareEnabled = v; if v then pcall(scanAllSnares) end end
    Core.setAntiGiggle = function(v) antiGiggleEnabled = v end
    Core.setAntiDread = function(v) antiDreadEnabled = v end
    Core.setAntiDrown = function(v) antiDrownEnabled = v end
    Core.setAntiGloombatEgg = function(v) antiGloombatEggEnabled = v end

    ---------------------------------------------------------
    -- [Конструктор стандартных секций вкладки]
    ---------------------------------------------------------
    local function buildStandardSections(tabId, tab, mobList, lootList, interactList, autoInteractListOverride)
        local autoInteractList = autoInteractListOverride or interactList
        selESPMobs[tabId] = {}
        selESPLoot[tabId] = {}
        selESPInteract[tabId] = {}
        selAutoLoot[tabId] = {}
        selAutoInteract[tabId] = {}
        tabAutoLootOn[tabId] = false
        tabAutoInteractOn[tabId] = false

        local espSec = tab:Section({ Title = "Enemies ESP & Notify", Column = "left" })
        if mobList and #mobList > 0 then
            espSec:Dropdown({
                Name = "Entity ESP", Options = mobList, MultiSelect = true, MaxSelect = #mobList,
                Flag = tabId.."_ESP_Mobs", Default = {},
                Callback = function(sel)
                    selESPMobs[tabId] = sel
                    for _, m in ipairs(mobList) do
                        if not isSelectedAnyESP(selESPMobs, m) then removeAllOfType(m) end
                        if isItemSelected(m, sel) then scanAll(m) end
                    end
                end
            })
        end

        local lootSec = tab:Section({ Title = "Loot ESP", Column = "left" })
        if lootList and #lootList > 0 then
            lootSec:Dropdown({
                Name = "Loot ESP", Options = lootList, MultiSelect = true, MaxSelect = #lootList,
                Flag = tabId.."_ESP_Loot", Default = {},
                Callback = function(sel)
                    selESPLoot[tabId] = sel
                    for _, it in ipairs(lootList) do
                        if not isSelectedAnyESP(selESPLoot, it) then removeAllOfType(it) end
                        if isItemSelected(it, sel) then scanAll(it) end
                    end
                end
            })
        end

        local interactSec = tab:Section({ Title = "Interactable's ESP", Column = "left" })
        if interactList and #interactList > 0 then
            interactSec:Dropdown({
                Name = "Interact ESP", Options = interactList, MultiSelect = true, MaxSelect = #interactList,
                Flag = tabId.."_ESP_Interact", Default = {},
                Callback = function(sel)
                    selESPInteract[tabId] = sel
                    for _, it in ipairs(interactList) do
                        if not isSelectedAnyESP(selESPInteract, it) then removeAllOfType(it) end
                        if isItemSelected(it, sel) then scanAll(it) end
                    end
                end
            })
        end

        local autoLootSec = tab:Section({ Title = "Auto Loot", Column = "mid" })
        autoLootSec:Toggle({
            Name = "Auto Loot", Default = false, Flag = tabId.."_AutoLoot_Enabled",
            Callback = function(v) tabAutoLootOn[tabId] = v end
        })
        if lootList and #lootList > 0 then
            autoLootSec:Dropdown({
                Name = "Auto Loot Items", Options = lootList, MultiSelect = true, MaxSelect = #lootList,
                Flag = tabId.."_AutoLoot_Items", Default = {},
                Callback = function(sel) selAutoLoot[tabId] = sel end
            })
        end

        local autoInterSec = tab:Section({ Title = "Auto Interact", Column = "mid" })
        autoInterSec:Toggle({
            Name = "Auto Interact", Default = false, Flag = tabId.."_AutoInteract_Enabled",
            Callback = function(v) tabAutoInteractOn[tabId] = v end
        })
        if autoInteractList and #autoInteractList > 0 then
            autoInterSec:Dropdown({
                Name = "Auto Interact Items", Options = autoInteractList, MultiSelect = true, MaxSelect = #autoInteractList,
                Flag = tabId.."_AutoInteract_Items", Default = {},
                Callback = function(sel) selAutoInteract[tabId] = sel end
            })
        end

        local antiSec = tab:Section({ Title = "Anti", Column = "right" })
        return antiSec
    end
    Core.buildStandardSections = buildStandardSections

    Core.mkAntiToggle = function(sec, name, flag, onChange)
        sec:Toggle({ Name = name, Default = false, Flag = flag, Callback = onChange })
    end

    return Core
end
