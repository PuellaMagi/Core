/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET User Manager                    */
/*                                                                */
/*                                                                */
/*  File:          vars.inc                                       */
/*  Description:   Interconnector of Game and Forum.              */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  MagicGirl.NET Dev Team                    */
/*  2017/02/10 01:53:55                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/

#if defined _MagicGirl_Vars_Include_
    #endinput
#endif

#define _MagicGirl_Vars_Include_

native bool MG_Vars_IsVarExists(const char[] _key);
native bool MG_Vars_GetVariable(const char[] _key, char[] _var, int maxLen);

public SharedPlugin __pl_mg_vars =
{
	name = "mg-vars",
	file = "mg-vars.smx",
#if !defined REQUIRE_PLUGIN
    required = 0
#else
    required = 1
#endif
};