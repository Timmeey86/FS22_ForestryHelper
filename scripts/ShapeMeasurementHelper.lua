---@diagnostic disable: deprecated
ShapeMeasurementHelper = {}
local ShapeMeasurementHelper_mt = Class(ShapeMeasurementHelper)

function ShapeMeasurementHelper.new()
    local self = setmetatable({}, ShapeMeasurementHelper_mt)

    self.futureWoodPartData = nil

    self.debugRadiusDetection = false
    self.debugRadiusResults = false
    self.debugShapeLength = false
    self.debugVolumeCalculations = false
    self.debugConvexityAngles = false
    self.debugConvexityLines = false
    self.debugConvexityAboveThreshold = true
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

-- Half of this is probably already in the engine or in MathUtil or something, but it's tough to discover

function ShapeMeasurementHelper.getAngleDifference(oldDim1, oldDim2, newDim1, newDim2)
    local newAngle = math.atan2(newDim2, newDim1)
    local oldAngle = math.atan2(oldDim2, oldDim1)
    return newAngle - oldAngle
end

function ShapeMeasurementHelper.getEulerAngleDifference(oldX, oldY, oldZ, newX, newY, newZ)
    -- beta: angle between the Z axes
    -- alpha: angle between oldX and
end

function ShapeMeasurementHelper.eulerRotateVector(x, y, z, rotX, rotY, rotZ)
    local qx2, qy2, qz2, qw2 = mathEulerToQuaternion(rotX, rotY, rotZ)
    return mathQuaternionRotateVector(qx2, qy2, qz2, qw2, x, y, z)
end

function ShapeMeasurementHelper.eulerRotateUnitVectors(unitVectors, rotX, rotY, rotZ)
    local newUnitVectors = {}
    newUnitVectors.xx, newUnitVectors.xy, newUnitVectors.xz = ShapeMeasurementHelper.eulerRotateVector(unitVectors.xx, unitVectors.xy, unitVectors.xz, rotX, rotY, rotZ)
    newUnitVectors.yx, newUnitVectors.yy, newUnitVectors.yz = ShapeMeasurementHelper.eulerRotateVector(unitVectors.yx, unitVectors.yy, unitVectors.yz, rotX, rotY, rotZ)
    newUnitVectors.zx, newUnitVectors.zy, newUnitVectors.zz = ShapeMeasurementHelper.eulerRotateVector(unitVectors.zx, unitVectors.zy, unitVectors.zz, rotX, rotY, rotZ)
    return newUnitVectors
end

function ShapeMeasurementHelper.rotateUnitVectors(unitVectors, newXUnitVector)
    -- Calculate the angles between the old X vector and the new one for all three planes using good ol' pythagoras
    local xyAngle = ShapeMeasurementHelper.getAngleDifference(unitVectors.xx, unitVectors.xy, newXUnitVector.x, newXUnitVector.y)
    local yzAngle = ShapeMeasurementHelper.getAngleDifference(unitVectors.xy, unitVectors.xz, newXUnitVector.y, newXUnitVector.z)
    local xzAngle = ShapeMeasurementHelper.getAngleDifference(unitVectors.xx, unitVectors.xz, newXUnitVector.x, newXUnitVector.z)

    -- Assumption: the parameters rotX, rotY, rotZ mean: Counter-clockwise rotation of the YZ plane around the X axis, ZX plane around Y, XY plane around Z
    print("--------------------------------------")
    local testVector = { x = 1, y = 0, z = 0 }
    local ninetyDegInRad = 90 * math.pi / 180
    local qx, qy, qz, qw = mathEulerToQuaternion(0, 0, 0)
    local x, y, z = mathQuaternionRotateVector(qx, qy, qz, qw, testVector.x, testVector.y, testVector.z)
    xyAngle = ShapeMeasurementHelper.getAngleDifference(1, 0, 1, 0)
    yzAngle = ShapeMeasurementHelper.getAngleDifference(0, 0, 0, 0)
    xzAngle = ShapeMeasurementHelper.getAngleDifference(1, 0, 1, 0)
    local qx2, qy2, qz2, qw2 = mathEulerToQuaternion(yzAngle, xzAngle, xyAngle)
    local x2, y2, z2 = mathQuaternionRotateVector(qx2, qy2, qz2, qw2, testVector.x, testVector.y, testVector.z)
    print( ('%.3f, %.3f, %.3f // %.3f, %.3f, %.3f // %.3f, %.3f, %.3f'):format(x, y, z, x2, y2, z2, yzAngle, xzAngle, xyAngle) )
    qx, qy, qz, qw = mathEulerToQuaternion(ninetyDegInRad, 0, 0)
    x, y, z = mathQuaternionRotateVector(qx, qy, qz, qw, testVector.x, testVector.y, testVector.z)
    xyAngle = ShapeMeasurementHelper.getAngleDifference(1, 0, 1, 0)
    yzAngle = ShapeMeasurementHelper.getAngleDifference(0, 0, 0, 0)
    xzAngle = ShapeMeasurementHelper.getAngleDifference(1, 0, 1, 0)
    qx2, qy2, qz2, qw2 = mathEulerToQuaternion(yzAngle, xzAngle, xyAngle)
    x2, y2, z2 = mathQuaternionRotateVector(qx2, qy2, qz2, qw2, testVector.x, testVector.y, testVector.z)
    print( ('%.3f, %.3f, %.3f // %.3f, %.3f, %.3f // %.3f, %.3f, %.3f'):format(x, y, z, x2, y2, z2, yzAngle, xzAngle, xyAngle) )
    qx, qy, qz, qw = mathEulerToQuaternion(0, ninetyDegInRad, 0)
    x, y, z = mathQuaternionRotateVector(qx, qy, qz, qw, testVector.x, testVector.y, testVector.z)
    xyAngle = ShapeMeasurementHelper.getAngleDifference(1, 0, 0, 0)
    yzAngle = ShapeMeasurementHelper.getAngleDifference(0, 0, 0, -1)
    xzAngle = ShapeMeasurementHelper.getAngleDifference(1, 0, 0, -1)
    qx2, qy2, qz2, qw2 = mathEulerToQuaternion(yzAngle, xzAngle, xyAngle)
    x2, y2, z2 = mathQuaternionRotateVector(qx2, qy2, qz2, qw2, testVector.x, testVector.y, testVector.z)
    print( ('%.3f, %.3f, %.3f // %.3f, %.3f, %.3f // %.3f, %.3f, %.3f'):format(x, y, z, x2, y2, z2, yzAngle, xzAngle, xyAngle) )
    qx, qy, qz, qw = mathEulerToQuaternion(0, 0, ninetyDegInRad)
    x, y, z = mathQuaternionRotateVector(qx, qy, qz, qw, testVector.x, testVector.y, testVector.z)
    xyAngle = ShapeMeasurementHelper.getAngleDifference(1, 0, 0, 1)
    yzAngle = ShapeMeasurementHelper.getAngleDifference(0, 0, 1, 0)
    xzAngle = ShapeMeasurementHelper.getAngleDifference(1, 0, 0, 0)
    qx2, qy2, qz2, qw2 = mathEulerToQuaternion(yzAngle, xzAngle, xyAngle)
    x2, y2, z2 = mathQuaternionRotateVector(qx2, qy2, qz2, qw2, testVector.x, testVector.y, testVector.z)
    print( ('%.3f, %.3f, %.3f // %.3f, %.3f, %.3f // %.3f, %.3f, %.3f'):format(x, y, z, x2, y2, z2, yzAngle, xzAngle, xyAngle) )


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
    local stepWidth = .25 * directionFactor
    -- Reduce the maximum length to avoid detection issues towards the end
    local adjustedLength = length - 0.03
    local numberOfParts = math.abs(math.ceil(adjustedLength / stepWidth))
    local totalVolume = 0
    local failedAt = -1
    local previousCoords = {}
    local previousRadius = 0
    local previousAngle = nil
    local previousNormalizedDirection = nil
    local maxRadius = 0

    local adjustedUnitVectors = {
        xx = unitVectors.xx,
        xy = unitVectors.xy,
        xz = unitVectors.xz,
        yx = unitVectors.yx,
        yy = unitVectors.yy,
        yz = unitVectors.yz,
        zx = unitVectors.zx,
        zy = unitVectors.zy,
        zz = unitVectors.zz
    }
    for i = 0,numberOfParts do -- intentionally not numberOfParts-1 because 5 parts have 6 "borders"
        local xOffset = i * stepWidth
        local pieceLength = stepWidth
        if i == numberOfParts then
            -- Last part: make sure it does not exceed the tree dimensions
            pieceLength = adjustedLength - (i-1) * stepWidth * directionFactor
            xOffset = xOffset - stepWidth + directionFactor * pieceLength
        end

        -- Get a point along the X axis from the tree, based on where the chainsaw is aiming
        local x = treeCoords.x + adjustedUnitVectors.xx * xOffset
        local y = treeCoords.y + adjustedUnitVectors.xy * xOffset
        local z = treeCoords.z + adjustedUnitVectors.xz * xOffset

        -- Retrieve the radius
        local foundShapeId, radius, newTreeCoords, yMinWorld, yMaxWorld, zMinWorld, zMaxWorld = self:getRadiusAtLocation(shapeId, { x = x, y = y, z = z }, adjustedUnitVectors)

        -- Stop processing if the shape was no longer found (too crooked, or shorter than calculated)
        if foundShapeId == nil or foundShapeId == 0 then
            failedAt = i
            break
        end
        maxRadius = math.max(maxRadius, radius)

        local coords = {}
        coords.x, coords.y, coords.z = newTreeCoords.x, newTreeCoords.y, newTreeCoords.z

        -- starting from the second radius:
        local angle = 0
        local normalizedDirection
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
                DebugDrawUtils.drawBoundingBox(coords, previousCoords, adjustedUnitVectors, radius * 2, previousRadius * 2, color)
            end

            -- Get a vector between the previous and the new coordinates. Invert for backwards direction
            local newDirectionVector = {
                x = (coords.x - previousCoords.x) * directionFactor,
                y = (coords.y - previousCoords.y) * directionFactor,
                z = (coords.z - previousCoords.z) * directionFactor
            }
            -- Normalize it to a vector of length = 1
            normalizedDirection = {}
            normalizedDirection.x, normalizedDirection.y, normalizedDirection.z = MathUtil.vector3Normalize(newDirectionVector.x, newDirectionVector.y, newDirectionVector.z)

            -- Retrieve the angle between the tree's X axis and the vector to the coordinate
            local cosTreeAngle = MathUtil.dotProduct(adjustedUnitVectors.xx, adjustedUnitVectors.xy, adjustedUnitVectors.xz, normalizedDirection.x, normalizedDirection.y, normalizedDirection.z)
            if self.debugConvexityAngles then
                DebugDrawUtils.renderText(coords, ('cos: %.5f'):format(cosTreeAngle), 0.4, .5)
            end

            -- Convert to a regular angle in degrees
            if cosTreeAngle ~= cosTreeAngle then cosTreeAngle = 0 end -- fix NaN values
            angle = math.acos(cosTreeAngle) * 180 / math.pi
            if self.debugConvexityAngles then
                DebugDrawUtils.renderText(coords, ('acos: %.3f'):format(angle), 0.2, .5)
            end

            -- Retrieve the difference in angle compared to the previous piece, starting from the third coordinate
            if angle ~= angle then angle = 0 end -- fix NaN values
            local angleDifference = (angle - previousAngle)
            if i == 1 then angleDifference = 0 end

            local angleThreshold = 1.5
            if self.debugConvexityAngles or (self.debugConvexityAboveThreshold and angleDifference > angleThreshold) then
                DebugDrawUtils.renderText(coords, ('diff: %.3f'):format(angleDifference), 0.1, .5)
            end
            if self.debugConvexityLines or (self.debugConvexityAboveThreshold and angleDifference > angleThreshold) then
                local directionVectorLength = 2
                local directionalCoordsFwd = {
                    x = coords.x + normalizedDirection.x * directionVectorLength,
                    y = coords.y + normalizedDirection.y * directionVectorLength,
                    z = coords.z + normalizedDirection.z * directionVectorLength
                }
                local directionalCoordsRev = {
                    x = coords.x - normalizedDirection.x * directionVectorLength,
                    y = coords.y - normalizedDirection.y * directionVectorLength,
                    z = coords.z - normalizedDirection.z * directionVectorLength
                }
                DebugDrawUtils.drawLine(directionalCoordsRev, directionalCoordsFwd, {1,0,0})
                if previousNormalizedDirection ~= nil then
                    local previousDirectionalCoordsFwd = {
                        x = coords.x + previousNormalizedDirection.x * directionVectorLength,
                        y = coords.y + previousNormalizedDirection.y * directionVectorLength,
                        z = coords.z + previousNormalizedDirection.z * directionVectorLength
                    }
                    local previousDirectionalCoordsRev = {
                        x = coords.x - previousNormalizedDirection.x * directionVectorLength,
                        y = coords.y - previousNormalizedDirection.y * directionVectorLength,
                        z = coords.z - previousNormalizedDirection.z * directionVectorLength
                    }
                    DebugDrawUtils.drawLine(previousDirectionalCoordsFwd, previousDirectionalCoordsRev, {0,0,1})
                end
                DebugDrawUtils.drawLine(previousCoords, coords, {0.7,0.7,0})
            end

            -- Adjust the unit vectors to the new direction



        -- else: just store the data for the first piece as a base for comparison
        end

        -- store data for the next calculation
        previousRadius = radius
        previousCoords = coords
        previousAngle = angle
        previousNormalizedDirection = normalizedDirection
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

        
        -- Get the wolrd position of the ring selector (or a bit above, for better visibility)
        local xCenter, yCenter, zCenter = localToWorld(chainsaw.ringSelector, 0, -.5, 0)
        -- Define world coordinate unit vectors
        local unitVectorsWorld = { xx = 1, xy = 0, xz = 0, yx = 0, yy = 1, yz = 0, zx = 0, zy = 0, zz = 1 }


        -- TEMP Draw several debug gizmos above the ring selector, based on the tree's coordinate system and rotated
        local currentTime = g_currentMission.environment.dayTime
        local angleMultiplier = (currentTime % 4000) / 4000
        local x1,y1,z1 = localToWorld(chainsaw.ringSelector, 0, -.4, 0)
        local x2,y2,z2 = localToWorld(chainsaw.ringSelector, -.6, -.8, 0)
        local x3,y3,z3 = localToWorld(chainsaw.ringSelector, 0, -.8, 0)
        local x4,y4,z4 = localToWorld(chainsaw.ringSelector, .6, -.8, 0)

        -- Draw the unmodified tree coordinate system
        DebugDrawUtils.drawDebugGizmo( {x=x1, y=y1, z=z1}, unitVectorsWorld, "Unmodified")

        local currentAngle = angleMultiplier*2*math.pi
        -- Set rotX to 45°
        local unitVectors1 = ShapeMeasurementHelper.eulerRotateUnitVectors(unitVectorsWorld, currentAngle, 0, 0)
        DebugDrawUtils.drawDebugGizmo( {x=x2, y=y2, z=z2}, unitVectorsWorld, "")
        DebugDrawUtils.drawDebugGizmo( {x=x2, y=y2, z=z2}, unitVectors1, "rotX = 45°")

        -- Set rotY to 45°
        local unitVectors2 = ShapeMeasurementHelper.eulerRotateUnitVectors(unitVectorsWorld, 0, currentAngle, 0)
        DebugDrawUtils.drawDebugGizmo( {x=x3, y=y3, z=z3}, unitVectorsWorld, "")
        DebugDrawUtils.drawDebugGizmo( {x=x3, y=y3, z=z3}, unitVectors2, "rotY = 45°")

        -- Set rotZ to 45°
        local unitVectors3 = ShapeMeasurementHelper.eulerRotateUnitVectors(unitVectorsWorld, 0, 0, currentAngle)
        DebugDrawUtils.drawDebugGizmo( {x=x4, y=y4, z=z4}, unitVectorsWorld, "")
        DebugDrawUtils.drawDebugGizmo( {x=x4, y=y4, z=z4}, unitVectors3, "rotZ = 45°")



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