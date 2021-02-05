#include <sourcemod>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.10"

bool g_bTouched[MAXPLAYERS+1];
bool g_bMVM;
bool g_bLateLoad;
ConVar g_hCVTimer;
ConVar g_hCVEnabled;
ConVar g_hCVTeam;
Handle g_hWearableEquip;
Handle g_hGameConfig;

public Plugin myinfo = 
{
	name = "Give Bots Cosmetics",
	author = "luki1412",
	description = "Gives TF2 bots cosmetics",
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
	ConVar hCVversioncvar = CreateConVar("sm_gbc_version", PLUGIN_VERSION, "Give Bots Cosmetics version cvar", FCVAR_NOTIFY|FCVAR_DONTRECORD); 
	g_hCVEnabled = CreateConVar("sm_gbc_enabled", "1", "Enables/disables this plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCVTimer = CreateConVar("sm_gbc_delay", "0.1", "Delay for giving cosmetics to bots", FCVAR_NONE, true, 0.1, true, 30.0);
	g_hCVTeam = CreateConVar("sm_gbc_team", "1", "Team to give cosmetics to: 1-both, 2-red, 3-blu", FCVAR_NONE, true, 1.0, true, 3.0);

	HookEvent("post_inventory_application", player_inv);
	HookConVarChange(g_hCVEnabled, OnEnabledChanged);
	
	SetConVarString(hCVversioncvar, PLUGIN_VERSION);
	AutoExecConfig(true, "Give_Bots_Cosmetics");

	if (g_bLateLoad)
	{
		OnMapStart();
	}
	
	g_hGameConfig = LoadGameConfigFile("give.bots.cosmetics");
	
	if (!g_hGameConfig)
	{
		SetFailState("Failed to find give.bots.cosmetics.txt gamedata! Can't continue.");
	}	
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Virtual, "EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hWearableEquip = EndPrepSDKCall();
	
	if (!g_hWearableEquip)
	{
		SetFailState("Failed to prepare the SDKCall for giving cosmetics. Try updating gamedata or restarting your server.");
	}
}

public void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarBool(g_hCVEnabled))
	{
		HookEvent("post_inventory_application", player_inv);
	}
	else
	{
		UnhookEvent("post_inventory_application", player_inv);
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
	if (!GetConVarInt(g_hCVEnabled))
	{
		return;
	}

	int userd = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userd);
	
	if (!g_bTouched[client] && !g_bMVM && IsPlayerHere(client))
	{
		g_bTouched[client] = true;
		int team = GetClientTeam(client);
		int team2 = GetConVarInt(g_hCVTeam);
		float timer = GetConVarFloat(g_hCVTimer);
		
		switch (team2)
		{
			case 1:
			{
				CreateTimer(timer, Timer_GiveHat, userd, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 2:
			{
				if (team == 2)
				{
					CreateTimer(timer, Timer_GiveHat, userd, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
			case 3:
			{
				if (team == 3)
				{
					CreateTimer(timer, Timer_GiveHat, userd, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
}

public Action Timer_GiveHat(Handle timer, any data)
{
	int client = GetClientOfUserId(data);
	g_bTouched[client] = false;
	
	if (!GetConVarInt(g_hCVEnabled) || !IsPlayerHere(client))
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
	
	if (!g_bMVM)
	{
		bool face = false;
		int rnd1 = GetRandomUInt(0,4);
		if(rnd1>2)CreateHat(client, 96, 6);
		else if(rnd1>1)CreateHat(client, 515, 5);
		else CreateHat(client, 30094 , 20);
		if ( !face )
		{
			int rnd2 = GetRandomUInt(0,10);
			switch (rnd2)
			{
				case 1:
				{
					CreateHat(client, 30569, 6); //The Tomb Readers
				}
				case 2:
				{
					CreateHat(client, 744, 6); //Pyrovision Goggles
				}
				case 3:
				{
					CreateHat(client, 522, 6); //The Deus Specs
				}
				case 4:
				{
					CreateHat(client, 816, 6); //The Marxman
				}
				case 5:
				{
					CreateHat(client, 30104, 6); //Graybanns
				}
				case 6:
				{
					CreateHat(client, 30306, 6); //The Dictator
				}
				case 7:
				{
					CreateHat(client, 30352, 6); //The Mustachioed Mann
				}
				case 8:
				{
					CreateHat(client, 30414, 6); //The Eye-Catcher
				}
				case 9:
				{
					CreateHat(client, 30140, 6); //The Virtual Viewfinder
				}
				case 10:
				{
					CreateHat(client, 30397, 6); //The Bruiser's Bandanna
				}				
			}
		}
		
		int rnd3 = GetRandomUInt(0,25);
		switch (rnd3)
		{
			case 1:
			{
				CreateHat(client, 868, 6, 20); //Heroic Companion Badge
			}
			case 2:
			{
				CreateHat(client, 583, 6, 20); //Bombinomicon
			}
			case 3:
			{
				CreateHat(client, 586, 6); //Mark of the Saint
			}
			case 4:
			{
				CreateHat(client, 625, 6, 20); //Clan Pride
			}
			case 5:
			{
				CreateHat(client, 619, 6, 20); //Flair!
			}
			case 6:
			{
				CreateHat(client, 1025, 6); //The Fortune Hunter
			}
			case 7:
			{
				CreateHat(client, 623, 6, 20); //Photo Badge
			}
			case 8:
			{
				CreateHat(client, 738, 6); //Pet Balloonicorn
			}
			case 9:
			{
				CreateHat(client, 955, 6); //The Tuxxy
			}
			case 10:
			{
				CreateHat(client, 995, 6, 20); //Pet Reindoonicorn
			}
			case 11:
			{
				CreateHat(client, 987, 6); //The Merc's Muffler
			}
			case 12:
			{
				CreateHat(client, 1096, 6); //The Baronial Badge
			}
			case 13:
			{
				CreateHat(client, 30607, 6); //The Pocket Raiders
			}
			case 14:
			{
				CreateHat(client, 30068, 6); //The Breakneck Baggies
			}
			case 15:
			{
				CreateHat(client, 869, 6); //The Rump-o-Lantern
			}
			case 16:
			{
				CreateHat(client, 30309, 6); //Dead of Night
			}
			case 17:
			{
				CreateHat(client, 1024, 6); //Crofts Crest
			}
			case 18:
			{
				CreateHat(client, 992, 6); //Smissmas Wreath
			}
			case 19:
			{
				CreateHat(client, 956, 6); //Faerie Solitaire Pin
			}
			case 20:
			{
				CreateHat(client, 943, 6); //Hitt Mann Badge
			}
			case 21:
			{
				CreateHat(client, 873, 6, 20); //Whale Bone Charm
			}
			case 22:
			{
				CreateHat(client, 855, 6); //Vigilant Pin
			}
			case 23:
			{
				CreateHat(client, 818, 6); //Awesomenauts Badge
			}
			case 24:
			{
				CreateHat(client, 767, 6); //Atomic Accolade
			}
			case 25:
			{
				CreateHat(client, 718, 6); //Merc Medal
			}
		}
	}	
}

bool CreateHat(int client, int itemindex, int quality, int level = 0)
{
	int hat = CreateEntityByName("tf_wearable");
	
	if (!IsValidEntity(hat))
	{
		return false;
	}
	
	char entclass[64];
	GetEntityNetClass(hat, entclass, sizeof(entclass));
	SetEntData(hat, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), itemindex);
	SetEntData(hat, FindSendPropInfo(entclass, "m_bInitialized"), 1);
	SetEntData(hat, FindSendPropInfo(entclass, "m_iEntityQuality"), quality);

	if (level)
	{
		SetEntData(hat, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
	}
	else
	{
		SetEntData(hat, FindSendPropInfo(entclass, "m_iEntityLevel"), GetRandomUInt(1,100));
	}
	
	DispatchSpawn(hat);
	SDKCall(g_hWearableEquip, client, hat);
	return true;
} 

bool IsPlayerHere(int client)
{
	return (client && IsClientInGame(client) && IsFakeClient(client));
}

int GetRandomUInt(int min, int max)
{
	return RoundToFloor(GetURandomFloat() * (max - min + 1)) + min;
}