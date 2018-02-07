_G._savedEnv = getfenv()
module( "ability_item_usage_generic", package.seeall )

require( GetScriptDirectory().."/basics" ) -- Almost all Hero stats, Roles, etc

local Bot = GetBot()

----------------------------------------------------------------------------------------------------

function ItemUsageThink()
	Bot = GetBot()
	if not Bot:IsHero() then return end
	-- Swap tp to backpack!
	for i = 6,8 do
		local item = Bot:GetItemInSlot(i)

		if item ~= nil and item:GetName() ~= "item_tpscroll" and Bot:FindItemSlot("item_tpscroll") >= 0 and Bot:FindItemSlot("item_tpscroll") < 6 then
			if not Bot:Mode(
				BOT_MODE_ROAM,
				BOT_MODE_RETREAT,
				BOT_MODE_SECRET_SHOP,
				BOT_MODE_PUSH_TOWER_TOP,
				BOT_MODE_PUSH_TOWER_MID,
				BOT_MODE_PUSH_TOWER_BOT,
				BOT_MODE_DEFEND_TOWER_TOP,
				BOT_MODE_DEFEND_TOWER_MID,
				BOT_MODE_DEFEND_TOWER_BOT,
				BOT_MODE_TEAM_ROAM,
				BOT_MODE_DEFEND_ALLY,
				BOT_MODE_EVASIVE_MANEUVERS) then
				Bot:ActionImmediate_SwapItems(i,Bot:FindItemSlot("item_tpscroll"))
			end
		end
	end


	ResetCustomVars()

	UseItems()

	UpdateStuck()
	HandleWarded() -- I like that :3

end

function CourierUsageThink()
	local Bot = GetBot()
	for i = 0 ,GetNumCouriers() do
		local cour = GetCourier( i )
		if (cour ~= nil and GetCourierState(cour) ~= COURIER_STATE_DEAD and Bot:IsAlive()) then
			if Bot.NextItem ~= nil then
				if IsItemPurchasedFromSecretShop(Bot.NextItem) and  Bot.NextItem ~= "item_bottle" and (IsFlyingCourier(cour) and Bot:GetGold() - GetItemCost(Bot.NextItem) < 300 or  Bot:GetGold() - GetItemCost(Bot.NextItem) < 500) and GetCourierState(cour) ~= COURIER_STATE_DELIVERING_ITEMS  then
					Bot:ActionImmediate_Courier(cour,COURIER_ACTION_SECRET_SHOP)
				elseif not IsItemPurchasedFromSecretShop(Bot.NextItem) and GetCourierState(cour) ~= COURIER_STATE_AT_BASE and GetCourierState(cour) ~= COURIER_STATE_DELIVERING_ITEMS and GetCourierState(cour) ~= COURIER_STATE_RETURNING_TO_BASE then
					Bot:ActionImmediate_Courier(cour,COURIER_ACTION_RETURN)
				end
			end
			if (GetCourierState(cour) == COURIER_STATE_AT_BASE or GetCourierState(cour) == COURIER_STATE_IDLE or GetCourierState(cour) == COURIER_STATE_RETURNING_TO_BASE) and GetCourierState(cour) ~= COURIER_STATE_DELIVERING_ITEMS then
				if (Bot:GetStashValue()>900 or (Bot:GetStashValue()>200 and math.random() > 0.999 )) or ImportatItem() then
					Bot:ActionImmediate_Courier(cour,COURIER_ACTION_TAKE_AND_TRANSFER_ITEMS)
				end
			end
		end
	end
end

function CanUseItem(item)
	return Bot:FindItemSlot(item) >= 0 and Bot:FindItemSlot(item) <= 5 and Bot:GetItemInSlot(Bot:FindItemSlot(item)):IsFullyCastable() and (Bot:IsHero() ~= nil and Bot:IsHero() or not (Bot:IsIllusion() or Bot:IsCreep() or Bot:IsAncientCreep() or Bot:IsBuilding() or Bot:IsTower() or Bot:IsFort()))
end

function ImportatItem()
	local Bot = GetBot()

	for i = 6, 20, 1 do
		local item = Bot:GetItemInSlot(i)
		if (item~=nil) then
			if((string.find(item:GetName(),"recipe")~=nil) or (string.find(item:GetName(),"item_boots")~=nil)) then
				return true
			end
			
			if(item:GetName()=="item_ward_observer" and item:GetCurrentCharges()>1) then -- 2 or more ward
				return true
			end
		end
	end
	return false
end

function UpdateStuck()
	local Bot = GetBot()
	local botLoc = Bot:GetLocation()
	if Bot:IsAlive() and Bot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and not IsLocationPassable(botLoc) then
		if Bot.stuckLoc == nil then
			Bot.stuckLoc = botLoc
			Bot.stuckTime = DotaTime()
		elseif Bot.stuckLoc ~= botLoc then
			Bot.stuckLoc = botLoc
			Bot.stuckTime = DotaTime()
		end
	else	
		Bot.stuckTime = nil
		Bot.stuckLoc = nil
	end
end

function ResetCustomVars()
	Bot = GetBot()
	Bot.IsUsingTango = false
	Bot.GetSpellShield = false
	Bot.GetLotusOrb = false
	Bot.UseManta = false
end

function CanCastOnTarget( npcTarget )
	return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and not npcTarget:IsInvulnerable() and not npcTarget:IsIllusion()
end

--Make items efficient as possible and give every (active) item a own function!
-- (c) YoungFlyme
local item = nil -- Just to be sure!
local Items = {
	
	["item_tango"] = function()
		if CanUseItem("item_tango") then -- We got a useable tango!
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_tango"))
			if DotaTime() > 10*60 and Bot:DistanceFromFountain() < 1300 then
				Bot:ActionImmediate_SellItem(item)
				return
			end
			local Seconds = item:GetSpecialValueFloat("buff_duration")
			local Regen = item:GetSpecialValueFloat("health_regen")
			-- Dont even try to eat a Happy tree, no possible tho (Dont find it as a tree, cant eat it because you dont have the id,....)
			if not Bot:HasModifier("modifier_tango_heal") and (Bot:GetHealth()+Bot:GetHealthRegen()*Seconds+Regen*Seconds < Bot:GetMaxHealth()) and not Bot.IsUsingTango then
				local BonusRange = 100 -- In percent
				local Radius = (Bot:GetMaxHealth()*((BonusRange+100)/100)) - (Bot:GetHealth()+Bot:GetHealthRegen()*Seconds+Regen*Seconds)
				local towerrange = GetTower(TEAM_RADIANT,TOWER_BASE_2):GetAttackRange()
				if Radius+towerrange >= 1600 then Radius = 1599-towerrange end	
				local trees = Bot:GetNearbyTrees(Radius)
				local tower = Bot:GetNearbyTowers( Radius+towerrange, true )
				if #trees > 0 then
					for i=1,#trees do
						if GetUnitToLocationDistance(tower[i],GetTreeLocation(trees[i])) < towerrange and GetHeightLevel(Bot:GetLocation()) == GetHeightLevel(GetTreeLocation(trees[i])) then
							if Bot:GetActiveMode() == BOT_MODE_RETREAT then
								if Bot:IsFacingLocation( GetTreeLocation(trees[i]),45) then
									Bot:Action_UseAbilityOnTree(item,trees[i])
									Bot.IsUsingTango = true
									return
								end
							else
								Bot:Action_UseAbilityOnTree(item,trees[i])
								Bot.IsUsingTango = true
								return
							end
						end
					end
				end
			end
			if Bot:GetBotRole().support ~= nil and Bot:GetBotRole().support > 0 then
				for _,v in pairs(Bot:GetNearbyHeroes(1000,false,BOT_MODE_NONE)) do
					if v:GetTeam() == Bot:GetTeam() and v:GetPlayerID() ~= Bot:GetPlayerID() and CanCastOnTarget(v) then
						if v:GetHealth()+v:GetHealthRegen()*Seconds+Regen*Seconds < v:GetMaxHealth()-200 and not v:GotItemOnHero("item_tango_single") and not v:GotItemOnHero("item_tango") and not v:HasModifier("modifier_tango_heal") then
							local UnitName = Bot:GetUnitName():gsub("npc_dota_hero_","")
							UnitName = UnitName:gsub("^%l", string.upper)
							local TargetName = v:GetUnitName():gsub("npc_dota_hero_","")
							TargetName = TargetName:gsub("^%l", string.upper)
							print(UnitName.." gives ".. TargetName .. " an single tango. He loves "..TargetName.." <3")
							Bot:Action_UseAbilityOnEntity(item,v)
							return
						end
					end
				end
			end
		end
	end
	,
	["item_tango_single"] = function() 
		if CanUseItem("item_tango_single") then -- We got a useable tango!
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_tango_single"))
			if DotaTime() > 10*60 and Bot:DistanceFromFountain() > 1300 then -- Eat useless tangos
				local trees = Bot:GetNearbyTrees(1300);
				if trees[1] ~= nil then
					print("Wasting tango!")
					Bot:Action_UseAbilityOnTree(item, trees[1])
					return
				end
			else
				local Seconds = item:GetSpecialValueFloat("buff_duration")
				local Regen = item:GetSpecialValueFloat("health_regen")
				-- Dont even try to eat a Happy tree, no possible tho (Dont find it as a tree, cant eat it because you dont have the id,....)
				if not Bot:HasModifier("modifier_tango_heal") and (Bot:GetHealth()+Bot:GetHealthRegen()*Seconds+Regen*Seconds < Bot:GetMaxHealth()) and not Bot.IsUsingTango then
					local BonusRange = 100 -- In percent
					local Radius = (Bot:GetMaxHealth()*((BonusRange+100)/100)) - (Bot:GetHealth()+Bot:GetHealthRegen()*Seconds+Regen*Seconds)
					local towerrange = GetTower(TEAM_RADIANT,TOWER_BASE_2):GetAttackRange()
					if Radius+towerrange >= 1600 then Radius = 1599-towerrange end	
					local trees = Bot:GetNearbyTrees(Radius)
					local tower = Bot:GetNearbyTowers( Radius+towerrange, true )
					if #trees > 0 then
						for i=1,#trees do
							if GetUnitToLocationDistance(tower[i],GetTreeLocation(trees[i])) < towerrange and GetHeightLevel(Bot:GetLocation()) == GetHeightLevel(GetTreeLocation(trees[i])) then
								if Bot:GetActiveMode() == BOT_MODE_RETREAT then
									if Bot:IsFacingLocation( GetTreeLocation(trees[i]),45) then
										Bot:Action_UseAbilityOnTree(item,trees[i])
										Bot.IsUsingTango = true
										return
									end
								else
									Bot:Action_UseAbilityOnTree(item,trees[i])
									Bot.IsUsingTango = true
									return
								end
							end
						end
					end
				end
			end
		end
	end
	,
	["item_faerie_fire"] = function() 
		if CanUseItem("item_faerie_fire") then -- We got a useable fearie fire
			local IncomingDamage = 0
			for _,v in pairs(Bot:GetIncomingTrackingProjectiles()) do
				if v.is_attack and v.caster ~= nil then
					IncomingDamage = IncomingDamage + Bot:GetActualIncomingDamage(v.caster:GetAttackDamage() + v.caster:GetBaseDamageVariance(), DAMAGE_TYPE_PHYSICAL)
				else
					local ability = v.ability
					if ability ~= nil then
						local dmg = ability:GetAbilityDamage()
						local damageType = ability:GetDamageType()
						IncomingDamage = IncomingDamage + Bot:GetActualIncomingDamage(dmg, damageType)
					end
				end
			end
			if Bot:GetHealth() <= Bot:GetMaxHealth()/7.5 or Bot:GetHealth() - IncomingDamage <= 100 then
				item = Bot:GetItemInSlot(Bot:FindItemSlot("item_faerie_fire"))
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_clarity"] = function() 
		if CanUseItem("item_clarity") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_clarity"))
			local duration = item:GetSpecialValueInt("buff_duration")
			local manaReg = item:GetSpecialValueFloat("mana_regen")
			local range = item:GetCastRange()
			if Bot:GetMana() + Bot:GetManaRegen() * duration + manaReg*duration < Bot:GetMaxMana() and Bot:IncommingProjectiles() == 0 and CanCastOnTarget(Bot) then
				Bot:Action_UseAbilityOnEntity(item,Bot)
				return
			end
			if Bot:GetBotRole().support ~= nil and Bot:GetBotRole().support > 1 then
				for _,v in pairs(Bot:GetNearbyHeroes(range*2,false,BOT_MODE_NONE)) do
					if v:GetTeam() == Bot:GetTeam() and v:IncommingProjectiles() == 0 and CanCastOnTarget(v) then
						if v:GetMana() + v:GetManaRegen() * duration + manaReg*duration < v:GetMaxMana() then
							Bot:Action_UseAbilityOnEntity(item,v)
							return
						end
					end
				end
			end
		end
	end
	,
	["item_smoke_of_deceit"] = function() 
		if CanUseItem("item_smoke_of_deceit") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_smoke_of_deceit"))
			local range = item:GetSpecialValueInt("application_radius")

			local Heroes = 0
			local RoamingHeroes = 0
			local TeamRoamingHeroes = 0
			local EnemyIsNear = false

			for _,v in pairs(Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)) do
				if v:GetTeam() ~= Bot:GetTeam() then
					EnemyIsNear = true
					break
				end
				Heroes = Heroes+1
				if v:GetActiveMode() == BOT_MODE_ROAM then
					RoamingHeroes = RoamingHeroes+1
				elseif v:GetActiveMode() == BOT_MODE_TEAM_ROAM then
					TeamRoamingHeroes = TeamRoamingHeroes+1
				end
			end

			if not EnemyIsNear and (Heroes >= 4 or RoamingHeroes >= 2 or TeamRoamingHeroes >= 3) then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_enchanted_mango"] = function() 
		if CanUseItem("item_enchanted_mango") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_enchanted_mango"))
			local mana = item:GetSpecialValueInt("replenish_amount")
			local range = item:GetCastRange()

			if Bot:GetBotRole().support ~= nil and Bot:GetBotRole().support > 1 then
				for _,v in pairs(Bot:GetNearbyHeroes(range*2,false,BOT_MODE_NONE)) do
					if v:GetTeam() == Bot:GetTeam() and CanCastOnTarget(v) then
						if v:GetMana() + mana < v:GetMaxMana()-50 then
							Bot:Action_UseAbilityOnEntity(item,v)
							return
						end
					end
				end
			end

			local Multiplier = Bot:GetBotRole().support
			if Multiplier == nil then Multiplier = 1 end
			if Bot:NeedMana() and CanCastOnTarget(Bot) then
				if Bot:GetMana() + mana < Bot:GetMaxMana() then
					Bot:Action_UseAbilityOnEntity(item,Bot)
					return
				end
			else
				if Bot:GetMana() + mana < Bot:GetMaxMana()-(50*Multiplier) and CanCastOnTarget(Bot) then
					Bot:Action_UseAbilityOnEntity(item,Bot)
					return
				end
			end
		end
	end
	,
	["item_flask"] = function() 
		if CanUseItem("item_flask") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_flask"))
			local range = item:GetCastRange()
			local duration = item:GetSpecialValueInt("buff_duration")
			local regen = item:GetSpecialValueInt("health_regen")

			if Bot:GetBotRole().support ~= nil and Bot:GetBotRole().support > 0 then
				for _,v in pairs(Bot:GetNearbyHeroes(range*2,false,BOT_MODE_NONE)) do
					if v:GetTeam() == Bot:GetTeam() and v:IncommingProjectiles() == 0 and CanCastOnTarget(v) then
						if v:GetHealth() + v:GetHealthRegen() * duration + regen * duration < v:GetMaxHealth() then
							Bot:Action_UseAbilityOnEntity(item,v)
							return
						end
					end
				end
			end

			if Bot:IncommingProjectiles() == 0 and CanCastOnTarget(Bot) then
				if Bot:GetHealth() + Bot:GetHealthRegen() * duration + regen * duration < Bot:GetMaxHealth() then
					Bot:Action_UseAbilityOnEntity(item,Bot)
					return
				end
			end
		end
	end
	,
	["item_tome_of_knowledge"] = function() 
		if CanUseItem("item_tome_of_knowledge") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_tome_of_knowledge"))
			-- Just use it :3
			Bot:Action_UseAbility(Bot)
			return
		end
	end
	,
	["item_courier"] = function() 
		if CanUseItem("item_courier") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_courier"))
			if Bot:DistanceFromFountain() < 1000 then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_dust"] = function() 
		if CanUseItem("item_dust") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_dust"))
			local Target = Bot:GetTarget()
			local range = item:GetCastRange()
			if Target ~= nil and Target:IsInvisible() and not Target:HasModifier("modifier_item_dustofappearance") and Bot:GetActiveMode() == BOT_MODE_ATTACK and Target:IsHero() then
				if GetUnitToUnitDistance(Bot,Target) < range then
					Bot:Action_UseAbility(item)
					return
				end
			end
		end
	end
	,
	["item_bottle"] = function() 
		if CanUseItem("item_bottle") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_bottle"))
			local range = item:GetCastRange()
			local Healthregen = item:GetSpecialValueInt("health_restore")
			local Manaregen = item:GetSpecialValueInt("mana_restore")

			if item:GetCurrentCharges() > 0 then
				if Bot:GetBotRole().support ~= nil and Bot:GetBotRole().support > 0 then
					for _,v in pairs(Bot:GetNearbyHeroes(range*2,false,BOT_MODE_NONE)) do
						if v:GetTeam() == Bot:GetTeam() and v:IncommingProjectiles() == 0 and CanCastOnTarget(v) then
							if v:GetHealth() + Healthregen < v:GetMaxHealth() and v:GetMana() + Manaregen < v:GetMaxMana() or ((v:GetMaxMana()/100) * v:GetMana() <= 10 or (v:GetMaxHealth()/100) * v:GetHealth() <= 10) then
								Bot:Action_UseAbilityOnEntity(item,v)
								return
							end
						end
					end
				end
				if Bot:IncommingProjectiles() == 0 and CanCastOnTarget(Bot) then
					if Bot:GetHealth() + Healthregen < Bot:GetMaxHealth() and Bot:GetMana() + Manaregen < Bot:GetMaxMana() or ((Bot:GetMaxMana()/100) * Bot:GetMana() <= 10 or (Bot:GetMaxHealth()/100) * Bot:GetHealth() <= 10)  then
						Bot:Action_UseAbilityOnEntity(item,Bot)
						return
					end
				end
				if Bot:HasModifier("modifier_fountain_aura") and (Bot:GetHealth() < Bot:GetMaxHealth() or Bot:GetMana() < Bot:GetMaxMana()) and CanCastOnTarget(Bot) then
					if not Bot:HasModifier("modifier_bottle_regeneration") then
						Bot:Action_UseAbilityOnEntity(item,Bot)
						return
					else
						local heroes = Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)
						for _,v in pairs(heroes) do
							if not v:HasModifier("modifier_bottle_regeneration") and (v:GetHealth() < v:GetMaxHealth() or v:GetMana() < v:GetMaxMana() ) and CanCastOnTarget(v) then
								Bot:Action_UseAbilityOnEntity(item,v)
								return
							end
						end
					end
				end
			end
		end
	end
	,

	--[[
	if CanUseItem("item_quelling_blade") then
		item = Bot:GetItemInSlot(Bot:FindItemSlot("item_quelling_blade"))
		 -- Do Whatever?
	end
	if CanUseItem("item_bfury") then
		item = Bot:GetItemInSlot(Bot:FindItemSlot("item_bfury"))
		 -- Do Whatever?
	end
	]]
	["item_magic_wand"] = function() 
		if CanUseItem("item_magic_wand") then -- 1st wand, than Stick (maby the bot will waste charges if he got both!)
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_magic_wand"))
			local regenPerCharge = item:GetSpecialValueInt("restore_per_charge")
			local charges = item:GetCurrentCharges()
			local regen = charges*regenPerCharge
			if charges > 0 then
				if Bot:GetActiveMode() == BOT_MODE_RETREAT and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_MODERATE then 
					Bot:Action_UseAbility(item)
					return
				else
					if Bot:GetHealth() + regen < Bot:GetMaxHealth() and Bot:GetMana() + regen < Bot:GetMaxMana() or ((Bot:GetMaxMana()/100) * Bot:GetMana() <= 20 or (Bot:GetMaxHealth()/100) * Bot:GetHealth() <= 40) then
						Bot:Action_UseAbility(item)
						return
					elseif Bot:GetMana()/Bot:GetMaxMana() - Bot:GetHealth()/Bot:GetMaxHealth() <= 1 and charges >= 10 then
						Bot:Action_UseAbility(item)
						return
					end
				end
			end
		end
	end
	,
	["item_magic_stick"] = function() 
		if CanUseItem("item_magic_stick") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_magic_stick"))
			local regenPerCharge = item:GetSpecialValueInt("restore_per_charge")
			local charges = item:GetCurrentCharges()
			local regen = charges*regenPerCharge
			if charges > 0 then
				if Bot:GetActiveMode() == BOT_MODE_RETREAT and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_MODERATE then 
					Bot:Action_UseAbility(item)
					return
				else
					if Bot:GetHealth() + regen < Bot:GetMaxHealth() and Bot:GetMana() + regen < Bot:GetMaxMana() or ((Bot:GetMaxMana()/100) * Bot:GetMana() <= 20 or (Bot:GetMaxHealth()/100) * Bot:GetHealth() <= 40) then
						Bot:Action_UseAbility(item)
						return
					elseif Bot:GetMana()/Bot:GetMaxMana() - Bot:GetHealth()/Bot:GetMaxHealth() <= 1 and charges >= 6 then
						Bot:Action_UseAbility(item)
						return
					end
				end
			end
		end
	end
	,
	["item_ghost"] = function() 
		if CanUseItem("item_ghost") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_ghost"))
			local bonusMagicDamage = item:GetSpecialValueInt("extra_spell_damage_percent")
			
			local damage = Bot:GetIncommingDamage()

			damage.Magic = damage.Magic + ((damage.Magic/100)*bonusMagicDamage)

			local MaxDamage = (Bot:GetMaxHealth()/100)*30
			if MaxDamage > 500 then MaxDamage = 500 end

			if damage.Physic > MaxDamage and damage.Magic+MaxDamage/2 < damage.Physic then
				Bot:Action_UseAbility(item)
				return
			end

			if Bot:GetActiveMode() == BOT_MODE_RETREAT and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_blink"] = function() 
		if CanUseItem("item_blink") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_blink"))
			local range = item:GetSpecialValueInt("blink_range")
			local FrontPos = Bot:GetForwardVector()
			if Bot:GetActiveMode() == BOT_MODE_RETREAT and Bot:GetActiveModeDesire() >= BOT_ACTION_DESIRE_MODERATE then -- Running away and got blink ready, BLINK!
				Bot:Action_UseAbilityOnLocation(item, Bot:GetLocation()+FrontPos*range)
				return
			elseif Bot:IsStuck() then
				Bot:Action_UseAbilityOnLocation(item, Bot:GetLocation()+FrontPos*range/2)
				return
			end
			--[[
				elseif (Bot:GetActiveMode() == BOT_MODE_ATTACK or Bot:GetActiveMode() == BOT_MODE_ROAM or Bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or Bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or Bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOT or Bot:GetActiveMode() == BOT_MODE_TEAM_ROAM or Bot:GetActiveMode() == BOT_MODE_DEFEND_ALLY) and Bot:GetActiveModeDesire() >= BOT_ACTION_DESIRE_MODERATE then 
				local locationAoE = Bot:FindAoELocation( true, true, Bot:GetLocation(), range, 500, 0, 0 )
				if locationAoE.count >= 2 then
					Bot:Action_UseAbilityOnLocation( item, locationAoE.targetloc )
					return
				elseif locationAoE.count == 1 then
					local Target = Bot:GetTarget()
					if Target ~= nil then
						local rangeLeft = range-GetUnitToUnitDistance(Bot,Target)
						local Blinkpos = Target:GetLocation() + Target:GetForwardVector()*rangeLeft
						Bot:Action_UseAbilityOnLocation(item, Blinkpos)
					end
				end
			]]
		end
	end
	,
	["item_soul_ring"] = function() 
		if CanUseItem("item_soul_ring") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_soul_ring"))
			local healtCost = item:GetSpecialValueInt("health_sacrifice")
			local manaGain = item:GetSpecialValueInt("mana_gain")
			if Bot:NeedMana() then
				if Bot:GetHealth() - healtCost > 400 then
					Bot:Action_UseAbility(item)
					return
				end
			end
		end
	end
	,
	["item_ward_observer"] = function() 
		if CanUseItem("item_ward_observer") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_ward_observer"))
			if Bot:GetActiveMode() == BOT_MODE_WARD then
				-- Simply randomize the waring pos (If we are not wardin a valid pos already!)
				-- Ward Placement moved to 'mode_ward_generic' due not working for bots under the difficult 'hard'!
				if Bot.IsWarding == nil or Bot.IsWarding == false or ( Bot.WardPos ~= nil and IsWardedPos(Bot.WardPos))  then
					local WardSpot,Distance = Bot:GetNearestWardSpot()
					if WardSpot ~= nil then
						Bot.IsWarding = true
						Bot.WardPos = WardSpot
					end
				elseif Bot.WardPos == nil then
					Bot.IsWarding = false
				end
			end
		end
	end
	,
	["item_phase_boots"] = function() 
		if CanUseItem("item_phase_boots") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_phase_boots"))
			if Bot:Mode(BOT_MODE_EVASIVE_MANEUVERS,BOT_MODE_DEFEND_ALLY,BOT_MODE_ATTACK,BOT_MODE_RETREAT,BOT_MODE_ROAM,BOT_MODE_TEAM_ROAM) then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_power_treads"] = function() -- Mostly, its hardly buggy in the retreat... buy why?
		if CanUseItem("item_power_treads") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_power_treads"))
			if Bot:Mode(BOT_MODE_RETREAT) and item:GetPowerTreadsStat() ~= ATTRIBUTE_STRENGTH and Bot:WasRecentlyDamagedByAnyHero(5.0) then
				Bot:Action_UseAbility(item)
				return
			elseif mode == BOT_MODE_ATTACK and CanSwitchPTStat(item) then
				Bot:Action_UseAbility(item)
				return
			else
				local enemies = Bot:GetNearbyHeroes( 1300, true, BOT_MODE_NONE )
				if #enemies == 0 and  mode ~= BOT_MODE_RETREAT and CanSwitchPTStat(item)  then
					Bot:Action_UseAbility(item)
					return
				end
			end
		end
	end
	,
	["item_hand_of_midas"] = function()
		if CanUseItem("item_hand_of_midas") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_hand_of_midas"))
			local range = item:GetCastRange()
			local creeps = Bot:GetNearbyCreeps(range,true)
			if creeps > 0 then
				Bot:Action_UseAbilityOnEntity(item,creeps[1])
			else -- No creeps Search for neutrals
				creeps = Bot:GetNearbyNeutralCreeps(range)
				if creeps > 0 then
					Bot:Action_UseAbilityOnEntity(item,creeps[1])
				end
			end
		end
	end
	,
	["item_ring_of_basilius"] = function()
		if CanUseItem("item_ring_of_basilius") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_ring_of_basilius"))
			if Bot:Mode(BOT_MODE_LANING) and not item:GetToggleState() then
				Bot:Action_UseAbility(item)
				return
			elseif not Bot:Mode(BOT_MODE_LANING) and item:GetToggleState() then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_ring_of_aquila"] = function()
		if CanUseItem("item_ring_of_aquila") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_ring_of_aquila"))
			if Bot:Mode(BOT_MODE_LANING) and not item:GetToggleState() then
				Bot:Action_UseAbility(item)
				return
			elseif not Bot:Mode(BOT_MODE_LANING) and item:GetToggleState() then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_buckler"] = function()
		if CanUseItem("item_buckler") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_buckler"))
			local range = item:GetCastRange()
			if Bot:Mode(BOT_MODE_ATTACK,BOT_MODE_RETREAT,BOT_MODE_EVASIVE_MANEUVERS) then
				Bot:Action_UseAbility(item)
				return
			elseif Bot:Mode(BOT_MODE_DEFEND_ALLY) and #Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE) > 0 then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_urn_of_shadows"] = function()
		if CanUseItem("item_urn_of_shadows") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_urn_of_shadows"))
			if item:GetCurrentCharges() == 0 then return end
			local range = item:GetCastRange()
			local heal = item:GetSpecialValueInt("soul_heal_amount")
			local damage = item:GetSpecialValueInt("soul_damage_amount")
			local duration = item:GetSpecialValueFloat("duration")

			local totalHeal = heal * duration
			local totalDamage = damage * duration
			if Bot:Mode(BOT_MODE_ATTACK) then
				local enemies = Bot:GetNearbyHeroes(range,true,BOT_MODE_NONE)
				for _,v in pairs(enemies) do
					if v:GetHealth() - totalDamage + v:GetHealthRegen() * duration < 200 and CanCastOnTarget(v) then
						Bot:Action_UseAbilityOnEntity(item,v)
						return
					end
				end
				return
			else
				local ally = Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)
				for _,v in pairs(ally) do
					if v:GetHealth() + totalHeal + v:GetHealthRegen() * duration < v:GetMaxHealth() and CanCastOnTarget(v) then
						Bot:Action_UseAbilityOnEntity(item,v)
						return
					end
				end
				return
			end
		end
	end
	,
	["item_medallion_of_courage"] = function()
		if CanUseItem("item_medallion_of_courage") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_medallion_of_courage"))
			local range = item:GetCastRange()
			-- Not use but they are here )
			local selfArmor = item:GetSpecialValueInt("armor_reduction") -- Is negativ!!
			local allyArmor = item:GetSpecialValueInt("bonus_armor")

			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				local enemies = Bot:GetNearbyHeroes(range,true,BOT_MODE_NONE)
				for _,v in pairs(enemies) do
					if v == Bot:GetTarget() and CanCastOnTarget(v) then
						Bot:Action_UseAbilityOnEntity(item,v)
						return
					end
				end
				return
			elseif Bot:Mode(BOT_MODE_DEFEND_ALLY) and (Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH or (Bot:Mode(BOT_MODE_DEFEND_ALLY) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_LOW and Bot:GetBotRole().support > 0)) then
				local ally = Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)
				for _,v in pairs(ally) do
					if CanCastOnTarget(v) then
						Bot:Action_UseAbilityOnEntity(item,v)
						return
					end
				end
				return
			end
		end
	end
	,
	["item_arcane_boots"] = function()
		if CanUseItem("item_arcane_boots") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_arcane_boots"))
			local range = item:GetCastRange()
			local manaGain = item:GetSpecialValueInt("replenish_amount")

			local MissingMana = Bot:GetMaxMana() - Bot:GetMana()

			local ally = Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)
			for _,v in pairs(ally) do
				MissingMana = MissingMana + v:GetMaxMana() - v:GetMana()
			end

			if MissingMana >= 400 or Bot:NeedMana() then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_ancient_janggo"] = function()
		if CanUseItem("item_ancient_janggo") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_ancient_janggo"))
			if item:GetCurrentCharges() <= 0 then return end
			local range = item:GetCastRange()

			local retreating = 0

			local ally = Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)
			for _,v in pairs(ally) do
				if v:Mode(BOT_MODE_RETREAT) and v:GetActiveModeDesire() >= BOT_MODE_DESIRE_MODERATE then
					retreating = retreating + BOT_MODE_DESIRE_MODERATE
				end
			end

			if retreating >= 1.25 then
				Bot:Action_UseAbility(item)
				return
			end

			if Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_mekansm"] = function()
		if CanUseItem("item_mekansm") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_mekansm"))
			local range = item:GetCastRange()
			local heal = item:GetSpecialValueInt("heal_amount")

			local missingHealth = 0
			if not Bot:HasModifier("modifier_item_mekansm_noheal") then
				missingHealth = Bot:GetMaxHealth() - Bot:GetHealth()
			end

			local ally = Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)
			for _,v in pairs(ally) do
				if not v:HasModifier("modifier_item_mekansm_noheal") then
					missingHealth = v:GetMaxHealth() - v:GetHealth()
				end
			end

			if missingHealth >= 650 then
				Bot:Action_UseAbility(item)
				return
			end

			if Bot:Mode(BOT_MODE_RETREAT)and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and not Bot:HasModifier("modifier_item_mekansm_noheal") and Bot:GetHealth()+heal < Bot:GetMaxHealth() then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_spirit_vessel"] = function() -- Stolen from Ranked Matchmaking AI :3
		if CanUseItem("item_spirit_vessel") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_spirit_vessel"))
			local range = item:GetCastRange()
			if item:GetCurrentCharges() > 0 then
				if Bot:Mode(BOT_MODE_ROAM,BOT_MODE_TEAM_ROAM,BOT_MODE_DEFEND_ALLY,BOT_MODE_ATTACK) then	
					local Target = Bot:GetTarget()
					if Target ~= nil and Target:IsHero() and CanCastOnTarget(Target) and GetUnitToUnitDistance(Bot, Target) < range and not Target:HasModifier("modifier_item_spirit_vessel_damage") and Target:GetHealth()/Target:GetMaxHealth() < 0.65 then
						Bot:Action_UseAbilityOnEntity(item, Target)
						return
					end
				else
					local Allies=Bot:GetNearbyHeroes(1150,false,BOT_MODE_NONE)
					local NearbyEnemyHero = Bot:GetNearbyHeroes(1550,true,BOT_MODE_NONE)
					for _,Ally in pairs(Allies) do
						if Ally:HasModifier('modifier_item_spirit_vessel_heal') == false and CanCastOnTarget(Ally) and Ally:GetHealth()/Ally:GetMaxHealth() < 0.35 and #NearbyEnemyHero == 0 and Ally:WasRecentlyDamagedByAnyHero(2.5) == false then
							Bot:Action_UseAbilityOnEntity(item,Ally)
							return
						end
					end
				end
			end
		end
	end
	,
	["item_pipe"] = function() -- TODO: Make this better!
		if CanUseItem("item_pipe") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_pipe"))
			local range = item:GetCastRange()
			if Bot:Mode(BOT_MODE_DEFEND_ALLY,BOT_MODE_ATTACK,BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_MODERATE then	
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_guardian_greaves"] = function()
		if CanUseItem("item_guardian_greaves") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_guardian_greaves"))
			local range = item:GetCastRange()
			local heal = item:GetSpecialValueInt("heal_amount")

			local MissingMana = Bot:GetMaxMana() - Bot:GetMana()

			local MissingHealth = 0
			if not Bot:HasModifier("modifier_item_mekansm_noheal") then
				MissingHealth = Bot:GetMaxHealth() - Bot:GetHealth()
			end

			local ally = Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)
			for _,v in pairs(ally) do
				MissingMana = MissingMana + v:GetMaxMana() - v:GetMana()
				if not v:HasModifier("modifier_item_mekansm_noheal") then
					MissingHealth = v:GetMaxHealth() - v:GetHealth()
				end
			end

			if MissingHealth+MissingMana >= 1150 then
				Bot:Action_UseAbility(item)
				return
			end

			if Bot:Mode(BOT_MODE_RETREAT)and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and not Bot:HasModifier("modifier_item_mekansm_noheal") and Bot:GetHealth()+heal < Bot:GetMaxHealth() then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_glimmer_cape"] = function()
		if CanUseItem("item_guardian_greaves") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_guardian_greaves"))
			local range = item:GetCastRange()

			if Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				Bot:Action_UseAbilityOnEntity(item,Bot)
				return
			end

			local ally = Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)
			for _,v in pairs(ally) do
				if v:Mode(BOT_MODE_RETREAT) and v:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
					Bot:Action_UseAbilityOnEntity(item,v)
					return
				end
			end
		end
	end
	,
	["item_veil_of_discord"] = function()
		if CanUseItem("item_veil_of_discord") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_veil_of_discord"))
			local range = item:GetCastRange()
			local radius = item:GetSpecialValueInt("debuff_radius")

			if Bot:Mode(BOT_MODE_ATTACK,BOT_MODE_ROAM,BOT_MODE_DEFEND_TOWER_TOP,BOT_MODE_DEFEND_TOWER_MID,BOT_MODE_DEFEND_TOWER_BOT,BOT_MODE_TEAM_ROAM) and Bot:GetActiveModeDesire() >= BOT_ACTION_DESIRE_MODERATE then
				local locationAoE = Bot:FindAoELocation( true, true, Bot:GetLocation(), range, radius, 0, 0 )
				if locationAoE.count >= 2 then
					Bot:Action_UseAbilityOnLocation( item, locationAoE.targetloc )
					return
				end
			end
		end
	end
	,
	["item_force_staff"] = function()
		if CanUseItem("item_force_staff") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_force_staff"))
			local range = item:GetCastRange()
			local force = item:GetSpecialValueInt("push_length")

			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_ACTION_DESIRE_MODERATE then
				local Target = Bot:GetTarget()
				if Target == nil or not Target:IsHero() or Target:IsInvulnerable() then return end -- Sad but true, it can be nil
				local Distance = GetUnitToUnitDistance(Bot,Target)
				if (Distance - force >= 300 or force - Distance >= 300) and Bot:IsFacingLocation(Target:GetLocation(),10) then
					Bot:Action_UseAbilityOnEntity( item, Bot )
					return
				end
			end

			if Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_ACTION_DESIRE_HIGH then
				if IsLocationPassable(Bot:GetXUnitsInFront(force)) then
					Bot:Action_UseAbilityOnEntity( item, Bot )
					return
				end
			end
		end
	end
	,
	-- TODO: Necronomicon
	["item_solar_crest"] = function()
		if CanUseItem("item_solar_crest") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_solar_crest"))
			local range = item:GetCastRange()
			-- Not use but they are here )

			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				local enemies = Bot:GetNearbyHeroes(range,true,BOT_MODE_NONE)
				for _,v in pairs(enemies) do
					if v == Bot:GetTarget() and CanCastOnTarget(v) then
						Bot:Action_UseAbilityOnEntity(item,v)
						return
					end
				end
				return
			elseif Bot:Mode(BOT_MODE_DEFEND_ALLY) and (Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH or (Bot:Mode(BOT_MODE_DEFEND_ALLY) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_LOW and Bot:GetBotRole().support > 0)) then
				local ally = Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)
				for _,v in pairs(ally) do
					if CanCastOnTarget(v) then
						Bot:Action_UseAbilityOnEntity(item,v)
						return
					end
				end
				return
			end
		end
	end
	,
	-- TODO: Dagon
	["item_cyclone"] = function()
		if CanUseItem("item_cyclone") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_cyclone"))
			local range = item:GetCastRange()
			local Target = Bot:GetTarget()

			local Modifiers = (
					Target ~= nil and ( 
						Target:HasModifier("modifier_teleporting") or 
						Target:HasModifier("modifier_abaddon_borrowed_time") or
						Target:HasModifier("modifier_nevermore_requiem") or
						Target:HasModifier("modifier_alchemist_chemical_rage") or
						Target:HasModifier("modifier_batrider_flaming_lasso_self") or
						Target:HasModifier("modifier_dark_seer_surge") or
						Target:HasModifier("modifier_dazzle_shallow_grave") or
						Target:HasModifier("modifier_spirit_breaker_nether_strike") or
						Target:HasModifier("modifier_spirit_breaker_charge_of_darkness") or
						Target:HasModifier("modifier_legion_commander_duel") or
						Target:HasModifier("modifier_magnataur_skewer_movement") or
						Target:HasModifier("modifier_medusa_stone_gaze") or
						Target:HasModifier("modifier_slark_pounce") or
						Target:HasModifier("modifier_visage_grave_chill_buff") or
						Target:HasModifier("modifier_winter_wyvern_arctic_burn_flight") or
						Target:HasModifier("modifier_item_forcestaff_active") or
						Target:HasModifier("modifier_item_ethereal_blade_ethereal") or
						Target:HasModifier("modifier_item_lotus_orb_active") or -- We will euls ourself, but save the other team (if they cast spells on this)
						Target:HasModifier("modifier_item_sphere") or
						Target:HasModifier("modifier_item_sphere_target") or 
						Target:HasModifier("modifier_lycan_shapeshift_transform") or
						Target:IsChanneling() or (Target:IsCastingAbility() and Target:GetCurrentActiveAbility():GetCastPoint() > 0.5)
					)
				)



			if Modifiers and not Target:HasModifier("modifier_rod_of_atos_debuff") and CanCastOnTarget(Target) and GetUnitToUnitDistance(Bot, Target) < range+200 then
				Bot:Action_UseAbilityOnEntity(item, Target)
				return
			end

			local Mult = Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire()*5 or 1

			if Bot:GetIncommingDamage().All > 500*Mult then
				Bot:Action_UseAbilityOnEntity(item, BOT)
				return
			end
		end
	end
	,
	["item_rod_of_atos"] = function()
		if CanUseItem("item_rod_of_atos") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_rod_of_atos"))
			local range = item:GetCastRange()
			local Target = Bot:GetTarget()
			if Target == nil or not Target:IsHero() or Target:IsInvulnerable() then return end
			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and GetUnitToUnitDistance(Bot, Target) < range+300 and CanCastOnTarget(Target) then
				Bot:Action_UseAbilityOnEntity(item, Target)
				return
			end
		end
	end
	,
	["item_orchid"] = function()
		if CanUseItem("item_orchid") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_orchid"))
			local range = item:GetCastRange()
			local Target = Bot:GetTarget()
			if Target == nil or not Target:IsHero() or Target:IsInvulnerable() then return end
			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and GetUnitToUnitDistance(Bot, Target) < range/1.5 and Target:GetHealth()/ Taget:GetMaxHealth() > 0.5 and CanCastOnTarget(Target) then
				Bot:Action_UseAbilityOnEntity(item, Target)
				return
			end
		end
	end
	,
	["item_nullifier"] = function()
		if CanUseItem("item_nullifier") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_nullifier"))
			local range = item:GetCastRange()
			local Target = Bot:GetTarget()
			if range > Bot:GetAttackRange() then
				range = Bot:GetAttackRange()
			end
			if Target == nil or not Target:IsHero() or Target:IsInvulnerable() then return end
			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and GetUnitToUnitDistance(Bot, Target) < range and CanCastOnTarget(Target) then
				Bot:Action_UseAbilityOnEntity(item, Target)
				return
			end
		end
	end
	,-- Refresher and RefresherShard are Only unit specific
	["item_sheepstick"] = function()
		if CanUseItem("item_sheepstick") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_sheepstick"))
			local range = item:GetCastRange()
			local Target = Bot:GetTarget()

			if Target == nil or not Target:IsHero() or Target:IsInvulnerable() then return end -- Sad but true, it can be nil

			local Modifiers = (
				not Target:HasModifier("modifier_dark_seer_surge") and
				not Target:HasModifier("modifier_rune_haste") and
				not Target:HasModifier("modifier_weaver_shukuchi") and
				not Target:HasModifier("modifier_lycan_shapeshift_speed") and
				not Target:HasModifier("modifier_lycan_shapeshift")
			)

			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and GetUnitToUnitDistance(Bot, Target) < range and CanCastOnTarget(Target) then
				Bot:Action_UseAbilityOnEntity(item, Target)
				return
			end
		end
	end
	,
	["item_hood_of_defiance"] = function()
		if CanUseItem("item_hood_of_defiance") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_hood_of_defiance"))
			local MagicBlock = item:GetSpecialValueInt("barrier_block")
			if Bot:GetIncommingDamage().Magic > MagicBlock then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_blade_mail"] = function()
		if CanUseItem("item_blade_mail") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_blade_mail"))
			if Bot:GetIncommingDamage().All > 500 then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_crimson_guard"] = function()
		if CanUseItem("item_crimson_guard") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_blade_mail"))
			if Bot:Mode(BOT_MODE_ATTACK,BOT_MODE_RETREAT,BOT_MODE_PUSH_TOWER_TOP,BOT_MODE_PUSH_TOWER_MID,BOT_MODE_PUSH_TOWER_BOT,BOT_MODE_DEFEND_ALLY) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_MODERATE and #Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE) >= 2 then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_crimson_guard"] = function()
		if CanUseItem("item_crimson_guard") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_blade_mail"))
			if Bot:Mode(BOT_MODE_ATTACK,BOT_MODE_RETREAT,BOT_MODE_PUSH_TOWER_TOP,BOT_MODE_PUSH_TOWER_MID,BOT_MODE_PUSH_TOWER_BOT,BOT_MODE_DEFEND_ALLY) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_MODERATE and #Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE) >= 2 then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_black_king_bar"] = function()
		if CanUseItem("item_black_king_bar") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_black_king_bar"))
			if Bot:Mode(BOT_MODE_ATTACK,BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_VERYHIGH  and Bot:WasRecentlyDamagedByAnyHero(1) and #Bot:GetNearbyHeroes(1200,true,BOT_MODE_NONE) >= 2 then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_lotus_orb"] = function()
		if CanUseItem("item_lotus_orb") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_lotus_orb"))
			local range = item:GetCastRange()
			local MaxTargets = 0
			local ally = nil

			local TargetDamage = 0

			for _,v in pairs(Bot:GetNearbyHeroes(1000,true,BOT_MODE_NONE)) do
				if v:GetCurrentActiveAbility() ~= nil then
					local ability = v:GetCurrentActiveAbility()
				end
			end


			for _,v in pairs(Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)) do
				if not v.GetLotusOrb and not v:HasModifier("modifier_item_lotus_orb_active") and not v.UseManta then
					if v:HasModifier("modifier_lina_laguna_blade") or v:HasModifier("modifier_lion_finger_of_death") then
						TargetDamage = TargetDamage + 3
					end
					for _,Value in pairs(v:GetIncomingTrackingProjectiles()) do
						if Value.ability ~= nil and not Bot:IsMyTeam(Value.caster) then
							if (
								(Value.ability:GetName() == "sniper_assassinate" and GetUnitToLocationDistance(Bot,Value.location) < 2500/3 and not Value.caster:HasScepter()) or 
								(Value.ability:GetName() == "lich_chain_frost" and GetUnitToLocationDistance(Bot,Value.location) < 850/3) or 
								(Value.ability:GetName() == "enchantress_impetus" and GetUnitToLocationDistance(Bot,Value.location) < 900/3) or -- Enchantress Projectile speed!
								(Value.ability:GetName() == "gyrocopter_homing_missile" and GetUnitToLocationDistance(Bot,Value.location) < 700/3) or -- 500 +- acceleration
								(Value.ability:GetName() == "huskar_life_break" and GetUnitToLocationDistance(Bot,Value.location) < 1200/3) or
								(Value.ability:GetName() == "lina_laguna_blade" and GetUnitToLocationDistance(Bot,Value.location) < 10000/3) or -- Actually its dogeable (confirmed with manta) but it got no speed!
								(Value.ability:GetName() == "lion_finger_of_death" and GetUnitToLocationDistance(Bot,Value.location) < 10000/3) or -- Same here, its dogeable but it hase no speed. (Dunno if both are still linear particle)
								(Value.ability:GetName() == "morphling_adaptive_strike_agi" and GetUnitToLocationDistance(Bot,Value.location) < 1150/3) or
								(Value.ability:GetName() == "morphling_adaptive_strike_str" and GetUnitToLocationDistance(Bot,Value.location) < 1150/3) or
								(Value.ability:GetName() == "tinker_heat_seeking_missile" and GetUnitToLocationDistance(Bot,Value.location) < 700/3) or
								(Value.ability:GetName() == "tusk_snowball" and GetUnitToLocationDistance(Bot,Value.location) < 675/3)
								) then
								TargetDamage = TargetDamage+1
							end
						end
					end
				end
				if TargetDamage > MaxTargets then
					MaxTargets = TargetDamage
					ally = v
				end
			end
			TargetDamage = 0
			if not Bot.GetLotusOrb and not Bot:HasModifier("modifier_item_lotus_orb_active") and not Bot.UseManta then
				if Bot:HasModifier("modifier_lina_laguna_blade") or Bot:HasModifier("modifier_lion_finger_of_death") then
					TargetDamage = TargetDamage + 3
				end
				for _,v in pairs(Bot:GetIncomingTrackingProjectiles()) do
					if v.ability ~= nil and not Bot:IsMyTeam(v.caster) then
						if (
							(v.ability:GetName() == "sniper_assassinate" and GetUnitToLocationDistance(Bot,v.location) < 2500/3 and not v.caster:HasScepter()) or 
							(v.ability:GetName() == "lich_chain_frost" and GetUnitToLocationDistance(Bot,v.location) < 850/3) or 
							(v.ability:GetName() == "enchantress_impetus" and GetUnitToLocationDistance(Bot,v.location) < 900/3) or -- Enchantress Projectile speed!
							(v.ability:GetName() == "gyrocopter_homing_missile" and GetUnitToLocationDistance(Bot,v.location) < 700/3) or -- 500 +- acceleration
							(v.ability:GetName() == "huskar_life_break" and GetUnitToLocationDistance(Bot,v.location) < 1200/3) or
							(v.ability:GetName() == "lina_laguna_blade" and GetUnitToLocationDistance(Bot,v.location) < 10000/3) or -- Actually its dogeable (confirmed with manta) but it got no speed!
							(v.ability:GetName() == "lion_finger_of_death" and GetUnitToLocationDistance(Bot,v.location) < 10000/3) or -- Same here, its dogeable but it hase no speed. (Dunno if both are still linear particle)
							(v.ability:GetName() == "morphling_adaptive_strike_agi" and GetUnitToLocationDistance(Bot,v.location) < 1150/3) or
							(v.ability:GetName() == "morphling_adaptive_strike_str" and GetUnitToLocationDistance(Bot,v.location) < 1150/3) or
							(v.ability:GetName() == "tinker_heat_seeking_missile" and GetUnitToLocationDistance(Bot,v.location) < 700/3) or
							(v.ability:GetName() == "tusk_snowball" and GetUnitToLocationDistance(Bot,v.location) < 675/3)
							) then
							TargetDamage = TargetDamage+1
						end
					end
				end
			end
			if TargetDamage > MaxTargets then
				MaxTargets = TargetDamage
				ally = Bot
			end

			if ally ~= nil then
				ally.GetLotusOrb = true
				Bot:Action_UseAbilityOnEntity(item,ally)
				return
			end
		end
	end
	,
	["item_shivas_guard"] = function()
		if CanUseItem("item_shivas_guard") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_shivas_guard"))
			local range = item:GetCastRange()
			local Target = Bot:GetTarget()
			if Target == nil or not Target:IsHero() or Target:IsInvulnerable() then return end 

			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and GetUnitToUnitDistance(Target,Bot) < range/1.5 then
				Bot:Action_UseAbility(item)
				return
			end

			if Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and #Bot:GetNearbyHeroes(range,true,BOT_MODE_NONE) >= 1 then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_hurricane_pike"] = function()
		if CanUseItem("item_hurricane_pike") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_hurricane_pike"))
			local range = item:GetCastRange()
			local force = item:GetSpecialValueInt("push_length")

			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_ACTION_DESIRE_MODERATE then
				local Target = Bot:GetTarget()
				if Target == nil or not Target:IsHero() or Target:IsInvulnerable() then return end
				local Distance = GetUnitToUnitDistance(Bot,Target)
				if (Distance - force >= 300 or force - Distance >= 300) and Bot:IsFacingLocation(Target:GetLocation(),10) then
					Bot:Action_UseAbilityOnEntity( item, Bot )
					return
				end
			end

			if Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_ACTION_DESIRE_HIGH then
				if IsLocationPassable(Bot:GetXUnitsInFront(force)) then
					Bot:Action_UseAbilityOnEntity( item, Bot )
					return
				end
			end

			-- TODO: Use on enemy's to gain the attackrange! (should this be unit specific?) EDIT: Yap it MUST BE unit specific! 
		end
	end
	,
	["item_bloodstone"] = function()
		if CanUseItem("item_bloodstone") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_bloodstone"))
			if Bot:GetIncommingDamage().All*2 > Bot:GetHealth() or (Bot:GetHealth() < 250 and #Bot:GetNearbyHeroes(1000,true,BOT_MODE_NONE) >= 2) then
				Bot:Action_UseAbilityOnLocation(item,Bot:GetLocation())
			end
		end
	end
	,
	["item_manta"] = function()
		if CanUseItem("item_manta") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_manta"))

			if Bot:HasModifier("modifier_lina_laguna_blade") or Bot:HasModifier("modifier_lion_finger_of_death") then -- Yap, exactly! Its dogeable with a reaction of 0.25 secs!
				Bot:Action_UseAbility(item)
				Bot.UseManta = true
			end

			for _,v in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
				if v:GetUnitName() == "npc_dota_gyrocopter_homing_missile" then -- Get units like gyro rocket
					print(GetUnitToUnitDistance(Bot,v))
					if GetUnitToUnitDistance(Bot,v) < 200 then
						print(Bot:GetUnitName().." uses manta during damages by gyro rocket")
						Bot:Action_UseAbility(item)
						Bot.UseManta = true
					end
				end
			end

			for _,v in pairs(Bot:GetIncomingTrackingProjectiles()) do -- Dodge high-damage projectiles (Sniper ult, ...)
				if v.ability ~= nil and not Bot:IsMyTeam(v.player) then
					if (
						(v.ability:GetName() == "sniper_assassinate" and GetUnitToLocationDistance(Bot,v.location) < 2500/3) or 
						(v.ability:GetName() == "lich_chain_frost" and GetUnitToLocationDistance(Bot,v.location) < 850/3) or 
						(v.ability:GetName() == "enchantress_impetus" and GetUnitToLocationDistance(Bot,v.location) < 900/3) or -- Enchantress Projectile speed!
						(v.ability:GetName() == "huskar_life_break" and GetUnitToLocationDistance(Bot,v.location) < 1200/3) or
						(v.ability:GetName() == "morphling_adaptive_strike_agi" and GetUnitToLocationDistance(Bot,v.location) < 1150/3) or
						(v.ability:GetName() == "morphling_adaptive_strike_str" and GetUnitToLocationDistance(Bot,v.location) < 1150/3) or
						(v.ability:GetName() == "tinker_heat_seeking_missile" and GetUnitToLocationDistance(Bot,v.location) < 700/3) or
						(v.ability:GetName() == "tusk_snowball" and GetUnitToLocationDistance(Bot,v.location) < 675/3)
						) then
						Bot:Action_UseAbility(item)
						Bot.UseManta = true
					end
				end
			end
			
			if Bot:Mode(BOT_MODE_PUSH_TOWER_TOP, BOT_MODE_PUSH_TOWER_MID, BOT_MODE_PUSH_TOWER_BOT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				Bot:Action_UseAbility(item)
			end
		end
	end
	,
	["item_sphere"] = function()
		if CanUseItem("item_sphere") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_sphere"))
			local range = item:GetCastRange()
			local MaxTargets = 0
			local ally = nil

			local TargetDamage = 0
			for _,v in pairs(Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)) do
				if not v:HasModifier("modifier_item_sphere_target") and not v:HasModifier("modifier_item_sphere") and not v.GetSpellShield and not v.UseManta then
					if v:HasModifier("modifier_lina_laguna_blade") or v:HasModifier("modifier_lion_finger_of_death") then
						TargetDamage = TargetDamage + 3
					end
					for _,Value in pairs(v:GetIncomingTrackingProjectiles()) do
						if Value.ability ~= nil then -- Dont realized that GetAbilityDamage() dont work in this case... Use known ability names 
							if ( Value.ability:GetName() == "sniper_assassinate" and not v.caster:HasScepter()) or 
									Value.ability:GetName() == "lich_chain_frost" or 
									Value.ability:GetName() == "enchantress_impetus" or 
									Value.ability:GetName() == "gyrocopter_homing_missile" or
									Value.ability:GetName() == "huskar_life_break" or
									Value.ability:GetName() == "morphling_adaptive_strike_agi" or
									Value.ability:GetName() == "morphling_adaptive_strike_str" or
									Value.ability:GetName() == "tinker_heat_seeking_missile" or
									Value.ability:GetName() == "tusk_snowball" then
								TargetDamage = TargetDamage + 1
							end
						end
					end
				end
				if TargetDamage > MaxTargets then
					MaxTargets = TargetDamage
					ally = v
				end
			end
			TargetDamage = 0
			if not Bot:HasModifier("modifier_item_sphere_target") and not Bot:HasModifier("modifier_item_sphere") and not Bot.GetSpellShield and not Bot.UseManta then
				if Bot:HasModifier("modifier_lina_laguna_blade") or Bot:HasModifier("modifier_lion_finger_of_death") then
					TargetDamage = TargetDamage + 3
				end
				for _,v in pairs(Bot:GetIncomingTrackingProjectiles()) do
					if v.ability ~= nil then
						if (v.ability:GetName() == "sniper_assassinate" and not v.caster:HasScepter()) or 
								v.ability:GetName() == "lich_chain_frost" or 
								v.ability:GetName() == "enchantress_impetus" or 
								v.ability:GetName() == "gyrocopter_homing_missile" or
								v.ability:GetName() == "huskar_life_break" or
								v.ability:GetName() == "lina_laguna_blade" or
								v.ability:GetName() == "lion_finger_of_death" or
								v.ability:GetName() == "morphling_adaptive_strike_agi" or
								v.ability:GetName() == "morphling_adaptive_strike_str" or
								v.ability:GetName() == "tinker_heat_seeking_missile" or
								v.ability:GetName() == "tusk_snowball" then
							TargetDamage = TargetDamage + 1
						end
					end
				end
			end
			if TargetDamage > MaxTargets then
				MaxTargets = TargetDamage
				ally = Bot
			end
			if ally ~= nil then
				ally.GetSpellShield = true
				Bot:Action_UseAbilityOnEntity(item,ally)
				return
			end
		end
	end
	,
	["item_armlet"] = function()
		if CanUseItem("item_armlet") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_armlet"))
			
			local incommingDamage = Bot:GetIncommingDamageWithDistance(500)

			if incommingDamage.All > Bot:GetHealth() and not item:GetToggleState() then
				Bot:Action_UseAbility(item)
				return
			elseif incommingDamage.All > Bot:GetHealth() and item:GetToggleState() then
				Bot:Action_UseAbility(item)
				Bot:Action_UseAbility(item)
				return
			else
				if item:GetToggleState() then
					if not Bot:Mode(BOT_MODE_ATTACK,BOT_MODE_PUSH_TOWER_TOP,BOT_MODE_PUSH_TOWER_MID,BOT_MODE_PUSH_TOWER_BOT) or Bot:GetHealth()/Bot:GetMaxHealth() < 0.5 then -- Item is useless turned on or we are to low.
						Bot:Action_UseAbility(item)
						return
					end
				else
					if Bot:Mode(BOT_MODE_ATTACK,BOT_MODE_PUSH_TOWER_TOP,BOT_MODE_PUSH_TOWER_MID,BOT_MODE_PUSH_TOWER_BOT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_MODERATE and  Bot:GetHealth()/Bot:GetMaxHealth() > 0.5 then
						if Bot:Mode(BOT_MODE_ATTACK) then
							local Target = Bot:GetTarget()
							if GetUnitToUnitDistance(Bot,Target) <= Bot:GetAttackRange() +200 then
								Bot:Action_UseAbility(item)
								return
							end
						end
						Bot:Action_UseAbility(item)
						return
					end 
				end
			end
		end
	end
	,
	["item_meteor_hammer"] = function()
		if CanUseItem("item_meteor_hammer") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_meteor_hammer"))
			local range = item:GetCastRange()
			local aoe = item:GetSpecialValueInt("impact_radius")

			local landDuration = item:GetSpecialValueFloat("land_time")
			local Channel = item:GetChannelTime()

			local Target = Bot:GetTarget()

			if Bot:Mode(BOT_MODE_LANING) and not Bot:GetBotRole().support > 0 then
				local creeps = Bot:FindAoELocation(true,false,Bot:GetLocation(),range,aoe,landDuration+Channel,0)
				if creeps.count >= 4 then
					Bot:Action_UseAbilityOnLocation(item,creeps.targetloc)
				end
			end

			-- Following code is from Ranked Matchmaking AI

			local tableNearbyAttackingAlliedHeroes = Bot:GetNearbyHeroes( 1000, false, BOT_MODE_ATTACK )
			if ( Bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or
				 Bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
				 Bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT) then
				local towers = Bot:GetNearbyTowers(800, true)
				if #towers > 0 and towers[1] ~= nil and  towers[1]:IsInvulnerable() == false then 
					Bot:Action_UseAbilityOnLocation(item, towers[1]:GetLocation())
					return
				end
			elseif ( #tableNearbyAttackingAlliedHeroes >= 2 ) then
				local locationAoE = Bot:FindAoELocation( true, true, Bot:GetLocation(), 600, 300, 0, 0 )
				if ( locationAoE.count >= 2 ) 
				then
					Bot:Action_UseAbilityOnLocation(item, locationAoE.targetloc)
					return
				end
			elseif ( Bot:GetActiveMode() == BOT_MODE_ROAM or
					 Bot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
					 Bot:GetActiveMode() == BOT_MODE_DEFEND_ALLY or
					 Bot:GetActiveMode() == BOT_MODE_ATTACK ) then	
				if Target ~= nil and Target:IsHero() and CanCastOnTarget(Target) and GetUnitToUnitDistance(Bot, Target) < 800
				   and IsDisabled(true, Target) == true	
				then
					Bot:Action_UseAbilityOnLocation(item, Target:GetLocation())
					return
				end
			end
		end
	end
	,
	["item_invis_sword"] = function() -- TODO: Make this better for attacks and chasing
		if CanUseItem("item_invis_sword") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_invis_sword"))

			if Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				Bot:Action_UseAbility(item)
				return
			end
			
		end
	end
	,
	["item_silver_edge"] = function() -- TODO: Make this better for attacks and chasing
		if CanUseItem("item_silver_edge") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_silver_edge"))

			if Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				Bot:Action_UseAbility(item)
				return
			end
			
		end
	end

	,
	["item_ethereal_blade"] = function()
		if CanUseItem("item_ethereal_blade") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_ethereal_blade"))
			local range = item:GetCastRange()
			local bonusMagicDamage = item:GetSpecialValueInt("extra_spell_damage_percent")
			
			local damage = Bot:GetIncommingDamage()


			if Bot:GetBotRole().support ~= nil and Bot:GetBotRole().support > 0 then -- We are support, use it on ally befor on us!
				for _,v in pairs(Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)) do
					damage = v:GetIncommingDamage()
					damage.Magic = damage.Magic + ((damage.Magic/100)*bonusMagicDamage) -- Calc damage with bonus magic damage
					local MaxDamage = (Bot:GetMaxHealth()/100)*30
					if MaxDamage > 500 then MaxDamage = 500 end

					if damage.Physic > MaxDamage and damage.Magic < damage.Physic then
						Bot:Action_UseAbilityOnEntity(item,v)
						return
					end

					if v:GetActiveMode() == BOT_MODE_RETREAT and v:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
						Bot:Action_UseAbilityOnEntity(item,v)
						return
					end
				end

				damage = Bot:GetIncommingDamage()

				damage.Magic = damage.Magic + ((damage.Magic/100)*bonusMagicDamage)

				local MaxDamage = (Bot:GetMaxHealth()/100)*30
				if MaxDamage > 500 then MaxDamage = 500 end

				if damage.Physic > MaxDamage and damage.Magic < damage.Physic then
					Bot:Action_UseAbilityOnEntity(item,Bot)
					return
				end

				if Bot:GetActiveMode() == BOT_MODE_RETREAT and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
					Bot:Action_UseAbilityOnEntity(item,Bot)
					return
				end

			else
				damage.Magic = damage.Magic + ((damage.Magic/100)*bonusMagicDamage)

				local MaxDamage = (Bot:GetMaxHealth()/100)*30
				if MaxDamage > 500 then MaxDamage = 500 end

				if damage.Physic > MaxDamage and damage.Magic < damage.Physic then
					Bot:Action_UseAbility(item)
					return
				end

				if Bot:GetActiveMode() == BOT_MODE_RETREAT and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
					Bot:Action_UseAbility(item)
					return
				end

				for _,v in pairs(Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)) do
					damage = v:GetIncommingDamage()
					damage.Magic = damage.Magic + ((damage.Magic/100)*bonusMagicDamage) -- Calc damage with bonus magic damage
					local MaxDamage = (Bot:GetMaxHealth()/100)*30
					if MaxDamage > 500 then MaxDamage = 500 end

					if damage.Physic > MaxDamage and damage.Magic < damage.Physic then
						Bot:Action_UseAbilityOnEntity(item,v)
						return
					end

					if v:GetActiveMode() == BOT_MODE_RETREAT and v:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
						Bot:Action_UseAbilityOnEntity(item,v)
						return
					end
				end
			end
		end
	end
	,
	["item_butterfly"] = function()
		if CanUseItem("item_butterfly") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_butterfly"))

			if Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				Bot:Action_UseAbility(item)
				return
			end
			
		end
	end
	,
	["item_abyssal_blade"] = function()
		if CanUseItem("item_abyssal_blade") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_abyssal_blade"))
			local range = item:GetCastRange()
			local Target = Bot:GetTarget()
			if Target ~= nil and not IsDisabled(Target) and Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				Bot:Action_UseAbilityOnEntity(item,Target)
			end
		end
	end
	,
	["item_bloodthorn"] = function()
		if CanUseItem("item_bloodthorn") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_bloodthorn"))
			local range = item:GetCastRange()
			local Target = Bot:GetTarget()
			if Target == nil or not Target:IsHero() or Target:IsInvulnerable() then return end
			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and GetUnitToUnitDistance(Bot, Target) < range/1.5 and Target:GetHealth()/ Taget:GetMaxHealth() > 0.7 and CanCastOnTarget(Target) then
				Bot:Action_UseAbilityOnEntity(item, Target)
				return
			end
		end
	end
	,
	["item_mask_of_madness"] = function()
		if CanUseItem("item_mask_of_madness") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_mask_of_madness"))
			local Target = Bot:GetTarget()
			if Target ~= nil and Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and GetUnitToUnitDistance(Bot, Target) < Bot:GetAttackRange()/1.5 and Target:GetHealth()/ Taget:GetMaxHealth() > 0.2 then
				Bot:Action_UseAbility(item)
				return
			elseif Bot:Mode(BOT_MODE_PUSH_TOWER_TOP,BOT_MODE_PUSH_TOWER_MID,BOT_MODE_PUSH_TOWER_BOT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				Bot:Action_UseAbility(item)
				return
			elseif Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_VERYHIGH then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_diffusal_blade"] = function()
		if CanUseItem("item_diffusal_blade") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_diffusal_blade"))
			local range = item:GetCastRange()
			local Target = Bot:GetTarget()
			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and GetUnitToUnitDistance(Bot, Target) < range then
				Bot:Action_UseAbilityOnEntity(item,Target)
				return
			elseif Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_VERYHIGH then
				local MaxDistance = range
				local enemy = nil
				for _,v in pairs(Bot:GetNearbyHeroes(range,true,BOT_MODE_NONE)) do
					if GetUnitToUnitDistance(Bot,v) < MaxDistance then
						MaxDistance = GetUnitToUnitDistance(Bot,v)
						enemy = v
					end
				end
				if enemy ~= nil then
					Bot:Action_UseAbilityOnEntity(item,enemy)
					return
				end
			end
		end
	end
	,
	["item_diffusal_blade_2"] = function()
		if CanUseItem("item_diffusal_blade_2") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_diffusal_blade_2"))
			local range = item:GetCastRange()
			local Target = Bot:GetTarget()
			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and GetUnitToUnitDistance(Bot, Target) < range then
				Bot:Action_UseAbilityOnEntity(item,Target)
				return
			elseif Bot:Mode(BOT_MODE_RETREAT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_VERYHIGH then
				local MaxDistance = range
				local enemy = nil
				for _,v in pairs(Bot:GetNearbyHeroes(range,true,BOT_MODE_NONE)) do
					if GetUnitToUnitDistance(Bot,v) < MaxDistance then
						MaxDistance = GetUnitToUnitDistance(Bot,v)
						enemy = v
					end
				end
				if enemy ~= nil then
					Bot:Action_UseAbilityOnEntity(item,enemy)
					return
				end
			end
		end
	end
	,
	["item_heavens_halberd"] = function()
		if CanUseItem("item_heavens_halberd") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_heavens_halberd"))
			local range = item:GetCastRange()

			local HighestDPS = 0
			local enemy = nil
			for _,v in pairs(Bot:GetNearbyHeroes(range,true,BOT_MODE_NONE)) do
				if v:GetDPS() > HighestDPS and v:GetLastAttackTime() < 0.5 then
					HighestDPS = v:GetDPS()
					enemy = v
				end
			end
			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
				if enemy ~= nil then
					Bot:Action_UseAbilityOnEntity(item,enemy)
					return
				end
			end
		end
	end
	,
	["item_satanic"] = function()
		if CanUseItem("item_satanic") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_satanic"))

			if Bot:Mode(BOT_MODE_ATTACK) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and Bot:GetHealth()/Bot:GetMaxHealth() < 0.5 then
				Bot:Action_UseAbility(item)
				return
			end
		end
	end
	,
	["item_mjollnir"] = function()
		if CanUseItem("item_mjollnir") then
			item = Bot:GetItemInSlot(Bot:FindItemSlot("item_mjollnir"))
			local range = item:GetCastRange()

			if Bot:Mode(BOT_MODE_ATTACK,BOT_MODE_PUSH_TOWER_TOP,BOT_MODE_PUSH_TOWER_MID,BOT_MODE_PUSH_TOWER_BOT) and Bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_MODERATE then
				local MaxIncomingProjectiles = 0
				local ally = nil
				for _,v in pairs(Bot:GetNearbyHeroes(range,false,BOT_MODE_NONE)) do
					if v:GetIncomingTrackingProjectiles() > MaxIncommingProjectiles then
						MaxIncommingProjectiles = v:GetIncomingTrackingProjectiles()
						ally = v
					end
				end
				for _,v in pairs(Bot:GetNearbyCreeps(range,false)) do
					if v:GetIncomingTrackingProjectiles() > MaxIncommingProjectiles then
						MaxIncommingProjectiles = v:GetIncomingTrackingProjectiles()
						ally = v
					end
				end
				if ally ~= nil and MaxIncommingProjectiles >= 5 then
					Bot:Action_UseAbilityOnEntity(item,ally)
				end
			end
		end
	end
	-- I am done o.O
}

function UseItems()
	Bot = GetBot()
	for i = 0, 5 do
		local item = Bot:GetItemInSlot(i)
		if item ~= nil and item:GetName() ~= "" then
			if Items[item:GetName()] ~= nil then
				Items[item:GetName()]()
			end
		end
	end
end

function CanSwitchPTStat(pt)
	local Bot = GetBot()
	if Bot:GetPrimaryAttribute() == ATTRIBUTE_STRENGTH and pt:GetPowerTreadsStat() ~= ATTRIBUTE_STRENGTH then
		return true
	elseif Bot:GetPrimaryAttribute() == ATTRIBUTE_AGILITY  and pt:GetPowerTreadsStat() ~= ATTRIBUTE_INTELLECT then
		return true
	elseif Bot:GetPrimaryAttribute() == ATTRIBUTE_INTELLECT and pt:GetPowerTreadsStat() ~= ATTRIBUTE_AGILITY then
		return true
	end 
	return false
end

-- Stolen from Ranked Matchmaking AI

function IsDisabled(npcTarget)
	if npcTarget:IsRooted( ) or npcTarget:IsStunned( ) or npcTarget:IsHexed( ) or npcTarget:IsSilenced() or npcTarget:IsNightmared() then
		return true;
	end
	return false;
end

for k,v in pairs( ability_item_usage_generic ) do	_G._savedEnv[k] = v end