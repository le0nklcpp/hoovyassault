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
 version = "1.0",
 url = ""
};
#define MAX_TRAITOR_ITEMS 22
char TraitorItemNames[MAX_TRAITOR_ITEMS][50]
int TraitorItemPrice[MAX_TRAITOR_ITEMS]
Function TraitorItemCallbacks[MAX_TRAITOR_ITEMS]
int TraitorItemsNum = 0

public TraitorMenuHandler(Handle menu,MenuAction action,int client,int item)
{
    if(action==MenuAction_End)CloseHandle(menu)
    else if(action == MenuAction_Select)
    {
        if(!ValidUser(client))return
        char strinfo[2]
        GetMenuItem(menu, item, strinfo, sizeof(strinfo))
        int index = strinfo[0]
        if(!WithdrawHoovyScores(client,TraitorItemPrice[index]))
        {
            PrintToChat(client,"These things don\'t grow on trees.Heavy have to earn it.")
            CancelClientMenu(client)
            ShowTraitorMenu(client)
            return
        }
        Call_StartFunction(INVALID_HANDLE,TraitorItemCallbacks[index])
        Call_PushCell(client)
        Call_Finish()  
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
    if(!ValidUser(Attacker)||GetHoovyClass(Attacker)!=TraitorClass||getItemIndex(weapon)!=30667)return HOOVY_CB_IGNORED
    damage *= 2.0
    return HOOVY_CB_IGNORED
}
void GiveEBat(int id)
{
    TF2_RemoveWeaponSlot(id,TFWeaponSlot_Melee)
    CreateWeapon(id,"tf_weapon_bat",30667)
}
void GiveSniperRifle(int id)
{
    SetHoovyPrimary(id,true)
    TF2_RemoveWeaponSlot(id,TFWeaponSlot_Primary)
    CreateWeapon(id,"tf_weapon_sniperrifle_classic",1098)
}
void TraitorThink(int id)
{
    static int item
    item = getItemIndex(GetPlayerWeaponSlot(id,TFWeaponSlot_Primary))
    if(item!=-1&&item!=1098)
    {
        TF2_RemoveWeaponSlot(id,TFWeaponSlot_Primary)
    }
}
void DisguisePlayer(int id)
{
    TF2_SetPlayerClass(id,TFClass_Spy,_,false)
    TF2_DisguisePlayer(id,TF2_GetClientTeam(id)==TFTeam_Red?TFTeam_Blue:TFTeam_Red,TFClass_Heavy)
    TF2_SetPlayerClass(id,TFClass_Heavy,_,false)
}
int TraitorSpawn(int id)
{
    if(TF2_GetPlayerClass(id)!=TFClass_Heavy)return 0
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
public OnPluginStart()
{
    GBW_Staging_OnPluginStart()
    RegisterTraitorItem("Neon stick(definitely not a weapon)",8,GiveEBat)
    RegisterTraitorItem("Classic",22,GiveSniperRifle)
    RegisterTraitorItem("Disguise",2,DisguisePlayer)
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

stock getItemIndex(item)
{
 if(item==-1)return -1
 return GetEntProp(item,Prop_Send, "m_iItemDefinitionIndex")
}
