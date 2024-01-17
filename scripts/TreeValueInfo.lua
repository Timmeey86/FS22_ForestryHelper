-- Create a table to store everything related to TreeValueInfo. This will also act like a class
TreeValueInfo = {
    -- Define some constants for lookup of translated texts. The strings must match the i18n/locale_...xml entries
    -- tvi is just a prefix for TreeValueInfo
    I18N_IDS = {
        VOLUME = 'tvi_volume',
        CURRENT_VALUE = 'tvi_current_value',
        DELIMBED_VALUE = 'tvi_delimbed_value',
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
-- The functions we are using from the WoodUnloadTrigger class don't actually use any of its properties, so really any instance is sufficient
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
    local volume = getVolume(treeOrPieceOfWood)
    local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(treeOrPieceOfWood))
    local sizeX, sizeY, sizeZ, numConvexes, numAttachments = getSplitShapeStats(treeOrPieceOfWood)
    local numberOfLiters, valuePerLiter  = TreeValueInfo.dummyWoodTrigger:calculateWoodBaseValueForData(volume, splitType, sizeX, sizeY, sizeZ, numConvexes, numAttachments)
    local currentValue = numberOfLiters * valuePerLiter

    -- Display the number of liters
    playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.VOLUME), ('%d l'):format(numberOfLiters))

    -- Display the current value (if the tree/piece of wood was sold in its current shape)
    local currencySymbol = g_i18n:getCurrencySymbol(true)
    playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.CURRENT_VALUE), ('%d %s'):format(currentValue, currencySymbol))

    if numAttachments > 0 then
        -- Display the current value if delimbed
        local _, valuePerLiterDelimbed  = TreeValueInfo.dummyWoodTrigger:calculateWoodBaseValueForData(volume, splitType, sizeX, sizeY, sizeZ, numConvexes, 0)
        local valueIfDelimbed = numberOfLiters * valuePerLiterDelimbed
        playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.DELIMBED_VALUE), ('%d %s'):format(valueIfDelimbed, currencySymbol))
    end

    -- If the player is looking at a piece of wood which was already cut (i.e. not a full tree)
    if getIsSplitShapeSplit(treeOrPieceOfWood) and getRigidBodyType(treeOrPieceOfWood) == RigidBodyType.DYNAMIC then

        -- If the player is sitting in a wood harvester, and the remaining wood is longer than the cutting length, estimate the value of the piece which will be cut
        local spec = g_currentMission.currentWoodHarvesterSpec
        if spec ~= nil and spec.currentCutLength < sizeX and spec.attachedSplitShape ~= nil then
            -- Get the world coordinates of the current start of the tree
            -- TODO: This doesn't work while the tree is being delimbed by the harvester, only before and afterwards
            local startOffset, cutOffset
            if spec.automaticCuttingIsDirty then
                -- the tree has already been moved to the cut position -> adjust the tree start
                startOffset = -1 * spec.currentCutLength
                cutOffset = 0
            else
                startOffset = 0
                cutOffset = spec.currentCutLength
            end
            -- Get the world coordinates of the start of the tree and the cut position. Note that the tree's Y axis corresponds to the harvester head's X axis
            -- so we supply the Y offset to the X axis here
            -- We add 0.3 to the start offset since there's a small gap between the cut position and the start of the remaining tree
            local startX, startY, startZ = localToWorld(spec.cutNode, startOffset + 0.3,0,0)
            local cutX, cutY, cutZ = localToWorld(spec.cutNode, cutOffset,0,0)

            -- Get a unit vector from the (virtual) tree start along the X, Y and Z axis
            local unitX_X,unitX_Y,unitX_Z = localDirectionToWorld(spec.cutNode, 1,0,0)
            local unitY_X,unitY_Y,unitY_Z = localDirectionToWorld(spec.cutNode, 0,1,0)
            local unitZ_X,unitZ_Y,unitZ_Z = localDirectionToWorld(spec.cutNode, 0,0,1)

            -- DEBUG: Draw the start and next cut positions, for visual confirmation
            DebugUtil.drawDebugGizmoAtWorldPos(startX,startY,startZ, unitZ_X, unitZ_Y, unitZ_Z, unitY_X, unitY_Y, unitY_Z, "Start Pos", false)
            DebugUtil.drawDebugGizmoAtWorldPos(cutX,cutY,cutZ, unitZ_X, unitZ_Y, unitZ_Z, unitY_X, unitY_Y, unitY_Z, "Next Cut", false)

            -- DEBUG: Get vectors which point to the center of the tree at the start and cut locations, just for drawing debugging rectangles there 
            local treeStartX,treeStartY,treeStartZ = localToWorld(treeOrPieceOfWood, 0, startOffset + spec.attachedSplitShapeTargetY, 0)
            local treeCutX,treeCutY,treeCutZ = localToWorld(treeOrPieceOfWood, 0, cutOffset + spec.attachedSplitShapeTargetY, 0)
            local treeUnitX_X,treeUnitX_Y,treeUnitX_Z = localDirectionToWorld(treeOrPieceOfWood, 1,0,0)
            local treeUnitZ_X,treeUnitZ_Y,treeUnitZ_Z = localDirectionToWorld(treeOrPieceOfWood, 0,0,1)

            -- Find the tree at the start and cut position just to retrieve its extents
            local startDiameter = nil
            local cutDiameter = nil
            local startRadius = nil
            local cutRadius = nil
            local shapeStart, minYStart, maxYStart, minZStart, maxZStart = findSplitShape(startX,startY,startZ, unitX_X,unitX_Y,unitX_Z, unitY_X,unitY_Y,unitY_Z, spec.cutSizeY, spec.cutSizeZ)
            if shapeStart == spec.attachedSplitShape then
                startDiameter = math.floor((maxYStart-minYStart + maxZStart-minZStart)*0.5*100 + 0.5) / 100.0
                startRadius = startDiameter / 2.0
                playerHudUpdater.objectBox:addLine("Start radius", ('%.3f'):format(startRadius))

                -- Draw a bounding rectangle for the start circle (didn't find out how to draw a circle which moves along with the object)
                DebugUtil.drawDebugAreaRectangle(
                    treeStartX - treeUnitX_X * startRadius - treeUnitZ_X * startRadius,
                    treeStartY - treeUnitX_Y * startRadius - treeUnitZ_Y * startRadius,
                    treeStartZ - treeUnitX_Z * startRadius - treeUnitZ_Z * startRadius,
                    treeStartX - treeUnitX_X * startRadius + treeUnitZ_X * startRadius,
                    treeStartY - treeUnitX_Y * startRadius + treeUnitZ_Y * startRadius,
                    treeStartZ - treeUnitX_Z * startRadius + treeUnitZ_Z * startRadius,
                    treeStartX + treeUnitX_X * startRadius - treeUnitZ_X * startRadius,
                    treeStartY + treeUnitX_Y * startRadius - treeUnitZ_Y * startRadius,
                    treeStartZ + treeUnitX_Z * startRadius - treeUnitZ_Z * startRadius,
                    false, -- don't align to ground
                    1, 0, 0
                )
            end
            local shapeCut, minYCut, maxYCut, minZCut, maxZCut = findSplitShape(cutX,cutY,cutZ, unitX_X,unitX_Y,unitX_Z, unitY_X,unitY_Y,unitY_Z, spec.cutSizeY, spec.cutSizeZ)
            if shapeCut == spec.attachedSplitShape then
                cutDiameter = math.floor((maxYCut-minYCut + maxZCut-minZCut)*0.5*100 + 0.5) / 100.0
                cutRadius = cutDiameter / 2.0
                playerHudUpdater.objectBox:addLine("Cut radius", ('%.3f'):format(cutRadius))

                -- Draw a bounding rectangle for the start circle (didn't find out how to draw a circle which moves along with the object)
                DebugUtil.drawDebugAreaRectangle(
                    treeCutX - treeUnitX_X * cutRadius - treeUnitZ_X * cutRadius,
                    treeCutY - treeUnitX_Y * cutRadius - treeUnitZ_Y * cutRadius,
                    treeCutZ - treeUnitX_Z * cutRadius - treeUnitZ_Z * cutRadius,
                    treeCutX - treeUnitX_X * cutRadius + treeUnitZ_X * cutRadius,
                    treeCutY - treeUnitX_Y * cutRadius + treeUnitZ_Y * cutRadius,
                    treeCutZ - treeUnitX_Z * cutRadius + treeUnitZ_Z * cutRadius,
                    treeCutX + treeUnitX_X * cutRadius - treeUnitZ_X * cutRadius,
                    treeCutY + treeUnitX_Y * cutRadius - treeUnitZ_Y * cutRadius,
                    treeCutZ + treeUnitX_Z * cutRadius - treeUnitZ_Z * cutRadius,
                    false, -- don't align to ground
                    1, 0, 0
                )
            end

            if startDiameter ~= nil and cutDiameter ~= nil then

                DebugUtil.drawDebugLine(
                    treeStartX - treeUnitX_X * startRadius, treeStartY - treeUnitX_Y * startRadius, treeStartZ - treeUnitX_Z * startRadius,
                    treeCutX - treeUnitX_X * cutRadius, treeCutY - treeUnitX_Y * cutRadius, treeCutZ - treeUnitX_Z * cutRadius,
                    1, 0, 0, nil, false)
                DebugUtil.drawDebugLine(
                    treeStartX + treeUnitX_X * startRadius, treeStartY + treeUnitX_Y * startRadius, treeStartZ + treeUnitX_Z * startRadius,
                    treeCutX + treeUnitX_X * cutRadius, treeCutY + treeUnitX_Y * cutRadius, treeCutZ + treeUnitX_Z * cutRadius,
                    1, 0, 0, nil, false)
                DebugUtil.drawDebugLine(
                    treeStartX - treeUnitZ_X * startRadius, treeStartY - treeUnitZ_Y * startRadius, treeStartZ - treeUnitZ_Z * startRadius,
                    treeCutX - treeUnitZ_X * cutRadius, treeCutY - treeUnitZ_Y * cutRadius, treeCutZ - treeUnitZ_Z * cutRadius,
                    1, 0, 0, nil, false)
                DebugUtil.drawDebugLine(
                    treeStartX + treeUnitZ_X * startRadius, treeStartY + treeUnitZ_Y * startRadius, treeStartZ + treeUnitZ_Z * startRadius,
                    treeCutX + treeUnitZ_X * cutRadius, treeCutY + treeUnitZ_Y * cutRadius, treeCutZ + treeUnitZ_Z * cutRadius,
                    1, 0, 0, nil, false)


                -- Estimate the volume of the wood piece which will be cut
                local averageRadius = (startDiameter + cutDiameter) / 4.0 -- divide by 2 for mean value and by 2 again to convert to radius
                playerHudUpdater.objectBox:addLine("Average radius", ('%.3f'):format(averageRadius))
                local averageArea = math.pi * averageRadius * averageRadius
                playerHudUpdater.objectBox:addLine("Average area", ('%.3f'):format(averageArea))
                local estimatedVolume = averageArea * spec.currentCutLength
                playerHudUpdater.objectBox:addLine("Estimated volume", ('%.3f'):format(estimatedVolume))
                -- Adjust the number of convexes to the same percentage as the volume, but round the value since it needs to be an integer
                local estimatedNumberOfConvexes = math.floor((numConvexes * estimatedVolume / volume) + 0.5)
                -- Calculate the price for the same piece of wood, but using the cut length and the estimated values. Also delimbed price since the harvester will do that
                local estimatedLiters, estimatedValuePerLiter = TreeValueInfo.dummyWoodTrigger:calculateWoodBaseValueForData(estimatedVolume, splitType, spec.currentCutLength, maxYStart-minYStart, maxZStart-minZStart, estimatedNumberOfConvexes, 0)
                local estimatedValue = estimatedLiters * estimatedValuePerLiter
                playerHudUpdater.objectBox:addLine("Estimated liters", ('%d'):format(estimatedLiters))
                playerHudUpdater.objectBox:addLine("Estimated value per liter", ('%.3f'):format(estimatedValuePerLiter))
                playerHudUpdater.objectBox:addLine("Estimated piece value", ('%d %s'):format(estimatedValue, currencySymbol))
            end
        end

        -- Calculate the best cut position: Each piece needs to be between 6 and 11 meters (value decreases when shorter or longer)
        -- Only recommend a cut if the piece of wood is longer than 12 meters (otherwise one piece would be below 6m, so worth less)
        if sizeX > 12 then
            local recommendedMinimumCutLength = TreeValueInfo.PROFITABLE_LENGTH_MIN
            local recommendedMaximumCutLength = math.min(TreeValueInfo.PROFITABLE_LENGTH_MAX, sizeX - recommendedMinimumCutLength)
            playerHudUpdater.objectBox:addLine(g_i18n:getText(TreeValueInfo.I18N_IDS.CUT_RECOMMENDATION), ('%.1fm-%.1fm'):format(recommendedMinimumCutLength, recommendedMaximumCutLength))
        end

        -- Calculate the maximum price the tree could fetch if processed into wood chips
        local litersIfChipped = numberOfLiters * splitType.woodChipsPerLiter
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

-- Now define a function which will display the same info box while in a wood harvester, with a tree being ready to cut or already grabbed
-- The function we override is this one: https://gdn.giants-software.com/documentation_scripting_fs22.php?version=script&category=48&class=585#onUpdate8967

---Shows the player hud info box while in a harvester with a tree within the harvester head
---@param currentVehicle table @The wood harvester the player is sitting in (maybe)
---@param superFunc function @The base game function WoodHarvester:onUpdate
---@param deltaTime number @The time which has passed since the previous call
---@param isActiveForInput boolean @Not sure
---@param isActiveForInputIgnoreSelection boolean @True if the wood harvester is active, no matter if selected or not
---@param isSelected boolean @True if the wood harvester is the currently selected implement
function TreeValueInfo.onWoodHarvesterUpdate(currentVehicle, superFunc, deltaTime, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

    -- Execute the base game behavior in any case
    superFunc(currentVehicle, deltaTime, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

    -- Retrieve the current player instance
    local player = g_currentMission.player
    if player ~= nil and isActiveForInputIgnoreSelection then
        -- Retrieve the wood harvester specialization of the current vehicle
        local spec = currentVehicle.spec_woodHarvester
        if spec ~= nil then
            -- Store the spec globally so we can access its current settings
            g_currentMission.currentWoodHarvesterSpec = spec
            local treeOrWoodNode = nil
            if spec.attachedSplitShape ~= nil then
                -- A tree has been cut and is attached to the harvester head
                treeOrWoodNode = spec.attachedSplitShape
            elseif spec.curSplitShape ~= nil then
                -- A tree which has not been cut down yet is within the harvester head and might be cut any moment
                treeOrWoodNode = spec.curSplitShape
            end

            -- Pretend the player is looking at the tree and let the base game implementation for that do its thing
            if player.hudUpdater ~= nil then
                -- let the info box know what we're pretending to look at
                player.hudUpdater:setCurrentRaycastTarget(treeOrWoodNode)
                if treeOrWoodNode ~= nil then
                    -- make the next call of the draw() method draw the info box
                    player.hudUpdater:showSplitShapeInfo(treeOrWoodNode)
                end
            end
        end
    else
        -- Reset the spec as soon as the wood harvester is no longer the active vehicle
        g_currentMission.currentWoodHarvesterSpec = nil
    end
end

-- Call our function on each update tick of the harvester
WoodHarvester.onUpdate = Utils.overwrittenFunction(WoodHarvester.onUpdate, TreeValueInfo.onWoodHarvesterUpdate)

-- At this point, the info box is prepared to draw information while the wood harvester has a tree in its harvester head
-- However, nobody would call the draw implementation, since we're using Player:hudUpdater, but that class won't render anything when we're in a vehicle
-- Therefore, we need to override the draw function of the wood harvester and draw the player HUD info box ourselves

---Draws the info box whenever necessary
---@param woodHarvester table @The wood harvester the player is sitting in
---@param superFunc function @The base game implementation of WoodHarvester:onDraw
---@param isActiveForInput boolean @Not sure
---@param isActiveForInputIgnoreSelection boolean @True if the wood harvester is active, no matter if selected or not
---@param isSelected boolean @True if the wood harvester is the currently selected implement
function TreeValueInfo.onWoodHarvesterDraw(woodHarvester, superFunc, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

    -- Call the base game implementation, as always
    superFunc(woodHarvester, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

    -- Draw only if the player HUD still exists and the player is sitting in the wood harvester
    local player = g_currentMission.player
    if player ~= nil and player.hudUpdater ~= nil and isActiveForInputIgnoreSelection then

        -- Retrieve the object box from the player HUD (that's what gets drawn when you look at a tree or any other object)
        local objectBox = player.hudUpdater.objectBox
        if objectBox ~= nil and objectBox:canDraw() then

            -- While sitting in a vehicle, the speed dial is in the place where the info box would normally be
            -- Therefore we retrieve the speed dial's position and draw the object box next to it
            local baseX, baseY = g_currentMission.hud.speedMeter:getBasePosition()
            objectBox:draw(baseX, baseY)
        end
    end
end

-- Register our draw override so it gets called when necessary
WoodHarvester.onDraw = Utils.overwrittenFunction(WoodHarvester.onDraw, TreeValueInfo.onWoodHarvesterDraw)