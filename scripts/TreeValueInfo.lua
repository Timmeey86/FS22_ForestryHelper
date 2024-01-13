-- Create a table to store everything related to TreeValueInfo. This will also act like a class
TreeValueInfo = {
    -- Define some constants for lookup of translated texts. The strings must match the i18n/locale_...xml entries
    -- tvi is just a prefix for TreeValueInfo
    I18N_IDS = {
        VOLUME = 'tvi_volume',
        CURRENT_VALUE = 'tvi_current_value',
        CUT_RECOMMENDATION = 'tvi_cut_recommendation'
    },
    -- Define constants for what the base game considers best value
    PROFITABLE_LENGTH_MIN = 6,
    PROFITABLE_LENGTH_MAX = 11
}
-- Define a dummy WoodUnloadTrigger to calculate price info
-- The bool arguments make it believe it's being created in a single player game - this info is not important for our use case
TreeValueInfo.dummyWoodTrigger = WoodUnloadTrigger.new(true, true)

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

        -- Calculate the best cut position: Each piece needs to be between 6 and 11 meters (value decreases when shorter or longer)
        local sizeX, sizeY, sizeZ, _, _ = getSplitShapeStats(pieceOfWood)
        local length = math.max(sizeX, sizeY, sizeZ)
        -- Only recommend a cut if the piece of wood is longer than 12 meters (otherwise one piece would be below 6m, so worth less)
        if length > 12 then
            local recommendedMinimumCutLength = TreeValueInfo.PROFITABLE_LENGTH_MIN
            local recommendedMaximumCutLength = math.min(TreeValueInfo.PROFITABLE_LENGTH_MAX, length - recommendedMinimumCutLength)
            playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.CUT_RECOMMENDATION), ('%.1fm-%.1fm'):format(recommendedMinimumCutLength, recommendedMaximumCutLength))
        end
    end
end

-- Inject our own method into the existing PlayerHUDUpdater method of the base game
PlayerHUDUpdater.showSplitShapeInfo = Utils.overwrittenFunction(PlayerHUDUpdater.showSplitShapeInfo, TreeValueInfo.addTreeValueInfo)

-- If the game would normally call the showSplitShapeInfo method, it will now call our method instead (which calls the original function first, and then adds stuff)