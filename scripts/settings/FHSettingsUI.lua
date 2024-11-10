---This file allows configuring the Forestry Helper settings within the ingame settings menu
---@class FHSettingsUI
---@field private settings FHSettings @The settings object
FHSettingsUI = {
    I18N_IDS = {
        GROUP_TITLE = "tvi_group_title",
        LENGTH_FACTOR_MODE = "tvi_length_factor_mode",
        LENGTH_FACTOR_ABS = "tvi_length_factor_abs",
        LENGTH_FACTOR_REL = "tvi_length_factor_rel"
    },
    LENGTH_FACTOR_MODE_I18N_IDS = {
        { index = 1, i18nTextId = "tvi_length_factor_mode_abs" },
        { index = 2, i18nTextId = "tvi_length_factor_mode_rel" }
    }
}

local FHSettingsUI_mt = Class(FHSettingsUI)
function FHSettingsUI.new()
    local self = setmetatable({}, FHSettingsUI_mt)
    return self
end

---This gets called every time the settings page gets opened
---@param   generalSettingsPage     table   @The instance of the base game's general settings page
function FHSettingsUI.onFrameOpen(generalSettingsPage)
    if generalSettingsPage.forestryHelperInitialized then
        -- Update the UI settings when opening the UI again
        generalSettingsPage.forestryHelperSettings:updateUiElements()
        return
    end

    local fhSettingsUI = FHSettingsUI.new()

    -- Create a text for the title and configure it as subtitle
    local groupTitle = TextElement.new()
    groupTitle:applyProfile("settingsMenuSubtitle", true)
    groupTitle:setText(g_i18n:getText(FHSettingsUI.I18N_IDS.GROUP_TITLE))
    generalSettingsPage.boxLayout:addElement(groupTitle)
    fhSettingsUI.groupTitle = groupTitle

    -- Create a UI element for chosing the length factor mode
    fhSettingsUI.lengthFactorMode = UIHelper.createChoiceElement(
        generalSettingsPage,
        "fh_lengthFactorMode",
        FHSettingsUI.I18N_IDS.LENGTH_FACTOR_MODE,
        FHSettingsUI.LENGTH_FACTOR_MODE_I18N_IDS,
        fhSettingsUI,
        "onLengthFactorModeChanged")

    -- Create two UI elements for the length factor, those will be switched out later in accordance with the selected mode
    fhSettingsUI.lengthFactorAbs = UIHelper.createRangeElement(
        generalSettingsPage,
        "fh_lengthFactorAbs",
        FHSettingsUI.I18N_IDS.LENGTH_FACTOR_ABS,
        FHSettings.LENGTH_FACTOR_ABS_MIN, FHSettings.LENGTH_FACTOR_ABS_MAX, FHSettings.LENGTH_FACTOR_ABS_STEP,
        g_i18n:getText("unit_mShort"),
        fhSettingsUI,
        "onAbsFactorChanged")
    fhSettingsUI.lengthFactorRel = UIHelper.createRangeElement(
        generalSettingsPage,
        "fh_lengthFactorRel",
        FHSettingsUI.I18N_IDS.LENGTH_FACTOR_REL,
        FHSettings.LENGTH_FACTOR_REL_MIN, FHSettings.LENGTH_FACTOR_REL_MAX, FHSettings.LENGTH_FACTOR_REL_STEP,
        "%",
        fhSettingsUI,
        "onRelFactorChanged")

    -- Apply the initial values
    fhSettingsUI.settings = g_currentMission.forestryHelperSettings
    fhSettingsUI:updateUiElements()

    -- Remember values for future calls
    generalSettingsPage.forestryHelperSettings = fhSettingsUI
    generalSettingsPage.forestryHelperInitialized = true
end
InGameMenuGeneralSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGeneralSettingsFrame.onFrameOpen, FHSettingsUI.onFrameOpen)

---Updates the UI elements to the reflect the current settings
function FHSettingsUI:updateUiElements()
    print(MOD_NAME .. ": Updating UI elements")
    -- Reflect the current settings state in the UI
    self.lengthFactorMode:setState(self.settings.lengthFactorMode)
    local isAbsMode = self.settings.lengthFactorMode == FHSettings.LENGTH_FACTOR_TYPE_ABS

    self.lengthFactorAbs:setDisabled(not isAbsMode)
    self.lengthFactorAbs:setState(self.settings.lengthFactorAbsIndex)

    self.lengthFactorRel:setDisabled(isAbsMode)
    self.lengthFactorRel:setState(self.settings.lengthFactorRelIndex)
end

---Reacts to changes of the length factor mode
---@param newState number @The new state
function FHSettingsUI:onLengthFactorModeChanged(newState)
    self.settings.lengthFactorMode = newState
    -- Update dependent fields
    self:updateUiElements()
    self.settings.cutPositionIndicator:updateF1MenuTexts()
end
---Reacts to changes of the absolute length factor
---@param newState number @The new state
function FHSettingsUI:onAbsFactorChanged(newState)
    self.settings.lengthFactorAbsIndex = newState
    self.settings.cutPositionIndicator:updateF1MenuTexts()
end
---Reacts to changes of the relative length factor
---@param newState number @The new state
function FHSettingsUI:onRelFactorChanged(newState)
    self.settings.lengthFactorRelIndex = newState
    self.settings.cutPositionIndicator:updateF1MenuTexts()
end