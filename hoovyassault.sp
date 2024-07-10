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
int HoovyClass[MAXPLAYERS]
int HoovyFlags[MAXPLAYERS] // bitsum
int HoovyRage[MAXPLAYERS] = 0
float HoovyCoords[MAXPLAYERS][3] // position
float HoovyMaxHealth[MAXPLAYERS]
int HoovyDeaths[2] = 0 // 0 = RED, 1 = BLU
bool HoovyValid[MAXPLAYERS]
bool HoovySpecialDelivery[MAXPLAYERS]
bool MadeHisChoice[MAXPLAYERS] = false
bool BannerDeployed[MAXPLAYERS] = false
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

#define MEDIC_HEAL 15 // HP/tic
#define MEDIC_TICK 0.2 // seconds
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
HOOVY_BOOMER,
NUM_CLASSES
}
enum
{
 Char_Maxhealth = 0,
 Char_Dmgbonus,
 Char_Dmgrespenalty,
 Num_Chars
}
float ClassChars[NUM_CLASSES][Num_Chars]={{1.25,1.0,1.0},{1.0,1.0,1.0},{0.5,0.85,1.3},{0.75,1.20,1.15},{0.6,0.6,1.0},{1.0,1.0,1.0},{0.7,1.0,1.0}, {0.26,0.3,1.0} }

#define BOT_CLASS_LIMIT 2

char ClassDescription[NUM_CLASSES][]={
"Health bonus +75 HP",
"Healing allies,BUT may use only melee",
"+50 max HP,+10% dmg res for allies, BUT -50% HP,-30% dmg res,-15% dmg penalty for you",
" +10% dmg bonus for allies,+15% for you, BUT -15% HP,-15% dmg res for you",
"increased speed, BUT -40% HP,-40% dmg penalty",
"kills with one punch, dies from one punch",
"Activate Buff Banner by using POOTIS (press x then press 5), BUT always marked for death,-30% health",
"Now your most terrifying weapon is your sandwich",
}
char ClassName[NUM_CLASSES][]=
{
"Soldier",
"Medic",
"Comissar",
"Officer",
"Scout",
"Boxer",
"Trumpeter",
"Boomer"
}
#define HOOVY_BIT_DMGBONUS (1<<1)
#define HOOVY_BIT_DMGRES (1<<2)
#define HOOVY_BIT_OVERHEAL (1<<3)
#define HOOVY_BIT_HEALING (1<<4)

#define SOUND_BOOM "items/cart_explode.wav"
#define BOOM_RADIUS 600.0


ConVar meleeOnlyAllowed

#define BOOMER_VO_NUM 8
char boomer_sounds[BOOMER_VO_NUM][] = {
"vo/heavy_sandwichtaunt06.mp3",
"vo/heavy_sandwichtaunt10.mp3",
"vo/heavy_sandwichtaunt15.mp3",
"vo/heavy_specialweapon08.mp3",
"vo/heavy_domination15.mp3",
"vo/heavy_award10.mp3",
"vo/heavy_meleeing01.mp3",
"vo/heavy_mvm_bomb_see01.mp3"
}

public Plugin myinfo = 
{
 name = "Hoovy assault",
 author = "breins",
 description = "Battle of heavies",
 version = "0.0.12",
 url = ""
};
public OnPluginStart()
{
    for(int i=1;i<MaxClients;i++){HoovyClass[i] = HoovyFlags[i] = HoovyRage[i] = 0;if(IsClientInGame(i))doSDKHooks(i);}
    //LoadTranslations("hoovy.phrases")
    CreateTimer(1.0,UpdateHoovies,_, TIMER_REPEAT)
    CreateTimer(MEDIC_TICK,HealTimer,_,TIMER_REPEAT)
    HookEvent("player_spawn", Event_PlayerSpawn)
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre)
    HookEvent("item_pickup" , Event_ItemPickup)
    HookEvent("post_inventory_application" , Event_Resupply)
    HookEvent("player_stealsandvich", Event_StealSandwich)
    AddCommandListener(VoiceCommand , "voicemenu")
    meleeOnlyAllowed = CreateConVar("hassault_melee_only","0","Enable/disable melee mode")
    HoovyDeaths[0] = HoovyDeaths[1] = 0
}
public OnMapStart()
{
    PrecacheSound(SOUND_BOOM)
    for(int i = 0 ; i < BOOMER_VO_NUM; i++)
    {
        PrecacheSound(boomer_sounds[i])
    }
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
    if(iVictim>=1&&iVictim<=MaxClients)
    {
        MadeHisChoice[iVictim] = false
        if(TF2_GetClientTeam(iVictim)==TFTeam_Red)HoovyDeaths[0]++
        else HoovyDeaths[1]++
    }
}
public Action Event_ItemPickup(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
    int user = GetClientOfUserId(GetEventInt(hEvent, "userid"))
    static char itemid[28]
    GetEventString(hEvent,"item",itemid,sizeof itemid)
    if(HoovyClass[user] != HOOVY_SCOUT)return
    if(StrContains(itemid,"medkit",false)!=-1)SetEntityHealth(user,RoundToFloor(300.0*ClassChars[HOOVY_SCOUT][Char_Maxhealth]))
}
public Action Event_PlayerSpawn(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(hEvent, "userid"))
    HoovySpecialDelivery[client] = false
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
    HoovySpecialDelivery[client] = false
}
public Action Event_StealSandwich(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
    int owner = GetClientOfUserId(GetEventInt(hEvent,"owner"))
    int target = GetClientOfUserId(GetEventInt(hEvent,"target"))
    if(HoovyClass[owner]==HOOVY_BOOMER)// I have a new way to kill cowards!
    {
        PrintToChatAll("Ooops, somebody just ate the wrong sandwich")
        ExplodeSandwich(target,owner)
    }
}
public OnClientConnected(id)
{
    HoovyClass[id] = HOOVY_SOLDIER
    HoovyFlags[id] = 0
    HoovyRage[id] = 0
    HoovySpecialDelivery[id] = false
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
public ShowMainMenu(id)
{
    if(!ValidUser(id))return
    CancelClientMenu(id)
    Menu menu = CreateMenu(MainMenuHandler)
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
public MainMenuHandler(Handle menuid, MenuAction action, id, menu_item)
{
    if(action == MenuAction_End)CloseHandle(menuid)
    else if(action == MenuAction_Select)
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
  if(!ValidUser(id))return
  CancelClientMenu(id)
  Menu menu = CreateMenu(HelpHandler)
  menu.SetTitle("Classes information")
  char strinfo[2]
  strinfo[1] = '\0'
  for(int i=0;i<NUM_CLASSES;i++)
  {  
    strinfo[0] = i
    menu.AddItem(strinfo,ClassName[i])
  }
  menu.ExitButton = true
  menu.ExitBackButton = true
  menu.Display( id, MENU_TIMEOUT*3)
}
public HelpHandler(Handle menuid, MenuAction action, id, menu_item)
{
 if(action == MenuAction_End)CloseHandle(menuid)
 if(action == MenuAction_Cancel)
 { 
   if(!MadeHisChoice[id])ShowMainMenu(id)
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
  if(!ValidUser(id))return
  CancelClientMenu(id)
  Menu menu = CreateMenu(ClassHelpHandler)
  menu.SetTitle(ClassName[classid])
  menu.AddItem("1",ClassDescription[classid])
  menu.ExitBackButton = true
  menu.ExitButton = false
  menu.Display(id , MENU_TIMEOUT*4)
}
public ClassHelpHandler(Handle menuid, MenuAction action, id, menu_item)
{
 if(action == MenuAction_End)CloseHandle(menuid)
 if(action == MenuAction_Cancel||action == MenuAction_Select)
 {
     ShowHelp(id)
 }
 else ShowMainMenu(id)
}
public TryHealing(id)
{
  HoovyMaxHealth[id] = getMaxHealth(id)
  if(HoovyFlags[id]&HOOVY_BIT_HEALING||HoovyClass[id]==HOOVY_MEDIC)
  {
   static int clienthealth
   clienthealth = GetClientHealth(id)+RoundToFloor(MEDIC_HEAL*MEDIC_TICK)
   SetEntityHealth(id,clienthealth)
   if(clienthealth<HoovyMaxHealth[id])AttachParticle(id,TF2_GetClientTeam(id) == TFTeam_Red?"healthgained_red":"healthgained_blu","head",_,1.0);
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
   static int weapon
   if(!IsFakeClient(i))
   {
       if(getActiveSlot(i)==TFWeaponSlot_Primary)setActiveSlot(i,HoovyClass[i]==HOOVY_MEDIC?TFWeaponSlot_Melee:TFWeaponSlot_Secondary)
       TF2_RemoveWeaponSlot(i,TFWeaponSlot_Primary) // Anti-repick protection
       if(HoovyClass[i]==HOOVY_MEDIC||HoovyClass[i]==HOOVY_BOOMER||meleeOnlyAllowed.BoolValue)
       {
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
     if(!HoovyValid[j]||HoovyClass[j] == HOOVY_SOLDIER||HoovyClass[j] == HOOVY_SCOUT||TF2_GetClientTeam(i)!=TF2_GetClientTeam(j)||(i==j&&HoovyClass[j]!=HOOVY_TRUMPETER))continue;
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
          HoovyFlags[i] |= HOOVY_BIT_DMGRES
          HoovyFlags[i] |= HOOVY_BIT_OVERHEAL
	}
	case(HOOVY_OFFICER):
        {
	  HoovyFlags[i]|=HOOVY_BIT_DMGBONUS
	}
        case(HOOVY_TRUMPETER):
        {
          if(BannerDeployed[j])TF2_AddCondition(i,TFCond_Buffed,1.1)
        }
      }
    }
   }
  }
}
public Action ExplosiveSandwichTimer(Handle timer,int client)
{
    HoovySpecialDelivery[client] = false
    static int entity
    entity = findMySandwich(client)
    if(entity==-1)return
    ExplodeSandwich(entity,client)
}
public Action HealTimer(Handle timer)
{
    static int i
    for(i=1;i<MaxClients;i++)if(ValidUser(i))TryHealing(i)
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
  if(!MadeHisChoice[client])ShowMainMenu(client)
 }
 else HoovyClass[client] = PickBotClass(client)
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
public Action OnPlayerRunCmd(client,&buttons)
{
    if((!(buttons&IN_ATTACK2))||HoovyClass[client]!=HOOVY_BOOMER||!ValidUser(client)||getActiveSlot(client)!=TFWeaponSlot_Secondary||HoovySpecialDelivery[client])return Plugin_Continue
    HoovySpecialDelivery[client] = true
    float expltime = GetURandomFloat()*3.0
    PrintToChatAll("An explosive sandwich has been deployed in this area. Time to take cover, probably.")
    CreateTimer(expltime>1.0?expltime:1.0,ExplosiveSandwichTimer,client)
    EmitSoundToAll(boomer_sounds[GetRandomInt(0,BOOMER_VO_NUM-1)],client)
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
stock countClass(id,cl)
{
    static int i,ctr
    ctr = 0
    for(i = 0; i < MaxClients;i++)
    {
        if(!HoovyValid[i]||i==id)continue;
        if(HoovyClass[i]==cl)ctr++
    }
    return ctr
}
stock findMySandwich(id)
{
    static int entity
    entity = -1
    while ((entity = FindEntityByClassname(entity, "item_healthkit_medium")) != -1)
    {
        if(IsValidEntity(entity)&&HasEntProp(entity,Prop_Send,"m_hOwnerEntity")&&(GetEntPropEnt(entity,Prop_Send,"m_hOwnerEntity")==id))return entity
    }
    while ((entity = FindEntityByClassname(entity, "item_healthkit_small")) != -1)
    {
        if(IsValidEntity(entity)&&HasEntProp(entity,Prop_Send,"m_hOwnerEntity")&&(GetEntPropEnt(entity,Prop_Send,"m_hOwnerEntity")==id))return entity
    }
    return -1
}
stock PickBotClass(id)
{
    static int i,j,cl,count
    ArrayList nClasses = CreateArray(1)
    for(i=0;i<NUM_CLASSES;i++)
    {
        if(countClass(id,i)<BOT_CLASS_LIMIT)
        {
            count = GetRandomInt(0,BOT_CLASS_LIMIT)
            for(j=0;j<count;j++)
            {
                nClasses.Push(i)
            }
        }
    }
    count = GetArraySize(nClasses)
    if(!count)
    {
        ClearArray(nClasses)
        return (GetRandomInt(0,100)>40)?0:GetRandomInt(1,NUM_CLASSES-1)
    }
    cl = GetArrayCell(nClasses,GetRandomInt(0,count-1))
    ClearArray(nClasses)
    delete nClasses
    return cl
}
stock ExplodeSandwich(int targetent,int owner)
{
    static int i
    static float pos[3]
    static float dist
    static float where[3]
    GetEntPropVector(targetent, Prop_Send, "m_vecOrigin", where)
    //if(targetent>=MaxClients)AcceptEntityInput(targetent, "Kill")
    EmitSoundToAll(SOUND_BOOM,SOUND_FROM_WORLD,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL,-1,where)
    AttachParticle(targetent,"hightower_explosion","",0.0,10.0)
    for(i=0;i<MaxClients;i++)
    {
        if(!ValidUser(i)||(i!=owner&&TF2_GetClientTeam(i)==TF2_GetClientTeam(owner)))continue;
        GetClientAbsOrigin(i,pos)
        dist = GetVectorDistance(pos,where)
        if(dist<BOOM_RADIUS) // if he shoots you, you'll probably die
        {
            SDKHooks_TakeDamage(i, 0, owner, dist<(BOOM_RADIUS/2.0)?320.0:(320.0*dist/BOOM_RADIUS), DMG_PREVENT_PHYSICS_FORCE|DMG_CRUSH|DMG_ALWAYSGIB)
        }
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
