---@class WoodPriceCalculation
---This is the implementation of https://gdn.giants-software.com/documentation_scripting_fs22.php?version=script&category=58&class=628
---but adapted to return intermediate calculation results and not depend on a class instance.
---This class will have to be adapted whenever the base game implementation of the referenced methods changes, unfortunately.
WoodPriceCalculation = {}

---Calculates parameters for a given piece of wood.
---Original implementation: https://gdn.giants-software.com/documentation_scripting_fs22.php?version=script&category=58&class=628#calculateWoodBaseValue9352
---@param objectId any @The ID of the object to be analyzed
---@return table @Two subtables containing information about the shape (shapeData) and the value (valueData)
function WoodPriceCalculation.calculateWoodParameters(objectId)
    local volume = getVolume(objectId)
    local splitType = g_splitShapeManager:getSplitTypeByIndex(getSplitType(objectId))
    local sizeX, sizeY, sizeZ, numConvexes, numAttachments = getSplitShapeStats(objectId)

    local shapeData = {
        volume = volume * 1000, -- convert to liters
        splitType = splitType,
        sizeX = sizeX,
        sizeY = sizeY,
        sizeZ = sizeZ,
        numConvexes = numConvexes,
        numAttachments = numAttachments
    }
    local valueData = WoodPriceCalculation.calculateWoodBaseValueForData(volume, splitType, sizeX, sizeY, sizeZ, numConvexes, numAttachments)
    return { shapeData = shapeData, valueData = valueData }
end

---Calculates the base value for a piece of wood with the given parameters.
---Original implementation: https://gdn.giants-software.com/documentation_scripting_fs22.php?version=script&category=58&class=628#calculateWoodBaseValueForData9353
---@param volume number @The volume in milliliters, as returned by getVolume(), for example
---@param splitType table @Information about the type of wood
---@param sizeX number @The size in X dimension.
---@param sizeY number @The size in Y dimension.
---@param sizeZ number @The size in Z dimension.
---@param numConvexes integer @The number of times the shape changes direction (assumption).
---@param numAttachments integer @The number of side branches still attached.
---@return table @A table with various calculation results
function WoodPriceCalculation.calculateWoodBaseValueForData(volume, splitType, sizeX, sizeY, sizeZ, numConvexes, numAttachments)
    local qualityScale = 1
    local lengthScale = 1
    local defoliageScale = 1
    local volumeQuality
    local convexityQuality
    if sizeX ~= nil and volume > 0 then
        local bvVolume = sizeX*sizeY*sizeZ
        local volumeRatio = bvVolume / volume
        volumeQuality = 1-math.sqrt(math.clamp((volumeRatio-3)/7, 0,1)) * 0.95  --  ratio <= 3: 100%, ratio >= 10: 5%
        convexityQuality = 1-math.clamp((numConvexes-2)/(6-2), 0,1) * 0.95  -- 0-2: 100%:, >= 6: 5%
        local maxSize = math.max(sizeX, sizeY, sizeZ)
        -- 1m: 60%, 6-11m: 120%, 19m: 60%
        if maxSize < 11 then
            lengthScale = 0.6 + math.min(math.max((maxSize-1)/5, 0), 1)*0.6
        else
            lengthScale = 1.2 - math.min(math.max((maxSize-11)/8, 0), 1)*0.6
        end
        local minQuality = math.min(convexityQuality, volumeQuality)
        local maxQuality = math.max(convexityQuality, volumeQuality)
        qualityScale = minQuality + (maxQuality - minQuality) * 0.3  -- use 70% of min quality
        defoliageScale = 1-math.min(numAttachments/15, 1) * 0.8  -- #attachments 0: 100%, >=15: 20%
    end
     -- Only take 33% into account of the quality criteria on low
    qualityScale = MathUtil.lerp(1, qualityScale, g_currentMission.missionInfo.economicDifficulty / 3)
    defoliageScale = MathUtil.lerp(1, defoliageScale, g_currentMission.missionInfo.economicDifficulty / 3)

    return {
        pricePerLiter = splitType.pricePerLiter,
        volumeQuality = volumeQuality,
        convexityQuality = convexityQuality,
        qualityScale = qualityScale,
        defoliageScale = defoliageScale,
        lengthScale = lengthScale,
    }
end