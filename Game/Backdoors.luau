--[[
	Backdoors  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local Module = Abysall.LoadModule("Backdoors");  Module.Init(Shared)

	Column 1:  Automation | Settings multisection - Auto Interact / Auto Loot with a LIST of what to use / pick up (whitelist,
	                          unlike the old global Auto Interact which only has an ignore list).
	Column 2:  ESP | Notifications | Settings multisection
	Column 3:  Anti         - Anti Lookman, Anti Vacuum, (moved 1:1 out of Main.luau).

	Everything below only works while Floor == "Backdoor". Rooms are NOT hard-coded, only names and structure:
	  Drawer       ...Backdoor_Table (1-2 DrawerContainer)   prompt: DrawerContainer.Knob.ActivateEventPrompt
	                   a container is "looted" once it has a LootHolder child -> no more interacting, and the ESP of the
	                   whole table goes away when ALL of its containers are looted
	  Door         ...Door (room door) / ...Backdoors_Exit.Door     prompts: Door.Lock.UnlockPrompt / Door.EnterPrompt
	  Timer Lever  ...TimerLever.ActivateEventPrompt
	  Key          ...KeyObtain.ModulePrompt      (in the open, or inside a DrawerContainer)
	  Star Vial    ...StarVial.ModulePrompt       (workspace.Drops or inside a DrawerContainer)
	  Star Bottle  ...StarBottle.ModulePrompt     (workspace.Drops or a room)
	  Closet       ...Backdoor_Wardrobe           (ESP only)
]]

local Module = {}

function Module.Init(Shared)
	local Abysall, Connections, CurrentRooms, Entities, EntityIcons, Functions, Groupboxes, LocalPlayer, Options, Services, Tabs, Toggles, Window
	   = Shared.Abysall, Shared.Connections, Shared.CurrentRooms, Shared.Entities, Shared.EntityIcons, Shared.Functions, Shared.Groupboxes, Shared.LocalPlayer, Shared.Options, Shared.Services, Shared.Tabs, Shared.Toggles, Shared.Window

	Tabs.Backdoors = Window:AddTab("Backdoors", "backdoors", { Columns = 3 })

	----------------------------------------------------------------------------------------------------
	-- UI
	----------------------------------------------------------------------------------------------------
	-- column 1: Automation | Settings
	Groupboxes.Backdoors_AutomationTabbox = Tabs.Backdoors:AddLeftTabbox("Automation / Settings")
	Groupboxes.Backdoors_Automation = Groupboxes.Backdoors_AutomationTabbox:AddTab("Automation")
	Groupboxes.Backdoors_AutomationSettings = Groupboxes.Backdoors_AutomationTabbox:AddTab("Settings")

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

	Groupboxes.Backdoors_AutomationSettings:AddToggle("BackdoorsLootDroppedItems", {
		Text = "Loot Dropped Items", Default = true,
		Tooltip = "When off, Auto Loot ignores items lying in workspace.Drops (items that were dropped)."
	})
	Groupboxes.Backdoors_AutomationSettings:AddToggle("BackdoorsDebug", {
		Text = "Debug (Auto Interact)", Default = false,
		Tooltip = "Shows a notification explaining what Auto Interact does with drawers (temporary, for troubleshooting)."
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
		Text = "Interactables ESP", Default = false, Tooltip = "Highlights the selected interactable objects."
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
	Groupboxes.Backdoors_Notifications:AddDivider()
	Groupboxes.Backdoors_Notifications:AddToggle("BackdoorsNotifyItemsToggle", {
		Text = "Notify Items", Default = false, Tooltip = "Shows a notification when one of the selected items appears."
	})
	Groupboxes.Backdoors_Notifications:AddDropdown("BackdoorsNotifyItemsList", {
		Text = "Items", Values = { "Key", "Star Vial", "Star Bottle" }, Multi = true, AllowNull = true
	})
	Groupboxes.Backdoors_Notifications:AddDivider()
	Groupboxes.Backdoors_Notifications:AddToggle("NotifyHasteTime",   { Text = "Notify Haste Time",   Default = false, Tooltip = "Shows how much time you have remaining before 'Haste' spawns." })

	-- Settings: ESP behaviour
	Groupboxes.Backdoors_Settings:AddToggle("BackdoorsRemoveESPOnActive", {
		Text = "Remove ESP On Active", Default = true,
		Tooltip = "Removes the ESP of a Timer Lever once it is pulled and of a Drawer once all of its drawers are looted."
	})
	Groupboxes.Backdoors_Settings:AddDropdown("BackdoorsInteractableESPType", {
		Text = "Interactables ESP Type", Values = { "Current Room", "Current & Next", "Previous & Current & Next", "Always" }, Default = 1
	})
	Groupboxes.Backdoors_Settings:AddDropdown("BackdoorsItemESPType", {
		Text = "Items ESP Type", Values = { "Current Room", "Current & Next", "Previous & Current & Next", "Always" }, Default = 1
	})

	-- Settings: ESP colours. One colour per category and one per entity / object / item; an item follows its category colour until
	-- you change its own.
	local CategoryDefaults = {
		Entity = Color3.fromRGB(255, 70, 70), Interactable = Color3.fromRGB(80, 170, 255), Item = Color3.fromRGB(255, 210, 60)
	}
	local function ColorIdx(Name)
		return "BackdoorsColor_" .. (Name:gsub("[^%w]", ""))
	end
	local ColorGroups = {
		{ Category = "Entity", Label = "Entity ESP Color", Idx = "BackdoorsEntityESPColor", Items = { "Blitz", "Lookman" } },
		{ Category = "Interactable", Label = "Interactables ESP Color", Idx = "BackdoorsInteractableESPColor", Items = { "Drawer", "Door", "Timer Lever", "Closet" } },
		{ Category = "Item", Label = "Items ESP Color", Idx = "BackdoorsItemESPColor", Items = { "Key", "Star Vial", "Star Bottle" } },
	}
	local AllColorPickers = {}
	for _, Group in ColorGroups do
		Groupboxes.Backdoors_Settings:AddDivider()
		Groupboxes.Backdoors_Settings:AddLabel(Group.Label):AddColorPicker(Group.Idx, { Default = CategoryDefaults[Group.Category] })
		Group.ItemIdxs = {}
		for _, Item in Group.Items do
			local Idx = ColorIdx(Item)
			table.insert(Group.ItemIdxs, Idx)
			Groupboxes.Backdoors_Settings:AddLabel(Item .. " Color"):AddColorPicker(Idx, { Default = CategoryDefaults[Group.Category] })
		end
	end

	-- Settings: notification settings + Show Entity Path. The originals live on the Hotel tab (moved there from Visuals);
	-- these are copies that stay in sync with them.
	Groupboxes.Backdoors_Settings:AddDivider()
	Groupboxes.Backdoors_Settings:AddToggle("EntityChatToggleBackdoors", { Text = "Notify Chat", Default = false, Tooltip = "Sends a message in the chat when an entity spawns." })
	Groupboxes.Backdoors_Settings:AddInput("EntityChatMessageBackdoors", { Text = "Message", Default = "spawned!", Numeric = false, Placeholder = "Message" })
	Groupboxes.Backdoors_Settings:AddDivider()
	Groupboxes.Backdoors_Settings:AddDropdown("NotifyStyleBackdoors", { Text = "Notify Style", Values = { "Abysall", "Doors", "STX", "Library" }, Default = 1 })
	Groupboxes.Backdoors_Settings:AddSlider("NotifySoundVolumeBackdoors", { Text = "Sound Volume", Min = 0, Max = 10, Default = 3, Rounding = 1 })
	Groupboxes.Backdoors_Settings:AddToggle("NotifyPlaySoundBackdoors", { Text = "Play Sound", Default = true, Tooltip = "Makes notifications play an alert sound." })
	Groupboxes.Backdoors_Settings:AddToggle("NotifyKeepNotificationsBackdoors", { Text = "Keep Notifications", Default = false, Tooltip = "Certain notifications will stay on screen until they are no longer needed." })
	Groupboxes.Backdoors_Settings:AddButton({ Text = "Test Notification", DoubleClick = false, Tooltip = "Sends a test notifcation, so you can see how your settings look.", Func = function()
		Functions.Notify({Title = "This is a test."})
	end})
	Groupboxes.Backdoors_Settings:AddDivider()
	Groupboxes.Backdoors_Settings:AddToggle("ShowEntityPathBackdoors", {
	    Text = "Show Entity Path",
	    Default = false,
	    Tooltip = "Shows the path of entitys."
	})

	Groupboxes.Backdoors_Settings:AddSlider("ShowEntityPathNodeTransparencyBackdoors", {
	    Text = "Node Transparency",
	    Default = 0,
	    Min = 0,
	    Max = 1,
	    Rounding = 2,
	    Compact = false,
	    Tooltip = "Transparency of the path nodes when shown"
	})

	Groupboxes.Backdoors_Settings:AddSlider("ShowEntityPathLineTransparencyBackdoors", {
	    Text = "Line Transparency",
	    Default = 0.15,
	    Min = 0,
	    Max = 1,
	    Rounding = 2,
	    Compact = false,
	    Tooltip = "Transparency of the path lines"
	})

	Groupboxes.Backdoors_Settings:AddSlider("ShowEntityPathLineThicknessBackdoors", {
	    Text = "Line Thickness",
	    Default = 0.3,
	    Min = 0.08,
	    Max = 1.2,
	    Rounding = 2
	})

	local function Link(Master, Mirror)
		Mirror:OnChanged(function(Value)
			if Master.Value ~= Value then Master:SetValue(Value) end
		end)
		Master:OnChanged(function(Value)
			if Mirror.Value ~= Value then Mirror:SetValue(Value) end
		end)
	end
	Link(Toggles.EntityChatToggle, Toggles.EntityChatToggleBackdoors)
	Link(Options.EntityChatMessage, Options.EntityChatMessageBackdoors)
	Link(Options.NotifyStyle, Options.NotifyStyleBackdoors)
	Link(Options.NotifySoundVolume, Options.NotifySoundVolumeBackdoors)
	Link(Toggles.NotifyPlaySound, Toggles.NotifyPlaySoundBackdoors)
	Link(Toggles.NotifyKeepNotifications, Toggles.NotifyKeepNotificationsBackdoors)
	Link(Toggles.ShowEntityPath, Toggles.ShowEntityPathBackdoors)
	Link(Options.ShowEntityPathNodeTransparency, Options.ShowEntityPathNodeTransparencyBackdoors)
	Link(Options.ShowEntityPathLineTransparency, Options.ShowEntityPathLineTransparencyBackdoors)
	Link(Options.ShowEntityPathLineThickness, Options.ShowEntityPathLineThicknessBackdoors)

	-- column 3: Anti (moved 1:1 out of Main.luau)
	Groupboxes.Backdoors_Anti = Tabs.Backdoors:AddRightGroupbox("Anti")
	Groupboxes.Backdoors_Anti:AddToggle("BypassLookman",        { Text = "Anti Lookman",          Default = false, Tooltip = "Prevents 'Lookman' from hurting you." })
	Groupboxes.Backdoors_Anti:AddToggle("BypassVacuum",         { Text = "Anti Vacuum",           Default = false, Tooltip = "Prevents you from falling into 'Vacuum' fake doors." })

	----------------------------------------------------------------------------------------------------
	-- Helpers
	----------------------------------------------------------------------------------------------------
	local InteractableCategories = { Drawer = true, Door = true, ["Timer Lever"] = true, Closet = true }
	local EntryNames = {
		Backdoor_Table = "Drawer", TimerLever = "Timer Lever", Door = "Door", Backdoor_Wardrobe = "Closet",
		KeyObtain = "Key", StarVial = "Star Vial", StarBottle = "Star Bottle"
	}
	local ScanFinished = false

	local function OnBackdoors()
		return Shared.Floor == "Backdoor"
	end

	local function HasBackdoorKey()
		return (Functions.HasItem("KeyBackdoor") or Functions.HasItem("Key")) and true or false
	end

	-- items that were picked up end up inside a player model (workspace.<name>): no ESP / loot / notification for those
	local function IsInPlayerModel(Object)
		local Players = game:GetService("Players")
		local Current = Object.Parent
		while Current and Current ~= Services.Workspace do
			if Players:GetPlayerFromCharacter(Current) then return true end
			Current = Current.Parent
		end
		return false
	end

	local function DebugLog(Text)
		if Toggles.BackdoorsDebug.Value then
			Functions.Notify({ Title = "Backdoors Debug", Body = Text, Time = 6 })
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

	-- ESP range:  Current Room | Current & Next | Previous & Current & Next | Always
	local function InRange(Room, Mode)
		if Room == nil or Mode == "Always" then return true end
		local Current = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
		if not Current then return false end
		if Mode == "Current & Next" then
			return Room == Current or Room == Current + 1
		elseif Mode == "Previous & Current & Next" then
			return Room >= Current - 1 and Room <= Current + 1
		end
		return Room == Current
	end

	local function PromptPosition(Prompt)
		local Parent = Prompt.Parent
		if Parent:IsA("BasePart") then return Parent.Position end
		if Parent:IsA("Model") then return Parent:GetPivot().Position end
		local Part = Parent:FindFirstAncestorWhichIsA("BasePart")
		return Part and Part.Position or Vector3.zero
	end

	local function DrawerContainers(Table)
		local List = {}
		for _, Child in Table:GetChildren() do
			if Child.Name == "DrawerContainer" then table.insert(List, Child) end
		end
		return List
	end

	local function LeverPrompt(Lever)
		return Lever:FindFirstChild("ActivateEventPrompt", true)
	end

	-- An invisible copy of an object (welded to the real parts). The ESP highlight is put on THIS copy: the game puts its own
	-- highlight on the real object while its prompt is showing, and two highlights on the same object replace each other, which
	-- made the ESP vanish whenever you walked up to an item or interactable.
	local function BuildProxy(Target)
		local Proxy = Instance.new("Model")
		Proxy.Name = "BackdoorsESPProxy"
		local Count = 0

		local function AddPart(Part)
			if Part.Transparency >= 0.98 or Count >= 80 then return end
			local Copy = Part:Clone()
			for _, Child in Copy:GetChildren() do
				if not Child:IsA("DataModelMesh") then Child:Destroy() end
			end
			Copy.Anchored = false
			Copy.CanCollide = false
			Copy.CanQuery = false
			Copy.CanTouch = false
			Copy.Massless = true
			Copy.CastShadow = false
			Copy.Transparency = 0.999
			Copy.Name = "ESPPart"
			local Weld = Instance.new("WeldConstraint")
			Weld.Part0 = Part
			Weld.Part1 = Copy
			Weld.Parent = Copy
			Copy.Parent = Proxy
			Count += 1
		end

		if Target:IsA("BasePart") then
			AddPart(Target)
		else
			for _, Descendant in Target:GetDescendants() do
				if Descendant:IsA("BasePart") then AddPart(Descendant) end
			end
		end

		if Count == 0 then
			Proxy:Destroy()
			return nil
		end
		Proxy.Parent = Services.Workspace.CurrentCamera
		return Proxy
	end

	----------------------------------------------------------------------------------------------------
	-- ESP entries (one per physical object, NOT per prompt)
	----------------------------------------------------------------------------------------------------
	-- Entries[Object] = { Object, Category, Label, Shown, EspObject, Visual, Conns, WasReady, Containers }
	local Entries = {}
	local Refresh

	local function ClassifyObject(Object)
		local Category = EntryNames[Object.Name]
		if not Category then return end
		if not (Object:IsA("Model") or Object:IsA("BasePart")) then return end
		if Category == "Door" then
			local Parent = Object.Parent
			if not Parent then return end
			-- room doors live directly in a room (numeric name); the exit door lives in Backdoors_Exit
			if not tonumber(Parent.Name) and Parent.Name ~= "Backdoors_Exit" then return end
		end
		return Category
	end

	local function DoorLabel(Door)
		local Ok, Number = pcall(Functions.GetDoorNumber, Door)
		return (Ok and Number) and ("Door " .. Number) or "Door"
	end

	-- Same object Abysall's own Door ESP uses: the invisible HighlightPart / HighlightModel that copies the door panel.
	-- Returns nil while Abysall has not created it yet; the exit door is not handled by Abysall (it gets its own copy).
	local function ResolveDoorObject(Door)
		local Proxy = Door:FindFirstChild("HighlightModel") or Door:FindFirstChild("HighlightPart")
		if Proxy then return Proxy, false end
		if Door.Parent and tonumber(Door.Parent.Name) then return nil end
		return Door, true
	end

	-- A DrawerContainer is done once its LootHolder spawned (while we watched) or its knob prompt was usable and no longer is.
	local function WatchContainer(Entry, Container)
		if Entry.Containers[Container] then return end
		local State = { LootSpawned = false, WasReady = false, Prompt = nil }
		Entry.Containers[Container] = State

		local function HookPrompt(Prompt)
			State.Prompt = Prompt
			if Prompt.Enabled then State.WasReady = true end
			table.insert(Entry.Conns, Prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
				if Prompt.Enabled then State.WasReady = true end
				Refresh()
			end))
			table.insert(Entry.Conns, Prompt.Destroying:Connect(function() task.defer(Refresh) end))
		end

		local Prompt = Container:FindFirstChild("ActivateEventPrompt", true)
		if Prompt then HookPrompt(Prompt) end
		table.insert(Entry.Conns, Container.DescendantAdded:Connect(function(Descendant)
			if Descendant.Name == "LootHolder" and Descendant.Parent == Container then
				State.LootSpawned = true
				Refresh()
			elseif Descendant.Name == "ActivateEventPrompt" and Descendant:IsA("ProximityPrompt") then
				HookPrompt(Descendant)
				Refresh()
			end
		end))
	end

	local function IsContainerDone(State)
		if State.LootSpawned then return true end
		if State.WasReady and (not State.Prompt or not State.Prompt.Parent or not State.Prompt.Enabled) then return true end
		return false
	end

	local function IsEntryDone(Entry)
		if Entry.Category == "Drawer" then
			local Containers = DrawerContainers(Entry.Object)
			if #Containers == 0 then return false end
			for _, Container in Containers do
				WatchContainer(Entry, Container)
				if not IsContainerDone(Entry.Containers[Container]) then return false end
			end
			return true
		elseif Entry.Category == "Timer Lever" then
			local Prompt = LeverPrompt(Entry.Object)
			if Prompt and Prompt.Enabled then
				Entry.WasReady = true
				return false
			end
			return Entry.WasReady == true -- it was usable once and now is not (or the prompt is gone) = pulled
		end
		return false
	end

	local function WantsEntry(Entry)
		if not OnBackdoors() or not Entry.Object:IsDescendantOf(Services.Workspace) then return false end
		if IsInPlayerModel(Entry.Object) then return false end
		if Entry.Category == "Drawer" and #DrawerContainers(Entry.Object) == 0 then return false end
		local Mode
		if InteractableCategories[Entry.Category] then
			if not (Toggles.BackdoorsInteractableESPToggle.Value and Options.BackdoorsInteractableESPList.Value[Entry.Category]) then return false end
			Mode = Options.BackdoorsInteractableESPType.Value
		else
			if not (Toggles.BackdoorsItemESPToggle.Value and Options.BackdoorsItemESPList.Value[Entry.Category]) then return false end
			Mode = Options.BackdoorsItemESPType.Value
		end
		if not InRange(RoomOf(Entry.Object), Mode) then return false end
		if Toggles.BackdoorsRemoveESPOnActive.Value and IsEntryDone(Entry) then return false end
		return true
	end

	local function EntryColor(Entry)
		return Options[ColorIdx(Entry.Category)].Value
	end

	-- Drawer: ONE box around the whole Backdoor_Table (all of its drawers). Highlights are composited by depth and would paint over
	-- the Key / Star Vial lying inside a closed drawer, so the box is made of AlwaysOnTop adornments (visible through walls, and
	-- the key's own highlight stays visible inside). The label comes from the ESP library through a tiny invisible anchor part.
	local function ShowDrawer(Entry)
		local Table = Entry.Object
		local Ok, CF, Size = pcall(function() return Table:GetBoundingBox() end)
		if not Ok then return false end

		local Color = EntryColor(Entry)
		local Camera = Services.Workspace.CurrentCamera

		local Box = Instance.new("Part")
		Box.Name = "BackdoorsDrawerESP"
		Box.Anchored = true
		Box.CanCollide = false
		Box.CanQuery = false
		Box.CanTouch = false
		Box.Transparency = 1
		Box.Size = Size
		Box.CFrame = CF
		Box.Parent = Camera

		local function AddBox(BoxSize, Offset, Transparency, ZIndex)
			local Adornment = Instance.new("BoxHandleAdornment")
			Adornment.Adornee = Box
			Adornment.Size = BoxSize
			Adornment.CFrame = Offset
			Adornment.Color3 = Color
			Adornment.Transparency = Transparency
			Adornment.AlwaysOnTop = true
			Adornment.ZIndex = ZIndex
			Adornment.Parent = Box
		end
		AddBox(Size, CFrame.new(), 0.88, 1)

		local T = math.clamp(math.min(Size.X, Size.Y, Size.Z) * 0.05, 0.06, 0.15)
		local HX, HY, HZ = Size.X / 2, Size.Y / 2, Size.Z / 2
		for _, SY in { -1, 1 } do
			for _, SZ in { -1, 1 } do
				AddBox(Vector3.new(Size.X, T, T), CFrame.new(0, SY * HY, SZ * HZ), 0, 2)
			end
		end
		for _, SX in { -1, 1 } do
			for _, SZ in { -1, 1 } do
				AddBox(Vector3.new(T, Size.Y, T), CFrame.new(SX * HX, 0, SZ * HZ), 0, 2)
			end
		end
		for _, SX in { -1, 1 } do
			for _, SY in { -1, 1 } do
				AddBox(Vector3.new(T, T, Size.Z), CFrame.new(SX * HX, SY * HY, 0), 0, 2)
			end
		end

		local Anchor = Instance.new("Part")
		Anchor.Name = "BackdoorsDrawerESPLabel"
		Anchor.Anchored = true
		Anchor.CanCollide = false
		Anchor.CanQuery = false
		Anchor.CanTouch = false
		Anchor.Transparency = 1
		Anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		Anchor.CFrame = CFrame.new(CF.Position + Vector3.new(0, Size.Y / 2 + 0.5, 0))
		Anchor.Parent = Camera

		Entry.Visual = { Box = Box, Anchor = Anchor }
		Entry.EspObject = Anchor
		Functions.AddESP({ Object = Anchor, Text = Entry.Label, Color = Color })
		return true
	end

	local function ShowEntry(Entry)
		if Entry.Category == "Drawer" then
			Entry.Shown = ShowDrawer(Entry)
			return
		end

		local Object, Label, Proxy = Entry.Object, Entry.Label, nil
		if Entry.Category == "Door" then
			local Resolved, NeedsProxy = ResolveDoorObject(Entry.Object)
			if not Resolved then return end
			Label = DoorLabel(Entry.Object)
			Object = Resolved
			if NeedsProxy then Proxy = BuildProxy(Resolved) end
		else
			Proxy = BuildProxy(Object)
		end
		if Proxy then
			Entry.Visual = { Proxy = Proxy }
			Object = Proxy
		end

		Entry.EspObject = Object
		Entry.Shown = true
		Functions.AddESP({ Object = Object, Text = Label, Color = EntryColor(Entry) })
	end

	local function HideEntry(Entry)
		if not Entry.Shown then return end
		Entry.Shown = false
		if Entry.EspObject then
			Functions.RemoveESP(Entry.EspObject)
			Entry.EspObject = nil
		end
		if Entry.Visual then
			for _, Instance_ in Entry.Visual do
				pcall(function() Instance_:Destroy() end)
			end
			Entry.Visual = nil
		end
	end

	local function ApplyEntry(Entry)
		-- the ESP can be wiped from outside (for example after dying): if the library no longer has it, drop our state and re-add
		if Entry.Shown and Entry.EspObject and Abysall.ESPLibrary.ElementsEnabled[Entry.EspObject] ~= true then
			HideEntry(Entry)
		end
		local Want = WantsEntry(Entry)
		if Want and not Entry.Shown then
			ShowEntry(Entry)
		elseif not Want and Entry.Shown then
			HideEntry(Entry)
		end
	end

	Refresh = function()
		for _, Entry in Entries do
			ApplyEntry(Entry)
		end
	end

	local function Recolor()
		for _, Entry in Entries do
			if Entry.Shown then HideEntry(Entry) end
		end
		Refresh()
	end

	local function HookEntry(Entry)
		local Object = Entry.Object
		local Conns = Entry.Conns

		local function HookLeverPrompt(Prompt)
			if Prompt.Enabled then Entry.WasReady = true end
			table.insert(Conns, Prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
				if Prompt.Enabled then Entry.WasReady = true end
				Refresh()
			end))
			table.insert(Conns, Prompt.Destroying:Connect(function() task.defer(Refresh) end))
		end

		if Entry.Category == "Drawer" then
			Entry.Containers = {}
			for _, Container in DrawerContainers(Object) do WatchContainer(Entry, Container) end
			table.insert(Conns, Object.ChildAdded:Connect(function(Child)
				if Child.Name == "DrawerContainer" then WatchContainer(Entry, Child) Refresh() end
			end))
		elseif Entry.Category == "Timer Lever" then
			local Prompt = LeverPrompt(Object)
			if Prompt then HookLeverPrompt(Prompt) end
			table.insert(Conns, Object.DescendantAdded:Connect(function(Descendant)
				if Descendant.Name == "ActivateEventPrompt" and Descendant:IsA("ProximityPrompt") then
					HookLeverPrompt(Descendant)
					Refresh()
				end
			end))
		end
	end

	local function TrackObject(Object)
		if Entries[Object] then return end
		local Category = ClassifyObject(Object)
		if not Category then return end

		local Entry = { Object = Object, Category = Category, Label = Category, Shown = false, Conns = {}, Containers = {} }
		Entries[Object] = Entry
		HookEntry(Entry)
		table.insert(Entry.Conns, Object.AncestryChanged:Connect(function() ApplyEntry(Entry) end))

		Object.Destroying:Once(function()
			HideEntry(Entry)
			for _, Conn in Entry.Conns do Conn:Disconnect() end
			Entries[Object] = nil
		end)

		ApplyEntry(Entry)

		-- notification for items that show up after the first scan (not for things already lying around or carried by a player)
		if ScanFinished and not InteractableCategories[Category] and OnBackdoors() and not IsInPlayerModel(Object)
			and Toggles.BackdoorsNotifyItemsToggle.Value and Options.BackdoorsNotifyItemsList.Value[Category] then
			Functions.Notify({
				Title = Category, Body = "A " .. Category .. " has appeared.",
				Time = Toggles.NotifyKeepNotifications.Value and Object or nil
			})
		end
	end

	----------------------------------------------------------------------------------------------------
	-- Colours: an item follows its category colour until you change its own
	----------------------------------------------------------------------------------------------------
	local AllColorIdxs = {}
	local function InheritColors(CategoryIdx, ItemIdxs)
		local Previous = Options[CategoryIdx].Value
		Options[CategoryIdx]:OnChanged(function(New)
			for _, Idx in ItemIdxs do
				if Options[Idx].Value == Previous then Options[Idx]:SetValue(New) end
			end
			Previous = New
		end)
	end
	for _, Group in ColorGroups do
		InheritColors(Group.Idx, Group.ItemIdxs)
		table.insert(AllColorIdxs, Group.Idx)
		for _, Idx in Group.ItemIdxs do table.insert(AllColorIdxs, Idx) end
	end

	Toggles.BackdoorsInteractableESPToggle:OnChanged(function() Refresh() end)
	Options.BackdoorsInteractableESPList:OnChanged(function() Refresh() end)
	Options.BackdoorsInteractableESPType:OnChanged(function() Refresh() end)
	Toggles.BackdoorsItemESPToggle:OnChanged(function() Refresh() end)
	Options.BackdoorsItemESPList:OnChanged(function() Refresh() end)
	Options.BackdoorsItemESPType:OnChanged(function() Refresh() end)
	Toggles.BackdoorsRemoveESPOnActive:OnChanged(function() Refresh() end)
	Connections.BackdoorsRoomChanged = LocalPlayer:GetAttributeChangedSignal("CurrentRoom"):Connect(function() Refresh() end)

	----------------------------------------------------------------------------------------------------
	-- Prompts for Auto Interact / Auto Loot (whitelist)
	----------------------------------------------------------------------------------------------------
	-- Prompts[Prompt] = { Category, LastFire, Fires, HadLootHolder }
	local Prompts = {}

	local function ClassifyPrompt(Prompt)
		local Parent = Prompt.Parent
		if not Parent then return end
		local Name, ParentName = Prompt.Name, Parent.Name
		local GrandParent = Parent.Parent
		local GrandName = GrandParent and GrandParent.Name

		if Name == "ActivateEventPrompt" and ParentName == "Knob" and GrandName == "DrawerContainer" then
			return "Drawer"
		elseif Name == "ActivateEventPrompt" and ParentName == "TimerLever" then
			return "Timer Lever"
		elseif Name == "UnlockPrompt" and ParentName == "Lock" and GrandName == "Door" then
			return "Door"
		elseif Name == "EnterPrompt" and ParentName == "Door" and GrandName == "Backdoors_Exit" then
			return "Door"
		elseif Name == "ModulePrompt" then
			if ParentName == "KeyObtain" then return "Key"
			elseif ParentName == "StarVial" then return "Star Vial"
			elseif ParentName == "StarBottle" then return "Star Bottle" end
		end
	end

	local function TrackPrompt(Prompt)
		if Prompts[Prompt] then return end
		local Category = ClassifyPrompt(Prompt)
		if not Category then return end
		Prompts[Prompt] = { Category = Category, LastFire = 0 }
		Prompt.Destroying:Once(function() Prompts[Prompt] = nil end)
	end

	local LastAutomationTick = 0
	Connections.BackdoorsAutomation = Services.RunService.Heartbeat:Connect(function()
		local Interact = Toggles.BackdoorsAutoInteractToggle.Value
		local Loot = Toggles.BackdoorsAutoLootToggle.Value
		if not Interact and not Loot then return end
		if tick() - LastAutomationTick < 0.1 then return end
		LastAutomationTick = tick()
		if not OnBackdoors() then return end

		local Character = LocalPlayer.Character
		if not Character or Character:GetAttribute("Hiding") == true then return end
		local CurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))

		for Prompt, Info in Prompts do
			if not Prompt.Parent or not Prompt.Enabled then continue end
			if IsInPlayerModel(Prompt) then continue end

			local Selected
			if InteractableCategories[Info.Category] then
				Selected = Interact and Options.BackdoorsAutoInteractList.Value[Info.Category]
			else
				Selected = Loot and Options.BackdoorsAutoLootList.Value[Info.Category]
			end
			if not Selected then continue end

			-- Loot Dropped Items off: leave everything in workspace.Drops alone
			if not InteractableCategories[Info.Category] and not Toggles.BackdoorsLootDroppedItems.Value then
				local Drops = Services.Workspace:FindFirstChild("Drops")
				if Drops and Prompt:IsDescendantOf(Drops) then continue end
			end

			local Cooldown = Info.Category == "Drawer" and 1.5 or 0.5
			if tick() - Info.LastFire < Cooldown then continue end

			local Room = RoomOf(Prompt)
			if Room ~= nil and Room ~= CurrentRoom then continue end
			if LocalPlayer:DistanceFromCharacter(PromptPosition(Prompt)) > Prompt.MaxActivationDistance then continue end

			-- Drawer: open every container once. Normally we stop as soon as its LootHolder spawns (it has been opened);
			-- if the LootHolder was already there before our first try (e.g. a drawer with a key inside) we cannot verify
			-- the result, so it is activated only once.
			if Info.Category == "Drawer" then
				local Container = Prompt.Parent and Prompt.Parent.Parent
				local HasLootHolder = Container ~= nil and Container:FindFirstChild("LootHolder") ~= nil
				if (Info.Fires or 0) > 0 then
					if Info.HadLootHolder or HasLootHolder or Info.Fires >= 3 then
						if not Info.LoggedDone then
							Info.LoggedDone = true
							DebugLog("Drawer done: fires=" .. Info.Fires .. ", LootHolder before=" .. tostring(Info.HadLootHolder) .. ", now=" .. tostring(HasLootHolder))
						end
						continue
					end
				else
					Info.HadLootHolder = HasLootHolder
					local Names = {}
					if Container then
						for _, Child in Container:GetChildren() do table.insert(Names, Child.Name) end
					end
					DebugLog("Drawer: opening. Container children: " .. table.concat(Names, ", ") .. " | LootHolder: " .. tostring(HasLootHolder))
				end
			end

			-- same rules as Abysall's Auto Interact: no second key, and a locked door needs a key
			if Info.Category == "Key" and HasBackdoorKey() then continue end
			if Prompt.Name == "UnlockPrompt" and not HasBackdoorKey() then continue end

			if Info.Category == "Drawer" then Info.Fires = (Info.Fires or 0) + 1 end
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
		if Data.Shown and Abysall.ESPLibrary.ElementsEnabled[Model] ~= true then
			Data.Shown = false -- wiped from outside (for example after dying): add it again
		end
		local Want = Toggles.BackdoorsEntityESPToggle.Value and Options.BackdoorsEntityESPList.Value[Data.Alias]
		if Want and not Data.Shown and Model.Parent then
			Data.Shown = true
			Functions.AddESP({ Object = Model, Text = Data.Alias, Color = Options[ColorIdx(Data.Alias)].Value })
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

	-- every colour picker (category or single object) re-applies the colours
	for _, Idx in AllColorIdxs do
		Options[Idx]:OnChanged(function()
			Recolor()
			RecolorEntities()
		end)
	end

	for _, Child in Services.Workspace:GetChildren() do
		task.spawn(HandleEntity, Child, true)
	end
	Connections.BackdoorsEntities = Services.Workspace.ChildAdded:Connect(function(Child)
		task.spawn(HandleEntity, Child)
	end)

	----------------------------------------------------------------------------------------------------
	-- Scan what already exists, then everything that appears later
	----------------------------------------------------------------------------------------------------
	local function Consider(Object)
		if Object:IsA("ProximityPrompt") then
			TrackPrompt(Object)
		elseif EntryNames[Object.Name] then
			TrackObject(Object)
		elseif (Object.Name == "HighlightPart" or Object.Name == "HighlightModel") and Object.Parent and Object.Parent.Name == "Door" then
			task.defer(Refresh) -- Abysall's door proxy appeared: the Door ESP can use it now
		end
	end

	task.spawn(function()
		local Count = 0
		for _, Object in Services.Workspace:GetDescendants() do
			Consider(Object)
			Count += 1
			if Count % 400 == 0 then task.wait() end
		end
		ScanFinished = true
	end)
	Connections.BackdoorsDescendants = Services.Workspace.DescendantAdded:Connect(function(Object)
		task.defer(Consider, Object)
	end)

	-- Watchdog: re-checks everything once a second, so ESP that was wiped (death / respawn) or hidden by a missed event comes back
	local WatchdogRunning = true
	task.spawn(function()
		while WatchdogRunning do
			task.wait(1)
			if not WatchdogRunning then break end
			pcall(Refresh)
			pcall(RefreshEntities)
		end
	end)

	-- clean up the boxes / copies when the script unloads
	Connections.BackdoorsEntryCleanup = {
		Disconnect = function()
			WatchdogRunning = false
			for _, Entry in Entries do
				HideEntry(Entry)
				for _, Conn in Entry.Conns do Conn:Disconnect() end
			end
			table.clear(Entries)
		end
	}
end

return Module
