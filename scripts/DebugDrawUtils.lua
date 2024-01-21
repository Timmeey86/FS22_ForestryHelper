---@class DebugDrawUtils
---A wrapper around DebugUtil with a simplified API, tailored to using vectors (tables) rather than single parameters
---The wrapper aims to provide the following:
--- - Good documentation
--- - A consistent API (e.g. parameter order: coordinates -> unit vectors -> further dimensions -> color)
--- - Consistent provision of unit vectors
--- - A much lower number of parameters (by wrapping them in highly reusable tables)
DebugDrawUtils = {}

---Visualizes a square which is being used to find a split shape, for example
---@param searchCorner table @Contains the X/Y/Z coordinates of the search corner. The square will be drawn from this point in positive Y and Z direction
---@param unitVectors table @Contains the X/Y/Z coordinates for each of the unit vectors along the X, Y and Z axes. The shape should intersect the YZ plane.
---@param searchSquareSize number @The size of any side of the square
---@param color table @An array with the R, G and B values for the color (from 0 to 1)
function DebugDrawUtils.drawShapeSearchSquare(searchCorner, unitVectors, searchSquareSize, color)
    -- Draw the rectangle
    DebugUtil.drawDebugAreaRectangle(
        -- First corner of the rectangle: The search corner
        searchCorner.x,
        searchCorner.y,
        searchCorner.z,
        -- Second corner: Move by the square size in Y direction
        searchCorner.x + unitVectors.yx*searchSquareSize,
        searchCorner.y + unitVectors.yy*searchSquareSize,
        searchCorner.z + unitVectors.yz*searchSquareSize,
        -- Third corner: Move by the square size in Z direction
        searchCorner.x + unitVectors.zx*searchSquareSize,
        searchCorner.y + unitVectors.zy*searchSquareSize,
        searchCorner.z + unitVectors.zz*searchSquareSize,
        false,
        color[1], color[2], color[3]
    )
    -- Draw the X/Y/Z axes which helps with verifying that the proper unit vectors were supplied
    DebugUtil.drawDebugGizmoAtWorldPos(
        searchCorner.x, searchCorner.y, searchCorner.z,
        unitVectors.yx, unitVectors.yy, unitVectors.yz,
        unitVectors.zx, unitVectors.zy, unitVectors.zz,
        "search",
        false)
end

---Draws the X/Y/Z directions at the given location
---@param worldLocation table @The X/Y/Z world coordinates of the location
---@param unitVectors table @The X/Y/Z coordinates for the unit vectors along the X/Y/Z axes, where X is the "main" direction
---@param text string @The text to print
function DebugDrawUtils.drawDebugGizmo(worldLocation, unitVectors, text)
    DebugUtil.drawDebugGizmoAtWorldPos(
        worldLocation.x, worldLocation.y, worldLocation.z,
        unitVectors.yx, unitVectors.yy, unitVectors.yz,
        unitVectors.zx, unitVectors.zy, unitVectors.zz,
        text,
        false)
end

---Retrieves four corners on the Y/Z plane around a location, using the given square size
---@param location table @The X/Y/Z coordinates of the center of the resulting square
---@param unitVectors table @The X/Y/Z coordinates for the unit vectors along the X/Y/Z axes, where X is the "main" direction
---@param squareSize number @The size of the square around the location, along the Y/Z plane
---@return table @The bottomLeft, bottomRight, topLeft and topRight X/Y/Z coordinates (nested table)
function DebugDrawUtils.getSquareCornersAroundLocation(location, unitVectors, squareSize)
    local halfSquareSize = squareSize / 2
    -- Calculate the coordinates for the corners. Naming convention is: Look along the X axis, with Y being upwards and Z to the right
    return {
        bottomLeft = {
            x = location.x - unitVectors.yx * halfSquareSize - unitVectors.zx * halfSquareSize,
            y = location.y - unitVectors.yy * halfSquareSize - unitVectors.zy * halfSquareSize,
            z = location.z - unitVectors.yz * halfSquareSize - unitVectors.zz * halfSquareSize
        },
        bottomRight = {
            x = location.x - unitVectors.yx * halfSquareSize + unitVectors.zx * halfSquareSize,
            y = location.y - unitVectors.yy * halfSquareSize + unitVectors.zy * halfSquareSize,
            z = location.z - unitVectors.yz * halfSquareSize + unitVectors.zz * halfSquareSize,
        },
        topLeft = {
            x = location.x + unitVectors.yx * halfSquareSize - unitVectors.zx * halfSquareSize,
            y = location.y + unitVectors.yy * halfSquareSize - unitVectors.zy * halfSquareSize,
            z = location.z + unitVectors.yz * halfSquareSize - unitVectors.zz * halfSquareSize,
        },
        topRight = {
            x = location.x + unitVectors.yx * halfSquareSize + unitVectors.zx * halfSquareSize,
            y = location.y + unitVectors.yy * halfSquareSize + unitVectors.zy * halfSquareSize,
            z = location.z + unitVectors.yz * halfSquareSize + unitVectors.zz * halfSquareSize,
        }
    }
end

---Draws a square defined by three corners. The directions used assume one is looking along the X axis with Y pointing up and Z to the right
---@param bottomLeft table @The X/Y/Z coordinates of the bottom left corner
---@param bottomRight table @The X/Y/Z coordinates of the bottom right corner
---@param topLeft table @The X/Y/Z coordinates of the top left corner
---@param color table @An array with the R, G and B values for the color (from 0 to 1)
function DebugDrawUtils.drawSquare(bottomLeft, bottomRight, topLeft, color)
    DebugUtil.drawDebugAreaRectangle(
        bottomLeft.x,
        bottomLeft.y,
        bottomLeft.z,
        bottomRight.x,
        bottomRight.y,
        bottomRight.z,
        topLeft.x,
        topLeft.y,
        topLeft.z,
        false,
        color[1], color[2], color[3])
end

---Draws a line between two points.
---@param firstLocation table @The X/Y/Z coordinates of the first location
---@param secondLocation table @The X/Y/Z coordinates of the second location
---@param color table @An array with the R, G and B values for the color (from 0 to 1)
---@param circleRadius any @The radius of circles on the Y/Z world plane to be drawn at either end, or nil if not desired
function DebugDrawUtils.drawLine(firstLocation, secondLocation, color, circleRadius)
    DebugUtil.drawDebugLine(
        firstLocation.x, firstLocation.y, firstLocation.z,
        secondLocation.x, secondLocation.y, secondLocation.z,
        color[1], color[2], color[3],
        circleRadius,
        false)
end

---Draws a bounding box two points, using the square sizes for the other two dimensions, centered on the two points
---@param firstPoint table @The X/Y/Z world coordinates of the first point
---@param secondPoint table @The X/Y/Z world coordinates of the second point
---@param unitVectors table @The X/Y/Z coordinates for the unit vectors along the X/Y/Z axes, where X is the "main" direction
---@param firstSquareSize number @The size of the square around the first point, along the Y/Z plane
---@param secondSquareSize number @The size of the square around the second point, along the Y/Z plane
---@param color table @An array with the R, G and B values for the color (from 0 to 1)
function DebugDrawUtils.drawBoundingBox(firstPoint, secondPoint, unitVectors, firstSquareSize, secondSquareSize, color)
    local firstSquare = DebugDrawUtils.getSquareCornersAroundLocation(firstPoint, unitVectors, firstSquareSize)
    local secondSquare = DebugDrawUtils.getSquareCornersAroundLocation(secondPoint, unitVectors, secondSquareSize)

    -- Draw the square around the first point
    DebugDrawUtils.drawSquare(firstSquare.bottomLeft, firstSquare.bottomRight, firstSquare.topLeft, color)
    -- Draw the square around the second point
    DebugDrawUtils.drawSquare(secondSquare.bottomLeft, secondSquare.bottomRight, secondSquare.topLeft, color)
    -- Connect the corners
    DebugDrawUtils.drawLine(firstSquare.bottomLeft, secondSquare.bottomLeft, color)
    DebugDrawUtils.drawLine(firstSquare.bottomRight, secondSquare.bottomRight, color)
    DebugDrawUtils.drawLine(firstSquare.topLeft, secondSquare.topLeft, color)
    DebugDrawUtils.drawLine(firstSquare.topRight, secondSquare.topRight, color)
end

---Renders a text at the given location, using a fixed size
---@param location table @The location to render the text at
---@param text string @The text to display
---@optional yOffset number @An optional Y offset, useful for drawing various information at the same location, but on top of each other
function DebugDrawUtils.renderText(location, text, yOffset)
    local offset = yOffset or 0
    Utils.renderTextAtWorldPosition(location.x, location.y + offset, location.z, text, getCorrectTextSize(0.02, 0))
end