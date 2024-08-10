/*
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAA <https://www.gnu.org/licenses/>.
*/
// TODO: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <menus>
#include <sdkhooks>
#include <string>
#include "hoovyassault"

#define AAAAAAAAAAAAAA 120.0

int AAAAAAAAAAAA = -1
bool A_A[MAXPLAYERS] = false
#define AAAAAAAAA     TF2_AddCondition(A,TFCond_HalloweenBombHead,HOOVY_CYCLE_TIME+0.1);TF2_AddCondition(A,TFCond_SpeedBuffAlly,HOOVY_CYCLE_TIME+0.1);GetClientAbsOrigin(A,AAAAAAA)

#define is_AA(%1) (IsClientInGame(%1)&&IsPlayerAlive(%1))
#define is_AAAA(%1) ((GetHoovyClass(%1)==AAAAAAAAAAAA)&&is_AA(%1))
#define is_AAAAAA(%1) (is_AA(%1)&&(TF2_GetClientTeam(%1)!=TF2_GetClientTeam(A)))
#define is_AAAAAAA(%1) (GetVectorDistance(AAAAAAA,AAAAAAAAAAA)<AAAAAAAAAAAAAA)
#define AAAAAAAA EmitSoundToAll("vo/heavy_battlecry03.mp3",AAAAAAAAAAAAAAA,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL,-1,NULL_VECTOR,NULL_VECTOR,true,1.3)
public Plugin myinfo = 
{
 name = "AAAAAAA",
 author = "AAAAAAA",
 description = "AAAAAAA",
 version = "AAAAAAA",
 url = "AAAAAAA"
};
// AAAAAAAA
public Action Timer_AAAA(Handle timer,AAAAAAAAAAAAAAA)
{
    if(is_AAAA(AAAAAAAAAAAAAAA))
    {
        A_A[AAAAAAAAAAAAAAA] = true
        //AAAAAAAA
        EmitSoundToAll("vo/heavy_battlecry03.mp3",AAAAAAAAAAAAAAA,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL,-1,NULL_VECTOR,NULL_VECTOR,true,GetGameTime()+1.3)
        CreateTimer(1.15,Timer_AAAA,AAAAAAAAAAAAAAA) // AAAAAAAAAAAAAAAA
    }
    else A_A[AAAAAAAAAAAAAAA] = false
}
int AAA(int A)
{
   if(!A_A[A])
   {
        CreateTimer(1.0,Timer_AAAA,A)
   }
   return 1
}
void AAAAAAAAAAAAAAAAAAAAAAAAAAAA(int A)
{
    float AAAAAAA[3],AAAAAAAAAAA[3]
    AAAAAAAAA
    for(int AA = 1;AA < MaxClients;AA++)
    {
        if(is_AAAAAA(AA))
        {
            GetClientAbsOrigin(AA,AAAAAAAAAAA)
            if(is_AAAAAAA(AA))
            {
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAA(A,AAAAAAAAAAA)
                return
            }
        }
    }
}
stock AAAAAAAAAAAAAAAAAAAAAAAAAAAAA(A,float AAAAAAA[3])
{
    static float pos[3]
    static float dist
    TFTeam AAAAAAAAAAAAAAAA = TF2_GetClientTeam(A)
    FakeClientCommand(A,"explode")
    EmitSoundToAll("items/cart_explode.wav",SOUND_FROM_WORLD,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL,-1,AAAAAAA)
    AttachParticle(AAAAAAA,"hightower_explosion","",0.0,2.0)
    for(int AA=1;AA<MaxClients;AA++)
    {
        if(!is_AA(AA)||(TF2_GetClientTeam(AA)==AAAAAAAAAAAAAAAA))continue;
        GetClientAbsOrigin(AA,pos)
        dist = GetVectorDistance(pos,AAAAAAA)
        if(dist<AAAAAAAAAAAAAA) // AAAAAAAAAAAAAAAAAAAAAA
        {
            SDKHooks_TakeDamage(AA, 0, A, dist<(AAAAAAAAAAAAAA/2.0)?320.0:(320.0*(1.0-dist/AAAAAAAAAAAAAA)), DMG_PREVENT_PHYSICS_FORCE|DMG_CRUSH|DMG_ALWAYSGIB)
        }
    }
}
AttachParticle(float flPos[3], const String:strParticleEffect[], const String:strAttachPoint[]="", Float:flOffsetZ=0.0, Float:flSelfDestruct=0.0)
{
    new iParticle = CreateEntityByName("info_particle_system");
    if(iParticle > MaxClients && IsValidEntity(iParticle))
    {
        flPos[2] += flOffsetZ;

        TeleportEntity(iParticle, flPos, NULL_VECTOR, NULL_VECTOR);
	
        DispatchKeyValue(iParticle, "effect_name", strParticleEffect);
        DispatchSpawn(iParticle);
        SetVariantString("!activator");
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
public Action Timer_DeleteParticle(Handle:hTimer, any:iRefEnt)
{
	new iEntity = EntRefToEntIndex(iRefEnt);
	if(iEntity > MaxClients)
	{
		AcceptEntityInput(iEntity, "Kill");
	}
	
	return Plugin_Handled;
}
public OnAllPluginsLoaded()
{
    if(LibraryExists("hoovyassault_classapi"))
    {
        AAAAAAAAAAAA = RegisterHoovyClass("AAAAAAAAAAAA","AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",0.3,0.01,1.0,true,0)
        RegisterHoovySpawnCallback(AAAAAAAAAAAA,AAA)
        RegisterHoovyThinkCallback(AAAAAAAAAAAA,AAAAAAAAAAAAAAAAAAAAAAAAAAAA)
    }
}
public OnMapStart()
{
    PrecacheSound("items/cart_explode.wav")
    PrecacheSound("vo/heavy_battlecry03.mp3")
}