/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET GOTV Controller                 */
/*                                                                */
/*                                                                */
/*  File:          mg-gotv.sp                                     */
/*  Description:   Interconnector of Game and Forum.              */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  MagicGirl.NET Dev Team                    */
/*  2018/03/10 21:30:45                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <MagicGirl.NET>
#include <MagicGirl/vars>

#include <system2>

#define PI_NAME THIS_PRETAG ... " - GOTV"
#define PI_DESC "GOTV and demo for MagicGirl.NET"

public Plugin myinfo = 
{
    name        = PI_NAME,
    author      = PI_AUTH,
    description = PI_DESC,
    version     = PI_VERS,
    url         = PI_URLS
};

ConVar tv_autorecord;
ConVar tv_enable;
ConVar tv_transmitall;
ConVar tv_snapshotrate;

char g_szDemo[128];
bool g_bRecording;
bool g_bNeedBzip;
bool g_b128Tick;
int g_iRecTime;
Handle g_hInitTimer;

public void OnPluginStart()
{
    if(GetEngineVersion() != Engine_CSGO)
        SetFailState("This plugin only for CSGO!");

    RegConsoleCmd("sm_demo", Command_Demo);
    
    HookEventEx("round_freeze_end",  Event_RoundStart,  EventHookMode_Post);
    HookEventEx("player_death",      Event_PlayerDeath, EventHookMode_Post);

    tv_enable = FindConVar("tv_enable");
    tv_autorecord = FindConVar("tv_autorecord");
    tv_transmitall = FindConVar("tv_transmitall");
    tv_snapshotrate = FindConVar("tv_snapshotrate");
    tv_enable.AddChangeHook(OnConVarChanged);
    tv_autorecord.AddChangeHook(OnConVarChanged);
    tv_transmitall.AddChangeHook(OnConVarChanged);
    tv_snapshotrate.AddChangeHook(OnConVarChanged);

    CheckConVarValue();
    CheckAndCleanDir();
}

public void OnPluginEnd() 
{
    StopRecord();
}

public void OnConfigsExecuted()
{
    g_b128Tick = (RoundToNearest(1.0 / GetTickInterval()) == 128);
    CheckConVarValue();
    if(g_hInitTimer != null)
        KillTimer(g_hInitTimer);
    g_hInitTimer = CreateTimer(FindConVar("mp_warmuptime").FloatValue + 3.0, OnMapStartPost);
}

public void OnMapEnd()
{
    if(g_hInitTimer != null)
        KillTimer(g_hInitTimer);
    g_hInitTimer = null;
    StopRecord();
}

public void OnClientDisconnect_Post(int client)
{
    CheckAllowRecord();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(2.0, Timer_Death, event.GetInt("userid"));
}

public Action Timer_Death(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if(!client || !g_bRecording || !g_iRecTime)
        return Plugin_Stop;

    char szTime[32];
    FormatTime(szTime, 32, "%M:%S", g_iRecTime-2);

    PrintToChat(client, " \07*** \x02DEMO \07***  \x10你被杀了,DEMO时间为\x04%s", szTime);
    PrintToChat(client, " \x04[\x0F%s\x04]", g_szDemo);

    return Plugin_Stop;
}

static void StopRecord()
{
    g_iRecTime = 0;
    g_bRecording = false;
    ServerCommand("tv_stoprecord");
    if(g_bNeedBzip ||  !g_bRecording)
    {
        g_bNeedBzip = false;
        CreateTimer(0.1, Timer_MoveFile);
    }
}

public Action Timer_MoveFile(Handle timer)
{
    char oldfile[128];
    FormatEx(oldfile, 128, "recording/%s.dem", g_szDemo);

    if(FileExists(oldfile))
    {
        char newfile[128];
        FormatEx(newfile, 128, "recording/bz2/%s.dem.7z", g_szDemo);
        DataPack pack = new DataPack();
        pack.WriteString(g_szDemo);
        pack.Reset();
        System2_CompressFile(OnBz2Completed, oldfile, newfile, ARCHIVE_7Z, LEVEL_3, pack);
    }

    g_szDemo[0] = '\0';
    
    return Plugin_Stop;
}

public void OnBz2Completed(const char[] output, const int size, CMDReturn status, DataPack pack)
{
    pack.Reset();
    char demoname[128];
    pack.ReadString(demoname, 128);

    if(status == CMD_SUCCESS)
    {
        char oldfile[128], newfile[128];
        FormatEx(oldfile, 128, "recording/%s.dem", demoname);
        if(!DeleteFile(oldfile))
            LogError("Delete %s failed.", oldfile);

        FormatEx(newfile, 128, "recording/bz2/%s.dem.7z", demoname);

        if(FileSize(newfile) < 10240000)
        {
            LogMessage("%s is too small, deleted", newfile);
            if(!DeleteFile(newfile))
                LogError("Delete %s failed.", newfile);
            return;
        }

        char remote[256];
        switch(MG_Core_GetServerModId())
        {
            case 102: FormatEx(remote, 256, "/Mini Games/%s.dem.7z", demoname);
            case 103: FormatEx(remote, 256, "/Trouble in Terrorist Town/%s.dem.7z", demoname);
            case 104: FormatEx(remote, 256, "/Jail Break/%s.dem.7z", demoname);
            default : FormatEx(remote, 256, "/Unknown/%s.dem.7z", demoname);
        }

        char host[32], port[32], user[32], pswd[32];
        MG_Vars_GetVariable("ftp_demo_host", host, 32);
        MG_Vars_GetVariable("ftp_demo_port", port, 32);
        MG_Vars_GetVariable("ftp_demo_user", user, 32);
        MG_Vars_GetVariable("ftp_demo_pswd", pswd, 32);
        System2_UploadFTPFile(OnFTPUploadCompleted, newfile, remote, host, user, pswd, StringToInt(port), pack);
    }
    else if(status == CMD_ERROR)
    {
        LogError("7z CompressFile %s failed.", demoname);

        char oldfile[128];
        FormatEx(oldfile, 128, "recording/%s.dem", demoname);
        if(!DeleteFile(oldfile))
            LogError("Delete %s failed.", oldfile);

        delete pack;
    }
}

public void OnFTPUploadCompleted(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow, DataPack hPack)
{
    pack.Reset();
    char demoname[128];
    pack.ReadString(demoname, 128);
    delete hPack;

    if(finished)
    {
        char oldfile[128];
        FormatEx(oldfile, 128, "recording/bz2/%s.dem.7z", demoname);
        if(!DeleteFile(oldfile))
            LogError("Delete %s failed.", oldfile);

        if(!StrEqual(error, ""))
            LogError("FTP Upload %s.dem.7z failed", demoname, error);
    }
}

public Action OnMapStartPost(Handle timer)
{
    g_hInitTimer = INVALID_HANDLE;

    if(!CheckAllowRecord())
        return Plugin_Stop;

    char time[64], map[64];
    FormatTime(time, 64, "%Y%m%d_%H-%M-%S", GetTime());

    GetCurrentMap(map, 64);

    FormatEx(g_szDemo, 128, "%s_%s", time, map);

    PrintToChatAll(" \07*** \x02DEMO \07***  \x04Demo已开始录制...");
    PrintToChatAll(" \x04[\x0F%s\x04]", g_szDemo);

    ServerCommand("tv_record recording/%s.dem", g_szDemo);

    g_bRecording = true;
    g_bNeedBzip = true;

    CreateTimer(1.0, Timer_RecTime, _, TIMER_REPEAT);
    
    return Plugin_Stop;
}

public Action Timer_RecTime(Handle timer)
{    
    if(!g_bRecording)
        return Plugin_Stop;
    
    g_iRecTime++;

    return Plugin_Continue;
}

public Action Timer_Broadcast(Handle timer)
{    
    PrintToChatAll(" \07*** \x02DEMO \07***  \x04Demo录制中...");
    PrintToChatAll(" \x04[\x0F%s\x04]", g_szDemo);
    
    return Plugin_Stop;
}

public Action Command_Demo(int client, int args)
{
    if(!g_bRecording)
    {
        PrintToChatAll(" \07*** \x02DEMO \07***  \x04[\x0F目前还未开始录制DEMO\x04]");
        return Plugin_Handled;
    }

    PrintToChatAll(" \07*** \x02DEMO \07***  \x10当前DEMO");
    PrintToChatAll(" \x04[\x0F%s\x04]", g_szDemo)

    return Plugin_Handled;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{    
    if(g_bRecording)
        CreateTimer(5.0, Timer_Broadcast);
}

static void CheckConVarValue()
{    
    tv_enable.SetInt(1);
    tv_autorecord.SetInt(0);
    tv_transmitall.SetInt(0);
    tv_snapshotrate.SetInt(g_b128Tick ? 128 : 32);
}

public void OnConVarChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
    CheckConVarValue();
}

static bool CheckAllowRecord()
{
    int players;

    for(int i = 1; i <= MaxClients; ++i)
        if(IsClientConnected(i) && !IsFakeClient(i) && !IsClientSourceTV(i))
            players++;

    if(players <= 3)
    {
        StopRecord();
        return false;
    }

    return true;
}

static void CheckAndCleanDir()
{
    if(!DirExists("recording"))
        CreateDirectory("recording", 511);

    if(!DirExists("recording/bz2"))
        CreateDirectory("recording/bz2", 511);

    OpenDirectory hDirectory;
    if((hDirectory = OpenDirectory("recording")) != null)
    {
        FileType type = FileType_Unknown;
        char filename[128];
        while(ReadDirEntry(hDirectory, filename, 128, type))
        {
            if(type != FileType_File)
                continue;

            TrimString(filename);

            if(StrContains(filename, ".dem", false) == -1)
                continue;

            char path2[128];
            FormatEx(path2, 128, "recording/%s", filename);
            if(DeleteFile(path2))
                LogMessage("Delete invalid demo: %s", path2);
        }
        delete hDirectory;
    }
}