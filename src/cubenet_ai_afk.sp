/**
 * =====================================================
 * [SS] AFK Bot Driver
 * CubeNet Game Servers
 *
 * Version 4.0.0
 *
 * Shadow bot controller.
 *
 * Player remains connected.
 * Bot drives replacement.
 *
 * =====================================================
 */

#pragma semicolon 1
#pragma newdecls required


#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <ss_debug>


#define PLUGIN_VERSION "4.0.0"


#define AFK_TIME 300.0
#define CHECK_TIME 10.0


float g_ReplacementTime[MAXPLAYERS+1];

bool g_Replaced[MAXPLAYERS+1];

int g_DriverBot[MAXPLAYERS+1];

float g_LastActivity[MAXPLAYERS+1];

// Saved player state

int g_SavedTeam[MAXPLAYERS+1];

TFClassType g_SavedClass[MAXPLAYERS+1];


// Bot tracking

int g_PreviousBotCount;


int CountBots()
{
    int count = 0;

    for(int i=1;i<=MaxClients;i++)
    {
        if(IsClientInGame(i) && IsFakeClient(i))
        {
            count++;
        }
    }

    return count;
}


public Plugin myinfo =
{
    name = "[SS] AFK Bot Driver",
    author = "CubeNet",
    description = "Shadow AFK player replacement",
    version = PLUGIN_VERSION,
    url = ""
};



// =====================================================
// START
// =====================================================

public void OnPluginStart()
{

    SS_DebugInit("ss_afkbot");


    HookEvent(
        "player_spawn",
        Event_PlayerSpawn
    );


    AddCommandListener(
        Command_Say,
        "say"
    );


    CreateTimer(
        CHECK_TIME,
        Timer_CheckAFK,
        _,
        TIMER_REPEAT
    );


    RegAdminCmd(
        "sm_afkbot_force",
        Command_Force,
        ADMFLAG_GENERIC
    );


    RegAdminCmd(
        "sm_afkbot_status",
        Command_Status,
        ADMFLAG_GENERIC
    );


    PrintToServer(
        "[SS] AFK Bot Driver %s loaded",
        PLUGIN_VERSION
    );

}




// =====================================================
// PLAYER JOIN
// =====================================================

public void OnClientPutInServer(int client)
{

    if(IsFakeClient(client))
        return;


    g_LastActivity[client] =
        GetGameTime();


    g_Replaced[client] = false;

    g_DriverBot[client] = -1;

}




// =====================================================
// ACTIVITY
// =====================================================


public Action Command_Say(
    int client,
    const char[] command,
    int argc
)
{

    TouchPlayer(client);

    return Plugin_Continue;

}




public Action OnPlayerRunCmd(
    int client,
    int &buttons,
    int &impulse,
    float vel[3],
    float angles[3],
    int &weapon,
    int &subtype,
    int &cmdnum,
    int &tickcount,
    int &seed,
    int mouse[2]
)
{

    if(client <= 0)
        return Plugin_Continue;


    if(IsFakeClient(client))
        return Plugin_Continue;


    if(buttons != 0 ||
       vel[0] != 0.0 ||
       vel[1] != 0.0)
    {
        TouchPlayer(client);
    }


    return Plugin_Continue;

}




void TouchPlayer(int client)
{
    g_LastActivity[client] =
        GetGameTime();


    if(g_Replaced[client])
    {
        if(GetGameTime() - g_ReplacementTime[client] < 5.0)
        {
            return;
        }


        StopAIDriver(client);
    }
}





// =====================================================
// AFK CHECK
// =====================================================

public Action Timer_CheckAFK(
    Handle timer,
    any data
)
{

    float now = GetGameTime();


    for(int i=1;i<=MaxClients;i++)
    {

        if(!IsClientInGame(i))
            continue;


        if(IsFakeClient(i))
            continue;


        if(g_Replaced[i])
            continue;


        if(now - g_LastActivity[i] >= AFK_TIME)
        {
            StartAIDriver(i);
        }

    }


    return Plugin_Continue;

}





// =====================================================
// SPAWN BOT
// =====================================================


void StartAIDriver(int client)
{
    if(g_Replaced[client])
        return;


    SS_Log(
        SS_INFO,
        "Starting driver for %N",
        client
    );


    g_Replaced[client] = true;

    g_ReplacementTime[client] = GetGameTime();

    g_SavedTeam[client] = GetClientTeam(client);

g_SavedClass[client] =
    TF2_GetPlayerClass(client);


    g_PreviousBotCount =
        CountBots();


    ServerCommand(
        "tf_bot_add 1"
    );


    CreateTimer(
        8.0,
        Timer_FindBot,
        GetClientUserId(client),
        TIMER_REPEAT
    );
}





public Action Timer_FindBot(
    Handle timer,
    any userid
)
{
    int client =
        GetClientOfUserId(userid);


    if(client <= 0)
        return Plugin_Stop;



    int bots = CountBots();


    if(bots <= g_PreviousBotCount)
        return Plugin_Continue;



    for(int i=1;i<=MaxClients;i++)
    {

        if(!IsClientInGame(i))
            continue;


        if(!IsFakeClient(i))
            continue;


        if(g_DriverBot[client] == i)
            continue;



        g_DriverBot[client]=i;


        SS_Log(
            SS_INFO,
            "Assigned bot %N to %N",
            i,
            client
        );


        SetupBot(
            client,
            i
        );


        HideAFKPlayer(client);


        CreateTimer(
            1.0,
            Timer_MoveBot,
            GetClientUserId(client)
        );


        return Plugin_Stop;
    }


    return Plugin_Continue;
}



public Action Timer_MoveBot(
    Handle timer,
    any userid
)
{
    int client =
        GetClientOfUserId(userid);


    if(client <= 0)
        return Plugin_Stop;


    int bot =
        g_DriverBot[client];


    if(bot <= 0 ||
       !IsClientInGame(bot))
        return Plugin_Stop;


    MoveBotToPlayer(
        client,
        bot
    );


    return Plugin_Stop;
}


void MoveBotToPlayer(
    int client,
    int bot
)
{
    float pos[3];
    float ang[3];

    GetClientAbsOrigin(
        client,
        pos
    );

    GetClientAbsAngles(
        client,
        ang
    );


    TeleportEntity(
        bot,
        pos,
        ang,
        NULL_VECTOR
    );
}


void HideAFKPlayer(int client)
{
    // freeze player
    SetEntityMoveType(
        client,
        MOVETYPE_NONE
    );


    // disable collision
    SetEntProp(
        client,
        Prop_Send,
        "m_CollisionGroup",
        2
    );


    // hide player model
    SetEntityRenderMode(
        client,
        RENDER_TRANSCOLOR
    );


    SetEntityRenderColor(
        client,
        255,
        255,
        255,
        0
    );


    // hide weapon/viewmodel
    SetEntProp(
        client,
        Prop_Send,
        "m_bDrawViewmodel",
        0
    );
}



void SetupBot(
    int client,
    int bot
)
{
    TFTeam team =
        view_as<TFTeam>(g_SavedTeam[client]);


    ChangeClientTeam(
        bot,
        team
    );


    TF2_SetPlayerClass(
        bot,
        g_SavedClass[client],
        false,
        true
    );


    TF2_RespawnPlayer(bot);


    FakeClientCommand(
        bot,
        "jointeam %s",
        team == TFTeam_Blue ? "blue" : "red"
    );


    FakeClientCommand(
        bot,
        "joinclass %s",
        "random"
    );


    SS_Log(
        SS_INFO,
        "Bot %N now mirrors %N",
        bot,
        client
    );
}



// =====================================================
// STOP
// =====================================================

void StopAIDriver(int client)
{

    SS_Log(
        SS_WARN,
        "STOP DRIVER CALLED FOR %N",
        client
    );

    if(!g_Replaced[client])
        return;


    int bot =
        g_DriverBot[client];


    if(bot > 0 &&
       IsClientInGame(bot))
    {
        KickClient(
            bot,
            "Player returned"
        );
    }


    g_DriverBot[client]=-1;

    g_Replaced[client]=false;


    SetEntityMoveType(
        client,
        MOVETYPE_WALK
    );


    SetEntityRenderColor(
        client,
        255,
        255,
        255,
        255
    );


      if(!IsPlayerAlive(client))
      {
          TF2_RespawnPlayer(client);
      }


    g_LastActivity[client]=GetGameTime();


    PrintToChat(
        client,
        "\x04[SS]\x01 Welcome back"
    );
}





// =====================================================
// EVENTS
// =====================================================


public Action Event_PlayerSpawn(
    Event event,
    const char[] name,
    bool dontBroadcast
)
{

    int client =
        GetClientOfUserId(
            event.GetInt("userid")
        );


    if(client>0 &&
       !IsFakeClient(client))
    {
        TouchPlayer(client);
    }


    return Plugin_Continue;

}





// =====================================================
// COMMANDS
// =====================================================


public Action Command_Force(
    int client,
    int args
)
{

    if(args < 1)
        return Plugin_Handled;


    char target[64];

    GetCmdArg(
        1,
        target,
        sizeof(target)
    );


    int player =
        FindTarget(
            client,
            target,
            true
        );


    if(player)
        StartAIDriver(player);


    return Plugin_Handled;

}





public Action Command_Status(
    int client,
    int args
)
{

    ReplyToCommand(
        client,
        "[SS] AFK Drivers:"
    );


    for(int i=1;i<=MaxClients;i++)
    {

        if(g_Replaced[i])
        {
            ReplyToCommand(
                client,
                "%N -> %N",
                i,
                g_DriverBot[i]
            );
        }

    }


    return Plugin_Handled;

}

