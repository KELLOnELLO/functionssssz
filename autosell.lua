local AutoSell = {}
AutoSell.__index = AutoSell

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local SELL_ITEMS = {
    "Gold Coin", "Rokakaka", "Pure Rokakaka", "Mysterious Arrow",
    "Diamond", "Ancient Scroll", "Caesar's Headband", "Stone Mask",
    "Rib Cage of The Saint's Corpse", "Quinton's Glove",
    "Zeppeli's Hat", "Lucky Arrow", "Lucky Stone Mask", "Clackers",
    "Steel Ball", "Dio's Diary"
}

function AutoSell.new()
    local self = setmetatable({}, AutoSell)
    self.enabled = false
    self.loopThread = nil
    self.currentClickCount = 0
    self.Callbacks = { OnStats = nil }
    return self
end

function AutoSell:GetSellItems()
    local list = {}
    for _, name in ipairs(SELL_ITEMS) do
        table.insert(list, name)
    end
    return list
end

local function countItem(name)
    local count = 0
    if LocalPlayer.Backpack then
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool.Name == name then count = count + 1 end
        end
    end
    if LocalPlayer.Character then
        for _, obj in ipairs(LocalPlayer.Character:GetChildren()) do
            if obj:IsA("Tool") and obj.Name == name then count = count + 1 end
        end
    end
    return count
end

local function equipTool(itemName)
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return nil end
    local tool = LocalPlayer.Backpack:FindFirstChild(itemName)
    if not tool then tool = char:FindFirstChild(itemName) end
    if not tool then return nil end
    if tool.Parent == LocalPlayer.Backpack then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.15)
    end
    return tool
end

local function ForceClick(optionName)
    local DialogueGui = LocalPlayer.PlayerGui:FindFirstChild("DialogueGui")
    if not DialogueGui then return end
    local Frame = DialogueGui:FindFirstChild("Frame")
    if not Frame then return end
    local Options = Frame:FindFirstChild("Options")
    if not Options then return end
    local Option = Options:FindFirstChild(optionName)
    if not Option then return end
    local TextButton = Option:FindFirstChild("TextButton")
    if not TextButton or not TextButton.Visible then return end
    for _, connection in pairs(getconnections(TextButton.MouseButton1Click)) do
        if connection.Function then
            pcall(function() connection.Function() end)
        else
            pcall(function() connection:Fire() end)
        end
    end
    pcall(function() TextButton:Activated() end)
end

local function findMerchantPrompt()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            local matched = false
            local depth = 0
            while parent and parent ~= workspace and depth < 6 do
                if tostring(parent.Name):lower():find("merchant", 1, true) then
                    matched = true
                    break
                end
                parent = parent.Parent
                depth = depth + 1
            end
            if matched then return obj end
        end
    end
    return nil
end

function AutoSell:InternalLoop()
    while self.enabled do
        task.wait(0.1)
        local DialogueGui = LocalPlayer.PlayerGui:FindFirstChild("DialogueGui")
        
        if not DialogueGui then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local equipped = false
                for _, itemName in ipairs(SELL_ITEMS) do
                    if countItem(itemName) > 0 then
                        equipTool(itemName)
                        equipped = true
                        break
                    end
                end
                if equipped then
                    local prompt = findMerchantPrompt()
                    if prompt then
                        pcall(function() fireproximityprompt(prompt) end)
                    end
                    task.wait(0.5)
                end
            end
        else
            local targetOption = "Option1"
            if self.currentClickCount >= 2 then
                targetOption = "Option5"
            end
            
            local Options = DialogueGui.Frame and DialogueGui.Frame:FindFirstChild("Options")
            if Options and Options:FindFirstChild(targetOption) then
                ForceClick(targetOption)
                if targetOption == "Option1" then
                    self.currentClickCount = self.currentClickCount + 1
                elseif targetOption == "Option5" then
                    self.currentClickCount = 0
                end
                task.wait(0.3)
            end
        end
    end
end

function AutoSell:Start()
    if self.enabled then return end
    self.enabled = true
    self.loopThread = task.spawn(function() self:InternalLoop() end)
end

function AutoSell:Stop()
    if not self.enabled then return end
    self.enabled = false
    if self.loopThread then
        pcall(function() task.cancel(self.loopThread) end)
        self.loopThread = nil
    end
    self.currentClickCount = 0
end

function AutoSell:IsRunning() return self.enabled end

return AutoSell
