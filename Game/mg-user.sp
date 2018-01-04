/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET User Manager                    */
/*                                                                */
/*                                                                */
/*  File:          mg-user.sp                                     */
/*  Description:   Interconnector of Game and Forum.              */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  MagicGirl.NET Dev Team                    */
/*  2017/01/05 07:29:07                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <MagicGirl.NET>
#include <MagicGirl/user>

#define PI_NAME THIS_PRETAG ... " - User Manager"
#define PI_AUTH THIS_AUTHOR
#define PI_DESC "User Manager for MagicGirl.NET"
#define PI_VERS Core_Version ... " " ... APIs_Version ... " " ... "<commit-count>"
#define PI_URLS THIS_URLINK

bool g_authClient[MAXPLAYERS+1][Authentication];

Handle g_hOnUMChecked;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("MG_UM_IsAuthorized", Native_IsAuthorized);
    return APLRes_Success;
}

public int Native_IsAuthorized(Handle plugin, int numParams)
{
    return g_authClient[GetNativeCell(1)][GetNativeCell(2)];
}

public void OnPluginStart()
{
    // console command
    RegConsoleCmd("sm_who", Command_Who);

    // global forwards
    g_hOnUMChecked = CreateGlobalForward("OnClientAuthCheck", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
}

public void OnRebuildAdminCache(AdminCachePart part)
{
    if(part == AdminCache_Admins)
        for(int client = 1; client <= MaxClients; ++client)
            if(IsClientAuthorized(client))
                OnClientAuthorized(client, "");
}

public Action Command_Who(int client, int args)
{
    if(!IsValidClient(client))
        return Plugin_Handled;
    
    static int _iLastUse[MAXPLAYERS+1];
    
    if(_iLastUse[client] > GetTime() - 5)
        return Plugin_Handled;
    
    _iLastUse[client] = GetTime();

    // dont print all in one time. if players > 48 will not working.
    CreateTimer(0.3, Timer_PrintConsole, client, TIMER_REPEAT);
    
    return Plugin_Handled;
}

public Action Timer_PrintConsole(Handle timer, int client)
{
    static int _iCurrentIndex[MAXPLAYERS+1];
    if(!IsClientInGame(client))
    {
        _iCurrentIndex[client] = 0;
        return Plugin_Stop;
    }

    int left = 16; // we loop 16 clients one time.
    while(left--)
    {
        int index = ++_iCurrentIndex[client];

        if(index == 0)
        {
            PrintToConsole(client, "#slot    userid      name      Supporter    Vip    Contributor    Operator    Administrator");
            continue;
        }
        
        if(index >= MaxClients)
        {
            _iCurrentIndex[client] = 0;
            return Plugin_Stop;
        }

        if(!IsValidClient(index))
            continue;
        
        char strSlot[8], strUser[8];
        StringPad(index, 4, ' ', strSlot);
        StringPad(index, 6, ' ', strUser);
        char strFlag[5][4];
        for(int x = 0; x < 5; ++x)
            TickOrCross(g_authClient[index][x], strFlag[x]);
        PrintToConsole(client, "%s    %s    %N    %s    %s    %s    %s    %s", strSlot, strUser, index, strFlag[0], strFlag[1], strFlag[2], strFlag[3], strFlag[4]);
    }

    return Plugin_Continue;
}

public void OnClientAuthorized(int client, const char[] auth)
{
    for(int i = 0; i < view_as<int>(Authentication); ++i)
        g_authClient[client][i] = false;

    if(strcmp(auth, "BOT") == 0 || IsFakeClient(client) || IsClientSourceTV(client))
        return;
    
    char steamid[32];
    if(!GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
    {
        MG_Core_LogMessage("User", "OnClientAuthorized", "Error: We can not verify client`s SteamId64 -> \"%L\"", client);
        CreateTimer(0.1, Timer_ReAuthorize, client, TIMER_REPEAT);
        return;
    }

    LoadClientAuth(client, steamid);
}

public Action Timer_ReAuthorize(Handle timer, int client)
{
    if(!IsClientConnected(client))
        return Plugin_Stop;

    char steamid[32];
    if(!GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
    {
        MG_Core_LogMessage("User", "OnClientAuthorized", "Error: We can not verify client`s SteamId64 -> \"%L\"", client);
        return Plugin_Continue;
    }

    LoadClientAuth(client, steamid);
    
    return Plugin_Stop;
}

void LoadClientAuth(int client, const char[] steamid)
{
    if(!MG_MySQL_IsConnected())
    {
        MG_Core_LogError("User", "LoadClientAuth", "Error: SQL is unavailable -> \"%L\"", client);
        CreateTimer(5.0, Timer_ReAuthorize, client);
        return;
    }
    
    Database db = MG_MySQL_GetDatabase();
    
    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "SELECT b.uid,b.username,a.imm,a.spt,a.vip,a.ctb,a.opt,a.adm FROM dxg_users a LEFT JOIN dz_common_member b ON a.uid = b.uid WHERE a.steamid = '%s'", steamid);
    db.Query(LoadClientCallback, m_szQuery, GetClientUserId(client));
}

public void LoadClientCallback(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!client)
        return;
    
    if(results == null || error[0])
    {
        MG_Core_LogError("User", "LoadClientCallback", "SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(5.0, Timer_ReAuthorize, client);
        return;
    }
    
    if(results.RowCount <= 0 || results.FetchRow())
    {
        CallForward(client);
        return;
    }

    g_authClient[client][Spt] = (results.FetchInt(3) == 1);
    g_authClient[client][Vip] = (results.FetchInt(4) == 1);
    g_authClient[client][Ctb] = (results.FetchInt(5) == 1);
    g_authClient[client][Opt] = (results.FetchInt(6) == 1);
    g_authClient[client][Adm] = (results.FetchInt(7) == 1);

    if(g_authClient[client][Ctb] || g_authClient[client][Opt] || g_authClient[client][Adm])
    {
        AdminId _admin = GetUserAdmin(client);
        if(_admin != INVALID_ADMIN_ID)
            RemoveAdmin(_admin);
        
        char username[32];
        results.FetchString(1, username, 32);
        _admin = CreateAdmin(username);
        SetUserAdmin(client, _admin, true);
        SetAdminImmunityLevel(_admin, results.FetchInt(2));

        _admin.SetFlag(Admin_Reservation, true);
        _admin.SetFlag(Admin_Generic, true);
        _admin.SetFlag(Admin_Kick, true);
        _admin.SetFlag(Admin_Slay, true);
        _admin.SetFlag(Admin_Changemap, true);
        _admin.SetFlag(Admin_Chat, true);
        _admin.SetFlag(Admin_Vote, true);

        if(g_authClient[client][Opt] || g_authClient[client][Adm] || g_authClient[client][Own])
        {
            _admin.SetFlag(Admin_Ban, true);
            _admin.SetFlag(Admin_Unban, true);
            
            if(g_authClient[client][Adm] || g_authClient[client][Own])
            {
                _admin.SetFlag(Admin_Convars, true);
                _admin.SetFlag(Admin_Config, true);
                _admin.SetFlag(Admin_Password, true);
                _admin.SetFlag(Admin_Cheats, true);
                
                if(g_authClient[client][Own])
                {
                    _admin.SetFlag(Admin_RCON, true);
                    _admin.SetFlag(Admin_Root, true);
                }
            }
        }

        RunAdminCacheChecks(client);
    }
    
    CallForward(client);
}

void CallForward(int client)
{
    Call_StartForward(g_hOnUMChecked);
    Call_PushCell(client);
    for(int i = 0; i < view_as<int>(Authentication); ++i)
        Call_PushCell(g_authClient[client][i]);
    Call_Finish();
}

/*  Check client validation  */
stock bool IsValidClient(int index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index) && !IsFakeClient(index) && !IsClientSourceTV(index));
}

/* String.PadLeft */
stock void StringPad(int number, int maxLen, char c, char[] output)
{
    char[] buffer = new char[maxLen];
    IntToString(number, buffer, maxLen);
    int padLen = maxLen - strlen(buffer);

    for(int i = 0; i < padLen; ++i)
    {
        output[i] = c;
    }

    StrCat(output, maxLen, buffer);
}

/* return tick or cross */
stock void TickOrCross(bool res, char[] output)
{
    strcopy(output, 4, res ? "✔" : "✘");
}

/*  Convert Steam64 To SteamID  */ 
stock void Steam64toSteamID(const char[] friendId, char[] steamid, int iLen)
{
    char[] szBase = "76561197960265728";
    char szSteam[18], szAccount[18];
    int iBorrow, iY, iZ, iTemp;

    strcopy(szSteam, 18, friendId);

    if(CharToNumber(szSteam[16]) % 2 == 1)
    {
        iY = 1;
        szSteam[16] = NumberToChar(CharToNumber(szSteam[16]) - 1);
    }
    
    for(int k = 16; k >= 0; k--)
    {
        if(iBorrow > 0)
        {
            iTemp = CharToNumber(szSteam[k]) - 1;
            
            if(iTemp >= CharToNumber(szBase[k]))
            {
                iBorrow = 0;
                szAccount[k] = NumberToChar(iTemp - CharToNumber(szBase[k]));
            }
            else
            {
                iBorrow = 1;
                szAccount[k] = NumberToChar((iTemp + 10) - CharToNumber(szBase[k]));
            }
        }
        else
        {
            if(CharToNumber(szSteam[k]) >= CharToNumber(szBase[k]))
            {
                iBorrow = 0;
                szAccount[k] = NumberToChar(CharToNumber(szSteam[k]) - CharToNumber(szBase[k]));
            }
            else
            {
                iBorrow = 1;
                szAccount[k] = NumberToChar((CharToNumber(szSteam[k]) + 10) - CharToNumber(szBase[k]));
            }
        }
    }
    
    iZ = StringToInt(szAccount);
    iZ /= 2;
    
    FormatEx(steamid, iLen, "STEAM_1:%d:%d", iY, iZ);
}

stock int NumberToChar(const int iNum)
{
    return '0' + ((iNum >= 0 && iNum <= 9) ? iNum : 0);
}

stock int CharToNumber(const int cNum)
{
    return (cNum >= '0' && cNum <= '9') ? (cNum - '0') : 0;
}