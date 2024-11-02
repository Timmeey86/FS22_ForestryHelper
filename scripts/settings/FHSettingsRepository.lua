---This class is responsible for reading and writing settings to the save game
---@class FHSettingsRepository
FHSettingsRepository = {
    FILENAME = "ForestryHelperSettings.xml",
    FH_KEY = "forestryHelper",
    LENGTH_FACTOR_BASE_KY = "lengthFactor",
    LENGTH_FACTOR_MODE_KEY = "modeIndex",
    LENGTH_FACTOR_ABS_KEY = "absoluteIndex",
    LENGTH_FACTOR_REL_KEY = "relativeIndex",
    STATE_ATTRIBUTE = "state"
}

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
function FHSettingsRepository.storeSettings()
    -- Create an empty XML file
    local settings = g_currentMission.forestryHelperSettings
    if settings == nil then
        Logging.warning("%s: Could not save settings because settings object was not found", MOD_NAME)
        return
    end
    local settingsXmlId = createXMLFile("FHSettings", FHSettingsRepository.getXmlFilePath(), FHSettingsRepository.FH_KEY)

    -- Add XML data in memory
    local lengthFactorKey = FHSettingsRepository.FH_KEY .. "." .. FHSettingsRepository.LENGTH_FACTOR_BASE_KY
    setXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_MODE_KEY, lengthFactorKey), settings.lengthFactorMode)
    setXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_ABS_KEY, lengthFactorKey), settings.lengthFactorAbsIndex)
    setXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_REL_KEY, lengthFactorKey), settings.lengthFactorRelIndex)

    -- Write the cache to the disk
    saveXMLFile(settingsXmlId)
end

function FHSettingsRepository.restoreSettings()
    -- Create an empty XML file
    local settings = g_currentMission.forestryHelperSettings
    if settings == nil then
        Logging.warning("%s: Could not read settings because settings object was not foun.d", MOD_NAME)
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
    local lengthFactorKey = FHSettingsRepository.FH_KEY .. "." .. FHSettingsRepository.LENGTH_FACTOR_BASE_KY
    settings.lengthFactorMode = getXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_MODE_KEY, lengthFactorKey))
    settings.lengthFactorAbsIndex = getXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_ABS_KEY, lengthFactorKey))
    settings.lengthFactorRelIndex = getXMLInt(settingsXmlId, getXmlStateAttributePath(FHSettingsRepository.LENGTH_FACTOR_REL_KEY, lengthFactorKey))
end

---Builds a path to the XML file which contains the settings
---@return  any      @The path to the XML or nil
function FHSettingsRepository.getXmlFilePath()
    if g_modSettingsDirectory then
        return ("%s/%s/%s"):format(g_modSettingsDirectory, MOD_NAME, FHSettingsRepository.FILENAME)
    end
    Logging.warning("%s: Could not retrieve mod settings directory, using local path", MOD_NAME)
    return "./" .. FHSettingsRepository.FILENAME
end