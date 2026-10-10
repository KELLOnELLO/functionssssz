local Utils = {}
Utils.__index = Utils

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local ALL_MODS = {
    "UzuKee", "BLOODTARO", "Dxscape", "Myst_Ari", "eurycIea", "v_cks", "ezguap",
    "Tsuzutou", "ReferToWithered", "Illus0", "Pyreiz", "VoidedFlame", "ROUXABOUT",
    "mixeriiiiiing", "MichDrajo", "hayst4", "ElmoNYC", "Core_CorruptionF",
    "Brillcake", "AxionTheRevenant", "sammyj0n", "ViveLesPatat", "Zimvasion",
    "vertiify", "redfoxP", "cakesucker05", "00kamiMio", "itscanii", "SirDeviloper",
    "0nkka", "Ramdharam", "Olliebutheskenny", "cswag_code", "TwoGio", "KoleRTX2",
    "Wilpuri", "remendyy", "SpaceNuggies", "CrimsonBeheIit", "warycoolio"
}

local REJOIN_URL = "https://raw.githubusercontent.com/KELLOnELLO/seson4ik/main/Main.lua"

function Utils.new()
    local self = setmetatable({}, Utils)
    self.connections = {}
    self.threads = {}
    self.modCheckEnabled = true
    self.autoSpinEnabled = false
    self.antiAfkEnabled = true
    self.autoRejoinEnabled = true
    self.moneyStealEnabled = false
    self.moneyStealRange = 6
    self.antiAfkInterval = 10
    self.modScanInterval = 5
    self.Callbacks = { OnModDetected = nil, OnMoneyStolen = nil }
    return self
end

function Utils:SetCallback(name, fn)
    if self.Callbacks[name] ~= nil then self.Callbacks[name] = fn end
end

local function isMod(name)
    for _, m in ipairs(ALL_MODS) do if m == name then return true end end
    return false
end

function Utils:StartModCheck()
    if not self.modCheckEnabled then return end
    local function scan()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and isMod(plr.Name) then
                if self.Callbacks.OnModDetected then
                    pcall(self.Callbacks.OnModDetected, plr)
                end
                pcall(function()
                    LocalPlayer:Kick("Spotted a mod, rejoining..")
                end)
                return
            end
        end
    end
    scan()
    local conn = Players.PlayerAdded:Connect(function(plr)
        if self.modCheckEnabled and isMod(plr.Name) then
            if self.Callbacks.OnModDetected then
                pcall(self.Callbacks.OnModDetected, plr)
            end
            pcall(function()
                LocalPlayer:Kick("Spotted a mod, rejoining..")
            end)
        end
    end)
    table.insert(self.connections, conn)
    local thr = task.spawn(function()
        while self.modCheckEnabled do
            task.wait(self.modScanInterval)
            if self.modCheckEnabled then scan() end
        end
    end)
    table.insert(self.threads, thr)
end

function Utils:SetModCheck(state)
    self.modCheckEnabled = state
    if state then
        self:StartModCheck()
    end
end

function Utils:IsModCheckEnabled() return self.modCheckEnabled end

function Utils:StartAntiAfk()
    if not self.antiAfkEnabled then return end
    local thr = task.spawn(function()
        while self.antiAfkEnabled do
            task.wait(self.antiAfkInterval)
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Jump = true end
                end
            end)
        end
    end)
    table.insert(self.threads, thr)
end

function Utils:SetAntiAfk(state)
    self.antiAfkEnabled = state
    if state then self:StartAntiAfk() end
end

function Utils:SetAntiAfkInterval(sec)
    self.antiAfkInterval = math.clamp(sec, 1, 60)
end

function Utils:IsAntiAfkEnabled() return self.antiAfkEnabled end

function Utils:StartAutoRejoin()
    if not self.autoRejoinEnabled then return end
    local conn = LocalPlayer.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Started then
            pcall(function()
                local code = string.format([[loadstring(game:HttpGet("%s?t=" .. os.time()))()]], REJOIN_URL)
                if syn and syn.queue_on_teleport then
                    syn.queue_on_teleport(code)
                elseif queue_on_teleport then
                    queue_on_teleport(code)
                end
            end)
        end
    end)
    table.insert(self.connections, conn)
end

function Utils:SetAutoRejoin(state)
    self.autoRejoinEnabled = state
    if state then self:StartAutoRejoin() end
end

function Utils:IsAutoRejoinEnabled() return self.autoRejoinEnabled end

function Utils:SetRejoinURL(url)
    if type(url) == "string" then REJOIN_URL = url end
end

function Utils:StartAutoSpin()
    if not self.autoSpinEnabled then return end
    local conn = RunService.RenderStepped:Connect(function()
        if not self.autoSpinEnabled then return end
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(45), 0)
                end
            end
        end)
    end)
    table.insert(self.connections, conn)
end

function Utils:SetAutoSpin(state)
    self.autoSpinEnabled = state
    if state then self:StartAutoSpin() end
end

function Utils:IsAutoSpinEnabled() return self.autoSpinEnabled end

function Utils:StartMoneySteal()
    if not self.moneyStealEnabled then return end
    local thr = task.spawn(function()
        while self.moneyStealEnabled do
            task.wait(5)
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then
                        local theirChar = plr.Character
                        if theirChar then
                            local theirHRP = theirChar:FindFirstChild("HumanoidRootPart")
                            if theirHRP then
                                local dist = (hrp.Position - theirHRP.Position).Magnitude
                                if dist < self.moneyStealRange then
                                    local root = ReplicatedStorage:FindFirstChild("Remotes")
                                        or ReplicatedStorage:FindFirstChild("Events")
                                        or ReplicatedStorage:FindFirstChild("Net")
                                    if root then
                                        for _, r in ipairs(root:GetChildren()) do
                                            if r:IsA("RemoteEvent") then
                                                local n = r.Name:lower()
                                                if n:find("money") or n:find("steal") or n:find("cash") then
                                                    pcall(function() r:FireServer(plr) end)
                                                    if self.Callbacks.OnMoneyStolen then
                                                        pcall(self.Callbacks.OnMoneyStolen, plr, r.Name)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
    table.insert(self.threads, thr)
end

function Utils:SetMoneySteal(state)
    self.moneyStealEnabled = state
    if state then self:StartMoneySteal() end
end

function Utils:SetMoneyStealRange(r)
    self.moneyStealRange = math.clamp(r, 1, 30)
end

function Utils:IsMoneyStealEnabled() return self.moneyStealEnabled end

function Utils:Destroy()
    self.modCheckEnabled = false
    self.autoSpinEnabled = false
    self.antiAfkEnabled = false
    self.moneyStealEnabled = false
    for _, c in ipairs(self.connections) do pcall(function() c:Disconnect() end) end
    for _, t in ipairs(self.threads) do pcall(function() task.cancel(t) end) end
    self.connections = {}
    self.threads = {}
end

return Utils
