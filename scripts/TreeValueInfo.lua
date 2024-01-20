-- Create a table to store everything related to TreeValueInfo. This will also act like a class
TreeValueInfo = {
    -- Define some constants for lookup of translated texts. The strings must match the i18n/locale_...xml entries
    -- tvi is just a prefix for TreeValueInfo
    I18N_IDS = {
        VOLUME = 'tvi_volume',
        CURRENT_VALUE = 'tvi_current_value',
        CUT_RECOMMENDATION = 'tvi_cut_recommendation',
        LITERS_IF_CHIPPED = 'tvi_liters_if_chipped',
        CURRENT_VALUE_IF_CHIPPED = 'tvi_current_value_if_chipped',
        POTENTIAL_VALUE_IF_CHIPPED = 'tvi_potential_value_if_chipped'
    },
    -- Define constants for what the base game considers best value
    PROFITABLE_LENGTH_MIN = 6,
    PROFITABLE_LENGTH_MAX = 11
}

-- Define a constructor, then create a new instance just so we can store some variables for the current session
-- This is how you define a proper class with a metatable and a constructor in FS22 lua:
local TreeValueInfo_mt = Class(TreeValueInfo)
function TreeValueInfo.new()
    local self = setmetatable({}, TreeValueInfo_mt)

    self.debugValueDetails = true
    self.debugShapeDetails = true
    return self
end

local treeValueInfo = TreeValueInfo.new()

-- Define a method which will add more information to the info box for trees or wood. The last argument is defined by the method we are extending

---This function adds information about the value of trees
---@param playerHudUpdater table @The object used by the base game to display the information. We are interested in its "objectBox"
---@param superFunc function @The base game function which is extended by this one.
---@param splitShape table @The split shape which might be a tree or a piece of wood (or something else).
function TreeValueInfo.addTreeValueInfo(playerHudUpdater, superFunc, splitShape)

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
    playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.VOLUME), ('%d l'):format(shapeData.volume))

    -- Display detailed info if enabled
    if treeValueInfo.debugShapeDetails then
        playerHudUpdater.objectBox:addLine("Size X", ('%.3f'):format(shapeData.sizeX))
        playerHudUpdater.objectBox:addLine("Size Y", ('%.3f'):format(shapeData.sizeY))
        playerHudUpdater.objectBox:addLine("Size Z", ('%.3f'):format(shapeData.sizeZ))
        playerHudUpdater.objectBox:addLine("# Convexes", ('%d'):format(shapeData.numConvexes))
        playerHudUpdater.objectBox:addLine("# Attachments", ('%d'):format(shapeData.numAttachments))
    end
    if treeValueInfo.debugValueDetails then
        playerHudUpdater.objectBox:addLine("Price per Liter", ('%.3f %s/l'):format(valueData.pricePerLiter, currencySymbol))
        playerHudUpdater.objectBox:addLine("Volume Quality", ('%.3f'):format(valueData.volumeQuality))
        playerHudUpdater.objectBox:addLine("Convexity Quality", ('%.3f'):format(valueData.convexityQuality))
        playerHudUpdater.objectBox:addLine("Quality Scale", ('%.3f'):format(valueData.qualityScale))
        playerHudUpdater.objectBox:addLine("Defoliage Scale", ('%.3f'):format(valueData.defoliageScale))
        playerHudUpdater.objectBox:addLine("Length Scale", ('%.3f'):format(valueData.lengthScale))
        playerHudUpdater.objectBox:addLine("Total Quality", ('%.3f'):format(totalQuality))
    end

    -- Display the current value (if the tree/piece of wood was sold in its current shape)
    playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.CURRENT_VALUE), ('%d %s'):format(currentValue, currencySymbol))

    -- If the player is looking at a piece of wood on the ground
    if getIsSplitShapeSplit(treeOrPieceOfWood) and getRigidBodyType(treeOrPieceOfWood) == RigidBodyType.DYNAMIC then
        local pieceOfWood = treeOrPieceOfWood -- alias for readability

        -- Get the amount of wood chips this piece of wood would produce
        local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(pieceOfWood))
        local litersIfChipped = shapeData.volume * splitType.woodChipsPerLiter
        playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.LITERS_IF_CHIPPED), ('%d l'):format(litersIfChipped))

        -- Calculate the price for the wood chips if sold right away
        local currentWoodChipValue = g_currentMission.economyManager:getPricePerLiter(FillType.WOODCHIPS) * litersIfChipped
        playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.CURRENT_VALUE_IF_CHIPPED), ('%d %s'):format(currentWoodChipValue, currencySymbol))

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
        playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.POTENTIAL_VALUE_IF_CHIPPED), ('%d %s'):format(potentialWoodChipValue, currencySymbol))
    end
end

-- Inject our own method into the existing PlayerHUDUpdater method of the base game
PlayerHUDUpdater.showSplitShapeInfo = Utils.overwrittenFunction(PlayerHUDUpdater.showSplitShapeInfo, TreeValueInfo.addTreeValueInfo)

-- If the game would normally call the showSplitShapeInfo method, it will now call our method instead (which calls the original function first, and then adds stuff)