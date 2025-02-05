add_rules("mode.release", "mode.debug")

add_requires("miniz", "lz4", "unordered_dense", "spirv-headers")
set_languages("c11", "cxx17")

option("shared", function()
	set_default(true)
end)

if is_os("windows") then
	add_defines("WIN32_LEAN_AND_MEAN", "VC_EXTRALEAN", "NOMINMAX", "UNICODE", "_UNICODE")
end

target("core", function()
	set_kind("static")

	add_includedirs("source", "include", { public = true })

	add_defines("SLANG_USE_SYSTEM_UNORDERED_DENSE_HEADER")

	add_files("source/core/*.cpp")
	add_packages("miniz", "lz4", "unordered_dense")

	if is_plat("windows") then
		add_files("source/core/windows/*.cpp")

		add_syslinks("Shell32")
	elseif is_plat("linux", "macosx") then
		add_files("source/core/unix/*.cpp")
	end
end)

target("compiler-core", function()
	set_kind("static")

	add_files("source/compiler-core/*.cpp")

	add_cxxflags("gxx::-fms-extensions")

	add_deps("core")
	add_packages("spirv-headers")
	add_packages("miniz", "lz4", "unordered_dense")

	if is_plat("windows") then
		add_files("source/compiler-core/windows/*.cpp")
	end
end)

target("slang", function()
	if is_config("shared", true) then
		set_kind("shared")
	else
		set_kind("static")
	end
	add_deps("slang-cpp-extractor")

	add_files(
		"source/slang/slang-ast-support-types.h",
		"source/slang/slang-ast-base.h",
		"source/slang/slang-ast-decl.h",
		"source/slang/slang-ast-expr.h",
		"source/slang/slang-ast-modifier.h",
		"source/slang/slang-ast-stmt.h",
		"source/slang/slang-ast-type.h",
		"source/slang/slang-ast-val.h",
		{ rule = "slang-reflect" }
	)
	add_rules("slang-lookup-tables")

	-- on_load(function(target)
	-- 	---@type Package
	-- 	local spirv = target:pkgs()["spirv-headers"]
	-- 	local include_dir = spirv:installdir("include")
	-- 	print(include_dir)
	-- end)

	add_packages("spirv-headers")

	-- add_files("source/slang/*.cpp")
end)

rule("slang-capability-generator-header", function()
	set_extensions("capdef")

	---@param target Target
	---@param batchcmds BatchCommand
	---@param sourcebatch SourceBatch
	---@param opt TargetOpt
	before_buildcmd_files(function(target, batchcmds, sourcebatch, opt)
		local base_dir = path.join(target:autogendir(), "rules", "slang-capability-generator")
		local generator_files = path.join(base_dir, "slang-generated-capability-defs-impl.cpp")
		local objectfile = target:objectfile(generator_files)

		target:add("includedirs", base_dir)
		table.insert(target:objectfiles(), objectfile)

		local cmd_opts = sourcebatch.sourcefiles
		table.insert(cmd_opts, "--target-directory")
		table.insert(cmd_opts, base_dir)
		table.insert(cmd_opts, "--doc")
		table.insert(cmd_opts, "docs/user-guide/a3-02-reference-capability-atoms.md")

		batchcmds:show_progress(opt.progress, "${color.build.object}compiling.slang-capability-generator")
		batchcmds:mkdir(base_dir)
		batchcmds:vrunv(target:dep("slang-capability-generator"):targetfile(), cmd_opts)
		batchcmds:compile(generator_files, objectfile)

		batchcmds:add_depfiles(sourcefile, target:dep("slang-capability-generator"):targetfile())
		batchcmds:set_depmtime(os.mtime(objectfile))
		batchcmds:set_depcache(target:dependfile(objectfile))
	end)
end)

rule("slang-reflect", function()
	on_load(function(target)
		target:add("deps", "slang-cpp-extractor")
	end)

	---comment
	---@param target Target
	---@param batchcmds BatchCommand
	---@param sourcebatch SourceBatch
	---@param opt TargetOpt
	on_buildcmd_files(function(target, batchcmds, sourcebatch, opt)
		local base_dir = path.join(target:autogendir(), "rules", "slang-generated")

		target:add("includedirs", base_dir)
		-- table.insert(target:objectfiles(), objectfile)

		local cmd_opts = sourcebatch.sourcefiles
		table.insert(cmd_opts, "-strip-prefix")
		table.insert(cmd_opts, "slang-")
		table.insert(cmd_opts, "-o")
		table.insert(cmd_opts, base_dir)
		table.insert(cmd_opts, "-output-fields")
		table.insert(cmd_opts, "-mark-suffix")
		table.insert(cmd_opts, "_CLASS")

		batchcmds:show_progress(opt.progress, "${color.build.object}compiling.slang-reflect-generator-header")
		batchcmds:mkdir(base_dir)
		batchcmds:vrunv(target:dep("slang-cpp-extractor"):targetfile(), cmd_opts)
		-- batchcmds:compile(generator_files, objectfile)

		batchcmds:add_depfiles(sourcefile, target:dep("slang-cpp-extractor"):targetfile())
	end)
end)

rule("slang-lookup-tables", function()
	---@param target Target
	on_load(function(target)
		target:add("packages", "spirv-headers")
	end)

	---@param target Target
	---@param batchcmds BatchCommand
	---@param sourcebatch SourceBatch
	---@param opt TargetOpt
	before_buildcmd(function(target, batchcmds, opt)
		local spirv = target:pkgs()["spirv-headers"]
		local spirv_include_dir = spirv:installdir("include")
		local input_json = path.join(spirv_include_dir, "spirv/unified1/extinst.glsl.std.450.grammar.json")

		local base_dir = path.join(target:autogendir(), "rules", "slang-lookup-tables")
		local generate_file = path.join(base_dir, "slang-lookup-GLSLstd450.cpp")
		local objectfile = target:objectfile(generate_file)

		local cmd_opts = { input_json }
		table.insert(cmd_opts, generate_file)
		table.insert(cmd_opts, "GLSLstd450")
		table.insert(cmd_opts, "GLSLstd450")
		table.insert(cmd_opts, "spirv/unified1/GLSL.std.450.h")

		batchcmds:show_progress(opt.progress, "${color.build.object}generating.slang-lookup-tables")
		batchcmds:mkdir(base_dir)
		batchcmds:vrunv(target:dep("slang-lookup-generator"):targetfile(), cmd_opts)

		batchcmds:show_progress(opt.progress, "${color.build.object}compiling.slang-lookup-tables")
		batchcmds:compile(generator_file, objectfile)
		batchcmds:add_depfiles(sourcefile, target:dep("slang-lookup-generator"):targetfile())
		batchcmds:set_depmtime(os.mtime(objectfile))
		batchcmds:set_depcache(target:dependfile(objectfile))
	end)
end)

target("slang-capability-def", function()
	set_kind("object")

	add_files("source/slang/*.capdef", { rule = "slang-capability-generator-header" })

	add_deps("slang-capability-generator")
end)

-- tools
target("slang-capability-generator", function()
	set_kind("binary")
	add_files("tools/slang-capability-generator/*.cpp")

	add_deps("compiler-core")
	add_packages("miniz", "lz4", "unordered_dense")
end)

target("slang-cpp-parser", function()
	set_kind("static")
	add_files("tools/slang-cpp-parser/*.cpp")

	add_deps("compiler-core")
	add_packages("miniz", "lz4", "unordered_dense")
end)

target("slang-cpp-extractor", function()
	set_kind("binary")
	add_files("tools/slang-cpp-extractor/*.cpp")

	add_includedirs("tools", { public = true })

	add_deps("compiler-core", "slang-cpp-parser")
	add_packages("miniz", "lz4", "unordered_dense")
end)

target("slang-embed", function()
	set_kind("binary")
	add_files("tools/slang-embed/*.cpp")

	add_deps("compiler-core", "core")
	add_packages("miniz", "lz4", "unordered_dense")
end)

target("slang-generate", function()
	set_kind("binary")
	add_files("tools/slang-generate/*.cpp")

	add_deps("compiler-core", "core")
	add_packages("miniz", "lz4", "unordered_dense")
end)

target("slang-lookup-generator", function()
	set_kind("binary")
	add_files("tools/slang-lookup-generator/*.cpp")

	add_deps("compiler-core", "core")
	add_packages("miniz", "lz4", "unordered_dense")
end)

target("slang-spirv-embed-generator", function()
	set_kind("binary")
	add_files("tools/slang-spirv-embed-generator/*.cpp")

	add_deps("compiler-core", "core")
	add_packages("miniz", "lz4", "unordered_dense", "spirv-headers")
end)
