--[[
	Outdoors  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local Module = Abysall.LoadModule("Outdoors");  Module.Init(Shared) ... Module.Late(...) ... Module.Floors(...)
	Contents: Anti / No Damage multisection (Anti Surge, No Surge Damage) | Visual (Show Eyestalk Path).
	The code is moved 1:1 out of Main.luau (toggle labels renamed to "Anti ...").
]]

local Module = {}

function Module.Init(Shared)
	local Groupboxes, Tabs, Window
	   = Shared.Groupboxes, Shared.Tabs, Shared.Window

	Tabs.Outdoors = Window:AddTab("Outdoors", "outdoors", { Columns = 3 })

	Groupboxes.Outdoors_AntiTabbox = Tabs.Outdoors:AddLeftTabbox("Anti / No Damage")
	Groupboxes.Outdoors_Anti = Groupboxes.Outdoors_AntiTabbox:AddTab("Anti")
	Groupboxes.Outdoors_NoDamage = Groupboxes.Outdoors_AntiTabbox:AddTab("No Damage")

	Groupboxes.Outdoors_Visual = Tabs.Outdoors:AddMiddleGroupbox("Visual")

	Tabs.Outdoors:UpdateWarningBox({
		Visible = true,
		Title = "Compatability/Risk Warning",
		Text = "Features highlighted in red are risky / dont work in the current floor.",
	})
end

-- Anti Surge / No Surge Damage with their handlers (moved from the Exploits "Remove" groupbox). Main.luau calls Module.Late(Shared)
-- at the position where this code used to live.
function Module.Late(Shared)
	local FakeEvents, Globals, Groupboxes, Toggles
	   = Shared.FakeEvents, Shared.Globals, Shared.Groupboxes, Shared.Toggles

Groupboxes.Outdoors_Anti:AddToggle("RemoveSurge", { Text = "Anti Surge", Default = false, Tooltip = "Prevents 'Surge' from spawning."})
Groupboxes.Outdoors_NoDamage:AddToggle("NoSurgeDamage",   { Text = "No Surge Damage",   Default = false, Tooltip = "Prevents 'Surge' from hurting you." })

Toggles.NoSurgeDamage:OnChanged(function(Value)
	if Shared.RemotesFolder:FindFirstChild("SurgeRemote") then
		if Value then
			FakeEvents.Surge.Parent = Shared.RemotesFolder
			FakeEvents.Surge_Real.Parent = nil
		else
			FakeEvents.Surge_Real.Parent = Shared.RemotesFolder
			FakeEvents.Surge.Parent = nil
		end
	end
end)
Toggles.RemoveSurge:OnChanged(function(Value)
	if Globals.SurgeFrame then
		Globals.SurgeFrame.Name = (Value and "SurgeVignette_Disabled" or "SurgeVignette")
	end
end)
end

-- Show Eyestalk Path (+ the eyestalk path nodes) moved from the Floors tab. Main.luau calls Module.Floors(Shared) at the
-- position where this code used to live.
function Module.Floors(Shared)
	local Connections, CurrentRooms, Globals, Groupboxes, Objects, Options, Toggles
	   = Shared.Connections, Shared.CurrentRooms, Shared.Globals, Shared.Groupboxes, Shared.Objects, Shared.Options, Shared.Toggles

Connections.RoomsHandler = CurrentRooms.ChildAdded:Connect(function(Room)
	for _, Object in Globals.RoomsNodesFolder:GetChildren() do
		if Object.Name == "StuckPart" then Object:Destroy() end
	end

	if Room:GetAttribute("RawName") and string.find(Room:GetAttribute("RawName"), "Eyestalk") then
        local PreviousNode = nil

		local function CreateEyestalkNode(WaypointPos)
			local NewNode = Instance.new("Part")
			NewNode.Size = Vector3.one
			NewNode.Transparency = 1
			NewNode.Parent = Globals.SeekNodesFolder
			NewNode.Anchored = true
			NewNode.Position = WaypointPos
			NewNode.CanCollide = false
			NewNode.Name = "SeekLightNode"

			local PrevNode = PreviousNode or NewNode
			PreviousNode = NewNode

			local NewBeam = Instance.new("Beam")
			NewBeam.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Options.ShowEyestalkPathColor.Value), ColorSequenceKeypoint.new(1, Options.ShowEyestalkPathColor.Value) })
			NewBeam.FaceCamera = true
			NewBeam.Width0 = 0.2
			NewBeam.Width1 = 0.2
			NewBeam.Brightness = 10
			NewBeam.LightInfluence = 0
			NewBeam.LightEmission = 0
			NewBeam.Enabled = true

			local Vis = Toggles.ShowEyestalkPathToggle.Value and 0 or 1
			NewBeam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, Vis), NumberSequenceKeypoint.new(1, Vis) })
			NewBeam.Parent = Globals.SeekNodesFolder

			local A0 = Instance.new("Attachment", NewNode)
			local A1 = Instance.new("Attachment", PrevNode)
			NewBeam.Attachment0 = A0
			NewBeam.Attachment1 = A1

			table.insert(Objects.EyestalkHighlights, NewBeam)
		end

		Room:WaitForChild("RoomEntrance", 9e9)
		Room:WaitForChild("RoomExit", 9e9)

		while not Room:GetAttribute("PathFound") do
			if Toggles.ShowEyestalkPathToggle.Value then
				local EyePath = game:GetService("PathfindingService"):CreatePath({
					AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 2, AgentRadius = 1, AgentHeight = 1
				})
				EyePath:ComputeAsync(Shared.RootPart.Position, Room.RoomExit.Position)
				if EyePath.Status == Enum.PathStatus.Success then
					Room:SetAttribute("PathFound", true)
					for _, Waypoint in EyePath:GetWaypoints() do
						CreateEyestalkNode(Waypoint.Position)
						task.wait()
					end
                    break
				end
			end
			task.wait(0.25)
		end
	end
end)

local function UpdateBeamVisibility(BeamTable, ColorKey, Visible)
	local Vis = Visible and 0 or 1
	local Seq = NumberSequence.new({ NumberSequenceKeypoint.new(0, Vis), NumberSequenceKeypoint.new(1, Vis) })
	for _, Beam in BeamTable do Beam.Transparency = Seq end
end
local function UpdateBeamColor(BeamTable, Value)
	local Seq = ColorSequence.new({ ColorSequenceKeypoint.new(0, Value), ColorSequenceKeypoint.new(1, Value) })
	for _, Beam in BeamTable do Beam.Color = Seq end
end

Groupboxes.Outdoors_Visual:AddToggle("ShowEyestalkPathToggle", {
	Text = "Show Eyestalk Path", Default = false, Tooltip = "Shows you the correct path in the eyestalk chase.",
	Risky = Shared.Floor ~= "Garden"
})
Toggles.ShowEyestalkPathToggle:AddColorPicker("ShowEyestalkPathColor", { Text = "Eyestalk Path", Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })
Toggles.ShowEyestalkPathToggle:OnChanged(function(V) UpdateBeamVisibility(Objects.EyestalkHighlights, "ShowEyestalkPathColor", V) end)
Options.ShowEyestalkPathColor:OnChanged(function(V)  UpdateBeamColor(Objects.EyestalkHighlights, V) end)
end

return Module
