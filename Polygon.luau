--- Author: COMT

--[[

	Canvas - A module all about writing images.
	Mod: Polygon

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
	x: number, y: number
) -> number

export type ShaderCompiler = (
	canvas: Canvas.Canvas,
	vertices: {number},
	dstWidth: number, dstHeight: number,
	...any
) -> Shader


-- -- Helpers

local buffer_readu32 = buffer.readu32
local buffer_rep = Canvas.buffer_rep
local buffer_writeu32 = buffer.writeu32

local math_ceil = math.ceil
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min

local table_insert = table.insert
local table_sort = table.sort

local compute_Blend = Canvas.compute_Blend


-- -- Methods

--[[
	Draws a polygon between the given vertices and blends pixels with color given by a shader function.
]]
function Module.draw_Blend(
	self: Canvas,
	vertices: {number},
	compileShader: ShaderCompiler,
	...: any
): boolean
	local n = #vertices
	if n < 6 then
		return false
	end

	local minY = math_huge
	local maxY = -math_huge
	for index = 2, n, 2 do
		local y = vertices[index]
		if y < minY then
			minY = y
		end
		if y > maxY then
			maxY = y
		end
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	minY = math_max(math_floor(minY), 0)
	maxY = math_min(math_ceil(maxY), dstHeight - 1)
	local shader = compileShader(self, vertices, dstWidth, dstHeight, ...)
	for y = minY, maxY do
		local intersections = {}

		-- Build intersections
		for index = 1, n, 2 do
			local x1 = vertices[index]
			local y1 = vertices[index + 1]
			local j = index + 2 <= n and index + 2 or 1
			local x2 = vertices[j]
			local y2 = vertices[j + 1]

			if y1 ~= y2 and y >= math_min(y1, y2) and y < math_max(y1, y2) then
				local t = (y - y1) / (y2 - y1)
				table_insert(intersections, x1 + t * (x2 - x1))
			end
		end

		table_sort(intersections)

		-- Fill spans
		for index = 1, #intersections, 2 do
			local x0 = math_max(math_floor(intersections[index]), 0)
			local x1 = math_min(math_floor(intersections[index + 1]), dstWidth - 1)

			for x = x0, x1 do
				local offset = (y * dstWidth + x) * 4
				buffer_writeu32(b, offset, compute_Blend(shader(x, y), buffer_readu32(b, offset)))
			end
		end
	end

	return true
end

--[[
	Draws a polygon between the given vertices and overwrites pixels with color given by a shader function.
]]
function Module.draw_Overwrite(
	self: Canvas,
	vertices: {number},
	compileShader: ShaderCompiler,
	...: any
): boolean
	local n = #vertices
	if n < 6 then
		return false
	end

	local minY = math_huge
	local maxY = -math_huge
	for index = 2, n, 2 do
		local y = vertices[index]
		if y < minY then
			minY = y
		end
		if y > maxY then
			maxY = y
		end
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	minY = math_max(math_floor(minY), 0)
	maxY = math_min(math_ceil(maxY), dstHeight - 1)
	local shader = compileShader(self, vertices, dstWidth, dstHeight, ...)
	for y = minY, maxY do
		local intersections = {}

		-- Build intersections
		for index = 1, n, 2 do
			local x1 = vertices[index]
			local y1 = vertices[index + 1]
			local j = index + 2 <= n and index + 2 or 1
			local x2 = vertices[j]
			local y2 = vertices[j + 1]

			if y1 ~= y2 and y >= math_min(y1, y2) and y < math_max(y1, y2) then
				local t = (y - y1) / (y2 - y1)
				table_insert(intersections, x1 + t * (x2 - x1))
			end
		end

		table_sort(intersections)

		-- Fill spans
		for index = 1, #intersections, 2 do
			local x0 = math_max(math_floor(intersections[index]), 0)
			local x1 = math_min(math_floor(intersections[index + 1]), dstWidth - 1)

			for x = x0, x1 do
				buffer_writeu32(b, (y * dstWidth + x) * 4, shader(x, y))
			end
		end
	end

	return true
end

--[[
	Draws a polygon between the given vertices and blends pixels with the given color.
	
	Vertices MUST be unsigned.
]]
function Module.fill_Blend(
	self: Canvas,
	vertices: {number},
	color: number
): boolean
	local n = #vertices
	if n < 6 then
		return false
	end

	local minY = math_huge
	local maxY = -math_huge
	for index = 2, n, 2 do
		local y = vertices[index]
		if y < minY then
			minY = y
		end
		if y > maxY then
			maxY = y
		end
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	minY = math_max(math_floor(minY), 0)
	maxY = math_min(math_ceil(maxY), dstHeight - 1)
	for y = minY, maxY do
		local intersections = {}

		-- Build intersections
		for index = 1, n, 2 do
			local x1 = vertices[index]
			local y1 = vertices[index + 1]
			local j = index + 2 <= n and index + 2 or 1
			local x2 = vertices[j]
			local y2 = vertices[j + 1]

			if y1 ~= y2 and y >= math_min(y1, y2) and y < math_max(y1, y2) then
				local t = (y - y1) / (y2 - y1)
				table_insert(intersections, x1 + t * (x2 - x1))
			end
		end

		table_sort(intersections)

		-- Fill spans
		for index = 1, #intersections, 2 do
			local x0 = math_max(math_floor(intersections[index]), 0)
			local x1 = math_min(math_floor(intersections[index + 1]), dstWidth - 1)

			for x = x0, x1 do
				local offset = (y * dstWidth + x) * 4
				buffer_writeu32(b, offset, compute_Blend(color, buffer_readu32(b, offset)))
			end
		end
	end

	return true
end

--[[
	Draws a polygon between the given vertices and overwrites pixels with the given color.
	
	Vertices MUST be unsigned.
]]
function Module.fill_Overwrite(
	self: Canvas,
	vertices: {number},
	color: number
): boolean
	local n = #vertices
	if n < 6 then
		return false
	end

	local minY = math_huge
	local maxY = -math_huge
	for index = 2, n, 2 do
		local y = vertices[index]
		if y < minY then
			minY = y
		end
		if y > maxY then
			maxY = y
		end
	end

	local b = self.Buffer
	local dstWidth, dstHeight = self.Width, self.Height
	minY = math_max(math_floor(minY), 0)
	maxY = math_min(math_ceil(maxY), dstHeight - 1)
	for y = minY, maxY do
		local intersections = {}

		-- Build intersections
		for index = 1, n, 2 do
			local x1 = vertices[index]
			local y1 = vertices[index + 1]
			local j = index + 2 <= n and index + 2 or 1
			local x2 = vertices[j]
			local y2 = vertices[j + 1]

			if y1 ~= y2 and y >= math_min(y1, y2) and y < math_max(y1, y2) then
				local t = (y - y1) / (y2 - y1)
				table_insert(intersections, x1 + t * (x2 - x1))
			end
		end

		table_sort(intersections)

		-- Fill spans
		for index = 1, #intersections, 2 do
			local x0 = math_max(math_floor(intersections[index]), 0)
			local x1 = math_min(math_floor(intersections[index + 1]), dstWidth - 1)
			if x0 <= x1 then
				local offset = (y * dstWidth + x0) * 4
				buffer_writeu32(b, offset, color)
				buffer_rep(b, offset, 4, x1 - x0 + 1)
			end
		end
	end

	return true
end

--[[
	Outlines a polygon between the given vertices and blends pixels with the given color.
]]
function Module.outline_Blend(self: Canvas,
	vertices: {number},
	color: number
): boolean
	local enx, eny = vertices[1], vertices[2]
	local x1, y1 = enx, eny
	for index = 3, #vertices, 2 do
		local x2, y2 = vertices[index], vertices[index + 1]
		Line.fill_Blend(self, x1, y1, x2, y2, color)
		x1, y1 = x2, y2
	end
	Line.fill_Blend(self, x1, y1, enx, eny, color)
	
	return true
end

--[[
	Outlines a polygon between the given vertices and blends pixels with color given by a shader function.
]]
function Module.outline_BlendShader(self: Canvas,
	vertices: {number},
	compileShader: Line.ShaderCompiler,
	...: any
): boolean
	local enx, eny = vertices[1], vertices[2]
	local x1, y1 = enx, eny
	for index = 3, #vertices, 2 do
		local x2, y2 = vertices[index], vertices[index + 1]
		Line.draw_Blend(self, x1, y1, x2, y2, compileShader, ...)
		x1, y1 = x2, y2
	end
	Line.draw_Blend(self, x1, y1, enx, eny, compileShader, ...)
	
	return true
end

--[[
	Outlines a polygon between the given vertices and overwrites pixels with the given color.
]]
function Module.outline_Overwrite(self: Canvas,
	vertices: {number},
	color: number
): boolean
	local enx, eny = vertices[1], vertices[2]
	local x1, y1 = enx, eny
	for index = 3, #vertices, 2 do
		local x2, y2 = vertices[index], vertices[index + 1]
		Line.fill_Overwrite(self, x1, y1, x2, y2, color)
		x1, y1 = x2, y2
	end
	Line.fill_Overwrite(self, x1, y1, enx, eny, color)
	
	return true
end

--[[
	Outlines a polygon between the given vertices and blends pixels with color given by a shader function.
]]
function Module.outline_OverwriteShader(self: Canvas,
	vertices: {number},
	compileShader: Line.ShaderCompiler,
	...: any
): boolean
	local enx, eny = vertices[1], vertices[2]
	local x1, y1 = enx, eny
	for index = 3, #vertices, 2 do
		local x2, y2 = vertices[index], vertices[index + 1]
		Line.draw_Overwrite(self, x1, y1, x2, y2, compileShader, ...)
		x1, y1 = x2, y2
	end
	Line.draw_Overwrite(self, x1, y1, enx, eny, compileShader, ...)
	
	return true
end


-- -- End

return Module
