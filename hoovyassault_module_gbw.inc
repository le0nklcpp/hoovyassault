Handle g_hWeaponEquip
/*
This file is part of hoovyassault plugin, however if you build it with GBW_STAGING disabled you can safely remove it
This code was stolen from GiveBotsWeapons by luki1412
*/
stock GBW_Staging_OnPluginStart()
{
    Handle g_hGameConfig = LoadGameConfigFile("give.bots.weapons")
    StartPrepSDKCall(SDKCall_Player)
    PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Virtual, "WeaponEquip")
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer)
    g_hWeaponEquip = EndPrepSDKCall()
}
int GetRandomUInt(int min, int max)
{
    return RoundToFloor(GetURandomFloat() * (max - min + 1)) + min;
}
stock CreateWeapon(int client, char[] classname, int itemindex, int level = 0)
{
    int weapon = CreateEntityByName(classname);

    if (!IsValidEntity(weapon))
    {
        return false;
    }

    char entclass[64];
    GetEntityNetClass(weapon, entclass, sizeof(entclass));
    SetEntData(weapon, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), itemindex);	 
    SetEntData(weapon, FindSendPropInfo(entclass, "m_bInitialized"), 1);
    SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityQuality"), 6);

    if (level)
    {
        SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
    }
    else
    {
        SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityLevel"), GetRandomUInt(1,99));
    }

    switch (itemindex)
    {
        case 810:
        {
            SetEntData(weapon, FindSendPropInfo(entclass, "m_iObjectType"), 3);
        }
        case 998:
        {
            SetEntData(weapon, FindSendPropInfo(entclass, "m_nChargeResistType"), GetRandomUInt(0,2));
        }
        case 19,1151:
        {
            SetEntProp(weapon, Prop_Data, "m_iClip1", 4);
        }
    }

    DispatchSpawn(weapon)
    SDKCall(g_hWeaponEquip, client, weapon)
    return true;
}
stock SetAmmo(client,weapon,int amount)
{
        if(!IsValidEntity(weapon))return
        int offs = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType",1)
        int iAmmo = FindSendPropInfo("CTFPlayer","m_iAmmo")
        if(iAmmo!=-1&&offs!=-1)SetEntData(client,iAmmo+(offs*4),amount,4)
}