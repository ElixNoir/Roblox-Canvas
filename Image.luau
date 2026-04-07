--- Author: COMT

--!native
--!optimize 2
--!strict

--[[

	Canvas - A module all about writing images.
	Mod: Image

]]


-- -- State

local Canvas = require(script.Parent)
type Canvas = Canvas.Canvas

local Module = {}


-- -- Helpers

local buffer_copy = buffer.copy
local buffer_readu32 = buffer.readu32
local buffer_writeu32 = buffer.writeu32

local math_abs = math.abs
local math_ceil = math.ceil
local math_clamp = math.clamp
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_round = math.round
local math_sin = math.sin

local Canvas_compute_Blend = Canvas.compute_Blend
local Canvas_buffer_rep = Canvas.buffer_rep


-- -- Methods

--[[
	Draws an image on the canvas, blending the overlapping pixels.
]]
function Module.fill_Blend(
	self: Canvas,
	dstX: number,
	dstY: number,
	src: Canvas,
	srcX: number,
	srcY: number,
	width: number,
	height: number
): boolean
	if width <= 0 or height <= 0 then
		return false
	end

	local dstBuf = self.Buffer
	local srcBuf = src.Buffer

	local dstW = self.Width
	local dstH = self.Height
	local srcW = src.Width
	local srcH = src.Height

	-- Clip left/top

	if dstX < 0 then
		srcX -= dstX
		width += dstX
		dstX = 0
	end

	if dstY < 0 then
		srcY -= dstY
		height += dstY
		dstY = 0
	end

	-- Clip right/bottom

	if dstX + width > dstW then
		width = dstW - dstX
	end

	if dstY + height > dstH then
		height = dstH - dstY
	end

	if srcX + width > srcW then
		width = srcW - srcX
	end

	if srcY + height > srcH then
		height = srcH - srcY
	end

	-- Write

	dstX *= 4
	dstY *= 4
	srcX *= 4
	srcY *= 4
	local q = width * 4 - 1
	for y = 0, height * 4 - 1 do
		local dstRow = (dstY + y) * dstW + dstX
		local srcRow = (srcY + y) * srcW + srcX

		for x = 0, q, 4 do
			local di = dstRow + x
			buffer_writeu32(dstBuf, di, Canvas_compute_Blend(buffer_readu32(srcBuf, srcRow + x), buffer_readu32(dstBuf, di)))
		end
	end

	return true
end

--[[
	Draws an image on the canvas, overwriting the overlapping pixels.
]]
function Module.fill_Overwrite(
	self: Canvas,
	dstX: number,
	dstY: number,
	src: Canvas,
	srcX: number,
	srcY: number,
	width: number,
	height: number
): boolean
	if width <= 0 or height <= 0 then
		return false
	end

	local dstBuf = self.Buffer
	local srcBuf = src.Buffer

	local dstW = self.Width
	local dstH = self.Height
	local srcW = src.Width
	local srcH = src.Height

	-- Clip left/top

	if dstX < 0 then
		srcX -= dstX
		width += dstX
		dstX = 0
	end

	if dstY < 0 then
		srcY -= dstY
		height += dstY
		dstY = 0
	end

	-- Clip right/bottom

	if dstX + width > dstW then
		width = dstW - dstX
	end

	if dstY + height > dstH then
		height = dstH - dstY
	end

	if srcX + width > srcW then
		width = srcW - srcX
	end

	if srcY + height > srcH then
		height = srcH - srcY
	end

	-- Write

	dstX *= 4
	dstY *= 4
	srcX *= 4
	srcY *= 4
	local rowBytes = width * 4
	for y = 0, height * 4 - 1, 4 do
		buffer_copy(
			dstBuf,
			(dstY + y) * dstW + dstX,
			srcBuf,
			(srcY + y) * srcW + srcX,
			rowBytes
		)
	end

	return true
end

--[[
	Draws an image on the canvas, overwriting the overlapping pixels.  Uses a buffer as the source and does not boundary check.
]]
function Module.fill_Overwrite_FromRaw_Unsafe(
	self: Canvas,
	dstX: number,
	dstY: number,
	srcBuf: buffer,
	srcPosition: number,
	width: number,
	height: number
)
	local dstBuf = self.Buffer
	local dstWidth = self.Width
	local dstHeight = self.Height
	
	local pixelWidth = width * 4
	for y = 0, height - 1 do
		buffer_copy(
			dstBuf,
			((y + dstY) * dstWidth + dstX) * 4,
			srcBuf,
			srcPosition + y * width,
			pixelWidth
		)
	end
end

local function fillTexturedTriangle_Blend(
	self: Canvas, src: Canvas,
	x1: number, y1: number, x2: number, y2: number, x3: number, y3: number,
	u1: number, v1: number, u2: number, v2: number, u3: number, v3: number
)
	local dstBuf = self.Buffer
	local srcBuf = src.Buffer
	local width, height = self.Width, self.Height
	local srcWidth, srcHeight = src.Width, src.Height

	if y1 > y2 then x1, y1, u1, v1, x2, y2, u2, v2 = x2, y2, u2, v2, x1, y1, u1, v1 end
	if y2 > y3 then x2, y2, u2, v2, x3, y3, u3, v3 = x3, y3, u3, v3, x2, y2, u2, v2 end
	if y1 > y2 then x1, y1, u1, v1, x2, y2, u2, v2 = x2, y2, u2, v2, x1, y1, u1, v1 end

	local function drawFlatTriangle(
		topX: number, topY: number, topU: number, topV: number,
		midX: number, midY: number, midU: number, midV: number,
		botX: number, botY: number, botU: number, botV: number
	)
		local dy1 = botY - topY
		local dy2 = midY - topY
		if dy1 == 0 then
			return
		end

		for y = math_max(math_floor(topY), 0), math_min(math_floor(botY), height - 1) do
			local t1 = (y - topY) / dy1
			local t2 = (y - topY) / dy2

			local xl = topX + (botX - topX) * t1
			local xr = topX + (midX - topX) * t2
			local ul = topU + (botU - topU) * t1
			local vl = topV + (botV - topV) * t1
			local ur = topU + (midU - topU) * t2
			local vr = topV + (midV - topV) * t2

			if xl > xr then
				xl, xr = xr, xl
				ul, ur = ur, ul
				vl, vr = vr, vl
			end

			local xStart = math_max(math_floor(xl), 0)
			local xEnd   = math_min(math_floor(xr), width - 1)
			local dx = xr - xl
			if dx == 0 then
				continue
			end

			local du = (ur - ul) / dx
			local dv = (vr - vl) / dx

			local u = ul
			local v = vl

			for x = xStart, xEnd do
				local color = buffer_readu32(srcBuf, math_floor(v * (srcHeight - 1)) * srcWidth + math_floor(u * (srcWidth - 1)))
				local offset = y * width + x
				buffer_writeu32(dstBuf, offset, Canvas_compute_Blend(color, buffer_readu32(dstBuf, offset)))
				u = u + du
				v = v + dv
			end
		end
	end

	if y2 == y3 then
		drawFlatTriangle(x1, y1, u1, v1, x2, y2, u2, v2, x3, y3, u3, v3)
	elseif y1 == y2 then
		drawFlatTriangle(x3, y3, u3, v3, x1, y1, u1, v1, x2, y2, u2, v2)
	else
		local t = (y2 - y1) / (y3 - y1)
		local vx = x1 + (x3 - x1) * t
		local vu = u1 + (u3 - u1) * t
		local vv = v1 + (v3 - v1) * t

		drawFlatTriangle(x1, y1, u1, v1, x2, y2, u2, v2, vx, y2, vu, vv)
		drawFlatTriangle(x3, y3, u3, v3, x2, y2, u2, v2, vx, y2, vu, vv)
	end
end Module.fillTexturedTriangle_Blend = fillTexturedTriangle_Blend

local function fillTexturedTriangle_Overwrite(
	self: Canvas, src: Canvas,
	x1: number, y1: number, x2: number, y2: number, x3: number, y3: number,
	u1: number, v1: number, u2: number, v2: number, u3: number, v3: number
)
	local dstBuf = self.Buffer
	local srcBuf = src.Buffer
	local width, height = self.Width, self.Height
	local srcWidth, srcHeight = src.Width, src.Height

	if y1 > y2 then x1, y1, u1, v1, x2, y2, u2, v2 = x2, y2, u2, v2, x1, y1, u1, v1 end
	if y2 > y3 then x2, y2, u2, v2, x3, y3, u3, v3 = x3, y3, u3, v3, x2, y2, u2, v2 end
	if y1 > y2 then x1, y1, u1, v1, x2, y2, u2, v2 = x2, y2, u2, v2, x1, y1, u1, v1 end

	local function drawFlatTriangle(
		topX: number, topY: number, topU: number, topV: number,
		midX: number, midY: number, midU: number, midV: number,
		botX: number, botY: number, botU: number, botV: number
	)
		local dy1 = botY - topY
		local dy2 = midY - topY
		if dy1 == 0 then
			return
		end

		for y = math_max(math_floor(topY), 0), math_min(math_floor(botY), height - 1) do
			local t1 = (y - topY) / dy1
			local t2 = (y - topY) / dy2

			local xl = topX + (botX - topX) * t1
			local xr = topX + (midX - topX) * t2
			local ul = topU + (botU - topU) * t1
			local vl = topV + (botV - topV) * t1
			local ur = topU + (midU - topU) * t2
			local vr = topV + (midV - topV) * t2

			if xl > xr then
				xl, xr = xr, xl
				ul, ur = ur, ul
				vl, vr = vr, vl
			end

			local xStart = math_max(math_floor(xl), 0)
			local xEnd   = math_min(math_floor(xr), width - 1)
			local dx = xr - xl
			if dx == 0 then
				continue
			end

			local du = (ur - ul) / dx
			local dv = (vr - vl) / dx

			local u = ul
			local v = vl

			for x = xStart, xEnd do
				local color = buffer_readu32(srcBuf, math_floor(v * (srcHeight - 1)) * srcWidth + math_floor(u * (srcWidth - 1)))
				buffer_writeu32(dstBuf, y * width + x, color)
				u = u + du
				v = v + dv
			end
		end
	end

	if y2 == y3 then
		drawFlatTriangle(x1, y1, u1, v1, x2, y2, u2, v2, x3, y3, u3, v3)
	elseif y1 == y2 then
		drawFlatTriangle(x3, y3, u3, v3, x1, y1, u1, v1, x2, y2, u2, v2)
	else
		local t = (y2 - y1) / (y3 - y1)
		local vx = x1 + (x3 - x1) * t
		local vu = u1 + (u3 - u1) * t
		local vv = v1 + (v3 - v1) * t

		drawFlatTriangle(x1, y1, u1, v1, x2, y2, u2, v2, vx, y2, vu, vv)
		drawFlatTriangle(x3, y3, u3, v3, x2, y2, u2, v2, vx, y2, vu, vv)
	end
end Module.fillTexturedTriangle_Overwrite = fillTexturedTriangle_Overwrite

function Module.fillRotatedImage_Blend(
	self: Canvas, src: Canvas,
	angle: number,
	x: number, y: number,
	pivot_X: number, pivot_Y: number,
	scale_X: number, scale_Y: number
)
	local width, height = src.Width * scale_X, src.Height * scale_Y
	pivot_X, pivot_Y = x + pivot_X * width, y + pivot_Y * height
	local cosine = math_cos(angle)
	local sine = math_sin(angle)

	local dx: number, dy: number
	dx, dy = x - pivot_X, y - pivot_Y
	local X0, Y0 = cosine * dx - sine * dy + pivot_X, sine * dx + cosine * dy + pivot_Y
	dx = x + width - pivot_X
	local X1, Y1 = cosine * dx - sine * dy + pivot_X, sine * dx + cosine * dy + pivot_Y
	dy = y + height - pivot_Y
	local X2, Y2 = cosine * dx - sine * dy + pivot_X, sine * dx + cosine * dy + pivot_Y
	dx = x - pivot_X
	local X3, Y3 = cosine * dx - sine * dy + pivot_X, sine * dx + cosine * dy + pivot_Y

	fillTexturedTriangle_Blend(
		self, src,
		X0, Y0, X1, Y1, X2, Y2,
		0, 0, 1, 0, 1, 1
	)
	fillTexturedTriangle_Blend(
		self, src,
		X0, Y0, X2, Y2, X3, Y3,
		0, 0, 1, 1, 0, 1
	)
end

function Module.fillRotatedImage_Overwrite(
	self: Canvas, src: Canvas,
	angle: number,
	x: number, y: number,
	pivot_X: number, pivot_Y: number,
	scale_X: number, scale_Y: number
)
	local width, height = src.Width * scale_X, src.Height * scale_Y
	pivot_X, pivot_Y = x + pivot_X * width, y + pivot_Y * height
	local cosine = math_cos(angle)
	local sine = math_sin(angle)

	local dx: number, dy: number
	dx, dy = x - pivot_X, y - pivot_Y
	local X0, Y0 = cosine * dx - sine * dy + pivot_X, sine * dx + cosine * dy + pivot_Y
	dx = x + width - pivot_X
	local X1, Y1 = cosine * dx - sine * dy + pivot_X, sine * dx + cosine * dy + pivot_Y
	dy = y + height - pivot_Y
	local X2, Y2 = cosine * dx - sine * dy + pivot_X, sine * dx + cosine * dy + pivot_Y
	dx = x - pivot_X
	local X3, Y3 = cosine * dx - sine * dy + pivot_X, sine * dx + cosine * dy + pivot_Y

	fillTexturedTriangle_Overwrite(
		self, src,
		X0, Y0, X1, Y1, X2, Y2,
		0, 0, 1, 0, 1, 1
	)
	fillTexturedTriangle_Overwrite(
		self, src,
		X0, Y0, X2, Y2, X3, Y3,
		0, 0, 1, 1, 0, 1
	)
end

--[[
	Repeat the src canvas image count times in the x and y directions.
]]
function Module.repeat_Square(self: Canvas, src: Canvas, offset: number, count: number)
	local dst_Buffer = self.Buffer
	local dst_Width = self.Width
	local src_Buffer = src.Buffer
	local src_Height = src.Height
	local src_Width = src.Width
	local q = src_Width * 4

	for y = 0, (src_Height - 1) * 4, 4 do
		local offset = offset + dst_Width * y
		buffer_copy(dst_Buffer, offset, src_Buffer, src_Width * y, q)
		Canvas_buffer_rep(dst_Buffer, offset, q, count)
	end

	Canvas_buffer_rep(dst_Buffer, offset, dst_Width * src_Height * 4, count)
end

--[[
	Repeat the src canvas image count times in the x direction.
]]
function Module.repeat_X(self: Canvas, src: Canvas, offset: number, count: number)
	local dst_Buffer = self.Buffer
	local dst_Width = self.Width
	local src_Buffer = src.Buffer
	local src_Width = src.Width
	local q = src_Width * 4

	for y = 0, (src.Height - 1) * 4, 4 do
		local offset = offset + dst_Width * y
		buffer_copy(dst_Buffer, offset, src_Buffer, src_Width * y, q)
		Canvas_buffer_rep(dst_Buffer, offset, q, count)
	end
end


-- -- End

return Module
