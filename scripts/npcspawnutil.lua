require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"
require "/scripts/loggingutil.lua"

npcUtil = {} 
--local func = testTable.func1

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
    prefix = string.format("%s;%s=%s",prefix,k,v)
  end
  return prefix
end

function npcUtil.compareDirectiveToColor(directive, json)
  if type(json) ~= "table" or (tostring(directive) == "") then return false end
  local _,set = next(json)
  if type(set) ~= "table" then return false end
  local k,v  = next(set)
  k = string.lower(k)
  v = string.lower(v)
  return string.match(directive,tostring(k).."=")
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
       if not hash[v] then
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
    if v ~= "" then
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
  table.insert(t, {[1]=0, [2]={[1]={}}})
  return t
end




--[[
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
