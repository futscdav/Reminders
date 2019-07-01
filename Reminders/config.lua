local Config = {}
local AceDialog, AceRegistry, AceGUI, SML, registered, options
local playerClass = select(2, UnitClass("player"))
local globalConfig = {}

local numel = table.getn;
local insert = table.insert;

Reminders.Config = Config
-- set when config is open
local db = nil
local addon_name_ref = "Method Reminder"

local function dump_table_chat(table, varname)
	_G["TESTVAR_"..varname] = table;
	UIParentLoadAddOn("Blizzard_DebugTools");
	DevTools_DumpCommand("TESTVAR_"..varname)
end

local function delete(info)
	-- remove from db
	-- print(info[1], info[2], info[3], info[4], info[5])
	Reminders:DeleteReminder(info[1], info[2], info[3])
	-- remove from ui
	options.args[info[1]].args[info[2]].args[info[3]] = nil
end

local event_trigger_value_options = {
	AA_INACTIVE = "No Trigger",
	SPELL_CAST_START = "SPELL_CAST_START",
	SPELL_CAST_SUCCESS = "SPELL_CAST_SUCCESS",
	SPELL_AURA_APPLIED = "SPELL_AURA_APPLIED",
	ENCOUNTER_START = "ENCOUNTER_START",
	UNIT_HEALTH = "UNIT_HEALTH",
	SPELL_AURA_APPLIED_DOSE = "SPELL_AURA_APPLIED_DOSE",
}

local difficulty_values = {
	ANY = "Any",
	HEROIC = "Heroic",
	MYTHIC = "Mythic"
}

local repetition_values = {
	first_only = "Only First",
	every_time = "Every Time",
	specific = "Specific Number",
	repeat_every = "Repeat Every"
}

local sound_values = { }

local function inject_specific_people_input(reminder, base_table)
	local input = {
		type = "input",
		name = "People list",
		desc = "List people to notify, separated by comma",
		order = 99,
		width = "double",
		get = function(info) return reminder.notification.specific_list end,
		set = function(info, value) reminder.notification.specific_list = value end,
	}
	base_table.args["specific_people_input"] = nil
	if reminder.notification.who == "specific" then
		base_table.args["specific_people_input"] = input
	end
end

local function inject_send_only_to_with_aura(reminder, base_table)
	local check = {
		type = "toggle",
		name = "Only if has aura",
		order = 100,
		get = function(info) return reminder.notification.check_for_aura end,
		set = function(info, value) reminder.notification.check_for_aura = value end,
	}
	local input = {
		type = "input",
		name = "Aura",
		order = 101,
		get = function(info) return reminder.notification.aura_to_check or "" end,
		set = function(info, value) reminder.notification.aura_to_check = value end,
	}
	base_table.args["aura_check_check"] = nil
	base_table.args["aura_check_input"] = nil
	if true then
		base_table.args["aura_check_check"] = check
		base_table.args["aura_check_input"] = input
	end
end

local function inject_event_trigger_opt_settings(reminder, base_table, event)
	local phase_only_check = {
		type = "toggle",
		name = "Only load in bw phase",
		order = 1.91,
		get = function(info) return reminder.trigger_opt.only_load_phase end,
		set = function(info, value) reminder.trigger_opt.only_load_phase = value end,
	}
	local phase_only_input = {
		type = "input",
		name = "Phase",
		order = 1.92,
		get = function(info) return tostring(reminder.trigger_opt.only_load_phase_num or "") end,
		set = function(info, value) reminder.trigger_opt.only_load_phase_num = tonumber(value) end,
	}
	local header = {
		type = "header",
		name = event,
		get = function(info) return event end,
		order = 2
	}
	base_table.args["event_trigger_header"] = header

	base_table.args["event_only_load_phase_check"] = phase_only_check
	base_table.args["event_only_load_phase_input"] = phase_only_input

	base_table.args["event_trigger_check_source"] = nil
	base_table.args["event_trigger_source_input"] = nil
	base_table.args["event_trigger_check_dest"] = nil
	base_table.args["event_trigger_dest_input"] = nil
	base_table.args["event_trigger_check_name"] = nil
	base_table.args["event_trigger_name_input"] = nil
	base_table.args["event_trigger_include_refresh_toggle"] = nil
	base_table.args["event_trigger_boss_hp_unit"] = nil
	base_table.args["event_trigger_boss_hp_pct"] = nil
	
	if event == "AA_INACTIVE" then
		header.name = "No Trigger"
		return
	end
	if event == "ENCOUNTER_START" then
		return
	end

	if event == "UNIT_HEALTH" then
		if not reminder.trigger_opt.boss_hp_unit then
			reminder.trigger_opt.boss_hp_unit = "boss1"
			reminder.trigger_opt.boss_hp_pct = 50
		end
		local boss_hp_unit = {
			type = "input",
			name = "Unit",
			order = 3,
			get = function(info) return reminder.trigger_opt.boss_hp_unit end,
			set = function(info, value) reminder.trigger_opt.boss_hp_unit = value end,
		}
		local boss_hp_pct = {
			type = "input",
			name = "Percentage",
			order = 4,
			get = function(info) return tostring(reminder.trigger_opt.boss_hp_pct) end,
			set = function(info, value) reminder.trigger_opt.boss_hp_pct = tonumber(value) end,
		}
		base_table.args["event_trigger_boss_hp_unit"] = boss_hp_unit
		base_table.args["event_trigger_boss_hp_pct"] = boss_hp_pct
		return
	end
	
	-- check source
	local check_source = {
		type = "toggle",
		name = "Source name",
		order = 3,
		get = function(info) return reminder.trigger_opt.check_source end,
		set = function(info, value) reminder.trigger_opt.check_source = value end,
	}
	local source_input = {
		type = "input",
		name = "Source name",
		order = 4,
		get = function(info) return reminder.trigger_opt.source_name end,
		set = function(info, value) reminder.trigger_opt.source_name = value end,
	}
	base_table.args["event_trigger_check_source"] = check_source
	base_table.args["event_trigger_source_input"] = source_input
	-- check destination
	if not (event == "SPELL_CAST_START" or event == "UNIT_HEALTH") then
		local check_dest = {
			type = "toggle",
			name = "Target name",
			order = 5,
			get = function(info) return reminder.trigger_opt.check_dest end,
			set = function(info, value) reminder.trigger_opt.check_dest = value end,
		}
		local dest_input = {
			type = "input",
			name = "Target name",
			order = 6,
			get = function(info) return reminder.trigger_opt.dest_name end,
			set = function(info, value) reminder.trigger_opt.dest_name = value end,
		}
		base_table.args["event_trigger_check_dest"] = check_dest
		base_table.args["event_trigger_dest_input"] = dest_input
	end
	-- check aura name
	local name_toggle = {
		type = "toggle",
		name = "Spell name",
		order = 7,
		get = function(info) return reminder.trigger_opt.check_name end,
		set = function(info, value) reminder.trigger_opt.check_name = value end,
	}
	local name_input = {
		type = "input",
		name = "Spell name",
		order = 8,
		get = function(info) return reminder.trigger_opt.name end,
		set = function(info, value) reminder.trigger_opt.name = value end,
	}
	base_table.args["event_trigger_check_name"] = name_toggle
	base_table.args["event_trigger_name_input"] = name_input
	-- include refresh
	if event == "SPELL_AURA_APPLIED" then
		local include_refresh_toggle = {
			type = "toggle",
			name = "Include refresh",
			order = 9,
			get = function(info) return reminder.trigger_opt.include_aura_refresh end,
			set = function(info, value) reminder.trigger_opt.include_aura_refresh = value end,
		}
		base_table.args["event_trigger_include_refresh_toggle"] = include_refresh_toggle
	end
	if event == "SPELL_AURA_APPLIED_DOSE" then 
		local stacks_toggle = {
			type = "toggle",
			name = "Check Stacks",
			order = 9,
			get = function(info) return reminder.trigger_opt.check_stacks end,
			set = function(info, value) reminder.trigger_opt.check_stacks = value end,
		}
		local stacks_count = {
			type = "input",
			name = "Stack count",
			order = 10,
		}
	end
end

local function inject_bw_trigger_opt_settings(reminder, base_table)

	base_table.args["bw_trigger_settings"] = nil
	base_table.args["bw_trigger_check_text"] = nil
	base_table.args["bw_trigger_text"] = nil
	base_table.args["bw_trigger_check_spellid"] = nil
	base_table.args["bw_trigger_spellid"] = nil
	base_table.args["bw_trigger_before"] = nil

	local phase_input = {
			type = "input",
			name = "Phase number",
			order = 3,
			get = function(info) return tostring(reminder.trigger_opt.bw_phase) end,
			set = function(info, value) reminder.trigger_opt.bw_phase = tonumber(value) end
	}
	if reminder.trigger_opt.bw_setup == "phase" then
		base_table.args["bw_trigger_settings"] = phase_input
	end


	local check_text = {
		type = "toggle",
		name = "Check Text",
		order = 3,
		get = function(info) return reminder.trigger_opt.bw_bar_check_text end,
		set = function(info, value) reminder.trigger_opt.bw_bar_check_text = value end,
	}
	local timer_text = {
		type = "input",
		name = "Bar Text (exact)",
		order = 4,
		get = function(info) return reminder.trigger_opt.bw_bar_text or "" end,
		set = function(info, value) reminder.trigger_opt.bw_bar_text = (value) end
	}
	local check_spellid = {
		type = "toggle",
		name = "Check Spell Id",
		order = 5,
		get = function(info) return reminder.trigger_opt.bw_bar_check_spellid end,
		set = function(info, value) reminder.trigger_opt.bw_bar_check_spellid = value end,
	}
	local spellid = {
		type = "input",
		name = "Spell Id",
		order = 6,
		get = function(info) return tostring(reminder.trigger_opt.bw_bar_spellid or "") end,
		set = function(info, value) reminder.trigger_opt.bw_bar_spellid = tonumber(value) end,
	}
	local before = {
		type = "input",
		name = "Seconds before",
		order = 7,
		get = function(info) return tostring(reminder.trigger_opt.bw_bar_before or "") end,
		set = function(info, value) reminder.trigger_opt.bw_bar_before = tonumber(value) end,
	}
	if reminder.trigger_opt.bw_setup == "timer" then
		base_table.args["bw_trigger_check_text"] = check_text
		base_table.args["bw_trigger_text"] = timer_text
		base_table.args["bw_trigger_check_spellid"] = check_spellid
		base_table.args["bw_trigger_spellid"] = spellid
		base_table.args["bw_trigger_before"] = before
	end
end

local function inject_event_trigger_settings(reminder, base_table)
	local settings = {
		type = "group",
		inline = true,
		name = "Trigger Setup",
		order = 3,
		args = {
			trigger_select = {
				type = "select",
				name = "Trigger selection",
				values = event_trigger_value_options,
				order = 1,
				get = function(info) return reminder.trigger_opt.event end,
				set = function(info, value) reminder.trigger_opt.event = value; 
											inject_event_trigger_opt_settings(reminder, base_table.args["trigger_settings"], value) 
											Reminders:ReminderTriggerChanged(reminder, "event")							
				end,
			},
			difficulty_select = {
				type = "select",
				name = "Difficulty",
				values = difficulty_values,
				--disabled = true,
				order = 1.9,
				get = function(info) return reminder.trigger_opt.difficulty end,
				set = function(info, value) reminder.trigger_opt.difficulty = value end,
			}
		}
	}
	-- inject
	base_table.args["trigger_settings"] = settings;
	-- and do initial injections
	inject_event_trigger_opt_settings(reminder, base_table.args["trigger_settings"], reminder.trigger_opt.event)
end

local function inject_bw_trigger_settings(reminder, base_table)
	local settings = {
		type = "group",
		inline = true,
		name = "Trigger Setup",
		order = 3,
		args = {
			difficulty_select = {
				type = "select",
				name = "Difficulty",
				values = difficulty_values,
				order = 0.9,
				get = function(info) return reminder.trigger_opt.difficulty end,
				set = function(info, value) reminder.trigger_opt.difficulty = value end,
				width = "double"
			},
			boss_phase = {
				type = "toggle",
				name = "Boss Phase",
				order = 1,
				get = function(info) return reminder.trigger_opt.bw_setup == "phase" end,
				set = function(info, value) reminder.trigger_opt.bw_setup = "phase";
											inject_bw_trigger_opt_settings(reminder, base_table.args["trigger_settings"]);
											Reminders:ReminderTriggerChanged(reminder, "bw");  end,
			},
			timer_status = {
				type = "toggle",
				name = "Timer",
				--disabled = true,
				order = 2,
				get = function(info) return reminder.trigger_opt.bw_setup == "timer" end,
				set = function(info, value) reminder.trigger_opt.bw_setup = "timer";
											inject_bw_trigger_opt_settings(reminder, base_table.args["trigger_settings"]);
											Reminders:ReminderTriggerChanged(reminder, "bw");  end,
			}
		}
	}
	-- inject
	base_table.args["trigger_settings"] = settings;
	inject_bw_trigger_opt_settings(reminder, base_table.args["trigger_settings"])
end

local function inject_trigger_settings(reminder, info)
	if reminder.trigger == "event" then
		inject_event_trigger_settings(reminder, info)
	end
	if reminder.trigger == "bw" then
		inject_bw_trigger_settings(reminder, info)
	end
	--print (reminder.trigger)
end

local function create_tab_content_reminder(reminder)
	--local function change_name(self_ref, value) self_ref.name = value end
	local self_ref_tab = {

	}
	local tab = {
		type = "group",
		childGroups = "tab",
		name = reminder.name,
		order = 2,
		args = {
			name_header = {
				type = "header",
				name = reminder.name,
				get = function(info) return reminder.name end,
				set = function(info, value) reminder.name = value; end,
				order = 1
			},
			trigger_type = {
				type = "group",
				inline = true,
				name = "Trigger Mechanism",
				order = 2,
				args = {
					event_toggle = {
						type = "toggle",
						name = "Event",
						order = 1,
						get = function(info) return reminder.trigger == "event" end,
						set = function(info, value) reminder.trigger = "event"; 
													Reminders:ReminderTriggerChanged(reminder, "bw"); 
													inject_event_trigger_settings(reminder, self_ref_tab.self_ref); 
							  end,
					},
					bw_timer_toggle = {
						type = "toggle",
						name = "BigWigs",
						order = 2,
						get = function(info) return reminder.trigger == "bw" end,
						set = function(info, value) reminder.trigger = "bw";
													Reminders:ReminderTriggerChanged(reminder, "event")
													reminder.trigger_opt.bw_setup = "phase"
													inject_bw_trigger_settings(reminder, self_ref_tab.self_ref); 
							  end,
					}
				}
			},
			delay_settings = {
				type = "group",
				inline = true,
				name = "Delay Setup",
				order = 4,
				args = {
					delay_sec = {
						type = "input",
						name = "Delay (sec)",
						get = function(info) return tostring(reminder.delay.delay_sec) end,
						-- validate number
						set = function(info, value) reminder.delay.delay_sec = tonumber(value) end,
					}
				}
			},
			repetition_settings = {
				type = "group",
				inline = true,
				name = "Repeat Setup",
				order = 5,
				args = {
					-- one of n
					only_first = {
						type = "toggle",
						name = "Only First",
						order = 1,
						get = function(info) return reminder.repeats.setup == "first_only" end,
						set = function(info, value) reminder.repeats.setup = "first_only" end,
					},
					every_occurence = {
						type = "toggle",
						name = "Every time",
						order = 2,
						get = function(info) return reminder.repeats.setup == "every_time" end,
						set = function(info, value) reminder.repeats.setup = "every_time" end,
					},
					specific = {
						type = "toggle",
						name = "Specific number",
						order = 3,
						get = function(info) return reminder.repeats.setup == "specific" end,
						set = function(info, value) reminder.repeats.setup = "specific" end,
					},
					specific_input = {
						type = "input",
						name = "Number (only for specific)",
						order = 4,
						get = function(info) return tostring(reminder.repeats.number) end,
						set = function(info, value) reminder.repeats.number = tonumber(value) end,
						width = "half"
					},
					repeat_every = {
						type = "toggle",
						name = "Repeat Every",
						order = 5,
						get = function(info) return reminder.repeats.setup == "repeat_every" end,
						set = function(info, value) reminder.repeats.setup = "repeat_every" end,
					},
					every_offset = {
						type = "input",
						name = "Offset",
						order = 6,
						get = function(info) return tostring(reminder.repeats.offset or "") end,
						set = function(info, value) reminder.repeats.offset = tonumber(value) end,
						width = "half"
					},
					every_mod = {
						type = "input",
						name = "Every nth after offset",
						order = 7,
						get = function(info) return tostring(reminder.repeats.modulo or "") end,
						set = function(info, value) reminder.repeats.modulo = tonumber(value) end,
						width = "half"
					},
				}
			},
			notify_settings = {
				type = "group",
				inline = true,
				name = "Notification Settings",
				order = 6,
				args = {
					send = {
						type = "toggle",
						name = "Only Local",
						desc = "If this is checked, no notification will be sent, it will only fire if this happens to you.",
						order = 0.5,
						get = function(info) return reminder.notification.send == false end,
						set = function(info, value) reminder.notification.send = not value end,
					},
					only_self = {
						type = "toggle",
						name = "Only Me",
						order = 1,
						get = function(info) return reminder.notification.who == "self" end,
						set = function(info, value) reminder.notification.who = "self"; inject_specific_people_input(reminder, self_ref_tab.self_ref.args.notify_settings); end,
					},
					everyone = {
						type = "toggle",
						name = "Everyone",
						order = 1,
						get = function(info) return reminder.notification.who == "everyone" end,
						set = function(info, value) reminder.notification.who = "everyone"; inject_specific_people_input(reminder, self_ref_tab.self_ref.args.notify_settings); end,
					},
					specific_people = {
						type = "toggle",
						name = "Specific People",
						order = 1,
						get = function(info) return reminder.notification.who == "specific" end,
						set = function(info, value) reminder.notification.who = "specific"; inject_specific_people_input(reminder, self_ref_tab.self_ref.args.notify_settings); end, -- and read + save specific
					}
				}
			},
			message_settings = {
				type = "group",
				inline = true,
				name = "Message Settings",
				order = 7,
				args = {
					message_input = {
						type = "input",
						name = "Message",
						order = 1,
						get = function(info) return reminder.notification.message end,
						set = function(info, value) reminder.notification.message = value end,
						width = "double",
					},
					sound_select = {
						type = "select",
						name = "Sound",
						order = 2,
						values = sound_values,
						get = function(info) return Reminders:SoundNameToIndex(reminder.notification.sound) end,
						set = function(info, value) reminder.notification.sound = Reminders:SoundIndexToName(value); Reminders:PlaySound(sound_values[value]) end,
					},
					duration_input = {
						type = "input",
						name = "Duration",
						order = 4,
						get = function(info) return tostring(reminder.notification.duration) end,
						set = function(info, value) reminder.notification.duration = tonumber(value) end,
						width = "half"
					}
				}
			},
			control = {
				type = "group",
				inline = true,
				name = "Controls",
				order = 99,
				args = {
					enable_button = {
						type = "toggle",
						name = "Enabled",
						get = function(info) return reminder.enabled end,
						set = function(info, value) reminder.enabled = value; end,
						order = 2,
					},
					delete = {
						type = 'execute',
						confirm = true,
						confirmText = "Are you sure?",
						name = "Delete Reminder",
						desc = "Delete Reminder",
						func = delete,
						order = 3,
						width = "half"
					},
					send_target = {
						type = "execute",
						name = "Send to Target",
						func = function() Reminders:SendReminderToTarget(reminder) end,
						order = 4,
						width = "double"
					},
					export_string = {
						type = "execute",
						name = "Export to String",
						func = function() Reminders:ExportToString(reminder) end,
						order = 5,
						width = "double",
					},
					test_reminder = {
						type = "execute",
						name = "Test Reminder",
						func = function() Reminders:DummyTest(reminder) end,
						order = 6,
						width = "double",
					},
					duplicate = {
						type = "execute",
						name = "Duplicate",
						func = function() Reminders:TriggerDuplicateDialog(reminder) end,
						order = 7,
						width = "double",
					},
					rename = {
						type = "execute",
						name = "Rename",
						--disabled = true,
						func = function() Reminders:TriggerRenameDialog(reminder) end,
						order = 8,
						width = "double",
					}
				}
			}
			
		}
	}
	tab.self_ref = tab
	self_ref_tab.self_ref = tab
	-- do the initial injections
	inject_trigger_settings(reminder, tab);
	inject_specific_people_input(reminder, self_ref_tab.self_ref.args.notify_settings);
	inject_send_only_to_with_aura(reminder, self_ref_tab.self_ref.args.notify_settings)
	return tab
end

local function create_empty(info, name)
	local reminder = {};
	reminder.name = name
	reminder.category = info[1]
	reminder.subcategory = info[2]

	-- enabled by default
	reminder.enabled = true
	reminder.trigger = "event"
	reminder.trigger_opt = {}
	reminder.trigger_opt.event = "AA_INACTIVE"
	reminder.trigger_opt.difficulty = "ANY"
	reminder.trigger_opt.bw_phase = 1

	reminder.delay = {}
	reminder.delay.delay_sec = 0

	reminder.repeats = {}
	reminder.repeats.setup = "every_time"
	reminder.repeats.number = 1

	reminder.notification = {}
	reminder.notification.who = "self"
	reminder.notification.message = ""
	reminder.notification.duration = 3
	reminder.notification.send = true
	reminder.notification.sound = "None"
	
	local instance = info[1]
	local encounter = info[2]

	if encounter == "everywhere" or encounter == "trash" then
		insert(db.reminders[instance].reminders, reminder)
	else
		insert(db.reminders[instance][encounter].reminders, reminder)
	end
	
	options.args[info[1]].args[info[2]].args[name] = create_tab_content_reminder(reminder)

	return reminder;
end

local function make_padding(order, width)
	local padding = {
		type = "description",
		name = "",
		width = width,
		order = order,
	}
	return padding
end

-- /run print(Reminders.Config.options.args["Tomb of Sargeras"].args["Kil'jaeden"])
local function filter_results(info, base_table, search)
	local config_tab = options.args[info[1]].args[info[2]]
	-- only keep 'general', wipe rest and reconstruct
	local new_args = {};
	new_args.general = config_tab.args.general;

	for i = 1, #base_table.reminders do
		local tab = create_tab_content_reminder(base_table.reminders[i])
		if tab.name:lower():find(search:lower()) then
			new_args[tab.name] = tab
		end
	end
	--config_tab.args = new_args
	options.args[info[1]].args[info[2]].args = new_args
end

local helpful_object_for_circular_dependency = {}

local function create_tab_content(base_table)
	local args = {
		general = {
			type = "group",
			childGroups = "tab",
			name = "Add new",
			order = 0,
			args = {
				toggle = {
					type = "input",
					name = "Name of the reminder",
					get = function(info) return info.arg end,
					set = create_empty,
					order = 1
				},
				padding = make_padding(2, "normal"),
				import = {
					type = "execute",
					name = "Import from string",
					func = function() Reminders:ImportFromString() end,
					order = 3,
				},
				padding2 = make_padding(4, "double"),
				padding3 = make_padding(5, "double"),
				del_all = {
					type = "execute",
					confirm = true,
					confirmText = "Are you sure?",
					name = "Delete all reminders for this boss",
					func = function(info) Reminders:PurgeBossReminders(info[1], info[2]) end,
					order = 6
				},
				export_all = {
					type = "execute",
					name = "Export all reminders",
					order = 7,
					func = function(info) Reminders:ExportAllBossReminders(info[1], info[2]) end,
				},
				padding4 = make_padding(6.5, "double"),
				padding5 = make_padding(7.3, "double"),
				padding6 = make_padding(7.35, "double"),
				padding7 = make_padding(7.37, "double"),
				search_box = {
					type = "input",
					name = "Search string",
					get = function(info) return info.arg end,
					set = function(info, value) filter_results(info, base_table, value) end,
					order = 7.5
				},
				cancel_search = {
					type = "execute",
					name = "Clear search",
					func = function(info) helpful_object_for_circular_dependency:filter_clear(info, base_table) end,
					order = 8,
				}
			}
		}
	}
	for i = 1, #base_table.reminders do
		local tab = create_tab_content_reminder(base_table.reminders[i])
		-- apparently entries cannot be indices, so use name as unique identifier
		args[tab.name] = tab
	end
	return args
end

function helpful_object_for_circular_dependency:filter_clear(info, base_table)
	-- reconstruct as if when building
	local args = create_tab_content(base_table)
	options.args[info[1]].args[info[2]].args = args;
end

local function load_instance_selection()

	local tab_content = create_tab_content(db.reminders.everywhere);

	options.args.everywhere = {
		type = "group",
		childGroups = "tab",
		name = "Everywhere",
		order = .5,
		args = {
			everywhere = {
				type = "group",
				name = "Loaded Everywhere",
				args = tab_content,
			}
		}
	}

	for _, instance in pairs(Reminders.instances) do
		local instance_name = instance.name
		if not db.reminders[instance_name] then
			db.reminders[instance_name] = {}
			db.reminders[instance_name].reminders = {}
		end
		local data_args = create_tab_content(db.reminders[instance_name])
		local instance_args = {
			-- add trash tab
			trash = {
				type = "group",
				name = "Trash",
				order = .5,
				args = data_args
			}
		}

		if instance.is_raid then
			for _, encounter in pairs(instance.encounters) do
				local encounter_name = encounter.name
				if not db.reminders[instance_name][encounter_name] then
					db.reminders[instance_name][encounter_name] = {}
					db.reminders[instance_name][encounter_name].reminders = {}
				end
				local data_args = create_tab_content(db.reminders[instance_name][encounter_name])
				encounter_args = {
					type = "group",
					name = encounter.name,
					order = encounter.order,
					args = data_args
				}
				instance_args[encounter_name] = encounter_args
				-- doesn't play nice with ace
				-- insert(instance_args, encounter_args)
			end
		end

		options.args[instance.name] = {
			type = "group",
			childGroups = "tab",
			name = instance.name,
			order = instance.order,
			args = instance_args
		}--[[]]--
	end
	--RemindersDB.options_saved_file = options
end

local function load_shared_media()
	SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")

	sound_values = SML:List(SML.MediaType.SOUND)
	if WeakAuras and WeakAuras.sound_types then
		for k, v in pairs(WeakAuras.sound_types) do
			sound_values[#sound_values+1] = v
		end
	end
end

local function load_db_if_needed()
	if not db then db = Reminders.db end
	db.reminders = db.reminders or {}
	db.reminders.everywhere = db.reminders.everywhere or {}
	db.reminders.everywhere.reminders = db.reminders.everywhere.reminders or {}
end

local function load_config()
	options = {
		type = "group",
		name = addon_name_ref,
		args = {}
	}
	-- expose for debug dumping
	_G["RemindersOptions"] = options

	load_db_if_needed();
	load_shared_media();
	load_instance_selection();

	-- So modules can access it easier/debug
	Config.options = options
	Config.redraw = load_instance_selection
	
	-- Options finished loading, fire callback for any non-default modules that want to be included
	Reminders:FireModuleEvent("OnConfigurationLoad")
end

local defaultToggles
function Config:Open()
	AceDialog = AceDialog or LibStub("AceConfigDialog-3.0")
	AceRegistry = AceRegistry or LibStub("AceConfigRegistry-3.0")
	
	if( not registered ) then
		load_config()
		
		AceRegistry:RegisterOptionsTable(addon_name_ref, options, true)
		AceDialog:SetDefaultSize(addon_name_ref, 895, 570)
		registered = true
	end
	
	AceDialog:Open(addon_name_ref)

	if( not defaultToggles ) then
		defaultToggles = true

		--AceDialog.Status[addon_name_ref].status.groups.groups.units = true
		--AceRegistry:NotifyChange(addon_name_ref)
	end

end

function Config:Hide()
	AceDialog:Close(addon_name_ref)
end
