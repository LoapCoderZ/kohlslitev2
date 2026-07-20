local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

local function Log(msg)
    print("[HitboxChanger] " .. tostring(msg))
end

local RayfieldSuccess, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)
if not RayfieldSuccess or not Rayfield then
    Log("Rayfield failed to load - using fallback")
end

local Window = Rayfield and Rayfield:CreateWindow({
    Name = "Hitbox Changer",
    LoadingTitle = "Loading...",
    ConfigurationSaving = {Enabled = true, FolderName = "HitboxChanger", FileName = "Settings"},
    KeySystem = false
}) or nil

local MainTab = Window and Window:CreateTab("Main", 4483362458) or nil
local TargetingTab = Window and Window:CreateTab("Targeting", 4483362459) or nil

local Enabled = false
local ModifiedParts = {}
local CurrentSize = Vector3.new(5, 5, 5)
local TargetPartName = "Head"
local TargetMode = "Players"
local TeamCheck = true
local CanCollide = false
local CanTouch = true
local Transparency = 0.3
local AutoSize = false
local MinSize = Vector3.new(1, 1, 1)
local MaxDistance = 30
local NPCRateLimit = 1
local lastNPCProcessTime = 0
local Connections = {}
local NPCWatcher = nil
local HealthConnections = {}
local MAX_MODIFIED_PARTS = 50

if _G.HitboxChanger and _G.HitboxChanger.Cleanup then
    _G.HitboxChanger.Cleanup()
end

local function GetAllParts(model)
    local parts = {}
    if not model then return parts end
    local function scan(parent, depth)
        if depth > 5 then return end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") then
                table.insert(parts, child)
            end
            if child:IsA("Model") or child:IsA("Folder") or child:IsA("Tool") or child:IsA("Accessory") then
                scan(child, (depth or 0) + 1)
            end
        end
    end
    scan(model, 0)
    return parts
end

local function GetTargetPart(char)
    local allParts = GetAllParts(char)
    for _, part in ipairs(allParts) do
        if part.Name == TargetPartName then
            return part
        end
    end
    local handler = char:FindFirstChild("HitboxHandler")
    if handler then
        for _, part in ipairs(handler:GetChildren()) do
            if part:IsA("BasePart") and part.Name == TargetPartName then
                return part
            end
        end
    end
    return nil
end

local function IsNPC(char)
    if not char then return false end
    if Players:GetPlayerFromCharacter(char) then return false end
    return char:FindFirstChildOfClass("Humanoid") ~= nil
end

local function CalculateDynamicSize(part)
    if not part or not LocalPlayer.Character then return CurrentSize end
    local primary = LocalPlayer.Character.PrimaryPart
    if not primary then return CurrentSize end
    local dist = (part.Position - primary.Position).Magnitude
    if dist >= MaxDistance then
        return CurrentSize
    end
    local t = dist / MaxDistance
    local size = MinSize + (CurrentSize - MinSize) * t
    return size
end

local function ModifyPart(part)
    if not part or not part:IsA("BasePart") or ModifiedParts[part] then return end
    if #ModifiedParts >= MAX_MODIFIED_PARTS then return end
    local originalSize = part.Size
    local originalTransparency = part.Transparency
    local originalCanTouch = part.CanTouch
    local originalCanCollide = part.CanCollide
    local initialSize = AutoSize and CalculateDynamicSize(part) or CurrentSize
    pcall(function()
        part.Size = initialSize
        part.Transparency = Transparency
        part.CanTouch = CanTouch
        part.CanCollide = CanCollide
    end)
    ModifiedParts[part] = {
        OriginalSize = originalSize,
        OriginalTransparency = originalTransparency,
        OriginalCanTouch = originalCanTouch,
        OriginalCanCollide = originalCanCollide
    }
end

local function ResetPart(part)
    if not part or not ModifiedParts[part] then return end
    local data = ModifiedParts[part]
    pcall(function()
        part.Size = data.OriginalSize
        part.Transparency = data.OriginalTransparency
        part.CanTouch = data.OriginalCanTouch
        part.CanCollide = data.OriginalCanCollide
    end)
    ModifiedParts[part] = nil
end

local function ResetAllParts()
    for part, _ in pairs(ModifiedParts) do
        ResetPart(part)
    end
    ModifiedParts = {}
end

local function ProcessCharacter(char)
    if not char or not Enabled then return end
    if TeamCheck then
        local player = Players:GetPlayerFromCharacter(char)
        if player and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            return
        end
    end
    local part = GetTargetPart(char)
    if part then
        ModifyPart(part)
    end
end

local function ResetCharacter(char)
    if not char then return end
    local part = GetTargetPart(char)
    if part then ResetPart(part) end
end

local function GetTargetCharacters()
    local targets = {}
    if TargetMode == "Players" or TargetMode == "Both" then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                table.insert(targets, player.Character)
            end
        end
    end
    if TargetMode == "NPCs" or TargetMode == "Both" then
        local now = tick()
        if now - lastNPCProcessTime >= NPCRateLimit then
            lastNPCProcessTime = now
            for _, model in ipairs(Workspace:GetDescendants()) do
                if model:IsA("Model") and model ~= LocalPlayer.Character then
                    if IsNPC(model) then
                        table.insert(targets, model)
                    end
                end
            end
        end
    end
    return targets
end

local function RefreshTargets()
    ResetAllParts()
    if not Enabled then return end
    local targets = GetTargetCharacters()
    for _, char in ipairs(targets) do
        ProcessCharacter(char)
    end
end

local autoSizeRunning = false
local autoSizeConnection

local function StartAutoSizeLoop()
    if autoSizeRunning then return end
    autoSizeRunning = true
    autoSizeConnection = RunService.Heartbeat:Connect(function()
        if not Enabled or not AutoSize or not LocalPlayer.Character then return end
        local primary = LocalPlayer.Character.PrimaryPart
        if not primary then return end
        for part, _ in pairs(ModifiedParts) do
            if not part or not part.Parent then
                ModifiedParts[part] = nil
            else
                local newSize = CalculateDynamicSize(part)
                pcall(function()
                    part.Size = newSize
                end)
            end
        end
    end)
end

local function StopAutoSizeLoop()
    if autoSizeConnection then
        autoSizeConnection:Disconnect()
        autoSizeConnection = nil
    end
    autoSizeRunning = false
end

local function OnCharacterAdded(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    task.wait(0.1)
    if hum.Health > 0 then
        ProcessCharacter(char)
    end
    local healthConn
    healthConn = hum.HealthChanged:Connect(function(health)
        if health <= 0 then
            ResetCharacter(char)
        elseif health > 0 then
            ProcessCharacter(char)
        end
    end)
    HealthConnections[char] = healthConn
end

local function OnCharacterRemoving(char)
    ResetCharacter(char)
    local conn = HealthConnections[char]
    if conn then
        conn:Disconnect()
        HealthConnections[char] = nil
    end
end

local function SetupPlayerEvents()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if player.Character then
                OnCharacterAdded(player.Character)
            end
            player.CharacterAdded:Connect(OnCharacterAdded)
            player.CharacterRemoving:Connect(OnCharacterRemoving)
        end
    end
    Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            player.CharacterAdded:Connect(OnCharacterAdded)
            player.CharacterRemoving:Connect(OnCharacterRemoving)
        end
    end)
end

local function SetupNPCWatcher()
    if NPCWatcher then NPCWatcher:Disconnect() end
    NPCWatcher = Workspace.DescendantAdded:Connect(function(desc)
        if Enabled and (TargetMode == "NPCs" or TargetMode == "Both") then
            if desc:IsA("Model") and IsNPC(desc) then
                local now = tick()
                if now - lastNPCProcessTime >= NPCRateLimit then
                    lastNPCProcessTime = now
                    ProcessCharacter(desc)
                end
            end
        end
    end)
end

local function Toggle()
    Enabled = not Enabled
    if not Enabled then
        ResetAllParts()
        StopAutoSizeLoop()
        Log("Disabled")
    else
        RefreshTargets()
        StartAutoSizeLoop()
        Log("Enabled")
    end
end

_G.HitboxChanger = {
    Cleanup = function()
        ResetAllParts()
        StopAutoSizeLoop()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                ResetCharacter(player.Character)
            end
            local conn = HealthConnections[player.Character]
            if conn then
                conn:Disconnect()
                HealthConnections[player.Character] = nil
            end
        end
        if NPCWatcher then
            NPCWatcher:Disconnect()
            NPCWatcher = nil
        end
        Log("Cleaned up previous instance")
    end
}

SetupPlayerEvents()
SetupNPCWatcher()
StartAutoSizeLoop()
Log("Setup complete")

if MainTab then
    MainTab:CreateToggle({
        Name = "Enable Hitbox Changer",
        CurrentValue = false,
        Flag = "Toggle1",
        Callback = function(Value) Toggle() end
    })

    MainTab:CreateInput({
        Name = "Size (studs)",
        PlaceholderText = "5",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local num = tonumber(Text)
            if num and num > 0 then
                CurrentSize = Vector3.new(num, num, num)
                if Enabled then RefreshTargets() end
                Log("Size set to " .. num)
            else
                Log("Invalid number")
            end
        end
    })

    MainTab:CreateToggle({
        Name = "Team Check",
        CurrentValue = true,
        Flag = "Toggle2",
        Callback = function(Value)
            TeamCheck = Value
            if Enabled then RefreshTargets() end
            Log("TeamCheck: " .. tostring(Value))
        end
    })

    MainTab:CreateToggle({
        Name = "Can Collide",
        CurrentValue = false,
        Flag = "Toggle3",
        Callback = function(Value)
            CanCollide = Value
            if Enabled then RefreshTargets() end
            Log("CanCollide: " .. tostring(Value))
        end
    })

    MainTab:CreateToggle({
        Name = "Can Touch",
        CurrentValue = true,
        Flag = "Toggle4",
        Callback = function(Value)
            CanTouch = Value
            if Enabled then RefreshTargets() end
            Log("CanTouch: " .. tostring(Value))
        end
    })

    MainTab:CreateInput({
        Name = "Part Name",
        PlaceholderText = "Hitbox_Head",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if Text and Text ~= "" then
                TargetPartName = Text
                if Enabled then RefreshTargets() end
                Log("Part name: " .. Text)
            end
        end
    })

    Log("Main GUI controls created")
else
    local UIS = game:GetService("UserInputService")
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            Toggle()
        end
    end)
    Log("Fallback mode: Press Insert to toggle")
end

if TargetingTab then
    TargetingTab:CreateDropdown({
        Name = "Target Mode",
        Options = {"Players", "NPCs", "Both"},
        CurrentOption = "Players",
        Flag = "Dropdown1",
        Callback = function(Option)
            TargetMode = Option
            if Enabled then RefreshTargets() end
            Log("Target mode: " .. Option)
        end
    })

    TargetingTab:CreateSlider({
        Name = "Transparency",
        Range = {0, 1},
        Increment = 0.05,
        Suffix = "",
        CurrentValue = 0.3,
        Flag = "Slider1",
        Callback = function(Value)
            Transparency = Value
            if Enabled then
                for part, _ in pairs(ModifiedParts) do
                    pcall(function()
                        part.Transparency = Transparency
                    end)
                end
            end
            Log("Transparency set to " .. Value)
        end
    })

    TargetingTab:CreateToggle({
        Name = "Auto-Size (dynamic shrink)",
        CurrentValue = false,
        Flag = "Toggle5",
        Callback = function(Value)
            AutoSize = Value
            if not Value then
                for part, _ in pairs(ModifiedParts) do
                    pcall(function()
                        part.Size = CurrentSize
                    end)
                end
            end
            Log("AutoSize: " .. tostring(Value))
        end
    })

    TargetingTab:CreateInput({
        Name = "Min Size (when near)",
        PlaceholderText = "1",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local num = tonumber(Text)
            if num and num > 0 then
                MinSize = Vector3.new(num, num, num)
                Log("Min size set to " .. num)
            else
                Log("Invalid number")
            end
        end
    })

    TargetingTab:CreateInput({
        Name = "Max Distance (studs)",
        PlaceholderText = "30",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local num = tonumber(Text)
            if num and num > 0 then
                MaxDistance = num
                Log("Max distance set to " .. num)
            else
                Log("Invalid number")
            end
        end
    })

    Log("Targeting GUI controls created")
end
