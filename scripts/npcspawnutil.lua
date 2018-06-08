require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"

dComp = {}
npcUtil = {} 
--local func = testTable.func1


function dLog(item, prefix)
  if not prefix then prefix = "" end
  if type(item) ~= "string" then
    sb.logInfo("%s",prefix.."  "..dOut(item))
  else 
    sb.logInfo("%s",prefix.."  "..dOut(item))
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
  sb.logInfo("%s",info)
  return info
end


function dCompare(prefix, one, two)
  dLog(prefix)
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

dComp["thread"] = function(input) return dLog(input) end
dComp["function"] = function(input) return sb.logInfo("%s", input) end
dComp["nil"] = function(input) return dLog("nil") end




function getAsset(assetPath)
  return root.assetJson(assetPath)
end

function getPathStr(t, str)
    if str == "" then return t end
    return jsonPath(t,str) or t[str]
end

function setPathStr(t, str, value)
    if str == "" then t[str] = value return end
    return jsonSetPath(t, str,value)
end

function toHex(v)
  return string.format("%02x", math.min(math.floor(v),255))
end

function toBool(value)
    if value then
      if value == "true" then return true end
      if value == "false" then return false end 
    end
    return nil
end

function npcUtil.checkIfNpcIs(v, npcConfig,typeParams)
    for k,v2 in pairs(typeParams) do
      local value = jsonPath(npcConfig, k)
      if (value and v2) then return true end
    end
    return false
end

function npcUtil.jsonToDirective(directiveJson)
  local prefix = ""
  for k,v in pairs(directiveJson) do
    prefix = prefix..string.format(";%06x=%06x","0x"..k,"0x"..v)
  end
  return prefix
end

function npcUtil.compareDirectiveToColor(directive, json)
  if type(json) ~= "table" or (tostring(directive) == "") then return false end
  local _,set = next(json)
  if type(set) ~= "table" then return false end
  local k,_  = next(set)
  return string.match(directive,string.format("%06x=", "0x"..k))
end

function npcUtil.formatParam(strType,...)
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

function npcUtil.getDirectiveAtEnd(directiveBase)
  local returnValue = ""
  local split = util.split(directiveBase, "?replace")
  local indx = #split
  if indx < 2 then 
    return nil 
  end
  while indx > 2 do
    if tostring(split[indx]) ~= ""  and string.find(split[indx], "=") then
      break
    end
    indx = indx - 1
  end 
  local table = {}
  for k, v in string.gmatch(split[indx],"(%w+)=(%w+)") do
    table[string.lower(k)] = string.lower(v)
  end
  return table
end

function npcUtil.getGenderIndx(name, genderTable)
  for i,v in ipairs(genderTable) do
    if v.name == name then return i end
  end
end

function npcUtil.parseArgs(args, defaults)
  for k,v in pairs(args) do
    defaults[k] = v
  end
  return defaults
end

function npcUtil.getWorldStorage(id, modVersion)
  local worldStorage = world.getProperty(id)
  local clearCache = false
  if not (worldStorage and worldStorage.iIcon) then 
    worldStorage = {iIcon = {}, time = world.time(), modVersion = modVersion} 
  end

  if worldStorage.modVersion ~= modVersion then
    worldStorage.modVersion = modVersion
    clearCache = true
  end
  worldStorage.time = worldStorage.time or 0
  if (worldStorage.time + 800) < world.time() then
    clearCache = true
  end

  return worldStorage, clearCache
end

function npcUtil.getPersonality(npcType, seed)
  local config = root.npcConfig(npcType).scriptConfig.personalities
  return util.weightedRandom(config, seed)
end


function npcUtil.isContainerEmpty(itemBag)
   for k,v in pairs(itemBag) do
    if v ~= nil then return false end
   end
   return true
end

function npcUtil.mergeUnique(t1, t2)
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

function npcUtil.replaceValueInList(list, value, repl)
  for i,v in ipairs(list) do
    if v == value then
      list[i] = repl
      return true
    end
  end
  return false
end

function npcUtil.modVersion() 
  return root.assetJson("/interface/scripted/NpcMenu/modConfig.config:modVersion")
end

function npcUtil.replaceDirectives(directive, directiveJson)
  
  if not directive and type(directive) == "nil" then return nil end
  local splitDirectives = util.split(directive,"?replace")

  for i,v in ipairs(splitDirectives) do
    if not (v == "") then
        local k = string.match(v, "(%w+)=%w+")
        if directiveJson[k] or directiveJson[string.upper(k)] or directiveJson[string.lower(k)] then
            splitDirectives[i] = npcUtil.jsonToDirective(directiveJson)
        end
    end
  end
  local returnString = ""
  for i,v in ipairs(splitDirectives) do
    if v ~= "" then
      returnString = returnString.."?replace"..v
    end
  end
  return returnString
end

--overriding function found in util.lua so I can comment out the logInfo clutter.  Its functionality is untouched.
function setPath(t, ...)
  local args = {...}
  --sb.logInfo("args are %s", args)
  if #args < 2 then return end

  for i,child in ipairs(args) do
    if i == #args - 1 then
      t[child] = args[#args]
      return
    else
      t[child] = t[child] or {}
      t = t[child]
    end
  end
end

function npcUtil.buildItemOverrideTable(t)
  local override = t or {}
  local container = nil
  table.insert(override, {})
  container = override[1]
  table.insert(container, 0)
  table.insert(container, {})
  container = override[1][2]
  table.insert(container, {})
  return override
end
----[[
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
--]]

--toHex(v*tonumber(color:sub(0,2),16))..toHex(v*tonumber(color:sub(3,4),16))..toHex(v*tonumber(color:sub(5,6),16))
