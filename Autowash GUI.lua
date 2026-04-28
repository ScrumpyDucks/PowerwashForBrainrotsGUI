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

local antiCheat = ReplicatedStorage.Events.AntiCheat_TileWashed
local powerWashTargets = workspace.PowerWashTargets
local brainrotsFolder = workspace.Game.Brainrots
local brainrotAssets = ReplicatedStorage.Assets.Brainrots

-- ── CONFIG VARIABLES ──────────────────────────────────────────────────────────
local CLEAR_RADIUS = 12
local BATCH_SIZE = 5
local CHECK_INTERVAL = 0.1
local PLACE_ID = 126349562582764
local BASE_SPEED = 50
local BOOST_SPEED = 100

-- Highlighter State
local highlightColor = Color3.fromRGB(255, 200, 0)
local rainbowEnabled = false

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
    for model, _ in pairs(highlights) do
        removeHighlight(model)
    end
end

-- Rainbow Loop
task.spawn(function()
    while true do
        if rainbowEnabled then
            local hue = tick() % 5 / 5
            local color = Color3.fromHSV(hue, 1, 1)
            for _, h in pairs(highlights) do
                h.Color3 = color
                h.SurfaceColor3 = color
            end
        end
        task.wait()
    end
end)

local function matchesBrainrot(model, filter)
    if filter == "Any" then return true end
    return model.Name == filter
end

-- ── FLUENT UI ─────────────────────────────────────────────────────────────────

local Window = Fluent:CreateWindow({
    Title = "Power Wash For Brainrot GUI",
    SubTitle = "by Scrumpyducks",
    TabWidth = 160,
    Size = UDim2.fromOffset(560, 430),
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

-- ── MAIN TAB (Auto Tile Cleaner) ──────────────────────────────────────────────

local running = false

Tabs.Main:AddToggle("AutoClear", {
    Title = "Auto Tile Cleaner",
    Description = "Clears tiles in front of you.",
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
                        cleared += 1
                    end
                end
                task.wait(CHECK_INTERVAL)
            end
        end)
    end
end)

Tabs.Main:AddSlider("ClearRadius", {
    Title = "Clear Radius",
    Description = "Distance to clear tiles.",
    Default = 12,
    Min = 5,
    Max = 50,
    Rounding = 1,
    Callback = function(Value) CLEAR_RADIUS = Value end
})

Tabs.Main:AddSlider("BatchSize", {
    Title = "Batch Size",
    Description = "How many tiles to clear per interval.",
    Default = 5,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Callback = function(Value) BATCH_SIZE = Value end
})

Tabs.Main:AddSlider("CheckInterval", {
    Title = "Check Interval",
    Description = "Delay between clear checks.",
    Default = 0.1,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
    Callback = function(Value) CHECK_INTERVAL = Value end
})

-- ── TRAVEL TAB ────────────────────────────────────────────────────────────────

Tabs.Travel:AddButton({
    Title = "Teleport to Zone 1",
    Callback = function()
        humanoidRootPart.CFrame = CFrame.new(Vector3.new(32.067, 17.831, -141.121))
    end,
})

Tabs.Travel:AddButton({
    Title = "Relog",
    Callback = function()
        TeleportService:Teleport(PLACE_ID, player)
    end,
})

-- ── BRAINROT TAB ──────────────────────────────────────────────────────────────

local highlightFilter = "Any"
local walkFilter = "Any"
local highlightEnabled = false
local autoWalking = false

Tabs.Brainrot:AddDropdown("HighlightFilter", {
    Title = "Highlight Filter",
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
end)

Tabs.Brainrot:AddToggle("BrainrotHighlight", {
    Title = "Brainrot Highlighter",
    Default = false,
}):OnChanged(function(value)
    highlightEnabled = value
    if highlightEnabled then
        for _, model in ipairs(brainrotsFolder:GetChildren()) do
            if matchesBrainrot(model, highlightFilter) then addHighlight(model) end
        end
    else
        clearAllHighlights()
    end
end)

local ColorPicker = Tabs.Brainrot:AddColorpicker("HighlightColor", {
    Title = "Highlight Color",
    Default = Color3.fromRGB(255, 200, 0)
})

ColorPicker:OnChanged(function()
    highlightColor = ColorPicker.Value
    if not rainbowEnabled then
        for _, h in pairs(highlights) do
            h.Color3 = highlightColor
            h.SurfaceColor3 = highlightColor
        end
    end
end)

Tabs.Brainrot:AddToggle("RainbowHighlight", {
    Title = "Rainbow Effect",
    Default = false,
}):OnChanged(function(value)
    rainbowEnabled = value
end)

Tabs.Brainrot:AddDropdown("WalkFilter", {
    Title = "Auto-Pickup Filter",
    Values = brainrotNames,
    Default = "Any",
}):OnChanged(function(value) walkFilter = value end)

Tabs.Brainrot:AddToggle("AutoWalk", {
    Title = "Auto Walk & Pickup",
    Description = "Paths to brainrot and holds E to pick up.",
    Default = false,
}):OnChanged(function(value)
    autoWalking = value
    if autoWalking then
        task.spawn(function()
            while autoWalking do
                local closest = nil
                local closestDist = math.huge
                for _, model in ipairs(brainrotsFolder:GetChildren()) do
                    if matchesBrainrot(model, walkFilter) then
                        local part = model:IsA("BasePart") and model or model.PrimaryPart
                        if part then
                            local d = (part.Position - humanoidRootPart.Position).Magnitude
                            if d < closestDist then closestDist = d; closest = model end
                        end
                    end
                end

                if closest then
                    local targetPart = closest:IsA("BasePart") and closest or closest.PrimaryPart
                    humanoid:MoveTo(targetPart.Position)
                    
                    -- Wait until close enough to trigger prompt
                    local count = 0
                    while autoWalking and (targetPart.Position - humanoidRootPart.Position).Magnitude > 5 and count < 30 do
                        task.wait(0.1)
                        count += 1
                    end

                    -- Attempt Pickup
                    local prompt = closest:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt then
                        fireproximityprompt(prompt) -- Most executors support this
                    end
                end
                task.wait(0.5)
            end
        end)
    end
end)

-- ── PLAYER TAB ────────────────────────────────────────────────────────────────

local boostEnabled = false

Tabs.Player:AddSlider("SpeedSlider", {
    Title = "Boost Speed",
    Min = 16,
    Max = 500,
    Default = 100,
    Rounding = 0,
    Callback = function(Value)
        BOOST_SPEED = Value
        if boostEnabled then humanoid.WalkSpeed = BOOST_SPEED end
    end
})

Tabs.Player:AddToggle("SpeedBoost", {
    Title = "Enable Speed Boost",
    Default = false,
}):OnChanged(function(value)
    boostEnabled = value
    humanoid.WalkSpeed = value and BOOST_SPEED or BASE_SPEED
end)

-- ── INIT ──────────────────────────────────────────────────────────────────────

Window:SelectTab(1)
Fluent:Notify({ Title = "Success", Content = "Script Updated", Duration = 3 })