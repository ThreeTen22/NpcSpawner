require "/scripts/util.lua"
require "/scripts/npcspawnutil.lua"

spnPersonality = {}
modNpc = {}
Generate = {}
Refine = {}
IO = {}

function init()
  self.returnInfo = {}
  sb.logInfo("NpcPanelMenu: init")
  self.portraits = {
    "portraitSlot01",
    "portraitSlot02",
    "portraitSlot03",
    "portraitSlot04",
    "portraitSlot05",
    "portraitSlot06",
    "portraitSlot07",
    "portraitSlot08",
    "portraitSlot09",
    "portraitSlot10",
    "portraitSlot11",
    "portraitSlot12",
    "portraitSlot13",
    "portraitSlot14",
    "portraitSlot15",
    "portraitSlot16",
    "portraitSlot17",
    "portraitSlot18",
    "portraitSlot19",
    "portraitSlot20"
    }

  self.assetParams = world.getObjectParameter(pane.containerEntityId(),"getAssetParams")
  dLog(self.assetParams)
  self.gettingNpcData = nil
 
	self.sendingSpecies = nil
	self.sendingSeedValue = nil
  self.sendingType = nil

  self.npcDataInit = false

  self.sendingData = nil

  self.currentSpecies = "human"
  self.currentSeed = 0
  self.currentType = "nakedvillager"
  self.currentIdentity = {}
  self.currentOverride = {identity = {}, items = {}}
  self.currentLevel = 10

	self.raceButtons = {}

  self.hairColor = {}
  self.bodyColor = {}
  self.undyColor = {}
  self.facialHairColor = {}
  self.facialSubMaskColor = {}

  self.seedInput = 0

  self.personalityIndex = 0

  self.returnInfoColors = {}

  --LIST VARS--
  self.scrollArea = "techScrollArea"
  self.techList = "techScrollArea.techList"

  self.tabData = nil

  self.tabGroupWidget = "rgTabs"
  self.npcTypeConfigList = "npcTypeList"
  
  self.speciesList = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering

  self.categoryWidget = "sgSelectCategory"

  self.categoryWidgetData = "Generate"
  ------------
  ---OVERRIDE VARS----
  self.manualInput = false
  self.overrideTextBox = "tbOverrideBox"
  self.overrideText = ""


  self.worldSize = 2000
  self.currentSize = 0
  self.targetSize = 0
  self.minTargetSize = 0
  self.targetSizeIncrement = 1

  self.maxStepSize = self.worldSize
  -- updateGUI()
  self.portraitNeedsUpdate = false
  --logReport(testTwo)

  self.doingMainUpdate = false
  self.firstRun = true

  self.cd = 2
  self.reset = 2



  widget.setSliderRange("sldTargetSize",0, self.worldSize)
  widget.setSliderEnabled("sldTargetSize", true)
  widget.setSliderValue("sldTargetSize",0)
  
  local currentRatio = self.currentSize / self.worldSize
  
  widget.setProgress("prgCurrentProgress", currentRatio)
  
  widget.setProgress("prgAvailable", 0.0)


  --testFunction()
   -- setList({list = self.speciesList,  listType = "species"})
  
end

function update(dt)
  --Cannot send entity messages during init, so will do it here
  if self.doingMainUpdate then
      local checkEquip = world.getObjectParameter(pane.containerEntityId(),"newEquipment")
      if world.getObjectParameter(pane.containerEntityId(),"newEquipment") then
        return checkAndEquip()
      end
  elseif self.firstRun then
    dLog(pane.containerEntityId(), "FirstRUN BABY  ")
    self.gettingNpcData = world.sendEntityMessage(pane.containerEntityId(), "getNpcData")
    self.firstRun = false
  else
      getParamsFromSpawner()
  end
end


-----NEED TO BE SORTED --------
--[[
function changeSpeciesGlobals(species)
  local speciesJson = getAsset("/species/"..species..".species") or nil

  if not speciesJson then dLog("getSpeciesOptions:  nil AssetFile") end
  self.indexedSpecies = species
  self.bodyColor = lowercaseCopy(speciesJson.bodyColor)
  self.hairColor = lowercaseCopy(speciesJson.hairColor)
  self.undyColor = lowercaseCopy(speciesJson.undyColor)

  self.altOptionAsUndyColor = speciesJson.altOptionAsUndyColor
    --dLogJson(speciesJson, "speciesJSON: ")
  local genderName = self.currentOverride.identity.gender or self.currentIdentity.gender
  local genderIndx = 1

  if not genderName then 
    dLog("getSpeciesOptions:  nil gender") 
  end

  if speciesJson.genders[1]["name"] == genderName then
    genderIndx = 1
  else
    genderIndx = 2
  end

  local genderPath = speciesJson.genders[self.genderIndx]
  self.hairGroup = genderPath["hairGroup"] or "hair"
  self.facialHairGroup = genderPath["hairGroup"] or ""
  self.facialMaskGroup = genderPath["facialHairGroup"] or ""
  self.facialHair  = genderPath["facialHair"] or ""
  self.facialMask = genderPath["facialMask"] or ""
  self.characterImage = genderPath["characterImage"]
end
--]]

-----CALLBACK FUNCTIONS-------
function spnPersonality.up()
  dLog("spinner UP:  ")
  local personalities = getAsset("/humanoid.config:personalities")
  self.personalityIndex = util.wrap(self.personalityIndex + 1, 0, #personalities)
  setPersonality(self.personalityIndex)
  updateNpc()
  return 
end

function spnPersonality.down()
  dLog("spinner DOWN:  ")
  local personalities = getAsset("/humanoid.config:personalities")
  self.personalityIndex = util.wrap(self.personalityIndex - 1, 0, #personalities)
  setPersonality(self.personalityIndex)
  updateNpc()
  return 
end

function finalizeOverride()
  dLog("FinalizingOverride")
  self.overrideText = widget.getText(self.overrideTextBox)

  local parsedStrings = util.split(self.overrideText, " ")
  dLogJson(parsedStrings, "ParsedStrings:  ")
  
  parsedStrings = parseArgs(parsedStrings, {
    "nil",
    "nil",
    "nil",
    "nil"
    })

  if parsedStrings[1] == "c&e" then
    return checkAndEquip()
  end

  if parsedStrings[1] == "hue" and parsedStrings[2] == "hair" then
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives or  self.currentIdentity.hairDirectives
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives.."?hueshift="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "hue" and parsedStrings[2] == "body" then
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives or  self.currentIdentity.bodyDirectives
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives.."?hueshift="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "hue" and parsedStrings[2] == "emote" then
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives or  self.currentIdentity.emoteDirectives
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives.."?hueshift="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "sat" and parsedStrings[2] == "hair" then
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives or  self.currentIdentity.hairDirectives
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives.."?saturation="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "sat" and parsedStrings[2] == "body" then
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives or  self.currentIdentity.bodyDirectives
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives.."?saturation="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "sat" and parsedStrings[2] == "emote" then
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives or  self.currentIdentity.emoteDirectives
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives.."?saturation="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] ~= "nil" then
    self.currentSpecies = parsedStrings[1]
  end

  if parsedStrings[2] ~= "nil" then
    self.currentType = parsedStrings[2]
  end

  if parsedStrings[3] ~= "nil" then
    self.currentLevel = parsedStrings[3]
  end

  if parsedStrings[4] ~= "nil" then
    self.seedInput = parsedStrings[4]
  end

  self.manualInput = true
 
  return updateNpc()
end

function setNpcName()
  local text = widget.getText("tbNameBox")
  if text == "" then
    --get seed name
    newText = self.currentIdentity.name
    if self.currentOverride.identity.name then
      self.currentOverride.identity.name = nil
    end
  else
    self.currentOverride.identity.name = text
  end
end

function updateTargetSize()
  self.currentOverride.identity = {}
  self.manualInput = false
  self.targetSize = widget.getSliderValue("sldTargetSize")
  self.currentSeed = self.targetSize
  widget.setText("lblSliderAmount", tostring(self.targetSize))

  return updateNpc()
end

function acceptBtn()
  --local identity = parseArgs(self.currentOverride.identity, self.currentIdentity)
  --self.currentOverride.identity = identity
  local args = {
    npcSpecies = self.currentSpecies,
    npcSeed = self.currentSeed,
    npcType = self.currentType,
    npcLevel = self.currentLevel,
    npcParam = self.currentOverride
  }
    --self.sendingSeedValue = world.sendEntityMessage(pane.sourceEntity(), "setSeedValuePanel", self.targetSize)
    self.sendingData = world.sendEntityMessage(pane.containerEntityId(), "setNpcData", args)

end

function selectTab(index, option)
  dLog(option,  "    SelectTab")
  self.returnInfo = {}
  self.returnInfoColors = {}
  local listOption = widget.getSelectedOption(self.tabGroupWidget)

  local curTabName = world.getObjectParameter(pane.containerEntityId(),"tabOptions."..self.categoryWidgetData)[index+2]
  local returnInfo = self.returnInfo
  local generateInfo = {}
  curTabName = tostring(curTabName)
  returnInfo.listType = curTabName
  if not curTabName then return setList(nil) end
  if self.categoryWidgetData == "Generate" then
    dLog(Generate[option](curTabName), "  GENERATE")
    generateInfo = Generate[option](curTabName)
  elseif self.categoryWidgetData == "Refine" then
    generateInfo = Refine[option](curTabName)
    dLog(Refine[option](curTabName),  "REFINE  ")
  else
    generateInfo = IO[option](curTabName)
  end
  returnInfo.title = copy(generateInfo.title)
  returnInfo.currentSelection = tostring(generateInfo.currentSelection)
  returnInfo.isOverride = generateInfo.isOverride


  if not(self.speciesJson and (self.speciesJson.kind == self.currentSpecies)) then
    self.speciesJson = root.assetJson("/species/"..self.currentSpecies..".species") or nil
  end
  returnInfo.species = self.currentSpecies
    --dLogJson(speciesJson, "speciesJSON: ")
  local genderPath = self.speciesJson.genders
  local gender = self.currentOverride.identity.gender or self.currentIdentity.gender
  local genderIndx = 1

  if not gender then 
    dLog("getSpeciesOptions:  nil gender") 
  end

  if genderPath[1]["name"] == gender then
    genderIndx = 1
  else
    genderIndx = 2
  end

  if self.speciesJson["headOptionAsFacialhair"] then
    if self.speciesJson["headOptionAsFacialhair"] == true then
      returnInfo["headOptionAsFacialhair"] = self.speciesJson["headOptionAsFacialhair"]
    end
  end

  if self.speciesJson["altColorAsFacialMaskSubColor"] then
    if self.speciesJson["altColorAsFacialMaskSubColor"] == true then
      returnInfo["altColorAsFacialMaskSubColor"] = self.speciesJson["altColorAsFacialMaskSubColor"]
    end
  end

  if self.speciesJson["bodyColorAsFacialMaskSubColor"] then
    if self.speciesJson["bodyColorAsFacialMaskSubColor"] == true then
      returnInfo["bodyColorAsFacialMaskSubColor"] = self.speciesJson["bodyColorAsFacialMaskSubColor"]
    end
  end


  if curTabName == "HColor" then
      self.returnInfoColors = lowercaseCopy(self.speciesJson.hairColor)
      returnInfo.isOverride = true
      getColorInfo(returnInfo)
  elseif option == "FHColor" then
      returnInfo.isOverride = true
      if compareDirectiveToColor(self.currentIdentity.facialHairDirectives, self.speciesJson.bodyColor) then
        self.returnInfoColors = self.speciesJson.bodyColor
      elseif compareDirectiveToColor(self.currentIdentity.facialHairDirectives, self.speciesJson.hairColor) then
        self.returnInfoColors = self.speciesJson.hairColor
      end
      getColorInfo(returnInfo)
  elseif curTabName == "FMColor" then
      returnInfo.isOverride = true
      if compareDirectiveToColor(self.currentIdentity.facialMaskDirectives, self.speciesJson.bodyColor) then
        self.returnInfoColors = self.speciesJson.bodyColor
      elseif compareDirectiveToColor(self.currentIdentity.facialMaskDirectives, self.speciesJson.hairColor) then
        self.returnInfoColors = self.speciesJson.hairColor
      end
      getColorInfo(returnInfo)
  elseif curTabName == "BColor" then
      returnInfo.isOverride = true
      self.returnInfoColors =  lowercaseCopy(self.speciesJson.bodyColor)
      getColorInfo(returnInfo)
  elseif curTabName == "UColor" then
      returnInfo.isOverride = true
      self.returnInfoColors =  lowercaseCopy(self.speciesJson.undyColor)
      getColorInfo(returnInfo)
  else
      local optn  = world.getObjectParameter(pane.containerEntityId(),"getAssetParams")[curTabName]
      getSpeciesAsset(self.speciesJson, genderIndx, self.currentSpecies, optn, returnInfo)
  end
      returnInfo.colors = self.returnInfoColors
      dLog(returnInfo, "selectTab End  ")
      setList(returnInfo)
end

function selectGenCategory(button, data)
  dLog("selectGenCategory")
  self.categoryWidgetData = data
  local tabNames = {"lblTab01","lblTab02","lblTab03","lblTab04","lblTab05","lblTab06"}
  local indx = widget.getSelectedOption(self.tabGroupWidget)
  local tabData = widget.getSelectedData(self.tabGroupWidget)
  if data == "Generate" then
    widget.setVisible(self.scrollArea, true)
    widget.setSliderEnabled("sldTargetSize", true)
    widget.setVisible("lblBlockNameBox", true)
    widget.setVisible("spnPersonality", false)
    widget.setVisible("lblPersonality", false)
  elseif data == "Refine" then
    widget.setVisible(self.scrollArea, true)
    widget.setSliderEnabled("sldTargetSize", false)
    widget.setVisible("lblBlockNameBox", false)
    widget.setVisible("spnPersonality", true)
    widget.setVisible("lblPersonality", true)
  elseif data == "IO" then
    widget.setSliderEnabled("sldTargetSize", false)
    widget.setVisible("lblBlockNameBox", false)
    widget.setVisible("spnPersonality", false)
    widget.setVisible("lblPersonality", false)
  end
  changeTabLabels(tabNames, data)
  dLog(data, "selectGenCategory - selectedOption:  ")
  if indx and tabData then
    selectTab(indx, tabData)
    return 
  end
end

--args:
  --list
  --listType
function setList(args)
  --dLogJson(args, "setList - ARGS")
  --table.sort(args.list)
  widget.clearListItems(self.techList)
  local indx = 1
  if not args then dLog("no args found") return end

  
  widget.setData(string.format("%s", self.techList), args)

  if (args.isOverride) and (args.currentSelection ~= "") then
    args.clearConfig = true
    local defaultListItem = widget.addListItem(self.techList)
      widget.setText(string.format("%s.%s.techName", self.techList, defaultListItem), "Remove Overrides")
      widget.setData(string.format("%s.%s", self.techList, defaultListItem), {listType = tostring(args.listType), clearConfig = true})
  end 
  local parse = {}
  if (not args.title) or (#args.title == 0) then 
    parse = args.colors
  else
    parse = args.title
  end
  dLog(parse["1"],  "setDATA PARSE")
  for _,v in pairs(parse) do
      --dLog({i,v}, "HIT PAIR")
      local listItem = widget.addListItem(self.techList)
      local displayText = tostring(v) 
      local iTitle = tostring(v)
      local iData = nil
      if type(v) ~= "string" then
        displayText = tostring(indx)
        iTitle = tostring(indx)
        iData = parse[iTitle]
        local _,hexId = next(iData)
        if hexId then
          displayText = "^#"..hexId..";"..displayText
        end
      end

      widget.setText(string.format("%s.%s.techName", self.techList, listItem), displayText)
      widget.setData(string.format("%s.%s", self.techList, listItem), {itemTitle=iTitle , itemData = iData})

      if v == args.currentSelection then 
        sb.logInfo("setList:  entered setListSelected")
        widget.setListSelected(self.techList, listItem)
      end 
      indx = indx+1
  end
  
end


function selectListItem(name, listData)

  local listItem = widget.getListSelected(self.techList)
  dLog(listItem, "listItem  ")
  if not listItem then return end
  
  local itemData = widget.getData(string.format("%s.%s", self.techList, listItem))
  dLog(itemData, "ItemData:  ")
  listData.itemData = itemData.itemData
  listData.itemTitle = itemData.itemTitle
  listData.clearConfig = itemData.clearConfig
  if not listData and listData.listType then return end
  dLogJson(listData, "LIST DATA :")
  modNpc[listData.listType](listData, self.currentIdentity, self.currentOverride.identity)

  updateNpc()
  return 
end


------TAB GROUP FUNCTIONS---------

--------SPECIES GATHER INFO FUNCTIONS--------
function getSpeciesOptions(species, option, returnInfo)
  return returnInfo
end

function compareDirectiveToColor(directive, json)
  if type(json) ~= "table" or (tostring(directive) == "") then return false end
  local set = next(json)
  local k,v  = next(set)

  return string.match(directive,tostring(k))
end

function getSpeciesAsset(speciesJson, genderIndx, species, optn, output)
  if not optn then return end
  local genderPath = speciesJson.genders[genderIndx]
  local title = {}
  local imgPath = {}
  local info = {}
  local oOne = tostring(optn[1])
  local oTwo = tostring(optn[2])
  dCompare("oOne - oTwo", oOne, oTwo)

 
  info[oOne] = genderPath[oOne] or optn[3]
  info[oTwo] = genderPath[oTwo]

  for _,v in ipairs(info[oTwo]) do
    table.insert(title, v)
    table.insert(imgPath, string.format("/humanoid/%s/%s/%s.png",species,info[oOne],v))
  end
  output.title = title
  output.imgPath = imgPath
  output.hairGroup = info[oOne]
end

function getColorInfo(output)
  local colors = self.returnInfoColors
  local firstRun = false
  local indx = 1
  if colors then
    for i = 1, #colors do    
      table.insert(output.title,tostring(i))
      firstRun = true
    end
  end
end


------ GUI UPDATE FUNCTIONS ------

function changeTabLabels(tabs, option)
  tabs = tabs or "nil"
  option = option or "nil"

  local tabOptions = world.getObjectParameter(pane.containerEntityId(),"tabOptions")[option]
  local indx = 1

  if tabOptions then
    for _,v in ipairs(tabs) do
      widget.setText(v, tabOptions[indx])
      indx = indx+1
    end
  end
end

function checkAndEquip()
  dLogJson("checkAndEqupi:  bag")
  local bag = widget.itemGridItems("itemGrid")
  dLogJson(bag, "bag")
end

function getArgs()
  local args = {
      curSpecies = self.currentSpecies,
      curSeed =  self.currentSeed,
      curType = self.currentType,
      curLevel = self.currentLevel,
      curId = self.currentIdentity, 
      curOverride = self.currentOverride
    }
  return args
end

function itemGrid(args)
  dLogJson(args,  "itemGrid -")
end

function setPersonality(index)
  if index ~= 0 then
    widget.setText("lblPersonality", tostring(index))
    local personalities = getAsset("/humanoid.config:personalities")
    local personality = personalities[index]
    --assert(personality, string.format("cannot find personality, bad index?  :  %s", index))
    local identity = self.currentOverride.identity
    identity.personalityIdle = personality[1]
    identity.personalityHeadOffset = personality[3]
    identity.personalityArmIdle = personality[2]
    identity.personalityArmOffset = personality[4]
  else
    widget.setText("lblPersonality", "No Override")
    clearPersonality()
  end
end

function clearPersonality()
  if self.currentOverride.identity then
    local identity = self.currentOverride.identity
    identity.personalityIdle = nil
    identity.personalityHeadOffset = nil
    identity.personalityArmIdle = nil
    identity.personalityArmOffset = nil
  end
end

function replaceDirectives(directive, directiveJson)
  
  dLog("replaceDirectives")
  dLog(directive, "enterString:  ")
  dLog(directiveJson,"enter Json")
  local splitDirectives = util.split(directive,"?replace")

  dLogJson(splitDirectives, "replaceDirectives: split: ")
 -- dLogJson(directiveJson, "directiveJson")
  for i,v in ipairs(splitDirectives) do
    --dLogJson(v, "replaceDirectives: v: ")
    if not (v == "") then
        local k = string.match(v, "(%w+)=%w+")
        dLog(k, "key  ")
        dLog({directiveJson[k], directiveJson[string.upper(k)],directiveJson[string.lower(k)]}, "Testing k ")
        if directiveJson[k] or directiveJson[string.upper(k)] or directiveJson[string.lower(k)] then
            dLogJson(directiveJson[k], "matchJsonValue:")
            splitDirectives[i] = createDirective(directiveJson)
        end
      --dLog(returnString, "returnString:  ")
    end
  end
  local returnString = ""
  for i,v in ipairs(splitDirectives) do
    if v ~= "" then
      returnString = returnString.."?replace"..v
    end
  end
  dLog(returnString, "returnString:  ")
  return returnString
end

function createDirective(directiveJson)
  local prefix = ""
  for k,v in pairs(directiveJson) do
    prefix = string.format("%s;%s=%s",prefix,k,v)
  end
  return prefix
end

function replaceItemOverrides(args)
  args = parseArgs(args, {
    head = nil,
    chest = "hikerchest",
    legs = "hikerlegs",
    back = nil
  })
  local params = world.getObjectParameter(pane.containerEntityId(),"itemOverrideTemplate")
  local item = world.getObjectParameter(pane.containerEntityId(),"itemTemplate").item[1]
  dLogJson(params, "Params: ")
  local insertPosition = params.items.override[1][2][1]
  --debug--
  insertPosition.chest = world.getObjectParameter(pane.containerEntityId(),"itemTemplate").item
  insertPosition.chest[1].name = args.chest
  insertPosition.legs = world.getObjectParameter(pane.containerEntityId(),"itemTemplate").item
  insertPosition.legs[1].name = args.legs
  dLogJson(params, "replaceItemOverrides: Params: ")
  return params
end


function updateNpc()
  local curSpecies = self.currentSpecies
  local curSeed =  self.currentSeed
  local curType = self.currentType
  local curLevel = self.currentLevel
  local curId = self.currentIdentity
  local curOverride = self.currentOverride

  local variant = root.npcVariant(curSpecies, curType, curLevel, curSeed)

  self.currentIdentity = copy(variant.humanoidIdentity)
  if self.currentOverride.identity.name then
    widget.setText("tbNameBox", self.currentOverride.identity.name)
  else
    widget.setText("tbNameBox", self.currentIdentity.name)
  end

  

  --variant = root.npcVariant(args.curSpecies,args.curType, args.curLevel, args.curSeed, self.currentOverride)
  --dLogJson(variant, "variantCONFIG:  ")
  
 -- dCompare("bodyDirectives - curIden/override", self.currentIdentity.bodyDirectives, variant.humanoidIdentity.bodyDirectives)
 -- dCompare("hairDirectives - curIden/override", self.currentIdentity.hairDirectives, variant.humanoidIdentity.hairDirectives)
 -- dCompare("emoteDirectives - curIden/override", self.currentIdentity.emoteDirectives, variant.humanoidIdentity.emoteDirectives)


  local npcPort = root.npcPortrait("full", curSpecies, curType, curLevel, curSeed, curOverride)

  return setPortrait(npcPort)
end

function setPortrait(npcPort)
  local num = 1
  local portraits = self.portraits

  while num <= #npcPort do
    widget.setImage(portraits[num], npcPort[num].image)
    widget.setVisible(portraits[num], true)
    num = num+1
  end

  while num <= #portraits do
    widget.setVisible(portraits[num], false)
    num = num+1
  end
end

-------TEST FUNCTIONS-----------
--not useful in any way, used to test things

function testFunction()
    local config = root.npcConfig("villager")
    dLogJson(config, "config:")
end



function getAsset(assetPath)
  local asset = root.assetJson(assetPath)
  return asset
end

-------MAIN LIST FUNCTIONS-----------


function replaceDirectiveAtEnd(directiveBase, directiveReplace)
  directiveBase = directiveBase or ""
  directiveReplace = directiveReplace or ""

  local split = util.split(directiveBase, "?replace")
  if #split < 3 then return directiveBase end
  if not string.match(directiveReplace, "?replace") then directiveReplace = "?replace"..directiveReplace end

  split[#split] = directiveReplace
  local result = ""
  for _,v in ipairs(split) do
    result = "?replace"..v
  end

  return result
end

function getDirectiveAtEnd(directiveBase)
  assert(directiveBase, "getDirectiveAtEnd:  givenDirective is null")
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


function getParamsFromSpawner()
  dLog("checkin FOR THE DATA WTF")
  
    self.doingMainUpdate = true
    local result = self.gettingNpcData:result()
    if type(result) ~= "table" then
     result = {} 
    end
    --world.logInfo("UI: the seed value has been initialized from panel object. Changed to: " .. tostring(result))
    --self.slider.value = result
    self.npcDataInit = true

    if result.npcSpecies then
      self.currentSpecies = tostring(result.npcSpecies)
    end

    if result.npcType then
      self.currentType = tostring(result.npcType)
    end

    if result.npcLevel then
      self.currentLevel = tonumber(result.npcLevel) or 10
    end

    if result.npcParam then
      self.currentOverride = parseArgs(result.npcParam, {identity = {}, items = {}})
    end
    
    if type(result.npcSeed) == "string" then 
        self.currentSeed = tostring(result.npcSeed)
        widget.setText("seedValue", self.seedInput)
    elseif type(result.npcSeed) == "number" then
      
        self.manualInput = false
        self.currentSeed = tostring(result.npcSeed)
        self.targetSize = result.npcSeed
        widget.setSliderValue("sldTargetSize", self.targetSize)
        widget.setText("seedValue", self.currentSeed)
    end

    --setName
    if self.currentOverride.identity.name then
      widget.setText("tbNameBox", self.currentOverride.identity.name)
    end
   -- self.updateIndx = self.updateIndx + 1
    updateNpc()
    
    widget.setSelectedOption(self.categoryWidget, -1)
    widget.setVisible(self.categoryWidget, true)
    widget.setVisible(self.tabGroupWidget, true)
    widget.setVisible(self.scrollArea, true)
    
    --script.setUpdateDelta(10)
    --self.updateIndx = self.updateIndx + 1 
end

------CHANGE NPC FUNCTIONS---------
function modNpc.Species(listData, cur, curO)
  if self.currentSpecies ~= listData.itemTitle then
    dLog({listData,cur,curO},"modNPC.HitSpecies")
    curO = {}
    self.currentSpecies = tostring(listData.itemTitle)
  end
end

function modNpc.npcType(listData, cur, curO)
    self.currentType = tostring(listData.itemTitle)
end


function modNpc.Hair(listData, cur, curO)
  if listData.clearConfig then 
    curO["hairType"] = nil
  else
    curO.hairType = tostring(listData.itemTitle)
  end
end

function modNpc.FHair(listData, cur, curO)
  if listData.clearConfig then 
    dLog("listData.fhair : clearConfig:  entered ClearConfig")
    --curO["facialHairGroup"] = nil
    curO["facialHairType"] = nil
  else
    --curO.facialHairGroup = listData.facialHairGroup
    curO.facialHairType = listData.itemTitle
  end
end

function modNpc.FMask(listData, cur, curO)
  if listData.clearConfig then 
    dLog("listData.fMask : clearConfig:  entered ClearConfig")
    --curO["facialHairGroup"] = nil
    curO["facialMaskType"] = nil
  else
    --curO.facialHairGroup = listData.facialHairGroup
    curO.facialMaskType = listData.itemTitle
  end
end

function modNpc.HColor(listData, cur, curO)
  dLog(cur.hairDirectives, "enterd HColor  ")
  dLog(listData.itemData, "ItemData  ")
  if cur.hairDirectives == "" then return end
  if listData.clearConfig then
    curO["hairDirectives"] = nil
  else
    curO.hairDirectives = replaceDirectives(curO.hairDirectives or cur.hairDirectives, listData.itemData)
  end
end

function modNpc.FHColor(listData, cur, curO)
  if cur.facialHairDirectives == "" then return end
  if listData.clearConfig then
    curO["facialHairDirectives"] = nil
  else
    curO.facialHairDirectives = replaceDirectives(curO.facialHairDirectives or cur.facialHairDirectives, listData.itemData)
  end
end

function modNpc.FMColor(listData, cur, curO)
  if cur.facialMaskDirectives == "" then return end
  if listData.clearConfig then
    curO["facialMaskDirectives"] = nil
  else
    curO.facialMaskDirectives = replaceDirectives(curO.facialMaskDirectives or cur.facialMaskDirectives, listData.itemData)
  end
end

function modNpc.BColor(listData, cur, curO)
  dLog("enterd BColor")
  if listData.clearConfig then
    curO["bodyDirectives"] = nil
    curO["emoteDirectives"] = nil
  else
    curO.bodyDirectives = replaceDirectives(curO.bodyDirectives or cur.bodyDirectives, listData.itemData)
    curO.emoteDirectives = replaceDirectives(curO.emoteDirectives or cur.emoteDirectives, listData.itemData)  
  end
end

function modNpc.UColor(listData, cur, curO)
  if listData.clearConfig then
    local endDirective = getDirectiveAtEnd(cur.bodyDirectives)
    curO.bodyDirectives = replaceDirectives(curO.bodyDirectives, endDirective)
    curO.hairDirectives = replaceDirectives(curO.hairDirectives, endDirective)  
    curO.emoteDirectives = replaceDirectives(curO.emoteDirectives, endDirective)
  else
    curO.bodyDirectives = replaceDirectives(curO.bodyDirectives or cur.bodyDirectives, listData.itemData)
    curO.hairDirectives = replaceDirectives(curO.hairDirectives or cur.hairDirectives, listData.itemData)  
    curO.emoteDirectives = replaceDirectives(curO.emoteDirectives or cur.emoteDirectives, listData.itemData)  
  end
end


function Generate.tab1(tabName)
  dLog("Species HAS BEEN HIT")
  local args = {}
    args.title = copy(self.speciesList)
    args.listType = tabName
    args.currentSelection = self.currentSpecies
    args.isOverride = false
    return args
end

function Generate.tab2(tabName)
    local args = {currentSelection = self.currentOverride.identity.hairType or self.currentIdentity.hairType, 
                  title = {}}
    return getSpeciesOptions(self.currentSpecies, tabName,args ) 
end

function Generate.tab3(tabName) 
  local args = {currentSelection = self.currentOverride.identity.facialHairType or self.currentIdentity.facialHairType,
                title = {}}
  return getSpeciesOptions(self.currentSpecies, tabName, args) 
end

function Generate.tab4(tabName) 
  local args = {currentSelection = self.currentOverride.identity.facialMaskType or self.currentIdentity.facialMaskType,
                title = {}}
  return getSpeciesOptions(self.currentSpecies, tabName, args) 
end



function Refine.tab1(tabName) 
  local args = {
    title = {},
    listType = tabName,
    colors = {},
    currentSelection = (self.currentOverride.identity.bodyDirectives or self.currentIdentity.bodyDirectives)
  }
  return getSpeciesOptions(self.currentSpecies, tabName, args) 
end

function Refine.tab2(tabName)
  local args = {currentSelection = self.currentOverride.identity.hairType or self.currentIdentity.hairType}
  return getSpeciesOptions(self.currentSpecies, tabName, args)
end

function Refine.tab3(tabName)
  local args =  {
    title = {},
    listType = tabName,
    colors = {},
    currentSelection = self.currentOverride.identity.facialHairType or self.currentIdentity.facialHairType}
  return getSpeciesOptions(self.currentSpecies, tabName, args)
end

function Refine.tab4(tabName)
  local args = {
    title = {},
    listType = tabName,
    colors = {},
    currentSelection = self.currentOverride.identity.facialMaskType or self.currentIdentity.facialMaskType}
  return getSpeciesOptions(self.currentSpecies, tabName, args)
end

function Refine.tab5(tabName)
  local args = {}
  return getSpeciesOptions(self.currentSpecies, tabName, args)
end

function IO.tab1(tabName) 
    local args = {}
    args.title = copy(self.typeList)
    args.listType = tabName
    args.currentSelection = self.currentType
    args.isOverride = false
    return args
end
