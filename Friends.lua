Friends = Friends or {};

local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local towstring = towstring
local tinsert = table.insert

local TextLogGetEntry = TextLogGetEntry
local TextLogGetNumEntries = TextLogGetNumEntries
local CreateHyperLink = CreateHyperLink

local ORDER_COLOR = {0,205,255};
local DESTR_COLOR = {255,25,25};
local LOCATION_COLOR = {169,169,169};
--Added by Xruptor
local WEAPONUSED_COLOR = {255, 165, 0};

local localization;

local SelfName;

local TIME_DELAY = 6 -- seconds untill kill announcement fades away
local timeUntillFadeOut;

--Added by Xruptor
local TIME_DELAY_KBM = 8 -- seconds untill kill announcement fades away
local SHOW_GROUP_WEAPON_KILLS = true
local SHOW_LOCATION = false
local SHOW_ABILITY_ICONS = true  --this causes a bit of stutter after each kill
local timeUntillFadeOutKilledByMe;

Friends.groupMembers = {};

----Added by Xruptor
Friends.sessionUnknownList = {};
Friends.combatListIndex = 0;
Friends.combatListOrder = {};
Friends.combatListAbilityName = {};

local function FixString(str)
	if (str == nil) then return nil end	
	local str = str;
	local pos = str:find (L"^", 1, true);
	if (pos) then str = str:sub (1, pos - 1) end	
	pos = str:find (L" ", 1, true);
	if (pos) then str = str:sub (1, pos - 1) end	
	return str;
end

--Added by Xruptor
--SimpleFixString does not remove the spaces, and does not cut off at first space found
function SimpleFixString (str)
	if (str == nil) then return nil end
	local str = str
	local pos = str:find (L"^", 1, true)
	if (pos) then str = str:sub (1, pos - 1) end
	return str
end

local function IsInGroup()
	return (GetNumGroupmates() > 0)
end

--Added by Xruptor
local function GetIconByAbilityName(abilityName)
	if not abilityName then return nil end

	--if type(abilityName) == "wstring" then
	local origAbilityName = SimpleFixString(abilityName):lower()
	abilityName = towstring(abilityName):lower()

	--first check to see if we grabbed it already from combatlog parser
	if Friends.combatListAbilityName and Friends.combatListAbilityName[abilityName] then
		--update it if it's stored and doesn't match
		if Friends.IconList[abilityName] and Friends.IconList[abilityName] ~= Friends.combatListAbilityName[abilityName] then
			Friends.IconList[abilityName] = Friends.combatListAbilityName[abilityName]
		end
		--d("we got it from combat parser")
		return Friends.combatListAbilityName[abilityName]
	end
	
	--second check to see if we already have it stored, that way we don't have to go through the loop
	if Friends.IconList and Friends.IconList[abilityName] then
		local storedIcon = Friends.IconList[abilityName];
		
		if storedIcon and storedIcon ~= "icon000000" and storedIcon ~= "icon-00001" and storedIcon ~= "icon-00002" then
			--d("we got it stored")
			return Friends.IconList[abilityName];
		else
			--somehow it was stored incorrectly, either way don't show it
			return nil
		end
	end
	
	--lastly, check the current session list and see if it was already parsed
	if Friends.sessionUnknownList and Friends.sessionUnknownList[abilityName] then
		--d("we got it from session list")
		--it's already been parsed so if we didn't have an icon for it then it's "icon000000"
		return nil
	end
	
	--check to see if it's a weapon kill instead of an abilityName
	local rightHand = SimpleFixString(CharacterWindow.equipmentData[GameData.EquipSlots.RIGHT_HAND].name):lower()
	local leftHand = SimpleFixString(CharacterWindow.equipmentData[GameData.EquipSlots.LEFT_HAND].name):lower()
	local rangedSlot = SimpleFixString(CharacterWindow.equipmentData[GameData.EquipSlots.RANGED].name):lower()
	
	--first check
	if (abilityName == rightHand or abilityName == towstring(rightHand) or origAbilityName == rightHand or towstring(origAbilityName) == towstring(rightHand)) then return nil end
	if (abilityName == leftHand or abilityName == towstring(leftHand) or origAbilityName == leftHand or towstring(origAbilityName) == towstring(leftHand)) then return nil end
	if (abilityName == rangedSlot or abilityName == towstring(rangedSlot) or origAbilityName == rangedSlot or towstring(origAbilityName) == towstring(rangedSlot)) then return nil end
	
	--for some reason sometimes an empty space is added to the end of the strings, so they don't compare properly
	if rightHand then rightHand = (rightHand):sub(1, (rightHand):len() - 1)	end
	if leftHand then leftHand = (leftHand):sub(1, (leftHand):len() - 1)	end
	if rangedSlot then rangedSlot = (rangedSlot):sub(1, (rangedSlot):len() - 1)	end
	
	--second check
	if (abilityName == rightHand or abilityName == towstring(rightHand) or origAbilityName == rightHand or towstring(origAbilityName) == towstring(rightHand)) then return nil end
	if (abilityName == leftHand or abilityName == towstring(leftHand) or origAbilityName == leftHand or towstring(origAbilityName) == towstring(leftHand)) then return nil end
	if (abilityName == rangedSlot or abilityName == towstring(rangedSlot) or origAbilityName == rangedSlot or towstring(origAbilityName) == towstring(rangedSlot)) then return nil end
	
	--it's probably a weapon attack or something I completely missed, or a buff that triggers or something lets just store it, to avoid going through loop again
	if Friends.sessionUnknownList then
		Friends.sessionUnknownList[abilityName] = "icon000000"
		--store it for future processing
		Friends.IconList.UnknownAbilityID[abilityName] = "icon000000"
	end

	return nil
end

function Friends.init()

	localization = Friends.Localization.GetMapping();
	SelfName = FixString(GameData.Player.name);
	
	--Added by Xruptor
	if not Friends.IconList then Friends.IconList = {}; end
	if not Friends.IconList.UnknownAbilityID then Friends.IconList.UnknownAbilityID = {}; end
	
	--Added by Xruptor
	--reset, icon list for the session
	Friends.sessionUnknownList = {}
	
	CreateWindow("FriendsKilledBy", true);
	LayoutEditor.RegisterWindow("FriendsKilledBy", L"Friends 'Killed by'", L"Friends 'killed by' window", true, true, true, nil);
	WindowSetShowing ("FriendsKilledBy", true);
	
	--Added by Xruptor
	CreateWindow("FriendsKilledByMe", true);
	LayoutEditor.RegisterWindow("FriendsKilledByMe", L"Friends 'Killed by Me'", L"Friends 'killed by Me' window", true, true, true, nil);
	WindowSetShowing ("FriendsKilledByMe", true);
	
	RegisterEventHandler(TextLogGetUpdateEventId("Combat"), "Friends.OnChatLogUpdated");
	RegisterEventHandler(SystemData.Events.LOADING_END, "Friends.ClearAllKillWindows");
	
	--Added by Xruptor
	RegisterEventHandler(SystemData.Events.WORLD_OBJ_COMBAT_EVENT, "Friends.OnCombatEvent")
	
	--RegisterEventHandler(SystemData.Events.GROUP_UPDATED			, "Friends.GROUP_UPDATED");
    --RegisterEventHandler(SystemData.Events.GROUP_STATUS_UPDATED		, "Friends.GROUP_UPDATED");
	--RegisterEventHandler(SystemData.Events.GROUP_LEAVE           	, "Friends.GROUP_UPDATED");	
	
	Friends.GROUP_UPDATED();
	
	Friends.parseUnknownsAbilities()
	
end

--Added by Xruptor
function Friends.parseUnknownsAbilities()

	for id = 1, 100000
	do
		if GetAbilityName(id) and GetAbilityData(id) and (GetAbilityName(id)):len() > 0 then

			local data = GetAbilityData(id)
			local iconTexture, x, y = GetIconData(data.iconNum)
			
			if iconTexture and iconTexture ~= "icon000000" and iconTexture ~= "icon-00001" and iconTexture ~= "icon-00002"  then

				local firstCheck = SimpleFixString(GetAbilityName(id)):lower()
				local secondCheck = FixString(GetAbilityName(id)):lower()

				if Friends.IconList.UnknownAbilityID[firstCheck] then
					Friends.IconList[firstCheck] = iconTexture
					Friends.IconList.UnknownAbilityID[firstCheck] = nil
					
				elseif Friends.IconList.UnknownAbilityID[secondCheck] then
					Friends.IconList[secondCheck] = iconTexture
					Friends.IconList.UnknownAbilityID[secondCheck] = nil
				
				end
				
			end
				
		end
		
	end
	
end

--Added by Xruptor
function Friends.OnCombatEvent(objectID, amount, combatEvent, abilityID)

	local player, pet, ability, source

	player = (objectID == GameData.Player.worldObjNum)
	pet = (objectID == GameData.Player.Pet.objNum)
	
	if not Friends.combatListIndex then Friends.combatListIndex = 0 end
	if not Friends.combatListOrder then Friends.combatListOrder = {} end
	if not Friends.combatListAbilityName then Friends.combatListAbilityName = {} end
	
	--so if we have player or pet, that's incoming damage of which we don't care about, we care about outgoing
	if not player and not pet and abilityID and abilityID ~= 0 then
		--d("ObjectID: "..objectID.."  Amount: "..amount.."  Event: "..combatEvent.." abilityID: "..abilityID)
		
		local abilityName = GetAbilityName(abilityID)
		local data = GetAbilityData(abilityID)
		local icon = GetIconData(data.iconNum)
		if icon == "icon000000" or iconTexture == "icon-00001" or iconTexture == "icon-00002"  then icon = nil end

		if icon and abilityName and (abilityName):len() > 0 then
			--gotta remove that ^n from end of string
			abilityName = SimpleFixString(abilityName):lower()
			local debugAbilityName = tostring(abilityName) --convert from wstring to string adds a "^n" to the end of a string, if you don't do SimpleFixString
			--d("abilityName: "..debugAbilityName.."  icon: "..icon)
			
			--first check to see if it's already in the list
			if Friends.combatListAbilityName[abilityName] then
				--d(debugAbilityName.." is already in list")
				return nil
			end
			
			--if it's not in the list then lets add it, start by incrementing the index
			Friends.combatListIndex = Friends.combatListIndex + 1
			
			--if the index is greater than 200 reset it back to 1, so we get rid of the oldest entry first
			if Friends.combatListIndex > 200 then Friends.combatListIndex = 1 end
			
			--check to see if we already have that entry, if so remove the old entry first, we really only want to keep the last 200 or so abilities last used
			--otherwise this list may grow too big and just consume way too much memory
			if Friends.combatListOrder[Friends.combatListIndex] then
				Friends.combatListAbilityName[Friends.combatListOrder[Friends.combatListIndex]] = nil --remove the ability by it's name
			end
			
			--now we can add it
			Friends.combatListOrder[Friends.combatListIndex] = abilityName
			Friends.combatListAbilityName[abilityName] = icon
			--d(debugAbilityName.." ++ has been added ==> "..tostring(Friends.combatListIndex))
			
			--check if we have it stored as unknown, if so update it so that other classes can refer to it
			if Friends.IconList.UnknownAbilityID[abilityName] then
				Friends.IconList[abilityName] = icon
				Friends.IconList.UnknownAbilityID[abilityName] = nil
			end
			
		end
  
	end

end

function Friends.GROUP_UPDATED()

	if (GameData.Player.isInScenario == true) then return end

    local partyData = PartyUtils.GetPartyData();
	if (not partyData) then return end

	local groupMembers = {};
	groupMembers[SelfName] = true;
	for index, partyMember in pairs (partyData) do	
		local name = FixString(towstring(partyMember.name));
		if name and (name ~= L"") then
			groupMembers[name] = true;
		end
	end

	Friends.groupMembers = groupMembers;
	
end

function Friends.OnUpdate(timeElapsed)
	if timeUntillFadeOut then
		timeUntillFadeOut = timeUntillFadeOut - timeElapsed;
		if (timeUntillFadeOut <= 0) then
			Friends.ClearKillWindow();
			timeUntillFadeOut = nil;
		end
	end
	--Added by Xruptor
	if timeUntillFadeOutKilledByMe then
		timeUntillFadeOutKilledByMe = timeUntillFadeOutKilledByMe - timeElapsed;
		if (timeUntillFadeOutKilledByMe <= 0) then
			Friends.ClearKilledByMeWindow();
			timeUntillFadeOutKilledByMe = nil;
		end
	end
end

--Updated by Xruptor
function Friends.OnChatLogUpdated(updateType, filterType)

	if (updateType ~= SystemData.TextLogUpdate.ADDED) then return end
	if not (filterType == SystemData.ChatLogFilters.RVR_KILLS_ORDER or filterType == SystemData.ChatLogFilters.RVR_KILLS_DESTRUCTION) then 
		return
	end
	
	local tmpWeaponLeft = towstring(" ( ");
	local tmpWeaponRight = towstring(" )");
    local indexOfLastEntry = TextLogGetNumEntries("Combat") - 1;    
    local _, _, message = TextLogGetEntry("Combat", indexOfLastEntry);
	--d(message)

	local victim, verb, player, weapon, location = localization["CombatMessageParser"](message);
	-- <icon876> = party flag icon
	--	L"<icon"..towstring(iconNum)..L">"
	
	--NOTE: To see these alerts in ANY chat window.. just make sure that the SAY filter option is enabled for that tab

	-- someone in my group got a kill
	if LibGroup.GroupMembers.ByName[player]	then

		local killString = L"";
		
		-- my group is playing destruction
		if (GameData.Player.realm == 2) then	
			killString = towstring(CreateHyperLink(L"", player, DESTR_COLOR, {} ));
			killString = killString .. L" killed ";
			killString = killString .. towstring(CreateHyperLink(L"", victim, ORDER_COLOR, {} ));
		-- my group is playing order
		elseif (GameData.Player.realm == 1) then
			killString = towstring(CreateHyperLink(L"", player, ORDER_COLOR, {} ));
			killString = killString .. L" killed ";
			killString = killString .. towstring(CreateHyperLink(L"", victim, DESTR_COLOR, {} ));
		end

		if (player ~= SelfName) then
			if not SHOW_GROUP_WEAPON_KILLS then
				Friends.AnnounceKill(killString);
			else
				Friends.AnnounceKill(killString .. towstring(CreateHyperLink(L"", tmpWeaponLeft .. weapon .. tmpWeaponRight, WEAPONUSED_COLOR, {} )) );
			end
		else
			--it was my kill
			local tmpIconTex = towstring("");
			local tmpIconTexIndent = towstring("");
			
			if SHOW_ABILITY_ICONS then
				local iconTex = GetIconByAbilityName(weapon);
				if iconTex then
					--strip everything from front including leading zeros.  Add "icon" afterwards
					iconTex = iconTex:match("0*(%d+)", 1, true)
					if iconTex then
						tmpIconTex = L"<icon"..towstring(iconTex)..L">";
						tmpIconTexIndent = towstring(" ");
					end
				end
			end
			
			--do the regular announce
			Friends.AnnounceKill(killString .. towstring(tmpIconTexIndent .. tmpIconTex .. CreateHyperLink(L"", tmpWeaponLeft .. weapon .. tmpWeaponRight, WEAPONUSED_COLOR, {} )) );

			--now do the killed by me announcement
			Friends.AnnounceMyKill(killString, towstring(tmpIconTex .. tmpIconTexIndent .. CreateHyperLink(L"", weapon, WEAPONUSED_COLOR, {} )) );
			
			--only play the sound if we don't have Deathblow installed
			if not (Deathblow) then
				PlaySound(215)
			end
		end
		 
		if SHOW_LOCATION then
			killString = killString .. L" in ";
			killString = killString .. towstring(CreateHyperLink(L"", location, LOCATION_COLOR, {} ));
		end
		
		--my own kills or possibly groups kills with weapons
		if (player == SelfName or SHOW_GROUP_WEAPON_KILLS) then
			killString = killString .. L" with ";
			killString = killString .. towstring(CreateHyperLink(L"", weapon, WEAPONUSED_COLOR, {} ));	
		end
		
		
		EA_ChatWindow.Print(killString);
		return;
	
	-- someone in my group died 
	elseif LibGroup.GroupMembers.ByName[victim] then
		
		-- deaths in warbands (especially pug warbands) can get very spammy
		if ( IsWarBandActive() == true ) then return end

		local killString = L"";
	
		-- my group is playing destruction
		if (GameData.Player.realm == 2) then
			killString = towstring(CreateHyperLink(L"", player, ORDER_COLOR, {} ));
			killString = killString .. L" killed ";
			killString = killString .. towstring(CreateHyperLink(L"", victim, DESTR_COLOR, {} ));
		-- my group is playing order
		elseif (GameData.Player.realm == 1) then
			killString = towstring(CreateHyperLink(L"", player, DESTR_COLOR, {} ));
			killString = killString .. L" killed ";
			killString = killString .. towstring(CreateHyperLink(L"", victim, ORDER_COLOR, {} ));
		end	

		if (victim ~= SelfName) then
			if not SHOW_GROUP_WEAPON_KILLS then
				Friends.AnnounceKill(killString);
			else
				Friends.AnnounceKill(killString .. towstring(CreateHyperLink(L"", tmpWeaponLeft .. weapon .. tmpWeaponRight, WEAPONUSED_COLOR, {} )) );
			end
		else
			--it was my death
			Friends.AnnounceKill(killString .. towstring(CreateHyperLink(L"", tmpWeaponLeft .. weapon .. tmpWeaponRight, WEAPONUSED_COLOR, {} )) );
		end
		
		if SHOW_LOCATION then
			killString = killString .. L" in ";
			killString = killString .. towstring(CreateHyperLink(L"", location, LOCATION_COLOR, {} ));
		end
		
		--my own deaths or possibly groups deaths with weapons
		if (victim == SelfName or SHOW_GROUP_WEAPON_KILLS) then
			killString = killString .. L" with ";
			killString = killString .. towstring(CreateHyperLink(L"", weapon, WEAPONUSED_COLOR, {} ));	
		end
		
		EA_ChatWindow.Print(killString);	
		return;
	
	end
	
end

function Friends.AnnounceKill(killString)
	LabelSetText ("FriendsKilledByText", killString);	
	WindowStopAlphaAnimation ("FriendsKilledBy");
	WindowStartAlphaAnimation ("FriendsKilledBy", Window.AnimationType.SINGLE_NO_RESET, 1, 0, 0, true, 0, 1);
	WindowStartAlphaAnimation ("FriendsKilledBy", Window.AnimationType.SINGLE_NO_RESET, 0, 1, 0.2, true, 0, 1);
	timeUntillFadeOut = TIME_DELAY;
end

--Added by Xruptor
function Friends.AnnounceMyKill(killString, weapString)
	LabelSetText ("FriendsKilledByMeText", killString);
	LabelSetText ("FriendsKilledByMeWeapon", weapString);	
	WindowStopAlphaAnimation ("FriendsKilledByMe");
	WindowStartAlphaAnimation ("FriendsKilledByMe", Window.AnimationType.SINGLE_NO_RESET, 1, 0, 0, true, 0, 1);
	WindowStartAlphaAnimation ("FriendsKilledByMe", Window.AnimationType.SINGLE_NO_RESET, 0, 1, 0.2, true, 0, 1);
	timeUntillFadeOutKilledByMe = TIME_DELAY_KBM;
end

function Friends.ClearKillWindow()
	WindowStopAlphaAnimation ("FriendsKilledBy")
	WindowStartAlphaAnimation ("FriendsKilledBy", Window.AnimationType.SINGLE_NO_RESET, 1, 1, 0, true, 0, 1)
	WindowStartAlphaAnimation ("FriendsKilledBy", Window.AnimationType.SINGLE_NO_RESET, 1, 0, 1, true, 0, 1)
end

--Added by Xruptor
function Friends.ClearKilledByMeWindow()
	WindowStopAlphaAnimation ("FriendsKilledByMe")
	WindowStartAlphaAnimation ("FriendsKilledByMe", Window.AnimationType.SINGLE_NO_RESET, 1, 1, 0, true, 0, 1)
	WindowStartAlphaAnimation ("FriendsKilledByMe", Window.AnimationType.SINGLE_NO_RESET, 1, 0, 1, true, 0, 1)
end

--Added by Xruptor
function Friends.ClearAllKillWindows()
	Friends.ClearKillWindow();
	Friends.ClearKilledByMeWindow();
end