--- Author: COMT

--[[

	Canvas - A module all about writing images.
	Mod: Triangle

]]

--!native
--!optimize 2
--!strict


-- -- State

local Canvas = require(script.Parent)
type Canvas = Canvas.Canvas
local Line = require(script.Parent.Line)

local Module = {}

export type Shader = (
	x: number, y: number,
	w12: number, w23: number, w31: number
) -> number

export type ShaderCompiler = (
	canvas: Canvas.Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number,
	dstWidth: number, dstHeight: number,
	...any
) -> Shader


-- -- Helpers

local bit32_band = bit32.band
local bit32_bor = bit32.bor
local bit32_lshift = bit32.lshift
local bit32_rshift = bit32.rshift

local buffer_readu32 = buffer.readu32
local buffer_writeu32 = buffer.writeu32

local math_clamp = math.clamp
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt

local compute_Blend = Canvas.compute_Blend

--[[
	Computes the clipped bounding box of a triangle with the given canvas size (dstWidth, dstHeight) and vertices.
	returns: (minX, minY, maxX, minY)
]]
local function compute_BoundingBox(
	dstWidth: number, dstHeight: number,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number
): (number, number, number, number)
	return math_max(0, math_min(x1, x2, x3)), math_max(0, math_min(y1, y2, y3)), math_min(dstWidth - 1, math_max(x1, x2, x3)), math_min(dstHeight - 1, math_max(y1, y2, y3))
end

Module.compute_BoundingBox = compute_BoundingBox

--[[
	returns: (area, A12, B12, C12, A23, B23, C23, A31, B31, C31)
]]
local function compute_EdgeCoefficients(
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number
): (number, number, number, number, number, number, number, number, number, number)
	local A12 = y2 - y1
	local B12 = x1 - x2
	local C12 = x2 * y1 - y2 * x1

	local A23 = y3 - y2
	local B23 = x2 - x3
	local C23 = x3 * y2 - y3 * x2

	local A31 = y1 - y3
	local B31 = x3 - x1
	local C31 = x1 * y3 - y1 * x3

	local area = A12 * x3 + B12 * y3 + C12
	if area < 0 then
		A12, B12, C12 = -A12, -B12, -C12
		A23, B23, C23 = -A23, -B23, -C23
		A31, B31, C31 = -A31, -B31, -C31
	end

	return area, A12, B12, C12, A23, B23, C23, A31, B31, C31
end

Module.compute_EdgeCoefficients = compute_EdgeCoefficients

--[[
	Draws a triangle between the given vertices and blends pixels with color given by a shader function in the order of the barymetric algorithm with anti-aliasing.
]]
function Module.draw_AABlend(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	local area, A12, B12, C12, A23, B23, C23, A31, B31, C31 = compute_EdgeCoefficients(x1, y1, x2, y2, x3, y3)
	if area == 0 then
		return false
	end

	-- Top-left flags
	local TL12 = (y2 - y1 == 0 and x1 > x2) or (y2 - y1 > 0)
	local TL23 = (y3 - y2 == 0 and x2 > x3) or (y3 - y2 > 0)
	local TL31 = (y1 - y3 == 0 and x3 > x1) or (y1 - y3 > 0)

	local e12 = 1 / math_sqrt(A12 * A12 + B12 * B12)
	local e23 = 1 / math_sqrt(A23 * A23 + B23 * B23)
	local e31 = 1 / math_sqrt(A31 * A31 + B31 * B31)

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local shader = compileShader(self, x1, y1, x2, y2, x3, y3, dstWidth, dstHeight, ...)
	local minX, minY, maxX, maxY = compute_BoundingBox(dstWidth, dstHeight, x1, y1, x2, y2, x3, y3)
	for y = minY, maxY do
		local px = minX + .5
		local py = y + .5

		local w12 = A12*px + B12*py + C12
		local w23 = A23*px + B23*py + C23
		local w31 = A31*px + B31*py + C31

		local rowOffset = y * dstWidth

		for x = minX, maxX do
			local inside12 = (w12 > 0) or (w12 == 0 and TL12)
			local inside23 = (w23 > 0) or (w23 == 0 and TL23)
			local inside31 = (w31 > 0) or (w31 == 0 and TL31)

			if inside12 and inside23 and inside31 then
				local c12 = math_clamp(w12 * e12 + .5, 0, 1)
				local c23 = math_clamp(w23 * e23 + .5, 0, 1)
				local c31 = math_clamp(w31 * e31 + .5, 0, 1)
				local coverage = math_min(c12, c23, c31)

				local offset = 4 * (rowOffset + x)
				local src = shader(x, y, w12, w23, w31)

				local sa = bit32_band(bit32_band(src, 0xFF) * coverage, 0xFF)
				local sb = bit32_band(bit32_band(src // 0x100, 0xFF) * coverage, 0xFF)
				local sg = bit32_band(bit32_band(src // 0x10000, 0xFF) * coverage, 0xFF)
				local sr = bit32_band(bit32_band(src // 0x1000000, 0xFF) * coverage, 0xFF)

				buffer_writeu32(b, offset, compute_Blend(bit32_bor(sa, sb * 0x100, sg * 0x10000, sr * 0x1000000), buffer_readu32(b, offset)))
			end
			
			w12 = w12 + A12
			w23 = w23 + A23
			w31 = w31 + A31
		end
	end

	return true
end

--[[
	Draws a triangle between the given vertices and blends pixels with color given by a shader function in the order of the barymetric algorithm.
]]
function Module.draw_Blend(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	local area, A12, B12, C12, A23, B23, C23, A31, B31, C31 = compute_EdgeCoefficients(x1, y1, x2, y2, x3, y3)
	if area == 0 then
		return false
	end
	
	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local shader = compileShader(self, x1, y1, x2, y2, x3, y3, dstWidth, dstHeight, ...)
	local minX, minY, maxX, maxY = compute_BoundingBox(dstWidth, dstHeight, x1, y1, x2, y2, x3, y3)
	for y = minY, maxY do
		local px = minX + .5
		local py = y + .5

		local w12 = A12 * px + B12 * py + C12
		local w23 = A23 * px + B23 * py + C23
		local w31 = A31 * px + B31 * py + C31

		local rowOffset = y * dstWidth

		for x = minX, maxX do
			if w12 >= 0 and w23 >= 0 and w31 >= 0 then
				local offset = 4 * (rowOffset + x)
				buffer_writeu32(b, offset, compute_Blend(shader(x, y, w12, w23, w31), buffer_readu32(b, offset)))
			end

			w12 += A12
			w23 += A23
			w31 += A31
		end
	end

	return true
end

--[[
	Draws a triangle between the given vertices and overwrites pixels with color given by a shader function in the order of the barymetric algorithm.
]]
function Module.draw_Overwrite(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	local area, A12, B12, C12, A23, B23, C23, A31, B31, C31 = compute_EdgeCoefficients(x1, y1, x2, y2, x3, y3)
	if area == 0 then
		return false
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local shader = compileShader(self, x1, y1, x2, y2, x3, y3, dstWidth, dstHeight, ...)
	local minX, minY, maxX, maxY = compute_BoundingBox(dstWidth, dstHeight, x1, y1, x2, y2, x3, y3)
	for y = minY, maxY do
		local px = minX + .5
		local py = y + .5

		local w12 = A12 * px + B12 * py + C12
		local w23 = A23 * px + B23 * py + C23
		local w31 = A31 * px + B31 * py + C31

		local rowOffset = y * dstWidth

		for x = minX, maxX do
			if w12 >= 0 and w23 >= 0 and w31 >= 0 then
				buffer_writeu32(b, 4 * (rowOffset + x), shader(x, y, w12, w23, w31))
			end

			w12 += A12
			w23 += A23
			w31 += A31
		end
	end

	return true
end

--[[
	Draws a triangle between the given vertices and blends pixels with the given color in the order of the barymetric algorithm.
]]
function Module.fill_Blend(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number,
	color: number
): boolean
	local sa = bit32_band(color // 0x1000000, 0xFF)
	if sa == 0 then
		return false
	end
	
	local area, A12, B12, C12, A23, B23, C23, A31, B31, C31 = compute_EdgeCoefficients(x1, y1, x2, y2, x3, y3)
	if area == 0 then
		return false
	end

	local sr = bit32_band(color, 0xFF)
	local sg = bit32_band(color // 0x100, 0xFF)
	local sb = bit32_band(color // 0x10000, 0xFF)
	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local minX, minY, maxX, maxY = compute_BoundingBox(dstWidth, dstHeight, x1, y1, x2, y2, x3, y3)
	for y = minY, maxY do
		local px = minX + .5
		local py = y + .5

		local w12 = A12 * px + B12 * py + C12
		local w23 = A23 * px + B23 * py + C23
		local w31 = A31 * px + B31 * py + C31

		local rowOffset = y * dstWidth

		for x = minX, maxX do
			if w12 >= 0 and w23 >= 0 and w31 >= 0 then
				local offset = 4 * (rowOffset + x)
				local dst = buffer_readu32(b, offset)

				local dr = bit32_band(dst, 0xFF)
				local dg = bit32_band(dst // 0x100, 0xFF)
				local db = bit32_band(dst // 0x10000, 0xFF)
				local da = bit32_band(dst // 0x1000000, 0xFF)

				local inv = 255 - sa

				buffer_writeu32(b, offset, bit32_bor(
					(sr * sa + dr * inv) // 0x100,
					((sg * sa + dg * inv) // 0x100) * 0x100,
					((sb * sa + db * inv) // 0x100) * 0x10000,
					((da * inv) // 0x100 + sa) * 0x1000000
				))
			end

			w12 += A12
			w23 += A23
			w31 += A31
		end
	end

	return true
end

--[[
	Draws a triangle between the given vertices and overwrites pixels with the given color in the order of the barymetric algorithm.
]]
function Module.fill_Overwrite(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number,
	color: number
): boolean
	local area, A12, B12, C12, A23, B23, C23, A31, B31, C31 = compute_EdgeCoefficients(x1, y1, x2, y2, x3, y3)
	if area == 0 then
		return false
	end
	
	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	local minX, minY, maxX, maxY = compute_BoundingBox(dstWidth, dstHeight, x1, y1, x2, y2, x3, y3)
	for y = minY, maxY do
		local px = minX + .5
		local py = y + .5

		local w12 = A12 * px + B12 * py + C12
		local w23 = A23 * px + B23 * py + C23
		local w31 = A31 * px + B31 * py + C31

		local rowOffset = y * dstWidth

		for x = minX, maxX do
			if w12 >= 0 and w23 >= 0 and w31 >= 0 then
				buffer_writeu32(b, 4 * (rowOffset + x), color)
			end

			w12 += A12
			w23 += A23
			w31 += A31
		end
	end

	return true
end

--[[
	Outlines a triangle between the given vertices and blends pixels with the given color.
]]
function Module.outline_Blend(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number,
	color: number
): boolean
	Line.fill_Blend(self, x1, y1, x2, y2, color)
	Line.fill_Blend(self, x2, y2, x3, y3, color)
	Line.fill_Blend(self, x3, y3, x1, y1, color)
	return true
end

--[[
	Outlines a triangle between the given vertices and blends pixels with color given by a shader function.
]]
function Module.outline_BlendShader(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number,
	compileShader: Line.ShaderCompiler,
	...: any
): boolean
	Line.draw_Blend(self, x1, y1, x2, y2, compileShader, ...)
	Line.draw_Blend(self, x2, y2, x3, y3, compileShader, ...)
	Line.draw_Blend(self, x3, y3, x1, y1, compileShader, ...)
	return true
end

--[[
	Outlines a triangle between the given vertices and overwrites pixels with the given color.
]]
function Module.outline_Overwrite(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number,
	color: number
): boolean
	Line.fill_Overwrite(self, x1, y1, x2, y2, color)
	Line.fill_Overwrite(self, x2, y2, x3, y3, color)
	Line.fill_Overwrite(self, x3, y3, x1, y1, color)
	return true
end

--[[
	Outlines a triangle between the given vertices and overwrites pixels with color given by a shader function.
]]
function Module.outline_OverwriteShader(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	x3: number, y3: number,
	compileShader: Line.ShaderCompiler,
	...: any
): boolean
	Line.draw_Overwrite(self, x1, y1, x2, y2, compileShader, ...)
	Line.draw_Overwrite(self, x2, y2, x3, y3, compileShader, ...)
	Line.draw_Overwrite(self, x3, y3, x1, y1, compileShader, ...)
	return true
end


-- -- End

return Module
