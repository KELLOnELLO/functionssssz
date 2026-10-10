local AutoFarm = {}
AutoFarm.__index = AutoFarm

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local CONFIG_FILE = "void_yba_farm_config.json"

local DEFAULT_TP_POINTS = {
    Vector3.new(95, 62, 72),
    Vector3.new(-292, 33, 15),
    Vector3.new(-36, -42, 523),
    Vector3.new(39, -33, 23),
    Vector3.new(-200, -33, -269),
    Vector3.new(-65, -33, -606),
    Vector3.new(73, 24, -932),
    Vector3.new(97, 14, -531),
    Vector3.new(253, 57, -210),
    Vector3.new(509, 14, 106),
    Vector3.new(976, -43, -111),
    Vector3.new(-655, -21, -750),
    Vector3.new(-190, 15, -585),
    Vector3.new(-182, 0, -231)
}

local MERCHANT_POS = Vector3.new(-702, -25, -335)
local ANIM_ID = "rbxassetid://72675993856360"
local ANIM_START_TIME = 0.5

function AutoFarm.new()
    local self = setmetatable({}, AutoFarm)

    self.Config = {
        TPOffset = 6,
        AutoSell = false,
        ServerHop = false,
        ServerHopInterval = 300,
        RandomTP = true,
        TPSpeed = 1.1,
        TPCount = 3,
        ERange = 50,
        EHoldTime = 1,
        TPPoints = DEFAULT_TP_POINTS,
        Weather = "Sunny",
        RemoveTrees = false,
        FPSCap = 60,
        RenderDistance = 5
    }

    self.autofarmEnabled = false
    self.noclipEnabled = false
    self.cameraNoclipEnabled = false
    self.connections = {}

    self.lockConnection = nil
    self.lockedPosition = nil
    self.noclipConnection = nil
    self.hopConnection = nil
    self.animConnection = nil
    self.animTrack = nil
    self.currentTarget = nil
    self.farmCoroutine = nil
    self.eSpamCoroutine = nil
    self.keyBypassHooked = false
    self.originalNamecall = nil

    self.stats = {
        totalTPs = 0,
        totalPicked = 0,
        pickedItems = {},
        lastPickedItem = "—",
        sessionStartTime = 0
    }

    self.Callbacks = {
        OnPickup = nil,
        OnStatsUpdate = nil,
        OnKeyBypass = nil
    }

    return self
end

function AutoFarm:SetCallback(name, fn)
    if self.Callbacks[name] ~= nil then
        self.Callbacks[name] = fn
    end
end

function AutoFarm:LoadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                if self.Config[k] ~= nil and k ~= "TPPoints" then
                    self.Config[k] = v
                end
            end
        end
    end
end

function AutoFarm:SaveConfig()
    if writefile then
        local save = {}
        for k, v in pairs(self.Config) do
            if k ~= "TPPoints" then
                save[k] = v
            end
        end
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(save))
        end)
    end
end

function AutoFarm:SetConfig(key, value)
    if self.Config[key] ~= nil then
        self.Config[key] = value
    end
end

function AutoFarm:SetTPPoints(points)
    if type(points) == "table" and #points > 0 then
        self.Config.TPPoints = points
    end
end

function AutoFarm:AddTPPoint(vec)
    if typeof(vec) == "Vector3" then
        table.insert(self.Config.TPPoints, vec)
    end
end

function AutoFarm:GetStats()
    return {
        totalTPs = self.stats.totalTPs,
        totalPicked = self.stats.totalPicked,
        lastPickedItem = self.stats.lastPickedItem,
        pickedItems = self.stats.pickedItems,
        sessionStartTime = self.stats.sessionStartTime
    }
end

function AutoFarm:GetItemsListText()
    if #self.stats.pickedItems == 0 then return "—" end
    local counts = {}
    for _, name in ipairs(self.stats.pickedItems) do
        counts[name] = (counts[name] or 0) + 1
    end
    local list = {}
    for name, count in pairs(counts) do
        table.insert(list, name .. ": " .. count)
    end
    table.sort(list)
    return table.concat(list, "\n")
end

function AutoFarm:EnableKeyBypass()
    if self.keyBypassHooked then return end
    local ok = pcall(function()
        self.originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self2, ...)
            local args = {...}
            local method = getnamecallmethod()
            if method == "InvokeServer" and args[1] == "idklolbrah2de" then
                if self.Callbacks.OnKeyBypass then
                    pcall(self.Callbacks.OnKeyBypass)
                end
                return "  ___XP DE KEY"
            end
            return self.originalNamecall(self2, ...)
        end))
    end)
    if ok then
        self.keyBypassHooked = true
    end
end

function AutoFarm:DisableKeyBypass()
    self.keyBypassHooked = false
end

local function getItemFolder()
    local spawns = workspace:FindFirstChild("Item_Spawns")
    if not spawns then return nil end
    return spawns:FindFirstChild("Items")
end

local function getItemPosition(item)
    if item:IsA("Model") then
        local primary = item.PrimaryPart
        if primary then return primary.Position end
        for _, d in ipairs(item:GetChildren()) do
            if d:IsA("BasePart") then return d.Position end
        end
    elseif item:IsA("BasePart") then
        return item.Position
    end
    return nil
end

local function isItemAvailable(item)
    if not item or not item.Parent then return false end
    if item:IsA("Model") then
        for _, d in ipairs(item:GetChildren()) do
            if d:IsA("BasePart") and d.Transparency < 0.95 then
                return true
            end
        end
        return false
    elseif item:IsA("BasePart") then
        return item.Transparency < 0.95
    end
    return false
end

function AutoFarm:GetAllItems()
    local folder = getItemFolder()
    if not folder then return {} end
    local items = {}
    for _, item in ipairs(folder:GetChildren()) do
        if isItemAvailable(item) then
            local pos = getItemPosition(item)
            if pos then
                table.insert(items, {item = item, pos = pos})
            end
        end
    end
    return items
end

function AutoFarm:HasItemNearby()
    local folder = getItemFolder()
    if not folder then return false end
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return false end
    local myPos = char.PrimaryPart.Position
    for _, item in ipairs(folder:GetChildren()) do
        if isItemAvailable(item) then
            local pos = getItemPosition(item)
            if pos and (pos - myPos).Magnitude <= self.Config.ERange then
                return true
            end
        end
    end
    return false
end

function AutoFarm:LockToPosition(position)
    self.stats.totalTPs = self.stats.totalTPs + 1
    self.lockedPosition = Vector3.new(position.X, position.Y - self.Config.TPOffset, position.Z)
    if self.lockConnection then self.lockConnection:Disconnect() end
    self.lockConnection = RunService.Heartbeat:Connect(function()
        if not self.autofarmEnabled or not self.lockedPosition then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local cam = workspace.CurrentCamera
        local flatDir = Vector3.new(0, 0, -1)
        if cam then
            local look = cam.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.01 then flatDir = flat.Unit end
        end
        hrp.CFrame = CFrame.new(self.lockedPosition, self.lockedPosition + flatDir)
        hrp.Velocity = Vector3.zero
    end)
end

function AutoFarm:UnlockPosition()
    self.lockedPosition = nil
    if self.lockConnection then
        self.lockConnection:Disconnect()
        self.lockConnection = nil
    end
end

function AutoFarm:RandomTeleport()
    local pts = self.Config.TPPoints
    if pts and #pts > 0 then
        local chosen = pts[math.random(1, #pts)]
        self:LockToPosition(chosen)
    end
end

function AutoFarm:TeleportTo(vec)
    if typeof(vec) == "Vector3" then
        self:LockToPosition(vec)
    end
end

function AutoFarm:EnableNoclip()
    if self.noclipConnection then self.noclipConnection:Disconnect() end
    self.noclipConnection = RunService.Stepped:Connect(function()
        if self.noclipEnabled and LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

function AutoFarm:DisableNoclip()
    if self.noclipConnection then
        self.noclipConnection:Disconnect()
        self.noclipConnection = nil
    end
    if LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

function AutoFarm:SetNoclip(state)
    self.noclipEnabled = state
    if state then self:EnableNoclip() else self:DisableNoclip() end
end

function AutoFarm:EnableCameraNoclip()
    pcall(function()
        local PopperClient = LocalPlayer:WaitForChild("PlayerScripts").PlayerModule.CameraModule.ZoomController.Popper
        for _, v in next, getgc() do
            if getfenv(v).script == PopperClient and typeof(v) == "function" then
                for i2, v2 in next, debug.getconstants(v) do
                    if tonumber(v2) == 0.25 then
                        debug.setconstant(v, i2, 0)
                    elseif tonumber(v2) == 0 then
                        debug.setconstant(v, i2, 0.25)
                    end
                end
            end
        end
    end)
    self.cameraNoclipEnabled = true
end

function AutoFarm:DisableCameraNoclip()
    pcall(function()
        local PopperClient = LocalPlayer:WaitForChild("PlayerScripts").PlayerModule.CameraModule.ZoomController.Popper
        for _, v in next, getgc() do
            if getfenv(v).script == PopperClient and typeof(v) == "function" then
                for i2, v2 in next, debug.getconstants(v) do
                    if tonumber(v2) == 0 then
                        debug.setconstant(v, i2, 0.25)
                    elseif tonumber(v2) == 0.25 then
                        debug.setconstant(v, i2, 0)
                    end
                end
            end
        end
    end)
    self.cameraNoclipEnabled = false
end

function AutoFarm:SetCameraNoclip(state)
    if state then self:EnableCameraNoclip() else self:DisableCameraNoclip() end
end

function AutoFarm:EnableAnim()
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    pcall(function()
        self.animTrack = animator:LoadAnimation(anim)
        self.animTrack.Priority = Enum.AnimationPriority.Action
        self.animTrack.Looped = false
        self.animTrack:Play()
        self.animTrack.TimePosition = ANIM_START_TIME
    end)

    if self.animConnection then self.animConnection:Disconnect() end
    self.animConnection = self.animTrack.Stopped:Connect(function()
        if not self.autofarmEnabled then return end
        task.wait(0.05)
        if self.animTrack and self.autofarmEnabled then
            pcall(function()
                self.animTrack:Play()
                self.animTrack.TimePosition = ANIM_START_TIME
            end)
        end
    end)
end

function AutoFarm:DisableAnim()
    if self.animConnection then
        self.animConnection:Disconnect()
        self.animConnection = nil
    end
    if self.animTrack then
        pcall(function() self.animTrack:Stop() end)
        self.animTrack = nil
    end
end

function AutoFarm:HoldE(duration)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    end)
    task.wait(duration)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

function AutoFarm:TrySellItems()
    if not self.Config.AutoSell then return end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return end

    local itemCount = 0
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then itemCount = itemCount + 1 end
    end

    if itemCount >= 15 then
        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        if remotes then
            local sellFunc = remotes:FindFirstChild("SellItem") or remotes:FindFirstChild("Sell")
            if sellFunc then
                for _, item in ipairs(backpack:GetChildren()) do
                    if item:IsA("Tool") then
                        pcall(function() sellFunc:InvokeServer(item) end)
                        task.wait(0.08)
                    end
                end
            end
        end
    end
end

function AutoFarm:WaitForPickup(item, timeout)
    timeout = timeout or 5
    local startTime = tick()
    while self.autofarmEnabled do
        if not item or not item.Parent then return true end
        if not isItemAvailable(item) then return true end
        if tick() - startTime >= timeout then return false end
        task.wait(0.1)
    end
    return false
end

function AutoFarm:InternalLoop()
    while self.autofarmEnabled do
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            task.wait(0.3)
        else
            local allItems = self:GetAllItems()
            local collected = false

            if #allItems > 0 then
                for _, entry in ipairs(allItems) do
                    if not self.autofarmEnabled then break end
                    if isItemAvailable(entry.item) then
                        self.currentTarget = entry.item
                        self:LockToPosition(entry.pos)
                        collected = true
                        local picked = self:WaitForPickup(entry.item, 5)
                        if picked then
                            self.stats.totalPicked = self.stats.totalPicked + 1
                            local itemName = entry.item.Name
                            local prox = entry.item:FindFirstChild("ProximityPrompt")
                            if prox and prox.ObjectText and prox.ObjectText ~= "" then
                                itemName = prox.ObjectText
                            end
                            table.insert(self.stats.pickedItems, itemName)
                            self.stats.lastPickedItem = itemName
                            if self.Callbacks.OnPickup then
                                pcall(self.Callbacks.OnPickup, itemName, self:GetStats())
                            end
                            if self.Callbacks.OnStatsUpdate then
                                pcall(self.Callbacks.OnStatsUpdate, self:GetStats())
                            end
                        end
                        self.currentTarget = nil
                    end
                end
            end

            if not collected and self.Config.RandomTP then
                for i = 1, self.Config.TPCount do
                    if not self.autofarmEnabled then break end
                    self:RandomTeleport()
                    task.wait(self.Config.TPSpeed)
                end
            end

            self:TrySellItems()
        end
        task.wait(0.1)
    end
end

function AutoFarm:InternalESpam()
    while self.autofarmEnabled do
        if self:HasItemNearby() then
            self:HoldE(self.Config.EHoldTime)
            task.wait(0.01)
        else
            task.wait(0.05)
        end
    end
end

function AutoFarm:Start()
    if self.autofarmEnabled then return end
    self.autofarmEnabled = true
    self.stats.sessionStartTime = tick()
    self.stats.totalTPs = 0
    self.stats.totalPicked = 0
    self.stats.pickedItems = {}
    self.stats.lastPickedItem = "—"
    self:EnableAnim()
    self.farmCoroutine = task.spawn(function() self:InternalLoop() end)
    self.eSpamCoroutine = task.spawn(function() self:InternalESpam() end)
end

function AutoFarm:Stop()
    if not self.autofarmEnabled then return end
    self.autofarmEnabled = false
    self:UnlockPosition()
    self:DisableAnim()
    self.currentTarget = nil
    if self.farmCoroutine then pcall(function() task.cancel(self.farmCoroutine) end) end
    if self.eSpamCoroutine then pcall(function() task.cancel(self.eSpamCoroutine) end) end
    self.farmCoroutine = nil
    self.eSpamCoroutine = nil
end

function AutoFarm:IsRunning()
    return self.autofarmEnabled
end

function AutoFarm:TeleportToMerchant()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(MERCHANT_POS)
    hrp.Velocity = Vector3.zero
end

function AutoFarm:SetWeather(value)
    task.spawn(function()
        pcall(function()
            local weather = workspace:WaitForChild("Weather", 15)
            if weather and weather:IsA("StringValue") then
                weather.Value = value
            end
        end)
    end)
end

function AutoFarm:ApplyFPSCap(cap)
    if setfpscap then pcall(setfpscap, cap) end
end

function AutoFarm:ApplyRenderDistance(dist)
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        workspace.StreamingTargetRadius = dist * 100
    end)
end

function AutoFarm:RemoveTreesAndBushes()
    local removed = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Tree" or obj.Name == "Bush" then
            obj:Destroy()
            removed = removed + 1
        end
    end
    return removed
end

function AutoFarm:ServerHop()
    local servers = {}
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local data = HttpService:JSONDecode(game:HttpGet(url))
        for _, s in ipairs(data.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                table.insert(servers, s.id)
            end
        end
    end)
    if #servers > 0 then
        local chosen = servers[math.random(1, #servers)]
        TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen, LocalPlayer)
    else
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end

function AutoFarm:StartServerHopLoop()
    if self.hopConnection then pcall(function() task.cancel(self.hopConnection) end) end
    self.hopConnection = task.spawn(function()
        while self.Config.ServerHop do
            task.wait(self.Config.ServerHopInterval)
            if self.Config.ServerHop then
                self:ServerHop()
            end
        end
    end)
end

function AutoFarm:StopServerHopLoop()
    self.Config.ServerHop = false
    if self.hopConnection then
        pcall(function() task.cancel(self.hopConnection) end)
        self.hopConnection = nil
    end
end

function AutoFarm:SkipLoading()
    task.spawn(function()
        if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("IMPORTANT") and workspace.Map.IMPORTANT:FindFirstChild("OceanFloor") then
            local of = workspace.Map.IMPORTANT.OceanFloor
            if of:FindFirstChild("OceanFloor_Sand_6") then
                of.OceanFloor_Sand_6.Size = Vector3.new(2048, 89, 2048)
            end
            if of:FindFirstChild("OceanFloor_Sand_4") then
                of.OceanFloor_Sand_4.Size = Vector3.new(2048, 89, 2048)
            end
        end
    end)
    task.spawn(function()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then
            local ok, result = pcall(function()
                return LocalPlayer:WaitForChild("PlayerGui", 10)
            end)
            if ok then playerGui = result end
        end
        if not playerGui then return end
        for _, name in ipairs({"LoadingScreen1", "LoadingScreen"}) do
            local s = playerGui:FindFirstChild(name)
            if s then s:Destroy() end
        end
    end)
end

function AutoFarm:Destroy()
    self:Stop()
    self:StopServerHopLoop()
    if self.noclipConnection then pcall(function() self.noclipConnection:Disconnect() end) end
    if self.cameraNoclipEnabled then pcall(function() self:DisableCameraNoclip() end) end
    for _, conn in ipairs(self.connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.connections = {}
    self.noclipConnection = nil
    self.lockConnection = nil
    self.animConnection = nil
    self.hopConnection = nil
end

function AutoFarm:SetCharacterRespawnHandler()
    local conn = LocalPlayer.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart", 10)
        task.wait(2)
        if self.autofarmEnabled then
            self:DisableAnim()
            self:UnlockPosition()
            task.wait(0.5)
            self:Start()
        end
        self:SetNoclip(self.noclipEnabled)
    end)
    table.insert(self.connections, conn)
end

return AutoFarm
