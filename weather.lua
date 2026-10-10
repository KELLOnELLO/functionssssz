local Weather = {}
Weather.__index = Weather

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local WEATHER_OPTIONS = {
    "Sunny",
    "Foggy",
    "Rainy",
    "Snowy",
}

local WEATHER_CONFIGS = {
    Sunny = "Sunny",
    Foggy = "Foggy",
    Rainy = "Rainy",
    Snowy = "Snowy",
}

function Weather.new()
    local self = setmetatable({}, Weather)

    self.current = nil
    self.WeatherValue = nil

    self.Callbacks = {
        OnChange = nil,
        OnError = nil
    }

    return self
end

function Weather:SetCallback(name, fn)
    if self.Callbacks[name] ~= nil then
        self.Callbacks[name] = fn
    end
end

function Weather:GetOptions()
    return WEATHER_OPTIONS
end

function Weather:WaitForWeatherValue(timeout)
    timeout = timeout or 10
    local value = workspace:WaitForChild("Weather", timeout)
    if value and value:IsA("StringValue") then
        self.WeatherValue = value
        return value
    end
    return nil
end

function Weather:Set(name)
    if not self.WeatherValue then
        local v = self:WaitForWeatherValue(10)
        if not v then
            if self.Callbacks.OnError then
                pcall(self.Callbacks.OnError, "Workspace.Weather not found")
            end
            return false
        end
    end

    local mapped = WEATHER_CONFIGS[name]
    if not mapped then
        if self.Callbacks.OnError then
            pcall(self.Callbacks.OnError, "Invalid weather: " .. tostring(name))
        end
        return false
    end

    local ok = pcall(function()
        self.WeatherValue.Value = mapped
    end)

    if ok then
        self.current = name
        if self.Callbacks.OnChange then
            pcall(self.Callbacks.OnChange, name)
        end
        return true
    else
        if self.Callbacks.OnError then
            pcall(self.Callbacks.OnError, "Failed to set weather: " .. tostring(name))
        end
        return false
    end
end

function Weather:Get()
    if self.WeatherValue then
        return self.WeatherValue.Value
    end
    return nil
end

function Weather:GetCurrent()
    return self.current
end

function Weather:IsValid(name)
    return WEATHER_CONFIGS[name] ~= nil
end

function Weather:Cycle()
    local idx = 1
    if self.current then
        for i, name in ipairs(WEATHER_OPTIONS) do
            if name == self.current then
                idx = i
                break
            end
        end
        idx = idx % #WEATHER_OPTIONS + 1
    end
    local nextWeather = WEATHER_OPTIONS[idx]
    self:Set(nextWeather)
    return nextWeather
end

return Weather
