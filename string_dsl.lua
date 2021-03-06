-- Tools for string DSLs
-- Make up for lack of macros using interned strings and reflection.

-- Note that this is probably not a good idea.  I'm avoiding this
-- approach and am using s-expression syntax instead.

require ('lure.log')

local function trace(tag, expr)
   -- log(tag) ; log(": ") ; log_desc(expr)
end

local mod = {}

-- Alternative lambda syntax.
-- Since 5.2 loadstring is deprecated and setfenv is removed,
-- but load allows adding in the environment.  This should
-- be escaped.
-- if _VERSION == "Lua 5.1" then
-- end

function mod.lua_eval(lcode, env)
   local f = loadstring(lcode)
   if env then setfenv(f, env) end
   assert(f)
   local fun = f()
   return fun
end

function mod.lambda(s, fragment)
   assert(s and s.var and type(s.var) == 'string')
   trace("EXPAND", fragment)
   local lcode =
      table.concat(
         {"return function(",s.var,") return (",fragment,") end"},
         "")
   trace("LCODE", lcode)
   local fun = mod.lua_eval(lcode, s.env)
   return fun
end

function mod.memo_eval(s, compile, str)
   local memo = s.memo
   if memo then
      -- Strings are interned.
      local val = memo[str]
      if val then
         trace("MEMO",str)
         return val
      end
   end
   local val = compile(s, str)
   if memo then
      memo[str] = val
   end
   return val
end

return mod
