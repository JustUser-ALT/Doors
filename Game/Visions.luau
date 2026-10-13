--[[
	Visions  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local Module = Abysall.LoadModule("Visions");  Module.Init(Shared) ... Module.Late(...) ... Module.Floors(...)
	Sections: Retro | Hotel - | Super Hard Mode | Rooms | Cringle Workshop
	The code is moved 1:1 out of Main.luau (toggle labels renamed to "Anti ...").
]]

local Module = {}

function Module.Init(Shared)
	local Groupboxes, Tabs, Window
	   = Shared.Groupboxes, Shared.Tabs, Shared.Window

	Tabs.Visions = Window:AddTab("Visions", "visions", { Columns = 3 })

	Groupboxes.Visions_Retro = Tabs.Visions:AddLeftGroupbox("Retro")
	Groupboxes.Visions_Retro:AddToggle("BypassKillbricks",     { Text = "Anti Killbricks",       Default = false, Tooltip = "Prevents 'Lava' from hurting you." })
	Groupboxes.Visions_Retro:AddToggle("BypassSeekingWall",    { Text = "Anti Seeking Wall",     Default = false, Tooltip = "Prevents 'ScaryWall' from hurting you." })

	Groupboxes.Visions_HotelMinus = Tabs.Visions:AddLeftGroupbox("Hotel -")

	Groupboxes.Visions_SuperHardMode = Tabs.Visions:AddMiddleGroupbox("Super Hard Mode")
	Groupboxes.Visions_SuperHardMode:AddToggle("BypassBanana",         { Text = "Anti Banana",           Default = false, Tooltip = "Prevents 'Banana Peel' from slipping you up (sometimes doesn't work)." })
	Groupboxes.Visions_SuperHardMode:AddToggle("BypassJeff",           { Text = "Anti Jeff",             Default = false, Tooltip = "Prevents 'Jeff the Killer' from stabbing you (sometimes doesn't work)." })

	Groupboxes.Visions_Rooms = Tabs.Visions:AddRightGroupbox("Rooms")
	Groupboxes.Visions_Cringle = Tabs.Visions:AddRightGroupbox("Cringle Workshop")

	Tabs.Visions:UpdateWarningBox({
		Visible = true,
		Title = "Compatability/Risk Warning",
		Text = "Features highlighted in red are risky / dont work in the current floor.",
	})
end

-- Anti A-90 / No A-90 Damage with their handlers (moved from the Exploits "Remove" groupbox). Main.luau calls Module.Late(Shared)
-- at the position where this code used to live.
function Module.Late(Shared)
	local FakeEvents, Groupboxes, Toggles
	   = Shared.FakeEvents, Shared.Groupboxes, Shared.Toggles

Groupboxes.Visions_Rooms:AddToggle("RemoveA90",     { Text = "Anti A-90",     Default = false, Tooltip = "Prevents 'A-90' from spawning." })
Groupboxes.Visions_Rooms:AddToggle("NoA90Damage",     { Text = "No A-90 Damage",    Default = false, Tooltip = "Prevents 'A-90' from hurting you." })

Toggles.NoA90Damage:OnChanged(function(Value)
	if Shared.RemotesFolder:FindFirstChild("A90") then
		if Value then
			FakeEvents.A90.Parent = Shared.RemotesFolder
			FakeEvents.A90_Real.Parent = nil
		else
			FakeEvents.A90_Real.Parent = Shared.RemotesFolder
			FakeEvents.A90.Parent = nil
		end
	end
end)
Toggles.RemoveA90:OnChanged(function(Value)
	if Shared.Modules.A90 then
		Shared.Modules.A90.Name = Value and "A90_Disabled" or "A90"
	end
end)
end

-- Rooms (Auto Rooms ...), Cringle Workshop, the Super Hard Mode / Hotel - toggles with their handlers (moved from the Floors tab).
-- Main.luau calls Module.Floors(Shared) at the position where this code used to live.
function Module.Floors(Shared)
	local Connections, CurrentRooms, Functions, Globals, Groupboxes, LatestRoom, LocalPlayer, Objects, Options, Services, Toggles
	   = Shared.Connections, Shared.CurrentRooms, Shared.Functions, Shared.Globals, Shared.Groupboxes, Shared.LatestRoom, Shared.LocalPlayer, Shared.Objects, Shared.Options, Shared.Services, Shared.Toggles

Groupboxes.Visions_Rooms:AddDivider()
Groupboxes.Visions_Rooms:AddToggle("RoomsAutoWalk",             { Text = "Auto Rooms",       Default = false, Tooltip = "Automatically moves and hides from entities in The Rooms." })
Groupboxes.Visions_Rooms:AddSlider("RoomsAutoWalkPathfindTimeout", { Text = "Pathfind Timeout", Min = 0.5, Max = 3, Default = 1, Rounding = 1 })
Groupboxes.Visions_Rooms:AddToggle("RoomsAutoWalkIgnoreA60",    { Text = "Ignore A-60",      Default = false, Tooltip = "Continues to walk if entity 'A-60' is present, enables position spoof automatically." })
Groupboxes.Visions_Rooms:AddToggle("RoomsAutoWalkShowPathToggle", { Text = "Show Path",       Default = false, Tooltip = "Shows the current path of rooms auto-walk." })
Groupboxes.Visions_Rooms:AddToggle("RoomsAutoWalkSpoofFootsteps", {
    Text = "Spoof Footsteps", Default = false, Tooltip = "Makes it appear as if your character is walking normally.",
    Disabled = not Functions.CheckCompatability({"hookmetamethod", "newcclosure", "getnamecallmethod"}), DisabledTooltip = Globals.IncompatibleMessage
})

Toggles.RoomsAutoWalk:OnChanged(function()
	for _, Object in Globals.RoomsNodesFolder:GetChildren() do
		if Object.Name == "PathNode" then Object:Destroy() end
	end
end)
Toggles.RoomsAutoWalkShowPathToggle:AddColorPicker("RoomsAutoWalkShowPathColor", { Text = "Path", Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })
Toggles.RoomsAutoWalkShowPathToggle:OnChanged(function(Value)
	for _, Object in Globals.RoomsNodesFolder:GetChildren() do
		if Object.Name == "PathNode" then Object.Transparency = Value and 0.5 or 1 end
	end
end)
Options.RoomsAutoWalkShowPathColor:OnChanged(function(Value)
	for _, Object in Globals.RoomsNodesFolder:GetChildren() do
		if Object.Name == "PathNode" then Object.Color = Value end
	end
end)

Functions.RoomsAutoWalk = {}
Functions.RoomsAutoWalk.GetNearestHidingSpot = function()
	local Nearest = { Distance = math.huge, Object = nil }
	for _, Object in Objects.HidingSpots do
		if Object.PrimaryPart and Object:FindFirstChild("HidePrompt") then
			local Distance = LocalPlayer:DistanceFromCharacter(Object.PrimaryPart.Position)
			if Distance < Nearest.Distance and Object.PrimaryPart.Position.Y > -10 then
				local HiddenPlayer = Object:FindFirstChild("HiddenPlayer", true)
				if HiddenPlayer and not HiddenPlayer.Value then
					Nearest.Distance = Distance
					Nearest.Object = Object
				end
			end
		end
	end
	return Nearest.Object
end

local RoomsEntityList = { "RushMoving","AmbushMoving","BackdoorRush","A60","A120","CustomEntity","GlitchRush","GlitchAmbush" }
Functions.RoomsAutoWalk.GetPathfindTarget = function()
	for _, Object in Services.Workspace:GetChildren() do
		if table.find(RoomsEntityList, Object.Name) and Object.PrimaryPart then
			local Y = Object.PrimaryPart.Position.Y
			if Y > -10 and Y < 150 then
				if Object.Name == "A60" and not Toggles.RoomsAutoWalkIgnoreA60.Value or Object.Name ~= "A60" then
					return Functions.RoomsAutoWalk.GetNearestHidingSpot() or CurrentRooms[tostring(LatestRoom.Value)]:FindFirstChild("RoomExit")
				end
			end
		end
	end
	return CurrentRooms[tostring(LatestRoom.Value)]:FindFirstChild("RoomExit")
end

Connections.RoomsAutoWalkHandler = Services.RunService.Heartbeat:Connect(function()
	if Shared.Floor ~= "Rooms" or not Toggles.RoomsAutoWalk.Value or Globals.RoomsAutoWalkActive or not Shared.CollisionPart or LatestRoom.Value >= 1000 then return end
	Globals.RoomsAutoWalkActive = true

	local Path = Services.PathfindingService:CreatePath({
		AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 4,
		AgentRadius = 1.5, AgentHeight = 1.5, Costs = { StuckPart = 8 }
	})

	if Toggles.RoomsAutoWalkIgnoreA60.Value and not Toggles.PositionSpoof.Value then
		Toggles.PositionSpoof:SetValue(true)
	end

	local TargetPart = Functions.RoomsAutoWalk.GetPathfindTarget()
	if not TargetPart then
		Globals.RoomsAutoWalkActive = false
		return
	end

	local TargetPosition
	if TargetPart.Name == "RoomExit" then
		TargetPosition = TargetPart.Position
	elseif TargetPart:FindFirstChild("HidePrompt") then
		for _, Part in TargetPart:GetDescendants() do
			if Part:IsA("BasePart") then Part.CanCollide = false end
		end
		TargetPosition = TargetPart.PrimaryPart.Position
	end

	if Shared.CollisionPart.Anchored and not TargetPart:FindFirstChild("HidePrompt") then
		Shared.Character:SetAttribute("Hiding", true)
		Shared.RemotesFolder.CamLock:FireServer()
		Shared.Character:SetAttribute("Hiding", false)
	end

	local CurrentRoom = CurrentRooms[tostring(LatestRoom.Value)]
	if CurrentRoom:FindFirstChild("Door") then
		CurrentRoom.Door.Door.CanCollide = false
	end

	if not TargetPosition or LocalPlayer:DistanceFromCharacter(TargetPosition) >= 750 then
		Globals.RoomsAutoWalkActive = false
		return
	end

	Path:ComputeAsync(Shared.CollisionPart.Position, TargetPosition)
	local Waypoints = Path:GetWaypoints()

	if #Waypoints == 0 then
		local RoomExit = CurrentRoom:FindFirstChild("RoomExit")
		if RoomExit then Shared.Humanoid:MoveTo(RoomExit.Position) end
		Globals.RoomsAutoWalkActive = false
		return
	end

	for _, Node in Globals.RoomsNodesFolder:GetChildren() do
		if Node.Name == "PathNode" then Node:Destroy() end
	end

	for _, Waypoint in Waypoints do
		local Block = Instance.new("Part", Globals.RoomsNodesFolder)
		Block.Transparency = Toggles.RoomsAutoWalkShowPathToggle.Value and 0.5 or 1
		Block.Size = Vector3.one
		Block.Position = Waypoint.Position
		Block.Shape = Enum.PartType.Ball
		Block.CanCollide = false
		Block.Anchored = true
		Block.Name = "PathNode"
		Block.Color = Options.RoomsAutoWalkShowPathColor.Value
		Block.Material = Enum.Material.Neon
	end

	local Stuck = false
	for _, Waypoint in Waypoints do
		if Stuck or not Toggles.RoomsAutoWalk.Value then break end

		local Finished = false
		local Start = tick()

		local StepConnection = Services.RunService.RenderStepped:Connect(function()
			if Stuck or not Toggles.RoomsAutoWalk.Value then Finished = true return end

			local NewTarget = Functions.RoomsAutoWalk.GetPathfindTarget()
			if NewTarget and NewTarget:FindFirstChild("HidePrompt") and not TargetPart:FindFirstChild("HidePrompt") then
				Finished = true return
			end
			if TargetPart:FindFirstChild("HidePrompt") then
				local HidePrompt = TargetPart:FindFirstChild("HidePrompt")
				if LocalPlayer:DistanceFromCharacter(TargetPosition) < HidePrompt.MaxActivationDistance
					and Shared.Character:GetAttribute("Hiding") ~= true
				then
					Functions.ForceFirePrompt(HidePrompt)
				end
			end
			local FlatPos = Vector3.new(Waypoint.Position.X, Shared.RootPart.Position.Y, Waypoint.Position.Z)
			if LocalPlayer:DistanceFromCharacter(FlatPos) < 5 then Finished = true end
			Shared.Humanoid:MoveTo(Waypoint.Position)
		end)

		while not Finished do
			if tick() - Start > Options.RoomsAutoWalkPathfindTimeout.Value then
				local StuckBlock = Instance.new("Part", Globals.RoomsNodesFolder)
				StuckBlock.Transparency = 1
				StuckBlock.Size = Vector3.one
				StuckBlock.CFrame = Shared.Collision.CFrame
				StuckBlock.Shape = Enum.PartType.Ball
				StuckBlock.CanCollide = false
				StuckBlock.Anchored = true
				StuckBlock.Name = "StuckPart"
				local Modifier = Instance.new("PathfindingModifier", StuckBlock)
				Modifier.Label = "StuckPart"
				Stuck = true
				break
			end
			task.wait()
		end
		StepConnection:Disconnect()
		Shared.Humanoid:MoveTo(Shared.RootPart.Position)
	end

	Globals.RoomsAutoWalkActive = false
end)

Groupboxes.Visions_Cringle:AddButton({
    Text = "Auto Complete Cringle",
    Tooltip = "Instantly completes the quest.",
    Func = function()
        local TouchPart = CurrentRooms:FindFirstChild("RippleExitDoor", true)
        if TouchPart then
            Shared.Character:PivotTo(TouchPart:GetPivot())
        end
    end
})

Groupboxes.Visions_SuperHardMode:AddToggle("RemoveSeekTrigger", {
	Text = "Delete Seek Trigger", Default = false, Tooltip = "Diables the 'Seek' chase trigger.",
	Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel"),
	Disabled = not Functions.CheckCompatability({"firetouchinterest"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visions_SuperHardMode:AddToggle("RemoveFigure", {
	Text = "Delete Figure", Default = false, Tooltip = "Completely removes the entity 'Figure' (doesn't always work).",
	Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel" or Shared.Floor == "Mines"),
	Disabled = not Functions.CheckCompatability({"isnetworkowner"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visions_SuperHardMode:AddToggle("AutoRevive", {
	Text = "Infinite Revives", Default = false, Tooltip = "Automatically revives after dying, with unlimited respawns.",
	Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel")
})
Groupboxes.Visions_SuperHardMode:AddToggle("FigureGodmode", {
	Text = "Figure Godmode", Default = false, Tooltip = "Prevents 'Figure' from hurting you.",
	Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel")
})
Groupboxes.Visions_SuperHardMode:AddDivider()
Groupboxes.Visions_SuperHardMode:AddToggle("RemoveBasementGate",  { Text = "Remove Basement Gate",   Default = false, Tooltip = "Removes the gate from basement rooms.",            Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel") })
Groupboxes.Visions_SuperHardMode:AddToggle("RemovePaintingsDoor", { Text = "Remove Paintings Door",  Default = false, Tooltip = "Removes the fireplace doors from painting rooms.", Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel") })
Groupboxes.Visions_SuperHardMode:AddToggle("RemoveSkeletonDoor",  { Text = "Remove Skeleton Door",   Default = false, Tooltip = "Removes the skeleton door from the infirmary.",    Risky = Shared.Floor ~= "Fools" })

local ObstructionNames = { ThingToOpen = "RemoveBasementGate", MovingDoor = "RemovePaintingsDoor", Wax_Door = "RemoveSkeletonDoor" }
for ObjName, ToggleName in ObstructionNames do
	Toggles[ToggleName]:OnChanged(function(Value)
		for _, Object in Objects.Obstructions do
			if Object.Name == ObjName then
				Object:PivotTo(Value and CFrame.new(-10000, -10000, -10000) or Object:GetAttribute("OriginalPosition"))
			end
		end
	end)
end

Groupboxes.Visions_HotelMinus:AddToggle("RemoveSeekTriggerHotelMinus", {
	Text = "Delete Seek Trigger", Default = false, Tooltip = "Diables the 'Seek' chase trigger.",
	Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel"),
	Disabled = not Functions.CheckCompatability({"firetouchinterest"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visions_HotelMinus:AddToggle("RemoveFigureHotelMinus", {
	Text = "Delete Figure", Default = false, Tooltip = "Completely removes the entity 'Figure' (doesn't always work).",
	Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel" or Shared.Floor == "Mines"),
	Disabled = not Functions.CheckCompatability({"isnetworkowner"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visions_HotelMinus:AddToggle("AutoReviveHotelMinus", {
	Text = "Infinite Revives", Default = false, Tooltip = "Automatically revives after dying, with unlimited respawns.",
	Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel")
})
Groupboxes.Visions_HotelMinus:AddToggle("FigureGodmodeHotelMinus", {
	Text = "Figure Godmode", Default = false, Tooltip = "Prevents 'Figure' from hurting you.",
	Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel")
})
Groupboxes.Visions_HotelMinus:AddDivider()
Groupboxes.Visions_HotelMinus:AddToggle("RemoveBasementGateHotelMinus",  { Text = "Remove Basement Gate",   Default = false, Tooltip = "Removes the gate from basement rooms.",            Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel") })
Groupboxes.Visions_HotelMinus:AddToggle("RemovePaintingsDoorHotelMinus", { Text = "Remove Paintings Door",  Default = false, Tooltip = "Removes the fireplace doors from painting rooms.", Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel") })

-- The same feature is reachable from several sections (Super Hard Mode, Hotel - and, for Delete Figure, Mines > Anti). The
-- original toggle is the one the script logic reads; its copies are kept in sync with it in both directions.
local function LinkToggles(MasterName, MirrorNames)
	local Master = Toggles[MasterName]
	for _, MirrorName in MirrorNames do
		Toggles[MirrorName]:OnChanged(function(Value)
			if Master.Value ~= Value then Master:SetValue(Value) end
		end)
	end
	Master:OnChanged(function(Value)
		for _, MirrorName in MirrorNames do
			local Mirror = Toggles[MirrorName]
			if Mirror.Value ~= Value then Mirror:SetValue(Value) end
		end
	end)
end
LinkToggles("RemoveSeekTrigger",   { "RemoveSeekTriggerHotelMinus" })
LinkToggles("RemoveFigure",        { "RemoveFigureMines", "RemoveFigureHotelMinus" })
LinkToggles("AutoRevive",          { "AutoReviveHotelMinus" })
LinkToggles("FigureGodmode",       { "FigureGodmodeHotelMinus" })
LinkToggles("RemoveBasementGate",  { "RemoveBasementGateHotelMinus" })
LinkToggles("RemovePaintingsDoor", { "RemovePaintingsDoorHotelMinus" })
end

return Module
