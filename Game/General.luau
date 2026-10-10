return function(Shared)
	local Abysall, Functions, GameData, Globals, Groupboxes, LatestRoom, LocalPlayer, Objects, Options, PartProperties, Services, Tabs, Toggles, Window
	   = Shared.Abysall, Shared.Functions, Shared.GameData, Shared.Globals, Shared.Groupboxes, Shared.LatestRoom, Shared.LocalPlayer, Shared.Objects, Shared.Options, Shared.PartProperties, Shared.Services, Shared.Tabs, Shared.Toggles, Shared.Window

	Tabs.General = Window:AddTab("General", "house")

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

Groupboxes.Self_Misc = Tabs.General:AddRightGroupbox("Miscellaneous")
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
Groupboxes.Debug = Tabs.General:AddRightGroupbox("Debug")
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
