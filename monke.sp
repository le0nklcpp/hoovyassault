#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

int itemlist[3] = { 1187,1188,1189}
ConVar enabled
Handle g_hWearableEquip,g_hGameConfig;
public OnPluginStart()
{
 AddCommandListener(sayListener,"say")
 AddCommandListener(sayListener,"say_team")
 enabled = CreateConVar("monke_enabled","1","Monke")
 g_hGameConfig = LoadGameConfigFile("give.bots.cosmetics");
 if (!g_hGameConfig)
  {
   SetFailState("Failed to find give.bots.cosmetics.txt gamedata! Can't continue.");
  }	
	
 StartPrepSDKCall(SDKCall_Player);
 PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Virtual, "EquipWearable");
 PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
 g_hWearableEquip = EndPrepSDKCall();
}
public Action sayListener(client, const String:command[], argc)
{
 if(enabled.BoolValue&&IsPlayerAlive(client))
  {
   for(int i=0;i<3;i++)
    {
     CreateHat(client,itemlist[i],6)
    }
   PrintToChat(client,"You became monke")
  }
 return Plugin_Handled;
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
		SetEntData(hat, FindSendPropInfo(entclass, "m_iEntityLevel"), 50);
	}
	
	DispatchSpawn(hat);
	SDKCall(g_hWearableEquip, client, hat);
	return true;
} 
