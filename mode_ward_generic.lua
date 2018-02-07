
require( GetScriptDirectory().."/basics" ) -- Almost all Hero stats, Roles, etc
-- Code from Ranked Matchmaking AI
-- Slighly modified by YoungFlyme
function GetDesire()
	local Bot = GetBot()
	if Bot:IsChanneling() or Bot:IsIllusion() or Bot:IsInvulnerable() or not Bot:IsHero() or not IsSuitableToWard() then
		return BOT_MODE_DESIRE_NONE
	end
	if Bot:GotItemInInv("item_ward_observer") then
		item = Bot:GetItemInSlot(Bot:FindItemSlot("item_ward_observer"))
		if item ~= nil then
			pinged, wt = Bot:IsPingedByHumanPlayer(false)
			if pinged then	
				return RemapValClamped(GetUnitToUnitDistance(bot, wt), 1000, 0, BOT_MODE_DESIRE_HIGH, BOT_MODE_DESIRE_VERYHIGH)
			end
			targetLoc, targetDist = Bot:GetNearestWardSpot()
			if targetLoc ~= nil then
				return RemapValClamped(targetDist, 6000, 0, BOT_MODE_DESIRE_MODERATE-0.05, BOT_MODE_DESIRE_HIGH-0.05)
			end
		end
		if Bot.IsWarding and IsWardedPos(Bot.WardPos) then
			return BOT_MODE_DESIRE_NONE 
		elseif Bot.IsWarding then
			return BOT_MODE_DESIRE_ABSOLUTE 
		end
	end

	return BOT_MODE_DESIRE_NONE
end

-- Original Ranked Matchmaking AI code
function  IsSuitableToWard()
	local bot = GetBot()
	local Enemies = bot:GetNearbyHeroes(1300, true, BOT_MODE_NONE);
	local mode = bot:GetActiveMode();
	if ( ( mode == BOT_MODE_RETREAT and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH )
		or mode == BOT_MODE_ATTACK
		or mode == BOT_MODE_RUNE 
		or mode == BOT_MODE_DEFEND_ALLY
		or mode == BOT_MODE_DEFEND_TOWER_TOP
		or mode == BOT_MODE_DEFEND_TOWER_MID
		or mode == BOT_MODE_DEFEND_TOWER_BOT
		or ( #Enemies >= 1 and IsIBecameTheTarget(Enemies) )
		or bot:WasRecentlyDamagedByAnyHero(5.0)
		) 
	then
		return false;
	end
	return true;
end

function IsIBecameTheTarget(units)
	local bot = GetBot()
	for _,u in pairs(units) do
		if u:GetAttackTarget() == bot then
			return true;
		end
	end
	return false;
end

function WardPath(Distance, Whutever, Poses)
	if Distance ~= 0 and #Poses > 0 then
		Bot:Path(Distance,Poses)
	end
end

function Think()
	Bot = GetBot()
	if Bot.IsWarding and not IsWardedPos(Bot.WardPos) and (Bot.IsGeneratingPath == nil or (Bot.IsGeneratingPath ~= nil and not Bot.IsGeneratingPath) ) and (Bot.PathTo == nil or (Bot.PathTo ~= nil and Bot.PathTo ~= Bot.WardPos)) then
		Bot.IsGeneratingPath = true
		Bot.PathTo = Bot.WardPos
		GeneratePath( Bot:GetLocation() , Bot.WardPos, GetAvoidanceZones(), WardPath)
	elseif Bot.IsWarding and not IsWardedPos(Bot.WardPos) then
		local item = Bot:GetItemInSlot(Bot:FindItemSlot("item_ward_observer"))
		if item ~= nil then
			local range = item:GetCastRange()
			if GetUnitToLocationDistance(Bot,Bot.WardPos) < range and Ward(Bot.WardPos) then
				print("Using ward: ",Bot.WardPos.x,Bot.WardPos.y,Bot.WardPos.z)
				Bot:Action_UseAbilityOnLocation(item,Bot.WardPos)
				Bot.IsWarding = false
				Bot.WardPos = nil
				return
			else
				Bot:Action_MoveToLocation(Bot.WardPos)
			end
		end
	end
end
