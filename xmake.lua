add_rules("mode.release", "mode.debug")

add_requires("miniz", "lz4", "unordered_dense", "spirv-headers")
set_languages("c11", "cxx17")

option("shared", function()
	set_default(true)
end)

if is_os("windows") then
	add_defines("WIN32_LEAN_AND_MEAN", "VC_EXTRALEAN", "NOMINMAX", "UNICODE", "_UNICODE")
end

-- tools
includes("tools")
includes("source")
