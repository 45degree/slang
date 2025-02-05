target('slang-embedded-core-module-source', function()
  set_kind('object')

  add_includedirs('$(projectdir)/source/slang')
  add_defines('SLANG_EMBED_CORE_MODULE_SOURCE')

  add_deps('core', 'slang-reflect')
  add_rules('slang-capability-generator-header')
  add_rules('slang-meta-generate')

  add_files('$(projectdir)/source/slang/*.meta.slang', { rule = 'slang-meta-generate' })
  add_files('$(projectdir)/source/slang/*.capdef', { rule = 'slang-capability-generator-header' })
  add_files('slang-embedded-core-module-source.cpp')

  add_packages('unordered_dense', 'spirv-headers')
end)

target('slang-embedded-core-module', function()

  set_kind('object')
  if is_config('shared', true) then
    add_defines('SLANG_DYNAMIC')
    add_defines('SLANG_DYNAMIC_EXPORT')
  else
    add_defines('SLANG_STATIC')
  end

  set_kind('object')

  ---@param target Target
  on_load(function(target)
    target:add('includedirs', target:autogendir())
  end)

  ---@param target Target
  before_build(function(target)
    local slang_bootstrap = target:dep('slang-bootstrap'):targetfile()
    local generate_dir = target:autogendir()

    local cmd_opts = {}
    table.insert(cmd_opts, '-archive-type')
    table.insert(cmd_opts, 'riff-lz4')
    table.insert(cmd_opts, '-save-core-module-bin-source')
    table.insert(cmd_opts, path.join(generate_dir, 'slang-core-module-generated.h'))
    table.insert(cmd_opts, '-save-glsl-module-bin-source')
    table.insert(cmd_opts, path.join(generate_dir, 'slang-glsl-module-generated.h'))

    os.mkdir(generate_dir)
    os.vrunv(slang_bootstrap, cmd_opts)
  end)

  add_files("slang-embedded-core-module.cpp")
  add_defines('SLANG_EMBED_CORE_MODULE')

  add_deps('slang-bootstrap', 'core')

  add_packages('unordered_dense', 'spirv-headers')
end)

rule('slang-capability-generator-header', function()
  set_extensions('capdef')

  ---@param target Target
  on_load(function(target)
    target:add('deps', 'slang-capability-generator')
    target:add('includedirs', path.join(target:autogendir(), 'rules', 'slang-capability-generator'), { public = true })
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
