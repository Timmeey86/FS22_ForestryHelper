DebugHelper = {}
---Prints a table recursively while sorting table entries alphabetically
---@param inputTable table @The table to be printed
---@param depth number @Always set this to 0
---@param maxDepth number @The number of times to recurse, counting from zero where zero = "Print only the first level"
function DebugHelper.printSortedTableRecursively(inputTable, depth, maxDepth)
	depth = depth or 0
	maxDepth = maxDepth or 3

	if depth == 0 then
		print("---------------------------------------------------")
	elseif depth > maxDepth then
		return
	end

	local sortedKeys = {}
	for i, _ in pairs(inputTable) do
		table.insert(sortedKeys, i)
	end
	table.sort(sortedKeys)
	local baseIndent = ""
	for i = 0, depth - 2 do
		baseIndent = baseIndent .. "  |"
	end
	if depth > 0 then
		baseIndent = baseIndent .. "  |- "
	end
	local numKeys = #sortedKeys
	for i, key in pairs(sortedKeys) do
		local value = inputTable[key]
		print(baseIndent .. tostring(key) .. " :: " .. tostring(value))

		if type(value) == "table" then
			DebugHelper.printSortedTableRecursively(value, depth + 1, maxDepth)
		end
	end
	if depth == 0 then
		print("---------------------------------------------------")
	end
end
function DebugHelper.hookFunction(cls_str, fnc_str)
    local root = getmetatable(_G).__index
    local cls = not cls_str and root or root[cls_str]
    if not cls then
        print("Error: Class " .. (cls_str or "nil") .. " not found")
        return
    end

    local fnc = cls[fnc_str]
    if not fnc then
        print("Error: Function " .. (fnc_str or "nil") .. " not found in " .. (cls_str or "_G"))
        return
    end
    
    print("OVER-WRITTEN: " .. (cls_str or "_G") .. "." .. fnc_str)
    cls[fnc_str] = Utils.overwrittenFunction(fnc, 
        function(self, superFunc, ...)
            local args = {...}
            print("FUNCTION: " .. fnc_str)
            print("self: " .. tostring(self))
            
            for i, v in ipairs(args) do
                print("arg" .. i .. " - " .. tostring(v))
            end

            local results = {superFunc(self, table.unpack(args))}

            for i, v in ipairs(results) do
                print("return" .. i .. " - " .. tostring(v))
            end

            return table.unpack(results)
        end
    )
end