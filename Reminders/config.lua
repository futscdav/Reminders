local Config = {}
local AceDialog, AceRegistry, AceGUI, SML, registered, options
local playerClass = select(2, UnitClass("player"))
local globalConfig = {}

local numel = table.getn;
local insert = table.insert;

Reminders.Config = Config
-- set when config is open
local db = nil
local addon_name_ref = "Method Reminders"

local function dump_table_chat(table, varname)
	_G["TESTVAR_"..varname] = table;
	UIParentLoadAddOn("Blizzard_DebugTools");
	DevTools_DumpCommand("TESTVAR_"..varname)
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

local function make_header(text, order)
	return {type="header", order=order, name=text}
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

local trigger_values = {
	event = "Event",
	bw_timer = "Big Wigs Timer",
	bw_phase = "Big Wigs Phase"
}

local function trigger_str_to_index(trigger, bw_set)
	if trigger == "event" then return "event"
	elseif trigger == "bw_timer" then return "bw_timer"
	else return "bw_phase"
	end
end

local function trigger_index_to_str(key)
	return trigger_values[index]
end

local repetition_values = {
	first_only = "Only First",
	every_time = "Every Time",
	specific = "Specific Number",
	repeat_every = "Repeat Every"
}

local sound_values = { }

local function inject_specific_people_input(reminder, base_table)
	base_table.plugins["notify_plugin"] = {}
	if reminder.notification.who == "specific" then
		if reminder.notification.specific_list == nil then
			reminder.notification.specific_list = ""
		end
		base_table.plugins["notify_plugin"] = {
			input = {
				type = "input",
				name = "People list",
				desc = "List people to notify, separated by comma",
				order = 99,
				width = "double",
				get = function(info) return reminder.notification.specific_list end,
				set = function(info, value) reminder.notification.specific_list = value end,
			}
		}
	end
end

local function inject_send_only_to_with_aura(reminder, base_table)
	local check = {
		type = "toggle",
		name = "Only show if has aura",
		desc = "Only show reminder of the receiver also has this aura",
		order = 100,
		get = function(info) return reminder.notification.check_for_aura end,
		set = function(info, value) reminder.notification.check_for_aura = value end,
	}
	local input = {
		type = "input",
		name = "", --"Aura",
		desc = "Only show reminder of the receiver also has this aura",
		order = 101,
		get = function(info) return reminder.notification.aura_to_check or "" end,
		set = function(info, value) reminder.notification.aura_to_check = value end,
	}
	base_table.args["aura_check_check"] = nil
	base_table.args["aura_check_input"] = nil
	if true then
		base_table.args["padding0"] = make_padding(99, "normal")
		base_table.args["aura_check_check"] = check
		base_table.args["aura_check_input"] = input
	end
end

local function inject_event_trigger_settings(reminder, base_table, child_name, order)

	if not reminder.trigger_opt.boss_hp_unit then
		reminder.trigger_opt.boss_hp_unit = "boss1"
		reminder.trigger_opt.boss_hp_pct = 50
	end

	local function make_check_source(order)
		return {
			type = "toggle",
			name = "Source name",
			order = order,
			get = function(info) return reminder.trigger_opt.check_source end,
			set = function(info, value) reminder.trigger_opt.check_source = value end,
		}
	end
	local function make_source_input(order)
		return {
			type = "input",
			name = "",--"Source name",
			order = order,
			get = function(info) return reminder.trigger_opt.source_name end,
			set = function(info, value) reminder.trigger_opt.source_name = value end,
		}
	end
	local function make_name_toggle(order)
		return {
			type = "toggle",
			name = "Spell name",
			order = order,
			get = function(info) return reminder.trigger_opt.check_name end,
			set = function(info, value) reminder.trigger_opt.check_name = value end,
		}
	end
	local function make_name_input(order)
		return {
			type = "input",
			name = "",--"Spell name",
			order = order,
			get = function(info) return reminder.trigger_opt.name end,
			set = function(info, value) reminder.trigger_opt.name = value end,
		}
	end
	local function make_dest_toggle(order)
		return {
			type = "toggle",
			name = "Target name",
			order = order,
			get = function(info) return reminder.trigger_opt.check_dest end,
			set = function(info, value) reminder.trigger_opt.check_dest = value end,
		}
	end
	local function make_dest_input(order)
		return {
			type = "input",
			name = "",--"Target name",
			order = order,
			get = function(info) return reminder.trigger_opt.dest_name end,
			set = function(info, value) reminder.trigger_opt.dest_name = value end,
		}
	end
	local function make_phase_only_header()
		return make_header("Phase only", order + 0.55)
	end
	local function make_phase_only_toggle()
		return {
			type = "toggle",
			name = "Only load in phase (BW)",
			order = order + 0.95,
			get = function(info) return reminder.trigger_opt.only_load_phase end,
			set = function(info, value) reminder.trigger_opt.only_load_phase = value end,
		}
	end
	local function make_phase_only_input()
		return {
			type = "input",
			name = "",--"Phase",
			order = order + 0.96,
			get = function(info) return tostring(reminder.trigger_opt.only_load_phase_num or "") end,
			set = function(info, value) reminder.trigger_opt.only_load_phase_num = tonumber(value) end,
		}
	end

	local optable = {}
	optable["=="] = "=="; optable["<"] = "<"; optable[">"] = ">"; optable["<="] = "<="; optable[">="] = ">=";

	local args_inject = {
		["AA_INACTIVE"] = {},
		["ENCOUNTER_START"] = {},
		["UNIT_HEALTH"] = {
			boss_hp_unit = {
				type = "input",
				name = "Unit",
				order = order + 0.21,
				get = function(info) return reminder.trigger_opt.boss_hp_unit end,
				set = function(info, value) reminder.trigger_opt.boss_hp_unit = value end,
			},
			boss_hp_pct = {
				type = "input",
				name = "Percentage",
				order = order + 0.22,
				get = function(info) return tostring(reminder.trigger_opt.boss_hp_pct) end,
				set = function(info, value) reminder.trigger_opt.boss_hp_pct = tonumber(value) end,
			},
			make_phase_only_header(),
			make_phase_only_toggle(),
			make_phase_only_input(),
		},
		["SPELL_AURA_APPLIED"] = {
			make_check_source(order + 0.21),
			make_source_input(order + 0.22),
			make_name_toggle(order + 0.23),
			make_name_input(order + 0.24),
			make_dest_toggle(order + 0.25),
			make_dest_input(order + 0.26),
			include_refresh_toggle = {
				type = "toggle",
				name = "Include refresh",
				order = order + 0.29,
				get = function(info) return reminder.trigger_opt.include_aura_refresh end,
				set = function(info, value) reminder.trigger_opt.include_aura_refresh = value end,
			},
			make_phase_only_header(),
			make_phase_only_toggle(),
			make_phase_only_input(),
		},
		["SPELL_AURA_APPLIED_DOSE"] = {
			make_check_source(order + 0.21),
			make_source_input(order + 0.22),
			make_name_toggle(order + 0.23),
			make_name_input(order + 0.24),
			make_dest_toggle(order + 0.25),
			make_dest_input(order + 0.26),
			stacks_toggle = {
				type = "toggle",
				name = "Check Stacks",
				order = order + 0.27,
				get = function(info) return reminder.trigger_opt.check_stacks end,
				set = function(info, value) reminder.trigger_opt.check_stacks = value end,
			},
			stacks_operator = {
				type = "select",
				name = "",
				values = optable,
				order = order + 0.28,
				width = "half",
				get = function(info) return reminder.trigger_opt.stacks_op end,
				set = function(info, value) reminder.trigger_opt.stacks_op = value end,
			},
			stacks_count = {
				type = "input",
				name = "",--"Stack count",
				order = order + 0.29,
				width = "half",
				get = function(info) return tostring(reminder.trigger_opt.stacks_count) end,
				set = function(info, value) reminder.trigger_opt.stacks_count = tonumber(value) end,
			},
			make_phase_only_header(),
			make_phase_only_toggle(),
			make_phase_only_input(),
		},
		["SPELL_CAST_SUCCESS"] = {
			make_check_source(order + 0.21),
			make_source_input(order + 0.22),
			make_name_toggle(order + 0.23),
			make_name_input(order + 0.24),
			make_dest_toggle(order + 0.25),
			make_dest_input(order + 0.26),
			make_phase_only_header(),
			make_phase_only_toggle(),
			make_phase_only_input(),
		},
		["SPELL_CAST_START"] = {
			make_check_source(order + 0.21),
			make_source_input(order + 0.22),
			make_name_toggle(order + 0.23),
			make_name_input(order + 0.24),
			make_phase_only_header(),
			make_phase_only_toggle(),
			make_phase_only_input(),
		}
	}

	base_table[child_name].plugins["event_settings"] = args_inject[reminder.trigger_opt.event]

	base_table[child_name].plugins["trigger"] = {
		header = make_header("Event", order + 0.01),
		trigger_select = {
			type = "select",
			name = "Event selection",
			values = event_trigger_value_options,
			order = order + 0.02,
			get = function(info) return reminder.trigger_opt.event end,
			set = function(info, value) reminder.trigger_opt.event = value; 
										base_table[child_name].plugins["event_settings"] = args_inject[reminder.trigger_opt.event]
										Reminders:ReminderTriggerChanged(reminder, "event")							
			end,
			width = "double",
		},
		-- plugins inside plugins don't work :( gotta do it the old way
		padding0 = make_padding(order + 0.5, "double"),

	}
end

local function inject_bw_timer_trigger_settings(reminder, base_table, child_name, order)
	local function make_phase_only_header()
		return make_header("Phase only", order + 0.55)
	end
	local function make_phase_only_toggle()
		return {
			type = "toggle",
			name = "Only load in phase (BW)",
			order = order + 0.95,
			get = function(info) return reminder.trigger_opt.only_load_phase end,
			set = function(info, value) reminder.trigger_opt.only_load_phase = value end,
		}
	end
	local function make_phase_only_input()
		return {
			type = "input",
			name = "",--"Phase",
			order = order + 0.96,
			get = function(info) return tostring(reminder.trigger_opt.only_load_phase_num or "") end,
			set = function(info, value) reminder.trigger_opt.only_load_phase_num = tonumber(value) end,
		}
	end
	base_table[child_name].plugins["trigger"] = {
		check_text = {
			type = "toggle",
			name = "Check Text",
			order = order + 0.02,
			get = function(info) return reminder.trigger_opt.bw_bar_check_text end,
			set = function(info, value) reminder.trigger_opt.bw_bar_check_text = value end,
		},
		timer_text = {
			type = "input",
			name = "Bar Text (contains)",
			order = order + 0.03,
			get = function(info) return reminder.trigger_opt.bw_bar_text or "" end,
			set = function(info, value) reminder.trigger_opt.bw_bar_text = (value) end
		},
		check_spellid = {
			type = "toggle",
			name = "Check Spell Id",
			order = order + 0.04,
			get = function(info) return reminder.trigger_opt.bw_bar_check_spellid end,
			set = function(info, value) reminder.trigger_opt.bw_bar_check_spellid = value end,
		},
		spellid = {
			type = "input",
			name = "",--"Spell Id",
			order = order + 0.05,
			get = function(info) return tostring(reminder.trigger_opt.bw_bar_spellid or "") end,
			set = function(info, value) reminder.trigger_opt.bw_bar_spellid = tonumber(value) end,
		},
		before = {
			type = "input",
			name = "Seconds before end",
			order = order + 0.06,
			get = function(info) return tostring(reminder.trigger_opt.bw_bar_before or "") end,
			set = function(info, value) reminder.trigger_opt.bw_bar_before = tonumber(value) end,
		},
		make_phase_only_header(),
		make_phase_only_toggle(),
		make_phase_only_input(),
	}
end

local function inject_bw_trigger_settings(reminder, base_table, child_name, order)
	base_table[child_name].plugins["trigger"] = {
		phase_input = {
			type = "input",
			name = "Phase number",
			order = order + 0.02,
			get = function(info) return tostring(reminder.trigger_opt.bw_phase) end,
			set = function(info, value) reminder.trigger_opt.bw_phase = tonumber(value) end
		}

	}
end

local function inject_trigger_settings(reminder, base_table, child_name, order)
	-- print("Injecting", reminder.trigger)
	if reminder.trigger == "event" then
		inject_event_trigger_settings(reminder, base_table, child_name, order)
	end
	if reminder.trigger == "bw_phase" then
		inject_bw_trigger_settings(reminder, base_table, child_name, order)
	end
	if reminder.trigger == "bw_timer" then
		inject_bw_timer_trigger_settings(reminder, base_table, child_name, order)
	end
end

local function create_tab_content_reminder(reminder)
	--local function change_name(self_ref, value) self_ref.name = value end
	local self_ref_tab = {

	}

	tab = {
		type = "group",
		childGroups = "tab",
		name = reminder.name,
		order = 3,
		args = {
			general_tab = {
				type = "group",
				name = "General",
				order = 5,
				args = {
					control_header = {
						type = "header",
						name = "Controls",
						order = 1,
					},
					enable_button = {
						type = "toggle",
						name = "Enabled",
						get = function(info) return reminder.enabled end,
						set = function(info, value) reminder.enabled = value; end,
						order = 2,
					},
					padding0 = make_padding(2.5, "double"),
					test_reminder = {
						type = "execute",
						name = "Test Send Reminder",
						func = function() Reminders:DummyTest(reminder) end,
						order = 3,
						width = "double",
					},
					rename = {
						type = "execute",
						name = "Rename",
						--disabled = true,
						func = function() Reminders:TriggerRenameDialog(reminder) end,
						order = 4,
						width = "normal",
					},
					send_target = {
						type = "execute",
						name = "Send to Target",
						func = function() Reminders:SendReminderToTarget(reminder) end,
						order = 5,
						width = "normal"
					},
					export_string = {
						type = "execute",
						name = "Export to String",
						func = function() Reminders:ExportToString(reminder) end,
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
					padding1 = make_padding(8, "double"),
					header_prot = {
						type = "header",
						name = "Delete",
						order = 9,
					},
					delete = {
						type = 'execute',
						confirm = true,
						confirmText = "Are you sure?",
						name = "Delete Reminder",
						desc = "Delete Reminder",
						func = delete,
						order = 10,
						width = "normal"
					},
				}
			},
			event_setup_tab = {
				type = "group",
				name = "Trigger",
				order = 3,
				plugins = {
					["trigger"] = {

					},
					["event_settings"] = {

					},
				},
				args = {
					-- newer begin
					trigger_header = make_header("Trigger Type", 0),
					-- order 1 to 3
					trigger_type_select = {
						name = "",
						type = "select",
						values = trigger_values,
						sorting = {"event", "bw_timer", "bw_phase"},
						get = function(info) return trigger_str_to_index(reminder.trigger) end, 
						set = function(info, value)
								local old = reminder.trigger
								reminder.trigger = value
								Reminders:ReminderTriggerChanged(reminder, old)
								self_ref_tab.self_ref.args.event_setup_tab.plugins["event_settings"] = {}
								inject_trigger_settings(reminder, self_ref_tab.self_ref.args, "event_setup_tab", 2)
							  end,
						width = "double",
						order = 1
					},
					-- order 4 to 5
					delay_settings_header = make_header("Delay After Trigger", 4),
					delay_settings_time = {
						type = "input",
						name = "",--"Delay (sec)",
						get = function(info) return tostring(reminder.delay.delay_sec) end,
						-- validate number
						set = function(info, value) reminder.delay.delay_sec = tonumber(value) end,
						order = 5,
					},
					difficulty_header = make_header("Difficulty", 5.98),
					difficulty_select = {
						type = "select",
						name = "",
						values = difficulty_values,
						order = 5.99,
						get = function(info) return reminder.trigger_opt.difficulty end,
						set = function(info, value) reminder.trigger_opt.difficulty = value end,
						width = "double"
					},
					-- order 6 to x
					-- one of n
					repetition_header = make_header("Repeating Setup", 6),
					only_first = {
						type = "toggle",
						name = "Only First",
						order = 7,
						get = function(info) return reminder.repeats.setup == "only_first" end,
						set = function(info, value) reminder.repeats.setup = "only_first" end,
					},
					every_occurence = {
						type = "toggle",
						name = "Every time",
						order = 8,
						get = function(info) return reminder.repeats.setup == "every_time" end,
						set = function(info, value) reminder.repeats.setup = "every_time" end,
					},
					specific = {
						type = "toggle",
						name = "Specific number",
						order = 9,
						get = function(info) return reminder.repeats.setup == "specific" end,
						set = function(info, value) reminder.repeats.setup = "specific" end,
					},
					specific_input = {
						type = "input",
						name = "",--"Number (only for specific)",
						order = 10,
						get = function(info) return tostring(reminder.repeats.number) end,
						set = function(info, value) reminder.repeats.number = tonumber(value) end,
						width = "normal"
					},
					padding0 = make_padding(10.5, "double"),
					repeat_every = {
						type = "toggle",
						name = "Repeat Every",
						order = 11,
						get = function(info) return reminder.repeats.setup == "repeat_every" end,
						set = function(info, value) reminder.repeats.setup = "repeat_every" end,
					},
					every_offset = {
						type = "input",
						name = "Offset",
						order = 12,
						get = function(info) return tostring(reminder.repeats.offset or "") end,
						set = function(info, value) reminder.repeats.offset = tonumber(value) end,
						width = "half"
					},
					every_mod = {
						type = "input",
						name = "Every nth after offset",
						order = 13,
						get = function(info) return tostring(reminder.repeats.modulo or "") end,
						set = function(info, value) reminder.repeats.modulo = tonumber(value) end,
						width = "half"
					},
					-- newer end
				}
			},
			display_tab = {
				type = "group",
				name = "Display",
				order = 2,
				args = {
					notify_settings = {
						type = "group",
						inline = true,
						name = "Notification Settings",
						order = 1,
						plugins = {
							["notify_plugin"] = {

							}
						},
						args = {
							-- send = {
							-- 	type = "toggle",
							-- 	name = "Only Local",
							-- 	desc = "If this is checked, no notification will be sent, it will only fire if this happens to you.",
							-- 	order = 0.5,
							-- 	get = function(info) return reminder.notification.send == false end,
							-- 	set = function(info, value) reminder.notification.send = not value end,
							-- },
							only_self = {
								type = "toggle",
								name = "Only Me",
								order = 1,
								get = function(info) return reminder.notification.who == "self" end,
								set = function(info, value) 
										reminder.notification.who = "self"; 
										inject_specific_people_input(reminder, self_ref_tab.self_ref.args.display_tab.args.notify_settings); 
									  end,
							},
							everyone = {
								type = "toggle",
								name = "Everyone",
								order = 2,
								get = function(info) return reminder.notification.who == "everyone" end,
								set = function(info, value) 
										reminder.notification.who = "everyone"; 
										inject_specific_people_input(reminder, self_ref_tab.self_ref.args.display_tab.args.notify_settings); 
									  end,
							},
							specific_people = {
								type = "toggle",
								name = "Specific People",
								order = 3,
								get = function(info) return reminder.notification.who == "specific" end,
								set = function(info, value) 
										reminder.notification.who = "specific"; 
										inject_specific_people_input(reminder, self_ref_tab.self_ref.args.display_tab.args.notify_settings); 
									  end, -- and read + save specific
							},

						}
					},
					make_header("Message", 5),
					message_input = {
						type = "input",
						name = "Message",
						order = 6,
						get = function(info) return reminder.notification.message end,
						set = function(info, value) reminder.notification.message = value end,
						width = "double",
					},
					duration_input = {
						type = "input",
						name = "Duration",
						order = 6.5,
						get = function(info) return tostring(reminder.notification.duration) end,
						set = function(info, value) reminder.notification.duration = tonumber(value) end,
						width = "normal"
					},
					sound_header = {
						type = "header",
						name = "Sound",
						order = 7,
					},
					sound_select = {
						type = "select",
						name = "",
						width = "double",
						order = 8,
						values = sound_values,
						get = function(info) return Reminders:SoundNameToIndex(reminder.notification.sound) end,
						set = function(info, value) reminder.notification.sound = Reminders:SoundIndexToName(value); Reminders:PlaySound(sound_values[value]) end,
					},
					color_header = make_header("Color", 9),
					color_picker = {
						type = "color",
						name = "Message color",
						order = 10,
						get = function(info) return unpack(reminder.notification.color or {1.0, 1.0, 1.0, 1.0})end,
						set = function(info, r, g, b, a) reminder.notification.color = {r, g, b, a} end,
					}

				}
			},
		}
	}

	tab.self_ref = tab
	self_ref_tab.self_ref = tab
	-- -- do the initial injections
	inject_trigger_settings(reminder, self_ref_tab.self_ref.args, "event_setup_tab", 2);
	inject_specific_people_input(reminder, self_ref_tab.self_ref.args.display_tab.args.notify_settings);
	inject_send_only_to_with_aura(reminder, self_ref_tab.self_ref.args.display_tab.args.notify_settings)
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
	reminder.repeats.offset = 0
	reminder.repeats.modulo = 1

	reminder.notification = {}
	reminder.notification.who = "self"
	reminder.notification.message = ""
	reminder.notification.duration = 3
	reminder.notification.send = true
	reminder.notification.sound = "None"
	reminder.notification.specific_list = ""
	reminder.notification.color = {1.0, 1.0, 1.0, 1.0}
	
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


-- /run print(Reminders.Config.options.args["Tomb of Sargeras"].args["Kil'jaeden"])
local function filter_results(info, base_table, search)
	local config_tab = options.args[info[1]].args[info[2]]
	-- only keep 'general', wipe rest and reconstruct
	local new_args = {};
	new_args.general = config_tab.args.general;
	new_args.hl = config_tab.args.hl;

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
			name = "|TInterface\\Icons\\Spell_chargepositive:16|t|cff00ff00Create New",
			order = 0,
			args = {
				toggle = {
					type = "input",
					name = "Name",
					get = function(info) return info.arg end,
					set = create_empty,
					order = 1,
				},
				padding0 = make_padding(2, "normal"),
				ortext = {
					type = "header",
					name = "OR",
					order = 2.5
				},
				import = {
					type = "execute",
					name = "Import from String",
					func = function() Reminders:ImportFromString() end,
					order = 3,
				},
				header = {
					type = "header",
					name = "",
					order = 3.5
				},
				-- padding1 = make_padding(3.5, "normal"),
				padding2 = make_padding(4, "normal"),
				padding3 = make_padding(5, "double"),

				padding4 = make_padding(6.5, "double"),
				padding5 = make_padding(7.3, "double"),
				padding6 = make_padding(7.35, "double"),
				padding7 = make_padding(7.37, "double"),
				search_box = {
					type = "input",
					name = "Search names",
					get = function(info) return info.arg end,
					set = function(info, value) filter_results(info, base_table, value) end,
					order = 7.5
				},
				cancel_search = {
					type = "execute",
					name = "Clear",
					width = 'half',
					func = function(info) helpful_object_for_circular_dependency:filter_clear(info, base_table) end,
					order = 8,
				},
				padding8 = make_padding(10, "double"),
				padding9 = make_padding(11, "double"),
				paddinga = make_padding(10.5, "double"),
				paddingb = make_padding(11.5, "double"),
				del_all = {
					type = "execute",
					confirm = true,
					confirmText = "Are you sure?",
					name = "Delete all reminders for this boss",
					func = function(info) Reminders:PurgeBossReminders(info[1], info[2]) end,
					order = 12
				},
				export_all = {
					type = "execute",
					name = "Export all reminders",
					order = 11,
					func = function(info) Reminders:ExportAllBossReminders(info[1], info[2]) end,
				},
			}
		},
		hl = {
			type = "group",
			disabled = true,
			name = "",
			order = 1,
			args = {}
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
		order = 99.5,
		args = {
			everywhere = {
				type = "group",
				name = "Loaded Everywhere",
				args = tab_content,
				order = 99.5
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
			-- add trash tab, disable for now
			-- trash = {
			-- 	type = "group",
			-- 	name = "Trash",
			-- 	order = .5,
			-- 	args = data_args
			-- }
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
	-- print(numel(options))
	-- print(unpack(keyset(options["args"])))
	-- dump_table_chat(options.args, "opts")
	-- RemindersDB.options_saved_file = options
end

local function load_shared_media()
	SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")

	sound_values = SML:List(SML.MediaType.SOUND)
	if WeakAuras and WeakAuras.sound_types then
		for k, v in pairs(WeakAuras.sound_types) do
			local isin = false
			for _, sv in pairs(sound_values) do if sv == v then isin = true end end
			if not isin and v ~= " Custom" and v ~= " Sound by Kit ID" then
				sound_values[#sound_values+1] = v
			end
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
		childGroups = "tree", -- select ?
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
