--[[
	Backdoors  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local Module = Abysall.LoadModule("Backdoors");  Module.Init(Shared)

	Column 1:  Automation   - Auto Interact / Auto Loot with a LIST of what to use / pick up (whitelist, unlike the old
	                          global Auto Interact which only has an ignore list).
	Column 2:  ESP | Notifications | Settings multisection
	Column 3:  Anti         - Anti Lookman, Anti Vacuum (moved 1:1 out of Main.luau).

	Prompt / object paths this module understands (rooms are NOT hard-coded, only names and structure):
	  Drawer       ...Backdoor_Table.DrawerContainer.Knob.ActivateEventPrompt
	  Door         ...Door.Lock.UnlockPrompt          and      ...Backdoors_Exit.Door.EnterPrompt
	  Timer Lever  ...TimerLever.ActivateEventPrompt
	  Key          ...KeyObtain.ModulePrompt          (in the open, or inside a DrawerContainer)
	  Star Vial    ...StarVial.ModulePrompt           (workspace.Drops or inside a DrawerContainer)
	  Star Bottle  ...StarBottle.ModulePrompt         (workspace.Drops or a room)
	  Closet       ...Backdoor_Wardrobe               (ESP only)
]]

local Module = {}

function Module.Init(Shared)
	local Connections, CurrentRooms, Entities, EntityIcons, Functions, Groupboxes, LocalPlayer, Options, Services, Tabs, Toggles, Window
	   = Shared.Connections, Shared.CurrentRooms, Shared.Entities, Shared.EntityIcons, Shared.Functions, Shared.Groupboxes, Shared.LocalPlayer, Shared.Options, Shared.Services, Shared.Tabs, Shared.Toggles, Shared.Window

	Tabs.Backdoors = Window:AddTab("Backdoors", "backdoors", { Columns = 3 })

	----------------------------------------------------------------------------------------------------
	-- UI
	----------------------------------------------------------------------------------------------------
	-- column 1: Automation
	Groupboxes.Backdoors_Automation = Tabs.Backdoors:AddLeftGroupbox("Automation")
	Groupboxes.Backdoors_Automation:AddToggle("BackdoorsAutoInteractToggle", {
		Text = "Auto Interact", Default = false, Tooltip = "Automatically interacts with the selected objects when you are close to them."
	})
	Groupboxes.Backdoors_Automation:AddDropdown("BackdoorsAutoInteractList", {
		Text = "Auto Interact List", Values = { "Drawer", "Door", "Timer Lever" }, Multi = true, AllowNull = true
	})
	Groupboxes.Backdoors_Automation:AddDivider()
	Groupboxes.Backdoors_Automation:AddToggle("BackdoorsAutoLootToggle", {
		Text = "Auto Loot", Default = false, Tooltip = "Automatically picks up the selected items when you are close to them."
	})
	Groupboxes.Backdoors_Automation:AddDropdown("BackdoorsAutoLootList", {
		Text = "Auto Loot List", Values = { "Key", "Star Vial", "Star Bottle" }, Multi = true, AllowNull = true
	})

	-- column 2: ESP | Notifications | Settings
	Groupboxes.Backdoors_Tabbox = Tabs.Backdoors:AddMiddleTabbox("ESP / Notifications / Settings")
	Groupboxes.Backdoors_ESP = Groupboxes.Backdoors_Tabbox:AddTab("ESP")
	Groupboxes.Backdoors_Notifications = Groupboxes.Backdoors_Tabbox:AddTab("Notifications")
	Groupboxes.Backdoors_Settings = Groupboxes.Backdoors_Tabbox:AddTab("Settings")

	Groupboxes.Backdoors_ESP:AddToggle("BackdoorsEntityESPToggle", {
		Text = "Entity ESP", Default = false, Tooltip = "Highlights the selected entities."
	})
	Groupboxes.Backdoors_ESP:AddDropdown("BackdoorsEntityESPList", {
		Text = "Entities", Values = { "Blitz", "Lookman" }, Multi = true, AllowNull = true
	})
	Groupboxes.Backdoors_ESP:AddDivider()
	Groupboxes.Backdoors_ESP:AddToggle("BackdoorsInteractableESPToggle", {
		Text = "Interactables ESP", Default = false, Tooltip = "Highlights the selected interactable objects (current room)."
	})
	Groupboxes.Backdoors_ESP:AddDropdown("BackdoorsInteractableESPList", {
		Text = "Interactables", Values = { "Drawer", "Door", "Timer Lever", "Closet" }, Multi = true, AllowNull = true
	})
	Groupboxes.Backdoors_ESP:AddDivider()
	Groupboxes.Backdoors_ESP:AddToggle("BackdoorsItemESPToggle", {
		Text = "Items ESP", Default = false, Tooltip = "Highlights the selected items (current room and dropped items)."
	})
	Groupboxes.Backdoors_ESP:AddDropdown("BackdoorsItemESPList", {
		Text = "Items", Values = { "Key", "Star Vial", "Star Bottle" }, Multi = true, AllowNull = true
	})

	Groupboxes.Backdoors_Notifications:AddToggle("BackdoorsNotifyEntitiesToggle", {
		Text = "Notify Entities", Default = false, Tooltip = "Shows a notification when the selected entities spawn."
	})
	Groupboxes.Backdoors_Notifications:AddDropdown("BackdoorsNotifyEntitiesList", {
		Text = "Entities", Values = { "Blitz", "Lookman" }, Multi = true, AllowNull = true
	})

	Groupboxes.Backdoors_Settings:AddLabel("Entity ESP Color"):AddColorPicker("BackdoorsEntityESPColor", { Default = Color3.fromRGB(255, 70, 70) })
	Groupboxes.Backdoors_Settings:AddLabel("Interactables ESP Color"):AddColorPicker("BackdoorsInteractableESPColor", { Default = Color3.fromRGB(80, 170, 255) })
	Groupboxes.Backdoors_Settings:AddLabel("Items ESP Color"):AddColorPicker("BackdoorsItemESPColor", { Default = Color3.fromRGB(255, 210, 60) })

	-- column 3: Anti (moved 1:1 out of Main.luau)
	Groupboxes.Backdoors_Anti = Tabs.Backdoors:AddRightGroupbox("Anti")
	Groupboxes.Backdoors_Anti:AddToggle("BypassLookman",        { Text = "Anti Lookman",          Default = false, Tooltip = "Prevents 'Lookman' from hurting you." })
	Groupboxes.Backdoors_Anti:AddToggle("BypassVacuum",         { Text = "Anti Vacuum",           Default = false, Tooltip = "Prevents you from falling into 'Vacuum' fake doors." })

	----------------------------------------------------------------------------------------------------
	-- Object tracking (prompts + closets)
	----------------------------------------------------------------------------------------------------
	local InteractableCategories = { Drawer = true, Door = true, ["Timer Lever"] = true, Closet = true }

	-- Tracked[Source] = { Category, Target (what gets the ESP), Label, Prompt, Shown, LastFire }
	local Tracked = {}

	local function HasBackdoorKey()
		return (Functions.HasItem("KeyBackdoor") or Functions.HasItem("Key")) and true or false
	end

	-- returns Category, ESP target, ESP label   (nil if the object is not one of ours)
	local function Classify(Object)
		if Object:IsA("ProximityPrompt") then
			local Parent = Object.Parent
			if not Parent then return end
			local Name, ParentName = Object.Name, Parent.Name
			local GrandParent = Parent.Parent
			local GrandName = GrandParent and GrandParent.Name

			if Name == "ActivateEventPrompt" and ParentName == "Knob" and GrandName == "DrawerContainer" then
				-- The ESP goes on the Knob ONLY, never on the DrawerContainer: a highlight on the whole container also covers
				-- everything inside it, which painted over the Key / Star Vial lying in a closed drawer.
				return "Drawer", Parent, "Drawer"
			elseif Name == "ActivateEventPrompt" and ParentName == "TimerLever" then
				return "Timer Lever", Parent, "Timer Lever"
			elseif Name == "UnlockPrompt" and ParentName == "Lock" and GrandName == "Door" then
				return "Door", GrandParent, "Door"
			elseif Name == "EnterPrompt" and ParentName == "Door" and GrandName == "Backdoors_Exit" then
				return "Door", Parent, "Exit Door"
			elseif Name == "ModulePrompt" then
				if ParentName == "KeyObtain" then
					return "Key", Parent, "Key"
				elseif ParentName == "StarVial" then
					return "Star Vial", Parent, "Star Vial"
				elseif ParentName == "StarBottle" then
					return "Star Bottle", Parent, "Star Bottle"
				end
			end
		elseif Object.Name == "Backdoor_Wardrobe" and Object:IsA("Model") then
			return "Closet", Object, "Closet"
		end
	end

	-- room number of an object (nil for things outside CurrentRooms, e.g. workspace.Drops)
	local function RoomOf(Object)
		local Current = Object
		while Current and Current.Parent do
			if Current.Parent == CurrentRooms then
				return tonumber(Current.Name)
			end
			Current = Current.Parent
		end
		return nil
	end

	local function PromptPosition(Prompt)
		local Parent = Prompt.Parent
		if Parent:IsA("BasePart") then return Parent.Position end
		if Parent:IsA("Model") then return Parent:GetPivot().Position end
		local Part = Parent:FindFirstAncestorWhichIsA("BasePart")
		return Part and Part.Position or Vector3.zero
	end

	----------------------------------------------------------------------------------------------------
	-- ESP (interactables + items)
	----------------------------------------------------------------------------------------------------
	local function WantsESP(Info)
		if InteractableCategories[Info.Category] then
			if not (Toggles.BackdoorsInteractableESPToggle.Value and Options.BackdoorsInteractableESPList.Value[Info.Category]) then return false end
		else
			if not (Toggles.BackdoorsItemESPToggle.Value and Options.BackdoorsItemESPList.Value[Info.Category]) then return false end
		end
		-- only objects of the room you are in (Highlights are limited); dropped items are not inside a room
		local Room = RoomOf(Info.Target)
		if Room ~= nil and Room ~= tonumber(LocalPlayer:GetAttribute("CurrentRoom")) then return false end
		return Info.Target:IsDescendantOf(Services.Workspace)
	end

	local function ColorOf(Info)
		if InteractableCategories[Info.Category] then
			return Options.BackdoorsInteractableESPColor.Value
		end
		return Options.BackdoorsItemESPColor.Value
	end

	local function ApplyESP(Info)
		local Want = WantsESP(Info)
		if Want and not Info.Shown then
			Info.Shown = true
			Functions.AddESP({ Object = Info.Target, Text = Info.Label, Color = ColorOf(Info) })
		elseif not Want and Info.Shown then
			Info.Shown = false
			Functions.RemoveESP(Info.Target)
		end
	end

	local function Refresh()
		for _, Info in Tracked do
			ApplyESP(Info)
		end
	end

	local function Recolor()
		for _, Info in Tracked do
			if Info.Shown then
				Info.Shown = false
				Functions.RemoveESP(Info.Target)
			end
		end
		Refresh()
	end

	local function Track(Object)
		if Tracked[Object] then return end
		local Category, Target, Label = Classify(Object)
		if not Category then return end

		local Info = {
			Category = Category, Target = Target, Label = Label,
			Prompt = Object:IsA("ProximityPrompt") and Object or nil,
			Shown = false, LastFire = 0
		}
		Tracked[Object] = Info

		Object.Destroying:Once(function()
			if Info.Shown then
				Info.Shown = false
				Functions.RemoveESP(Info.Target)
			end
			Tracked[Object] = nil
		end)

		ApplyESP(Info)
	end

	Toggles.BackdoorsInteractableESPToggle:OnChanged(Refresh)
	Options.BackdoorsInteractableESPList:OnChanged(Refresh)
	Toggles.BackdoorsItemESPToggle:OnChanged(Refresh)
	Options.BackdoorsItemESPList:OnChanged(Refresh)
	Options.BackdoorsInteractableESPColor:OnChanged(Recolor)
	Options.BackdoorsItemESPColor:OnChanged(Recolor)
	Connections.BackdoorsRoomChanged = LocalPlayer:GetAttributeChangedSignal("CurrentRoom"):Connect(Refresh)

	-- everything that already exists, then everything that appears later
	task.spawn(function()
		local Count = 0
		for _, Object in Services.Workspace:GetDescendants() do
			if Object:IsA("ProximityPrompt") or Object.Name == "Backdoor_Wardrobe" then
				Track(Object)
			end
			Count += 1
			if Count % 400 == 0 then task.wait() end
		end
	end)
	Connections.BackdoorsDescendants = Services.Workspace.DescendantAdded:Connect(function(Object)
		if Object:IsA("ProximityPrompt") or Object.Name == "Backdoor_Wardrobe" then
			task.defer(Track, Object)
		end
	end)

	----------------------------------------------------------------------------------------------------
	-- Auto Interact / Auto Loot (whitelist)
	----------------------------------------------------------------------------------------------------
	local LastAutomationTick = 0
	Connections.BackdoorsAutomation = Services.RunService.Heartbeat:Connect(function()
		local Interact = Toggles.BackdoorsAutoInteractToggle.Value
		local Loot = Toggles.BackdoorsAutoLootToggle.Value
		if not Interact and not Loot then return end
		if tick() - LastAutomationTick < 0.1 then return end
		LastAutomationTick = tick()

		local Character = LocalPlayer.Character
		if not Character or Character:GetAttribute("Hiding") == true then return end
		local CurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))

		for _, Info in Tracked do
			local Prompt = Info.Prompt
			if not Prompt or not Prompt.Parent or not Prompt.Enabled then continue end

			local Selected
			if InteractableCategories[Info.Category] then
				Selected = Interact and Options.BackdoorsAutoInteractList.Value[Info.Category]
			else
				Selected = Loot and Options.BackdoorsAutoLootList.Value[Info.Category]
			end
			if not Selected then continue end
			if tick() - Info.LastFire < 0.5 then continue end

			local Room = RoomOf(Prompt)
			if Room ~= nil and Room ~= CurrentRoom then continue end
			if LocalPlayer:DistanceFromCharacter(PromptPosition(Prompt)) > Prompt.MaxActivationDistance then continue end

			-- same rules as Abysall's Auto Interact: no second key, and a locked door needs a key
			if Info.Category == "Key" and HasBackdoorKey() then continue end
			if Prompt.Name == "UnlockPrompt" and not HasBackdoorKey() then continue end

			Info.LastFire = tick()
			task.spawn(Functions.FirePrompt, Prompt)
		end
	end)

	----------------------------------------------------------------------------------------------------
	-- Entities: Blitz / Lookman  (ESP + notifications)
	----------------------------------------------------------------------------------------------------
	local EntityAliases = { BackdoorRush = "Blitz", BackdoorLookman = "Lookman" }
	local TrackedEntities = {} -- [Model] = { Alias, Shown }

	local function ApplyEntityESP(Model, Data)
		local Want = Toggles.BackdoorsEntityESPToggle.Value and Options.BackdoorsEntityESPList.Value[Data.Alias]
		if Want and not Data.Shown and Model.Parent then
			Data.Shown = true
			Functions.AddESP({ Object = Model, Text = Data.Alias, Color = Options.BackdoorsEntityESPColor.Value })
		elseif not Want and Data.Shown then
			Data.Shown = false
			Functions.RemoveESP(Model)
		end
	end

	local function RefreshEntities()
		for Model, Data in TrackedEntities do
			ApplyEntityESP(Model, Data)
		end
	end

	local function RecolorEntities()
		for Model, Data in TrackedEntities do
			if Data.Shown then
				Data.Shown = false
				Functions.RemoveESP(Model)
			end
		end
		RefreshEntities()
	end

	local function HandleEntity(Model, Silent)
		local Alias = EntityAliases[Model.Name]
		if not Alias or not Model:IsA("Model") or TrackedEntities[Model] then return end
		local Data = { Alias = Alias, Shown = false }
		TrackedEntities[Model] = Data

		-- same as Main: wait for a PrimaryPart before using the entity
		local Waited = 0
		while not Model.PrimaryPart and Model.Parent and Waited < 5 do
			for _, Child in Model:GetChildren() do
				if Child:IsA("BasePart") then Model.PrimaryPart = Child break end
			end
			if not Model.PrimaryPart then Waited += task.wait() end
		end
		if not Model.Parent then
			TrackedEntities[Model] = nil
			return
		end

		if not Silent and Toggles.BackdoorsNotifyEntitiesToggle.Value and Options.BackdoorsNotifyEntitiesList.Value[Alias] then
			local EntityData = Entities[Model.Name]
			if EntityData then
				Functions.Notify({
					Title = EntityData.NotifyMessage.Title,
					Body = EntityData.NotifyMessage.Body,
					Image = EntityIcons[Model.Name],
					Time = Toggles.NotifyKeepNotifications.Value and Model or nil
				})
			end
		end

		ApplyEntityESP(Model, Data)

		Model.Destroying:Once(function()
			if Data.Shown then
				Data.Shown = false
				Functions.RemoveESP(Model)
			end
			TrackedEntities[Model] = nil
		end)
	end

	Toggles.BackdoorsEntityESPToggle:OnChanged(RefreshEntities)
	Options.BackdoorsEntityESPList:OnChanged(RefreshEntities)
	Options.BackdoorsEntityESPColor:OnChanged(RecolorEntities)

	for _, Child in Services.Workspace:GetChildren() do
		task.spawn(HandleEntity, Child, true)
	end
	Connections.BackdoorsEntities = Services.Workspace.ChildAdded:Connect(function(Child)
		task.spawn(HandleEntity, Child)
	end)
end

return Module
