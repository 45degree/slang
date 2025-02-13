target("slang-capability-generator", function()
	set_kind("binary")
	add_files("slang-capability-generator/*.cpp")

	add_deps("compiler-core")
	add_packages("miniz", "lz4", "unordered_dense")
  set_policy("build.fence", true)
end)

target("slang-cpp-parser", function()
	set_kind("static")
	add_files("slang-cpp-parser/*.cpp")

	add_deps("compiler-core")
	add_packages("miniz", "lz4", "unordered_dense")
  set_policy("build.fence", true)
end)

target("slang-cpp-extractor", function()
	set_kind("binary")
	add_files("slang-cpp-extractor/*.cpp")

	add_includedirs(".", { public = true })

	add_deps("compiler-core", "slang-cpp-parser")
	add_packages("miniz", "lz4", "unordered_dense")
  set_policy("build.fence", true)
end)

target("slang-embed", function()
	set_kind("binary")
	add_files("slang-embed/*.cpp")

	add_deps("compiler-core", "core")
	add_packages("miniz", "lz4", "unordered_dense")
  set_policy("build.fence", true)
end)

target("slang-generate", function()
	set_kind("binary")
	add_files("slang-generate/*.cpp")

	add_deps("compiler-core", "core")
	add_packages("miniz", "lz4", "unordered_dense")
  set_policy("build.fence", true)
end)

target("slang-lookup-generator", function()
	set_kind("binary")
	add_files("slang-lookup-generator/*.cpp")

	add_deps("compiler-core", "core")
	add_packages("miniz", "lz4", "unordered_dense")
  set_policy("build.fence", true)
end)

target("slang-spirv-embed-generator", function()
	set_kind("binary")
	add_files("slang-spirv-embed-generator/*.cpp")

	add_deps("compiler-core", "core")
	add_packages("miniz", "lz4", "unordered_dense", "spirv-headers")
  set_policy("build.fence", true)
end)
