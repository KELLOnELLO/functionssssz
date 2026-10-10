local Player = {}
Player.__index = Player

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMPPOWER = 50
local FLY_SPEED_MULT = 25
local TP_KEY = "idklolbrah2de"
local PREVIEW_NAME = "VoidTPPreview"
local RAYCAST_DISTANCE = 500

function Player.new()
    local self = setmetatable({}, Player)

    self.noclipEnabled = false
    self.flyEnabled = false
    self.clickTPEnabled = false

    self.noclipConn = nil
    self.flyLoopConn = nil
    self.flyInputBeganConn = nil
    self.flyInputEndedConn = nil
    self.clickTPConn = nil
    self.charConn = nil
    self.tpNamecallHook = nil
    self.originalNamecall = nil

    self.flySpeed = 1
    self.keysPressed = {
        W = 0,
        A = 0,
        S = 0,
        D = 0,
        Space = 0,
        LeftControl = 0
    }

    self.keyInfo = {
        W = { Operator = "+", Direction = "LookVector" },
        A = { Operator = "-", Direction = "RightVector" },
        S = { Operator = "-", Direction = "LookVector" },
        D = { Operator = "+", Direction = "RightVector" }
    }

    self.tpPreview = nil
    self.tpTargetPosition = nil
    self.tpHeldItem = nil
    self.tpHandConn = nil
    self.tpPreviewConn = nil

    self.Callbacks = {
        OnFlyToggle = nil,
        OnNoclipToggle = nil,
        OnClickTPToggle = nil,
        OnTP = nil,
        OnError = nil
    }

    return self
end

function Player:SetCallback(name, fn)
    if self.Callbacks[name] ~= nil then
        self.Callbacks[name] = fn
    end
end

local function getChar()
    return LocalPlayer.Character
end

local function getHRP()
    local char = getChar()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getChar()
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function getMass(model)
    local mass = 0
    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then
            mass = mass + v:GetMass()
        end
    end
    return mass
end

local function mathOp(op, a, b)
    if op == "-" then return a - b end
    if op == "+" then return a + b end
    return a
end

local function getKeyName(input)
    return input.KeyCode.Name
end

function Player:StartFly()
    local UIS = UserInputService

    self.flyInputBeganConn = UIS.InputBegan:Connect(function(input, typing)
        if typing then return end
        local key = getKeyName(input)
        if self.keysPressed[key] ~= nil then
            self.keysPressed[key] = 1
        end
    end)

    self.flyInputEndedConn = UIS.InputEnded:Connect(function(input, typing)
        if typing then return end
        local key = getKeyName(input)
        if self.keysPressed[key] ~= nil then
            self.keysPressed[key] = 0
        end
    end)

    self.flyLoopConn = RunService.RenderStepped:Connect(function()
        if not self.flyEnabled then return end
        local hrp = getHRP()
        local hum = getHumanoid()
        if not hrp or not hum then return end

        hum.WalkSpeed = 0
        hum.JumpPower = 0
        hum.PlatformStand = false

        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + workspace.CurrentCamera.CFrame.LookVector)

        local charMass = getMass(getChar())

        local velocity = Vector3.new(0, charMass / workspace.Gravity, 0)

        for key, state in pairs(self.keysPressed) do
            if state ~= 0 and self.keyInfo[key] then
                local info = self.keyInfo[key]
                velocity = mathOp(info.Operator, velocity, hrp.CFrame[info.Direction] * (self.flySpeed * FLY_SPEED_MULT) * charMass)
            end
        end

        hrp.Velocity = velocity
    end)
end

function Player:StopFly()
    if self.flyInputBeganConn then self.flyInputBeganConn:Disconnect(); self.flyInputBeganConn = nil end
    if self.flyInputEndedConn then self.flyInputEndedConn:Disconnect(); self.flyInputEndedConn = nil end
    if self.flyLoopConn then self.flyLoopConn:Disconnect(); self.flyLoopConn = nil end

    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = DEFAULT_WALKSPEED
        hum.JumpPower = DEFAULT_JUMPPOWER
    end
end

function Player:SetFly(state)
    if state == self.flyEnabled then return end
    self.flyEnabled = state
    if state then
        self:StartFly()
        if self.Callbacks.OnFlyToggle then pcall(self.Callbacks.OnFlyToggle, true) end
    else
        self:StopFly()
        if self.Callbacks.OnFlyToggle then pcall(self.Callbacks.OnFlyToggle, false) end
    end
end

function Player:SetFlySpeed(value)
    self.flySpeed = math.clamp(value, 0.1, 10)
end

function Player:IsFly()
    return self.flyEnabled
end

function Player:SetNoclip(state)
    self.noclipEnabled = state

    if state then
        if not self.noclipConn then
            self.noclipConn = RunService.Stepped:Connect(function()
                if not self.noclipEnabled then return end
                local char = getChar()
                if not char then return end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end)
        end
    else
        if self.noclipConn then
            self.noclipConn:Disconnect()
            self.noclipConn = nil
        end
        local char = getChar()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end

    if self.Callbacks.OnNoclipToggle then pcall(self.Callbacks.OnNoclipToggle, state) end
end

function Player:IsNoclip()
    return self.noclipEnabled
end

function Player:GetMouseWorldPosition()
    local camera = workspace.CurrentCamera
    local mouse = LocalPlayer:GetMouse()
    if not mouse or not camera then return nil end

    local unitRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {getChar()}
    if self.tpPreview then
        table.insert(params.FilterDescendantsInstances, self.tpPreview)
    end

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * RAYCAST_DISTANCE, params)
    if result then
        return result.Position, result.Normal
    end
    return unitRay.Origin + unitRay.Direction * RAYCAST_DISTANCE, Vector3.new(0, 1, 0)
end

function Player:CreatePreview(position)
    if not self.tpPreview then
        local part = Instance.new("Part")
        part.Name = PREVIEW_NAME
        part.Size = Vector3.new(2, 0.2, 2)
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(155, 89, 255)
        part.Transparency = 0.5
        part.Shape = Enum.PartType.Block
        part.Parent = workspace
        self.tpPreview = part
    end
    self.tpPreview.Position = position
end

function Player:DestroyPreview()
    if self.tpPreview then
        pcall(function() self.tpPreview:Destroy() end)
        self.tpPreview = nil
    end
end

function Player:StartClickTPLoop()
    if self.tpPreviewConn then self.tpPreviewConn:Disconnect() end

    self.tpPreviewConn = RunService.RenderStepped:Connect(function()
        if not self.clickTPEnabled then
            self:DestroyPreview()
            return
        end
        local char = getChar()
        if not char then
            self:DestroyPreview()
            return
        end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then
            self:DestroyPreview()
            return
        end
        local pos = self:GetMouseWorldPosition()
        if pos then
            self:CreatePreview(pos)
        end
    end)
end

function Player:StopClickTPLoop()
    if self.tpPreviewConn then
        self.tpPreviewConn:Disconnect()
        self.tpPreviewConn = nil
    end
    self:DestroyPreview()
end

function Player:DoTP(position)
    local hrp = getHRP()
    if not hrp then return end
    hrp.CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0))
    hrp.Velocity = Vector3.zero
    if self.Callbacks.OnTP then
        pcall(self.Callbacks.OnTP, position)
    end
end

function Player:EnableClickTP()
    if self.clickTPEnabled then return end
    self.clickTPEnabled = true

    self:StartClickTPLoop()

    if not self.tpNamecallHook then
        local ok = pcall(function()
            self.originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(obj, ...)
                local method = getnamecallmethod()
                local args = {...}
                if method == "InvokeServer" and args[1] == TP_KEY then
                    if self.clickTPEnabled then
                        local pos = self:GetMouseWorldPosition()
                        if pos then
                            self:DoTP(pos)
                        end
                    end
                    return self.originalNamecall(obj, ...)
                end
                return self.originalNamecall(obj, ...)
            end))
        end)
        if ok then
            self.tpNamecallHook = true
        end
    end

    if self.Callbacks.OnClickTPToggle then pcall(self.Callbacks.OnClickTPToggle, true) end
end

function Player:DisableClickTP()
    if not self.clickTPEnabled then return end
    self.clickTPEnabled = false
    self:StopClickTPLoop()
    if self.Callbacks.OnClickTPToggle then pcall(self.Callbacks.OnClickTPToggle, false) end
end

function Player:SetClickTP(state)
    if state then
        self:EnableClickTP()
    else
        self:DisableClickTP()
    end
end

function Player:IsClickTP()
    return self.clickTPEnabled
end

function Player:HookRespawn()
    if self.charConn then return end
    self.charConn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if self.noclipEnabled then
            local char = getChar()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end

function Player:Destroy()
    self:SetFly(false)
    self:SetNoclip(false)
    self:DisableClickTP()
    if self.charConn then
        self.charConn:Disconnect()
        self.charConn = nil
    end
    self:DestroyPreview()
end

return Player
