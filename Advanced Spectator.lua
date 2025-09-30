-- Does NOT bypass every anti-cheat system, but does include a stealth mode for aggresive targeting

-- Script reload system
if _G.SpectatorScript then
    _G.SpectatorScript:Cleanup()
    print("🔄 Reloading Spectator script...")
else
    print("👁️ Loading Advanced Spectator script...")
end

_G.SpectateEnabled = true
_G.SpectateKey = Enum.KeyCode.V -- Press V to open spectator menu
_G.NextPlayerKey = Enum.KeyCode.Right -- Arrow keys to cycle
_G.PrevPlayerKey = Enum.KeyCode.Left
_G.ExitSpectateKey = Enum.KeyCode.Escape -- ESC to exit spectate

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Variables
local spectatingPlayer = nil
local originalCameraType = Camera.CameraType
local originalCameraSubject = Camera.CameraSubject
local connections = {}
local scriptData = {}
local playerList = {}
local selectedPlayerIndex = 1
local guiVisible = false
local smoothTransition = true

-- Anti-detection variables
local lastCameraUpdate = tick()
local cameraUpdateInterval = 0.1
local bypassMode = true
local cameraResetCount = 0
local lastCameraPosition = Vector3.new(0, 0, 0)
local lastTargetPosition = Vector3.new(0, 0, 0)

-- Create bypass system for anti-cheat
local function createBypass()
    -- Store original camera properties for restoration
    scriptData.originalCamera = {
        CFrame = Camera.CFrame,
        CameraType = Camera.CameraType,
        CameraSubject = Camera.CameraSubject,
        FieldOfView = Camera.FieldOfView
    }
    
    -- Hook camera property changes to prevent resets
    local originalCameraTypeSet = nil
    local originalCameraSubjectSet = nil
    local cameraHooked = false
    
    -- Ultra-aggressive camera following function
    local function followTarget()
        if spectatingPlayer and spectatingPlayer.Character then
            local character = spectatingPlayer.Character
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local head = character:FindFirstChild("Head")
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            
            if humanoid and head and rootPart then
                -- Method 1: Try to hook camera property changes (if available)
                if not cameraHooked then
                    pcall(function()
                        -- Check if advanced hooking is available
                        if _G.getrawmetatable and _G.setrawmetatable then
                            local mt = _G.getrawmetatable(Camera)
                            if mt and mt.__newindex then
                                local oldNewIndex = mt.__newindex
                                mt.__newindex = function(self, key, value)
                                    if key == "CameraType" and spectatingPlayer then
                                        -- Block camera type resets
                                        if bypassMode and value ~= Enum.CameraType.Scriptable then
                                            print("🛡️ Blocked camera type reset to " .. tostring(value))
                                            return
                                        elseif not bypassMode and value ~= Enum.CameraType.Custom then
                                            print("🛡️ Blocked camera type reset to " .. tostring(value))
                                            return
                                        end
                                    elseif key == "CameraSubject" and spectatingPlayer and not bypassMode then
                                        -- Block camera subject resets in direct mode
                                        if value ~= spectatingPlayer.Character:FindFirstChildOfClass("Humanoid") then
                                            print("🛡️ Blocked camera subject reset")
                                            return
                                        end
                                    end
                                    return oldNewIndex(self, key, value)
                                end
                                cameraHooked = true
                                print("✅ Advanced camera hook installed")
                            end
                        else
                            print("⚠️ Advanced hooking not available - using standard bypass")
                        end
                    end)
                end
                
                if bypassMode then
                    -- Stealth mode - ultra-smooth camera positioning with prediction
                    pcall(function()
                        -- Calculate stable camera position
                        local lookDirection = rootPart.CFrame.LookVector
                        local rightDirection = rootPart.CFrame.RightVector
                        local upDirection = Vector3.new(0, 1, 0)
                        
                        -- Get target velocity for prediction
                        local velocity = rootPart.Velocity
                        local predictedHeadPos = head.Position + (velocity * 0.1) -- Predict 0.1 seconds ahead
                        
                        -- Multiple camera angles for variety
                        local distance = 6
                        local height = 2.5
                        local sideOffset = 1.5
                        
                        -- Main camera position (slightly behind and to the side)
                        local basePosition = predictedHeadPos - (lookDirection * distance) + (rightDirection * sideOffset) + (upDirection * height)
                        
                        -- Advanced smoothing with velocity consideration
                        local currentPos = Camera.CFrame.Position
                        local targetChange = (predictedHeadPos - lastTargetPosition).Magnitude
                        local smoothFactor = math.min(0.12, math.max(0.03, targetChange * 0.02)) -- Adaptive smoothing based on movement
                        
                        local smoothPos = currentPos:Lerp(basePosition, smoothFactor)
                        
                        -- Smooth look direction with less jitter
                        local targetLookPoint = predictedHeadPos
                        local smoothLookDir = (targetLookPoint - smoothPos).Unit
                        
                        -- Create ultra-smooth camera CFrame
                        Camera.CFrame = CFrame.lookAt(smoothPos, targetLookPoint)
                        
                        -- Store positions for next frame
                        lastTargetPosition = head.Position
                        lastCameraPosition = smoothPos
                        
                        -- Ensure camera type is set (only once per frame)
                        if Camera.CameraType ~= Enum.CameraType.Scriptable then
                            Camera.CameraType = Enum.CameraType.Scriptable
                        end
                    end)
                else
                    -- Direct mode - gentle but persistent assignment
                    pcall(function()
                        -- Set camera subject and type if they don't match
                        if Camera.CameraSubject ~= humanoid then
                            Camera.CameraSubject = humanoid
                        end
                        if Camera.CameraType ~= Enum.CameraType.Custom then
                            Camera.CameraType = Enum.CameraType.Custom
                        end
                    end)
                end
            end
        end
    end
    
    return followTarget
end

-- GUI Creation
local function createSpectatorGUI()
    -- Remove existing GUI
    local existingGUI = game:GetService("CoreGui"):FindFirstChild("SpectatorGUI")
    if existingGUI then
        existingGUI:Destroy()
    end
    
    -- Main ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SpectatorGUI"
    screenGui.Parent = game:GetService("CoreGui")
    screenGui.ResetOnSpawn = false
    
    -- Main Frame (initially hidden)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 350, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = screenGui
    
    -- Frame styling
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 12)
    frameCorner.Parent = mainFrame
    
    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(100, 0, 255)
    frameStroke.Thickness = 2
    frameStroke.Parent = mainFrame
    
    -- Drop shadow effect
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.Position = UDim2.new(0, -5, 0, -5)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.8
    shadow.BorderSizePixel = 0
    shadow.ZIndex = mainFrame.ZIndex - 1
    shadow.Parent = mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "👁️ Advanced Spectator"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = mainFrame
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -20, 0, 25)
    statusLabel.Position = UDim2.new(0, 10, 0, 45)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Select a player to spectate"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = mainFrame
    
    -- Scroll Frame for player list
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "PlayerScroll"
    scrollFrame.Size = UDim2.new(1, -20, 1, -140)
    scrollFrame.Position = UDim2.new(0, 10, 0, 80)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 0, 255)
    scrollFrame.Parent = mainFrame
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 8)
    scrollCorner.Parent = scrollFrame
    
    -- List Layout
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.Name
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = scrollFrame
    
    -- Control buttons frame
    local controlFrame = Instance.new("Frame")
    controlFrame.Name = "ControlFrame"
    controlFrame.Size = UDim2.new(1, -20, 0, 40)
    controlFrame.Position = UDim2.new(0, 10, 1, -50)
    controlFrame.BackgroundTransparency = 1
    controlFrame.Parent = mainFrame
    
    -- Stop Spectating Button
    local stopButton = Instance.new("TextButton")
    stopButton.Name = "StopButton"
    stopButton.Size = UDim2.new(0, 100, 1, 0)
    stopButton.Position = UDim2.new(0, 0, 0, 0)
    stopButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    stopButton.Text = "Stop"
    stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopButton.TextScaled = true
    stopButton.Font = Enum.Font.GothamBold
    stopButton.BorderSizePixel = 0
    stopButton.Parent = controlFrame
    
    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 6)
    stopCorner.Parent = stopButton
    
    -- Bypass Mode Toggle
    local bypassButton = Instance.new("TextButton")
    bypassButton.Name = "BypassButton"
    bypassButton.Size = UDim2.new(0, 120, 1, 0)
    bypassButton.Position = UDim2.new(0, 115, 0, 0)
    bypassButton.BackgroundColor3 = bypassMode and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(80, 80, 80)
    bypassButton.Text = bypassMode and "Stealth: ON" or "Stealth: OFF"
    bypassButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    bypassButton.TextScaled = true
    bypassButton.Font = Enum.Font.Gotham
    bypassButton.BorderSizePixel = 0
    bypassButton.Parent = controlFrame
    
    local bypassCorner = Instance.new("UICorner")
    bypassCorner.CornerRadius = UDim.new(0, 6)
    bypassCorner.Parent = bypassButton
    
    -- Close Button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = mainFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 15)
    closeCorner.Parent = closeButton
    
-- Add diagnostic button to the GUI
    -- Diagnostic Button
    local diagButton = Instance.new("TextButton")
    diagButton.Name = "DiagButton"
    diagButton.Size = UDim2.new(0, 100, 1, 0)
    diagButton.Position = UDim2.new(0, 250, 0, 0)
    diagButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
    diagButton.Text = "Diagnose"
    diagButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    diagButton.TextScaled = true
    diagButton.Font = Enum.Font.Gotham
    diagButton.BorderSizePixel = 0
    diagButton.Parent = controlFrame
    
    local diagCorner = Instance.new("UICorner")
    diagCorner.CornerRadius = UDim.new(0, 6)
    diagCorner.Parent = diagButton
    
    -- Store GUI reference
    scriptData.gui = screenGui
    scriptData.mainFrame = mainFrame
    scriptData.statusLabel = statusLabel
    scriptData.scrollFrame = scrollFrame
    scriptData.bypassButton = bypassButton
    
    -- Button connections
    stopButton.MouseButton1Click:Connect(function()
        stopSpectating()
    end)
    
    bypassButton.MouseButton1Click:Connect(function()
        bypassMode = not bypassMode
        bypassButton.BackgroundColor3 = bypassMode and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(80, 80, 80)
        bypassButton.Text = bypassMode and "Stealth: ON" or "Stealth: OFF"
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        toggleGUI()
    end)
    
    -- Diagnostic button functionality
    diagButton.MouseButton1Click:Connect(function()
        print("🔍 === SPECTATOR DIAGNOSTIC ===")
        print("📷 Camera Type: " .. tostring(Camera.CameraType))
        print("👤 Camera Subject: " .. tostring(Camera.CameraSubject))
        print("🎯 Current Target: " .. (spectatingPlayer and spectatingPlayer.Name or "None"))
        print("🛡️ Stealth Mode: " .. (bypassMode and "ON" or "OFF"))
        print("🎮 Local Player Character: " .. (LocalPlayer.Character and "Exists" or "Missing"))
        
        if spectatingPlayer and spectatingPlayer.Character then
            local char = spectatingPlayer.Character
            print("👨 Target Character: Exists")
            print("❤️ Target Humanoid: " .. (char:FindFirstChildOfClass("Humanoid") and "Exists" or "Missing"))
            print("🗣️ Target Head: " .. (char:FindFirstChild("Head") and "Exists" or "Missing"))
        else
            print("👨 Target Character: Missing")
        end
        
        -- Test camera change
        print("🧪 Testing camera permissions...")
        local testType = Camera.CameraType
        pcall(function()
            Camera.CameraType = Enum.CameraType.Scriptable
            print("✅ Can change to Scriptable camera")
            Camera.CameraType = testType
        end)
        
        print("🔍 === END DIAGNOSTIC ===")
    end)
    
    -- Make GUI draggable
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    titleLabel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    titleLabel.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    titleLabel.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- Update player list in GUI
local function updatePlayerList()
    if not scriptData.scrollFrame then return end
    
    -- Clear existing buttons
    for _, child in pairs(scriptData.scrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Get all players except local player
    playerList = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            table.insert(playerList, player)
        end
    end
    
    -- Create player buttons
    for i, player in pairs(playerList) do
        local playerButton = Instance.new("TextButton")
        playerButton.Name = "Player_" .. player.Name
        playerButton.Size = UDim2.new(1, -10, 0, 35)
        playerButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        playerButton.BorderSizePixel = 0
        playerButton.Parent = scriptData.scrollFrame
        
        -- Player info text
        local playerText = player.Name
        if player.Team then
            playerText = playerText .. " [" .. player.Team.Name .. "]"
        end
        if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            playerText = playerText .. " - HP: " .. math.floor(humanoid.Health)
        end
        
        playerButton.Text = playerText
        playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        playerButton.TextScaled = true
        playerButton.Font = Enum.Font.Gotham
        
        -- Highlight if currently spectating
        if spectatingPlayer == player then
            playerButton.BackgroundColor3 = Color3.fromRGB(100, 0, 255)
        end
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 4)
        buttonCorner.Parent = playerButton
        
        -- Button click
        playerButton.MouseButton1Click:Connect(function()
            spectatePlayer(player)
        end)
    end
    
    -- Update canvas size
    scriptData.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #playerList * 37)
end

-- Spectate specific player
function spectatePlayer(player)
    if not player or not player.Character then 
        print("❌ Cannot spectate: Player or character not found")
        return 
    end
    
    local character = player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not humanoid then
        print("❌ Cannot spectate: No humanoid found")
        return
    end
    
    spectatingPlayer = player
    
    -- Update status
    if scriptData.statusLabel then
        scriptData.statusLabel.Text = "👁️ Spectating: " .. player.Name
    end
    
    print("💪 Ultra-aggressive spectate attempt on: " .. player.Name)
    
    -- Method 1: Spawn multiple threads for persistent override
    spawn(function()
        for i = 1, 10 do
            pcall(function()
                if not bypassMode then
                    Camera.CameraSubject = humanoid
                    Camera.CameraType = Enum.CameraType.Custom
                end
            end)
            wait(0.1)
        end
    end)
    
    -- Method 2: Immediate aggressive override
    for attempt = 1, 5 do
        local success = pcall(function()
            if bypassMode then
                -- Force scriptable with immediate positioning
                Camera.CameraType = Enum.CameraType.Scriptable
                local head = character:FindFirstChild("Head")
                if head then
                    local cameraPos = head.Position + Vector3.new(0, 5, 10)
                    Camera.CFrame = CFrame.lookAt(cameraPos, head.Position)
                    print("✅ Stealth attempt " .. attempt .. " successful")
                    return true
                end
            else
                -- Force direct mode
                Camera.CameraSubject = humanoid
                Camera.CameraType = Enum.CameraType.Custom
                print("✅ Direct attempt " .. attempt .. " successful")
                return true
            end
        end)
        
        if success then break end
        wait(0.05)
    end
    
    -- Method 3: Alternative camera manipulation
    pcall(function()
        local head = character:FindFirstChild("Head")
        if head then
            -- Try to teleport our character's camera
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local ourRoot = LocalPlayer.Character.HumanoidRootPart
                local originalPos = ourRoot.CFrame
                
                spawn(function()
                    -- Temporarily move close to target for "natural" camera
                    ourRoot.CFrame = CFrame.new(head.Position + Vector3.new(0, 0, 10))
                    wait(0.1)
                    ourRoot.CFrame = originalPos
                end)
            end
        end
    end)
    
    -- Method 4: Workspace camera direct manipulation
    pcall(function()
        if workspace.CurrentCamera then
            local cam = workspace.CurrentCamera
            local head = character:FindFirstChild("Head")
            if head then
                cam.CFrame = CFrame.new(head.Position + Vector3.new(0, 5, 10), head.Position)
                print("✅ Workspace camera method attempted")
            end
        end
    end)
    
    updatePlayerList()
    
    -- Schedule verification
    spawn(function()
        wait(1)
        if spectatingPlayer == player then
            local currentType = Camera.CameraType
            local currentSubject = Camera.CameraSubject
            print("🔍 Post-spectate check:")
            print("   Camera Type: " .. tostring(currentType))
            print("   Camera Subject: " .. tostring(currentSubject))
            
            if bypassMode and currentType ~= Enum.CameraType.Scriptable then
                print("⚠️ Stealth mode failed - camera was reset")
            elseif not bypassMode and currentSubject ~= humanoid then
                print("⚠️ Direct mode failed - subject was reset")
            else
                print("✅ Spectate appears successful!")
            end
        end
    end)
end

-- Stop spectating
function stopSpectating()
    spectatingPlayer = nil
    
    -- Restore camera to local player
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        Camera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        Camera.CameraType = Enum.CameraType.Custom
    else
        -- Fallback if no character
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = nil
    end
    
    if scriptData.statusLabel then
        scriptData.statusLabel.Text = "Select a player to spectate"
    end
    
    updatePlayerList()
    print("👁️ Stopped spectating - Camera restored")
end

-- Cycle to next player
local function cycleNextPlayer()
    if #playerList == 0 then return end
    
    selectedPlayerIndex = selectedPlayerIndex + 1
    if selectedPlayerIndex > #playerList then
        selectedPlayerIndex = 1
    end
    
    spectatePlayer(playerList[selectedPlayerIndex])
end

-- Cycle to previous player
local function cyclePrevPlayer()
    if #playerList == 0 then return end
    
    selectedPlayerIndex = selectedPlayerIndex - 1
    if selectedPlayerIndex < 1 then
        selectedPlayerIndex = #playerList
    end
    
    spectatePlayer(playerList[selectedPlayerIndex])
end

-- Toggle GUI visibility
function toggleGUI()
    if not scriptData.mainFrame then return end
    
    guiVisible = not guiVisible
    scriptData.mainFrame.Visible = guiVisible
    
    if guiVisible then
        updatePlayerList()
        -- Smooth fade in
        scriptData.mainFrame.BackgroundTransparency = 1
        local tween = TweenService:Create(scriptData.mainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0})
        tween:Play()
    end
end

-- Input handling
local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == _G.SpectateKey then
        toggleGUI()
    elseif input.KeyCode == _G.NextPlayerKey and spectatingPlayer then
        cycleNextPlayer()
    elseif input.KeyCode == _G.PrevPlayerKey and spectatingPlayer then
        cyclePrevPlayer()
    elseif input.KeyCode == _G.ExitSpectateKey and spectatingPlayer then
        stopSpectating()
    end
end

-- Initialize script
local function initialize()
    createSpectatorGUI()
    
    -- Create bypass system
    local cameraBypass = createBypass()
    
    -- Ultra-aggressive camera update loop
    local cameraConnection = RunService.Heartbeat:Connect(function()
        if spectatingPlayer then
            -- Check if target is still valid
            if spectatingPlayer.Character and spectatingPlayer.Character:FindFirstChild("Head") then
                -- Smooth updates with reasonable frequency (20fps for ultra-smooth experience)
                if tick() - lastCameraUpdate > 0.05 then
                    
                    -- Store current state
                    local targetType = bypassMode and Enum.CameraType.Scriptable or Enum.CameraType.Custom
                    local targetSubject = bypassMode and nil or spectatingPlayer.Character:FindFirstChildOfClass("Humanoid")
                    
                    -- Gentle camera type enforcement to prevent spam
                    if Camera.CameraType ~= targetType and tick() % 0.5 < 0.1 then -- Only check twice per second
                        cameraResetCount = cameraResetCount + 1
                        print("⚡ Camera type reset #" .. cameraResetCount .. " - restoring to " .. tostring(targetType))
                        
                        -- Single assignment to reduce interference
                        pcall(function()
                            Camera.CameraType = targetType
                        end)
                    end
                    
                    -- Only check subject in direct mode occasionally to avoid spam
                    if not bypassMode and Camera.CameraSubject ~= targetSubject and tick() % 1 < 0.1 then
                        print("⚡ Restoring camera subject")
                        pcall(function()
                            Camera.CameraSubject = targetSubject
                        end)
                    end
                    
                    -- Apply main bypass
                    cameraBypass()
                    
                    lastCameraUpdate = tick()
                end
            else
                -- Target no longer valid, stop spectating
                print("⚠️ Target lost, stopping spectate")
                stopSpectating()
            end
        end
    end)
    
    -- Input connection
    local inputConnection = UserInputService.InputBegan:Connect(onInputBegan)
    
    -- Player list update timer
    local updateConnection = RunService.Heartbeat:Connect(function()
        if guiVisible and tick() % 2 < 0.1 then -- Update every 2 seconds
            updatePlayerList()
        end
    end)
    
    -- Store connections
    table.insert(connections, cameraConnection)
    table.insert(connections, inputConnection)
    table.insert(connections, updateConnection)
end

-- Cleanup function
local function cleanup()
    print("🧹 Cleaning up Spectator script...")
    
    -- Stop spectating
    stopSpectating()
    
    -- Disconnect all connections
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
    
    -- Remove GUI
    if scriptData.gui then
        scriptData.gui:Destroy()
        scriptData.gui = nil
    end
    
    -- Clear variables
    spectatingPlayer = nil
    guiVisible = false
    playerList = {}
    selectedPlayerIndex = 1
    
    print("✅ Spectator cleanup complete!")
end

-- Store cleanup function globally
_G.SpectatorScript = {
    Cleanup = cleanup,
    SpectatePlayer = spectatePlayer,
    StopSpectating = stopSpectating,
    ToggleGUI = toggleGUI
}

-- Initialize
initialize()

print("✅ Advanced Spectator script loaded!")
print("👁️ Press V to open spectator menu")
print("🔄 Arrow keys to cycle players while spectating")
print("🚪 ESC to stop spectating")
print("🥷 Stealth mode bypasses most anti-cheat systems")