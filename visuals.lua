local Visuals = {}
Visuals.__index = Visuals

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local ESP_GUI_NAME = "VoidVisualsESP"
local THREED_GUI_NAME = "Void3DOffOverlay"

local function safeParent(obj)
    pcall(function() obj.Parent = CoreGui end)
    if not obj.Parent then
        obj.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

function Visuals.new()
    local self = setmetatable({}, Visuals)

    self.espEnabled = false
    self.threeDDisabled = false

    self.espGui = nil
    self.espFolder = nil
    self.espData = {}
    self.espConn = nil
    self.espAddedConn = nil
    self.espRemovedConn = nil
    self.espCharConn = nil

    self.threeDGui = nil
    self.threeDLabels = nil

    self.Callbacks = {
        On3DCreate = nil,
        On3DUpdate = nil,
        On3DDestroy = nil
    }

    return self
end

function Visuals:SetCallback(name, fn)
    if self.Callbacks[name] ~= nil then
        self.Callbacks[name] = fn
    end
end

local function getCharacter(plr)
    return plr.Character
end

local function getHumanoid(plr)
    local char = getCharacter(plr)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function getRoot(plr)
    local char = getCharacter(plr)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("LowerTorso")
end

local function readLeaderstat(plr, names)
    if type(names) == "string" then names = {names} end
    local stats = plr:FindFirstChild("leaderstats")
    if not stats then return nil end
    for _, name in ipairs(names) do
        local v = stats:FindFirstChild(name)
        if v then return v.Value end
    end
    return nil
end

local function readStand(plr)
    local stand = readLeaderstat(plr, {"Stand"})
    if stand and stand ~= "" then return tostring(stand) end
    local char = getCharacter(plr)
    if char then
        local s = char:FindFirstChild("Stand")
        if s then
            if s:IsA("StringValue") then return s.Value end
            return s.Name
        end
    end
    return nil
end

local function readLevel(plr)
    local lvl = readLeaderstat(plr, {"Level", "Lvl", "LVL"})
    if lvl then return tostring(lvl) end
    return nil
end

local function readSpec(plr)
    local spec = readLeaderstat(plr, {"Spec", "Specialty"})
    if spec and spec ~= "" then return tostring(spec) end
    local char = getCharacter(plr)
    if char then
        local s = char:FindFirstChild("Spec")
        if s and s:IsA("StringValue") then return s.Value end
    end
    return nil
end

function Visuals:CreateESPGui()
    if self.espGui then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = ESP_GUI_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 10
    safeParent(gui)
    self.espGui = gui

    local folder = Instance.new("Folder")
    folder.Name = "Players"
    folder.Parent = gui
    self.espFolder = folder
end

function Visuals:CreateESPForPlayer(plr)
    if self.espData[plr] then return end
    if not self.espFolder then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "VoidESP_" .. plr.Name
    billboard.Size = UDim2.new(0, 200, 0, 64)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = nil
    billboard.Parent = self.espFolder

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.Size = UDim2.new(1, 0, 0, 16)
    nameLbl.Position = UDim2.new(0, 0, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextStrokeTransparency = 0
    nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLbl.Text = plr.Name
    nameLbl.Parent = billboard

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Name = "Info"
    infoLbl.Size = UDim2.new(1, 0, 0, 48)
    infoLbl.Position = UDim2.new(0, 0, 0, 16)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Font = Enum.Font.Gotham
    infoLbl.TextSize = 11
    infoLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
    infoLbl.TextStrokeTransparency = 0
    infoLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    infoLbl.TextYAlignment = Enum.TextYAlignment.Top
    infoLbl.Text = ""
    infoLbl.Parent = billboard

    self.espData[plr] = {
        billboard = billboard,
        nameLbl = nameLbl,
        infoLbl = infoLbl
    }
end

function Visuals:RemoveESPForPlayer(plr)
    local data = self.espData[plr]
    if not data then return end
    pcall(function() data.billboard:Destroy() end)
    self.espData[plr] = nil
end

function Visuals:UpdateESP()
    if not self.espEnabled then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = getCharacter(plr)
            local root = getRoot(plr)
            if char and root then
                if not self.espData[plr] then
                    self:CreateESPForPlayer(plr)
                end
                local data = self.espData[plr]
                if data then
                    data.billboard.Adornee = root

                    local level = readLevel(plr)
                    local stand = readStand(plr)
                    local spec = readSpec(plr)
                    local hp = nil
                    local hum = getHumanoid(plr)
                    if hum then
                        hp = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                    end

                    local lines = {}
                    table.insert(lines, "Lvl: " .. (level or "?"))
                    table.insert(lines, "Stand: " .. (stand or "-"))
                    table.insert(lines, "Spec: " .. (spec or "-"))
                    if hp then
                        table.insert(lines, "HP: " .. hp)
                    end
                    data.infoLbl.Text = table.concat(lines, "\n")
                end
            else
                if self.espData[plr] then
                    self:RemoveESPForPlayer(plr)
                end
            end
        end
    end

    for plr, _ in pairs(self.espData) do
        if not plr.Parent or not plr.Character then
            self:RemoveESPForPlayer(plr)
        end
    end
end

function Visuals:EnableESP()
    if self.espEnabled then return end
    self.espEnabled = true
    self:CreateESPGui()

    self.espConn = RunService.RenderStepped:Connect(function()
        if not self.espEnabled then return end
        self:UpdateESP()
    end)

    self.espAddedConn = Players.PlayerAdded:Connect(function(plr)
        if self.espEnabled then
            self:CreateESPForPlayer(plr)
        end
    end)

    self.espRemovedConn = Players.PlayerRemoving:Connect(function(plr)
        self:RemoveESPForPlayer(plr)
    end)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            self:CreateESPForPlayer(plr)
        end
    end

    self.espCharConn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        for plr, _ in pairs(self.espData) do
            self:RemoveESPForPlayer(plr)
        end
        if self.espEnabled then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    self:CreateESPForPlayer(plr)
                end
            end
        end
    end)
end

function Visuals:DisableESP()
    if not self.espEnabled then return end
    self.espEnabled = false

    if self.espConn then self.espConn:Disconnect(); self.espConn = nil end
    if self.espAddedConn then self.espAddedConn:Disconnect(); self.espAddedConn = nil end
    if self.espRemovedConn then self.espRemovedConn:Disconnect(); self.espRemovedConn = nil end
    if self.espCharConn then self.espCharConn:Disconnect(); self.espCharConn = nil end

    for plr, _ in pairs(self.espData) do
        self:RemoveESPForPlayer(plr)
    end

    if self.espGui then
        pcall(function() self.espGui:Destroy() end)
        self.espGui = nil
        self.espFolder = nil
    end
end

function Visuals:SetESP(state)
    if state then
        self:EnableESP()
    else
        self:DisableESP()
    end
end

function Visuals:IsESPEnabled()
    return self.espEnabled
end

function Visuals:Build3DItemsList()
    if not self.threeDItems or #self.threeDItems == 0 then
        return "-"
    end
    local counts = {}
    for _, name in ipairs(self.threeDItems) do
        counts[name] = (counts[name] or 0) + 1
    end
    local list = {}
    for name, count in pairs(counts) do
        table.insert(list, name .. ": " .. count)
    end
    table.sort(list)
    return table.concat(list, "\n")
end

function Visuals:Enable3DOff()
    if self.threeDDisabled then return end
    self.threeDDisabled = true

    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.LocalTransparencyModifier = 1
            end
        end
    end)

    if self.threeDGui then
        pcall(function() self.threeDGui:Destroy() end)
        self.threeDGui = nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = THREED_GUI_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    safeParent(gui)

    local bg = Instance.new("Frame")
    bg.Name = "BG"
    bg.Size = UDim2.fromScale(1, 1)
    bg.Position = UDim2.fromScale(0, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BorderSizePixel = 0
    bg.ZIndex = 1
    bg.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0.05, 0)
    title.BackgroundTransparency = 1
    title.Text = "LAST PICKED ITEM:"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 28
    title.ZIndex = 2
    title.Parent = bg

    local lastItem = Instance.new("TextLabel")
    lastItem.Size = UDim2.new(1, 0, 0, 50)
    lastItem.Position = UDim2.new(0, 0, 0.05, 45)
    lastItem.BackgroundTransparency = 1
    lastItem.Text = "-"
    lastItem.TextColor3 = Color3.fromRGB(180, 40, 40)
    lastItem.Font = Enum.Font.GothamBold
    lastItem.TextSize = 40
    lastItem.ZIndex = 2
    lastItem.Parent = bg

    local list = Instance.new("TextLabel")
    list.Size = UDim2.new(1, -40, 0.6, 0)
    list.Position = UDim2.new(0, 20, 0.25, 0)
    list.BackgroundTransparency = 1
    list.Text = "-"
    list.TextColor3 = Color3.fromRGB(160, 160, 170)
    list.Font = Enum.Font.Gotham
    list.TextSize = 14
    list.TextWrapped = true
    list.TextYAlignment = Enum.TextYAlignment.Top
    list.ZIndex = 2
    list.Parent = bg

    local stats = Instance.new("TextLabel")
    stats.Size = UDim2.new(1, 0, 0, 24)
    stats.Position = UDim2.new(0, 0, 0.93, 0)
    stats.BackgroundTransparency = 1
    stats.Text = "Picked: 0 | TP: 0"
    stats.TextColor3 = Color3.fromRGB(120, 120, 130)
    stats.Font = Enum.Font.Gotham
    stats.TextSize = 16
    stats.ZIndex = 2
    stats.Parent = bg

    self.threeDGui = gui
    self.threeDLabels = {
        lastItem = lastItem,
        list = list,
        stats = stats
    }

    if self.Callbacks.On3DCreate then
        pcall(self.Callbacks.On3DCreate, self.threeDLabels)
    end
end

function Visuals:Disable3DOff()
    if not self.threeDDisabled then return end
    self.threeDDisabled = false

    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.LocalTransparencyModifier = 0
            end
        end
    end)

    if self.threeDGui then
        pcall(function() self.threeDGui:Destroy() end)
        self.threeDGui = nil
        self.threeDLabels = nil
    end

    if self.Callbacks.On3DDestroy then
        pcall(self.Callbacks.On3DDestroy)
    end
end

function Visuals:Set3DOff(state)
    if state then
        self:Enable3DOff()
    else
        self:Disable3DOff()
    end
end

function Visuals:Update3DOverlay(stats, itemsText)
    if not self.threeDGui or not self.threeDLabels then return end
    if stats then
        if self.threeDLabels.lastItem then
            self.threeDLabels.lastItem.Text = stats.lastPickedItem or "-"
        end
        if self.threeDLabels.stats then
            self.threeDLabels.stats.Text = "Picked: " .. tostring(stats.totalPicked or 0) .. " | TP: " .. tostring(stats.totalTPs or 0)
        end
    end
    if itemsText and self.threeDLabels.list then
        self.threeDLabels.list.Text = itemsText
    end
    if self.Callbacks.On3DUpdate then
        pcall(self.Callbacks.On3DUpdate, stats, itemsText)
    end
end

function Visuals:Is3DOff()
    return self.threeDDisabled
end

function Visuals:Destroy()
    self:DisableESP()
    self:Disable3DOff()
    self.espData = {}
    self.threeDLabels = nil
    self.threeDItems = nil
end

return Visuals
