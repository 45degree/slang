target('slang-capability-generator', function()
  set_kind('binary')
  add_files('slang-capability-generator/*.cpp')

  add_deps('compiler-core')
  add_packages('miniz', 'lz4', 'unordered_dense')
  set_policy('build.fence', true)
end)

target('slang-cpp-parser', function()
  set_kind('static')
  add_files('slang-cpp-parser/*.cpp')

  add_deps('compiler-core')
  add_packages('miniz', 'lz4', 'unordered_dense')
end)

target('slang-cpp-extractor', function()
  set_kind('binary')
  add_files('slang-cpp-extractor/*.cpp')

  add_includedirs('.', { public = true })

  add_deps('compiler-core', 'slang-cpp-parser')
  add_packages('miniz', 'lz4', 'unordered_dense')
  set_policy('build.fence', true)
end)

target('slang-embed', function()
  set_kind('binary')
  add_files('slang-embed/*.cpp')

  add_deps('compiler-core', 'core')
  add_packages('miniz', 'lz4', 'unordered_dense')
  set_policy('build.fence', true)
end)

target('slang-generate', function()
  set_kind('binary')
  add_files('slang-generate/*.cpp')

  add_deps('compiler-core', 'core')
  add_packages('miniz', 'lz4', 'unordered_dense')
  set_policy('build.fence', true)
end)

target('slang-lookup-generator', function()
  set_kind('binary')
  add_files('slang-lookup-generator/*.cpp')

  add_deps('compiler-core', 'core')
  add_packages('miniz', 'lz4', 'unordered_dense')
  set_policy('build.fence', true)
end)

target('slang-spirv-embed-generator', function()
  set_kind('binary')
  add_files('slang-spirv-embed-generator/*.cpp')

  add_deps('compiler-core', 'core')
  add_packages('miniz', 'lz4', 'unordered_dense', 'spirv-headers')
  set_policy('build.fence', true)
end)

target('slang-bootstrap', function()
  set_kind('binary')

  add_rules('slang-capability-generator-header')
  add_defines("SLANG_STATIC")

  add_includedirs('$(projectdir)/source/slang', '$(buildir)')
  add_configfiles('$(projectdir)/slang-tag-version.h.in')

  add_files('$(projectdir)/source/slang-record-replay/record/*.cpp')
  add_files('$(projectdir)/source/slang-record-replay/util/*.cpp')
  add_files('$(projectdir)/source/slangc/*.cpp')
  add_files('$(projectdir)/source/slang-core-module/slang-embedded-core-module.cpp')
  add_files('$(projectdir)/source/slang/*.cpp')

  add_deps('slang-generate-prelude', 'slang-generate-lookup-tables')
  add_deps('core', 'compiler-core', 'slang-reflect')
  add_deps('slang-embedded-core-module-source')

  add_packages('spirv-headers', 'unordered_dense')

  set_policy('build.fence', true)
end)
