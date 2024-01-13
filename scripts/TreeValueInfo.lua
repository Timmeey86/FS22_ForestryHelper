-- Create a table to store everything related to TreeValueInfo. This will also act like a class
TreeValueInfo = {}

-- Define a method which will add more information to the info box for trees or wood. The last argument is defined by the method we are extending

---This function adds information about the value of trees
---@param baseGameObject table @The object used by the base game to display the information. We are interested in its "objectBox"
---@param superFunc function @The base game function which is extended by this one.
---@param splitShape table @The split shape which might be a tree or a piece of wood (or something else).
function TreeValueInfo.addTreeValueInfo(baseGameObject, superFunc, splitShape)

    -- Call the base game behavior (including other mods which were registered before our mod)
    -- This way, if Giants changes their code, we don't have to adapt our mod in many cases
    superFunc(baseGameObject, splitShape)

    -- Add our content
    baseGameObject.objectBox:addLine("Test", "Just a test")
end

-- Inject our own method into the existing PlayerHUDUpdater method of the base game
PlayerHUDUpdater.showSplitShapeInfo = Utils.overwrittenFunction(PlayerHUDUpdater.showSplitShapeInfo, TreeValueInfo.addTreeValueInfo)

-- If the game would normally call the showSplitShapeInfo method, it will now call our method instead (which calls the original function)