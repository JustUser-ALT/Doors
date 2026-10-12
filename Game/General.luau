--[[
	General tab  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local General = Abysall.LoadModule("General");  General.Init(Shared) ... General.Bypass(...) ... General.Late(...)
	Contents (3 columns): Character + Self | Camera / Effects / Audio + Farming | Bypass + Misc / Debug.
	Code moved 1:1 out of Main.luau.
	The "Automation" groupbox now lives in Hotel.luau.

-- Mutable Main state (Character, Humanoid, RemotesFolder, Floor, CustomPhysics, OldJump, OldSlide) is
-- read/written through Shared.<Name> so it always reflects Main's live value.
]]

local Module = {}

function Module.Init(Shared)
	local Abysall, Connections, Functions, GameData, Globals, Groupboxes, LatestRoom, LocalPlayer, Objects, Options, PartProperties, Services, Tabs, Toggles, Window
	   = Shared.Abysall, Shared.Connections, Shared.Functions, Shared.GameData, Shared.Globals, Shared.Groupboxes, Shared.LatestRoom, Shared.LocalPlayer, Shared.Objects, Shared.Options, Shared.PartProperties, Shared.Services, Shared.Tabs, Shared.Toggles, Shared.Window

	Tabs.General = Window:AddTab("General", "house", { Columns = 3 })

	-- right column: Bypass (moved from Exploits) sits ABOVE Misc / Debug; its contents are added by Module.Bypass
	Groupboxes.Exploits_BypassRight = Tabs.General:AddRightGroupbox("Bypass")

Groupboxes.General_Character = Tabs.General:AddLeftGroupbox("Character")
Groupboxes.General_Character:AddSlider("SpeedBoostSlider", {
	Text = "Speed Boost", Min = 0, Max = 100, Default = 0, Rounding = 0, Compact = true
})
Groupboxes.General_Character:AddToggle("SpeedBoostToggle", {
	Text = "Enable Speed Boost", Default = false, Tooltip = "Increases your walkspeed by the specified amount."
})
Groupboxes.General_Character:AddToggle("FlyToggle", {
	Text = "Fly", Default = false, Tooltip = "Allows you to freely fly around the map."
})
Toggles.FlyToggle:AddKeyPicker("FlyKeybind", {
	Text = "Fly", Default = "F", Mode = "Toggle", SyncToggleState = true
})
Groupboxes.General_Character:AddSlider("FlySpeed", {
	Text = "Fly Speed", Min = 0, Max = 115, Default = 20, Rounding = 0, Compact = true
})
Groupboxes.General_Character:AddDivider()
Groupboxes.General_Character:AddToggle("NoclipToggle", {
	Text = "Noclip", Default = false, Tooltip = "Allows your character to pass through solid objects."
})
Groupboxes.General_Character:AddToggle("RemoveClosetDelay", {
	Text = "Remove Closet Delay", Default = false,
	Tooltip = "Removes the short window where you can't exit out of a closet after the animation finishes."
})
Groupboxes.General_Character:AddToggle("RemoveAcceleration", {
	Text = "Remove Acceleration", Default = false, Tooltip = "Prevents your character from sliding while moving."
})


Options.SpeedBoostSlider:OnChanged(function(Value)
	if Shared.RemotesFolder:FindFirstChild("Crouch") then
		Shared.RemotesFolder.Crouch:FireServer(Value and true or Functions.IsCrouching(), true)
	end
end)

Toggles.NoclipToggle:AddKeyPicker("NoclipKeybind", {
	Text = "Noclip", Default = "N", Mode = "Toggle", SyncToggleState = true
})
Toggles.RemoveAcceleration:OnChanged(function(Value)
	for Index, Old in PartProperties do
		Index.CustomPhysicalProperties = Value and Shared.CustomPhysics or Old
	end
end)

Groupboxes.General_Character:AddDivider()
Groupboxes.General_Character:AddToggle("EnableCharacterJump", {
	Text = "Enable Jumping", Default = false, Tooltip = "Allows your character to jump."
})
Groupboxes.General_Character:AddToggle("EnableCharacterSlide", {
	Text = "Enable Sliding", Default = false, Tooltip = "Allows your character to slide."
})
Groupboxes.General_Character:AddToggle("InfiniteJumps", {
	Text = "Infinite Jumps", Default = false, Tooltip = "Allows you to jump while in the air."
})
Groupboxes.General_Character:AddDivider()
Groupboxes.General_Character:AddToggle("DisableAutoJump", {
	Text = "Disable AutoJump", Default = false, Tooltip = "Sets AutoJumpEnabled to false on your Humanoid."
})


Toggles.SpeedBoostToggle:OnChanged(function(Value)
	if Shared.Humanoid then
		Shared.Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + (Value and Options.SpeedBoostSlider.Value or 0)
	end
end)
Toggles.EnableCharacterJump:OnChanged(function(Value)
	if Shared.Character then
		Shared.Character:SetAttribute("CanJump", Value and true or Shared.OldJump)
	end
end)
Toggles.EnableCharacterSlide:OnChanged(function(Value)
	if Shared.Character then
		Shared.Character:SetAttribute("CanSlide", Value and true or Shared.OldSlide)
	end
end)

-- Disable AutoJump: sets AutoJumpEnabled = false on workspace.<LocalPlayer>.Humanoid while the toggle is on. It is kept off if the
-- game turns it back on, re-applied after a respawn, and the previous value is restored when the toggle is switched off.
local OldAutoJump = nil
local AutoJumpGuard
local function GetLocalHumanoid()
	local PlayerModel = Services.Workspace:FindFirstChild(LocalPlayer.Name)
	return (PlayerModel and PlayerModel:FindFirstChild("Humanoid")) or Shared.Humanoid
end
local function ApplyAutoJump()
	if AutoJumpGuard then
		AutoJumpGuard:Disconnect()
		AutoJumpGuard = nil
	end
	local Humanoid = GetLocalHumanoid()
	if not Humanoid then return end

	if Toggles.DisableAutoJump.Value then
		if OldAutoJump == nil then OldAutoJump = Humanoid.AutoJumpEnabled end
		Humanoid.AutoJumpEnabled = false
		AutoJumpGuard = Humanoid:GetPropertyChangedSignal("AutoJumpEnabled"):Connect(function()
			if Toggles.DisableAutoJump.Value and Humanoid.AutoJumpEnabled then
				Humanoid.AutoJumpEnabled = false
			end
		end)
	elseif OldAutoJump ~= nil then
		Humanoid.AutoJumpEnabled = OldAutoJump
		OldAutoJump = nil
	end
end
Toggles.DisableAutoJump:OnChanged(ApplyAutoJump)
local AutoJumpRespawn = LocalPlayer.CharacterAdded:Connect(function(NewCharacter)
	NewCharacter:WaitForChild("Humanoid", 10)
	if Toggles.DisableAutoJump.Value then ApplyAutoJump() end
end)
-- registered in Main's Connections so the unload code cleans it up (and puts AutoJumpEnabled back)
Connections.DisableAutoJump = {
	Disconnect = function()
		AutoJumpRespawn:Disconnect()
		if AutoJumpGuard then AutoJumpGuard:Disconnect() AutoJumpGuard = nil end
		local Humanoid = GetLocalHumanoid()
		if Humanoid and OldAutoJump ~= nil then Humanoid.AutoJumpEnabled = OldAutoJump end
	end
}

Groupboxes.General_Self = Tabs.General:AddLeftGroupbox("Self")
Groupboxes.General_Self:AddToggle("DoorReachToggle", {
	Text = "Door Reach", Default = false, Tooltip = "Allows you to open doors from further away."
})
Groupboxes.General_Self:AddToggle("DisableIdleKick", {
	Text = "Disable Idle Kick", Default = false, Tooltip = "Prevents the kick from being idle for 20 minutes."
})
Toggles.DisableIdleKick:OnChanged(function(Value)
	if Functions.CheckCompatability({"getconnections"}) then
		for _, Conn in Abysall.Environment.getconnections(LocalPlayer.Idled) do
			if Value then Conn:Disable() else Conn:Enable() end
		end
	end
end)
LocalPlayer.Idled:Connect(function()
	if Toggles.DisableIdleKick.Value then
		Services.VirtualUser:CaptureController()
		Services.VirtualUser:ClickButton2(Vector2.new())
	end
end)

Groupboxes.General_Self:AddDivider()
Groupboxes.General_Self:AddSlider("PromptReachSlider", {
	Text = "Prompt Reach Multiplier", Min = 1, Max = 2, Default = 1, Rounding = 1, Compact = true
})
Groupboxes.General_Self:AddToggle("InstantPrompts", {
	Text = "Instant Prompts", Default = false, Tooltip = "Allows you to trigger all prompts instantly."
})
Groupboxes.General_Self:AddToggle("PromptClip", {
	Text = "Prompt Clip", Default = false, Tooltip = "Allows you to interact with prompts through walls."
})

Options.PromptReachSlider:OnChanged(function(Value)
	for _, Prompt in Objects.Prompts do
		Prompt.MaxActivationDistance = Prompt:GetAttribute("MaxActivationDistance_Old") * Value
	end
end)
Toggles.InstantPrompts:OnChanged(function(Value)
	for _, Prompt in Objects.Prompts do
		Prompt.HoldDuration = Value and 0 or Prompt:GetAttribute("HoldDuration_Old")
	end
end)
Toggles.PromptClip:OnChanged(function(Value)
	for _, Prompt in Objects.Prompts do
		Prompt.RequiresLineOfSight = Value and false or Prompt:GetAttribute("RequiresLineOfSight_Old")
	end
end)

Groupboxes.MiscDebug = Tabs.General:AddRightTabbox("Misc / Debug")
Groupboxes.Self_Misc = Groupboxes.MiscDebug:AddTab("Misc")
Groupboxes.Self_Misc:AddButton({
	Text = "Play Again", Tooltip = "Makes you join a new run, click again to cancel.", DoubleClick = true,
	Func = function() Shared.RemotesFolder.PlayAgain:FireServer() end
})
Groupboxes.Self_Misc:AddButton({
	Text = "Return to Lobby", Tooltip = "Makes you teleport back to the lobby.", DoubleClick = true,
	Func = function() Shared.RemotesFolder.Lobby:FireServer() end
})
Groupboxes.Self_Misc:AddButton({
	Text = "Revive",
	Tooltip = "Makes you revive, if you have a revive and haven't already revived in this run.",
	DoubleClick = true,
	Func = function() Shared.RemotesFolder.Revive:FireServer() end
})
Groupboxes.Self_Misc:AddButton({
	Text = "Reset Character",
	Tooltip = "Kills your character on the server. (takes around 20 seconds if replicatesignal isn't supported)",
	DoubleClick = true,
	Func = function()
		Globals.SelfKilled = true
		if Functions.CheckCompatability({"replicatesignal"}) then
			Abysall.Environment.replicatesignal(LocalPlayer.Kill)
		else
			if Shared.RemotesFolder:FindFirstChild("Underwater") then
				Shared.RemotesFolder.Underwater:FireServer(true)
			else
				Shared.Humanoid.Health = 0
			end
		end
	end
})


Tabs.General:UpdateWarningBox({
	Visible = true,
	Title = "Risk Warning",
	Text = "Features highlighted in red are risky.",
})
Groupboxes.Debug = Groupboxes.MiscDebug:AddTab("Debug")
Groupboxes.Debug:AddButton({
	Text = "Ladder Softlock Fix",
	Tooltip = "Ladder Softlock Fix.",
	Func = function()
   		LocalPlayer:SetAttribute("Climbing", false)
	end
})
Groupboxes.Debug:AddButton({
	Text = "Get Current Floor",
	Tooltip = "Prints the current floor to the console.",
	Func = function()
		print("Current Floor:", GameData:WaitForChild("Floor").Value)
	end
})
Groupboxes.Debug:AddButton({
	Text = "Get Current Room",
	Tooltip = "Prints the current room number to the console.",
	Func = function()
		print("Current Room:", LocalPlayer:GetAttribute("CurrentRoom"))
	end
})
Groupboxes.Debug:AddButton({
	Text = "Void",
	Tooltip = "Teleports your character to Y -120.",
	Func = function()
		if not Shared.Character then return end
		local Pivot = Shared.Character:GetPivot()
		-- Too lazy to loop this
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
		Shared.Character:PivotTo(Pivot + Vector3.new(0, -120 - Pivot.Position.Y, 0))
	end
})
Groupboxes.Debug:AddButton({
	Text = "Death",
	Tooltip = "Death",
	Func = function()
		Globals.Deathing = true
		LocalPlayer.Character.Humanoid.Health = 0
	end
})
Groupboxes.Debug:AddButton({
	Text = "Exit Closet",
	Tooltip = "Exits the current closet.",
	Func = function()
		if Shared.RemotesFolder and Shared.RemotesFolder:FindFirstChild("CamLock") then
			Shared.RemotesFolder.CamLock:FireServer()
		end
	end
})
local TpNextDoorConnection

local function getNextClosedDoor()
	if not Shared.Character then return nil end

	local GameData = game:GetService("ReplicatedStorage"):FindFirstChild("GameData")
	if not GameData then return nil end

	local LatestRoom = GameData:FindFirstChild("LatestRoom")
	if not LatestRoom then return nil end

	local startRoom = LatestRoom.Value
	local bestDoor = nil
	local bestNumber = math.huge

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "Door" and obj:IsA("Model") then
			local openAttr = obj:GetAttribute("Open")
			if openAttr == false or openAttr == nil then
				local roomModel = obj.Parent
				local roomNum = tonumber(roomModel and roomModel.Name)

				if roomNum and roomNum >= startRoom and roomNum < bestNumber then
					bestNumber = roomNum
					bestDoor = obj
				end
			end
		end
	end

	return bestDoor
end

Groupboxes.Debug:AddButton({
	Text = "Tp Next Door",
	Tooltip = "Teleports you to the next sequential unopened door.",
	Func = function()
		local door = getNextClosedDoor()
		if door then
			Shared.Character:PivotTo(door:GetPivot() * CFrame.new(0, -1, 0))
		end
	end
})

Toggles.TpNextDoor = Groupboxes.Debug:AddToggle("TpNextDoor", {
	Text = "Auto Tp Next Door",
	Tooltip = "Continuously teleports you to the next sequential unopened door.",
	Default = false
})

Toggles.TpNextDoor:OnChanged(function(TpNextDoorEnabled)
	if TpNextDoorConnection then
		task.cancel(TpNextDoorConnection)
		TpNextDoorConnection = nil
	end

	if not TpNextDoorEnabled then
		return
	end

	TpNextDoorConnection = task.spawn(function()
		while Toggles.TpNextDoor.Value do
			local door = getNextClosedDoor()
			if door and Shared.Character then
				Shared.Character:PivotTo(door:GetPivot() * CFrame.new(0, -1, 0))
			end
			task.wait(0.15)
		end
		TpNextDoorConnection = nil
	end)
end)
end

-- Bypass (right column, above Misc / Debug).  Moved here from the Exploits tab; Main.luau calls Module.Bypass(Shared) at
-- the position where this code used to live.
function Module.Bypass(Shared)
	local Functions, Globals, Groupboxes, Library, RunService, Toggles
	   = Shared.Functions, Shared.Globals, Shared.Groupboxes, Shared.Library, Shared.RunService, Shared.Toggles

Groupboxes.Exploits_BypassRight:AddToggle("DisableAnticheat", {
	Text = "Anticheat Bypass", Default = false,
	Tooltip = "Completely disables the anticheat, after interacting with a ladder."
})
Groupboxes.Exploits_BypassRight:AddToggle("VelocityManipulationToggle", {
	Text = "Velocity Manipulation", Default = false,
	Tooltip = "Moves your character forward slowly, mitigating the game's anti-noclip."
})
Toggles.DisableAnticheat:OnChanged(function(Value)
	if Globals.AnticheatDisabled == true and not Value then
		Shared.RemotesFolder.ClimbLadder:FireServer()
		Globals.AnticheatDisabled = false
	end
end)
Toggles.VelocityManipulationToggle:AddKeyPicker("VelocityManipulationKeybind", {
	Text = "Velocity Manipulation", Default = "V",
	Mode = Library.IsMobile and "Toggle" or "Hold", SyncToggleState = true
})
Groupboxes.Exploits_BypassRight:AddDropdown("VelocityManipulationMode", {
	Values = {"Velocity", "Pivot"}, Text = "Manipulation Method",
	Default = 1,
})

Groupboxes.Exploits_BypassRight:AddDivider()
Groupboxes.Exploits_BypassRight:AddToggle("InfiniteItemsToggle", {
	Text = "Infinite Items", Default = false,
	Tooltip = "Allows certain items to be used without draining their uses.",
	Disabled = not Functions.CheckCompatability({"fireproximityprompt"}),
	DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Exploits_BypassRight:AddDropdown("InfiniteItemsList", {
	Text = "Item List",
	Values = { "Lockpicks", "Skeleton Key", "Shears", "Multitool" },
	Multi = true, AllowNull = true,
	Disabled = not Functions.CheckCompatability({"fireproximityprompt"}),
	DisabledTooltip = Globals.IncompatibleMessage
})

Groupboxes.Exploits_BypassRight:AddToggle("InfCrucifix", {
	Text = "Infinite Crucifix",
	Default = false,
	Tooltip = "Risky! You can die or lose the Crucifix. Recommended to have low ping and stable fps.",
	Risky = Shared.Floor ~= "Ballz",
})


local InfCrucifixDropTable = {
	RushMoving   = 54,
	AmbushMoving = 67,
	A60          = 70,
	GlitchRush   = 120,
	GlitchAmbush = 155,
	A120         = 75,

}



Toggles.InfCrucifix:OnChanged(function(Value)
	print("i allive")
	local InfCrucifixRaycastParams = RaycastParams.new()
	InfCrucifixRaycastParams.FilterType = Enum.RaycastFilterType.Blacklist

	local InfCrucifixConnection
	InfCrucifixConnection = RunService.RenderStepped:Connect(function()
		if not Toggles.InfCrucifix.Value then
			if InfCrucifixConnection then
				InfCrucifixConnection:Disconnect()
			end
			return
		end

		local InfCrucifixCharacter = game.Players.LocalPlayer
		if not InfCrucifixCharacter then
			return
		end

		local InfCrucifixCollision = InfCrucifixCharacter:FindFirstChild("CollisionPart")
		if not InfCrucifixCollision then
			return
		end

		InfCrucifixRaycastParams.FilterDescendantsInstances = {InfCrucifixCharacter}

		for _, InfCrucifixEntity in ipairs(Workspace:GetChildren()) do
			local InfCrucifixMaxDistance = InfCrucifixDropTable[InfCrucifixEntity.Name]
			if not InfCrucifixMaxDistance or not InfCrucifixEntity.PrimaryPart then
				continue
			end

			InfCrucifixEntity.PrimaryPart.CanCollide = true
			InfCrucifixEntity.PrimaryPart.CanQuery = true

			local InfCrucifixOrigin = InfCrucifixCollision.Position
			local InfCrucifixDirection = InfCrucifixEntity.PrimaryPart.Position - InfCrucifixOrigin
			local InfCrucifixRayResult = Workspace:Raycast(InfCrucifixOrigin, InfCrucifixDirection, InfCrucifixRaycastParams)

			if not InfCrucifixRayResult or not InfCrucifixRayResult.Instance:IsDescendantOf(InfCrucifixEntity) then
				continue
			end

			local InfCrucifixDistance = (InfCrucifixCollision.Position - InfCrucifixEntity.PrimaryPart.Position).Magnitude
			if InfCrucifixDistance >= InfCrucifixMaxDistance then
				continue
			end

			local InfCrucifixTool = InfCrucifixCharacter:FindFirstChildOfClass("Tool")
			if not InfCrucifixTool or InfCrucifixTool.Name ~= "Crucifix" then
				continue
			end

			task.spawn(function()
				ReplicatedStorage.RemotesFolder.DropItem:FireServer(InfCrucifixTool)
				task.wait(0.54)
				print("hi")
				local InfCrucifixDrops = Workspace:FindFirstChild("Drops")
				if not InfCrucifixDrops then
					return
				end

				local InfCrucifixDropped = InfCrucifixDrops:FindFirstChild("Crucifix")
				if not InfCrucifixDropped then
					return
				end

				local InfCrucifixPrompt = InfCrucifixDropped:FindFirstChildOfClass("ProximityPrompt")
				if InfCrucifixPrompt then
					fireproximityprompt(InfCrucifixPrompt)
				end
			end)
			print ("hi")
			task.wait(0.6)
		end
	end)
end)


Groupboxes.Exploits_BypassRight:AddDivider()
Groupboxes.Exploits_BypassRight:AddToggle("PositionSpoof", {
	Text = "Position Spoof", Default = false,
	Tooltip = "Makes your character appear underground on the server, protecting you from rush-like entities."
})
Groupboxes.Exploits_BypassRight:AddToggle("CrouchSpoof", {
	Text = "Crouch Spoof", Default = false, Tooltip = "Makes the game think you are always crouching."
})
Toggles.PositionSpoof:OnChanged(function(Value)
	if Shared.Floor ~= "Fools" and Shared.Floor ~= "OldHotel" then
		if Value then
			Shared.RootPart.CFrame = Shared.RootPart.CFrame * CFrame.new(0, -2.346, 0)
			Shared.Humanoid.HipHeight = 0.05
			Shared.RemotesFolder.Crouch:FireServer(true, true)
		else
			Shared.RootPart.CFrame = Shared.RootPart.CFrame * CFrame.new(0, 2.346, 0)
			Shared.Humanoid.HipHeight = 2.396
		end
	end
end)
Toggles.PositionSpoof:AddKeyPicker("PositionSpoof", {
	Text = "Position Spoof", Default = "B", Mode = "Toggle", SyncToggleState = true
})
Toggles.CrouchSpoof:OnChanged(function(Value)
	if Shared.RemotesFolder:FindFirstChild("Crouch") then
		Shared.RemotesFolder.Crouch:FireServer(Value and true or Functions.IsCrouching(), true)
	end
end)
end

-- Audio + Camera / Effects (centre column, one multisection with three pages).  Camera / Effects came from the Visuals tab,
-- Audio from the Exploits tab.  Main.luau calls Module.Late(Shared) where this code used to live, because it needs locals
-- that are declared further down in Main.luau.
function Module.Late(Shared)
	local Connections, CurrentRooms, CutsceneNames, FloorReplicated, Functions, Globals, Groupboxes, LocalPlayer, Objects, Options, Services, Tabs, Toggles
	   = Shared.Connections, Shared.CurrentRooms, Shared.CutsceneNames, Shared.FloorReplicated, Shared.Functions, Shared.Globals, Shared.Groupboxes, Shared.LocalPlayer, Shared.Objects, Shared.Options, Shared.Services, Shared.Tabs, Shared.Toggles

	Groupboxes.Visuals_LeftTab = Tabs.General:AddMiddleTabbox("Camera / Effects / Audio")
	Groupboxes.Visuals_Camera = Groupboxes.Visuals_LeftTab:AddTab("Camera")
	Groupboxes.Visuals_Effects = Groupboxes.Visuals_LeftTab:AddTab("Effects")
	Groupboxes.Exploits_Audio = Groupboxes.Visuals_LeftTab:AddTab("Audio")

Globals.JamMuffle = Services.SoundService:WaitForChild("Main"):FindFirstChild("Jamming") or Instance.new("EqualizerSoundEffect")

Groupboxes.Exploits_Audio:AddToggle("RemoveFootstepSounds",    { Text = "Remove Footstep Sounds",    Default = false, Tooltip = "Removes the sounds when walking." })
Groupboxes.Exploits_Audio:AddToggle("RemoveJamminMusic",       { Text = "Remove Jammin Music",       Default = false, Tooltip = "Removes the music and muffle effect from the 'Jammin' modifier." })
Groupboxes.Exploits_Audio:AddToggle("RemoveInteractingSounds", { Text = "Remove Interacting Sounds", Default = false, Tooltip = "Removes the sounds when interacting with proximity prompts." })

Toggles.RemoveJamminMusic:OnChanged(function(Value)
	local Jam = Globals.MainUI.Initiator.Main_Game.Health:FindFirstChild("Jam")
	if Jam then
		Jam.Volume = Value and 0 or 0.45
		Globals.JamMuffle.Enabled = Shared.LiveModifiers:FindFirstChild("Jammin") and not Value or false
	end
end)
Toggles.RemoveInteractingSounds:OnChanged(function(Value)
	local PS = Globals.MainUI.Initiator.Main_Game.PromptService
	PS.Triggered.Volume   = Value and 0 or 0.04
	PS.Holding.Volume     = Value and 0 or 0.1
	PS.Notification.Volume = Value and 0 or 0.03
	Globals.MainUI.Initiator.Main_Game.Reminder.Caption.Volume = Value and 0 or 0.1
end)

Groupboxes.Visuals_Camera:AddToggle("AmbientToggle", { Text = "Ambient", Default = false, Tooltip = "Changes the lighting color to the specified value." })
Groupboxes.Visuals_Camera:AddSlider("FieldOfView", { Text = "Field of View", Min = 1, Max = 120, Default = 70, Rounding = 0 })
Groupboxes.Visuals_Camera:AddToggle("FOVToggle", {    Text = "Custom FOV",    Default = false,    Tooltip = "Only applies the Field of View slider when enabled." })
Toggles.FOVToggle:AddKeyPicker("FovToggle", {Text = "Custom Fov", Default = "O", Mode = "Toggle", SyncToggleState = true})
Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("RemoveCameraShake", {
	Text = "Remove Camera Shake", Default = false, Tooltip = "Prevents the camera from shaking.",
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visuals_Camera:AddToggle("RemoveCameraBobbing", {
	Text = "Remove Camera Bobbing", Default = false, Tooltip = "Prevents the camera from bobbing when moving.",
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visuals_Camera:AddToggle("RemoveCutscenes", { Text = "Remove Cutscenes", Default = false, Tooltip = "Removes all non-necessary cutscenes." })
Groupboxes.Visuals_Camera:AddToggle("RemoveCameraFog", { Text = "Remove Fog", Default = false, Tooltip = "Removes all fog effects from the camera." })
Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("ThirdPersonToggle", { Text = "Third Person", Default = false, Tooltip = "Zooms out your camera, allowing you to see your character from behind." })
Toggles.ThirdPersonToggle:AddKeyPicker("ThirdPersonKeybind", { Text = "Third Person", Default = "T", Mode = "Toggle", SyncToggleState = true })
Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetX", { Text = "X Offset", Min = -10, Max = 10, Default = 1.5, Rounding = 1, Compact = true })
Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetY", { Text = "Y Offset", Min = -10, Max = 10, Default = 1,   Rounding = 1, Compact = true })
Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetZ", { Text = "Z Offset", Min = -10, Max = 10, Default = 5,   Rounding = 1, Compact = true })
Groupboxes.Visuals_Camera:AddToggle("ThirdPersonWallCheck", { Text = "Wall Check", Default = false, Tooltip = "Prevents third person from going through walls." })
Groupboxes.Visuals_Camera:AddDivider()
Groupboxes.Visuals_Camera:AddToggle("ViewmodelOffsetToggle", {
	Text = "Viewmodel Offset", Default = false, Tooltip = "Changes the offset of your viewmodel while holding an item.",
	Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage
})
Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetX", { Text = "X Offset", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage })
Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetY", { Text = "Y Offset", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage })
Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetZ", { Text = "Z Offset", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, Disabled = not Functions.CheckCompatability({"require"}), DisabledTooltip = Globals.IncompatibleMessage })

Toggles.AmbientToggle:AddColorPicker("AmbientColor", { Text = "Ambient", Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
Toggles.AmbientToggle:OnChanged(function(Value)
	local OldAmbient = CurrentRooms:FindFirstChild(tostring(LocalPlayer:GetAttribute("CurrentRoom"))):GetAttribute("Ambient")
	Services.TweenService:Create(Services.Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
		Ambient = Value and Options.AmbientColor.Value or OldAmbient
	}):Play()
end)


Toggles.RemoveCameraBobbing:OnChanged(function(Value)
	if Shared.Main_Game then Shared.Main_Game.spring.Speed = Value and 9e9 or 8 end
end)
Toggles.RemoveCameraFog:OnChanged(function(Value)
	Services.Lighting.FogEnd = Value and 10000000 or Globals.OldFog
	for _, Object in Globals.FogInstances do
		Object.Density = Value and 0 or Object:GetAttribute("Density_Old")
	end
end)
Toggles.RemoveCutscenes:OnChanged(function(Value)
    local Cutscenes = Globals.MainUI.Initiator.Main_Game.RemoteListener.Cutscenes
    for _, Object in pairs(Cutscenes:GetChildren()) do
        if table.find(CutsceneNames, Object.Name) and Object:IsA("ModuleScript") or table.find(CutsceneNames, Object:GetAttribute("OriginalName")) and Object:IsA("ModuleScript") then
            Object.Name = (Value and Object.Name .. "_Disabled" or Object:GetAttribute("OriginalName"))
        end
    end
    for _, Object in pairs(FloorReplicated:GetChildren()) do
        if table.find(CutsceneNames, Object.Name) and Object:IsA("ModuleScript") or table.find(CutsceneNames, Object:GetAttribute("OriginalName")) and Object:IsA("ModuleScript") then
            Object.Name = (Value and Object.Name .. "_Disabled" or Object:GetAttribute("OriginalName"))
        end
    end
end)

Groupboxes.Visuals_Effects:AddToggle("TransparentHidingSpotsToggle", { Text = "Transparent Hiding Spots", Default = false, Tooltip = "Makes a hiding spot transparent when you enter it." })
Groupboxes.Visuals_Effects:AddSlider("TransparentHidingSpotsSlider", { Text = "Transparency", Min = 0, Max = 1, Default = 0.5, Rounding = 2, Compact = true })

local function ApplyHidingTransparency(Value, SliderValue)
	for _, Object in Objects.HidingSpots do
		local IsHiding = false
		for _, Child in Object:GetDescendants() do
			if Child.Name == "HiddenPlayer" and Child.Value == Shared.Character then
				IsHiding = true
				break
			end
		end
		for _, Part in Object:GetDescendants() do
			if Part:IsA("BasePart") and Part:GetAttribute("Transparency_Old") then
				Services.TweenService:Create(Part, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
					Transparency = (Value and IsHiding) and SliderValue or Part:GetAttribute("Transparency_Old")
				}):Play()
			end
		end
	end
end

Toggles.TransparentHidingSpotsToggle:OnChanged(function(Value)
	ApplyHidingTransparency(Value, Options.TransparentHidingSpotsSlider.Value)
end)
Options.TransparentHidingSpotsSlider:OnChanged(function(Value)
	ApplyHidingTransparency(Toggles.TransparentHidingSpotsToggle.Value, Value)
end)

Groupboxes.Visuals_Effects:AddDivider()
Groupboxes.Visuals_Effects:AddToggle("DisableGlitchJumpscare",   { Text = "Disable Glitch Jumpscare",   Default = false, Tooltip = "Disables the jumpscare from 'Glitch'" })
Groupboxes.Visuals_Effects:AddToggle("DisableTimothyJumpscare",  { Text = "Disable Timothy Jumpscare",  Default = false, Tooltip = "Disables the jumpscare from 'Timothy'" })
Groupboxes.Visuals_Effects:AddToggle("DisableVoidJumpscare",     { Text = "Disable Void Jumpscare",     Default = false, Tooltip = "Disables the jumpscare from 'Void'" })
Groupboxes.Visuals_Effects:AddDivider()
Groupboxes.Visuals_Effects:AddToggle("DisableHideVignette",      { Text = "Disable Hide Vignette",      Default = false, Tooltip = "Disables the hiding screen effect." })
Groupboxes.Visuals_Effects:AddToggle("DisableFiredampEffect",    { Text = "Disable Firedamp Effect",    Default = false, Tooltip = "Disables the firedamp screen effect." })
Groupboxes.Visuals_Effects:AddToggle("DisableEntityJumpscares",  { Text = "Disable Entity Jumpscares",  Default = false, Tooltip = "Disables jumpscares from entities like Rush and Ambush." })
Groupboxes.Visuals_Effects:AddToggle("DisableStarlightEffect",   { Text = "Disable Starlight Effect",   Default = false, Tooltip = "Removes the Starlight colour effect." })
Groupboxes.Visuals_Effects:AddToggle("DisableGweenSodaEffect",   { Text = "Disable Gween Soda Effect",  Default = false, Tooltip = "Removes the Gween Soda colour effect." })

Toggles.DisableGlitchJumpscare:OnChanged(function(Value)
	Shared.Modules.Glitch.Name = Value and "Glitch_Disabled" or "Glitch"
end)
Toggles.DisableTimothyJumpscare:OnChanged(function(Value)
	Shared.Modules.SpiderJumpscare.Name = Value and "SpiderJumpscare_Disabled" or "SpiderJumpscare"
end)
Toggles.DisableVoidJumpscare:OnChanged(function(Value)
	if Shared.Modules.Void then Shared.Modules.Void.Name = Value and "Void_Disabled" or "Void" end
end)
Toggles.DisableHideVignette:OnChanged(function(Value)
	local Vignette = Globals.MainUI:FindFirstChild("HideVignette") or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
	if Vignette then Vignette.Image = Value and "Disabled" or "rbxassetid://6100076320" end
end)
Toggles.DisableFiredampEffect:OnChanged(function(Value)
	for _, Object in CurrentRooms:GetChildren() do
		if Value then
			Object:SetAttribute("Firedamp", false)
			for _, FiredampObj in Shared.Camera:GetChildren() do
				if FiredampObj.Name == "LiveFiredamp" then FiredampObj:Destroy() end
			end
		else
			Object:SetAttribute("Firedamp", Object:GetAttribute("Firedamp_Old"))
		end
	end
	local Old = LocalPlayer:GetAttribute("CurrentRoom")
	LocalPlayer:SetAttribute("CurrentRoom", 0)
	task.wait()
	LocalPlayer:SetAttribute("CurrentRoom", Old)
end)
Toggles.DisableEntityJumpscares:OnChanged(function(Value)
	local Jumpscares = Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares")
		or Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares_Disabled")
	if Jumpscares then
		Jumpscares.Name = Value and "Jumpscares_Disabled" or "Jumpscares"
		for _, Object in Objects.JumpscareModules do
			Object.Name = Value and (Object:GetAttribute("OriginalName") .. "_Disabled") or Object:GetAttribute("OriginalName")
		end
	end
end)

	-- Disable Starlight Effect / Disable Gween Soda Effect (new).
	-- Both effects are ColorCorrectionEffects that the game puts into workspace.Camera. Handles effects that already exist
	-- when the toggle is switched on, ones that appear later during the game, and several copies of the same effect.
	local function CreateEffectBlocker(ToggleName, EffectName)
		local Active = {}
		local CameraSignal

		local function StopWatching()
			for _, Connection in Active do Connection:Disconnect() end
			table.clear(Active)
		end

		local function IsTarget(Object)
			if not Object:IsA("ColorCorrectionEffect") then return false end
			if Object.Name == EffectName then return true end
			return Object.Parent ~= nil and Object.Parent.Name == EffectName
		end

		local function Remove(Object)
			if Toggles[ToggleName].Value and IsTarget(Object) then
				pcall(function() Object:Destroy() end)
			end
		end

		local function Watch(Camera)
			StopWatching()
			if not Camera then return end
			table.insert(Active, Camera.DescendantAdded:Connect(function(Object)
				Remove(Object)
				-- if the game names the effect after parenting it, check again when the name changes
				if Object:IsA("ColorCorrectionEffect") then
					Object:GetPropertyChangedSignal("Name"):Once(function() Remove(Object) end)
				end
			end))
			for _, Object in Camera:GetDescendants() do Remove(Object) end
		end

		Toggles[ToggleName]:OnChanged(function(Value)
			if Value then Watch(workspace.CurrentCamera) else StopWatching() end
		end)

		-- the camera object can be replaced (respawn, cutscenes): hook the new one while the toggle is on
		CameraSignal = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			if Toggles[ToggleName].Value then Watch(workspace.CurrentCamera) end
		end)

		-- registered in Main's Connections so the unload code cleans it up
		Connections[ToggleName] = {
			Disconnect = function()
				StopWatching()
				if CameraSignal then CameraSignal:Disconnect() end
			end
		}
	end

	CreateEffectBlocker("DisableStarlightEffect", "yea")
	CreateEffectBlocker("DisableGweenSodaEffect", "Im green... No... NOOO!!!!")
end

-- Farming (centre column, below Camera / Effects / Audio).  Moved here from the Floors tab; Main.luau calls
-- Module.Farming(Shared) at the position where this code used to live.
function Module.Farming(Shared)
	local Abysall, Connections, Functions, Globals, Groupboxes, LatestRoom, Library, LocalPlayer, Services, Tabs, Toggles
	   = Shared.Abysall, Shared.Connections, Shared.Functions, Shared.Globals, Shared.Groupboxes, Shared.LatestRoom, Shared.Library, Shared.LocalPlayer, Shared.Services, Shared.Tabs, Shared.Toggles

	Groupboxes.Floors_Farming = Tabs.General:AddMiddleGroupbox("Farming")
Groupboxes.Floors_Farming:AddToggle("KnobFarm", {
    Text = "Knob Farm",
    Default = false,
    Tooltip = "Automatically gains knobs for you, dies and revives repeatedly.",
	Risky = Shared.Floor ~= "Ballz",
})

Groupboxes.Floors_Farming:AddButton({
    Text = "Start Knob Farm",
    Tooltip = "Starts farming knobs, click this when you have enough gold.",
    Func = function()
		if LatestRoom.Value ~= 0 then
			Functions.Notify({Title = "You must be in Room 0 to use this."})
			return
		end

		if LocalPlayer.PlayerGui:FindFirstChild("TopbarUI") then 
			local GoldCount = LocalPlayer.PlayerGui.TopbarUI.Topbar.StatsTopbarHandler.StatModules.Gold.GoldVal
			if GoldCount.Value <= 0 then
				Functions.Notify({Title = "You must have gold to do this."})
				return
			end
		end

        Globals.KnobFarmStarted = true
    end
})

Groupboxes.Floors_Farming:AddDivider()
Groupboxes.Floors_Farming:AddButton({
	Text = "Start Death Farm",
	DoubleClick = true,
	Tooltip = "Automatically farms deaths, joining new runs.",
	Func = function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/bocaj111004/Abysall/refs/heads/main/Scripts/DeathFarm.luau"))()
	end,

	Disabled = not Functions.CheckCompatability({"fireproximityprompt", "firesignal"}),
	DisabledTooltip = Globals.ImcompatibleMessage
})
Groupboxes.Floors_Farming:AddButton({
	Text = "Copy Death Farm Loadstring",
	DoubleClick = false,
	Tooltip = "Copies the death farm loadstring to your clipboard.",
	Func = function()
		toclipboard([==[
			loadstring(game:HttpGet("https://raw.githubusercontent.com/bocaj111004/Abysall/refs/heads/main/Scripts/DeathFarm.luau"))()
		]==])
		Library:Notify("Loadstring has been copied to your clipboard.")
	end,

	Disabled = not Functions.CheckCompatability({"fireproximityprompt", "firesignal"}),
	DisabledTooltip = Globals.ImcompatibleMessage
})

Toggles.KnobFarm:OnChanged(function(Value)
    if Value then
        Functions.Notify({Title = "Please collect some gold to earn knobs.", Body = "Click 'Start Knob Farm' when you're ready."})
	else
		Globals.KnobFarmStarted = false
    end
end)

Globals.KnobFarmActive = false
Globals.KnobFarmStarted = false
Connections.KnobFarm = Services.RunService.Heartbeat:Connect(function()
	if Toggles.KnobFarm.Value and Globals.KnobFarmStarted then
		if not Globals.KnobFarmActive then
			Globals.KnobFarmActive = true
			if Functions.CheckCompatability({"replicatesignal"}) then
				Abysall.Environment.replicatesignal(LocalPlayer.Kill)
			else
				LocalPlayer.Character.Humanoid.Health = 0
			end
			while task.wait() do
				if LocalPlayer:GetAttribute("Alive") then
					break
				end
			end
			Shared.RemotesFolder.Statistics:FireServer()
			task.wait(0.25)
			Globals.KnobFarmActive = false
		end
	end
end)
end

return Module
