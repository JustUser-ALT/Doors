--[[
    Abysall -> JustLib interface adapter
    ------------------------------------------------------------------
    Abysall's Main.luau / Lobby.luau talk to an Obsidian-style API:

        Library:CreateWindow, Window:AddTab, Tab:AddLeft/RightGroupbox,
        Tab:AddLeft/RightTabbox, Groupbox:AddToggle/AddSlider/AddDropdown/
        AddInput/AddButton/AddDivider/AddLabel, Toggle:AddKeyPicker/
        AddColorPicker, Toggles.X / Options.X (.Value, :OnChanged, :SetValue,
        :GetState), Tab:UpdateWarningBox, Library:Notify / OnUnload / Unload.

    This file implements exactly that API on top of JustLib, so the Abysall
    scripts run UNCHANGED (byte-identical to the originals).

    How it works
      * Every control is a small "model" object that holds .Value and the
        OnChanged callbacks right away (the scripts read Toggles.X.Value and
        register callbacks long before the window is on screen).
      * When ApplySettingsTab(Window) is called (last UI call in Main/Lobby)
        the whole model tree is rendered into real JustLib widgets.

    JustLib nuances handled here
      * Toggle + KeyPicker / ColorPicker  -> Sec:Group (toggle on the left,
        keybind/colour swatch on the right of the SAME row). A 2nd companion on
        the same toggle gets its own Group row directly below.
      * Tabbox                            -> Tab:MultiSection (one page per tab)
      * Disabled / DisabledTooltip        -> Locked / LockedMessage
      * Risky                             -> label painted red
      * Button.DoubleClick                -> JL:Confirm dialog
      * Tab:UpdateWarningBox              -> a text section at the top of the tab
      * Multi dropdown .Value             -> { [name] = true } (same as Obsidian)
      * Key modes Hold/Toggle/Always + SyncToggleState are emulated here
        (JustLib keybind chips only report the chosen key).
      * Flags are prefixed (Toggle_X / Option_X) because JustLib has ONE flag
        registry while Obsidian has separate Toggles/Options tables.
]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Env = (getgenv and getgenv()) or _G
local Cfg = Env.AbysallConfig or {}

-- ---------------------------------------------------------------- JustLib
local JL = Cfg.JustLib
if not JL then
    local url = Cfg.JustLibUrl or "https://raw.githubusercontent.com/JustUser-ALT/JustLib/refs/heads/main/JustLib.lua"
    local src
    if Cfg.LocalFolder and readfile then
        src = readfile(Cfg.LocalFolder .. "/JustLib.lua")
    else
        src = game:HttpGet(url)
    end
    JL = loadstring(src)()
end
JL:SetIcons({ house = "🏠", shield = "🛡", eye = "👁", earth = "🌍", ["layout-grid"] = "▦", info = "ℹ", power = "🔌" }) -- text icons, no network

-- ---------------------------------------------------------------- helpers
local Library = {
    Toggles = {},
    Options = {},
    Unloaded = false,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    ForceCheckbox = false,
    ShowToggleFrameInKeybinds = true,
}
local Toggles, Options = Library.Toggles, Library.Options

local UnloadCallbacks = {}
local Connections = {}
local KeyPickers = {}
local WindowModel -- set by CreateWindow
local JLWindow -- real JustLib window after render
local Rendered = false

local function warnf(...)
    warn("[Abysall/JustLib]", ...)
end

-- Library.Scheme: Main.luau reads BackgroundColor / AccentColor / FontColor for its own notifications
Library.Scheme = setmetatable({}, {
    __index = function(_, Key)
        local Theme = JL._themes and JL._themes[JL._currentTheme] or nil
        if not Theme then
            return Color3.fromRGB(255, 255, 255)
        end
        if Key == "BackgroundColor" then return Theme.panel end
        if Key == "MainColor" then return Theme.pHdr end
        if Key == "AccentColor" then return Theme.accents and Theme.accents[1] or Theme.togOn end
        if Key == "OutlineColor" then return Theme.border end
        if Key == "FontColor" then return Theme.txt end
        if Key == "DarkColor" then return Theme.sidebar end
        if Key == "RedColor" then return Theme.danger end
        return Theme.txt
    end,
})

local function toSet(Value)
    local Set = {}
    if type(Value) == "table" then
        if Value[1] ~= nil then
            for _, Name in ipairs(Value) do Set[Name] = true end
        else
            for Name, On in pairs(Value) do
                if On then Set[Name] = true end
            end
        end
    elseif type(Value) == "string" then
        Set[Value] = true
    end
    return Set
end

local function toList(Set, Values)
    local List = {}
    for _, Name in ipairs(Values) do
        if Set[Name] then List[#List + 1] = Name end
    end
    return List
end

local function sameSet(A, B)
    for K in pairs(A) do if not B[K] then return false end end
    for K in pairs(B) do if not A[K] then return false end end
    return true
end

local function CopySet(Set)
    local C = {}
    for K, V in pairs(Set) do C[K] = V end
    return C
end

local function Fire(Obj)
    for _, Callback in ipairs(Obj._callbacks) do
        local Ok, Err = pcall(Callback, Obj.Value)
        if not Ok then
            warnf("OnChanged '" .. tostring(Obj.Idx) .. "' errored:", Err)
        end
    end
end

local function CallCtrl(Obj, Method, ...)
    local Ctrl = Obj._ctrl
    if Ctrl and Ctrl[Method] then
        local Args = { ... }
        pcall(function() Ctrl[Method](Ctrl, table.unpack(Args)) end)
    end
end

-- ---------------------------------------------------------------- model base
local Base = {}
Base.__index = Base

function Base:OnChanged(Func)
    table.insert(self._callbacks, Func)
end

function Base:OnClick(Func)
    table.insert(self._clicks, Func)
end

function Base:SetValue(Value)
    self:_apply(Value, false)
end

function Base:SetText(Text)
    self.Text = Text
end

function Base:SetVisible(Visible)
    self.Visible = Visible
    CallCtrl(self, "SetHidden", not Visible)
end

function Base:SetDisabled(Disabled)
    self.Disabled = Disabled
    CallCtrl(self, "SetLocked", Disabled)
end

function Base:Destroy()
    CallCtrl(self, "SetHidden", true)
end

local function NewObj(Type, Idx, Cfg2)
    Cfg2 = Cfg2 or {}
    local Obj = setmetatable({
        Type = Type,
        Idx = Idx,
        Text = Cfg2.Text,
        Tooltip = Cfg2.Tooltip,
        Disabled = Cfg2.Disabled == true,
        DisabledTooltip = Cfg2.DisabledTooltip,
        Risky = Cfg2.Risky == true,
        Visible = Cfg2.Visible ~= false,
        _callbacks = {},
        _clicks = {},
    }, Base)
    if Cfg2.Callback then
        table.insert(Obj._callbacks, Cfg2.Callback)
    end
    return Obj
end

-- ---------------------------------------------------------------- key handling
local KeyInputConnected = false

local function KeyMatches(KP, Input)
    local Name = KP.Value
    if not Name or Name == "None" then return false end
    if Input.UserInputType == Enum.UserInputType.Keyboard then
        return Input.KeyCode.Name == Name
    end
    if Name == "MB1" then return Input.UserInputType == Enum.UserInputType.MouseButton1 end
    if Name == "MB2" then return Input.UserInputType == Enum.UserInputType.MouseButton2 end
    if Name == "MB3" then return Input.UserInputType == Enum.UserInputType.MouseButton3 end
    return false
end

local function KPGetState(KP)
    if KP.Mode == "Always" then return true end
    if KP.Mode == "Hold" then return KP._held end
    if KP.SyncToggleState and KP._toggle then return KP._toggle.Value end
    return KP._state
end

local function ConnectKeyInput()
    if KeyInputConnected then return end
    KeyInputConnected = true

    table.insert(Connections, UserInputService.InputBegan:Connect(function(Input, Processed)
        if Processed or Library.Unloaded or JL._listening then return end
        for _, KP in ipairs(KeyPickers) do
            if KP.Mode ~= "Always" and KeyMatches(KP, Input) then
                if KP.Mode == "Hold" then
                    KP._held = true
                    KP._state = true
                    if KP.SyncToggleState and KP._toggle then KP._toggle:SetValue(true) end
                else
                    local New = not KPGetState(KP)
                    KP._state = New
                    if KP.SyncToggleState and KP._toggle then KP._toggle:SetValue(New) end
                end
                for _, Func in ipairs(KP._clicks) do pcall(Func) end
            end
        end
    end))

    table.insert(Connections, UserInputService.InputEnded:Connect(function(Input)
        if Library.Unloaded then return end
        for _, KP in ipairs(KeyPickers) do
            if KP.Mode == "Hold" and KeyMatches(KP, Input) then
                KP._held = false
                KP._state = false
                if KP.SyncToggleState and KP._toggle then KP._toggle:SetValue(false) end
            end
        end
    end))
end

-- ---------------------------------------------------------------- constructors
local function CompanionList(Toggle)
    Toggle._companions = Toggle._companions or {}
    return Toggle._companions
end

local function MakeKeyPicker(Toggle, Idx, Cfg2)
    Cfg2 = Cfg2 or {}
    local KP = NewObj("KeyPicker", Idx, Cfg2)
    KP.Mode = Cfg2.Mode or "Toggle"
    KP.SyncToggleState = Cfg2.SyncToggleState == true
    KP.Value = (typeof(Cfg2.Default) == "EnumItem" and Cfg2.Default.Name) or (Cfg2.Default and tostring(Cfg2.Default)) or "None"
    KP._held = false
    KP._state = false
    KP._toggle = Toggle
    KP.GetState = KPGetState

    function KP:_apply(Value)
        if type(Value) == "table" then
            if Value[2] then self.Mode = Value[2] end
            Value = Value[1]
        end
        if typeof(Value) == "EnumItem" then Value = Value.Name end
        self.Value = Value and tostring(Value) or "None"
        local Key = Enum.KeyCode[self.Value]
        CallCtrl(self, "Set", Key)
        Fire(self)
    end

    function KP:SetValueFromChip(Key)
        self.Value = Key and Key.Name or "None"
        Fire(self)
    end

    Options[Idx] = KP
    KeyPickers[#KeyPickers + 1] = KP
    ConnectKeyInput()
    return KP
end

local function MakeColorPicker(Idx, Cfg2)
    Cfg2 = Cfg2 or {}
    local CP = NewObj("ColorPicker", Idx, Cfg2)
    CP.Value = Cfg2.Default or Color3.new(1, 1, 1)
    CP.Transparency = Cfg2.Transparency or 0
    CP.Title = Cfg2.Title

    function CP:_apply(Value, FromUI)
        if typeof(Value) ~= "Color3" then return end
        local Changed = self.Value ~= Value
        self.Value = Value
        if not FromUI then CallCtrl(self, "Set", Value) end
        if Changed then Fire(self) end
    end

    function CP:SetValueRGB(Color, Transparency)
        if Transparency ~= nil then self.Transparency = Transparency end
        self:_apply(Color, false)
    end

    Options[Idx] = CP
    return CP
end

local function MakeToggle(Idx, Cfg2)
    local T = NewObj("Toggle", Idx, Cfg2)
    T.Value = Cfg2.Default == true
    T.Addons = {}
    CompanionList(T)

    function T:_apply(Value, FromUI)
        Value = Value and true or false
        local Changed = self.Value ~= Value
        self.Value = Value
        if not FromUI then CallCtrl(self, "Set", Value) end
        if Changed then Fire(self) end
    end

    function T:AddKeyPicker(KIdx, KCfg)
        local KP = MakeKeyPicker(self, KIdx, KCfg)
        KP.Text = (KCfg and KCfg.Text) or self.Text
        table.insert(CompanionList(self), KP)
        return KP
    end

    function T:AddColorPicker(CIdx, CCfg)
        local CP = MakeColorPicker(CIdx, CCfg)
        CP.Text = (CCfg and CCfg.Text) or self.Text
        table.insert(CompanionList(self), CP)
        return CP
    end

    Toggles[Idx] = T
    return T
end

local function MakeSlider(Idx, Cfg2)
    local S = NewObj("Slider", Idx, Cfg2)
    S.Min = Cfg2.Min or 0
    S.Max = Cfg2.Max or 100
    S.Rounding = Cfg2.Rounding or 0
    S.Suffix = Cfg2.Suffix
    S.Value = math.clamp(Cfg2.Default or S.Min, S.Min, S.Max)

    function S:_apply(Value, FromUI)
        Value = tonumber(Value)
        if not Value then return end
        local M = 10 ^ self.Rounding
        Value = math.floor(math.clamp(Value, self.Min, self.Max) * M + 0.5) / M
        local Changed = self.Value ~= Value
        self.Value = Value
        if not FromUI then CallCtrl(self, "Set", Value) end
        if Changed then Fire(self) end
    end

    Options[Idx] = S
    return S
end

local RenderDropdown -- forward declaration (defined with the other renderers)

local function MakeDropdown(Idx, Cfg2)
    local D = NewObj("Dropdown", Idx, Cfg2)
    D.Values = Cfg2.Values or {}
    D.Multi = Cfg2.Multi == true
    D.AllowNull = Cfg2.AllowNull

    if D.Multi then
        D.Value = toSet(Cfg2.Default)
    else
        local Default = Cfg2.Default
        if type(Default) == "number" then Default = D.Values[Default] end
        D.Value = Default
    end

    function D:_apply(Value, FromUI)
        if self.Multi then
            local New = toSet(Value)
            local Changed = not sameSet(self.Value, New)
            self.Value = New
            if not FromUI then CallCtrl(self, "Set", toList(New, self.Values)) end
            if Changed then Fire(self) end
        else
            if type(Value) == "number" then Value = self.Values[Value] end
            local Changed = self.Value ~= Value
            self.Value = Value
            if not FromUI and Value ~= nil then CallCtrl(self, "Set", Value) end
            if Changed then Fire(self) end
        end
    end

    function D:SetValues(Values)
        self.Values = Values or {}
        -- drop selections that no longer exist
        if self.Multi then
            local Keep = {}
            for Name in pairs(self.Value) do
                if table.find(self.Values, Name) then Keep[Name] = true end
            end
            self.Value = Keep
        elseif self.Value ~= nil and not table.find(self.Values, self.Value) then
            self.Value = self.Values[1]
        end
        -- JustLib dropdown options are fixed at creation: when already on screen, hide the old
        -- widget and add a fresh one (at the end of the same section) with the new option list.
        if self._sec then
            CallCtrl(self, "SetHidden", true)
            self._gen = (self._gen or 0) + 1
            RenderDropdown(self._sec, self, {})
        end
    end

    function D:GetActiveValues()
        if self.Multi then return toList(self.Value, self.Values) end
        return self.Value ~= nil and { self.Value } or {}
    end

    Options[Idx] = D
    return D
end

local function MakeInput(Idx, Cfg2)
    local I = NewObj("Input", Idx, Cfg2)
    I.Value = Cfg2.Default ~= nil and tostring(Cfg2.Default) or ""
    I.Numeric = Cfg2.Numeric
    I.Finished = Cfg2.Finished
    I.Placeholder = Cfg2.Placeholder

    function I:_apply(Value, FromUI)
        Value = Value == nil and "" or tostring(Value)
        local Changed = self.Value ~= Value
        self.Value = Value
        if not FromUI then CallCtrl(self, "Set", Value) end
        if Changed then Fire(self) end
    end

    Options[Idx] = I
    return I
end

-- ---------------------------------------------------------------- groupbox model
local GroupboxMethods = {}
GroupboxMethods.__index = GroupboxMethods

local function NewGroupbox()
    return setmetatable({ Elements = {} }, GroupboxMethods)
end

function GroupboxMethods:AddToggle(Idx, Cfg2)
    local T = MakeToggle(Idx, Cfg2 or {})
    table.insert(self.Elements, { Kind = "Toggle", Obj = T })
    return T
end

function GroupboxMethods:AddSlider(Idx, Cfg2)
    local S = MakeSlider(Idx, Cfg2 or {})
    table.insert(self.Elements, { Kind = "Slider", Obj = S })
    return S
end

function GroupboxMethods:AddDropdown(Idx, Cfg2)
    local D = MakeDropdown(Idx, Cfg2 or {})
    table.insert(self.Elements, { Kind = "Dropdown", Obj = D })
    return D
end

function GroupboxMethods:AddInput(Idx, Cfg2)
    local I = MakeInput(Idx, Cfg2 or {})
    table.insert(self.Elements, { Kind = "Input", Obj = I })
    return I
end

function GroupboxMethods:AddButton(Cfg2, Func)
    if type(Cfg2) == "string" then
        Cfg2 = { Text = Cfg2, Func = Func }
    end
    local B = NewObj("Button", nil, Cfg2)
    B.Func = Cfg2.Func or Cfg2.Callback
    B.DoubleClick = Cfg2.DoubleClick == true
    table.insert(self.Elements, { Kind = "Button", Obj = B })
    return B
end

function GroupboxMethods:AddDivider(Label)
    table.insert(self.Elements, { Kind = "Divider", Label = type(Label) == "string" and Label or nil })
end

function GroupboxMethods:AddLabel(Text, Wrap)
    if type(Text) == "table" then Text = Text.Text end
    local L = { Kind = "Label", Text = tostring(Text or "") }
    table.insert(self.Elements, L)
    return {
        SetText = function(_, New)
            L.Text = tostring(New)
            if L._ctrl then pcall(function() L._ctrl:Set(L.Text) end) end
        end,
    }
end

-- ---------------------------------------------------------------- tab model
local TabMethods = {}
TabMethods.__index = TabMethods

function TabMethods:_addGroupbox(Side, Title)
    local G = NewGroupbox()
    G.Title = Title
    table.insert(self.Items, { Kind = "Groupbox", Side = Side, Title = Title, Box = G })
    return G
end

function TabMethods:AddLeftGroupbox(Title) return self:_addGroupbox("Left", Title) end
function TabMethods:AddRightGroupbox(Title) return self:_addGroupbox("Right", Title) end

function TabMethods:_addTabbox(Side, Title)
    local TB = { Pages = {} }
    function TB:AddTab(Name)
        local G = NewGroupbox()
        table.insert(self.Pages, { Name = Name, Box = G })
        return G
    end
    table.insert(self.Items, { Kind = "Tabbox", Side = Side, Title = Title, Tabbox = TB })
    return TB
end

function TabMethods:AddLeftTabbox(Title) return self:_addTabbox("Left", Title) end
function TabMethods:AddRightTabbox(Title) return self:_addTabbox("Right", Title) end

function TabMethods:UpdateWarningBox(Info)
    self.Warning = Info
end

-- ---------------------------------------------------------------- window model
local WindowMethods = {}
WindowMethods.__index = WindowMethods

function WindowMethods:AddTab(Name, Icon)
    local T = setmetatable({ Name = Name, Icon = Icon, Items = {} }, TabMethods)
    table.insert(self.Tabs, T)
    return T
end

function WindowMethods:AddKeyTab(Name) return self:AddTab(Name) end
function WindowMethods:SetFooter() end
function WindowMethods:SetCornerRadius() end
function WindowMethods:Toggle() if JLWindow then JLWindow:Toggle() end end
function WindowMethods:Show() if JLWindow then JLWindow:Open() end end
function WindowMethods:Hide() if JLWindow then JLWindow:Close() end end

-- ---------------------------------------------------------------- rendering
local function LockOpts(Obj)
    if Obj.Disabled then
        return { Locked = true, LockedMessage = Obj.DisabledTooltip or "This feature is not available.", LockedTitle = "Unavailable" }
    end
    return {}
end

local function Merge(Into, From)
    for K, V in pairs(From) do Into[K] = V end
    return Into
end

local function RenderToggle(Sec, T, Risky)
    local ToggleCfg = {
        Type = "Toggle",
        Flag = "Toggle_" .. T.Idx,
        Default = T.Value,
        Callback = function(V) T:_apply(V, true) end,
    }

    local function CompanionCfg(C)
        if C.Type == "KeyPicker" then
            return {
                Type = "Keybind",
                Flag = "Option_" .. C.Idx,
                Default = C.Value,
                Callback = function(Key) C:SetValueFromChip(Key) end,
            }
        end
        return {
            Type = "ColorPicker",
            Flag = "Option_" .. C.Idx,
            Default = C.Value,
            Callback = function(Color) C:_apply(Color, true) end,
        }
    end

    local Companions = T._companions or {}
    if #Companions == 0 then
        local O = Merge({
            Name = T.Text or T.Idx,
            Flag = ToggleCfg.Flag,
            Default = T.Value,
            Tooltip = T.Tooltip,
            Callback = ToggleCfg.Callback,
        }, LockOpts(T))
        T._ctrl = Sec:Toggle(O)
        local Ok, Got = pcall(function() return T._ctrl:Get() end)
        if Ok and type(Got) == "boolean" then T.Value = Got end
    else
        local O = Merge({
            Name = T.Text or T.Idx,
            Tooltip = T.Tooltip,
            A = ToggleCfg,
            B = CompanionCfg(Companions[1]),
        }, LockOpts(T))
        local G = Sec:Group(O)
        T._ctrl = G.A
        Companions[1]._ctrl = G.B
        for I = 2, #Companions do
            local C = Companions[I]
            local G2 = Sec:Group({ Name = C.Text or T.Text or T.Idx, A = CompanionCfg(C) })
            C._ctrl = G2.A
        end

        local Ok, Got = pcall(function() return T._ctrl:Get() end)
        if Ok and type(Got) == "boolean" then T.Value = Got end

        for _, C in ipairs(Companions) do
            local Ok2, Val = pcall(function() return C._ctrl:Get() end)
            if Ok2 and Val ~= nil then
                if C.Type == "KeyPicker" then
                    C.Value = (typeof(Val) == "EnumItem" and Val.Name) or "None"
                elseif typeof(Val) == "Color3" then
                    C.Value = Val
                end
            end
        end
    end

    if T.Risky and T.Text then Risky[T.Text] = true end
end

local function RenderSlider(Sec, S, Risky)
    local O = Merge({
        Name = S.Text or S.Idx,
        Min = S.Min,
        Max = S.Max,
        Step = 10 ^ -S.Rounding,
        Default = S.Value,
        Suffix = S.Suffix,
        Flag = "Option_" .. S.Idx,
        Tooltip = S.Tooltip,
        Callback = function(V) S:_apply(V, true) end,
    }, LockOpts(S))
    S._ctrl = Sec:Slider(O)
    local Ok, Got = pcall(function() return S._ctrl:Get() end)
    if Ok and type(Got) == "number" then S.Value = Got end
    if S.Risky and S.Text then Risky[S.Text] = true end
end

RenderDropdown = function(Sec, D, Risky)
    D._sec = Sec
    local Default
    if D.Multi then
        Default = toList(D.Value, D.Values)
    else
        Default = D.Value
    end
    local O = Merge({
        Name = D.Text or D.Idx,
        Options = D.Values,
        MultiSelect = D.Multi,
        MaxSelect = D.Multi and math.max(#D.Values, 1) or 1,
        Search = #D.Values > 8,
        Default = Default,
        Flag = "Option_" .. D.Idx .. (D._gen and ("_g" .. D._gen) or ""),
        Tooltip = D.Tooltip,
        Callback = function(V)
            if D.Multi then
                D:_apply(V, true)
            else
                if type(V) == "table" then V = V[1] end
                D:_apply(V, true)
            end
        end,
    }, LockOpts(D))
    D._ctrl = Sec:Dropdown(O)

    local Ok, Got = pcall(function() return D._ctrl:Get() end)
    if Ok then
        if D.Multi and type(Got) == "table" then
            D.Value = toSet(Got)
        elseif not D.Multi then
            if type(Got) == "string" then
                D.Value = Got
            elseif type(Got) == "table" then
                D.Value = Got[1] or next(Got)
            end
        end
    end
    if D.Risky and D.Text then Risky[D.Text] = true end
end

local function RenderInput(Sec, I, Risky)
    local O = Merge({
        Name = I.Text or I.Idx,
        Placeholder = I.Placeholder or I.Text,
        Flag = "Option_" .. I.Idx,
        Tooltip = I.Tooltip,
        OnChange = not I.Finished,
        Callback = function(V) I:_apply(V, true) end,
    }, LockOpts(I))
    I._ctrl = Sec:Input(O)
    local Ok, Got = pcall(function() return I._ctrl:Get() end)
    if Ok and type(Got) == "string" then
        if Got == "" and I.Value ~= "" then
            pcall(function() I._ctrl:Set(I.Value) end)
        else
            I.Value = Got
        end
    end
end

local function RenderButton(Sec, B, Risky)
    local O = Merge({
        Name = B.Text or "Button",
        Tooltip = B.Tooltip,
        Callback = function()
            local function Run()
                if B.Func then
                    local Ok, Err = pcall(B.Func)
                    if not Ok then warnf("Button '" .. tostring(B.Text) .. "' errored:", Err) end
                end
                for _, F in ipairs(B._clicks) do pcall(F) end
            end
            if B.DoubleClick then
                task.spawn(function()
                    local Confirmed = JL:Confirm({
                        Title = B.Text or "Are you sure?",
                        Desc = B.Tooltip or "Press Yes to continue.",
                    })
                    if Confirmed then Run() end
                end)
            else
                Run()
            end
        end,
    }, LockOpts(B))
    B._ctrl = Sec:Button(O)
    if B.Risky and B.Text then Risky[B.Text] = true end
end

local function RenderElements(Sec, Box, Panel)
    local Risky = {}
    for _, E in ipairs(Box.Elements) do
        local Kind = E.Kind
        if Kind == "Toggle" then
            RenderToggle(Sec, E.Obj, Risky)
        elseif Kind == "Slider" then
            RenderSlider(Sec, E.Obj, Risky)
        elseif Kind == "Dropdown" then
            RenderDropdown(Sec, E.Obj, Risky)
        elseif Kind == "Input" then
            RenderInput(Sec, E.Obj, Risky)
        elseif Kind == "Button" then
            RenderButton(Sec, E.Obj, Risky)
        elseif Kind == "Divider" then
            Sec:Divider(E.Label and { Label = E.Label } or nil)
        elseif Kind == "Label" then
            E._ctrl = Sec:Label({ Text = E.Text })
        end

        -- Obsidian hides elements with Visible = false
        local Obj = E.Obj
        if Obj and Obj.Visible == false then
            CallCtrl(Obj, "SetHidden", true)
        end
    end

    -- Risky = red label (Obsidian look). JLNoRepaint keeps theme swaps from undoing it.
    if next(Risky) and Panel then
        for _, D in ipairs(Panel:GetDescendants()) do
            if D:IsA("TextLabel") and Risky[D.Text] then
                D.TextColor3 = Color3.fromRGB(255, 85, 85)
                D:SetAttribute("JLNoRepaint", true)
            end
        end
    end
end

local function EnsureFolders(Path)
    if not (makefolder and isfolder) then return end
    local Built = ""
    for Part in string.gmatch(Path, "[^/]+") do
        Built = Built == "" and Part or (Built .. "/" .. Part)
        if not isfolder(Built) then pcall(makefolder, Built) end
    end
end

local InfoRequested = false

local function RenderAll()
    if Rendered or not WindowModel then return end
    Rendered = true

    local SavePath = (Env.Abysall and Env.Abysall.SavePath) or "Game"
    local ConfigFolder = "Abysall/" .. SavePath
    EnsureFolders(ConfigFolder)

    JLWindow = JL:Window({
        Title = WindowModel.Title or "Abysall Hub",
        Width = 700,
        Height = 440,
        Columns = 2,
        Hotkey = Enum.KeyCode.RightShift,
        Config = ConfigFolder .. "/JustLib",
    })

    if InfoRequested then
        pcall(function()
            JLWindow:HomeTab({
                Name = "Info",
                Icon = "info",
                DiscordInvite = "https://dsc.gg/abysallhub",
                Announcement = WindowModel.Footer or "dsc.gg/abysallhub",
            })
        end)
    end

    for _, TabModel in ipairs(WindowModel.Tabs) do
        local Tab = JLWindow:Tab({ Name = TabModel.Name, Icon = TabModel.Icon or "layout-grid", Type = "Grid" })

        local Warn = TabModel.Warning
        if Warn and Warn.Visible ~= false then
            local WSec = Tab:Section({ Title = Warn.Title or "Warning", Column = 1 })
            WSec:Text({ Text = Warn.Text or "", Size = 11, Bold = false, Color = Color3.fromRGB(255, 120, 120) })
        end

        for _, Item in ipairs(TabModel.Items) do
            local Column = Item.Side == "Right" and 2 or 1
            if Item.Kind == "Groupbox" then
                local Sec = Tab:Section({ Title = Item.Title or "Section", Column = Column })
                RenderElements(Sec, Item.Box, Sec.Panel)
            else
                local Names = {}
                for _, Page in ipairs(Item.Tabbox.Pages) do table.insert(Names, Page.Name) end
                if #Names > 0 then
                    local MS = Tab:MultiSection({ Title = Item.Title, Pages = Names, Column = Column })
                    for _, Page in ipairs(Item.Tabbox.Pages) do
                        RenderElements(MS:Page(Page.Name), Page.Box, MS.Panel)
                    end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- Library API
function Library:CreateWindow(Config)
    Config = Config or {}
    WindowModel = setmetatable({
        Title = Config.Title,
        Footer = Config.Footer,
        Tabs = {},
    }, WindowMethods)
    return WindowModel
end

function Library:Notify(Data, Time)
    local Title, Desc, Duration = "Abysall Hub", "", nil
    if type(Data) == "table" then
        Title = Data.Title or Title
        Desc = Data.Description or Data.Desc or ""
        Duration = Data.Time
    else
        Title = tostring(Data)
        Duration = Time
    end
    if typeof(Duration) == "Instance" then
        Duration = 30
    elseif type(Duration) ~= "number" then
        Duration = nil
    end
    JL:Notify({ Title = Title, Desc = Desc, Duration = Duration })
end

function Library:OnUnload(Func)
    table.insert(UnloadCallbacks, Func)
end

function Library:Unload()
    if Library.Unloaded then return end
    Library.Unloaded = true
    for _, Func in ipairs(UnloadCallbacks) do
        local Ok, Err = pcall(Func)
        if not Ok then warnf("OnUnload errored:", Err) end
    end
    for _, C in ipairs(Connections) do pcall(function() C:Disconnect() end) end
    if JLWindow then pcall(function() JLWindow:Destroy() end) end
end

function Library:SetFont() end
function Library:SetDPIScale() end
function Library:ToggleKeybinds() end

-- MenuKeybind (Main.luau prints Options.MenuKeybind.Value in its "loaded" notification)
do
    local MK = NewObj("KeyPicker", "MenuKeybind", {})
    MK.Mode = "Toggle"
    MK.Value = "RightShift"
    MK.GetState = function() return false end
    function MK:_apply() end
    Options.MenuKeybind = MK
end

-- ---------------------------------------------------------------- SaveManager / ThemeManager
-- JustLib has its own Settings page (themes, config, hotkey). Main.luau only stores these in locals.
local function NoOpModule()
    return setmetatable({}, {
        __index = function()
            return function() end
        end,
    })
end

-- ---------------------------------------------------------------- Interface table
local Interface = {
    Library = Library,
    SaveManager = NoOpModule(),
    ThemeManager = NoOpModule(),
    JustLib = JL,
}

function Interface.ApplyInfoTab(Window)
    InfoRequested = true
end

function Interface.ApplySettingsTab(Window)
    RenderAll()
    if not JLWindow then return end

    pcall(function() JLWindow:Settings() end)

    -- Unload tab (Obsidian had an "Unload" button on its UI Settings tab)
    pcall(function()
        local UTab = JLWindow:Tab({ Name = "Unload", Icon = "power", Type = "Grid" })
        local USec = UTab:Section({ Title = "Interface", Column = 1 })
        USec:Button({
            Name = "Unload",
            Tooltip = "Removes the script and all of its features.",
            Callback = function()
                task.spawn(function()
                    if JL:Confirm({ Title = "Unload", Desc = "Remove Abysall Hub and all of its features?", Danger = true }) then
                        Library:Unload()
                    end
                end)
            end,
        })
    end)

    pcall(function() JLWindow:Open() end)
end

return Interface
