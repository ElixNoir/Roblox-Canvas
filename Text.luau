--- Author: COMT

--!native
--!optimize 2
--!strict

--[[

	Canvas - A module all about writing images.
	Mod: Text

]]


-- -- State

local Canvas = require(script.Parent)
type Canvas = Canvas.Canvas

local Module = {}

--[[
	For those who are reading "something | false" and are wondering why not "something?":
	
	False means empty and nil means empty.  However, they act differently in the Lua VM.
	Nil is not used because arrays cannot have nil in them without becoming hashmaps internally.  This is primarily a performance optimization.
]]
type ExistingGlyph = {AtlasPosition: number, Width: number, Height: number, xOffset: number, yOffset: number, xAdvance: number}
export type Glyph = ExistingGlyph | false
export type Font = {Atlas: buffer, Glyphs: {Glyph}, LineHeight: number, SpaceAdvance: number, TabWidth: number?}

--[[ -- Shaders are not yet implemented for this mod.

export type Shader = (
	x: number, y: number
) -> number

export type ShaderCompiler = (
	canvas: Canvas.Canvas,
	x: number, y: number,
	width: number, height: number,
	...any
) -> Shader

]]


-- -- Helpers

local buffer_copy = buffer.copy
local buffer_readu32 = buffer.readu32
local buffer_writeu32 = buffer.writeu32

local math_ceil = math.ceil
local math_clamp = math.clamp
local math_min = math.min
local math_round = math.round

local string_byte = string.byte
local string_char = string.char
local string_format = string.format

local compute_Blend = Canvas.compute_Blend


-- -- Methods

--[[
	Draws and blends a character using its font given by its respective atlas.
]]
function Module.fillCharacter_Blend(self: Canvas, font: Font, character: number, x: number, y: number): number
	local glyph = font.Glyphs[character]
	if not glyph then
		error(string_format("No glyph for '%s'", string_char(character)))
	end

	local dstBuffer = self.Buffer

	local atlas = font.Atlas
	local dstWidth = self.Width

	local dstX = x + glyph.xOffset
	local dstY = y + glyph.yOffset

	local glyph_AtlasPosition = glyph.AtlasPosition
	local glyph_Width = glyph.Width
	local q = (glyph_Width - 1) * 4

	for row = 0, glyph.Height - 1 do
		local srcRow = (glyph_AtlasPosition + row * glyph_Width) * 4
		local dstRow = ((dstY + row) * dstWidth + dstX) * 4

		for column = 0, q, 4 do
			local dst = dstRow + column
			buffer_writeu32(dstBuffer, dst, compute_Blend(buffer_readu32(atlas, srcRow + column), buffer_readu32(dstBuffer, dst)))
		end
	end

	return glyph.xAdvance
end

--[[
	Draws a character using its font given by its respective atlas.
]]
function Module.fillCharacter_Overwrite(self: Canvas, font: Font, character: number, x: number, y: number): number
	local glyph = font.Glyphs[character]
	if not glyph then
		error(string_format("No glyph for '%s'", string_char(character)))
	end
	
	local b = self.Buffer
	
	local atlas = font.Atlas
	local dstWidth = self.Width
	
	local dstX = x + glyph.xOffset
	local dstY = y + glyph.yOffset
	
	local glyph_AtlasPosition = glyph.AtlasPosition
	local glyph_Width = glyph.Width
	
	for row = 0, glyph.Height - 1 do
		buffer_copy(
			b,
			(dstY + row) * dstWidth + dstX,
			atlas,
			glyph_AtlasPosition + row * glyph_Width,
			glyph_Width
		)
	end

	return glyph.xAdvance
end

--[[
	Draws and blends text using its font given by its respective atlas.
]]
function Module.fill_Blend(
	self: Canvas,
	font: Font,
	text: string,
	x: number,
	y: number,
	maxWidth: number?,
	padding: number?,
	spacing: number?
)
	local padding = padding or 0
	local spacing = spacing or 0
	local maxWidth = maxWidth or math.huge

	local cursorX = x + padding
	local cursorY = y + padding

	local startX = cursorX

	for index = 1, #text do
		local character = string_byte(text, index)
		if character == 32 then -- space
			cursorX += font.SpaceAdvance + spacing
		elseif character == 10 then -- newline
			cursorX = startX
			cursorY += font.LineHeight + spacing
			continue
		elseif character == 9 then -- tab
			local tabWidth = font.TabWidth or (font.SpaceAdvance * 4)

			local relative = cursorX - startX
			local nextStop = (relative // tabWidth + 1) * tabWidth

			cursorX = startX + nextStop
			continue
		end

		local glyph = font.Glyphs[character]
		if not glyph then
			error(string_format("No glyph found for character '%s'", string_char(character)))
		end

		if cursorX + glyph.Width > startX + maxWidth then -- Wrap
			cursorX = startX
			cursorY += font.LineHeight + spacing
		end

		cursorX += Module.fillCharacter_Blend(
			self,
			font,
			character,
			cursorX,
			cursorY
		) + spacing
	end
end

--[[
	Draws text using its font given by its respective atlas.
]]
function Module.fill_Overwrite(
	self: Canvas,
	font: Font,
	text: string,
	x: number,
	y: number,
	maxWidth: number?,
	padding: number?,
	spacing: number?
)
	local padding = padding or 0
	local spacing = spacing or 0
	local maxWidth = maxWidth or math.huge

	local cursorX = x + padding
	local cursorY = y + padding

	local startX = cursorX

	for index = 1, #text do
		local character = string_byte(text, index)
		if character == 32 then -- space
			cursorX += font.SpaceAdvance + spacing
		elseif character == 10 then -- newline
			cursorX = startX
			cursorY += font.LineHeight + spacing
			continue
		elseif character == 9 then -- tab
			local tabWidth = font.TabWidth or (font.SpaceAdvance * 4)

			local relative = cursorX - startX
			local nextStop = (relative // tabWidth + 1) * tabWidth

			cursorX = startX + nextStop
			continue
		end

		local glyph = font.Glyphs[character]
		if not glyph then
			error(string_format("No glyph found for character '%s'", string_char(character)))
		end

		if cursorX + glyph.Width > startX + maxWidth then -- Wrap
			cursorX = startX
			cursorY += font.LineHeight + spacing
		end

		cursorX += Module.fillCharacter_Overwrite(
			self,
			font,
			character,
			cursorX,
			cursorY
		) + spacing
	end
end


-- -- End

return Module
