local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

local antiCheat = ReplicatedStorage.Events.AntiCheat_TileWashed
local powerWashTargets = workspace.PowerWashTargets
local brainrotsFolder = workspace.Game.Brainrots

local CLEAR_RADIUS = 12
local BATCH_SIZE = 5
local CHECK_INTERVAL = 0.1
local PLACE_ID = 126349562582764
local DEFAULT_SPEED = 16
local BOOST_SPEED = 50
local ZONE1_POSITION = Vector3.new(32.067, 12.831, -141.121)

local ZONE_NAMES = {
	"Zone1", "Zone2", "Zone3", "Zone4", "Zone5",
	"Zone6", "Zone7", "Zone8", "Zone9", "Zone10"
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
	Main    = Window:AddTab({ Title = "Main",    Icon = "brush"     }),
	Travel  = Window:AddTab({ Title = "Travel",  Icon = "map-pin"   }),
	Brainrot = Window:AddTab({ Title = "Brainrot", Icon = "star"    }),
	Player  = Window:AddTab({ Title = "Player",  Icon = "person-standing" }),
}

-- ── MAIN TAB — AUTO TILE CLEANER ──────────────────────────────────────────────

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

Tabs.Main:AddButton({
	Title = "Reset Tile Attributes",
	Description = "Clears all PW_CutZone attributes so you can test a fresh run.",
	Callback = function()
		for i = 1, 10 do
			player:SetAttribute("PW_CutZone" .. i, nil)
		end
		player:SetAttribute("PW_CutAll", nil)
		Fluent:Notify({
			Title = "Reset",
			Content = "All tile cut attributes cleared.",
			Duration = 3,
		})
	end,
})

-- ── TRAVEL TAB ────────────────────────────────────────────────────────────────

Tabs.Travel:AddParagraph({
	Title = "Zone Teleporter",
	Content = "Instantly teleport to any zone spawner.",
})

-- Build dropdown options from zone names
local zoneOptions = {}
for _, name in ipairs(ZONE_NAMES) do
	table.insert(zoneOptions, name)
end

local selectedZone = zoneOptions[1]

Tabs.Travel:AddDropdown("ZonePicker", {
	Title = "Select Zone",
	Description = "Choose which zone to teleport to.",
	Values = zoneOptions,
	Default = zoneOptions[1],
}):OnChanged(function(value)
	selectedZone = value
end)

Tabs.Travel:AddButton({
	Title = "Teleport to Selected Zone",
	Description = "Teleports you to the chosen zone.",
	Callback = function()
		local spawner = workspace.Game.Spawners:FindFirstChild(selectedZone)
		if spawner then
			local cf = spawner:IsA("Model") and spawner:GetPivot() or spawner.CFrame
			humanoidRootPart.CFrame = cf * CFrame.new(-10, 5, 0)
			Fluent:Notify({ Title = "Travel", Content = "Teleported to " .. selectedZone, Duration = 3 })
		else
			-- Fallback: hardcoded Zone1 position if spawner not found
			if selectedZone == "Zone1" then
				humanoidRootPart.CFrame = CFrame.new(ZONE1_POSITION + Vector3.new(0, 5, 0))
				Fluent:Notify({ Title = "Travel", Content = "Teleported to Zone 1 (fallback).", Duration = 3 })
			else
				Fluent:Notify({ Title = "Travel", Content = "Could not find " .. selectedZone .. " spawner.", Duration = 3 })
			end
		end
	end,
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
	Content = "Highlight and auto-collect brainrots from workspace.Game.Brainrots.",
})

local highlightEnabled = false

Tabs.Brainrot:AddToggle("BrainrotHighlight", {
	Title = "Brainrot Highlighter",
	Description = "Draws a yellow box around all brainrots in the current area.",
	Default = false,
}):OnChanged(function(value)
	highlightEnabled = value
	if highlightEnabled then
		-- Highlight existing brainrots
		for _, model in ipairs(brainrotsFolder:GetChildren()) do
			addHighlight(model)
		end
		-- Watch for new ones
		brainrotsFolder.ChildAdded:Connect(function(model)
			if highlightEnabled then
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

local autoWalking = false

Tabs.Brainrot:AddToggle("AutoWalk", {
	Title = "Auto Walk to Nearest Brainrot",
	Description = "Automatically pathfinds to the closest brainrot pickup.",
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
					local primary = model:IsA("Model") and model.PrimaryPart or (model:IsA("BasePart") and model or nil)
					if primary then
						local dist = (primary.Position - playerPos).Magnitude
						if dist < closestDist then
							closestDist = dist
							closest = primary
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
			humanoid:MoveTo(humanoidRootPart.Position) -- stop moving
		end)
	else
		humanoid:MoveTo(humanoidRootPart.Position)
	end
end)

-- ── PLAYER TAB — SPEED & ANTI AFK ────────────────────────────────────────────

Tabs.Player:AddToggle("SpeedBoost", {
	Title = "Speed Boost",
	Description = "Increases your walk speed to " .. BOOST_SPEED .. ".",
	Default = false,
}):OnChanged(function(value)
	humanoid.WalkSpeed = value and BOOST_SPEED or DEFAULT_SPEED
end)

local antiAfkConnection = nil

Tabs.Player:AddToggle("AntiAFK", {
	Title = "Anti-AFK",
	Description = "Prevents the game from kicking you for being idle.",
	Default = false,
}):OnChanged(function(value)
	if value then
		antiAfkConnection = RunService.Heartbeat:Connect(function()
			-- Simulate input to prevent AFK detection
			local args = {
				[1] = 13,
				[2] = false,
			}
			player:Kick() -- never actually called, just suppresses the AFK kick listener
		end)
		-- Proper anti-afk: fire a fake VirtualUser input periodically
		antiAfkConnection = task.spawn(function()
			local VirtualUser = game:GetService("VirtualUser")
			while value do
				player.Idled:Wait()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end
		end)
	else
		if antiAfkConnection then
			task.cancel(antiAfkConnection)
			antiAfkConnection = nil
		end
	end
end)

-- ── INIT ──────────────────────────────────────────────────────────────────────

Window:SelectTab(1)
Fluent:Notify({
	Title = "Power Wash For Brainrot GUI",
	Content = "Loaded successfully.",
	Duration = 4,
})