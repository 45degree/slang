target("core", function()
	set_kind("static")

	add_includedirs("$(projectdir)/include", { public = true })
	add_includedirs(".")

	add_defines("SLANG_USE_SYSTEM_UNORDERED_DENSE_HEADER")

	add_files("core/*.cpp")
	add_packages("miniz", "lz4", "unordered_dense")

	if is_plat("windows") then
		add_files("core/windows/*.cpp")
		add_syslinks("Shell32")
	elseif is_plat("linux", "macosx") then
		add_files("core/unix/*.cpp")
	end
end)

target("compiler-core", function()
	set_kind("static")

	add_files("compiler-core/*.cpp")
	add_includedirs(".", { public = true })

	add_cxxflags("gxx::-fms-extensions")

	add_deps("core")
	add_packages("spirv-headers")
	add_packages("miniz", "lz4", "unordered_dense")

	if is_plat("windows") then
		add_files("compiler-core/windows/*.cpp")
	end
end)

target("slang", function()
	if is_config("shared", true) then
		set_kind("shared")
    add_defines("SLANG_DYNAMIC")
    add_defines("SLANG_DYNAMIC_EXPORT")
	else
		set_kind("static")
    add_defines("SLANG_STATIC")
	end
	add_deps("slang-cpp-extractor", "slang-capability-generator", "slang-lookup-generator")
	add_includedirs("slang", "$(projectdir)/build")

	add_files("slang/*.cpp")
	add_files("slang-record-replay/record/*.cpp")
	add_files("slang-record-replay/util/*.cpp")
  add_rules("slang-reflect")
  add_configfiles("$(projectdir)/slang-tag-version.h.in")

	add_files(
		"slang/slang-ast-support-types.h",
		"slang/slang-ast-base.h",
		"slang/slang-ast-decl.h",
		"slang/slang-ast-expr.h",
		"slang/slang-ast-modifier.h",
		"slang/slang-ast-stmt.h",
		"slang/slang-ast-type.h",
		"slang/slang-ast-val.h",
		{ rule = "slang-reflect" }
	)

	add_files("slang/*.capdef", { rule = "slang-capability-generator-header" })
	add_files("$(buildir)/slang-lookup-tables-generates/*.cpp", { always_added = true })

	before_build(function()
		import("core.project.task")
		import("core.project.config")
		task.run("generate-slang-lookup-tables", {}, path.join(config.buildir(), "slang-lookup-tables-generates"))
	end)

	add_packages("spirv-headers", "miniz", "lz4", "unordered_dense")
end)

--- rules and tasks

task("generate-slang-lookup-tables", function()
	---@param generate_dir string
	on_run(function(generate_dir)
		import("core.project.project")

		---@type Package
		local spirv = project.required_packages()["spirv-headers"]
		local spirv_include_dir = path.join(spirv:installdir(), "include")
		local input_json = path.join(spirv_include_dir, "spirv/unified1/extinst.glsl.std.450.grammar.json")

		---@type Target
		local slang_lookup_generator = project.target("slang-lookup-generator")

		local cmd_opts = { input_json }
		table.insert(cmd_opts, path.join(generate_dir, "slang-lookup-GLSLstd450.cpp"))
		table.insert(cmd_opts, "GLSLstd450")
		table.insert(cmd_opts, "GLSLstd450")
		table.insert(cmd_opts, "spirv/unified1/GLSL.std.450.h")

		os.mkdir(generate_dir)
		os.vrunv(slang_lookup_generator:targetfile(), cmd_opts)

		input_json = path.join(spirv_include_dir, "spirv/unified1/spirv.core.grammar.json")
		local output_file = path.join(generate_dir, "slang-spirv-core-grammar-embed.cpp")

		---@type Target
		local slang_spirv_embed_generator = project.target("slang-spirv-embed-generator")
		cmd_opts = { input_json, output_file }
		os.vrunv(slang_spirv_embed_generator:targetfile(), cmd_opts)
	end)
end)

rule("slang-reflect", function()
	on_load(function(target)
		target:add("deps", "slang-cpp-extractor")
		local base_dir = path.join(target:autogendir(), "ast-reflect")
    print(base_dir)
		target:add("includedirs", base_dir)
	end)

	---comment
	---@param target Target
	---@param batchcmds BatchCommand
	---@param sourcebatch SourceBatch
	---@param opt TargetOpt
	on_buildcmd_files(function(target, batchcmds, sourcebatch, opt)
		local base_dir = path.join(target:autogendir(), "ast-reflect")

		-- table.insert(target:objectfiles(), objectfile)

		local cmd_opts = sourcebatch.sourcefiles
		table.insert(cmd_opts, "-strip-prefix")
		table.insert(cmd_opts, "slang-")
		table.insert(cmd_opts, "-o")
		table.insert(cmd_opts, path.join(base_dir, "slang-generated"))
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

rule("slang-capability-generator-header", function()
	set_extensions("capdef")

	on_load(function(target)
		target:add("deps", "slang-capability-generator")
	end)

	---@param target Target
	---@param batchcmds BatchCommand
	---@param sourcebatch SourceBatch
	---@param opt TargetOpt
	before_buildcmd_files(function(target, batchcmds, sourcebatch, opt)
		local base_dir = path.join(target:autogendir(), "rules", "slang-capability-generator")
		local generator_files = path.join(base_dir, "slang-lookup-capability-defs.cpp")
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
