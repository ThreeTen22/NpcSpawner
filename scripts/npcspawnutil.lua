dComp = {}

function dLog(item, prefix)
  if not prefix then prefix = "" end
  if type(item) ~= "string" then
    sb.logInfo(prefix.."  "..dOut(item))
  else 
    sb.logInfo("%s",prefix.."  "..item)
  end
end

function dOut(input)
  if not input then input = "" end
  return sb.print(input)
end

function dLogJson(input, prefix, clean)
  local str = "\n"
  if toBool(clean) or toBool(prefix) then clean = 1 else clean = 0 end
  if prefix ~= "true" and prefix ~= "false" and prefix then
    str = prefix..str
  end
   local info = sb.printJson(input, clean)
   sb.logInfo("%s", str..info)
end

function dPrintJson(input)
  local info = sb.printJson(input,1)
  sb.logInfo(info)
  return info
end


function dCompare(prefix, one, two)

  dComp[type(one)](one) 
  dComp[type(two)](two) 
end

function dComp.string(input)
  return dLog(input, "string: ")
end

function dComp.table(input)
  return dLogJson(input, "table")
end

function dComp.number(input)
  return dLog(input, "number")
end

function dComp.boolean(input)
  return dLog(input, "bool: ")
end

function dComp.userdata(input)
  return dLogJson(input, "userdata:")
end

function valuesToKeys(list)
  local newList = {}
  local vName = ""
  for k,v in pairs(list) do
    vName = tostring(v)
    newList.vName = {}
  end
end

function keysToList(keyList)
  local newList = {}
  local count = 0
  for k,_ in pairs(keyList) do
    count = count + 1
    table.insert(newList,tostring(k))
  end
  return newList
end

function lowercaseCopy(v)
  if type(v) ~= "table" then
    return string.lower(v)
  else
    local c = {}
    for k,v in pairs(v) do
      if type(k) == "string" then k = string.lower(k) end
      c[k] = lowercaseCopy(v)
    end
    setmetatable(c, getmetatable(v))
    return c
  end
end

function logENV()
  for i,v in pairs(_ENV) do
    if type(v) == "function" then
      sb.logInfo("%s", i)
    elseif type(v) == "table" then
      for j,k in pairs(v) do
        sb.logInfo("%s.%s (%s)", i, j, type(k))
      end
    end
  end
end

function hasValue(t, value)
  for _,v in pairs(t) do
    if v == value then return true end
  end
  return false
end

function mergeUnique(t1, t2)
if not t2 or #t2 < 1 then return t1 end
local merged = util.mergeLists(t1,t2)
local hash = {}
local res = {}
  for _,v in ipairs(merged) do
     if (not hash[v]) then
         res[#res+1] = v
         hash[v] = true
     end
  end
  return res
end


function hasKey(t, value)
  for k,_ in pairs(t) do
    if k == value then return true end
  end
  return false
end

function getUserConfig(key)
  local config = root.getConfiguration(key)
  if not config then
    root.setConfiguration(key, {additionalSpecies = jarray(), additionalNpcTypes = jarray()})
    config = root.getConfiguration(key)
  end
  return root.getConfiguration(key)
end

function isContainerEmpty(itemBag)
   for k,v in pairs(itemBag) do
    if v then return false end
   end
   return true
end

function getPathStr(t, str)
    if str == "" then return t end
    local s, _ = string.find(str, ".", 1, true)
    if not s then return t[str] end
    return jsonPath(t,str)
end

function setPathStr(t, pathString, value)
    local s, _ = string.find(str, ".", 1, true)
    if not s then t[str] = value return end
    jsonSetPath(t, pathString,value)
end

function toBool(value)
    if value then
      if value == "true" then return true end
      if value == "false" then return false end 
    end
    return nil
end

function formatParam(strType,...)
    local params = {...}
    if #params == 0 then return nil end
    if strType == "boolean" then 
        local value = toBool(params[1])
        return value
    elseif strType == "integer" then
        local value = tonumber(params[1])
        if not value then return nil end
        return math.floor(value)
    elseif strType == "float" or strType == "double" then
        local value = tonumber(params[1])
        if not value then return nil end
        return value*1.0
    elseif strType == "array" then
        local returnTable = {}
        local value = ""
        for _,v in ipairs(params) do
            if tonumber(v) then
                value = tonumber(v)
            elseif toBool(v) then
                value = toBool(v)
            else
                value = v
            end
            returnTable.insert(returnTable,value)
        end
        return returnTable
    else
      return tostring(params[1])
    end
end

function toHex(v)
  return string.format("%02x", math.min(math.floor(v),255))
end

--toHex(v*tonumber(color:sub(0,2),16))..toHex(v*tonumber(color:sub(3,4),16))..toHex(v*tonumber(color:sub(5,6),16))
dComp["thread"] = function(input) dLog(input) end
dComp["function"] = function(input) sb.logInfo("%s", input) end
dComp["nil"] = function(input) return dLog("nil") end