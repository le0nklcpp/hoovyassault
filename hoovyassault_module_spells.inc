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
int SpellJumpingCurse[MAXPLAYERS+1]
bool ForceJump[MAXPLAYERS+1]
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
#define SPELLFLAG_MAY_ON_EVERYONE (1<<14)
#define SPELLFLAG_PICK_ALLY (1<<15)

#define SPELL_CAST_SOUNDS_NUM 6

char SpellCastingSounds[SPELL_CAST_SOUNDS_NUM][] = {
"misc/halloween/spell_meteor_cast.wav",
"misc/halloween/spell_athletic.wav",
"misc/spell_mirv_cast.wav",
"misc/halloween/merasmus_spell.wav",
"ambient_mp3/halloween/mysterious_perc_02.mp3",
"misc/halloween/merasmus_stun.wav"
}


// Note that non-wizard heavies can also use BAD Wizard's voice lines, and a Wizard can use GOOD non-Wizard's voice lines
#define SPELL_VO_SHARED 1 // To disable it set this value to 0



#define SPELL_VO_BAD_WIZARD_NUM 10

char SpellCommentBad_Wizard[SPELL_VO_BAD_WIZARD_NUM][] = {
"vo/heavy_jeers01.mp3",
"vo/heavy_jeers03.mp3",
"vo/heavy_jeers04.mp3",
"vo/heavy_jeers09.mp3",
"vo/heavy_sf12_badmagic06.mp3",
"vo/heavy_sf12_badmagic10.mp3",
"vo/heavy_sf13_magic_reac01.mp3",
"vo/heavy_sf13_magic_reac02.mp3",
"vo/heavy_sf13_magic_reac03.mp3",
"vo/heavy_fairyprincess12.mp3"
}

#define SPELL_VO_BAD_NUM 12

char SpellCommentBad[SPELL_VO_BAD_NUM][] = {
"vo/heavy_sf12_seeking01.mp3",
"vo/heavy_sf12_seeking03.mp3",
"vo/heavy_sf12_seeking04.mp3",
"vo/heavy_sf12_seeking05.mp3",
"vo/heavy_sf12_seeking06.mp3",
"vo/heavy_meleedare01.mp3",
"vo/heavy_meleedare02.mp3",
"vo/heavy_meleedare03.mp3",
"vo/heavy_meleedare05.mp3",
"vo/heavy_meleedare06.mp3",
"vo/heavy_fairyprincess17.mp3",
"vo/heavy_fairyprincess19.mp3"
}

#define SPELL_VO_GOOD_WIZARD_NUM 2

char SpellCommentGood_Wizard[SPELL_VO_GOOD_WIZARD_NUM][] = {
"vo/heavy_fairyprincess08.mp3",
"vo/heavy_fairyprincess10.mp3"
}

#define SPELL_VO_GOOD_NUM 6

char SpellCommentGood[SPELL_VO_GOOD_NUM][] = {
"vo/heavy_domination05.mp3",
"vo/heavy_sf13_influx_big01.mp3",
"vo/heavy_sf13_influx_big02.mp3",
"vo/heavy_sf13_influx_big04.mp3",
"vo/heavy_sf13_influx_big05.mp3",
"vo/heavy_positivelocalization04.mp3"
}
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
SPELL_JUMPING,
SPELL_SPEEDUP,
SPELL_INSTANTDEATH,
SPELL_REPLACE,
SPELL_SCRAMBLE,
SPELL_STRIP_WEAPONS,
SPELL_LARGE_HEALTH,
SPELL_TITANIZE,
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
(SPELLFLAG_FUN|SPELLFLAG_MAY_ON_ALLY|SPELLFLAG_MAY_ON_FOE|SPELLFLAG_ON_YOURSELF|SPELLFLAG_IN_EVERYWHERE),
(SPELLFLAG_FUN|SPELLFLAG_MAY_ON_EVERYONE|SPELLFLAG_MAY_ON_ALLY|SPELLFLAG_MAY_ON_FOE|SPELLFLAG_IN_EVERYWHERE),
(SPELLFLAG_BUFF|SPELLFLAG_ON_ALLY|SPELLFLAG_IN_RANGE),
(SPELLFLAG_HARM|SPELLFLAG_ON_FOE|SPELLFLAG_IN_RANGE|SPELLFLAG_MAY_ON_YOURSELF),
(SPELLFLAG_BUFF|SPELLFLAG_ON_YOURSELF),
(SPELLFLAG_FUN|SPELLFLAG_ON_YOURSELF), // Casting this on yourself will cause everyone to switch places
(SPELLFLAG_FUN|SPELLFLAG_ON_ALLY|SPELLFLAG_ON_FOE|SPELLFLAG_ON_YOURSELF|SPELLFLAG_IN_EVERYWHERE),
(SPELLFLAG_BUFF|SPELLFLAG_ON_ALLY|SPELLFLAG_ON_FOE|SPELLFLAG_IN_EVERYWHERE),
(SPELLFLAG_BUFF|SPELLFLAG_PICK_ALLY|SPELLFLAG_IN_EVERYWHERE)
}
int CurrentHoovyWizard
int CurrentSpellFlags
int CurrentSpell
TFTeam CurrentWizardTeam
typeset SpellCallback
{
    function void (int client)
}
SpellCallback SpellList[23]
#define getSpellCb  SpellCallback cb = SpellList[CurrentSpell]
#define IsAllowedToCast(%1) (((CurrentSpellFlags&SPELLFLAG_ON_YOURSELF)&&(CurrentHoovyWizard==%1))||((CurrentSpellFlags&SPELLFLAG_ON_ALLY)&&TF2_GetClientTeam(%1)==CurrentWizardTeam)||((CurrentSpellFlags&SPELLFLAG_ON_FOE)&&TF2_GetClientTeam(%1)!=CurrentWizardTeam))
bool HoovySpellTraceFilter(int entity)
{
    if(ValidUser(entity)&&IsAllowedToCast(entity))
    {
        //LogMessage("Spell hit entity #%i",entity)
        getSpellCb
        Call_StartFunction(INVALID_HANDLE,cb)
        Call_PushCell(entity)
        Call_Finish()
        return false
    }
    return true
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
    cb(SPELL_JUMPING,SpellJumping)
    cb(SPELL_SPEEDUP,SpellSpeedup)
    cb(SPELL_INSTANTDEATH,SpellInstantDeath)
    cb(SPELL_REPLACE,SpellReplace)
    cb(SPELL_SCRAMBLE,SpellScramble)
    cb(SPELL_STRIP_WEAPONS,SpellStripWeapons)
    cb(SPELL_LARGE_HEALTH,SpellLargeHealth)
    cb(SPELL_TITANIZE,SpellTitanize)
    #undef cb
    for(int i=0;i<SPELL_VO_GOOD_WIZARD_NUM;i++)PrecacheSound(SpellCommentGood_Wizard[i])
    for(int i=0;i<SPELL_VO_GOOD_NUM;i++)PrecacheSound(SpellCommentGood[i])
    for(int i=0;i<SPELL_VO_BAD_NUM;i++)PrecacheSound(SpellCommentBad[i])
    for(int i=0;i<SPELL_VO_BAD_WIZARD_NUM;i++)PrecacheSound(SpellCommentBad_Wizard[i])
    for(int i=0;i<SPELL_CAST_SOUNDS_NUM;i++)PrecacheSound(SpellCastingSounds[i])
    RegAdminCmd("hassault_test_spell",TestSpellCommand,ADMFLAG_RCON)
}
public Action TestSpellCommand(client, args)
{
    if(!ValidUser(client))return Plugin_Handled
    if(args<1)
    {
        PrintToConsole(client,"You must specify spell to cast")
        return Plugin_Handled
    }
    int spellid = GetCmdArgInt(1)
    if(spellid>=NUM_SPELLS)
    {
        PrintToConsole(client,"There\'s no spell like this in your spellbook")
        return Plugin_Handled
    }
    CurrentWizardTeam = TF2_GetClientTeam(client)
    int team = CurrentWizardTeam==TFTeam_Blue?1:0
    int buf = SpellIds[0][team]
    SpellIds[0][team] = spellid
    TryCastingSpell(client,0)
    SpellIds[0][team] = buf
    return Plugin_Handled
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
    for(int i=1;i<MaxClients;i++)
    {
        SpellJumpingCurse[i] = 0
        ForceJump[i] = false
    }
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
            return
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
    if((CurrentSpellFlags&SPELLFLAG_MAY_ON_EVERYONE)&&(GetRandomInt(0,100)>50))CurrentSpellFlags |= (SPELLFLAG_ON_ALLY|SPELLFLAG_ON_FOE|SPELLFLAG_ON_YOURSELF)
    if(CurrentSpellFlags&SPELLFLAG_IN_BEAM)CastDirectSpell(client)
    EmitSoundToAll(SpellCastingSounds[GetRandomInt(0,SPELL_CAST_SOUNDS_NUM-1)],client)
    CastSpell()
    LogMessage("Casted spell:%i, on yourself: %i,on allies:%i, on foes:%i",CurrentSpell,CurrentSpellFlags&SPELLFLAG_ON_YOURSELF,CurrentSpellFlags&SPELLFLAG_ON_ALLY,CurrentSpellFlags&SPELLFLAG_ON_FOE)
    return true
}
stock CastDirectSpell(client)
{
    /*float flPos[3]
    float flAng[3]
    GetClientEyePosition(client, flPos)
    GetClientEyeAngles(client, flAng)
    TR_EnumerateEntities(flPos,flAng,MASK_SOLID,RayType_Infinite,HoovySpellTraceFilter)*/
    int target = GetClientAimTarget(client,true)
    HoovySpellTraceFilter(target)
}
stock CastSpell()
{
    getSpellCb
    if(CurrentSpellFlags&SPELLFLAG_PICK_ALLY)
    {
        ArrayList clist = CreateArray()
        for(int i=1;i<MaxClients;i++)
        {
            if((!ValidUser(i))||(TF2_GetClientTeam(i)!=CurrentWizardTeam)||i==CurrentHoovyWizard)continue;
            clist.Push(i)
        }
        if(clist.Length<1)return
        int client = clist.Get(GetRandomInt(0,clist.Length-1))
        ReactToSpell(client)
        Call_StartFunction(INVALID_HANDLE,cb)
        Call_PushCell(client)
        Call_Finish()
        clist.Clear()
        delete clist
    }
    for(int i=1;i<MaxClients;i++)
    {
        if(ValidUser(i)&&IsAllowedToCast(i)&&(((CurrentSpellFlags&SPELLFLAG_ON_YOURSELF)&&i==CurrentHoovyWizard)||(CurrentSpellFlags&SPELLFLAG_IN_EVERYWHERE)||(CurrentSpellFlags&SPELLFLAG_IN_RANGE&&(GetVectorDistance(HoovyCoords[i],HoovyCoords[CurrentHoovyWizard])<SPELL_EFFECT_RADIUS))))
        {
            ReactToSpell(i)
            Call_StartFunction(INVALID_HANDLE,cb)
            Call_PushCell(i)
            Call_Finish()
        }
    }
}
void ReactToSpell(int client)
{
    if(GetRandomInt(0,100)<61)return
    if(CurrentSpellFlags&(SPELLFLAG_DEBUFF|SPELLFLAG_HARM|SPELLFLAG_FUN)) // Bad spell
    {
        if(client==CurrentHoovyWizard)EmitSoundToAll(SpellCommentBad_Wizard[GetRandomInt(0,SPELL_VO_BAD_WIZARD_NUM-1)],client,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL)
        else {
            #if SPELL_VO_SHARED
              if(GetRandomInt(0,100)<59){
            #endif
            EmitSoundToAll(SpellCommentBad[GetRandomInt(0,SPELL_VO_BAD_NUM-1)],client,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL)
            #if SPELL_VO_SHARED
              } else EmitSoundToAll(SpellCommentBad_Wizard[GetRandomInt(0,SPELL_VO_BAD_WIZARD_NUM-1)],client,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL)
            #endif
        }
    }
    else {
        // Good spell
        if(client==CurrentHoovyWizard)
        {
            #if SPELL_VO_SHARED
              if(GetRandomInt(0,100)<59){
            #endif
            EmitSoundToAll(SpellCommentGood[GetRandomInt(0,SPELL_VO_GOOD_NUM-1)],client,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL)
            #if SPELL_VO_SHARED
              } else EmitSoundToAll(SpellCommentGood_Wizard[GetRandomInt(0,SPELL_VO_GOOD_WIZARD_NUM-1)],client,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL)
            #endif
        }
        else EmitSoundToAll(SpellCommentGood[GetRandomInt(0,SPELL_VO_GOOD_NUM-1)],client,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL)
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
    TF2_AddCondition(client,TFCond_Stealthed,40.0)
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
void SpellJumping(int client)
{
    SpellJumpingCurse[client] = 30
    CreateTimer(1.0,JumpTimer,client,TIMER_REPEAT)
}
void SpellInstantDeath(int client)
{
    SetEntityHealth(client,1)
}
void SpellReplace(int client)
{
    ArrayList clist = CreateArray()
    for(int i=1;i<MaxClients;i++)
    {
        if(!ValidUser(i)||i==client||GetClientTeam(i)==GetClientTeam(client))continue;
        clist.Push(i)
    }
    if(clist.Length>0)
    {
        int index = clist.Get(GetRandomInt(0,clist.Length-1))
        FakeClientCommandEx(client,"dropitem")
        FakeClientCommandEx(index,"dropitem")
        TeleportEntity(client,HoovyCoords[index],NULL_VECTOR,NULL_VECTOR)
        TeleportEntity(index,HoovyCoords[client],NULL_VECTOR,NULL_VECTOR)
    }
    clist.Clear()
    delete clist
}
void SpellScramble(int client)
{
    ArrayList clist = CreateArray()
    for(int i=1;i<MaxClients;i++)
    {
        if(!ValidUser(i))continue;
        clist.Push(i)
    }
    if(clist.Length>0)
    {
        while(clist.Length >= 2)
        {
            int index = GetRandomInt(0,clist.Length-1)
            int cl1 = clist.Get(index)
            RemoveFromArray(clist,index)
            index = GetRandomInt(0,clist.Length-1)
            int cl2 = clist.Get(index)
            RemoveFromArray(clist,index)
            FakeClientCommandEx(cl1,"dropitem")
            FakeClientCommandEx(cl2,"dropitem")
            TeleportEntity(cl2,HoovyCoords[cl1],NULL_VECTOR,NULL_VECTOR)
            TeleportEntity(cl1,HoovyCoords[cl2],NULL_VECTOR,NULL_VECTOR)
        }
    }
    clist.Clear()
    delete clist
}
void SpellStripWeapons(int client)
{
    TF2_RemoveAllWeapons(client)
}
void SpellLargeHealth(int client)
{
    SetEntityHealth(client,3000)
}
void SpellTitanize(int client)
{
    TF2_AddCondition(client,TFCond_HalloweenGiant,72.0)
    TF2_AddCondition(client,TFCond_HalloweenQuickHeal,3.0)
    SetEntityHealth(client,9000)
}
public Action JumpTimer(Handle timer,i)
{
    if(ValidUser(i)&&(SpellJumpingCurse[i]>0))
    {
        SpellJumpingCurse[i]--
        ForceJump[i] = !ForceJump[i]
/*        static int onground
        onground = GetEntPropEnt(i,Prop_Send,"m_hGroundEntity")
        if(onground!=-1)
        {
            SpellJumpingCurse[i]--
            static float vel[3]
            GetEntPropVector(i, Prop_Data, "m_vecVelocity", vel)
            vel[2] += 250.0
            TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vel)
        }*/
        return Plugin_Continue
    }
    ForceJump[i] = false
    return Plugin_Stop
}
public Action ClearPowerPlayTimer(Handle timer, i)
{
    if(ValidUser(i))TF2_SetPlayerPowerPlay(i,false)
    return Plugin_Stop
}