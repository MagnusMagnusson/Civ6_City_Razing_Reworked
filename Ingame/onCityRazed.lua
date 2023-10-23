-- onCityRazed
-- Author: Magnus
-- DateCreated: 10/21/2023 11:49:34 PM
--------------------------------------------------------------

local CityWatch = {};
local settings = {};
function onCityDestroyed(playerID, cityID) 
	print("City was destroyed", playerID, cityID);
	for i, city in ipairs(CityWatch) do 
		if(city.cityId == cityID) then 
			print("Observed City razed, triggering onRaze()");
			onCityRazed(city);
			table.remove(CityWatch, i);
			break;
		end
	end
end

function onCityRazed(cityInfo)
	--Grant Settler if the owner isn't out--
	print("OnCityRazed");
	print(settings["giveSettler"]);
	if(settings["giveSettler"] == true) then
		print("giveSettler enabled");
		giveSettler(cityInfo.oldOwner, 1);
	else 
		print("giveSettler not enabled");
	end

	if(settings["refugeePerc"] ~= "0") then 
		MigratePop(cityInfo, settings["refugeePerc"]);
	end
end

function MigratePop(cityInfo, chance)
	print("Trying to migrate pops!");
	local pop = cityInfo.population;
	local razed_x = cityInfo.x;
	local razed_y = cityInfo.y;
	local oldOwner = cityInfo.oldOwner;
	if(playerExists(oldOwner) == false or pop <= 1) then 
		return;
	end
	local totalDistances = 0;
	local candidates = {};
	local owner = PlayerManager.GetPlayer(oldOwner);
	print("Calculating distances to nearby cities");
	--Get Nearby Cities--
	for i,city in owner:GetCities():Members() do 
		local _x, _y, d;
		_x = city:GetX();
		_y = city:GetY();
		d = (math.abs(razed_x - _x) + math.abs(razed_y - _y));
		local dScore = math.max(1, 50 - d);
		dScore = dScore * dScore;
		totalDistances = totalDistances + dScore;
		table.insert(candidates, {
			city = city,
			distanceScore = dScore
		});
	end
	

	print("Distributing refugees");
	-- Start Distributing Pops --
	for i = 0, pop - 1 do 
		local r = Game.GetRandNum(10);
		if(r < chance) then 
			print("Refugee made it!", i, r, chance);
			local roll = Game.GetRandNum(totalDistances);
			local x = 0;
			local chosenCity = nil;
			for i, city in ipairs(candidates) do 
				x = x + city.distanceScore;
				if(x >= roll) then 
					chosenCity = city.city;
					break;
				end
			end
			if(chosenCity ~= nil) then 
				chosenCity:ChangePopulation(1);
			end
			print("Pop migrated to ", chosenCity);
		else 
			print("Refugee died.", i, r, chance);
		end
	end
end

function giveSettler(playerId, count)
	print("giveSettler()");
	if(playerExists(playerId)) then 
		local owner = PlayerManager.GetPlayer(playerId)
		for i = 0, count - 1 do 
			local capital = owner:GetCities():GetCapitalCity();
			local settler = GameInfo.Units["UNIT_SETTLER"];
			owner:GetUnits():Create(settler, capital:GetX(), capital:GetY());
		end
	end
end

function CityOccupationChanged(playerID, cityID) 
	print("City occupation status changed", playerID, cityID);
	for i, city in ipairs(CityWatch) do 
		if(city.cityId == cityID) then 
			print("City not razed, removing from raze candidate list");
			table.remove(CityWatch, i);
			break;
		end
	end
end

function CityConquered(newOwner, oldOwner, cityId)
	-- Safety check -- 
	if(newOwner == nil or playerExists(oldOwner) == false or cityId == nil) then
		print("One or both players involved are not eligable for razing benefits", newOwner, oldOwner, cityId);
		return;
	end

	print("City was just captured, ", newOwner, oldOwner, cityId);
	local city = GetCityId(newOwner, cityId);
	local pop = city:GetPopulation();
	local row = {
		newOwner = newOwner,
		oldOwner = oldOwner,
		cityId = cityId,
		population = pop,
		x = city:GetX(),
		y = city:GetY(),
	}
	print("population", pop);
	table.insert(CityWatch, row);
end


function GetCityId(ownerId, cityId) 
	local p = PlayerManager.GetPlayer(ownerId);
	return p:GetCities():FindID(cityId)
end

function playerExists(playerId) 
	return playerId ~= nil 
	and PlayerManager.GetPlayer(playerId) ~= nil
	and PlayerManager.GetPlayer(playerId):IsAlive() ~= false
	and PlayerManager.GetPlayer(playerId):IsMajor() == true;
end

function GameTurnStart(playerID) 
	print(playerID);
end

function init()
	settings["giveSettler"] = GameInfo.MCR_CONFIG["giveSettler"].value == "1";
	settings["refugeePerc"] = tonumber(GameInfo.MCR_CONFIG["refugeePerc"].value);
end

print("subscribing to destruction event");
Events.CityRemovedFromMap.Add(onCityDestroyed);
print("subscribing to occupation event");
Events.CityOccupationChanged.Add(CityOccupationChanged);
print("subscribing to global Conquest event");
GameEvents.CityConquered.Add(CityConquered);

init();