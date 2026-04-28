local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local antiCheat = ReplicatedStorage.Events.AntiCheat_TileWashed
local powerWashTargets = workspace.PowerWashTargets

local CLEAR_RADIUS = 12
local BATCH_SIZE = 5
local CHECK_INTERVAL = 0.1

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

-- ── FLUENT UI ─────────────────────────────────────────────────────────────────

local Window = Fluent:CreateWindow({
	Title = "Infinite Power",
	SubTitle = "by your game",
	TabWidth = 160,
	Size = UDim2.fromOffset(500, 350),
	Acrylic = false,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
	Main = Window:AddTab({ Title = "Main", Icon = "brush" }),
	Travel = Window:AddTab({ Title = "Travel", Icon = "map-pin" }),
}

-- ── MAIN TAB ──────────────────────────────────────────────────────────────────

local running = false
local totalCleared = 0

Tabs.Main:AddParagraph({
	Title = "Auto Tile Cleaner",
	Content = "Walk through zones normally. Tiles ahead of you will be automatically cleared and registered.",
})

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
	Content = "Teleports you back to the Zone 1 spawner.",
})

Tabs.Travel:AddButton({
	Title = "Teleport to Zone 1",
	Description = "Returns you to the beginning of the map.",
	Callback = function()
		local spawner = workspace.Game.Spawners:FindFirstChild("Zone1")
		if spawner then
			local cf = spawner:IsA("Model") and spawner:GetPivot() or spawner.CFrame
			humanoidRootPart.CFrame = cf * CFrame.new(-10, 5, 0)
			Fluent:Notify({
				Title = "Travel",
				Content = "Teleported to Zone 1.",
				Duration = 3,
			})
		else
			Fluent:Notify({
				Title = "Travel",
				Content = "Could not find Zone 1 spawner.",
				Duration = 3,
			})
		end
	end,
})

-- ── INIT ──────────────────────────────────────────────────────────────────────

Window:SelectTab(1)
Fluent:Notify({
	Title = "Infinite Power",
	Content = "Loaded successfully.",
	Duration = 4,
})