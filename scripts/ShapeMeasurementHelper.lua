ShapeMeasurementHelper = {}
local ShapeMeasurementHelper_mt = Class(ShapeMeasurementHelper)

function ShapeMeasurementHelper.new()
    local self = setmetatable({}, ShapeMeasurementHelper_mt)
    self.woodProbeNode = createTransformGroup("treeValueInfo_woodProbeNode")
    self.debugNode = createTransformGroup("treeValueInfo_debugNode")
    link(getRootNode(), self.debugNode)


    self.debugRadiusDetection = false
    self.debugRadiusResults = true
    self.debugShapeLength = true
    self.debugVolumeCalculations = true
    return self
end

function ShapeMeasurementHelper:afterChainsawPostLoad(chainsaw)
    print("afterChainsawPostLoad")
    link(chainsaw.chainsawSplitShapeFocus, self.woodProbeNode) -- Use the point the player is looking at as a reference system
end

function ShapeMeasurementHelper:beforeChainsawDelete(chainswa)
    unlink(self.woodProbeNode)
    print("beforeChainsawDelete")
end

---Gets the radius of the tree at the given location
---@param shapeId any @The tree shape which was already found
---@param worldCoordsNearShape table @World coordinates close to or within the tree
---@param shapeUnitVectors table @Unit vectors for X/Y/Z dimensions, where the X vector points along the longest dimension of the tree
---@return any @The ID of the tree shape or nil if it wasn't found at the given location
---@return number @The radius at the given location
---@return table @The coordinates a the given location, centered on the tree shape in Y/Z direction
function ShapeMeasurementHelper:getRadiusAtLocation(shapeId, worldCoordsNearShape, shapeUnitVectors)

    -- Define a reasonably large enough rectangle to find the tree
    local rectangleSize = 2.0
    local halfRectangleSize = rectangleSize / 2.0

    -- Move the coordinates half a height in Y and Z direction so that the resulting rectangle will have the original y/z in its center
    local x = worldCoordsNearShape.x - shapeUnitVectors.yx*halfRectangleSize - shapeUnitVectors.zx*halfRectangleSize
    local y = worldCoordsNearShape.y - shapeUnitVectors.yy*halfRectangleSize - shapeUnitVectors.zy*halfRectangleSize
    local z = worldCoordsNearShape.z - shapeUnitVectors.yz*halfRectangleSize - shapeUnitVectors.zz*halfRectangleSize

    if self.debugRadiusDetection then
        DebugUtil.drawDebugAreaRectangle(
            x,y,z,
            x + shapeUnitVectors.yx*rectangleSize,
            y + shapeUnitVectors.yy*rectangleSize,
            z + shapeUnitVectors.yz*rectangleSize,
            x + shapeUnitVectors.zx*rectangleSize,
            y + shapeUnitVectors.zy*rectangleSize,
            z + shapeUnitVectors.zz*rectangleSize,
            false,
            .7,0,.7
        )
        DebugUtil.drawDebugGizmoAtWorldPos(
            x,y,z,
            shapeUnitVectors.yx, shapeUnitVectors.yy, shapeUnitVectors.yz,
            shapeUnitVectors.zx, shapeUnitVectors.zy, shapeUnitVectors.zz,
            "search",
            false)
    end

    -- Find the split shape at the location we already found it at, but this time with a perpendicular cut
    local minY, maxY, minZ, maxZ = testSplitShape(
        shapeId,
        x,y,z,
        shapeUnitVectors.xx,
        shapeUnitVectors.xy,
        shapeUnitVectors.xz,
        shapeUnitVectors.yx,
        shapeUnitVectors.yy,
        shapeUnitVectors.yz,
        rectangleSize,
        rectangleSize)
    if minY ~= nil then
        local radius = ((maxY-minY)+(maxZ-minZ)) / 4.0 -- /2 for average diameter and another /2 to get the radius

        -- Move the corner of the search rectangle used above to the center of the found location. min/max Y/Z are relative to that location
        local yCenter = (minY + maxY) / 2.0
        local zCenter = (minZ + maxZ) / 2.0
        local worldCoordsAtShape = {}
        worldCoordsAtShape.x = x + yCenter * shapeUnitVectors.yx + zCenter * shapeUnitVectors.zx
        worldCoordsAtShape.y = y + yCenter * shapeUnitVectors.yy + zCenter * shapeUnitVectors.zy
        worldCoordsAtShape.z = z + yCenter * shapeUnitVectors.yz + zCenter * shapeUnitVectors.zz

        if self.debugRadiusDetection then
            DebugUtil.drawDebugGizmoAtWorldPos(
                worldCoordsAtShape.x, worldCoordsAtShape.y, worldCoordsAtShape.z,
                shapeUnitVectors.yx, shapeUnitVectors.yy, shapeUnitVectors.yz,
                shapeUnitVectors.zx, shapeUnitVectors.zy, shapeUnitVectors.zz,
                "match",
                false)
        end

        -- Move the world coordinates by the specified Y and Z dimensions
        return shapeId, radius, worldCoordsAtShape
    else
        return nil, 0, {}
    end
end

---Retrieves information about a wood shape at the focus point of the user
---@param chainsaw table @The base game chainsaw object
---@return any @The ID of the tree shape, or nil if it wasn't found
---@return table @The world X/Y/Z coordinate of the center of the "ring" the player can see
---@return number @The radius of the tree shape at the given coordinates
---@return table @Unit vectors for the tree in X/Y/Z direction, where the tree is aligned around the X axis
function ShapeMeasurementHelper:getWoodShapeDimensionsAtFocusPoint(chainsaw)

    -- Retrieve the following information from the focus point of the player:
    -- The x,y,z coordinates of the focus point
    -- A unit vector (length = 1) along the X axis of the focus point
    -- A unit vector along the Y axis of the focus point
    local x,y,z, nx,ny,nz, yx,yy,yz = chainsaw:getCutShapeInformation()

    -- Find the wood shape at the given coordinates
    local largeEnoughRectangleSize = 2.0
    local shapeId, minY, maxY, minZ, maxZ = findSplitShape(x,y,z, nx,ny,nz, yx,yy,yz, largeEnoughRectangleSize, largeEnoughRectangleSize)

    local treeCutXWorld, treeCutYWorld, treeCutZWorld, treeCoords, radius, treeUnitVectors
    if shapeId ~= nil and shapeId ~= 0 then

        -- Get the radius of the wood shape at the same position, but while ignoring the chainsaw cutting angle
        -- instead, simulate a perfect perpendicular cut to get the actual radius of the tree
        -- in order to properly find the shape again, we need to define a rectangle around the whole shape.

        -- Translate our own probing node to the center of the retrieved tree shape rectangle (relative to its parent node, which is the focus point of the user)
        setTranslation(self.woodProbeNode, 0, (minY+maxY)/2.0, (minZ+maxZ)/2.0)

        -- Get the world coordinates for that point
        treeCutXWorld, treeCutYWorld, treeCutZWorld = localToWorld(self.woodProbeNode, 0,0,0)
        treeCoords = {
            x = treeCutXWorld,
            y = treeCutYWorld,
            z = treeCutZWorld
        }

        -- Retrieve unit vectors for the local tree coordinate system, but rotate it so that the tree's Y becomes the lookup X axis,
        -- otherwise `testSplitShape` will fail to find anything later on.
        -- The reason for this is that `testSplitShape` needs the split shape to intersect the Y/Z plane in X direction, while trees and pieces of wood
        -- have their longest side along their Y axis
        nx,ny,nz = localDirectionToWorld(shapeId, 0,1,0) -- unit vector along the local X axis of the shape, but in world coordinates
        yx,yy,yz = localDirectionToWorld(shapeId, 1,0,0) -- unit vector along the local Y axis of the shape, but in world coordinates
        local zx,zy,zz = localDirectionToWorld(shapeId, 0,0,-1) -- unit vector along the local Y axis of the shape, but in world coordinates

        -- Put unit vectors in a table so other functions can use it afterwards
        treeUnitVectors = {
            xx = nx,
            xy = ny,
            xz = nz,
            yx = yx,
            yy = yy,
            yz = yz,
            zx = zx,
            zy = zy,
            zz = zz
        }

        shapeId, radius, _ = self:getRadiusAtLocation(shapeId, treeCoords, treeUnitVectors)
    end

    return shapeId, treeCoords, radius, treeUnitVectors
end

---Calculates the volume of a part of the tree
---@param shapeId any @The ID of the tree shape
---@param treeCoords table @The x/y/z coordinates of the planned cutting position
---@param unitVectors table @Unit vectors along the x/y/z axes of the tree, where x goes along the tree
---@param length integer @The distance between the end of the tree and the cutting position
---@param directionFactor integer @+1 if going from the cut position towards the (former) top of the tree or -1 to go below
---@return integer @The volume of the part (in milliliters, just like getVolume())
---@return integer @If >= 0, the part at which processing could no longer find the tree
---@return integer @The number of parts which were analyzed
function ShapeMeasurementHelper:calculatePartVolume(shapeId, treeCoords, unitVectors, length, directionFactor)

    if shapeId == nil then
        return 0, 0, 0
    end
    local stepWidth = .1 * directionFactor
    -- Reduce the maximum length to avoid detection issues towards the end
    local adjustedLength = length - 0.03
    local numberOfParts = math.abs(math.ceil(adjustedLength / stepWidth))
    local previousRadius = 0
    local totalVolume = 0
    local failedAt = -1
    local previousCoords = {}
    for i = 0,numberOfParts do -- intentionally not numberOfParts-1 because 5 parts have 6 "borders"
        local xOffset = i * stepWidth
        local pieceLength = stepWidth
        if i == numberOfParts then
            -- Last part: make sure it does not exceed the tree dimensions
            pieceLength = adjustedLength - (i-1) * stepWidth
            xOffset = xOffset - stepWidth + directionFactor * pieceLength
        end

        -- Get a point along the X axis from the tree, based on where the chainsaw is aiming
        local x = treeCoords.x + unitVectors.xx * xOffset
        local y = treeCoords.y + unitVectors.xy * xOffset
        local z = treeCoords.z + unitVectors.xz * xOffset

        -- Retrieve the radius
        local foundShapeId, radius, newTreeCoords = self:getRadiusAtLocation(shapeId, { x = x, y = y, z = z }, unitVectors)

        -- Stop processing if the shape was no longer found (too crooked, or shorter than calculated)
        if foundShapeId == nil or foundShapeId == 0 then
            failedAt = i
            break
        end

        --treeCoords = newTreeCoords
        x,y,z = newTreeCoords.x, newTreeCoords.y, newTreeCoords.z

        -- starting from the second radius:
        if i > 0 then
            -- calculate the volume to the previous radius
            local averageRadius = (previousRadius + radius) / 2.0

            -- Calculate the distance between the two 
            local calculatedLength = MathUtil.vector3Length(x - previousCoords.x, y - previousCoords.y, z - previousCoords.z)

            -- approximate volume of a cone stump: average circle area * length. circle area = pi * r²
            totalVolume = totalVolume + math.pi * averageRadius * averageRadius * calculatedLength

            if self.debugRadiusResults then
                local color
                if directionFactor > 0 then
                    color =  { 1,0,0 }
                else
                    color =  { 0,0,1 }
                end
                DebugUtil.drawDebugAreaRectangle(
                    x - unitVectors.yx * radius - unitVectors.zx * radius,
                    y - unitVectors.yy * radius - unitVectors.zy * radius,
                    z - unitVectors.yz * radius - unitVectors.zz * radius,
                    x - unitVectors.yx * radius + unitVectors.zx * radius,
                    y - unitVectors.yy * radius + unitVectors.zy * radius,
                    z - unitVectors.yz * radius + unitVectors.zz * radius,
                    x + unitVectors.yx * radius - unitVectors.zx * radius,
                    y + unitVectors.yy * radius - unitVectors.zy * radius,
                    z + unitVectors.yz * radius - unitVectors.zz * radius,
                    false,
                    color[1], color[2], color[3])
                DebugUtil.drawDebugLine(
                    x - unitVectors.yx * radius - unitVectors.zx * radius,
                    y - unitVectors.yy * radius - unitVectors.zy * radius,
                    z - unitVectors.yz * radius - unitVectors.zz * radius,
                    previousCoords.x - unitVectors.yx * previousRadius - unitVectors.zx * previousRadius,
                    previousCoords.y - unitVectors.yy * previousRadius - unitVectors.zy * previousRadius,
                    previousCoords.z - unitVectors.yz * previousRadius - unitVectors.zz * previousRadius,
                    color[1], color[2], color[3],
                    nil,
                    false)
                DebugUtil.drawDebugLine(
                    x - unitVectors.yx * radius + unitVectors.zx * radius,
                    y - unitVectors.yy * radius + unitVectors.zy * radius,
                    z - unitVectors.yz * radius + unitVectors.zz * radius,
                    previousCoords.x - unitVectors.yx * previousRadius + unitVectors.zx * previousRadius,
                    previousCoords.y - unitVectors.yy * previousRadius + unitVectors.zy * previousRadius,
                    previousCoords.z - unitVectors.yz * previousRadius + unitVectors.zz * previousRadius,
                    color[1], color[2], color[3],
                    nil,
                    false)
                DebugUtil.drawDebugLine(
                    x + unitVectors.yx * radius - unitVectors.zx * radius,
                    y + unitVectors.yy * radius - unitVectors.zy * radius,
                    z + unitVectors.yz * radius - unitVectors.zz * radius,
                    previousCoords.x + unitVectors.yx * previousRadius - unitVectors.zx * previousRadius,
                    previousCoords.y + unitVectors.yy * previousRadius - unitVectors.zy * previousRadius,
                    previousCoords.z + unitVectors.yz * previousRadius - unitVectors.zz * previousRadius,
                    color[1], color[2], color[3],
                    nil,
                    false)
                DebugUtil.drawDebugLine(
                    x + unitVectors.yx * radius + unitVectors.zx * radius,
                    y + unitVectors.yy * radius + unitVectors.zy * radius,
                    z + unitVectors.yz * radius + unitVectors.zz * radius,
                    previousCoords.x + unitVectors.yx * previousRadius + unitVectors.zx * previousRadius,
                    previousCoords.y + unitVectors.yy * previousRadius + unitVectors.zy * previousRadius,
                    previousCoords.z + unitVectors.yz * previousRadius + unitVectors.zz * previousRadius,
                    color[1], color[2], color[3],
                    nil,
                    false)
            end

        -- else: just store the radius for the first piece
        end
        -- store the radius for the next calculation
        previousRadius = radius
        previousCoords = { x = x, y = y, z = z }
    end

    return totalVolume, failedAt, numberOfParts
end

function ShapeMeasurementHelper:afterChainsawUpdate(chainsaw)

    -- If the ring around the tree is currently visible with an equipped chain saw
    if chainsaw.ringSelector ~= nil and getVisibility(chainsaw.ringSelector) then

        -- Find the wood shape we're looking at
        local shapeId, treeCoords, _, unitVectors = self:getWoodShapeDimensionsAtFocusPoint(chainsaw)

        if shapeId ~= nil then

            -- Retrieve data on the whole piece of wood
            --local _, _, _, numConvexes, numAttachments = getSplitShapeStats(shapeId)

            -- Retrieve the length above and below the cut ("above" and "below" from a tree perspective)
            local lenBelow, lenAbove = getSplitShapePlaneExtents(shapeId, treeCoords.x, treeCoords.y, treeCoords.z, unitVectors.xx, unitVectors.xy, unitVectors.xz)
            if self.debugShapeLength then
                -- Note: Need to press F4 with developer mode active to be able to see these
                local shapeCutLocalCoords = { worldToLocal(shapeId, treeCoords.x, treeCoords.y, treeCoords.z) }
                local shapeTopWorldCoords = { localToWorld(shapeId, shapeCutLocalCoords[1], shapeCutLocalCoords[2] + lenAbove, shapeCutLocalCoords[3]) }
                local shapeBottomWorldCoords = { localToWorld(shapeId, shapeCutLocalCoords[1], shapeCutLocalCoords[2] - lenBelow, shapeCutLocalCoords[3]) }

                DebugUtil.drawDebugLine(treeCoords.x, treeCoords.y, treeCoords.z, shapeTopWorldCoords[1], shapeTopWorldCoords[2], shapeTopWorldCoords[3], 1,0,0, 0.1, false)
                DebugUtil.drawDebugLine(treeCoords.x, treeCoords.y, treeCoords.z, shapeBottomWorldCoords[1], shapeBottomWorldCoords[2], shapeBottomWorldCoords[3], 0,0,1, 0.1, false)
            end

            -- Calculate the volume for the pices
            local volumeBelow, failedAtBelow, numPiecesBelow = self:calculatePartVolume(shapeId, treeCoords, unitVectors, lenBelow, -1)
            local volumeAbove, failedAtAbove, numPiecesAbove = self:calculatePartVolume(shapeId, treeCoords, unitVectors, lenAbove, 1)

            if self.debugVolumeCalculations then
                local estimatedVolume = volumeBelow + volumeAbove
                local engineVolume = getVolume(shapeId)
                local volumeDeviation = (estimatedVolume / engineVolume - 1) * 100
                
                Utils.renderTextAtWorldPosition(treeCoords.x, treeCoords.y + 1.0, treeCoords.z, ("Volume (below): %d l"):format(volumeBelow * 1000), getCorrectTextSize(0.02, 0))
                Utils.renderTextAtWorldPosition(treeCoords.x, treeCoords.y + 0.9, treeCoords.z, ("Volume (above): %d l"):format(volumeAbove * 1000), getCorrectTextSize(0.02, 0))
                Utils.renderTextAtWorldPosition(treeCoords.x, treeCoords.y + 0.8, treeCoords.z, ("Volume (total est'd): %d l"):format(estimatedVolume * 1000), getCorrectTextSize(0.02, 0))
                Utils.renderTextAtWorldPosition(treeCoords.x, treeCoords.y + 0.7, treeCoords.z, ("Volume (engine): %d l"):format(engineVolume * 1000), getCorrectTextSize(0.02, 0))
                Utils.renderTextAtWorldPosition(treeCoords.x, treeCoords.y + 0.6, treeCoords.z, ("Volume (deviation)): %.2f %%"):format(volumeDeviation), getCorrectTextSize(0.02, 0))
                if failedAtBelow >= 0 then
                    Utils.renderTextAtWorldPosition(treeCoords.x, treeCoords.y + 0.5, treeCoords.z, ("Bottom calculation aborted at %d/%d"):format(failedAtBelow, numPiecesBelow), getCorrectTextSize(0.02, 0))
                end
                if failedAtAbove >= 0 then
                    Utils.renderTextAtWorldPosition(treeCoords.x, treeCoords.y + 0.4, treeCoords.z, ("Top calculation aborted at %d/%d"):format(failedAtAbove, numPiecesAbove), getCorrectTextSize(0.02, 0))
                end

            end
        end
    end

    if not chainsaw.wasAlreadyCutting and chainsaw.isCutting then
        -- The user has just started cutting
        chainsaw.wasAlreadyCutting = true

        local originalShape = chainsaw.curSplitShape
        if originalShape ~= nil then
        end

    elseif chainsaw.wasAlreadyCutting and not chainsaw.isCutting then
        -- The user has just stopped cutting
        chainsaw.wasAlreadyCutting = false
    end
end