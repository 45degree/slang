includes('slang-core-module')

target('core', function()
  set_kind('static')

  add_includedirs('$(projectdir)/include', { public = true })
  add_includedirs('.')

  add_defines('SLANG_USE_SYSTEM_UNORDERED_DENSE_HEADER')

  add_files('core/*.cpp')
  add_packages('miniz', 'lz4', 'unordered_dense')

  if is_os('windows') then
    add_files('core/windows/*.cpp')
    add_syslinks('Shell32')
  elseif is_os('linux') or is_os('macos') then
    add_files('core/unix/*.cpp')
  end
end)

target('compiler-core', function()
  set_kind('static')

  add_files('compiler-core/*.cpp')
  add_includedirs('.', { public = true })

  add_cxxflags('gxx::-fms-extensions')

  if is_plat("mingw") then
    add_defines("SLANG_ENABLE_DXIL_SUPPORT=0")
  end

  add_deps('core')
  add_packages('spirv-headers')
  add_packages('miniz', 'lz4', 'unordered_dense')

  if is_os('windows') then
    add_files('compiler-core/windows/*.cpp')
    add_syslinks('Ole32', 'Oleaut32', 'uuid')
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
  add_deps('slang-generate-prelude', 'slang-generate-lookup-tables', 'slang-reflect')
  add_headerfiles('$(projectdir)/include/*.h')
  remove_headerfiles('$(projectdir)/include/slang-gfx.h')

  add_includedirs('slang', '$(buildir)')

  add_defines('SLANG_EMBED_CORE_MODULE')

  add_files('slang/*.cpp')
  add_files('slang-record-replay/record/*.cpp')
  add_files('slang-record-replay/util/*.cpp')
  add_configfiles('$(projectdir)/slang-tag-version.h.in')

  add_packages('spirv-headers', 'miniz', 'lz4', 'unordered_dense')
  add_deps('slang-embedded-core-module-source', 'slang-embedded-core-module')
end)

target('slangc', function()
  set_kind('binary')

  add_files('slangc/*.cpp')
  add_deps('slang', 'compiler-core')

  add_packages('spirv-headers', 'miniz', 'lz4', 'unordered_dense')
end)

--- rules and tasks

target('slang-generate-lookup-tables', function()
  set_kind('object')
  add_deps('slang-lookup-generator', 'slang-spirv-embed-generator')

  on_load(function(target)
    target:add('files', path.join(target:autogendir(), 'slang-lookup-tables-generates/slang-lookup-GLSLstd450.cpp'), { always_added = true })
    target:add('files', path.join(target:autogendir(), 'slang-lookup-tables-generates/slang-spirv-core-grammar-embed.cpp'), { always_added = true })
  end)

  ---@param target Target
  before_build(function(target)
    local spirv = target:pkgs()['spirv-headers']
    local spirv_include_dir = path.join(spirv:installdir(), 'include')
    local input_json = path.join(spirv_include_dir, 'spirv/unified1/extinst.glsl.std.450.grammar.json')

    local generate_dir = path.join(target:autogendir(), 'slang-lookup-tables-generates')

    ---@type Target
    local slang_lookup_generator = target:dep('slang-lookup-generator')

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
    local slang_spirv_embed_generator = target:dep('slang-spirv-embed-generator')
    cmd_opts = { input_json, output_file }
    os.vrunv(slang_spirv_embed_generator:targetfile(), cmd_opts)
  end)

  add_packages('spirv-headers', 'unordered_dense')
end)

target('slang-reflect', function()
  set_kind('headeronly')

  --- @param target Target
  on_load(function(target)
    target:set('generate_dir', target:autogendir())
    target:add('includedirs', target:autogendir(), { public = true })
  end)

  before_build(function(target)
    local generate_dir = target:get('generate_dir')
    local files = {
      path.join(os.scriptdir(), 'slang/slang-ast-support-types.h'),
      path.join(os.scriptdir(), 'slang/slang-ast-base.h'),
      path.join(os.scriptdir(), 'slang/slang-ast-decl.h'),
      path.join(os.scriptdir(), 'slang/slang-ast-expr.h'),
      path.join(os.scriptdir(), 'slang/slang-ast-modifier.h'),
      path.join(os.scriptdir(), 'slang/slang-ast-stmt.h'),
      path.join(os.scriptdir(), 'slang/slang-ast-type.h'),
      path.join(os.scriptdir(), 'slang/slang-ast-val.h'),
    }

    -- local base_dir = target:autogendir()
    local cmd_opts = files
    table.insert(cmd_opts, '-strip-prefix')
    table.insert(cmd_opts, 'slang-')
    table.insert(cmd_opts, '-o')
    table.insert(cmd_opts, path.join(generate_dir, 'slang-generated'))
    table.insert(cmd_opts, '-output-fields')
    table.insert(cmd_opts, '-mark-suffix')
    table.insert(cmd_opts, '_CLASS')

    os.mkdir(generate_dir)
    os.vrunv(target:dep('slang-cpp-extractor'):targetfile(), cmd_opts)

    -- target:add('headerfiles', path.join(generate_dir, 'slang-generated', '*.h'))
    target:add('includedirs', base_dir, { public = true })
  end)

  add_deps('slang-cpp-extractor')
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

target('slang-generate-prelude', function()
  set_kind('object')
  add_rules('slang-generate-prelude')

  add_files('$(projectdir)/prelude/*-prelude.h', { rule = 'slang-generate-prelude' })
  add_packages('unordered_dense')
end)

rule('slang-generate-prelude', function()
  on_load(function(target)
    target:add('deps', 'slang-embed')
  end)

  ---@param target Target
  ---@param batchcmds BatchCommand
  ---@param sourcefile string
  ---@param opt TargetOpt
  before_buildcmd_file(function(target, batchcmds, sourcefile, opt)
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
