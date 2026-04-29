local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local camera = workspace.CurrentCamera

local antiCheat = ReplicatedStorage.Events.AntiCheat_TileWashed
local powerWashTargets = workspace.PowerWashTargets
local brainrotsFolder = workspace.Game.Brainrots
local brainrotAssets = ReplicatedStorage.Assets.Brainrots

local PLACE_ID = 126349562582764
local BASE_SPEED = 50
local ZONE1_POSITION = Vector3.new(32.067, 12.831, -141.121)

local settings = {
	clearRadius = 12,
	batchSize = 5,
	checkInterval = 0.1,
}

-- ── TILE CACHE ────────────────────────────────────────────────────────────────

local tileSet = {}

local function addTile(tile)
	if tile:IsA("BasePart") and tile:GetAttribute("IsPowerWashTile") then
		tileSet[tile] = true
	end
end

for _, tile in ipairs(powerWashTargets:GetChildren()) do
	addTile(tile)
end

powerWashTargets.ChildAdded:Connect(addTile)
powerWashTargets.ChildRemoved:Connect(function(tile)
	tileSet[tile] = nil
end)

-- ── BRAINROT NAMES ────────────────────────────────────────────────────────────

local brainrotNames = {"Any"}
for _, asset in ipairs(brainrotAssets:GetChildren()) do
	table.insert(brainrotNames, asset.Name)
end

-- ── SHARED ESP STATE ──────────────────────────────────────────────────────────

local highlightColor = Color3.fromRGB(255, 200, 0)
local rainbowEnabled = false
local rainbowHue = 0
local rainbowConnection = nil
local highlightFilter = "Any"

local function matchesBrainrot(model, filter)
	if filter == "Any" then return true end
	return model.Name == filter
end

-- ── HIGHLIGHT SYSTEM ──────────────────────────────────────────────────────────

local highlights = {}

local function addHighlight(model)
	if highlights[model] then return end
	local h = Instance.new("SelectionBox")
	h.Adornee = model
	h.Color3 = highlightColor
	h.LineThickness = 0.05
	h.SurfaceTransparency = 0.7
	h.SurfaceColor3 = highlightColor
	h.Parent = model
	highlights[model] = h
end

local function removeHighlight(model)
	if highlights[model] then
		highlights[model]:Destroy()
		highlights[model] = nil
	end
end

local function clearAllHighlights()
	for model in pairs(highlights) do
		removeHighlight(model)
	end
end

local function updateHighlightColors(color)
	for _, h in pairs(highlights) do
		h.Color3 = color
		h.SurfaceColor3 = color
	end
end

-- ── TRACER SYSTEM ─────────────────────────────────────────────────────────────

local tracerGui = Instance.new("ScreenGui")
tracerGui.Name = "BrainrotTracers"
tracerGui.ResetOnSpawn = false
tracerGui.IgnoreGuiInset = true
tracerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
tracerGui.Parent = player.PlayerGui

local tracers = {}
local tracerEnabled = false
local tracerUpdateConnection = nil

local function getOrigin()
	local vp = camera.ViewportSize
	return Vector2.new(vp.X / 2, vp.Y) -- bottom center of screen
end

local function addTracer(model)
	if tracers[model] then return end
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.BorderSizePixel = 0
	line.BackgroundColor3 = highlightColor
	line.Size = UDim2.fromOffset(0, 2)
	line.Visible = false
	line.Parent = tracerGui
	tracers[model] = line
end

local function removeTracer(model)
	if tracers[model] then
		tracers[model]:Destroy()
		tracers[model] = nil
	end
end

local function clearAllTracers()
	for model in pairs(tracers) do
		removeTracer(model)
	end
end

local function updateTracers(color)
	local origin = getOrigin()
	for model, line in pairs(tracers) do
		if not model or not model.Parent then
			line:Destroy()
			tracers[model] = nil
		else
			local primary = model:IsA("Model") and model.PrimaryPart or (model:IsA("BasePart") and model or nil)
			if primary then
				local screenPos, onScreen = camera:WorldToViewportPoint(primary.Position)
				local target = Vector2.new(screenPos.X, screenPos.Y)
				if onScreen then
					local diff = target - origin
					local dist = diff.Magnitude
					local angle = math.atan2(diff.Y, diff.X)
					line.Visible = true
					line.Size = UDim2.fromOffset(dist, 2)
					line.Position = UDim2.fromOffset(origin.X, origin.Y)
					line.Rotation = math.deg(angle)
					line.BackgroundColor3 = color
				else
					line.Visible = false
				end
			end
		end
	end
end

-- ── SHARED RAINBOW LOOP ───────────────────────────────────────────────────────
-- Drives both highlights and tracers from one heartbeat connection

local function startRainbow()
	if rainbowConnection then rainbowConnection:Disconnect() end
	rainbowConnection = RunService.Heartbeat:Connect(function(dt)
		rainbowHue = (rainbowHue + dt * 0.3) % 1
		local color = Color3.fromHSV(rainbowHue, 1, 1)
		updateHighlightColors(color)
		if tracerEnabled then
			updateTracers(color)
		end
	end)
end

local function stopRainbow()
	if rainbowConnection then
		rainbowConnection:Disconnect()
		rainbowConnection = nil
	end
	updateHighlightColors(highlightColor)
	updateTracers(highlightColor)
end

-- ── FLUENT UI ─────────────────────────────────────────────────────────────────

local Window = Fluent:CreateWindow({
	Title = "Power Wash For Brainrot GUI",
	SubTitle = "by Scrumpyducks",
	TabWidth = 160,
	Size = UDim2.fromOffset(580, 450),
	Acrylic = false,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
	Main     = Window:AddTab({ Title = "Main",     Icon = "brush"           }),
	Travel   = Window:AddTab({ Title = "Travel",   Icon = "map-pin"         }),
	Brainrot = Window:AddTab({ Title = "Brainrot", Icon = "star"            }),
	Player   = Window:AddTab({ Title = "Player",   Icon = "person-standing" }),
}

-- ── MAIN TAB ──────────────────────────────────────────────────────────────────

Tabs.Main:AddParagraph({
	Title = "Auto Tile Cleaner",
	Content = "Walk through zones normally. Tiles ahead of you will be automatically cleared and registered.",
})

local running = false
local totalCleared = 0

Tabs.Main:AddToggle("AutoClear", {
	Title = "Auto Tile Cleaner",
	Description = "Clears tiles in front of you as you walk through zones.",
	Default = false,
}):OnChanged(function(value)
	running = value
	if running then
		task.spawn(function()
			while running do
				local playerPos = humanoidRootPart.Position
				local playerLook = humanoidRootPart.CFrame.LookVector
				local cleared = 0
				for tile in pairs(tileSet) do
					if cleared >= settings.batchSize then break end
					local offset = tile.Position - playerPos
					local dist = offset.Magnitude
					if dist <= settings.clearRadius and offset.Unit:Dot(playerLook) > -0.5 then
						tileSet[tile] = nil
						antiCheat:FireServer(tile)
						tile:Destroy()
						totalCleared += 1
						cleared += 1
					end
				end
				task.wait(settings.checkInterval)
			end
		end)
	end
end)

Tabs.Main:AddSlider("ClearRadius", {
	Title = "Clear Radius",
	Description = "How far ahead tiles are cleared (studs).",
	Default = 12, Min = 4, Max = 50, Rounding = 0,
}):OnChanged(function(value) settings.clearRadius = value end)

Tabs.Main:AddSlider("BatchSize", {
	Title = "Batch Size",
	Description = "How many tiles are cleared per cycle.",
	Default = 5, Min = 1, Max = 30, Rounding = 0,
}):OnChanged(function(value) settings.batchSize = value end)

Tabs.Main:AddSlider("CheckInterval", {
	Title = "Check Interval",
	Description = "Speed of each clear cycle. Higher = faster.",
	Default = 10, Min = 1, Max = 30, Rounding = 0,
}):OnChanged(function(value) settings.checkInterval = value / 100 end)

-- ── TRAVEL TAB ────────────────────────────────────────────────────────────────

Tabs.Travel:AddParagraph({
	Title = "Return to Start",
	Content = "Teleports you back to the Zone 1 area.",
})

Tabs.Travel:AddButton({
	Title = "Teleport to Zone 1",
	Description = "Returns you to the beginning of the map.",
	Callback = function()
		humanoidRootPart.CFrame = CFrame.new(ZONE1_POSITION + Vector3.new(0, 5, 0))
		Fluent:Notify({ Title = "Travel", Content = "Teleported to Zone 1.", Duration = 3 })
	end,
})

Tabs.Travel:AddButton({
	Title = "Relog",
	Description = "Rejoins a fresh server. Useful for testing.",
	Callback = function()
		Fluent:Notify({ Title = "Relog", Content = "Rejoining server...", Duration = 3 })
		task.wait(1)
		TeleportService:Teleport(PLACE_ID, player)
	end,
})

-- ── BRAINROT TAB ──────────────────────────────────────────────────────────────

Tabs.Brainrot:AddParagraph({
	Title = "Brainrot Tools",
	Content = "Highlight, trace, and auto-collect brainrots. Color picker and rainbow apply to both highlights and tracers.",
})

local highlightEnabled = false
local walkFilter = "Any"
local autoWalking = false

-- Shared filter
Tabs.Brainrot:AddDropdown("HighlightFilter", {
	Title = "ESP Filter",
	Description = "Which brainrot type to highlight and trace.",
	Values = brainrotNames,
	Default = "Any",
}):OnChanged(function(value)
	highlightFilter = value
	if highlightEnabled then
		clearAllHighlights()
		for _, model in ipairs(brainrotsFolder:GetChildren()) do
			if matchesBrainrot(model, highlightFilter) then addHighlight(model) end
		end
	end
	if tracerEnabled then
		clearAllTracers()
		for _, model in ipairs(brainrotsFolder:GetChildren()) do
			if matchesBrainrot(model, highlightFilter) then addTracer(model) end
		end
	end
end)

-- Shared color picker
Tabs.Brainrot:AddColorpicker("HighlightColor", {
	Title = "ESP Color",
	Default = Color3.fromRGB(255, 200, 0),
}):OnChanged(function(value)
	highlightColor = value
	if not rainbowEnabled then
		updateHighlightColors(highlightColor)
		updateTracers(highlightColor)
	end
end)

-- Shared rainbow toggle
Tabs.Brainrot:AddToggle("RainbowHighlight", {
	Title = "Rainbow",
	Description = "Cycles highlight and tracer colors through a rainbow.",
	Default = false,
}):OnChanged(function(value)
	rainbowEnabled = value
	if rainbowEnabled then startRainbow() else stopRainbow() end
end)

-- Highlight toggle
Tabs.Brainrot:AddToggle("BrainrotHighlight", {
	Title = "Brainrot Highlighter",
	Description = "Draws a colored box around matching brainrots.",
	Default = false,
}):OnChanged(function(value)
	highlightEnabled = value
	if highlightEnabled then
		for _, model in ipairs(brainrotsFolder:GetChildren()) do
			if matchesBrainrot(model, highlightFilter) then addHighlight(model) end
		end
		brainrotsFolder.ChildAdded:Connect(function(model)
			if highlightEnabled and matchesBrainrot(model, highlightFilter) then addHighlight(model) end
		end)
		brainrotsFolder.ChildRemoved:Connect(function(model) removeHighlight(model) end)
	else
		clearAllHighlights()
	end
end)

-- Tracer toggle
Tabs.Brainrot:AddToggle("BrainrotTracers", {
	Title = "Brainrot Tracers",
	Description = "Draws ESP lines from the bottom of your screen to each brainrot.",
	Default = false,
}):OnChanged(function(value)
	tracerEnabled = value
	if tracerEnabled then
		for _, model in ipairs(brainrotsFolder:GetChildren()) do
			if matchesBrainrot(model, highlightFilter) then addTracer(model) end
		end
		brainrotsFolder.ChildAdded:Connect(function(model)
			if tracerEnabled and matchesBrainrot(model, highlightFilter) then addTracer(model) end
		end)
		brainrotsFolder.ChildRemoved:Connect(function(model) removeTracer(model) end)
		-- Start update loop
		tracerUpdateConnection = RunService.RenderStepped:Connect(function()
			if not rainbowEnabled then
				updateTracers(highlightColor)
			end
		end)
	else
		clearAllTracers()
		if tracerUpdateConnection then
			tracerUpdateConnection:Disconnect()
			tracerUpdateConnection = nil
		end
	end
end)

-- Walk filter
Tabs.Brainrot:AddDropdown("WalkFilter", {
	Title = "Walk Filter",
	Description = "Which brainrot type to walk towards and collect.",
	Values = brainrotNames,
	Default = "Any",
}):OnChanged(function(value)
	walkFilter = value
end)

-- Auto walk + pickup
Tabs.Brainrot:AddToggle("AutoWalk", {
	Title = "Auto Walk & Pickup",
	Description = "Walks to nearest matching brainrot and picks it up.",
	Default = false,
}):OnChanged(function(value)
	autoWalking = value
	if autoWalking then
		task.spawn(function()
			while autoWalking do
				local closest = nil
				local closestDist = math.huge
				local playerPos = humanoidRootPart.Position

				for _, model in ipairs(brainrotsFolder:GetChildren()) do
					if matchesBrainrot(model, walkFilter) then
						local primary = model:IsA("Model") and model.PrimaryPart or (model:IsA("BasePart") and model or nil)
						if primary then
							local dist = (primary.Position - playerPos).Magnitude
							if dist < closestDist then
								closestDist = dist
								closest = primary
							end
						end
					end
				end

				if closest then
					local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
					local success = pcall(function()
						path:ComputeAsync(playerPos, closest.Position)
					end)

					if success and path.Status == Enum.PathStatus.Success then
						for _, waypoint in ipairs(path:GetWaypoints()) do
							if not autoWalking then break end
							if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
							humanoid:MoveTo(waypoint.Position)
							humanoid.MoveToFinished:Wait(3)
						end
					else
						humanoid:MoveTo(closest.Position)
						humanoid.MoveToFinished:Wait(5)
					end

					if closest and closest.Parent then
						local searchRoot = closest.Parent or closest
						for _, desc in ipairs(searchRoot:GetDescendants()) do
							if desc:IsA("ProximityPrompt") and desc.Enabled then
								fireproximityprompt(desc)
								break
							end
						end
					end
				end

				task.wait(0.5)
			end
			humanoid:MoveTo(humanoidRootPart.Position)
		end)
	else
		humanoid:MoveTo(humanoidRootPart.Position)
	end
end)

-- ── PLAYER TAB ────────────────────────────────────────────────────────────────

local currentSpeed = BASE_SPEED

Tabs.Player:AddSlider("SpeedSlider", {
	Title = "Walk Speed",
	Description = "Set your walk speed. Base is " .. BASE_SPEED .. ".",
	Default = BASE_SPEED, Min = BASE_SPEED, Max = 500, Rounding = 0,
}):OnChanged(function(value)
	currentSpeed = value
	humanoid.WalkSpeed = value
end)

Tabs.Player:AddToggle("SpeedBoost", {
	Title = "Speed Boost",
	Description = "Applies the walk speed from the slider above.",
	Default = false,
}):OnChanged(function(value)
	humanoid.WalkSpeed = value and currentSpeed or BASE_SPEED
end)

-- ── INIT ──────────────────────────────────────────────────────────────────────

Window:SelectTab(1)
Fluent:Notify({
	Title = "Power Wash For Brainrot GUI",
	Content = "Loaded successfully.",
	Duration = 4,
})