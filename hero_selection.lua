require( GetScriptDirectory().."/basics" ) -- Almost all Hero stats, Roles, etc

local BotNames = {	-- Make 10, just to be sure!
	"YoungFlyme",
	"NeWBie",
	"YoungY",
	"MrAt☢m",
	"KobbY",
	"BrutalX",
	"eXYoung",
	"OneManArmy",
	"Isa",
	"Play Without Friends!"
}

local Radiant = {
	Picked = {},
	SuppBotLane = false,
	SuppTopLane = false,
	BotLane = false,
	TopLane = false
}

local Dire = {
	Picked = {},
	SuppBotLane = false,
	SuppTopLane = false,
	BotLane = false,
	TopLane = false
}


----------------------------------------------------------------------------------------------------

function Think2() -- It wont work! (there is a 2 in the function name :3)
	local team_radi = GetTeamPlayers(TEAM_RADIANT)
	local team_dire = GetTeamPlayers(TEAM_DIRE)

	if GetTeam() == TEAM_RADIANT then
		for _, id in ipairs(team_radi) do
			if IsPlayerBot(id) then -- Only Bots! (id == dire_id  is only needed in 1v1!)
				local heroName = GetSelectedHeroName(id)
				if heroName == nil or heroName == "" then -- Picked allready and got a name?
					local Hero = GetRandomHero()
					if #Radiant.Picked < 2 then
						Hero = GetRandomHero("support")
					elseif #Radiant.Picked < 4 then
						Hero = GetRandomHero("carry","nuker","initiator")
					elseif #Radiant.Picked < 5 then
						Hero = GetRandomHero("durable")
					end
					SelectHero(id,Hero)
					table.insert(Radiant.Picked,Hero)
				end
			end
		end
	elseif GetTeam() == TEAM_DIRE then
		for _, id in ipairs(team_dire) do
			if IsPlayerBot(id) then -- Only Bots! (id == dire_id  is only needed in 1v1!)
				local heroName = GetSelectedHeroName(id)
				if heroName == nil or heroName == "" then -- Picked allready and got a name?
					local Hero = GetRandomHero()
					if #Dire.Picked < 2 then
						Hero = GetRandomHero("support")
					elseif #Dire.Picked < 3 then
						Hero = GetRandomHero("durable")
					elseif #Dire.Picked < 5 then
						Hero = GetRandomHero("carry","nuker","initiator")
					end
					SelectHero(id,Hero)
					table.insert(Dire.Picked,Hero)
				end
			end
		end
	end
end

function GetRandomHero( ... )
	local args = {...}

	local PossibleHeroes = {}
	for _,v in pairs(args) do
		for Key,Value in pairs(HeroRole) do
			if Value[v] ~= 0 then
				table.insert(PossibleHeroes,Key)
			end
		end
	end
	local rnd = RandomInt(1,#PossibleHeroes)
	local name = PossibleHeroes[rnd]
	return name
end

function GetBotNames()
	return(BotNames)
end

function UpdateLaneAssignments2() -- It wont work! (there is a 2 in the function name :3)
	local lanes = {}
	for id=0,9 do
		if IsPlayerBot(id) then
			if id < 5 then -- Dire laneup
				print(Radiant.Picked[id],id,id)
				if HeroRole[Radiant.Picked[id%5]].support > 0 then
					if not Radiant.SuppBotLane then
						Radiant.SuppBotLane = true
						lanes[id] = LANE_BOT
					elseif not Radiant.SuppTopLane then
						Radiant.SuppTopLane = true
						lanes[id] = LANE_TOP
					end
				else
					if not Radiant.BotLane then
						Radiant.BotLane = true
						lanes[id] = LANE_BOT
					elseif not Radiant.TopLane then
						Radiant.TopLane = true
						lanes[id] = LANE_TOP
					else
						lanes[id] = LANE_MID
					end
				end
			else -- Dire laneup
				print("Dire is shire  "..Dire.Picked[id-5])
				if HeroRole[Dire.Picked[id-5]].support > 0 then
					if not Dire.SuppBotLane then
						Dire.SuppBotLane = true
						lanes[id] = LANE_BOT
					elseif not Dire.SuppTopLane then
						Dire.SuppTopLane = true
						lanes[id] = LANE_TOP
					end
				else
					if not Dire.BotLane then
						Dire.BotLane = true
						lanes[id] = LANE_BOT
					elseif not Dire.TopLane then
						Dire.TopLane = true
						lanes[id] = LANE_TOP
					else
						lanes[id] = LANE_MID
					end
				end
			end
		end
	end
	return lanes
end