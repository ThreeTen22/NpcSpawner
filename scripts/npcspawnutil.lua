dComp = {}

function dLog(item, prefix)
  if not prefix then prefix = "" end
  if type(item) ~= "string" then
    sb.logInfo(prefix.."  "..dOut(item))
  else 
    sb.logInfo(prefix.."  "..item)
  end
end

function dOut(input)
  if not input then input = "" end
  return sb.print(input)
end

function dLogJson(input, prefix)
  if prefix ~= nil then
    sb.logInfo(prefix)
  end
   sb.logInfo("%s", sb.printJson(input))
end

function dCompare(prefix, one, two)
  sb.logInfo(prefix)
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

function dComp.bool(input)
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

dComp["nil"] = function(input) return dLog("nil") end