--- Author: COMT

--[[

	Canvas - A module all about writing images.
	Mod: Ellipse

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
	x1: number, y1: number, x2: number, y2: number,
	dstWidth: number, dstHeight: number,
	...any
) -> Shader


-- -- Helpers

local buffer_readu32 = buffer.readu32
local buffer_rep = Canvas.buffer_rep
local buffer_writeu32 = buffer.writeu32

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt

local compute_Blend = Canvas.compute_Blend

--[[
	Draws an ellipse around two points and blends pixels with color given by a shader function.
]]
function Module.draw_Blend(
	self: Canvas, 
	x1: number, y1: number,
	x2: number, y2: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	local left = math_min(x1, x2)
	local right = math_max(x1, x2)
	local top = math_min(y1, y2)
	local bottom = math_max(y1, y2)
	local rx = (right - left) // 2
	local ry = (bottom - top) // 2
	if rx <= 0 or ry <= 0 then
		return false
	end

	local cx = left + rx
	local cy = top + ry
	local rx2 = rx * rx
	local ry2 = ry * ry
	local x = 0
	local y = ry
	local dx = 0
	local dy = 2 * rx2 * y
	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local shader = compileShader(self, x1, y1, x2, y2, dstWidth, dstHeight, ...)
	
	local function plot(px, py)
		if px >= 0 and px < dstWidth and py >= 0 and py < dstHeight then
			local offset = (py * dstWidth + px) * 4
			buffer_writeu32(b, offset, compute_Blend(shader(px, py), buffer_readu32(b, offset)))
		end
	end

	local err = ry2 - rx2 * ry + rx2 * 0.25
	while dx < dy do
		plot(cx + x, cy + y)
		plot(cx - x, cy + y)
		plot(cx + x, cy - y)
		plot(cx - x, cy - y)

		x += 1
		dx += 2 * ry2
		if err < 0 then
			err += ry2 + dx
		else
			y -= 1
			dy -= 2 * rx2
			err += ry2 + dx - dy
		end
	end

	err = ry2 * (x + 0.5)^2 + rx2 * (y - 1)^2 - rx2 * ry2
	while y >= 0 do
		plot(cx + x, cy + y)
		plot(cx - x, cy + y)
		plot(cx + x, cy - y)
		plot(cx - x, cy - y)

		y -= 1
		dy -= 2 * rx2
		if err > 0 then
			err += rx2 - dy
		else
			x += 1
			dx += 2 * ry2
			err += rx2 - dy + dx
		end
	end

	return true
end

--[[
	Draws an ellipse around two points and overwrites pixels with color given by a shader function.
]]
function Module.draw_Overwrite(
	self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	local left = math_min(x1, x2)
	local right = math_max(x1, x2)
	local top = math_min(y1, y2)
	local bottom = math_max(y1, y2)
	local rx = (right - left) // 2
	local ry = (bottom - top) // 2
	if rx <= 0 or ry <= 0 then
		return false
	end

	local cx = left + rx
	local cy = top + ry
	local rx2 = rx * rx
	local ry2 = ry * ry
	local x = 0
	local y = ry
	local dx = 0
	local dy = 2 * rx2 * y
	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local shader = compileShader(self, x1, y1, x2, y2, dstWidth, dstHeight, ...)

	local function plot(px, py)
		if px >= 0 and px < dstWidth and py >= 0 and py < dstHeight then
			buffer_writeu32(b, (py * dstWidth + px) * 4, shader(px, py))
		end
	end

	local err = ry2 - rx2 * ry + rx2 * 0.25
	while dx < dy do
		plot(cx + x, cy + y)
		plot(cx - x, cy + y)
		plot(cx + x, cy - y)
		plot(cx - x, cy - y)

		x += 1
		dx += 2 * ry2
		if err < 0 then
			err += ry2 + dx
		else
			y -= 1
			dy -= 2 * rx2
			err += ry2 + dx - dy
		end
	end

	err = ry2 * (x + 0.5)^2 + rx2 * (y - 1)^2 - rx2 * ry2
	while y >= 0 do
		plot(cx + x, cy + y)
		plot(cx - x, cy + y)
		plot(cx + x, cy - y)
		plot(cx - x, cy - y)

		y -= 1
		dy -= 2 * rx2
		if err > 0 then
			err += rx2 - dy
		else
			x += 1
			dx += 2 * ry2
			err += rx2 - dy + dx
		end
	end

	return true
end

--[[
	Draws an ellipse around two points and blends pixels with the given color.
]]
function Module.fill_Blend(
	self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	color: number
): boolean
	local left = math_min(x1, x2)
	local right = math_max(x1, x2)
	local top = math_min(y1, y2)
	local bottom = math_max(y1, y2)
	local rx = (right - left) // 2
	local ry = (bottom - top) // 2
	if rx <= 0 or ry <= 0 then
		return false
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local cx = left + rx
	local cy = top + ry
	local invRx2 = 1 / (rx * rx)
	local invRy2 = 1 / (ry * ry)
	local yStart = math_max(top, 0)
	local yEnd   = math_min(bottom, dstHeight - 1)
	for y = yStart, yEnd do
		local dy = y - cy
		local t = 1 - (dy * dy) * invRy2
		if t >= 0 then
			local dx = math_sqrt(t / invRx2)

			local x0 = math_max(math_floor(cx - dx), 0)
			local x1 = math_min(math_floor(cx + dx), dstWidth - 1)

			for x = x0, x1 do
				local offset = (y * dstWidth + x) * 4
				buffer_writeu32(b, offset, compute_Blend(color, buffer_readu32(b, offset)))
			end
		end
	end

	return true
end

--[[
	Draws an ellipse around two points and overwrites pixels with the given color.
]]
function Module.fill_Overwrite(
	self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	color: number
): boolean
	local left = math_min(x1, x2)
	local right = math_max(x1, x2)
	local top = math_min(y1, y2)
	local bottom = math_max(y1, y2)
	local rx = (right - left) // 2
	local ry = (bottom - top) // 2
	if rx <= 0 or ry <= 0 then
		return false
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local cx = left + rx
	local cy = top + ry
	local invRx2 = 1 / (rx * rx)
	local invRy2 = 1 / (ry * ry)
	local yStart = math_max(top, 0)
	local yEnd   = math_min(bottom, dstHeight - 1)
	for y = yStart, yEnd do
		local dy = y - cy
		local t = 1 - (dy * dy) * invRy2
		if t >= 0 then
			local dx = math_sqrt(t / invRx2)

			local x0 = math_max(math_floor(cx - dx), 0)
			local x1 = math_min(math_floor(cx + dx), dstWidth - 1)

			local offset = (y * dstWidth + x0) * 4
			buffer_writeu32(b, offset, color)
			buffer_rep(b, offset, 4, (x1 - x0 + 1) * 4)
		end
	end

	return true
end

--[[
	Outlines an ellipse around two points and blends pixels with the given color.
]]
function Module.outline_Blend(self: Canvas.Canvas, x1: number, y1: number, x2: number, y2: number, color: number): boolean
	local left   = math_min(x1, x2)
	local right  = math_max(x1, x2)
	local top    = math_min(y1, y2)
	local bottom = math_max(y1, y2)

	local rx = (right - left) // 2
	local ry = (bottom - top) // 2
	if rx <= 0 or ry <= 0 then
		return false
	end

	local cx = left + rx
	local cy = top + ry

	local b = self.Buffer
	local w = self.Width
	local h = self.Height

	local function plot(x, y)
		if x >= 0 and x < w and y >= 0 and y < h then
			local offset = (y * w + x) * 4
			buffer_writeu32(b, offset, compute_Blend(color, buffer_readu32(b, offset)))
		end
	end

	local rx2 = rx * rx
	local ry2 = ry * ry

	-- Region 1
	local x = 0
	local y = ry
	local p1 = ry2 - rx2 * ry + .25 * rx2

	while ry2 * x <= rx2 * y do
		plot(cx + x, cy + y)
		plot(cx - x, cy + y)
		plot(cx + x, cy - y)
		plot(cx - x, cy - y)

		if p1 < 0 then
			x += 1
			p1 += 2 * ry2 * x + ry2
		else
			x += 1
			y -= 1
			p1 += 2 * ry2 * x - 2 * rx2 * y + ry2
		end
	end

	-- Region 2
	local p2 = ry2 * (x + .5)^2 + rx2 * (y - 1)^2 - rx2 * ry2

	while y >= 0 do
		plot(cx + x, cy + y)
		plot(cx - x, cy + y)
		plot(cx + x, cy - y)
		plot(cx - x, cy - y)

		if p2 > 0 then
			y -= 1
			p2 -= 2 * rx2 * y + rx2
		else
			y -= 1
			x += 1
			p2 += 2 * ry2 * x - 2 * rx2 * y + rx2
		end
	end

	return true
end

--[[
	Outlines an ellipse around two points and overwrites pixels with the given color.
]]
function Module.outline_Overwrite(self: Canvas.Canvas, x1: number, y1: number, x2: number, y2: number, color: number): boolean
	local left   = math_min(x1, x2)
	local right  = math_max(x1, x2)
	local top    = math_min(y1, y2)
	local bottom = math_max(y1, y2)

	local rx = (right - left) // 2
	local ry = (bottom - top) // 2
	if rx <= 0 or ry <= 0 then
		return false
	end

	local cx = left + rx
	local cy = top + ry

	local b = self.Buffer
	local w = self.Width
	local h = self.Height

	local function plot(x, y)
		if x >= 0 and x < w and y >= 0 and y < h then
			local offset = (y * w + x) * 4
			buffer_writeu32(b, offset, color)
		end
	end

	local rx2 = rx * rx
	local ry2 = ry * ry

	-- Region 1
	local x = 0
	local y = ry
	local p1 = ry2 - rx2 * ry + .25 * rx2

	while ry2 * x <= rx2 * y do
		plot(cx + x, cy + y)
		plot(cx - x, cy + y)
		plot(cx + x, cy - y)
		plot(cx - x, cy - y)

		if p1 < 0 then
			x += 1
			p1 += 2 * ry2 * x + ry2
		else
			x += 1
			y -= 1
			p1 += 2 * ry2 * x - 2 * rx2 * y + ry2
		end
	end

	-- Region 2
	local p2 = ry2 * (x + .5)^2 + rx2 * (y - 1)^2 - rx2 * ry2

	while y >= 0 do
		plot(cx + x, cy + y)
		plot(cx - x, cy + y)
		plot(cx + x, cy - y)
		plot(cx - x, cy - y)

		if p2 > 0 then
			y -= 1
			p2 -= 2 * rx2 * y + rx2
		else
			y -= 1
			x += 1
			p2 += 2 * ry2 * x - 2 * rx2 * y + rx2
		end
	end

	return true
end


-- -- End

return Module
