-- Scheme files are wrapped as strings inside this module.
local asset = require('lure.asset_scm')
local smc   = require('lure.smc')

local function compile(filename)
   local forms = {
      -- extensions
      require('lure.smc_cspc'),
      require('lure.smc_co'),
   }
   local comp = smc.new({forms = forms})
   comp.write = function(self, str) io.stdout:write(str) end
   comp:compile_module_file(filename, asset)
end

local function run(w)
   compile('test1.sm')
   compile('test2.sm')
   compile('test_co.sm')
end

return { run = run }
