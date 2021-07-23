local _, Reminders = ...;

_G["Reminders"] = Reminders;

local addon = "Reminders";
local addonPrefix = "MTHDRMDRS_PR"
local addonPrefixPre = "MTHDRMDRS_PRE"
local addonPrefixPost = "MTHDRMDRS_PST"
-- bit of a hack, do not use $ or § in reminder messages, please, there is no escape sequence
local sep = "$"
local multilinesep = "§"
local numel = table.getn;
local VERSION = "1.7" -- Shadowlands
local versionRetTable = {}

local loaded = {}
local instances = nil
local phaseMap = nil
local timerMap = nil
local eventMap = nil
local activeEncounterReminders = nil -- active timers

local AceSerializer, AceComm
local Dialog = LibStub("LibDialog-1.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate")
local LibCompress = LibStub:GetLibrary("LibCompress")

local hack__max_engage_delay = 2

SLASH_METHODREMINDERS1 = "/rm";

local function strwssplit(str)
	rf = string.gmatch(str, "%S+")
	fragments = {}
	for i in rf do
		table.insert(fragments, i)
	end
	return fragments
end

function string.starts_with(str, start)
	return str:sub(1, #start) == start
end

function string.ends_with(str, ending)
	return ending == "" or str:sub(-#ending) == ending
end

local function rgbatohex(r, g, b, a)
	local function numtohex(num)
		num = num * 255
		return string.format('%02X', num)
	end
	return numtohex(r) .. numtohex(g) .. numtohex(b) .. numtohex(a)
	
end

local function hextorgba(hex)
	local function bytetonum(byte)
		return string.byte(string.char(tonumber(byte, 16))) / 255.0
	end
	return bytetonum(hex:sub(1, 2)), bytetonum(hex:sub(3, 4)), bytetonum(hex:sub(5, 6)), bytetonum(hex:sub(7, 8))
end

function Reminders.TEST_HEX_RGBA(r, g, b, a)
	hex = rgbatohex(r, g, b, a)
	print(hex)
	r, g, b, a = hextorgba(hex)
	print(r, g, b, a)
end

function keyset(table)
	local keyset={}
	local n=0

	for k,v in pairs(tab) do
		n=n+1
		keyset[n]=k
	end
	return keyset
end

function SlashCmdList.METHODREMINDERS(cmd, editbox)
	if cmd == "unlock" and Reminders.gui then
		Reminders.gui:UnlockMove()
	elseif cmd == "lock" and Reminders.gui then
		Reminders.gui:LockMove()
	elseif cmd == "" or cmd == "show" then
		Reminders:ShowInterface();
	else
		local cmdparse = strwssplit(cmd)
		if cmdparse[1] == "verscheck" then
			Reminders:VersionCheck()
			return
		end
		if cmdparse[1] == "i" or cmdparse[1] == "instance" then
			if numel(cmdparse) < 2 then print("Give more args") return end
			if cmdparse[2] == 'u' or cmdparse[2] == 'unload' then
				local _ = nil
				Reminders:ZoneChanged(function() return _, _, "Mythic", _, _, _, _, 0 end)
			end
			if cmdparse[2] == 'l' or cmdparse[2] == 'load' then
				if numel(cmdparse) < 3 then print("Give more args") return end
				local _ = nil
				Reminders:ZoneChanged(function() return _, _, "Mythic", _, _, _, _, tonumber(cmdparse[3]) end)
			end
		end
		if cmdparse[1] == 'e' or cmdparse[1] == 'encounter' then
			if numel(cmdparse) < 2 then print("Give more args") return end
			if cmdparse[2] == 'u' or cmdparse[2] == 'unload' then
				Reminders:EncounterEnd(Reminders.debug_encounter, Reminders.debug_encounter_name, 16, 20, false) -- 16 is MYTHIC
			end
			if cmdparse[2] == 'l' or cmdparse[2] == 'load' then
				if numel(cmdparse) < 3 then print("Give more args") return end
				Reminders.debug_encounter = tonumber(cmdparse[3])
				Reminders.debug_encounter_name = "Dummy"
				Reminders:EncounterStart(Reminders.debug_encounter, Reminders.debug_encounter_name, 16, 20)
			end
		end
	end
end

function Reminders.debug(...)
	if RemindersEnableDebug then
		print(...)
	end
end

do
	local event_frame = CreateFrame("frame", "ReminderManagerFrame", UIParent);
	Reminders.event_frame = event_frame;
	Reminders.eventMap = {}
	Reminders.phaseMap = {}
	Reminders.timerMap = {}
	Reminders.activeEncounterReminders = {}

	phaseMap = Reminders.phaseMap
	eventMap = Reminders.eventMap
	timerMap = Reminders.timerMap

	timerMap.texts = {}
	timerMap.spellids = {}

	activeEncounterReminders = Reminders.activeEncounterReminders
	
	event_frame:RegisterEvent("ADDON_LOADED");
	event_frame:RegisterEvent("PLAYER_LOGIN");
	event_frame:RegisterEvent("PLAYER_LOGOUT");
	event_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	event_frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	event_frame:RegisterEvent("ENCOUNTER_START");
	event_frame:RegisterEvent("ENCOUNTER_END");
	event_frame:RegisterEvent("CHAT_MSG_ADDON");
	event_frame:RegisterEvent("UNIT_HEALTH");
	event_frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT");
	
	event_frame:SetScript("OnEvent", function(self, ...)
		local event, loaded = ...;
		if event == "ADDON_LOADED" then
			if addon == loaded then
				Reminders:OnLoad();
			end
		else
			Reminders:OnEvent(...);
		end
	end)
	
	-- Show Frame
	event_frame:Hide();
end

local RegisterBigWigs, BigWigsResetLocals, savedPhase
do
	local registered = false
	savedPhase = 0

	-- New Messages
	function RegisterBigWigs()
		if registered then return end
		if (BigWigsLoader) and BigWigsLoader.RegisterMessage then

			Reminders.BigWigs_Stage = function(event, boss, stage)
				savedPhase = savedPhase or 0
				savedPhase = savedPhase + 1
				
				Reminders.bw_last_stage_call = GetTime();
				Reminders.bw_last_stage_call_args = { event, boss, stage };
				
				Reminders.debug("Reminders: Phasing into "..savedPhase)
				Reminders:BossPhased(savedPhase)
			end

			BigWigsLoader.RegisterMessage(Reminders, "BigWigs_SetStage", Reminders.BigWigs_Stage);
			BigWigsLoader.RegisterMessage(Reminders, "BigWigs_OnBossEngage", function(event, boss, difficulty)
				-- This triggers whenever BigWigs gets ECOUNTER_START, however, it's only sent after the boss
				-- received OnEngage. The timing trick is a disgusting hack.
				Reminders.bw_last_engage_call = GetTime();
				Reminders.bw_last_engage_id = boss.engageId;

				-- Reminders ENCOUNTER_START was not yet triggered (which means reminders were not loaded etc)
				if not Reminders.encounter_start_last_call or (Reminders.bw_last_engage_call - Reminders.encounter_start_last_call) > hack__max_engage_delay then
					-- Phase was sent (which is sent pre-pull)
					Reminders.bw_last_stage_call = Reminders.bw_last_stage_call or 0
					Reminders.bw_trigger_stage_manual = (Reminders.bw_last_engage_call - Reminders.bw_last_stage_call) < hack__max_engage_delay;
				else
					Reminders.bw_trigger_stage_manual = false
				end
			end);

			registered = true
		end
	end
	function BigWigsResetLocals()
		savedPhase = 0
	end
end

local function split(msg, sep)
	local ar = {}
	local index = 1
	for v in string.gmatch(msg, "([^"..sep.."]+)") do
		ar[index] = v
		index = index + 1
	end
	return ar
end

local function table_find(table, el)
	local ind = nil
	if not table then return nil end
	for k, v in pairs(table) do
		if v == el then
			return k
		end
	end
	return ind
end

function dump_table_chat(table, varname)
	_G["TESTVAR_"..varname] = table;
	UIParentLoadAddOn("Blizzard_DebugTools");
	DevTools_DumpCommand("TESTVAR_"..varname)
end

local function SendAddonMessageWrap(prefix, text, distribution, target, prio, callbackFn, callbackArg)
	--print("Sending message length", string.len(text))
	if ChatThrottleLib then
		ChatThrottleLib.MAX_CPS = 4000;
		ChatThrottleLib.BURST = 8000;
		ChatThrottleLib.MIN_FPS = 4;
	end
	AceComm:SendCommMessage(prefix, text, distribution, target, prio, callbackFn, callbackArg)
end

function Reminders:InitDB()
	local t = {};
	t.reminders = {}
	t.reminders.everywhere = {}
	t.reminders.everywhere.reminders = {}

	instances = Reminders.instances

	for k, v in pairs(instances) do
		local iname = v.name
		t.reminders[v.name] = {}
		t.reminders[v.name].reminders = {}
		for k, v in pairs(v.encounters) do
			t.reminders[iname][v.name] = {}
			t.reminders[iname][v.name].reminders = {}
		end
	end

	return t;
end

function Reminders:CheckForNewInstances()
	db = self.db
	for k, v in pairs(self.instances) do
		local iname = v.name
		if db.reminders[iname] == nil then
			db.reminders[iname] = {}
			db.reminders[iname].reminders = {}
			for k, v in pairs(v.encounters) do
				db.reminders[iname][v.name] = {}
				db.reminders[iname][v.name].reminders = {}
			end
		end
	end
end

function Reminders:DelayedOnLoad()

	self.instances = Reminders:PopulateInstances()
	self:CheckForNewInstances();

	RegisterBigWigs()

	-- load shared media
	LoadAddOn("LibSharedMedia-3.0");
	AceComm = AceComm or LibStub:GetLibrary("AceComm-3.0")

	instances = self.instances

	-- register any reminders that are always active
	if Reminders.db.reminders then
		for i = 1, #self.db.reminders.everywhere.reminders do
			self:RegisterReminder(self.db.reminders.everywhere.reminders[i]);
		end
	end
	-- register current zone reminders
	self:ZoneChanged()
	-- if gui exists
	if Reminders.gui then
		Reminders.gui:InitializeGUI(Reminders)
	end

	local success = AceComm:RegisterComm(addonPrefix, function(prefix, message, distribution, sender) self:OnMessageReceived(message, distribution, sender) end) --RegisterAddonMessagePrefix(addonPrefix)
	local success_pre = AceComm:RegisterComm(addonPrefixPre, function(prefix, message, distribution, sender) self:OnMessagePreReceived(message, distribution, sender) end)
	local success_post = AceComm:RegisterComm(addonPrefixPost, function(prefix, message, distribution, sender) self:OnMessagePostReceived(message, distribution, sender) end)
	if not success or not success_pre or not success_post then
		--print("REMINDERS ERROR - FAILED TO REGISTER MESSAGE PREFIX")
	end
	self:RegisterBigWigsTimer()
	self.init_finished = true
end

function Reminders:OnLoad()
	self.event_frame:UnregisterEvent("ADDON_LOADED");
	self.loaded = loaded
	self.instance_loaded = nil
	RemindersDB = RemindersDB or self:InitDB();
	Reminders.db = RemindersDB
	RemindersDB.misc_data = RemindersDB.misc_data or {}

	-- Seems like some functions are not actually available during addon onload event
	-- So delay sensitive init for 0.5 second afterwards. This will be called at earliest
	-- 1 full frame later, which should be enough.
	C_Timer.After(0.5, function() Reminders:DelayedOnLoad() end)
end

function Reminders:Purge()
	RemindersDB = self:InitDB();
end

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function Reminders:DuplicateReminder(reminder, new_name)
	local db = RemindersDB
	local clone = deepcopy(reminder)
	-- find new name
	clone.name = new_name
	table.insert(db.reminders[reminder.category][reminder.subcategory].reminders, clone)
end

function Reminders:RenameReminder(reminder, new_name)
	local db = RemindersDB
	local found = false
	local tab = nil
	local index = nil
	local category = reminder.category
	local subcategory = reminder.subcategory
	local name = reminder.name
	if category == "everywhere" or subcategory == "trash" then
		for i = 1, #self.db.reminders[category].reminders do 
			if not found and self.db.reminders[category].reminders[i].name == name then
				tab = self.db.reminders[category].reminders
				index = i
				found = true
			end
		end
	else
		Reminders.debug(category .. " " .. subcategory .. " " .. name)
		for i = 1, #self.db.reminders[category][subcategory].reminders do 
			if not found and self.db.reminders[category][subcategory].reminders[i].name == name then
				tab = self.db.reminders[category][subcategory].reminders
				index = i
				found = true
			end
		end
	end
	if not found then
		return
	end
	tab[index].name = new_name
end

function Reminders:DeleteReminder(category, subcategory, name)
	-- remove from db
	local found = false
	local tab = nil
	local index = nil
	if category == "everywhere" or subcategory == "trash" then
		for i = 1, #self.db.reminders[category].reminders do 
			if not found and self.db.reminders[category].reminders[i].name == name then
				tab = self.db.reminders[category].reminders
				index = i
				found = true
			end
		end
	else
		Reminders.debug(category .. " " .. subcategory .. " " .. name)
		for i = 1, #self.db.reminders[category][subcategory].reminders do 
			if not found and self.db.reminders[category][subcategory].reminders[i].name == name then
				tab = self.db.reminders[category][subcategory].reminders
				index = i
				found = true
			end
		end
	end

	if found then
		self:UnregisterReminder(tab[index])
		table.remove(tab, index)
	end

	if not found then
		Reminders.debug("Reminders - ERROR, CANNOT DELETE " .. name .. ", CONTACT AUTHOR");
	end
	
end

function Reminders:HideInterface()
	Reminders.Config.Hide();
end

function Reminders:ShowInterface()
	--print("Opening Config")
	Reminders.Config:Open();
end

function Reminders:CLEU(timestamp, event, ...)
	-- print(event, ...)
	if self.eventMap[event] then
		for i = 1, #self.eventMap[event] do
			local reminder = self.eventMap[event][i]
			if reminder.enabled then
				self:CheckReminder(event, reminder, ...)
			end
		end
	end
end

function Reminders:OnEvent(...)
	if not self.init_finished then return end
	
	local game_event = ...; --, timestamp, event = ...;
	if game_event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local payload = {CombatLogGetCurrentEventInfo()}
		-- print(unpack(payload))
		self:CLEU(unpack(payload))
	end
	if game_event == "UNIT_HEALTH" then
		local _, unit = ...;
		self:UnitHealth(unit)
	end
	if game_event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
		-- doesn't specify unit :))
		--local _, unit = ...;
		--self:UnitReset(unit)
	end
	-- check on login too btw (done in on load)
	if game_event == "ZONE_CHANGED_NEW_AREA" then
		self:ZoneChanged()
	end
	if game_event == "ENCOUNTER_START" then
		local _, id, name, diff, raidsize = ...;
		self:EncounterStart(id, name, diff, raidsize)
	end
	if game_event == "ENCOUNTER_END" then
		local _, id, name, diff, raidsize, kill = ...;
		self:EncounterEnd(id, name, diff, raidsize, kill)
	end
	if game_event == "CHAT_MSG_ADDON" then
		local _, prefix, msg, channel, source = ...;
		if prefix == addonPrefix then
			-- handled by acecomm
			-- self:OnMessageReceived(msg, channel, source)
		end
	end
end

-- doesn't seem to work really?
function Reminders:UnitReset(unit)
	local event = "UNIT_HEALTH"
	Reminders.debug(unit .. " changed")
	if self.eventMap[event] then
		for i = 1, #self.eventMap[event] do
			local reminder = self.eventMap[event][i]
			if reminder.enabled and reminder.trigger_opt.boss_hp_unit == unit then
				reminder.volatile.procced = false
			end
		end
	end
end

function Reminders:UnitHealth(unit)
	local event = "UNIT_HEALTH"
	if self.eventMap[event] then
		for i = 1, #self.eventMap[event] do
			local reminder = self.eventMap[event][i]
			if reminder.enabled and reminder.trigger_opt.boss_hp_unit == unit then
				reminder.volatile = reminder.volatile or {}
				if not reminder.volatile.procced then
					local pct = (UnitHealth(unit) / UnitHealthMax(unit)) * 100
					if reminder.trigger_opt.boss_hp_pct and pct <= reminder.trigger_opt.boss_hp_pct then
						self:FireReminder(reminder)
						reminder.volatile.procced = true
					end
				end
			end
		end
	end
end

function Reminders:EncounterStart(id, name, difficulty, raidsize)
	if not self.instance_loaded then
		Reminders.debug("Encounter", id, "started, but no instance is loaded.")
		return
	end
	self.encounter_loaded = name
	self:LoadEncounterReminders(id, difficulty)
	
	-- Currently this heavily depends on Reminders ENCOUNTER_START being called
	-- before BigWigs ENCOUNTER_START, but I'm not sure I can guarantee that!

	-- If BigWigs triggers first and sets SetStage, then I need to retrigger that
	-- after all reminders are loaded!
	BigWigsResetLocals()

	self.encounter_start_last_call = GetTime();
	
	self.active_encounter = id
	self.active_difficulty = difficulty
	
	-- manually call all encounter start reminders
	local event = "ENCOUNTER_START"
	if self.eventMap[event] then
		for i = 1, #self.eventMap[event] do
			local reminder = self.eventMap[event][i]
			if reminder.enabled then
				self:FireReminder(reminder)
			end
		end
	end

	if self.bw_trigger_stage_manual then
		Reminders.debug("Trigger Manual Phasing.")
		self.BigWigs_Stage(unpack(self.bw_last_stage_call_args))
		self.bw_trigger_stage_manual = false;
	end

end

function Reminders:EncounterEnd(id, name, difficulty, raidsize, kill)
	if not self.instance_loaded or not self.encounter_loaded then
		--print("Encounter", id, "ended, but no instance is loaded.")
		return
	end
	self.encounter_loaded = nil

	self.active_encounter = nil
	self.active_difficulty = nil
	self.active_phase = nil

	self.encounter_start_last_call = nil

	self:UnloadEncounterReminders(id, difficulty)
	BigWigsResetLocals()
	for k, v in pairs(activeEncounterReminders) do
		v:Cancel()
	end
	table.wipe(activeEncounterReminders)
end

function Reminders:ZoneChanged(api_call)
	if not api_call then
		api_call = GetInstanceInfo
	end
	local _, _, difficulty, _, _, _, _, new_id = api_call()
	if self.instance_loaded then
		self:UnloadInstanceReminders(self.instance_loaded)
		-- maybe unload all encounters to prevent some errors like hearthstoning etc
		Reminders.debug("Reminders - Unloading instance")
		self.instance_loaded = nil
	end

	for k, v in pairs(instances) do
		if v.instance_id == new_id then
			-- Key is now instance zone id
			self.instance_loaded = new_id
			Reminders.debug("Reminders - Loading instance")
			self:LoadInstanceReminders(k)
		end
	end
end

function Reminders:GetRemindersForInstance(key_name) -- exact instance name
	local instance = instances[key_name].name
	return self.db.reminders[instance].reminders
end

function Reminders:GetRemindersForEncounter(instance_key_name, encounter_id)
	for k, v in pairs(self.instances[instance_key_name].encounters) do
		-- find the right encounter (TODO: can be done by indexing)
		if v.engage_id == encounter_id then
			local instance = instances[instance_key_name].name
			Reminders.debug("Found", #self.db.reminders[instance][v.name].reminders, "reminders..")
			return self.db.reminders[instance][v.name].reminders
		end
	end
	Reminders.debug("ENCOUNTER", encounter_id, "NOT FOUND!")
	return {}
end

function Reminders:LoadInstanceReminders(instance_name)
	Reminders.debug("Loading reminders for " .. instance_name)
	local reminders = self:GetRemindersForInstance(instance_name)
	for k, v in pairs(reminders) do
		self:RegisterReminder(v)
	end
end

function Reminders:UnloadInstanceReminders(instance_name)
	Reminders.debug("Unloading reminders for " .. instance_name)
	local reminders = self:GetRemindersForInstance(instance_name)
	for k, v in pairs(reminders) do
		self:UnregisterReminder(v)
	end
end

function Reminders:UnloadEncounterRemindersPhase(encounter_id, difficulty, phase)
	Reminders.debug("Unloading encounter reminders for " .. encounter_id .. ", phase " .. phase)
	if not self.instance_loaded then
		Reminders.debug("REMINDERS ERROR - ENDING AN ENCOUNTER, BUT NO INSTANCE IS LOADED.")
		return
	end
	local reminders = self:GetRemindersForEncounterPhase(self.instance_loaded, encounter_id, difficulty, phase)
	for k, v in pairs(reminders) do
		if v.trigger_opt.difficulty == "ANY" or difficulty == Reminders:DifficultyStringToId(v.trigger_opt.difficulty) then
			self:UnregisterReminder(v);
		end
	end
end

function Reminders:LoadEncounterRemindersPhase(encounter_id, difficulty, phase)
	Reminders.debug("Loading encounter reminders for " .. encounter_id .. ", phase " .. phase)
	local instance = instances[self.instance_loaded].name
	if not self.instance_loaded then
		Reminders.debug("REMINDERS ERROR - STARTING AN ENCOUNTER, BUT NO INSTANCE IS LOADED.")
		return
	end
	local reminders = self:GetRemindersForEncounterPhase(self.instance_loaded, encounter_id, difficulty, phase)
	for k, v in pairs(reminders) do
		-- check difficulty
		if v.trigger_opt.difficulty == "ANY" or difficulty == Reminders:DifficultyStringToId(v.trigger_opt.difficulty) then
			self:RegisterReminder(v);
		end
	end
end

function Reminders:GetRemindersForEncounterPhase(instance_key_name, encounter_id, difficulty, phase)
	local ret = {}
	for k, v in pairs(self.instances[instance_key_name].encounters) do
		-- find the right encounter (TODO: can be done by indexing)
		if v.engage_id == encounter_id then
			local instance = instances[instance_key_name].name
			for k2, v2 in pairs(self.db.reminders[instance][v.name].reminders) do
				if v2.trigger_opt.only_load_phase and v2.trigger_opt.only_load_phase_num == phase then
					table.insert(ret, v2);
				end
			end
		end
	end
	return ret
end

function Reminders:LoadEncounterReminders(encounter_id, difficulty)
	Reminders.debug("Loading encounter reminders for " .. encounter_id)
	local instance = instances[self.instance_loaded].name
	if not self.instance_loaded then
		Reminders.debug("REMINDERS ERROR - STARTING AN ENCOUNTER, BUT NO INSTANCE IS LOADED.")
		return
	end
	local reminders = self:GetRemindersForEncounter(self.instance_loaded, encounter_id)
	for k, v in pairs(reminders) do
		-- check difficulty
		if v.trigger_opt.difficulty == "ANY" or difficulty == Reminders:DifficultyStringToId(v.trigger_opt.difficulty) then
			-- dont load if there is specific phase set, that is handled separately
			if not v.trigger_opt.only_load_phase then
				self:RegisterReminder(v);
			end
		end
	end
end

function Reminders:UnloadEncounterReminders(encounter_id, difficulty)
	Reminders.debug("Unloading encounter reminders for " .. encounter_id)
	if not self.instance_loaded then
		Reminders.debug("REMINDERS ERROR - ENDING AN ENCOUNTER, BUT NO INSTANCE IS LOADED.")
		return
	end
	local reminders = self:GetRemindersForEncounter(self.instance_loaded, encounter_id)
	for k, v in pairs(reminders) do
		if v.trigger_opt.difficulty == "ANY" or difficulty == Reminders:DifficultyStringToId(v.trigger_opt.difficulty) then
			self:UnregisterReminder(v);
		end
	end
end

function Reminders:DifficultyStringToId(string)
	if string == "MYTHIC" then 
		return 16
	elseif string == "HEROIC" then 
		return 15
	else
		error(string .. " represents no known difficulty")
		return 1/0 -- error
	end
end

function Reminders:ReminderToString(reminder)
	return reminder.category .. "_" .. reminder.name
end

function Reminders:FireModuleEvent(event)
	-- This was here for possible submodules implementation, but was never needed.
end

function Reminders:RegisterReminder(reminder)
	Reminders.debug("Registering reminder, name=" .. reminder.name)
	if reminder.volatile then
		reminder.volatile = nil
	end
	if reminder.trigger == "event" then
		self:RegisterEventReminder(reminder)
	elseif reminder.trigger:starts_with("bw") then
		self:RegisterBWReminder(reminder)
	else
		Reminders.debug("Unknown trigger mechanism " .. reminder.trigger)
	end
end

function Reminders:UnregisterReminder(reminder)
	--print("Unregistering reminder, name=" .. reminder.name)
	if reminder.volatile then
		reminder.volatile = nil
	end
	if reminder.trigger == "event" then
		self:UnregisterEventReminder(reminder)
	elseif reminder.trigger:starts_with("bw") then
		self:UnregisterBWReminder(reminder)
	end
end

function Reminders:RegisterBWReminder(reminder)
	if reminder.trigger:ends_with("phase") and reminder.trigger_opt.bw_phase then
		local phase = reminder.trigger_opt.bw_phase
		phaseMap[phase] = phaseMap[phase] or {}
		phaseMap[phase][#phaseMap[phase] + 1] = reminder
	end
	if reminder.trigger:ends_with("timer") then
		if reminder.trigger_opt.bw_bar_check_text then
			Reminders.debug("Registering timer, text=" .. reminder.trigger_opt.bw_bar_text)
			timerMap.texts[reminder.trigger_opt.bw_bar_text] = timerMap.texts[reminder.trigger_opt.bw_bar_text] or {}
			table.insert(timerMap.texts[reminder.trigger_opt.bw_bar_text], reminder)
		elseif reminder.trigger_opt.bw_bar_check_spellid then
			timerMap.spellids[reminder.trigger_opt.bw_bar_spellid] = timerMap.texts[reminder.trigger_opt.bw_bar_spellid] or {}
			table.insert(timerMap.spellids[reminder.trigger_opt.bw_bar_spellid], reminder)
		end
	end
end

function Reminders:UnregisterBWReminder(reminder)
	if reminder.trigger:ends_with("phase") and reminder.trigger_opt.bw_phase then
		-- find it in phase map
		local ind = nil
		if not self.phaseMap[reminder.trigger_opt.bw_phase] then
			-- nothing to unregister
			return
		end
		for i = 1, #self.phaseMap[reminder.trigger_opt.bw_phase] do
			if self.phaseMap[reminder.trigger_opt.bw_phase][i] == reminder then
				ind = i
			end
		end
		table.remove(self.phaseMap[reminder.trigger_opt.bw_phase], ind)
	end
	if reminder.trigger:ends_with("timer") then
		if reminder.trigger_opt.bw_bar_check_text then
			local ind = table_find(timerMap.texts[reminder.trigger_opt.bw_bar_text], reminder)
			if ind then
				table.remove(timerMap.texts[reminder.trigger_opt.bw_bar_text], ind)
			end
		elseif reminder.trigger_opt.bw_bar_check_spellid then
			local ind = table_find(timerMap.spellids[reminder.trigger_opt.bw_bar_spellid], reminder)
			if ind then
				table.remove(timerMap.spellids[reminder.trigger_opt.bw_bar_spellid], ind)
			end
		end
	end
end

function Reminders:UnregisterEventReminder(reminder)
	local found = false
	local ind_remove = {}
	local table_remove = {}
	for k, v in pairs(self.eventMap) do
		for i = 1, #self.eventMap[k] do
			-- find all occurences (can have multiple triggers)
			if self.eventMap[k][i] and self.eventMap[k][i] == reminder then
				found = true; 
				table.insert(ind_remove, i); table.insert(table_remove, self.eventMap[k]);
				--print("Found the event to unregister.")
			end
		end
	end
	if found then
		for i = 1, #ind_remove do
			table.remove(table_remove[i], ind_remove[i])
		end
	else
		--print("Debug - reminder to unregister not found! (maybe it wasn't loaded?)")
	end
end

function Reminders:RegisterEventReminder(reminder)
	-- check if even is registered
	local event = reminder.trigger_opt.event
	if not self.eventMap[event] then
		--print("Registering for new event: " .. event)
		self.eventMap[event] = {}
		if event == "SPELL_AURA_APPLIED" and not self.eventMap["SPELL_AURA_REFRESH"] then
			self.eventMap["SPELL_AURA_REFRESH"] = {}
		end
	end
	table.insert(self.eventMap[event], reminder) -- fuck functions for now
	-- special case for spell aura refresh
	if event == "SPELL_AURA_APPLIED" and reminder.trigger_opt.include_aura_refresh then
		table.insert(self.eventMap["SPELL_AURA_REFRESH"], reminder)
	end
end

function Reminders:ReminderTriggerChanged(reminder, old_trigger)
	-- unregister reminder
	if old_trigger == "event" then
		self:UnregisterEventReminder(reminder)
	else
		self:UnregisterBWReminder(reminder)
	end
	-- register reminder again, if it should be loaded!
	if (self:ShouldLoad(reminder)) then
		self:RegisterReminder(reminder)
	end
end

function Reminders:ShouldLoad(reminder)
	if reminder.category == "everywhere" then
		return true
	end
	-- don't reload encounter stuff, probably a mistake anyway if done mid-pull
	if reminder.subcategory == "trash" and self.instance_loaded == reminder.category then
		return true
	end
	return false
end

function Reminders:BossPhased(phase)
	local instance = self.instance_loaded
	local encounter = self.encounter_loaded
	
	if not instance or not encounter then
		return
	end
	Reminders.debug(instance, encounter, "boss phased into", phase)

	if self.phaseMap then
		if self.phaseMap[phase] then
			for i = 1, #self.phaseMap[phase] do
				self:FireReminder(self.phaseMap[phase][i])
			end
		end
	end

	if self.active_phase then
		self:UnloadEncounterRemindersPhase(self.active_encounter, self.active_difficulty, self.active_phase)
	end
	self:LoadEncounterRemindersPhase(self.active_encounter, self.active_difficulty, phase)
	self.active_phase = phase
end

function Reminders:PurgeBossReminders(instance, encounter)
	if instance == 'everywhere' then
		RemindersDB.reminders[instance].reminders = {}
	else
		RemindersDB.reminders[instance][encounter].reminders = {}
	end
	if self.Config.redraw then
		self.Config.redraw()
		if self.Config:IsOpen() then
			self.Config:Open()
		end
	end
end

function Reminders:BWTimerStop(bar_info)
	--Reminders.debug("Timer", bar_info.text, "stopped")
end

function Reminders:FindActiveBarRemindersContainingText(bartext)
	local found = {}
	for text, reminder_list in pairs(timerMap.texts) do
		-- this is regex matching
		-- if string.match(bartext:lower(), text:lower()) then
		if string.find(bartext:lower(), text:lower(), nil, true) then
			for k, v in pairs(reminder_list) do table.insert(found, v) end
		end
	end
	return found
end

function Reminders:BWTimerStart(bar_info)
	--Reminders.debug("Timer", bar_info.text, bar_info.spellId, "started")
	if timerMap.texts then
		for k, v in pairs(self:FindActiveBarRemindersContainingText(bar_info.text)) do
			if v.trigger_opt.bw_bar_before == nil then v.trigger_opt.bw_bar_before = 0 end
			if (bar_info.duration - v.trigger_opt.bw_bar_before) < 0 then
				print(v.name, "Error: Requested reminder to fire", v.trigger_opt.bw_bar_before, "sec before timer, but timer is only", bar_info.duration, "long, ignoring..", bar_info.text)
			else
				C_Timer.After(bar_info.duration - v.trigger_opt.bw_bar_before, function() Reminders:ScheduledBWTimerCheck(bar_info, v) end)
			end
		end
	end
	if timerMap.spellids and timerMap.spellids[bar_info.spellId] then
		for k, v in pairs(timerMap.spellids[bar_info.spellId]) do
			if v.trigger_opt.bw_bar_before == nil then v.trigger_opt.bw_bar_before = 0 end
			if (bar_info.duration - v.trigger_opt.bw_bar_before) < 0 then
				print(v.name, "Error: Requested reminder to fire", v.trigger_opt.bw_bar_before, "sec before timer, but timer is only", bar_info.duration, "long, ignoring..", bar_info.spellId)
			else
				C_Timer.After(bar_info.duration - v.trigger_opt.bw_bar_before, function() Reminders:ScheduledBWTimerCheck(bar_info, v) end)
			end
		end
	end
end

function Reminders:ScheduledBWTimerCheck(bar_info, reminder)
	Reminders.debug("Checking if I should still trigger.")
	if Reminders:GetBigWigsTimerById(bar_info.text) == bar_info then
		Reminders:FireReminder(reminder)
	end
end

function Reminders:CheckReminder(event_triggered, reminder, ...)
	local _, _, sourceName, _, _, _, destName, _, _, spellId, spellName, _, _, stacksAmount = ...

	-- do some robustness things
	if sourceName then -- some spells also have no source (world buffs etc)
		sourceName = sourceName:lower() 
	end
	if destName then -- some spells clearly have no target (aoe etc)
		destName = destName:lower()
	end
	spellName = spellName:lower()

	-- event is already checked here
	local fire = true

	if reminder.trigger_opt.check_source then
		if reminder.trigger_opt.source_name:lower() ~= sourceName then
			fire = false
			return
		end
	end
	-- BUG: will check dest when trigger was changed (not an implementation issue though)
	if reminder.trigger_opt.check_dest then
		if reminder.trigger_opt.dest_name:lower() ~= destName then
			fire = false
			return
		end
	end
	if reminder.trigger_opt.check_name then
		if reminder.trigger_opt.name:lower() ~= spellName then
			fire = false
			return
		end
	end

	-- if spell dose
	if event_triggered == "SPELL_AURA_APPLIED_DOSE" then
		if reminder.trigger_opt.check_stacks then
			if reminder.trigger_opt.stacks_op == "==" then fire = (stacksAmount == reminder.trigger_opt.stacks_count) end
			if reminder.trigger_opt.stacks_op == ">=" then fire = (stacksAmount >= reminder.trigger_opt.stacks_count) end
			if reminder.trigger_opt.stacks_op == "<=" then fire = (stacksAmount <= reminder.trigger_opt.stacks_count) end
			if reminder.trigger_opt.stacks_op == ">" then fire = (stacksAmount > reminder.trigger_opt.stacks_count) end
			if reminder.trigger_opt.stacks_op == "<" then fire = (stacksAmount < reminder.trigger_opt.stacks_count) end
		end
	end

	if fire then
		self:FireReminder(reminder)
	end
end

-- handle delaying here
function Reminders:FireReminder(reminder)
	if not reminder.enabled then
		-- last chance to catch the disabled reminder
		return
	end
	
	-- check repeating
	reminder.volatile = reminder.volatile or {}
	reminder.volatile.count = reminder.volatile.count or -1
	-- first run = 0
	reminder.volatile.count = reminder.volatile.count + 1
	if reminder.repeats.setup == "only_first" and reminder.volatile.count > 0 then
		return
	end

	if reminder.repeats.setup == "specific" and reminder.repeats.number - 1 ~= reminder.volatile.count then
		--print(reminder.volatile.count)
		return
	end

	local offset = reminder.repeats.offset or 0
	local modulo = reminder.repeats.modulo or 1
	if modulo < 1 then modulo = 1 end
	if reminder.repeats.setup == "repeat_every" and (reminder.volatile.count < offset or mod(reminder.volatile.count - offset, modulo) ~= 0) then
		return
	end

	if reminder.delay and reminder.delay.delay_sec > 0 then
		Reminders.debug("Setting up delay of " .. tostring(reminder.delay.delay_sec))
		local timer = C_Timer.NewTimer(reminder.delay.delay_sec, function() self:FireReminderReal(reminder) end)
		table.insert(activeEncounterReminders, timer)
	else
		self:FireReminderReal(reminder)
	end
end

function Reminders.TrueUnitAura(unit, name)
	name = name:lower()
	for i = 1,40 do
		n = UnitBuff(unit, i)
		if not n then break end
		if (name == n:lower()) then return n end
	end
	for i = 1,40 do
		n = UnitDebuff(unit, i)
		if not n then break end 
		if (name == n:lower()) then return n end
	end
	return nil
end

local TrueUnitAura = Reminders.TrueUnitAura

-- check aura before sending if we should only send to people with an aura
function Reminders:FireReminderReal(reminder)
	Reminders.debug("|cff00ff00" .. "Fired Reminder " .. "'" .. reminder.name .. "'")
	if reminder.notification.check_for_aura then
		Reminders.debug("Checking for aura..", reminder.notification.aura_to_check)
	end
	if not Reminders.gui then
		Reminders.debug("Reminder " .. reminder.name .. " fired")
		-- return
	end
	-- check for sending
	if reminder.notification.who == "self" then
		if not reminder.notification.check_for_aura or TrueUnitAura('player', reminder.notification.aura_to_check) ~= nil then
			if Reminders.gui then
				Reminders.gui:ShowReminder(reminder)
			end
		end
	end
	if reminder.notification.who == "everyone" then
		-- send broadcast to raid
		-- Reminders.gui:ShowReminder(reminder) (done by receiving your own message)
		if not UnitInParty('player') then
			if not reminder.notification.check_for_aura or TrueUnitAura('player', reminder.notification.aura_to_check) ~= nil then
				Reminders.gui:ShowReminder(reminder)
			end
		elseif not UnitInRaid('player') then
			if not reminder.notification.check_for_aura then
				Reminders:SendAlert(reminder, 'PARTY')
			else
				for i = 1, 5 do
					if TrueUnitAura('party'..i, reminder.notification.aura_to_check) ~= nil then
						Reminders:SendAlert(reminder, "WHISPER", UnitName('party'..i))
					end
				end
				-- player doesn't come up in party..i
				if TrueUnitAura('player', reminder.notification.aura_to_check) ~= nil then
					Reminders:SendAlert(reminder, "WHISPER", UnitName('player'))
				end
			end
		else -- in raid
			if not reminder.notification.check_for_aura then
				Reminders:SendAlert(reminder, "RAID")
			else
				for i = 1, 40 do
					if TrueUnitAura('raid'..i, reminder.notification.aura_to_check) ~= nil then
						Reminders:SendAlert(reminder, "WHISPER", UnitName('raid'..i))
					end
				end
			end
		end
	end
	if reminder.notification.who == "specific" then
		local names = split(reminder.notification.specific_list:gsub("%s+", ""), ",")
		for k, v in pairs(names) do
			if not reminder.notification.check_for_aura or TrueUnitAura(v, reminder.notification.aura_to_check) ~= nil then
				Reminders:SendAlert(reminder, "WHISPER", v)
			end
		end
	end
	if reminder.notification.who == "echointernal" then

		if EchoInternal == nil then print("Reminders: EchoInternal not found."); return end
		for i = 1, 40 do

			local aura_check_ok = true;
			if reminder.notification.check_for_aura then
				if TrueUnitAura('raid'..i, reminder.notification.aura_to_check) == nil then
					-- continue to next
					aura_check_ok = false;
				end
			end
			
			if aura_check_ok then
				if reminder.notification.echointernal.melee and EchoInternal:IsMelee('raid'..i, false) then
					Reminders:SendAlert(reminder, "WHISPER", UnitName('raid'..i));
				end
				if reminder.notification.echointernal.ranged and EchoInternal:IsRanged('raid'..i, false) then
					Reminders:SendAlert(reminder, "WHISPER", UnitName('raid'..i));
				end
				if reminder.notification.echointernal.tanks and EchoInternal:IsTank('raid'..i) then
					Reminders:SendAlert(reminder, "WHISPER", UnitName('raid'..i));
				end
				if reminder.notification.echointernal.healers and EchoInternal:IsHealer('raid'..i) then
					Reminders:SendAlert(reminder, "WHISPER", UnitName('raid'..i));
				end
			end
		end
	end
end

function Reminders:OnMessagePreReceived(msg, channel, source)
	print("|cff00ff00Reminders|r: Receiving reminders from|cff0088ff", source, "|r- please wait until finished.");
end

function Reminders:OnMessagePostReceived(msg, channel, source)
	print("|cff00ff00Reminders|r: Reminders transfer to|cff0088ff", source, "|rcompleted.")
end

function Reminders:OnMessageReceived(msg, channel, source)
	--print(string.len(msg))
	local spl = split(msg, sep)
	if not spl or not spl[1] then
		Reminders.debug("Wrong message format")
		return
	end
	local sig = spl[1]
	if sig == "ALERT" then
		local reminder = {
			notification = {
				duration = tonumber(spl[4]),
				sound = spl[3],
				message = spl[2],
				color = {hextorgba(spl[5])}
			}
		}
		self:ReceiveAlert(reminder)
	elseif sig == "REMINDER" then
		local serialized = string.sub(msg, string.len("REMINDER") + string.len(sep) + 1)
		serialized = LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(serialized))
		if not serialized then print("ERROR DECODING REMINDERS") end
		self:ReceiveReminder(serialized)
		print("|cff00ff00Reminders|r: Reminders received successfully.")
	elseif sig == "REMINDER_WD" then
		local instance = spl[2]
		local boss = spl[3]
		local offset = string.len("REMINDER_WD") + string.len(instance) + string.len(boss) + 3 * string.len(sep) + 1
		local serialized = LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(string.sub(msg, offset)))
		if not serialized then print("ERROR DECODING REMINDERS") end
		self:PurgeBossReminders(instance, boss)
		self:ReceiveReminder(serialized)
		print("|cff00ff00Reminders|r: Reminders received successfully.")
		SendAddonMessageWrap(addonPrefixPost, "done", "WHISPER", source)
	elseif sig == "VERSCHECK" then
		local vers = "VERSCHECKRET" .. sep .. VERSION
		SendAddonMessageWrap(addonPrefix, vers, "WHISPER", source)
	elseif sig == "VERSCHECKRET" then
		local vers = spl[2]
		versionRetTable[source] = vers
	elseif sig == "CODE" then
		local code = spl[2]
		self:ExecuteCode(code)
	else
		Reminders.debug("Wrong message format")
	end

end

-- very dangerous, disable since the addon is public now
function Reminders:ExecuteCode(code)
	local runnable = "local function dummy_func_name_() " .. code .. "; end; dummy_func_name_()"
	-- RunScript(runnable)
end

function Reminders:VersCheckOutput()
	local rtrns = {}
	local nms = {}
	for k, v in pairs(versionRetTable) do 
		nms[#nms+1] = k
		rtrns[v] = rtrns[v] or {}
		rtrns[v][#rtrns[v]+1] = k
	end
	rtrns["Missing"] = {}
	for i = 1, 40 do
		if UnitName('raid'..i) and not table_find(nms, UnitName('raid'..i)) then
			rtrns["Missing"][#rtrns["Missing"]+1] = UnitName('raid'..i)
		end
	end
	local str = "Version check:\n"; 
	for k, v in pairs(rtrns) do
		local num = 0
		str = str .. tostring(k) .. ": "
		for l, n in pairs(v) do
			str = str .. tostring(n) .. ","
			num = num + 1
			if num > 4 then
				str = str .. "\n"
				num = 0
			end
		end
		str = str .. "\n"
	end 
	print(str)
	versionRetTable = {}
end

function Reminders:VersionCheck()
	print("Running version check of Reminders..")
	SendAddonMessageWrap(addonPrefix, "VERSCHECK", "RAID")
	-- allow some delay to get response
	C_Timer.After(1.5, function() Reminders:VersCheckOutput() end)
end

-- Now only used for exporting to string, otherwise reminders are deflated
function Reminders:SerializeReminder(reminder)
	AceSerializer = AceSerializer or LibStub:GetLibrary("AceSerializer-3.0")
	if not AceSerializer then
		print("AceSerializer is not installed")
		return
	end
	local serializedString = AceSerializer:Serialize(reminder)
	serializedString = "REMINDER" .. sep .. serializedString
	return serializedString
end

function Reminders:SendReminder(reminder, channel, ...)
	AceSerializer = AceSerializer or LibStub:GetLibrary("AceSerializer-3.0")
	if not AceSerializer then
		print("AceSerializer is not installed")
		return
	end
	local serializedString = AceSerializer:Serialize(reminder)
	serializedString = "REMINDER" .. sep .. LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(serializedString))

	SendAddonMessageWrap(addonPrefixPre, "dummy", channel, ...)
	SendAddonMessageWrap(addonPrefix, serializedString, channel, ...)
end

local function tab2str(t)
	local r = nil
	for k, v in pairs(t) do
		if r == nil then
			r = tostring(v)
		else
			r = r .. ", " .. tostring(v)
		end
	end
	return r
end

function Reminders:SendAllReminders(instance, boss, with_delete, channel, ...)
	local to_send = RemindersDB.reminders[instance][boss].reminders;
	print("|cff00ff00Reminders|r: Sending "..instance.. " - "..boss.." ("..tostring(#to_send) ..") reminders via "..channel.." (".. tab2str({ ... }) ..").");
	SendAddonMessageWrap(addonPrefixPre, "dummy", channel, ...)

	AceSerializer = AceSerializer or LibStub:GetLibrary("AceSerializer-3.0")
	if not AceSerializer then
		print("AceSerializer is not installed")
		return
	end

	local serializedString = ""
	if with_delete then
		serializedString = serializedString .. "REMINDER_WD" .. sep .. instance .. sep .. boss .. sep
	else
		serializedString = serializedString .. "REMINDER" .. sep
	end
	local first = true;
	local encode = "";
	for i = 1, #to_send do
		if not first then
			encode = encode .. multilinesep;
		end
		encode = encode .. AceSerializer:Serialize(to_send[i]);
		first = false;
	end
	serializedString = serializedString .. LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(encode));

	SendAddonMessageWrap(addonPrefix, serializedString, channel, ...)
end

function Reminders:SendReminderToTarget(reminder)
	local target = UnitName('target')
	if not target then 
		print("No target selected.")
		return
	end
	print("Sending reminder to " .. target)
	self:SendReminder(reminder, "WHISPER", target)
end

function Reminders:SendAllRemindersToTarget(instance, boss, with_delete)
	with_delete = with_delete or true
	local target = UnitName('target')
	if not target then 
		print("No target selected.")
		return
	end
	self:SendAllReminders(instance, boss, with_delete, "WHISPER", target)
end

function Reminders:SendAllRemindersToName(instance, boss, name, with_delete)
	with_delete = with_delete or true
	self:SendAllReminders(instance, boss, with_delete, "WHISPER", name)
end

function Reminders:SendReminderToName(reminder, name)
	self:SendReminder(reminder, "WHISPER", name)
end

function Reminders:SendAllRemindersToOneOfNamesInGuild(instance, boss, list_of_names, with_delete)
	with_delete = with_delete or true
	local num_guild_chars, online_max, _ = GetNumGuildMembers();
	for i = 1, num_guild_chars do
		local full_name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i);
		if online then
			local without_server = Ambiguate(full_name, "guild");
			for _, v in pairs(list_of_names) do
				if v == without_server then
					print("Reminders: Found|cff00ff00", v, "|r== sending all reminders for|cffffff00", boss, "|r")
					self:SendAllReminders(instance, boss, with_delete, "WHISPER", v);
					return
				end
			end
		end
	end
	print("Reminders: Name not found!")
end

function Reminders:FindCategoryForSubcategory(subcategory)
	for _, raid in pairs(self.instances) do
		for _, encounter in pairs(raid.encounters) do
			if encounter.name:lower() == subcategory:lower() then
				return raid.name, encounter.name
			end
		end
	end
	print("Encounter name of reminder import is wrong, raid for", subcategory, "not found.")
	return nil, nil
end

function Reminders:ReceiveReminderSingle(serialized, purge_category)
	AceSerializer = AceSerializer or LibStub:GetLibrary("AceSerializer-3.0")
	if not AceSerializer then
		print("AceSerializer is not installed")
		return
	end
	local success, reminder = AceSerializer:Deserialize(serialized)
	if not success then
		print(reminder)
		return
	end
	-- dump_table_chat(reminder, "RECEIVED_REMINDER")
	-- check if category needs to be autofilled
	if reminder.category == nil or reminder.category == "" then
		reminder.category, reminder.subcategory = self:FindCategoryForSubcategory(reminder.subcategory)
		if reminder.category == nil then return end
	end
	if purge_category then
		self:PurgeBossReminders(reminder.category, reminder.subcategory)
	end

	-- insert it into db
	self:AddReminder(reminder)
	-- load if necessary
	if self:ShouldLoad(reminder) then
		self:RegisterReminder(reminder)
	end
end

function Reminders:ReceiveReminder(serializedString, purge_category, redraw)
	-- split multiline for multiimport
	if string.find(serializedString, multilinesep) then
		local yield_counter = 0;
		local splits = split(serializedString, multilinesep)
		for k, spl in pairs(splits) do
			self:ReceiveReminderSingle(spl, purge_category, redraw)
			purge_category = false
			if coroutine.running() and (yield_counter % 10) == 0 then
				coroutine.yield();
			end
			yield_counter = yield_counter + 1;
		end
	else
		Reminders:ReceiveReminderSingle(serializedString, purge_category)
	end

	-- redraw config if it was loaded already
	if self.Config.redraw then
		self.Config.redraw()
		if self.Config:IsOpen() then
			self.Config:Open()
		end
	end
end

function Reminders:SendAlert(reminder, channel, target)
	if reminder.notification.send or target and target == UnitName('player') then
		if channel == "WHISPER" then
			Reminders.debug("Sending reminder to " .. target)
			SendAddonMessageWrap(addonPrefix, Reminders:ConstructAlertMessage(reminder, target), channel, target)
		else
			SendAddonMessageWrap(addonPrefix, Reminders:ConstructAlertMessage(reminder), channel)
		end
	end
end

function Reminders:ReceiveAlert(reminder)
	if Reminders.gui then
		Reminders.gui:ShowReminder(reminder)
	else
		print("Received reminder with message", reminder.notification.message, "but no gui is loaded.")
	end
end

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function trim_split(haystack, token, dotrim)
    token = token or ","
    dotrim = dotrim or true
    
    if token == "/" then
        token = "\\/"
    end
    
    local t = {}
    for word in string.gmatch(haystack, '([^' .. token .. ']+)') do
        if dotrim then
            table.insert(t, trim(word))
        else
            table.insert(t, word)
        end
    end 
    return t
end

local template_replace = {
	["star"] 		= "|T137001:0|t",
    ["orange"] 		= "|T137002:0|t",
    ["diamond"] 	= "|T137003:0|t",
    ["triangle"] 	= "|T137004:0|t",
    ["moon"] 		= "|T137005:0|t",
    ["square"] 		= "|T137006:0|t",
    ["cross"] 		= "|T137007:0|t",
    ["skull"] 		= "|T137008:0|t",
    
    -- Marker: Color
    ["yellow"] 	= "|T137001:0|t",
    ["orange"] 	= "|T137002:0|t",
    ["purple"] 	= "|T137003:0|t",
    ["green"] 	= "|T137004:0|t",
    ["white"] 	= "|T137005:0|t",
    ["blue"] 	= "|T137006:0|t",
    ["red"] 	= "|T137007:0|t",
    ["bone"] 	= "|T137008:0|t",
    
    -- Marker Index
    ["rt1"] = "|T137001:0|t",
    ["rt2"] = "|T137002:0|t",
    ["rt3"] = "|T137003:0|t",
    ["rt4"] = "|T137004:0|t",
    ["rt5"] = "|T137005:0|t",
    ["rt6"] = "|T137006:0|t",
    ["rt7"] = "|T137007:0|t",
    ["rt8"] = "|T137008:0|t",

    ["spell"] = function(placeholder, spellid)
        local name, _, icon = GetSpellInfo(spellid)
        if name and icon then
            return "|T" .. icon .. ":0|t " .. name
        end
        return placeholder
    end,
    
    ["spellicon"] = function(placeholder, spellid)
        local _, _, icon = GetSpellInfo(spellid)
        if icon then
            return "|T" .. icon .. ":0|t"
        end
        return ""
    end,
    
    ["spellname"] = function(placeholder, spellid)
        local name = GetSpellInfo(spellid)
        return name or ""
    end,

	["icon"] = function(placeholder, id)
		return "|T" .. id .. ":0|t"
	end,
};
do 
	template_replace.si = template_replace.spellicon
	template_replace.sn = template_replace.spellname
	template_replace.s = template_replace.spell
	template_replace.i = template_replace.icon

	-- DK
	template_replace["amz"]              = function(t) return template_replace.s(t, 51052) end
	template_replace["ams"]              = function(t) return template_replace.s(t, 48707) end

	-- Paladin
	template_replace["aura_mastery"]     = function(t) return template_replace.s(t, 31821) end
	template_replace["wings"]            = function(t) return template_replace.s(t, 31884) end
	template_replace["avenging_wrath"]   = function(t) return template_replace.s(t, 31884) end
	template_replace["ashen_hallow"]     = function(t) return template_replace.s(t, 316958) end
	template_replace["bubble"]           = function(t) return template_replace.s(t, 642) end

	-- Druid
	template_replace["tranquility"]      = function(t) return template_replace.s(t, 740) end
	template_replace["tranq"]            = function(t) return template_replace.s(t, 740) end
	template_replace["roar"]             = function(t) return template_replace.s(t, 106898) end
	template_replace["massroot"]         = function(t) return template_replace.s(t, 102359) end

	-- Hunter
	template_replace["turtle"]           = function(t) return template_replace.s(t, 186265) end

	-- Mage
	template_replace["iceblock"]         = function(t) return template_replace.s(t, 45438) end
	template_replace["ice block"]        = function(t) return template_replace.s(t, 45438) end
	template_replace["alter_time"]       = function(t) return template_replace.s(t, 108978) end
	
	-- Monk
	template_replace["revival"]          = function(t) return template_replace.s(t, 115310) end
	
	-- Priest
	template_replace["mass_dispel"]      = function(t) return template_replace.s(t, 32375) end
	template_replace["spirit_shell"]     = function(t) return template_replace.s(t, 109964) end
	template_replace["rapture"]          = function(t) return template_replace.s(t, 47536) end
	template_replace["barrier"]          = function(t) return template_replace.s(t, 62618) end
	template_replace["vampic_embrace"]   = function(t) return template_replace.s(t, 15286) end
	template_replace["ve"]               = function(t) return template_replace.s(t, 15286) end
	template_replace["divine hymn"]      = function(t) return template_replace.s(t, 64843) end
	template_replace["evang"]            = function(t) return template_replace.s(t, 246287) end
	template_replace["evangelism"]       = function(t) return template_replace.s(t, 246287) end
	template_replace["pain_supp"]        = function(t) return template_replace.s(t, 33206) end
	template_replace["pain_suppression"] = function(t) return template_replace.s(t, 33206) end

	-- Shaman
	template_replace["tide"]             = function(t) return template_replace.s(t, 108280) end
	template_replace["healing_tide"]     = function(t) return template_replace.s(t, 108280) end
	template_replace["link"]             = function(t) return template_replace.s(t, 98021) end
	template_replace["spirit_link"]      = function(t) return template_replace.s(t, 98021) end
	template_replace["windrush"]         = function(t) return template_replace.s(t, 192077) end
	template_replace["wind rush"]        = function(t) return template_replace.s(t, 192077) end

	-- Warlock
	template_replace["gate"]             = function(t) return template_replace.s(t, 111771) end

	-- Warrior
	template_replace["rally"]            = function(t) return template_replace.s(t, 97462) end
	template_replace["rallying_cry"]     = function(t) return template_replace.s(t, 97462) end

	-- DH
	template_replace["darkness"]         = function(t) return template_replace.s(t, 196718) end

	-- Lust
	template_replace["bloodlust"]        = function(t) return template_replace.s(t, 2825) end
	template_replace["lust"]             = function(t) return template_replace.s(t, 2825) end
	-- catch anything that doesn't comply
	setmetatable(template_replace, {["__index"] = function(t, idx) return tostring(idx) end})
end

function Reminders.EscapeReminderMessage(message)
    local template = true
    
    while template do
        template = message:match("^.*{([A-Za-z0-9-_:]+)}.*$")
        if template then
            local needle = "{" .. template .. "}"
            
            local id = 0
            if template:find(":") then
                local splitted = trim_split(template, ":")
                template = splitted[1]
                id = tonumber(splitted[2] or "0")
            end
            
            local replacer = template_replace[template:lower()]
            if type(replacer) == "function" then
                message = message:gsub(needle, replacer(template, id))
            else
                message = message:gsub(needle, replacer)
            end
        end
    end
	return message
end

function Reminders:ConstructAlertMessage(reminder, optional_target)
	local payload = reminder.notification.message
	if optional_target then
		-- kinda useless but maybe will find use
		payload = payload:gsub("%%n", optional_target)
	end
	payload = Reminders.EscapeReminderMessage(payload)
	local msg = "ALERT"
	msg = msg .. sep
	msg = msg .. payload
	msg = msg .. sep
	msg = msg .. tostring(reminder.notification.sound)
	msg = msg .. sep
	msg = msg .. tostring(reminder.notification.duration)
	msg = msg .. sep
	msg = msg .. rgbatohex(unpack(reminder.notification.color or {1.0, 1.0, 1.0, 1.0}))
	return msg
end

-- when received; should make the data name-indexable, but thats a TODO
function Reminders:AddReminder(reminder)
	local db = RemindersDB
	if reminder.category == "everywhere" then
		self:AddOrOverwrite(db.reminders[reminder.category].reminders, reminder)
	else
		if reminder.subcategory == "trash" then
			self:AddOrOverwrite(db.reminders[reminder.category].reminders, reminder)
		else
			self:AddOrOverwrite(db.reminders[reminder.category][reminder.subcategory].reminders, reminder)
		end
	end
end

function Reminders:AddOrOverwrite(table, reminder)
	local exists = false
	local index = nil
	for k, v in pairs(table) do
		if v and v.name == reminder.name then
			exists = true
			index = k
		end
	end
	if not exists then
		Reminders.debug("Adding a new reminder -", reminder.name, "(", reminder.subcategory, ")")
		table[#table + 1] = reminder
	else
		self:UnregisterReminder(table[index])
		Reminders.debug("Overwriting an existing reminder -", reminder.name, "(", reminder.subcategory, ")")
		table[index] = reminder
	end
end

function Reminders:ExportToString(reminder)
	local string = self:SerializeReminder(reminder)
	Dialog:Register("RemindersStringExport", {
		text = "Reminder String Export",
		width = 500,
		editboxes = {
			{ width = 484,
				on_escape_pressed = function(self, data) self:GetParent():Hide() end,
			},
		},
		on_show = function(self, data) 
			self.editboxes[1]:SetText(data.string)
			self.editboxes[1]:HighlightText()
			self.editboxes[1]:SetFocus()
		end,
		buttons = {
			{ text = CLOSE, },
		},	
		show_while_dead = true,
		hide_on_escape = true,
	})
	if Dialog:ActiveDialog("RemindersStringExport") then
		Dialog:Dismiss("RemindersStringExport")
	end
	Dialog:Spawn("RemindersStringExport", {string = string})
end

function Reminders:ExportAllBossReminders(instance, boss)
	local reminders = nil
	if instance == "everywhere" then
		reminders = RemindersDB.reminders[instance].reminders
	else
		reminders = RemindersDB.reminders[instance][boss].reminders
	end
	local string = ""
	for k, v in pairs(reminders) do
		if string == "" then
			string = string .. self:SerializeReminder(v)
		else
			string = string .. multilinesep .. self:SerializeReminder(v) -- .. "\n"
		end
	end
	Dialog:Register("RemindersStringExportAll", {
		text = "Reminder String Export",
		width = 500,
		editboxes = {
			{ width = 484,
				on_escape_pressed = function(self, data) self:GetParent():Hide() end,
			},
		},
		on_show = function(self, data) 
			self.editboxes[1]:SetText(data.string)
			self.editboxes[1]:HighlightText()
			self.editboxes[1]:SetFocus()
		end,
		buttons = {
			{ text = CLOSE, },
		},	
		show_while_dead = true,
		hide_on_escape = true,
	})
	if Dialog:ActiveDialog("RemindersStringExportAll") then
		Dialog:Dismiss("RemindersStringExportAll")
	end
	Dialog:Spawn("RemindersStringExportAll", {string = string})
end

local function import_click(bytes)
	local decoded = LibDeflate:DecodeForPrint(bytes);
	-- Zlib is used because its the only compression that I found to have compatible algorithm implementations in Lua and javascript
	coroutine.yield();
	local str = LibDeflate:DecompressZlib(decoded);
	coroutine.yield();
	if str == nil then
		print("Error decompression");
	end
	Reminders:ReceiveReminder(str, true); 
	return
end

function Reminders:ImportFromString()
	Dialog:Register("RemindersStringImport", {
		text = "Reminder String Import",
		width = 500,
		editboxes = {
			{ width = 484,
				on_escape_pressed = function(self, data) self:GetParent():Hide() end,
			},
		},
		on_show = function(self, data) 
			self.editboxes[1]:SetText('')
			self.editboxes[1]:HighlightText()
			self.editboxes[1]:SetFocus()
		end,
		buttons = {
			{ text = "Close", },
			{ text = "Import", 

			  on_click = function(self, mousebutton, down)
				Reminders.import_coro = coroutine.create(import_click)
				coroutine.resume(Reminders.import_coro, self.editboxes[1]:GetText())
				
				Reminders.coro_ticker = Reminders.coro_ticker or C_Timer.NewTicker(
					0.03,
					function() coroutine.resume(Reminders.import_coro) end
				)
			  end,
			},
		},	
		show_while_dead = true,
		hide_on_escape = true,
	})
	if Dialog:ActiveDialog("RemindersStringImport") then
		Dialog:Dismiss("RemindersStringImport")
	end
	Dialog:Spawn("RemindersStringImport", {})
end

function Reminders:TriggerDuplicateDialog(reminder)
	Dialog:Register("RemindersDuplicate", {
		text = "New name",
		width = 500,
		editboxes = {
			{ width = 484,
				on_escape_pressed = function(self, data) self:GetParent():Hide() end,
			},
		},
		on_show = function(self, data) 
			self.editboxes[1]:SetText('')
			self.editboxes[1]:HighlightText()
			self.editboxes[1]:SetFocus()
		end,
		buttons = {
			{ text = "Close", },
			{ text = "Duplicate", 

			  on_click = function(self, mouseButton, down) Reminders:DuplicateReminder(reminder, self.editboxes[1]:GetText()); 	
			  	if Reminders.Config.redraw then
					Reminders.Config.redraw()
					Reminders.Config:Open()
				end end,
			},
		},	
		show_while_dead = true,
		hide_on_escape = true,
	})
	if Dialog:ActiveDialog("RemindersDuplicate") then
		Dialog:Dismiss("RemindersDuplicate")
	end
	Dialog:Spawn("RemindersDuplicate", {})
end

function Reminders:CopyNames()
	Dialog:Register("RemindersCopy", {
		text = "",
		width = 500,
		editboxes = {
			{ width = 484,
				on_escape_pressed = function(self, data) self:GetParent():Hide() end,
			},
		},
		on_show = function(self, data)
			local namestring = ""
			for i = 1, 20 do
				local name = UnitName('raid'..i);
				if name then
					namestring = namestring .. name .. "\n"
				end
			end
			self.editboxes[1]:SetText(namestring)
			self.editboxes[1]:HighlightText()
			self.editboxes[1]:SetFocus()
		end,
		buttons = {
			{ text = "Close", },
		},	
		show_while_dead = true,
		hide_on_escape = true,
	})
	if Dialog:ActiveDialog("RemindersCopy") then
		Dialog:Dismiss("RemindersCopy")
	end
	Dialog:Spawn("RemindersCopy", {})
end

function Reminders:TriggerRenameDialog(reminder)
	Dialog:Register("RemindersRename", {
		text = "New name",
		width = 500,
		editboxes = {
			{ width = 484,
				on_escape_pressed = function(self, data) self:GetParent():Hide() end,
			},
		},
		on_show = function(self, data) 
			self.editboxes[1]:SetText('')
			self.editboxes[1]:HighlightText()
			self.editboxes[1]:SetFocus()
		end,
		buttons = {
			{ text = "Close", },
			{ text = "Rename", 

			  on_click = function(self, mouseButton, down) Reminders:RenameReminder(reminder, self.editboxes[1]:GetText()); 	
			  	if Reminders.Config.redraw then
					Reminders.Config.redraw()
					Reminders.Config:Open()
				end end,
			},
		},	
		show_while_dead = true,
		hide_on_escape = true,
	})
	if Dialog:ActiveDialog("RemindersRename") then
		Dialog:Dismiss("RemindersRename")
	end
	Dialog:Spawn("RemindersRename", {})
end

function Reminders:DummyTest(reminder)
	self:FireReminderReal(reminder)
end

function Reminders:PlaySound(name)
	local SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")
	local fetch = SML:Fetch(SML.MediaType.SOUND, name, true)
	if fetch then
		PlaySoundFile(fetch, "MASTER")
		return
	elseif WeakAuras and WeakAuras.sound_types then
		for k, v in pairs(WeakAuras.sound_types) do
			if v == name then
				PlaySoundFile(k, "MASTER")
				return
			end
		end
	end
	print("Warning - Sound '" .. name .. "' not found.")
end

function Reminders:SoundIndexToName(index)
    local SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")
    local sound_name = SML:List(SML.MediaType.SOUND)[index]
    if not sound_name then return "None" end
    return sound_name
end

function Reminders:SoundNameToIndex(name)
    local SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")
    for k, v in pairs(SML:List(SML.MediaType.SOUND)) do
        if v == name then
            return k
        end
    end
    print("Sound index not found.")
    return 0
end
