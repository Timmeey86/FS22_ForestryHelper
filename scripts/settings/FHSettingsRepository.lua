---This class is responsible for reading and writing settings to the save game
---@class FHSettingsRepository
---@field settings FHSettings @The settings to be stored and loaded
FHSettingsRepository = {
    FILENAME = "ForestryHelperSettings.xml",
    FH_KEY = "forestryHelper",
    LENGTH_FACTOR_BASE_KEY = "lengthFactor",
    LENGTH_FACTOR_MODE_KEY = "modeIndex",
    LENGTH_FACTOR_ABS_KEY = "absoluteIndex",
    LENGTH_FACTOR_REL_KEY = "relativeIndex",
    CUT_POS_INDICATOR_BASE_KEY = "cutPositionIndicator",
    CUT_POS_INDICATOR_MODE_KEY = "modeIndex",
    CUT_POS_INDICATOR_LENGTH = "length",
    CUT_POS_INDICATOR_WEIGHT = "weight",
    STATE_ATTRIBUTE = "state"
}
local FHSettingsRepository_mt = Class(FHSettingsRepository)

---Creates a new settings repository
---@param settings FHSettings @The settings to be stored and loaded
---@return FHSettingsRepository @The new instance
function FHSettingsRepository.new(settings)
    local self = setmetatable({}, FHSettingsRepository_mt)
    self.settings = settings
    return self
end

---Builds an XML path for the given parameters
---@param   attribute       string      @the XML attribute
---@param   property        string      @the XML property which contains the attribute
---@param   parentProperty  any         @the parent property (if this is empty, the root node will be used)
---@return  string      @the XML path
local function getXmlAttributePath(attribute, property, parentProperty)
    local parentProp = parentProperty or FHSettingsRepository.FH_KEY
    return parentProp .. "." .. property .. "#" .. attribute
end

---Builds an XML path for "state" values like bool or enums
---@param   property        string      @the XML property which contains the attribute
---@param   parentProperty  any         @the parent property (if this is empty, the root node will be used)
---@return  string      @the XML path
local function getXmlStateAttributePath(property, parentProperty)
    return getXmlAttributePath(FHSettingsRepository.STATE_ATTRIBUTE, property, parentProperty)
end

---Writes the settings to a separate XML file in the save game folder
function FHSettingsRepository:storeSettings()
    print(MOD_NAME .. ": Storing settings")
    -- Create an empty XML file
    if self.settings == nil then
        Logging.warning("%s: Could not save settings because settings object was not found", MOD_NAME)
        return
    end
    local settingsXmlId = createXMLFile("FHSettings", FHSettingsRepository.getXmlFilePath(), FHSettingsRepository.FH_KEY)

    -- Add XML data in memory
    local lengthFactorKey = FHSettingsRepository.FH_KEY .. "." .. FHSettingsRepository.LENGTH_FACTOR_BASE_KEY
    setXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_MODE_KEY, lengthFactorKey), self.settings.lengthFactorMode)
    setXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_ABS_KEY, lengthFactorKey), self.settings.lengthFactorAbsIndex)
    setXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_REL_KEY, lengthFactorKey), self.settings.lengthFactorRelIndex)
    if self.settings.cutPositionIndicator ~= nil then
        local cpiKey = FHSettingsRepository.FH_KEY .. "." .. FHSettingsRepository.CUT_POS_INDICATOR_BASE_KEY
        setXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.CUT_POS_INDICATOR_MODE_KEY, cpiKey), self.settings.cutPositionIndicator.indicatorMode)
        setXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.CUT_POS_INDICATOR_LENGTH, cpiKey), self.settings.cutPositionIndicator.indicationLength)
        setXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.CUT_POS_INDICATOR_WEIGHT, cpiKey), self.settings.cutPositionIndicator.weightLimit)
    end

    -- Write the cache to the disk
    if not saveXMLFile(settingsXmlId) then
        Logging.error("%s: Failed saving XML settings to %s", MOD_NAME, FHSettingsRepository.getXmlFilePath())
    end
end

function FHSettingsRepository:restoreSettings()
    print(MOD_NAME .. ": Restoring settings")
    -- Create an empty XML file
    if self.settings == nil then
        Logging.warning("%s: Could not read settings because settings object was not found.", MOD_NAME)
        return
    end
    local xmlPath = FHSettingsRepository.getXmlFilePath()
    if not fileExists(xmlPath) then
        print(MOD_NAME .. ": No settings found, using default settings. (This usually means you added or updated the mod with an existing savegame)")
        return
    end
    local settingsXmlId = loadXMLFile("FHSettings", xmlPath, FHSettingsRepository.FH_KEY)
    if settingsXmlId == 0 then
        Logging.warning("%s: Failed loading settings even though the XML file exists.", MOD_NAME)
        return
    end

    -- Read the XML from memory
    local lengthFactorKey = FHSettingsRepository.FH_KEY .. "." .. FHSettingsRepository.LENGTH_FACTOR_BASE_KEY
    self.settings.lengthFactorMode = getXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_MODE_KEY, lengthFactorKey))
    self.settings.lengthFactorAbsIndex = getXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_ABS_KEY, lengthFactorKey))
    self.settings.lengthFactorRelIndex = getXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_REL_KEY, lengthFactorKey))
    if self.settings.cutPositionIndicator ~= nil then
        local cpiKey = FHSettingsRepository.FH_KEY .. "." .. FHSettingsRepository.CUT_POS_INDICATOR_BASE_KEY
        self.settings.cutPositionIndicator.indicatorMode = getXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.CUT_POS_INDICATOR_MODE_KEY, cpiKey)) or 1
        self.settings.cutPositionIndicator.indicationLength = getXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.CUT_POS_INDICATOR_LENGTH, cpiKey)) or 1
        self.settings.cutPositionIndicator.weightLimit = getXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.CUT_POS_INDICATOR_WEIGHT, cpiKey)) or 200
    end
end

---Builds a path to the XML file which contains the settings
---@return  any      @The path to the XML or nil
function FHSettingsRepository.getXmlFilePath()
    if g_modSettingsDirectory then
        return ("%s%s"):format(g_modSettingsDirectory, FHSettingsRepository.FILENAME)
    end
    Logging.warning("%s: Could not retrieve mod settings directory, using local path", MOD_NAME)
    return "./" .. FHSettingsRepository.FILENAME
end