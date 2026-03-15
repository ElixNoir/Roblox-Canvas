--- Author: COMT

--[[

	Canvas - A module for image processing
	Mod: Rectangle

]]

--!native
--!optimize 2
--!strict


-- -- State

local Canvas = require(script.Parent)
type Canvas = Canvas.Canvas

local Module = {}

export type Shader = (
	x: number, y: number
) -> number

export type ShaderCompiler = (
	canvas: Canvas.Canvas,
	x: number, y: number,
	width: number, height: number,
	...any
) -> Shader


-- -- Helpers

local buffer_readu32 = buffer.readu32
local buffer_rep = Canvas.buffer_rep
local buffer_writeu32 = buffer.writeu32

local math_max = math.max
local math_min = math.min

local compute_Blend = Canvas.compute_Blend

--[[
	Computes the clipped bounding box of a rectangle with the given canvas size (dstWidth, dstHeight), top-left (x, y) coordinate, width, and height.
	returns: (minX, minY, maxX, minY)
]]
local function compute_BoundingBox(
	dstWidth: number, dstHeight: number,
	x: number, y: number,
	width: number, height: number
): (number, number, number, number)
	return math_max(x, 0), math_max(y, 0), math_min(dstWidth, x + width), math_min(dstHeight, x + height)
end

Module.compute_BoundingBox = compute_BoundingBox

--[[
	Draws a rectangle, top-left to bottom-right, at the given (x, y) coordinate with the given width and height and blends pixels with color given by a shader function.
]]
function Module.draw_Blend(self: Canvas,
	x: number, y: number,
	width: number, height: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	if width <= 0 or height <= 0 then 
		return false
	end 

	local dstWidth, dstHeight = self.Width, self.Height
	local xStart, yStart, xEnd, yEnd = compute_BoundingBox(dstWidth, dstHeight, x, y, width, height)
	if xStart >= xEnd or yStart >= yEnd then
		return false
	end

	local b = self.Buffer
	local shader = compileShader(self, x, y, width, height, ...)
	for py = yStart, yEnd - 1 do
		local rowOffset = py * dstWidth
		for px = xStart, xEnd - 1 do
			local offset = 4 * (rowOffset + px)
			buffer_writeu32(b, offset, compute_Blend(shader(px, py), buffer_readu32(b, offset)))
		end
	end

	return true
end

--[[
	Draws a rectangle, top-left to bottom-right, at the given (x, y) coordinate with the given width and height and overwrites pixels with color given by a shader function.
]]
function Module.draw_Overwrite(self: Canvas,
	x: number, y: number,
	width: number, height: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	if width <= 0 or height <= 0 then 
		return false
	end 

	local dstWidth, dstHeight = self.Width, self.Height
	local xStart, yStart, xEnd, yEnd = compute_BoundingBox(dstWidth, dstHeight, x, y, width, height)
	if xStart >= xEnd or yStart >= yEnd then
		return false
	end
	
	local b = self.Buffer
	local shader = compileShader(self, x, y, width, height, ...)
	for py = yStart, yEnd - 1 do
		local rowOffset = py * dstWidth
		for px = xStart, xEnd - 1 do
			local offset = 4 * (rowOffset + px)
			buffer_writeu32(b, py * dstWidth + px, shader(px, py))
		end
	end

	return true
end

--[[
	Draws a rectangle, top-left to bottom-right, at the given (x, y) coordinate with the given width and height and blends pixels with the given color.
]]
function Module.fill_Blend(self: Canvas,
	x: number, y: number,
	width: number, height: number,
	color: number
): boolean
	if width <= 0 or height <= 0 then
		return false
	end

	local dstWidth, dstHeight = self.Width, self.Height
	local xStart, yStart, xEnd, yEnd = compute_BoundingBox(dstWidth, dstHeight, x, y, width, height)
	if xStart >= xEnd or yStart >= yEnd then
		return false
	end
	
	local b = self.Buffer
	for py = yStart, yEnd - 1 do
		local rowOffset = py * dstWidth
		for px = xStart, xEnd - 1 do
			local offset = 4 * (rowOffset + px)
			buffer_writeu32(b, offset, compute_Blend(color, buffer_readu32(b, offset)))
		end
	end

	return true
end

--[[
	Draws a rectangle, top-left to bottom-right, at the given (x, y) coordinate with the given width and height and overwrites pixels with the given color.
]]
function Module.fill_Overwrite(self: Canvas,
	x: number, y: number,
	width: number, height: number,
	color: number
): boolean
	if width <= 0 or height <= 0 then
		return false
	end

	local dstWidth, dstHeight = self.Width, self.Height
	local xStart, yStart, xEnd, yEnd = compute_BoundingBox(dstWidth, dstHeight, x, y, width, height)
	if xStart >= xEnd or yStart >= yEnd then
		return false
	end
	
	local b = self.Buffer
	
	xStart *= 4
	local count = (xEnd - xStart)
	local rowStride = dstWidth * 4
	for py = yStart, yEnd - 1 do
		local offset = py * rowStride + xStart
		buffer_writeu32(b, offset, color)
		buffer_rep(b, offset, 4, count)
	end

	return true
end

--[[
	Outlines a rectangle, top-left to bottom-right, at the given (x, y) coordinate with the given width and height and blends pixels with the given color.
]]
function Module.outline_Blend(self: Canvas,
	x: number, y: number,
	width: number, height: number,
	color: number
): boolean
	if width <= 0 or height <= 0 then
		return false
	end

	local dstWidth, dstHeight = self.Width, self.Height
	local xStart, yStart, xEnd, yEnd = compute_BoundingBox(dstWidth, dstHeight, x, y, width, height)
	if xStart >= xEnd or yStart >= yEnd then
		return false
	end
	
	local b = self.Buffer
	local rowStride = dstWidth * 4

	-- Top & bottom edges

	yEnd -= 1
	for x0 = xStart, xEnd - 1 do
		local topOff = yStart * rowStride + x0 * 4
		buffer_writeu32(b, topOff, compute_Blend(buffer_readu32(b, topOff), color))

		if yEnd - 1 ~= yStart then
			local botOff = (yEnd - 1) * rowStride + x0 * 4
			buffer_writeu32(b, botOff, compute_Blend(buffer_readu32(b, botOff), color))
		end
	end

	-- Vertical edges

	xEnd -= 1
	for y0 = yStart + 1, yEnd - 1 do
		local row = y0 * rowStride

		local leftOff = row + xStart * 4
		buffer_writeu32(b, leftOff, compute_Blend(buffer_readu32(b, leftOff), color))

		if xEnd ~= xStart then
			local rightOff = row + xEnd * 4
			buffer_writeu32(b, rightOff, compute_Blend(buffer_readu32(b, rightOff), color))
		end
	end

	return true
end

--[[
	Outlines a rectangle, top-left to bottom-right, at the given (x, y) coordinate with the given width and height and blends pixels with color given by a shader function.
]]
function Module.outline_BlendShader(self: Canvas,
	x: number, y: number,
	width: number, height: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	if width <= 0 or height <= 0 then
		return false
	end

	local dstWidth, dstHeight = self.Width, self.Height
	local xStart, yStart, xEnd, yEnd = compute_BoundingBox(dstWidth, dstHeight, x, y, width, height)
	if xStart >= xEnd or yStart >= yEnd then
		return false
	end

	local b = self.Buffer
	local shader = compileShader(self, x, y, width, height, ...)
	local rowStride = dstWidth * 4

	-- Top & bottom edges

	yEnd -= 1
	for x = xStart, xEnd - 1 do
		local topOff = yStart * rowStride + x * 4
		buffer_writeu32(b, topOff, compute_Blend(buffer_readu32(b, topOff), shader(x, yStart)))

		if yEnd - 1 ~= yStart then
			local botOff = (yEnd - 1) * rowStride + x * 4
			buffer_writeu32(b, botOff, compute_Blend(buffer_readu32(b, botOff), shader(x, yStart)))
		end
	end

	-- Vertical edges

	xEnd -= 1
	for y = yStart + 1, yEnd - 1 do
		local row = y * rowStride
		local leftOff = row + xStart * 4
		buffer_writeu32(b, leftOff, compute_Blend(buffer_readu32(b, leftOff), shader(xStart, y)))

		if xEnd ~= xStart then
			local rightOff = row + xEnd * 4
			buffer_writeu32(b, rightOff, compute_Blend(buffer_readu32(b, rightOff), shader(xStart, y)))
		end
	end

	return true
end

--[[
	Outlines a rectangle, top-left to bottom-right, at the given (x, y) coordinate with the given width and height and overwrites pixels with the given color.
]]
function Module.outline_Overwrite(self: Canvas,
	x: number, y: number,
	width: number, height: number,
	color: number
): boolean
	if width <= 0 or height <= 0 then
		return false
	end

	local dstWidth, dstHeight = self.Width, self.Height
	local xStart, yStart, xEnd, yEnd = compute_BoundingBox(dstWidth, dstHeight, x, y, width, height)
	if xStart >= xEnd or yStart >= yEnd then
		return false
	end
	
	local b = self.Buffer
	local count = (xEnd - xStart)
	local rowStride = dstWidth * 4

	local offset =  yStart * rowStride + xStart * 4
	buffer_writeu32(b, offset, color)
	buffer_rep(b, offset, 4, count)

	yEnd -= 1
	if yEnd ~= yStart then
		local offset = yEnd * rowStride + xStart * 4
		buffer_writeu32(b, offset, color)
		buffer_rep(b, offset, 4, count)
	end

	xEnd -= 1
	for y0 = yStart + 1, yEnd - 1 do
		local row = y0 * rowStride
		buffer_writeu32(b, row + xStart * 4, color)
		if xEnd ~= xStart then
			buffer_writeu32(b, row + xEnd * 4, color)
		end
	end

	return true
end

--[[
	Outlines a rectangle, top-left to bottom-right, at the given (x, y) coordinate with the given width and height and overwrites pixels with color given by a shader function.
]]
function Module.outline_OverwriteShader(self: Canvas,
	x: number, y: number,
	width: number, height: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	if width <= 0 or height <= 0 then
		return false
	end

	local dstWidth, dstHeight = self.Width, self.Height
	local xStart, yStart, xEnd, yEnd = compute_BoundingBox(dstWidth, dstHeight, x, y, width, height)
	if xStart >= xEnd or yStart >= yEnd then
		return false
	end
	
	local b = self.Buffer
	local shader = compileShader(self, x, y, width, height, ...)
	local rowStride = dstWidth * 4

	-- Top & bottom edges

	yEnd -= 1
	for x = xStart, xEnd - 1 do
		local color = shader(x, yStart)
		
		local topOff = yStart * rowStride + x * 4
		buffer_writeu32(b, topOff, color)

		if yEnd - 1 ~= yStart then
			local botOff = (yEnd - 1) * rowStride + x * 4
			buffer_writeu32(b, botOff, color)
		end
	end

	-- Vertical edges

	xEnd -= 1
	for y = yStart + 1, yEnd - 1 do
		local color = shader(xStart, y)
		
		local row = y * rowStride
		local leftOff = row + xStart * 4
		buffer_writeu32(b, leftOff, color)

		if xEnd ~= xStart then
			local rightOff = row + xEnd * 4
			buffer_writeu32(b, rightOff, color)
		end
	end

	return true
end


-- -- End

return Module
