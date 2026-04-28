local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

local antiCheat = ReplicatedStorage.Events.AntiCheat_TileWashed
local powerWashTargets = workspace.PowerWashTargets
local brainrotsFolder = workspace.Game.Brainrots
local brainrotAssets = ReplicatedStorage.Assets.Brainrots

local CLEAR_RADIUS = 12
local BATCH_SIZE = 5
local CHECK_INTERVAL = 0.1
local PLACE_ID = 126349562582764
local BASE_SPEED = 50
local BOOST_SPEED = 100
local ZONE1_POSITION = Vector3.new(32.067, 12.831, -141.121)

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

-- ── HIGHLIGHT CACHE ───────────────────────────────────────────────────────────

local highlights = {}

local function addHighlight(model)
	if highlights[model] then return end
	local h = Instance.new("SelectionBox")
	h.Adornee = model
	h.Color3 = Color3.fromRGB(255, 200, 0)
	h.LineThickness = 0.05
	h.SurfaceTransparency = 0.7
	h.SurfaceColor3 = Color3.fromRGB(255, 200, 0)
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
	for model, _ in pairs(highlights) do
		removeHighlight(model)
	end
end

local function matchesBrainrot(model, filter)
	if filter == "Any" then return true end
	return model.Name == filter
end

-- ── FLUENT UI ─────────────────────────────────────────────────────────────────

local Window = Fluent:CreateWindow({
	Title = "Power Wash For Brainrot GUI",
	SubTitle = "by Scrumpyducks",
	TabWidth = 160,
	Size = UDim2.fromOffset(560, 400),
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
					if cleared >= BATCH_SIZE then break end
					local offset = tile.Position - playerPos
					local dist = offset.Magnitude
					if dist <= CLEAR_RADIUS and offset.Unit:Dot(playerLook) > -0.5 then
						tileSet[tile] = nil
						antiCheat:FireServer(tile)
						tile:Destroy()
						totalCleared += 1
						cleared += 1
					end
				end

				task.wait(CHECK_INTERVAL)
			end
		end)
	end
end)

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
	Content = "Highlight and auto-walk to brainrots. Select 'Any' to target all, or pick a specific brainrot.",
})

local highlightFilter = "Any"
local walkFilter = "Any"
local highlightEnabled = false
local autoWalking = false

-- Highlight dropdown
Tabs.Brainrot:AddDropdown("HighlightFilter", {
	Title = "Highlight Filter",
	Description = "Which brainrot type to highlight.",
	Values = brainrotNames,
	Default = "Any",
}):OnChanged(function(value)
	highlightFilter = value
	-- Refresh highlights if active
	if highlightEnabled then
		clearAllHighlights()
		for _, model in ipairs(brainrotsFolder:GetChildren()) do
			if matchesBrainrot(model, highlightFilter) then
				addHighlight(model)
			end
		end
	end
end)

Tabs.Brainrot:AddToggle("BrainrotHighlight", {
	Title = "Brainrot Highlighter",
	Description = "Draws a yellow box around matching brainrots.",
	Default = false,
}):OnChanged(function(value)
	highlightEnabled = value
	if highlightEnabled then
		for _, model in ipairs(brainrotsFolder:GetChildren()) do
			if matchesBrainrot(model, highlightFilter) then
				addHighlight(model)
			end
		end
		brainrotsFolder.ChildAdded:Connect(function(model)
			if highlightEnabled and matchesBrainrot(model, highlightFilter) then
				addHighlight(model)
			end
		end)
		brainrotsFolder.ChildRemoved:Connect(function(model)
			removeHighlight(model)
		end)
	else
		clearAllHighlights()
	end
end)

-- Walk dropdown
Tabs.Brainrot:AddDropdown("WalkFilter", {
	Title = "Walk Filter",
	Description = "Which brainrot type to walk towards.",
	Values = brainrotNames,
	Default = "Any",
}):OnChanged(function(value)
	walkFilter = value
end)

Tabs.Brainrot:AddToggle("AutoWalk", {
	Title = "Auto Walk to Nearest Brainrot",
	Description = "Automatically pathfinds to the closest matching brainrot.",
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
					local path = PathfindingService:CreatePath({
						AgentRadius = 2,
						AgentHeight = 5,
						AgentCanJump = true,
					})

					local success = pcall(function()
						path:ComputeAsync(playerPos, closest.Position)
					end)

					if success and path.Status == Enum.PathStatus.Success then
						for _, waypoint in ipairs(path:GetWaypoints()) do
							if not autoWalking then break end
							if waypoint.Action == Enum.PathWaypointAction.Jump then
								humanoid.Jump = true
							end
							humanoid:MoveTo(waypoint.Position)
							humanoid.MoveToFinished:Wait(3)
						end
					else
						humanoid:MoveTo(closest.Position)
						humanoid.MoveToFinished:Wait(5)
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

Tabs.Player:AddToggle("SpeedBoost", {
	Title = "Speed Boost",
	Description = "Doubles your walk speed from " .. BASE_SPEED .. " to " .. BOOST_SPEED .. ".",
	Default = false,
}):OnChanged(function(value)
	humanoid.WalkSpeed = value and BOOST_SPEED or BASE_SPEED
end)

-- ── INIT ──────────────────────────────────────────────────────────────────────

Window:SelectTab(1)
Fluent:Notify({
	Title = "Power Wash For Brainrot GUI",
	Content = "Loaded successfully.",
	Duration = 4,
})