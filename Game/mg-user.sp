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
/*  2018/01/05 07:29:07                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <MagicGirl.NET>
#include <MagicGirl/user>

#define PI_NAME THIS_PRETAG ... " - User Manager"
#define PI_DESC "User Manager for MagicGirl.NET"

public Plugin myinfo = 
{
    name        = PI_NAME,
    author      = PI_AUTH,
    description = PI_DESC,
    version     = PI_VERS,
    url         = PI_URLS
};

int  g_iUserId[MAXPLAYERS+1];
bool g_authClient[MAXPLAYERS+1][Authentication];
bool g_bAuthLoaded[MAXPLAYERS+1];
bool g_bBanChecked[MAXPLAYERS+1];
bool g_bAuthLoading[MAXPLAYERS+1];
bool g_bBansLoading[MAXPLAYERS+1];
char g_szUsername[MAXPLAYERS+1][32];

Handle g_hOnUMAuthChecked;
Handle g_hOnUMDataChecked;

static char g_banType[3][32] = {"全服封禁", "当前模式封禁", "当前服务器封禁"};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    // Auth
    CreateNative("MG_Users_IsAuthorized", Native_IsAuthorized);

    // Identity
    CreateNative("MG_Users_UserIdentity", Native_UserIdentity);

    // Banning
    CreateNative("MG_Users_BanClient",    Native_BanClient);
    CreateNative("MG_Users_BanIdentity",  Native_BanIdentity);

    // lib
    RegPluginLibrary("mg-user");

    return APLRes_Success;
}

public int Native_IsAuthorized(Handle plugin, int numParams)
{
    return g_authClient[GetNativeCell(1)][GetNativeCell(2)];
}

public int Native_UserIdentity(Handle plugin, int numParams)
{
    return g_iUserId[GetNativeCell(1)];
}

public int Native_BanClient(Handle plugin, int numParams)
{
    int admin  = GetNativeCell(1);
    int target = GetNativeCell(2);
    int btype  = GetNativeCell(3);
    int length = GetNativeCell(4);
    char reason[128];
    GetNativeString(5, reason, 128);

    if(MG_Core_GetServerId() < 0)
        return;

    if(!MG_MySQL_IsConnected())
        return;

    Database db = MG_MySQL_GetDatabase();

    char ip[24];
    GetClientIP(target, ip, 24, false);
    
    char name[64], nickname[128];
    GetClientName(target, name, 64);
    db.Escape(name, nickname, 128);
    
    char adminName[64];
    db.Escape(g_szUsername[admin], adminName, 64);

    char bReason[256];
    db.Escape(reason, bReason, 256);
    
    char steamid[32];
    if(!GetClientAuthId(target, AuthId_SteamID64, steamid, 32, true))
    {
        MG_Core_LogError("User", "Native_BanClient", "We can not fetch target`s steamid64 -> \"%L\"", target);
        return;
    }

    char m_szQuery[1024];
    FormatEx(m_szQuery, 1024, "INSERT INTO dxg_bans VALUES (DEFAULT, '%s', '%s', '%s', %d, %d, %d, %d, %d, %d, '%s', '%s', -1);", steamid, ip, nickname, GetTime()+length*60, btype, MG_Core_GetServerId(), MG_Core_GetServerModId(), g_iUserId[admin], g_szUsername[admin], bReason);
    
    DataPack pack = new DataPack();
    pack.WriteCell(admin);
    pack.WriteCell(GetClientUserId(target));
    pack.WriteCell(btype);
    pack.WriteCell(length);
    pack.WriteString(reason);
    pack.WriteString(m_szQuery);

    db.Query(BanClientCallback, m_szQuery, pack);
}

public int Native_BanIdentity(Handle plugin, int numParams)
{
    int admin = GetNativeCell(1);
    
    char steamIdentity[32];
    GetNativeString(2, steamIdentity, 32);

    int btype  = GetNativeCell(3);
    int length = GetNativeCell(4);
    char reason[128];
    GetNativeString(5, reason, 128);

    if(MG_Core_GetServerId() < 0)
        return;

    // we using php auto-check target`s steam nickname.
    char ip[32], targetName[64];
    int target = FindClientByIdentity(steamIdentity);
    if(target != -1)
    {
        GetClientIP(target, ip, 32);

        char _name[32];
        GetClientName(target, _name, 32);
        MG_MySQL_GetDatabase().Escape(_name, targetName, 64);
        
        PrintToChatAll(" \07*** \x02BAN \07***  \x05%s\x04已被伺服器封锁!", _name);
    }
    else
    {
        strcopy(ip,         32, "127.0.0.1");
        strcopy(targetName, 64, "php_auto_check");
        
        PrintToChatAll(" \07*** \x02BAN \07***  \x05%s\x04已被伺服器封锁!", steamIdentity);
    }

    char adminName[64];
    MG_MySQL_GetDatabase().Escape(g_szUsername[admin], adminName, 64);

    char bReason[256];
    MG_MySQL_GetDatabase().Escape(reason, bReason, 256);

    char m_szQuery[1024];
    FormatEx(m_szQuery, 1024, "INSERT INTO dxg_bans VALUES (DEFAULT, '%s', '%s', '%s', %d, %d, %d, %d, %d, %d, '%s', '%s', -1);", steamIdentity, ip, targetName, GetTime()+length*60, btype, MG_Core_GetServerId(), MG_Core_GetServerModId(), g_iUserId[admin], g_szUsername[admin], bReason);

    MG_MySQL_SaveDatabase(m_szQuery);
}

public void OnPluginStart()
{
    // global forwards
    g_hOnUMAuthChecked = CreateGlobalForward("OnClientAuthChecked", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOnUMDataChecked = CreateGlobalForward("OnClientDataChecked", ET_Ignore, Param_Cell, Param_Cell);

    // init console
    g_iUserId[0] = 0;
    g_szUsername[0] = "CONSOLE";
}

public void OnClientConnected(int client)
{
    for(int i = 0; i < view_as<int>(Authentication); ++i)
        g_authClient[client][i] = false;

    g_bAuthLoading[client] = false;
    g_bBansLoading[client] = false;
    
    g_bAuthLoaded[client] = false;
    g_bBanChecked[client] = false;
    g_szUsername[client][0] = '\0';

    g_iUserId[client] = 0;
}

// we call this forward after client is fully in-game.
// this forward -> tell other plugins, we are available, allow to load client`s data.
public void OnClientPutInServer(int client)
{
    if(IsFakeClient(client) || IsClientSourceTV(client))
    {
        CallDataForward(client);
        return;
    }

    if(!g_bAuthLoaded[client] || g_iUserId[client] <= 0)
    {
        CreateTimer(1.0, Timer_Waiting, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    CallDataForward(client);
}

public Action Timer_Waiting(Handle timer, int client)
{
    if(!IsClientInGame(client))
        return Plugin_Stop;
    
    OnClientPutInServer(client);

    return Plugin_Stop;
}

public void OnRebuildAdminCache(AdminCachePart part)
{
    char steamid[32];
    if(part == AdminCache_Admins)
        for(int client = 1; client <= MaxClients; ++client)
            if(IsClientAuthorized(client))
                if(GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
                    LoadClientAuth(client, steamid);
}

public void OnClientAuthorized(int client, const char[] auth)
{
    if(strcmp(auth, "BOT") == 0 || IsFakeClient(client) || IsClientSourceTV(client))
    {
        CallAuthForward(client);
        return;
    }

    char steamid[32];
    GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true);

    LoadClientAuth(client, steamid);
    CheckClientBanStats(client, steamid);
}

void LoadClientAuth(int client, const char[] steamid)
{
    if(!MG_MySQL_IsConnected())
    {
        MG_Core_LogError("User", "LoadClientAuth", "Error: SQL is unavailable -> \"%L\"", client);
        CreateTimer(1.0, Timer_ReloadAuth, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "SELECT uid, username, imm, grp, spt, vip, ctb, opt, adm, own FROM dxg_users WHERE steamid = '%s'", steamid);
    MG_MySQL_GetDatabase().Query(LoadClientCallback, m_szQuery, GetClientUserId(client));
}

public Action Timer_ReloadAuth(Handle timer, int client)
{
    if(!IsClientConnected(client))
        return Plugin_Stop;

    char steamid[32];
    GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true);
    LoadClientAuth(client, steamid);
    
    return Plugin_Stop;
}

void CheckClientBanStats(int client, const char[] steamid)
{
    if(!MG_MySQL_IsConnected())
    {
        MG_Core_LogError("User", "LoadClientAuth", "Error: SQL is unavailable -> \"%L\"", client);
        CreateTimer(1.0, Timer_ReloadBans, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "SELECT bType, bSrv, bSrvMod, bCreated, bLength, bReason, id FROM dxg_bans WHERE steamid = '%s' AND bRemovedBy = -1", steamid);
    MG_MySQL_GetDatabase().Query(CheckBanCallback, m_szQuery, GetClientUserId(client));
}

public Action Timer_ReloadBans(Handle timer, int client)
{
    if(!IsClientConnected(client))
        return Plugin_Stop;

    char steamid[32];
    GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true);
    CheckClientBanStats(client, steamid);

    return Plugin_Stop;
}

public void LoadClientCallback(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!client)
        return;

    if(results == null || error[0])
    {
        MG_Core_LogError("User", "LoadClientCallback", "SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(1.0, Timer_ReloadAuth, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    if(results.RowCount <= 0 || !results.FetchRow())
    {
        InsertNewUserData(client);
        return;
    }

    g_bAuthLoading[client] = false;
    g_bAuthLoaded[client]  = true;

    g_iUserId[client] = results.FetchInt(0);
    results.FetchString(1, g_szUsername[client], 32);
    g_authClient[client][Spt] = (results.FetchInt(4) == 1);
    g_authClient[client][Vip] = (results.FetchInt(5) == 1);
    g_authClient[client][Ctb] = (results.FetchInt(6) == 1);
    g_authClient[client][Opt] = (results.FetchInt(7) == 1);
    g_authClient[client][Adm] = (results.FetchInt(8) == 1);
    g_authClient[client][Own] = (results.FetchInt(9) == 1);
    
    int mod = results.FetchInt(3);
    if(mod == 0 || mod == MG_Core_GetServerModId())
    {
        if(g_authClient[client][Ctb] || g_authClient[client][Opt] || g_authClient[client][Adm] || g_authClient[client][Own])
        {
            AdminId _admin = GetUserAdmin(client);
            if(_admin != INVALID_ADMIN_ID)
            {
                RemoveAdmin(_admin);
                SetUserAdmin(client, INVALID_ADMIN_ID);
            }

            _admin = CreateAdmin(g_szUsername[client]);
            SetUserAdmin(client, _admin, true);
            SetAdminImmunityLevel(_admin, results.FetchInt(2));

            _admin.SetFlag(Admin_Reservation, true);
            _admin.SetFlag(Admin_Generic, true);
            _admin.SetFlag(Admin_Kick, true);
            _admin.SetFlag(Admin_Slay, true);
            _admin.SetFlag(Admin_Chat, true);
            _admin.SetFlag(Admin_Vote, true);
            _admin.SetFlag(Admin_Changemap, true);

            if(g_authClient[client][Opt] || g_authClient[client][Adm] || g_authClient[client][Own])
            {
                _admin.SetFlag(Admin_Ban, true);
                _admin.SetFlag(Admin_Unban, true);

                if(g_authClient[client][Adm] || g_authClient[client][Own])
                {
                    _admin.SetFlag(Admin_Convars, true);
                    _admin.SetFlag(Admin_Config, true);

                    if(g_authClient[client][Own])
                    {
                        _admin.SetFlag(Admin_Password, true);
                        _admin.SetFlag(Admin_Cheats, true);
                        _admin.SetFlag(Admin_RCON, true);
                        _admin.SetFlag(Admin_Root, true);
                    }
                }
            }

            // we give admin perm before client admin check
            if(IsClientInGame(client))
                RunAdminCacheChecks(client);
        }
    }
    
    CallAuthForward(client);
}

void InsertNewUserData(int client)
{
    char steamid[32], m_szQuery[128];
    GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true);
    FormatEx(m_szQuery, 128, "INSERT INTO dxg_users (`steamid`, `firstjoin`) VALUES ('%s', %d);", steamid, GetTime());
    MG_MySQL_GetDatabase().Query(InserUserCallback, m_szQuery, GetClientUserId(client));
}

public void InserUserCallback(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!client)
        return;

    // Refresh client
    CreateTimer(1.0, Timer_ReloadAuth, client, TIMER_FLAG_NO_MAPCHANGE);

    if(results == null || error[0])
        MG_Core_LogError("User", "InserUserCallback", "SQL Error:  %s -> \"%L\"", error, client);
}

public void CheckBanCallback(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!client)
        return;

    if(results == null || error[0])
    {
        MG_Core_LogError("User", "CheckBanCallback", "SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(1.0, Timer_ReloadBans, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    if(results.RowCount <= 0)
        return;

    while(results.FetchRow())
    {
        //bType, bSrv, bSrvMod, bCreated, bLength, bReason, id

        char bReason[32];
        int bType    = results.FetchInt(0);
        int bSrv     = results.FetchInt(1);
        int bSrvMod  = results.FetchInt(2);
        int bCreated = results.FetchInt(3);
        int bLength  = results.FetchInt(4);
        results.FetchString(5, bReason, 32);

        /* process results */
        
        // if srv ban and current server id != ban server id
        if(bType == 2 && MG_Core_GetServerId() != bSrv)
            continue;
        
        // if mod ban and current server mod != ban mod id
        if(bType == 1 && MG_Core_GetServerModId() != bSrvMod)
            continue;
        
        char ip[32];
        GetClientIP(client, ip, 32);
        
        char m_szQuery[256];
        FormatEx(m_szQuery, 256, "INSERT INTO dxg_blocks VALUES (DEFAULT, %d, '%s', %d)", results.FetchInt(6), ip, GetTime());
        MG_MySQL_SaveDatabase(m_szQuery);

        char timeExpired[64];
        if(bLength != 0)
            FormatTime(timeExpired, 64, "%Y.%m.%d %H:%M:%S", bCreated+bLength);
        else
            FormatEx(timeExpired, 64, "永久封禁");

        char kickReason[256];
        FormatEx(kickReason, 256, "您已被服务器封锁,禁止进入游戏!\n类型: %s\n原因: %s\n到期: %s\n访问https://ban.magicgirl.net/查看详细信息", g_banType[bType], bReason, timeExpired);
        //KickClient(client, kickReason);
        BanClient(client, 5, BANFLAG_AUTHID, kickReason, kickReason);

        break;
    }
}

public void BanClientCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    int admin  = pack.ReadCell();
    int target = pack.ReadCell(); target = GetClientOfUserId(target);
    int btype  = pack.ReadCell();
    int length = pack.ReadCell();
    char reason[128];
    pack.ReadString(reason, 128);
    char query[1024];
    pack.ReadString(query, 1024);
    delete pack;

    if(results == null || error[0])
    {
        MG_Core_LogError("User", "BanClientCallback", "SQL Error:  %s -> \n%s", error, query);
        return;
    }

    if(!target || !IsClientConnected(target))
        return;
    
    char adminName[32];
    if(IsClientInGame(admin))
        GetClientName(admin, adminName, 32);
    else
        strcopy(adminName, 32, g_szUsername[admin]);

    PrintToChatAll(" \07*** \x02BAN \07***  \x05%N\01已被管理员\x04%s\x01封锁,原因: \x0A%s", target, adminName, reason);
    
    char timeExpired[64];
    if(length != 0)
        FormatTime(timeExpired, 64, "%Y.%m.%d %H:%M:%S", GetTime()+length*60);
    else
        FormatEx(timeExpired, 64, "永久封禁");

    char kickReason[256];
    FormatEx(kickReason, 256, "您已被服务器封锁,禁止进入游戏!\n类型: %s\n原因: %s\n到期: %s\n访问https://ban.magicgirl.net/查看详细信息", g_banType[btype], reason, timeExpired);
    BanClient(target, 5, BANFLAG_AUTHID, kickReason, kickReason);
}

void CallAuthForward(int client)
{
    Call_StartForward(g_hOnUMAuthChecked);
    Call_PushCell(client);
    for(int i = 0; i < view_as<int>(Authentication); ++i)
        Call_PushCell(g_authClient[client][i]);
    Call_Finish();
}

void CallDataForward(int client)
{
    Call_StartForward(g_hOnUMDataChecked);
    Call_PushCell(client);
    Call_PushCell(g_iUserId[client]);
    Call_Finish();
}

int FindClientByIdentity(const char[] steamid)
{
    char auth[32];
    for(int client = 1; client <= MaxClients; ++ client)
        if(IsClientAuthorized(client))
            if(GetClientAuthId(client, AuthId_SteamID64, auth, 32, true))
                if(strcmp(steamid, auth) == 0)
                    return client;
                
    return -1;
}