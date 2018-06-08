local DEBUG = true

local tstrict = require "tstrict" (DEBUG)
local strict, typed, const, typed_def, const_def, final
  = tstrict.strict, tstrict.typed, tstrict.const, tstrict.typed_def, tstrict.const_def, tstrict.final

print("Version:", tstrict._VERSION)
print("Enabled:", tstrict._ENABLED)

print "make _G strict"
strict (_G)

local function texpect(t, exp)
  for k,v in pairs(exp) do
    if t[k] == nil then
      error("missing ["..k.."] is '"..v.."'", 2)
    end
    if t[k] ~= v then
      error("wrong ["..k.."] ~= '"..v.."' is '"..t[k].."'", 2)
    end
  end
end


do
  print "table keeps its identity"
  local tbl = {}
  assert (strict (tbl) == tbl)
end

do
  print "promote table strictness"
  local tbl = {'a', 'b', 'c', foo = 'foo', bar = 'bar'}
  assert (strict (tbl) == tbl)

  tbl[1] = 'A'
  tbl.VAR[4] = 'd'
  assert (typed (tbl) == tbl)
  assert(#tbl == 4)

  tbl.TYPED[5] = 'e'
  assert (const (tbl) == tbl)
  assert(#tbl == 5)

  tbl.CONST[6] = 'f'
  assert (final (tbl) == tbl)
  assert(#tbl == 6)
  texpect(tbl, {'A', 'b', 'c', 'd', 'e', 'f', foo = 'foo', bar = 'bar'})
end

do
  print "demote table strictness"
  local tbl = {'a', 'b', 'c', foo = 'foo', bar = 'bar'}
  assert (const (tbl) == tbl)
  tbl.CONST[4] = 'd'
  assert (typed (tbl) == tbl)
  tbl[4] = 'dd'
  tbl.TYPED[5] = 'e'
  assert (strict (tbl) == tbl)
  tbl[4] = 'ddd'
  texpect(tbl, {'a', 'b', 'c', 'ddd', 'e',foo = 'foo', bar = 'bar'})
end


do
  print "enforce final"
  local tbl = final {'a', 'b', 'c', foo = 'foo', bar = 'bar'}

  local ok, result = pcall(function() const (tbl) end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("readonly table"))
end

print "global functions must be defined"
function CONST.test()
  global_variable = true -- may raise an error
  return global_variable
end


print "calling test w/ undefined global_variable"
local ok, result = pcall(test)
assert(not DEBUG or not ok)


print "calling test w/ var defined global_variable"
VAR.global_variable = false
local ok, result = pcall(test)
assert(ok)
assert(global_variable == true)


print "calling test w/ typed defined global_variable"
global_variable = nil
TYPED.global_variable = false
local ok, result = pcall(test)
assert(ok)
assert(global_variable == true)


print "calling test w/ typed defined global_variable, type error"
global_variable = nil
TYPED.global_variable = "wrong type"
local ok, result = pcall(test)
assert(not DEBUG or not ok)
assert(not DEBUG or global_variable == "wrong type")


print "calling test w/ const defined global_variable"
global_variable = nil
CONST.global_variable = false
local ok, result = pcall(test)
assert(not DEBUG or not ok)
assert(not DEBUG or global_variable == false)


print "unsetting const works"
local ok, result = pcall(function () global_variable = nil end)
assert(ok)
assert(global_variable == nil)


print "redefining, x = x or 'new' idiom)"
VAR.global_variable = global_variable or 'new'
VAR.global_variable = global_variable or 'new'

global_variable = nil
TYPED.global_variable = global_variable or 'new'
TYPED.global_variable = global_variable or 'new'

global_variable = nil
CONST.global_variable = global_variable or 'new'
CONST.global_variable = global_variable or 'new'

global_variable = nil
CONSTRAIN.global_variable = {global_variable or 'new',
                             function(v) return v == 'new' end}
CONSTRAIN.global_variable = {global_variable or 'new',
                             function(v) return v == 'new' end}

do
  print "local table"
  local my = strict {}

  print "access to undefined name"
  assert(my.undefined_local == nil)

  my.CONST.a = "A"
  my.CONST.b = "B"
  my.TYPED.c = "C"
  my.CONSTRAIN.d = {"D", function(x) return x:match("^%u$") end}

  print "check members"
  assert(type(my.VAR) == 'table')
  assert(type(my.TYPED) == 'table')
  assert(type(my.CONST) == 'table')
  assert(type(my.CONSTRAIN) == 'table')

  assert(my.a == "A")
  assert(my.b == "B")
  assert(my.c == "C")
  assert(my.d == "D")
end

do
  local t = strict {}

  print("string indexed member")
  t.TYPED["foo"] = "bar"
  assert(t["foo"] == "bar")
  t["foo"] = "baz"
  assert(t["foo"] == "baz")

  print "strictness invariants, typed"
  local t = typed {a='alpha'}
  t.TYPED.a = 'alpha' -- same value works

  local ok,result = pcall(function () t.TYPED.a = 'alpha2' end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("already defined"))

  t.a = 'beta'
  local ok,result = pcall(function () t.a = 0 end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("type error"))

  print "strictness invariants, const"
  t.CONST.b = 'B'
  t.CONST.b = 'B'
  t.b = 'B'

  local ok,result = pcall(function () t.CONST.b = 'C' end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("already defined"))

  local ok,result = pcall(function () t.b = 'C' end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("constant value"))

  print "strictness invariants, const, erasing"
  local ok,result = pcall(function () t.CONST.b = nil end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("already defined"))

  t.b = nil
  assert(t.b == nil)
end

do
  print "strictness invariants, final"
  local f = final { a = "readonly"}

  local ok,result = pcall(function () f.a = 'blah' end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("readonly table"))

  local ok,result = pcall(function () f.CONST.a = 'blah' end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("explicit definition disabled"))

  local ok,result = pcall(function () f.a = nil end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("readonly table"))
end

do
  print "arrays init"
  local array = strict {1,2,3}
  assert(array[1] == 1)
  assert(#array == 3)
end


do
  print "arrays empty"
  local array = strict {}
  assert(#array == 0)

  print "arrays emptied"
  local array = strict {1,2,3}
  array[3] = nil
  array[2] = nil
  array[1] = nil
  assert(#array == 0)
end


do
  print "arrays, dynamic"
  local array = strict {}
  array.CONST[1] = "foo"
  array.CONST[2] = "bar"
  assert(array[1] == "foo")
  assert(array[2] == "bar")
  assert(#array == 2)
end


do
  print "arrays, global constraint"
  local array = strict {}
  array.CONSTRAIN[1] = {"foo", function(v) return v:match("^...$") end}
  assert(array[1] == "foo")
  array[1] = "bar"
  assert(array[1] == "bar")

  local ok,result = pcall(function () array[1] = "barf" end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("constraint error"))

  local ok,result = pcall(function () array[1] = 10 end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("constraint error"))

  array[1] = nil
  assert(array[1] == nil)
end


do
  print "arrays, cont"
  local array = typed {1,2,3}
  array[2] = 222
  assert (#array == 3)

  print "arrays, must be same definition mode"
  local ok,result = pcall(function () array.CONST[4] = 4 end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("array definition mode"))

  -- make array discontinous
  array.TYPED[5] = 5

  print "arrays, # disallowed on discontinous arrays"
  local ok,result = pcall(function () return #array end)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("discontinous array"))
end


do
  print "array, reset"
  local array = typed {1,2,3}
  assert (#array == 3)

  array[3] = nil
  assert (#array == 2)
  array[2] = nil
  array[1] = nil
  assert (#array == 0)

  -- now definition of another mode works
  print "arrays, new definition mode"
  array.CONST[1] = 11
  array.CONST[2] = 22

  assert (#array == 2)
  assert (array[1] == 11)
  assert (array[2] == 22)

  --TODO: check array on constrained
end


do
  print "numeric iteration"
  local tbl = const {'a', 'b', 'c', 'd', foo = 'foo', bar = 'bar'}

  local result = {}
  for i = 1, #tbl do
    result[i] = tbl[i]
  end

  assert (#result == 4)

  texpect(result, {'a', 'b', 'c', 'd'})
end


do
  print "ipairs iteration"
  local tbl = const {'a', 'b', 'c', 'd', foo = 'foo', bar = 'bar'}

  local result = {}
  for i,v in ipairs(tbl) do
    print(i,v)
    result[i] = v
  end

  assert (#result == 4)

  texpect(result, {'a', 'b', 'c', 'd'})
end


do
  print "pairs iteration"
  local tbl = const {'a', 'b', 'c', 'd', foo = 'foo', bar = 'bar'}

  local result = {}
  for k,v in pairs(tbl) do
    result[k] = v
  end

  texpect(result, {'a', 'b', 'c', 'd', foo = 'foo', bar = 'bar'})
end


do
  print "table library, legacy"
  local tbl =  {'a', 'b', 'c'}
  table.insert(tbl, 'd')

  assert(#tbl == 4)
  texpect(tbl, {'a', 'b', 'c', 'd'})
end

do
  print "table library, strict"
  local tbl = strict {'a', 'b', 'c'}
  table.insert(tbl, 'd')

  assert(#tbl == 4)
  texpect(tbl, {'a', 'b', 'c', 'd'})
end


do
  print "table library"
  local tbl = const {'a', 'b', 'c'}
  table.insert(tbl, 'd')

  assert(#tbl == 4)
  texpect(tbl, {'a', 'b', 'c', 'd'})

  assert(table.concat(tbl, '+') == "a+b+c+d")

  local r = table.remove(tbl, 3)
  assert(r == 'c')
  assert(#tbl == 3)
  texpect(tbl, {'a', 'b', 'd'})

  local tbl = const {'c', 'b', 'd', 'a'}
  table.sort(tbl)
  texpect(tbl, {'a', 'b', 'c', 'd'})

  texpect({table.unpack(tbl)}, {'a', 'b', 'c', 'd'})
end


do
  print "table library, final"
  local tbl = final {'c', 'b', 'a'}
  local ok,result = pcall(table.insert, tbl, 'd')
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("readonly table"))

  local tbl = final {'c', 'b', 'a'}
  local ok,result = pcall(table.remove, tbl, 2)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("readonly table"))

  local tbl = final {'c', 'b', 'a'}
  local ok,result = pcall(table.sort, tbl)
  assert(not DEBUG or not ok)
  assert(not DEBUG or result:match("readonly table"))

  local tbl = final {'c', 'b', 'a'}
  texpect({table.unpack(tbl)}, {'c', 'b', 'a'})
end
