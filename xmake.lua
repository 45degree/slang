add_rules('mode.release', 'mode.debug')

package('SPIRV-headers', function()
  set_base('spirv-headers')
  add_urls('https://github.com/KhronosGroup/SPIRV-Headers.git')
end)

add_requires('miniz', 'lz4', 'unordered_dense')
add_requires('SPIRV-headers e7294a8ebed84f8c5bd3686c68dbe12a4e65b644', { alias = 'spirv-headers' })
set_languages('c11', 'cxx17')

add_defines('SLANG_USE_SYSTEM_SPIRV_HEADER')

option('shared', function()
  set_default(true)
end)

if is_os('windows') then
  add_defines('WIN32_LEAN_AND_MEAN', 'VC_EXTRALEAN', 'NOMINMAX', 'UNICODE', '_UNICODE')
end

-- tools
includes('tools')
includes('source')
