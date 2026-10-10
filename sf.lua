local SF = {}
SF.__index = SF

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local HITBOX_SIZE = Vector3.new(10000000, 10000000, 10000000)
local FOLLOW_OFFSET = Vector3.new(0, 15, 0)
local TORSO_NAME = "LowerTorso"
local HEAD_NAME = "Head"

function SF.new()
    local self = setmetatable({}, SF)

    self.selected = {}
    self.originalSizes = {}
    self.followConnection = nil
    self.playerAddedConn = nil
    self.charAddedConns = {}
    self.charConn = nil
    self.resetEvent = nil
    self.resetHooked = false

    self.Callbacks = {
        OnApply = nil,
        OnReset = nil,
        OnFollowStart = nil,
        OnFollowStop = nil,
        OnError = nil
    }

    return self
end

function SF:SetCallback(name, fn)
    if self.Callbacks[name] ~= nil then
        self.Callbacks[name] = fn
    end
end

function SF:GetPlayerNames()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    table.sort(names)
    return names
end

function SF:IsSelected(name)
    return table.find(self.selected, name) ~= nil
end

function SF:Select(name)
    if type(name) ~= "string" then return end
    if not self:IsSelected(name) then
        table.insert(self.selected, name)
        local plr = Players:FindFirstChild(name)
        if plr and plr.Character then
            self:ApplyHitbox(plr)
        end
    end
end

function SF:Deselect(name)
    if type(name) ~= "string" then return end
    local idx = table.find(self.selected, name)
    if idx then
        table.remove(self.selected, idx)
        local plr = Players:FindFirstChild(name)
        if plr then
            self:ResetHitbox(plr)
        end
    end
end

function SF:SetSelected(names)
    if type(names) ~= "table" then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            self:ResetHitbox(plr)
        end
    end
    self.selected = {}
    for _, name in ipairs(names) do
        self:Select(name)
    end
end

function SF:ClearSelected()
    self:SetSelected({})
end

function SF:GetSelected()
    return self.selected
end

local function getChar(plr)
    return plr.Character or plr.CharacterAdded:Wait()
end

function SF:ApplyHitbox(plr)
    if not plr or plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end

    local torso = char:FindFirstChild(TORSO_NAME)
    if not torso then
        local ok, result = pcall(function()
            return char:WaitForChild(TORSO_NAME, 5)
        end)
        if ok then torso = result end
    end
    if not torso then
        if self.Callbacks.OnError then
            pcall(self.Callbacks.OnError, "No " .. TORSO_NAME .. " for " .. plr.Name)
        end
        return
    end

    if not self.originalSizes[plr] then
        self.originalSizes[plr] = torso.Size
    end

    pcall(function()
        torso.Size = HITBOX_SIZE
        torso.CanCollide = false
        torso.Massless = true
    end)

    if self.Callbacks.OnApply then
        pcall(self.Callbacks.OnApply, plr)
    end
end

function SF:ResetHitbox(plr)
    if not plr then return end
    local char = plr.Character
    if not char then return end

    local torso = char:FindFirstChild(TORSO_NAME)
    if not torso then return end

    if self.originalSizes[plr] then
        pcall(function()
            torso.Size = self.originalSizes[plr]
            torso.CanCollide = true
            torso.Massless = false
        end)
        self.originalSizes[plr] = nil
    end

    if self.Callbacks.OnReset then
        pcall(self.Callbacks.OnReset, plr)
    end
end

function SF:StartFollow()
    if self.followConnection then return end

    self.followConnection = RunService.Heartbeat:Connect(function()
        local myChar = LocalPlayer.Character
        if not myChar then return end
        local myHead = myChar:FindFirstChild(HEAD_NAME)
        if not myHead then return end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and self:IsSelected(plr.Name) then
                local char = plr.Character
                if char then
                    local torso = char:FindFirstChild(TORSO_NAME)
                    if torso then
                        torso.CFrame = myHead.CFrame + FOLLOW_OFFSET
                        torso.Velocity = Vector3.zero
                    end
                end
            end
        end
    end)

    if self.Callbacks.OnFollowStart then
        pcall(self.Callbacks.OnFollowStart)
    end
end

function SF:StopFollow()
    if self.followConnection then
        self.followConnection:Disconnect()
        self.followConnection = nil
        if self.Callbacks.OnFollowStop then
            pcall(self.Callbacks.OnFollowStop)
        end
    end
end

function SF:ResetAll()
    for _, plr in ipairs(Players:GetPlayers()) do
        self:ResetHitbox(plr)
    end
    self:StopFollow()
    self.originalSizes = {}
end

function SF:HookPlayers()
    if self.playerAddedConn then return end

    self.playerAddedConn = Players.PlayerAdded:Connect(function(plr)
        if self:IsSelected(plr.Name) then
            local conn
            conn = plr.CharacterAdded:Connect(function()
                task.wait(0.5)
                if self:IsSelected(plr.Name) then
                    self:ApplyHitbox(plr)
                end
            end)
            table.insert(self.charAddedConns, conn)
        end
    end)
end

function SF:UnhookPlayers()
    if self.playerAddedConn then
        self.playerAddedConn:Disconnect()
        self.playerAddedConn = nil
    end
    for _, conn in ipairs(self.charAddedConns) do
        pcall(function() conn:Disconnect() end)
    end
    self.charAddedConns = {}
end

function SF:HookResetButton()
    if self.resetHooked then return end
    self.resetEvent = Instance.new("BindableEvent")
    self.resetEvent.Event:Connect(function()
        self:ResetAll()
        local char = LocalPlayer.Character
        if char then
            pcall(function() char:BreakJoints() end)
        end
    end)
    pcall(function()
        StarterGui:SetCore("ResetButtonCallback", self.resetEvent)
    end)
    self.resetHooked = true
end

function SF:HookLocalRespawn()
    if self.charConn then return end
    self.charConn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if #self.selected > 0 then
            self:StartFollow()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and self:IsSelected(plr.Name) then
                    self:ApplyHitbox(plr)
                end
            end
        end
    end)
end

function SF:Setup()
    self:HookPlayers()
    self:HookResetButton()
    self:HookLocalRespawn()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and self:IsSelected(plr.Name) then
            self:ApplyHitbox(plr)
        end
    end

    if #self.selected > 0 then
        self:StartFollow()
    end
end

function SF:Destroy()
    self:ResetAll()
    self:UnhookPlayers()
    if self.charConn then
        self.charConn:Disconnect()
        self.charConn = nil
    end
    if self.resetEvent then
        pcall(function()
            StarterGui:SetCore("ResetButtonCallback", Instance.new("BindableEvent"))
        end)
        pcall(function() self.resetEvent:Destroy() end)
        self.resetEvent = nil
    end
    self.resetHooked = false
    self.selected = {}
end

return SF
