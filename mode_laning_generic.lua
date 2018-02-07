_G._savedEnv = getfenv()
module( "mode_generic_laning", package.seeall )

require( GetScriptDirectory().."/basics" ) -- Almost all Hero stats, Roles, etc

function Think()
	Bot = GetBot()
	-- Now its complicated!
	-- Supports dont lasthit, only deny
	-- carry's lasthit and deny (focus mor lasthitting as denying (via a score?))

	local FrontAmount = GetLaneFrontAmount( Bot:GetTeam(), Bot:GetAssignedLane(), false )
	local FrontPos = GetLocationAlongLane( Bot:GetAssignedLane(), FrontAmount-0.005 )+RandomVector(125)

	-- Find creeps (Lowest enemy and move to him and prepare kill if no enemy is near otherwise play saver!)

	if GetUnitToLocationDistance(Bot,FrontPos) < range /2 then -- Fixed that pretty fast!

	end

	if (Bot:GetCurrentActionType() == BOT_ACTION_TYPE_NONE or Bot:GetCurrentActionType() == BOT_ACTION_TYPE_IDLE or (Bot:IsAlive() and Bot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and Bot:GetVelocity() == Vector(0,0)) and not Bot:IsUsingAbility()) then	
		print(Bot:GetCurrentActionType(),BOT_ACTION_TYPE_NONE,BOT_ACTION_TYPE_IDLE,Bot:IsStuck(),Bot:IsUsingAbility(),Bot:GetVelocity())
		Bot:Action_MoveToLocation(FrontPos)
	end

	local npcName = Bot:GetUnitName()
	local BotStats = HeroRole[npcName] -- All bot stats (which we will need!)
	if BotStats.support >= 2 then -- Hard-Support! Dont last hit, only deny, harass enemies and pull camp (if on safelane)
		local range = Bot:GetAttackRange()
		
		for _,v in pairs(Bot:GetNearbyCreeps(range+200,false)) do
			local dist = GetUnitToUnitDistance(v,Bot)
			local neededTime = Bot:GetAttackPoint()
			if dist > range then
				local tempDist = dist-range
				neededTime = neededTime+(tempDist/Bot:GetCurrentMovementSpeed())
			end
			neededTime = neededTime+(range/Bot:GetAttackProjectileSpeed())
			if v:GetIncommingDamageInTime(neededTime).All < v:GetHealth() then
				if v:GetHealth()-v:GetIncommingDamageInTime(neededTime).All <= Bot:GetAttackDamage() then
					print(Bot:GetUnitName().." deny")
					Bot:Action_AttackUnit(v,true)
					return
				end
			end
		end

		-- Still here? Not returned? Harass enemies if possible!
		if Bot:GetLastAttackTime() - GameTime() + Bot:GetSecondsPerAttack() < 0 then -- locked and loaded
			local Enemy = nil
			for _,v in pairs(Bot:GetNearbyHeroes(Bot:GetAttackRange(),true,BOT_MODE_NONE)) do
				if Enemy == nil or v:GetHealth() < Enemy:GetHealth() then
					Enemy = v
				end
			end
			if Enemy ~= nil then
				Bot:Action_AttackUnit(Enemy,true)
			end
		end

		if not Bot:NeedMana() then -- Do we need mana (cannot cast our most expensive spell) than dont harass!
			-- Look which spell makes the most damage (at all on heroes/possible lasthits)
			local effectiveness = 0
			local castAbility = nil
			for i = 0, 2 do -- only 1st 3 abilities or we maby waste a ultimate
				local ability = Bot:GetAbilityInSlot(i)
				if ability ~= nil and ability:GetName() ~= "" and ability:GetCastRange() ~= nil and ability:GetCastRange() >= 200 and (ability:GetBehavior() ~= nil and (ability:GetBehavior() == ABILITY_BEHAVIOR_POINT or (ability:GetBehavior() == ABILITY_BEHAVIOR_UNIT_TARGET and ability:GetTargetTeam() == ABILITY_TARGET_TEAM_ENEMY and ability:GetTargetType()%3 == 1))) then
					local dmg = ability:GetAbilityDamage()
					local manacost = ability:GetManaCost()
					if dmg/manacost > effectiveness then
						castAbility = ability
						effectiveness = dmg/manacost
					end
				end
			end
			print(effectiveness)
			if castAbility ~= nil then
				local range = castAbility:GetCastRange()+400
				if range >= 1600 then range = 1599 end
				local Hero = Bot:GetNearbyHeroes(range,true,BOT_MODE_NONE)
				if #Hero > 0 and Hero[1] ~= nil then
					if castAbility:GetBehavior() == ABILITY_BEHAVIOR_POINT then
						print(Bot:GetUnitName().." is harassing")
						Bot:Action_UseAbilityOnLocation(castAbility,Hero[1]:GetLocation())
						return
					else
						print(Bot:GetUnitName().." is harassing")
						Bot:Action_UseAbilityOnEntity(castAbility,Hero[1])
						return
					end
				end
			end
		end

		-- Still here o.O??
		-- Stack or pull,.... but this i dont implement now!
	elseif BotStats.support == 1 then -- Soft-Support, can lasthit if carry dont get it, also harass enemies and deny, do not have to pull or stack
		-- Shitty softsupport. You will get the last one :3 Muhahah ^-^

	else -- No support, you will get all the farm :3
		local range = Bot:GetAttackRange()
		for _,v in pairs(Bot:GetNearbyCreeps(range+200,true)) do
			local dist = GetUnitToUnitDistance(v,Bot)
			local neededTime = Bot:GetAttackPoint()
			if dist > range then
				local tempDist = dist-range
				neededTime = neededTime+(tempDist/Bot:GetCurrentMovementSpeed())
			end
			neededTime = neededTime+(range/Bot:GetAttackProjectileSpeed())
			if v:GetIncommingDamageInTime(neededTime).All < v:GetHealth() then
				if v:GetHealth()-v:GetIncommingDamageInTime(neededTime).All <= Bot:GetAttackDamage() then
					print(Bot:GetUnitName().." lasthits")
					Bot:Action_AttackUnit(v,true)
					return
				end
			end
		end
		-- No lasthits? Ok... Deny than :)
		for _,v in pairs(Bot:GetNearbyCreeps(range+200,false)) do
			local dist = GetUnitToUnitDistance(v,Bot)
			local neededTime = Bot:GetAttackPoint()
			if dist > range then
				local tempDist = dist-range
				neededTime = neededTime+(tempDist/Bot:GetCurrentMovementSpeed())
			end
			neededTime = neededTime+(range/Bot:GetAttackProjectileSpeed())
			if v:GetIncommingDamageInTime(neededTime).All < v:GetHealth() then
				if v:GetHealth()-v:GetIncommingDamageInTime(neededTime).All <= Bot:GetAttackDamage() then
					print(Bot:GetUnitName().." deny")
					Bot:Action_AttackUnit(v,true)
					return
				end
			end
		end
		-- Wow? Still no action? Hopefully Dota will controll you now ... :/
	end
end
for k,v in pairs( mode_generic_laning ) do	_G._savedEnv[k] = v end