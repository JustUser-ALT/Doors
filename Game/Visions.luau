--[[
	Visions  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local Module = Abysall.LoadModule("Visions");  Module.Init(Shared) ... Module.Late(...)
	Contents: Retro (Anti Killbricks, Anti Seeking Wall) | Super Hard Mode (Anti Banana, Anti Jeff) | Rooms (Anti A-90, No A-90 Damage).
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

	Groupboxes.Visions_SuperHardMode = Tabs.Visions:AddMiddleGroupbox("Super Hard Mode")
	Groupboxes.Visions_SuperHardMode:AddToggle("BypassBanana",         { Text = "Anti Banana",           Default = false, Tooltip = "Prevents 'Banana Peel' from slipping you up (sometimes doesn't work)." })
	Groupboxes.Visions_SuperHardMode:AddToggle("BypassJeff",           { Text = "Anti Jeff",             Default = false, Tooltip = "Prevents 'Jeff the Killer' from stabbing you (sometimes doesn't work)." })

	Groupboxes.Visions_Rooms = Tabs.Visions:AddRightGroupbox("Rooms")
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

return Module
