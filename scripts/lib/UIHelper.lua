UIHelper = {}

---Adds a simple yes/no switch to the UI
---@param generalSettingsPage   table       @The base game object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param target                table       @The object which contains the callback func
---@param callbackFunc          string      @The name of the function to call when the value changes
---@return                      table       @The created object
function UIHelper.createBoolElement(generalSettingsPage, id, i18nTextId, target, callbackFunc)
    -- Most other mods seem to clone an element rather than creating a new one
    local boolElement = generalSettingsPage.checkUseEasyArmControl:clone()
    -- Assign the object which shall receive change events
    boolElement.target = target
    -- Change relevant values
    boolElement.id = id
    boolElement:setLabel(g_i18n:getText(i18nTextId .. "_short"))
    -- Element #6 is the tool tip. Maybe we can find a more robust way to get this in future
    boolElement.elements[6]:setText(g_i18n:getText(i18nTextId .. "_long"))
    boolElement:setCallback("onClickCallback", callbackFunc)
    generalSettingsPage.boxLayout:addElement(boolElement)

    return boolElement
end

---Creates an element which allows choosing one out of several text values
---@param generalSettingsPage   table       @The base game object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param i18nValueMap          table       @An map of values containing translation IDs for the possible values
---@param target                table       @The object which contains the callback func
---@param callbackFunc          string      @The name of the function to call when the value changes
---@return                      table       @The created object
function UIHelper.createChoiceElement(generalSettingsPage, id, i18nTextId, i18nValueMap, target, callbackFunc)
    -- Create a bool element and then change its values
    local choiceElement = UIHelper.createBoolElement(generalSettingsPage, id, i18nTextId, target, callbackFunc)

    local texts = {}
    for _, valueEntry in pairs(i18nValueMap) do
        table.insert(texts, g_i18n:getText(valueEntry.i18nTextId))
    end
    choiceElement:setTexts(texts)

    return choiceElement
end

---Creates an element which allows choosing one out of several integer values
---@param generalSettingsPage   table       @The base game object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param minValue              integer     @The first value which can be selected
---@param maxValue              integer     @The last value which can be selected
---@param step                  integer     @The difference between any two values. Make sure this matches max value
---@param unit                  string      @The unit to be displayed (may be empty)
---@param target                table       @The object which contains the callback func
---@param callbackFunc          string      @The name of the function to call when the value changes
---@return                      table       @The created object
function UIHelper.createRangeElement(generalSettingsPage, id, i18nTextId, minValue, maxValue, step, unit, target, callbackFunc)
    -- Create a bool element and then change its values
    local rangeElement = UIHelper.createBoolElement(generalSettingsPage, id, i18nTextId, target, callbackFunc)

    local texts = {}
    for i = minValue, maxValue, step do
        local text = tostring(i)
        if unit then
            text = ("%s %s"):format(text, unit)
        end
        table.insert(texts, text)
    end
    rangeElement:setTexts(texts)

    return rangeElement
end