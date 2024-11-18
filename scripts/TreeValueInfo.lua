MOD_NAME = "FS22_ForestryHelper"

-- Create a table to store everything related to ForestryHelper. This will also act like a class
ForestryHelper = {
    -- Define some constants for lookup of translated texts. The strings must match the i18n/locale_...xml entries
    -- tvi is just a prefix for ForestryHelper
    I18N_IDS = {
        VOLUME = 'fh_volume',
        CURRENT_VALUE = 'fh_current_value',
        TOTAL_QUALITY = 'fh_total_quality',
        LITERS_IF_CHIPPED = 'fh_liters_if_chipped',
        CURRENT_VALUE_IF_CHIPPED = 'fh_current_value_if_chipped',
        POTENTIAL_VALUE_IF_CHIPPED = 'fh_potential_value_if_chipped',
        SHAPE = 'fh_shape',
        LENGTH = 'fh_length',
        ATTACHMENTS = 'fh_attachments',
        PERFECT = 'fh_perfect',
        GOOD = 'fh_good',
        ACCEPTABLE = 'fh_acceptable',
        BAD = 'fh_bad'
    },
    -- Define constants for what the base game considers best value
    PROFITABLE_LENGTH_MIN = 6,
    PROFITABLE_LENGTH_MAX = 11
}

-- Define a constructor, then create a new instance just so we can store some variables for the current session
-- This is how you define a proper class with a metatable and a constructor in FS22 lua:
local ForestryHelper_mt = Class(ForestryHelper)
function ForestryHelper.new()
    local self = setmetatable({}, ForestryHelper_mt)

    self.debugValueDetails = false
    self.debugShapeDetails = false
    self.currentShape = nil
    return self
end

local ForestryHelper = ForestryHelper.new()

-- Define a function which returns the appropriate quality text based on defined thresholds

---Retrieves a translated "perfect", "good", "acceptable", or "bad" text based on the current quality and the provided thresholds.
---@param quality number @The quality factor as calculated by the wood sell trigger.
---@param perfectThreshold number @The maximum possible quality.
---@param goodThreshold number @The minimum quality to still consider it "good".
---@param acceptableThreshold number @The minimum quality to still consider it "acceptable"
---@return string @A translated rating of the quality
function ForestryHelper.getQualityText(quality, perfectThreshold, goodThreshold, acceptableThreshold)
    -- Since quality ratings are floating point values, consider a small imprecision (often called "epsilon")
    local floatingPointImprecision = .0001
    local translationKey
    if quality >= (perfectThreshold - floatingPointImprecision) then
        translationKey = ForestryHelper.I18N_IDS.PERFECT
    elseif quality >= (goodThreshold - floatingPointImprecision) then
        translationKey = ForestryHelper.I18N_IDS.GOOD
    elseif quality >= (acceptableThreshold - floatingPointImprecision) then
        translationKey = ForestryHelper.I18N_IDS.ACCEPTABLE
    else
        translationKey = ForestryHelper.I18N_IDS.BAD
    end
    return g_i18n:getText(translationKey)
end

-- Define a method which will add more information to the info box for trees or wood. The last argument is defined by the method we are extending

---This function adds information about the value of trees
---@param playerHudUpdater PlayerHUDUpdater @The object used by the base game to display the information. We are interested in its "objectBox"
---@param superFunc function @The base game function which is extended by this one.
---@param splitShape table @The split shape which might be a tree or a piece of wood (or something else).
function ForestryHelper.addForestryHelper(playerHudUpdater, superFunc, splitShape)

    -- Call the base game behavior (including other mods which were registered before our mod)
    -- This way, if Giants changes their code, we don't have to adapt our mod in many cases
    superFunc(playerHudUpdater, splitShape)

    -- Do nothing if we're not looking at a tree or piece of wood
    if not entityExists(splitShape) or getSplitType(splitShape) == 0 then
        -- Note: The entityExists check is done in https://gdn.giants-software.com/documentation_scripting_fs22.php?version=script&category=58&class=628#processWood9359
        --       so it felt like we should probably do the same.
        -- Note: The split type seems to be the type of tree, starting from 1, so a type of 0 would mean this is not a tree. It also looks like trees are the
        --       only thing which classify as split shape (with a type > 0).
        return
    end
    local treeOrPieceOfWood = splitShape -- alias for readability

    -- Retrieve data about the tree or piece of wood
    local data = WoodPriceCalculation.calculateWoodParameters(treeOrPieceOfWood)

    -- Retrieve the number of liters in the tree and the price per liter (adjusted to the current shape of the tree)
    local valueData = data.valueData
    local shapeData = data.shapeData
    local totalQuality = valueData.qualityScale * valueData.defoliageScale * valueData.lengthScale
    local currentValue = shapeData.volume * valueData.pricePerLiter * totalQuality

    -- Display the number of liters
    local currencySymbol = g_i18n:getCurrencySymbol(true)
    playerHudUpdater.objectBox:addLine(g_i18n:getText(ForestryHelper.I18N_IDS.VOLUME), g_i18n:formatFluid(shapeData.volume))

    -- If the player is looking at a piece of wood on the ground
    -- Note: A the body type for a piece of wood on the ground returns DYNAMIC on servers/in single player, but KINEMATIC on multiplayer clients (reason unknown)
    --       Therefore we just filter for "not equal to static"
    if getIsSplitShapeSplit(treeOrPieceOfWood) and getRigidBodyType(treeOrPieceOfWood) ~= RigidBodyType.STATIC then

        local pieceOfWood = treeOrPieceOfWood -- alias for readability

        -- Check if the player is sitting in a wood harvester
        local isInWoodHarvester = g_currentMission.currentWoodHarvesterSpec ~= nil

        -- Skip quality info while in a wood harvester - The player would only get this info for the remaining tree rather than the piece they are about to cut
        if not isInWoodHarvester then

            -- Display the current value (if the tree/piece of wood was sold in its current shape)
            playerHudUpdater.objectBox:addLine(g_i18n:getText(ForestryHelper.I18N_IDS.CURRENT_VALUE), ('%d %s'):format(currentValue, currencySymbol))

            -- Display hints about different aspects which influence the total quality
            playerHudUpdater.objectBox:addLine(g_i18n:getText(ForestryHelper.I18N_IDS.SHAPE), ForestryHelper.getQualityText(valueData.qualityScale, 1.0, 0.7, 0.5)) -- min 0.05
            playerHudUpdater.objectBox:addLine(g_i18n:getText(ForestryHelper.I18N_IDS.LENGTH), ForestryHelper.getQualityText(valueData.lengthScale, 1.2, 1.0, 0.8)) -- min 0.6
            playerHudUpdater.objectBox:addLine(g_i18n:getText(ForestryHelper.I18N_IDS.ATTACHMENTS), ('%d'):format(shapeData.numAttachments))

            -- Display the total quality of the tree, which is proportional to the sell price
            playerHudUpdater.objectBox:addLine(g_i18n:getText(ForestryHelper.I18N_IDS.TOTAL_QUALITY), ('%d %%'):format(totalQuality * 100))

            -- Display detailed info if enabled
            if ForestryHelper.debugShapeDetails then
                playerHudUpdater.objectBox:addLine("Size X", ('%.3f'):format(shapeData.sizeX))
                playerHudUpdater.objectBox:addLine("Size Y", ('%.3f'):format(shapeData.sizeY))
                playerHudUpdater.objectBox:addLine("Size Z", ('%.3f'):format(shapeData.sizeZ))
                playerHudUpdater.objectBox:addLine("# Convexes", ('%d'):format(shapeData.numConvexes))
                playerHudUpdater.objectBox:addLine("# Attachments", ('%d'):format(shapeData.numAttachments))
            end
            if ForestryHelper.debugValueDetails then
                playerHudUpdater.objectBox:addLine("Price per Liter", ('%.3f %s/l'):format(valueData.pricePerLiter, currencySymbol))
                playerHudUpdater.objectBox:addLine("Volume Quality", ('%.3f'):format(valueData.volumeQuality))
                playerHudUpdater.objectBox:addLine("Convexity Quality", ('%.3f'):format(valueData.convexityQuality))
                playerHudUpdater.objectBox:addLine("Quality Scale", ('%.3f'):format(valueData.qualityScale))
                playerHudUpdater.objectBox:addLine("Defoliage Scale", ('%.3f'):format(valueData.defoliageScale))
                playerHudUpdater.objectBox:addLine("Length Scale", ('%.3f'):format(valueData.lengthScale))
            end
        end

        -- Information about wood chips might help the player decide whether or not to chip the top part of the tree

        -- Get the amount of wood chips this piece of wood would produce
        local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(pieceOfWood))
        local litersIfChipped = shapeData.volume * splitType.woodChipsPerLiter
        playerHudUpdater.objectBox:addLine(g_i18n:getText(ForestryHelper.I18N_IDS.LITERS_IF_CHIPPED), g_i18n:formatFluid(litersIfChipped))

        -- Calculate the price for the wood chips if sold right away
        local currentWoodChipValue = g_currentMission.economyManager:getPricePerLiter(FillType.WOODCHIPS) * litersIfChipped
        playerHudUpdater.objectBox:addLine(g_i18n:getText(ForestryHelper.I18N_IDS.CURRENT_VALUE_IF_CHIPPED), ('%d %s'):format(currentWoodChipValue, currencySymbol))

        -- Calculate the maximum price for the wood chips
        local highestFactor = 0.1
        local woodChipFillType = g_fillTypeManager:getFillTypeByIndex(FillType.WOODCHIPS)
        for _, factor in pairs(woodChipFillType.economy.factors) do
            if factor > highestFactor then
                highestFactor = factor
            end
        end
        -- Looks like economyManager:getPricePerLiter respects the game's difficulty setting, while FillType:pricePerLiter doesn't, so we need to
        -- multiply manually here.
        -- Note: You can find functions like getPriceMultiplier while debugging if you unfold the class name (like EconomyManager) in the globals tab
        -- of GIANTS Studio and make sure the "Filter" dropdown has "function" enabled. You won't know the syntax, but you'll get lua errors if you got it wrong,
        -- so just try it out until you get it right.
        local difficultyMultiplier = g_currentMission.economyManager:getPriceMultiplier()
        local maximumPricePerLiter = woodChipFillType.pricePerLiter * highestFactor * difficultyMultiplier
        local potentialWoodChipValue = litersIfChipped * maximumPricePerLiter
        playerHudUpdater.objectBox:addLine(g_i18n:getText(ForestryHelper.I18N_IDS.POTENTIAL_VALUE_IF_CHIPPED), ('%d %s'):format(potentialWoodChipValue, currencySymbol))
    end
end


-- If the game would normally call the showSplitShapeInfo method, it will now call our method instead (which calls the original function first, and then adds stuff)

-- When aiming a chainsaw at a tree, one often doesn't get the info window because the chainsaw needs to point above the tree, and the info window will only be
-- displayed when looking right at the tree. We therefore hook into the chainsaw's update method to figure out if the info box should be displayed

---Remembers the current shape when the chainsaw displays a ring around a tree to be cut
---@param chainsaw table @The chainsaw instance
---@param superFunc function @The base game function
---@param shape any @The ID of the wood shape (or nil)
local function onChainsawUpdateRingSelector(chainsaw, superFunc, shape)
    -- Always call the superFunc
    superFunc(chainsaw, shape)

    -- If the ring selector is displayed, and a shape was detected which is not the root shape
    if chainsaw.isClient and chainsaw.player.isEntered and chainsaw.ringSelector ~= nil and getVisibility(chainsaw.ringSelector) and shape ~= nil and shape ~= 0 then
        -- Remember the shape
        ForestryHelper.currentShape = shape
    else
        ForestryHelper.currentShape = nil
    end
end

---Makes sure the info box is shown on the next frame while the chainsaw ring is visible
---@param chainsaw table @The chainsaw instance
---@param superFunc function @The base game function
---@param deltaTime number @The time which has passed since the previous update call
---@param allowInput boolean @True if input is currently allowed for the player
local function onChainsawUpdate(chainsaw, superFunc, deltaTime, allowInput)
    -- Always call the superFunc
    superFunc(chainsaw, deltaTime, allowInput)

    -- Check that everything is properly initialized
    local player = g_currentMission.player
    if player ~= nil and player.hudUpdater ~= nil and player.hudUpdater.objectBox ~= nil then

        -- If the chainsaw is pointing at a tree and..
        if ForestryHelper.currentShape ~= nil then
            -- ... the info hud would not be displayed currently
            if not player.hudUpdater.objectBox:canDraw() then
                -- Display the info hud on the next frame
                player.hudUpdater:showSplitShapeInfo(ForestryHelper.currentShape)
            end
            -- else: the box will be displayed already; nothing to do
        end
    end
end

local cutPositionIndicator = CutPositionIndicator.new()
local settings = FHSettings.new(cutPositionIndicator)
local settingsRepository = FHSettingsRepository.new(settings)

-- Register our overrides as late as possible in order to not be affected by mods which override the same methods, but don't call superFunc
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(mission, node)
    -- We use local functions so we can supply different parameters, e.g. cutPositionIndicator as first argument (by calling the function with : instead of .))
    Chainsaw.delete = Utils.prependedFunction(Chainsaw.delete, function(chainsaw) cutPositionIndicator:before_chainsawDelete(chainsaw) end)
    Chainsaw.onDeactivate = Utils.prependedFunction(Chainsaw.onDeactivate, function(chainsaw, allowInput) cutPositionIndicator:before_chainsawDeactivate(chainsaw) end)
    Chainsaw.postLoad = Utils.appendedFunction(Chainsaw.postLoad, function(chainsaw, xmlFile) cutPositionIndicator:after_chainsawPostLoad(chainsaw, xmlFile) end)
    Chainsaw.updateRingSelector = Utils.appendedFunction(Chainsaw.updateRingSelector, function(chainsaw, shape) cutPositionIndicator:after_chainsawUpdateRingSelector(chainsaw, shape) end)

    -- Note: When overriding non-member functions, superFunc will still be the second argument, even though the first argument isn't "self"
    ChainsawUtil.cutSplitShape = Utils.overwrittenFunction(ChainsawUtil.cutSplitShape, function(shapeId, superFunc, x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ, farmId)
        cutPositionIndicator:adaptCutIfNecessary(superFunc, shapeId, x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ, farmId)
    end)

    Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, function(player) cutPositionIndicator:registerActionEvents() end)

    -- Multiplayer synchronization
    ChainsawCutEvent.new = Utils.overwrittenFunction(ChainsawCutEvent.new, function(splitShapeId, superFunc, x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ, farmId)
        x, y, z = cutPositionIndicator:getAdjustedCutPosition(x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ)
        return superFunc(splitShapeId, x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ, farmId)
    end)
    PlayerHUDUpdater.showSplitShapeInfo = Utils.overwrittenFunction(PlayerHUDUpdater.showSplitShapeInfo, ForestryHelper.addForestryHelper)
    Chainsaw.updateRingSelector = Utils.overwrittenFunction(Chainsaw.updateRingSelector, onChainsawUpdateRingSelector)
    Chainsaw.update = Utils.overwrittenFunction(Chainsaw.update, onChainsawUpdate)

    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, function()
        settingsRepository:storeSettings()
    end)

    g_currentMission.forestryHelperSettings = settings
    settingsRepository:restoreSettings()

end)