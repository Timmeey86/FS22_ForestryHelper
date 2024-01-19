ChainsawTest = {}
local ChainsawTest_mt = Class(ChainsawTest)

function ChainsawTest.new()
    local self = setmetatable({}, ChainsawTest_mt)
    return self
end

--[[function ChainsawTest.updateRingSelector(chainsaw,superFunc, shape)
    superFunc(chainsaw, shape)

    --if chainsaw.ringSelector and getVisibility(chainsaw.ringSelector) then
        --print("Visible")
    --end
end]]

function ChainsawTest:update(chainsaw)


    -- If the ring around the tree is currently visible with an equipped chain saw
    if chainsaw.ringSelector ~= nil and getVisibility(chainsaw.ringSelector) then
        -- Find the wood shape we're looking at
        local x,y,z, nx,ny,nz, yx,yy,yz = chainsaw:getCutShapeInformation()
        local shapeId, minY, maxY, minZ, maxZ = findSplitShape(x,y,z, nx,ny,nz, yx,yy,yz, chainsaw.cutSizeY, chainsaw.cutSizeZ)
        if shapeId ~= nil and shapeId ~= 0 then

            -- Get the radius of the wood shape at the same position, but while ignoring the chainsaw cutting angle
            -- instead, simulate a perfect perpendicular cut to get the actual radius of the tree
            -- in order to properly find the shape again, we need to define a rectangle around the whole shape.
            -- However, x,y,z points to the a point along the local Y axis of the shape (because trees always grow along the Y axis in FS22).
            -- Therefore, we need to move X and Z half a width/height away to make the local Y axis of the shape end up in the center
            -- of the rectangle we're defining
            local yOffset = chainsaw.cutSizeY / 2.0 -- from the point of view of a tree or log, we cut along the X and Z axis
            local zOffset = chainsaw.cutSizeZ / 2.0

            -- Instead of getting the coordinates of the shape, get the coordinates of the ring selector, since that is centered within the shape,
            x,y,z = localToWorld(chainsaw.ringSelector, 0,0,0)
            nx,ny,nz = localDirectionToWorld(shapeId, 0,1,0) -- unit vector along the local X axis of the shape, but in world coordinates
            yx,yy,yz = localDirectionToWorld(shapeId, 1,0,0) -- unit vector along the local Y axis of the shape, but in world coordinates
            local zx,zy,zz = localDirectionToWorld(shapeId, 0,0,-1) -- unit vector along the local Y axis of the shape, but in world coordinates

            -- but move the coordinates half a height in Y and Z direction so that the resulting rectangle will have the original x/z in its center
            x = x - yx*yOffset - zx*zOffset
            y = y - yy*yOffset - zy*zOffset
            z = z - yz*yOffset - zz*zOffset

            DebugUtil.drawDebugAreaRectangle(
                x,y,z,
                x+yx*chainsaw.cutSizeY, y+yy*chainsaw.cutSizeY, z+yz*chainsaw.cutSizeY,
                x+zx*chainsaw.cutSizeZ, y+zy*chainsaw.cutSizeZ, z+zz*chainsaw.cutSizeZ,
                false,
                1,0,1)


            DebugUtil.drawDebugLine(x,y,z, x+nx/5,y+ny/5,z+nz/5, 1,0,0, nil, false)
            DebugUtil.drawDebugLine(x,y,z, x+yx/5,y+yy/5,z+yz/5, 0,1,0, nil, false)
            DebugUtil.drawDebugLine(x,y,z, x+zx/5,y+zy/5,z+zz/5, 0,0,1, nil, false)

            shapeId, minY, maxY, minZ, maxZ = findSplitShape(x,y,z, nx,ny,nz, yx,yy,yz, chainsaw.cutSizeY, chainsaw.cutSizeZ)
            if shapeId ~= nil and shapeId ~= 0 then
                local radius = ((maxY-minY)+(maxZ-minY)) / 4.0 -- /2 for average diameter and another /2 to get the radius
                Utils.renderTextAtWorldPosition(x,y,z, ('Found shapeId: %d'):format(shapeId), getCorrectTextSize(0.02), 0)

                local rX, rY, rZ = localToWorld(chainsaw.ringSelector, 0,0,0)
                Utils.renderTextAtWorldPosition(rX,rY,rZ, ('Radius: %.3f'):format(radius), getCorrectTextSize(0.02), 0)
                Utils.renderTextAtWorldPosition(rX,rY+0.2,rZ, ('Y: %.3f/%.3f, Z: %.3f/%.3f'):format(minY, maxY, minZ, maxZ), getCorrectTextSize(0.02), 0)
                DebugUtil.drawDebugAreaRectangle(
                    rX - yx*radius - zx*radius,
                    rY - yy*radius - zy*radius,
                    rZ - yz*radius - zz*radius,
                    rX - yx*radius + zx*radius,
                    rY - yy*radius + zy*radius,
                    rZ - yz*radius + zz*radius,
                    rX + yx*radius - zx*radius,
                    rY + yy*radius - zy*radius,
                    rZ + yz*radius - zz*radius,
                    false,
                    0,0.5,0.5)
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