--[[
	Mines  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local Module = Abysall.LoadModule("Mines");  Module.Init(Shared)
	Contents: Anti (3rd column) - Anti Giggle, Anti Gloombat Eggs.
	The code is moved 1:1 out of Main.luau (toggle labels renamed to "Anti ...").
]]

local Module = {}

function Module.Init(Shared)
	local Groupboxes, Tabs, Window
	   = Shared.Groupboxes, Shared.Tabs, Shared.Window

	Tabs.Mines = Window:AddTab("Mines", "mines", { Columns = 3 })

	Groupboxes.Mines_Anti = Tabs.Mines:AddRightGroupbox("Anti")
	Groupboxes.Mines_Anti:AddToggle("BypassGiggle",         { Text = "Anti Giggle",           Default = false, Tooltip = "Prevents 'Giggle' from attacking you." })
	Groupboxes.Mines_Anti:AddToggle("BypassGloombatEggs",   { Text = "Anti Gloombat Eggs",    Default = false, Tooltip = "Prevents taking damage from stepping on 'Gloombat' eggs." })
end

return Module
