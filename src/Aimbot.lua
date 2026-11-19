if LPH_OBFUSCATED == nil then
	LPH_NO_VIRTUALIZE = function(...)
		return ...
	end
end

--// Remove any previous copy (re-running the script is safe)

if getgenv then
	if getgenv().ESPGUI_Cleanup then
		pcall(getgenv().ESPGUI_Cleanup)
	end

	if getgenv().ExunysDeveloperAimbot then
		pcall(function()
			getgenv().ExunysDeveloperAimbot:Exit()
		end)
	end
end

--// Cache

local game, workspace = game, workspace
local getrawmetatable, pcall, next, tick, getgenv = getrawmetatable, pcall, next, tick, getgenv
local Vector2new, Vector3zero, CFramenew, Color3fromRGB, Color3fromHSV, Drawingnew = Vector2.new, Vector3.zero, CFrame.new, Color3.fromRGB, Color3.fromHSV, Drawing and Drawing.new
local mousemoverel, mousemoveabs, tablefind, tableremove, stringlower, stringsub, mathclamp = mousemoverel or (Input and Input.MouseMove), mousemoveabs, table.find, table.remove, string.lower, string.sub, math.clamp
local mouse1press, mouse1release, mouse1click, taskwait = mouse1press, mouse1release, mouse1click, task.wait
local clonefunction, cloneref = clonefunction or LPH_NO_VIRTUALIZE(function(...)
	return ...
end), cloneref or LPH_NO_VIRTUALIZE(function(...)
	return ...
end)

local GameMetatable = getrawmetatable and getrawmetatable(game) or {
	__index = LPH_NO_VIRTUALIZE(function(self, Index)
		return self[Index]
	end),

	__newindex = LPH_NO_VIRTUALIZE(function(self, Index, Value)
		self[Index] = Value
	end)
}

local __index = GameMetatable.__index
local __newindex = GameMetatable.__newindex

local getrenderproperty, setrenderproperty = getrenderproperty or __index, setrenderproperty or __newindex

local _GetService = __index(game, "GetService")
local GetService = function(Service)
	return cloneref(_GetService(game, Service))
end

--// Services

local RunService = GetService("RunService")
local UserInputService = GetService("UserInputService")
local Players = GetService("Players")

--// Service Methods

local LocalPlayer = __index(Players, "LocalPlayer")
local Camera = __index(workspace, "CurrentCamera")

local FindFirstChild, FindFirstChildOfClass = __index(game, "FindFirstChild"), __index(game, "FindFirstChildOfClass")
local WorldToViewportPoint = __index(Camera, "WorldToViewportPoint")
local GetPartsObscuringTarget = __index(Camera, "GetPartsObscuringTarget")
local GetMouseLocation = __index(UserInputService, "GetMouseLocation")
local GetPlayers = __index(Players, "GetPlayers")
local GetPlayerFromCharacter = __index(Players, "GetPlayerFromCharacter")
local Mouse = __index(LocalPlayer, "GetMouse")(LocalPlayer)

--// Variables

local Typing, Running, ServiceConnections, OriginalSensitivity = false, false, {}
local SensitivityOverridden, TriggerBusy, LastTick = false, false, tick()
local Connect, Disconnect = __index(game, "DescendantAdded").Connect

do
	local TemporaryConnection = Connect(__index(game, "DescendantAdded"), function() end)
	Disconnect = TemporaryConnection.Disconnect
	Disconnect(TemporaryConnection)
end

--// Environment

getgenv().ExunysDeveloperAimbot = {
	DeveloperSettings = {
		UpdateMode = "RenderStepped",
		TeamCheckOption = "TeamColor",
		RainbowSpeed = 1, -- Bigger = Slower
		DisableWarnings = false
	},

	Settings = {
		Enabled = true,

		TeamCheck = true,
		AliveCheck = true,
		WallCheck = true,

		OffsetToMoveDirection = false,
		OffsetIncrement = 15,

		Sensitivity = 0, -- Smoothing time (seconds) before fully locking onto target
		Sensitivity2 = 1, -- mousemoverel Sensitivity

		LockMode = 1, -- 1 = CFrame; 2 = mousemoverel; 3 = mousemoveabs
		LockPart = "Head",

		TriggerKey = Enum.UserInputType.MouseButton2,
		Toggle = true
	},

	Triggerbot = {
		Enabled = false,

		TeamCheck = false,
		AliveCheck = true,
		AimLockedCheck = false,

		Delay = 0
	},

	ClosestPlayerTracer = {
		Enabled = true,
		Position = 3, -- 1 = Bottom; 2 = Center; 3 = Mouse

		Transparency = 0.5,
		Thickness = 1,

		RainbowColor = false,
		Color = Color3fromRGB(150, 150, 255)
	},

	FOVSettings = {
		Enabled = true,
		Visible = true,

		Radius = 100,
		NumSides = 60,

		Thickness = 1,
		Transparency = 1,
		Filled = false,

		RainbowColor = false,
		RainbowOutlineColor = false,
		Color = Color3fromRGB(255, 255, 255),
		OutlineColor = Color3fromRGB(0, 0, 0),
		LockedColor = Color3fromRGB(255, 150, 150)
	},

	Blacklisted = {},
	FOVCircleOutline = Drawingnew("Circle"),
	FOVCircle = Drawingnew("Circle"),
	Tracer = Drawingnew("Line")
}

local Environment, _warn = getgenv().ExunysDeveloperAimbot, clonefunction(warn); warn = function(...)
	return not Environment.DeveloperSettings.DisableWarnings and _warn(...)
end

setrenderproperty(Environment.FOVCircle, "Visible", false)
setrenderproperty(Environment.FOVCircleOutline, "Visible", false)

--// Render property helpers (only touch Drawing objects when a value actually changed)

local LastValues, ValidProperties = {}, {}

local Apply = function(Object, Property, Value)
	local Cache = LastValues[Object]

	if not Cache then
		Cache = {}
		LastValues[Object] = Cache
	end

	if Cache[Property] ~= Value then
		Cache[Property] = Value
		setrenderproperty(Object, Property, Value)
	end
end

local Sync = function(Object, Settings, Skip)
	local Valid = ValidProperties[Object]

	if not Valid then
		Valid = {}
		ValidProperties[Object] = Valid
	end

	for Index, Value in next, Settings do
		if not Skip[Index] then
			local IsValid = Valid[Index]

			if IsValid == nil then
				IsValid = pcall(getrenderproperty, Object, Index)
				Valid[Index] = IsValid
			end

			if IsValid then
				Apply(Object, Index, Value)
			end
		end
	end
end

local SkipColor, SkipColorThickness = {Color = true}, {Color = true, Thickness = true}

--// Core Functions

local FixUsername = LPH_NO_VIRTUALIZE(function(String)
	for _, Value in next, GetPlayers(Players) do
		local Name = __index(Value, "Name")

		if stringsub(stringlower(Name), 1, #String) == stringlower(String) then
			return Name
		end
	end
end)

local GetRainbowColor = LPH_NO_VIRTUALIZE(function()
	local RainbowSpeed = Environment.DeveloperSettings.RainbowSpeed

	return Color3fromHSV(tick() % RainbowSpeed / RainbowSpeed, 1, 1)
end)

local ConvertVector = LPH_NO_VIRTUALIZE(function(Vector)
	return Vector2new(Vector.X, Vector.Y)
end)

local RefreshCamera = LPH_NO_VIRTUALIZE(function()
	local CurrentCamera = __index(workspace, "CurrentCamera")

	if CurrentCamera and CurrentCamera ~= Camera then
		Camera = CurrentCamera
		WorldToViewportPoint = __index(Camera, "WorldToViewportPoint")
		GetPartsObscuringTarget = __index(Camera, "GetPartsObscuringTarget")
	end
end)

local CancelLock = LPH_NO_VIRTUALIZE(function()
	Environment.Locked = nil

	Apply(Environment.FOVCircle, "Color", Environment.FOVSettings.Color)

	if SensitivityOverridden then
		SensitivityOverridden = false
		__newindex(UserInputService, "MouseDeltaSensitivity", OriginalSensitivity)
	end

	Apply(Environment.Tracer, "Visible", Environment.ClosestPlayerTracer.Enabled)
end)

-- Aux = true: only return the closest valid player (used by the tracer / public API)
local GetClosestPlayer = LPH_NO_VIRTUALIZE(function(Aux, MouseLocation)
	local Settings = Environment.Settings
	local LockPart = Settings.LockPart
	local Locked = Environment.Locked

	if Aux and (Running or Locked) then
		return
	end

	MouseLocation = MouseLocation or GetMouseLocation(UserInputService)

	local FOVSettings = Environment.FOVSettings
	local MaxDistance = FOVSettings.Enabled and FOVSettings.Radius or 2000

	-- Already locked: just verify the target is still valid / inside the FOV
	if Locked then
		local Character = __index(Locked, "Character")
		local Part = Character and FindFirstChild(Character, LockPart)

		if not Part then
			CancelLock()
			return
		end

		local Vector = WorldToViewportPoint(Camera, __index(Part, "Position"))

		if (MouseLocation - ConvertVector(Vector)).Magnitude > MaxDistance then
			CancelLock()
		end

		return
	end

	local TeamCheckOption = Environment.DeveloperSettings.TeamCheckOption
	local LocalTeam = Settings.TeamCheck and __index(LocalPlayer, TeamCheckOption)
	local LocalCharacter = __index(LocalPlayer, "Character")
	local CameraPosition = __index(Camera, "CFrame").Position
	local Blacklisted = Environment.Blacklisted

	local BestDistance, Best3DDistance, Best = MaxDistance, 10000, nil

	for _, Value in next, GetPlayers(Players) do
		if Value == LocalPlayer or (next(Blacklisted) and tablefind(Blacklisted, __index(Value, "Name"))) then
			continue
		end

		local Character = __index(Value, "Character")
		local Part = Character and FindFirstChild(Character, LockPart)
		local Humanoid = Character and FindFirstChildOfClass(Character, "Humanoid")

		if not (Part and Humanoid) then
			continue
		end

		if Settings.TeamCheck and __index(Value, TeamCheckOption) == LocalTeam then
			continue
		end

		if Settings.AliveCheck and __index(Humanoid, "Health") <= 0 then
			continue
		end

		-- Cheap screen / distance checks FIRST
		local PartPosition = __index(Part, "Position")
		local Vector, OnScreen = WorldToViewportPoint(Camera, PartPosition)

		if not OnScreen then
			continue
		end

		local Distance = (MouseLocation - ConvertVector(Vector)).Magnitude
		local Distance3D = (CameraPosition - PartPosition).Magnitude

		if Distance < BestDistance and Distance3D < Best3DDistance then
			-- Expensive wall check LAST, and only for candidates that would actually win.
			-- Ignore list takes instances (descendants are ignored automatically),
			-- so there's no need to build giant GetDescendants tables.
			if Settings.WallCheck then
				local IgnoreList = LocalCharacter and {LocalCharacter, Character} or {Character}

				if #GetPartsObscuringTarget(Camera, {PartPosition}, IgnoreList) > 0 then
					continue
				end
			end

			BestDistance, Best3DDistance, Best = Distance, Distance3D, Value
		end
	end

	if Aux then
		return Best
	end

	if Best then
		Environment.Locked = Best
	end
end)

local Load = function()
	for Index, Connection in next, ServiceConnections do
		pcall(Disconnect, Connection)
		ServiceConnections[Index] = nil
	end

	Running = false
	OriginalSensitivity = __index(UserInputService, "MouseDeltaSensitivity")

	local Settings, Triggerbot, Tracer, FOVCircle, FOVCircleOutline, TracerSettings, FOVSettings = Environment.Settings, Environment.Triggerbot, Environment.Tracer, Environment.FOVCircle, Environment.FOVCircleOutline, Environment.ClosestPlayerTracer, Environment.FOVSettings

	local DeveloperSettings = Environment.DeveloperSettings
	local UpdateMode = DeveloperSettings.UpdateMode
	local TeamCheckOption = DeveloperSettings.TeamCheckOption

	if mouse1press and mouse1release then
		ServiceConnections.Triggerbot = Connect(__index(RunService, UpdateMode), LPH_NO_VIRTUALIZE(function()
			if TriggerBusy or not Triggerbot.Enabled then
				return
			end

			local Target = Mouse.Target

			if not Target then
				return
			end

			local Character = Target.Parent
			local Humanoid = Character and FindFirstChildOfClass(Character, "Humanoid")
			local Player = Character and GetPlayerFromCharacter(Players, Character)

			if Humanoid and Player then
				if Triggerbot.TeamCheck and __index(Player, TeamCheckOption) == __index(LocalPlayer, TeamCheckOption) then
					return
				end

				if Triggerbot.AliveCheck and __index(Humanoid, "Health") <= 0 then
					return
				end

				if Triggerbot.AimLockedCheck and not Environment.Locked then
					return
				end

				TriggerBusy = true -- prevents piling up a new yielding thread every frame

				if Triggerbot.Delay ~= 0 then
					taskwait(Triggerbot.Delay)
				end

				mouse1press(); __index(RunService, UpdateMode):Wait(); mouse1release(); mouse1click(); __index(RunService, UpdateMode):Wait()

				TriggerBusy = false
			end
		end))
	end

	local LastTracerSearch, TracerTarget = 0, nil

	-- Single combined per-frame loop (was two separate loops that each searched for players)
	ServiceConnections.RenderSteppedConnection = Connect(__index(RunService, UpdateMode), LPH_NO_VIRTUALIZE(function()
		local Now = tick()
		local DeltaTime = Now - LastTick
		LastTick = Now

		RefreshCamera()

		local MouseLocation = GetMouseLocation(UserInputService)

		--// Aim

		if Running and Settings.Enabled then
			GetClosestPlayer(false, MouseLocation)

			local Locked = Environment.Locked
			local Character = Locked and __index(Locked, "Character")
			local Part = Character and FindFirstChild(Character, Settings.LockPart)

			if Part then
				local Offset = Vector3zero

				if Settings.OffsetToMoveDirection then
					local Humanoid = FindFirstChildOfClass(Character, "Humanoid")

					if Humanoid then
						Offset = __index(Humanoid, "MoveDirection") * (mathclamp(Settings.OffsetIncrement, 1, 30) / 10)
					end
				end

				local TargetPosition = __index(Part, "Position") + Offset
				local LockedPosition = WorldToViewportPoint(Camera, TargetPosition)

				if Settings.LockMode == 2 then
					mousemoverel((LockedPosition.X - MouseLocation.X) / Settings.Sensitivity2, (LockedPosition.Y - MouseLocation.Y) / Settings.Sensitivity2)
				elseif Settings.LockMode == 3 and mousemoveabs then
					mousemoveabs(LockedPosition.X, LockedPosition.Y)
				else
					local CameraCFrame = __index(Camera, "CFrame")
					local TargetCFrame = CFramenew(CameraCFrame.Position, TargetPosition)

					if Settings.Sensitivity > 0 then
						-- Frame-rate independent smoothing instead of creating a new Tween every frame
						local Alpha = 1 - 0.001 ^ (DeltaTime / Settings.Sensitivity)
						__newindex(Camera, "CFrame", CameraCFrame:Lerp(TargetCFrame, Alpha))
					else
						__newindex(Camera, "CFrame", TargetCFrame)
					end

					if not SensitivityOverridden then
						SensitivityOverridden = true
						__newindex(UserInputService, "MouseDeltaSensitivity", 0)
					end
				end
			end
		end

		--// FOV circle

		if FOVSettings.Enabled and Settings.Enabled then
			Sync(FOVCircle, FOVSettings, SkipColor)
			Sync(FOVCircleOutline, FOVSettings, SkipColorThickness)

			Apply(FOVCircle, "Color", (Environment.Locked and FOVSettings.LockedColor) or (FOVSettings.RainbowColor and GetRainbowColor()) or FOVSettings.Color)
			Apply(FOVCircleOutline, "Color", FOVSettings.RainbowOutlineColor and GetRainbowColor() or FOVSettings.OutlineColor)
			Apply(FOVCircleOutline, "Thickness", FOVSettings.Thickness + 1)
			Apply(FOVCircle, "Position", MouseLocation)
			Apply(FOVCircleOutline, "Position", MouseLocation)
		else
			Apply(FOVCircle, "Visible", false)
			Apply(FOVCircleOutline, "Visible", false)
		end

		--// Tracer

		local ClosestPlayer

		if TracerSettings.Enabled and Settings.Enabled and not Running and not Environment.Locked then
			-- Re-pick the tracer's target ~12x per second instead of every frame.
			-- The line itself (start / end points) still updates every single frame.
			if Now - LastTracerSearch >= 0.08 then
				LastTracerSearch = Now
				TracerTarget = GetClosestPlayer(true, MouseLocation)
			end

			ClosestPlayer = TracerTarget
		else
			TracerTarget = nil
		end

		local TracerCharacter = ClosestPlayer and __index(ClosestPlayer, "Character")
		local TracerPart = TracerCharacter and FindFirstChild(TracerCharacter, Settings.LockPart)

		if TracerPart then
			Apply(Tracer, "Visible", true)
			Sync(Tracer, TracerSettings, SkipColor)
			Apply(Tracer, "Color", TracerSettings.RainbowColor and GetRainbowColor() or TracerSettings.Color)

			local Position = TracerSettings.Position

			if Position == 1 then
				local Size = __index(Camera, "ViewportSize")
				Apply(Tracer, "From", Vector2new(Size.X / 2, Size.Y))
			elseif Position == 2 then
				Apply(Tracer, "From", __index(Camera, "ViewportSize") / 2)
			elseif Position == 3 then
				Apply(Tracer, "From", MouseLocation)
			else
				TracerSettings.Position = 3
			end

			Apply(Tracer, "To", ConvertVector(WorldToViewportPoint(Camera, __index(TracerPart, "Position"))))
		else
			Apply(Tracer, "Visible", false)
		end
	end))

	ServiceConnections.InputBeganConnection = Connect(__index(UserInputService, "InputBegan"), LPH_NO_VIRTUALIZE(function(Input)
		if Typing then
			return
		end

		local TriggerKey = Settings.TriggerKey

		-- HOLD mode: aimlock is active only while the trigger key is held down
		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			Running = true
		end
	end))

	ServiceConnections.InputEndedConnection = Connect(__index(UserInputService, "InputEnded"), LPH_NO_VIRTUALIZE(function(Input)
		local TriggerKey = Settings.TriggerKey

		-- Always release, even if a textbox got focus while the key was held
		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			Running = false; CancelLock()
		end
	end))

	-- Typing checks live in Load so Restart() doesn't permanently lose them
	ServiceConnections.TypingStartedConnection = Connect(__index(UserInputService, "TextBoxFocused"), function()
		Typing = true
	end)

	ServiceConnections.TypingEndedConnection = Connect(__index(UserInputService, "TextBoxFocusReleased"), function()
		Typing = false
	end)
end

--// Interactive User Methods

Environment.Exit = LPH_NO_VIRTUALIZE(function(self) -- ExunysDeveloperAimbot.Exit(self)
	assert(self, "EXUNYS_AIMBOT-V3.Exit: Missing parameter #1 \"self\" <table>.")

	for Index, _ in next, ServiceConnections do
		pcall(Disconnect, ServiceConnections[Index])
	end

	CancelLock()

	Load = nil; ConvertVector = nil; CancelLock = nil; GetClosestPlayer = nil; GetRainbowColor = nil; FixUsername = nil

	self.FOVCircle:Remove()
	self.FOVCircleOutline:Remove()
	self.Tracer:Remove()

	getgenv().ExunysDeveloperAimbot = nil; pcall(collectgarbage, "step", 200)
end)

Environment.Restart = LPH_NO_VIRTUALIZE(function() -- ExunysDeveloperAimbot.Restart(<void>)
	for Index, _ in next, ServiceConnections do
		pcall(Disconnect, ServiceConnections[Index])
	end

	Load()
end)

Environment.Blacklist = LPH_NO_VIRTUALIZE(function(self, Username) -- ExunysDeveloperAimbot.Blacklist(self, <string> Player Name)
	assert(self, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #2 \"Username\" <string>.")

	local Fixed = FixUsername(Username)

	assert(Fixed, "EXUNYS_AIMBOT-V3.Blacklist: User "..Username.." couldn't be found.")

	self.Blacklisted[#self.Blacklisted + 1] = Fixed
end)

Environment.Whitelist = LPH_NO_VIRTUALIZE(function(self, Username) -- ExunysDeveloperAimbot.Whitelist(self, <string> Player Name)
	assert(self, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #2 \"Username\" <string>.")

	local Fixed = FixUsername(Username)

	assert(Fixed, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." couldn't be found.")

	local Index = tablefind(self.Blacklisted, Fixed)

	assert(Index, "EXUNYS_AIMBOT-V3.Whitelist: User "..Fixed.." is not blacklisted.")

	tableremove(self.Blacklisted, Index)
end)

Environment.GetClosestPlayer = LPH_NO_VIRTUALIZE(function() -- ExunysDeveloperAimbot.GetClosestPlayer(<void>)
	return GetClosestPlayer(true)
end)

Environment.Load = Load -- ExunysDeveloperAimbot.Load()

setmetatable(Environment, {__call = Load})

--// ESP + GUI

do
	local ParentTarget = (gethui and gethui()) or GetService("CoreGui")
	local TrackedConnections = {}

	local Track = function(Connection)
		TrackedConnections[#TrackedConnections + 1] = Connection
		return Connection
	end

	local Create = function(Class, Properties, Parent)
		local Object = Instance.new(Class)

		for Property, Value in next, Properties do
			Object[Property] = Value
		end

		Object.Parent = Parent
		return Object
	end

	--// ESP

	local ESPSettings = {
		Enabled = true,
		Names = false,
		ShowTeammates = true, -- true = everyone (incl. teammates); false = enemies only
		OutlineTransparency = 0,
		FillTransparency = 1, -- 1 = outline only
		NoTeamColor = Color3fromRGB(255, 255, 255)
	}

	local ESPContainer = Create("Folder", {Name = "ESPContainer"}, ParentTarget)
	local Entries, PlayerConnections, Pending = {}, {}, {}

	local SetProperty = function(Object, Property, Value) -- only write when changed
		if Object[Property] ~= Value then
			Object[Property] = Value
		end
	end

	local GetTeamColor = function(Player)
		if Player.Team then
			return Player.TeamColor.Color
		end

		return ESPSettings.NoTeamColor
	end

	local UpdateESP = function(Player)
		local Entry = Entries[Player]

		if not Entry then
			return
		end

		local Character = Player.Character
		local Hidden = not ESPSettings.ShowTeammates and Player.Team ~= nil and Player.Team == LocalPlayer.Team
		local Show = ESPSettings.Enabled and not Hidden and Character ~= nil
		local Head = Character and (FindFirstChild(Character, "Head") or FindFirstChild(Character, "HumanoidRootPart"))
		local Color = GetTeamColor(Player)

		SetProperty(Entry.Highlight, "Adornee", Character)
		SetProperty(Entry.Highlight, "OutlineColor", Color)
		SetProperty(Entry.Highlight, "OutlineTransparency", ESPSettings.OutlineTransparency)
		SetProperty(Entry.Highlight, "FillTransparency", ESPSettings.FillTransparency)
		SetProperty(Entry.Highlight, "Enabled", Show)

		SetProperty(Entry.Billboard, "Adornee", Head)
		SetProperty(Entry.Label, "TextColor3", Color)
		SetProperty(Entry.Billboard, "Enabled", Show and ESPSettings.Names and Head ~= nil)
	end

	-- Several events often fire together (respawn + team change); merge them into one update
	local ScheduleESP = function(Player)
		if Pending[Player] then
			return
		end

		Pending[Player] = true

		task.defer(function()
			Pending[Player] = nil
			UpdateESP(Player)
		end)
	end

	local RefreshESP = function()
		for Player in next, Entries do
			UpdateESP(Player)
		end
	end

	local AddESPPlayer = function(Player)
		if Player == LocalPlayer or Entries[Player] then
			return
		end

		local Highlight = Create("Highlight", {
			Name = Player.Name,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, -- visible through walls
			FillColor = Color3.new(0, 0, 0),
			Enabled = false
		}, ESPContainer)

		local Billboard = Create("BillboardGui", {
			Name = Player.Name,
			AlwaysOnTop = true,
			Size = UDim2.fromOffset(120, 18),
			StudsOffset = Vector3.new(0, 2.2, 0),
			Enabled = false
		}, ESPContainer)

		local Label = Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = Player.Name,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextStrokeTransparency = 0.4,
			TextColor3 = ESPSettings.NoTeamColor
		}, Billboard)

		Entries[Player] = {Highlight = Highlight, Billboard = Billboard, Label = Label}

		PlayerConnections[Player] = {
			Player.CharacterAdded:Connect(function(Character)
				ScheduleESP(Player)

				task.spawn(function() -- the head may not exist yet when the character spawns
					if Character:WaitForChild("Head", 5) then
						ScheduleESP(Player)
					end
				end)
			end),
			Player:GetPropertyChangedSignal("Team"):Connect(function()
				ScheduleESP(Player)
			end),
			Player:GetPropertyChangedSignal("TeamColor"):Connect(function()
				ScheduleESP(Player)
			end)
		}

		UpdateESP(Player)
	end

	local RemoveESPPlayer = function(Player)
		Pending[Player] = nil

		if PlayerConnections[Player] then
			for _, Connection in next, PlayerConnections[Player] do
				Connection:Disconnect()
			end

			PlayerConnections[Player] = nil
		end

		local Entry = Entries[Player]

		if Entry then
			Entry.Highlight:Destroy()
			Entry.Billboard:Destroy()
			Entries[Player] = nil
		end
	end

	for _, Player in next, GetPlayers(Players) do
		AddESPPlayer(Player)
	end

	Track(Players.PlayerAdded:Connect(AddESPPlayer))
	Track(Players.PlayerRemoving:Connect(RemoveESPPlayer))
	Track(LocalPlayer:GetPropertyChangedSignal("Team"):Connect(RefreshESP))

	--// GUI

	local Colors = {
		Background = Color3fromRGB(22, 22, 26),
		Title = Color3fromRGB(30, 30, 36),
		Button = Color3fromRGB(36, 36, 43),
		Stroke = Color3fromRGB(52, 52, 60),
		Text = Color3fromRGB(205, 205, 212),
		AimOn = Color3fromRGB(70, 140, 255), -- aimlock toggles: blue when ON
		ESPOn = Color3fromRGB(235, 75, 75), -- ESP toggles: red when ON
		Off = Color3fromRGB(70, 70, 80),
		Knob = Color3fromRGB(235, 235, 240)
	}

	local ScreenGui = Create("ScreenGui", {
		Name = "ControlPanel",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100
	}, ParentTarget)

	local Frame = Create("Frame", {
		Size = UDim2.fromOffset(230, 232), -- 5 rows + a gap between the aimlock and ESP groups
		Active = true,
		Position = UDim2.fromOffset(12, 200),
		BackgroundColor3 = Colors.Background,
		BorderSizePixel = 0
	}, ScreenGui)

	Create("UICorner", {CornerRadius = UDim.new(0, 6)}, Frame)
	Create("UIStroke", {Color = Colors.Stroke, Thickness = 1}, Frame)

	local TitleBar = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Colors.Title,
		BorderSizePixel = 0
	}, Frame)

	Create("UICorner", {CornerRadius = UDim.new(0, 6)}, TitleBar)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -8, 1, 0),
		Text = "Control Panel   [Alt] hide",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left
	}, TitleBar)

	local List = Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 34),
		Size = UDim2.new(1, -16, 1, -44)
	}, Frame)

	Create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, List)

	local AddToggle = function(Text, Initial, Callback, OnColor, Order)
		local State = Initial

		local Button = Create("TextButton", {
			Size = UDim2.new(1, 0, 0.2, -6), -- 5 rows share the height (the group gap is accounted for), so rows grow when the panel is resized
			LayoutOrder = Order,
			BackgroundColor3 = Colors.Button,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = ""
		}, List)

		Create("UICorner", {CornerRadius = UDim.new(0, 4)}, Button)

		local ToggleLabel = Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -52, 1, 0),
			Text = Text,
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextColor3 = Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left
		}, Button)

		Create("UITextSizeConstraint", {MinTextSize = 6, MaxTextSize = 14}, ToggleLabel)

		local Pill = Create("Frame", {
			AnchorPoint = Vector2new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(30, 14),
			BackgroundColor3 = Colors.Off,
			BorderSizePixel = 0
		}, Button)

		Create("UICorner", {CornerRadius = UDim.new(1, 0)}, Pill)

		local Knob = Create("Frame", {
			AnchorPoint = Vector2new(0, 0.5),
			Position = UDim2.new(0, 2, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = Colors.Knob,
			BorderSizePixel = 0
		}, Pill)

		Create("UICorner", {CornerRadius = UDim.new(1, 0)}, Knob)

		local Render = function()
			Pill.BackgroundColor3 = State and OnColor or Colors.Off
			Knob.Position = State and UDim2.new(1, -12, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
		end

		Render()

		Track(Button.MouseButton1Click:Connect(function()
			State = not State
			Render()
			Callback(State)
		end))
	end

	AddToggle("Toggle Aimbot", Environment.Settings.Enabled, function(State)
		Environment.Settings.Enabled = State

		if not State and CancelLock then
			CancelLock() -- releases the target and restores mouse sensitivity
		end
	end, Colors.AimOn, 1)

	AddToggle("Aimlock Team Check", Environment.Settings.TeamCheck, function(State)
		Environment.Settings.TeamCheck = State -- ON = ignore teammates, OFF = lock anyone

		if CancelLock then
			CancelLock() -- drop the current target so the new rule applies immediately
		end
	end, Colors.AimOn, 2)

	-- Small gap between the aimlock group and the ESP group
	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 3
	}, List)

	AddToggle("Toggle ESP", ESPSettings.Enabled, function(State)
		ESPSettings.Enabled = State
		RefreshESP()
	end, Colors.ESPOn, 4)

	AddToggle("Toggle ESP Names", ESPSettings.Names, function(State)
		ESPSettings.Names = State
		RefreshESP()
	end, Colors.ESPOn, 5)

	AddToggle("Toggle Teammate ESP", ESPSettings.ShowTeammates, function(State)
		ESPSettings.ShowTeammates = State -- ON = everyone, OFF = enemies only
		RefreshESP()
	end, Colors.ESPOn, 6)

	--// Dragging (title bar) + resizing (grip in the bottom-right corner)

	local Grip = Create("Frame", {
		AnchorPoint = Vector2new(1, 1),
		Position = UDim2.new(1, -3, 1, -3),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Colors.Stroke,
		BorderSizePixel = 0,
		Active = true
	}, Frame)

	Create("UICorner", {CornerRadius = UDim.new(0, 3)}, Grip)

	local MinSize, MaxSize = Vector2new(170, 165), Vector2new(480, 400)
	local Dragging, Resizing, DragStart, StartPosition, StartSize

	local IsPointer = function(Input)
		return Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
	end

	Track(TitleBar.InputBegan:Connect(function(Input)
		if IsPointer(Input) then
			Dragging, DragStart, StartPosition = true, Input.Position, Frame.Position
		end
	end))

	Track(Grip.InputBegan:Connect(function(Input)
		if IsPointer(Input) then
			Resizing, DragStart, StartSize = true, Input.Position, Frame.AbsoluteSize
		end
	end))

	Track(UserInputService.InputChanged:Connect(function(Input)
		if not (Dragging or Resizing) then
			return
		end

		if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local Delta = Input.Position - DragStart

		if Dragging then
			Frame.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
		else
			Frame.Size = UDim2.fromOffset(
				mathclamp(StartSize.X + Delta.X, MinSize.X, MaxSize.X),
				mathclamp(StartSize.Y + Delta.Y, MinSize.Y, MaxSize.Y)
			)
		end
	end))

	Track(UserInputService.InputEnded:Connect(function(Input)
		if IsPointer(Input) then
			Dragging, Resizing = false, false
		end
	end))

	--// Alt = show / hide the panel

	Track(UserInputService.InputBegan:Connect(function(Input)
		if (Input.KeyCode == Enum.KeyCode.LeftAlt or Input.KeyCode == Enum.KeyCode.RightAlt) and not UserInputService:GetFocusedTextBox() then
			ScreenGui.Enabled = not ScreenGui.Enabled
		end
	end))

	--// Startup notification (slides in at the top, then fades away)

	local Notice = Create("ScreenGui", {
		Name = "StartupNotice",
		ResetOnSpawn = false,
		DisplayOrder = 101
	}, ParentTarget)

	local NoticeFrame = Create("Frame", {
		AnchorPoint = Vector2new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -40),
		Size = UDim2.fromOffset(230, 30),
		BackgroundColor3 = Colors.Background,
		BorderSizePixel = 0
	}, Notice)

	Create("UICorner", {CornerRadius = UDim.new(0, 6)}, NoticeFrame)
	Create("UIStroke", {Color = Colors.Stroke, Thickness = 1}, NoticeFrame)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "Aimbot V3 fork by Beast",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Colors.Text
	}, NoticeFrame)

	task.spawn(pcall, function()
		local TweenService = GetService("TweenService")

		TweenService:Create(NoticeFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 10)}):Play()
		task.wait(3.5)

		local Out = TweenService:Create(NoticeFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0, -40)})
		Out:Play()
		Out.Completed:Wait()

		Notice:Destroy()
	end)

	--// Cleanup (re-running the script removes the old ESP + GUI)

	getgenv().ESPGUI_Cleanup = function()
		for _, Connection in next, TrackedConnections do
			pcall(Disconnect, Connection)
		end

		for Player in next, Entries do
			RemoveESPPlayer(Player)
		end

		ESPContainer:Destroy()
		ScreenGui:Destroy()
		Notice:Destroy()

		getgenv().ESPGUI_Cleanup = nil
	end
end

--// Start the aimbot (this is what wires up the trigger key and the render loop)
Load()

--// Start notification (bottom-right, slides in, then fades out)

do
	local TweenService = GetService("TweenService")
	local ParentTarget = (gethui and gethui()) or GetService("CoreGui")

	task.spawn(function()
		local Old = ParentTarget:FindFirstChild("AimlockNotification")

		if Old then
			Old:Destroy()
		end

		local Gui = Instance.new("ScreenGui")
		Gui.Name = "AimlockNotification"
		Gui.ResetOnSpawn = false
		Gui.DisplayOrder = 101
		Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		local Group = Instance.new("CanvasGroup") -- lets the whole card fade as one piece
		Group.AnchorPoint = Vector2new(1, 1)
		Group.Size = UDim2.fromOffset(300, 40)
		Group.Position = UDim2.new(1, 320, 1, -16) -- starts off-screen (right)
		Group.BackgroundColor3 = Color3fromRGB(22, 22, 26)
		Group.BorderSizePixel = 0
		Group.GroupTransparency = 1
		Group.Parent = Gui

		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(0, 6)
		Corner.Parent = Group

		local Stroke = Instance.new("UIStroke")
		Stroke.Color = Color3fromRGB(52, 52, 60)
		Stroke.Thickness = 1
		Stroke.Parent = Group

		local Accent = Instance.new("Frame")
		Accent.Size = UDim2.new(0, 3, 1, 0)
		Accent.BackgroundColor3 = Color3fromRGB(90, 200, 130)
		Accent.BorderSizePixel = 0
		Accent.Parent = Group

		local Label = Instance.new("TextLabel")
		Label.BackgroundTransparency = 1
		Label.Position = UDim2.fromOffset(14, 0)
		Label.Size = UDim2.new(1, -20, 1, 0)
		Label.Text = "Aimbot V3 fork by BeastGotNoChillz"
		Label.Font = Enum.Font.GothamMedium
		Label.TextSize = 13
		Label.TextColor3 = Color3fromRGB(220, 220, 228)
		Label.TextXAlignment = Enum.TextXAlignment.Left
		Label.Parent = Group

		Gui.Parent = ParentTarget

		local SlideIn = TweenService:Create(Group, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.new(1, -16, 1, -16),
			GroupTransparency = 0
		})

		SlideIn:Play()
		SlideIn.Completed:Wait()

		task.wait(3.5)

		local SlideOut = TweenService:Create(Group, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 320, 1, -16),
			GroupTransparency = 1
		})

		SlideOut:Play()
		SlideOut.Completed:Wait()

		Gui:Destroy()
	end)
end

return Environment
