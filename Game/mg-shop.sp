/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET Shop System                     */
/*                                                                */
/*                                                                */
/*  File:          mg-shop.sp                                     */
/*  Description:   Interconnector of Game and Forum.              */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  MagicGirl.NET Dev Team                    */
/*  2017/01/22 17:17:52                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/

#pragma semicolon 1
#pragma newdecls required

#define PI_NAME THIS_PRETAG ... " - Shop"
#define PI_AUTH THIS_AUTHOR
#define PI_DESC "In-game Shop for MagicGirl.NET"
#define PI_VERS Core_Version ... " " ... APIs_Version ... " " ... "<commit-count>"
#define PI_URLS THIS_URLINK

public Plugin myinfo = 
{
    name        = PI_NAME,
    author      = PI_AUTH,
    description = PI_DESC,
    version     = PI_VERS,
    url         = PI_URLS
};


enum Item_Categories //Category
{
    String:szType[32],
    bool:bEquipable,
    Handle:hPlugin,
    Function:fnOnUse,
    Function:fnOnRemove,
    Function:fnOnLoad,
    Function:fnMenuInventory,
    Function:fnMenuPreview
}

enum Item_Data
{
    iPrice[4],
    iParent,
    iTypeIndex,
    iLevel,
    bool:bBuyable,
    bool:bGiftable,
    bool:bVipItem,
    String:szFullName[128],
    String:szShrotName[32],
    String:szUniqueId[32],
    String:szDescription[128],
    String:szPersonalId[128]
}

enum Client_Item
{
    iItemIndex,
    iDbIndex,
    iCost,
    iDateOfPurchase,
    iDateOfExpiration
}

enum Client_Data
{
    iUid,
    iMoney,
    iItems,
    bool:bLoaded
}

any g_ClientData[MAXPLAYERS+1][Client_Data];
any g_ClientItem[MAXPLAYERS+1][Client_Item]
any g_ItemsData[MAX_ITEMS][Item_Data];
any g_ItemCategory[MAX_ITEM_CATEGORY][Item_Categories];

int g_iItemCategories;

Database g_MySQL;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if(late)
    {
        strcopy(error, err_max, "Late load this plugin is not allowed.");
        return APLRes_Failure;
    }

    //global
    CreateNative("MG_Shop_RegItemCategory",             Native_RegItemCategory);
    CreateNative("MG_Shop_GetItemIndex",                Native_GetItemIndex);

    //client
    CreateNative("MG_Shop_ClientHasItem",               Native_ClientHasItem);
    CreateNative("MG_Shop_ClientGetDateofExpiration",   Native_GetDateofExpiration);
    CreateNative("MG_Shop_ClientGetDateofPurchase",     Native_GetDateofPurchase);
    CreateNative("MG_Shop_ClientGetCostofPurchase",     Native_GetCostofPurchase);


    RegPluginLibrary("mg-stop");

    return APLRes_Success;
}

public int Native_RegItemCategory(Handle plugin, int numParams)
{
    char m_szType[32];
    if(GetNativeString(1, m_szType, 32) != SP_ERROR_NONE)
        return false;
    
    int index = UTIL_FindCategoryByType(m_szType);
    
    if(index != -1)
        return true;
    
    index = g_iItemCategories;
    
    g_ItemCategory[index][szType] = m_szType;
    g_ItemCategory[index][bEquipable] = GetNativeCell(2);
    g_ItemCategory[index][hPlugin] = plugin;
    g_ItemCategory[index][fnOnLoad] = GetNativeFunction(3);
    g_ItemCategory[index][fnOnUse] = GetNativeFunction(4);
    g_ItemCategory[index][fnOnRemove] = GetNativeFunction(5);
    g_ItemCategory[index][fnMenuInventory] = GetNativeFunction(6);
    g_ItemCategory[index][fnMenuPreview] = GetNativeFunction(7);

    g_iItemCategories++;
    
    return true;
}

public void OnPluginStart()
{
    ConnectAndLoad();
}

public void ConnectAndLoad()
{
    char error[256];
    g_MySQL = SQL_Connect("csgo", false, error, 256);
    if(g_MySQL == null)
        SetFailState("Connect to database Error.");

    g_MySQL.SetCharset("utf8");

    //delete old item 
    SQL_FastQuery(g_MySQL, "DELETE FROM dxg_inventory WHERE date_of_expiration < UNIX_TIMESTAMP()", 128);

    char m_szQuery[256];
    //load parent

}

public void OnClientConnected(int client)
{
    g_ClientData[client][bLoaded] = false;

    g_ClientData[client][iMoney] = 0;
    g_ClientData[client][iItems] = 0;
}

public void OnClientPostAdminCheck(int client)
{
    if(IsFakeClient(client))
        return;

    char steamid[32];
    if(!GetClientAuthId(target, AuthId_SteamID64, steamid, 32, true))
    {
        KickClient(client, "系统无法获取您的SteamID");
        return;
    }

    char m_szQuery[64];
    FormatEx(m_szQuery, 64, "SELECT uid,money FROM dxg_users WHERE uid = '%s'", steamid);
    g_MySQL.Query(LoadClientCallback, m_szQuery, GetClientUserId(client));
}

public Action Timer_ReAuthorize(Handle timer, int client)
{
    if(!IsClientInGame(client) || g_ClientData[client][bLoaded])
        return Plugin_Stop;

    OnClientConnected(client);
    OnClientPostAdminCheck(client);

    return Plugin_Stop;
}

public void LoadClientCallback(Database db, DBResultSet results, const char[] error, int uid)
{
    int client = GetClientOfUserId(uid);
    if(!client)
        return;

    if(results == null || error[0])
    {
        MG_Core_LogError("Shop", "LoadClientCallback", "SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(5.0, Timer_ReAuthorize, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }


    if(results.RowCount <= 0 || results.FetchRow())
    {
        KickClient(client, "系统无法获取您的数据");
        return;
    }

    g_ClientData[client][bLoaded] = true;
    g_ClientData[client][iUid]    = result.FetchInt(0);
    g_ClientData[client][iMoney]  = result.FetchInt(1);

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "SELECT * FROM dxg_inventory WHERE uid = %d AND date_of_expiration > %d", g_ClientData[client][iUid], GetTime());
    g_MySQL.Query(LoadInventoryCallback, m_szQuery, uid);
}

public void LoadInventoryCallback(Database db, DBResultSet results, const char[] error, int uid)
{
    int client = GetClientOfUserId(uid);
    if(!client)
        return;

    if(results == null || error[0])
    {
        MG_Core_LogError("Shop", "LoadClientCallback", "SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(5.0, Timer_ReAuthorize, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }


    if(results.RowCount <= 0)
        return;

    while(results.FetchRow())
    {
        
    }
}