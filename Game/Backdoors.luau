--[[
	Backdoors  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local Module = Abysall.LoadModule("Backdoors");  Module.Init(Shared)
	Contents: Anti (3rd column) - Anti Lookman, Anti Vacuum.
	The code is moved 1:1 out of Main.luau (toggle labels renamed to "Anti ...").
]]

local Module = {}

function Module.Init(Shared)
	local Groupboxes, Tabs, Window
	   = Shared.Groupboxes, Shared.Tabs, Shared.Window

	Tabs.Backdoors = Window:AddTab("Backdoors", "backdoors", { Columns = 3 })

	Groupboxes.Backdoors_Anti = Tabs.Backdoors:AddRightGroupbox("Anti")
	Groupboxes.Backdoors_Anti:AddToggle("BypassLookman",        { Text = "Anti Lookman",          Default = false, Tooltip = "Prevents 'Lookman' from hurting you." })
	Groupboxes.Backdoors_Anti:AddToggle("BypassVacuum",         { Text = "Anti Vacuum",           Default = false, Tooltip = "Prevents you from falling into 'Vacuum' fake doors." })
end

return Module
