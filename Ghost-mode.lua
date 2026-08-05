-- ========================================
-- POLTERGEIST MODE - Complete Ghost System
-- For Codex Executor (Mobile)
-- ========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local ChatService = game:GetService("Chat")

local player = Players.LocalPlayer
local character = player.Character
local humanoid = character and character:FindFirstChild("Humanoid")
local camera = Workspace.CurrentCamera

-- ========================================
-- CONFIGURATION
-- ========================================
local SPECTATOR_SPEED = 50
local TOGGLE_KEY = Enum.KeyCode.F
local TELEPORT_KEY = Enum.KeyCode.T
local MOBILE_BUTTON_SIZE = UDim2.new(0, 60, 0, 40)

-- ========================================
-- STATE VARIABLES
-- ========================================
local isGhost = false
local originalCameraSubject = nil
local ghostConnections = {}
local playerHighlights = {}
local selectedTarget = nil
local chatCaptureActive = false

-- ========================================
-- 1. MOBILE UI BUILDER (Touch Controls)
-- ========================================
local function createMobileUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PoltergeistUI"
    screenGui.Parent = player:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    
    -- Button: Toggle Ghost Mode
    local ghostBtn = Instance.new("TextButton")
    ghostBtn.Size = UDim2.new(0, 70, 0, 50)
    ghostBtn.Position = UDim2.new(0, 10, 0.8, 0)
    ghostBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 200)
    ghostBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ghostBtn.Text = "👻\nGhost"
    ghostBtn.Font = Enum.Font.GothamBold
    ghostBtn.TextSize = 12
    ghostBtn.Parent = screenGui
    Instance.new("UICorner").Parent = ghostBtn
    
    ghostBtn.MouseButton1Click:Connect(function()
        toggleGhostMode()
    end)
    
    -- Button: Teleport to Nearest Player
    local tpBtn = Instance.new("TextButton")
    tpBtn.Size = UDim2.new(0, 70, 0, 50)
    tpBtn.Position = UDim2.new(0.15, 0, 0.8, 0)
    tpBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tpBtn.Text = "🔮\nTP"
    tpBtn.Font = Enum.Font.GothamBold
    tpBtn.TextSize = 12
    tpBtn.Parent = screenGui
    Instance.new("UICorner").Parent = tpBtn
    
    tpBtn.MouseButton1Click:Connect(function()
        teleportToNearestPlayer()
    end)
    
    -- Button: Send Ghost Message
    local msgBtn = Instance.new("TextButton")
    msgBtn.Size = UDim2.new(0, 70, 0, 50)
    msgBtn.Position = UDim2.new(0.30, 0, 0.8, 0)
    msgBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    msgBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    msgBtn.Text = "💬\nGhost Chat"
    msgBtn.Font = Enum.Font.GothamBold
    msgBtn.TextSize = 12
    msgBtn.Parent = screenGui
    Instance.new("UICorner").Parent = msgBtn
    
    msgBtn.MouseButton1Click:Connect(function()
        openGhostChat()
    end)
    
    -- Button: Player List (for ESP)
    local listBtn = Instance.new("TextButton")
    listBtn.Size = UDim2.new(0, 70, 0, 50)
    listBtn.Position = UDim2.new(0.45, 0, 0.8, 0)
    listBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    listBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    listBtn.Text = "🔍\nESP"
    listBtn.Font = Enum.Font.GothamBold
    listBtn.TextSize = 12
    listBtn.Parent = screenGui
    Instance.new("UICorner").Parent = listBtn
    
    listBtn.MouseButton1Click:Connect(function()
        toggleESP()
    end)
    
    -- Chat Display (for reading private messages)
    local chatFrame = Instance.new("Frame")
    chatFrame.Size = UDim2.new(0, 300, 0, 200)
    chatFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
    chatFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    chatFrame.BackgroundTransparency = 0.3
    chatFrame.Visible = false
    chatFrame.Parent = screenGui
    Instance.new("UICorner").Parent = chatFrame
    
    local chatScroll = Instance.new("ScrollingFrame")
    chatScroll.Size = UDim2.new(1, -10, 1, -40)
    chatScroll.Position = UDim2.new(0, 5, 0, 5)
    chatScroll.BackgroundTransparency = 1
    chatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    chatScroll.ScrollBarThickness = 4
    chatScroll.Parent = chatFrame
    
    local chatLayout = Instance.new("UIListLayout")
    chatLayout.Parent = chatScroll
    chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local closeChatBtn = Instance.new("TextButton")
    closeChatBtn.Size = UDim2.new(0, 30, 0, 30)
    closeChatBtn.Position = UDim2.new(1, -35, 0, 5)
    closeChatBtn.Text = "✕"
    closeChatBtn.TextColor3 = Color3.fromRGB(255, 0, 0)
    closeChatBtn.BackgroundTransparency = 1
    closeChatBtn.Parent = chatFrame
    closeChatBtn.MouseButton1Click:Connect(function()
        chatFrame.Visible = false
    end)
    
    return screenGui, chatFrame, chatScroll, chatLayout
end

local ui, chatFrame, chatScroll, chatLayout = createMobileUI()

-- ========================================
-- 2. ESP SYSTEM (See players through walls)
-- ========================================
local espEnabled = false
local espConnections = {}

local function toggleESP()
    espEnabled = not espEnabled
    
    if espEnabled then
        print("🔍 ESP Activated - All players highlighted")
        
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                local highlight = Instance.new("Highlight")
                highlight.Adornee = otherPlayer.Character
                highlight.FillColor = Color3.fromRGB(255, 0, 0)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = 0.5
                highlight.Name = "GhostESP"
                highlight.Parent = otherPlayer.Character
                playerHighlights[otherPlayer] = highlight
            end
        end
        
        -- Track new players joining
        local conn = Players.PlayerAdded:Connect(function(newPlayer)
            newPlayer.CharacterAdded:Connect(function(char)
                task.wait(1)
                if espEnabled and char then
                    local highlight = Instance.new("Highlight")
                    highlight.Adornee = char
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.5
                    highlight.Name = "GhostESP"
                    highlight.Parent = char
                    playerHighlights[newPlayer] = highlight
                end
            end)
        end)
        table.insert(espConnections, conn)
        
    else
        print("🔍 ESP Deactivated")
        for _, highlight in pairs(playerHighlights) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
        end
        playerHighlights = {}
        for _, conn in ipairs(espConnections) do
            pcall(conn.Disconnect, conn)
        end
        espConnections = {}
    end
end

-- ========================================
-- 3. TELEPORT TO NEAREST PLAYER
-- ========================================
local function teleportToNearestPlayer()
    if not isGhost then 
        print("❌ Must be in ghost mode to teleport!")
        return 
    end
    
    local nearest = nil
    local shortestDist = math.huge
    local ghostPos = camera.CFrame.Position
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = otherPlayer.Character.HumanoidRootPart.Position
            local dist = (targetPos - ghostPos).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearest = otherPlayer
            end
        end
    end
    
    if nearest then
        local targetPos = nearest.Character.HumanoidRootPart.Position
        camera.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 5))
        print("🔮 Teleported to " .. nearest.Name)
        
        -- Add visual effect
        local ring = Instance.new("Part")
        ring.Size = Vector3.new(1, 0.1, 1)
        ring.Position = targetPos
        ring.Anchored = true
        ring.CanCollide = false
        ring.Material = Enum.Material.Neon
        ring.BrickColor = BrickColor.new("Bright violet")
        ring.Parent = Workspace
        game:GetService("Debris"):AddItem(ring, 2)
    else
        print("❌ No players found to teleport to!")
    end
end

-- ========================================
-- 4. GHOST CHAT (Send messages while "dead")
-- ========================================
local function openGhostChat()
    if not isGhost then
        print("❌ Must be in ghost mode to use ghost chat!")
        return
    end
    
    -- Create input box for ghost message
    local ghostInput = Instance.new("TextBox")
    ghostInput.Size = UDim2.new(0, 200, 0, 40)
    ghostInput.Position = UDim2.new(0.5, -100, 0.7, 0)
    ghostInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    ghostInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    ghostInput.PlaceholderText = "👻 Type ghost message..."
    ghostInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    ghostInput.Font = Enum.Font.GothamBold
    ghostInput.TextSize = 16
    ghostInput.Name = "GhostInput"
    ghostInput.Parent = ui
    Instance.new("UICorner").Parent = ghostInput
    
    ghostInput.FocusLost:Connect(function(enterPressed)
        if enterPressed and ghostInput.Text ~= "" then
            local msg = ghostInput.Text
            ghostInput:Destroy()
            
            -- Send message through the normal chat system
            local chatBar = CoreGui:FindFirstChild("Chat") or StarterGui:FindFirstChild("Chat")
            if chatBar then
                local inputBar = chatBar:FindFirstChild("ChatInputBar") or chatBar:FindFirstChild("ChatBar")
                if inputBar then
                    inputBar.Text = msg
                    inputBar:Fire("FocusLost", true)
                    print("👻 Ghost message sent: " .. msg)
                end
            else
                -- Alternative: Use ChatService
                pcall(function()
                    ChatService:SendMessage(msg)
                end)
            end
        else
            ghostInput:Destroy()
        end
    end)
end

-- ========================================
-- 5. PRIVATE CHAT READER (Read whispers)
-- ========================================
local function capturePrivateMessages()
    print("📡 Listening for private messages...")
    
    -- Method 1: Scan CoreGui for private messages
    local function scanChat()
        local coreGui = CoreGui
        if not coreGui then return end
        
        for _, child in ipairs(coreGui:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextBox") then
                local text = child.Text or ""
                -- Detect whispers (usually contain "->" or "to" or are in a different color)
                if string.find(text, "->") or string.find(text, "whispers") or string.find(text, "to") then
                    -- Check if it's a private message (not global chat)
                    if not string.find(text, ":") or string.find(text, "->") then
                        -- Display in our custom chat frame
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, -10, 0, 20)
                        label.BackgroundTransparency = 1
                        label.TextColor3 = Color3.fromRGB(255, 200, 0)
                        label.TextXAlignment = Enum.TextXAlignment.Left
                        label.Font = Enum.Font.Gotham
                        label.TextSize = 12
                        label.Text = "💬 " .. text
                        label.Parent = chatLayout
                        
                        chatFrame.Visible = true
                        chatScroll.CanvasPosition = Vector2.new(0, chatScroll.CanvasSize.Y.Offset)
                    end
                end
            end
        end
    end
    
    -- Scan every 0.5 seconds
    while isGhost and task.wait(0.5) do
        scanChat()
    end
end

-- ========================================
-- 6. THE FAKE LEAVE / GHOST MODE ENGINE
-- ========================================
local function disableGhostMode()
    if not isGhost then return end
    
    print("👻 Disabling Poltergeist Mode...")
    isGhost = false
    chatCaptureActive = false
    
    -- Re-enable character respawning
    if player:FindFirstChild("Character") then
        local char = player.Character
        if char:FindFirstChild("Humanoid") then
            char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        end
    end
    
    -- Reset camera
    if originalCameraSubject then
        camera.CameraSubject = originalCameraSubject
        camera.CameraType = Enum.CameraType.Custom
    end
    
    -- Disconnect all ghost connections
    for _, conn in ipairs(ghostConnections) do
        pcall(conn.Disconnect, conn)
    end
    ghostConnections = {}
    
    -- Remove any ghost highlights
    for _, highlight in pairs(playerHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    playerHighlights = {}
    
    print("✅ Poltergeist Mode Disabled. You are alive again!")
end

function toggleGhostMode()
    if isGhost then
        disableGhostMode()
    else
        enableGhostMode()
    end
end

function enableGhostMode()
    if isGhost then 
        disableGhostMode() 
        return 
    end
    
    print("👻 Activating Poltergeist Mode...")
    isGhost = true
    chatCaptureActive = true
    
    -- ========================================
    -- STEP 1: Kill the character
    -- ========================================
    character = player.Character
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.Health = 0
    end
    
    -- ========================================
    -- STEP 2: Prevent respawning
    -- ========================================
    local function onCharacterAdded(newChar)
        print("🚫 Blocking respawn...")
        task.wait(0.1)
        newChar:Destroy()
        camera.CameraType = Enum.CameraType.Scriptable
    end
    
    local charAddedConn = player.CharacterAdded:Connect(onCharacterAdded)
    table.insert(ghostConnections, charAddedConn)
    
    -- ========================================
    -- STEP 3: Spoof leave remote
    -- ========================================
    local leaveRemote = ReplicatedStorage:FindFirstChild("LeaveGame") or 
                        ReplicatedStorage:FindFirstChild("PlayerLeft") or
                        game:FindFirstChild("Teleport")
    
    if leaveRemote and leaveRemote:IsA("RemoteEvent") then
        pcall(function()
            leaveRemote:FireServer()
            print("📤 Spoofed leave remote.")
        end)
    end
    
    -- ========================================
    -- STEP 4: Switch to spectator camera
    -- ========================================
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.new(Vector3.new(0, 50, 0))
    
    print("👻 POLTERGEIST MODE ACTIVE!")
    print("📌 Features:")
    print("  - Press F to toggle ghost mode")
    print("  - Press T to teleport to nearest player")
    print("  - Use on-screen buttons for mobile controls")
    print("  - All private messages are being captured!")
    
    -- ========================================
    -- STEP 5: Spectator controls (Keyboard + Mobile)
    -- ========================================
    local function updateSpectatorCamera()
        if not isGhost then return end
        
        local moveVector = Vector3.new(0, 0, 0)
        
        -- Keyboard input
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVector = moveVector - Vector3.new(0, 1, 0)
        end
        
        -- Touch/Mobile joystick simulation (tap on screen corners)
        if UserInputService:IsKeyDown(Enum.KeyCode.Up) then
            moveVector = moveVector + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Down) then
            moveVector = moveVector - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Left) then
            moveVector = moveVector - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Right) then
            moveVector = moveVector + camera.CFrame.RightVector
        end
        
        if moveVector.Magnitude > 0 then
            local newPos = camera.CFrame.Position + (moveVector.Unit * SPECTATOR_SPEED)
            camera.CFrame = CFrame.new(newPos)
        end
    end
    
    local heartbeatConn = RunService.Heartbeat:Connect(updateSpectatorCamera)
    table.insert(ghostConnections, heartbeatConn)
    
    -- ========================================
    -- STEP 6: Start private chat capture
    -- ========================================
    task.spawn(capturePrivateMessages)
    
    -- ========================================
    -- STEP 7: Keep-alive to avoid server timeout
    -- ========================================
    local function keepAlive()
        while isGhost and task.wait(30) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local rootPart = char.HumanoidRootPart
                rootPart.Velocity = Vector3.new(0, 0, 0)
                rootPart.CFrame = rootPart.CFrame
            end
        end
    end
    task.spawn(keepAlive)
end

-- ========================================
-- 7. KEYBOARD SHORTCUTS
-- ========================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == TOGGLE_KEY then
        toggleGhostMode()
    end
    
    if input.KeyCode == TELEPORT_KEY and isGhost then
        teleportToNearestPlayer()
    end
end)

-- ========================================
-- 8. CLEANUP
-- ========================================
game:BindToClose(function()
    if isGhost then
        disableGhostMode()
    end
end)

print("👻 POLTERGEIST MODE FULLY LOADED!")
print("📱 Mobile UI buttons added to screen!")
print("💀 You are now the ghost in the machine...")
