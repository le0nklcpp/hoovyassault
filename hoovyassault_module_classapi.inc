/*
This file is a part of hoovyassault plugin
This module is optional and enables Hoovy Engine support (extension enabling custom classes support)
*/
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
#define MAX_CLASSAPI_LIMIT 32
#define ClassApiIndex(%1) (%1-NUM_CLASSES)
#define OnClassApi(%1,%2) if(HoovyClass[%1]>=NUM_CLASSES)%2
enum
{
    HOOVY_CB_IGNORED=0,
    HOOVY_CB_BLOCKED=-1,
    HOOVY_CB_CHANGED=1
}
int NumHoovyClasses = 0
char HoovyExtraClassDesc[MAX_CLASSAPI_LIMIT][256]
char HoovyExtraClassName[MAX_CLASSAPI_LIMIT][16]
float HoovyExtraClassParams[MAX_CLASSAPI_LIMIT][3]
bool HoovyExtraClassMeleeAccess[MAX_CLASSAPI_LIMIT]
int HoovyExtraClassLimit[MAX_CLASSAPI_LIMIT] = -1



typeset HoovyCallback
{
    function void(int id);
    function int(int Victim,int Attacker,int inflictor,float &damage,int &damagetype,int &weapon);
}
void DummyThink(int id)
{
    
}
int DummyAttack(int Victim,int Attacker,int inflictor,float &damage,int &damagetype,int &weapon)
{
    return HOOVY_CB_IGNORED
}
Handle HoovyPlugins[MAX_CLASSAPI_LIMIT][4]
HoovyCallback HoovyThinkCallbacks[MAX_CLASSAPI_LIMIT]
HoovyCallback HoovyAttackCallbacks[MAX_CLASSAPI_LIMIT]
HoovyCallback HoovyPootisCallbacks[MAX_CLASSAPI_LIMIT]
HoovyCallback HoovySpawnCallbacks[MAX_CLASSAPI_LIMIT]

void Hoovyassault_Classapi_Init()
{
    for(int i=0;i<MAX_CLASSAPI_LIMIT;i++)
    {
        HoovyPlugins[i][0] = HoovyPlugins[i][1] = HoovyPlugins[i][2] = HoovyPlugins[i][3] = INVALID_HANDLE
        HoovyThinkCallbacks[i] = DummyThink
        HoovyAttackCallbacks[i] = DummyAttack
        HoovyPootisCallbacks[i] = DummyThink
        HoovySpawnCallbacks[i] = DummyThink
    }
}
void Hoovyassault_Classapi_Create_Natives()
{
    CreateNative("RegisterHoovyClass", NativeRegisterHoovyClass)
    CreateNative("RegisterHoovyThinkCallback", NativeRegisterHoovyThinkCallback)
    CreateNative("RegisterHoovyDamageCallback", NativeRegisterHoovyDamageCallback)
    CreateNative("RegisterHoovyPootisCallback", NativeRegisterHoovyPootisCallback)
    CreateNative("RegisterHoovySpawnCallback", NativeRegisterHoovySpawnCallback)
    RegPluginLibrary("hoovyassault_classapi")
}
Action Hoovyassault_Classapi_TakeDamage(int Victim,int Attacker,int inflictor,float &damage, &damagetype, &weapon)
{
    static int classvictim,classattacker,result
    static bool changed
    changed = false
    result = HOOVY_CB_IGNORED
    classattacker = ClassApiIndex(HoovyClass[Attacker])
    if(classattacker>=0&&HoovyPlugins[classattacker][1]!=INVALID_HANDLE)
    {
        Call_StartFunction(HoovyPlugins[classattacker][1],HoovyAttackCallbacks[classattacker])
        Call_PushCell(Victim)
        Call_PushCell(Attacker)
        Call_PushCell(inflictor)
        Call_PushFloatRef(damage)
        Call_PushCellRef(damagetype)
        Call_PushCellRef(weapon)
        Call_Finish(result)
        switch(result)
        {
            case(HOOVY_CB_CHANGED):changed = true;
            case(HOOVY_CB_BLOCKED):return Plugin_Stop;
        }
    }
    classvictim = ValidUser(Victim)?ClassApiIndex(HoovyClass[Victim]):-1
    if(classvictim>=0&&classvictim!=classattacker&&HoovyPlugins[classvictim][1]!=INVALID_HANDLE) // in this case we've already called that
    {
        Call_StartFunction(HoovyPlugins[classvictim][1],HoovyAttackCallbacks[classvictim])
        Call_PushCell(Victim)
        Call_PushCell(Attacker)
        Call_PushCell(inflictor)
        Call_PushFloatRef(damage)
        Call_PushCellRef(damagetype)
        Call_PushCellRef(weapon)
        Call_Finish(result)
        switch(result)
        {
        case(HOOVY_CB_CHANGED):changed = true;
        case(HOOVY_CB_BLOCKED):return Plugin_Stop;
        }
    }
    return changed?Plugin_Changed:Plugin_Continue
}
void Hoovyassault_Classapi_Think(int id)
{
    int classid = ClassApiIndex(HoovyClass[id])
    if(HoovyPlugins[classid][0]!=INVALID_HANDLE)
    {
        Call_StartFunction(HoovyPlugins[classid][0],HoovyThinkCallbacks[classid])
        Call_PushCell(id)
        Call_Finish()
    }
}
void Hoovyassault_Classapi_Pootis(int id)
{
    int classid = ClassApiIndex(HoovyClass[id])
    if(HoovyPlugins[classid][2]!=INVALID_HANDLE)
    {
        Call_StartFunction(HoovyPlugins[classid][2],HoovyPootisCallbacks[classid])
        Call_PushCell(id)
        Call_Finish()
    }
}
// returns false if we won't let the player pick this class
bool Hoovyassault_Classapi_OnSpawn(int id)
{
    static int result
    static int classid
    result = 1
    classid = ClassApiIndex(HoovyClass[id])
    if(HoovyPlugins[classid][3]!=INVALID_HANDLE)
    {
        Call_StartFunction(HoovyPlugins[classid][3],HoovySpawnCallbacks[classid])
        Call_PushCell(id)
        Call_Finish(result)
    }
    return result!=0
}
any NativeRegisterHoovyThinkCallback(Handle plugin,int numParams)
{
    int classid = ClassApiIndex(GetNativeCell(1))
    if(classid<0||classid>NumHoovyClasses)ThrowNativeError(1,"Failed to register callback for %s class %i(%i classes total)",classid<0?"hardcoded":"non-existent",classid,NumHoovyClasses+NUM_CLASSES-1)
    HoovyThinkCallbacks[classid] = view_as<HoovyCallback>(GetNativeFunction(2))
    HoovyPlugins[classid][0] = plugin
}
any NativeRegisterHoovyDamageCallback(Handle plugin,int numParams)
{
    int classid = ClassApiIndex(GetNativeCell(1))
    if(classid<0||classid>NumHoovyClasses)ThrowNativeError(1,"Failed to register callback for %s class %i(%i classes total)",classid<0?"hardcoded":"non-existent",classid,NumHoovyClasses+NUM_CLASSES-1)
    HoovyAttackCallbacks[classid] = view_as<HoovyCallback>(GetNativeFunction(2))
    HoovyPlugins[classid][1] = plugin
}
any NativeRegisterHoovyPootisCallback(Handle plugin,int numParams)
{
    int classid = ClassApiIndex(GetNativeCell(1))
    if(classid<0||classid>NumHoovyClasses)ThrowNativeError(1,"Failed to register callback for %s class %i(%i classes total)",classid<0?"hardcoded":"non-existent",classid,NumHoovyClasses+NUM_CLASSES-1)
    HoovyPootisCallbacks[classid] = view_as<HoovyCallback>(GetNativeFunction(2))
    HoovyPlugins[classid][2] = plugin
}
any NativeRegisterHoovySpawnCallback(Handle plugin,int numParams)
{
    int classid = ClassApiIndex(GetNativeCell(1))
    if(classid<0||classid>NumHoovyClasses)ThrowNativeError(1,"Failed to register callback for %s class %i(%i classes total)",classid<0?"hardcoded":"non-existent",classid,NumHoovyClasses+NUM_CLASSES-1)
    HoovySpawnCallbacks[classid] = view_as<HoovyCallback>(GetNativeFunction(2))
    HoovyPlugins[classid][3] = plugin
}
int NativeRegisterHoovyClass(Handle plugin,int numParams)
{
    if(NumHoovyClasses==MAX_CLASSAPI_LIMIT)ThrowNativeError(2,"Failed to register another class: class limit of %i classes reached. Try increasing MAX_CLASSAPI_LIMIT in source code",MAX_CLASSAPI_LIMIT)
    GetNativeString(1, HoovyExtraClassName[NumHoovyClasses], 16)
    GetNativeString(2, HoovyExtraClassDesc[NumHoovyClasses], 255)
    HoovyExtraClassParams[NumHoovyClasses][0]=view_as<float>(GetNativeCell(3))
    HoovyExtraClassParams[NumHoovyClasses][1]=view_as<float>(GetNativeCell(4))
    HoovyExtraClassParams[NumHoovyClasses][2]=view_as<float>(GetNativeCell(5))
    HoovyExtraClassMeleeAccess[NumHoovyClasses] = GetNativeCell(6)
    HoovyExtraClassLimit[NumHoovyClasses] = GetNativeCell(7)
    NumHoovyClasses++
    return NUM_CLASSES+NumHoovyClasses-1
}