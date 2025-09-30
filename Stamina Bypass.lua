-- This script uses 4 methods to effectively bypass most stamina systems in applicable Roblox games.
-- It attempts to set stamina-related attributes/values to infinite and overrides common Humanoid properties.

_G.UnlimitedStamina = true -- Toggle for unlimited stamina

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local LocalPlayer = Players.LocalPlayer

-- Common stamina attribute/value names (Adjust these to match your game!!) (If these values don't work, try to find the correct names using DEX or similar tools)
local staminaNames = {
    "Stamina",
    "Energy",
    "Endurance",
    "Sprint",
    "Breath"
}

-- Function to find and set stamina values
local function setUnlimitedStamina()
    if not _G.UnlimitedStamina then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- Method 1: Check for Attributes (most common)
    for _, staminaName in pairs(staminaNames) do
        if character:GetAttribute(staminaName) then
            character:SetAttribute(staminaName, math.huge) -- Set to infinite
        end
        
        if humanoid:GetAttribute(staminaName) then
            humanoid:SetAttribute(staminaName, math.huge)
        end
    end
    
    -- Method 2: Check for Values/IntValues/NumberValues
    for _, obj in pairs(character:GetDescendants()) do
        if obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("DoubleValue") then
            for _, staminaName in pairs(staminaNames) do
                if string.lower(obj.Name):find(string.lower(staminaName)) then
                    obj.Value = math.huge
                end
            end
        end
    end
    
    -- Method 3: Check for StringValues that might control stamina
    for _, obj in pairs(character:GetDescendants()) do
        if obj:IsA("StringValue") and obj.Name:lower():find("stamina") then
            obj.Value = "999999" -- High stamina value as string
        end
    end
    
    -- Method 4: Override common stamina-related Humanoid properties
    if humanoid then
        -- Prevent exhaustion
        humanoid.PlatformStand = false
        
        -- Keep movement speed at maximum if it's being reduced by stamina
        if humanoid.WalkSpeed < 16 then -- Default Roblox walkspeed
            humanoid.WalkSpeed = 20 -- Set to higher speed
        end
        
        -- Ensure jump power isn't reduced
        if humanoid.JumpPower and humanoid.JumpPower < 50 then
            humanoid.JumpPower = 50
        elseif humanoid.JumpHeight and humanoid.JumpHeight < 7.2 then
            humanoid.JumpHeight = 7.2
        end
    end
end

-- Function to handle character respawn
local function onCharacterAdded(character)
    character:WaitForChild("Humanoid")
    wait(1) -- Wait for game systems to initialize
end

-- Connect to character spawning
if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Main loop - runs continuously
RunService.Heartbeat:Connect(function()
    pcall(setUnlimitedStamina) -- Use pcall to prevent errors from breaking the script
end)

-- Optional: Create a simple toggle GUI
local function createStaminaGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StaminaToggleGUI"
    screenGui.Parent = game:GetService("CoreGui")
    screenGui.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 180, 0, 60)
    frame.Position = UDim2.new(0, 20, 0, 120) -- Below ESP GUI
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 0) -- Green theme
    stroke.Thickness = 1
    stroke.Parent = frame
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 140, 0, 30)
    button.Position = UDim2.new(0, 20, 0, 15)
    button.BackgroundColor3 = _G.UnlimitedStamina and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(80, 80, 80)
    button.Text = _G.UnlimitedStamina and "STAMINA: ON" or "STAMINA: OFF"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = frame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = button
    
    button.MouseButton1Click:Connect(function()
        _G.UnlimitedStamina = not _G.UnlimitedStamina
        button.BackgroundColor3 = _G.UnlimitedStamina and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(80, 80, 80)
        button.Text = _G.UnlimitedStamina and "STAMINA: ON" or "STAMINA: OFF"
    end)
end

-- Initialize GUI
createStaminaGUI()

print("Unlimited Stamina script loaded! Toggle with the GUI or set _G.UnlimitedStamina = false to disable")