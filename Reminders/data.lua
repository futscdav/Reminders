-- Key is instance ID
local instances = {
	[2164] = {
		order = 4,
		is_raid = true,
		instance_id = 2164,
		name = "The Eternal Palace",
		encounters = {
			sivara = {
				encounter_id = 2352,
				engage_id = 2298,
				name = "Sivara",
				order = 12
			},
			behemoth = {
				encounter_id = 2347,
				engage_id = 2289,
				name = "Behemoth",
				order = 11
			},
            radiance = {
                encounter_id = 2353,
                engage_id = 2305,
                name = "Radiance",
                order = 10
            },
            ashvane = {
                encounter_id = 2354,
                engage_id = 2304,
                name = "Ashvane",
                order = 9
            },
            orgozoa = {
                encounter_id = 2351,
                engage_id = 2303,
                name = "Orgozoa",
                order = 8
            },
            court = {
                encounter_id = 2359,
                engage_id = 2311,
                name = "Court",
                order = 7
            },
            zaqul = {
                encounter_id = 2349,
                engage_id = 2293,
                name = "Za'qul",
                order = 6
            },
            azshara = {
                encounter_id = 2361,
                engage_id = 2299,
                name = "Azshara",
                order = 5
            }
		}
    },
    [2217] = {
		order = 1,
		is_raid = true,
		instance_id = 2217,
        name = "Nya'lotha",
        encounters = {
            wrathion = { -- OK
				encounter_id = 2368,
				engage_id = 2329,
				name = "Wrathion",
				order = 12
			},
            maut = { -- OK
				encounter_id = 2365,
				engage_id = 2327,
				name = "Maut",
				order = 11
            },
            skitra = { -- OK
				encounter_id = 2369,
				engage_id = 2334,
				name = "Skitra",
				order = 10
			},
            xanesh = { -- OK
				encounter_id = 2377,
				engage_id = 2328,
				name = "Xanesh",
				order = 9
			},
            hivemind = { -- OK
				encounter_id = 2372,
				engage_id = 2333,
				name = "Hivemind",
				order = 8
			},
            shadhar = { -- OK
				encounter_id = 2367,
				engage_id = 2335,
				name = "Shad'har",
				order = 7
			},
            drestagath = { -- OK
				encounter_id = 2373,
				engage_id = 2343,
				name = "Drest'agath",
				order = 6
            },
            vexiona = { -- OK
				encounter_id = 2370,
				engage_id = 2336,
				name = "Vexiona",
				order = 5 -- Forgot this boss
            },
            raden = { -- OK
				encounter_id = 2364,
				engage_id = 2331,
				name = "Ra-den",
				order = 4
			},
            ilgy = { -- OK
				encounter_id = 2374,
				engage_id = 2345,
				name = "Il'gynoth",
				order = 3
			},
            carapace = { -- OK
				encounter_id = 2366,
				engage_id = 2337,
				name = "Carapace",
				order = 2
			},
            nzoth = { -- OK
				encounter_id = 2375,
				engage_id = 2344,
				name = "N'Zoth",
				order = 1
			},
        }
    }
}

Reminders.instances = instances;

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