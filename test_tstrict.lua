DEBUG = true
local strict, var, typed, const, constrain = require "tstrict" (DEBUG)

strict (_G)

-- disable assert when DEBUG is false
local assert_real = assert
function assert(...)
  if DEBUG then
    assert_real(...)
  end
end


--: global functions must be defined
function CONST.test()
  global_variable = true -- may raise an error
  return global_variable
end


print "calling test w/ undefined global_variable"
local ok, result = pcall(test)
assert(not ok)


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
assert(not ok)
assert(global_variable == "wrong type")


print "calling test w/ const defined global_variable"
global_variable = nil
CONST.global_variable = false
local ok, result = pcall(test)
assert(not ok)
assert(global_variable == false)


print "unsetting const should fail"
local ok, result = pcall(function () global_variable = nil end)
assert(not ok)
assert(global_variable == false)

print()

local my = strict {}

my.CONST.a = "A"
my.CONST.b = "B"
my.TYPED.c = "C"
my.CONSTRAIN.d = {"D", function(x) return x:match("^%u$") end}


for k,v in pairs(my) do
    print ("result", k,v)
end


local t = strict {}

t.TYPED["foo"] = "bar"



-- arrays:

do
  local array = strict {}
  array.CONST[1] = "foo"
  assert(array[1] == "foo")
end


do
  local array = strict {}
  array.CONSTRAIN[1] = {"foo", function(v) return v:match("^...$") end}
  assert(array[1] == "foo")
  array[1] = "bar"
  assert(array[1] == "bar")
  --array[1] = "barf"
end


print ""
print "----------"
print ""

do
  local array = typed {1,2,3}

  -- make array discontinous
  array.TYPED[5] = 5
  print(array[5])

  -- remove array members
  array[1] = nil
  array[2] = nil
  array[3] = nil
  array[5] = nil

  -- now CONST works and array is continous again
  array.CONST[1] = 11
  array.CONST[2] = 22

  for i=1,#array do
    print(i,array[i])
  end
end
