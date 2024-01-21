ShapeMeasurementHelper = {}
local ShapeMeasurementHelper_mt = Class(ShapeMeasurementHelper)

function ShapeMeasurementHelper.new()
    local self = setmetatable({}, ShapeMeasurementHelper_mt)

    self.futureWoodPartData = nil

    self.debugRadiusDetection = false
    self.debugRadiusResults = false
    self.debugShapeLength = false
    self.debugVolumeCalculations = false
    return self
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
    local largeEnoughSquareSize = 2.0
    local shapeId, _, _, _, _ = findSplitShape(x,y,z, nx,ny,nz, yx,yy,yz, largeEnoughSquareSize, largeEnoughSquareSize)

    local treeCoords, radius, treeUnitVectors
    if shapeId ~= nil and shapeId ~= 0 then

        -- Get the radius of the wood shape at the same position, but while ignoring the chainsaw cutting angle
        -- instead, simulate a perfect perpendicular cut to get the actual radius of the tree
        -- in order to properly find the shape again, we need to define a square around the whole shape.

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

        -- Lazy approach: Just use the ring selector to find the tree center. This will also make sure everything is calculated from the center
        -- of the exact cut location
        treeCoords = {}
        treeCoords.x, treeCoords.y, treeCoords.z = localToWorld(chainsaw.ringSelector, 0,0,0)

        shapeId, radius, _, _, _, _, _ = self:getRadiusAtLocation(shapeId, treeCoords, treeUnitVectors)
    end

    return shapeId, treeCoords, radius, treeUnitVectors
end

---Gets the radius of the tree at the given location
---@param shapeId any @The tree shape which was already found
---@param worldCoordsNearShape table @World coordinates close to or within the tree
---@param shapeUnitVectors table @Unit vectors for X/Y/Z dimensions, where the X vector points along the longest dimension of the tree
---@return any @The ID of the tree shape or nil if it wasn't found at the given location
---@return number @The radius at the given location
---@return table @The coordinates a the given location, centered on the tree shape in Y/Z direction
---@return number @The minimum Y coordinate of the shape at that location, in world coordinates
---@return number @The maximum Y coordinate of the shape at that location, in world coordinates
---@return number @The minimum Z coordinate of the shape at that location, in world coordinates
---@return number @The maximum Z coordinate of the shape at that location, in world coordinates
function ShapeMeasurementHelper:getRadiusAtLocation(shapeId, worldCoordsNearShape, shapeUnitVectors)

    -- Define a reasonably large enough square to find the tree
    local squareSize = 2.0
    local halfSquareSize = squareSize / 2.0

    -- Move the coordinates half a height in Y and Z direction so that the resulting square will have the original y/z in its center
    local x = worldCoordsNearShape.x - shapeUnitVectors.yx*halfSquareSize - shapeUnitVectors.zx*halfSquareSize
    local y = worldCoordsNearShape.y - shapeUnitVectors.yy*halfSquareSize - shapeUnitVectors.zy*halfSquareSize
    local z = worldCoordsNearShape.z - shapeUnitVectors.yz*halfSquareSize - shapeUnitVectors.zz*halfSquareSize

    if self.debugRadiusDetection then
        DebugDrawUtils.drawShapeSearchSquare( { x=x, y=y, z=z }, shapeUnitVectors, squareSize, {0.7, 0, 1})
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
        squareSize,
        squareSize)
    if minY ~= nil then
        local radius = ((maxY-minY)+(maxZ-minZ)) / 4.0 -- /2 for average diameter and another /2 to get the radius

        -- Move the corner of the search square used above to the center of the found location. min/max Y/Z are relative to that location
        local yCenter = (minY + maxY) / 2.0
        local zCenter = (minZ + maxZ) / 2.0
        local worldCoordsAtShape = {}
        worldCoordsAtShape.x = x + yCenter * shapeUnitVectors.yx + zCenter * shapeUnitVectors.zx
        worldCoordsAtShape.y = y + yCenter * shapeUnitVectors.yy + zCenter * shapeUnitVectors.zy
        worldCoordsAtShape.z = z + yCenter * shapeUnitVectors.yz + zCenter * shapeUnitVectors.zz

        if self.debugRadiusDetection then
            DebugDrawUtils.drawDebugGizmo(worldCoordsAtShape, shapeUnitVectors, "match")
        end

        -- Calculate the minimum and maximum world Y and Z coordinates for further processing
        local minYWorld = y
        local maxYWorld = y + math.abs(maxY - minY)
        local minZWorld = z
        local maxZWorld = z + math.abs(maxZ - minZ)

        -- Move the world coordinates by the specified Y and Z dimensions
        return shapeId, radius, worldCoordsAtShape, minYWorld, maxYWorld, minZWorld, maxZWorld
    else
        return nil, 0, {}, 0, 0, 0, 0
    end
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
---@return integer @The total Y size of the part bounding box
---@return integer @The total Z size of the part bounding box
function ShapeMeasurementHelper:calculatePartData(shapeId, treeCoords, unitVectors, length, directionFactor)

    if shapeId == nil then
        return 0, 0, 0, 0, 0
    end
    local stepWidth = .1 * directionFactor
    -- Reduce the maximum length to avoid detection issues towards the end
    local adjustedLength = length - 0.03
    local numberOfParts = math.abs(math.ceil(adjustedLength / stepWidth))
    local previousRadius = 0
    local totalVolume = 0
    local failedAt = -1
    local previousCoords = {}
    local maxRadius = 0
    for i = 0,numberOfParts do -- intentionally not numberOfParts-1 because 5 parts have 6 "borders"
        local xOffset = i * stepWidth
        local pieceLength = stepWidth
        if i == numberOfParts then
            -- Last part: make sure it does not exceed the tree dimensions
            pieceLength = adjustedLength - (i-1) * stepWidth * directionFactor
            xOffset = xOffset - stepWidth + directionFactor * pieceLength
        end

        -- Get a point along the X axis from the tree, based on where the chainsaw is aiming
        local x = treeCoords.x + unitVectors.xx * xOffset
        local y = treeCoords.y + unitVectors.xy * xOffset
        local z = treeCoords.z + unitVectors.xz * xOffset

        -- Retrieve the radius
        local foundShapeId, radius, newTreeCoords, yMinWorld, yMaxWorld, zMinWorld, zMaxWorld = self:getRadiusAtLocation(shapeId, { x = x, y = y, z = z }, unitVectors)

        -- Stop processing if the shape was no longer found (too crooked, or shorter than calculated)
        if foundShapeId == nil or foundShapeId == 0 then
            failedAt = i
            break
        end
        maxRadius = math.max(maxRadius, radius)

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
                DebugDrawUtils.drawBoundingBox({ x=x, y=y, z=z }, previousCoords, unitVectors, radius * 2, previousRadius * 2, color)
            end

        -- else: just store the radius for the first piece
        end

        -- store the radius for the next calculation
        previousRadius = radius
        previousCoords = { x = x, y = y, z = z }
    end

    -- Calculate the total Y and Z size
    -- TODO: Retrieve actual Y/Z total dimensions. For now, use the radius, which is usually smaller than the bounding box, however
    local sizeY = maxRadius * 2
    local sizeZ = sizeY

    return totalVolume, failedAt, numberOfParts, sizeY, sizeZ
end

function ShapeMeasurementHelper:afterChainsawUpdate(chainsaw)

    -- If the ring around the tree is currently visible with an equipped chain saw
    if chainsaw.ringSelector ~= nil and getVisibility(chainsaw.ringSelector) then

        -- Find the wood shape we're looking at
        local shapeId, treeCoords, _, unitVectors = self:getWoodShapeDimensionsAtFocusPoint(chainsaw)

        if shapeId ~= nil then

            -- Retrieve the length above and below the cut ("above" and "below" from a tree perspective)
            local lenBelow, lenAbove = getSplitShapePlaneExtents(shapeId, treeCoords.x, treeCoords.y, treeCoords.z, unitVectors.xx, unitVectors.xy, unitVectors.xz)

            -- TODO: Don't display info for the bottom part if it's an actual tree rather than a piece of wood on the ground

            if self.debugShapeLength then
                -- Note: Need to press F4 with developer mode active to be able to see these
                local shapeCutLocalCoords = { worldToLocal(shapeId, treeCoords.x, treeCoords.y, treeCoords.z) }
                local shapeTopWorldCoords = {}
                local shapeBottomWorldCoords = {}
                shapeTopWorldCoords.x, shapeTopWorldCoords.y, shapeTopWorldCoords.z = localToWorld(shapeId, shapeCutLocalCoords[1], shapeCutLocalCoords[2] + lenAbove, shapeCutLocalCoords[3])
                shapeBottomWorldCoords.x, shapeBottomWorldCoords.y, shapeBottomWorldCoords.z = localToWorld(shapeId, shapeCutLocalCoords[1], shapeCutLocalCoords[2] - lenBelow, shapeCutLocalCoords[3])

                DebugDrawUtils.drawLine(treeCoords, shapeTopWorldCoords, {1,0,0}, 0.1)
                DebugDrawUtils.drawLine(treeCoords, shapeBottomWorldCoords, {1,0,0}, 0.1)
            end

            -- Calculate the volume for the pieces
            local volumeBelow, failedAtBelow, numPiecesBelow, sizeYBelow, sizeZBelow = self:calculatePartData(shapeId, treeCoords, unitVectors, lenBelow, -1)
            local volumeAbove, failedAtAbove, numPiecesAbove, sizeYAbove, sizeZAbove = self:calculatePartData(shapeId, treeCoords, unitVectors, lenAbove, 1)

            -- Get the total volume calculated by the engine and adjust our own calculations to match that total sum
            local targetVolume = getVolume(shapeId)
            local volumeFactor = targetVolume / (volumeBelow + volumeAbove)
            volumeBelow = volumeBelow * volumeFactor
            volumeAbove = volumeAbove * volumeFactor

            -- TODO: Find out if "above" is top, left or right from a player point of view

            -- Store the volumes so the UI can read them
            self.futureWoodPartData = {
                bottomVolume = volumeBelow,
                bottomLength = lenBelow,
                bottomSizeY = sizeYBelow,
                bottomSizeZ = sizeZBelow,
                topVolume = volumeAbove,
                topLength = lenAbove,
                topSizeY = sizeYAbove,
                topSizeZ = sizeZAbove,
             }

            if self.debugVolumeCalculations then
                local estimatedVolume = volumeBelow + volumeAbove

                DebugDrawUtils.renderText(treeCoords, ("Volume (below): %d l"):format(volumeBelow * 1000), 1.0)
                DebugDrawUtils.renderText(treeCoords, ("Volume (above): %d l"):format(volumeAbove * 1000), .9)
                DebugDrawUtils.renderText(treeCoords, ("Volume (total est'd): %d l"):format(estimatedVolume * 1000), .8)
                DebugDrawUtils.renderText(treeCoords, ("Volume (engine): %d l"):format(targetVolume * 1000), .7)
                DebugDrawUtils.renderText(treeCoords, ("Length (below): %.2f m"):format(lenBelow), .6)
                DebugDrawUtils.renderText(treeCoords, ("Length (above): %.2f m"):format(lenAbove), .5)

                local _, _, _, numConvexes, _ = getSplitShapeStats(shapeId)

                DebugDrawUtils.renderText(treeCoords, ("numConvexes: %d"):format(numConvexes), .4)

                if failedAtBelow >= 0 then
                    DebugDrawUtils.renderText(treeCoords, ("Bottom calculation aborted at %d/%d"):format(failedAtBelow, numPiecesBelow), .3)
                end
                if failedAtAbove >= 0 then
                    DebugDrawUtils.renderText(treeCoords, ("Top calculation aborted at %d/%d"):format(failedAtAbove, numPiecesAbove), .2)
                end

            end
        end
    else
        -- Chainsaw is no longer aimed at a tree; reset calculations
        self.futureWoodPartData = nil
    end
end