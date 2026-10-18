local Visuals = {}
Visuals.__index = Visuals

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

function Visuals.new()
    local self = setmetatable({}, Visuals)
    self.espEnabled = false
    self.itemEspEnabled = false
    self.hideNick = false
    self.playerHighlights = {}
    self.itemHighlights = {}
    self.conn = nil
    self:StartLoop()
    return self
end

function Visuals:StartLoop()
    if self.conn then return end
    self.conn = RunService.Heartbeat:Connect(function()
        if self.espEnabled then
            self:UpdatePlayerESP()
        else
            self:ClearPlayerESP()
        end
        if self.itemEspEnabled then
            self:UpdateItemESP()
        else
            self:ClearItemESP()
        end
        if self.hideNick then
            self:HideNickname()
        end
    end)
end

function Visuals:UpdatePlayerESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if not self.playerHighlights[plr] then
                local hl = Instance.new("Highlight")
                hl.FillColor = Color3.fromRGB(255, 50, 50)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.5
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Adornee = plr.Character
                hl.Parent = plr.Character
                self.playerHighlights[plr] = hl
            end
        end
    end
end

function Visuals:ClearPlayerESP()
    for plr, hl in pairs(self.playerHighlights) do
        hl:Destroy()
        self.playerHighlights[plr] = nil
    end
end

function Visuals:UpdateItemESP()
    local folder = workspace:FindFirstChild("Item_Spawns") and workspace.Item_Spawns:FindFirstChild("Items")
    if not folder then return end
    for _, item in ipairs(folder:GetChildren()) do
        if item:IsA("Model") and not self.itemHighlights[item] then
            local hl = Instance.new("Highlight")
            hl.FillColor = Color3.fromRGB(50, 255, 50)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.3
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = item
            hl.Parent = item
            self.itemHighlights[item] = hl
        end
    end
end

function Visuals:ClearItemESP()
    for item, hl in pairs(self.itemHighlights) do
        hl:Destroy()
        self.itemHighlights[item] = nil
    end
end

function Visuals:HideNickname()
    local char = LocalPlayer.Character
    if char then
        local head = char:FindFirstChild("Head")
        if head then
            local bb = head:FindFirstChildOfClass("BillboardGui")
            if bb then bb.Enabled = not self.hideNick end
        end
    end
end

function Visuals:SetESP(state) self.espEnabled = state end
function Visuals:SetItemESP(state) self.itemEspEnabled = state end
function Visuals:SetHideNick(state) self.hideNick = state end

return Visuals
