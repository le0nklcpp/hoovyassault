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
#include "hoovyassault"
#include "hoovyassault_module_gbw" // for CreateWeapon

#define ValidUser(%1) ((1<=%1<=MaxClients)&&IsClientInGame(%1)&&IsPlayerAlive(%1))

typeset TraitorItemCallback{
function bool(int id);
};

int TraitorClass = -1
public Plugin myinfo = 
{
 name = "Hoovyassault spy class",
 author = "breins",
 description = "Spy class for Pootis Fortress",
 version = "1.2",
 url = ""
};
#define MAX_TRAITOR_ITEMS 22
char TraitorItemNames[MAX_TRAITOR_ITEMS][50]
int TraitorItemPrice[MAX_TRAITOR_ITEMS]

float TraitorCoords[MAXPLAYERS+1][3]
bool TraitorAdrenaline[MAXPLAYERS+1]
bool TraitorKart[MAXPLAYERS+1]

bool TraitorDisguised[MAXPLAYERS+1]

Function TraitorItemCallbacks[MAX_TRAITOR_ITEMS]
int TraitorItemsNum = 0

public TraitorMenuHandler(Handle menu,MenuAction action,int client,int item)
{
    if(action==MenuAction_End)CloseHandle(menu)
    else if(action == MenuAction_Select)
    {
        int result
        if(!ValidUser(client))return
        char strinfo[2]
        GetMenuItem(menu, item, strinfo, sizeof(strinfo))
        int index = strinfo[0]
        if(GetHoovyScores(client)<TraitorItemPrice[index])
        {
            PrintToChat(client,"These things don\'t grow on trees.Heavy have to earn it.")
            CancelClientMenu(client)
            ShowTraitorMenu(client)
            return
        }
        Call_StartFunction(INVALID_HANDLE,TraitorItemCallbacks[index])
        Call_PushCell(client)
        Call_Finish(result)
        if(result)WithdrawHoovyScores(client,TraitorItemPrice[index])
    }
}
void ShowTraitorMenu(int id)
{
    Menu menu = CreateMenu(TraitorMenuHandler)
    char strinfo[2]
    strinfo[1] = 0
    menu.SetTitle("Gadget shop [%i points]",GetHoovyScores(id))
    for(int i=0;i<TraitorItemsNum;i++)
    {
        strinfo[0] = i
        char caption[81]
        Format(caption,80,"%s[%i]",TraitorItemNames[i],TraitorItemPrice[i])
        menu.AddItem(strinfo,caption)
    }
    menu.Display(id,20)
}
int TraitorTakeDamage(int Victim,int Attacker,int inflictor,float &damage,int &damagetype,int &weapon)
{
    if(ValidUser(Victim)&&(GetHoovyClass(Victim)==TraitorClass)&&TraitorAdrenaline[Victim]&&(GetRandomInt(0,100)>70)&&(damage<108.0))
    {
        return HOOVY_CB_BLOCKED // 30% chance to dodge
    }
    if(!ValidUser(Attacker)||GetHoovyClass(Attacker)!=TraitorClass)return HOOVY_CB_IGNORED
    switch(getItemIndex(weapon)){
    case(30667):damage *= 2.0;
    case(19):{
        damage = 0.0
        if(Victim==Attacker||TF2_GetClientTeam(Victim)!=TF2_GetClientTeam(Attacker))
            TF2_StunPlayer(Victim,7.0,0.5,TF_STUNFLAGS_SMALLBONK)
        }
    }
    return HOOVY_CB_IGNORED
}
int GiveEBat(int id)
{
    TF2_RemoveWeaponSlot(id,TFWeaponSlot_Melee)
    CreateWeapon(id,"tf_weapon_bat",30667)
    ClientCommand(id,"slot3") // Proper weapon class animations
    return 1
}
int GiveSniperRifle(int id)
{
    SetHoovyPrimary(id,true)
    TF2_RemoveWeaponSlot(id,TFWeaponSlot_Primary)
    CreateWeapon(id,"tf_weapon_sniperrifle_classic",1098)
    SetAmmo(id,GetPlayerWeaponSlot(id,TFWeaponSlot_Primary),32)
    ClientCommand(id,"slot1")
    return 1
}
int GiveGL(int id)
{
    SetHoovyPrimary(id,true)
    TF2_RemoveWeaponSlot(id,TFWeaponSlot_Primary)
    CreateWeapon(id,"tf_weapon_grenadelauncher",19)
    SetAmmo(id,GetPlayerWeaponSlot(id,TFWeaponSlot_Primary),16)
    ClientCommand(id,"slot1")
    return 1
}
int GiveAdrenaline(int id)
{
    TF2_AddCondition(id,TFCond_SpeedBuffAlly,3.0)
    TraitorAdrenaline[id] = true
    CreateTimer(8.0,Timer_ResetAdrenaline,id)
    return 1
}
int GiveKart(int id)
{
    TraitorKart[id] = true
    return 1
}
int LeapBack(int id)
{
    float flMins[3], flMaxs[3], angles[3]//, scale = 1.0
    GetEntPropVector(id, Prop_Data, "m_vecMinsPreScaled", flMins)
    GetEntPropVector(id, Prop_Data, "m_vecMaxsPreScaled", flMaxs)
    GetClientAbsAngles(id, angles)
    /*
    if(HasEntProp(id,Prop_Send,"m_flModelScale"))
    {
        scale = GetEntPropFloat(id, Prop_Send, "m_flModelScale")
        scaleVector(vecMins,scale)
        scaleVector(vecMaxs,scale)
    }
    */
    TR_TraceHull(TraitorCoords[id], TraitorCoords[id], flMins, flMaxs, MASK_SOLID)
    TeleportEntity(id,TraitorCoords[id],angles,NULL_VECTOR)
    if(TR_DidHit())
    {
        ForcePlayerSuicide(id)
        int entity = TR_GetEntityIndex()
        if(ValidUser(entity))
        {
            SDKHooks_TakeDamage(entity, 0, id, float(GetClientHealth(entity)), DMG_PREVENT_PHYSICS_FORCE|DMG_CRUSH|DMG_ALWAYSGIB)
        }
    }
    return 1
}

void TraitorThink(int id)
{
    static int item,weapon
    weapon = GetPlayerWeaponSlot(id,TFWeaponSlot_Primary)
    item = getItemIndex(weapon)
    if(item!=-1&&item!=1098&&item!=19)
    {
        TF2_RemoveWeaponSlot(id,TFWeaponSlot_Primary)
    }
    //else if(item==19)SetAmmo(id,weapon,0)
    if(TraitorKart[id])TF2_AddCondition(id,TFCond_HalloweenKart,HOOVY_CYCLE_TIME+0.1)
}
int DisguisePlayer(int id)
{
    TF2_SetPlayerClass(id,TFClass_Spy,_,false)
    TF2_DisguisePlayer(id,TF2_GetClientTeam(id)==TFTeam_Red?TFTeam_Blue:TFTeam_Red,TFClass_Heavy)
    TF2_SetPlayerClass(id,TFClass_Heavy,_,false)
    return 1
}
int TraitorSpawn(int id)
{
    if(TF2_GetPlayerClass(id)!=TFClass_Heavy)return 0
    CreateTimer(5.0,Timer_SavePosition,id,TIMER_REPEAT)
    GetClientAbsOrigin(id,TraitorCoords[id])
    TraitorKart[id] = false
    TraitorAdrenaline[id] = false
    DisguisePlayer(id)
    PrintToChat(id,"Press X then press 5 to activate your gadgets menu. Note that it uses your team\'s budget")
    return 1
}
void RegisterTraitorItem(String:name[],int price,Function callback)
{
    if(TraitorItemsNum==MAX_TRAITOR_ITEMS)
    {
        ThrowNativeError(1,"Failed to register traitor item. Reached traitor items limit")
    }
    strcopy(TraitorItemNames[TraitorItemsNum],49,name)
    TraitorItemCallbacks[TraitorItemsNum] = callback
    TraitorItemPrice[TraitorItemsNum] = price
    TraitorItemsNum++
}

public Action TauntCommand(client, const String:command[], argc)
{
    if(TraitorDisguised[client]&&GetHoovyClass(client)==TraitorClass)return Plugin_Handled
    return Plugin_Continue
}

public Action OnTouchStart(int client,int other)
{
    if(TraitorKart[client]&&(GetHoovyClass(client)==TraitorClass)&&ValidUser(other))
    {
        static float angles[3],vel[3],fwd[3],right[3],up[3],cur[3]
        vel[0]=vel[1]=vel[2]=0.0
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", cur)
        GetClientAbsAngles(client,angles)
        GetAngleVectors(angles,fwd,right,up)
        AddVectors(vel,fwd,vel)
        AddVectors(vel,right,vel)
        AddVectors(vel,up,vel)
        ScaleVector(vel,250.0)
        AddVectors(vel,cur,vel)
        if(vel[2]<0)vel[2]=-vel[2]
        TeleportEntity(other, NULL_VECTOR, NULL_VECTOR, vel)
    }
    return Plugin_Continue
}

public OnPluginStart()
{
    GBW_Staging_OnPluginStart()
    RegisterTraitorItem("Neon stick(definitely not a weapon)",8,GiveEBat)
    RegisterTraitorItem("Classic",22,GiveSniperRifle)
    RegisterTraitorItem("Disguise",2,DisguisePlayer)
    RegisterTraitorItem("Adrenaline injection",8,GiveAdrenaline)
    RegisterTraitorItem("Grenade launcher(stun-grenades)",26,GiveGL)
    RegisterTraitorItem("Car!",30,GiveKart)
    RegisterTraitorItem("Teleport to your old position",7,LeapBack)
    AddCommandListener(TauntCommand,"taunt")
    AddCommandListener(TauntCommand,"+taunt")
    for(int i=1;i<MaxClients;i++)TraitorAdrenaline[i] = TraitorKart[i] = TraitorDisguised[i] = false
}
public OnAllPluginsLoaded()
{
    if(LibraryExists("hoovyassault_classapi"))
    {
        TraitorClass = RegisterHoovyClass("Saboteur","Sabotage your enemy assault using your cool gadgets(press X->5)",0.6,1.0,1.0,false,1)
        RegisterHoovySpawnCallback(TraitorClass,TraitorSpawn)
        RegisterHoovyPootisCallback(TraitorClass,ShowTraitorMenu)
        RegisterHoovyThinkCallback(TraitorClass,TraitorThink)
        RegisterHoovyDamageCallback(TraitorClass,TraitorTakeDamage)
    }
}
public OnClientPutInServer(id)
{
    TraitorKart[id] = false
    TraitorDisguised[id] = false
    SDKHook(id,SDKHook_StartTouch,OnTouchStart)
}
public OnClientDisconnect(id)
{
    SDKUnhook(id,SDKHook_StartTouch,OnTouchStart)
}

public TF2_OnConditionAdded(int client, TFCond condition)
{
    if(condition==TFCond_Disguised)TraitorDisguised[client] = true
}

public TF2_OnConditionRemoved(int client, TFCond condition)
{
    if(condition==TFCond_Disguised)TraitorDisguised[client] = false
}

public Action Timer_ResetAdrenaline(Handle:hTimer,id)
{
    TraitorAdrenaline[id] = false
    return Plugin_Handled
}
public Action Timer_SavePosition(Handle: hTimer,id)
{
    if(GetHoovyClass(id)!=TraitorClass||!ValidUser(id))return Plugin_Stop
    GetClientAbsOrigin(id,TraitorCoords[id])
    return Plugin_Continue
}

stock getItemIndex(item)
{
 if(item==-1)return -1
 return GetEntProp(item,Prop_Send, "m_iItemDefinitionIndex")
}