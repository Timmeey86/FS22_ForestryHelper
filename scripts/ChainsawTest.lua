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

    if not chainsaw.wasAlreadyCutting and chainsaw.isCutting then
        -- The user has just started cutting
        chainsaw.wasAlreadyCutting = true

        local originalShape = chainsaw.curSplitShape
        if originalShape ~= nil then

            -- split the shape, but don't remove the original
            local x,y,z, nx,ny,nz, yx,yy,yz = chainsaw:getCutShapeInformation()
            print(tostring(originalShape))
            --local clonedShape = clone(originalShape, false, false, false) -- don't group unde rparent, don't call "onCreate", don't add physics
            splitShape(originalShape, x,y,z, nx,ny,nz, yx,yy,yz, chainsaw.cutSizeY, chainsaw.cutSizeZ, "cutSplitShapeCallback", self)
        end

    elseif chainsaw.wasAlreadyCutting and not chainsaw.isCutting then
        -- The user has just stopped cutting
        chainsaw.wasAlreadyCutting = false
    end
end


function ChainsawTest:cutSplitShapeCallback(shape, isBelow, isAbove, minY, maxY, minZ, maxZ)
    -- Add the shape temporarily to make sure all functions which access it work properly (might not be needed, not sure yet)    
	g_currentMission:addKnownSplitShape(shape)
    print(tostring(shape))
    local x,y,z = localToWorld(shape, 0,0,0)
    -- local nx,ny,nz = localDirectionToWorld(shape, 1,0,0)
    print(('%d: %.3f, %.3f, %.3f'):format(shape, x, y, z))
    -- Remove the shape again since we no longer need it (not sure if add + remove leaves a different state than when not calling any of the methods)
    g_currentMission:removeKnownSplitShape(shape)
end