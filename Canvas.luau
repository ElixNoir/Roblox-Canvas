--- Author: COMT

--!native
--!optimize 2
--!strict

--[[

	Canvas - A module all about writing images.
	
	Work in progress.
	- Anti-aliasing is not fully supported yet
	- There is no parallelization
	- Some shaders are missing because I'm too lazy to add them
	
	Notes:
	- Some code is not set into functions and it's pretty much entirely because I don't want to worry about runtime overhead.  Hate me all you want.  Lol.
	- Some variables are not really named very well.

]]


-- -- State

local AssetService = game:GetService("AssetService")

local Module = {}
Module.__index = Module

export type Canvas = typeof(setmetatable({} :: {
	Buffer: buffer,
	Content: Content,
	EditableImage: EditableImage,
	Width: number, Height: number
}, Module))


-- -- Helpers

local bit32_band = bit32.band
local bit32_bor = bit32.bor
local bit32_lshift = bit32.lshift
local bit32_rshift = bit32.rshift

local buffer_copy = buffer.copy
local buffer_create = buffer.create
local buffer_fill = buffer.fill
local buffer_fromstring = buffer.fromstring
local buffer_len = buffer.len
local buffer_readu32 = buffer.readu32
local buffer_tostring = buffer.tostring
local buffer_writeu32 = buffer.writeu32

local content_fromObject = Content.fromObject
local content_None = Content.none

local math_atan2 = math.atan2
local math_ceil = math.ceil
local math_clamp = math.clamp
local math_cos = math.cos
local math_Huge = math.huge
local math_max = math.max
local math_min = math.min
local math_rad = math.rad
local math_sin = math.sin
local math_sqrt = math.sqrt

local table_create = table.create
local table_find = table.find
local table_insert = table.insert
local table_move = table.move

local vector2_new = Vector2.new
local vector2_Zero = Vector2.zero

--[[
	Repeat a certain number of bytes specified, width, repeatCount times.
	
	Uses O(log(n)) copy doubling technique, since there is no way to use something equal to rep stosd.
]]
local function buffer_rep(b: buffer, offset: number, width: number, repeatCount: number)
	repeatCount *= width
	while width * 2 <= repeatCount do
		buffer_copy(b, offset + width, b, offset, width)
		width *= 2
	end
	if width < repeatCount then
		buffer_copy(b, offset + width, b, offset, repeatCount - width)
	end
end Module.buffer_rep = buffer_rep

local function buffer_reverse(b: buffer): buffer
	return buffer_fromstring(buffer_tostring(b):reverse())
end Module.buffer_reverse = buffer_reverse

--[[
	Get the unsigned 32-bit integer value corresponding to unsigned 8-bit integer RGBA values.
	returns: 32-bit ABGR value
]]
local function color_FromRGBA(r: number, g: number, b: number, a: number): number
	return r + g * 0x100 + b * 0x10000 + a * 0x1000000
end

Module.color_FromRGBA = color_FromRGBA

--[[
	Blend two 32-bit ABGR colors.
	return: 32-bit ABGR color
]]
local function compute_Blend(src: number, dst: number): number
	-- Extract channels
	
	local sa = bit32_band(src, 0xFF)
	local sb = bit32_band(src // 0x100, 0xFF)
	local sg = bit32_band(src // 0x10000, 0xFF)
	local sr = bit32_band(src // 0x1000000, 0xFF)

	local da = bit32_band(dst, 0xFF)
	local db = bit32_band(dst // 0x100, 0xFF)
	local dg = bit32_band(dst // 0x10000, 0xFF)
	local dr = bit32_band(dst // 0x1000000, 0xFF)

	local inv_sa = (255 - sa)

	-- Blend each channel
	
	local a = sa + da * inv_sa // 0x100
	local b = sb + db * inv_sa // 0x100
	local g = sg + dg * inv_sa // 0x100
	local r = sr + dr * inv_sa // 0x100

	-- Pack back into 32-bit RGBA
	
	return bit32_bor(a, b * 0x100, g * 0x10000, r * 0x1000000)
end Module.compute_Blend = compute_Blend

local function compute_PremultipliedColor(color: number): number
	local a = bit32_band(color, 0xFF)
	local b = bit32_band(color // 0x100, 0xFF)
	local g = bit32_band(color // 0x10000, 0xFF)
	local r = bit32_band(color // 0x1000000, 0xFF)
	
	b *= a // 0x100
	g *= a // 0x100
	r *= a // 0x100
	
	return bit32_bor(a, b * 0x100, g * 0x10000, r * 0x1000000)
end Module.compute_PremultipliedColor = compute_PremultipliedColor


-- -- Functions

function Module.destroy(self: Canvas)
	self.EditableImage:Destroy()
end

function Module.fromBuffer(b: buffer, width: number, height: number): Canvas
	return setmetatable({
		Buffer = b,
		Content = content_None,
		EditableImage = AssetService:CreateEditableImage({Size = vector2_new(width, height)}),
		Width = width, Height = height
	}, Module)
end

function Module.fromVertices(vertices: {number}): Canvas
	local length = #vertices
	
	local max_X, min_X = 0, math_Huge
	for index = 1, length, 2 do
		local x = vertices[index]
		if x > max_X then
			max_X = x
		elseif x < min_X then
			min_X = x
		end
	end
	
	local max_Y, min_Y = 0, math_Huge
	for index = 2, length, 2 do
		local y = vertices[index]
		if y > max_Y then
			max_Y = y
		elseif y < min_Y then
			min_Y = y
		end
	end
	
	local width, height = max_X - min_X, max_Y - min_Y
	
	return setmetatable({
		Buffer = buffer_create(width * height * 4),
		Content = content_None,
		EditableImage = AssetService:CreateEditableImage({Size = vector2_new(width, height)}),
		Width = width, Height = height
	}, Module)
end

function Module.new(width: number, height: number): Canvas
	return setmetatable({
		Buffer = buffer_create(width * height * 4),
		Content = content_None,
		EditableImage = AssetService:CreateEditableImage({Size = vector2_new(width, height)}),
		Width = width, Height = height
	}, Module)
end


-- -- Methods

--[[
	Flips the canvas horizontally.
]]
function Module.bufferFromFlip_Horizontal(self: Canvas): (buffer, number, number)
	local srcBuffer = self.Buffer
	local width, height = self.Width, self.Height
	local decWidth, decHeight = (width - 1) * 4, height - 1
	width *= 4
	local dstBuffer = buffer_create(width * height)
	for row = 0, decHeight do
		local rowOffset = row * width
		local q = rowOffset + decWidth
		for col = 0, decWidth, 4 do
			buffer_copy(dstBuffer, q - col, srcBuffer, rowOffset + col, 4)
		end
	end
	return dstBuffer, width, height
end

--[[
	Flips the canvas vertically.
]]
function Module.bufferFromFlip_Vertical(self: Canvas): (buffer, number, number)
	local srcBuffer = self.Buffer
	local width, height = self.Width * 4, self.Height
	local decHeight = height - 1
	local dstBuffer = buffer_create(width * height)
	for row = 0, (height // 2) - 1 do
		local dstOffset = row * width
		local srcOffset = (decHeight - row) * width
		buffer_copy(dstBuffer, dstOffset, srcBuffer, srcOffset, width)
		buffer_copy(dstBuffer, srcOffset, srcBuffer, dstOffset, width)
	end
	return dstBuffer, width, height
end

--[[
	Creates a buffer with the content of the canvas, rotated 90 degrees clockwise.

	returns: (buffer, width, height)
]]
function Module.bufferFromRotation_90(self: Canvas): (buffer, number, number)
	local srcBuffer = self.Buffer
	local width, height = self.Width, self.Height
	local decWidth, decHeight = width - 1, height - 1
	local dstBuffer = buffer_create(width * height * 4)
	for y = 0, decHeight do
		local nx = decHeight - y
		local q = y * width
		for x = 0, decWidth do
			buffer_writeu32(dstBuffer, (x * height + nx) * 4, buffer_readu32(srcBuffer, (q + x) * 4))
		end
	end

	return dstBuffer, height, width
end

--[[
	Creates a buffer with the content of the canvas, rotated 180 degrees clockwise.

	returns: (buffer, width, height)
]]
function Module.bufferFromRotation_180(self: Canvas): (buffer, number, number)
	local srcBuffer = self.Buffer
	local width, height = self.Width, self.Height
	local decWidth, decHeight = width - 1, height - 1
	local dstBuffer = buffer_create(width * height * 4)
	for y = 0, decHeight do
		local ny = (decHeight - y) * width + decWidth
		local q = y * width
		for x = 0, decWidth do
			buffer_writeu32(dstBuffer, (ny - x) * 4, buffer_readu32(srcBuffer, (q + x) * 4))
		end
	end

	return dstBuffer, width, height
end

--[[
	Creates a buffer with the content of the canvas, rotated 270 degrees clockwise.

	returns: (buffer, width, height)
]]
function Module.bufferFromRotation_270(self: Canvas): (buffer, number, number)
	local srcBuffer = self.Buffer
	local width, height = self.Width, self.Height
	local decWidth, decHeight = width - 1, height - 1
	local dstBuffer = buffer_create(width * height * 4)
	for y = 0, decHeight do
		local ny = (decHeight - y) * height
		local q = y * width
		for x = 0, decWidth do
			buffer_writeu32(dstBuffer, (ny + y) * 4, buffer_readu32(srcBuffer, (q + x) * 4))
		end
	end

	return dstBuffer, height, width
end

--[[
	Fill the entire canvas with the given color.
	
	Because buffer.fill is rep stosb, a 4-byte color which would normally work with rep stosd cannot be used.
	If the buffer was a structure of arrays instead of an array of structures, this would not be an issue.
	
	This implementation tries to optimize for a lack of stosd by doubling the copy size every copy iteration.
]]
function Module.fill(self: Canvas, color: number)
	local dstBuffer = self.Buffer
	local len = buffer_len(dstBuffer)

	buffer_writeu32(dstBuffer, 0, color)

	local filled = 4

	while filled * 2 <= len do
		buffer_copy(dstBuffer, filled, dstBuffer, 0, filled)
		filled = filled * 2
	end

	if filled < len then
		buffer_copy(dstBuffer, filled, dstBuffer, 0, len - filled)
	end
end

--[[
	Fill the entire canvas with the color given by the given grayscale value.
]]
function Module.fillGrayscale(self: Canvas, value: number)
	local b = self.Buffer
	buffer_fill(b, 0, value, buffer_len(b))
end

--[[
	Flood-fills a region of pixels in a buffer with a given color.
]]
function Module.floodFill(self: Canvas, width: number, height: number, startX: number, startY: number, targetColor: number, fillColor: number)
	if targetColor == fillColor then
		return
	end

	local dstBuffer = self.Buffer
	local stack: {number} = {}
	local top = 1
	local x, y = startX, startY
	while #stack > 0 do
		-- Move left
		local left = x
		while left >= 0 do
			if buffer_readu32(dstBuffer, (y * width + left) * 4) ~= targetColor then
				break
			end
			left -= 1
		end
		left += 1

		-- Move right
		local right = x
		while right < width do
			if buffer_readu32(dstBuffer, (y * width + right) * 4) ~= targetColor then
				break
			end
			right += 1
		end
		right -= 1

		-- Fill the span
		local spanLength = right - left + 1
		local offset = (y * width + left) * 4
		buffer_writeu32(dstBuffer, offset, fillColor)
		buffer_rep(dstBuffer, offset, 4, spanLength)

		-- Check above and below
		for ny = y - 1, y + 1, 2 do
			if ny >= 0 and ny < height then
				while left <= right do
					if buffer_readu32(dstBuffer, (ny * width + left) * 4) == targetColor then
						stack[top] = left
						stack[top + 1] = ny
						top += 2
						break
					end
					left += 1
				end
			end
		end

		x, y = stack[top - 2], stack[top - 1]
		top -= 2
	end
end

--[[
	Batch update canvas.
]]
function Module.flush(self: Canvas)
	local editableImage = self.EditableImage
	editableImage:WritePixelsBuffer(vector2_Zero, editableImage.Size, self.Buffer)
	self.Content = content_fromObject(editableImage)
end

--[[
	Flips the canvas horizontally (in-place).
]]
function Module.flip_Horizontal(self: Canvas)
	local dstBuffer = self.Buffer
	local width, height = self.Width, self.Height
	local decWidth, decHeight = (width - 1) * 4, height - 1
	local halfWidth = ((width // 2) - 1) * 4
	width *= 4
	local temp = buffer_create(4)
	for row = 0, height - 1 do
		local rowOffset = row * width
		for col = 0, halfWidth, 4 do
			local left = rowOffset + col
			local right = rowOffset + decWidth - col
			buffer_copy(temp, 0, dstBuffer, right, 4)
			buffer_copy(dstBuffer, right, dstBuffer, left, 4)
			buffer_copy(dstBuffer, left, temp, 0, 4)
		end
	end
end

--[[
	Flips the canvas vertically (in-place).
]]
function Module.flip_Vertical(self: Canvas)
	local dstBuffer = self.Buffer
	local width, height = self.Width * 4, self.Height
	local halfHeight = height // 2
	local decHeight = height - 1
	local temp = buffer_create(width)
	for row = 0, halfHeight - 1 do
		local dstOffset = row * width
		local srcOffset = (decHeight - row) * width
		buffer_copy(temp, 0, dstBuffer, srcOffset, width)
		buffer_copy(dstBuffer, srcOffset, dstBuffer, dstOffset, width)
		buffer_copy(dstBuffer, dstOffset, temp, 0, width)
	end
end


-- -- End

return Module
