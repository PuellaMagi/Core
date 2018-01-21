/******************************************************************/
/*                                                                */
/*                      MagicGirl.NET Core                        */
/*                                                                */
/*                                                                */
/*  File:          MagicGirl.NET.inc                              */
/*  Description:   Interconnector of Game and Forum.              */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  MagicGirl.NET Dev Team                    */
/*  2017/01/04 11:16:39                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/


#define THIS_AUTHOR "MagicGirl.NET Dev Team" // Kyle 'Kxnrl' Lu and Magic '2724' Jiang
#define THIS_PRETAG "MagicGirl.NET"
#define THIS_URLINK "https://MagicGirl.net"

#define Core_Version "c1.0"
#define APIs_Version "a1.0"

#if !defined REQUIRE_PLUGIN
    #endinput
#endif

#if defined _MagicGirl_Core_Include_
    #endinput
#endif

#define _MagicGirl_Core_Include_

forward void MG_MySQL_OnConnected(Database mysql);
forward void MG_Core_OnAvailable(int serverId, int modId);

// core
native void MG_Core_LogError(const char[] module = "Global", const char[] func = "Invalid Function", const char[] msg, any ...);
native void MG_Core_LogMessage(const char[] module = "Global", const char[] func = "Invalid Function", const char[] msg, any ...);
native int  MG_Core_GetServerId();
native int  MG_Core_GetServerModId();

// database
native bool MG_MySQL_IsConnected();
native Database MG_MySQL_GetDatabase();
native bool MG_MySQL_EscapeString(const char[] input, char[] output, int maxLen);
native void MG_MySQL_SaveDatabase(const char[] QueryString);
native DBResultSet MG_MySQL_ExecDatabase(const char[] QueryString);

public SharedPlugin __pl_MagicGirl =
{
	name = "MagicGirl",
	file = "MagicGirl.smx",
	required = 1 // force requires
};