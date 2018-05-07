require "/scripts/npcspawnutil.lua"
require "/scripts/loggingutil.lua"
require "/scripts/rect.lua"
require "/scripts/vec2.lua"
spnIdleStance = {}
spnSldParamBase = {}
spnSldParamDetail = {}
modNpc = {}
selectedTab = {}
override = {}

function init(cardArgs)
  local baseConfig = root.assetJson("/interface/scripted/NpcMenu/modConfig.config:init")
  self.gettingInfo = world.getObjectParameter(pane.containerEntityId(), "npcArgs")
  self.npcTypeList = baseConfig.npcTypeList
  self.getSpeciesPath = function(species, path)          
    path = path or "/species/"
    return tostring(path..species..".species")
  end

  self.tabOptions = config.getParameter("tabOptions.Generate")
  self.tabData = nil
  local protectorate = jsonPath(root.npcConfig("villager"), "scriptConfig.questGenerator.graduation.nextNpcType")
  
  self.speciesList = root.assetJson("/interface/windowconfig/charcreation.config:speciesOrdering")
  self.speciesList = npcUtil.mergeUnique(self.speciesList, baseConfig.additionalSpecies)
  
  if protectorate ~= nil then
    local listOfProtectorates = {}
    for _,v in ipairs(protectorate) do
      table.insert(listOfProtectorates, tostring(v[2]))
    end
    self.npcTypeList = npcUtil.mergeUnique(self.npcTypeList, listOfProtectorates)
  end
  for i,v in ipairs(self.npcTypeList) do
    if not pcall(root.npcConfig,v) then
      dLog(v, "bad NpcType: ")
      self.npcTypeList[i] = "_r"
    end
  end
  table.sort(self.speciesList)
  table.sort(self.npcTypeList)
  while string.find(self.npcTypeList[1],"_r",1,true) do
    table.remove(self.npcTypeList, 1)
  end
  
  for i,v in ipairs(baseConfig.npcTypeListPrio) do
    table.insert(self.npcTypeList, 1, v)
  end

  self.categoryWidget = "rgSelectCategory"
  self.categoryWidgetData = "Generate"
  self.portraitCanvas = widget.bindCanvas("portraitCanvas")
  self.backgroundCanvas = widget.bindCanvas("backgroundCanvas")
  self.objectImageCanvas = widget.bindCanvas("cardFactoryLayout.cardLayout.objectImageCanvas")
  self.tbGreenColor = {0, 255, 0}
  self.tbRedColor = {255,0,0}
  self.colorChangeTime = 1
  self.slotCount = 12
  self.idleStanceIndex = 0
  self.techList = "techScrollArea.techList"
  self.infoList = "techScrollArea.infoList"
  self.infoLabel = "techScrollArea.lblOverrideConsole"
  self.categoryWidget = "rgSelectCategory"
  self.nameBox = "tbNameBox"
  self.overrideTextBox = "tbOverrideBox"
  self.minSldValue = 0
  self.maxSldValue = 20000
  self.mainUpdate = false
  self.filterText = ""
  self.npcTypeStorage = "npcTypeStorage"
  self.speciesJson = {}

  self.currentType = self.gettingInfo.npcType or self.npcTypeList[math.random(1, #self.npcTypeList)]
  self.currentSeed = self.gettingInfo.npcSeed or math.random(0, 20000)
  self.currentLevel = self.gettingInfo.npcLevel or math.random(0, world.threatLevel())
  self.currentSpecies = self.gettingInfo.npcSpecies or self.speciesList[math.random(1, #self.speciesList)]


  self.gettingInfo.npcParam = self.gettingInfo.npcParam or {}
  if self.gettingInfo.npcParam.identity then 
    self.identity = copy(self.gettingInfo.npcParam.identity)
  else
    self.identity = {}
  end
  if self.gettingInfo.npcParam.scriptConfig then
    self.scriptConfig = copy(self.gettingInfo.npcParam.scriptConfig)
  else
    self.scriptConfig = {}
  end
  self.items = {}

  self.getOverrideItemBag = function()
    if path(self.items, "override", 1, 2, 1) then
      return self.items.override[1][2][1]
    end
    return nil
  end

  --Cannot send entity messages during init, so will do it here
  self.sliderValue =  tonumber(self.currentSeed)

  script.setUpdateDelta(20)
end
--this changes based on state


function update(dt)
  if self.mainUpdate == false then 
    self.itemSlotBag = self.itemSlotBag or {}
    self.sliderValue = self.currentSeed
    self.getCurrentOverride = function() return {identity = self.identity, scriptConfig = self.scriptConfig, items = self.items} end
    self.setSeedValue = function(value) 
      self.currentSeed = tonumber(value) 
    end
    self.setOverride = function(value, data) 
      applyDirective(self.seedIdentity, self.getCurrentOverride(), value, data)
    end
    widget.setSliderRange("sldMainSlider", 0, 20000)
    widget.setSliderValue("sldMainSlider",self.currentSeed)
    widget.setText("lblSliderValue", "Seed Value:  "..tostring(self.currentSeed))
    
    widget.setSliderEnabled("sldMainSlider", true)
 
    updateNpc(true)
    modNpc.Species({iTitle = self.currentSpecies}, self.seedIdentity, self.getCurrentOverride())
  
    local id = npcUtil.getGenderIndx(self.identity.gender or self.seedIdentity.gender, self.speciesJson.genders)
    widget.setSelectedOption("rgGenders", id-1)
  
    local equipSlots = config.getParameter("equipSlots")
    local itemBag = world.containerItems(pane.containerEntityId())
    
    if not npcUtil.isContainerEmpty(itemBag) then 
      
      for i = 1, #equipSlots do
        onItemSlotPress(equipSlots[i].."Slot",nil, {nil, itemBag[i]})
      end
    
    end
    widget.setSelectedOption("rgSelectCategory", 0)
    widget.setSelectedOption("rgTabs", 0)
    updatePortrait()
    self.mainUpdate = true
    return 
  end
  promises:update()
  local itemBag = world.containerItems(pane.containerEntityId())

  for i=0, 12 do
    if type(itemBag[i]) ~= type(self.itemSlotBag[i]) then
      player.giveItem(itemBag[i])
      world.containerSwapItemsNoCombine(pane.containerEntityId(), nil, i-1)
    end
  end
  if self.tbFeedbackColorRoutine then self.tbFeedbackColorRoutine() end
end

-----CALLBACK FUNCTIONS-------
function spnIdleStance.up()
  local personalities = root.assetJson("/humanoid.config:personalities")
  self.idleStanceIndex = util.wrap(self.idleStanceIndex + 1, 0, #personalities)
  setIdleStance(self.idleStanceIndex, self.identity)
  
  return updatePortrait()
end

function spnIdleStance.down()
  local personalities = root.assetJson("/humanoid.config:personalities")
  self.idleStanceIndex = util.wrap(self.idleStanceIndex - 1, 0, #personalities)
  setIdleStance(self.idleStanceIndex, self.identity)
  
  return updatePortrait()
end

function onItemSlotPress(id, data, args)
    args = args or {}
    local itemSlotItem = args[1] or widget.itemSlotItem(id)
    local itemSwapItem = args[2] or player.swapSlotItem()
    local calledByProgram = args[1] or args[2]

    data = data or config.getParameter("gui."..id..".data")

    --Check if item its valid
    --if given arguments, then assume its to give an item directly back.

    if itemSwapItem then
      local success, itemType = pcall(root.itemType, itemSwapItem.name)
      if itemType ~= data.equipType then 
        if calledByProgram then player.giveItem(itemSwapItem) end
        return nil
      end
    end
    
    player.setSwapSlotItem(itemSlotItem)
    widget.setItemSlotItem(id, itemSwapItem)

    --get new slot item
    itemSlotItem = widget.itemSlotItem(id)

    --save it in the back end
    world.containerSwapItemsNoCombine(pane.containerEntityId(), itemSlotItem, data.containerSlot)
    --throw away the return value of containerSwapItems as we already gave it back via set SwapSlotItem.
    if not self.items.override then 
      self.items.override = npcUtil.buildItemOverrideTable(jarray())
    end
    --add / remove / update self.items
    itemSlotItem = itemSlotItem and ({itemSlotItem})
    self.items.override[1][2][1][data.equipSlot] = itemSlotItem
    if not self.itemSlotBag then self.itemSlotBag = {} end
    self.itemSlotBag[data.containerSlot+1] = itemSlotItem
    if npcUtil.isContainerEmpty(self.items.override[1][2][1]) then 
      self.items.override = nil
    end
    return updateNpc()
end

function onImportItemSlotClick(id, data)
  local swapItem = player.swapSlotItem()
  local slotItem = widget.itemSlotItem(id)

  if swapItem == nil then return end

  if path(swapItem, "parameters", "npcArgs") then

    self.currentSpecies = swapItem.parameters.npcArgs.npcSpecies
    self.currentType = swapItem.parameters.npcArgs.npcType
    self.currentSeed = swapItem.parameters.npcArgs.npcSeed
    self.currentLevel = swapItem.parameters.npcArgs.npcLevel
    
    updateNpc(true)
    modNpc.Species({iTitle = self.currentSpecies}, self.seedIdentity, self.getCurrentOverride())


    self.items = swapItem.parameters.npcArgs.npcParam.items
    self.identity = swapItem.parameters.npcArgs.npcParam.identity
    self.scriptConfig = swapItem.parameters.npcArgs.npcParam.scriptConfig
    widget.setItemSlotItem(id, swapItem)

    
  
    local id = npcUtil.getGenderIndx(self.identity.gender or self.seedIdentity.gender, self.speciesJson.genders)
    widget.setSelectedOption("rgGenders", id-1)

    widget.setSelectedOption("rgSelectCategory", 0)
    widget.setSelectedOption("rgTabs", 0)
    updateNpc()    
  end
end


function onExportItemSlotClick(id, data)

  local swapItem = player.swapSlotItem()
  local slotItem = widget.itemSlotItem(id)
  
  if not slotItem then
    widget.setSelectedOption("rgSelectCategory", 2)
    widget.setSelectedOption("rgTabs", 3)
    widget.setVisible("exportItemLbl", false)
    return selectedTab.Export()
  end
  if swapItem then
    return 
  end

  player.setSwapSlotItem(slotItem)
  widget.setItemSlotItem(id, nil)
  widget.setVisible("exportItemLbl", true)
  return 
---]]
end

function interpTextColor(tbPath)
  local timer = 0
  local name = tbPath or self.overrideTextBox
  local dt = script.updateDt()
  while timer < self.colorChangeTime do
    timer = math.min(timer + dt, self.colorChangeTime)
    local ratio = timer/self.colorChangeTime
    for i,v in ipairs(self.curOverrideColor) do
      self.curOverrideColor[i] = math.min(interp.sin(ratio,v,255),255) 
    end
    widget.setFontColor(name, self.curOverrideColor)
    coroutine.yield()
  end
  self.tbFeedbackColorRoutine = nil
end

--callback
function onOverrideEnter()
  local wasSuccessful = nil
  local overrideText = widget.getText(self.overrideTextBox)
  local parsedStrings = nil
  while self.tbFeedbackColorRoutine do
    self.tbFeedbackColorRoutine()
  end

  overrideText = string.gsub(overrideText, "  "," ",1, true)
  while overrideText[#overrideText] == " " do
    overrideText[#overrideText] = ""
  end
  while overrideText[1] == " " do
    overrideText[1] = ""
  end
  if overrideText ~= "" then 
    parsedStrings = util.split(overrideText, " ")
    while self.tbFeedbackColorRoutine do
      self.tbFeedbackColorRoutine()
    end
    parsedStrings[1] = string.lower(parsedStrings[1])

    if parsedStrings[2] then
      parsedStrings[2] = string.lower(parsedStrings[2])
    end

    if not(parsedStrings[1] == "output") then  
      for i,v in ipairs(parsedStrings) do
        parsedStrings[i] = string.lower(v)
      end
    end

  end
  
  if override[parsedStrings[1]] then
    wasSuccessful, errorMsg = override[parsedStrings[1]](self.getCurrentOverride(),self.seedIdentity,table.unpack(parsedStrings,2))
  end
  if wasSuccessful then
    widget.setFontColor(self.overrideTextBox, self.tbGreenColor)
    self.curOverrideColor = copy(self.tbGreenColor)
    self.tbFeedbackColorRoutine = coroutine.wrap(interpTextColor)
    self.tbFeedbackColorRoutine()
    return updateNpc()
  else
    widget.setFontColor(self.overrideTextBox, self.tbRedColor)
    self.curOverrideColor = copy(self.tbRedColor)
    self.tbFeedbackColorRoutine = coroutine.wrap(interpTextColor)
    self.tbFeedbackColorRoutine()
  end
  if not wasSuccessful then
    return override.outputStr(errorMsg)
  end
end

--Callback
function onSeachBoxKeyPress(tbLabel)
  local text = widget.getText(tbLabel)

  if text == self.filterText then return end
  self.filterText = text
  local args = widget.getData(string.format("%s", self.techList))
  --dLog("keypress passed")
  if text == "" then text = nil end
  args.filter = text
  return setList(args)
end

--Callback

function setNpcName(instant)
  while self.tbFeedbackColorRoutine do
    self.tbFeedbackColorRoutine()
  end

  local text = widget.getText(self.nameBox)
  if text == "" then
    --get seed name
    self.identity.name = tostring(self.seedIdentity.name)
    widget.setText(self.nameBox, self.identity.name)
  else
    self.identity.name = text
  end
  if instant == true then return end
  widget.setFontColor(self.nameBox, self.tbGreenColor)
  self.curOverrideColor = copy(self.tbGreenColor)
  self.tbFeedbackColorRoutine = coroutine.wrap(interpTextColor)
  self.tbFeedbackColorRoutine(self.nameBox)
end

function finalizeNpcParameters()
  local hasEquip = false
  local hasWeapon = false
  local itemBag = world.containerItems(pane.containerEntityId())
  local equipSlots = config.getParameter("equipSlots")

  if (not path(self.scriptConfig,"initialStorage","itemSlots")) then 
    setPath(self.scriptConfig,"initialStorage","itemSlots",{})
  end

  local itemSlots = {}
  local slotName = ""
  for i = 1, 4 do 
    if itemBag[i] then
      hasWeapon = true
      slotName = equipSlots[i]
      itemSlots[slotName] = copy(itemBag[i])
      if itemSlots[slotName] and string.find(itemSlots[slotName].name, "capturepod",1,true) then 
        itemSlots[slotName].name = "npcpetcapturepod" 
        itemSlots[slotName].count = 1
      end
    end
  end

  self.scriptConfig.personality = self.scriptConfig.personality or {}

  if jsize(self.scriptConfig.personality) == 0 then
    self.scriptConfig.personality = npcUtil.getPersonality(self.currentType, self.currentSeed)
  end

  for i = 5, #itemBag do
    if itemBag[i] then
      hasEquip = true
      local slotName = equipSlots[i]
      itemSlots[slotName] = copy(itemBag[i])
    end
  end
  self.scriptConfig.initialStorage.itemSlots = itemSlots

  --The only scriptConfig parameter to get saved is personality.  You can sneak in behaviorConfig parameters in that table.
  --If no personality was manually chosen then I will mimic what bmain.lua does when generating a personality
  --Update - I no longer technically need this because its bollocks and doesnt work due to chucklefish's personality changes being applied AFTER its behavior was implemented.
  --However I am adding it in anyways because if chucklefish decides to fix it, it will be ready to go!
  if hasWeapon then
    setPath(self.scriptConfig, "personality", "behaviorConfig","emptyHands",false)
    setPath(self.scriptConfig, "behaviorConfig","emptyHands",false)
  end

  if (not hasEquip) and (not hasWeapon) and self.scriptConfig.initialStorage then
    self.scriptConfig.initialStorage = nil
  end

  setNpcName(true)

  if path(self.scriptConfig, "personality", "storedOverrides") then
    self.scriptConfig.personality.storedOverrides = {}
  end
  self.scriptConfig.personality.storedOverrides = copy(self.getCurrentOverride())
end

function acceptBtn()
  finalizeNpcParameters()
  local args = {
    npcSpecies = tostring(self.currentSpecies),
    npcSeed = self.currentSeed,
    npcType = tostring(self.currentType),
    npcLevel = math.floor(tonumber(self.currentLevel)),
    npcParam = copy(self.getCurrentOverride())
  }

 
  world.sendEntityMessage(pane.containerEntityId(), "setNpcData", args)
  pane.dismiss()
end

function setListInfo(categoryName, uniqueId, infoOverride)
  widget.clearListItems(self.infoList)
  if not categoryName then return end
  local tabInfo = config.getParameter("tabOptions."..categoryName)
  local info = infoOverride or root.assetJson("/interface/scripted/NpcMenu/modConfig.config:infoDescription")
  local subInfo = info[categoryName]
  if uniqueId then 
    for i,v in ipairs(subInfo) do
      if v.key == "uniqueID" then 
        info[categoryName][i].value = "^orange;"..uniqueId
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

function onTabSelection(index, tabData)
  --dLog("onTabSelection")
  self.returnInfo = {}
  self.returnInfoColors = nil
  self.curSelectedTitle = "none"
  widget.setText(self.infoLabel, "")
  widget.setData(self.infoLabel, "")

  local listType = self.tabOptions[index+1]

  if not listType or listType == "" then 
    return setList(nil) 
  end
  dLog(listType, "listType!")
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
      local genderIndx = npcUtil.getGenderIndx(self.identity.gender or self.seedIdentity.gender, self.speciesJson.genders)
      getSpeciesAsset(self.speciesJson, genderIndx, self.currentSpecies, optn, self.returnInfo)
    end
  end
  self.returnInfo.colors = self.returnInfoColors
  setList(self.returnInfo)
  return updatePortrait()
end

function onCategorySelection(id, data)
  self.tabOptions = config.getParameter("tabOptions."..data)
  self.categoryWidgetData = data
  if data == "Generate" then
    widget.setVisible("techScrollArea", true)
    widget.setSliderEnabled("sldMainSlider", true)
    widget.setVisible("spnPersonality", false)
    widget.setVisible("lblPersonality", false)
  elseif data == "Colorize" then
    widget.setVisible("techScrollArea", true)
    widget.setVisible("spnPersonality", true)
    widget.setVisible("lblPersonality", true)
  elseif data == "Advanced" then
    widget.setSliderEnabled("sldMainSlider", false)
    widget.setVisible("spnPersonality", false)
    widget.setVisible("lblPersonality", false)
  end

  changeTabLabels("rgTabs")
  local indx = widget.getSelectedOption("rgTabs")
  local tabData = widget.getSelectedData("rgTabs")
  dLogJson({id, indx, tabData, self.categoryWidgetData}, "onCategorySelection:  id, indx, tabData, self.categoryWidgetData")
  return  onTabSelection(indx)
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
          if hexIndx == 2 then break end
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

      widget.setText(string.format("%s.%s.title", self.techList, listItem), displayText)
      widget.setData(string.format("%s.%s", self.techList, listItem), {iTitle=iTitle , iData = iData})

      if v == self.curSelectedTitle then 
        selectedItem = tostring(listItem)
      end 
    end
  end
  widget.setData(string.format("%s", self.techList), args)
  if selectedItem then  
    widget.setListSelected(self.techList, selectedItem)
  end
end


function onSelectItem(name, listData)
  dLog("onSelectItem")
  local listItem = widget.getListSelected(self.techList)
  if not listItem then return end
  local itemData = widget.getData(string.format("%s.%s", self.techList, listItem))
  listData.iData = copy(itemData.iData)
  listData.iTitle = itemData.iTitle
  listData.clearConfig = itemData.clearConfig
  if not listData and listData.listType then return end
  --dLogJson(itemData, "onSelectItem: itemData")
  --self.curSelectedTitle = itemData.iTitle
  modNpc[listData.listType](listData, self.seedIdentity, self.getCurrentOverride())

  return updateNpc()
end

--------SPECIES GATHER INFO FUNCTIONS--------

function getSpeciesAsset(speciesJson, genderIndx, species, optn, output)
  if not optn then return end
  local genderPath = speciesJson.genders[genderIndx]
  local title = {}
  local iIcon = {}
  local iData = {}
  local info = {}
  local oOne = tostring(optn[1])
  local oTwo = tostring(optn[2])
  
  info[oOne] = genderPath[oOne] or optn[3]
  info[oTwo] = genderPath[oTwo]
  local directive = self.identity[optn[4]] or self.seedIdentity[optn[4]]
  for _,v in ipairs(info[oTwo]) do
    table.insert(title, v)
    iIcon[v] = string.format("/humanoid/%s/%s/%s.png:normal%s",species,info[oOne],v,directive)
    if not output.iData then
      iData[v] = output.assetGroup
    end
  end
  output.title = title
  output.iIcon = iIcon
  if not output.iData then
    output.iData = iData
  end
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
function changeTabLabels(tabBaseName)
  self.tabOptions = config.getParameter("tabOptions."..self.categoryWidgetData)
  if self.categoryWidgetData == "Generate" then
    updateNpc(true)
    if self.seedIdentity.facialMaskType == "" then
      npcUtil.replaceValueInList(self.tabOptions, "FMask", "")
    end

    if self.seedIdentity.facialHairType == "" then
      npcUtil.replaceValueInList(self.tabOptions, "FHair", "")
    end

  elseif self.categoryWidgetData == "Colorize" then
    self.tabOptions = config.getParameter("tabOptions.Colorize")
    if self.seedIdentity.facialHairType == "" then
      npcUtil.replaceValueInList(self.tabOptions, "FHColor", "")
    end
    if self.seedIdentity.facialMaskType == "" then
      npcUtil.replaceValueInList(self.tabOptions, "FMColor", "")
    end
    if self.speciesJson.hairColorAsBodySubColor then
      npcUtil.replaceValueInList(self.tabOptions, "", "BSColor")
    end

  end 
  for i,v in ipairs(self.tabOptions) do
    widget.setText(string.format("%s.%s",tabBaseName,i-1), self.tabOptions[i])
  end
end

--While the humanoid table has defined these idle stances as personalities, they do not affect
--actual npc behavior.  That is the personality table with the path: scriptConfig.personality
--if scriptConfig.personality isnt found, its chosen at random from scriptConfig.personalities
function setIdleStance(index, identity)
  if index ~= 0 then
    widget.setText("lblIdleStance", tostring(index))
    local personalities = root.assetJson("/humanoid.config:personalities")
    local personality = personalities[index]
    --assert(personality, string.format("cannot find personality, bad index?  :  %s", index))
    identity.personalityIdle = personality[1]
    identity.personalityHeadOffset = personality[3]
    identity.personalityArmIdle = personality[2]
    identity.personalityArmOffset = personality[4]
  else
    identity.personalityIdle = nil
    identity.personalityHeadOffset = nil
    identity.personalityArmIdle = nil
    identity.personalityArmOffset = nil
    widget.setText("lblIdleStance", "Seed")
  end
end

function updateNpc(noVisual)
  self.seedIdentity = root.npcVariant(self.currentSpecies, self.currentType, self.currentLevel, self.currentSeed).humanoidIdentity
  if self.identity.name then
    widget.setText(self.nameBox, self.identity.name)
  else
    widget.setText(self.nameBox, self.seedIdentity.name)
  end
  if noVisual then return end
  --dLogJson(curOverride, "whsa", false)
  return updatePortrait()
end

function updatePortrait()
  local npcPort = createPortrait("full")
  self.portraitCanvas:clear()
  local start = {1,1}
  for _,v in ipairs(npcPort) do
    self.portraitCanvas:drawImage(v.image,{v.position[1]+start[1], v.position[2]+start[2]}, 1.8, v.color, false)
  end
  return npcPort
end

function createPortrait(type)
  local fakeItems = getFakeItems()
  local params  = {
    identity = self.identity,
    scriptConfig = self.scriptConfig,
    items = fakeItems or self.items
  }
  local npcPort = root.npcPortrait(type, self.currentSpecies, self.currentType, self.currentLevel, self.currentSeed, params)
  return npcPort
end

function updateSpecies(species)
  self.currentSpecies = species
  dLogJson({(self.speciesJson or {}).kind, self.currentSpecies})
  if not((self.speciesJson or {}).kind == self.currentSpecies) then
    if self.mainUpdate then
      local gender = self.identity.gender 
      self.identity = {}
      self.identity.gender = gender
    end
    self.speciesJson = root.assetJson(self.getSpeciesPath(species))
    local id = npcUtil.getGenderIndx(self.identity.gender or self.seedIdentity.gender, self.speciesJson.genders)
    if self.mainUpdate then
      return widget.setSelectedOption("rgGenders", id-1)
    end
  end
end

function matchDirectivesToJson(identityDirective, speciesJson)
  if npcUtil.compareDirectiveToColor(identityDirective, speciesJson.bodyColor) then
    return speciesJson.bodyColor
  elseif npcUtil.compareDirectiveToColor(identityDirective, speciesJson.hairColor) then
    return speciesJson.hairColor
  elseif npcUtil.compareDirectiveToColor(identityDirective, speciesJson.undyColor) then
    return speciesJson.undyColor
  else 
    return nil
  end
end

------CHANGE NPC FUNCTIONS---------
function modNpc.Species(listData, cur, curO)
  updateSpecies(listData.iTitle)
  changeTabLabels("rgTabs")
  local directive = widget.getData("rgGenders")
  local genderIndx = npcUtil.getGenderIndx(self.identity.gender or cur.gender, self.speciesJson.genders)
  local speciesIcon = self.speciesJson.genders[genderIndx].characterImage
  widget.setImage("techIconHead",speciesIcon)
  widget.setButtonOverlayImage("rgGenders.0", self.speciesJson.genders[1].image..directive)
  widget.setButtonOverlayImage("rgGenders.1", self.speciesJson.genders[2].image..directive)

end

function modNpc.NpcType(listData, cur, curO)
  self.currentType = listData.iTitle
end

function getFakeItems()
  local bag = self.getOverrideItemBag()
  if bag then 
    return nil
  end

  local config = root.npcConfig(self.currentType)
  local isCrewmember = path(config.scriptConfig,"crew","recruitable") or false
  local defaultUniform = path(config.scriptConfig,"crew","defaultUniform")
  local colorIndex = path(config.scriptConfig,"crew","role", "uniformColorIndex")
  local items
  if isCrewmember and not isEmpty(defaultUniform or {}) then
    items = {}
    items.override = npcUtil.buildItemOverrideTable(jarray())
    for k, v in pairs(defaultUniform) do
      items.override[1][2][1][k] = {dyeUniformItem(v, colorIndex)}
    end
  end
  return items
end

function dyeUniformItem(item, colorIndex)
  if not item or not colorIndex then return item end

  local item = copy(item)
  if type(item) == "string" then item = { name = item, count = 1 } end
  item.parameters = item.parameters or {}
  item.parameters.colorIndex = colorIndex

  return item
end


function modNpc.Hair(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then 
    curO.hairType = nil
    curO.hairGroup = nil
  else
    curO.hairType = listData.iTitle
    curO.hairGroup = listData.iData
  end
end

function modNpc.FHair(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then 
    --dLog("listData.fhair : clearConfig:  entered ClearConfig")
    --curO["facialHairGroup"] = nil
    curO.facialHairType = nil
    curO.facialHairGroup = nil
  else
    --curO.facialHairGroup = listData.facialHairGroup
    curO.facialHairType = listData.iTitle
    curO.facialHairGroup = listData.iData
  end
  --dCompare("facialHairs: ",curO.facialHairGroup, curO.facialHairType)
end

function modNpc.FMask(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then 
    --dLog("listData.fMask : clearConfig:  entered ClearConfig")
    curO.facialMaskType = nil
    curO.facialMaskGroup = nil
  else
    curO.facialMaskType = listData.iTitle
    curO.facialMaskGroup = listData.iData
  end
  --dCompare("facialMasks: ",curO.facialMaskGroup, curO.facialMaskType)
end

function modNpc.HColor(listData, cur, curO)
  local curO = curO.identity
  if cur.hairDirectives == "" then return end
  if listData.clearConfig then
    curO.hairDirectives = nil
  else
    curO.hairDirectives = npcUtil.replaceDirectives(curO.hairDirectives or cur.hairDirectives, listData.iData)
  end
end

function modNpc.FHColor(listData, cur, curO)
  local curO = curO.identity
  if cur.facialHairDirectives == "" then return end
  if listData.clearConfig then
    curO.facialHairDirectives = nil
  else
    curO.facialHairDirectives = npcUtil.replaceDirectives(curO.facialHairDirectives or cur.facialHairDirectives, listData.iData)
  end
end

function modNpc.FMColor(listData, cur, curO)
  local curO = curO.identity
  if cur.facialMaskDirectives == "" then return end
  if listData.clearConfig then
    curO.facialMaskDirectives = nil
  else
    curO.facialMaskDirectives = npcUtil.replaceDirectives(curO.facialMaskDirectives or cur.facialMaskDirectives, listData.iData)
  end
end

function modNpc.BColor(listData, cur, curO)
  local curO = curO.identity
  --dLog("enterd BColor")
  if listData.clearConfig then
    curO.bodyDirectives = nil
    curO.emoteDirectives = nil
  else
    curO.bodyDirectives = npcUtil.replaceDirectives(curO.bodyDirectives or cur.bodyDirectives, listData.iData)
    curO.emoteDirectives = npcUtil.replaceDirectives(curO.emoteDirectives or cur.emoteDirectives, listData.iData)  
  end
end

function modNpc.BSColor(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then
    curO.bodyDirectives = nil
    curO.emoteDirectives = nil
  else
    curO.bodyDirectives = npcUtil.replaceDirectives(curO.bodyDirectives or cur.bodyDirectives, listData.iData)
    curO.emoteDirectives = npcUtil.replaceDirectives(curO.emoteDirectives or cur.emoteDirectives, listData.iData)  
  end
end

function modNpc.UColor(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then
    local endDirective = npcUtil.getDirectiveAtEnd(cur.bodyDirectives)
    curO.bodyDirectives = npcUtil.replaceDirectives(curO.bodyDirectives, endDirective)
    curO.hairDirectives = npcUtil.replaceDirectives(curO.hairDirectives, endDirective)  
    curO.emoteDirectives = npcUtil.replaceDirectives(curO.emoteDirectives, endDirective)
  else
    curO.bodyDirectives = npcUtil.replaceDirectives(curO.bodyDirectives or cur.bodyDirectives, listData.iData)
    curO.hairDirectives = npcUtil.replaceDirectives(curO.hairDirectives or cur.hairDirectives, listData.iData)  
    curO.emoteDirectives = npcUtil.replaceDirectives(curO.emoteDirectives or cur.emoteDirectives, listData.iData)  
  end
end

function modNpc.Prsnlity(listData,cur,curO)
  if listData.clearConfig then 
    if path(curO,"scriptConfig","personality") then
      curO.scriptConfig.personality = nil
    end
  else
    construct(curO,"scriptConfig","personality")
    self.scriptConfig.personality = listData.iData
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
  local genderIndx = npcUtil.getGenderIndx(self.identity.gender or self.seedIdentity.gender, self.speciesJson.genders)-1
  for _,v in ipairs(self.speciesList) do
    local jsonPath = string.format("/species/%s.species:genders.%s.characterImage",v, tostring(genderIndx))
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
  local updateToWorld = false
  --TODO: Load speeds are pretty damn fast already, but we still want to keep things updated. 
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
  local modVersion = npcUtil.modVersion()
  local worldStorage, clearCache = npcUtil.getWorldStorage(self.npcTypeStorage, modVersion)
  if clearCache then
    world.setProperty(self.npcTypeStorage, {iIcon = {}})
    worldStorage = {iIcon = {}}
  end
  local npcConfig = nil
  local success = false

  for _,v in ipairs(self.npcTypeList) do
    if not worldStorage.iIcon[v] then
      success, npcConfig = pcall(root.npcConfig,v)
      --dCompare("npcType: ",v,npcConfig)
      if success then
        if npcUtil.checkIfNpcIs(v, npcConfig, hostile) then worldStorage.iIcon[v] = hIcon; updateToWorld = true;
        elseif npcUtil.checkIfNpcIs(v, npcConfig, guard) then worldStorage.iIcon[v] = gIcon ; updateToWorld = true;
        elseif npcUtil.checkIfNpcIs(v, npcConfig, merchant) then worldStorage.iIcon[v] = mIcon ; updateToWorld = true;
        elseif npcUtil.checkIfNpcIs(v, npcConfig, crew) then worldStorage.iIcon[v] = cIcon; updateToWorld = true;
        else  
          worldStorage.iIcon[v] = vIcon
        end
      end
    end
  end
  if updateToWorld then
    worldStorage.time = world.time()
    worldStorage.modVersion = modVersion
    world.setProperty(self.npcTypeStorage, worldStorage)
  end
  args.iIcon = shallowCopy(worldStorage.iIcon)
  return worldStorage
end

function selectedTab.Hair(args)
  local gender = self.identity.gender or self.seedIdentity.gender
  local genderIndx = npcUtil.getGenderIndx(gender, self.speciesJson.genders)
  
  self.curSelectedTitle = self.identity.hairType or self.seedIdentity.hairType 

  args.assetGroup = self.speciesJson.genders[genderIndx].hairGroup or "hair"
  args.title = {}
  args.isOverride = true
end

function selectedTab.FHair(args)

  local gender = self.identity.gender or self.seedIdentity.gender
  local genderIndx = npcUtil.getGenderIndx(gender, self.speciesJson.genders)

  self.curSelectedTitle = self.identity.facialHairType or self.seedIdentity.facialHairType
  --self.curSelectedTitle = self.curSelectedTitle.." - "..gender

  args.assetGroup = self.speciesJson.genders[genderIndx].facialHairGroup

  args.title = {}
  args.isOverride = true
end

function selectedTab.FMask(args)

  local gender = self.identity.gender or self.seedIdentity.gender
  local genderIndx = npcUtil.getGenderIndx(gender, self.speciesJson.genders)

  self.curSelectedTitle = self.identity.facialMaskType or self.seedIdentity.facialMaskType
  args.assetGroup = self.speciesJson.genders[genderIndx].facialMaskGroup

  args.title = {}
  args.isOverride = true
end

function selectedTab.HColor(args)
  args.title, args.colors, args.iIcon = {}, {}, {}

  args.isOverride = true
  self.returnInfoColors =  matchDirectivesToJson(self.seedIdentity.hairDirectives, self.speciesJson)
end

function selectedTab.FHColor(args)
  args.title, args.colors, args.iIcon = {}, {}, {}

  args.isOverride = true
  self.returnInfoColors = matchDirectivesToJson(self.seedIdentity.facialHairDirectives, self.speciesJson)
end

function selectedTab.FMColor(args)
  args.title, args.colors, args.iIcon = {}, {}, {}

  args.isOverride = true
  self.returnInfoColors = matchDirectivesToJson(self.seedIdentity.facialMaskDirectives, self.speciesJson)
end

function selectedTab.UColor(args)
  args.title, args.colors, args.iIcon = {}, {}, {}

  if #self.speciesJson.undyColor > 1 then
    self.returnInfoColors = self.speciesJson.undyColor
  else
    self.returnInfoColors = nil
  end
  args.isOverride = true
end


function selectedTab.BColor(args)
  args.title, args.colors, args.iIcon = {}, {}, {}
  if #self.speciesJson.bodyColor > 1 then
    self.returnInfoColors = self.speciesJson.bodyColor
  else
    self.returnInfoColors = nil
  end
  args.isOverride = true
end

function selectedTab.BSColor(args)
  args.title, args.colors, args.iIcon = {}, {}, {}
  self.returnInfoColors = self.speciesJson.hairColor
  args.isOverride = true
end

function selectedTab.Prsnlity(args)
  local npcType = self.currentType
  local typeConfig = root.npcConfig(npcType)
  args.title = {}
  args.iData = {}
  args.isOverride = true
  for _,v in ipairs(typeConfig.scriptConfig.personalities) do
    local prsnlity = v[2]
    table.insert(args.title,prsnlity.personality)
    args.iData[prsnlity.personality] = prsnlity
  end
  return typeConfig
end

function selectedTab.Export(args)
  args = args or {}
  args.useInfoList = true
  args.skipTheRest = true
  args.selectedCategory = "ExportOptn"
  self.identity = npcUtil.parseArgs(self.identity, copy(self.seedIdentity))
  setNpcName()
  local args = {
  npcSpecies = self.currentSpecies,
  npcSeed = self.currentSeed,
  npcType = self.currentType,
  npcLevel = self.currentLevel,
  npcParam = self.getCurrentOverride()
  }

  local exportNpc = [[/spawnnpc %s %s %s %s '%s']]
  exportNpc = exportNpc:format(args.npcSpecies, args.npcType, args.npcLevel, args.npcSeed, sb.printJson(args.npcParam))
  


  local name = widget.getText(self.nameBox)
  local species = self.currentSpecies
  local gender = self.seedIdentity.gender
  local key = string.format("%s%s%s", name,species,gender)
  self.uniqueExportId = key:lower()

  local template = [[


    Search ID: %s

     --/NPC SPAWN COMMAND--
%s

     --NPCSPAWNER+ NPC CARD ITEM SPAWN COMMAND--
%s
  ]]

  local item = config.getParameter("templateCard")
  local portrait = createPortrait("full")
  local bust = createPortrait("bust")

  local iconStorage = selectedTab.NpcType()

  local _, indx = util.find(self.npcTypeList, function(input) return input == args.npcType end, 1) 

  item.parameters.shortdescription = name
  item.parameters.inventoryIcon = bust
  --item.parameters.description = "Inscribed in this item contains all the information about your npc.  Share it with everyone!"
  item.parameters.description = ""
  item.parameters.tooltipFields.collarNameLabel = "Created By:  "..world.entityName(player.id())
  item.parameters.tooltipFields.objectImage = portrait
  item.parameters.tooltipFields.subtitle = self.currentType
  item.parameters.tooltipFields.collarIconImage = iconStorage.iIcon[indx]
  item.parameters.npcArgs = {
    npcSpecies = tostring(self.currentSpecies),
    npcSeed = self.currentSeed,
    npcType = tostring(self.currentType),
    npcLevel = math.floor(tonumber(self.currentLevel)),
    npcParam = copy(self.getCurrentOverride())
  }
  cardExportString = [[/spawnitem %s %s '%s']]
  cardExportString = cardExportString:format(item.item, item.count, sb.printJson(item.parameters))

  dLog(template:format(key:lower(), exportNpc, cardExportString))

  widget.setItemSlotItem("exportItemSlot", item)
end

--[[
  "templateCard" : {
    "item" : "secretnote",
    "count": 1,
    "parameters": {
      "rarity" : "Common",
      "category" : "quest",
      "inventoryIcon" : "bust",
      "description" : "A note with a secret message on it.",
      "shortdescription" : "Someones Name",
      "tooltipKind": "filledcapturepod",
      "tooltipFields": {
        "subtitle" : "ThreeTen22",
        "collarNameLabel": "Created By:  ThreeTen",
        "collarIconImage": "/objects/human/bunkerpanel2/bunkerpanel2icon.png",
        "noCollarLabel": "",
        "objectImage" : "full"
      }
    }
  }  
--]]

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

--Callback
function onMainSliderChange()
  if not self.mainUpdate then return end
  if self.updatingSlider then return end
  local data = widget.getData("sldMainSlider")
  local value = widget.getSliderValue("sldMainSlider")
  if data.removeOnZero and self.seedIdentity[data.key] == "" then
    widget.setSliderValue("sldMainSlider", 0)
  else
    self[data.funcName](value, data)
  end
  --Need to get value again because it may have changedG
  value = widget.getSliderValue("sldMainSlider")

  --dLog(data.removeOnZero, "onZero?")
  if data.removeOnZero and value == 0 then
    removeDirective(self.seedIdentity, self.getCurrentOverride(), data)
    widget.setText(data.valueId, string.format(data.valueText, data.zeroText))
  else
    widget.setText(data.valueId, string.format(data.valueText, value)) 
  end
  return updateNpc()
end

function updateSldData(data)
  local sldData = widget.getData(data.sldName)
  local newSldData = data.sldParams[data.index]
  sldData = npcUtil.parseArgs(newSldData, sldData)
  widget.setData(data.sldName, sldData)
end

function spnSldParamBase.run(direction)
  local data = widget.getData("spnSldParamBase")
  if direction == "up" then direction = 1 else direction = -1 end
  data.index = util.wrap(data.index+direction, 1,data.maxIndx)
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
    value = getDirectiveValue(self.seedIdentity, self.getCurrentOverride(), newSldData)
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


function spnSldParamDetail.run(direction)
  local data = widget.getData("spnSldParamDetail")
  if direction == "up" then direction = 1 else direction = -1 end
  data.index = util.wrap(data.index+direction, 1,data.maxIndx)

  updateSldData(data)
  spnSldParamDetail.updateOwnData(data)
  widget.setData(data.selfName, data)
end

function spnSldParamDetail.updateOwnData(data)
  local text = data.params[data.index]
  widget.setText(data.lblName, text)


  local newSldData =  widget.getData(data.sldName)
  local value = 0

  value = getDirectiveValue(self.seedIdentity, self.getCurrentOverride(), newSldData)
  value = tonumber(value) or 0
  
  if self.seedIdentity[newSldData.key] == "" then
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

spnSldParamBase.up = spnSldParamBase.run
spnSldParamBase.down = spnSldParamBase.run

spnSldParamDetail.up = spnSldParamDetail.run
spnSldParamDetail.down= spnSldParamDetail.run


function onGenderSelection(id, data)

  self.identity.gender = data or self.speciesJson.genders[tonumber(id)+1].name
  if self.mainUpdate then 
    local indx = widget.getSelectedOption("rgTabs")
    setList(nil)
    onTabSelection(indx)
    return updateNpc()
  end
end

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

function uninit()
  self.tbFeedbackColorRoutine = nil
end
