/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET User Manager                    */
/*                                                                */
/*                                                                */
/*  File:          mg-shop.sp                                     */
/*  Description:   Interconnector of Game and Forum.              */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  MagicGirl.NET Dev Team                    */
/*  2017/01/55 17:17:52                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <MagicGirl.NET>
#include <MagicGirl/user>

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
}

enum Item_Data
{
    iItemId,
    iDataIndex,
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
    iIndex,
    iItemIndex,
    iCost,
    iDateOfPurchase,
    iDateOfExpiration
}

enum Client_Data
{
    iMoney,
    iItems,
    bool:bEquipped[MAX_ITEM_CATEGORY][MAX_SLOT],
}

any g_ClientData[MAXPLAYERS+1][Client_Data];
any g_ClientItem[MAXPLAYERS+1][Client_Item]
any g_ItemsData[MAX_ITEMS][Item_Data];
any g_ItemCategory[MAX_ITEM_CATEGORY][Item_Categories];

int g_iItemCategories;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("MG_Shop_RegItemCategory",    Native_RegItemCategory);

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
    g_ItemCategory[index][fnOnLoad] = GetNativeCell(3);
    g_ItemCategory[index][fnOnUse] = GetNativeCell(4);
    g_ItemCategory[index][fnOnRemove] = GetNativeCell(5);

    g_iItemCategories++;
    
    return true;
}

public void OnPluginStart()
{
    
}