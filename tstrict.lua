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

local function tstrict_on(tbl, kind, constraint)
  local constants,typed,constrained,array,cont_array
  local ixcnt=0

  local function continous(t)
    local ret = true
    for k,_ in pairs(t) do
      if type(k) == 'number' and k%1 == 0 then
        ixcnt = ixcnt+1
        if k > 1 and t[k-1] == nil then
          ret = false
        end
      end
    end
    return ret
  end

  local function tcall(...)
    local ok,result = pcall(...)
    return ok and result
  end


  cont_array = continous(tbl)

  if kind == 'CONST' then
    constants = tbl
    if #tbl > 0 then
      array = constants
    end
    tbl = {}
    typed = {}
    constrained = {}
  elseif kind == 'TYPED' then
    typed = tbl
    if #tbl > 0 then
      array = typed
    end
    tbl = {}
    constants = {}
    constrained = {}
  elseif kind == 'CONSTRAIN' then
    assert(type(constraint) == 'function',
           "constraint must be a function"
    )

    constrained = tbl
    for k,v in constrained do
        if tcall(constraint,v, k, tbl) then
          constrained[k] = {v, constraint}
        else
          error("constraint error", 2)
        end
    end

    tbl = {}
    constants = {}
    typed = {}
  else
    constants = {}
    typed = {}
    constrained = {}
    if #tbl > 0 then
      array = tbl
    end
  end

  local mt =  getmetatable (tbl) or {}
  setmetatable(tbl, mt)

  local function ipairs_array ()
    return ipairs(array or {})
  end

  local function available(k)
    if rawget(tbl, k) ~= nil
      or rawget(constants, k) ~= nil
      or rawget(typed, k) ~= nil
      or rawget(constrained, k) ~= nil
    then
      error("already defined", 3)
    end
  end

  local function arraydef(k, t)
    if type(k) == 'number' and k%1 == 0 then
      if array == nil then
        array = t
        if array ~= tbl then
          mt.__ipairs = ipairs_array
        end
      elseif array ~= t then
        error("array definition", 3)
      end
      if cont_array and k ~= #t+1 then
        cont_array = false
      elseif k == 1 and ixcnt == 0 then
        cont_array = true
      end
      if array ~= tbl then
        ixcnt = ixcnt + 1
      end
    end
  end

  constants.VAR = setmetatable ({}, {
      __newindex = function (_,k,v)
        arraydef(k,tbl)
        available(k)
        rawset(tbl,k,v)
      end
  })

  constants.CONST = setmetatable({}, {
      __newindex = function (_,k,v)
        arraydef(k,constants)
        available(k)
        constants[k] = v
      end
  })

  constants.TYPED = setmetatable({}, {
      __newindex = function (_,k,v)
        arraydef(k,typed)
        available(k)
        typed[k] = v
      end
  })

  constants.CONSTRAIN = setmetatable({}, {
      __newindex = function (_,k,v)
        arraydef(k,constrained)
        available(k)

        assert(type(v) == 'table' and type(v[2]) == 'function',
               "constraint must be a {value, function}"
        )
        if tcall(v[2], v[1], k, tbl) then
          constrained[k] = v
        else
          error("constraint error", 2)
        end
      end
  })

  function mt.__newindex (_,k,v)
    if constants[k] ~= nil then
      error("constant value", 2)
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
    else
      error("not defined", 2)
    end

    if type(k) == 'number' and k%1 == 0 then
      if v == nil then
        ixcnt = ixcnt - 1
        if ixcnt > 0 then
          if k ~= #array then
            cont_array = false
          end
        else
          cont_array = true
          array = nil
        end
      end
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
    if not cont_array then
      error("discontinous array", 2)
    end
    return array and rawlen(array) or 0
  end

  return tbl
end


local function tstrict_off(tbl)
  if tbl.VAR then
    return tbl
  end
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



return function (state)
  local tstrict = state and tstrict_on or tstrict_off

  return tstrict
  ,      function (tbl) return tstrict(tbl, 'VAR') end
  ,      function (tbl) return tstrict(tbl, 'TYPED') end
  ,      function (tbl) return tstrict(tbl, 'CONST') end
  ,      function (tbl, constraint) return tstrict(tbl, 'CONSTRAIN', constraint)
         end
end


--PLANNED: how to let the user override __index __newindex and __pairs
