-- Define a class for this file
WoodHarvesterInjection = {}

-- Define a function which will display the same info box while in a wood harvester, with a tree being ready to cut or already grabbed
-- The function we override is this one: https://gdn.giants-software.com/documentation_scripting_fs22.php?version=script&category=48&class=585#onUpdate8967

---Shows the player hud info box while in a harvester with a tree within the harvester head
---@param currentVehicle table @The wood harvester the player is sitting in (maybe)
---@param superFunc function @The base game function WoodHarvester:onUpdate
---@param deltaTime number @The time which has passed since the previous call
---@param isActiveForInput boolean @Not sure
---@param isActiveForInputIgnoreSelection boolean @True if the wood harvester is active, no matter if selected or not
---@param isSelected boolean @True if the wood harvester is the currently selected implement
function WoodHarvesterInjection.onWoodHarvesterUpdate(currentVehicle, superFunc, deltaTime, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

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

-- At this point, the info box is prepared to draw information while the wood harvester has a tree in its harvester head
-- However, nobody would call the draw implementation, since we're using Player:hudUpdater, but that class won't render anything when we're in a vehicle
-- Therefore, we need to override the draw function of the wood harvester and draw the player HUD info box ourselves

---Draws the info box whenever necessary
---@param woodHarvester table @The wood harvester the player is sitting in
---@param superFunc function @The base game implementation of WoodHarvester:onDraw
---@param isActiveForInput boolean @Not sure
---@param isActiveForInputIgnoreSelection boolean @True if the wood harvester is active, no matter if selected or not
---@param isSelected boolean @True if the wood harvester is the currently selected implement
function WoodHarvesterInjection.onWoodHarvesterDraw(woodHarvester, superFunc, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

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
            objectBox:draw(baseX - 0.01, baseY)
        end
    end
end


-- Mods like Wood Harvester Controls overwrite onUpdate without calling the superFunc. We therefore delay the registration of the override as late as possible
-- in order to decrease the chance for a mod conflict
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(mission, node)
    -- Call our function on each update tick of the harvester
    WoodHarvester.onUpdate = Utils.overwrittenFunction(WoodHarvester.onUpdate, WoodHarvesterInjection.onWoodHarvesterUpdate)
    -- Register our draw override so it gets called when necessary
    WoodHarvester.onDraw = Utils.overwrittenFunction(WoodHarvester.onDraw, WoodHarvesterInjection.onWoodHarvesterDraw)
end)