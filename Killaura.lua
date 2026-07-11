-- For 77790193039862 (Game-ID)
local RADIUS = 30.5
local COOLDOWN = 0.01

if _G.KillAura2Running then
    if _G.KillAura2Connection then
        _G.KillAura2Connection:Disconnect()
        _G.KillAura2Connection = nil
    end
    _G.KillAura2Running = nil
end

_G.KillAura2Running = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local HitRequest = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("HitRequest")
if not HitRequest or not HitRequest:IsA("RemoteEvent") then
    warn("[KillAura] HitRequest not found.")
    _G.KillAura2Running = nil
    return
end

local function getPlayerHitbox(character)
    if not character then return nil end
    return character:FindFirstChild("PlayerHitbox")
end

local function getClosestTarget()
    local closest = nil
    local closestDist = RADIUS

    local originPart = getPlayerHitbox(Character)
    if not originPart then return nil end
    local origin = originPart.Position

    local otherCharacters = workspace:FindFirstChild("OtherCharacters")
    if not otherCharacters then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == Player then continue end
        local fakeChar = otherCharacters:FindFirstChild(player.Name .. "_FakeCharacter")
        if not fakeChar then continue end
        local targetPart = getPlayerHitbox(fakeChar)
        if not targetPart then continue end
        local distance = (targetPart.Position - origin).Magnitude
        if distance <= RADIUS and distance < closestDist then
            closestDist = distance
            closest = {
                Player = player,
                FakeCharacter = fakeChar,
                Position = targetPart.Position
            }
        end
    end
    return closest
end

local lastAttack = 0

local function onHeartbeat()
    local now = tick()
    if now - lastAttack < COOLDOWN then return end

    local target = getClosestTarget()
    if not target then return end

    local originPart = getPlayerHitbox(Character)
    if not originPart then return end
    local origin = originPart.Position
    local direction = (target.Position - origin).Unit

    HitRequest:FireServer(target.Position, direction, target.FakeCharacter, target.Player)
    lastAttack = now
end

_G.KillAura2Connection = RunService.Heartbeat:Connect(onHeartbeat)

Player.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
end)

warn("[KillAura] Active | Radius: " .. RADIUS .. " | Cooldown: " .. COOLDOWN .. "s")
