local expLeg = select(4, GetBuildInfo()) >= 70000
--[[ TankCDs ]]

local DefaultO = {
  ["framePoint"] = "CENTER";
  ["frameRelativeTo"] = "UIParent";
  ["frameRelativePoint"] = "CENTER";
  ["frameOffsetX"] = 0;
  ["frameOffsetY"] = 0;
  ["hidden"] = false,
  ["hideSelf"] = false,
}

local UnitGUID = UnitGUID
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local myGUID
local moving = false
local LGIST = LibStub:GetLibrary("LibGroupInSpecT-1.1")

local TankCDs_UpdateOptionsArray, TankCDs_CloneTable, TankCDs_CopyValues
function TankCDs_UpdateOptionsArray()
  local TempTankCDsOptions = TankCDs_CloneTable(DefaultO);
  TankCDs_CopyValues(TankCDsOptions, TempTankCDsOptions);
  TankCDsOptions = TempTankCDsOptions
end
--from "SCT" by "Grayhoof"
function TankCDs_CloneTable(t) -- return a copy of the table t
  local new = {}; -- create a new table
  local i, v = next(t, nil); -- i is an index of t, v = t[i]
  while i do
    if type(v)=="table" then
      v=TankCDs_CloneTable(v);
    end
    new[i] = v;
    i, v = next(t, i); -- get next index
  end
  return new;
end
function TankCDs_CopyValues(from,to)
  local i, v = next(from, nil); -- i is an index of from, v = from[i]
  while i do
    if type(v)=="table" then
      if to[i] ~= nil then
        if type(to[i])=="table" then
          TankCDs_CopyValues(v,to[i]);
        end
      end
    else
      if to[i] ~= nil then
        if type(to[i])~="table" then
          to[i] = v;
        end
      end
    end
    i, v = next(from, i); -- get next index
  end
end

local spellIDs = {
---------------------------------------------
--remember to add the spell to spellIDsOrder!
---------------------------------------------
  --[102342] = {cd = 60, class = "DRUID", spec = 4, resetAfterWipe = true}, --Ironbark (-20%)
  [102342] = {cd = {{amount = 60, talent = 21651}, {amount = 90}}, class = "DRUID", spec = {[4]=1}, resetAfterWipe = true}, --Ironbark (-20%, 12s)
  
  [116849] = {cd = 180, class = "MONK", spec = {[2]=1}, resetAfterWipe = true}, --Life Cocoon (shield, +50% periodic healing taken, 12s)
  
  --X[6940] = {cd = {{amount = 90, spec = 3}, {amount = 120}}, class = "PALADIN", charges = {{count = 2, talent = 17593}, {count = 1}}}, --Hand of Sacrifice (-30%, 12s)
  --X[114039] = {cd = 30, class = "PALADIN", talent = 17589, resetAfterWipe = true}, --Hand of Purity (-10%, -80% dot, 6s)
  [6940] = {cd = 150, class = "PALADIN", spec = {[1]=1,[2]=1}}, --Blessing of Sacrifice (-30%, 12s), Protection 90sec CD
  [1022] = {cd = 300, class = "PALADIN", nottalent = 22433}, --Blessing of Protection (single target, 10sec no physical damage)
  [204018] = {cd = 180, class = "PALADIN", spec = {[2]=1}, talent = 22433}, --Blessing of Spellwarding (single target, 10sec no spell damage), replaces Blessing of Protection
  --[204077] = {cd = xxx, class = "PALADIN", spec = {[2]=1}, talent = 17601}, --Final Stand, passive
  
  [33206] = {cd = 180, class = "PRIEST", spec = {[1]=1}}, --Pain Suppression (-5% threat, -40%, 8s)
  [62618] = {cd = 180, class = "PRIEST", spec = {[1]=1}}, --Power Word: Barrier (-5% threat, -40%, 8s)
  [47788] = {cd = 180, class = "PRIEST", spec = {[2]=1}, resetAfterWipe = true}, --Guardian Spirit (+60% healing taken, 40% maxhp on death, 10s)
  
  [114030] = {cd = 120, class = "WARRIOR", talent = 19676, resetAfterWipe = true}, --Vigilance (-30%, 12s)
};
local spellIDsOrder = {
  102342, 116849, 6940, 1022, 204018,
  --114039,
  33206, 62618, 47788, 114030
};

local frame = CreateFrame("Frame", "TankCDsFrame", UIParent)
local frameEvents = {};

local function initFrame()
  local lastSpell, spellIndex
  frame:SetPoint(TankCDsOptions["framePoint"], TankCDsOptions["frameRelativeTo"], TankCDsOptions["frameRelativePoint"], TankCDsOptions["frameOffsetX"], TankCDsOptions["frameOffsetY"])
  frame:SetFrameStrata("LOW")
  frame:SetSize(140, 40)
  
  frame:SetScript("OnEvent", function(self, event, ...)
    frameEvents[event](self, ...); -- call one of the event functions
  end);
  
  frame.subFrames = {};
  local lastSubFrame = nil
  for _, k in ipairs(spellIDsOrder) do
    local spellID = spellIDs[k]
    local subFrame = CreateFrame("Frame", nil, frame)
    subFrame:SetFrameStrata("LOW")
    subFrame:SetSize(140, 12)
    if lastSubFrame then
      subFrame:SetPoint("TOPLEFT", lastSubFrame, "BOTTOMLEFT")
    else
      subFrame:SetPoint("TOPLEFT", frame, "TOPLEFT")
    end
    lastSubFrame = subFrame
    frame.subFrames[k] = subFrame
    
    subFrame.headerText = subFrame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    local spellName = GetSpellInfo(k)
    if spellName then
      subFrame.headerText:SetText(spellName)
    else
      subFrame.headerText:SetText("unknown")
    end
    local c = RAID_CLASS_COLORS[spellID.class or "PRIEST"]
    subFrame.headerText:SetTextColor(c.r, c.g, c.b, 1)
    subFrame.headerText:SetPoint("TOPLEFT", subFrame, "TOPLEFT")
    
    subFrame.cd = spellID.cd
    subFrame.class = spellID.class or "PRIEST"
    subFrame.spec = spellID.spec
    --charges = {{count = 2, talent = 17593}, {count = 1}}
    subFrame.charges = spellID.charges or {{count = 1}}
    subFrame.resetAfterWipe = spellID.resetAfterWipe
    
    subFrame.casterBars = {};
  end
  frame:updateSubFrameVisibility()
  
  frame.bgtexture = frame:CreateTexture(nil, "BACKGROUND")
  frame.bgtexture:SetAllPoints(frame)
  if expLeg then
    frame.bgtexture:SetColorTexture(0, 0, 0, 0.8)
  else
    frame.bgtexture:SetTexture(0, 0, 0, 0.8)
  end
  frame.bgtexture:Hide()
  frame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    TankCDsOptions["framePoint"] = point or "LEFT"
    TankCDsOptions["frameRelativeTo"] = relativeTo or "UIParent"
    TankCDsOptions["frameRelativePoint"] = relativePoint or "CENTER"
    TankCDsOptions["frameOffsetX"] = xOfs
    TankCDsOptions["frameOffsetY"] = yOfs
  end);
  
end

frame.activeSpells = {}
frame.inactiveSpells = {}

frame.getNewCasterBar = function(self, casterName, casterGUID, maxCharges, cd, isDead)
  local ret
  if #(self.inactiveSpells) > 0 then
    ret = table.remove(self.inactiveSpells) --pop last element
  else
    ret = CreateFrame("Frame", nil, self)
    ret:SetFrameStrata("LOW")
    ret:SetSize(140, 12)

    ret.casterText = ret:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    ret.casterText:SetPoint("TOPLEFT", ret, "TOPLEFT", 10, 0)
    
    ret.cdText = ret:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    ret.cdText:SetPoint("TOPRIGHT", ret, "TOPRIGHT")
  end
  
  ret.casterName = casterName
  ret.casterGUID = casterGUID
  ret.durLeft = -1
  ret.tslU = -1
  
  ret.maxCharges = maxCharges or 1
  ret.charges = ret.maxCharges
  ret.cd = cd or 0
  ret.isDead = isDead or false
  ret.isOnCD = false
  
  ret.cdText:SetText("")
  ret:Show()
  
  ret.updateCasterName = function(self)
    if self.maxCharges > 1 then
      self.casterText:SetText(format("%dx %s", self.charges, self.casterName))
    else
      self.casterText:SetText(self.casterName)
    end
  end
  ret:updateCasterName()
  
  ret.updateCooldownText = function(self, s)
    if type(s) == "number" then
      if s >= 60 then
        local m = math.floor(s / 60)
        s = s - 60 * m
        self.cdText:SetText(string.format("%d:%02d", m, s))
      else
        self.cdText:SetText(s)
      end
    else
      self.cdText:SetText(s)
    end
  end
  
  ret.updateAlpha = function(self)
    if (self.charges == 0) or self.isDead then
      self:SetAlpha(0.6)
    else
      self:SetAlpha(1)
    end
  end
  ret:updateAlpha()
  
  ret.NoOp = function() end
  ret.RealOnUpdate = function(self, elapsed)
    self.tslU = self.tslU + elapsed
    while self.tslU >= 1 do
    
      if self.isOnCD then
        self.durLeft = self.durLeft - 1
        --self.cdText:SetText(self.durLeft)
        self:updateCooldownText(self.durLeft)
        
        if self.durLeft <= 0 then
          self.charges = min(self.charges + 1, self.maxCharges)
          if self.charges == self.maxCharges then
            --self.tslU = -1
            self.durLeft = -1
            --self.cdText:SetText("")
            self:updateCooldownText("")
            self.isOnCD = false
            
            if not self.isDead then
              self.tslU = -1
              self.OnUpdate = self.NoOp
            end
          else
            --self.tslU = self.tslU - 1
            self.durLeft = self.cd
            --self.cdText:SetText(self.durLeft)
            self:updateCooldownText(self.durLeft)
          end
          
          self:updateAlpha()
          
          self:updateCasterName()
        end
      end
      
      if self.isDead then
        local lku = LGIST:GuidToUnit(self.casterGUID)
        self.isDead = lku and UnitIsDeadOrGhost(lku) or false
        
        if not self.isDead then
          self:updateAlpha()
          
          if not self.isOnCD then
            self.tslU = -1
            self.OnUpdate = self.NoOp
          end
        end
      end
      
      self.tslU = self.tslU - 1
    end
  end
  if ret.isDead or ret.isOnCD then
    ret.tslU = 0
    ret.OnUpdate = ret.RealOnUpdate
  else
    ret.OnUpdate = ret.NoOp
  end
  ret:SetScript("OnUpdate", function(self, elapsed)
    self.OnUpdate(self, elapsed)
  end);
  
  return ret
end

frame.addCasterBarToSpell = function(self, casterBar, spellID)
  local subFrame = self.subFrames[spellID]
  if not subFrame then return end
  
  table.insert(subFrame.casterBars, casterBar)
  local c = RAID_CLASS_COLORS[subFrame.class or "PRIEST"]
  casterBar.casterText:SetTextColor(c.r, c.g, c.b, 1)
  casterBar.cdText:SetTextColor(c.r, c.g, c.b, 1)
  
  subFrame.headerText:Show()
  subFrame:SetHeight((#subFrame.casterBars)*12 + 12)
  casterBar:SetPoint("TOPLEFT", subFrame, "TOPLEFT", 0, -12*(#subFrame.casterBars))
end
frame.removeCasterBarsFromSpell = function(self, casterGUID, spellID)
  local subFrame = self.subFrames[spellID]
  if not subFrame then return end
  
  local numBars = #subFrame.casterBars
  local casterBar
  for i = numBars, 1, -1 do
    if subFrame.casterBars[i].casterGUID == casterGUID then
      local casterBar = table.remove(subFrame.casterBars, i) --pop last element
      casterBar:Hide()
      table.insert(self.inactiveSpells, casterBar)
    end
  end
  numBars = #subFrame.casterBars
  subFrame:SetHeight(numBars*12 + 12)
  for i, v in ipairs(subFrame.casterBars) do
    v:SetPoint("TOPLEFT", subFrame, "TOPLEFT", 0, -12*i)
  end
end
frame.removeCasterBars = function(self, casterGUID)
  for k, _ in pairs(self.subFrames) do
    self:removeCasterBarsFromSpell(casterGUID, k)
  end
  self:updateSubFrameVisibility()
end
frame.updateSubFrameVisibility = function(self)
  for _, subFrame in pairs(self.subFrames) do
    if #subFrame.casterBars == 0 then
      subFrame.headerText:Hide()
      subFrame:SetHeight(0.001)
    end
  end
end
frame.startCD = function(self, casterGUID, spellID)
  local subFrame = self.subFrames[spellID]
  if not subFrame then return end
  
  for _, v in ipairs(subFrame.casterBars) do
    if v.casterGUID == casterGUID then
      v.isOnCD = true
      --only update if not already on cooldown
      if v.charges >= v.maxCharges then
        v.durLeft = v.cd --subFrame.cd
        --v.cdText:SetText(v.cd)
        v:updateCooldownText(v.cd)
        v.tslU = 0
        v.OnUpdate = v.RealOnUpdate
      end
      v.charges = max(v.charges - 1, 0)
      v:updateCasterName()
      v:updateAlpha()
    end
  end
end
frame.startIsDead = function(self, casterGUID)
  for k, subFrame in pairs(self.subFrames) do
    for _, v in ipairs(subFrame.casterBars) do
      if v.casterGUID == casterGUID then
        --only update if not already on cooldown
        if not (v.isDead or v.isOnCD) then
          v.isDead = true
          
          v.tslU = 0
          v.OnUpdate = v.RealOnUpdate
        else
          v.isDead = true
        end
        v:updateAlpha()
      end
    end
  end
end
frame.resetAfterWipe = function(self)
  for _, subFrame in pairs(self.subFrames) do
    if subFrame.resetAfterWipe then
      for _, casterBar in ipairs(subFrame.casterBars) do
        if (casterBar.durLeft > 0) or (casterBar.charges < casterBar.maxCharges) then
          casterBar.durLeft = 0
          casterBar.charges = casterBar.maxCharges
        end
      end
    end
  end
end

function frame:UpdateHandler(event, guid, unit, info)
  self:removeCasterBars(guid)
  
  if not info.class then return end
  
  if TankCDsOptions["hideSelf"] and (guid == myGUID) then return end
  
  local isDead = info.lku and UnitIsDeadOrGhost(info.lku) or false
  
  for k, v in pairs(spellIDs) do
    if v.class == info.class then
      --if (not v.spec) or (info.spec_index == v.spec) then
      --example:
      --spec = {[2]=1, [3]=1} (specs 2 and 3 are "1", and spec 1 is "nil", so only specs 2 and 3 apply)
      if (not v.spec) or (v.spec[info.spec_index]) then
        --(no talent info) OR (talent info, talent learned) OR (nottalent info, no talents leared OR not learned this talent)
        if ((not v.talent) and (not v.nottalent)) or (v.talent and next(info.talents) and info.talents[v.talent]) or (v.nottalent and ((not next(info.talents)) or (info.talents[v.nottalent] == nil))) then
          --charges = {{count = 2, talent = 17593}, {count = 1}} or {{count = 1}} or nil
          local charges = 1
          if v.charges then
            for _, v2 in ipairs(v.charges) do
              if (v2.talent and next(info.talents) and info.talents[v2.talent]) or (not v2.talent) then
                charges = v2.count or 1
                break
              end
            end
          end
          --cd = 10 or {{amount = 90, spec = 3}, {amount = 120}}
          local cd
          if type(v.cd) == "number" then
            cd = v.cd
          else
            --{{amount = 90, spec = 3}, {amount = 50, talent = 12345}, {amount = 120}}
            for _, v2 in ipairs(v.cd) do
              if ((v2.spec and info.spec_index == v2.spec) or (not v2.spec)) and ((v2.talent and next(info.talents) and info.talents[v2.talent]) or (not v2.talent)) then
                cd = v2.amount or 0
                break
              end
            end
          end
          
          local b = self:getNewCasterBar(info.name or UnitName(info.lku), guid, charges, cd, isDead)
          self:addCasterBarToSpell(b, k)
        end
      end
    end
  end
end
function frame:RemoveHandler(event, guid)
  -- guid no longer a group member
  self:removeCasterBars(guid)
end

function frameEvents:PLAYER_ENTERING_WORLD(...)
  frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  
  if not TankCDsOptions then
    TankCDsOptions = DefaultO
  end
  TankCDs_UpdateOptionsArray()
  initFrame()
  
  if TankCDsOptions["hidden"] then
    frame:SetAlpha(0)
  else
    frame:SetAlpha(1)
  end
  myGUID = UnitGUID("player")
  
  LGIST.RegisterCallback(frame, "GroupInSpecT_Update", "UpdateHandler")
  LGIST.RegisterCallback(frame, "GroupInSpecT_Remove", "RemoveHandler")
  
  frame:RegisterEvent("ENCOUNTER_END")
  frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end
--[[
PARTY_MEMBER_DISABLE
local function CLEU(_, _, eventType, _, _, _, _, dstName)
    if eventType ~= "UNIT_DIED" or (GetNumRaidMembers() == 0) then return end
    if UnitInRaid(dstName) and (not UnitInParty(dstName)) and UnitHealth(dstName) <= 1 then
        print(ClassColor[select(2,UnitClass(dstName))] .. dstName .. "|r |cffffff00has died.|r")
    end
end
--UNIT_DIED
--SPELL_RESURRECT
--http://www.wowinterface.com/forums/showthread.php?t=50020
--UnitIsDead(unitid)
--]]
function frameEvents:COMBAT_LOG_EVENT_UNFILTERED(...)
  local timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2 = select(1, ...)
  if event == "SPELL_CAST_SUCCESS" then
    local spellId, spellName, spellSchool = select(12, ...) --from prefix SPELL
    if spellIDs[spellId] then
      self:startCD(sourceGUID, spellId)
    end
  elseif event == "UNIT_DIED" then
    --don't call this for every mob, just for raid members
    if LGIST:GetCachedInfo(destGUID) then
      self:startIsDead(destGUID)
    end
  end
end
function frameEvents:ENCOUNTER_END()
  self:resetAfterWipe()
end
frame:SetScript("OnEvent", function(self, event, ...)
  frameEvents[event](self, ...)
end);
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local function mysplit(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  local i = 1
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    t[i] = str
    i = i + 1
  end
  return t
end

SLASH_TANKCDS1 = "/tankcds"
SlashCmdList["TANKCDS"] = function(msg, editbox)
  msg = msg or ""
  args = mysplit(msg, " ")
  
  if string.lower(args[1] or "") == "move" then
    if moving then
      moving = false
      frame:SetMovable(false) --click-through
      frame:EnableMouse(false)
      frame:RegisterForDrag("")
      frame.bgtexture:Hide()
    else
      moving = true
      frame:SetMovable(true);
      frame:EnableMouse(true);
      frame:RegisterForDrag("LeftButton");
      frame.bgtexture:Show()
    end
    print("|cffaaaaffTankCDs |rmove |cffaaaaffis now "..(moving == true and "|cffaaffaamoving" or "|cffff8888fixed"))
  elseif string.lower(args[1] or "") == "reset" then
    TankCDsOptions["framePoint"] = DefaultO["framePoint"]
    TankCDsOptions["frameRelativeTo"] = DefaultO["frameRelativeTo"]
    TankCDsOptions["frameRelativePoint"] = DefaultO["frameRelativePoint"]
    TankCDsOptions["frameOffsetX"] = DefaultO["frameOffsetX"]
    TankCDsOptions["frameOffsetY"] = DefaultO["frameOffsetY"]
    
    frame:ClearAllPoints()
    frame:SetPoint(TankCDsOptions["framePoint"], TankCDsOptions["frameRelativeTo"], TankCDsOptions["frameRelativePoint"], TankCDsOptions["frameOffsetX"], TankCDsOptions["frameOffsetY"])
    
    print("|cffaaaaffTankCDs |rposition reset")
  elseif string.lower(args[1] or "") == "update" then
    LGIST:Rescan()
  elseif string.lower(args[1] or "") == "toggle" then
    TankCDsOptions["hidden"] = not(TankCDsOptions["hidden"] and true or false)
    if TankCDsOptions["hidden"] then
      frame:SetAlpha(0)
    else
      frame:SetAlpha(1)
    end
    print("|cffaaaaffTankCDs is now "..(TankCDsOptions["hidden"] and "|cffff8888hidden" or "|cffaaffaashown"))
  elseif string.lower(args[1] or "") == "hideself" then
    TankCDsOptions["hideSelf"] = not(TankCDsOptions["hideSelf"] and true or false)
    LGIST:Rescan(myGUID) --remove [and add again]
    print("|cffaaaaffTankCDs is now "..(TankCDsOptions["hideSelf"] and "|cffff8888hiding" or "|cffaaffaashowing").." |cffaaaaffyour own CDs.")
  else
    print("|cffaaaaffTankCDs "..(GetAddOnMetadata("TankCDs", "Version") or ""))
    print("|cffaaaaff  use |r/tankcds <option> |cffaaaaffto toggle one of these options:")
    print("  move |cffaaaafftoggle moving the frame ("..(moving == true and "|cffaaffaamoving" or "|cffff8888fixed").."|cffaaaaff)")
    print("  reset |cffaaaaffreset the frame's position")
    print("  toggle |cffaaaaffshow/hide the frame ("..(TankCDsOptions["hidden"] and "|cffff8888hidden" or "|cffaaffaashown").."|cffaaaaff)")
    print("  hideself |cffaaaaffshow/hide own CDs ("..(TankCDsOptions["hideSelf"] and "|cffff8888hidden" or "|cffaaffaashown").."|cffaaaaff)")
  end
end
