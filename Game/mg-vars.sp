/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET User Manager                    */
/*                                                                */
/*                                                                */
/*  File:          mg-vars.sp                                     */
/*  Description:   Interconnector of Game and Forum.              */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  MagicGirl.NET Dev Team                    */
/*  2017/02/10 01:53:55                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <MagicGirl.NET>
#include <MagicGirl/vars>

#define PI_NAME THIS_PRETAG ... " - Variables"
#define PI_DESC "Variable Library for MagicGirl.NET"

public Plugin myinfo = 
{
    name        = PI_NAME,
    author      = PI_AUTH,
    description = PI_DESC,
    version     = PI_VERS,
    url         = PI_URLS
};

StringMap g_smVars;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("MG_Vars_IsVarExists",   Native_IsVarExists);
    CreateNative("MG_Vars_GetVariable",   Native_GetVariable);

    RegPluginLibrary("mg-vars");

    return APLRes_Success;
}

public int Native_IsVarExists(Handle plugin, int numParams)
{
    char _key[32];
    if(GetNativeString(1, _key, 32) != SP_ERROR_NONE)
        return false;

    char _var[128];
    return g_smVars.GetString(_key, _var, 128);
}

public int Native_GetVariable(Handle plugin, int numParams)
{
    char _key[32];
    if(GetNativeString(1, _key, 32) != SP_ERROR_NONE)
        return false;
    
    char _var[128];
    if(!g_smVars.GetString(_key, _var, 128))
        return false;
    
    return (SetNativeString(2, _var, GetNativeCell(3), true) == SP_ERROR_NONE);
}

public void OnPluginStart()
{
    g_smVars = new StringMap();

    LoadVars();
    CreateTimer(1800.0, Timer_Refresh, _, TIMER_REPEAT);
}

public Action Timer_Refresh(Handle timer)
{
    LoadVars();
    return Plugin_Stop;
}

void LoadVars()
{
    if(!MG_MySQL_IsConnected())
    {
        CreateTimer(5.0, Timer_Refresh, _, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    PrintToServer("Load Variables From SQL Database...");
    MG_MySQL_GetDatabase().Query(LoadVarsCallback, "SELECT * FROM dxg_vars");
}

public void LoadVarsCallback(Database db, DBResultSet results, const char[] error, any unuse)
{
    if(results == null || error[0])
    {
        MG_Core_LogError("Vars", "LoadVarsCallback", "SQL Error:  %s", error);
        return;
    }

    char type[32], _key[32], _var[128];
    while(results.FetchRow())
    {
        results.FetchString(1, type,  32);
        results.FetchString(2, _key,  32);
        results.FetchString(3, _var, 128);

        g_smVars.SetString(_key, _var, true);

        if(strcmp(type, "cvar") == 0)
        {
            ConVar cvar = FindConVar(_key);
            if(cvar != null)
            {
                cvar.SetString(_var, true, false);
                
                if(results.FetInt(4) == 1)
                    cvar.AddChangeHook(Hook_OnConVarChanged);
            }
        }
    }
}

public void Hook_OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    char cvar[128];
    convar.GetName(cvar, 128);
    
    char _var[128];
    if(!g_smVars.GetString(cvar, _var, 128))
    {
        convar.RemoveChangeHook(Hook_OnConVarChanged);
        return;
    }

    if(strcmp(newValue, _var) == 0)
        return;

    convar.SetString(_var, true, false);
}