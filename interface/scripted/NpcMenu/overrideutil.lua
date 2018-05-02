require("/scripts/npcspawnutil.lua")

function override.set(curO, cur, setParams, ...)
    if (not setParams) or setParams == "" then 
      return false, "no parameter given"
    end
    local setParam = config.getParameter("overrideConfig.setParams."..setParams)
    if not setParam then 
      --dLog("Cannot find parameter") 
      return false, "Cannot find parameter:"..setParams.." spelling error?" 
    end
    local formattedParam = npcUtil.formatParam(setParam[2], ...)
    local setPath = config.getParameter("overrideConfig.path."..setParam[1])
    if not setPath then 
      --dLog("cannot find path to parameter") 
      return false, "cannot find path to parameter" 
    end
    --Check if its not a path but a variable in the self table.
    if setPath == "selfVariable" then
      if type(formattedParam) == "nil" then dLog("formatted incorrectly") return false, ("value given incorrectly formatted: Expect: "..setParam[2]) end
      if type(self[setParam[1]]) ~= "nil" then
        self[setParam[1]] = formattedParam
        return true, "parameter set"
      else
        return false, string.format("no variable named: %s was found inside self", setParam[1])
      end
    else
      local setPathTable = getPathStr(curO, setPath)
      if not setPathTable then 
        setPathTable = setPathStr(curO,setPath,{})
      end
      --dLog(setPathTable)
      
      if type(formattedParam) == "nil" then dLog("formatted incorrectly") return false, ("value given incorrectly formatted: Expect: "..setParam[2]) end
      setPathTable[setParam[1]] = formattedParam
      return true, "parameter set"
    end
    return false, "set could not complete for unknown reasons"
  end
  
function override.detach()
  local initInfo = world.getObjectParameter(pane.containerEntityId(), "npcArgs")
  local curSpecies = self.currentSpecies
  local curSeed =  self.currentSeed
  local curType = self.currentType
  local curLevel = self.currentLevel
  local errs = {}
  if curSpecies ~= initInfo.npcSpecies then
    table.insert(errs, "Species")
  end
  if curSeed ~= initInfo.npcSeed then
    table.insert(errs, "Seed")
  end
  if curType ~= initInfo.npcType then
    table.insert(errs, "npctype")
  end
  local npcParam = initInfo.npcParam or {}
  dLogJson(self.identity, "identity")
  dLogJson(npcParam.identity, "identity")
  if not compare(self.identity, npcParam.identity) then
    table.insert(errs, "identity")
  end
  if not compare(self.scriptConfig, npcParam.scriptConfig) then
    table.insert(errs, "Behavior and/or equipped items")
  end
  if not compare(self.items, npcParam.items) then
    table.insert(errs, "Equippied Items")
  end
  if #errs > 0 then
    local str = "Unable to detach:  Inconsistancies found in your npc's parameters:\n"
    for _,v in ipairs(errs) do
      str = str.."\n"..v
    end
    str = str.."\n\nEither finalize your changes by pressing the activate button, or close and reopen this panel.  After doing so, enter the command again."
    return false, str 
  end
  world.sendEntityMessage(pane.containerEntityId(), "detachNpc")
  return true
end

function override.insert(_,_,name, ...)
  local userConfig = nil
  local key = nil
  local list = {...}
  local successes = {}
  local failures = {}
  local selfTable = nil
  if name == "additionalspecies" then
    key = "npcSpawnerPlus.additionalSpecies"
    for i,v in ipairs(list) do
      local path = self.getSpeciesPath(v)
      local success = pcall(getAsset, path)
      if success then
        table.insert(successes, v)
      else
        table.insert(failures, v)
      end
      if not isEmpty(successes) then
        self.speciesList = npcUtil.mergeUnique(self.speciesList, successes)
        table.sort(self.speciesList)
      end
    end
  elseif name == "additionalnpctypes" then
    key = "npcSpawnerPlus.additionalNpcTypes"
    for i,v in ipairs(list) do
      local success = pcall(root.npcConfig, v)
      if success then
        table.insert(successes, v)
      else
        table.insert(failures, v)
      end
      if not isEmpty(successes) then
        self.npcTypeList = npcUtil.mergeUnique(self.npcTypeList, successes)
        table.sort(self.npcTypeList)
      end
    end
  else
    return false, "listName not given"
  end
  for i,v in ipairs(successes) do
    override.outputStr("Added "..v)
  end
  for i,v in ipairs(failures) do
    override.outputStr("Failed to add "..(v or "-"))
  end
  override.outputStr("\n Note:  Due to patch 1.3 changes, added species/npctypes will NOT be saved after the panel closes.")

  return true
end

function override.clear()
  widget.clearListItems(self.infoList)
  widget.setText(self.overrideTextBox, "")
  widget.setText(self.infoLabel, "")
  return true
end

function override.clearcache()
  world.setProperty(self.npcTypeStorage, {})
  widget.setText(self.overrideTextBox, "")
  return true
end

function override.output(curO, _, configType, label, jsonPath)

  local output = nil
  local success = false
  local prefix = ""
  local replaceSelf = compare(label, "self")
  local errorStr = nil
  if configType == "override" then
    output = curO or {}
    success = true
    if jsonPath then
      jsonPath = label.."."..jsonPath
    else
      jsonPath = label
    end
  elseif configType == "species" then
    if replaceSelf then label = self.currentSpecies end
    local assetPath =  self.getSpeciesPath(label)
    errorStr = "cannot get asset using path: %s"
    success, output =  pcall(getAsset, assetPath)
  elseif configType == "npctype" then
    if replaceSelf then label = self.currentType end
    errorStr = "cannot get npcConfig: %s"
    success, output = pcall(root.npcConfig, label)
  else
    return false, "could not understand: "..(configType or "2nd parameter")
  end
  if jsonPath then
    output = sb.jsonQuery(output, jsonPath, output[label]) or output
    success = (output and true)
  end
  if (not success) and errorStr then
    if jsonPath then
      jsonPath = "."..jsonPath
    else
      jsonPath = ""
    end
    output = string.format(errorStr, label..jsonPath)
  end
  local oldText = widget.getData(self.infoLabel) or ""
  output = dPrintJson(output)
  output = string.format("%s\n%s  was successful? %s\n->",oldText, prefix, success)..output
  widget.setText(self.infoLabel, output)
  widget.setData(self.infoLabel, output)
  return success
end

function override.outputStr(str)
  widget.clearListItems(self.infoList)
  local oldText = widget.getData(self.infoLabel) or ""
  output = string.format("%s\n \n%s",oldText, str)
  widget.setText(self.infoLabel, output)
  widget.setData(self.infoLabel, output)
end