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
-- Define a dummy WoodUnloadTrigger to calculate price info
-- The bool arguments make it believe it's being created in a single player game - this info is not important for our use case
TreeValueInfo.dummyWoodTrigger = WoodUnloadTrigger.new(true, true)

-- Helper object for calculating advanced stuff
local shapeMeasurementHelper = ShapeMeasurementHelper.new()

-- Define a function which will estimate the value of a part of a tree based on precalculated values

---Retrieves the partial value of a part of a tree, assuming it's delimbed
---@param wholePieceData table @Contains the total volume, the type of tree and the number of convexes, Y size and Z size for the whole shape
---@param partialPieceData table @Contains the volume, length, Y extent and Z extent of the partial piece
---@return integer @The volume in liters
---@return integer @The price per liter adjusted to the quality of the tree
local function getPartialDelimbedValue(wholePieceData, partialPieceData)
    local volumeProportion = partialPieceData.volume / wholePieceData.volume
    local partialNumConvexes = math.floor(wholePieceData.numConvexes * volumeProportion + .5)

    return TreeValueInfo.dummyWoodTrigger:calculateWoodBaseValueForData(
        partialPieceData.volume, wholePieceData.treeType, partialPieceData.length, wholePieceData.sizeY, wholePieceData.sizeZ, partialNumConvexes, 0)
end

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

    -- Retrieve the number of liters in the tree and the price per liter (adjusted to the current shape of the tree)
    -- We reuse the function which is used by the sell trigger to get accurate price info
    -- (Source: https://gdn.giants-software.com/documentation_scripting_fs22.php?version=script&category=58&class=628#calculateWoodBaseValue9352)
    local numberOfLiters, valuePerLiter  = TreeValueInfo.dummyWoodTrigger:calculateWoodBaseValue(treeOrPieceOfWood)
    local currentValue = numberOfLiters * valuePerLiter

    -- Display the number of liters
    playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.VOLUME), ('%d l'):format(numberOfLiters))

    -- Display the current value (if the tree/piece of wood was sold in its current shape)
    local currencySymbol = g_i18n:getCurrencySymbol(true)
    playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.CURRENT_VALUE), ('%d %s'):format(currentValue, currencySymbol))

    -- If the player is looking at a piece of wood on the ground
    if getIsSplitShapeSplit(treeOrPieceOfWood) and getRigidBodyType(treeOrPieceOfWood) == RigidBodyType.DYNAMIC then
        local pieceOfWood = treeOrPieceOfWood -- alias for readability

        -- Get the type of tree
        local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(pieceOfWood))

        -- Estimate the value for the left and right pieces
        if shapeMeasurementHelper.futureWoodPartData ~= nil then
            -- Get data on the full shape
            local _, sizeY, sizeZ, numConvexes, _ = getSplitShapeStats(treeOrPieceOfWood)
            local wholePieceData = {
                volume = getVolume(treeOrPieceOfWood),
                treeType = splitType,
                numConvexes = numConvexes,
                sizeY = sizeY,
                sizeZ = sizeZ
            }
            local partData = shapeMeasurementHelper.futureWoodPartData

            -- Calculate the value of the bottom part
            local bottomData = {
                volume = partData.bottomVolume,
                length = partData.bottomLength,
                sizeY = partData.bottomSizeY,
                sizeZ = partData.bottomSizeZ
            }
            local delimbedBottomVolume, bottomPricePerLiter = getPartialDelimbedValue(wholePieceData, bottomData)
            local bottomPrice = delimbedBottomVolume * bottomPricePerLiter

            -- Calculate the value of the top part
            local topData = {
                volume = partData.topVolume,
                length = partData.topLength,
                sizeY = partData.topSizeY,
                sizeZ = partData.topSizeZ
            }
            local delimbedTopVolume, topPricePerLiter = getPartialDelimbedValue(wholePieceData, topData)
            local topPrice = delimbedTopVolume * topPricePerLiter

            -- Display the values
            playerHudUpdater.objectBox:addLine("Estimated value after cut", ('%d %s| %d %s'):format(bottomPrice, currencySymbol, topPrice, currencySymbol))

            -- Calculate the absolute value increase
            local priceAfterCutting = bottomPrice + topPrice
            local absoluteValueIncrease = priceAfterCutting - currentValue
            playerHudUpdater.objectBox:addLine("Value increase when cutting", ('%d %s'):format(absoluteValueIncrease, currencySymbol))
        end

        -- Get the amount of wood chips this piece of wood would produce
        local litersIfChipped = numberOfLiters * splitType.woodChipsPerLiter
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
        -- multiplay manually here.
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



local function inj_update(chainsaw, superFunc, deltaTime, allowInput)
    superFunc(chainsaw, deltaTime, allowInput)
    shapeMeasurementHelper:afterChainsawUpdate(chainsaw)
end
Chainsaw.update = Utils.overwrittenFunction(Chainsaw.update, inj_update)