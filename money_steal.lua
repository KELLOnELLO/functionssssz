local MoneySteal = {}
MoneySteal.__index = MoneySteal

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

function MoneySteal.new()
    local self = setmetatable({}, MoneySteal)
    self.enabled = false
    self.thread = nil
    return self
end

function MoneySteal:Loop()
    while self.enabled do
        task.wait(0.05)
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local money = plr.Character:FindFirstChild("Money")
                    if money and money:IsA("BasePart") then
                        firetouchinterest(hrp, money, 0)
                        firetouchinterest(hrp, money, 1)
                    end
                end
            end
        end)
    end
end

function MoneySteal:Start()
    if self.enabled then return end
    self.enabled = true
    self.thread = task.spawn(function() self:Loop() end)
end

function MoneySteal:Stop()
    if not self.enabled then return end
    self.enabled = false
    if self.thread then pcall(function() task.cancel(self.thread) end); self.thread = nil end
end

return MoneySteal
