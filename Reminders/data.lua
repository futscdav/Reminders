-- Key is instance ID
-- engage_id is the important number which is given in ENCOUNTER_START event

function Reminders:PopulateInstances()

	local loaded, reason = LoadAddOn("Blizzard_EncounterJournal")

	-- Set current tier in dungeon journal
	local current_expansion_index = EJ_GetNumTiers()
	EJ_SelectTier(current_expansion_index)
	local raid = true
	
	local valid_indices = {}
	local instance_index = 1
	local instance_id = EJ_GetInstanceByIndex(instance_index, raid)

	while instance_id do
		table.insert(valid_indices, instance_index)
		instance_index = instance_index + 1
		instance_id = EJ_GetInstanceByIndex(instance_index, raid)
	end

	-- Do last one only.
	instance_index = valid_indices[#valid_indices]
	instance_id = EJ_GetInstanceByIndex(instance_index, raid)
	EJ_SelectInstance(instance_id)
	local instance_name, _, _, _, _, _, dungeonAreaMapID = EJ_GetInstanceInfo(instance_id)

	local boss_list = {}
	local boss_id = 1
	local instance_zone_id

	while true do
		EJ_SelectInstance(instance_id)
		local boss, _, _, _, _, _, encounter_id, zid = EJ_GetEncounterInfoByIndex(boss_id, instance_id)
		if not boss then break end
		instance_zone_id = zid
		table.insert(boss_list, {name = boss, engage_id = encounter_id})
		boss_id = boss_id + 1
	end

	for i = 1, #boss_list do
		boss_list[i].order = #boss_list - i
	end

	if instance_zone_id == nil then
		print("Error: Dungeon Journal not working.")
	end

	instance_table = {
		[instance_zone_id] = {
			order = 3,
			is_raid = true,
			instance_id = instance_zone_id,
			name = instance_name,
			encounters = boss_list,
		},
	}

	return instance_table
end


-- remiders wa
-- !TQrdZjUUX)l8ANh0EHgiF0BUoTVHeijKhbYdtU8MMjacBHrngBEY2q4Ug(T3Dxj)fyt4URtUZrwE3v737kPmS2Wbdn8hAuVATZRE(qJ5dnSW)bZYKMD4U2bZg29KZpEOXepPfxEbZ8flP3IHgx4i(YxysRnJh455eiGPET30P(8GHDbWTLEHlAB65oSBTto9KtHPyUMZ8K37jCdgACzRUdA1pISx654jHvTBne5U1PNNqppfNeqq6TYybZKJVAWmdeEU(e3hWKbWaaKPcxH)m1yyOAwyCGuyBZL(Qfyq8e4ql(KWPthSEbFOXnT6C)vp0b(o9kluYQdlWcUJtBlFfD9dNWxYDdmaSeVo0y0LnmgmYyqJ(aXcXf1yHdBnqCdx2CUglcfyb4mhqHgtK7LCIig33QtheUq3ewlqX8MEoHZDteDjZse6d6OJjvQyodvfP1egwaJJtosjh(CWma8VwSC9C5iHNZeUho0X62ddEadMJW2nXql9cuCk6DakG(CBTjeG1XJroDH(8rMomF)HtifVjo58qW9kYwQ(62Z6l(cF7jHPNO9wt7EvJCVQrUx1i3RJREgXVKUKtRSjZrPTvUN4CQrTSSbH04pczs(MXxf64Sz8JZeaAgssGuEswRbJVWKccIq1a5ryTnCeZb3KUNrIBh6LjyaJWsHC)MOSt276uG0QHgn79yx0xWfmYUbxb()Gaz0VrZ2pyqZpvyRuLQflks8uyreqi9T(F(JRKRA1pemjbEMlHWbYy8XJpbDKqyg1Npx4ci7p6XgOH1zQoyDqV7bpaj4pdHoSaMkgKcNVcNvX3gx2VvRUkj5rHfM54Si(PTlXoiAHbaA9weKy9xhXTyEgFpWjw5gHYLLifGaZWLUmNphX91pNC7PigWVc9pIdY9cdCeivgCt7l)1EpmOt7UTaXWdcEjtbMtkDkllHpg6oG)kqN)mONmd9d8MREFAOlLZPm)1fcvaWaXC(h2mwYw1uhsaVTq6zl5((WWPEs0HYk1xXucWVeM0BaNB(IFLn3UzS6hjpiu6QaBZTCxRu6MIsGMYmDrVbd6DxU230oNbKaLiCpSWc97JssbgipmPIPYgA0aEp3mUgwEJuuz4fr0BOXMBft3mgZDoI7USkaCaePemJ7MiNoEqagi)EHUq9J)52Gxv9HyWrcQHLHp0J38Fbml1f8ukT9ce9tmDrd7icVY0ZukDoUuKUM(cibJJKfqavZnPGYl5Rc0IhZYYZvLINeYs3n4MM9VRzFJr33VeWa32bs71WYQNB5sDetmMbjvSUJBjyhDs1Jlv5FS5wnPAyYV0B(CImXJ9KBgJOfeo5txZdGHsMCD5sAau0axgu)56fKc1SARfsW9PCPMcqPUIZEb1A(O7P3cq57A6eAjCTJr)xkTRl7TKwmMFJ07zmU43JnibC)Gr(bsLMPuQVaPELbJwYXuC0x)6BP(QKBYflHQemhhm9obrCW5csBdHwqLxFMngRbr1qn1jH6iqFoMHlLaeWM4WRkG8tYGY5YeawF9DO3BvI1aOYoorQ2j1v4uGopfKw8ay54wFid(p2aSjcSmdzbXcLVV63p00ey40UlFcR36hGTAnFE5uUMWYLqUVdf549e1TTX6BHSCvq6ThDuS7BSyPuLhD0wktux1V1DT72SvFikUv)(96Vzma1vnA3PvtOt1Eiax32aYCUz8DTmmACDRnJVVFRRA)7OA9OJ0kYyrygKG0tApHLXrBZ4YWhQStgTKVpzDapWZnCEzCuLDvsr56rP31Ukcvz9ytirqzc5jCjHpOyQDELkGA5VTzC9ZoR6XBL)ABQMS8aF(jODRY1aAuVsLpK33obM90c(2zWSNxW3(7WSFSsIVFs6wMe6KtQDJZgJc1lhrHx7Q(85lu5d(tL2JQfQslckp33MCxwKJUnklus(JcGazpvY5A7cZum)ZseOyRKnuy0CMETlv(PnVvQAvGhQwT0Z)1kGh0ylVDjuCCH8jAbFMwXLfdycBPh9xZLbZy532dae(8Dr2rZMelcoEUUCN4WqIfcDxGHU7ZSTWHGuByIjxwJtsymcoQBJE7PApxub8OiBPhwast6OwRkvCyv(IEe)kSJ4xCPZ2Nb9n0hSrNw9huyNfAsLXf)RfBrbrvmvyYuEW7h2OFI2OfbFC6aKPp9ziE8DXpP9keNtE(aqjwbRrQ(HGKjU7kLqTBAtIFp75kVvmDEBpRXuPNQRhTd5oa(wXraX2MeNbhFEwJCu5IcTZyrgpxN1Q0atPn8PBUEF09ZqfOlVP1L)675aTKQYNbL(Tq3UQv15dXbX9janeanO1auZLYNxH9ESWdn7RebZaeXAI4AKd4rDgyaQwCWDkJ)wnhGiJj7E8M2g3dkQ86HAx5)YEnBTxDQW21d2cDgs8de(NBrqSTROstPlofVxGTRPJ77A30Bg31HaK(DrnDNx)77wdJdvpIO1NUcFRmmQkHdU5SQg9EOBZKnkgid5BLcvtJ81S3dIMbkzxjC4LjqrB3DnWoEoO0LAlzKxMVElxXVR2BgD2p(fXfuHZx(qCXZfmH0VCUK4DQyISYsLlfTN4cwW9RgEz)QG3tLCqvDZmzMxICHzsxAtuGVVHY37N1r5kjJcZ)zDrXPievlP6S6aoetDLIHgNL5yhZEEKGAxAYFiZCQTSoAMWcpyaXCUv0HWbBRUTfURw88rnM5TQhqEF63nG4LLCfG6ys8eSuhay0MGZ)mo3)5NM9OwrYZM47jNCNhWExeFcfxoJb6iD6kuk1ZR5)CpsxTGQpZs8ugc1h7redh3GkSzfca)TI8(Pc2I6)AZ4JlovN2(FnAwj8GWgTHpFcwC)SbzpRKmCXUUR5hwsiP64fcl(PG9h)Lxxof0KF(7D(j6LNRS)q8e6tArQarCY(vysikQGLajW7qVQwoClvoRvZ4s(7hBRLNx4RjrbsGJhIx5kuh2sGGEZXxW13LJ0MH9)k(JqUcP3DbI9DEca)5dTtV4o2GWlv3EqE)pC44H9TBZT(Eqn68kXWfvFiuuuPVbsKPp1idu10D8w1k(iqpyQM9CwZZC9)RvsL)TqEpE)mhU5iUH48Pi99Vb6L0Rs(0J((3a9Wt49giJ)3J)Y7d5B)iLoFNSxIKMkeQUkcuDqmo4jHkCJoRTIlhh1Bik2QaDMZk2A)SF5x0Nimwckvzt8mENXnFb(GU4bcqO(tPkhsfFGsIPFfAUVXGr3zC9iyq3UTY9c)OZzFjFGAsQUx3JQr3SroxCsU3hY)bQNjMUo5gcY)scjNW(0vYS1n6j5omvbEMZIzSbzkRtODbHgn8AAivQgbE3(as6nPgErelGKnC6AQGYT8MCt2A96qxXXR0Z10tI(zxD6I5whVKeeKvbhCfqXuLXZ7OhY9AjIT8yfX4)VLFZUxQrvDyEwAOpTK8aTsbUIzxwLJhDBPC1DLIY8RjA8g6lep6(BtDVRPnQPuvz15zSHfDzUjwKuwb)ajtyplqDDQAR0RjqD9wmzAZsoNWC8fLjrj3gFmbFWWhY64C4Jj4dw9TAHiEt(1OIbXKBZ4)c8MSo1OTSgDWL25cJTcgBfmtYfMjkyMOGHLlmmfmSAvYB)OfzktCFN89D964n2gDQay75ATDH3Yn5ZCW3Hl0Bop6sCP)sdOBr(FBZC7V6Xh)9FdYZSYtA9OKTyOXJXJ2(E9tFX0BFzUr35)p(18JxP7qJRKIVSz8VfYSqXBZ4bAKwcs6P1rXF4)7