getgenv().scriptname = "KohlsLite"
getgenv().klversion = "0.3"
local prefix = getgenv().prefix or "."

local function SendCommand(cmd)
    local args = {cmd}
    game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("SayMessageRequest"):FireServer(unpack(args))
end

local function Speak(msg) SendCommand(msg) end
local function Chat(msg) Speak(msg) end

local function Notify(msg, dur)
    game.StarterGui:SetCore("SendNotification", {
        Title = getgenv().scriptname.." "..getgenv().klversion,
        Text = msg,
        Duration = dur or 1
    })
end

local whitelist = {"YT_MATHEUSMODZ5"}
local pwl = {"YT_MATHEUSMODZ5", "ScriptingProgrammer"}

local function billboardGui(text, color)
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.new(0,100,0,50)
    gui.StudsOffset = Vector3.new(0,3,0)
    local lbl = Instance.new("TextLabel", gui)
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.TextScaled = true
    lbl.Font = Enum.Font.ArialBold
    return gui
end

local function addBillboard(player)
    local text, color
    if player.Name == "YT_MATHEUSMODZ5" then
        text = "Owner Skid"; color = Color3.new(1,0,0)
    elseif table.find(pwl, player.Name) then
        text = "KL Owner"; color = Color3.new(0,0,1)
    else return end
    player.CharacterAdded:Connect(function(char)
        local head = char:WaitForChild("Head")
        if player ~= game.Players.LocalPlayer then
            local g = billboardGui(text, color)
            g.Adornee = head; g.Parent = head
        end
    end)
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head and player ~= game.Players.LocalPlayer then
            local g = billboardGui(text, color)
            g.Adornee = head; g.Parent = head
        end
    end
end

game.Players.PlayerAdded:Connect(addBillboard)
for _,v in pairs(game.Players:GetPlayers()) do addBillboard(v) end

game.Players.PlayerAdded:Connect(function(p)
    if p.Name == "YT_MATHEUSMODZ5" then
        task.wait(1)
        Speak("m Me!!!")
        if not table.find(whitelist, p.Name) then
            table.insert(whitelist, p.Name)
            Speak("h Whitelisted YT_MATHEUSMODZ5")
        end
    end
end)

local folderName = "YT_KohlsLite"
local configFile = folderName .. "/config.json"

local config = {
    spam_delay = 0.1,
    super_delay = 0.001,
    super_count = 250,
    explode_count = 100,
    explode_interval = 0.8,
    prefix = prefix,
    autorun = {".nkill", ".antijail", ".antifreeze", ".autof3x"}
}

local function ensureFolder()
    if writefile and not isfolder(folderName) then
        makefolder(folderName)
    end
end

local function loadConfig()
    if writefile and isfile(configFile) then
        local data = game:GetService("HttpService"):JSONDecode(readfile(configFile))
        for k,v in pairs(data) do
            config[k] = v
        end
        if config.prefix then
            prefix = config.prefix
            getgenv().prefix = prefix
        end
    end
end

local function saveConfig()
    if writefile then
        ensureFolder()
        local data = game:GetService("HttpService"):JSONEncode(config)
        writefile(configFile, data)
    end
end

ensureFolder()
loadConfig()

local function setPrefix(newPrefix)
    if newPrefix and newPrefix ~= "" then
        prefix = newPrefix
        getgenv().prefix = newPrefix
        config.prefix = newPrefix
        saveConfig()
        Notify("Prefix changed to "..newPrefix)
    end
end

local spam_running = false
local spam_commands = {}
local spam_index = 1
local spam_timer = nil

local super_running = false
local super_commands = {}
local super_thread = nil

local platform_enabled = false
local platform_part = nil

local softlock_enabled = false
local softlock_target = nil
local softlock_thread = nil
local softlock_last_state = nil

local regen_loop_enabled = false

local antijail_enabled = false
local antifreeze_enabled = false
local antipunish_enabled = false
local autof3x_done = false

local admin_enabled = false
local admin_thread = nil

local loopgrab_enabled = false
local loopgrab_thread = nil

local function togglePlatform(on)
    if on then
        if platform_part then platform_part:Destroy() end
        platform_part = Instance.new("Part")
        platform_part.Size = Vector3.new(5,5,5)
        platform_part.Transparency = 1
        platform_part.Anchored = true
        platform_part.CanCollide = true
        platform_part.Material = Enum.Material.SmoothPlastic
        platform_part.Parent = workspace
        platform_enabled = true
        Notify("Platform enabled.")
    else
        if platform_part then platform_part:Destroy(); platform_part = nil end
        platform_enabled = false
        Notify("Platform disabled.")
    end
end

task.spawn(function()
    while true do
        task.wait()
        if platform_enabled and platform_part and game.Players.LocalPlayer.Character then
            local root = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                platform_part.CFrame = CFrame.new(root.Position.X, -1, root.Position.Z)
            end
        end
    end
end)

local function spamStep()
    if not spam_running or #spam_commands == 0 then return end
    local cmd = spam_commands[spam_index]
    if cmd then
        SendCommand(cmd)
        spam_index = spam_index + 1
        if spam_index > #spam_commands then spam_index = 1 end
    end
    spam_timer = task.delay(config.spam_delay, spamStep)
end

local function runSuper()
    super_running = true
    for iter = 1, config.super_count do
        if not super_running then break end
        for _, cmd in ipairs(super_commands) do
            if not super_running then break end
            SendCommand(cmd)
            task.wait(config.super_delay)
        end
    end
    super_running = false
    Notify("Super finished.")
end

local function runExplode(target)
    if not target then target = "me" end
    for i = 1, config.explode_count do
        SendCommand("explode "..target)
        SendCommand("respawn "..target)
        task.wait(config.explode_interval)
    end
end

local function parseCommands(str)
    local cmds = {}
    for part in string.gmatch(str, "[^;]+") do
        local trimmed = part:gsub("^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then table.insert(cmds, trimmed) end
    end
    return cmds
end

local function findPlayer(input)
    if not input or input == "" then return nil end
    input = input:lower()
    for _, p in pairs(game.Players:GetPlayers()) do
        local name = p.Name:lower()
        local display = p.DisplayName:lower()
        if name == input or display == input then
            return p
        end
        if string.sub(name, 1, #input) == input or string.sub(display, 1, #input) == input then
            return p
        end
    end
    return nil
end

local function softlockLoop()
    softlock_last_state = nil
    while softlock_enabled and softlock_target do
        local target = softlock_target
        local exists = target and workspace:FindFirstChild(target.Name)
        local state = exists and "punish" or "none"

        if state ~= softlock_last_state then
            if state == "punish" then
                SendCommand("punish "..target.Name)
            end
            softlock_last_state = state
        end
        task.wait(0.5)
    end
    softlock_last_state = nil
end

local function makeChat(target, message)
    if not target or not message then return end
    local plr = findPlayer(target)
    if not plr then Notify("Player not found.") return end
    local name = plr.Name
    local formatted = ""
    for i = 1, #message do
        local c = string.sub(message, i, i)
        if i < #message then
            formatted = formatted .. c .. "\226\128\139"
        else
            formatted = formatted .. c
        end
    end
    local cmd = "hint \n\n\n\n\n\n\n\n" .. name .. ": " .. formatted .. "\n\n\n\n\n\n\n\n/test"
    SendCommand(cmd)
end

local function doRegen()
    local regen = workspace:FindFirstChild("Terrain"):FindFirstChild("_Game"):FindFirstChild("Admin"):FindFirstChild("Regen")
    if regen and regen:FindFirstChild("ClickDetector") then
        if fireclickdetector then
            fireclickdetector(regen.ClickDetector, 0)
        else
            Notify("fireclickdetector not supported.")
        end
    else
        Notify("Regen not found.")
    end
end

local function regenLoop()
    regen_loop_enabled = true
    while regen_loop_enabled do
        doRegen()
        task.wait(0.5)
    end
end

local function nKill()
    local obby = workspace:FindFirstChild("Tabby"):FindFirstChild("Admin_House"):FindFirstChild("Obby")
    if not obby then
        Notify("Obby not found.")
        return
    end
    local count = 0
    for _, part in pairs(obby:GetChildren()) do
        if part:IsA("BasePart") then
            for _, child in pairs(part:GetChildren()) do
                if child:IsA("TouchTransmitter") then
                    child:Destroy()
                    count = count + 1
                end
            end
        end
    end
    Notify("Removed "..count.." TouchInterests from Obby.")
end

-- Anti-jail 
task.spawn(function()
    local lastJailed = false
    while true do
        task.wait(0.05)
        if antijail_enabled then
            local name = game.Players.LocalPlayer.Name
            local jail = workspace:FindFirstChild(name.."'s jail")
            if jail then
                if not lastJailed then
                    SendCommand("unjail me")
                    lastJailed = true
                end
            else
                lastJailed = false
            end
        else
            lastJailed = false
        end
    end
end)

-- Anti-freeze 
task.spawn(function()
    local lastFrozen = false
    while true do
        task.wait(0.05)
        if antifreeze_enabled then
            local char = game.Players.LocalPlayer.Character
            if char then
                local anchored = false
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Anchored then
                        anchored = true
                        break
                    end
                end
                if anchored then
                    if not lastFrozen then
                        SendCommand("unfreeze me")
                        lastFrozen = true
                    end
                else
                    lastFrozen = false
                end
            else
                lastFrozen = false
            end
        else
            lastFrozen = false
        end
    end
end)

-- Anti-punish 
task.spawn(function()
    local lastPunished = false
    while true do
        task.wait(0.05)
        if antipunish_enabled then
            local player = game.Players.LocalPlayer
            local char = player.Character
            if not char or not char.Parent or char.Parent ~= workspace then
                if not lastPunished then
                    SendCommand("unpunish me")
                    lastPunished = true
                end
            else
                lastPunished = false
            end
        else
            lastPunished = false
        end
    end
end)

-- Admin loop (try to get admin, regen if no pad available)
local function adminLoop()
    while admin_enabled do
        local playerName = game.Players.LocalPlayer.Name
        local hasAdmin = false
        local pads = workspace:FindFirstChild("Terrain"):FindFirstChild("_Game"):FindFirstChild("Admin"):FindFirstChild("Pads")
        if pads then
            for _, pad in pairs(pads:GetChildren()) do
                if pad.Name == playerName .. "'s admin" then
                    hasAdmin = true
                    break
                end
            end
            if not hasAdmin then
                local clicked = false
                for _, pad in pairs(pads:GetChildren()) do
                    if pad:FindFirstChild("Head") and pad.Head:FindFirstChild("TouchInterest") then
                        local head = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Head")
                        if head and firetouchinterest then
                            firetouchinterest(pad.Head, head, 0)
                            firetouchinterest(pad.Head, head, 1)
                            firetouchinterest(pad.Head, head, 0)
                            clicked = true
                            break
                        end
                    end
                end
                if not clicked then
                    doRegen()
                end
            end
        end
        task.wait(0.1)
    end
end

-- Loopgrab: ensure all pads are owned by player, try to touch if not, regen as fallback
local function loopgrabLoop()
    while loopgrab_enabled do
        local playerName = game.Players.LocalPlayer.Name
        local pads = workspace:FindFirstChild("Terrain"):FindFirstChild("_Game"):FindFirstChild("Admin"):FindFirstChild("Pads")
        if pads then
            local allMine = true
            for _, pad in pairs(pads:GetChildren()) do
                if pad.Name ~= playerName .. "'s admin" then
                    allMine = false
                    -- Try to grab this pad
                    local grabbed = false
                    if pad:FindFirstChild("Head") and pad.Head:FindFirstChild("TouchInterest") then
                        local head = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Head")
                        if head and firetouchinterest then
                            firetouchinterest(pad.Head, head, 0)
                            firetouchinterest(pad.Head, head, 1)
                            firetouchinterest(pad.Head, head, 0)
                            grabbed = true
                        end
                    end
                    if not grabbed then
                        -- If can't grab, regen to reset pads
                        doRegen()
                        break -- after regen, restart the loop
                    end
                end
            end
            if allMine then
                -- All pads are mine, do nothing
            end
        end
        task.wait(0.001) -- 1ms loop for instant response
    end
end

local function handleCommand(msg)
    local args = string.split(msg, " ")
    local cmd = args[1]:gsub("^"..prefix, "")

    if cmd == "explode" then
        local target = args[2] or "me"
        runExplode(target)
        Notify("Exploded "..target.." "..config.explode_count.." times.")
        return
    end

    if cmd == "platform" then
        togglePlatform(not platform_enabled)
        return
    end

    if cmd == "spam" then
        local rest = table.concat(args, " ", 2)
        if rest == "" then Notify("Usage: .spam cmd1; cmd2; ...") return end
        spam_commands = parseCommands(rest)
        if #spam_commands == 0 then Notify("No valid commands.") return end
        spam_index = 1
        if spam_running then
            spam_running = false
            if spam_timer then task.cancel(spam_timer); spam_timer = nil end
        end
        spam_running = true
        spamStep()
        Notify("Spamming "..#spam_commands.." commands.")
        return
    end

    if cmd == "stopspam" then
        spam_running = false
        if spam_timer then task.cancel(spam_timer); spam_timer = nil end
        Notify("Spam stopped.")
        return
    end

    if cmd == "super" then
        local rest = table.concat(args, " ", 2)
        if rest ~= "" then
            super_commands = parseCommands(rest)
            if #super_commands == 0 then Notify("No valid commands.") return end
        end
        if #super_commands == 0 then Notify("Usage: .super cmd1; cmd2; ...") return end
        if super_running then Notify("Super already running.") return end
        super_running = true
        task.spawn(runSuper)
        Notify("Super started: "..#super_commands.." commands.")
        return
    end

    if cmd == "stopsuper" then
        super_running = false
        Notify("Super stopped.")
        return
    end

    if cmd == "spamdelay" then
        local val = tonumber(args[2])
        if val and val > 0 then config.spam_delay = val; saveConfig(); Notify("Spam delay set to "..val.."s") end
        return
    end

    if cmd == "superdelay" then
        local val = tonumber(args[2])
        if val and val > 0 then config.super_delay = val; saveConfig(); Notify("Super delay set to "..val.."s") end
        return
    end

    if cmd == "supercount" then
        local val = tonumber(args[2])
        if val and val > 0 then config.super_count = val; saveConfig(); Notify("Super count set to "..val) end
        return
    end

    if cmd == "explodecount" then
        local val = tonumber(args[2])
        if val and val > 0 then config.explode_count = val; saveConfig(); Notify("Explode count set to "..val) end
        return
    end

    if cmd == "softlock" then
        if not args[2] then Notify("Usage: .softlock <target>") return end
        local target = findPlayer(args[2])
        if not target then Notify("Player not found.") return end
        if table.find(pwl, target.Name) then Notify("Cannot softlock whitelisted player.") return end
        if softlock_enabled then
            softlock_enabled = false
            if softlock_thread and coroutine.status(softlock_thread) ~= "dead" then
                task.wait()
            end
        end
        softlock_target = target
        softlock_enabled = true
        softlock_thread = task.spawn(softlockLoop)
        Notify("Softlock on "..target.Name)
        return
    end

    if cmd == "unsoftlock" then
        softlock_enabled = false
        softlock_target = nil
        softlock_last_state = nil
        Notify("Softlock disabled.")
        return
    end

    if cmd == "makechat" then
        if #args < 3 then Notify("Usage: .makechat <target> <message>") return end
        local target = args[2]
        local message = table.concat(args, " ", 3)
        makeChat(target, message)
        Notify("Sent makechat to "..target)
        return
    end

    if cmd == "regen" then
        doRegen()
        Notify("Regen clicked.")
        return
    end

    if cmd == "loopregen" then
        if regen_loop_enabled then
            Notify("Loopregen already running.")
            return
        end
        task.spawn(regenLoop)
        Notify("Loopregen started (every 0.5s).")
        return
    end

    if cmd == "stopregen" then
        regen_loop_enabled = false
        Notify("Loopregen stopped.")
        return
    end

    if cmd == "nkill" then
        nKill()
        return
    end

    if cmd == "antijail" then
        antijail_enabled = true
        Notify("Anti-jail enabled.")
        return
    end

    if cmd == "unantijail" then
        antijail_enabled = false
        Notify("Anti-jail disabled.")
        return
    end

    if cmd == "antifreeze" then
        antifreeze_enabled = true
        Notify("Anti-freeze enabled.")
        return
    end

    if cmd == "unantifreeze" then
        antifreeze_enabled = false
        Notify("Anti-freeze disabled.")
        return
    end

    if cmd == "antipunish" then
        antipunish_enabled = true
        Notify("Anti-punish enabled.")
        return
    end

    if cmd == "unantipunish" then
        antipunish_enabled = false
        Notify("Anti-punish disabled.")
        return
    end

    if cmd == "admin" then
        if admin_enabled then
            Notify("Admin loop already running.")
            return
        end
        admin_enabled = true
        admin_thread = task.spawn(adminLoop)
        Notify("Admin loop started.")
        return
    end

    if cmd == "unadmin" then
        admin_enabled = false
        if admin_thread then
            admin_thread = nil
        end
        Notify("Admin loop stopped.")
        return
    end

    if cmd == "loopgrab" then
        if loopgrab_enabled then
            Notify("Loopgrab already running.")
            return
        end
        loopgrab_enabled = true
        loopgrab_thread = task.spawn(loopgrabLoop)
        Notify("Loopgrab started .")
        return
    end

    if cmd == "unloopgrab" then
        loopgrab_enabled = false
        if loopgrab_thread then
            loopgrab_thread = nil
        end
        Notify("Loopgrab stopped.")
        return
    end

    if cmd == "autof3x" then
        SendCommand("startergive me")
        Notify("F3X starter given.")
        return
    end

    if cmd == "prefix" then
        if args[2] then
            setPrefix(args[2])
        else
            Notify("Current prefix: "..prefix)
        end
        return
    end

    if cmd == "help" then
        print("==== KohlsLite Commands ====")
        print(".explode [target] - explode+respawn target")
        print(".platform - toggle platform")
        print(".spam cmd1; cmd2; ... - spam commands")
        print(".stopspam - stop spam")
        print(".super cmd1; cmd2; ... - super fast")
        print(".stopsuper - stop super")
        print(".spamdelay <sec> - set spam delay")
        print(".superdelay <sec> - set super delay")
        print(".supercount <num> - set super iterations")
        print(".explodecount <num> - set explode iterations")
        print(".softlock <target> - punish when character exists")
        print(".unsoftlock - disable softlock")
        print(".makechat <target> <msg> - hint with target name")
        print(".regen - click regen once")
        print(".loopregen - click regen every 0.5s")
        print(".stopregen - stop loopregen")
        print(".nkill - remove all TouchInterests from Obby")
        print(".antijail - auto unjail")
        print(".unantijail - disable antijail")
        print(".antifreeze - auto unfreeze")
        print(".unantifreeze - disable antifreeze")
        print(".antipunish - auto unpunish when punished")
        print(".unantipunish - disable antipunish")
        print(".admin - loop to get admin (regen if no pad)")
        print(".unadmin - stop admin loop")
        print(".loopgrab - ensure all pads are yours (instant, touches pads)")
        print(".unloopgrab - stop loopgrab")
        print(".autof3x - give F3X starter once")
        print(".prefix <new> - change prefix")
        print(".help - this list")
        Notify("Commands listed in console.")
        return
    end

    Notify("Unknown command. Use .help")
end

game.TextChatService.MessageReceived:Connect(function(tbl)
    if not tbl.TextSource then return end
    local player = game:GetService("Players"):GetPlayerByUserId(tbl.TextSource.UserId)
    if player ~= game.Players.LocalPlayer then return end
    local msg = tbl.Text
    if string.sub(msg:lower(), 1, #prefix) == prefix then
        handleCommand(msg)
    end
end)

local function createCmdBar()
    local gui = Instance.new("ScreenGui")
    gui.Name = "CmdBar"
    gui.ResetOnSpawn = false
    gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 30, 0, 30)
    frame.Position = UDim2.new(1, -40, 1, -45)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 1, 0)
    box.BackgroundTransparency = 1
    box.TextColor3 = Color3.new(1,1,1)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 24
    box.Text = "]"
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Top
    box.ClearTextOnFocus = false
    box.Parent = frame

    box.FocusLost:Connect(function(enter)
        if enter then
            local txt = box.Text
            if txt and txt ~= "" and txt ~= "" then
                if string.sub(txt, 1, 1) == prefix then
                    handleCommand(txt)
                else
                    SendCommand(txt)
                end
            end
            box.Text = "]"
        else
            if box.Text == "" then
                box.Text = "]"
            end
        end
    end)

    box.MouseButton1Click:Connect(function()
        if box.Text == "]" then
            box.Text = ""
        end
        box:CaptureFocus()
    end)

    box:GetPropertyChangedSignal("IsFocused"):Connect(function()
        if box.IsFocused and box.Text == "]" then
            box.Text = ""
        end
        if not box.IsFocused and box.Text == "" then
            box.Text = "]"
        end
    end)
end

task.spawn(createCmdBar)

task.spawn(function()
    task.wait(1)
    if config.autorun then
        for _, cmd in ipairs(config.autorun) do
            if cmd and cmd ~= "" then
                local args = string.split(cmd, " ")
                local cmdName = args[1]:gsub("^"..prefix, "")
                if cmdName then
                    handleCommand(cmd)
                end
                task.wait(0.3)
            end
        end
    end
end)

Notify("KohlsLite loaded. Use .help")
print("KohlsLite ready. Prefix: "..prefix)
print("Config folder: "..folderName)