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

#define PI_NAME "MagicGirl.NET - Shop"
#define PI_AUTH "MagicGirl.NET Dev Team"
#define PI_DESC "In-game Shop for MagicGirl.NET"
#define PI_VERS "<commit-count>"
#define PI_URLS "https://MagicGirl.net"

#define MAX_ITEMS 512
#define MAX_ITEM_CATEGORY 32

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
    bool:bVip,
    bool:bLoaded
}

any g_ClientData[MAXPLAYERS+1][Client_Data];
any g_ClientItem[MAXPLAYERS+1][MAX_ITEMS][Client_Item];
any g_Items[MAX_ITEMS][Item_Data];
any g_Category[MAX_ITEM_CATEGORY][Item_Categories];

int g_iItems;
int g_iCategories;
int g_iFakeCategory;

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
    CreateNative("MG_Shop_HasClientItem",               Native_HasClientItem);
    CreateNative("MG_Shop_ClientGetDateofExpiration",   Native_GetDateofExpiration);
    CreateNative("MG_Shop_ClientGetDateofPurchase",     Native_GetDateofPurchase);
    CreateNative("MG_Shop_ClientGetCostofPurchase",     Native_GetCostofPurchase);
    
    CreateNative("MG_Shop_GetClientMoney",              Native_GetClientMoney);
    CreateNative("MG_Shop_ClientEarnMoney",             Native_ClientEarnMoney);
    CreateNative("MG_Shop_ClientCostMoney",             Native_ClientCostMoney);
    
    CreateNative("MG_Shop_ClientBuyItem",               Native_ClientBuyItem);
    CreateNative("MG_Shop_ClientSellItem",              Native_ClientSellItem);
    CreateNative("MG_Shop_ClientGiftItem",              Native_ClientGiftItem);

    //menu
    


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
    
    index = g_iCategories;
    
    strcopy(g_Category[index][szType], 32, m_szType);
    g_Category[index][bEquipable] = GetNativeCell(2);
    g_Category[index][hPlugin] = plugin;
    g_Category[index][fnOnLoad] = GetNativeFunction(3);
    g_Category[index][fnOnUse] = GetNativeFunction(4);
    g_Category[index][fnOnRemove] = GetNativeFunction(5);
    g_Category[index][fnMenuInventory] = GetNativeFunction(6);
    g_Category[index][fnMenuPreview] = GetNativeFunction(7);

    g_iCategories++;
    
    return true;
}

public int Native_GetItemIndex(Handle plugin, int numParams)
{
    char m_szUniqueId[32];
    if(GetNativeString(1, m_szUniqueId, 32) != SP_ERROR_NONE)
        return -1;
    
    return UTIL_FindItemByUniqueId(m_szUniqueId);
}

public int Native_HasClientItem(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if(!IsClientInGame(client))
        return false;
    
    char m_szUniqueId[32];
    if(GetNativeString(2, m_szUniqueId, 32) != SP_ERROR_NONE)
        return false;
    
    return UTIL_HasClientItem(client, m_szUniqueId);
}

public int Native_GetDateofExpiration(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char m_szUniqueId[32];
    if(GetNativeString(2, m_szUniqueId, 32) != SP_ERROR_NONE)
        return -1;
    
    int itemid = UTIL_FindItemByUniqueId(m_szUniqueId);
    
    if(itemid == -1)
        return -1;
    
    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(g_ClientItem[client][i][iItemIndex] == itemid)
            return g_ClientItem[client][i][iDateOfExpiration];
    
    return -1;
}

public int Native_GetDateofPurchase(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char m_szUniqueId[32];
    if(GetNativeString(2, m_szUniqueId, 32) != SP_ERROR_NONE)
        return -1;
    
    int itemid = UTIL_FindItemByUniqueId(m_szUniqueId);
    
    if(itemid == -1)
        return -1;
    
    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(g_ClientItem[client][i][iItemIndex] == itemid)
            return g_ClientItem[client][i][iDateOfPurchase];

    return -1;
}

public int Native_GetCostofPurchase(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char m_szUniqueId[32];
    if(GetNativeString(2, m_szUniqueId, 32) != SP_ERROR_NONE)
        return -1;
    
    int itemid = UTIL_FindItemByUniqueId(m_szUniqueId);
    
    if(itemid == -1)
        return -1;
    
    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(g_ClientItem[client][i][iItemIndex] == itemid)
            return g_ClientItem[client][i][iCost];

    return -1;
}

public int Native_GetClientMoney(Handle plugin, int numParams)
{
    return g_ClientData[GetNativeCell(1)][iMoney];
}

public int Native_ClientEarnMoney(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if(!g_ClientData[client][bLoaded])
        return false;
    
    char reason[128];
    if(GetNativeString(3, reason, 128) != SP_ERROR_NONE)
        return false;
    
    return UTIL_EarnMoney(client, GetNativeCell(2), reason);
}

public int Native_ClientCostMoney(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if(!g_ClientData[client][bLoaded])
        return false;
    
    int cost = GetNativeCell(2);
    if(cost > g_ClientData[client][iMoney])
        return false;
    
    char reason[128];
    if(GetNativeString(3, reason, 128) != SP_ERROR_NONE)
        return false;

    return UTIL_CostMoney(client, GetNativeCell(2), reason);
}

public int Native_ClientBuyItem(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if(!g_ClientData[client][bLoaded])
        return;
    
    int cost = GetNativeCell(2);
    if(cost > g_ClientData[client][iMoney])
        return;

    char unique[32];
    if(GetNativeString(3, unique, 32) != SP_ERROR_NONE)
        return;

    int itemid = UTIL_FindItemByUniqueId(unique);
    if(itemid == -1)
        return;

    int length = UTIL_GetLengthByPrice(itemid, cost);
    if(length == -1)
        return;

    Function callback = GetNativeFunction(4);
    
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(cost);
    pack.WriteString(unique);
    pack.WriteCell(itemid);
    pack.WriteCell(length);
    pack.WriteCell(plugin);
    pack.WriteFunction(callback);
    pack.Reset();
    
    char m_szQuery[512], reason[128];
    FormatEx(reason, 128, "购买了 %s.%s", g_Category[g_Items[itemid][iTypeIndex]][szType], g_Items[itemid][szShrotName]);
    FormatEx(m_szQuery, 512,   "UPDATE dxg_users SET money-%d WHERE uid=%d; \
                                INSERT INTO dxg_inventory VALUES (DEFAULT, %d, '%s', %d, %d, %d); \
                                INSERT INTO dxg_banklog VALUES (DEFAULT, %d, %d, '%s', %d); ", 
                                cost, g_ClientData[client][iUid], g_ClientData[client][iUid], unique, cost, GetTime(), length != 0 ? GetTime()+length : 0, g_ClientData[client][iUid], -cost, reason, GetTime());
    g_MySQL.Query(BuyItemCallback, m_szQuery, pack, DBPrio_High);
}

public void BuyItemCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    int client = GetClientOfUserId(pack.ReadCell());
    int cost   = pack.ReadCell();
    char unique[32];
    pack.ReadString(unique, 32);
    int itemid = pack.ReadCell();
    int length = pack.ReadCell();
    Handle plugin = pack.ReadCell();
    Function callback = pack.ReadFunction();
    delete pack;
    
    if(results == null || error[0])
    {
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "BuyItemCallback -> SQL Error:  %s -> %N -> %d -> %s -> %d -> %d", error, client, cost, unique, length, itemid);
        return;
    }
    
    if(!client)
        return;
    
    if(results.AffectedRows != 3)
    {
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "BuyItemCallback -> AffectedRows: %d -> %N -> %d -> %s -> %d -> %d", results.AffectedRows, client, cost, unique, length, itemid);
        return;
    }
    
    if(callback != INVALID_FUNCTION)
    {
        Call_StartFunction(plugin, callback);
        Call_PushCell(client);
        Call_PushCell(cost);
        Call_PushString(unique);
        Call_Finish();
    }
}

public void OnPluginStart()
{
    // databse ann item.
    ConnectAndLoad();
    
    // fake category
    g_iFakeCategory = MG_Shop_RegItemCategory("fakeCategory", false, GetMyHandle(), INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION);

    // console command
    RegConsoleCmd("sm_shop",        Command_Shop);
    RegConsoleCmd("sm_store",       Command_Shop);
    RegConsoleCmd("sm_inventory",   Command_Inv);
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
    if(!GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
    {
        KickClient(client, "系统无法获取您的SteamID");
        return;
    }

    char m_szQuery[64];
    FormatEx(m_szQuery, 64, "SELECT uid,money,spt FROM dxg_users WHERE uid = '%s'", steamid);
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
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "LoadClientCallback -> SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(5.0, Timer_ReAuthorize, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }


    if(results.RowCount <= 0 || results.FetchRow())
    {
        KickClient(client, "系统无法获取您的数据");
        return;
    }

    g_ClientData[client][bLoaded] = true;
    g_ClientData[client][iUid]    = results.FetchInt(0);
    g_ClientData[client][iMoney]  = results.FetchInt(1);
    g_ClientData[client][bVip]    = (results.FetchInt(2) == 1);

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
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "LoadClientCallback -> SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(5.0, Timer_ReAuthorize, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    if(results.RowCount <= 0)
        return;

    int items = 0;
    char unique[32];
    while(results.FetchRow())
    {
        results.FetchString(2, unique, 32);
        
        g_ClientItem[client][items][iItemIndex] = UTIL_FindItemByUniqueId(unique);
        
        if(g_ClientItem[client][items][iItemIndex] == -1)
            continue;
        
        g_ClientItem[client][items][iDbIndex]           = results.FetchInt(0);
        g_ClientItem[client][items][iCost]              = results.FetchInt(3);
        g_ClientItem[client][items][iDateOfPurchase]    = results.FetchInt(4);
        g_ClientItem[client][items][iDateOfExpiration]  = results.FetchInt(5);
        
        items++;
        
        LogMessage("Load %N item -> %s -> %s", client, unique, g_Items[g_ClientItem[client][items][iItemIndex]][szFullName]);
    }
    
    g_ClientData[client][iItems] = items;
}

int UTIL_FindItemByUniqueId(const char[] uniqueId)
{
    for(int i = 0; i < g_iItems; ++i)
        if(strcmp(uniqueId, g_Items[i][szUniqueId]) == 0)
            return i;
    return -1;
}

int UTIL_FindCategoryByType(const char[] type)
{
    for(int i = 0; i < g_iCategories; ++i)
        if(strcmp(type, g_Category[i][szType]) == 0)
            return i;
    return -1;
}

bool UTIL_HasClientItem(int client, const char[] uniqueId)
{
    if(!g_ClientData[client][bLoaded])
        return false;
    
    int itemid = UTIL_FindItemByUniqueId(uniqueId);
    
    if(itemid == -1)
        return false;
    
    if(g_Items[itemid][bVipItem])
        return g_ClientData[client][bVip];
    
    if(g_Items[itemid][szPersonalId][0] != '\0')
    {
        char m_szUserId[12];
        IntToString(g_ClientData[client][iUid], m_szUserId, 12);
        return (StrContains(g_Items[itemid][szPersonalId], m_szUserId) != -1);
    }
    
    if(g_Items[itemid][bBuyable] && g_Items[itemid][iPrice][0] == 0 && g_Items[itemid][iPrice][1] == 0 && g_Items[itemid][iPrice][2] == 0 && g_Items[itemid][iPrice][3] == 0)
        return true;

    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(itemid == g_ClientItem[client][i][iItemIndex])
        {
            if(g_ClientItem[client][i][iDateOfExpiration] == 0 || g_ClientItem[client][i][iDateOfExpiration] > GetTime())
                return true;
            break;
        }

    return false;
}

int UTIL_GetLengthByPrice(int itemid, int cost)
{
    int index = -1;
    for(int i = 0; i < 4; ++i)
        if(g_Items[itemid][iPrice][i] == cost)
            index = i;
    
    switch(index)
    {
        case 3 : return 0;
        case 2 : return 2592000;
        case 1 : return  604800;
        case 0 : return   86400;
    }

    return -1;
}

bool UTIL_EarnMoney(int client, int earn, const char[] reason)
{
    g_ClientData[client][iMoney] += earn;
    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "UPDATE dxg_users SET money=money+%d WHERE uid=%d", earn, g_ClientData[client][iUid]);
    UTIL_SQLNoCallback(m_szQuery, 128);
    UTIL_DBLogging(client, earn, reason);
    return true;
}

bool UTIL_CostMoney(int client, int cost, const char[] reason)
{
    g_ClientData[client][iMoney] -= cost;
    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "UPDATE dxg_users SET money=money-%d WHERE uid=%d", cost, g_ClientData[client][iUid]);
    UTIL_SQLNoCallback(m_szQuery, 128);
    UTIL_DBLogging(client, -cost, reason);
    return true;
}

void UTIL_DBLogging(int client, int money, const char[] reason)
{
    char eR[256], m_szQuery[512];
    g_MySQL.Escape(reason, eR, 256);
    FormatEx(m_szQuery, 512, "INSERT INTO dxg_banklog VALUES (DEFAULT, %d, %d, '%s', %d)", g_ClientData[client][iUid], money, eR, GetTime());
    UTIL_SQLNoCallback(m_szQuery, 512);
}

void UTIL_SQLNoCallback(const char[] m_szQuery, int maxLen)
{
    DataPack pack = new DataPack();
    pack.WriteCell(maxLen);
    pack.WriteString(m_szQuery);
    pack.Reset();

    g_MySQL.Query(QueryNoCallback, m_szQuery, pack);
}

public void QueryNoCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    if(results == null || error[0] || results.AffectedRows == 0)
    {
        int maxLen = pack.ReadCell();
        char[] m_szQueryString = new char[maxLen];
        pack.ReadString(m_szQueryString, maxLen);
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "LoadInventoryCallback -> SQL Error: %s\nQuery: %s", (results == null || error[0]) ? error : "No affected row", m_szQueryString);
    }

    delete pack;
}