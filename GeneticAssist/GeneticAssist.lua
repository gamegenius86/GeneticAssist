-----------------------------------------------------------------------------------------------
-- GeneticAssist
-- slash command to turn the addon on/off: /ga
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "GroupLib"
require "ICCommLib"

-----------------------------------------------------------------------------------------------
-- Performance Boost: Redefine global functions locally
-----------------------------------------------------------------------------------------------

local GameLib    = GameLib
local ICCommLib  = ICCommLib
local Apollo     = Apollo
local Vector3    = Vector3
local pairs      = pairs
local math       = math
local table      = table
local Print      = Print

local GeminiDB   = Apollo.GetPackage("Gemini:DB-1.0").tPackage

local Encounters = GeneticAssistConfig.Encounters
local Util       = GeneticAssistUtil

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------

local GeneticAssist = {
	callbacks = {}
}

function GeneticAssist:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function GeneticAssist:Init()
  Apollo.RegisterAddon(self, false, '', {})
end

function GeneticAssist:OnLoad()
	Apollo.RegisterSlashCommand("ga", "SlashCommand", self)
	Apollo.LoadSprites("GeneticAssistSprites.xml")
  self.xmlDoc = XmlDoc.CreateFromFile("GeneticAssist.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	self.db = GeminiDB:New(self, tDefaults)
	self.iUnits = {}
end

function GeneticAssist:OnDocumentReady()
	self.gameOverlay = Apollo.LoadForm(self.xmlDoc, "GameOverlay",'InWorldHudStratum', self)

	-- Unit Monitoring
	Apollo.RegisterEventHandler("UnitCreated",          "OnUnitCreated",         self) -- Unit Created
	Apollo.RegisterEventHandler("UnitDestroyed",        "OnUnitDestroyed",       self) -- Unit Destroyed

 --  -- Group Monitoring
	-- Apollo.RegisterEventHandler("Group_Join",           "OnGroupJoin",           self) -- I Joined a Group
	-- Apollo.RegisterEventHandler("Group_Left",           "OnGroupLeft",           self) -- I Left a Group
	-- Apollo.RegisterEventHandler("Group_Add",            "OnGroupAdd",            self) -- A Group Member was Added
	-- Apollo.RegisterEventHandler("Group_Remove",         "OnGroupRemove",         self) -- A Group Member was Removed / Left
	-- Apollo.RegisterEventHandler("Group_MemberPromoted", "OnGroupMemberPromoted", self) -- Group Leader Change

 --  if GroupLib.InRaid() or GroupLib.InGroup() then
 --  	self:OnGroupJoin()
 --  end
end

function GeneticAssist:SlashCommand()
end

-----------------------------------------------------------------------------------------------
-- Events: Unit Management
-----------------------------------------------------------------------------------------------

function GeneticAssist:OnUnitDestroyed(tUnit)
	if not tUnit then return; end

	local unitid = tUnit:GetId()
	if self.iUnits[unitid] then
		Print("UnitDestroyed: ("..unitid..") "..tUnit:GetName())

		self:DestroyUnit(self.iUnits[unitid])
		self.iUnits[unitid] = nil

		if Util:TableLength(self.iUnits) == 0 then
			Apollo.RemoveEventHandler("NextFrame", self)
		end
	end
end

function GeneticAssist:OnUnitCreated(tUnit)
	if not tUnit then return; end
	local unitname = tUnit:GetName()
	local config   = Encounters[unitname]
	if config then
		local unitid = tUnit:GetId()
		if not self.iUnits[unitid] then
			Print("UnitCreated: ("..unitid..") "..unitname)
			self.iUnits[unitid] = { ['unit'] = tUnit, ['id'] = unitid, ['name'] = unitname, ['config'] = config }

			self:CreateUnit(self.iUnits[unitid])

			-- If this is the first unit that we're watching, then lets go ahead and begin updating
			if Util:TableLength(self.iUnits) == 1 then
				Apollo.RegisterEventHandler("NextFrame", "OnUpdate", self)
			end
		end
	end
end

function GeneticAssist:OnUpdate()
	if not self.iUnits then return end

	for _, unit in pairs(self.iUnits) do
		local config = unit['config']

		-- if false it means that the unit doesn't exist anymore, but we're not destroying the infomartion
		if config['exists'] ~= false then
			if unit['unit']:IsInCombat() or config['SkipCombatCheck'] == true then
				self:UpdateUnit(unit)
			else
				self:DestroyUnit(unit)
			end
		end
	end
end


-----------------------------------------------------------------------------------------------
-- Events: Group Management
-----------------------------------------------------------------------------------------------

-- -- You've joined a group
-- function GeneticAssist:OnGroupJoin()
-- 	Print("You Joined Group")
-- 	self.groupMembers = {}
-- 	self:UpdateGroup()
-- end

-- -- You've left a group
-- function GeneticAssist:OnGroupLeft()
-- 	Print("You Left Group")
--   self.channelName = nil
--   self.channel = nil
--   self.groupMembers = {}
-- end

-- -- A member has joined your group
-- function GeneticAssist:OnGroupAdd(strMemberName)
-- 	Print("Member Joined Group: "..strMemberName)
-- 	self:UpdateGroup()
-- end

-- -- A member has left your group
-- function GeneticAssist:OnGroupRemove(strMemberName, eReason)
-- 	Print("Member Left Group: "..strMemberName)
--   if eReason == GroupLib.RemoveReason.Disband then return; end
-- 	table.remove(self.groupMembers, GetTableIndex(self.groupMembers, strMemberName))
-- end

-- -- A member has been promoted to party leader
-- function GeneticAssist:OnGroupMemberPromoted(strMemberName)
-- 	self.groupLeader = strMemberName
-- 	self.channelName = tostring(self.groupLeader .. "_GAA_Channel")
-- 	self.channel = ICCommLib.JoinChannel(self.channelName, "OnChanMessage", self)
-- 	Print("Joined Channel: "..self.channelName)
-- end

-- function GeneticAssist:UpdateGroup()
-- 	Print("Group Update")
-- 	for i = 1, GroupLib.GetMemberCount(), 1 do
--     local tGroupMember = GroupLib.GetGroupMember(i)
--     if tGroupMember.bIsLeader then
--     	self:OnGroupMemberPromoted(tGroupMember.strCharacterName)
--     end
-- 		self.groupMembers[tGroupMember.strCharacterName] = tGroupMember
--   end
-- end

-----------------------------------------------------------------------------------------------
-- Functions: Unit Management
-----------------------------------------------------------------------------------------------

function GeneticAssist:CreateUnit(unit)
	local config = unit['config']

	if self.callbacks[unit['name']] and self.callbacks[unit['name']]['OnCreate'] then
		self.callbacks[unit['name']]['OnCreate'](unit)
	end

	if config['Line'] then
		unit['Line'] = GeneticAssistLine.new(self.gameOverlay, 'solid', config['Line']['Color'], config['Line']['Thickness'], true);
	end

	if config['Circle'] then
		unit['Circle'] = GeneticAssistCircle.new(self.gameOverlay, config['Circle']['Resolution'], config['Circle']['Thickness'], config['Circle']['Color'], config['Circle']['Height'], config['Circle']['Outline']);
	end

	if config['Marker'] then
		unit['Marker'] = GeneticAssistMarker.new(self.gameOverlay, config['Marker']['Sprite'], config['Marker']['Color'], config['Marker']['Width'], config['Marker']['Height'], true);
	end

	if config['Notification'] then
		unit['Notification'] = GeneticAssistNotification.new(self.gameOverlay, config['Notification'], nil, true);
	end

	if config['DeBuff'] then
		unit['DeBuff'] = {}
		for buffname, sprite in pairs(config['DeBuff']) do
			unit['DeBuff'][buffname] = GeneticAssistNotification.new(self.gameOverlay, sprite)
		end
	end

	if config['Buff'] then
		unit['Buff'] = {}
		for buffname, sprite in pairs(config['Buff']) do unit['Buff'][buffname] = GeneticAssistNotification.new(self.gameOverlay, sprite) end
	end

	if config['Cast'] then
		unit['Cast'] = {}
		for spellname, sprite in pairs(config['Cast']) do unit['Cast'][spellname] = GeneticAssistNotification.new(self.gameOverlay, sprite) end
	end
end


function GeneticAssist:DestroyUnit(unit)
	local config = unit['config']

	if self.callbacks[unit['name']] and self.callbacks[unit['name']]['OnDestroy'] then
		self.callbacks[unit['name']]['OnDestroy'](unit)
	end

	if config['Line'] and unit['Line'] then
		unit['Line']:Destroy()
	end

	if config['Circle'] and unit['Circle'] then
		unit['Circle']:Destroy()
	end

	if config['Marker'] and unit['Marker'] then
		unit['Marker']:Destroy()
	end

	if config['Notification'] and unit['Notification'] then
		unit['Notification']:Destroy()
	end

	if config['DeBuff'] then
		for buffname, _ in pairs(config['DeBuff']) do
			if unit['DeBuff'][buffname] then
				unit['DeBuff'][buffname]:Destroy()
			end
		end
		unit['DeBuff'] = {}
	end

	if config['Buff'] then
		for buffname, _ in pairs(config['Buff']) do
			if unit['Buff'][buffname] then
				unit['Buff'][buffname]:Destroy()
			end
		end
		unit['Buff'] = {}
	end

	if config['Cast'] then
		for spellname, _ in pairs(config['Cast']) do
			if unit['Cast'][spellname] then
				unit['Cast'][spellname]:Destroy()
			end
		end
		unit['Cast'] = {}
	end
end

-- function GeneticAssist:HideUnit(unit)
-- 	local config = unit['config']

-- 	if self.callbacks[unit['name']] and self.callbacks[unit['name']]['OnHide'] then
-- 		delete = self.callbacks[unit['name']]['OnHide'](unit)
-- 	end

-- 	if config['Line'] and unit['Line'] then
-- 		unit['Line']:Hide();
-- 	end

-- 	if config['Circle'] and unit['Circle'] then
-- 		unit['Circle']:Hide();
-- 	end

-- 	if config['Marker'] and unit['Marker'] then
-- 		unit['Marker']:Hide();
-- 	end

-- 	if config['Notification'] and unit['Notification'] then
-- 		unit['Notification']:Hide();
-- 	end

-- 	if config['DeBuff'] then
-- 		for buffname, _ in pairs(config['DeBuff']) do
-- 			if unit['DeBuff'][buffname] then
-- 				unit['DeBuff'][buffname]:Hide()
-- 			end
-- 		end
-- 	end

-- 	if config['Buff'] then
-- 		for buffname, _ in pairs(config['Buff']) do
-- 			if unit['Buff'][buffname] then
-- 				unit['Buff'][buffname]:Hide()
-- 			end
-- 		end
-- 	end

-- 	if config['Cast'] then
-- 		for spellname, _ in pairs(config['Cast']) do
-- 			if unit['Cast'][spellname] then
-- 				unit['Cast'][spellname]:Hide()
-- 			end
-- 		end
-- 	end
-- end

function GeneticAssist:UpdateUnit(unit)
	local config = unit['config']

	if self.callbacks[unit['name']] and self.callbacks[unit['name']]['OnUpdate'] then
		self.callbacks[unit['name']]['OnUpdate'](unit)
	end

	if config['Line'] then
		unit['Line']:Show()
		unit['Line']:Draw(GameLib.GetPlayerUnit():GetPosition(), unit['unit']:GetPosition())
	end

	if config['Marker'] then
		unit['Marker']:Show()
		unit['Marker']:Draw(unit['unit']:GetPosition())
	end

	if config['Notification'] then
		unit['Notification']:Show()
	end

	if config['Circle'] then
		local tPos = unit['unit']:GetPosition()
		local tPosVector= Vector3.New(tPos.x, tPos.y, tPos.z) -- why?
		local tFacing = unit['unit']:GetFacing()
		local tAngle = math.atan2(tFacing.x, tFacing.z)
		unit['Circle']:Show()
		unit['Circle']:Draw(tPos, config['Circle']['Radius'], tAngle, config['Circle']['Color'])
	end

	if config['DeBuff'] then
		local debuffs = Util:GetBuffList(GameLib.GetPlayerUnit(), 'arHarmful')
		for buffname, _ in pairs(config['DeBuff']) do
			unit['DeBuff'][buffname]:Active(debuffs[buffname])
		end
	end

	if config['Buff'] then
		local buffs = Util:GetBuffList(GameLib.GetPlayerUnit(), 'arBeneficial')
		for buffname, _ in pairs(config['Buff']) do
			unit['Buff'][buffname]:Active(buffs[buffname])
		end
	end

	if config['Cast'] then
		-- Error!
		for spellname, _ in pairs(config['Cast']) do
			unit['Cast'][spellname]:Active(unit['unit']:ShouldShowCastBar() and unit['unit']:GetCastName() == spellname)
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Callbacks (used so encounters can bind to specific events)
-----------------------------------------------------------------------------------------------

function GeneticAssist:SetCallback(unitname, type, method)
	if not self.callbacks[unitname] then
		self.callbacks[unitname] = {}
	end

	self.callbacks[unitname][type] = method
end

-----------------------------------------------------------------------------------------------
-- Addon Communication
-----------------------------------------------------------------------------------------------

function GeneticAssist:OnChanMessage(channel, message)
  if self.channelName ~= channel then return; end

end

function GeneticAssist:SendMessage(mSender, mType, mBody)
  if not self.channel then return; end
  self.channel:SendMessage({ sender = mSender, type = mType, body = mBody })
end

-----------------------------------------------------------------------------------------------
-- Private Helper Methods
-----------------------------------------------------------------------------------------------

-- function GetTableIndex(tbl, value)
-- 	for i, v in ipairs(tbl) do
-- 		if v == value then
-- 			return i;
-- 		end
-- 	end
-- end
-----------------------------------------------------------------------------------------------
-- Addon Object Creation & Initialization
-----------------------------------------------------------------------------------------------

local GeneticAssistInstance = GeneticAssist:new()
GeneticAssistInstance:Init()

_G['GeneticAssist'] = GeneticAssistInstance