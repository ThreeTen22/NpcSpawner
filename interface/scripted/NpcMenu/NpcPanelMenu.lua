require "/scripts/npcspawnutil.lua"

spnIdleStance = {}
spnSldParamBase = {}
spnSldParamDetail = {}
modNpc = {}
selectedTab = {}
override = {}

function init()
  self.speciesList = root.assetJson("/interface/windowconfig/charcreation.config:speciesOrdering")
  local baseConfig = root.assetJson("/interface/scripted/NpcMenu/modConfig.config:init")
  local userConfig = getUserConfig("npcSpawnerPlus")
  self.equipSlot = baseConfig.equipSlot
  self.portraits = baseConfig.portraits

  dLogJson(self.portraits,"portraits",true)
  dLogJson(self.equipSlot,"slots",true)

  local mSpeciesConfig = mergeUnique(baseConfig.additionalSpecies, userConfig.additionalSpecies)
  self.speciesList = mergeUnique(self.speciesList, mSpeciesConfig)
  self.npcTypeList = mergeUnique(baseConfig.npcTypeList, userConfig.additionalNpcTypes)

  table.sort(self.speciesList)
  table.sort(self.npcTypeList)

  local protectorate = root.npcConfig("villager")
  
  local listOfProtectorates = {}
  local lotsOfNpcs = jsonPath(protectorate, "scriptConfig.questGenerator.graduation.nextNpcType")
  
  for _,v in ipairs(lotsOfNpcs) do
    local name = v[2]
    table.insert(listOfProtectorates, tostring(name))
  end
  self.npcTypeList = mergeUnique(self.npcTypeList, listOfProtectorates)
  self.returnInfo = {}
  
  self.getSpeciesPath = function(species, path)
                             path = path or "/species/";
                             return tostring(path..species..".species")
                        end

  self.personalityIndex = 0

  self.returnInfoColors = nil
  --UI VARS--
  self.sldMain = "sldMainSlider"


  --LIST VARS--
  self.scrollArea = "techScrollArea"
  self.techList = "techScrollArea.techList"
  self.infoList = "techScrollArea.infoList"
  self.infoLabel = "techScrollArea.lblOverrideConsole"

  self.tabData = nil
  self.tabGroupWidget = "rgTabs"
  self.categoryWidget = "sgSelectCategory"
  self.categoryWidgetData = "Generate"
  self.nameBox = "tbNameBox"
  ---OVERRIDE VARS----
  self.overrideTextBox = "tbOverrideBox"
  self.overrideText = ""

  self.minSldValue = 0
  self.maxSldValue = 20000

  self.doingMainUpdate = false
  self.firstRun = true
  self.filterText = ""
  self.npcTypeStorage = "npcTypeStorage"  

                  --primary and sheathed primary are always the goto weapons, secondary is for shields.
                  --duel wielding weapons for npcs doesn't work.
  self.equipBagStorage = widget.itemGridItems("itemGrid")
  self.gettingInfo = world.getObjectParameter(pane.containerEntityId(), "npcArgs")
  self.currentOverride = self.gettingInfo.npcParam or {identity = {}, scriptConfig = {}}
  self.currentType = self.gettingInfo.npcType or "follower"
  self.currentSeed = self.gettingInfo.npcSeed or math.random(0, self.maxSldValue)
  self.currentLevel = self.gettingInfo.npcLevel or math.random(1, world.threatLevel())
  self.currentSpecies = self.gettingInfo.npcSpecies or "penguin"

  self.currentIdentity = {}
  self.tbFeedbackColorRoutine = nil
  self.tbGreenColor = {0,255,0}
  self.tbRedColor = {255,0,0}

  self.colorChangeTime = 1

  self.curOverrideColor = nil
  self.curNameBoxColor = nil

  updateNpc(true)
  modNpc.Species({iTitle = self.currentSpecies}, self.currentIdentity, self.currentOverride)
  --if #self.currentOverride.identity < 1 or jcount(self.currentOverride.identity) < 1 then self.currentOverride.identity = copy(self.currentIdentity)
  self.slotCount = 12
  self.sliderValue = tonumber(self.currentSeed) or 0

  widget.setSliderRange(self.sldMain,self.minSldValue, self.maxSldValue)
  widget.setSliderEnabled(self.sldMain, true)
  widget.setSliderValue(self.sldMain,self.sliderValue)
  widget.setText("lblSliderValue", "Seed:  "..tostring(self.sliderValue))
  self.mockdt = 0.33
  self.mockTimer = 0
  
  --used for slider
  self.setSeedValue = function(value) 
        self.currentSeed = tonumber(value) 
  end
  self.setOverride = function(value, data) 
      --local data = widget.getData(self.sldMain)
      applyDirective(self.currentIdentity, self.currentOverride, value, data)
  end
  script.setUpdateDelta(3)
end

--uninit WORKS. Question is, can we send entity messages without worrying about memory leaks?  Answer: fuck entity messages.
function update(dt)
  --Cannot send entity messages during init, so will do it here
  if self.doingMainUpdate then
    if notTime(dt) then return end
    local contentsChanged = false
    local itemBag = widget.itemGridItems("itemGrid")
    for i = 1, self.slotCount do
      if not compare(self.equipBagStorage[i], itemBag[i]) then
        if not (self.currentOverride.items and self.currentOverride.items.override)  then 
          self.currentOverride.items = config.getParameter("overrideContainerTemplate.items") 
        end
        local itemBagCopy = copy(itemBag[i])
        --Add items to override item slot so they update visually.
        local insertPosition = self.currentOverride.items.override[1][2][1]
        setItemOverride(self.equipSlot[i],insertPosition, itemBag[i])

        --Also add them to bmain's initialStorage config parameter so its baked into the npc during reloads.

        --if type(insertPosition[1]) ~= "string" then
          local currentPath = self.currentOverride.scriptConfig
          if (not path(currentPath,"initialStorage","itemSlots")) then 
            setPath(currentPath,"initialStorage","itemSlots",{}) 
          end
          local itemSlots = self.currentOverride.scriptConfig.initialStorage.itemSlots
          itemSlots[self.equipSlot[i]] = itemBagCopy
          if itemSlots[self.equipSlot[i]] and itemSlots[self.equipSlot[i]].name == "capturepod" then 
            itemSlots[self.equipSlot[i]].name = "npcpetcapturepod" 
            itemSlots[self.equipSlot[i]].count = 10
          end
        --end
        contentsChanged = true
      end
    end

    if contentsChanged then 
      if isContainerEmpty(itemBag) then
        self.currentOverride.items = nil
        if self.currentOverride.scriptConfig then
          self.currentOverride.scriptConfig.initialStorage = nil
        end
      end
      self.equipBagStorage = widget.itemGridItems("itemGrid")
      updateNpc() 
    end
  elseif self.firstRun then
    self.firstRun = false
  else
    widget.setSelectedOption(self.categoryWidget, -1)
    widget.setVisible(self.categoryWidget, true)
    widget.setVisible(self.tabGroupWidget, true)
    widget.setVisible(self.scrollArea, true)
    self.doingMainUpdate = true
    updateNpc()
    script.setUpdateDelta(20)
  end
end

function notTime(dt)
  if dt < self.mockdt then
    self.tbFeedbackColorRoutine(dt)
    self.mockTimer = self.mockTimer + dt
    if self.mockTimer < self.mockdt then 
      return true
    end
    self.mockTimer = 0
    return false
  end
  return false
end

function setItemOverride(slotName, insertPosition, itemContainer)
  if itemContainer then 
    if type(itemContainer) == "table" then
        if string.find(itemContainer.name, "capturepod",1,true) then
          --itemContainer = {}
          --itemContainer.name = {"npcpetcapturepod"}
          itemContainer = "npcpetcapturepod"
          insertPosition[slotName] = {itemContainer}
          return
        end
      if type(itemContainer) ~= "string" then
        itemContainer.count = nil
      end
      insertPosition[slotName] = {itemContainer}
    end
  else
    insertPosition[slotName] = nil
  end
end


-----CALLBACK FUNCTIONS-------
function spnIdleStance.up()
  dLog("spinner UP:  ")
  local personalities = root.assetJson("/humanoid.config:personalities")
  self.personalityIndex = util.wrap(self.personalityIndex + 1, 0, #personalities)
  setIdleStance(self.personalityIndex)
  updateNpc()
  return 
end

function spnIdleStance.down()
  dLog("spinner DOWN:  ")
  local personalities = root.assetJson("/humanoid.config:personalities")
  self.personalityIndex = util.wrap(self.personalityIndex - 1, 0, #personalities)
  setIdleStance(self.personalityIndex)
  updateNpc()
  return 
end

function interpTextColor(tbName)
  local timer = 0
  local name = tbName
  local dt = script.updateDt()
  while timer < self.colorChangeTime do

    timer = math.min(timer + dt, self.colorChangeTime)
    local ratio = timer/self.colorChangeTime
    local count = 0
    for i,v in ipairs(self.curOverrideColor) do
      self.curOverrideColor[i] = math.min(interp.sin(ratio,v,255),255) 
    end
    widget.setFontColor(name, self.curOverrideColor)
    coroutine.yield()
  end
  script.setUpdateDelta(20)
  self.tbFeedbackColorRoutine = nil
end

--callback
function onOverrideEnter()
  dLog("FinalizingOverride")
  self.overrideText = widget.getText(self.overrideTextBox)
  self.overrideText = string.gsub(self.overrideText, "  "," ",1, true)
  while self.overrideText[#self.overrideText] == " " do
    self.overrideText[#self.overrideText] = ""
  end
  while self.overrideText[1] == " " do
    self.overrideText[1] = ""
  end
  local parsedStrings = util.split(self.overrideText, " ")
  --widget.setText(self.overrideTextBox, self.overrideText)

  while self.tbFeedbackColorRoutine do
    self.tbFeedbackColorRoutine()
  end
  local wasSuccessful = nil
  parsedStrings[1] = string.lower(parsedStrings[1])

  if parsedStrings[2] then
    parsedStrings[2] = string.lower(parsedStrings[2])
  end

  if not(parsedStrings[1] == "output") then  
    for i,v in ipairs(parsedStrings) do
        parsedStrings[i] = string.lower(v)
    end
  end
  
  
  if override[parsedStrings[1]] then
    dLog("entered override Check")
    wasSuccessful, errorMsg = override[parsedStrings[1]](self.currentOverride,self.currentIdentity,table.unpack(parsedStrings,2))
  end
  if wasSuccessful then
    widget.setFontColor(self.overrideTextBox, self.tbGreenColor)
    self.curOverrideColor = copy(self.tbGreenColor)
    script.setUpdateDelta(3)
    self.tbFeedbackColorRoutine = coroutine.wrap(interpTextColor)
    self.tbFeedbackColorRoutine(self.overrideTextBox)
    return updateNpc()
  else
    widget.setFontColor(self.overrideTextBox, self.tbRedColor)
    self.curOverrideColor = copy(self.tbRedColor)
    script.setUpdateDelta(3)
    self.tbFeedbackColorRoutine = coroutine.wrap(interpTextColor)
    self.tbFeedbackColorRoutine(self.overrideTextBox)
  end
  if not wasSuccessful then
    override.outputStr(errorMsg)
  end
end

--Callback
function onSeachBoxKeyPress(tbLabel)
  local text = widget.getText(tbLabel)
  
  --dLog(text, "onSeachBoxKeyPress")

  if text == self.filterText then return end
  self.filterText = text
  local args = widget.getData(string.format("%s", self.techList))
  dLog("keypress passed")
  if text == "" then text = nil end
  args.filter = text
  return setList(args)
end

--Callback

function setNpcName()
  while self.tbFeedbackColorRoutine do
    self.tbFeedbackColorRoutine()
  end

  local text = widget.getText(self.nameBox)
  if text == "" then
    --get seed name
    local newText = self.currentIdentity.name
    if self.currentOverride.identity.name then
      self.currentOverride.identity.name = newText
    end
    newText = newText or "DEMO"
    widget.setText(self.nameBox, newText)
  else
    self.currentOverride.identity.name = text
  end

  widget.setFontColor(self.nameBox, self.tbGreenColor)
  self.curOverrideColor = copy(self.tbGreenColor)
  script.setUpdateDelta(3)
  self.tbFeedbackColorRoutine = coroutine.wrap(interpTextColor)
  self.tbFeedbackColorRoutine(self.nameBox)

end

--Callback
function onSliderChange()
  if not self.doingMainUpdate then return end
  local data = widget.getData(self.sldMain)
  local value = widget.getSliderValue(self.sldMain)

  updateNpc()
end

function acceptBtn()
  self.currentOverride.identity = self.currentOverride.identity or {} 
  self.currentOverride.identity = parseArgs(self.currentOverride.identity, self.currentIdentity)
  setNpcName()
  update(0)
  local args = {
    npcSpecies = self.currentSpecies,
    npcSeed = self.currentSeed,
    npcType = self.currentType,
    npcLevel = self.currentLevel,
    npcParam = self.currentOverride
  }
    self.sendingData = world.sendEntityMessage(pane.containerEntityId(), "setNpcData", args)
end

function setListInfo(categoryName, uniqueId, infoOverride)
  widget.clearListItems(self.infoList)
  --dLog(categoryName, "catName")
  if not categoryName then return end
  local tabInfo = config.getParameter("tabOptions."..categoryName)
  local info = infoOverride or root.assetJson("/interface/scripted/NpcMenu/modConfig.config:infoDescription")
  local subInfo = info[categoryName]
  if uniqueId then 
    for i,v in ipairs(subInfo) do
      if v.key == "uniqueID" then 
        info[categoryName][i].value = uniqueId
        break
      end
    end
  end
  subInfo = info[categoryName]
  for _,v in ipairs(subInfo) do
    local listItem = widget.addListItem(self.infoList)
    for k,ve in pairs(v) do
      widget.setText(string.format("%s.%s.%s", self.infoList, listItem, k), ve)
    end
  end
  --dLog(tabInfo, "TAB INFO:  ")
  for i,v in ipairs(tabInfo) do
    local tabDesc = info[v]
    if type(tabDesc) == "string" and tabDesc ~= "" then
      local listItem = widget.addListItem(self.infoList)
      widget.setText(string.format("%s.%s.%s",self.infoList, listItem,"key"), v)
      widget.setText(string.format("%s.%s.%s",self.infoList, listItem,"value"), tabDesc)
    elseif type(tabDesc) == "table" then
      for k,v in pairs(tabDesc) do
        local listItem = widget.addListItem(self.infoList)
        widget.setText(string.format("%s.%s.%s",self.infoList, listItem,k), v)
      end
    end
  end
end

function selectTab(index, option)
  --dLog(option,  "    SelectTab") 
  self.returnInfo = {}
  self.returnInfoColors = nil
  self.curSelectedTitle = nil
  widget.setText(self.infoLabel, "")
  widget.setData(self.infoLabel, "")
  local listOption = widget.getSelectedOption(self.tabGroupWidget)

  local curTabs = config.getParameter("tabOptions."..self.categoryWidgetData)
  local listType = curTabs[index+2]
  
  if not listType or listType == "" then 
    return setList(nil) 
  end

  updateSpecies()
  self.returnInfo.listType = listType
  selectedTab[listType](self.returnInfo)


  if self.returnInfo.useInfoList then
    setList(nil)
    widget.setVisible(self.techList, false)
    widget.setVisible(self.infoList, true)
    widget.setVisible("tbSearchBox", false)
    widget.setVisible("tbOverrideBox", true)
    widget.setText(self.infoLabel, "")
    setListInfo(self.returnInfo.selectedCategory, self.uniqueExportId)
    self.uniqueExportId = nil
    return
  else
    setListInfo(nil)
    widget.setVisible(self.techList, true)
    widget.setVisible(self.infoList, false)
    widget.setVisible("tbSearchBox", true)
    widget.setVisible("tbOverrideBox", false)
    widget.setText(self.infoLabel, "")
  end
  
  
  if self.returnInfo.skipTheRest then setList(self.returnInfo); return end

  --dLog("contining getting tab info")

  if self.returnInfo.colors then
    getColorInfo(self.returnInfoColors, self.returnInfo)
  else
    local optn  = config.getParameter("assetParams."..listType)
    if optn then
      getSpeciesAsset(self.speciesJson, getGenderIndx(self.currentIdentity.gender), self.currentSpecies, optn, self.returnInfo)
    end
  end
  self.returnInfo.colors = self.returnInfoColors
  setList(copy(self.returnInfo))
end

function selectGenCategory(button, data)
  --dLog("selectGenCategory")
  self.categoryWidgetData = data
  local tabNames = {"lblTab01","lblTab02","lblTab03","lblTab04","lblTab05","lblTab06"}
  local indx = widget.getSelectedOption(self.tabGroupWidget)
  local tabData = widget.getSelectedData(self.tabGroupWidget)
  if data == "Generate" then
    widget.setVisible(self.scrollArea, true)
    widget.setSliderEnabled(self.sldMain, true)
    widget.setVisible("spnPersonality", false)
    widget.setVisible("lblPersonality", false)
  elseif data == "Colorize" then
    widget.setVisible(self.scrollArea, true)
    widget.setVisible("spnPersonality", true)
    widget.setVisible("lblPersonality", true)
  elseif data == "Advanced" then
    widget.setSliderEnabled(self.sldMain, false)
    widget.setVisible("lblBlockNameBox", false)
    widget.setVisible("spnPersonality", false)
    widget.setVisible("lblPersonality", false)
  end
  changeTabLabels(tabNames, data)
  --dLog(data, "selectGenCategory - selectedOption:  ")
  if indx and tabData then
    selectTab(indx, tabData)
    return 
  end
end

--args:
  --list
  --listType
function setList(args)
  widget.clearListItems(self.techList)
  local indx = 0
  local displayText = nil
  local iTitle = nil
  local iData = nil
  local selectedItem = nil
  if not args then --dLog("no args found") 
    return 
  end

  --args.widgets = args.widgets or {}

  if (args.isOverride) and (self.curSelectedTitle ~= "") then
    args.clearConfig = true
    local defaultListItem = widget.addListItem(self.techList)
      widget.setText(string.format("%s.%s.title", self.techList, defaultListItem), "Remove Overrides")
      widget.setData(string.format("%s.%s", self.techList, defaultListItem), {listType = tostring(args.listType), clearConfig = true})
  end 
  local s = nil
  for i,v in pairs(args.title) do
      indx = indx+1
      local continue = true
      local v = v
      if args.colors then
        v = indx
      end
      if args.filter then 
        s,_ = string.find(v, args.filter, 1, true)
        if not s then 
          continue = false
        end
      end
    if continue then
      displayText = tostring(v)
      iTitle = tostring(v)
      local listItem = widget.addListItem(self.techList)
      
      local hexId = nil
      if args.colors then
        local hexIndx = 0
        iData = args.colors[v] or {}
        for k,v in pairs(iData) do
          hexIndx = hexIndx+1
          hexId = tostring(v)
          if hexIndx == 3 then break end
        end
      else
        if args.iData and args.iData[v] then
          iData = args.iData[v]
        else
          iData = v
        end
      end
      if hexId then
        args.iIcon[v] = string.format("/interface/statuses/darken.png?setcolor=%s",hexId)
        displayText = "^#"..hexId..";"..tostring(v)
      end
      if args.iIcon and args.iIcon[v] then
        local iIcon = args.iIcon[v]
        widget.setImage(string.format("%s.%s.techIcon", self.techList, listItem), iIcon)
      end

      --args.widgets[iTitle] = listItem
      widget.setText(string.format("%s.%s.title", self.techList, listItem), displayText)
      widget.setData(string.format("%s.%s", self.techList, listItem), {iTitle=iTitle , iData = iData})

      if v == self.curSelectedTitle then 
       selectedItem = tostring(listItem)
      end 
    end
  end
  widget.setData(string.format("%s", self.techList), args)
  if selectedItem then  
    sb.logInfo("setList:  entered setListSelected")
    widget.setListSelected(self.techList, selectedItem)
  end
end


function onSelectItem(name, listData)
  --dLog("onSelectItem")
  local listItem = widget.getListSelected(self.techList)
  if not listItem then return end
  local itemData = widget.getData(string.format("%s.%s", self.techList, listItem))
  listData.iData = copy(itemData.iData)
  listData.iTitle = itemData.iTitle
  listData.clearConfig = itemData.clearConfig
  if not listData and listData.listType then return end
  self.curSelectedTitle = itemData.iTitle
  modNpc[listData.listType](listData, self.currentIdentity, self.currentOverride)

  updateNpc()
  return 
end

--------SPECIES GATHER INFO FUNCTIONS--------
function getSpeciesOptions(species, option, returnInfo)
  return returnInfo
end

function compareDirectiveToColor(directive, json)
  if type(json) ~= "table" or (tostring(directive) == "") then return false end
  local _,set = next(json)
  if type(set) ~= "table" then return false end
  local k,v  = next(set)
  k = string.lower(k)
  v = string.lower(v)
  --dLog(k, "MATCHING TEST")
  --dLog(string.match(directive,tostring(k).."="), "result ")
  return string.match(directive,tostring(k).."=")
end

function getSpeciesAsset(speciesJson, genderIndx, species, optn, output)
  if not optn then return end
  local genderPath = speciesJson.genders[genderIndx]
  local title = {}
  local iIcon = {}
  local info = {}
  local oOne = tostring(optn[1])
  local oTwo = tostring(optn[2])
  
  info[oOne] = genderPath[oOne] or optn[3]
  info[oTwo] = genderPath[oTwo]
  local directive = self.currentOverride.identity[optn[4]] or self.currentIdentity[optn[4]]
  for _,v in ipairs(info[oTwo]) do
    local append = ""
    table.insert(title, v)
    iIcon[v] = string.format("/humanoid/%s/%s/%s.png:normal%s",species,info[oOne],v,directive)
  end
  output.title = title
  output.iIcon = iIcon
  output.hairGroup = info[oOne]
end

function getColorInfo(colors, output)
  output.title = output.title or {}
  if colors then
    for i = 1, #colors do    
      table.insert(output.title,tostring(i))
    end
  end
end


------ GUI UPDATE FUNCTIONS ------
function changeTabLabels(tabs, option)
  tabs = tabs or "nil"
  option = option or "Error"

  local tabOptions = config.getParameter("tabOptions."..option)
  local indx = 1

  if tabOptions then
    for _,v in ipairs(tabs) do
      widget.setText(v, tabOptions[indx])
      indx = indx+1
    end
  end
end

function setIdleStance(index)
  if index ~= 0 then
    widget.setText("lblIdleStance", tostring(index))
    local personalities = root.assetJson("/humanoid.config:personalities")
    local personality = personalities[index]
    --assert(personality, string.format("cannot find personality, bad index?  :  %s", index))
    local identity = self.currentOverride.identity
    identity.personalityIdle = personality[1]
    identity.personalityHeadOffset = personality[3]
    identity.personalityArmIdle = personality[2]
    identity.personalityArmOffset = personality[4]
  else
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
    widget.setText("lblIdleStance", "No Override")
end

function replaceDirectives(directive, directiveJson)
  
  if not directive and type(directive) == "nil" then return nil end
  local splitDirectives = util.split(directive,"?replace")

  for i,v in ipairs(splitDirectives) do
    if not (v == "") then
        local k = string.match(v, "(%w+)=%w+")
        if directiveJson[k] or directiveJson[string.upper(k)] or directiveJson[string.lower(k)] then
            splitDirectives[i] = createDirective(directiveJson)
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

function createDirective(directiveJson)
  local prefix = ""
  for k,v in pairs(directiveJson) do
    prefix = string.format("%s;%s=%s",prefix,k,v)
  end
  return prefix
end

function updateNpc(noVisual)
  local curSpecies = self.currentSpecies
  local curSeed =  self.currentSeed
  local curType = self.currentType
  local curLevel = self.currentLevel
  local curId = self.currentIdentity
  local curOverride = self.currentOverride

  local variant = root.npcVariant(curSpecies, curType, curLevel, curSeed)

  self.currentIdentity = copy(variant.humanoidIdentity)
  if curOverride.identity and curOverride.identity.name then
    widget.setText(self.nameBox, curOverride.identity.name)
  else
    widget.setText(self.nameBox, self.currentIdentity.name)
  end
  if noVisual then return end
  sb.setLogMap("curOverride", "%s",sb.printJson(curOverride or {},1))
  local npcPort = root.npcPortrait("full", curSpecies, curType, curLevel, curSeed, curOverride)
  --dLogJson(curOverride, "whsa", false)
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

function getAsset(assetPath)
  return root.assetJson(assetPath)
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

function updateSpecies()
    if not(self.speciesJson and (self.speciesJson.kind == self.currentSpecies)) then
    self.speciesJson = root.assetJson("/species/"..self.currentSpecies..".species")
  end
end

function getGenderIndx(name)
  local genderIndx
  for i,v in ipairs(self.speciesJson.genders) do
    if v.name == name then return i end
  end
end


------CHANGE NPC FUNCTIONS---------
function modNpc.Species(listData, cur, curO)
  if self.currentSpecies ~= listData.iTitle then
    self.currentSpecies = tostring(listData.iTitle)
    updateNpc(true)
    curO.identity = {}
  end
  updateSpecies()
  local speciesIcon = self.speciesJson.genders[getGenderIndx(cur.gender)].characterImage
  widget.setImage("techIconHead",speciesIcon)
end

function modNpc.NpcType(listData, cur, curO)
    self.currentType = tostring(listData.iTitle)
end

function modNpc.Hair(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then 
    curO["hairType"] = nil
  else
    curO.hairType = tostring(listData.iTitle)
  end
end

function modNpc.FHair(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then 
    --dLog("listData.fhair : clearConfig:  entered ClearConfig")
    --curO["facialHairGroup"] = nil
    curO["facialHairType"] = nil
  else
    --curO.facialHairGroup = listData.facialHairGroup
    curO.facialHairType = listData.iTitle
  end
end

function modNpc.FMask(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then 
    --dLog("listData.fMask : clearConfig:  entered ClearConfig")
    curO["facialMaskType"] = nil
  else
    curO.facialMaskType = listData.iTitle
  end
end

function modNpc.HColor(listData, cur, curO)
  local curO = curO.identity
  --dLog(cur.hairDirectives, "enterd HColor  ")
  --dLog(listData.iData, "ItemData  ")
  if cur.hairDirectives == "" then return end
  if listData.clearConfig then
    curO["hairDirectives"] = nil
  else
    curO.hairDirectives = replaceDirectives(curO.hairDirectives or cur.hairDirectives, listData.iData)
  end
end

function modNpc.FHColor(listData, cur, curO)
  local curO = curO.identity
  if cur.facialHairDirectives == "" then return end
  if listData.clearConfig then
    curO["facialHairDirectives"] = nil
  else
    curO.facialHairDirectives = replaceDirectives(curO.facialHairDirectives or cur.facialHairDirectives, listData.iData)
  end
end

function modNpc.FMColor(listData, cur, curO)
  local curO = curO.identity
  if cur.facialMaskDirectives == "" then return end
  if listData.clearConfig then
    curO["facialMaskDirectives"] = nil
  else
    curO.facialMaskDirectives = replaceDirectives(curO.facialMaskDirectives or cur.facialMaskDirectives, listData.iData)
  end
end

function modNpc.BColor(listData, cur, curO)
  local curO = curO.identity
  --dLog("enterd BColor")
  if listData.clearConfig then
    curO["bodyDirectives"] = nil
    curO["emoteDirectives"] = nil
  else
    curO.bodyDirectives = replaceDirectives(curO.bodyDirectives or cur.bodyDirectives, listData.iData)
    curO.emoteDirectives = replaceDirectives(curO.emoteDirectives or cur.emoteDirectives, listData.iData)  
  end
end

function modNpc.UColor(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then
    local endDirective = getDirectiveAtEnd(cur.bodyDirectives)
    curO.bodyDirectives = replaceDirectives(curO.bodyDirectives, endDirective)
    curO.hairDirectives = replaceDirectives(curO.hairDirectives, endDirective)  
    curO.emoteDirectives = replaceDirectives(curO.emoteDirectives, endDirective)
  else
    curO.bodyDirectives = replaceDirectives(curO.bodyDirectives or cur.bodyDirectives, listData.iData)
    curO.hairDirectives = replaceDirectives(curO.hairDirectives or cur.hairDirectives, listData.iData)  
    curO.emoteDirectives = replaceDirectives(curO.emoteDirectives or cur.emoteDirectives, listData.iData)  
  end
end

function modNpc.Prsnlity(listData,cur,curO)
  if listData.clearConfig then 
    if curO.scriptConfig and curO.scriptConfig.personality then
        curO.scriptConfig.personality = nil
    end
  else
    if not curO.scriptConfig then curO.scriptConfig = {} end
    if not curO.scriptConfig.personality then curO.scriptConfig.personality = {} end
    self.currentOverride.scriptConfig.personality = listData.iData
  end
end

function selectedTab.Species(args)
  args = args or {}
  args.title = copy(self.speciesList)
  self.curSelectedTitle = self.currentSpecies
  args.isOverride = false
  args.skipTheRest = true
  args.iIcon = {}
  --JSON indx starts at 0,  lua starts at 1.  RIP
  local genderIndx = getGenderIndx(self.currentIdentity.gender)-1
  for _,v in ipairs(self.speciesList) do
    local jsonPath = string.format("/species/%s.species:genders.%s.characterImage",v, tostring(genderIndx))
    --dLog(jsonPath, "JSON PATH")
    local image = root.assetJson(jsonPath)
    args.iIcon[v] = image
  end
end

function selectedTab.NpcType(args)
  args = args or {}
  args.title = copy(self.npcTypeList)
  self.curSelectedTitle = self.currentType
  args.isOverride = false
  args.skipTheRest = true
  args.iIcon = {}
  local worldStorage = world.getProperty(self.npcTypeStorage)
  if not (worldStorage and worldStorage.iIcon) then worldStorage = {iIcon = {}, skyTime = world.time()} end

  local updateToWorld = false
  --TODO:  CHANGE THIS SO THAT A REASONABLE AMOUNT OF TIME HAS PASSED.
    --IDEALLY IT WOULD BE NICE IF I COULD GET A HASH OF LOADED ASSETS SO I CAN QUICKLY DETECT CHANGES.  
    --MAYBE HASH THE NPCTYPE LIST
  if worldStorage.skyTime and worldStorage.skyTime + 86400 < world.time() then
    override.clearcache()
  end
  
  local typeParams = config.getParameter("npcTypeParams")
  local hIcon = jsonPath(typeParams,"hostile.icon")
  local gIcon = jsonPath(typeParams,"guard.icon") 
  local mIcon = jsonPath(typeParams,"merchant.icon")
  local cIcon = jsonPath(typeParams,"crew.icon")
  local vIcon = jsonPath(typeParams,"villager.icon")
  local hostile = config.getParameter(string.format("npcTypeParams.%s.paramsToCheck","hostile"))
  local guard = config.getParameter(string.format("npcTypeParams.%s.paramsToCheck","guard"))
  local merchant = config.getParameter(string.format("npcTypeParams.%s.paramsToCheck","merchant"))
  local crew = config.getParameter(string.format("npcTypeParams.%s.paramsToCheck","crew"))

  local npcConfig = nil
  for _,v in ipairs(self.npcTypeList) do
    if not worldStorage.iIcon[v] then
     npcConfig = root.npcConfig(v)
      if checkIfNpcIs(v, npcConfig, hostile) then worldStorage.iIcon[v] = hIcon; updateToWorld = true;
      elseif checkIfNpcIs(v, npcConfig, guard) then worldStorage.iIcon[v] = gIcon ; updateToWorld = true;
      elseif checkIfNpcIs(v, npcConfig, merchant) then worldStorage.iIcon[v] = mIcon ; updateToWorld = true;
      elseif checkIfNpcIs(v, npcConfig, crew) then worldStorage.iIcon[v] = cIcon; updateToWorld = true;
      else  
        worldStorage.iIcon[v] = vIcon
      end
    end
  end
  args.iIcon = shallowCopy(worldStorage.iIcon)
  if updateToWorld then
    worldStorage.skyTime = world.time()
    world.setProperty(self.npcTypeStorage, worldStorage)
  end  
end

function checkIfNpcIs(v, npcConfig,typeParams)
    for k,v2 in pairs(typeParams) do
      local value = jsonPath(npcConfig, k)
      if (value and v2) then return true end
    end
    return false
end

function selectedTab.Hair(args)
  self.curSelectedTitle = self.currentOverride.identity.hairType or self.currentIdentity.hairType 
  args.title = {}
  args.isOverride = true
end

function selectedTab.FHair(args)
  self.curSelectedTitle = self.currentOverride.identity.facialHairType or self.currentIdentity.facialHairType
  args.title = {}
  args.isOverride = true
end

function selectedTab.FMask(args)
  self.curSelectedTitle = self.currentOverride.identity.facialMaskType or self.currentIdentity.facialMaskType
  args.title = {}
  args.isOverride = true
end

function selectedTab.HColor(args)
  args.title = {}
  args.colors = {}
  args.iIcon = {}
  if compareDirectiveToColor(self.currentIdentity.hairDirectives, self.speciesJson.bodyColor) then
    self.returnInfoColors = self.speciesJson.bodyColor
  elseif compareDirectiveToColor(self.currentIdentity.hairDirectives, self.speciesJson.hairColor) then
    self.returnInfoColors = self.speciesJson.hairColor
  elseif compareDirectiveToColor(self.currentIdentity.hairDirectives, self.speciesJson.undyColor) then
    self.returnInfoColors = self.speciesJson.undyColor
  else 
    self.returnInfoColors = nil
  end
  args.isOverride = true
end

function selectedTab.FHColor(args)
  args.title = {}
  args.colors = {}
  args.iIcon = {}
  if compareDirectiveToColor(self.currentIdentity.facialHairDirectives, self.speciesJson.bodyColor) then
    self.returnInfoColors = self.speciesJson.bodyColor
  elseif compareDirectiveToColor(self.currentIdentity.facialHairDirectives, self.speciesJson.hairColor) then
    self.returnInfoColors = self.speciesJson.hairColor
  elseif compareDirectiveToColor(self.currentIdentity.facialHairDirectives, self.speciesJson.undyColor) then
    self.returnInfoColors = self.speciesJson.undyColor
  else 
    self.returnInfoColors = nil
  end
  args.isOverride = true
end

function selectedTab.FMColor(args)
  args.title = {}
  args.colors = {}
  args.iIcon = {}
  if compareDirectiveToColor(self.currentIdentity.facialMaskDirectives, self.speciesJson.bodyColor) then
    self.returnInfoColors = self.speciesJson.bodyColor
  elseif compareDirectiveToColor(self.currentIdentity.facialMaskDirectives, self.speciesJson.hairColor) then
    self.returnInfoColors = self.speciesJson.hairColor
  elseif compareDirectiveToColor(self.currentIdentity.facialMaskDirectives, self.speciesJson.undyColor) then
    self.returnInfoColors = self.speciesJson.undyColor
  else 
    self.returnInfoColors = nil
  end
  args.isOverride = true
end

function selectedTab.BColor(args)
  args.title = {}
  args.colors = {}
  args.iIcon = {}
  if #self.speciesJson.bodyColor > 1 then
    self.returnInfoColors = self.speciesJson.bodyColor
  else
    self.returnInfoColors = nil
  end
  args.isOverride = true
end

function selectedTab.UColor(args)
  args.title = {}
  args.colors = {}
  args.iIcon = {}
  if #self.speciesJson.undyColor > 1 then
    self.returnInfoColors =  self.speciesJson.undyColor
  else
    self.returnInfoColors = nil
  end
  args.isOverride = true
end


function selectedTab.Prsnlity(args)
  local npcType = self.currentType
  self.typeConfig = root.npcConfig(npcType)
  args.title = {}
  args.iData = {}
  for _,v in ipairs(self.typeConfig.scriptConfig.personalities) do
    local prsnlity = v[2]
    --dLog(prsnlity.personality, "Prsnlity:  ")
    table.insert(args.title,prsnlity.personality)
    args.iData[prsnlity.personality] = prsnlity
  end
  args.isOverride = true
end

function selectedTab.Export(args)
  args.useInfoList = true
  args.skipTheRest = true
  args.selectedCategory = "ExportOptn"
  self.currentOverride.identity = parseArgs(self.currentOverride.identity, copy(self.currentIdentity))
  setNpcName()
  local args = {
    npcSpecies = self.currentSpecies,
    npcSeed = self.currentSeed,
    npcType = self.currentType,
    npcLevel = self.currentLevel,
    npcParam = self.currentOverride
  }
  local spawner = world.getObjectParameter(pane.containerEntityId(),"spawner")
  spawner.npcSpeciesOptions[1] = args.npcSpecies
  spawner.npcTypeOptions[1] = args.npcType
  spawner.npcParameterOptions[1] = args.npcParam
  local exportString = string.format("/spawnitem spawnerwizard 1 '{\"shortdescription\":\"%s Spawner\",\"retainObjectParametersInItem\": true, \"level\":%s,\"spawner\":%s}'", args.npcParam.identity.name, args.currentLevel, sb.printJson(spawner))
  local config = getUserConfig("npcSpawnerPlus")
  local name = widget.getText(self.nameBox)
  local species = self.currentSpecies
  local gender = self.currentIdentity.gender
  local key = string.format("%s%s%s", name,species,gender)
  self.uniqueExportId = key:lower()
  dLog("")
  dLog("Search ID:  "..key:lower().."\n\n"..exportString.."\n\n")
  dLog("")
  dLog("")
end

function selectedTab.Override(args)
  args.useInfoList = true
  args.skipTheRest = true
  args.selectedCategory = "OverrideOptn"
end

function selectedTab.Info(args)
  args.useInfoList = true
  args.skipTheRest = true
  args.selectedCategory = self.categoryWidgetData
end

function selectedTab.Detach(args)
  args.useInfoList = true
  args.skipTheRest = true
  args.selectedCategory = "DetachOptn"
end

function override.set(curO, cur, setParams, ...)
    local setParam = config.getParameter("overrideConfig.setParams."..setParams)
    if not setParam then dLog("Cannot find parameter") return false, "Cannot find parameter:"..setParams.." spelling error?" end
    local setPath = config.getParameter("overrideConfig.path."..setParam[1])
    if not setPath then dLog("cannot find path to parameter") return false, "cannot find path to parameter" end
    local setPathTable = getPathStr(curO, setPath)
    if not setPathTable then 
      setPathTable = setPathStr(curO,setPath,{})
    end
    --dLog(setPathTable)
    local formattedParam = formatParam(setParam[2], ...)
    if type(formattedParam) == "nil" then dLog("formatted incorrectly") return false, ("value given incorrectly formatted: Expect: "..setParam[2]) end
    setPathTable[setParam[1]] = formattedParam
    return true
end

function override.detach()
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
  override.outputStr("re-open the panel to see the updated changes")
  userConfig = root.getConfigurationPath(key)
  --dLog(userConfig,"userConfig:")
  userConfig = mergeUnique(userConfig, successes)
  --dLog(userConfig,"userConfig:")
  root.setConfigurationPath(key, userConfig)
  return true
end

function override.clearcache()
  world.setProperty(self.npcTypeStorage, nil)
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

  output = dPrintJson(output)
  

  local oldText = widget.getData(self.infoLabel) or ""

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

function applyDirective(cur, curO, value, data)
  local path = data.path
  local gsubTable = data.gsubTable
  local directive = jsonPath(curO, path) or cur[data.key] 
  
  if directive == "" then return end
  local b = string.find(directive, gsubTable[1])
    if not b then 
        directive = directive..gsubTable[2]
    else
        directive = string.gsub(directive,gsubTable[1],gsubTable[2],1)
    end
  
    directive = string.gsub(directive,"<(.)>",value,1)
    jsonSetPath(curO, path, directive)
end

function getDirectiveValue(cur, curO, data)
  local path = data.path
  local gsubTable = data.gsubTable
  
  local directive = jsonPath(curO, path) or cur[data.key]
    local b, _, value = string.find(directive, gsubTable[1])
    return value
end


function removeDirective(cur, curO, data)
  local path = data.path
  local gsubTable = data.gsubTable
  local directive = jsonPath(curO, path) or ""

  local b, _, value = string.find(directive, gsubTable[1])
  if not b then 
    --dLog("skipping")
    return 
  end
  directive = string.gsub(directive,gsubTable[1],"",1)
  --dLog(directive, "directive")
  jsonSetPath(curO, path, directive)
end

function uninit()
  self.tbFeedbackColorRoutine = nil
end

function onMainSliderChange()
  if not self.doingMainUpdate then return end
  if self.updatingSlider then return end
  local data = widget.getData(self.sldMain)
  local value = widget.getSliderValue(self.sldMain)
  local cur = self.currentIdentity
  local curO = self.currentOverride
  if data.removeOnZero and cur[data.key] == "" then
    widget.setSliderValue(self.sldMain, 0)
  else
    self[data.funcName](value, data)
  end
  --Need to get value again because it may have changed
  value = widget.getSliderValue(self.sldMain)

  --dLog(data.removeOnZero, "onZero?")
  if data.removeOnZero and value == 0 then
    removeDirective(cur, curO, data)
    widget.setText(data.valueId, string.format(data.valueText, data.zeroText))
  else
    widget.setText(data.valueId, string.format(data.valueText, value)) 
  end
  updateNpc()
end

function spnSldParamBase.up()
  local data = widget.getData("spnSldParamBase")
  data.index = util.wrap(data.index+1, 1,data.maxIndx)
  updateSldData(data)
  
  spnSldParamBase.updateOwnData(data)
  widget.setData(data.selfName, data)
end

function spnSldParamBase.down()
    local data = widget.getData("spnSldParamBase")
  data.index = util.wrap(data.index-1, 1,data.maxIndx)
  updateSldData(data)
  
  spnSldParamBase.updateOwnData(data)
  widget.setData(data.selfName, data)
end

function spnSldParamBase.updateOwnData(data)
  local param = data.params[data.index]
  local newSldData =  widget.getData(data.sldName)

  widget.setText(data.lblName, param.titleText)
  widget.setVisible(data.spnDetailName, param.detailVisible)
  widget.setFontColor(data.lblDetailName, param.detailFontColor)
  local value = 0
  if param.titleText ~= "Seed" then
    value = getDirectiveValue(self.currentIdentity, self.currentOverride, newSldData)
    value = tonumber(value) or 0
  else
    value = self.currentSeed
  end

  self.updatingSlider = true
  widget.setSliderRange(data.sldName, param.minSldValue, param.maxSldValue, 1)
  self.updatingSlider = false

  local detailData = widget.getData("spnSldParamDetail")
  spnSldParamDetail.updateOwnData(detailData)

  if widget.getSliderValue(data.sldName) ~= value then
    widget.setSliderValue(data.sldName, value)
  else
    return onMainSliderChange()
  end
end

function spnSldParamDetail.up()
  local data = widget.getData("spnSldParamDetail")
  data.index = util.wrap(data.index+1, 1,data.maxIndx)

    updateSldData(data)
    spnSldParamDetail.updateOwnData(data)
  widget.setData(data.selfName, data)
end

function spnSldParamDetail.down()
  local data = widget.getData("spnSldParamDetail")
  data.index = util.wrap(data.index-1, 1,data.maxIndx)
  updateSldData(data)
  spnSldParamDetail.updateOwnData(data)
  widget.setData(data.selfName, data)
end

function spnSldParamDetail.updateOwnData(data)
  local text = data.params[data.index]
  widget.setText(data.lblName, text)


  local newSldData =  widget.getData(data.sldName)
  local value = 0

  value = getDirectiveValue(self.currentIdentity, self.currentOverride, newSldData)
  value = tonumber(value) or 0
  
  if self.currentIdentity[newSldData.key] == "" then
    widget.setFontColor(data.lblName, data.fontColor[1])
  else 
    widget.setFontColor(data.lblName, data.fontColor[2]) 
  end

  if widget.getSliderValue(data.sldName) ~= value then
    widget.setSliderValue(data.sldName, value)
  else
    return onMainSliderChange()
  end
end

function updateSldData(data)
  local sldData = widget.getData(data.sldName)
  local newSldData = data.sldParams[data.index]
  sldData = parseArgs(newSldData, sldData)
  widget.setData(data.sldName, sldData)
end

