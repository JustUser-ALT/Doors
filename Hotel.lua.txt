--[[
    Just X Hub — Hotel module. return function(Core, Lib, Win, HotelTab)
--]]
return function(Core, Lib, Win, HotelTab)
    local LP = Core.LP
    local remotesFolder = Core.remotesFolder

    local HotelMobs = { "Rush", "Ambush", "Figure", "Screech", "Eyes", "Dupe", "Sally" }
    local HotelLoot = {
        "Gold", "Stardust", "Bandage", "Key", "Lighter", "Flashlight", "Lockpick",
        "Vitamins", "Candle", "Smoothie", "AlarmClock", "Crucifix", "Shears",
        "Donut", "Breaker", "SkeletonKey", "TipJar", "Cheese"
    }
    local HotelInteract = {
        "Door", "Drawers", "Lockers", "Lever", "VentGrate", "SmallToolshed", "Toolshed",
        "DoorLock", "Chest", "Locked Chest", "Books", "GlitchCube"
    }

    local HotelAntiSec = Core.buildStandardSections("Hotel", HotelTab, HotelMobs, HotelLoot, HotelInteract)

    Core.mkAntiToggle(HotelAntiSec, "Anti Screech", "Hotel_AntiScreech", Core.setAntiScreech)
    Core.mkAntiToggle(HotelAntiSec, "Anti Eyes", "Hotel_AntiEyes", Core.setAntiEyes)
    Core.mkAntiToggle(HotelAntiSec, "Anti Halt", "Hotel_AntiHalt", Core.setAntiHalt)
    Core.mkAntiToggle(HotelAntiSec, "Anti Figure Hearing", "Hotel_AntiFigureHearing", Core.setAntiFigureHearing)
    Core.mkAntiToggle(HotelAntiSec, "Anti Seek Obstacles", "Hotel_AntiSeek", Core.setAntiSeekObstacles)
    Core.mkAntiToggle(HotelAntiSec, "Anti Snare", "Hotel_AntiSnare", Core.setAntiSnare)
    Core.mkAntiToggle(HotelAntiSec, "Anti Dread", "Hotel_AntiDread", Core.setAntiDread)
    -- Anti Drown только в Mines — здесь не добавляем

    ---------------------------------------------------------
    -- [Library Room 50 Solver]
    ---------------------------------------------------------
    local LibrarySec = HotelTab:Section({ Title = "Library Room 50", Column = "right" })

    local librarySolverEnabled = false
    local autoOpenPadlockEnabled = false
    local libraryCollectedHints = {}

    local padlockHintRemote = remotesFolder and remotesFolder:FindFirstChild("PadlockHint")
    if padlockHintRemote then
        padlockHintRemote.OnClientEvent:Connect(function(shapeId, digit)
            libraryCollectedHints[shapeId] = tostring(digit)
        end)
    end

    local function getLibraryCode()
        local backpack = LP:FindFirstChildOfClass("Backpack")
        local char = LP.Character
        local paper = (backpack and backpack:FindFirstChild("LibraryHintPaper"))
                   or (char and char:FindFirstChild("LibraryHintPaper"))
        if not paper or not paper:FindFirstChild("UI") then return "_____" end
        local result = {}
        for i = 1, 5 do
            local imgLabel = paper.UI:FindFirstChild(tostring(i))
            if imgLabel and imgLabel:IsA("ImageLabel") then
                local offsetX = math.floor(imgLabel.ImageRectOffset.X + 0.5)
                local rectW = imgLabel.ImageRectSize.X
                local width = (rectW and rectW > 0) and rectW or 50
                local shapeId = math.floor((offsetX / width) + 0.5)
                result[i] = libraryCollectedHints[shapeId] or "?"
            else
                result[i] = "?"
            end
        end
        return table.concat(result, "")
    end

    local libraryCodeGui = Instance.new("ScreenGui")
    libraryCodeGui.Name = "LibraryCodeOverlayGui"
    pcall(function() libraryCodeGui.Parent = game:GetService("CoreGui") end)
    if not libraryCodeGui.Parent then libraryCodeGui.Parent = LP:WaitForChild("PlayerGui") end

    local libraryCodeLabel = Instance.new("TextLabel")
    libraryCodeLabel.Size = UDim2.new(0, 160, 0, 36)
    libraryCodeLabel.Position = UDim2.new(0.85, 0, 0.05, 0)
    libraryCodeLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    libraryCodeLabel.BackgroundTransparency = 0.3
    libraryCodeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    libraryCodeLabel.Font = Enum.Font.GothamBold
    libraryCodeLabel.TextSize = 16
    libraryCodeLabel.Text = "Code: -----"
    libraryCodeLabel.Visible = false
    libraryCodeLabel.Parent = libraryCodeGui
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = libraryCodeLabel
    end

    local lastAutoOpenedCode = ""

    -- Путь пэдлока подтверждён скриншотом:
    -- CurrentRooms.50.Door.Padlock.ActivateEventPrompt (прямые дети, без рекурсии)
    task.spawn(function()
        while true do
            local ok = pcall(function()
                task.wait(0.3)
                local currentRooms = workspace:FindFirstChild("CurrentRooms")
                local room50 = currentRooms and currentRooms:FindFirstChild("50")
                local isInRoom50 = room50 ~= nil and Core.getPlayerCurrentRoom() == room50

                if isInRoom50 and librarySolverEnabled then
                    local code = getLibraryCode()
                    libraryCodeLabel.Text = "Code: " .. code
                    libraryCodeLabel.Visible = true

                    if autoOpenPadlockEnabled and not code:find("%?") and #code == 5 and code ~= lastAutoOpenedCode then
                        local doorFolder = room50:FindFirstChild("Door")
                        local padlock = doorFolder and doorFolder:FindFirstChild("Padlock")
                        if padlock then
                            local padlockPos = padlock:GetPivot().Position
                            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                            if hrp and (hrp.Position - padlockPos).Magnitude <= 15 then
                                local prompt = padlock:FindFirstChild("ActivateEventPrompt")
                                if prompt then
                                    Core.interactWithPrompt(prompt)
                                    task.wait(0.3)
                                end
                                local plRemote = remotesFolder and remotesFolder:FindFirstChild("PL")
                                if plRemote then
                                    lastAutoOpenedCode = code
                                    plRemote:FireServer(code)
                                    Lib:Notify({ Title = "Padlock Solved", Desc = "Entered code: " .. code, Type = "Success", Duration = 4 })
                                end
                            end
                        end
                    end
                else
                    libraryCodeLabel.Visible = false
                end
            end)
            if not ok then task.wait(1) end
        end
    end)

    LibrarySec:Toggle({ Name = "Auto Library Solver", Default = false, Flag = "LibrarySolver_Enabled", Callback = function(v) librarySolverEnabled = v end })
    LibrarySec:Toggle({ Name = "Auto Open Door (Padlock)", Default = false, Flag = "LibraryAutoOpen_Enabled", Callback = function(v) autoOpenPadlockEnabled = v end })
end
