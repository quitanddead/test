/*
	GoldKey

	F507DMT aka Левин Д.Ю. 
	BlackGoga aka Федотов В.В.

	http://goldkey-games.ru 
	https://vk.com/goldkey_dz
*/
#include "defines.h"
private ["_height_now","_daytime","_fireplaces","_vel","_speed","_looptime","_sun_factor","_building_factor","_vehicle_factor","_fire_factor","_water_factor","_rain_factor","_night_factor","_wind_factor","_height_mod","_difference","_isinbuilding","_inVehicle","_raining","_sunrise","_building","_fireplaces","_daytime","_temp","_moving_factor"];
_looptime=_this;

//Factors are equal to win/loss of factor*basic value
//All Values can be seen as x of 100: 100 / x = minutes from min temperetaure to max temperature (without other effects)
_vehicle_factor		=	10;
_moving_factor 		=  	7;
_fire_factor		=	17;	//Should be always:  _rain_factor + _night_factor + _wind_factor || higher !
_building_factor 	=  	7;
_sun_factor			= 	6;	//max sunfactor linear over the day. highest value in the middle of the day

_water_factor		= 	-13;
_rain_factor		=	-10;
_night_factor		= 	-5;
_wind_factor		=	-3;

_difference 		= 	0;
_isinbuilding		= false;
_inVehicle			= false;

_raining 			= if(rain > 0)then{true}else{false};
_sunrise			= call world_sunRise;

//vehicle
if((vehicle player) != player)then{
	if !(typeOf vehicle player in TrashVeh) then {
		if(isEngineOn vehicle player)then{
			_difference=_difference + _vehicle_factor;
		}else{
			_difference=_difference +3;
		};
		_inVehicle=true;
	}else{
	_difference=_difference - 2;
	};
} else {
	//speed factor
	private[];
	_vel=velocity player;
	_speed=round((_vel distance [0,0,0]) * 3.5);
	_difference=(_moving_factor * (_speed / 20)) min 7;
};

//low blood
if (6000 >= r_player_blood) then {
	_difference = _difference -10;
};

if(!_inVehicle)then{
	//fire
	_fireplaces = nearestObjects [player, ["Land_Fire","Land_Campfire"], 8];
	if(({inflamed _x} count _fireplaces) > 0 && !_inVehicle ) then {
		//Math: factor * 1 / (0.5*(distance max 1)^2) 		0.5 = 12.5% of the factor effect in a distance o 4 meters
		_difference 	= _difference + (_fire_factor /(0.5*((player distance (_fireplaces select 0)) max 1)^2));
	};

	//building
	_building = nearestObject [player, "HouseBase"];
	if(!isNull _building) then {
		if([player,_building] call fnc_isInsideBuilding) then {
			//Make sure thate Fire && Building Effect can only appear single		Not used at the moment
			_difference=_difference + _building_factor;
			_isinbuilding= true;
			dayz_inside=true;
		} else {
			dayz_inside=false;
		};
	} else {
		dayz_inside=false;
	};

	//sun
	if(daytime > _sunrise && daytime < (24 - _sunrise) && !_raining && overcast <= 0.6 && !_isinbuilding) then {
		_difference = _difference + (-((_sun_factor / (12 - _sunrise)^2)) * ((daytime - 12)^2) + _sun_factor);	
	};

	//water
	if(surfaceIsWater getPosATL player || dayz_isSwimming) then {
		_difference = _difference + _water_factor;
	};

	//rain
	if(_raining && !_isinbuilding) then {
		_difference = _difference + (rain * _rain_factor);
	};

	//night
	if((daytime < _sunrise || daytime > (24 - _sunrise))) then {
		_daytime=if(daytime < 12)then{daytime + 24}else{daytime};
		if(_isinbuilding) then {
			_difference=_difference + ((((_night_factor * -1) / (_sunrise^2)) * ((_daytime - 24)^2) + _night_factor)) / 2;
		} else {
			_difference=_difference + (((_night_factor * -1) / (_sunrise^2)) * ((_daytime - 24)^2) + _night_factor);
		};
	};

	//wind
	if(((wind select 0) > 4 || (wind select 1) > 4) && !_inVehicle && !_isinbuilding ) then {
		_difference = _difference + _wind_factor;
	};
	
	//height
#ifdef HEIGHT_COLD
	_height_now = getPosASL player select 2;
	if (_height_now > COLD_HEIGHT) then {
		_height_mod = (_height_now/100) * 3;
		_difference = _difference - _height_mod;
	};
#else
	if (overcast >= 0.6) then {
		_height_mod = ((getPosASL player select 2) / 100) / 2;
		_difference = _difference - _height_mod;
	};
#endif

#ifdef _ORIGINS
	if((typeOf player)in WinterSkin)then{
		_difference = _difference+35;
	};
#endif
};

//Calculate Change Value			Basic Factor			Looptime Correction			Adjust Value to current used temperatur scala
_difference = _difference * SleepTemperatur / (60 / _looptime)		* ((dayz_temperaturmax - dayz_temperaturmin) / 100);

//Change Temperatur															 Should be moved in a own Function to allow adding of Items which increase the Temp like "hot tea"
dayz_temperatur = (((dayz_temperatur + _difference) max dayz_temperaturmin) min dayz_temperaturmax);

//Add Shivering
//Percent when the Shivering will start 
if(dayz_temperatur <= (0.2 * (dayz_temperaturmax - dayz_temperaturmin) + dayz_temperaturmin)) then { //30 град
	//CamShake as linear Function Maximum reached when Temp is at temp minimum. First Entry = Max Value
	_temp = 1 * (dayz_temperaturmin / dayz_temperatur );
	addCamShake [_temp,(_looptime + 1),30];	//[0.5,looptime,6] -> Maximum is 25% of the Pain Effect	
} else {
	addCamShake [0,0,0];			//Not needed at the Moment, but will be necesarry for possible Items
};