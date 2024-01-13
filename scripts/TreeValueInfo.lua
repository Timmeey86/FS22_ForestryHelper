-- Create a table to store everything related to TreeValueInfo. This will also act like a class
TreeValueInfo = {}
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
    local treeOrPieceOfWood = splitShape -- Just to make the remaining code easier to understand

    -- Retrieve the number of liters in the tree and the price per liter (adjusted to the current shape of the tree)
    -- We reuse the function which is used by the sell trigger to get accurate price info
    -- (Source: https://gdn.giants-software.com/documentation_scripting_fs22.php?version=script&category=58&class=628#calculateWoodBaseValue9352)
    local numberOfLiters, valuePerLiter  = TreeValueInfo.dummyWoodTrigger:calculateWoodBaseValue(treeOrPieceOfWood)
    -- Round to an integer (lua has no math.round, so math.floor(x + .5) does what we want)
    local currentValue = math.floor(numberOfLiters * valuePerLiter + .5)
    numberOfLiters = math.floor(numberOfLiters + .5)

    -- Display the number of liters
    playerHudUpdater.objectBox:addLine("Liters", ('%s l'):format(numberOfLiters))

    -- Display the current value (if the tree/piece of wood was sold in its current shape)
    local currencySymbol = g_i18n:getCurrencySymbol(true)
    playerHudUpdater.objectBox:addLine("Current Value", ('%s %s'):format(currentValue, currencySymbol))

    --playerHudUpdater.objectBox:addLine("Potential Value", "TODO")
end

-- Inject our own method into the existing PlayerHUDUpdater method of the base game
PlayerHUDUpdater.showSplitShapeInfo = Utils.overwrittenFunction(PlayerHUDUpdater.showSplitShapeInfo, TreeValueInfo.addTreeValueInfo)

-- If the game would normally call the showSplitShapeInfo method, it will now call our method instead (which calls the original function)