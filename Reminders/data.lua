-- KEY MUST BE THE EXACT INSTANCE NAME
-- aka this will only work for English version

-- ^^^ This should no longer be the case, but just to be sure, there is no
-- reason not to follow this rule

local instances = {
    ["Uldir"] = {
        order = 4,
        is_raid = true,
        zone_id = 9389,
        instance_id = 1861,
        -- map_id = 0, UNUSED (hopefully)
        name = "Uldir",
        encounters = {
            taloc = {
				encounter_id = 2168,
				engage_id = 1853,
				name = "Taloc",
				order = 1
            },
            mother = {
                encounter_id = 2167,
                engage_id = 2141,
                name = "Mother",
                order = 2
            },
            devourer = {
                encounter_id = 2146,
                engage_id = 2128,
                name = "Devourer",
                order = 3
            },
            zekvoz = {
                encounter_id = 2169,
                engage_id = 2136,
                name = "Zekvoz",
                order = 4
            },
            vectis = {
                encounter_id = 2166,
                engage_id = 2134,
                name = "Vectis",
                order = 5
            },
            zul = {
                encounter_id = 2195,
                engage_id = 2145, -- NEEDS CHECKING?
                name = "Zul",
                order = 6
            },
            mythrax = {
                encounter_id = 2194,
                engage_id = 2135,
                name = "Mythrax",
                order = 7
            },
            ghuun = {
                encounter_id = 2147,
                engage_id = 2122,
                name = "Ghuun",
                order = 8
            }
        }
    }
}

-- /run for i = 1,2000 do local m=C_Map.GetMapInfo(i); if (m ~= nil) then print((i) .. ' ' .. m.name) end end

local instances_old = {
	["The Emerald Nightmare"] = {
		order = 4,
		is_raid = true,
		zone_id = 8026,
		instance_id = 1520,
		map_id = 1094,
		name = "Emerald Nightmare",
		encounters = {
			nythendra = {
				encounter_id = 1703,
				engage_id = 1853,
				name = "Nythendra",
				order = 1
			},
			ursoc = {
				encounter_id = 1667,
				engage_id = 1841,
				name = "Ursoc",
				order = 2
			},
            elerethe = {
                encounter_id = 1,
                engage_id = 1876,
                name = "Elerethe",
                order = 3
            },
            dragons = {
                encounter_id = 1,
                engage_id = 1854,
                name = "Dragons",
                order = 4
            },
            ilgynoth = {
                encounter_id = 1,
                engage_id = 1873,
                name = "Il'gynoth",
                order = 5
            },
            cenarius = {
                encounter_id = 1,
                engage_id = 1877,
                name = "Cenarius",
                order = 6
            },
            xavius = {
                encounter_id = 1,
                engage_id = 1864,
                name = "Xavius",
                order = 7
            }
		}
	},
	["The Nighthold"] = {
		order = 3,
		is_raid = true,
		zone_id = 8025,
		instance_id = 1530,
		map_id = 1088,
		name = "The Nighthold",
		encounters = {
			skorpyron = {
				encounter_id = 1706,
				engage_id = 1849,
				name = "Skorpyron",
				order = 1
			},
			chronomatic_anomaly = {
				encounter_id = 1725,
				engage_id = 1865,
				name = "Chronomatic Anomaly",
				order = 2
			},
            triliax = {
                encounter_id = 1,
				engage_id = 1867,
				name = "Trilliax",
				order = 3
            },
            spellblade = {
                encounter_id = 1,
				engage_id = 1871,
				name = "Spellblade",
				order = 4
            },
            krosus = {
                encounter_id = 1,
				engage_id = 1842,
				name = "Krosus",
				order = 5
            },
            tichondrius = {
                encounter_id = 1,
				engage_id = 1862,
				name = "Tichondrius",
				order = 6
            },
            starboi = {
                encounter_id = 1,
				engage_id = 1863,
				name = "Star Augur",
				order = 8
            },
            botanist = {
                encounter_id = 1,
				engage_id = 1886,
				name = "Botanist",
				order = 7
            },
            elisande = {
                encounter_id = 1,
				engage_id = 1872,
				name = "Elisande",
				order = 9
            },
            guldan = {
                encounter_id = 1,
				engage_id = 1866,
				name = "Gul'dan",
				order = 10
            },
		}
	},
	["Trial of Valor"] = {
		order = 3,
		is_raid = true,
		zone_id = 8440,
		instance_id = 1648,
		map_id = 1114,
		name = "Trial of Valor",
		encounters = {
			odyn = {
				encounter_id = 1819,
				engage_id = 1958,
				name = "Odyn",
				order = 1
			},
			guarm = {
				encounter_id = 1830,
				engage_id = 1962,
				name = "Guarm",
				order = 2,
			},
			helya = {
				encounter_id = 1829,
				engage_id = 2008,
				name = "Helya",
				order = 3
			}
		}
	},
    ["Tomb of Sargeras"] = {
        order = 1.5,
        is_raid = true,
        map_id = 1676, -- TODO: UPDATE
        instance_id = 1676, -- TODO: UPDATE
        name = "Tomb of Sargeras",
        encounters = {
            goroth = {
                engage_id = 2032,
                name = "Goroth",
                order = 1
            },
            inquisition = {
                engage_id = 2048,
                name = "Demonic Inquisition",
                order = 2
            },
            harjatan = {
                engage_id = 2036,
                name = "Harjatan",
                order = 3
            },
            sisters = {
                engage_id = 2050,
                name = "Sisters",
                order = 4
            },
            mistress = {
                engage_id = 2037,
                name = "Mistress Sassz'ine",
                order = 5
            },
            desolate_host = {
                engage_id = 2054,
                name = "Desolate Host",
                order = 6
            },
            maiden = {
                engage_id = 2052,
                name = "Maiden",
                order = 7
            },
            fallen_avatar = {
                engage_id = 2038,
                name = "Fallen Avatar",
                order = 8
            },
            kiljaeden = {
                engage_id = 2051,
                name = "Kil'jaeden",
                order = 9
            }
        }
    },
    ["Antorus, the Burning Throne"] = {
        order = 1,
        is_raid = true,
        map_id = 1712,
        instance_id = 1712,
        name = "Antorus",
        encounters = {
            worldbreaker = {
                engage_id = 2076,
                name = "Worldbreaker",
                order = 1
            },
            felhounds = {
                engage_id = 2074,
                name = "Felhounds",
                order = 2
            },
            high_command = {
                engage_id = 2070,
                name = "High Command",
                order = 3
            },
            hasabel = {
                engage_id = 2064,
                name = "Hasabel",
                order = 4
            },
            eonar = {
                engage_id = 2075,
                name = "Eonar",
                order = 5
            },
            imonar = {
                engage_id = 2082,
                name = "Imonar",
                order = 6
            },
            kingaroth = {
                engage_id = 2088,
                name = "Kin'garoth",
                order = 7
            },
            varimathras = {
                engage_id = 2069,
                name = "Varimathras",
                order = 8
            },
            coven = {
                engage_id = 2073,
                name = "Coven of Shivarra",
                order = 9
            },
            aggramar = {
                engage_id = 2063,
                name = "Aggramar",
                order = 10
            },
            argus = {
                engage_id = 2092,
                name = "Argus",
                order = 11
            }
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