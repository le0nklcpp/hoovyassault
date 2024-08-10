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

#define HOOVY_POINTS_LIMIT 65

#define GBW_STAGING 1 // set to 1 to enable the following features: Comissar SMG
#define SPELLS_STAGING 1 // set to 1 to enable the following features: Spells
#define HOOVY_CLASSAPI_ENABLED 1 // set to 1 to enable Hoovy Assault Plugin API

int HoovyClass[MAXPLAYERS]
int HoovyFlags[MAXPLAYERS] // bitsum
int HoovyRage[MAXPLAYERS] = 0
bool HoovyVisuals[MAXPLAYERS] = true
float HoovyCoords[MAXPLAYERS][3] // position
float HoovyMaxHealth[MAXPLAYERS]
int HoovyScores[2] = 0 // 0 = RED, 1 = BLU

bool HoovyValid[MAXPLAYERS] = false
bool HoovySpecialDelivery[MAXPLAYERS] = false
bool MadeHisChoice[MAXPLAYERS] = false
bool BannerDeployed[MAXPLAYERS] = false


int BeamSprite[2],HaloSprite

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
#define TeamScoresIndex(%1) (TF2_GetClientTeam(%1)==TFTeam_Blue?1:0)
#define ValidUser(%1) ((1<=%1<=MaxClients)&&IsClientInGame(%1)&&IsPlayerAlive(%1))
#define HOOVY_CYCLE_TIME 0.2
#define HOOVY_EFFECTS_RADIUS 315.0
#define MENU_TIMEOUT 4
#define MEDIC_HEAL 15 // HP/tic
#define MEDIC_FIST_HEAL 35
#define MEDIC_HEAL_FIST_DELAY 1.5
#define MEDIC_OVERHEAL 100
#define MEDIC_TICK 0.2 // seconds
#define COMISSAR_OVERHEAL 50.0
#define COMISSAR_DMGRES 0.9
#define OFFICER_DMGBONUS 1.1
#define TRUMPETER_BUFFTIME 10
#define TRUMPETER_DAMAGENEEDED 600

#define HOOVY_BIT_DMGBONUS (1<<1)
#define HOOVY_BIT_DMGRES (1<<2)
#define HOOVY_BIT_OVERHEAL (1<<3)
#define HOOVY_BIT_HEALING (1<<4)

#define SOUND_HEAL "items/smallmedkit1.wav"
#define SOUND_BOOM "items/cart_explode.wav"
#define SOUND_RJUMP "weapons/rocket_jumper_explode1.wav"

#define BOOM_RADIUS 600.0

#define LEAPER_VEL 1200.0
#define LEAPER_SPEED 8.0
#define BOT_CLASS_LIMIT 2

#define DISPENSER_COST 5
#define SENTRY_COST 12

#if GBW_STAGING
#include "hoovyassault_module_gbw.inc"
#endif
enum
{
HOOVY_SOLDIER=0,
HOOVY_MEDIC, // Healing allies closer than HOOVY_EFFECTS_RADIUS, BUT can use only melee
HOOVY_COMISSAR,// at choise:  +50 maximum health(not current health), +10% damage resistance
 //BUT: +30% received damage,-50% maximum health, -15% damage penalty for user at the same time
HOOVY_OFFICER,// +10% damage bonus for allies,+15% damage bonus for user,BUT -25% maximum health, +25% received damage 
 // The same effects ARE NOT summed up
HOOVY_SCOUT, // accelerated speed,every healthkit fully regenerates you,BUT: -40% health, -15% damage penalty
HOOVY_BOXER, // Kills anyone with one punch, but anyone can kill him with one punch
HOOVY_TRUMPETER,
HOOVY_BOOMER,
HOOVY_LEAPER,
HOOVY_ENGINEER,
HOOVY_GNOME,
NUM_CLASSES
}
enum
{
 Char_Maxhealth = 0, Char_Dmgbonus, Char_Dmgrespenalty, Num_Chars
}
float ClassChars[NUM_CLASSES][Num_Chars]={
{1.25,1.0,1.0},  // HOOVY_SOLDIER
{1.0,1.0,1.0},   // HOOVY_MEDIC
{0.5,0.85,1.3},  // HOOVY_COMISSAR
{0.75,1.20,1.15},// HOOVY_OFFICER
{0.6,0.85,1.0},  // HOOVY_SCOUT
{1.0,1.0,1.0},   // HOOVY_BOXER
{0.7,1.0,1.0},   // HOOVY_TRUMPETER
{0.26,0.3,1.0},  // HOOVY_BOOMER
{0.84,0.6,1.3},  // HOOVY_LEAPER
{0.5,1.0,1.0},   // HOOVY_ENGINEER
{0.25,0.5,0.5}   // HOOVY_GNOME
}

// negative value means it can't be accessed using the class menu. Set to -2 to remove it from help too
int ClassLimit[NUM_CLASSES]=
{
0,  // HOOVY_SOLDIER
0,  // HOOVY_MEDIC
0,  // HOOVY_COMISSAR
0,  // HOOVY_OFFICER
0,  // HOOVY_SCOUT
0,  // HOOVY_BOXER
0,  // HOOVY_TRUMPETER
2,  // HOOVY_BOOMER
0,  // HOOVY_LEAPER
1,  // HOOVY_ENGINEER
2   // HOOVY_GNOME
}


char ClassDescription[NUM_CLASSES][]={
"Health bonus +75 HP",
"Healing allies,BUT may use only melee",
"+50 max HP,+10% dmg res for allies, BUT -50% HP,-30% dmg res,-15% dmg penalty for you",
" +10% dmg bonus for allies,+15% for you, BUT -15% HP,-15% dmg res for you",
"increased speed, BUT -40% HP,-40% dmg penalty",
"kills with one punch, dies from one punch",
"Activate Buff Banner by using POOTIS (press x then press 5), BUT always marked for death,-30% health",
"Now your most terrifying weapon is your sandwich",
"Jump really high using RMB, -30% dmg resistance, -15% dmg penalty",
"Put dispenser here by saying \"Put dispenser here\"(press x then press 5), -85% health,damage penalty based on health",
"Cast gruesome spells on your foes and allies"
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
"Boomer",
"Leaper",
"Engineer",
"Gnome wizard"
}


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
// modules that require basic Heavyassault constants
#if SPELLS_STAGING
#include "hoovyassault_module_spells"
#endif
#if HOOVY_CLASSAPI_ENABLED
#include "hoovyassault_module_classapi"
#endif
public Plugin myinfo = 
{
 name = "Hoovy assault",
 author = "breins",
 description = "Battle of heavies",
 version = "10.08.24.2",
 url = ""
};
public OnPluginStart()
{
    for(int i=1;i<MaxClients;i++){HoovyClass[i] = HoovyFlags[i] = HoovyRage[i] = 0;if(IsClientInGame(i))doSDKHooks(i);}
    //LoadTranslations("hoovy.phrases")
    CreateTimer(HOOVY_CYCLE_TIME,UpdateHoovies,_, TIMER_REPEAT)
    CreateTimer(MEDIC_TICK,HealTimer,_,TIMER_REPEAT)
    HookEvent("player_spawn", Event_PlayerSpawn)
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre)
    HookEvent("item_pickup" , Event_ItemPickup)
    HookEvent("post_inventory_application" , Event_Resupply)
    HookEvent("player_stealsandvich", Event_StealSandwich)
    HookEvent("teamplay_round_start", Event_RoundStart)
    HookEvent("teamplay_point_captured",Event_PointCaptured)
    HookEvent("teamplay_flag_event",Event_FlagEvent)
    HookEvent("killed_capping_player",Event_KilledCappingPlayer)
    AddCommandListener(VoiceCommand , "voicemenu")
    AddCommandListener(SayCommand, "say")
    AddCommandListener(SayCommand, "say_team")
    meleeOnlyAllowed = CreateConVar("hassault_melee_only","0","Enable/disable melee mode")
    HoovyScores[0] = HoovyScores[1] = 0
    #if GBW_STAGING
    GBW_Staging_OnPluginStart()
    #endif
    #if SPELLS_STAGING
    Spells_OnPluginStart()
    #endif
    #if HOOVY_CLASSAPI_ENABLED
    Hoovyassault_Classapi_Init()
    #endif
}
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (GetEngineVersion() != Engine_TF2) 
    {
        Format(error, err_max, "This plugin only works for Team Fortress 2.")
        return APLRes_Failure
    }
    CreateNative("GetHoovyClass",NativeGetHoovyClass)
    CreateNative("SetHoovyClass",NativeSetHoovyClass)
    CreateNative("AddHoovyScores",NativeAddHoovyScores)
    CreateNative("WithdrawHoovyScores",NativeWithdrawHoovyScores)
    CreateNative("GetHoovyScores", NativeGetHoovyScores)
    CreateNative("SetHoovyScores", NativeSetHoovyScores)
    #if HOOVY_CLASSAPI_ENABLED
    Hoovyassault_Classapi_Create_Natives()
    #endif
    return APLRes_Success
}
public OnMapStart()
{
    PrecacheSound(SOUND_BOOM)
    PrecacheSound(SOUND_RJUMP)
    PrecacheSound(SOUND_HEAL)
    BeamSprite[0] = PrecacheModel("materials/sprites/healbeam_blue.vmt")
    BeamSprite[1] = PrecacheModel("materials/sprites/healbeam.vmt")
    HaloSprite = PrecacheModel("materials/sprites/glow02.vmt")
    for(int i = 0 ; i < BOOMER_VO_NUM; i++)
    {
        PrecacheSound(boomer_sounds[i])
    }
    #if SPELLS_STAGING
    Spells_OnMapStart()
    #endif
}
public Action OnPlayerRunCmd(int client,int &buttons)
{
    if(!(buttons&IN_ATTACK2)||!ValidUser(client)||HoovySpecialDelivery[client])return Plugin_Continue
    if(HoovyClass[client]==HOOVY_BOOMER)
    {
        if(getActiveSlot(client)!=TFWeaponSlot_Secondary)return Plugin_Continue
        HoovySpecialDelivery[client] = true
        float expltime = GetURandomFloat()*3.0
        PrintToChatAll("An explosive sandwich has been deployed in this area. Time to take cover, probably.")
        CreateTimer(expltime>1.0?expltime:1.0,ExplosiveSandwichTimer,client)
        EmitSoundToAll(boomer_sounds[GetRandomInt(0,BOOMER_VO_NUM-1)],client)
    }
    else if(HoovyClass[client]==HOOVY_LEAPER)
    {
        static float angles[3],vel[3],fwd[3],right[3],up[3],cur[3]
        vel[0]=vel[1]=vel[2]=0.0
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", cur)
        GetClientAbsAngles(client,angles)
        GetAngleVectors(angles,fwd,right,up)
        AddVectors(vel,fwd,vel)
        AddVectors(vel,right,vel)
        AddVectors(vel,up,vel)
        ScaleVector(vel,LEAPER_VEL)
        AddVectors(vel,cur,vel)
        setPlayerSpeed(client,1.0)
        if(vel[2]>0)
        {
            GetClientAbsOrigin(client,cur)
            EmitSoundToAll(SOUND_RJUMP,SOUND_FROM_WORLD,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL,-1,cur)
            HoovySpecialDelivery[client] = true
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel)
            CreateTimer(12.0,Timer_ResetJumping,client)
        }
        //setPlayerSpeed(client,LEAPER_SPEED)
        return Plugin_Handled
    }
    return Plugin_Continue
}
public Action OnTakeDamage(iVictim, &iAttacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
    static bool validVictim
    validVictim = ValidUser(iVictim)
    if(!ValidUser(iAttacker))return Plugin_Continue
    #if HOOVY_CLASSAPI_ENABLED
    static Action APIResult
    APIResult = Hoovyassault_Classapi_TakeDamage(iVictim,iAttacker,inflictor,damage,damagetype,weapon)
    if(APIResult!=Plugin_Continue)return APIResult
    #endif
    if(HoovyClass[iAttacker]==HOOVY_GNOME&&(damagetype&DMG_BURN))return Plugin_Continue
    if(HoovyFlags[iAttacker]&HOOVY_BIT_DMGBONUS)damage *= OFFICER_DMGBONUS
    if(validVictim)
    {
        if(HoovyFlags[iVictim]&HOOVY_BIT_DMGRES)damage  *= COMISSAR_DMGRES
        #if HOOVY_CLASSAPI_ENABLED
        OnClassApi(iVictim,damage = damage * HoovyExtraClassParams[ClassApiIndex(HoovyClass[iVictim])][Char_Dmgrespenalty])
        else 
        #endif
        damage = damage * ClassChars[HoovyClass[iVictim]][Char_Dmgrespenalty]
    }
    #if GBW_STAGING
    if(HoovyClass[iAttacker]==HOOVY_COMISSAR&&getActiveSlot(iAttacker)==TFWeaponSlot_Secondary)damage = damage * 1.25
    else
    #endif
    #if HOOVY_CLASSAPI_ENABLED
    OnClassApi(iAttacker,damage = damage * HoovyExtraClassParams[ClassApiIndex(HoovyClass[iAttacker])][Char_Dmgbonus])
    else
    #endif
    damage = damage * ClassChars[HoovyClass[iAttacker]][Char_Dmgbonus]
    if((validVictim&&HoovyClass[iVictim]==HOOVY_BOXER)||HoovyClass[iAttacker]==HOOVY_BOXER)
    {
        if(TF2_GetClientTeam(iAttacker)!=TF2_GetClientTeam(iVictim)&&(damagetype&DMG_CLUB))
        {
            damage = validVictim?float(GetClientHealth(iVictim)):(damage*2)
        }
    }
    if(HoovyClass[iAttacker]==HOOVY_TRUMPETER)
    {
        HoovyRage[iAttacker] = min(HoovyRage[iAttacker]+RoundToFloor(damage), TRUMPETER_DAMAGENEEDED)
    }
    else if(HoovyClass[iAttacker]==HOOVY_ENGINEER&&weapon == GetPlayerWeaponSlot(iAttacker,TFWeaponSlot_Secondary))
    {
        damage *= float(GetClientHealth(iAttacker))/HoovyMaxHealth[iAttacker]
    }
    return Plugin_Changed
}
public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if(!ValidUser(victim)||!ValidUser(attacker)||TF2_GetClientTeam(attacker)!=TF2_GetClientTeam(victim)||HoovyClass[attacker]!=HOOVY_MEDIC)return Plugin_Continue
    static int health, maxhealth
    health = GetClientHealth(victim)
    maxhealth = RoundToFloor(HoovyMaxHealth[victim]) + MEDIC_OVERHEAL
    if(health>maxhealth)return Plugin_Continue
    SetEntityHealth(victim,min(health+MEDIC_FIST_HEAL,maxhealth))
    SetEntPropFloat(attacker,Prop_Send,"m_flNextAttack",GetGameTime()+ MEDIC_HEAL_FIST_DELAY)
    EmitSoundToAll(SOUND_HEAL,victim)
    return Plugin_Handled
}
public Action OnGetMaxHealth(int client, int &maxHealth)
{
    maxHealth = RoundToFloor(HoovyMaxHealth[client])
    int sandwich = GetPlayerWeaponSlot(client,TFWeaponSlot_Secondary)
    if(sandwich!=-1&&IsFood(sandwich)&&getItemIndex(sandwich)==159&&HasEntProp(sandwich,Prop_Send,"m_iPrimaryAmmoType"))
    {
        int offs = GetEntProp(sandwich, Prop_Send, "m_iPrimaryAmmoType",1)
        int iAmmo = FindSendPropInfo("CTFPlayer","m_iAmmo")
        if(iAmmo!=-1&&offs!=-1&&(!GetEntData(client,iAmmo+(offs*4),4)))maxHealth += 50 // better than nothing
    }
    return Plugin_Changed
}
public Action OnWeaponSwitch(int client, int weapon)
{
    if(!CanHaveSecondary(client))
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
    int iAttacker = GetClientOfUserId(GetEventInt(hEvent,"attacker"))
    if(iVictim>=1&&iVictim<=MaxClients)
    {
        MadeHisChoice[iVictim] = false
        DestroyClientBuildings(iVictim,"obj_sentrygun")
        if(iVictim!=iAttacker)
        {
            AddScores(iVictim,1)
            if(ValidUser(iAttacker))AddScores(iAttacker,2)
        }
    }
}
public Action Event_KilledCappingPlayer(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
    int killer = GetEventInt(hEvent,"killer")
    if(ValidUser(killer))AddScores(killer,1)
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
        CreateTimer(2.0,Timer_AfterSpawn,client)
    }
}
public Action Event_FlagEvent(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
    int user = GetEventInt(hEvent,"player")
    int eventtype = GetEventInt(hEvent,"eventtype")
    switch(eventtype)
    {
        case(TF_FLAGEVENT_CAPTURED):AddScores(user,20);
        case(TF_FLAGEVENT_DEFENDED):AddScores(user,5);
    }
    return Plugin_Continue
}
public Action Event_PointCaptured(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
    TFTeam team = view_as<TFTeam>(GetEventInt(hEvent,"team"))
    int index = team==TFTeam_Blue?1:0
    HoovyScores[index] = min(HoovyScores[index]+8,HOOVY_POINTS_LIMIT)
    PrintToChatAll("Team %s gets 8 points for capturing the point. Current balance: %i",index?"BLU":"RED",HoovyScores[index])
    return Plugin_Continue
}
public Action Event_RoundStart(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
    HoovyScores[0] = HoovyScores[1] = 0
    #if SPELLS_STAGING
    Spells_RoundStart()
    #endif
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
        PrintToChatAll("Ooops, somebody just stepped on the wrong sandwich")
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
    HoovyVisuals[id] = true
}
public OnClientPutInServer(client)
{
    doSDKHooks(client)
}
public void OnClientDisconnect(int client)
{
    removeSDKHooks(client)
    HoovyVisuals[client] = false
    HoovyValid[client] = false
    DestroyClientBuildings(client, "obj_sentrygun")
    DestroyClientBuildings(client, "obj_dispenser")
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
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack)
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
      if(!CanPickClass(id,i))continue;
      strinfo[0] = i
      menu.AddItem(strinfo,ClassName[i])
    }
    #if HOOVY_CLASSAPI_ENABLED
    for(int i=0;i<NumHoovyClasses;i++)
    {
        if(HoovyExtraClassLimit[i]==-2)continue
        strinfo[0] = i+NUM_CLASSES
        menu.AddItem(strinfo,HoovyExtraClassName[i])
    }
    #endif
    strinfo[0]++
    menu.AddItem(strinfo, "Help")
    strinfo[0]++
    menu.AddItem(strinfo, HoovyVisuals[id]?"Hide medic beams":"Show medic beams")
    strinfo[0]++
    menu.AddItem(strinfo, "Source code")
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
        #if HOOVY_CLASSAPI_ENABLED
        if(result<(NUM_CLASSES+NumHoovyClasses))
        #else
        if(result<NUM_CLASSES)
        #endif
        {
            if(!CanPickClass(id,result))
            {
                PrintToChat(id,"Sorry, but the team can\'t have any more members of this class")
                ShowMainMenu(id)
                return
            }
            MadeHisChoice[id] = true
            HoovyClass[id] = result
            HoovyMaxHealth[id] = getMaxHealth(id)
            SetEntityHealth(id,RoundToFloor(HoovyMaxHealth[id]))
            TF2_RespawnPlayer(id)
            PrintToChat(id,"You will be able to pick other class after death")
        }
        #if HOOVY_CLASSAPI_ENABLED
        else if(result==NUM_CLASSES+NumHoovyClasses)ShowHelp(id,true)
        else if(result==NUM_CLASSES+NumHoovyClasses+1)
        {
            HoovyVisuals[id] = !HoovyVisuals[id]
            ShowMainMenu(id)
        }
        else if(result==NUM_CLASSES+NumHoovyClasses+2)
        {
            PrintToChat(id,"You can download the source code at https://github.com/le0nklcpp/hoovyassault")
            PrintToChat(id,"Note that the modification is licensed under GNU General Public License version 3.0")
            ShowMainMenu(id)
        }
        #else
        else switch(result){
        case(NUM_CLASSES):
        {
            ShowHelp(id,true)
        }
        case(NUM_CLASSES+1):
        {
            HoovyVisuals[id] = !HoovyVisuals[id]
            ShowMainMenu(id)
        }
        case(NUM_CLASSES+2):
        {
            PrintToChat(id,"You can download the source code at https://github.com/le0nklcpp/hoovyassault")
            PrintToChat(id,"Note that the modification is licensed under GNU General Public License version 3.0")
            ShowMainMenu(id)
        }
        }
        #endif
    }
}
public ShowHelp(id,bool canreturn)
{
    if(!ValidUser(id))return
    CancelClientMenu(id)
    Menu menu = CreateMenu(HelpHandler)
    menu.SetTitle("Classes information")
    char strinfo[3]
    strinfo[1] = canreturn?1:0
    strinfo[2] = '\0'
    for(int i=0;i<NUM_CLASSES;i++)
    {
        if(ClassLimit[i]==-2)continue;
        strinfo[0] = i
        menu.AddItem(strinfo,ClassName[i])
    }
    #if HOOVY_CLASSAPI_ENABLED
    for(int i=0;i<NumHoovyClasses;i++)
    {
        if(HoovyExtraClassLimit[i]==-2)continue
        strinfo[0] = i+NUM_CLASSES
        menu.AddItem(strinfo,HoovyExtraClassName[i])
    }
    #endif
    menu.ExitButton = true
    if(canreturn)menu.ExitBackButton = true
    menu.Display( id, MENU_TIMEOUT*3)
}
public HelpHandler(Handle menuid, MenuAction action, id, menu_item)
{
    if(action == MenuAction_End)CloseHandle(menuid)
    if(action == MenuAction_Cancel&&!MadeHisChoice[id])ShowMainMenu(id)
    if(action == MenuAction_Select)
    {
        char strinfo[3]
        GetMenuItem(menuid, menu_item, strinfo, sizeof(strinfo))
        ShowClassHelp(id,strinfo[0],strinfo[1]==1?true:false)
    }
}
public ShowClassHelp(id,classid,bool canreturn)
{
    if(!ValidUser(id))return
    CancelClientMenu(id)
    Menu menu = CreateMenu(ClassHelpHandler)
    #if HOOVY_CLASSAPI_ENABLED
    if(classid>=NUM_CLASSES)menu.SetTitle(HoovyExtraClassName[ClassApiIndex(classid)])
    else
    #endif
    menu.SetTitle(ClassName[classid])
    char strinfo[2]
    strinfo[0] = canreturn?1:0
    strinfo[1] = '\0'
    #if HOOVY_CLASSAPI_ENABLED
    if(classid>=NUM_CLASSES)menu.AddItem(strinfo,HoovyExtraClassDesc[ClassApiIndex(classid)])
    else
    #endif
    menu.AddItem(strinfo,ClassDescription[classid])
    menu.ExitBackButton = true
    menu.ExitButton = false
    menu.Display(id , MENU_TIMEOUT*4)
}
public ClassHelpHandler(Handle menuid, MenuAction action, id, menu_item)
{
    if(action == MenuAction_End)CloseHandle(menuid)
    else{
    char strinfo[2]
    GetMenuItem(menuid, menu_item, strinfo, sizeof(strinfo))
    if(action == MenuAction_Cancel||action == MenuAction_Select)
    {
        ShowHelp(id,strinfo[1]?true:false)
    }
    else if(strinfo[1])ShowMainMenu(id)
    }
}
public TryHealing(id)
{
    HoovyMaxHealth[id] = getMaxHealth(id)
    if(HoovyFlags[id]&HOOVY_BIT_HEALING||HoovyClass[id]==HOOVY_MEDIC)
    {
        static int clienthealth,maxhealth
        clienthealth = GetClientHealth(id)
        maxhealth = RoundToFloor(HoovyMaxHealth[id])
        if(clienthealth<maxhealth)
        {
            SetEntityHealth(id,min(clienthealth+RoundToFloor(MEDIC_HEAL*MEDIC_TICK),maxhealth))
            AttachParticle(id,TF2_GetClientTeam(id) == TFTeam_Red?"healthgained_red":"healthgained_blu","head",_,HOOVY_CYCLE_TIME);
        }
    }
    //if(GetClientHealth(id)>RoundToFloor(HoovyMaxHealth[id]))SetEntityHealth(id,RoundToFloor(HoovyMaxHealth[id]))
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
  if(IsFakeClient(i)&&(!CanHaveSecondary(i)))setActiveSlot(i,TFWeaponSlot_Melee) // force medic bot to use melee
  #if HOOVY_CLASSAPI_ENABLED
  if(HoovyClass[i]>=NUM_CLASSES)Hoovyassault_Classapi_Think(i)
  else 
  #endif
  switch(HoovyClass[i])
  {
   case(HOOVY_SCOUT):TF2_AddCondition(i, TFCond_SpeedBuffAlly, HOOVY_CYCLE_TIME+0.1);
   case(HOOVY_LEAPER):if(!HoovySpecialDelivery[i])TF2_StunPlayer(i,HOOVY_CYCLE_TIME+0.1,0.3,TF_STUNFLAG_SLOWDOWN);
   case(HOOVY_BOXER):
   {
      if(getItemIndex(GetPlayerWeaponSlot(i, TFWeaponSlot_Melee))==43)TF2_AddCondition(i,TFCond_MarkedForDeathSilent,HOOVY_CYCLE_TIME+0.1)
   }
   case(HOOVY_TRUMPETER):
   {
    TF2_AddCondition(i,TFCond_MarkedForDeathSilent,HOOVY_CYCLE_TIME+0.1)
    Handle hHudText = CreateHudSynchronizer()
    SetHudTextParams(-1.0, 0.8, HOOVY_CYCLE_TIME, 255, 0, 0, 255)
    ShowSyncHudText(i, hHudText, "Buff:%i/%i",HoovyRage[i],TRUMPETER_DAMAGENEEDED)
    CloseHandle(hHudText);
    if(!BannerDeployed[i]&&HoovyRage[i]==TRUMPETER_DAMAGENEEDED&&IsFakeClient(i))BannerDeployed[i] = true
    if(BannerDeployed[i])
    {
      HoovyRage[i]-=RoundToFloor(float(TRUMPETER_DAMAGENEEDED)/float(TRUMPETER_BUFFTIME)/(1.0/HOOVY_CYCLE_TIME))
      if(HoovyRage[i]<=0)
      {
        BannerDeployed[i] = false
        HoovyRage[i] = 0
      }
    }
   }
   case(HOOVY_ENGINEER):
   {
        Handle hHudText = CreateHudSynchronizer()
        SetHudTextParams(-1.0, 0.8, HOOVY_CYCLE_TIME, 255, 0, 0, 255)
        ShowSyncHudText(i, hHudText, "Points:%i",HoovyScores[TeamScoresIndex(i)])
        CloseHandle(hHudText);
   }
   case(HOOVY_GNOME):
   {
       TF2_AddCondition(i,TFCond_HalloweenTiny,HOOVY_CYCLE_TIME+0.1)
   }
  }
 }
}
public RemoveUnwantedWeapons(i)
{
   static int weapon
   if(!IsFakeClient(i))
   {
       static bool allowsecondary
       allowsecondary = CanHaveSecondary(i)
       if(getActiveSlot(i)==TFWeaponSlot_Primary)setActiveSlot(i,(!allowsecondary)?TFWeaponSlot_Melee:TFWeaponSlot_Secondary)
       TF2_RemoveWeaponSlot(i,TFWeaponSlot_Primary) // Anti-repick protection
       weapon = GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary)
       if(!allowsecondary)
       {
           if(weapon!=-1&&!IsFood(weapon))
           {
               TF2_RemoveWeaponSlot(i,TFWeaponSlot_Secondary)
//               setActiveSlot(i,TFWeaponSlot_Melee) // uncomment to disable a-posing
           }
       }

       #if GBW_STAGING
       else if(HoovyClass[i]==HOOVY_COMISSAR)
       {
           if(weapon!=-1&&getItemIndex(weapon)!=16)
           {
               TF2_RemoveWeaponSlot(i,TFWeaponSlot_Secondary)
               if(!CreateWeapon(i,"tf_weapon_smg",16,1))
               {
                   //LogError("Failed to create tf_weapon_smg")
               }
               else SetAmmo(i,GetPlayerWeaponSlot(i,TFWeaponSlot_Secondary),100)
           }
       }
       #endif
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
            switch(HoovyClass[j])
            {
                case(HOOVY_MEDIC):
	        {
                    if(!(HoovyFlags[i]&HOOVY_BIT_HEALING))
                    {
	            HoovyFlags[i] |= HOOVY_BIT_HEALING
                    Beam(i,j)
                    }
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
                    if(BannerDeployed[j])
                    {
                        TF2_AddCondition(i,TFCond_DefenseBuffed,HOOVY_CYCLE_TIME+0.1)
                        TF2_AddCondition(i,TFCond_CritOnFirstBlood,HOOVY_CYCLE_TIME+0.1)
                    }
                }
            }
        }
    }
}
public bool CanHaveSecondary(int client)
{
    #if HOOVY_CLASSAPI_ENABLED
    if(HoovyClass[client]>=NUM_CLASSES)
    {
        return !(meleeOnlyAllowed.BoolValue||HoovyExtraClassMeleeOnlyAccess[ClassApiIndex(HoovyClass[client])])
    }
    #endif
    return !(meleeOnlyAllowed.BoolValue||HoovyClass[client]==HOOVY_MEDIC||HoovyClass[client]==HOOVY_BOOMER||HoovyClass[client]==HOOVY_GNOME);
}
public bool CanPickClass(int client,int class)
{
    #if HOOVY_CLASSAPI_ENABLED
    if(class>=NUM_CLASSES)return (!HoovyExtraClassLimit[ClassApiIndex(class)]||(HoovyExtraClassLimit[ClassApiIndex(class)]>countClass(client,class)))
    #endif
    return (!ClassLimit[class])||(ClassLimit[class]>countClass(client,class))
}
bool AttemptToBuy(int client,int amount,bool as_team=false)
{
    int index = as_team?(view_as<TFTeam>(client)==TFTeam_Blue?1:0):TeamScoresIndex(client)
    if(HoovyScores[index]>=amount)
    {
        HoovyScores[index] -= amount
        return true
    }
    return false
}
public GetScores(client)
{
    return HoovyScores[TeamScoresIndex(client)]
}
public AddScores(int client,int scores)
{
    int index = TeamScoresIndex(client)
    HoovyScores[index] = min(HoovyScores[index]+scores,HOOVY_POINTS_LIMIT)
}
public Action Timer_ResetJumping(Handle timer,int client)
{
    HoovySpecialDelivery[client] = false
}
public Action Timer_RemoveSandwich(Handle timer, int client)
{
    int ent = findMySandwich(client)
    if(ent!=-1&&IsValidEntity(ent))AcceptEntityInput(ent, "Kill")
}
public Action ExplosiveSandwichTimer(Handle timer,int client)
{
    HoovySpecialDelivery[client] = false
    static int entity
    entity = findMySandwich(client)
    if(entity==-1)return
    ExplodeSandwich(entity,client)
    CreateTimer(1.0,Timer_RemoveSandwich,client)
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
public Action Timer_AfterSpawn(Handle timer, client)
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
    #if HOOVY_CLASSAPI_ENABLED
    if(HoovyClass[client]>=NUM_CLASSES)
    {
        if(!Hoovyassault_Classapi_OnSpawn(client))
        {
        MadeHisChoice[client] = false
        HoovyClass[client] = HOOVY_SOLDIER
        TF2_RespawnPlayer(client)
        }
    }
    #endif
}
public Action VoiceCommand(client, const String:command[], argc)
{
    if(!ValidUser(client))return Plugin_Continue
    static char Numbers[32] // thats even too much
    GetCmdArgString(Numbers, sizeof(Numbers))
    TrimString(Numbers)
    if(!StrEqual(Numbers,"1 4"))
    {
        if(!StrEqual(Numbers,"1 5"))return Plugin_Continue
        if(HoovyClass[client] == HOOVY_ENGINEER)
        {
            TryBuilding(client,false)
            return Plugin_Continue
        }
    }
    #if HOOVY_CLASSAPI_ENABLED
    if(HoovyClass[client]>=NUM_CLASSES)Hoovyassault_Classapi_Pootis(client)
    else 
    #endif
    switch(HoovyClass[client])
    {
    case(HOOVY_TRUMPETER):
        {
        if(HoovyRage[client]<TRUMPETER_DAMAGENEEDED||BannerDeployed[client])return Plugin_Continue
        AddScores(client,4)
        BannerDeployed[client] = true
        }
    case(HOOVY_ENGINEER):
        {
        TryBuilding(client,true)
        }
    #if SPELLS_STAGING
    case(HOOVY_GNOME):
        {
        ShowSpellMenu(client)
        }
    #endif
    }
    return Plugin_Continue
}
public Action SayCommand(client, const String:command[], argc)
{
    if(!client || client > MaxClients ||!IsClientInGame(client))return Plugin_Continue
    static char msg[32]
    GetCmdArgString(msg,sizeof(msg))
    TrimString(msg)
    if(StrEqual(msg,"\"!help\"")||StrEqual(msg,"\"/help\""))
    {
        ShowHelp(client,false)
        return Plugin_Stop
    }
    return Plugin_Continue
}
// rtd plugin from linux_lover (abkowald@gmail.com)
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
stock countClass(id,cl)
{
    static int i,ctr
    ctr = 0
    for(i = 1; i < MaxClients;i++)
    {
        if(!HoovyValid[i]||i==id||TF2_GetClientTeam(i)!=TF2_GetClientTeam(id))continue;
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
    for(i=0;i<=HOOVY_TRUMPETER;i++)
    {
        cl = countClass(id,i)
        if(cl<BOT_CLASS_LIMIT)
        {
            if(i==HOOVY_MEDIC&&cl==0)
            {
                ClearArray(nClasses)
                delete nClasses
                return HOOVY_MEDIC
            }
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
        delete nClasses
        return (GetRandomInt(0,100)>40)?0:GetRandomInt(1,NUM_CLASSES-1)
    }
    cl = GetArrayCell(nClasses,GetRandomInt(0,count-1))
    ClearArray(nClasses)
    delete nClasses
    return cl
}
// don't forget to TE_SendToAll
stock Beam(int from,int to)
{
    static int color[4],team
    static float hfrom,hto
    static int total
    int[] clients = new int[MaxClients]
    team = (TF2_GetClientTeam(from)==TFTeam_Red)
    color = team?{255,0,0,255}:{0,0,255,255}
    hfrom = HoovyCoords[from][2]
    hto = HoovyCoords[to][2]
    HoovyCoords[from][2] += 36.0+(GetURandomFloat()-0.5)*5.0
    HoovyCoords[to][2] += 36.0+(GetURandomFloat()-0.5)*5.0
    TE_SetupBeamPoints(HoovyCoords[from],HoovyCoords[to],BeamSprite[team],HaloSprite,0,0,HOOVY_CYCLE_TIME,5.0,5.0,0,0.0,color,0)
    HoovyCoords[from][2] = hfrom
    HoovyCoords[to][2] = hto
    total = 0
    for (int i=1; i<=MaxClients; i++)
    {
        if (IsClientInGame(i)&&HoovyVisuals[i])
        {
            clients[total++] = i;
        }
    }
    TE_Send(clients, total, 0.0);
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
            SDKHooks_TakeDamage(i, 0, owner, dist<(BOOM_RADIUS/2.0)?320.0:(320.0*(1.0-dist/BOOM_RADIUS)), DMG_PREVENT_PHYSICS_FORCE|DMG_CRUSH|DMG_ALWAYSGIB)
        }
    }
}
// also from rtd plugin
bool CanBuildHere(Float:flPos[3], Float:flMins[3], Float:flMaxs[3])
{
    TR_TraceHull(flPos, flPos, flMins, flMaxs, MASK_SOLID);
    return !TR_DidHit();
}
public bool:TraceFilterIgnorePlayers(entity, contentsMask, any:client)
{
    if(entity >= 1 && entity <= MaxClients)
    {
        return false;
    }
    return true;
}
float g_iDispenserMins[] = {-24.0, -24.0, 0.0};
float g_iDispenserMaxs[] = {24.0, 24.0, 55.0};
float g_iSentryMins[] = {-20.0,-20.0,0.0}
float g_iSentryMaxs[] = {20.0,20.0,20.0}
stock TryBuilding(client,bool dispenser)
{
    float flPos[3]
    float flAng[3]
    GetClientEyePosition(client, flPos)
    GetClientEyeAngles(client, flAng)
    Handle hTrace = TR_TraceRayFilterEx(flPos, flAng, MASK_SHOT, RayType_Infinite, TraceFilterIgnorePlayers, client)
    if(hTrace != INVALID_HANDLE && TR_DidHit(hTrace))
    {
        float flEndPos[3]
        TR_GetEndPosition(flEndPos, hTrace)
        flEndPos[2] += 5.0
        float flMins[3]
        float flMaxs[3]
        flMins = view_as<float>(dispenser?g_iDispenserMins:g_iSentryMins)
        flMaxs = view_as<float>(dispenser?g_iDispenserMaxs:g_iSentryMaxs)
        if((GetVectorDistance(flEndPos,flPos)<HOOVY_EFFECTS_RADIUS)&&CanBuildHere(flEndPos, flMins, flMaxs))
        {
            if(!AttemptToBuy(client,dispenser?DISPENSER_COST:SENTRY_COST))
            {
                PrintToChat(client,"Not enough points to build structure: %i/%i",GetScores(client),dispenser?DISPENSER_COST:SENTRY_COST)
                CloseHandle(hTrace)
                return
            }
            DestroyClientBuildings(client,dispenser?"obj_dispenser":"obj_sentrygun")
            GetClientAbsAngles(client, flAng)
            int iBuilding = dispenser?BuildDispenser(client, flEndPos, flAng, 3):BuildSentry(client,flEndPos,flAng)
            SDKHooks_TakeDamage(client, 0, client, dispenser?75.0:120.0, DMG_CRUSH)
            if(iBuilding > MaxClients && IsValidEntity(iBuilding))
            {
		AttachParticle(iBuilding, "ping_circle", _, 2.0, 2.0)
            }
        }
        else PrintToChat(client,"Can't build %s here",dispenser?"dispenser":"sentry")
    }
    else PrintToChat(client,"Can't build %s here",dispenser?"dispenser":"sentry")
    if(hTrace!=INVALID_HANDLE)CloseHandle(hTrace)
}
stock BuildDispenser(iBuilder, Float:flOrigin[3], Float:flAngles[3], iLevel=1)
{
    new String:strModel[100]
    int iTeam = GetClientTeam(iBuilder)
    int iHealth
    int iAmmo = 400
    if(iLevel == 2)
    {
        strcopy(strModel, sizeof(strModel), "models/buildables/dispenser_lvl2.mdl")
        iHealth = 180
    }else if(iLevel == 3)
    {
        strcopy(strModel, sizeof(strModel), "models/buildables/dispenser_lvl3.mdl")
        iHealth = 216
    }else{
        // Assume level 1
        strcopy(strModel, sizeof(strModel), "models/buildables/dispenser.mdl")
        iHealth = 150
    }
    int iDispenser = CreateEntityByName("obj_dispenser")
    if(iDispenser > MaxClients && IsValidEntity(iDispenser))
    {
        DispatchSpawn(iDispenser)
        TeleportEntity(iDispenser, flOrigin, flAngles, NULL_VECTOR)
        SetEntityModel(iDispenser, strModel)
        SetVariantInt(iTeam)
        AcceptEntityInput(iDispenser, "TeamNum")
        SetVariantInt(iTeam)
        AcceptEntityInput(iDispenser, "SetTeam")
        ActivateEntity(iDispenser)
        SetEntProp(iDispenser, Prop_Send, "m_iAmmoMetal", iAmmo)
        SetEntProp(iDispenser, Prop_Send, "m_iHealth", iHealth)
        SetEntProp(iDispenser, Prop_Send, "m_iMaxHealth", iHealth)
        SetEntProp(iDispenser, Prop_Send, "m_iObjectType", _:TFObject_Dispenser)
        SetEntProp(iDispenser, Prop_Send, "m_iTeamNum", iTeam)
        SetEntProp(iDispenser, Prop_Send, "m_nSkin", iTeam-2)
        SetEntProp(iDispenser, Prop_Send, "m_iHighestUpgradeLevel", iLevel)
        SetEntPropFloat(iDispenser, Prop_Send, "m_flPercentageConstructed", 1.0)
        SetEntPropVector(iDispenser, Prop_Send, "m_vecBuildMaxs", g_iDispenserMaxs)
        SetEntPropEnt(iDispenser, Prop_Send, "m_hBuilder", iBuilder)	
        return iDispenser
    }
    return 0
}
BuildSentry(iBuilder, Float:flOrigin[3], Float:flAngles[3]) // Builds mini sentry
{
	
	new iTeam = GetClientTeam(iBuilder)
	new iShells = 150, iHealth = 100
	
	new iSentry = CreateEntityByName("obj_sentrygun")
	if(iSentry > MaxClients && IsValidEntity(iSentry))
	{
		DispatchSpawn(iSentry);
		
		TeleportEntity(iSentry, flOrigin, flAngles, NULL_VECTOR)
		
		SetEntityModel(iSentry, "models/buildables/sentry1.mdl")
		SetEntProp(iSentry, Prop_Send, "m_bMiniBuilding", true,1) // mini sentry flag
		SetEntProp(iSentry, Prop_Send, "m_iAmmoShells", iShells)
		SetEntProp(iSentry, Prop_Send, "m_iHealth", iHealth)
		SetEntProp(iSentry, Prop_Send, "m_iMaxHealth", iHealth)
		SetEntProp(iSentry, Prop_Send, "m_iObjectType", _:TFObject_Sentry)
		SetEntProp(iSentry, Prop_Send, "m_iState", 1)
		SetEntPropFloat(iSentry, Prop_Send, "m_flModelScale", 0.75); // 0.75 for actual mini-sentry size
		SetEntProp(iSentry, Prop_Send, "m_iTeamNum", iTeam)
		SetEntProp(iSentry, Prop_Send, "m_nSkin", iTeam) // skin + 2 = mini-sentry
		SetEntProp(iSentry, Prop_Send, "m_iUpgradeLevel", 1)
		SetEntProp(iSentry, Prop_Send, "m_iAmmoRockets", 0)
		
		SetEntPropEnt(iSentry, Prop_Send, "m_hBuilder", iBuilder)
		
		SetEntPropFloat(iSentry, Prop_Send, "m_flPercentageConstructed", 1.0)
		
		SetEntPropVector(iSentry, Prop_Send, "m_vecBuildMaxs", g_iSentryMaxs)
	
		return iSentry;
	}
	
	return 0;
}
stock DestroyClientBuildings(client,const char[]objname)
{
    static int entity
    entity = -1
    while ((entity = FindEntityByClassname(entity, objname)) != -1)
    {
        if(IsValidEntity(entity)&&HasEntProp(entity,Prop_Send,"m_hBuilder")&&(GetEntPropEnt(entity,Prop_Send,"m_hBuilder")==client))
        {
            AcceptEntityInput(entity, "Kill")
        }
    }
}
stock setActiveSlot(client,slot)
{
    new iWeapon = GetPlayerWeaponSlot(client, slot);
    if(IsValidEntity(iWeapon))
    {
       SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon);
    }
}
public void setPlayerSpeed(client,float value)
{
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", value)
}
public float getMaxHealth(id)
{
    static float newmaxhealth 
    newmaxhealth = 300.0
    #if HOOVY_CLASSAPI_ENABLED
    OnClassApi(id,newmaxhealth *= HoovyExtraClassParams[ClassApiIndex(HoovyClass[id])][Char_Maxhealth])
    else
    #endif
    newmaxhealth *= ClassChars[HoovyClass[id]][Char_Maxhealth]
    if(HoovyFlags[id]&HOOVY_BIT_OVERHEAL)newmaxhealth += COMISSAR_OVERHEAL
    return newmaxhealth
}
stock getItemIndex(item)
{
 if(item==-1)return -1
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
// Natives
int NativeGetHoovyClass(Handle plugin, int numParams)
{
    return HoovyClass[GetNativeCell(1)];
}
any NativeSetHoovyClass(Handle plugin, int numParams)
{
    HoovyClass[GetNativeCell(1)] = GetNativeCell(2)
}
any NativeSetHoovyScores(Handle plugin,int numParams)
{
    int index = GetNativeCell(1)
    int amount = GetNativeCell(2)
    bool asTeam = GetNativeCell(3)
    if(asTeam)HoovyScores[view_as<TFTeam>(index)==TFTeam_Blue?1:0] = amount
    else HoovyScores[TeamScoresIndex(index)] = amount
}
int NativeGetHoovyScores(Handle plugin,int numParams)
{
    int index = GetNativeCell(1)
    bool asTeam = GetNativeCell(2)
    if(asTeam)return HoovyScores[view_as<TFTeam>(index)==TFTeam_Blue?1:0]
    else return HoovyScores[TeamScoresIndex(index)]
}
any NativeAddHoovyScores(Handle plugin,int numParams)
{
    int index = GetNativeCell(1)
    int amount = GetNativeCell(2)
    bool asTeam = GetNativeCell(3)
    if(asTeam)HoovyScores[view_as<TFTeam>(index)==TFTeam_Blue?1:0] += amount
    else HoovyScores[TeamScoresIndex(index)] += amount
}
int NativeWithdrawHoovyScores(Handle plugin,int numParams)
{
    int index = GetNativeCell(1)
    int amount = GetNativeCell(2)
    bool asTeam = GetNativeCell(3)
    return AttemptToBuy(index,amount,asTeam)
}