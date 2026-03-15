--- Author: COMT

--!native
--!optimize 2
--!strict

--[[

	Canvas - A module all about writing images.
	Mod: Line

]]


-- -- State

local Canvas = require(script.Parent)
type Canvas = Canvas.Canvas

local Module = {}

export type Shader = (
	x: number, y: number
) -> number

export type ShaderCompiler = (
	b: buffer,
	x1: number, y1: number, x2: number, y2: number,
	width: number?,
	...any
) -> Shader


-- -- Helpers

local buffer_readu32 = buffer.readu32
local buffer_writeu32 = buffer.writeu32

local compute_Blend = Canvas.compute_Blend


--[[
	Draws a line from (x1, y1) to (x2, y2) and blends pixels with color given by a shader function.
]]
function Module.draw_Blend(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height

	local shader = compileShader(b, x1, y1, x2, y2, ...)

	local dx = x2 - x1
	if dx < 0 then
		dx = -dx
	end

	local dy = y2 - y1
	if dy < 0 then
		dy = -dy
	end

	local sx = x1 < x2 and 1 or -1
	local sy = y1 < y2 and 1 or -1

	local err = dx - dy
	local e2

	if x1 >= 0 and x1 < dstWidth and y1 >= 0 and y1 < dstHeight then
		local offset = 4 * (y1 * dstWidth + x1)
		buffer_writeu32(b, offset, compute_Blend(shader(x1, y1), buffer_readu32(b, offset)))
	end

	while x1 ~= x2 or y1 ~= y2 do
		e2 = err + err

		if e2 > -dy then
			err -= dy
			x1 += sx
		end

		if e2 < dx then
			err += dx
			y1 += sy
		end
		
		if x1 >= 0 and x1 < dstWidth and y1 >= 0 and y1 < dstHeight then
			local offset = 4 * (y1 * dstWidth + x1)
			buffer_writeu32(b, offset, compute_Blend(shader(x1, y1), buffer_readu32(b, offset)))
		end
	end

	return true
end

--[[
	Draws a line from (x1, y1) to (x2, y2) and overwrites pixels with color given by a shader function.
]]
function Module.draw_Overwrite(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height

	local shader = compileShader(b, x1, y1, x2, y2, ...)

	local dx = x2 - x1
	if dx < 0 then
		dx = -dx
	end

	local dy = y2 - y1
	if dy < 0 then
		dy = -dy
	end

	local sx = x1 < x2 and 1 or -1
	local sy = y1 < y2 and 1 or -1

	local err = dx - dy
	local e2

	if x1 >= 0 and x1 < dstWidth and y1 >= 0 and y1 < dstHeight then
		buffer_writeu32(b, 4 * (y1 * dstWidth + x1), shader(x1, y1))
	end

	while x1 ~= x2 or y1 ~= y2 do
		e2 = err + err

		if e2 > -dy then
			err -= dy
			x1 += sx
		end

		if e2 < dx then
			err += dx
			y1 += sy
		end
		
		if x1 >= 0 and x1 < dstWidth and y1 >= 0 and y1 < dstHeight then
			buffer_writeu32(b, 4 * (y1 * dstWidth + x1), shader(x1, y1))
		end
	end

	return true
end

--[[
	Draws a line from (x1, y1) to (x2, y2) with the given width and blends pixels with color given by a shader function.
]]
function Module.drawWide_Blend(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	width: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	if width <= 0 then
		return false
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height

	local shader = compileShader(b, x1, y1, x2, y2, ...)

	local dx = x2 - x1
	if dx < 0 then
		dx = -dx
	end

	local dy = y2 - y1
	if dy < 0 then
		dy = -dy
	end

	local sx = x1 < x2 and 1 or -1
	local sy = y1 < y2 and 1 or -1

	local err = dx - dy
	local e2
	local half = err // 2
	local steep = dy > dx

	if steep then
		for ox = -half, half do
			local px = x1 + ox
			if px >= 0 and px < dstWidth and y1 >= 0 and y1 < dstHeight then
				local offset = 4 * (y1 * dstWidth + px)
				buffer_writeu32(b, offset, compute_Blend(shader(px, y1), buffer_readu32(b, offset)))
			end
		end
	else
		for oy = -half, half do
			local py = y1 + oy
			if x1 >= 0 and x1 < dstWidth and py >= 0 and py < dstHeight then
				local offset = 4 * (py * dstWidth + x1)
				buffer_writeu32(b, offset, compute_Blend(shader(x1, py), buffer_readu32(b, offset)))
			end
		end
	end

	while x1 ~= x2 or y1 ~= y2 do
		e2 = err + err

		if e2 > -dy then
			err -= dy
			x1 += sx
		end

		if e2 < dx then
			err += dx
			y1 += sy
		end
		
		if steep then
			for ox = -half, half do
				local px = x1 + ox
				if px >= 0 and px < dstWidth and y1 >= 0 and y1 < dstHeight then
					local offset = 4 * (y1 * dstWidth + px)
					buffer_writeu32(b, offset, compute_Blend(shader(px, y1), buffer_readu32(b, offset)))
				end
			end
		else
			for oy = -half, half do
				local py = y1 + oy
				if x1 >= 0 and x1 < dstWidth and py >= 0 and py < dstHeight then
					local offset = 4 * (py * dstWidth + x1)
					buffer_writeu32(b, offset, compute_Blend(shader(x1, py), buffer_readu32(b, offset)))
				end
			end
		end
	end

	return true
end

--[[
	Draws a line from (x1, y1) to (x2, y2) with the given width and overwrites pixels with color given by a shader function.
]]
function Module.drawWide_Overwrite(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	width: number,
	compileShader: ShaderCompiler,
	...: any
): boolean
	if width <= 0 then
		return false
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height

	local shader = compileShader(b, x1, y1, x2, y2, ...)

	local dx = x2 - x1
	if dx < 0 then
		dx = -dx
	end

	local dy = y2 - y1
	if dy < 0 then
		dy = -dy
	end

	local sx = x1 < x2 and 1 or -1
	local sy = y1 < y2 and 1 or -1

	local err = dx - dy
	local e2
	local half = err // 2
	local steep = dy > dx

	if steep then
		for ox = -half, half do
			local px = x1 + ox
			if px >= 0 and px < dstWidth and y1 >= 0 and y1 < dstHeight then
				local offset = 4 * (y1 * dstWidth + px)
				buffer_writeu32(b, offset, shader(px, y1))
			end
		end
	else
		for oy = -half, half do
			local py = y1 + oy
			if x1 >= 0 and x1 < dstWidth and py >= 0 and py < dstHeight then
				local offset = 4 * (py * dstWidth + x1)
				buffer_writeu32(b, offset, shader(x1, py))
			end
		end
	end

	while x1 ~= x2 or y1 ~= y2 do
		e2 = err + err

		if e2 > -dy then
			err -= dy
			x1 += sx
		end

		if e2 < dx then
			err += dx
			y1 += sy
		end
		
		if steep then
			for ox = -half, half do
				local px = x1 + ox
				if px >= 0 and px < dstWidth and y1 >= 0 and y1 < dstHeight then
					local offset = 4 * (y1 * dstWidth + px)
					buffer_writeu32(b, offset, shader(px, y1))
				end
			end
		else
			for oy = -half, half do
				local py = y1 + oy
				if x1 >= 0 and x1 < dstWidth and py >= 0 and py < dstHeight then
					local offset = 4 * (py * dstWidth + x1)
					buffer_writeu32(b, offset, shader(x1, py))
				end
			end
		end
	end

	return true
end

--[[
	Draws a line from (x1, y1) to (x2, y2) and blends pixels with the given color.
]]
function Module.fill_Blend(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	color: number
): boolean
	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height

	local dx = x2 - x1
	if dx < 0 then
		dx = -dx
	end

	local dy = y2 - y1
	if dy < 0 then
		dy = -dy
	end

	local sx = x1 < x2 and 1 or -1
	local sy = y1 < y2 and 1 or -1

	local err = dx - dy
	local e2

	if x1 >= 0 and x1 < dstWidth and y1 >= 0 and y1 < dstHeight then
		local offset = 4 * (y1 * dstWidth + x1)
		buffer_writeu32(b, offset, compute_Blend(color, buffer_readu32(b, offset)))
	end

	while x1 ~= x2 or y1 ~= y2 do
		e2 = err + err

		if e2 > -dy then
			err -= dy
			x1 += sx
		end

		if e2 < dx then
			err += dx
			y1 += sy
		end
		
		if x1 >= 0 and x1 < dstWidth and y1 >= 0 and y1 < dstHeight then
			local offset = 4 * (y1 * dstWidth + x1)
			buffer_writeu32(b, offset, compute_Blend(color, buffer_readu32(b, offset)))
		end
	end

	return true
end

--[[
	Draws a line from (x1, y1) to (x2, y2) and overwrites pixels with the given color.
]]
function Module.fill_Overwrite(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	color: number
): boolean
	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height

	local dx = x2 - x1
	if dx < 0 then
		dx = -dx
	end

	local dy = y2 - y1
	if dy < 0 then
		dy = -dy
	end

	local sx = x1 < x2 and 1 or -1
	local sy = y1 < y2 and 1 or -1

	local err = dx - dy
	local e2
	
	if x1 >= 0 and x1 < dstWidth and y1 >= 0 and y1 < dstHeight then
		buffer_writeu32(b, 4 * (y1 * dstWidth + x1), color)
	end
	
	while x1 ~= x2 or y1 ~= y2 do
		e2 = err + err

		if e2 > -dy then
			err -= dy
			x1 += sx
		end

		if e2 < dx then
			err += dx
			y1 += sy
		end
		
		if x1 >= 0 and x1 < dstWidth and y1 >= 0 and y1 < dstHeight then
			buffer_writeu32(b, 4 * (y1 * dstWidth + x1), color)
		end
	end

	return true
end

--[[
	Draws a line from (x1, y1) to (x2, y2) with the given width and blends pixels with the given color.
]]
function Module.fillWide_Blend(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	width: number,
	color: number
): boolean
	if width <= 0 then
		return false
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height

	local dx = x2 - x1
	if dx < 0 then
		dx = -dx
	end

	local dy = y2 - y1
	if dy < 0 then
		dy = -dy
	end

	local sx = x1 < x2 and 1 or -1
	local sy = y1 < y2 and 1 or -1

	local err = dx - dy
	local e2
	local half = err // 2
	local steep = dy > dx

	if steep then
		for ox = -half, half do
			local px = x1 + ox
			if px >= 0 and px < dstWidth and y1 >= 0 and y1 < dstHeight then
				local offset = 4 * (y1 * dstWidth + px)
				buffer_writeu32(b, offset, compute_Blend(color, buffer_readu32(b, offset)))
			end
		end
	else
		for oy = -half, half do
			local py = y1 + oy
			if x1 >= 0 and x1 < dstWidth and py >= 0 and py < dstHeight then
				local offset = 4 * (py * dstWidth + x1)
				buffer_writeu32(b, offset, compute_Blend(color, buffer_readu32(b, offset)))
			end
		end
	end

	while x1 ~= x2 or y1 ~= y2 do
		e2 = err + err

		if e2 > -dy then
			err -= dy
			x1 += sx
		end

		if e2 < dx then
			err += dx
			y1 += sy
		end
		
		if steep then
			for ox = -half, half do
				local px = x1 + ox
				if px >= 0 and px < dstWidth and y1 >= 0 and y1 < dstHeight then
					local offset = 4 * (y1 * dstWidth + px)
					buffer_writeu32(b, offset, compute_Blend(color, buffer_readu32(b, offset)))
				end
			end
		else
			for oy = -half, half do
				local py = y1 + oy
				if x1 >= 0 and x1 < dstWidth and py >= 0 and py < dstHeight then
					local offset = 4 * (py * dstWidth + x1)
					buffer_writeu32(b, offset, compute_Blend(color, buffer_readu32(b, offset)))
				end
			end
		end
	end

	return true
end

--[[
	Draws a line from (x1, y1) to (x2, y2) with the given width and overwrites pixels with the given color.
]]
function Module.fillWide_Overwrite(self: Canvas,
	x1: number, y1: number,
	x2: number, y2: number,
	width: number,
	color: number
): boolean
	if width <= 0 then
		return false
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height

	local dx = x2 - x1
	if dx < 0 then
		dx = -dx
	end

	local dy = y2 - y1
	if dy < 0 then
		dy = -dy
	end

	local sx = x1 < x2 and 1 or -1
	local sy = y1 < y2 and 1 or -1

	local err = dx - dy
	local e2
	local half = err // 2
	local steep = dy > dx

	if steep then
		for ox = -half, half do
			local px = x1 + ox
			if px >= 0 and px < dstWidth and y1 >= 0 and y1 < dstHeight then
				local offset = 4 * (y1 * dstWidth + px)
				buffer_writeu32(b, offset, color)
			end
		end
	else
		for oy = -half, half do
			local py = y1 + oy
			if x1 >= 0 and x1 < dstWidth and py >= 0 and py < dstHeight then
				local offset = 4 * (py * dstWidth + x1)
				buffer_writeu32(b, offset, color)
			end
		end
	end

	while x1 ~= x2 or y1 ~= y2 do
		e2 = err + err

		if e2 > -dy then
			err -= dy
			x1 += sx
		end

		if e2 < dx then
			err += dx
			y1 += sy
		end
		
		if steep then
			for ox = -half, half do
				local px = x1 + ox
				if px >= 0 and px < dstWidth and y1 >= 0 and y1 < dstHeight then
					local offset = 4 * (y1 * dstWidth + px)
					buffer_writeu32(b, offset, color)
				end
			end
		else
			for oy = -half, half do
				local py = y1 + oy
				if x1 >= 0 and x1 < dstWidth and py >= 0 and py < dstHeight then
					local offset = 4 * (py * dstWidth + x1)
					buffer_writeu32(b, offset, color)
				end
			end
		end
	end

	return true
end


-- -- End

return Module
