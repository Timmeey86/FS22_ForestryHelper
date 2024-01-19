ChainsawTest = {}
local ChainsawTest_mt = Class(ChainsawTest)

function ChainsawTest.new()
    local self = setmetatable({}, ChainsawTest_mt)
    self.woodProbeNode = createTransformGroup("treeValueInfo_woodProbeNode")
    return self
end

--[[function ChainsawTest.updateRingSelector(chainsaw,superFunc, shape)
    superFunc(chainsaw, shape)

    --if chainsaw.ringSelector and getVisibility(chainsaw.ringSelector) then
        --print("Visible")
    --end
end]]

function ChainsawTest:afterChainsawPostLoad(chainsaw)
    link(chainsaw.chainsawSplitShapeFocus, self.woodProbeNode) -- Use the point the player is looking at as a reference system
end

---Retrieves information about a wood shape at the focus point of the user
---@param chainsaw table @The base game chainsaw object
---@return any @The ID of the tree shape, or nil if it wasn't found
---@return number @The world X coordinate of the center of the "ring" the player can see
---@return number @The world Y coordinate of the center of the "ring" the player can see
---@return number @The world Z coordinate of the center of the "ring" the player can see
---@return number @The radius of the tree shape at the given coordinates
function ChainsawTest:getWoodShapeDimensionsAtFocusPoint(chainsaw)

    -- Retrieve the following information from the focus point of the player:
    -- The x,y,z coordinates of the focus point
    -- A unit vector (length = 1) along the X axis of the focus point
    -- A unit vector along the Y axis of the focus point
    local x,y,z, nx,ny,nz, yx,yy,yz = chainsaw:getCutShapeInformation()

    -- Find the wood shape at the given coordinates
    local largeEnoughRectangleSize = 2.0
    local shapeId, minY, maxY, minZ, maxZ = findSplitShape(x,y,z, nx,ny,nz, yx,yy,yz, largeEnoughRectangleSize, largeEnoughRectangleSize)

    local halfRectangleSize = largeEnoughRectangleSize / 2.0
    local treeCutXWorld, treeCutYWorld, treeCutZWorld, radius
    if shapeId ~= nil and shapeId ~= 0 then

        -- Get the radius of the wood shape at the same position, but while ignoring the chainsaw cutting angle
        -- instead, simulate a perfect perpendicular cut to get the actual radius of the tree
        -- in order to properly find the shape again, we need to define a rectangle around the whole shape.

        -- Translate our own probing node to the center of the retrieved tree shape rectangle (relative to its parent node, which is the focus point of the user)
        setTranslation(self.woodProbeNode, 0, (minY+maxY)/2.0, (minZ+maxZ)/2.0)

        -- Get the world coordinates for that point
        treeCutXWorld, treeCutYWorld, treeCutZWorld = localToWorld(self.woodProbeNode, 0,0,0)

        -- Retrieve unit vectors for the local tree coordinate system, but rotate it so that the tree's Y becomes the lookup X axis,
        -- otherwise `testSplitShape` will fail to find anything later on.
        -- The reason for this is that `testSplitShape` needs the split shape to intersect the Y/Z plane in X direction, while trees and pieces of wood
        -- have their longest side along their Y axis
        nx,ny,nz = localDirectionToWorld(shapeId, 0,1,0) -- unit vector along the local X axis of the shape, but in world coordinates
        yx,yy,yz = localDirectionToWorld(shapeId, 1,0,0) -- unit vector along the local Y axis of the shape, but in world coordinates
        local zx,zy,zz = localDirectionToWorld(shapeId, 0,0,-1) -- unit vector along the local Y axis of the shape, but in world coordinates

        -- Move the coordinates half a height in Y and Z direction so that the resulting rectangle will have the original y/z in its center
        x = treeCutXWorld - yx*halfRectangleSize - zx*halfRectangleSize
        y = treeCutYWorld - yy*halfRectangleSize - zy*halfRectangleSize
        z = treeCutZWorld - yz*halfRectangleSize - zz*halfRectangleSize

        -- Find the split shape at the location we already found it at, but this time with a perpendicular cut
        local minY2, maxY2, minZ2, maxZ2 = testSplitShape(shapeId, x,y,z, nx,ny,nz, yx,yy,yz, largeEnoughRectangleSize, largeEnoughRectangleSize)
        if minY2 ~= nil then
            radius = ((maxY2-minY2)+(maxZ2-minZ2)) / 4.0 -- /2 for average diameter and another /2 to get the radius
        else
            shapeId = nil
        end
    end

    return shapeId, treeCutXWorld, treeCutYWorld, treeCutZWorld, radius
end

function ChainsawTest:afterChainsawUpdate(chainsaw)

    -- If the ring around the tree is currently visible with an equipped chain saw
    if chainsaw.ringSelector ~= nil and getVisibility(chainsaw.ringSelector) then

        -- Find the wood shape we're looking at
        local shapeId, treeX, treeY, treeZ, radius = self:getWoodShapeDimensionsAtFocusPoint(chainsaw)

        Utils.renderTextAtWorldPosition(treeX,treeY,treeZ, ('ShapeId: %d, Radius: %.3f'):format(shapeId, radius), getCorrectTextSize(0.02), 0)
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