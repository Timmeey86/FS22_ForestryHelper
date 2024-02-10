---@class CutPositionIndicator
---This class is responsible for displaying an indicator for the desired cut position
---Most of this code was created by taking a look at the LUADOC for the chainsaw class and see where it uses the ringSelector
CutPositionIndicator = {
    -- Constants for translations
    I18N_IDS = {
        CHANGE_LENGTH = 'tvi_change_length'
    }
}

local CutPositionIndicator_mt = Class(CutPositionIndicator)

---Creates a new cut position indicator (handler)
---@return table @The new object
function CutPositionIndicator.new()
    local self = setmetatable({}, CutPositionIndicator_mt)

    self.ring = nil
    self.loadRequestId = nil
    self.chainsawIsDeleted = false
    self.cycleActionEventId = nil
    self.cutIndicationWidth = 1
    self.chainsawIsSnapped = false


    self.debugPositionDetection = false
    self.debugIndicator = false
    return self
end

-- Create an object now so it can be referenced by method overrides
local cutPositionIndicator = CutPositionIndicator.new()

---Deletes our own ring before the chainsaw gets deleted
---@param chainsaw table @The chainsaw which will be deleted afterwards
function CutPositionIndicator:before_chainsawDelete(chainsaw)
    if chainsaw.isClient then
        if self.ring ~= nil then
            delete(self.ring)
            self.ring = nil
        end
        if self.loadRequestId ~= nil then
            g_i3DManager:releaseSharedI3DFile(self.loadRequestId)
            self.loadRequestId = nil
        end
        -- Our object doesn't get deleted, just the chainsaw
        self.chainsawIsDeleted = true
    end
end

---Hides our own ring before the chainsaw gets deactivated
---@param chainsaw table @The chainsaw
function CutPositionIndicator:before_chainsawDeactivate(chainsaw)
    if chainsaw.isClient then
        if self.ring ~= nil then
            setVisibility(self.ring, false)
        end
    end

    -- Allow cut indication width cycling
    g_inputBinding:setActionEventActive(self.cycleActionEventId, false)
end

---This gets called by the game engine once the I3D for the ring selector has finished loading. Note that this is not an override of a chainsaw function
---but a new one instead.
---@param node number @The ID of the 3D node which was created.
---@param failedReason table @A potential failure reason if the node couldn't be created.
---@param args table @Arguments (unknown)
function CutPositionIndicator:onOwnRingLoaded(node, failedReason, args)
    if node ~= 0 then
        if not self.chainsawIsDeleted then
            self.ring = getChildAt(node, 0)
            setVisibility(self.ring, false)
            -- Note: The position of our ring is based on the log, so we don't link it to the player's point of view.
            link(getRootNode(), self.ring)

            -- We use a fixed color for the ring so we can apply it as soon as it's loaded
            setShaderParameter(self.ring, "colorScale", 0.7, .0, 0.7, 1, false)
        end
        delete(node)

        -- Allow cut indication width cycling
        g_inputBinding:setActionEventActive(self.cycleActionEventId, true)
        self:updateHelpMenuText()
    end
end

---Trigger loading of a second ring after the chainsaw loaded its own ring selector
---@param chainsaw table @The chainsaw
---@param xmlFile table @The object which contains the chainsaw XML file's contents
function CutPositionIndicator:after_chainsawPostLoad(chainsaw, xmlFile)
    -- Load another ring selector in addition to the one used by the base game chainsaw
    local filename = xmlFile:getValue("handTool.chainsaw.ringSelector#file")
    if filename ~= nil then
        filename = Utils.getFilename(filename, chainsaw.baseDirectory)
        -- Base game "pins" the shared I3D in cache, but there's no point in doing that twice (it's a shared cache, after all), so we skip that step

        -- Load the file again
        self.loadRequestId = g_i3DManager:loadSharedI3DFileAsync(filename, false, false, self.onOwnRingLoaded, self, chainsaw.player)
    end
    self.chainsawIsDeleted = false
    self.chainsawIsSnapped = false

    -- TEMP
    chainsaw.defaultCutDuration = 1
end

---Rotates an object so its own X axis points along the given unit vector
---@param object number @The ID of the object to rotate
---@param xx number @The X dimension of the new direction vector. The vector must have a length of 1
---@param xy number @The y dimension of the new direction vector.
---@param xz number @The z dimension of the new direction vector.
function CutPositionIndicator.rotateObjectAroundYAxis(object, xx,xy,xz)
    -- Rotate the ring around its own Y axis to match the tree direction
    setRotation(object, 0,0,0)
    local xxInd,xyInd,xzInd = localDirectionToWorld(object, 1,0,0)
    local yRotation = MathUtil.getVectorAngleDifference(xxInd,xyInd,xzInd, xx,xy,xz)
    -- The rotation seems to be an absolute value, so we need to invert it in some cases
    if xz > 0 then
        yRotation = yRotation * -1
    end
    setRotation(object, 0, yRotation, 0)
end

---Show or hide our own ring whenever the visibliity of the chainsaw's ring selector changes
---@param chainsaw table @The chain saw
function CutPositionIndicator:after_chainsawUpdateRingSelector(chainsaw, shape)
    if self.ring ~= nil then
        -- Just tie the visibility of our ring to the one of the chainsaw's ring selector
        setVisibility(self.ring, getVisibility(chainsaw.ringSelector))

        if shape ~= nil and shape ~= 0 and getVisibility(self.ring) then
            -- Find the center of the cut location in world coordinates
            local chainsawX, chainsawY, chainsawZ = localToWorld(chainsaw.ringSelector, 0,0,0)
            -- Unit vectors along the local X axis of the log, same for Y and Z below
            -- There is a special case for trees, however, since they grow in world Y direction, so the X axis is not their main axis
            -- In order to make the following code less confusing, we rotate the tree's axis system so it grows along its X axis
            local xx,xy,xz = localDirectionToWorld(shape, 0,1,0)
            local yx,yy,yz = localDirectionToWorld(shape, 1,0,0)
            local zx,zy,zz = localDirectionToWorld(shape, 0,0,-1)

            -- Detect how far the beginning of the tree is away
            local lenBelow = getSplitShapePlaneExtents(shape, chainsawX, chainsawY, chainsawZ, xx,xy,xz)

            -- Determine how far the projected cut location must be from the chainsaw focus location
            local xDiff = self.cutIndicationWidth - lenBelow

            -- Shift the chainsaw location by the required X distance, along the local X axis of the tree
            local desiredLocation = {}
            desiredLocation.x, desiredLocation.y, desiredLocation.z = chainsawX + xDiff * xx, chainsawY + xDiff * xy, chainsawZ + xDiff * xz

            -- Find the tree at this location
            local searchSquareHalfSize = .6
            local searchSquareSize = searchSquareHalfSize * 2
            local searchSquareCorner = {
                x = desiredLocation.x - yx * searchSquareHalfSize - zx * searchSquareHalfSize,
                y = desiredLocation.y - yy * searchSquareHalfSize - zy * searchSquareHalfSize,
                z = desiredLocation.z - yz * searchSquareHalfSize - zz * searchSquareHalfSize
            }

            if self.debugPositionDetection then
                DebugUtil.drawDebugGizmoAtWorldPos(chainsawX,chainsawY,chainsawZ, yx,yy,yz, zx,zy,zz, "Cut", false)
                DebugUtil.drawDebugGizmoAtWorldPos(desiredLocation.x, desiredLocation.y, desiredLocation.z, yx,yy,yz, zx,zy,zz, "desired", false)
                DebugUtil.drawDebugGizmoAtWorldPos(searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z, yx,yy,yz, zx,zy,zz, "search", false)
                DebugUtil.drawDebugAreaRectangle(
                    searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z,
                    searchSquareCorner.x + yx * searchSquareSize,
                    searchSquareCorner.y + yy * searchSquareSize,
                    searchSquareCorner.z + yz * searchSquareSize,
                    searchSquareCorner.x + zx * searchSquareSize,
                    searchSquareCorner.y + zy * searchSquareSize,
                    searchSquareCorner.z + zz * searchSquareSize,
                    false, .7,0,.7
                )
            end

            -- Search in a square starting in the search square corner. We supply X and Y unit vectors, but the function will actually search in the Y/Z plane
            local minY, maxY, minZ, maxZ = testSplitShape(shape, searchSquareCorner.x, searchSquareCorner.y, searchSquareCorner.z, xx,xy,xz, yx,yy,yz, searchSquareSize, searchSquareSize)
            if minY ~= nil then
                -- Move the corner of the search square used above to the center of the found location. min/max Y/Z are relative to the search square corner
                local yCenter = (minY + maxY) / 2.0
                local zCenter = (minZ + maxZ) / 2.0
                local indicatorX = searchSquareCorner.x + yCenter * yx + zCenter * zx
                local indicatorY = searchSquareCorner.y + yCenter * yy + zCenter * zy
                local indicatorZ = searchSquareCorner.z + yCenter * yz + zCenter * zz
                setTranslation(self.ring, indicatorX, indicatorY, indicatorZ)

                -- Adjust the radius
                local diameter = math.max((maxY - minY), (maxZ - minZ)) * 1.4
                setScale(self.ring, 1, diameter, diameter)

                CutPositionIndicator.rotateObjectAroundYAxis(self.ring, xx,xy,xz)

                if self.debugIndicator then
                    local yx1,yy1,yz1 = localDirectionToWorld(self.ring, 0,1,0)
                    local zx1,zy1,zz1 = localDirectionToWorld(self.ring, 0,0,1)
                    DebugUtil.drawDebugGizmoAtWorldPos(indicatorX, indicatorY, indicatorZ, yx1,yy1,yz1, zx1,zy1,zz1, ('%.3f'):format(diameter), false)
                    DebugUtil.drawDebugGizmoAtWorldPos(indicatorX, indicatorY, indicatorZ, yx,yy,yz, zx,zy,zz, "", false)
                end
            else
                -- Failed finding the shape at that location. It is probably too short
                setVisibility(self.ring, false)
                setRotation(self.ring, 0,0,0)
            end
        end

        -- Snap the base game ring selector to our indicator if the player is close
        if getVisibility(self.ring) then
            -- Calculate the distance between the centers of the two rings
            local xInd,yInd,zInd = localToWorld(self.ring, 0,0,0)
            local xCut,yCut,zCut = localToWorld(chainsaw.ringSelector, 0,0,0)
            local xDiff,yDiff,zDiff = xInd-xCut, yInd-yCut, zInd-zCut
            local distance = math.sqrt(xDiff * xDiff + yDiff * yDiff + zDiff * zDiff)

            if distance < 0.2 then -- +/- 20cm
                -- Figure out the position of our own ring in the local coordinate system of the chainsaw's ring selector
                -- The chainsaw's ring selector's translation is relative to some other object, so we use the coordinate system of that object instead
                -- Not sure why that's the right thing, but Chainsaw:updateRingSelector does it, too, and it won't work without the getParent call
                local xCutLocal, yCutLocal, zCutLocal = worldToLocal(getParent(chainsaw.ringSelector), xInd, yInd, zInd)
                -- Translate the chainsaw's ring selector onto those coordinates
                setTranslation(chainsaw.ringSelector, xCutLocal, yCutLocal, zCutLocal)
                self.chainsawIsSnapped = true
            else
                self.chainsawIsSnapped = false
            end
        end
    end
end

---Registers the "Cycle Cut Indicator" event so it can be displayed in the help menu
function CutPositionIndicator:registerActionEvents()
    -- Register the action. Bool variables: Trigger on key release, trigger on key press, trigger always, unknown
    local _, actionEventId = g_inputBinding:registerActionEvent('CYCLE_CUT_INDICATOR', self, CutPositionIndicator.cycleCutIndicator, false, true, false, true)
    self.cycleActionEventId = actionEventId
    g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
    g_inputBinding:setActionEventActive(actionEventId, false)
    g_inputBinding:setActionEventText(actionEventId, "")
end

---Cycles the desired cut length
function CutPositionIndicator:cycleCutIndicator()
    self.cutIndicationWidth = 1 + self.cutIndicationWidth % 12 -- from 1 to 12
    self:updateHelpMenuText()
end

---Updates the text of "desired length" option in the help menu so it reflects the current cut indication width
function CutPositionIndicator:updateHelpMenuText()
    g_inputBinding:setActionEventText(self.cycleActionEventId, ('%s: %d %s'):format(g_i18n:getText(CutPositionIndicator.I18N_IDS.CHANGE_LENGTH), self.cutIndicationWidth, "m"))
end

function CutPositionIndicator:adaptCutIfNecessary(superFunc, shapeId, x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ, farmId)
    if self.chainsawIsSnapped then
        x,y,z = getWorldTranslation(self.ring)
        local halfCutSizeY = cutSizeY / 2.0
        local halfCutSizeZ = cutSizeZ / 2.0
        local zx,zy,zz = MathUtil.crossProduct(xx,xy,xz, yx,yy,yz)
        x = x - yx * halfCutSizeY - zx * halfCutSizeZ
        y = y - yy * halfCutSizeY - zy * halfCutSizeZ
        z = z - yz * halfCutSizeY - zz * halfCutSizeZ
    end

    superFunc(shapeId, x,y,z, xx,xy,xz, yx,yy,yz, cutSizeY, cutSizeZ, farmId)
end

-- Register all our functions as late as possible just in case other mods which are further behind in the alphabet replace methods 
-- rather than overriding them properly.
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
end)