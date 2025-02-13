target('core', function()
  set_kind('static')

  add_includedirs('$(projectdir)/include', { public = true })
  add_includedirs('.')

  add_defines('SLANG_USE_SYSTEM_UNORDERED_DENSE_HEADER')

  add_files('core/*.cpp')
  add_packages('miniz', 'lz4', 'unordered_dense')

  if is_plat('windows') then
    add_files('core/windows/*.cpp')
    add_syslinks('Shell32')
  elseif is_plat('linux', 'macosx') then
    add_files('core/unix/*.cpp')
  end
end)

target('compiler-core', function()
  set_kind('static')

  add_files('compiler-core/*.cpp')
  add_includedirs('.', { public = true })

  add_cxxflags('gxx::-fms-extensions')

  add_deps('core')
  add_packages('spirv-headers')
  add_packages('miniz', 'lz4', 'unordered_dense')

  if is_plat('windows') then
    add_files('compiler-core/windows/*.cpp')
  end

  if is_plat('windows') then
    add_syslinks('Ole32')
  end
end)

target('slang', function()
  if is_config('shared', true) then
    set_kind('shared')
    add_defines('SLANG_DYNAMIC')
    add_defines('SLANG_DYNAMIC_EXPORT')
  else
    set_kind('static')
    add_defines('SLANG_STATIC')
  end
  add_deps('slang-cpp-extractor', 'slang-lookup-generator', 'slang-spirv-embed-generator')
  add_includedirs('slang', '$(projectdir)/build')

  add_defines('SLANG_EMBED_CORE_MODULE')

  add_files('slang/*.cpp')
  add_files('slang-record-replay/record/*.cpp')
  add_files('slang-record-replay/util/*.cpp')
  add_rules('slang-reflect', 'slang-capability-generator-header', 'slang-meta-generate', 'slang-generate-prelude', "slang-generate-core-module-header")
  add_configfiles('$(projectdir)/slang-tag-version.h.in')

  add_files(
    'slang/slang-ast-support-types.h',
    'slang/slang-ast-base.h',
    'slang/slang-ast-decl.h',
    'slang/slang-ast-expr.h',
    'slang/slang-ast-modifier.h',
    'slang/slang-ast-stmt.h',
    'slang/slang-ast-type.h',
    'slang/slang-ast-val.h',
    { rule = 'slang-reflect' }
  )

  add_files('slang/*.meta.slang', { rule = 'slang-meta-generate' })
  add_files('slang/*.capdef', { rule = 'slang-capability-generator-header' })
  add_files('$(buildir)/slang-lookup-tables-generates/*.cpp', { always_added = true })
  add_files('slang-core-module/*.cpp')
  add_files('$(projectdir)/prelude/*-prelude.h', { rule = 'slang-generate-prelude' })

  before_build(function(target)
    import('core.project.task')
    import('core.project.config')
    task.run('generate-slang-lookup-tables', {}, path.join(config.buildir(), 'slang-lookup-tables-generates'))
  end)

  add_packages('spirv-headers', 'miniz', 'lz4', 'unordered_dense')
end)

target('slangc', function()
  set_kind('binary')

  add_files('slangc/*.cpp')
  add_deps('slang', 'compiler-core')

  add_packages('spirv-headers', 'miniz', 'lz4', 'unordered_dense')
end)

--- rules and tasks

task('generate-slang-lookup-tables', function()
  ---@param generate_dir string
  on_run(function(generate_dir)
    import('core.project.project')

    ---@type Package
    local spirv = project.required_packages()['spirv-headers']
    local spirv_include_dir = path.join(spirv:installdir(), 'include')
    local input_json = path.join(spirv_include_dir, 'spirv/unified1/extinst.glsl.std.450.grammar.json')

    ---@type Target
    local slang_lookup_generator = project.target('slang-lookup-generator')

    local cmd_opts = { input_json }
    table.insert(cmd_opts, path.join(generate_dir, 'slang-lookup-GLSLstd450.cpp'))
    table.insert(cmd_opts, 'GLSLstd450')
    table.insert(cmd_opts, 'GLSLstd450')
    table.insert(cmd_opts, 'spirv/unified1/GLSL.std.450.h')

    os.mkdir(generate_dir)
    os.vrunv(slang_lookup_generator:targetfile(), cmd_opts)

    input_json = path.join(spirv_include_dir, 'spirv/unified1/spirv.core.grammar.json')
    local output_file = path.join(generate_dir, 'slang-spirv-core-grammar-embed.cpp')

    ---@type Target
    local slang_spirv_embed_generator = project.target('slang-spirv-embed-generator')
    cmd_opts = { input_json, output_file }
    os.vrunv(slang_spirv_embed_generator:targetfile(), cmd_opts)
  end)
end)

-- rule("generate-slang-lookup-tables", function()
--   ---@param target Target
--   on_load(function(target)
--     target:add("deps", "slang-lookup-generator")
--   end)
--
-- 	before_buildcmd_file(function(target, batchcmds, sourcebatch, opt)
-- 		import("core.project.project")
--
-- 		---@type Package
-- 		local spirv = project.required_packages()["spirv-headers"]
-- 		local spirv_include_dir = path.join(spirv:installdir(), "include")
-- 		local input_json = path.join(spirv_include_dir, "spirv/unified1/extinst.glsl.std.450.grammar.json")
--
-- 		---@type Target
-- 		local slang_lookup_generator = target:dep("slang-lookup-generator"):targetfile()
--
-- 		local cmd_opts = { input_json }
-- 		table.insert(cmd_opts, path.join(generate_dir, "slang-lookup-GLSLstd450.cpp"))
-- 		table.insert(cmd_opts, "GLSLstd450")
-- 		table.insert(cmd_opts, "GLSLstd450")
-- 		table.insert(cmd_opts, "spirv/unified1/GLSL.std.450.h")
--
-- 		batchcmds:show_progress(opt.progress, "${color.build}generating.slang-lookup-tables")
-- 		os.mkdir(generate_dir)
-- 		os.vrunv(slang_lookup_generator:targetfile(), cmd_opts)
-- 	end)
-- end)

rule('slang-generate-core-module-header', function()
  ---@param target Target
  on_load(function(target)
    target:add('deps', 'slang-bootstrap')
    local base_dir = path.join(target:autogendir(), 'core-module-generated-header')
    target:add('includedirs', base_dir)
  end)

  before_buildcmd_file(function(target, batchcmds, sourcefile, opt)
    local base_dir = path.join(target:autogendir(), 'core-module-generated-header')
    local header_file = path.join(base_dir, 'slang-core-module-generated.h')

    local cmd_opts = {}
    table.insert(cmd_opts, '-archive-type')
    table.insert(cmd_opts, 'riff-lz4')
    table.insert(cmd_opts, '-save-core-module-bin-source')
    table.insert(cmd_opts, header_file)

    batchcmds:show_progress(opt.progress, '${color.build.object}generating.slang-core-module-header')
    batchcmds:mkdir(base_dir)
    batchcmds:vrunv(target:dep('slang-bootstrap'):targetfile(), cmd_opts)
  end)
end)

rule('slang-reflect', function()
  on_load(function(target)
    target:add('deps', 'slang-cpp-extractor')
    local base_dir = path.join(target:autogendir(), 'ast-reflect')
    target:add('includedirs', base_dir)
  end)

  ---comment
  ---@param target Target
  ---@param batchcmds BatchCommand
  ---@param sourcebatch SourceBatch
  ---@param opt TargetOpt
  before_buildcmd_files(function(target, batchcmds, sourcebatch, opt)
    local base_dir = path.join(target:autogendir(), 'ast-reflect')

    -- table.insert(target:objectfiles(), objectfile)

    local cmd_opts = sourcebatch.sourcefiles
    table.insert(cmd_opts, '-strip-prefix')
    table.insert(cmd_opts, 'slang-')
    table.insert(cmd_opts, '-o')
    table.insert(cmd_opts, path.join(base_dir, 'slang-generated'))
    table.insert(cmd_opts, '-output-fields')
    table.insert(cmd_opts, '-mark-suffix')
    table.insert(cmd_opts, '_CLASS')

    batchcmds:show_progress(opt.progress, '${color.build.object}compiling.slang-reflect-generator-header')
    batchcmds:mkdir(base_dir)
    batchcmds:vrunv(target:dep('slang-cpp-extractor'):targetfile(), cmd_opts)
    -- batchcmds:compile(generator_files, objectfile)

    batchcmds:add_depfiles(sourcefile, target:dep('slang-cpp-extractor'):targetfile())
  end)
end)

rule('slang-capability-generator-header', function()
  set_extensions('capdef')

  on_load(function(target)
    target:add('deps', 'slang-capability-generator')
  end)

  ---@param target Target
  ---@param batchcmds BatchCommand
  ---@param sourcebatch SourceBatch
  ---@param opt TargetOpt
  before_buildcmd_files(function(target, batchcmds, sourcebatch, opt)
    local base_dir = path.join(target:autogendir(), 'rules', 'slang-capability-generator')
    local generator_files = path.join(base_dir, 'slang-lookup-capability-defs.cpp')
    local objectfile = target:objectfile(generator_files)

    target:add('includedirs', base_dir)
    table.insert(target:objectfiles(), objectfile)

    local cmd_opts = sourcebatch.sourcefiles
    table.insert(cmd_opts, '--target-directory')
    table.insert(cmd_opts, base_dir)
    table.insert(cmd_opts, '--doc')
    table.insert(cmd_opts, 'docs/user-guide/a3-02-reference-capability-atoms.md')

    batchcmds:show_progress(opt.progress, '${color.build.object}compiling.slang-capability-generator')
    batchcmds:mkdir(base_dir)
    batchcmds:vrunv(target:dep('slang-capability-generator'):targetfile(), cmd_opts)
    batchcmds:compile(generator_files, objectfile)

    batchcmds:add_depfiles(sourcefile, target:dep('slang-capability-generator'):targetfile())
    batchcmds:set_depmtime(os.mtime(objectfile))
    batchcmds:set_depcache(target:dependfile(objectfile))
  end)
end)

rule('slang-meta-generate', function()
  on_load(function(target)
    target:add('deps', 'slang-generate')
    target:add('includedirs', path.join(target:autogendir(), 'slang-meta-generator'))
  end)

  ---@param target Target
  before_buildcmd_file(function(target, batchcmds, sourcefile, opt)
    local slang_generator = target:dep('slang-generate'):targetfile()
    local base_dir = path.join(target:autogendir(), 'slang-meta-generator')

    local cmd_opts = {}
    table.insert(cmd_opts, sourcefile)
    table.insert(cmd_opts, '--target-directory')
    table.insert(cmd_opts, base_dir)

    batchcmds:show_progress(opt.progress, '${color.build.object}compiling.meta.slang %s', sourcefile)
    batchcmds:mkdir(base_dir)
    batchcmds:vrunv(slang_generator, cmd_opts)

    target:add('includedirs', base_dir)
  end)
end)

rule('slang-generate-prelude', function()
  on_load(function(target)
    target:add('deps', 'slang-embed')
  end)

  on_buildcmd_file(function(target, batchcmds, sourcefile, opt)
    local slang_embed = target:dep('slang-embed'):targetfile()
    local base_dir = path.join(target:autogendir(), 'slang-prelude-generate')
    local sourcefile_cx = path.join(base_dir, path.basename(sourcefile) .. '.cpp')

    local objectfile = target:objectfile(sourcefile_cx)
    table.insert(target:objectfiles(), objectfile)

    local cmd_opts = {}
    table.insert(cmd_opts, sourcefile)
    table.insert(cmd_opts, vformat('$(projectdir)/include'))
    table.insert(cmd_opts, sourcefile_cx)

    batchcmds:show_progress(opt.progress, '${color.build.object}generating.prelude %s', sourcefile)
    batchcmds:mkdir(base_dir)
    batchcmds:vrunv(slang_embed, cmd_opts)
    batchcmds:compile(sourcefile_cx, objectfile)

    batchcmds:add_depfiles(sourcefile_lex)
    local dependfile = target:dependfile(objectfile)
    batchcmds:set_depmtime(os.mtime(dependfile))
    batchcmds:set_depcache(dependfile)
  end)
end)
