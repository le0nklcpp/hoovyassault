native int GetHoovyClass(int client);
native int SetHoovyClass(int client,int class);
native int GetHoovyScores(int client,bool as_team = false);
native int SetHoovyScores(int client,int sc,bool as_team=false);
native void SetHoovyClassRestriction(int client,bool restrict = true);
native void AddHoovyScores(int client,int sc,bool as_team=false);
native bool WithdrawHoovyScores(int client,int amount,bool as_team=false);
native void SetHoovyPrimary(int client,bool allow = true)
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
    HOOVY_CB_IGNORED=0,
    HOOVY_CB_BLOCKED=-1,
    HOOVY_CB_CHANGED=1
}
typeset HoovyCallback
{
    function int(int id);
    function void(int id);
    function int(int Victim,int Attacker,int inflictor,float &damage,int &damagetype,int &weapon);
}
native int RegisterHoovyClass(String: classname[],String: classdesc[],float maxhealth,float dmgbonus,float dmgvuln,bool meleeOnly=false,int ClassLimit=0)
native void RegisterHoovyThinkCallback(int id,HoovyCallback cb)
native void RegisterHoovyDamageCallback(int id,HoovyCallback cb)
native void RegisterHoovyPootisCallback(int id,HoovyCallback cb)
native void RegisterHoovySpawnCallback(int id,HoovyCallback cb)