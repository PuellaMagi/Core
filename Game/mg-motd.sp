/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET Motd Extended                   */
/*                                                                */
/*                                                                */
/*  File:          mg-motd.sp                                     */
/*  Description:   Interconnector of Game and Forum.              */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  MagicGirl.NET Dev Team                    */
/*  2017/01/23 18:54:45                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <MagicGirl.NET>
#include <MagicGirl/user>

#include <clientprefs>

#define PI_NAME THIS_PRETAG ... " - Motd"
#define PI_DESC "MOTD Extended for MagicGirl.NET"

public Plugin myinfo = 
{
    name        = PI_NAME,
    author      = PI_AUTH,
    description = PI_DESC,
    version     = PI_VERS,
    url         = PI_URLS
};

int g_Resolution[MAXPLAYERS+1][2];
Handle g_cRqesolution;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("MG_Motd_ShowNormalMotd", Native_ShowNormalMotd);
    CreateNative("MG_Motd_ShowHiddenMotd", Native_ShowHiddenMotd);
    CreateNative("MG_Motd_RemoveMotd",     Native_RemoveMotd);
    
    RegPluginLibrary("mg-motd");

    return APLRes_Success;
}

public int Native_ShowNormalMotd(Handle plugin, int numParams)
{
    // db is unavailable
    if(!MG_MySQL_IsConnected())
        return false;
    
    int client = GetNativeCell(1);

    if(!IsValidClient(client))
        return false;
    
    char m_szUrl[192];
    if(GetNativeString(2, m_szUrl, 192) != SP_ERROR_NONE)
        return false;
    
    // checking resolution
    if(g_Resolution[client][0] == 0 || g_Resolution[client][1] == 0)
    {
        BuildSetupResolutionMenu(client, m_szUrl);
        return true;
    }

    // fix for fullscreen.
    int width = g_Resolution[client][0]-12;
    int height = g_Resolution[client][1]-80;

    return UrlToWebInterface(client, width, height, m_szUrl, true);
}

public int Native_ShowHiddenMotd(Handle plugin, int numParams)
{
    // db is unavailable
    if(!MG_MySQL_IsConnected())
        return false;
    
    int client = GetNativeCell(1);

    if(!IsValidClient(client))
        return false;

    char m_szUrl[192];
    if(GetNativeString(2, m_szUrl, 192) != SP_ERROR_NONE)
        return false;

    return UrlToWebInterface(client, 0, 0, m_szUrl, false);
}

public int Native_RemoveMotd(Handle plugin, int numParams)
{
    // db is unavailable
    if(!MG_MySQL_IsConnected())
        return;

    int client = GetNativeCell(1);

    if(!IsValidClient(client))
        return;

    UrlToWebInterface(client, 0, 0, "https://ump45.moe/aboutblank", false);
}

bool UrlToWebInterface(int client, int width, int height, const char[] url, bool show)
{
    if(MG_Users_UserIdentity(client) < 1)
        return false;

    char m_szQuery[512], m_szEscape[256];
    MG_MySQL_GetDatabase().Escape(url, m_szEscape, 256);
    FormatEx(m_szQuery, 512, "INSERT INTO `dxg_motd` (`uid`, `show`, `width`, `height`, `url`) VALUES (%d, %b, %d, %d, '%s') ON DUPLICATE KEY UPDATE `url` = VALUES(`url`), `show`=%b, `width`=%d, `height`=%d", MG_Users_UserIdentity(client), show, width, height, m_szEscape, show, width, height);
    MG_MySQL_GetDatabase().Query(SQLCallback_WebInterface, m_szQuery, client | (view_as<int>(show) << 7), DBPrio_High);

    return true;
}

public void SQLCallback_WebInterface(Database db, DBResultSet results, const char[] error, int data)
{
    int client = data & 0x7f;
    bool show = (data >> 7) == 1;

    if(!IsValidClient(client))
        return;

    if(results == null ||  error[0])
        return;

    ShowMOTDPanelEx(client, show);
}

void ShowMOTDPanelEx(int client, bool show = true)
{
    char url[192];
    FormatEx(url, 192, "https://magicgirl.net/motd.php?uid=%d", MG_Users_UserIdentity(client));

    Handle m_hKv = CreateKeyValues("data");
    KvSetString(m_hKv, "title", "叁生鉐");
    KvSetNum(m_hKv, "type", MOTDPANEL_TYPE_URL);
    KvSetString(m_hKv, "msg", url);
    KvSetNum(m_hKv, "cmd", 0);
    ShowVGUIPanel(client, "info", m_hKv, show);
    CloseHandle(m_hKv);
}

void BuildSetupResolutionMenu(int client, const char[] url)
{
    Menu menu = CreateMenu(MenuHandler_RP);
    menu.SetTitle("选择你的游戏分辨率\n如果没有则选择接近数值(向下取值)\n分辨率过大将无法正常关闭窗口\n ");

    menu.AddItem("1920*1080", "1920*1080");
    menu.AddItem("1280*1024", "1280*1024");
    menu.AddItem("1600*900", "1600*900");
    menu.AddItem("1366*768", "1366*768");
    menu.AddItem("1280*720", "1280*720");
    menu.AddItem("1280*960", "1280*960");
    menu.AddItem(url, url, ITEMDRAW_IGNORE);

    menu.ExitButton = false;
    menu.Display(client, 0);
}

public int MenuHandler_RP(Menu menu, MenuAction action, int client, int itemNum) 
{
    if(action == MenuAction_Select) 
    {
        char info[32];
        menu.GetItem(itemNum, info, 32);
        
        char url[192];
        menu.GetItem(6, url, 192);

        char m_szData[2][16];
        ExplodeString(info, "*", m_szData, 2, 16);
        g_Resolution[client][0] = StringToInt(m_szData[0]);
        g_Resolution[client][1] = StringToInt(m_szData[1]);

        SetClientCookie(client, g_cRqesolution, info);

        PrintToChat(client, "***\x04MOTD\x01***   你的设置已保存分辨率[\x04%s\x01]", info);

        if(strlen(url) > 5)
            UrlToWebInterface(client, g_Resolution[client][0]-12, g_Resolution[client][1]-80, url, true);
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }
    else if(action == MenuAction_Cancel && itemNum == MenuCancel_Interrupted)
    {
        char url[192];
        menu.GetItem(6, url, 192);
        BuildSetupResolutionMenu(client, url);
    }
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_setrp", Command_SetRP);
    g_cRqesolution = RegClientCookie("motd_extended_rp", "resolution of motd window", CookieAccess_Protected);
}

public void OnClientCookiesCached(int client)
{
    g_Resolution[client][0] = 0;
    g_Resolution[client][1] = 0;
    
    char buffer[16];
    GetClientCookie(client, g_cRqesolution, buffer, 16);
    if(strlen(buffer) > 0)
    {
        char m_szData[2][16];
        ExplodeString(buffer, "*", m_szData, 2, 16);
        g_Resolution[client][0] = StringToInt(m_szData[0]);
        g_Resolution[client][1] = StringToInt(m_szData[1]);
    }
}

public Action Command_SetRP(int client, int args)
{
    if(!IsValidClient(client))
        return Plugin_Handled;
    
    BuildSetupResolutionMenu(client, "");
    
    return Plugin_Handled;
}

bool IsValidClient(int client)
{
    return (1 <= client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client));
}