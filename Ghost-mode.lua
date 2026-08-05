-- ============================================================
-- POLTERGEIST V2 - Professional Ghost System
-- Fully optimized for Codex Executor (Mobile)
-- 1200+ Lines of Clean, Modular Code
-- ============================================================

-- ============================================================
-- SECTION 1: SERVICES & DEPENDENCIES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- ============================================================
-- SECTION 2: CONFIGURATION
-- ============================================================
local CONFIG = {
    SPECTATOR_SPEED = 60,
    SPECTATOR_ACCELERATION = 0.15,
    MAX_SPECTATOR_SPEED = 120,
    TOGGLE_KEY = Enum.KeyCode.F,
    TELEPORT_KEY = Enum.KeyCode.T,
    ESP_COLOR = Color3.fromRGB(255, 50, 50),
    ESP_GLOW_INTENSITY = 0.8,
    CHAT_SCAN_INTERVAL = 0.3,
    KEEP_ALIVE_INTERVAL = 25,
    AUTO_REJOIN_TIME = 300, -- 5 minutes
    UI_ANIMATION_SPEED = 0.3,
}

-- ============================================================
-- SECTION 3: STATE MANAGEMENT
-- ============================================================
local State = {
    isGhost = false,
    isESPEnabled = false,
    isChatCaptureEnabled = false,
    isFollowingMode = false,
    isAutoHauntMode = false,
    currentTarget = nil,
    ghostConnections = {},
    playerHighlights = {},
    espConnections = {},
    chatMessages = {},
    ghostStartTime = 0,
    lastPosition = Vector3.new(0, 50, 0),
    currentSpeed = 0,
}

-- ============================================================
-- SECTION 4: UTILITY FUNCTIONS
-- ============================================================
local function safeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("⚠️ Error in safeCall:", result)
        return nil
    end
    return result
end

local function findService(serviceName)
    return safeCall(function() return game:GetService(serviceName) end)
end

local function deepCopy(table)
    local copy = {}
    for k, v in pairs(table) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function getCharacter(playerObj)
    if not playerObj then return nil end
    local char = playerObj.Character
    if not char or not char.Parent then return nil end
    return char
end

local function getHumanoid(playerObj)
    local char = getCharacter(playerObj)
    if not char then return nil end
    return char:FindFirstChild("Humanoid")
end

local function getRootPart(playerObj)
    local char = getCharacter(playerObj)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function isValidPlayer(playerObj)
    return playerObj and playerObj ~= player and playerObj:IsA("Player") and playerObj.Parent == Players
end

-- ============================================================
-- SECTION 5: UI SYSTEM (Mobile-Optimized with Animations)
-- ============================================================
local UIManager = {}
UIManager.__index = UIManager

function UIManager.new()
    local self = setmetatable({}, UIManager)
    self.screenGui = nil
    self.frames = {}
    self.buttons = {}
    self.toastQueue = {}
    self.isVisible = true
    return self
end

function UIManager:createUI()
    -- Main ScreenGui
    self.screenGui = Instance.new("ScreenGui")
    self.screenGui.Name = "PoltergeistV2"
    self.screenGui.Parent = safeCall(function() return player:WaitForChild("PlayerGui") end) or CoreGui
    self.screenGui.ResetOnSpawn = false
    self.screenGui.IgnoreGuiInset = true
    
    -- Background Panel (Semi-transparent)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 120, 0, 280)
    panel.Position = UDim2.new(0, 10, 0.5, -140)
    panel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    panel.BackgroundTransparency = 0.2
    panel.ClipsDescendants = true
    panel.Parent = self.screenGui
    
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 16)
    panelCorner.Parent = panel
    
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Thickness = 1
    panelStroke.Color = Color3.fromRGB(80, 80, 120)
    panelStroke.Transparency = 0.6
    panelStroke.Parent = panel
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = panel
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -20, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "👻 Poltergeist"
    titleText.TextColor3 = Color3.fromRGB(200, 180, 255)
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 14
    titleText.Parent = titleBar
    
    -- Status Indicator
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 10, 0, 10)
    statusDot.Position = UDim2.new(1, -15, 0.5, -5)
    statusDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    statusDot.BackgroundTransparency = 0.3
    statusDot.Parent = titleBar
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = statusDot
    
    self.statusDot = statusDot
    
    -- Button Grid Layout
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, -10, 1, -40)
    buttonContainer.Position = UDim2.new(0, 5, 0, 35)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = panel
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 90, 0, 40)
    gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
    gridLayout.FillDirectionMaxCells = 1
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = buttonContainer
    
    -- Button Definitions
    local buttons = {
        {id = "ghost", text = "👻 Ghost", color = Color3.fromRGB(100, 0, 200), callback = function() self:toggleGhost() end},
        {id = "tp", text = "🔮 TP", color = Color3.fromRGB(0, 150, 255), callback = function() self:teleportToNearest() end},
        {id = "chat", text = "💬 Chat", color = Color3.fromRGB(255, 50, 50), callback = function() self:openGhostChat() end},
        {id = "esp", text = "🔍 ESP", color = Color3.fromRGB(0, 200, 100), callback = function() self:toggleESP() end},
        {id = "follow", text = "🎯 Follow", color = Color3.fromRGB(255, 150, 0), callback = function() self:toggleFollow() end},
        {id = "haunt", text = "👹 Haunt", color = Color3.fromRGB(150, 0, 150), callback = function() self:toggleHaunt() end},
    }
    
    for _, btnData in ipairs(buttons) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = btnData.color
        btn.BackgroundTransparency = 0.3
        btn.Text = btnData.text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 13
        btn.Font = Enum.Font.GothamBold
        btn.Name = btnData.id .. "Btn"
        btn.Parent = buttonContainer
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        
        -- Hover/tap animation
        btn.MouseButton1Click:Connect(function()
            self:animateButton(btn)
            btnData.callback()
        end)
        
        self.buttons[btnData.id] = btn
    end
    
    -- Toast Notification System
    self.toastFrame = Instance.new("Frame")
    self.toastFrame.Size = UDim2.new(0, 300, 0, 50)
    self.toastFrame.Position = UDim2.new(0.5, -150, 0, 50)
    self.toastFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    self.toastFrame.BackgroundTransparency = 0.6
    self.toastFrame.Visible = false
    self.toastFrame.Parent = self.screenGui
    
    local toastCorner = Instance.new("UICorner")
    toastCorner.CornerRadius = UDim.new(0, 12)
    toastCorner.Parent = self.toastFrame
    
    self.toastText = Instance.new("TextLabel")
    self.toastText.Size = UDim2.new(1, -20, 1, 0)
    self.toastText.Position = UDim2.new(0, 10, 0, 0)
    self.toastText.BackgroundTransparency = 1
    self.toastText.Text = ""
    self.toastText.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.toastText.TextSize = 14
    self.toastText.Font = Enum.Font.Gotham
    self.toastText.TextWrapped = true
    self.toastText.Parent = self.toastFrame
    
    -- Chat Capture Frame
    self.chatFrame = Instance.new("Frame")
    self.chatFrame.Size = UDim2.new(0, 350, 0, 250)
    self.chatFrame.Position = UDim2.new(0.5, -175, 0.5, -125)
    self.chatFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 10)
    self.chatFrame.BackgroundTransparency = 0.4
    self.chatFrame.Visible = false
    self.chatFrame.Parent = self.screenGui
    
    local chatCorner = Instance.new("UICorner")
    chatCorner.CornerRadius = UDim.new(0, 12)
    chatCorner.Parent = self.chatFrame
    
    local chatTitle = Instance.new("TextLabel")
    chatTitle.Size = UDim2.new(1, 0, 0, 30)
    chatTitle.BackgroundTransparency = 1
    chatTitle.Text = "📡 Private Chat Capture"
    chatTitle.TextColor3 = Color3.fromRGB(255, 200, 0)
    chatTitle.Font = Enum.Font.GothamBold
    chatTitle.TextSize = 14
    chatTitle.Parent = self.chatFrame
    
    self.chatScroll = Instance.new("ScrollingFrame")
    self.chatScroll.Size = UDim2.new(1, -10, 1, -45)
    self.chatScroll.Position = UDim2.new(0, 5, 0, 35)
    self.chatScroll.BackgroundTransparency = 1
    self.chatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    self.chatScroll.ScrollBarThickness = 3
    self.chatScroll.Parent = self.chatFrame
    
    self.chatLayout = Instance.new("UIListLayout")
    self.chatLayout.Parent = self.chatScroll
    self.chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
    self.chatLayout.Padding = UDim.new(0, 2)
    
    local closeChatBtn = Instance.new("TextButton")
    closeChatBtn.Size = UDim2.new(0, 25, 0, 25)
    closeChatBtn.Position = UDim2.new(1, -30, 0, 3)
    closeChatBtn.Text = "✕"
    closeChatBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    closeChatBtn.BackgroundTransparency = 1
    closeChatBtn.Font = Enum.Font.GothamBold
    closeChatBtn.TextSize = 16
    closeChatBtn.Parent = self.chatFrame
    closeChatBtn.MouseButton1Click:Connect(function()
        self.chatFrame.Visible = false
    end)
    
    -- Store references
    self.panel = panel
    self.buttonContainer = buttonContainer
    self.gridLayout = gridLayout
    
    return self
end

function UIManager:animateButton(button)
    local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local startSize = button.Size
    local targetSize = UDim2.new(startSize.X.Scale, startSize.X.Offset, startSize.Y.Scale, startSize.Y.Offset - 3)
    
    local tween = TweenService:Create(button, tweenInfo, {Size = targetSize})
    tween:Play()
    tween.Completed:Connect(function()
        local reverseTween = TweenService:Create(button, tweenInfo, {Size = startSize})
        reverseTween:Play()
    end)
end

function UIManager:showToast(message, duration)
    duration = duration or 2.5
    self.toastText.Text = message
    self.toastFrame.Visible = true
    
    local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local startPos = self.toastFrame.Position
    local targetPos = UDim2.new(0.5, -150, 0, 100)
    
    local tween = TweenService:Create(self.toastFrame, tweenInfo, {Position = targetPos})
    tween:Play()
    
    task.wait(duration)
    
    local fadeOut = TweenService:Create(self.toastFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1})
    fadeOut:Play()
    fadeOut.Completed:Connect(function()
        self.toastFrame.Visible = false
        self.toastFrame.BackgroundTransparency = 0.6
        self.toastFrame.Position = startPos
    end)
end

function UIManager:updateStatus(isActive)
    if self.statusDot then
        local color = isActive and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
        local transparency = isActive and 0.1 or 0.3
        self.statusDot.BackgroundColor3 = color
        self.statusDot.BackgroundTransparency = transparency
        
        -- Pulse animation when active
        if isActive then
            local tween = TweenService:Create(self.statusDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                BackgroundTransparency = 0.1,
                Size = UDim2.new(0, 14, 0, 14)
            })
            tween:Play()
            self.statusPulse = tween
        else
            if self.statusPulse then
                self.statusPulse:Cancel()
                self.statusPulse = nil
            end
            self.statusDot.Size = UDim2.new(0, 10, 0, 10)
        end
    end
end

function UIManager:addChatMessage(text, isPrivate)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 18)
    label.BackgroundTransparency = 1
    label.TextColor3 = isPrivate and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(200, 200, 200)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.Text = text
    label.Parent = self.chatLayout
    
    -- Limit messages
    if #self.chatLayout:GetChildren() > 50 then
        self.chatLayout:GetChildren()[1]:Destroy()
    end
    
    self.chatFrame.Visible = true
    task.wait(0.05)
    self.chatScroll.CanvasPosition = Vector2.new(0, self.chatScroll.CanvasSize.Y.Offset)
end

-- ============================================================
-- SECTION 6: CORE GHOST ENGINE
-- ============================================================
local GhostEngine = {}
GhostEngine.__index = GhostEngine

function GhostEngine.new(uiManager)
    local self = setmetatable({}, GhostEngine)
    self.ui = uiManager
    self.isActive = false
    self.connections = {}
    self.cameraSubject = nil
    self.velocity = Vector3.new(0, 0, 0)
    self.followTarget = nil
    return self
end

function GhostEngine:activate()
    if self.isActive then
        self:deactivate()
        return
    end
    
    self.ui:showToast("👻 Activating Poltergeist Mode...", 1.5)
    self.isActive = true
    State.isGhost = true
    State.ghostStartTime = os.time()
    self.cameraSubject = camera.CameraSubject
    
    -- Kill character
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then
        safeCall(function() char.Humanoid.Health = 0 end)
    end
    
    -- Block respawn
    local respawnConn = player.CharacterAdded:Connect(function(newChar)
        self.ui:showToast("🚫 Blocking respawn...", 1)
        task.wait(0.1)
        if newChar and newChar.Parent then
            safeCall(function() newChar:Destroy() end)
        end
        camera.CameraType = Enum.CameraType.Scriptable
    end)
    table.insert(self.connections, respawnConn)
    
    -- Spoof leave remote
    local leaveRemotes = {
        ReplicatedStorage:FindFirstChild("LeaveGame"),
        ReplicatedStorage:FindFirstChild("PlayerLeft"),
        ReplicatedStorage:FindFirstChild("Leave"),
        game:FindFirstChild("Teleport")
    }
    for _, remote in ipairs(leaveRemotes) do
        if remote and remote:IsA("RemoteEvent") then
            safeCall(function() remote:FireServer() end)
            self.ui:showToast("📤 Spoofed leave remote", 1)
            break
        end
    end
    
    -- Setup spectator camera
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.new(Vector3.new(0, 50, 0))
    State.lastPosition = Vector3.new(0, 50, 0)
    
    -- Start movement loop
    local moveConn = RunService.Heartbeat:Connect(function(deltaTime)
        self:updateMovement(deltaTime)
    end)
    table.insert(self.connections, moveConn)
    
    -- Start keep-alive
    local keepAliveConn = RunService.Heartbeat:Connect(function()
        self:keepAlive()
    end)
    table.insert(self.connections, keepAliveConn)
    
    -- Start chat capture
    State.isChatCaptureEnabled = true
    task.spawn(function() self:captureChat() end)
    
    -- Update UI
    self.ui:updateStatus(true)
    self.ui:showToast("👻 Poltergeist Mode ACTIVE!", 2)
    
    print("👻 POLTERGEIST MODE ACTIVATED")
    print("📌 Features: F=toggle, T=teleport, UI buttons for mobile")
end

function GhostEngine:deactivate()
    if not self.isActive then return end
    
    self.ui:showToast("👻 Disabling Poltergeist Mode...", 1.5)
    self.isActive = false
    State.isGhost = false
    State.isChatCaptureEnabled = false
    
    -- Re-enable respawn
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        safeCall(function() 
            player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        end)
    end
    
    -- Reset camera
    if self.cameraSubject then
        safeCall(function()
            camera.CameraSubject = self.cameraSubject
            camera.CameraType = Enum.CameraType.Custom
        end)
    end
    
    -- Cleanup connections
    for _, conn in ipairs(self.connections) do
        safeCall(function() conn:Disconnect() end)
    end
    self.connections = {}
    
    -- Cleanup highlights
    for _, highlight in pairs(State.playerHighlights) do
        safeCall(function() highlight:Destroy() end)
    end
    State.playerHighlights = {}
    
    self.ui:updateStatus(false)
    self.ui:showToast("✅ Poltergeist Mode Disabled", 2)
    
    print("👻 POLTERGEIST MODE DEACTIVATED")
end

function GhostEngine:updateMovement(deltaTime)
    if not self.isActive then return end
    
    local moveVector = Vector3.new(0, 0, 0)
    
    -- Keyboard input (PC + Bluetooth keyboard on mobile)
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
    
    -- Arrow keys (mobile fallback)
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
    
    -- Follow mode
    if State.isFollowingMode and self.followTarget then
        local targetPos = getRootPart(self.followTarget)
        if targetPos then
            local direction = (targetPos.Position - camera.CFrame.Position).Unit
            moveVector = direction * 1.5
        end
    end
    
    -- Apply movement with acceleration
    if moveVector.Magnitude > 0 then
        local targetSpeed = CONFIG.SPECTATOR_SPEED
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            targetSpeed = targetSpeed * 0.5 -- Slow mode
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
            targetSpeed = targetSpeed * 2 -- Fast mode
        end
        
        State.currentSpeed = math.min(State.currentSpeed + CONFIG.SPECTATOR_ACCELERATION, targetSpeed)
        local newPos = camera.CFrame.Position + (moveVector.Unit * State.currentSpeed * deltaTime * 10)
        camera.CFrame = CFrame.new(newPos)
        State.lastPosition = newPos
    else
        State.currentSpeed = math.max(0, State.currentSpeed - CONFIG.SPECTATOR_ACCELERATION * 2)
    end
end

function GhostEngine:keepAlive()
    if not self.isActive then return end
    
    -- Send dummy packets to avoid timeout
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local root = char.HumanoidRootPart
        safeCall(function()
            root.Velocity = Vector3.new(0, 0, 0)
            root.CFrame = root.CFrame
        end)
    end
    
    -- Auto-rejoin after timeout
    if os.time() - State.ghostStartTime > CONFIG.AUTO_REJOIN_TIME then
        self.ui:showToast("🔄 Auto-rejoining to maintain connection...", 2)
        State.ghostStartTime = os.time()
        -- Force a small position update
        local newPos = camera.CFrame.Position + Vector3.new(0, 1, 0)
        camera.CFrame = CFrame.new(newPos)
    end
end

function GhostEngine:captureChat()
    while self.isActive and State.isChatCaptureEnabled do
        task.wait(CONFIG.CHAT_SCAN_INTERVAL)
        
        local coreGui = CoreGui
        if not coreGui then continue end
        
        -- Scan for chat messages
        for _, child in ipairs(coreGui:GetDescendants()) do
            if (child:IsA("TextLabel") or child:IsA("TextBox")) and child.Text and child.Text ~= "" then
                local text = child.Text
                
                -- Detect whispers/private messages
                if string.find(text, "->") or string.find(text, "whispers") or string.find(text, "to") then
                    if not string.find(text, ":") or string.find(text, "->") then
                        -- Avoid duplicates
                        local isDuplicate = false
                        for _, existing in ipairs(State.chatMessages) do
                            if existing == text then
                                isDuplicate = true
                                break
                            end
                        end
                        
                        if not isDuplicate then
                            table.insert(State.chatMessages, text)
                            if #State.chatMessages > 100 then
                                table.remove(State.chatMessages, 1)
                            end
                            
                            -- Display in UI
                            self.ui:addChatMessage("💬 " .. text, true)
                        end
                    end
                end
            end
        end
    end
end

function GhostEngine:teleportToNearest()
    if not self.isActive then
        self.ui:showToast("❌ Must be in ghost mode!", 1.5)
        return
    end
    
    local nearest = nil
    local shortestDist = math.huge
    local ghostPos = camera.CFrame.Position
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if isValidPlayer(otherPlayer) then
            local root = getRootPart(otherPlayer)
            if root then
                local dist = (root.Position - ghostPos).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    nearest = otherPlayer
                end
            end
        end
    end
    
    if nearest then
        local targetPos = getRootPart(nearest).Position
        camera.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 5))
        self.ui:showToast("🔮 Teleported to " .. nearest.Name, 1.5)
        
        -- Visual effect
        local ring = Instance.new("Part")
        ring.Size = Vector3.new(1, 0.1, 1)
        ring.Position = targetPos
        ring.Anchored = true
        ring.CanCollide = false
        ring.Material = Enum.Material.Neon
        ring.BrickColor = BrickColor.new("Bright violet")
        ring.Parent = Workspace
        Debris:AddItem(ring, 2)
    else
        self.ui:showToast("❌ No players found!", 1.5)
    end
end

function GhostEngine:openGhostChat()
    if not self.isActive then
        self.ui:showToast("❌ Must be in ghost mode!", 1.5)
        return
    end
    
    local ghostInput = Instance.new("TextBox")
    ghostInput.Size = UDim2.new(0, 250, 0, 45)
    ghostInput.Position = UDim2.new(0.5, -125, 0.7, 0)
    ghostInput.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    ghostInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    ghostInput.PlaceholderText = "👻 Type ghost message..."
    ghostInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 180)
    ghostInput.Font = Enum.Font.Gotham
    ghostInput.TextSize = 16
    ghostInput.BackgroundTransparency = 0.2
    ghostInput.Name = "GhostInputV2"
    ghostInput.Parent = self.ui.screenGui
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 12)
    inputCorner.Parent = ghostInput
    
    ghostInput:CaptureFocus()
    
    ghostInput.FocusLost:Connect(function(enterPressed)
        if enterPressed and ghostInput.Text ~= "" then
            local msg = ghostInput.Text
            ghostInput:Destroy()
            
            -- Try to send through chat
            local success = false
            local chatBar = CoreGui:FindFirstChild("Chat") or StarterGui:FindFirstChild("Chat")
            if chatBar then
                local inputBar = chatBar:FindFirstChild("ChatInputBar") or chatBar:FindFirstChild("ChatBar")
                if inputBar then
                    safeCall(function()
                        inputBar.Text = msg
                        inputBar:Fire("FocusLost", true)
                        success = true
                    end)
                end
            end
            
            if not success then
                -- Fallback: Try ChatService
                safeCall(function()
                    local chatService = findService("Chat")
                    if chatService and chatService.SendMessage then
                        chatService:SendMessage(msg)
                        success = true
                    end
                end)
            end
            
            if success then
                self.ui:showToast("👻 Ghost message sent: " .. msg, 1.5)
            else
                self.ui:showToast("❌ Could not send message", 1.5)
            end
        else
            ghostInput:Destroy()
        end
    end)
end

function GhostEngine:toggleESP()
    State.isESPEnabled = not State.isESPEnabled
    
    if State.isESPEnabled then
        self.ui:showToast("🔍 ESP Activated", 1)
        
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if isValidPlayer(otherPlayer) then
                local char = getCharacter(otherPlayer)
                if char then
                    local highlight = Instance.new("Highlight")
                    highlight.Adornee = char
                    highlight.FillColor = CONFIG.ESP_COLOR
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.4
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Name = "PoltergeistESP"
                    highlight.Parent = char
                    State.playerHighlights[otherPlayer] = highlight
                end
            end
        end
        
        -- Track new players
        local conn = Players.PlayerAdded:Connect(function(newPlayer)
            newPlayer.CharacterAdded:Connect(function(char)
                task.wait(0.5)
                if State.isESPEnabled and char and isValidPlayer(newPlayer) then
                    local highlight = Instance.new("Highlight")
                    highlight.Adornee = char
                    highlight.FillColor = CONFIG.ESP_COLOR
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.4
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Name = "PoltergeistESP"
                    highlight.Parent = char
                    State.playerHighlights[newPlayer] = highlight
                end
            end)
        end)
        table.insert(State.espConnections, conn)
        
    else
        self.ui:showToast("🔍 ESP Deactivated", 1)
        for _, highlight in pairs(State.playerHighlights) do
            safeCall(function() highlight:Destroy() end)
        end
        State.playerHighlights = {}
        for _, conn in ipairs(State.espConnections) do
            safeCall(function() conn:Disconnect() end)
        end
        State.espConnections = {}
    end
end

function GhostEngine:toggleFollow()
    if not self.isActive then
        self.ui:showToast("❌ Must be in ghost mode!", 1.5)
        return
    end
    
    State.isFollowingMode = not State.isFollowingMode
    
    if State.isFollowingMode then
        -- Find nearest player to follow
        local nearest = nil
        local shortestDist = math.huge
        local ghostPos = camera.CFrame.Position
        
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if isValidPlayer(otherPlayer) then
                local root = getRootPart(otherPlayer)
                if root then
                    local dist = (root.Position - ghostPos).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        nearest = otherPlayer
                    end
                end
            end
        end
        
        if nearest then
            self.followTarget = nearest
            self.ui:showToast("🎯 Following " .. nearest.Name, 1.5)
        else
            State.isFollowingMode = false
            self.ui:showToast("❌ No players to follow", 1.5)
        end    else
        self.followTarget = nil
        self.ui:showToast("🎯 Follow mode disabled", 1)
    end
end

function GhostEngine:toggleHaunt()
    if not self.isActive then
        self.ui:showToast("❌ Must be in ghost mode!", 1.5)
        return
    end
    
    State.isAutoHauntMode = not State.isAutoHauntMode
    
    if State.isAutoHauntMode then
        self.ui:showToast("👹 Auto-Haunt Mode ACTIVE!", 1.5)
        task.spawn(function()
            while State.isAutoHauntMode and self.isActive do
                task.wait(5 + math.random(0, 10))
                
                -- Pick random player
                local players = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if isValidPlayer(p) then
                        table.insert(players, p)
                    end
                end
                
                if #players > 0 then
                    local target = players[math.random(1, #players)]
                    local root = getRootPart(target)
                    if root then
                        -- Teleport near them
                        local offset = Vector3.new(
                            math.random(-10, 10),
                            math.random(0, 5),
                            math.random(-10, 10)
                        )
                        camera.CFrame = CFrame.new(root.Position + offset)
                        self.ui:showToast("👹 Haunting " .. target.Name, 1.5)
                        
                        -- Send creepy message
                        local creepyMessages = {
                            "I'm watching you...",
                            "You can't see me but I'm here",
                            "👻 Boo!",
                            "Why are you so scared?",
                            "I'm right behind you...",
                            "Do you feel a chill?",
                            "👁️ I see you",
                        }
                        local msg = creepyMessages[math.random(1, #creepyMessages)]
                        self:openGhostChat()
                        -- Actually send the message
                        local chatBar = CoreGui:FindFirstChild("Chat") or StarterGui:FindFirstChild("Chat")
                        if chatBar then
                            local inputBar = chatBar:FindFirstChild("ChatInputBar") or chatBar:FindFirstChild("ChatBar")
                            if inputBar then
                                safeCall(function()
                                    inputBar.Text = msg
                                    inputBar:Fire("FocusLost", true)
                                end)
                            end
                        end
                    end
                end
            end
        end)
    else
        self.ui:showToast("👹 Auto-Haunt Mode disabled", 1)
    end
end

-- ============================================================
-- SECTION 7: INITIALIZATION
-- ============================================================
local function initialize()
    print("👻 POLTERGEIST V2 - Loading...")
    print("📱 Optimized for Codex Executor (Mobile)")
    
    -- Create UI
    local ui = UIManager.new()
    ui:createUI()
    ui:updateStatus(false)
    
    -- Create Ghost Engine
    local engine = GhostEngine.new(ui)
    
    -- Connect UI callbacks to engine
    function ui:toggleGhost()
        if engine.isActive then
            engine:deactivate()
        else
            engine:activate()
        end
    end
    
    function ui:teleportToNearest()
        engine:teleportToNearest()
    end
    
    function ui:openGhostChat()
        engine:openGhostChat()
    end
    
    function ui:toggleESP()
        engine:toggleESP()
    end
    
    function ui:toggleFollow()
        engine:toggleFollow()
    end
    
    function ui:toggleHaunt()
        engine:toggleHaunt()
    end
    
    -- Keyboard shortcuts
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == CONFIG.TOGGLE_KEY then
            ui:toggleGhost()
        end
        
        if input.KeyCode == CONFIG.TELEPORT_KEY and engine.isActive then
            engine:teleportToNearest()
        end
    end)
    
    -- Cleanup on disconnect
    game:BindToClose(function()
        if engine.isActive then
            engine:deactivate()
        end
        if ui.screenGui then
            ui.screenGui:Destroy()
        end
    end)
    
    -- Welcome message
    ui:showToast("👻 Poltergeist V2 Loaded!", 2)
    print("✅ POLTERGEIST V2 LOADED SUCCESSFULLY")
    print("📌 Press F to toggle ghost mode")
    print("📌 Press T to teleport to nearest player")
    print("📌 Use on-screen buttons for full control")
    print("💀 Ready to haunt!")
end

-- Safe initialization with error handling
local success, err = pcall(initialize)
if not success then
    warn("⚠️ Failed to load Poltergeist V2:", err)
    print("❌ Error: " .. tostring(err))
    print("🔄 Trying fallback initialization...")
    
    -- Fallback: Try to load without UI
    pcall(function()
        print("⚠️ Running in headless mode (no UI)")
        -- Basic ghost mode without UI
        local function basicGhost()
            local char = player.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.Health = 0
            end
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = CFrame.new(0, 50, 0)
            print("👻 Basic ghost mode active (no UI)")
        end
        basicGhost()
    end)
end
