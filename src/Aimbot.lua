--[[

	Universal Aimbot Module by Exunys © CC0 1.0 Universal (2023)
	https://github.com/Exunys

	Performance-optimized revision.

]]

--// Luraph Macros

if LPH_OBFUSCATED == nil then
	LPH_NO_VIRTUALIZE = function(...)
		return ...
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
		if Value == LocalPlayer or tablefind(Blacklisted, __index(Value, "Name")) then
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

		local ClosestPlayer = TracerSettings.Enabled and Settings.Enabled and GetClosestPlayer(true, MouseLocation)
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

		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle

		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			if Toggle then
				Running = not Running

				if not Running then
					CancelLock()
				end
			else
				Running = true
			end
		end
	end))

	ServiceConnections.InputEndedConnection = Connect(__index(UserInputService, "InputEnded"), LPH_NO_VIRTUALIZE(function(Input)
		if Typing or Settings.Toggle then
			return
		end

		local TriggerKey = Settings.TriggerKey

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

return Environment
