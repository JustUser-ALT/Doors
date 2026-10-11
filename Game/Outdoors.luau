--[[
	Outdoors  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local Module = Abysall.LoadModule("Outdoors");  Module.Init(Shared) ... Module.Late(...)
	Contents: Anti / No Damage multisection - Anti Surge, No Surge Damage.
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

return Module
