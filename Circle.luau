--- Author: COMT

--[[

	Canvas - A module all about writing images.
	Mod: Circle

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
	radius: number,
	dstWidth: number, dstHeight: number,
	...any
) -> Shader


-- -- Helpers

local buffer_readu32 = buffer.readu32
local buffer_rep = Canvas.buffer_rep
local buffer_writeu32 = buffer.writeu32

local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt

local compute_Blend = Canvas.compute_Blend

--[[
	Draws a circle centered at (cx, cy) with the given radius and blends pixels with color given by a shader function.
]]
function Module.draw_Blend(
	self: Canvas,
	cx: number, cy: number,
	radius: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	if radius <= 0 then
		return false
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local shader = compileShader(self, cx, cy, radius, dstWidth, dstHeight, ...)
	local x = radius
	local y = 0
	local err = 1 - x

	local function plot(px, py)
		if px >= 0 and px < dstWidth and py >= 0 and py < dstHeight then
			local offset = (py * dstWidth + px) * 4
			buffer_writeu32(b, offset, compute_Blend(shader(px, py), buffer_readu32(b, offset)))
		end
	end

	while x >= y do
		plot(cx + x, cy + y)
		plot(cx + y, cy + x)
		plot(cx - y, cy + x)
		plot(cx - x, cy + y)
		plot(cx - x, cy - y)
		plot(cx - y, cy - x)
		plot(cx + y, cy - x)
		plot(cx + x, cy - y)

		y += 1
		if err < 0 then
			err += 2 * y + 1
		else
			x -= 1
			err += 2 * (y - x) + 1
		end
	end

	return true
end

--[[
	Draws a circle centered at (cx, cy) with the given radius and overwrites pixels with the given color.
]]
function Module.draw_Overwrite(
	self: Canvas,
	cx: number, cy: number,
	radius: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	if radius <= 0 then
		return false
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local shader = compileShader(self, cx, cy, radius, dstWidth, dstHeight, ...)
	local x = radius
	local y = 0
	local err = 1 - x

	local function plot(px, py)
		if px >= 0 and px < dstWidth and py >= 0 and py < dstHeight then
			buffer_writeu32(b, (py * dstWidth + px) * 4, shader(px, py))
		end
	end

	while x >= y do
		plot(cx + x, cy + y)
		plot(cx + y, cy + x)
		plot(cx - y, cy + x)
		plot(cx - x, cy + y)
		plot(cx - x, cy - y)
		plot(cx - y, cy - x)
		plot(cx + y, cy - x)
		plot(cx + x, cy - y)

		y += 1
		if err < 0 then
			err += 2 * y + 1
		else
			x -= 1
			err += 2 * (y - x) + 1
		end
	end

	return true
end

--[[
	Draws a circle centered at (cx, cy) with the given radius and blends pixels with the given color.
]]
function Module.fill_Blend(
	self: Canvas,
	cx: number, cy: number,
	radius: number,
	color: number
): boolean
	if radius <= 0 then
		return false
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local r2 = radius * radius
	local yStart = math_max(cy - radius, 0)
	local yEnd   = math_min(cy + radius, dstHeight - 1)
	for y = yStart, yEnd do
		local dy = y - cy
		local dxMax = math_sqrt(r2 - dy * dy) // 1

		local x0 = math_max(cx - dxMax, 0)
		local x1 = math_min(cx + dxMax, dstWidth - 1)

		for x = x0, x1 do
			local offset = (y * dstWidth + x) * 4
			buffer_writeu32(
				b,
				offset,
				compute_Blend(color, buffer_readu32(b, offset))
			)
		end
	end

	return true
end

--[[
	Draws a circle centered at (cx, cy) with the given radius and overwrites pixels with the given color.
]]
function Module.fill_Overwrite(
	self: Canvas,
	cx: number, cy: number,
	radius: number,
	color: number
): boolean
	if radius <= 0 then
		return false
	end

	local b = self.Buffer
	local w, h = self.Width, self.Height
	local r2 = radius * radius
	local stride = w * 4
	local yStart = math_max(cy - radius, 0)
	local yEnd = math_min(cy + radius, h - 1)
	for y = yStart, yEnd do
		local dy = y - cy
		local dxMax = math_sqrt(r2 - dy * dy) // 1

		local x0 = math_max(cx - dxMax, 0)
		local x1 = math_min(cx + dxMax, w - 1)

		local offset = (y * w + x0) * 4
		buffer_writeu32(b, offset, color)
		buffer_rep(b, offset, 4, x1 - x0 + 1)
	end

	return true
end


-- -- End

return Module
