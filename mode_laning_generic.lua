_G._savedEnv = getfenv()
module( "mode_generic_laning", package.seeall )

require( GetScriptDirectory().."/basics" ) -- Almost all Hero stats, Roles, etc

function Think()
	Bot = GetBot()
	-- Now its complicated!
	-- Supports dont lasthit, only deny
	-- carry's lasthit and deny (focus mor lasthitting as denying (via a score?))

	if DotaTime() > 30 then
		local FrontAmount = GetLaneFrontAmount( Bot:GetTeam(), Bot:GetAssignedLane(), false )
		local FrontPos = GetLocationAlongLane( Bot:GetAssignedLane(), FrontAmount-0.005-(Bot:GetAttackRange()/80000) )+RandomVector(Bot:GetAttackRange())

		-- Find creeps (Lowest enemy and move to him and prepare kill if no enemy is near otherwise play saver!)

		if (Bot:GetCurrentActionType() == BOT_ACTION_TYPE_NONE or Bot:GetCurrentActionType() == BOT_ACTION_TYPE_IDLE or (Bot:IsAlive() and Bot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and Bot:GetVelocity() == Vector(0,0)) and not Bot:IsUsingAbility()) or GetUnitToLocationDistance(Bot,FrontPos) > Bot:GetAttackRange()/2 then	
			Bot:Action_MoveToLocation(FrontPos) -- Cant return here or we wont make any actions :/
		elseif GetUnitToLocationDistance(Bot,FrontPos) <= Bot:GetAttackRange()/2 then  -- Anything is false? We just check the Distance and nearby creeps! if they are <= 1 and this creep is under 20% of life go back :3
			print(GetUnitToLocationDistance(Bot,FrontPos),Bot:GetAttackRange()/2)
			local creeps = Bot:GetNearbyCreeps(Bot:GetAttackRange()+200,false) -- only our creeps!
			if #creeps <= 1 then
				--if creeps[1]:GetHealth()/creeps[1]:GetMaxHealth() <= 0.5 then
					print("Falling back, amount before: "..FrontAmount)
					FrontAmount = GetLaneFrontAmount( Bot:GetTeam(), Bot:GetAssignedLane(), true )
					FrontPos = GetLocationAlongLane( Bot:GetAssignedLane(), FrontAmount-0.4 )+RandomVector(Bot:GetAttackRange())
					Bot:Action_MoveToLocation(FrontPos)
					return
				--end
			end
		end

		local towerRange = GetTower(Bot:GetTeam(),TOWER_BASE_2):GetAttackRange() -- be sure the tower is not destroyed!
		local posAmount = FrontAmount-0.05
		for _,v in pairs(Bot:GetNearbyTowers(towerRange,true)) do
			local Pos = GetLocationAlongLane( Bot:GetAssignedLane(), posAmount)
			if GetUnitToLocationDistance(v,Pos) < towerRange+Bot:GetAttackRange() then
				posAmount = posAmount-0.001
				Pos = GetLocationAlongLane( Bot:GetAssignedLane(), posAmount)
				print("Moving out of tower range!")
				Bot:Action_MoveToLocation(Pos)
				return
			end
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
					print(Bot:GetUnitName().." is harassing "..Enemy:GetUnitName().." with a normal attack")
					Bot:Action_AttackUnit(Enemy,true)
				end
			end

			if not Bot:NeedMana() then -- Do we need mana (cannot cast our most expensive spell) than dont harass!
				-- Look which spell makes the most damage (at all on heroes/possible lasthits)
				local effectiveness = 0
				local castAbility = nil
				for i = 0, 23 do -- only 1st 3 abilities or we maby waste a ultimate
					local ability = Bot:GetAbilityInSlot(i)
					if ability ~= nil and ability:GetName() ~= "" and ability:GetCastRange() ~= nil and ability:GetCastRange() >= 200 and (ability:GetBehavior() ~= nil and (ability:GetBehavior() == ABILITY_BEHAVIOR_POINT or (ability:GetBehavior() == ABILITY_BEHAVIOR_UNIT_TARGET and ability:GetTargetTeam() == ABILITY_TARGET_TEAM_ENEMY and ability:GetTargetType()%3 == 1))) then
						-- local dmg = ability:GetAbilityDamage() -- Not working at all.... Valve fucked somthing up here!
						local manacost = ability:GetManaCost()
						--if dmg/manacost > effectiveness then
							castAbility = ability
							break
						--end
					end
				end
				if castAbility ~= nil and castAbility:IsFullyCastable() then
					local range = castAbility:GetCastRange()+400
					if range >= 1600 then range = 1599 end
					local Hero = Bot:GetNearbyHeroes(range,true,BOT_MODE_NONE)
					if #Hero > 0 and Hero[1] ~= nil then
						if castAbility:GetBehavior() == ABILITY_BEHAVIOR_POINT then
							print(Bot:GetUnitName().." is harassing with "..castAbility:GetName())
							Bot:Action_UseAbilityOnLocation(castAbility,Hero[1]:GetLocation())
							return
						else
							print(Bot:GetUnitName().." is harassing with "..castAbility:GetName())
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
	else -- DotaTime() < 30 -> Blocking!
		-- Good Blocks require good work, jsut making a huge table with all creep waypoints i found on the map, eto gg!
		local WayPoints = { -- Required for perfect block (i think)
			[TEAM_RADIANT] = {
				[LANE_BOT] = {
					["lane_bot_pathcorner_goodguys_1"] = {
						Next = "lane_bot_pathcorner_goodguys_6",
						Pos = Vector(-4224,-6112,320)
					},
					["lane_bot_pathcorner_goodguys_6"] = {
						Next = "lane_bot_pathcorner_goodguys_8",
						Pos = Vector(480,-6656,320)
					},
					["lane_bot_pathcorner_goodguys_8"] = {
						Next = "lane_bot_pathcorner_goodguys_9",
						Pos = Vector(2048,-6336,320)
					},
					["lane_bot_pathcorner_goodguys_9"] = {
						Next = "lane_bot_pathcorner_goodguys_10",
						Pos = Vector(3320,-6312,320)
					},
					["lane_bot_pathcorner_goodguys_10"] = {
						Next = "lane_bot_pathcorner_goodguys_2",
						Pos = Vector(4028,-6268,320)
					},
					["lane_bot_pathcorner_goodguys_2"] = {
						Next = "lane_bot_pathcorner_goodguys_11",
						Pos = Vector(4672,-6044,320)
					},
					["lane_bot_pathcorner_goodguys_11"] = {
						Next = "lane_bot_pathcorner_goodguys_5",
						Pos = Vector(5600,-5728,320)
					},
					["lane_bot_pathcorner_goodguys_5"] = {
						Next = "lane_bot_pathcorner_goodguys_12",
						Pos = Vector(6028,-5484,320)
					},
					["lane_bot_pathcorner_goodguys_12"] = {
						Next = "lane_bot_pathcorner_goodguys_7",
						Pos = Vector(6456,-4776,320)
					},
					["lane_bot_pathcorner_goodguys_7"] = {
						Next = "lane_bot_pathcorner_goodguys_3",
						Pos = Vector(6080,-3320,320)
					},
					-- I Stop here because I need this just for blocking! (No more waypoints needed!)
				},
				[LANE_MID] = {
					["lane_mid_pathcorner_goodguys_1"] = {
						Next = "lane_mid_pathcorner_goodguys_9",
						Pos = Vector(-4856,-4376,320)
					},
					["lane_mid_pathcorner_goodguys_9"] = {
						Next = "lane_mid_pathcorner_goodguys_2",
						Pos = Vector(-3104,-2736,320)
					},
					["lane_mid_pathcorner_goodguys_2"] = {
						Next = "lane_mid_pathcorner_goodguys_3",
						Pos = Vector(-976,-824,256)
					},
					["lane_mid_pathcorner_goodguys_3"] = {
						Next = "lane_mid_pathcorner_goodguys_4",
						Pos = Vector(-360,-256,160)
					},
				},
				[LANE_TOP] = {
					["lane_top_pathcorner_goodguys_1"] = {
						Next = "lane_top_pathcorner_goodguys_5",
						Pos = Vector(-6592,-3720,320)
					},
					["lane_top_pathcorner_goodguys_5"] = {
						Next = "lane_top_pathcorner_goodguys_6",
						Pos = Vector(-6368,56,320)
					},
					["lane_top_pathcorner_goodguys_6"] = {
						Next = "lane_top_pathcorner_goodguys_7",
						Pos = Vector(-6368,2808,320)
					},
					["lane_top_pathcorner_goodguys_7"] = {
						Next = "lane_top_pathcorner_goodguys_2",
						Pos = Vector(-6164,4276,320)
					},
					["lane_top_pathcorner_goodguys_2"] = {
						Next = "lane_top_pathcorner_goodguys_2b",
						Pos = Vector(-5964,5208,320)
					},
				}
			},
			[TEAM_DIRE] = {
				[LANE_BOT] = {
					["lane_bot_pathcorner_badguys_1"] = {
						Next = "lane_bot_pathcorner_badguys_2",
						Pos = Vector(6320,3328,352)
					},
					["lane_bot_pathcorner_badguys_2"] = {
						Next = "lane_bot_pathcorner_badguys_7",
						Pos = Vector(6448,352,352)
					},
					["lane_bot_pathcorner_badguys_7"] = {
						Next = "lane_bot_pathcorner_badguys_8",
						Pos = Vector(6496,-2424,308)
					},
					["lane_bot_pathcorner_badguys_8"] = {
						Next = "lane_bot_pathcorner_badguys_12",
						Pos = Vector(5856,-3304,308)
					},
					["lane_bot_pathcorner_badguys_12"] = {
						Next = "lane_bot_pathcorner_badguys_10",
						Pos = Vector(6112,-3884,320)
					},
					["lane_bot_pathcorner_badguys_10"] = {
						Next = "lane_bot_pathcorner_badguys_11",
						Pos = Vector(6148,-5104,320)
					},
					["lane_bot_pathcorner_badguys_11"] = {
						Next = "lane_bot_pathcorner_badguys_5",
						Pos = Vector(5568,-5760,320)
					},
				},
				[LANE_MID] = {
					["lane_mid_pathcorner_badguys_1"] = {
						Next = "lane_mid_pathcorner_badguys_8",
						Pos = Vector(4456,3960,352)
					},
					["lane_mid_pathcorner_badguys_8"] = { -- This looks pretty close to the tower, creeps can (will) split if we block here! Should We?
						Next = "lane_mid_pathcorner_badguys_2", -- TODO: Remove this due better blocks
						Pos = Vector(2368,1904,320)
					},
					["lane_mid_pathcorner_badguys_2"] = {
						Next = "lane_mid_pathcorner_badguys_3",
						Pos = Vector(864,672,320)
					},
					["lane_mid_pathcorner_badguys_3"] = {
						Next = "lane_mid_pathcorner_badguys_4",
						Pos = Vector(144,152,256)
					},
					["lane_mid_pathcorner_badguys_4"] = {
						Next = "lane_mid_pathcorner_badguys_5",
						Pos = Vector(-392,-224,160)
					},

				},
				[LANE_TOP] = {
					["lane_top_pathcorner_badguys_1"] = {
						Next = "lane_top_pathcorner_badguys_5",
						Pos = Vector(3856,5768,352)
					},
					["lane_top_pathcorner_badguys_5"] = { -- Whoo, pretty huuge jump, i like it :3
						Next = "lane_top_pathcorner_badguys_6",
						Pos = Vector(-1872,6008,320)
					},
					["lane_top_pathcorner_badguys_6"] = { -- And again :3 Valve just helped me out here ^^
						Next = "lane_top_pathcorner_badguys_2",
						Pos = Vector(-5264,5552,320)
					},
					["lane_top_pathcorner_badguys_2"] = {
						Next = "lane_top_pathcorner_badguys_2b",
						Pos = Vector(-6004,5484,320)
					},
					["lane_top_pathcorner_badguys_2b"] = {
						Next = "lane_top_pathcorner_badguys_2b1",
						Pos = Vector(-6236,4872,320)
					},
					["lane_top_pathcorner_badguys_2b1"] = {
						Next = "lane_top_pathcorner_badguys_3",
						Pos = Vector(-6376,3896,320)
					},
					-- The next Waypoint is soo enormously far away (We are not even at T1 and the next waypoint are the radiant rax xD) lazy Mapper of Valve, thx for this
				}
			}
		}

		local function GetWaypoint(Creep)
			if type(Creep) == "table" then
				local Amount = 0
				for _,v in pairs(Creep) do
					if GetAmountAlongLane(Bot:GetAssignedLane(),v:GetLocation()).amount > Amount then
						Amount = GetAmountAlongLane(Bot:GetAssignedLane(),v:GetLocation()).amount
					end
				end
				if Amount ~= 0 then -- We now have to return the Waypoint!
					local Team = Bot:GetTeam()
					local Lane = Bot:GetAssignedLane()
					for k,v in pairs(WayPoints[Team][Lane]) do
						if GetAmountAlongLane(Lane,v.Pos).amount > Amount then
							return v
						end
					end
				end
			else
				local Amount = GetAmountAlongLane(Bot:GetAssignedLane(),Creep:GetLocation()).amount
				if Amount ~= 0 then -- We now have to return the Waypoint!
					local Team = Bot:GetTeam()
					local Lane = Bot:GetAssignedLane()
					for k,v in pairs(WayPoints[Team][Lane]) do
						if GetAmountAlongLane(Lane,v.Pos).amount > Amount then
							return v
						end
					end
				end
			end
		end

		if not (Bot:IsAlive()) then return end

		-- After we got this huuge (and half-completed) waypoint table, do some blocking stuff
		local Radius = Bot:GetBoundingRadius()

		local Creeps = Bot:GetNearbyCreeps(600,false)
		local BadCreeps = Bot:GetNearbyCreeps(600,true)

		if #Creeps > 0 and #BadCreeps == 0 and (Bot.Block == nil or Bot.Block) then -- No bad creeps and atleast 1 creep to block
			-- Get currently aiming waypoint of this creep
			print(Bot:GetVelocity())

			local CreepWayPoint = GetWaypoint(Creeps)
			if CreepWayPoint == nil or CreepWayPoint.Pos == nil then return end

			Bot.Block = true

			-- Get creep which is the nearst creep to the Waypoint
			-- Sort Table based on the distance!
			for i,v in ipairs(Creeps) do
				for f = i, #Creeps do
					if GetUnitToLocationDistance(v,CreepWayPoint.Pos) > GetUnitToLocationDistance(Creeps[f],CreepWayPoint.Pos) then -- Is our current creeps pos bigger than the next, then swap them!
						local Swap = Creeps[f]
						Creeps[f] = v
						Creeps[f-1] = Swap
					end
				end
			end

			local DistanceOffset = 10
			local MovementOffset = 500

			-- After sorting them loop to get the best blocking pos
			for _,v in pairs(Creeps) do
				-- 1stly avoid already blocked creeps (blocked by other creeps)
				if not(v:GetVelocity() == Vector(0,0)) and GetUnitToUnitDistance(v,Bot) > DistanceOffset then
					local Distance = GetUnitToLocationDistance(v,CreepWayPoint.Pos) + DistanceOffset
					local HeroDistance = GetUnitToLocationDistance(v,CreepWayPoint.Pos) -- Without the offset!

					local Angle = v:GetRotationAngle(Bot:GetLocation())
					if not((Distance < HeroDistance and Angle > 2) or Angle > 2.5) then
						local MoveDistance = MovementOffset/Bot:GetCurrentMovementSpeed() * 100
						if (Bot:GetCurrentMovementSpeed() - v:GetCurrentMovementSpeed() > DistanceOffset) then -- Get Speed differences and calculate them into the Movedistance
							MoveDistance = MoveDistance - (Bot:GetCurrentMovementSpeed() - v:GetCurrentMovementSpeed()) / 2
						end
						local MovePosition = v:GetXUnitsInFront(math.max(MoveDistance, MoveDistance * Angle))
						if not (GetLocationToLocationDistance(MovePosition,CreepWayPoint.Pos) - DistanceOffset > HeroDistance) then
							if not (Angle < 0.2 and (Bot:GetVelocity() ~= Vector(0,0))) then -- Got a bit to long, splittet it in 2 if's
								print("Blocking")
								Bot:Action_MoveToLocation(MovePosition)
								return
							end
						end
					end
				end
			end

			if (Bot:GetVelocity() ~= Vector(0,0)) then
				print(Bot:GetVelocity())
				Bot:Action_ClearActions(true)
				print(Bot:GetVelocity())
			end

		elseif #BadCreeps > 0 and Bot.Block ~= nil and Bot.Block then
			Bot.Block = false -- We blocked and found enemy creeps :3
		elseif Bot.Block ~= nil and Bot.Block == false then -- We blocked atleast once but failed it, move to "normal" position
			local FrontAmount = GetLaneFrontAmount( Bot:GetTeam(), Bot:GetAssignedLane(), false )
			local FrontPos = GetLocationAlongLane( Bot:GetAssignedLane(), FrontAmount-0.005-(Bot:GetAttackRange()/80000) )+RandomVector(Bot:GetAttackRange())
			Bot:Action_MoveToLocation(FrontPos) -- Cant return here or we wont make any actions :/
		elseif Bot.Block == nil and #Creeps == 0 then
			FrontPos = GetLocationAlongLane( Bot:GetAssignedLane(), 0.20 )
			if GetUnitToLocationDistance(Bot,FrontPos) > Bot:GetAttackRange() then
				Bot:Action_MoveToLocation(FrontPos)
			end
		elseif #Creeps == 0 and Bot.Block then
			Bot.Block = false
		end
	end
end
for k,v in pairs( mode_generic_laning ) do	_G._savedEnv[k] = v end