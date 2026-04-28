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
	Size = UDim2.fromOffset(500, 300),
	Acrylic = false, -- no blur
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
	Main = Window:AddTab({ Title = "Main", Icon = "brush" }),
}

local totalCleared = 0
local running = false

-- Use a label instead of paragraph so we can update it via an Options reference
local statusParagraph = Tabs.Main:AddParagraph({
	Title = "Status",
	Content = "Inactive — toggle to begin.",
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

Tabs.Main:AddParagraph({
	Title = "Tiles Cleared",
	Content = "Check the output for live tile count.",
})

-- Print tile count to output periodically as a lightweight alternative
task.spawn(function()
	while true do
		task.wait(2)
		if running then
			print("[Infinite Power] Tiles cleared: " .. totalCleared)
		end
	end
end)

Tabs.Main:AddParagraph({
	Title = "Info",
	Content = "Walk through each zone normally. Tiles within " .. CLEAR_RADIUS .. " studs ahead of you will be automatically cleared and registered.",
})

Window:SelectTab(1)
Fluent:Notify({
	Title = "Infinite Power",
	Content = "Loaded successfully.",
	Duration = 4,
})