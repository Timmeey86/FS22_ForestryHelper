---@diagnostic disable: deprecated
ShapeMeasurementHelper = {}
local ShapeMeasurementHelper_mt = Class(ShapeMeasurementHelper)

function ShapeMeasurementHelper.new()
    local self = setmetatable({}, ShapeMeasurementHelper_mt)

    self.futureWoodPartData = nil

    self.debugRadiusDetection = true
    self.debugRadiusResults = true
    self.debugShapeLength = false
    self.debugVolumeCalculations = false
    self.debugConvexityAngles = false
    self.debugConvexityLines = false
    self.debugConvexityAboveThreshold = false

    self.previousCalculationPos = { x = 0, y = 0, z = 0 }
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

        local coordinates = {}
        coordinates, radius = self:findPointInMiddleOfShape(shapeId, treeCoords, treeUnitVectors)
        if coordinates == nil then
            shapeId = nil
        end
    end

    return shapeId, treeCoords, radius, treeUnitVectors
end

---comment
---@param shapeId any
---@param worldCoordsNearShape any
---@param shapeUnitVectors any
---@param searchRadius any
---@return any
---@return number
function ShapeMeasurementHelper:findPointInMiddleOfShape(shapeId, worldCoordsNearShape, shapeUnitVectors, searchRadius)
    -- Define a search square centered around the world coordinates
    local halfSearchBoxSize = searchRadius or 0.7
    local searchBoxSize = halfSearchBoxSize * 2

    local x = worldCoordsNearShape.x - shapeUnitVectors.yx*halfSearchBoxSize - shapeUnitVectors.zx*halfSearchBoxSize
    local y = worldCoordsNearShape.y - shapeUnitVectors.yy*halfSearchBoxSize - shapeUnitVectors.zy*halfSearchBoxSize
    local z = worldCoordsNearShape.z - shapeUnitVectors.yz*halfSearchBoxSize - shapeUnitVectors.zz*halfSearchBoxSize

    if self.debugRadiusDetection then
        DebugDrawUtils.drawShapeSearchSquare( { x=x, y=y, z=z }, shapeUnitVectors, searchBoxSize, {0.7, 0, 1})
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
        searchBoxSize,
        searchBoxSize)
    if minY ~= nil then
        -- Move the corner of the search square used above to the center of the found location. min/max Y/Z are relative to that location
        local yCenter = (minY + maxY) / 2.0
        local zCenter = (minZ + maxZ) / 2.0
        local worldCoordsAtShape = {}
        worldCoordsAtShape.x = x + yCenter * shapeUnitVectors.yx + zCenter * shapeUnitVectors.zx
        worldCoordsAtShape.y = y + yCenter * shapeUnitVectors.yy + zCenter * shapeUnitVectors.zy
        worldCoordsAtShape.z = z + yCenter * shapeUnitVectors.yz + zCenter * shapeUnitVectors.zz

        --[[if self.debugRadiusResults then
            DebugDrawUtils.drawDebugGizmo(worldCoordsAtShape, shapeUnitVectors, "")
        end]]

        local radius = math.max((maxY-minY)/2, (maxZ-minZ)/2)
        return worldCoordsAtShape, radius
    else
        return nil, 0
    end

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

---Simple conversion function to convert a three component vector into an table
---@param x number @The X component
---@param y number @The Y component
---@param z number @The Z component
---@return table @The vector as a table with properties x, y and z
function ShapeMeasurementHelper:joinVector(x, y, z)
    return { x = x, y = y, z = z }
end

---Retrieves a quaternion which rotates a vector 
---@param oldUnitVector table @The X/Y/Z coordinates of the old (source) vector (with a length of 1)
---@param newUnitVector table @The X/Y/Z coordintaes of the new (target) vector (with a length of 1)
---@param angleMultiplier any @Optional parameter used for animation. Usually between 0 and 1
---@return table @The W/X/Y/Z components of the quaternion. Note that some engine functions expect quaternions to be supplied in XYZW order.
function ShapeMeasurementHelper:getRotationQuaternion(oldUnitVector, newUnitVector, angleMultiplier)
    -- Get a rotation axis which is rectangular on the old and new x axis
    local rotationAxisX, rotationAxisY, rotationAxisZ = MathUtil.crossProduct(oldUnitVector.x, oldUnitVector.y, oldUnitVector.z, newUnitVector.x, newUnitVector.y, newUnitVector.z )
    -- Calculate the angle between the two x axes by making use of general properties of cross products
    local crossProductMagnitude = MathUtil.vector3Length(rotationAxisX, rotationAxisY, rotationAxisZ)
    local rotationAngle = math.asin(crossProductMagnitude)
    -- Normalize the rotation axis since the quaternion processing functions expect unit vectors
    rotationAxisX, rotationAxisY, rotationAxisZ = MathUtil.vector3Normalize(rotationAxisX, rotationAxisY, rotationAxisZ)

    -- Define a quaternion which rotates anything around the rotation Axis by the rotation angle
    -- A quaternion which rotates an object around a unit vector (x,y,z) by an angle a is defined as q = (cos(a/2), x*sin(a/2), y*sin(a/2), z*sin(a/2))
    -- https://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation
    local halfAngle = rotationAngle * (angleMultiplier or 1) / 2
    local sinMultiplier = math.sin(halfAngle)
    local cosMultiplier = math.cos(halfAngle)

    return {
        w = cosMultiplier,
        x = rotationAxisX * sinMultiplier,
        y = rotationAxisY * sinMultiplier,
        z = rotationAxisZ * sinMultiplier
    }
end

---Rotates the X/Y/Z unit vectors as configured in the rotation quaternion.
---@param oldUnitVectors table @A nested table of unit vectors in X/Y/Z direction
---@param rotationQuaternion table @A quaternion which describes a rotation in 3D space
---@return table @A nested table with the rotated unit vectors pointing in the new X/Y/Z directions
function ShapeMeasurementHelper:rotateUnitVectors(oldUnitVectors, rotationQuaternion)
    local newUnitVectors = {}
    newUnitVectors.xx, newUnitVectors.xy, newUnitVectors.xz = mathQuaternionRotateVector(
        rotationQuaternion.x, rotationQuaternion.y, rotationQuaternion.z, rotationQuaternion.w,
        oldUnitVectors.xx, oldUnitVectors.xy, oldUnitVectors.xz
    )
    newUnitVectors.yx, newUnitVectors.yy, newUnitVectors.yz = mathQuaternionRotateVector(
        rotationQuaternion.x, rotationQuaternion.y, rotationQuaternion.z, rotationQuaternion.w,
        oldUnitVectors.yx, oldUnitVectors.yy, oldUnitVectors.yz
    )
    newUnitVectors.zx, newUnitVectors.zy, newUnitVectors.zz = mathQuaternionRotateVector(
        rotationQuaternion.x, rotationQuaternion.y, rotationQuaternion.z, rotationQuaternion.w,
        oldUnitVectors.zx, oldUnitVectors.zy, oldUnitVectors.zz
    )
    return newUnitVectors
end

function ShapeMeasurementHelper:copyUnitVectors(unitVectors)
    return {
        xx = unitVectors.xx, xy = unitVectors.xy, xz = unitVectors.xz,
        yx = unitVectors.yx, yy = unitVectors.yy, yz = unitVectors.yz,
        zx = unitVectors.zx, zy = unitVectors.zy, zz = unitVectors.zz,
    }
end

---Calculates the volume of a part of the tree
---@param shapeId any @The ID of the tree shape
---@param treeCoords table @The x/y/z coordinates of the planned cutting position
---@param unitVectors table @Unit vectors along the x/y/z axes of the tree, where x goes along the tree
---@param initialRadius number @The radius at the split point
---@param length integer @The distance between the end of the tree and the cutting position
---@param directionFactor integer @+1 if going from the cut position towards the (former) top of the tree or -1 to go below
function ShapeMeasurementHelper:calculatePartData(shapeId, treeCoords, unitVectors, initialRadius, length, directionFactor)
    local coordinateList, radiusList, unitVectorList, angleList = self:retrieveShapeData(shapeId, treeCoords, unitVectors, initialRadius, length, directionFactor)

    -- Find the "dents" in the tree and split at those locations
    local shapeParts = {}
    local currentStart = nil
    for i = 1, #coordinateList do
        if currentStart == nil then
            currentStart = { coordinateList[i] }
        end

        local currentAngle = angleList[i] * 180 / math.pi
        if currentAngle > 1 then
            DebugDrawUtils.renderText(coordinateList[i], ('%.1f°'):format(currentAngle))
        end
    end
end

---comment
---@param shapeId any
---@param treeCoords any
---@param unitVectors any
---@param length any
---@param directionFactor any
---@return table|any
---@return table|any
---@return table|any
---@return table|any
function ShapeMeasurementHelper:retrieveShapeData(shapeId, treeCoords, unitVectors, initialRadius, length, directionFactor)
    if shapeId == nil then
        return nil, nil, nil, nil
    end

    local maxLength = length
    local coordinateList = { treeCoords }
    local radiusList = { initialRadius }
    local unitVectorList = { self:copyUnitVectors(unitVectors) }
    local angleList = { 0 }
    local currentLength = 0
    local currentCoordinates = { x = treeCoords.x, y = treeCoords.y, z = treeCoords.z }
    local currentUnitVectors = self:copyUnitVectors(unitVectors)
    local currentRadius = initialRadius * 2 or .5

    -- Repeat until the end of the shape was exceeded
    while currentLength <= maxLength do
        local currentOffset = .1

        -- Get a point along the X axis from the tree, based on where the chainsaw is aiming
        local x = currentCoordinates.x + currentUnitVectors.xx * currentOffset * directionFactor
        local y = currentCoordinates.y + currentUnitVectors.xy * currentOffset * directionFactor
        local z = currentCoordinates.z + currentUnitVectors.xz * currentOffset * directionFactor

        -- Test if the shape can still be detected at this location. Use a search radius which is 30% larger than the previous match
        local pointInMiddleOfShape = {}
        pointInMiddleOfShape, currentRadius = self:findPointInMiddleOfShape(shapeId, { x=x, y=y, z=z }, currentUnitVectors, currentRadius * 1.3)

        if pointInMiddleOfShape ~= nil then
            -- A new point was found. Remember its location and other properties
            currentCoordinates.x = pointInMiddleOfShape.x
            currentCoordinates.y = pointInMiddleOfShape.y
            currentCoordinates.z = pointInMiddleOfShape.z
            table.insert(coordinateList, pointInMiddleOfShape)
            table.insert(radiusList, currentRadius)
            table.insert(unitVectorList, self:copyUnitVectors(currentUnitVectors))
        else
            -- Nothing was found => looks like the end of the tree was reached
            break
        end

        currentLength = currentLength + currentOffset

        local numberOfCoordinates = #coordinateList
        if numberOfCoordinates > 2 then
            -- Rotate the unit vectors so the X axis follows the direction between the two most recent coordinates
            local newDirection = {
                x = coordinateList[numberOfCoordinates].x - coordinateList[numberOfCoordinates - 1].x,
                y = coordinateList[numberOfCoordinates].y - coordinateList[numberOfCoordinates - 1].y,
                z = coordinateList[numberOfCoordinates].z - coordinateList[numberOfCoordinates - 1].z
            }
            newDirection.x, newDirection.y, newDirection.z = MathUtil.vector3Normalize(
                newDirection.x * directionFactor,
                newDirection.y * directionFactor,
                newDirection.z * directionFactor)
            local currentXUnitVector = { x = currentUnitVectors.xx, y = currentUnitVectors.xy, z = currentUnitVectors.xz }
            local rotationQuaternion = self:getRotationQuaternion(currentXUnitVector, newDirection)
            currentUnitVectors = self:rotateUnitVectors(currentUnitVectors, rotationQuaternion)

            -- Remember the rotation angle for further processing. Since the w part of a quaternion is cos(theta/2), theta can be calculated as 2*acos(w)
            local rotationAngle = math.acos(rotationQuaternion.w) * 2

            if numberOfCoordinates == 3 then
                -- This is the first coordinate which adjusted the unit vector. Ignore its angle since the basis is the tree trunk orientation rather than the cut position's one
                table.insert(angleList, 0)
            else
                table.insert(angleList, rotationAngle)
            end

            if numberOfCoordinates > 3 and rotationAngle > 0.17 then -- around 10°
                -- This only happens near the end of the tree, especially if it was cut diagonally
                table.remove(coordinateList, #coordinateList)
                table.remove(radiusList, #radiusList)
                table.remove(unitVectorList, #unitVectorList)
                break
            end

            if self.debugRadiusResults then
                DebugDrawUtils.drawDebugGizmo(coordinateList[numberOfCoordinates], currentUnitVectors, "")
                DebugDrawUtils.drawLine(
                    coordinateList[numberOfCoordinates],
                    coordinateList[numberOfCoordinates - 1],
                    {.8, 0, .8})
            end
        else
            table.insert(angleList, 0)
        end

        if currentRadius < 0.01 then
            -- Too small, trying to detect further will produce coordinates which jump around too much
            break
        end
    end
    return coordinateList, radiusList, unitVectorList, angleList

end

---Retrieves the distance between two points in 3D space
---@param vector1 table @The X/Y/Z coordinates of the first vector
---@param vector2 table @The X/Y/Z coordinates of the second vector
---@return number @The distance between the two points the vectors are pointing to
function ShapeMeasurementHelper:getDistance(vector1, vector2)
    local dX = vector1.x - vector2.x
    local dY = vector1.y - vector2.y
    local dZ = vector1.z - vector2.z
    return math.sqrt(dX * dX + dY * dY + dZ * dZ)
end

function ShapeMeasurementHelper:afterChainsawUpdate(chainsaw)

    -- If the ring around the tree is currently visible with an equipped chain saw
    if chainsaw.ringSelector ~= nil and getVisibility(chainsaw.ringSelector) then

        local currentRingSelectorPos = {}
        currentRingSelectorPos.x, currentRingSelectorPos.y, currentRingSelectorPos.z = localToWorld(chainsaw.ringSelector, 0,0,0)
        local distanceMoved = self:getDistance(currentRingSelectorPos, self.previousCalculationPos)
        self.previousCalculationPos = currentRingSelectorPos

        if distanceMoved > 0.05 or self.debugRadiusResults then -- 5 cm
            -- Find the wood shape we're looking at
            local shapeId, treeCoords, radius, unitVectors = self:getWoodShapeDimensionsAtFocusPoint(chainsaw)

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

                self:calculatePartData(shapeId, treeCoords, unitVectors, radius, lenBelow, -1)
                self:calculatePartData(shapeId, treeCoords, unitVectors, radius, lenAbove, 1)
            end
        end
    else
        -- Chainsaw is no longer aimed at a tree; reset calculations
        self.futureWoodPartData = nil
        self.previousCalculationPos = { x = 0, y = 0, z = 0 }
    end
end