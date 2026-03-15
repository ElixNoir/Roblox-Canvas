--- Author: COMT

--[[

	Canvas - A module all about writing images.
	Mod: Function

]]

--!native
--!optimize 2
--!strict


-- -- State

local Canvas = require(script.Parent)
type Canvas = Canvas.Canvas

local Module = {}


-- -- Helpers

local buffer_readu32 = buffer.readu32
local buffer_writeu32 = buffer.writeu32

local math_cos = math.cos
local math_sin = math.sin

local compute_Blend = Canvas.compute_Blend


-- -- Methods

--[[
	Draws and blends color given by a function over cartesian coordinates.
]]
function Module.draw_Blend(self: Canvas, domain_Minimum: number, domain_Maximum: number, range_Minimum: number, range_Maximum: number, offset_X: number, offset_Y: number, fn: (x: number, y: number) -> number)
	local dstBuffer = self.Buffer
	local width, height = self.Width, self.Height
	local decWidth = width - 1
	local decHeight = height - 1
	for row = 0, decHeight do
		local rowOffset = row * width
		for column = 0, decWidth do
			local x = domain_Minimum + (column / (decWidth)) * (domain_Maximum - domain_Minimum) + offset_X
			local y = range_Maximum - (row / (decHeight)) * (range_Maximum - range_Minimum) + offset_Y
			local offset = rowOffset + column
			buffer_writeu32(dstBuffer, offset, compute_Blend(fn(x, y), buffer_readu32(dstBuffer, offset)))
		end
	end
end

--[[
	Draws and blends color given by a rotated function over cartesian coordinates.
]]
function Module.draw_Blend_Rotated(self: Canvas, domain_Minimum: number, domain_Maximum: number, range_Minimum: number, range_Maximum: number, offset_X: number, offset_Y: number, theta: number, fn: (x: number, y: number) -> number)
	local dstBuffer = self.Buffer
	local width, height = self.Width, self.Height
	local decWidth = width - 1
	local decHeight = height - 1
	for row = 0, decHeight do
		local rowOffset = row * width
		for column = 0, decWidth do
			local x = domain_Minimum + (column / (decWidth)) * (domain_Maximum - domain_Minimum) + offset_X
			local y = range_Maximum - (row / (decHeight)) * (range_Maximum - range_Minimum) + offset_Y
			local offset = rowOffset + column
			local cosine = math_cos(theta)
			local sine = math_sin(theta)
			x = x * cosine + y * sine
			y = y * cosine - x * sine
			buffer_writeu32(dstBuffer, offset, compute_Blend(fn(x, y), buffer_readu32(dstBuffer, offset)))
		end
	end
end

--[[
	Draws color given by a function over cartesian coordinates.
]]
function Module.draw_Overwrite(self: Canvas, domain_Minimum: number, domain_Maximum: number, range_Minimum: number, range_Maximum: number, offset_X: number, offset_Y: number, fn: (x: number, y: number) -> number)
	local dstBuffer = self.Buffer
	local width, height = self.Width, self.Height
	local decWidth = width - 1
	local decHeight = height - 1
	for row = 0, decHeight do
		local rowOffset = row * width
		for column = 0, decWidth do
			local x = domain_Minimum + (column / (decWidth)) * (domain_Maximum - domain_Minimum) + offset_X
			local y = range_Maximum - (row / (decHeight)) * (range_Maximum - range_Minimum) + offset_Y
			buffer_writeu32(dstBuffer, rowOffset + column, fn(x, y))
		end
	end
end

--[[
	Draws color given by a rotated function over cartesian coordinates.
]]
function Module.draw_Overwrite_Rotated(self: Canvas, domain_Minimum: number, domain_Maximum: number, range_Minimum: number, range_Maximum: number, offset_X: number, offset_Y: number, theta: number, fn: (x: number, y: number) -> number)
	local dstBuffer = self.Buffer
	local width, height = self.Width, self.Height
	local decWidth = width - 1
	local decHeight = height - 1
	for row = 0, decHeight do
		local rowOffset = row * width
		for column = 0, decWidth do
			local x = domain_Minimum + (column / (decWidth)) * (domain_Maximum - domain_Minimum) + offset_X
			local y = range_Maximum - (row / (decHeight)) * (range_Maximum - range_Minimum) + offset_Y
			local cosine = math_cos(theta)
			local sine = math_sin(theta)
			x = x * cosine + y * sine
			y = y * cosine - x * sine
			buffer_writeu32(dstBuffer, rowOffset + column, fn(x, y))
		end
	end
end


-- -- End

return Module
