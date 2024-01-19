ChainsawTest = {}
local ChainsawTest_mt = Class(ChainsawTest)

function ChainsawTest.new()
    local self = setmetatable({}, ChainsawTest_mt)
    self.woodProbeNode = createTransformGroup("treeValueInfo_woodProbeNode")
    self.debugNode = createTransformGroup("treeValueInfo_debugNode")
    link(getRootNode(), self.debugNode)
    return self
end

--[[function ChainsawTest.updateRingSelector(chainsaw,superFunc, shape)
    superFunc(chainsaw, shape)

    --if chainsaw.ringSelector and getVisibility(chainsaw.ringSelector) then
        --print("Visible")
    --end
end]]

function ChainsawTest:afterChainsawPostLoad(chainsaw)
    print("afterChainsawPostLoad")
    link(chainsaw.chainsawSplitShapeFocus, self.woodProbeNode) -- Use the point the player is looking at as a reference system
end

function ChainsawTest:beforeChainsawDelete(chainswa)
    unlink(self.woodProbeNode)
    print("beforeChainsawDelete")
end

---Gets the radius of the tree at the given location
---@param shapeId any @The tree shape which was already found
---@param worldCoorpsNearShape table @World coordinates close to or within the tree
---@param shapeUnitVectors table @Unit vectors for X/Y/Z dimensions, where the X vector points along the longest dimension of the tree
---@return any @The ID of the tree shape or nil if it wasn't found at the given location
---@return number @The radius at the given location
---@return table @The coordinates a the given location, centered on the tree shape in Y/Z direction
function ChainsawTest:getRadiusAtLocation(shapeId, worldCoorpsNearShape, shapeUnitVectors)

    -- Define a reasonably large enough rectangle to find the tree
    -- We already found a tree at this point so we don't need an overly large radius
    local rectangleSize = 1.1
    local halfRectangleSize = rectangleSize / 2.0

    -- Move the coordinates half a height in Y and Z direction so that the resulting rectangle will have the original y/z in its center
    local x = worldCoorpsNearShape.x - shapeUnitVectors.yx*halfRectangleSize - shapeUnitVectors.zx*halfRectangleSize
    local y = worldCoorpsNearShape.y - shapeUnitVectors.yy*halfRectangleSize - shapeUnitVectors.zy*halfRectangleSize
    local z = worldCoorpsNearShape.z - shapeUnitVectors.yz*halfRectangleSize - shapeUnitVectors.zz*halfRectangleSize

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

        return shapeId, radius, worldCoorpsNearShape
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
function ChainsawTest:getWoodShapeDimensionsAtFocusPoint(chainsaw)

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

        shapeId, radius, treeCoords = self:getRadiusAtLocation(shapeId, treeCoords, treeUnitVectors)
    end

    return shapeId, treeCoords, radius, treeUnitVectors
end

function ChainsawTest:afterChainsawUpdate(chainsaw)

    -- If the ring around the tree is currently visible with an equipped chain saw
    if chainsaw.ringSelector ~= nil and getVisibility(chainsaw.ringSelector) then

        -- Find the wood shape we're looking at
        local shapeId, treeCoords, radius, unitVectors = self:getWoodShapeDimensionsAtFocusPoint(chainsaw)

        if shapeId ~= nil then

            -- Retrieve data on the whole piece of wood
            local sizeX, _, _, numConvexes, numAttachments = getSplitShapeStats(shapeId)

            -- Retrieve the length above and below the cut ("above" and "below" from a tree perspective)
            local lenBelow, lenAbove = getSplitShapePlaneExtents(shapeId, treeCoords.x, treeCoords.y, treeCoords.z, unitVectors.xx, unitVectors.xy, unitVectors.xz)
            Utils.renderTextAtWorldPosition(treeCoords.x,treeCoords.y+0.2,treeCoords.z, ('length: %.3f'):format(sizeX), getCorrectTextSize(0.02), 0)
            Utils.renderTextAtWorldPosition(treeCoords.x,treeCoords.y+0.4,treeCoords.z, ('lenBelow: %.3f'):format(lenBelow), getCorrectTextSize(0.02), 0)
            Utils.renderTextAtWorldPosition(treeCoords.x,treeCoords.y+0.6,treeCoords.z, ('lenAbove: %.3f'):format(lenAbove), getCorrectTextSize(0.02), 0)
            -- Calculate data for both sides
            for xOffset = 0, 10 do
                -- Probe the radius to the left 
                local x = treeCoords.x + unitVectors.xx * xOffset
                local y = treeCoords.y + unitVectors.xy * xOffset
                local z = treeCoords.z + unitVectors.xz * xOffset

                shapeId, radius, _ = self:getRadiusAtLocation(shapeId,  { x = x, y = y, z = z }, unitVectors)

                if shapeId ~= nil then
                    Utils.renderTextAtWorldPosition(x,y,z, ('%d: %.3f'):format(xOffset, radius), getCorrectTextSize(0.02), 0)
                else
                    Utils.renderTextAtWorldPosition(x,y,z, "No data", getCorrectTextSize(0.02), 0)
                end

                --Utils.renderTextAtWorldPosition(treeX,treeY,treeZ, ('ShapeId: %d, Radius: %.3f'):format(shapeId, radius), getCorrectTextSize(0.02), 0)
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