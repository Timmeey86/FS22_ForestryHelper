---Stores settings for the forestry helper
---@class FHSettings
---@field public lengthFactorMode integer @The mode for additional length (absolute or relative)
---@field public lengthFactorAbsIndex integer @The index of the additional absolute length setting
---@field public lengthFactorRelIndex integer @The index of the additional relative length setting
---@field public cutPositionIndicator CutPositionIndicator @The cut position indicator which also stores some settings
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
---@param cutPositionIndicator CutPositionIndicator @The class instance which handles the adjusted cut position
---@return FHSettings @The new instance
function FHSettings.new(cutPositionIndicator)
    print(MOD_NAME .. ": Creating settings")
    local self = setmetatable({}, FHSettings_mt)

    self.lengthFactorMode = FHSettings.LENGTH_FACTOR_TYPE_ABS
    self.lengthFactorAbsIndex = 1
    self.lengthFactorRelIndex = 1
    self.cutPositionIndicator = cutPositionIndicator

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
    if length == nil then
        Logging.error("Method called with nil length")
        printCallstack()
    end
    local adjustedFactor
    if self.lengthFactorMode == FHSettings.LENGTH_FACTOR_TYPE_ABS then
        adjustedFactor = length + toAbsFactor(self.lengthFactorAbsIndex)
    else
        adjustedFactor = length * toRelFactor(self.lengthFactorRelIndex)
    end
    return adjustedFactor
end
