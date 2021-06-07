--[[
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see https://www.gnu.org/licenses/.
--]]

--- LibDeflate usage example
-- @author Haoqian He
-- @file example.lua

local LibDeflate

if LibStub then -- You are using LibDeflate as WoW addon
	LibDeflate = LibStub:GetLibrary("LibDeflate")
else
	-- You are using LibDeflate as Lua library.
	-- Setup the path to locate LibDeflate.lua,
	-- if 'require("LibDeflate")' fails, for example:
	-- package.path = ("?.lua;../?.lua;")..(package.path or "")
	LibDeflate = require("LibDeflate")
end

local example_input = "12123123412345123456123456712345678123456789"

-- Compress using raw deflate format
local compress_deflate = LibDeflate:CompressDeflate(example_input)

-- decompress
local decompress_deflate = LibDeflate:DecompressDeflate(compress_deflate)
-- Check if the first return value of DecompressXXXX is non-nil to know if the
-- decompression succeeds.
if decompress_deflate == nil then
	error("Decompression fails.")
else
	-- Decompression succeeds.
	assert(example_input == decompress_deflate)
end

-- /dump LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate("This is a very long string is it really that long after compress tho?>"))
-- /dump LibDeflate:DecompressDeflate(LibDeflate:DecodeForPrint("Tl1YUTnmqWFM(bK0x3vIvrnGTQHOdkYfsrrTsIWuKc8rs9f97KFZUKswjnxArrUuGcyqRz5Yz3D2PmF)2In5LVJEn9iL0ak(51pyoqql(0vupL4TYUoWYmJ(09Y2wPiO8NPKSI7PK6hzJ9ChqlUkbQ5wwn0ASyKcEXAmp8dKTvOOheNMdwtjgT6mtz4nZCX0HHyUVkCmZF55UrqPKnX4WdGg5pV42VDxXX8sg5ywj2VotWkqc5dqKXgW5xbx(V24CS(rwql9Vepk8lZWs5sCfR2mos2ZOeBiY55ItouVIuTaeMG(vCLUaZhRO24LOOY9sJoQXcJYyXpkUo979PZpKo)y8eFYJ9gK8rqeFiLmaohVdhMdb)u13nwvZu1EU9eytsGUb3ws7u1xnwnQcb7CXqwxzHPK44q2l1Yg4e6giCmnM3ml2XPzU1XDllEvAybK6BIDKfgbU3f7Fh4dJPvI9mZlJImUqRXEzwbmTTyklGbttqzMb(l7KB752oWnv9fPn2uGMxRGyLiUqnQuqNXIDirfA6G2uJVyuVyf8u6tL)Et(N)h0KtoKVBhl7UYmw2Hd72MV5pXNVbdzdcV8byQA7WihD3VLw)B(V1)n16xc)9o)Fc"))

-- If it is to transmit through WoW addon channel,
-- compressed data must be encoded so NULL ("\000") is not transmitted.
local data_to_trasmit_WoW_addon = LibDeflate:EncodeForWoWAddonChannel(
	compress_deflate)
-- When the receiver gets the data, decoded it first.
local data_decoded_WoW_addon = LibDeflate:DecodeForWoWAddonChannel(
	data_to_trasmit_WoW_addon)
-- Then decomrpess it
assert(LibDeflate:DecompressDeflate(data_decoded_WoW_addon) == example_input)

-- The compressed output is not printable. EncodeForPrint will convert to
-- a printable format, in case you want to export to the user to
-- copy and paste. This encoding will make the data 25% bigger.
local printable_compressed = LibDeflate:EncodeForPrint(compress_deflate)

-- DecodeForPrint to convert back.
-- DecodeForPrint will remove prefixed and trailing control or space characters
-- in the string before decode it.
assert(LibDeflate:DecodeForPrint(printable_compressed) == compress_deflate)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

--- Compress and decompress using zlib format
local compress_zlib = LibDeflate:CompressZlib(example_input)
local decompress_zlib = LibDeflate:DecompressZlib(compress_zlib)
assert(decompress_zlib == example_input)

--- Control the compression level
-- NOTE: High compression level does not make a difference here,
-- because the input data is very small
local compress_deflate_with_level = LibDeflate:CompressDeflate(example_input
	, {level = 9})
local decompress_deflate_with_level = LibDeflate:DecompressDeflate(
	compress_deflate_with_level)
assert(decompress_deflate_with_level == example_input)


-- Compress with a preset dictionary
local dict_str = "121231234" -- example preset dictionary string.
-- print(LibDeflate:Adler32(dict_str), #dict_str)
-- 9 147325380
-- hardcode the print result above, the ensure it is not modified
-- accidenttaly during the program development.
--
-- WARNING: The compressor and decompressor must use the same dictionary.
-- You should be aware of this when tranmitting compressed data over the
-- internet.
local dict = LibDeflate:CreateDictionary(dict_str, 9, 147325380)

-- Using the dictionary with raw deflate format
local compress_deflate_with_dict = LibDeflate:CompressDeflateWithDict(
	example_input, dict)
assert(#compress_deflate_with_dict < #compress_deflate)
local decompress_deflate_with_dict = LibDeflate:DecompressDeflateWithDict(
	compress_deflate_with_dict, dict)
assert(decompress_deflate_with_dict == example_input)

-- Using the dictionary with zlib format, specifying compression level
local compress_zlib_with_dict = LibDeflate:CompressZlibWithDict(
	example_input, dict, {level = 9})
assert(#compress_zlib_with_dict < #compress_zlib)
local decompress_zlib_with_dict = LibDeflate:DecompressZlibWithDict(
	compress_zlib_with_dict, dict)
assert(decompress_zlib_with_dict == example_input)
