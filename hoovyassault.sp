/*
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <menus>
#include <sdkhooks>
#include <string>
int HoovyClass[32]
int HoovyFlags[32] // bitsum
int HoovyRage[32] = 0
float HoovyCoords[32][3] // position
float HoovyMaxHealth[32]
bool HoovyValid[32]
bool MadeHisChoice[32] = false
bool BannerDeployed[32] = false
#define HOOVY_EFFECTS_RADIUS 315.0
#define MENU_TIMEOUT 4

public bool IsFood(weapon)
{
 static char classname[64]
 GetEdictClassname(weapon, classname, sizeof(classname))
 return !strcmp(classname,"tf_weapon_lunchbox")
}
stock min(a,b)
{
 return a>b?b:a
}
#define ValidUser(%1) ((1<=%1<=MaxClients)&&IsClientInGame(%1)&&IsPlayerAlive(%1))

#define MEDIC_HEAL 5 // HP/sec
#define COMISSAR_OVERHEAL 50.0
#define COMISSAR_DMGRES 0.9
#define OFFICER_DMGBONUS 1.1
#define TRUMPETER_BUFFTIME 10
#define TRUMPETER_DAMAGENEEDED 600


enum
{
HOOVY_SOLDIER=0,
HOOVY_MEDIC, // Healing allies closer than HOOVY_EFFECTS_RADIUS, BUT can use only melee
HOOVY_COMISSAR,// at choise:  +50 maximum health(not current health), +10% damage resistance
 //BUT: +30% received damage,-50% maximum health, -15% damage penalty for user at the same time
HOOVY_OFFICER,// +10% damage bonus for allies,+15% damage bonus for user,BUT -25% maximum health, +25% received damage 
 // The same effects ARE NOT summed up
HOOVY_SCOUT, // accelerated speed,every healthkit fully regenerates you,BUT: -40% health, -40% damage penalty
HOOVY_BOXER, // Kills anyone with one punch, but anyone can kill him with one punch
HOOVY_TRUMPETER,
NUM_CLASSES
}
enum
{
 Char_Maxhealth = 0,
 Char_Dmgbonus,
 Char_Dmgrespenalty,
 Num_Chars
}
float ClassChars[NUM_CLASSES][Num_Chars]={{1.0,1.0,1.0},{1.0,1.0,1.0},{0.5,0.85,1.3},{0.75,1.15,1.15},{0.6,0.6,1.0},{1.0,1.0,1.0},{0.7,1.0,1.0} }
char ClassDescription[NUM_CLASSES][]={
"no positive or negative effects",
"Healing allies,BUT may use only melee",
"+50 max HP,+10% dmg res for allies, BUT -50% HP,-30% dmg res,-15% dmg penalty for you",
" +10% dmg bonus for allies,+15% for you, BUT -15% HP,-15% dmg res for you",
"increased speed, BUT -40% HP,-40% dmg penalty",
"kills with one punch, dies from one punch",
"Activate Buff Banner by using POOTIS (press x then press 5), BUT always marked for death,-30% health"
}
char ClassName[NUM_CLASSES][]=
{
"Soldier",
"Medic",
"Comissar",
"Officer",
"Scout",
"Boxer",
"Trumpeter"
}
#define HOOVY_BIT_DMGBONUS (1<<1)
#define HOOVY_BIT_DMGRES (1<<2)
#define HOOVY_BIT_OVERHEAL (1<<3)
#define HOOVY_BIT_HEALING (1<<4)

ConVar meleeOnlyAllowed

public Plugin myinfo = 
{
 name = "Hoovy assault",
 author = "breins",
 description = "Battle of heavies",
 version = "0.0.10",
 url = ""
};
public OnPluginStart()
{
 for(int i=1;i<MaxClients;i++){HoovyClass[i] = HoovyFlags[i] = HoovyRage[i] = 0;if(IsClientInGame(i))doSDKHooks(i);}
 //LoadTranslations("hoovy.phrases")
 CreateTimer(1.0,UpdateHoovies,_, TIMER_REPEAT)
 HookEvent("player_spawn", Event_PlayerSpawn)
 HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre)
 HookEvent("item_pickup" , Event_ItemPickup)
 HookEvent("post_inventory_application" , Event_Resupply)
 AddCommandListener(VoiceCommand , "voicemenu")
 meleeOnlyAllowed = CreateConVar("hassault_melee_only","0","Enable/disable melee mode")
}
public Action OnTakeDamage(iVictim, &iAttacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(!ValidUser(iAttacker)||!ValidUser(iVictim))return Plugin_Continue
	if(HoovyFlags[iAttacker]&HOOVY_BIT_DMGBONUS)damage *= OFFICER_DMGBONUS
	if(HoovyFlags[iVictim]&HOOVY_BIT_DMGRES)damage  *= COMISSAR_DMGRES
	damage = damage * ClassChars[HoovyClass[iVictim]][Char_Dmgrespenalty] * ClassChars[HoovyClass[iAttacker]][Char_Dmgbonus]
	if(HoovyClass[iVictim]==HOOVY_BOXER||HoovyClass[iAttacker]==HOOVY_BOXER)
         {
	  if(getActiveSlot(iAttacker)==TFWeaponSlot_Melee)damage*=300.0
	 }
        if(HoovyClass[iAttacker]==HOOVY_TRUMPETER)
         {
          HoovyRage[iAttacker] = min(HoovyRage[iAttacker]+RoundToFloor(damage), TRUMPETER_DAMAGENEEDED)
         }
	return Plugin_Changed
}
public Action OnGetMaxHealth(int client, int &maxHealth)
{
 maxHealth = RoundToFloor(HoovyMaxHealth[client])
 return Plugin_Changed
}
public Action OnWeaponSwitch(int client, int weapon)
{
 if(HoovyClass[client] == HOOVY_MEDIC||meleeOnlyAllowed.BoolValue)
  {
   if(IsValidEntity(weapon))
    {
    static int melee
    melee = GetPlayerWeaponSlot(client,TFWeaponSlot_Melee)
    if(weapon==melee)return Plugin_Continue 
    }
   return Plugin_Handled
  }
 static int machinegun
 machinegun = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary)
 if(weapon == machinegun)
  {
  /*static int shotgun, melee, active
  shotgun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary)
  melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee)
  active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")
  if(active == shotgun)SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", melee)
  else SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", shotgun)*/
  return Plugin_Handled
  }
 return Plugin_Continue
}
public Action Event_PlayerDeath(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
 int iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"))
 if(iVictim>=1&&iVictim<=MaxClients)MadeHisChoice[iVictim] = false
}
public Action Event_ItemPickup(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
 int user = GetClientOfUserId(GetEventInt(hEvent, "userid"))
 static char itemid[28]
 if(HoovyClass[user] != HOOVY_SCOUT)return
 GetEventString(hEvent,"item",itemid,sizeof itemid)
 if(StrContains(itemid,"medkit",false)!=-1)SetEntityHealth(user,RoundToFloor(300.0*ClassChars[HOOVY_SCOUT][Char_Maxhealth]))
}
public Action Event_PlayerSpawn(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"))
	HoovyMaxHealth[client] = getMaxHealth(client)
        HoovyRage[client] = 0
        BannerDeployed[client] = false
	if(ValidUser(client))
	 {
	 CreateTimer(2.0,task_afterspawn,client)
	 }
}
public Action Event_Resupply(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
        new client = GetClientOfUserId(GetEventInt(hEvent, "userid"))
	RemoveUnwantedWeapons(client)
}
public OnClientConnected(id)
{
 HoovyClass[id] = HOOVY_SOLDIER
 HoovyFlags[id] = 0
 HoovyRage[id] = 0
 MadeHisChoice[id] = false
}
public OnClientPutInServer(client)
{
 doSDKHooks(client)
}
public void OnClientDisconnect(int client)
{
 removeSDKHooks(client)
}
public removeSDKHooks(client)
{
 SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage)
 SDKUnhook(client, SDKHook_GetMaxHealth,OnGetMaxHealth)
 if(IsFakeClient(client))SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch)
}
public doSDKHooks(client)
{
 SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage)
 SDKHook(client, SDKHook_GetMaxHealth,OnGetMaxHealth)
 if(IsFakeClient(client))SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch)
}
public showMenu(id)
{
 Menu menu = CreateMenu(MenuHandler)
 menu.SetTitle("Hoovy Class menu")
 char strinfo[2]
 strinfo[1] = '\0'
 for(int i=0;i<NUM_CLASSES;i++)
  {  
   strinfo[0] = i
   menu.AddItem(strinfo,ClassName[i])
  }
 strinfo[0]++
 menu.AddItem(strinfo ,"Help")
 menu.ExitBackButton = false
 menu.ExitButton = true
 menu.Display( id, MENU_TIMEOUT)
}
public MenuHandler(Handle menuid, MenuAction action, id, menu_item)
{ 
 if(action == MenuAction_End)CloseHandle(menuid)
 if(action == MenuAction_Select)
 {
  char strinfo[2]
  GetMenuItem(menuid, menu_item, strinfo, sizeof(strinfo))
  int result = strinfo[0]
  if(result<NUM_CLASSES)
   {
    MadeHisChoice[id] = true
    HoovyClass[id] = result 
    HoovyMaxHealth[id] = getMaxHealth(id)
    SetEntityHealth(id,RoundToFloor(HoovyMaxHealth[id]))
    TF2_RespawnPlayer(id)
    PrintToChat(id,"You will be able to pick other class after death")
   }
  else
   {
    ShowHelp(id)
   }
 }
}
public ShowHelp(id)
 {
  Menu menu = CreateMenu(HelpHandler)
  menu.SetTitle("Classes information")
  char strinfo[2]
  strinfo[1] = '\0'
  for(int i=0;i<NUM_CLASSES;i++)
   {  
    strinfo[0] = i
    menu.AddItem(strinfo,ClassName[i])
   }
  menu.ExitButton = false
  menu.ExitBackButton = true
  menu.Display( id, MENU_TIME_FOREVER)
 }
public HelpHandler(Handle menuid, MenuAction action, id, menu_item)
{ 
 if(action == MenuAction_Cancel)
  { 
   CloseHandle(menuid)
   if(!MadeHisChoice[id])showMenu(id)
  }
 if(action == MenuAction_Select)
 {
  char strinfo[2]
  GetMenuItem(menuid, menu_item, strinfo, sizeof(strinfo))
  ShowClassHelp(id,strinfo[0])
 }
}
public ShowClassHelp(id,classid)
{
  Menu menu = CreateMenu(ClassHelpHandler)
  menu.SetTitle(ClassName[classid])
  menu.AddItem("1",ClassDescription[classid])
  menu.ExitBackButton = true
  menu.ExitButton = false
  menu.Display(id , MENU_TIME_FOREVER)
}
public ClassHelpHandler(Handle menuid, MenuAction action, id, menu_item)
{ 
 if(action == MenuAction_Cancel||action == MenuAction_Select)
  { 
   CloseHandle(menuid)
   ShowHelp(id)
  }
}
public TryHealing(id)
{
  HoovyMaxHealth[id] = getMaxHealth(id)
  if(HoovyFlags[id]&HOOVY_BIT_HEALING)
   {
   SetEntityHealth(id,GetClientHealth(id)+MEDIC_HEAL)
   AttachParticle(id,TF2_GetClientTeam(id) == TFTeam_Red?"healthgained_red":"healthgained_blu","head",_,1.0);
   }
  if(GetClientHealth(id)>RoundToFloor(HoovyMaxHealth[id]))SetEntityHealth(id,RoundToFloor(HoovyMaxHealth[id]))
}

public HoovyBasicOperations()
{ 
 static int i
 for(i = 1;i < MaxClients;i++)
  {
  if(!ValidUser(i))
   {
    HoovyValid[i] = false
    continue
   }
  HoovyValid[i] = true
  HoovyFlags[i] = 0
  GetClientAbsOrigin(i, HoovyCoords[i])
  RemoveUnwantedWeapons(i)
  if(IsFakeClient(i)&&(HoovyClass[i]==HOOVY_MEDIC||meleeOnlyAllowed.BoolValue))setActiveSlot(i,TFWeaponSlot_Melee) // force medic bot to use melee
  if(HoovyClass[i]==HOOVY_SCOUT)TF2_AddCondition(i, TFCond_SpeedBuffAlly, 1.1)
  if(HoovyClass[i]==HOOVY_BOXER)
   {
    if(getItemIndex(GetPlayerWeaponSlot(i, TFWeaponSlot_Melee))==43)TF2_AddCondition(i,TFCond_MarkedForDeathSilent,1.1)
   }
  if(HoovyClass[i]==HOOVY_TRUMPETER)
   { 
    TF2_AddCondition(i,TFCond_MarkedForDeathSilent,1.1)
    Handle hHudText = CreateHudSynchronizer()
    SetHudTextParams(-1.0, 0.8, 0.4, 255, 0, 0, 255)
    ShowSyncHudText(i, hHudText, "Buff:%i/%i",HoovyRage[i],TRUMPETER_DAMAGENEEDED)
    CloseHandle(hHudText);
    if(!BannerDeployed[i]&&HoovyRage[i]==TRUMPETER_DAMAGENEEDED&&IsFakeClient(i))BannerDeployed[i] = true
    if(BannerDeployed[i])
     {
      HoovyRage[i]-=(TRUMPETER_DAMAGENEEDED/TRUMPETER_BUFFTIME)
      if(HoovyRage[i]<=0)
       {
        BannerDeployed[i] = false
        HoovyRage[i] = 0
       }
     }
   }
  }
}
public RemoveUnwantedWeapons(i)
{
   if(!IsFakeClient(i))
   {
   if(getActiveSlot(i)==TFWeaponSlot_Primary)setActiveSlot(i,HoovyClass[i]==HOOVY_MEDIC?TFWeaponSlot_Melee:TFWeaponSlot_Secondary)
   TF2_RemoveWeaponSlot(i,TFWeaponSlot_Primary) // Anti-repick protection
   if(HoovyClass[i]==HOOVY_MEDIC||meleeOnlyAllowed.BoolValue)
    {
    static int weapon
    weapon = GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary)
    if(weapon!=-1&&!IsFood(weapon))TF2_RemoveWeaponSlot(i,TFWeaponSlot_Secondary)
    }
   }
}
public CheckBuffZones()
{
  static  int i,j
  for(i = 1;i < MaxClients;i++)
  {
   if(!HoovyValid[i])continue;
   for(j = 1; j < MaxClients; j++)
    {
     if(!HoovyValid[j]||HoovyClass[j] == HOOVY_SOLDIER||HoovyClass[j] == HOOVY_SCOUT||TF2_GetClientTeam(i)!=TF2_GetClientTeam(j))continue;
     if(GetVectorDistance(HoovyCoords[i],HoovyCoords[j])<=HOOVY_EFFECTS_RADIUS)
      {
      switch(HoovyClass[j])
       {
        case(HOOVY_MEDIC):
	 {
	 HoovyFlags[i] |= HOOVY_BIT_HEALING
	 }
        case(HOOVY_COMISSAR):
          {
	   if(i!=j)
	    {
            HoovyFlags[i] |= HOOVY_BIT_DMGRES
	    HoovyFlags[i] |= HOOVY_BIT_OVERHEAL
	    }
	  }
	case(HOOVY_OFFICER):
          {
	   if(i!=j)HoovyFlags[i]|=HOOVY_BIT_DMGBONUS
	  }
        case(HOOVY_TRUMPETER):
          {
           if(BannerDeployed[j])TF2_AddCondition(i,TFCond_Buffed,1.1)
          }
       }
     }
    }
   TryHealing(i)
  }
}

public Action Timer_DeleteParticle(Handle:hTimer, any:iRefEnt)
{
	new iEntity = EntRefToEntIndex(iRefEnt);
	if(iEntity > MaxClients)
	{
		AcceptEntityInput(iEntity, "Kill");
	}
	
	return Plugin_Handled;
}
public Action UpdateHoovies(Handle timer)
{
 HoovyBasicOperations()
 CheckBuffZones()
}
public Action task_afterspawn(Handle timer, client)
{
 if(!ValidUser(client))return
 if(!IsFakeClient(client))
  { 
  if(!MadeHisChoice[client])showMenu(client)
  }
 else HoovyClass[client] = GetRandomInt(0,6)
 if(TF2_GetPlayerClass(client)!=TFClass_Heavy)
   {
   MadeHisChoice[client] = false
   TF2_SetPlayerClass(client, TFClass_Heavy)
   TF2_RespawnPlayer(client)
   }
}
public Action VoiceCommand(client, const String:command[], argc)
{
 if(!HoovyValid[client]||HoovyClass[client]!=HOOVY_TRUMPETER||HoovyRage[client]<TRUMPETER_DAMAGENEEDED||BannerDeployed[client])return Plugin_Continue
 char Numbers[32] // thats even too much
 GetCmdArgString(Numbers, sizeof(Numbers))
 TrimString(Numbers)
 if(StrEqual(Numbers,"1 4"))BannerDeployed[client] = true
 return Plugin_Continue
}
AttachParticle(iEntity, const String:strParticleEffect[], const String:strAttachPoint[]="", Float:flOffsetZ=0.0, Float:flSelfDestruct=0.0)
{
	new iParticle = CreateEntityByName("info_particle_system");
	if(iParticle > MaxClients && IsValidEntity(iParticle))
	{
		new Float:flPos[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flPos);
		flPos[2] += flOffsetZ;
		
		TeleportEntity(iParticle, flPos, NULL_VECTOR, NULL_VECTOR);
		
		DispatchKeyValue(iParticle, "effect_name", strParticleEffect);
		DispatchSpawn(iParticle);
		
		SetVariantString("!activator");
		AcceptEntityInput(iParticle, "SetParent", iEntity);
		ActivateEntity(iParticle);
		
		if(strlen(strAttachPoint))
		{
			SetVariantString(strAttachPoint);
			AcceptEntityInput(iParticle, "SetParentAttachmentMaintainOffset");
		}
		
		AcceptEntityInput(iParticle, "start");
		
		if(flSelfDestruct > 0.0) CreateTimer(flSelfDestruct, Timer_DeleteParticle, EntIndexToEntRef(iParticle));
		
		return iParticle;
	}
	
	return 0;
}
stock getItemIndex(item)
{
 return GetEntProp(item,Prop_Send, "m_iItemDefinitionIndex")
}
stock getActiveSlot(id)
{
 static int gun, primary, secondary, melee
 gun = GetEntPropEnt(id, Prop_Send, "m_hActiveWeapon")
 if(gun==-1)return -1
 primary = GetPlayerWeaponSlot(id,TFWeaponSlot_Primary)
 secondary = GetPlayerWeaponSlot(id,TFWeaponSlot_Secondary)
 melee = GetPlayerWeaponSlot(id,TFWeaponSlot_Melee)
 if(gun==primary)return TFWeaponSlot_Primary
 if(gun==secondary)return TFWeaponSlot_Secondary
 if(gun==melee)return TFWeaponSlot_Melee
 return -1
}
stock setActiveSlot(client,slot)
{
  new iWeapon = GetPlayerWeaponSlot(client, slot);
  if(IsValidEntity(iWeapon))
  {
   SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon);
  }
}
public float getMaxHealth(id)
{
  static float newmaxhealth 
  newmaxhealth = 300.0
  newmaxhealth *= ClassChars[HoovyClass[id]][Char_Maxhealth]
  if(HoovyFlags[id]&HOOVY_BIT_OVERHEAL)newmaxhealth += COMISSAR_OVERHEAL
  return newmaxhealth
}
