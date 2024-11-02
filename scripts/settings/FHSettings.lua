---Stores settings for the forestry helper
---@class FHSettings
FHSettings = {
    LENGTH_FACTOR_TYPE_ABS = 1,
    LENGTH_FACTOR_TYPE_REL = 2,
    LENGTH_FACTOR_ABS_MIN = .0,
    LENGTH_FACTOR_ABS_MAX = .40,
    LENGTH_FACTOR_ABS_STEP = .01,
    LENGTH_FACTOR_REL_MIN = 1,
    LENGTH_FACTOR_REL_MAX = 15,
    LENGTH_FACTOR_REL_STEP = 1,
}
local FHSettings_mt = Class(FHSettings)

---Creates a new instance of this clas
---@return table @The new instance
function FHSettings.new()
    local self = setmetatable({}, FHSettings_mt)

    self.lengthFactorMode = FHSettings.LENGTH_FACTOR_TYPE_ABS
    self.lengthFactorAbsIndex = 1
    self.lengthFactorRelIndex = 1

    return self
end

---Converts an index of an absolute length factor to its corresponding value
---@param index number @the index
---@return number @the value which matches the index
local function toAbsFactor(index)
    return FHSettings.LENGTH_FACTOR_ABS_MIN + (index - 1) * FHSettings.LENGTH_FACTOR_ABS_STEP
end

---Converts an index of a relative length factor to its corresponding value
---@param index number @the index
---@return number @the value which matches the index
local function toRelFactor(index)
    return 1.0 + (FHSettings.LENGTH_FACTOR_REL_MIN + (index - 1) * FHSettings.LENGTH_FACTOR_REL_STEP) / 100.0
end

---Adjusts the length value in accordance with the settings
---@param length number @The current length
---@return number @The potentially adusted length
function FHSettings:getAdjustedLength(length)
    local adjustedFactor
    if self.lengthFactorMode == FHSettings.LENGTH_FACTOR_TYPE_ABS then
        adjustedFactor = length + toAbsFactor(self.lengthFactorAbsIndex)
    else
        adjustedFactor = length * toRelFactor(self.lengthFactorRelIndex)
    end
    return adjustedFactor
end

-- Note: These settings are meant to be per-player and are thus not being synchronized

Mission00.load = Utils.prependedFunction(Mission00.load, function(mission)
    mission.forestryHelperSettings = FHSettings:new()
end)
BaseMission.loadMapFinished = Utils.prependedFunction(BaseMission.loadMapFinished, function(...)
    FHSettingsRepository.restoreSettings()
end)
FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, function()
    g_currentMission.forestryHelperSettings = nil
end)
FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, function()
    FHSettingsRepository.storeSettings()
end)