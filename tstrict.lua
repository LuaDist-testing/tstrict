--license:
--: tstrict - yet another implementation for lua strict tables
--:
--: Copyright (C)
--:  2017                              Christian Thaeter <ct@pipapo.org>
--:
--: This program is free software: you can redistribute it and/or modify
--: it under the terms of the GNU General Public License as published by
--: the Free Software Foundation, either version 2 of the License, or
--: (at your option) any later version.
--:
--: This program is distributed in the hope that it will be useful,
--: but WITHOUT ANY WARRANTY; without even the implied warranty of
--: MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--: GNU General Public License for more details.
--:
--: You should have received a copy of the GNU General Public License
--: along with this program.  If not, see <http://www.gnu.org/licenses/>.
--:
--:


local rawset = rawset
local error = error
local setmetatable = setmetatable
local getmetatable = getmetatable
local keywords = {VAR = true, TYPED = true, CONSTRAIN = true, CONST = true}


local function tstrict_enabled(tbl, initmode, default, force)
  local constants, typed, constrained = {},{},{}

  -- array points to the table holding sequential 1..n entries
  -- whenever the sequence becomes broken, it is set to nil
  -- disabling the # operator.
  -- when #array is 0 it may be reassignd to another mode.
  local array

  local mt =  getmetatable (tbl) or {}
  setmetatable(tbl, mt)

  -- heuristic, should be good enough
  local function continous(t)
    local cnt = 0
    for k in pairs(t) do
      if type(k) == 'number' and k%1 == 0 then
        cnt = cnt+1
        if k > 1 and t[k-1] == nil then
          return
        end
      end
    end
    return cnt == rawlen(t) and t
  end

  -- for changing the strictness mode we must copy the members over
  -- while maintaining sequence.
  local function mvtable(src,dest)
    for i,v in ipairs(src) do
      dest[i],src[i] = v
    end
    for k,v in pairs(src) do
      if not keywords[k] and not dest[k] then
        dest[k],src[k] = v
       end
    end
    for k in pairs(src) do
      src[k] = nil
    end
  end


  local function tcall(...)
    local ok,result = pcall(...)
    return ok and result
  end

  local function ipairs_array ()
    return ipairs(array or {})
  end

  if initmode == 'CONST' then
    mvtable(tbl, constants)
    array = continous(constants)
    mt.__ipairs = ipairs_array
  elseif initmode == 'TYPED' then
    mvtable(tbl, typed)
    array = continous(typed)
    mt.__ipairs = ipairs_array
  elseif type(initmode) == 'function' then
    mvtable(tbl, constrained)
    array = continous(constrained)
    mt.__ipairs = ipairs_array
    for k,v in constrained do
        if tcall(initmode, v, k, tbl) then
          constrained[k] = {v, initmode}
        else
          error("constraint error", 2)
        end
    end
  else
    mt.__newindex = nil
    mt.__index = nil
    mt.__ipairs = nil
    for i,v in ipairs(tbl) do
      tbl[i] = v
    end
    for k,v in pairs(tbl) do
      if not keywords[k] and not tbl[k] then
        tbl[k] = v
      end
    end
    array = continous(tbl)
  end


  local function definitioncheck(k, v)
    if default == 'FINAL' then
      error("readonly table", 3)
    end
    if tbl[k] ~= nil then
      if (rawget(constrained, k) ~= nil and rawget(constrained, k)[1] == v[1])
        or tbl[k] == v
      then
        return false
      else
        error("already defined", 3)
      end
    end
    return true
  end


  local function arraycheck(k, t)
    if array and type(k) == 'number' and k%1 == 0 then
      if #array == 0 and k == 1 then
        array = t
        if t ~= tbl then
          mt.__ipairs = ipairs_array
        end
      elseif array ~= t then
        error("array definition mode", 3)
      elseif k ~= #array+1 then
        array = nil
      end
    end
  end


  if not force then
    constants.VAR = setmetatable ({}, {
        __newindex = function (_,k,v)
          arraycheck(k,tbl)
          if definitioncheck(k,v) then
            rawset(tbl,k,v)
          end
        end
    })

    constants.CONST = setmetatable({}, {
        __newindex = function (_,k,v)
          arraycheck(k,constants)
          if definitioncheck(k,v) then
            constants[k] = v
          end
        end
    })

    constants.TYPED = setmetatable({}, {
        __newindex = function (_,k,v)
          arraycheck(k,typed)
          if definitioncheck(k,v) then
            typed[k] = v
          end
        end
    })

    constants.CONSTRAIN = setmetatable({}, {
        __newindex = function (_,k,v)
          arraycheck(k,constrained)

          if definitioncheck(k,v) then
            assert(type(v) == 'table' and type(v[2]) == 'function',
                   "constraint must be a {value, function} pair"
            )
            if tcall(v[2], v[1], k, tbl) then
              constrained[k] = v
            else
              error("constraint error", 2)
            end
          end
        end
    })
  else

    local forbid_explicit = setmetatable({}, {
        __newindex = function ()
          error("explicit definition disabled", 2)
        end
    })

    constants.VAR = forbid_explicit
    constants.CONST = forbid_explicit
    constants.TYPED = forbid_explicit
    constants.CONSTRAIN = forbid_explicit
  end

  function mt.__newindex (_,k,v)

    if array
      and v == nil
      and type(k) == 'number'
      and k%1 == 0
      and k ~= #array
    then
      array = nil
    end

    if default == 'FINAL' then
      error("readonly table", 2)
    elseif constants[k] ~= nil then
      if v == nil then
        constants[k] = v
      elseif constants[k] ~= v then
        error("constant value", 2)
      end
    elseif typed[k] ~= nil then
      if v == nil or type(typed[k]) == type(v) then
        typed[k] = v
      else
        error("type error", 2)
      end
    elseif constrained[k] ~= nil then
      if v == nil then
        constrained[k] = nil
      else
        local c = constrained[k]
        if tcall(c[2], v, k, tbl) then
          c[1] = v
        else
          error("constraint error", 2)
        end
      end
    elseif default == 'CONST' then
      arraycheck(k,constants)
      if definitioncheck(k,v) then
        constants[k] = v
      end
    elseif default == 'TYPED' then
      arraycheck(k,typed)
      if definitioncheck(k,v) then
        typed[k] = v
      end
    elseif type(default) == 'function' then
      arraycheck(k,constrained)

      if definitioncheck(k,v) then
        if tcall(default, v, k, tbl) then
          constrained[k] = v
        else
          error("constraint error", 2)
        end
      end
    else
      error("not defined", 2)
    end

  end

  function mt.__index (_, k)
    if typed[k] ~= nil then
      return typed[k]
    elseif constants[k] ~= nil then
      return constants[k]
    elseif constrained[k] ~= nil then
      return constrained[k][1]
    end
  end


  function mt.__pairs ()
    local next = next

    local hidden_tables = {typed, constants, constrained}
    local tvalue = tbl
    local tpos
    local kpos

    return function ()
      local value

      ::again::
      kpos,value = next(tvalue,kpos)

      if kpos == nil then
        tpos,tvalue = next(hidden_tables, tpos)
        if tpos == nil then
          return
        end
        goto again
      end

      if tvalue == constrained then
        value = value[1]
      end

      return kpos,value
    end
  end


  function mt.__len ()
    if not array then
      error("discontinous array", 2)
    end
    return rawlen(array)
  end

  return tbl
end


local function tstrict_disabled(tbl)
  tbl.VAR = tbl
  tbl.CONST = tbl
  tbl.TYPED = tbl
  tbl.CONSTRAIN = setmetatable({}, {
      __newindex = function (_,k,v)
        tbl[k] = v[1]
      end
  })

  return tbl
end


return function (state, selector)
  local tstrict = state and tstrict_enabled or tstrict_disabled

  return tstrict (
    {
      _VERSION = "0.3",
      _ENABLED = not not state,
      strict = tstrict,
      typed = function (tbl) return tstrict(tbl, 'TYPED') end,
      const = function (tbl) return tstrict(tbl, 'CONST') end,
      typed_def = function (tbl) return tstrict(tbl, 'TYPED', 'TYPED') end,
      const_def = function (tbl) return tstrict(tbl, 'CONST', 'CONST') end,
      final = function (tbl) return tstrict(tbl, 'CONST', 'FINAL', true) end,
    },
    'CONST', 'FINAL'
  )
end


--PLANNED: how to let the user override __index __newindex and __pairs
