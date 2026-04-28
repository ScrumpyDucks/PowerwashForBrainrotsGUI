local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
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

-- Highlighter & Tracer State
local highlightColor = Color3.fromRGB(255, 200, 0)
local rainbowEnabled = false
local tracersEnabled = false

-- ── TILE CACHE ────────────────────────────────────────────────────────────────
local tileSet = {}
local function addTile(tile)
    if tile:IsA("BasePart") and tile:GetAttribute("IsPowerWashTile") then
        tileSet[tile] = true
    end
end
for _, tile in ipairs(powerWashTargets:GetChildren()) do addTile(tile) end
powerWashTargets.ChildAdded:Connect(addTile)
powerWashTargets.ChildRemoved:Connect(function(tile) tileSet[tile] = nil end)

-- ── BRAINROT NAMES ────────────────────────────────────────────────────────────
local brainrotNames = {"Any"}
for _, asset in ipairs(brainrotAssets:GetChildren()) do
    table.insert(brainrotNames, asset.Name)
end

-- ── HIGHLIGHT & TRACER CACHE ──────────────────────────────────────────────────
local highlights = {}
local tracerLines = {}

local function createTracer()
    local line = Drawing.new("Line")
    line.Thickness = 1.5
    line.Transparency = 0.8
    line.Visible = false
    return line
end

local function addHighlight(model)
    if highlights[model] then return end
    
    -- Selection Box
    local h = Instance.new("SelectionBox")
    h.Adornee = model
    h.Color3 = highlightColor
    h.LineThickness = 0.05
    h.SurfaceTransparency = 0.7
    h.SurfaceColor3 = highlightColor
    h.Parent = model
    highlights[model] = h

    -- Tracer Line
    tracerLines[model] = createTracer()
end

local function removeHighlight(model)
    if highlights[model] then
        highlights[model]:Destroy()
        highlights[model] = nil
    end
    if tracerLines[model] then
        tracerLines[model]:Remove()
        tracerLines[model] = nil
    end
end

local function clearAllHighlights()
    for model, _ in pairs(highlights) do
        removeHighlight(model)
    end
end

-- ── RENDER LOOP (Rainbow & Tracers) ──────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    local currentHue = (tick() % 5 / 5)
    local rainbowColor = Color3.fromHSV(currentHue, 1, 1)
    local finalColor = rainbowEnabled and rainbowColor or highlightColor
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y) -- Bottom center of screen

    for model, line in pairs(tracerLines) do
        local h = highlights[model]
        if h then
            h.Color3 = finalColor
            h.SurfaceColor3 = finalColor
        end

        local part = model:IsA("BasePart") and model or model.PrimaryPart
        if part and tracersEnabled then
            local vector, onScreen = camera:WorldToViewportPoint(part.Position)
            if onScreen then
                line.Color = finalColor
                line.From = screenCenter
                line.To = Vector2.new(vector.X, vector.Y)
                line.Visible = true
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
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
    Size = UDim2.fromOffset(560, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
    Main     = Window:AddTab({ Title = "Main",     Icon = "brush"           }),
    Brainrot = Window:AddTab({ Title = "Brainrot", Icon = "star"            }),
    Player   = Window:AddTab({ Title = "Player",   Icon = "person-standing" }),
}

-- ── MAIN TAB ──────────────────────────────────────────────────────────────────
Tabs.Main:AddToggle("AutoClear", { Title = "Auto Tile Cleaner", Default = false }):OnChanged(function(v)
    running = v
    task.spawn(function()
        while running do
            local playerPos = humanoidRootPart.Position
            local playerLook = humanoidRootPart.CFrame.LookVector
            local cleared = 0
            for tile in pairs(tileSet) do
                if cleared >= BATCH_SIZE then break end
                local offset = tile.Position - playerPos
                if offset.Magnitude <= CLEAR_RADIUS and offset.Unit:Dot(playerLook) > -0.5 then
                    tileSet[tile] = nil
                    antiCheat:FireServer(tile)
                    tile:Destroy()
                    cleared += 1
                end
            end
            task.wait(CHECK_INTERVAL)
        end
    end)
end)

Tabs.Main:AddSlider("ClearRadius", { Title = "Clear Radius", Min = 5, Max = 50, Default = 12, Callback = function(v) CLEAR_RADIUS = v end })
Tabs.Main:AddSlider("BatchSize", { Title = "Batch Size", Min = 1, Max = 20, Default = 5, Callback = function(v) BATCH_SIZE = v end })

-- ── BRAINROT TAB ──────────────────────────────────────────────────────────────
local highlightFilter = "Any"
local walkFilter = "Any"

Tabs.Brainrot:AddDropdown("HighlightFilter", { Title = "Filter", Values = brainrotNames, Default = "Any" }):OnChanged(function(v)
    highlightFilter = v
    if highlights then clearAllHighlights() end
end)

Tabs.Brainrot:AddToggle("BrainrotHighlight", { Title = "Enable Highlighter", Default = false }):OnChanged(function(v)
    highlightEnabled = v
    if not v then clearAllHighlights() end
end)

Tabs.Brainrot:AddToggle("EnableTracers", { Title = "Enable Tracers", Default = false }):OnChanged(function(v)
    tracersEnabled = v
end)

local ColorPicker = Tabs.Brainrot:AddColorpicker("HighlightColor", { Title = "Color", Default = highlightColor })
ColorPicker:OnChanged(function() highlightColor = ColorPicker.Value end)

Tabs.Brainrot:AddToggle("RainbowHighlight", { Title = "Rainbow Effect", Default = false }):OnChanged(function(v) rainbowEnabled = v end)

-- Auto Walk & Pickup Logic
Tabs.Brainrot:AddToggle("AutoWalk", { Title = "Auto Walk & Pickup", Default = false }):OnChanged(function(v)
    autoWalking = v
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
                local target = closest:IsA("BasePart") and closest or closest.PrimaryPart
                humanoid:MoveTo(target.Position)
                if (target.Position - humanoidRootPart.Position).Magnitude < 7 then
                    local prompt = closest:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt then fireproximityprompt(prompt) end
                end
            end
            task.wait(0.5)
        end
    end)
end)

-- ── PLAYER TAB ────────────────────────────────────────────────────────────────
Tabs.Player:AddSlider("SpeedSlider", { Title = "Speed", Min = 16, Max = 500, Default = 100, Callback = function(v) BOOST_SPEED = v end })
Tabs.Player:AddToggle("SpeedBoost", { Title = "Speed Boost", Default = false }):OnChanged(function(v)
    humanoid.WalkSpeed = v and BOOST_SPEED or BASE_SPEED
end)

-- Initialize folder listeners
brainrotsFolder.ChildAdded:Connect(function(m) if highlightEnabled and matchesBrainrot(m, highlightFilter) then addHighlight(m) end end)
brainrotsFolder.ChildRemoved:Connect(removeHighlight)

Window:SelectTab(1)