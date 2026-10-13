--[[
	Mines  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local Module = Abysall.LoadModule("Mines");  Module.Init(Shared) ... Module.Floors(...)
	Column 1 Automation: Skip Seek (Mines), Auto Steer Minecart, Turn Distance, Crouch Distance, Auto Complete Dam Seek
	Column 2 Visual:     Show Seek Path
	Column 3 Anti:       Anti Giggle, Anti Gloombat Eggs, Anti Figure (copy of "Delete Figure", kept in sync with it)
	The code is moved 1:1 out of Main.luau.
]]

local Module = {}

function Module.Init(Shared)
	local Functions, Globals, Groupboxes, Tabs, Window
	   = Shared.Functions, Shared.Globals, Shared.Groupboxes, Shared.Tabs, Shared.Window

	Tabs.Mines = Window:AddTab("Mines", "mines", { Columns = 3 })

	Groupboxes.Mines_Automation = Tabs.Mines:AddLeftGroupbox("Automation")
	Groupboxes.Mines_Visual = Tabs.Mines:AddMiddleGroupbox("Visual")

	Groupboxes.Mines_Anti = Tabs.Mines:AddRightGroupbox("Anti")
	Groupboxes.Mines_Anti:AddToggle("BypassGiggle",         { Text = "Anti Giggle",           Default = false, Tooltip = "Prevents 'Giggle' from attacking you." })
	Groupboxes.Mines_Anti:AddToggle("BypassGloombatEggs",   { Text = "Anti Gloombat Eggs",    Default = false, Tooltip = "Prevents taking damage from stepping on 'Gloombat' eggs." })
	Groupboxes.Mines_Anti:AddToggle("RemoveFigureMines", {
		Text = "Anti Figure", Default = false, Tooltip = "Completely removes the entity 'Figure' (doesn't always work).",
		Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel" or Shared.Floor == "Mines"),
		Disabled = not Functions.CheckCompatability({"isnetworkowner"}), DisabledTooltip = Globals.IncompatibleMessage
	})

	Tabs.Mines:UpdateWarningBox({
		Visible = true,
		Title = "Compatability/Risk Warning",
		Text = "Features highlighted in red are risky / dont work in the current floor.",
	})
end

-- Skip Seek / Auto Steer Minecart / Auto Complete Dam Seek / Show Seek Path with their handlers (moved from the Floors tab).
-- Main.luau calls Module.Floors(Shared) at the position where this code used to live.
function Module.Floors(Shared)
	local Functions, Globals, Groupboxes, LatestRoom, Objects, Options, Toggles
	   = Shared.Functions, Shared.Globals, Shared.Groupboxes, Shared.LatestRoom, Shared.Objects, Shared.Options, Shared.Toggles

Groupboxes.Mines_Automation:AddToggle("SkipSeekMines", {
	Text = "Skip Seek (Mines)",
	Default = false,
	Tooltip = "Skips the entire Seek sections.",
	Risky = Shared.Floor ~= "Mines"
})

Toggles.SkipSeekMines:OnChanged(function(Value)
	if Value then
		if Shared.Floor ~= "Mines" then
			return
		end
		task.spawn(function()
			local MinesSkipSeekCurrentRooms

			repeat
				if not Toggles.SkipSeekMines.Value then
					return
				end

				MinesSkipSeekCurrentRooms = workspace:FindFirstChild("CurrentRooms")
				task.wait()
			until MinesSkipSeekCurrentRooms

			local MinesSkipSeekStartRoom

			repeat
				if not Toggles.SkipSeekMines.Value then
					return
				end

				MinesSkipSeekCurrentRooms = workspace:FindFirstChild("CurrentRooms")

				if MinesSkipSeekCurrentRooms then
					MinesSkipSeekStartRoom = MinesSkipSeekCurrentRooms:FindFirstChild("42")
				end

				task.wait()
			until MinesSkipSeekStartRoom

			local MinesSkipSeekStartDoor

			repeat
				if not Toggles.SkipSeekMines.Value then
					return
				end

				MinesSkipSeekStartDoor = MinesSkipSeekStartRoom:FindFirstChild("Door", true)
				task.wait()
			until MinesSkipSeekStartDoor

			repeat
				if not Toggles.SkipSeekMines.Value then
					return
				end

				task.wait()
			until MinesSkipSeekStartDoor:GetAttribute("Opened") == true

			if Shared.Character and Shared.Character:GetAttribute("Minecarting") == true then
				Shared.Character:SetAttribute("Minecarting", false)
			end

			for _, MinesSkipSeekRoomNumber in ipairs({
				43, 44, 45, 46, 47, 48, 49,
				78, 79, 80, 81, 82, 83
			}) do
				if not Toggles.SkipSeekMines.Value then
					return
				end

				local MinesSkipSeekRoom

				repeat
					if not Toggles.SkipSeekMines.Value then
						return
					end

					MinesSkipSeekCurrentRooms = workspace:FindFirstChild("CurrentRooms")

					if MinesSkipSeekCurrentRooms then
						MinesSkipSeekRoom = MinesSkipSeekCurrentRooms:FindFirstChild(
							tostring(MinesSkipSeekRoomNumber)
						)
					end

					task.wait()
				until MinesSkipSeekRoom

				local MinesSkipSeekDoor

				repeat
					if not Toggles.SkipSeekMines.Value then
						return
					end

					MinesSkipSeekDoor = MinesSkipSeekRoom:FindFirstChild("Door", true)
					task.wait()
				until MinesSkipSeekDoor

				repeat
					if not Toggles.SkipSeekMines.Value then
						return
					end

					if Shared.Character then
						Shared.Character:PivotTo(MinesSkipSeekDoor:GetPivot())
					end

					task.wait()
				until MinesSkipSeekDoor:GetAttribute("Opened") == true

				if MinesSkipSeekRoomNumber == 49 or MinesSkipSeekRoomNumber == 83 then
					if not Shared.Character then
						return
					end

					local MinesSkipSeekVoidPivot = Shared.Character:GetPivot()
					MinesSkipSeekVoidPivot = MinesSkipSeekVoidPivot + Vector3.new(0, -1000, 0)

					task.wait(0.3)

					for MinesSkipSeekVoidCount = 1, 12 do
						Shared.Character:PivotTo(MinesSkipSeekVoidPivot)
					end

					for MinesSkipSeekVoidCount = 1, 12 do
						Shared.Character:PivotTo(MinesSkipSeekVoidPivot)
					end

					for MinesSkipSeekVoidCount = 1, 12 do
						Shared.Character:PivotTo(MinesSkipSeekVoidPivot)
					end

					task.wait(0.3)

					for MinesSkipSeekVoidCount = 1, 6 do
						Shared.Character:PivotTo(MinesSkipSeekVoidPivot)
					end
				end

				if MinesSkipSeekRoomNumber == 83 then
					return
				end
			end
		end)
	end
end)

Groupboxes.Mines_Automation:AddToggle("AutoSteerMinecart", {
	Text = "Auto Steer Minecart", Default = false, Tooltip = "Automatically completes the minecart chase.",
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Mines_Automation:AddSlider("AutoSteerMinecartTurnDistance", {
	Text = "Turn Distance", Min = 20, Max = 40, Default = 30, Rounding = 0,
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Mines_Automation:AddSlider("AutoSteerMinecartDuckDistance", {
	Text = "Crouch Distance", Min = 20, Max = 40, Default = 30, Rounding = 0,
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})

Groupboxes.Mines_Automation:AddButton({
    Text = "Auto Complete Dam Seek",
    Tooltip = "Automatically teleports to and interacts with each water pump.",
    Func = function()
        if LatestRoom.Value < 100 or Shared.Floor ~= "Mines" then
            Functions.Notify({Title = "You must be in Room 200 to do this."})
            return
        end

		local IsCutscene = false
		local CutsceneConnection = Shared.RemotesFolder.Cutscene.OnClientEvent:Connect(function()
			IsCutscene = true
			task.wait(7)
			IsCutscene = false
		end)

        local function GetNextPump()
            local Highest = {
                Height = -69420,
                Object = nil
            }
            for _, Object in pairs(Objects.Objectives) do
                if Object.Name == "WaterPump" and Object:GetAttribute("Abysall_Completed") ~= true then
                    if Object.PrimaryPart and Object.PrimaryPart.Position.Y > Highest.Height then
                        Highest.Object = Object
                        Highest.Height = Object.PrimaryPart.Position.Y
                    end
                end
            end
            return Highest.Object
        end

        local function HandlePump(Pump)

            while task.wait(0.1) do
				if IsCutscene then
					continue
				end

                Shared.Character:PivotTo(Pump:GetPivot())

                local Prompt = Pump:FindFirstChild("ValvePrompt", true)
                if Prompt then
                    Functions.ForceFirePrompt(Prompt)
                end

                if Pump:GetAttribute("Abysall_Completed") then
                    break
                end
            end
        end

        Functions.Notify({Title = "Attempting to complete the valves.", Body = "Please wait."})
        while task.wait(0.1) do
            local Pump = GetNextPump()
            if Pump then
                HandlePump(Pump)
            else
                break
            end
        end
        Functions.Notify({Title = "Successfully completed the valves."})
    end
})

Groupboxes.Mines_Visual:AddToggle("ShowSeekPathToggle", {
	Text = "Show Seek Path", Default = false, Tooltip = "Shows you the correct path in seek chases.",
	Risky = Shared.Floor ~= "Mines"
})
Toggles.ShowSeekPathToggle:AddColorPicker("ShowSeekPathColor", { Text = "Seek Path", Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })

local function UpdateBeamVisibility(BeamTable, ColorKey, Visible)
	local Vis = Visible and 0 or 1
	local Seq = NumberSequence.new({ NumberSequenceKeypoint.new(0, Vis), NumberSequenceKeypoint.new(1, Vis) })
	for _, Beam in BeamTable do Beam.Transparency = Seq end
end
local function UpdateBeamColor(BeamTable, Value)
	local Seq = ColorSequence.new({ ColorSequenceKeypoint.new(0, Value), ColorSequenceKeypoint.new(1, Value) })
	for _, Beam in BeamTable do Beam.Color = Seq end
end

Toggles.ShowSeekPathToggle:OnChanged(function(V)  UpdateBeamVisibility(Objects.SeekHighlights, "ShowSeekPathColor", V) end)
Options.ShowSeekPathColor:OnChanged(function(V)   UpdateBeamColor(Objects.SeekHighlights, V) end)
end

return Module
