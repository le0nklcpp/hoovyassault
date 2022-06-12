#include <sourcemod>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.10"

bool g_bTouched[MAXPLAYERS+1];
bool g_bSuddenDeathMode;
bool g_bMVM;
bool g_bLateLoad;
ConVar g_hCVTimer;
ConVar g_hCVEnabled;
ConVar g_hCVTeam;
Handle g_hWeaponEquip;
Handle g_hWWeaponEquip;
Handle g_hGameConfig;

public Plugin myinfo = 
{
	name = "Give Bots Weapons",
	author = "luki1412",
	description = "Gives TF2 bots non-stock weapons",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/member.php?u=43109"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	if (GetEngineVersion() != Engine_TF2) 
	{
		Format(error, err_max, "This plugin only works for Team Fortress 2.");
		return APLRes_Failure;
	}

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() 
{
	ConVar hCVversioncvar = CreateConVar("sm_gbw_version", PLUGIN_VERSION, "Give Bots Weapons version cvar", FCVAR_NOTIFY|FCVAR_DONTRECORD); 
	g_hCVEnabled = CreateConVar("sm_gbw_enabled", "1", "Enables/disables this plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVTimer = CreateConVar("sm_gbw_delay", "0.1", "Delay for giving weapons to bots", FCVAR_NONE, true, 0.1, true, 30.0);
	g_hCVTeam = CreateConVar("sm_gbw_team", "1", "Team to give weapons to: 1-both, 2-red, 3-blu", FCVAR_NONE, true, 1.0, true, 3.0);
	
	HookEvent("post_inventory_application", player_inv);
	HookEvent("teamplay_round_stalemate", EventSuddenDeath, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_start", EventRoundReset, EventHookMode_PostNoCopy);
	HookConVarChange(g_hCVEnabled, OnEnabledChanged);
	
	SetConVarString(hCVversioncvar, PLUGIN_VERSION);
	AutoExecConfig(true, "Give_Bots_Weapons");

	if (g_bLateLoad)
	{
		OnMapStart();
	}
	
	g_hGameConfig = LoadGameConfigFile("give.bots.weapons");
	
	if (!g_hGameConfig)
	{
		SetFailState("Failed to find give.bots.weapons.txt gamedata! Can't continue.");
	}	
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Virtual, "WeaponEquip");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hWeaponEquip = EndPrepSDKCall();
	
	if (!g_hWeaponEquip)
	{
		SetFailState("Failed to prepare the SDKCall for giving weapons. Try updating gamedata or restarting your server.");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Virtual, "EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hWWeaponEquip = EndPrepSDKCall();
	
	if (!g_hWWeaponEquip)
	{
		SetFailState("Failed to prepare the SDKCall for giving weapons. Try updating gamedata or restarting your server.");
	}
}

public void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarBool(g_hCVEnabled))
	{
		HookEvent("post_inventory_application", player_inv);
		HookEvent("teamplay_round_stalemate", EventSuddenDeath, EventHookMode_PostNoCopy);
		HookEvent("teamplay_round_start", EventRoundReset, EventHookMode_PostNoCopy);
	}
	else
	{
		UnhookEvent("post_inventory_application", player_inv);
		UnhookEvent("teamplay_round_stalemate", EventSuddenDeath, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_start", EventRoundReset, EventHookMode_PostNoCopy);
	}
}

public void OnMapStart()
{
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		g_bMVM = true;
	}
}

public void OnClientDisconnect(int client)
{
	g_bTouched[client] = false;
}

public void player_inv(Handle event, const char[] name, bool dontBroadcast) 
{
	if (!GetConVarBool(g_hCVEnabled))
	{
		return;
	}

	int userd = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userd);
	
	if (!g_bSuddenDeathMode && !g_bTouched[client] && !g_bMVM && IsPlayerHere(client))
	{
		g_bTouched[client] = true;
		int team = GetClientTeam(client);
		int team2 = GetConVarInt(g_hCVTeam);
		float timer = GetConVarFloat(g_hCVTimer);
		
		switch (team2)
		{
			case 1:
			{
				CreateTimer(timer, Timer_GiveWeapons, userd, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 2:
			{
				if (team == 2)
				{
					CreateTimer(timer, Timer_GiveWeapons, userd, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
			case 3:
			{
				if (team == 3)
				{
					CreateTimer(timer, Timer_GiveWeapons, userd, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
}

public Action Timer_GiveWeapons(Handle timer, any data)
{
	int client = GetClientOfUserId(data);
	g_bTouched[client] = false;
	
	if (!GetConVarBool(g_hCVEnabled) || !IsPlayerHere(client))
	{
		return;
	}

	int team = GetClientTeam(client);
	int team2 = GetConVarInt(g_hCVTeam);
	
	switch (team2)
	{
		case 2:
		{
			if (team != 2)
			{
				return;
			}
		}
		case 3:
		{
			if (team != 3)
			{
				return;
			}
		}
	}

	if (!g_bSuddenDeathMode && !g_bMVM&&TF2_GetPlayerClass(client)==TFClass_Heavy)
	{
			TF2_RemoveWeaponSlot(client,1);
			TF2_RemoveWeaponSlot(client,2);
			int rnd2 = GetRandomUInt(1,100);
			if(rnd2<40)
			{
				CreateWeapon(client, "tf_weapon_shotgun_hwg", 425);
			}
			else if(rnd2<80)
			{
					CreateWeapon(client, "tf_weapon_shotgun_hwg", 11);
			}
			else
			{
					CreateWeapon(client, "tf_weapon_lunchbox", 311);
			}
			
			int rnd3 = GetRandomUInt(1,11);
			switch (rnd3)
			{
				case 1,2:
				{
					CreateWeapon(client, "tf_weapon_fists", 43);
				}
				case 3:
				{
					CreateWeapon(client, "tf_weapon_fists", 310);
				}
				case 4:
				{
					CreateWeapon(client, "tf_weapon_fists", 331);
				}
				case 5,6:
				{
					CreateWeapon(client, "tf_weapon_fists", 656);
				}
				case 7:
				{
					CreateWeapon(client, "tf_weapon_fists", 587);
				}
				case 8:
				{
					CreateWeapon(client, "tf_weapon_fireaxe", 1013, 5);
				}
				case 9:
				{
					CreateWeapon(client, "tf_weapon_fireaxe", 939, 5);
				}
				case 10:
				{
					CreateWeapon(client, "tf_weapon_fireaxe", 880, 25);
				}
				case 11:
				{
					CreateWeapon(client, "tf_weapon_fireaxe", 474, 25);
			 	}

			}
		
	}
}

public void EventSuddenDeath(Handle event, const char[] name, bool dontBroadcast)
{
	g_bSuddenDeathMode = true;
}

public void EventRoundReset(Handle event, const char[] name, bool dontBroadcast)
{
	g_bSuddenDeathMode = false;
}

bool CreateWeapon(int client, char[] classname, int itemindex, int level = 0)
{
	int weapon = CreateEntityByName(classname);
	
	if (!IsValidEntity(weapon))
	{
		return false;
	}
	
	char entclass[64];
	GetEntityNetClass(weapon, entclass, sizeof(entclass));
	SetEntData(weapon, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), itemindex);	 
	SetEntData(weapon, FindSendPropInfo(entclass, "m_bInitialized"), 1);
	SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityQuality"), 6);

	if (level)
	{
		SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
	}
	else
	{
		SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityLevel"), GetRandomUInt(1,99));
	}

	switch (itemindex)
	{
		case 810:
		{
			SetEntData(weapon, FindSendPropInfo(entclass, "m_iObjectType"), 3);
		}
		case 998:
		{
			SetEntData(weapon, FindSendPropInfo(entclass, "m_nChargeResistType"), GetRandomUInt(0,2));
		}
	}
	
	DispatchSpawn(weapon);
	SDKCall(g_hWeaponEquip, client, weapon);
	return true;
} 

public Action TimerHealth(Handle timer, any client)
{
	int hp = GetPlayerMaxHp(client);
	
	if (hp > 0)
	{
		SetEntityHealth(client, hp);
	}
}

int GetPlayerMaxHp(int client)
{
	if (!IsClientConnected(client))
	{
		return -1;
	}

	int entity = GetPlayerResourceEntity();

	if (entity == -1)
	{
		return -1;
	}

	return GetEntProp(entity, Prop_Send, "m_iMaxHealth", _, client);
}

bool IsPlayerHere(int client)
{
	return (client && IsClientInGame(client) && IsFakeClient(client));
}

int GetRandomUInt(int min, int max)
{
	return RoundToFloor(GetURandomFloat() * (max - min + 1)) + min;
}