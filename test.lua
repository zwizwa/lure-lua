local test = {}

local ins = table.insert

-- First make sure all the modules load properly.
-- lure.meta is generated from files in uc_tools/lua/lure/*.lua
local meta = require('lure.meta')
local mod = {}
local test = {}
for name in pairs(meta.modules) do
   if name ~= 'test' then
      mod[name] = require('lure.' .. name)
   else
      -- We are in test, avoid loop.
   end
end

local function wrap_rockspec(version, modules_tab)

local modules = {}
for k in pairs(modules_tab) do
   ins(modules, {"    ['lure.",k,"'] = '",k,".lua',","\n"})
end

return {
'package = "lure"\n',
'version = "', version, "-1'\n",
'source = {\n',
' url = "https://github.com/zwizwa/lure-lua/archive/v',version,'.zip",\n',
' dir = "lure-lua-',version,'",\n',
'}\n',
[[

description = {
  summary    = "Lua library for writing Scheme interpreters/compilers",
  homepage   = "https://github.com/zwizwa/lure-lua",
  license    = "MIT/X11",
  maintainer = "Tom Schouten",
  detailed   = "Lua wrappers for writing Scheme interpreters and compilers.",
}

dependencies = {
  "lua >= 5.1"
}

build = {
  type = "builtin",
  module = {
]],
modules,
[[
    },
  },
]]
}
end

-- Print out the modules list for the specs file.
local w = mod.iolist.io_writer(io.stdout)
function test.gen_rockspec(version)
   assert(version)
   w(wrap_rockspec(version,meta.modules))
end

-- This is the one advertised on the luarocks page.
function test.run()
   w("Running Lure Tests\n")
   for k in pairs(mod) do
      if k:sub(1,5) == 'test_' then
         w("*** ",k,"\n")
         mod[k].run(w)
      end
   end

end
return test
