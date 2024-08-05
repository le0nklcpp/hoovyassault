#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <menus>
#include <sdkhooks>
#include <string>
#define MAX_SPELLS 7
#define BOOK_SPELLS 4
// Make sure that BOOK_SPELLS is less than SPELL_NUM
char SpellNames[MAX_SPELLS][]={
"Crudux Cruo",// Actually this has nothing to do with spell indexes as spells are mixed up
"Didbdminoibdi",
"Oni Soma",
"Mpipe",
"Testicular Torsion",
"Ambadeblo",
"Amistrabin Hazartha"
//"Random spell for fixed price"
}
#define IsHarmfulSpell(%1) (%1==4)
int SpellMana[MAX_SPELLS]={
14,
12,
22,
16,
10,
15,
23
}
int SpellLabels[BOOK_SPELLS][2] // This is for captions that are taken from the array above
int SpellIds[BOOK_SPELLS][2] // So the actual spells are scrambled for both teams lmao
#define SPELLFLAG_DEBUFF (1<<1)
#define SPELLFLAG_HARM (1<<2)
#define SPELLFLAG_BUFF (1<<3)
#define SPELLFLAG_FUN (1<<4)
#define SPELLFLAG_ON_YOURSELF (1<<5)
#define SPELLFLAG_ON_ALLY (1<<6)
#define SPELLFLAG_ON_FOE (1<<7)
#define SPELLFLAG_MAY_ON_ALLY (1<<8)
#define SPELLFLAG_MAY_ON_FOE (1<<9)
#define SPELLFLAG_MAY_ON_YOURSELF (1<<10)
#define SPELLFLAG_IN_RANGE (1<<11)
#define SPELLFLAG_IN_BEAM (1<<12)
#define SPELLFLAG_IN_EVERYWHERE (1<<13)

#define SPELL_EFFECT_RADIUS 625.0

enum {
SPELL_HEAL=0,
SPELL_IGNITE,
SPELL_SLOWDOWN,
SPELL_POWERPLAY,
SPELL_JARATE,
SPELL_GNOMEME,
SPELL_INVIS,
SPELL_TAUNT,
SPELL_MINICRIT,
SPELL_MILK,
SPELL_MERASMUSED,
SPELL_DEATH,
SPELL_BULLETPROOF,
SPELL_INCARNATION,
SPELL_SWIMMING,
NUM_SPELLS
}
int SpellFlags[]=
{
(SPELLFLAG_BUFF|SPELLFLAG_ON_ALLY|SPELLFLAG_ON_YOURSELF|SPELLFLAG_IN_RANGE),
(SPELLFLAG_DEBUFF|SPELLFLAG_HARM|SPELLFLAG_MAY_ON_YOURSELF|SPELLFLAG_ON_FOE|SPELLFLAG_IN_RANGE),
(SPELLFLAG_DEBUFF|SPELLFLAG_MAY_ON_ALLY|SPELLFLAG_MAY_ON_YOURSELF|SPELLFLAG_ON_FOE|SPELLFLAG_IN_RANGE),
(SPELLFLAG_BUFF|SPELLFLAG_ON_ALLY|SPELLFLAG_IN_RANGE),
(SPELLFLAG_DEBUFF|SPELLFLAG_MAY_ON_YOURSELF|SPELLFLAG_ON_FOE|SPELLFLAG_IN_EVERYWHERE),
(SPELLFLAG_FUN|SPELLFLAG_MAY_ON_FOE|SPELLFLAG_MAY_ON_ALLY|SPELLFLAG_IN_EVERYWHERE),
(SPELLFLAG_BUFF|SPELLFLAG_ON_ALLY|SPELLFLAG_IN_EVERYWHERE),
(SPELLFLAG_FUN|SPELLFLAG_ON_ALLY|SPELLFLAG_ON_FOE|SPELLFLAG_MAY_ON_YOURSELF|SPELLFLAG_IN_EVERYWHERE),
(SPELLFLAG_BUFF|SPELLFLAG_ON_ALLY|SPELLFLAG_IN_RANGE),
(SPELLFLAG_DEBUFF|SPELLFLAG_MAY_ON_YOURSELF|SPELLFLAG_IN_EVERYWHERE),
(SPELLFLAG_FUN|SPELLFLAG_ON_ALLY|SPELLFLAG_ON_FOE|SPELLFLAG_ON_YOURSELF|SPELLFLAG_IN_EVERYWHERE),
(SPELLFLAG_HARM|SPELLFLAG_ON_FOE|SPELLFLAG_IN_BEAM),
(SPELLFLAG_BUFF|SPELLFLAG_ON_ALLY|SPELLFLAG_IN_RANGE),
(SPELLFLAG_BUFF|SPELLFLAG_ON_ALLY|SPELLFLAG_IN_BEAM),
(SPELLFLAG_FUN|SPELLFLAG_MAY_ON_ALLY|SPELLFLAG_MAY_ON_FOE|SPELLFLAG_ON_YOURSELF|SPELLFLAG_IN_EVERYWHERE)
}
int CurrentHoovyWizard
int CurrentSpellFlags
int CurrentSpell
TFTeam CurrentWizardTeam
typeset SpellCallback
{
    function void (int client)
}
SpellCallback[15] SpellList
#define getSpellCb  SpellCallback cb = SpellList[CurrentSpell]
#define IsAllowedToCast(%1) (((CurrentSpellFlags&SPELLFLAG_ON_YOURSELF)&&(CurrentHoovyWizard==%1))||((CurrentSpellFlags&SPELLFLAG_ON_ALLY)&&TF2_GetClientTeam(%1)==CurrentWizardTeam)||((CurrentSpellFlags&SPELLFLAG_ON_FOE)&&TF2_GetClientTeam(%1)!=CurrentWizardTeam))
bool HoovySpellTraceFilter(int entity)
{
    if(ValidUser(entity)&&IsAllowedToCast(entity))
    {
        getSpellCb
        Call_StartFunction(INVALID_HANDLE,cb)
        Call_PushCell(entity)
        Call_Finish()
        return true
    }
    return false
}
public Spells_OnPluginStart()
{
    #define cb(%1,%2) SpellList[%1] = %2
    cb(SPELL_HEAL,SpellHeal)
    cb(SPELL_IGNITE,SpellOnFire)
    cb(SPELL_SLOWDOWN,SpellSlowdown)
    cb(SPELL_POWERPLAY,SpellPowerPlay)
    cb(SPELL_JARATE,SpellJarate)
    cb(SPELL_GNOMEME,SpellGnomify)
    cb(SPELL_INVIS,SpellInvis)
    cb(SPELL_TAUNT,SpellForcedTaunt)
    cb(SPELL_MINICRIT,SpellMiniCrit)
    cb(SPELL_MILK,SpellMilk)
    cb(SPELL_MERASMUSED,SpellCart)
    cb(SPELL_DEATH,SpellKill)
    cb(SPELL_BULLETPROOF,SpellBulletproof)
    cb(SPELL_INCARNATION,SpellIncarnation)
    cb(SPELL_SWIMMING,SpellSwimming)
    #undef cb
}
float SpellMapBoundsMin[3],SpellMapBoundsMax[3]
public Spells_OnMapStart()
{
    ScrambleSpells(0)
    ScrambleSpells(1)
}
Spells_RoundStart()
{
    ScrambleSpells(0)
    ScrambleSpells(1)
    GetEntPropVector(0, Prop_Send, "m_WorldMaxs", SpellMapBoundsMax)
    GetEntPropVector(0, Prop_Send, "m_WorldMins", SpellMapBoundsMin)
}
public ShowSpellMenu(int client)
{
    CancelClientMenu(client)
    char strinfo[3],label[64]
    int team = TF2_GetClientTeam(client)==TFTeam_Blue?1:0
    Menu menu = CreateMenu(SpellMenuHandler)
    menu.SetTitle("List of known spells(remaining mana:%i)",HoovyScores[team])
    strinfo[1] = team
    strinfo[2] = 0
    for(int i=0;i<BOOK_SPELLS;i++)
    {
        strinfo[0] = i
        Format(label,sizeof(label),"%s [%i points]",SpellNames[SpellLabels[i][team]],SpellMana[SpellLabels[i][team]])
        menu.AddItem(strinfo,label)
    }
    menu.Display(client , MENU_TIMEOUT*4)
}
public SpellMenuHandler(Handle menuid, MenuAction action, id, menu_item)
{
    if(action == MenuAction_End)CloseHandle(menuid)
    else if(action == MenuAction_Select)
    {
        if(!ValidUser(id))
        {
            PrintToChat(id,"Sorry, but you need to be alive to cast spells")
        }
        char strinfo[3]
        GetMenuItem(menuid, menu_item, strinfo, sizeof(strinfo))
        int index = strinfo[0]
        TryCastingSpell(id,index)
    }
}
stock ScrambleSpells(int index)
{
    ArrayList freeSpells = CreateArray(1)
    for(int i=0;i<NUM_SPELLS;i++)
    {
        freeSpells.Push(i)
    }
    for(int i=0;i<BOOK_SPELLS;i++)
    {
        int si = GetRandomInt(0,freeSpells.Length-1)
        SpellIds[i][index] = freeSpells.Get(si)
        RemoveFromArray(freeSpells,si)
    }
    freeSpells.Clear()
    for(int i=0;i<MAX_SPELLS;i++)
    {
        freeSpells.Push(i)
    }
    for(int i=0;i<BOOK_SPELLS;i++)
    {
        int si = GetRandomInt(0,freeSpells.Length-1)
        int label = freeSpells.Get(si)
        if(IsHarmfulSpell(label)&&(!(SpellFlags[SpellIds[i][index]]&SPELLFLAG_HARM)))
        {
            SpellIds[i][index] = 11// This spell can only mean death
        }
        else SpellLabels[i][index] = label
        RemoveFromArray(freeSpells,si)
    }
    freeSpells.Clear()
    delete freeSpells
}
stock Sacrifice(client,spell)
{
    int team = 1
    if(TF2_GetClientTeam(client)==TFTeam_Red)team = 0
    int mana = SpellMana[SpellLabels[spell][team]]
    if(HoovyScores[team]<mana)return false
    HoovyScores[team]-=mana
    return true
}
#define NUM_SPELL_TRAITS 24
stock GetSpellTrait(char[] spelltrait,int len)
{
    char spellTraits[NUM_SPELL_TRAITS][] = {
    "unavoidable","dreadful","awful","disgusting","foolish","menacing","devastating","inevitable",
    "ridiculous","crazy","insane","horrifying","awesome","funny","distracting","cruel",
    "wrong","bad","useless","meaningless","irreversible","mind-blowing","offensive","dismembering"
    }
    int index = GetRandomInt(0,NUM_SPELL_TRAITS-1)
    strcopy(spelltrait,len,spellTraits[index])
}
stock TryCastingSpell(client,spell)
{
    if(!Sacrifice(client,spell))
    {
        PrintToChat(client,"Come back when you\'re a little...Ummm...wiser")
        return false
    }
    static char name[32], trait[24]
    GetClientName(client,name,31)
    ReplaceString(name,31,"%","")
    name[31] = '\0'
    GetSpellTrait(trait,23)
    CurrentHoovyWizard = client
    CurrentWizardTeam = TF2_GetClientTeam(client)
    int team = CurrentWizardTeam==TFTeam_Blue?1:0
    CurrentSpell = SpellIds[spell][team]
    PrintToChatAll("Cover fools! The wizard whose name is %s casts the %s spell \"%s\"",name,trait,SpellNames[SpellLabels[spell][team]])
    CurrentSpellFlags = SpellFlags[CurrentSpell]
    if((CurrentSpellFlags&SPELLFLAG_MAY_ON_ALLY)&&(GetRandomInt(0,100)>50))CurrentSpellFlags |= SPELLFLAG_ON_ALLY
    if((CurrentSpellFlags&SPELLFLAG_MAY_ON_FOE)&&(GetRandomInt(0,100)>50))CurrentSpellFlags |= SPELLFLAG_ON_FOE
    if((CurrentSpellFlags&SPELLFLAG_MAY_ON_YOURSELF)&&(GetRandomInt(0,100)>50))CurrentSpellFlags |= SPELLFLAG_ON_YOURSELF
    if(CurrentSpellFlags&SPELLFLAG_IN_BEAM)CastDirectSpell(client)
    CastSpell()
    LogMessage("Casted spell:%i, on yourself: %i,on allies:%i, on foes:%i",CurrentSpell,CurrentSpellFlags&SPELLFLAG_ON_YOURSELF,CurrentSpellFlags&SPELLFLAG_ON_ALLY,CurrentSpellFlags&SPELLFLAG_ON_FOE)
    return true
}
stock CastDirectSpell(client)
{
    float flPos[3]
    float flAng[3]
    GetClientEyePosition(client, flPos)
    GetClientEyeAngles(client, flAng)
    TR_EnumerateEntities(flPos,flAng,MASK_SHOT,RayType_Infinite,HoovySpellTraceFilter)
}
stock CastSpell()
{
    getSpellCb
    for(int i=1;i<MaxClients;i++)
    {
        if(ValidUser(i)&&IsAllowedToCast(i)&&(((CurrentSpellFlags&SPELLFLAG_ON_YOURSELF)&&i==CurrentHoovyWizard)||(CurrentSpellFlags&SPELLFLAG_IN_EVERYWHERE)||(CurrentSpellFlags&SPELLFLAG_IN_RANGE&&(GetVectorDistance(HoovyCoords[i],HoovyCoords[CurrentHoovyWizard])<SPELL_EFFECT_RADIUS))))
        {
            Call_StartFunction(INVALID_HANDLE,cb)
            Call_PushCell(i)
            Call_Finish()
        }
    }
}
void SpellHeal(int client)
{
    SetEntityHealth(client,GetClientHealth(client)+150)
}
void SpellSpeedup(int client)
{
    TF2_AddCondition(client, TFCond_SpeedBuffAlly, 15.0)
}
void SpellPowerPlay(int client)
{
    TF2_SetPlayerPowerPlay(client,true)
    CreateTimer(1.8,ClearPowerPlayTimer,client)
}
void SpellSlowdown(int client)
{
    TF2_StunPlayer(client,8.0,0.3,TF_STUNFLAG_SLOWDOWN)
}
void SpellJarate(int client)
{
    TF2_AddCondition(client,TFCond_Jarated,8.0)
}
void SpellGnomify(int client)
{
    TF2_AddCondition(client,TFCond_HalloweenTiny,8.0)
}
void SpellInvis(int client)
{
    TF2_AddCondition(client,TFCond_Stealthed,4.0)
}
void SpellOnFire(int client)
{
    TF2_IgnitePlayer(client,CurrentHoovyWizard) 
}
void SpellForcedTaunt(int client)
{
    FakeClientCommand(client,"taunt 0;taunt 0;wait 5000;taunt 0;taunt 0")
}
void SpellMiniCrit(int client)
{
    TF2_AddCondition(client,TFCond_Buffed,4.0)
}
void SpellMilk(int client)
{
    TF2_AddCondition(client,TFCond_Milked,8.0)
}
void SpellCart(int client)
{
    TF2_AddCondition(client,TFCond_HalloweenKart,35.0)
}
void SpellKill(int client)
{
    FakeClientCommand(client,"explode")
}
void SpellBulletproof(int client)
{
    TF2_AddCondition(client,TFCond_BulletImmune,8.0)
}
void SpellIncarnation(int client)
{
    TF2_AddCondition(client,TFCond_PreventDeath,300.0)
}
void SpellSwimming(int client)
{
    TF2_AddCondition(client,TFCond_SwimmingCurse,20.0)
}
public Action ClearPowerPlayTimer(Handle timer, i)
{
    if(ValidUser(i))TF2_SetPlayerPowerPlay(i,false)
}