local Invis = {}
Invis.__index = Invis

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local INVIS_TRANSPARENCY = 1
local DEFAULT_GHOST_WALKSpeed = 16
local GHOST_WALK_MULT = 2
local GLOW_COLOR = Color3.fromRGB(255, 30, 30)
local GLOW_OUTLINE_COLOR = Color3.fromRGB(255, 0, 0)
local GLOW_NAME = "VoidInvisGlow"

function Invis.new()
    local self = setmetatable({}, Invis)

    self.enabled = false
    self.ghostWalk = false
    self.glow = true
    self.savedTransparency = {}
    self.savedWalkSpeed = nil
    self.savedColor = {}
    self.steppedConn = nil
    self.descConn = nil
    self.charConn = nil
    self.currentChar = nil
    self.highlight = nil

    self.Callbacks = {
        OnEnable = nil,
        OnDisable = nil
    }

    return self
end

function Invis:SetCallback(name, fn)
    if self.Callbacks[name] ~= nil then
        self.Callbacks[name] = fn
    end
end

local function getChar()
    return LocalPlayer.Character
end

local function isBasePart(part)
    return part:IsA("BasePart")
end

local function isVisiblePart(part)
    return part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture")
end

function Invis:ApplyGlow()
    if not self.glow then return end
    local char = getChar()
    if not char then return end

    if self.highlight and self.highlight.Parent == char then return end
    if self.highlight then
        pcall(function() self.highlight:Destroy() end)
        self.highlight = nil
    end

    local hl = Instance.new("Highlight")
    hl.Name = GLOW_NAME
    hl.Adornee = char
    hl.FillColor = GLOW_COLOR
    hl.OutlineColor = GLOW_OUTLINE_COLOR
    hl.FillTransparency = 0.4
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char

    self.highlight = hl
end

function Invis:RemoveGlow()
    if self.highlight then
        pcall(function() self.highlight:Destroy() end)
        self.highlight = nil
    end
    local char = getChar()
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj.Name == GLOW_NAME and obj:IsA("Highlight") then
                pcall(function() obj:Destroy() end)
            end
        end
    end
end

function Invis:ApplyRedTint()
    if not self.glow then return end
    local char = getChar()
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if isBasePart(obj) and obj.Name ~= "HumanoidRootPart" then
            if self.savedColor[obj] == nil then
                self.savedColor[obj] = obj.Color
            end
            pcall(function()
                obj.Color = GLOW_COLOR
                obj.Material = Enum.Material.Neon
            end)
        end
    end
end

function Invis:RestoreRedTint()
    local char = getChar()
    if not char then
        self.savedColor = {}
        return
    end
    for obj, original in pairs(self.savedColor) do
        if obj and obj.Parent then
            pcall(function()
                obj.Color = original
                obj.Material = Enum.Material.Plastic
            end)
        end
    end
    self.savedColor = {}
end

function Invis:ApplyTransparency()
    local char = getChar()
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if isVisiblePart(obj) then
            if self.savedTransparency[obj] == nil then
                self.savedTransparency[obj] = obj.Transparency
            end
            pcall(function()
                obj.Transparency = INVIS_TRANSPARENCY
            end)
        end
    end
end

function Invis:RestoreTransparency()
    local char = getChar()
    if not char then
        self.savedTransparency = {}
        return
    end
    for obj, original in pairs(self.savedTransparency) do
        if obj and obj.Parent then
            pcall(function()
                obj.Transparency = original
            end)
        end
    end
    self.savedTransparency = {}
end

function Invis:ApplyGhostWalk()
    local char = getChar()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if self.savedWalkSpeed == nil then
        self.savedWalkSpeed = hum.WalkSpeed
    end
    hum.WalkSpeed = self.savedWalkSpeed * GHOST_WALK_MULT
end

function Invis:RestoreGhostWalk()
    local char = getChar()
    if not char then
        self.savedWalkSpeed = nil
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and self.savedWalkSpeed then
        pcall(function()
            hum.WalkSpeed = self.savedWalkSpeed
        end)
    end
    self.savedWalkSpeed = nil
end

function Invis:BindChar()
    local char = getChar()
    if not char then return end
    self.currentChar = char

    if self.descConn then self.descConn:Disconnect() end
    self.descConn = char.DescendantAdded:Connect(function(obj)
        if not self.enabled then return end
        task.defer(function()
            if not obj or not obj.Parent then return end
            if isVisiblePart(obj) then
                if self.savedTransparency[obj] == nil then
                    self.savedTransparency[obj] = obj.Transparency
                end
                pcall(function()
                    obj.Transparency = INVIS_TRANSPARENCY
                end)
            end
            if self.glow and isBasePart(obj) and obj.Name ~= "HumanoidRootPart" then
                if self.savedColor[obj] == nil then
                    self.savedColor[obj] = obj.Color
                end
                pcall(function()
                    obj.Color = GLOW_COLOR
                    obj.Material = Enum.Material.Neon
                end)
            end
        end)
    end)
end

function Invis:StartLoop()
    if self.steppedConn then return end
    self.steppedConn = RunService.Stepped:Connect(function()
        if not self.enabled then return end
        local char = getChar()
        if not char then return end

        for _, obj in ipairs(char:GetDescendants()) do
            if isVisiblePart(obj) then
                if obj.Transparency < INVIS_TRANSPARENCY then
                    if self.savedTransparency[obj] == nil then
                        self.savedTransparency[obj] = obj.Transparency
                    end
                    pcall(function()
                        obj.Transparency = INVIS_TRANSPARENCY
                    end)
                end
            end
            if self.glow and isBasePart(obj) and obj.Name ~= "HumanoidRootPart" then
                if obj.Color ~= GLOW_COLOR then
                    if self.savedColor[obj] == nil then
                        self.savedColor[obj] = obj.Color
                    end
                    pcall(function()
                        obj.Color = GLOW_COLOR
                        obj.Material = Enum.Material.Neon
                    end)
                end
            end
        end

        if self.glow then
            if not self.highlight or self.highlight.Parent ~= char then
                self:ApplyGlow()
            end
        end

        if self.ghostWalk then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and self.savedWalkSpeed then
                local target = self.savedWalkSpeed * GHOST_WALK_MULT
                if hum.WalkSpeed ~= target then
                    hum.WalkSpeed = target
                end
            end
        end
    end)
end

function Invis:StopLoop()
    if self.steppedConn then
        self.steppedConn:Disconnect()
        self.steppedConn = nil
    end
end

function Invis:Enable()
    if self.enabled then return end
    self.enabled = true
    self.savedTransparency = {}
    self.savedColor = {}
    self:BindChar()
    self:ApplyTransparency()
    if self.glow then
        self:ApplyRedTint()
        self:ApplyGlow()
    end
    if self.ghostWalk then
        self:ApplyGhostWalk()
    end
    self:StartLoop()
    if self.Callbacks.OnEnable then
        pcall(self.Callbacks.OnEnable)
    end
end

function Invis:Disable()
    if not self.enabled then return end
    self.enabled = false
    self:StopLoop()
    self:RemoveGlow()
    self:RestoreRedTint()
    self:RestoreTransparency()
    self:RestoreGhostWalk()
    if self.Callbacks.OnDisable then
        pcall(self.Callbacks.OnDisable)
    end
end

function Invis:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
    return self.enabled
end

function Invis:SetEnabled(state)
    if state then
        self:Enable()
    else
        self:Disable()
    end
end

function Invis:SetGhostWalk(state)
    self.ghostWalk = state
    if self.enabled then
        if state then
            self:ApplyGhostWalk()
        else
            self:RestoreGhostWalk()
        end
    end
end

function Invis:SetGlow(state)
    self.glow = state
    if self.enabled then
        if state then
            self:ApplyRedTint()
            self:ApplyGlow()
        else
            self:RemoveGlow()
            self:RestoreRedTint()
        end
    end
end

function Invis:IsEnabled()
    return self.enabled
end

function Invis:IsGhostWalk()
    return self.ghostWalk
end

function Invis:IsGlow()
    return self.glow
end

function Invis:HookRespawn()
    if self.charConn then return end
    self.charConn = LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if self.enabled then
            self.savedTransparency = {}
            self.savedColor = {}
            self.savedWalkSpeed = nil
            self.currentChar = char
            self:BindChar()
            self:ApplyTransparency()
            if self.glow then
                self:ApplyRedTint()
                self:ApplyGlow()
            end
            if self.ghostWalk then
                self:ApplyGhostWalk()
            end
        end
    end)
end

function Invis:Destroy()
    self:Disable()
    if self.descConn then
        self.descConn:Disconnect()
        self.descConn = nil
    end
    if self.charConn then
        self.charConn:Disconnect()
        self.charConn = nil
    end
    self.savedTransparency = {}
    self.savedColor = {}
    self.savedWalkSpeed = nil
    self.currentChar = nil
end

return Invis
