local _, Reminders = ...;

_G["Reminders"] = Reminders;

local addon = "Reminders";
local addonPrefix = "MTHDRMDRS_PR"
-- bit of a hack, but was easy to code (and who's gonna use that.. oh wait)
local sep = "ř"
local multilinesep = "§"
local numel = table.getn;
local VERSION = "1.1.0"

local loaded = {}
local instances = nil
local phaseMap = nil
local timerMap = nil
local eventMap = nil
local activeEncounterReminders = nil

local AceSerializer, AceComm
local Dialog = LibStub("LibDialog-1.0")

SLASH_METHODRETARDMANAGER1 = "/rm";

function SlashCmdList.METHODRETARDMANAGER(cmd, editbox)
	if cmd == "unlock" and Reminders.gui then
		Reminders.gui:UnlockMove()
	elseif cmd == "lock" and Reminders.gui then
		Reminders.gui:LockMove()
	elseif cmd == "verscheck" then
		Reminders:VersionCheck()
	else
		Reminders:ShowInterface();
	end
end

-- if you want to disable all debugging output, just change this function
function Reminders.debug(...)
	--print(...)
end

do
	local event_frame = CreateFrame("frame", "RetardManagerFrame", UIParent);
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

	Reminders.versionRetTable = {}
	
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
			-- do some on event handling here
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
	function RegisterBigWigs()
		if registered then
			return
		end
		if (BigWigsLoader) and BigWigsLoader.RegisterMessage then
			local aux = {}
			function aux:BigWigs_Message (event, module, key, text, ...)
				if (key == "stages") then
					savedPhase = savedPhase or 0
					savedPhase = savedPhase + 1
					Reminders:BossPhased(savedPhase)
				end
			end
			BigWigsLoader.RegisterMessage(aux, "BigWigs_Message")
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

function Reminders:OnLoad()
	self.event_frame:UnregisterEvent("ADDON_LOADED");
	self.loaded = loaded
	self.instance_loaded = nil
	RemindersDB = RemindersDB or self:InitDB();
	Reminders.db = RemindersDB

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
	if not success then
		--print("REMINDERS ERROR - FAILED TO REGISTER MESSAGE PREFIX")
	end

	self:RegisterBigWigsTimer()

end

function Reminders:abc()
	print(savedPhase)
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
		Reminders.debug("Reminders - ERROR, CANNOT DELETE " .. name .. ", CONTACT QONING");
	end
	
end

function Reminders:HideInterface()
	Reminders.Config.Hide();
end

function Reminders:ShowInterface()
	--print("Opening Config")
	Reminders.Config:Open();
end

function Reminders:OnEvent(...)
	local game_event = ...;
	if game_event == "COMBAT_LOG_EVENT_UNFILTERED" then
		timestamp, event = CombatLogGetCurrentEventInfo()
		if self.eventMap[event] then
			for i = 1, #self.eventMap[event] do
				local reminder = self.eventMap[event][i]
				if reminder.enabled then
					self:CheckReminder(reminder, CombatLogGetCurrentEventInfo())
				end
			end
		end
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
		--print("Encounter", id, "started, but no instance is loaded.")
		return
	end
	self.encounter_loaded = name
	self:LoadEncounterReminders(id, difficulty)
	BigWigsResetLocals()

	self.active_encounter = id
	self.active_difficulty = difficulty

	-- due to "pretty names", this is no longer reliable
	-- self:BossPhased(1)
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

	-- due to bigwigs changes, hardcode that kj is shifted 1 phase forward
	if id == 2051 then
		Reminders.debug("This is a special boss, manually triggering 1st phase.");
		savedPhase = 1
		Reminders:BossPhased(savedPhase)
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

	self:UnloadEncounterReminders(id, difficulty)
	BigWigsResetLocals()
	for k, v in pairs(activeEncounterReminders) do
		v:Cancel()
	end
	table.wipe(activeEncounterReminders)
end

function Reminders:ZoneChanged()
	local _, _, difficulty, _, _, _, _, new_id = GetInstanceInfo()
	self.debug("Entering instance " .. new_id)
	if self.instance_loaded then
		self:UnloadInstanceReminders(self.instance_loaded)
		-- maybe unload all encounters to prevent some errors like hearthstoning etc
		Reminders.debug("Reminders - Unloading instance")
		self.instance_loaded = nil
	end

	for k, v in pairs(instances) do
		if v.instance_id == new_id then
			-- KEY MUST BE EXACT INSTANCE NAME
			self.instance_loaded = k
			Reminders.debug("Reminders - Loading instance")
			self:LoadInstanceReminders(k)
		end
	end
end

function Reminders:GetRemindersForInstance(key_name) -- exact instance name
	if instances[key_name] == nil then
		print("Reminders: Fatal error - Instance name doesn't match the zone name when loaded by id.")
		return {}
	end
	local instance = instances[key_name].name
	if self.db.reminders[instance] == nil then
		print("Uninitialized instances found, may require a db purge.")
		return {}
	end
	return self.db.reminders[instance].reminders
end

function Reminders:GetRemindersForEncounter(instance_key_name, encounter_id)
	for k, v in pairs(self.instances[instance_key_name].encounters) do
		-- find the right encounter (TODO: can be done by indexing)
		if v.engage_id == encounter_id then
			local instance = instances[instance_key_name].name
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
		return 1/0 -- error
	end
end

function Reminders:ReminderToString(reminder)
	return reminder.category .. "_" .. reminder.name
end

function Reminders:FireModuleEvent(event)
	--print("Module event was fired: " .. event)
end

function Reminders:RegisterReminder(reminder)
	Reminders.debug("Registering reminder, name=" .. reminder.name)
	if reminder.volatile then
		reminder.volatile = nil
	end
	if reminder.trigger == "event" then
		self:RegisterEventReminder(reminder)
	elseif reminder.trigger == "bw" then
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
	elseif reminder.trigger == "bw" then
		self:UnregisterBWReminder(reminder)
	end
end

function Reminders:RegisterBWReminder(reminder)
	if reminder.trigger_opt.bw_setup == "phase" and reminder.trigger_opt.bw_phase then
		local phase = reminder.trigger_opt.bw_phase
		phaseMap[phase] = phaseMap[phase] or {}
		phaseMap[phase][#phaseMap[phase] + 1] = reminder
	end
	if reminder.trigger_opt.bw_setup == "timer" then
		if reminder.trigger_opt.bw_bar_check_text then
			timerMap.texts[reminder.trigger_opt.bw_bar_text] = timerMap.texts[reminder.trigger_opt.bw_bar_text] or {}
			table.insert(timerMap.texts[reminder.trigger_opt.bw_bar_text], reminder)
		elseif reminder.trigger_opt.bw_bar_check_spellid then
			timerMap.spellids[reminder.trigger_opt.bw_bar_spellid] = timerMap.texts[reminder.trigger_opt.bw_bar_spellid] or {}
			table.insert(timerMap.spellids[reminder.trigger_opt.bw_bar_spellid], reminder)
		end
	end
end

function Reminders:UnregisterBWReminder(reminder)
	if reminder.trigger_opt.bw_setup == "phase" and reminder.trigger_opt.bw_phase then
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
	if reminder.trigger_opt.bw_setup == "timer" then
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
	RemindersDB.reminders[instance][encounter].reminders = {}
	if self.Config.redraw then
		self.Config.redraw()
		self.Config:Open()
	end
end

function Reminders:BWTimerStop(bar_info)
	--Reminders.debug("Timer", bar_info.text, "stopped")
end

function Reminders:BWTimerStart(bar_info)
	--Reminders.debug("Timer", bar_info.text, bar_info.spellId, "started")
	if timerMap.texts and timerMap.texts[bar_info.text] then
		for k, v in pairs(timerMap.texts[bar_info.text]) do
			C_Timer.After(bar_info.duration - v.trigger_opt.bw_bar_before, function() Reminders:ScheduledBWTimerCheck(bar_info, v) end)
		end
	end
	if timerMap.spellids and timerMap.spellids[bar_info.spellId] then
		for k, v in pairs(timerMap.spellids[bar_info.spellId]) do
			C_Timer.After(bar_info.duration - v.trigger_opt.bw_bar_before, function() Reminders:ScheduledBWTimerCheck(bar_info, v) end)
		end
	end
end

function Reminders:ScheduledBWTimerCheck(bar_info, reminder)
	Reminders.debug("Checking if I should still trigger.")
	if Reminders:GetBigWigsTimerById(bar_info.text) == bar_info then
		Reminders:FireReminder(reminder)
	end
end

function Reminders:CheckReminder(reminder, ...)
	local _, _, _, _, sourceName, _, _, _, destName, _, _, spellId, spellName = ...
	-- event is already checked here
	local fire = true

	if reminder.trigger_opt.check_source then
		if reminder.trigger_opt.source_name ~= sourceName then
			fire = false
			return
		end
	end
	-- BUG: will check dest when trigger was changed (not an implementation issue though)
	if reminder.trigger_opt.check_dest then
		if reminder.trigger_opt.dest_name ~= destName then
			fire = false
			return
		end
	end
	if reminder.trigger_opt.check_name then
		if reminder.trigger_opt.name ~= spellName then
			fire = false
			return
		end
	end

	if fire then
		self:FireReminder(reminder)
	end
end

-- handle delaying here
function Reminders:FireReminder(reminder)
	if not reminder.enabled then
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
	if reminder.repeats.setup == "repeat_every" and (reminder.volatile.count < offset or mod(reminder.volatile.count - offset, modulo) ~= 0) then
		return
	end

	if reminder.delay and reminder.delay.delay_sec > 0 then
		Reminders.debug("Setting up a timer of " .. tostring(reminder.delay.delay_sec))
		local timer = C_Timer.NewTimer(reminder.delay.delay_sec, function() self:FireReminderReal(reminder) end)
		table.insert(activeEncounterReminders, timer)
	else
		self:FireReminderReal(reminder)
	end
end

function Reminders.TrueUnitAura(unit, name)
	return UnitBuff(unit, name) or UnitDebuff(unit, name)
end

local TrueUnitAura = Reminders.TrueUnitAura

-- check aura before sending if we should only send to people with an aura
function Reminders:FireReminderReal(reminder)
	Reminders.debug("Fired Reminder " .. reminder.name)
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
				message = spl[2]
			}
		}
		self:ReceiveAlert(reminder)
	elseif sig == "REMINDER" then
		local serialized = string.sub(msg, string.len("REMINDER") + string.len(sep) + 1)
		self:ReceiveReminder(serialized)
	elseif sig == "VERSCHECK" then
		local vers = "VERSCHECKRET" .. sep .. VERSION
		SendAddonMessageWrap(addonPrefix, vers, "WHISPER", source)
	elseif sig == "VERSCHECKRET" then
		local vers = spl[2]
		self.versionRetTable[source] = vers
	elseif sig == "CODE" then
		local code = spl[2]
		self:ExecuteCode(code)
	else
		print(source)
		print(msg)
		Reminders.debug("Wrong message format", source, msg)
	end

end

function Reminders:ExecuteCode(code)
	local runnable = "local function dummy_func_name_() " .. code .. "; end; dummy_func_name_()"
	RunScript(runnable)
end

function Reminders:VersCheckOutput()
	local rtrns = {}
	local nms = {}
	for k, v in pairs(self.versionRetTable) do 
		nms[#nms+1] = k
		rtrns[v] = rtrns[v] or {}
		rtrns[v][#rtrns[v]+1] = k
	end
	rtrns["Missing in raid"] = {}
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
	self.versionRetTable = {}
end

function Reminders:VersionCheck()
	print("Running version check of Reminders..")
	SendAddonMessageWrap(addonPrefix, "VERSCHECK", "GUILD")
	C_Timer.After(1.5, function() Reminders:VersCheckOutput() end)
end

-- SENDING HERE
function Reminders:SerializeReminder(reminder)
	AceSerializer = AceSerializer or LibStub:GetLibrary("AceSerializer-3.0")
	if not AceSerializer then
		print("AceSerializer is not installed")
		return
	end
	local serializedString = AceSerializer:Serialize(reminder)
	--print(string.len(serializedString))
	serializedString = "REMINDER" .. sep .. serializedString
	return serializedString
end

function Reminders:SendReminderToTarget(reminder)
	local target = UnitName('target')
	if not target then 
		print("No target selected.")
		return
	end
	print("Sending")
	local serializedString = self:SerializeReminder(reminder)
	SendAddonMessageWrap(addonPrefix, serializedString, "WHISPER", target)
end

function Reminders:SendReminder(reminder, channel)
	-- NYI
end

function Reminders:ReceiveReminder(serializedString)
	-- split multiline for multiimport
	if string.find(serializedString, multilinesep) then
		--print("Splitting reminders")
		local splits = split(serializedString, multilinesep)
		for k, spl in pairs(splits) do
			self:ReceiveReminder(spl)
		end
		return
	end
	AceSerializer = AceSerializer or LibStub:GetLibrary("AceSerializer-3.0")
	if not AceSerializer then
		print("AceSerializer is not installed")
		return
	end
	--print(string.len(serializedString))
	local success, reminder = AceSerializer:Deserialize(serializedString)
	if not success then
		print(reminder)
		return
	end
	-- dump_table_chat(reminder, "RECEIVED_REMINDER")
	-- insert it into db??
	self:AddReminder(reminder)
	-- redraw config if it was loaded already
	if self.Config.redraw then
		self.Config.redraw()
		self.Config:Open()
	end
	-- load if necessary
	if self:ShouldLoad(reminder) then
		self:RegisterReminder(reminder)
	end
end

function Reminders:SendAlert(reminder, channel, target)
	if reminder.notification.send or target and target == UnitName('player') then
		if channel == "WHISPER" then
			Reminders.debug("Sending reminder to " .. target)
			SendAddonMessageWrap(addonPrefix, Reminders:ConstructAlertMessage(reminder), channel, target)
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

function Reminders:ConstructAlertMessage(reminder)
	-- what do i need to include? message, sound, duration -- that's it?
	local msg = "ALERT"
	msg = msg .. sep
	msg = msg .. reminder.notification.message
	msg = msg .. sep
	msg = msg .. tostring(reminder.notification.sound)
	msg = msg .. sep
	msg = msg .. tostring(reminder.notification.duration)
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
		print("Adding a new reminder")
		table[#table + 1] = reminder
	else
		self:UnregisterReminder(table[index])
		print("Overwriting an old reminder")
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
	local reminders = RemindersDB.reminders[instance][boss].reminders
	local string = ""
	for k, v in pairs(reminders) do
		if string == "" then
			string = string .. self:SerializeReminder(v)
		else
			string = string .. "\n" .. multilinesep .. self:SerializeReminder(v)
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

			  on_click = function(self, mouseButton, down) Reminders:ReceiveReminder(self.editboxes[1]:GetText()); end,
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

function Reminders:nm()
	useframe = nil
	for _, frame in pairs(C_NamePlate.GetNamePlates(true)) do
		print(frame)
		useframe = frame
		GLOBAL_A = frame
	end
	dump_table_chat(useframe, 'dummy')
end