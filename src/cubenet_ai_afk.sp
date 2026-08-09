/**
 * =====================================================
 * CubeNet AI Squad - AFK Possession (Phase 2.3b)
 * Same-entity takeover via CBaseNPC navmesh.
 * Fixes: TheNavMesh, height-aware path cost, stairs,
 * stickier combat / last-known hunt, engie build/maintain.
 * Fire (ATTACK) to reclaim control.
 * =====================================================
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <cbasenpc>

#define PLUGIN_VERSION "4.2.4-phase2.3b"

ConVar g_CvarAFKTime;
ConVar g_CvarCheckInterval;
ConVar g_CvarDebug;

float g_LastActivity[MAXPLAYERS + 1];
bool  g_IsAIControlled[MAXPLAYERS + 1];

ArrayList g_PathPositions[MAXPLAYERS + 1];
int   g_PathIndex[MAXPLAYERS + 1];
int   g_PathGoalIndex[MAXPLAYERS + 1];
float g_NextRepath[MAXPLAYERS + 1];

float g_LookAt[MAXPLAYERS + 1][3];
int   g_AIButtons[MAXPLAYERS + 1];
float g_AIForwardMove[MAXPLAYERS + 1];
float g_AISideMove[MAXPLAYERS + 1];

int   g_CombatTarget[MAXPLAYERS + 1];
float g_LastKnownEnemyPos[MAXPLAYERS + 1][3];
bool  g_HasLastKnownEnemy[MAXPLAYERS + 1];
float g_LastKnownEnemyTime[MAXPLAYERS + 1];

float g_EgressGoal[MAXPLAYERS + 1][3];
bool  g_HasEgress[MAXPLAYERS + 1];

float g_LastPos[MAXPLAYERS + 1][3];
float g_LastMovedAt[MAXPLAYERS + 1];
float g_UnstuckUntil[MAXPLAYERS + 1];
int   g_UnstuckDir[MAXPLAYERS + 1];
float g_NudgeUntil[MAXPLAYERS + 1];
float g_NudgeYawOffset[MAXPLAYERS + 1];
float g_HighYawSince[MAXPLAYERS + 1];

float g_NextBuildTry[MAXPLAYERS + 1];
int   g_BuildState[MAXPLAYERS + 1];
float g_NextSlotCmd[MAXPLAYERS + 1];

float g_EngNestOrigin[MAXPLAYERS + 1][3];
bool  g_EngHasNest[MAXPLAYERS + 1];

int   g_EngStage[MAXPLAYERS + 1];
float g_EngStageUntil[MAXPLAYERS + 1];
float g_EngFrontGoal[MAXPLAYERS + 1][3];
bool  g_EngHasFrontGoal[MAXPLAYERS + 1];
float g_EngDeployGuard[MAXPLAYERS + 1];

float g_BlockedUntil[MAXPLAYERS + 1];
float g_AvoidYaw[MAXPLAYERS + 1];
float g_DoorUseUntil[MAXPLAYERS + 1];
int   g_DoorEnt[MAXPLAYERS + 1];
int   g_DoorState[MAXPLAYERS + 1]; // 0=none 1=approach 2=use 3=wait
float g_DoorWaitUntil[MAXPLAYERS + 1];
int   g_BlockCount[MAXPLAYERS + 1];

float g_EngDangerUntil[MAXPLAYERS + 1];
float g_EngLastEnemySeen[MAXPLAYERS + 1];
int   g_EngLastEnemy[MAXPLAYERS + 1];
float g_EngPlaceYaw[MAXPLAYERS + 1];

bool  g_IsInBuildMode[MAXPLAYERS + 1];
float g_NextBuildCheck[MAXPLAYERS + 1];

bool  g_NavReady;

enum
{
    ENG_STAGE_SPAWN_BUILD = 0,
    ENG_STAGE_UPGRADE,
    ENG_STAGE_PACK,
    ENG_STAGE_HAUL,
    ENG_STAGE_DEPLOY,
    ENG_STAGE_HOLD
};

public Plugin myinfo =
{
    name        = "[CubeNet] AFK Possession",
    author      = "CubeNet",
    description = "Same-entity AFK AI takeover (Phase 2.3b – nav/combat/engie fixes)",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/cube-source/CubeNet-AI-Squad"
};

public void OnPluginStart()
{
    g_CvarAFKTime       = CreateConVar("cubenet_afk_time", "120.0", "Seconds idle before AI control", _, true, 30.0, true, 600.0);
    g_CvarCheckInterval = CreateConVar("cubenet_afk_check", "5.0", "AFK check interval", _, true, 2.0, true, 30.0);
    g_CvarDebug         = CreateConVar("cubenet_afk_debug", "1", "Debug overlay", _, true, 0.0, true, 1.0);

    AutoExecConfig(true, "cubenet_ai_afk");

    HookEvent("player_spawn", Event_PlayerSpawn);

    CreateTimer(g_CvarCheckInterval.FloatValue, Timer_CheckAFK, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    RegConsoleCmd("sm_afk_force",   Command_Force,   "Force AI control");
    RegConsoleCmd("sm_afk_release", Command_Release, "Release AI control");
    RegConsoleCmd("sm_afk_status",  Command_Status,  "List AI-controlled players");

    for (int i = 1; i <= MaxClients; i++)
    {
        g_PathPositions[i] = new ArrayList(3);
        g_IsAIControlled[i] = false;
        g_LastActivity[i]   = GetGameTime();
        g_UnstuckDir[i]     = 1;
    }

    PrintToServer("[CubeNet] AFK Possession %s loaded", PLUGIN_VERSION);
}

public void OnMapStart()
{
    g_NavReady = TheNavMesh.IsLoaded();
    if (!g_NavReady)
        PrintToServer("[CubeNet] WARNING: NavMesh not loaded – pathing will be degraded.");
    else
        PrintToServer("[CubeNet] NavMesh loaded (%d areas).", TheNavMesh.GetNavAreaCount());
}

public void OnClientPutInServer(int client)
{
    if (IsFakeClient(client))
        return;

    ResetClientAIState(client);
    g_IsAIControlled[client] = false;
    g_LastActivity[client]   = GetGameTime();
}

public void OnClientDisconnect(int client)
{
    g_IsAIControlled[client] = false;
    if (g_PathPositions[client] != null)
        g_PathPositions[client].Clear();
}

void ResetClientAIState(int client)
{
    g_PathIndex[client]      = -1;
    g_PathGoalIndex[client]  = -1;
    g_NextRepath[client]     = 0.0;
    g_AIButtons[client]      = 0;
    g_AIForwardMove[client]  = 0.0;
    g_AISideMove[client]     = 0.0;
    g_CombatTarget[client]   = -1;
    g_HasLastKnownEnemy[client] = false;
    g_LastKnownEnemyTime[client] = 0.0;
    g_HasEgress[client]      = false;
    g_LastMovedAt[client]    = GetGameTime();
    g_UnstuckUntil[client]   = 0.0;
    g_UnstuckDir[client]     = 1;
    g_NudgeUntil[client]     = 0.0;
    g_NudgeYawOffset[client] = 0.0;
    g_HighYawSince[client]   = 0.0;
    g_BlockedUntil[client] = 0.0;
    g_AvoidYaw[client]     = 0.0;
    g_DoorUseUntil[client] = 0.0;
    g_DoorEnt[client]      = -1;
    g_DoorState[client]    = 0;
    g_DoorWaitUntil[client] = 0.0;
    g_BlockCount[client]   = 0;
    g_BuildState[client]     = 0;
    g_NextBuildTry[client]   = 0.0;
    g_NextSlotCmd[client]    = 0.0;
    g_EngHasNest[client]     = false;

    g_EngStage[client]        = ENG_STAGE_SPAWN_BUILD;
    g_EngHasFrontGoal[client] = false;
    g_EngStageUntil[client]   = 0.0;
    g_EngDeployGuard[client]  = 0.0;
    g_EngDangerUntil[client]  = 0.0;
    g_EngLastEnemySeen[client] = 0.0;
    g_EngLastEnemy[client]    = -1;
    g_EngPlaceYaw[client]     = 0.0;

    g_IsInBuildMode[client]   = false;
    g_NextBuildCheck[client]  = 0.0;

    if (client > 0 && client <= MaxClients && IsClientInGame(client))
        GetClientAbsOrigin(client, g_LastPos[client]);

    if (g_PathPositions[client] != null)
        g_PathPositions[client].Clear();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;

    if (g_IsAIControlled[client])
    {
        if (buttons & IN_ATTACK)
        {
            ReleaseControl(client);
            return Plugin_Continue;
        }

        buttons   = g_AIButtons[client];
        vel[0]    = g_AIForwardMove[client];
        vel[1]    = g_AISideMove[client];
        vel[2]    = 0.0;
        angles[0] = g_LookAt[client][0];
        angles[1] = g_LookAt[client][1];
        angles[2] = 0.0;
        return Plugin_Changed;
    }

    if (buttons != 0 || vel[0] != 0.0 || vel[1] != 0.0 || mouse[0] != 0 || mouse[1] != 0)
        g_LastActivity[client] = GetGameTime();

    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || IsFakeClient(client))
        return Plugin_Continue;

    if (!g_IsAIControlled[client])
        g_LastActivity[client] = GetGameTime();

    if (g_IsAIControlled[client])
    {
        g_PathIndex[client]     = -1;
        g_PathGoalIndex[client] = -1;
        g_NextRepath[client]    = 0.0;
        if (g_PathPositions[client] != null)
            g_PathPositions[client].Clear();

        SeedEgressGoal(client);

        g_EngStage[client]        = ENG_STAGE_SPAWN_BUILD;
        g_EngHasFrontGoal[client] = false;
        g_EngStageUntil[client]   = 0.0;
        g_BuildState[client]      = 0;
        g_NextBuildTry[client]    = 0.0;
        g_CombatTarget[client]    = -1;
        g_HasLastKnownEnemy[client] = false;
    }

    return Plugin_Continue;
}

public Action Timer_CheckAFK(Handle timer)
{
    float now       = GetGameTime();
    float threshold = g_CvarAFKTime.FloatValue;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
            continue;
        if (g_IsAIControlled[i])
            continue;

        int team = GetClientTeam(i);
        if (team != view_as<int>(TFTeam_Red) && team != view_as<int>(TFTeam_Blue))
            continue;

        if (now - g_LastActivity[i] >= threshold)
            TakeControl(i);
    }
    return Plugin_Continue;
}

void SeedEgressGoal(int client)
{
    float pos[3];
    GetClientAbsOrigin(client, pos);

    float center[3];
    center[0] = 0.0;
    center[1] = 0.0;
    center[2] = pos[2];

    float dir[3];
    SubtractVectors(center, pos, dir);
    dir[2] = 0.0;

    if (GetVectorLength(dir) < 10.0)
    {
        dir[0] = (GetClientTeam(client) == view_as<int>(TFTeam_Red)) ? -1.0 : 1.0;
        dir[1] = 0.0;
    }
    NormalizeVector(dir, dir);

    g_EgressGoal[client][0] = pos[0] + dir[0] * 1800.0;
    g_EgressGoal[client][1] = pos[1] + dir[1] * 1800.0;
    g_EgressGoal[client][2] = pos[2];
    g_HasEgress[client] = true;
}

void TakeControl(int client)
{
    if (g_IsAIControlled[client])
        return;

    g_IsAIControlled[client] = true;
    ResetClientAIState(client);
    SeedEgressGoal(client);

    if (g_CvarDebug.BoolValue)
        PrintToChatAll("[CubeNet] AI took control of %N (AFK)", client);

    PrintToChat(client, "\x04[CubeNet]\x01 AI controlling you. Press \x03ATTACK\x01 to take back control.");
}

void ReleaseControl(int client)
{
    if (!g_IsAIControlled[client])
        return;

    g_IsAIControlled[client] = false;
    g_AIButtons[client]      = 0;
    g_CombatTarget[client]   = -1;
    g_HasLastKnownEnemy[client] = false;
    g_HasEgress[client]      = false;
    g_BuildState[client]     = 0;
    g_LastActivity[client]   = GetGameTime();

    if (g_PathPositions[client] != null)
        g_PathPositions[client].Clear();

    if (g_CvarDebug.BoolValue)
        PrintToChatAll("[CubeNet] %N took back control", client);

    PrintToChat(client, "\x04[CubeNet]\x01 You are back in control.");
}

void UpdateUnstuck(int client)
{
    float now = GetGameTime();
    float pos[3];
    GetClientAbsOrigin(client, pos);

    if (GetVectorDistance(pos, g_LastPos[client]) > 18.0)
    {
        g_LastPos[client][0] = pos[0];
        g_LastPos[client][1] = pos[1];
        g_LastPos[client][2] = pos[2];
        g_LastMovedAt[client] = now;
        return;
    }

    float stalled = now - g_LastMovedAt[client];

    if (stalled > 0.55 && now > g_NudgeUntil[client] && now > g_UnstuckUntil[client])
    {
        g_NudgeUntil[client]     = now + 0.25;
        g_NudgeYawOffset[client] = (GetRandomFloat(0.0, 1.0) > 0.5) ? 22.0 : -22.0;
    }

    if (stalled > 1.15)
    {
        g_UnstuckUntil[client] = now + 1.15;
        if (TF2_GetPlayerClass(client) == TFClass_Heavy)
            g_UnstuckUntil[client] = now + 1.6;

        g_UnstuckDir[client]  = -g_UnstuckDir[client];
        g_LastMovedAt[client] = now;
        g_PathIndex[client]   = -1;
        g_NextRepath[client]  = 0.0;
    }
}

void ApplyNudge(int client)
{
    if (GetGameTime() > g_NudgeUntil[client])
        return;

    g_AISideMove[client] += (g_NudgeYawOffset[client] > 0.0) ? 220.0 : -220.0;
    g_AIButtons[client]  |= IN_FORWARD;

    if (g_NudgeYawOffset[client] > 0.0)
        g_AIButtons[client] |= IN_MOVERIGHT;
    else
        g_AIButtons[client] |= IN_MOVELEFT;
}

void ApplyUnstuck(int client)
{
    if (GetGameTime() > g_UnstuckUntil[client])
        return;

    g_AIButtons[client] |= IN_JUMP | IN_FORWARD;
    if (GetGameTime() < g_UnstuckUntil[client] - 0.45)
        g_AIButtons[client] |= IN_DUCK;

    g_AISideMove[client]    = 450.0 * float(g_UnstuckDir[client]);
    g_AIForwardMove[client] = 380.0;

    if (g_UnstuckDir[client] > 0)
        g_AIButtons[client] |= IN_MOVERIGHT;
    else
        g_AIButtons[client] |= IN_MOVELEFT;
}

public void OnGameFrame()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!g_IsAIControlled[client] || !IsClientInGame(client) || !IsPlayerAlive(client))
            continue;
        AI_Think(client);
    }
}

void AI_Think(int client)
{
    g_AIButtons[client]     = 0;
    g_AIForwardMove[client] = 0.0;
    g_AISideMove[client]    = 0.0;

    if (!IsPlayerAlive(client))
        return;

    float origin[3], eye[3];
    GetClientAbsOrigin(client, origin);
    GetClientEyePosition(client, eye);

    float now = GetGameTime();

    // ---- Combat target selection (stickier + last known) ----
    int enemy = g_CombatTarget[client];
    if (enemy > 0)
    {
        if (!IsClientInGame(enemy) || !IsPlayerAlive(enemy) || GetClientTeam(enemy) == GetClientTeam(client))
        {
            enemy = -1;
            g_CombatTarget[client] = -1;
        }
        else
        {
            float epos[3];
            GetClientAbsOrigin(enemy, epos);
            g_LastKnownEnemyPos[client][0] = epos[0];
            g_LastKnownEnemyPos[client][1] = epos[1];
            g_LastKnownEnemyPos[client][2] = epos[2] + 20.0;
            g_HasLastKnownEnemy[client] = true;
            g_LastKnownEnemyTime[client] = now;

            // Drop only if very far and not recently seen
            float d = GetVectorDistance(origin, epos);
            if (d > 3200.0 && !IsTargetVisible(client, enemy))
            {
                enemy = -1;
                g_CombatTarget[client] = -1;
            }
        }
    }

    if (enemy <= 0)
    {
        int cand = FindBestEnemy(client);
        if (cand > 0)
        {
            enemy = cand;
            g_CombatTarget[client] = cand;
            g_HasEgress[client] = false;
            g_PathIndex[client] = -1;
            g_PathGoalIndex[client] = -1;
            g_NextRepath[client] = 0.0;

            float epos[3];
            GetClientAbsOrigin(cand, epos);
            g_LastKnownEnemyPos[client][0] = epos[0];
            g_LastKnownEnemyPos[client][1] = epos[1];
            g_LastKnownEnemyPos[client][2] = epos[2] + 20.0;
            g_HasLastKnownEnemy[client] = true;
            g_LastKnownEnemyTime[client] = now;
        }
    }

    // Expire last-known after 6s
    if (g_HasLastKnownEnemy[client] && (now - g_LastKnownEnemyTime[client]) > 6.0)
        g_HasLastKnownEnemy[client] = false;

    float goal[3];
    bool  haveGoal = false;

    if (enemy > 0)
    {
        GetClientAbsOrigin(enemy, goal);
        goal[2] += 20.0;
        haveGoal = true;
    }
    else if (g_HasLastKnownEnemy[client])
    {
        goal[0] = g_LastKnownEnemyPos[client][0];
        goal[1] = g_LastKnownEnemyPos[client][1];
        goal[2] = g_LastKnownEnemyPos[client][2];
        haveGoal = true;

        if (GetVectorDistance(origin, goal) < 120.0)
            g_HasLastKnownEnemy[client] = false;
    }
    else if (g_HasEgress[client])
    {
        goal[0] = g_EgressGoal[client][0];
        goal[1] = g_EgressGoal[client][1];
        goal[2] = g_EgressGoal[client][2];
        haveGoal = true;

        if (GetVectorDistance(origin, goal) < 200.0)
        {
            g_HasEgress[client] = false;
            if (FindFrontObjective(client, goal))
                haveGoal = true;
        }
    }
    else
    {
        haveGoal = FindFrontObjective(client, goal);
        if (!haveGoal)
        {
            float ang[3], fwd[3];
            GetClientEyeAngles(client, ang);
            GetAngleVectors(ang, fwd, NULL_VECTOR, NULL_VECTOR);
            goal[0] = origin[0] + fwd[0] * 1000.0;
            goal[1] = origin[1] + fwd[1] * 1000.0;
            goal[2] = origin[2];
            haveGoal = true;
        }
    }

    if (!haveGoal)
        return;

    bool pathDone = (g_PathPositions[client] == null)
                 || (g_PathIndex[client] < 0)
                 || (g_PathIndex[client] >= g_PathPositions[client].Length);

    if (pathDone || now >= g_NextRepath[client])
    {
        BuildSimplePath(client, goal);
        g_NextRepath[client] = now + ((enemy > 0) ? 0.55 : 1.25);
    }

    float pullTarget[3];
    bool  havePull = GetPulledPathTarget(client, pullTarget);

    float curAng[3];
    GetClientEyeAngles(client, curAng);

    float wantPitch = 0.0;
    float wantYaw   = curAng[1];

    if (enemy > 0 && IsTargetVisible(client, enemy))
    {
        float tpos[3];
        GetClientEyePosition(enemy, tpos);
        tpos[2] -= 10.0;

        float dir[3], ang[3];
        SubtractVectors(tpos, eye, dir);
        GetVectorAngles(dir, ang);
        wantPitch = ang[0];
        wantYaw   = ang[1];

        if (wantPitch > 22.0)  wantPitch = 22.0;
        if (wantPitch < -25.0) wantPitch = -25.0;
    }
    else if (havePull)
    {
        float dir[3], ang[3];
        SubtractVectors(pullTarget, eye, dir);
        dir[2] = 0.0;
        if (GetVectorLength(dir) > 1.0)
        {
            GetVectorAngles(dir, ang);
            wantYaw = ang[1];
        }
        wantPitch = 0.0;
    }

    g_LookAt[client][0] = ApproachAngle(curAng[0], wantPitch, 18.0);
    g_LookAt[client][1] = ApproachAngle(curAng[1], wantYaw,   28.0);
    g_LookAt[client][2] = 0.0;

    float yawErr = FloatAbs(AngleDiff(wantYaw, curAng[1]));
    // Only hard-snap when error is large (less jank on stairs)
    if (yawErr > 18.0 || FloatAbs(wantPitch - curAng[0]) > 16.0)
        TeleportEntity(client, NULL_VECTOR, g_LookAt[client], NULL_VECTOR);

    FollowCurrentPath(client);
    ApplyNudge(client);
    UpdateUnstuck(client);
    ApplyUnstuck(client);

    if (havePull && now > g_UnstuckUntil[client])
    {
        float toTarget[3];
        SubtractVectors(pullTarget, origin, toTarget);
        toTarget[2] = 0.0;

        if (GetVectorLength(toTarget) > 1.0)
        {
            float wantMove[3];
            GetVectorAngles(toTarget, wantMove);
            float err = FloatAbs(AngleDiff(wantMove[1], g_LookAt[client][1]));

            if (err > 40.0 && (FloatAbs(g_AIForwardMove[client]) > 40.0 || g_AISideMove[client] != 0.0))
            {
                if (g_HighYawSince[client] <= 0.0)
                    g_HighYawSince[client] = now;
                else if (now - g_HighYawSince[client] > 0.35)
                {
                    g_NextRepath[client]   = 0.0;
                    g_PathIndex[client]    = -1;
                    g_HighYawSince[client] = 0.0;
                }
            }
            else
                g_HighYawSince[client] = 0.0;
        }
    }

    if (now > g_UnstuckUntil[client]
        && now > g_BlockedUntil[client]
        && FloatAbs(g_AIForwardMove[client]) < 50.0
        && FloatAbs(g_AISideMove[client]) < 50.0)
    {
        g_AIForwardMove[client] = 300.0;
        g_AIButtons[client]    |= IN_FORWARD;
    }

    TFClassType cls = TF2_GetPlayerClass(client);

    if (cls == TFClass_Spy)
        AI_SpyThink(client, enemy);
    else if (cls == TFClass_Engineer)
        AI_EngineerThink(client, enemy);

    bool engBusy = false;
    if (cls == TFClass_Engineer)
    {
        if (g_EngStage[client] < ENG_STAGE_HOLD || now < g_EngDeployGuard[client])
            engBusy = true;

        if (!engBusy && FindFriendlySentry(client) <= 0)
            engBusy = (g_BuildState[client] != 0);

        int s = FindFriendlySentry(client);
        if (s > 0 && !engBusy)
        {
            int lvl   = GetEntProp(s, Prop_Send, "m_iUpgradeLevel");
            int hp    = GetEntProp(s, Prop_Send, "m_iHealth");
            int maxhp = GetEntProp(s, Prop_Send, "m_iMaxHealth");
            if (lvl < 3 || hp < maxhp)
                engBusy = true;
        }
    }

    if (enemy > 0 && !engBusy)
        AI_Combat(client, enemy, eye, goal, wantYaw);
    else if (enemy <= 0)
        AI_SupportIdle(client);

    if (g_CvarDebug.BoolValue)
    {
        if (cls == TFClass_Engineer)
        {
            int s   = FindFriendlySentry(client);
            int lvl = (s > 0) ? GetEntProp(s, Prop_Send, "m_iUpgradeLevel") : 0;
            PrintHintText(client, "eng metal=%d lvl=%d stage=%d busy=%d nav=%d",
                GetEngineerMetal(client), lvl, g_EngStage[client], engBusy ? 1 : 0, g_NavReady ? 1 : 0);
        }
        else
        {
            PrintHintText(client, "idx=%d pull=%d fwd=%.0f yawErr=%.0f tgt=%d lkp=%d",
                g_PathIndex[client], g_PathGoalIndex[client],
                g_AIForwardMove[client], yawErr, enemy, g_HasLastKnownEnemy[client] ? 1 : 0);
        }
    }
}

void AI_Combat(int client, int enemy, const float eye[3], const float goal[3], float wantYaw)
{
    float clientVel[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", clientVel);
    float speed = GetVectorLength(clientVel);
    float dist  = GetVectorDistance(eye, goal);
    float yawDiff = FloatAbs(AngleDiff(wantYaw, g_LookAt[client][1]));
    bool  canSee  = IsTargetVisible(client, enemy);

    TFClassType cls = TF2_GetPlayerClass(client);

    if (canSee && yawDiff < 42.0)
    {
        if (cls == TFClass_Soldier && speed > 100.0)
            g_AIButtons[client] &= ~IN_ATTACK;

        if (cls == TFClass_Scout && dist < 900.0)
            g_AIButtons[client] |= IN_ATTACK;
        else if (cls == TFClass_Soldier && dist < 1600.0)
            g_AIButtons[client] |= IN_ATTACK;
        else if (cls == TFClass_Pyro && dist < 450.0)
            g_AIButtons[client] |= IN_ATTACK;
        else if (cls == TFClass_DemoMan && dist < 1400.0)
            g_AIButtons[client] |= IN_ATTACK;
        else if (cls == TFClass_Heavy && dist < 1200.0)
        {
            g_AIButtons[client] |= IN_ATTACK2;
            g_AIButtons[client] |= IN_ATTACK;
        }
        else if (cls == TFClass_Engineer && dist < 900.0)
            g_AIButtons[client] |= IN_ATTACK;
        else if (cls == TFClass_Medic && dist < 350.0)
            g_AIButtons[client] |= IN_ATTACK;
        else if (cls == TFClass_Sniper)
        {
            if (dist > 350.0 && dist < 2200.0)
            {
                g_AIButtons[client] |= IN_ATTACK2;
                if (yawDiff < 12.0)
                    g_AIButtons[client] |= IN_ATTACK;
            }
            else if (dist <= 350.0)
                g_AIButtons[client] |= IN_ATTACK;
        }
        else if (cls == TFClass_Spy)
        {
            if (dist < 150.0)
                g_AIButtons[client] |= IN_ATTACK;
            else if (dist < 900.0 && canSee)
                g_AIButtons[client] |= IN_ATTACK;
        }
        else if (dist < 1100.0)
            g_AIButtons[client] |= IN_ATTACK;
    }

    if (canSee && dist < 1000.0 && GetGameTime() > g_UnstuckUntil[client] && cls != TFClass_Spy)
    {
        float t = GetGameTime();
        g_AISideMove[client] = (Sine(t * 2.5) > 0.0) ? 280.0 : -280.0;
        if (g_AISideMove[client] > 0.0)
            g_AIButtons[client] |= IN_MOVERIGHT;
        else
            g_AIButtons[client] |= IN_MOVELEFT;
    }
}

void AI_SupportIdle(int client)
{
    if (TF2_GetPlayerClass(client) != TFClass_Medic)
        return;

    int mate = FindHurtTeammate(client);
    if (mate <= 0)
        return;

    float eye[3], tpos[3], matePos[3];
    GetClientEyePosition(client, eye);
    GetClientEyePosition(mate, tpos);
    GetClientAbsOrigin(mate, matePos);

    float dir[3], ang[3];
    SubtractVectors(tpos, eye, dir);
    GetVectorAngles(dir, ang);

    float cur[3];
    GetClientEyeAngles(client, cur);

    g_LookAt[client][0] = ApproachAngle(cur[0], ang[0], 14.0);
    g_LookAt[client][1] = ApproachAngle(cur[1], ang[1], 20.0);
    g_LookAt[client][2] = 0.0;

    if (FloatAbs(AngleDiff(ang[1], cur[1])) > 25.0)
        TeleportEntity(client, NULL_VECTOR, g_LookAt[client], NULL_VECTOR);

    float dist = GetVectorDistance(eye, tpos);
    if (dist > 400.0)
    {
        if (GetGameTime() >= g_NextRepath[client])
        {
            BuildSimplePath(client, matePos);
            g_NextRepath[client] = GetGameTime() + 1.0;
        }
    }
    else if (dist < 550.0)
        g_AIButtons[client] |= IN_ATTACK;
}

// =====================================================
// ENGINEER HELPERS
// =====================================================

bool EngIsCarrying(int client)
{
    if (HasEntProp(client, Prop_Send, "m_bCarryingObject") &&
        GetEntProp(client, Prop_Send, "m_bCarryingObject") != 0)
        return true;
    return false;
}

bool EngIsInBuildMode(int client)
{
    // Carrying a building
    if (HasEntProp(client, Prop_Send, "m_bCarryingObject") &&
        GetEntProp(client, Prop_Send, "m_bCarryingObject") != 0)
        return true;

    // Toolbox / placement weapon is active
    int wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (wep > MaxClients && IsValidEntity(wep))
    {
        char cls[64];
        GetEntityClassname(wep, cls, sizeof(cls));
        if (StrEqual(cls, "tf_weapon_builder"))
            return true;
    }
    return false;
}

int FindFriendlySentry(int client)
{
    int myTeam = GetClientTeam(client);
    int best   = -1;
    float bestD = 999999.0;
    float myPos[3];
    GetClientAbsOrigin(client, myPos);

    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
    {
        if (!IsValidEntity(ent))
            continue;
        if (GetEntProp(ent, Prop_Send, "m_iTeamNum") != myTeam)
            continue;

        int builder = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
        if (builder != client)
            continue;

        float pos[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
        float d = GetVectorDistance(myPos, pos);
        if (d < bestD)
        {
            bestD = d;
            best  = ent;
        }
    }
    return best;
}

int GetEngineerMetal(int client)
{
    int m = GetEntProp(client, Prop_Data, "m_iAmmo", _, 3);
    if (m < 0)
        m = 0;
    return m;
}

int FindFriendlyDispenser(int client)
{
    int myTeam = GetClientTeam(client);
    int best   = -1;
    float bestD = 999999.0;
    float myPos[3];
    GetClientAbsOrigin(client, myPos);

    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
    {
        if (!IsValidEntity(ent))
            continue;
        if (GetEntProp(ent, Prop_Send, "m_iTeamNum") != myTeam)
            continue;

        float pos[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
        float d = GetVectorDistance(myPos, pos);
        if (d < bestD)
        {
            bestD = d;
            best  = ent;
        }
    }
    return best;
}

void EngEquipWrench(int client)
{
    // Do NOT steal the toolbox while placing/carrying
    if (EngIsInBuildMode(client))
        return;

    int wrench = GetPlayerWeaponSlot(client, 2);
    if (wrench > 0 && IsValidEntity(wrench))
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", wrench);
}

void EngEquipBuilder(int client)
{
    int builder = GetPlayerWeaponSlot(client, 5);
    if (builder <= 0 || !IsValidEntity(builder))
    {
        for (int i = 0; i < 8; i++)
        {
            int w = GetPlayerWeaponSlot(client, i);
            if (w <= 0 || !IsValidEntity(w))
                continue;
            char cls[64];
            GetEntityClassname(w, cls, sizeof(cls));
            if (StrEqual(cls, "tf_weapon_builder"))
            {
                builder = w;
                break;
            }
        }
    }
    if (builder > 0 && IsValidEntity(builder))
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", builder);
}

void EngFaceEntity(int client, int ent)
{
    float eye[3], tpos[3], dir[3], ang[3];
    GetClientEyePosition(client, eye);
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", tpos);
    tpos[2] += 20.0;
    SubtractVectors(tpos, eye, dir);
    GetVectorAngles(dir, ang);

    g_LookAt[client][0] = ang[0];
    g_LookAt[client][1] = ang[1];
    g_LookAt[client][2] = 0.0;
    TeleportEntity(client, NULL_VECTOR, g_LookAt[client], NULL_VECTOR);
}

void EngFacePlaceYaw(int client)
{
    float ang[3];
    GetClientEyeAngles(client, ang);
    ang[0] = 22.0; // mild look-down, not extreme
    ang[1] = g_EngPlaceYaw[client];
    ang[2] = 0.0;
    g_LookAt[client][0] = ang[0];
    g_LookAt[client][1] = ang[1];
    g_LookAt[client][2] = 0.0;
    TeleportEntity(client, NULL_VECTOR, g_LookAt[client], NULL_VECTOR);
}

void EngWrenchTarget(int client, int ent)
{
    EngEquipWrench(client);
    EngFaceEntity(client, ent);
    g_AIButtons[client] |= IN_ATTACK;

    float myPos[3], bPos[3];
    GetClientAbsOrigin(client, myPos);
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", bPos);
    float d = GetVectorDistance(myPos, bPos);

    if (d < 95.0)
    {
        g_AIForwardMove[client] = 0.0;
        g_AISideMove[client]    = 0.0;
        g_AIButtons[client]    &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT);
    }
    else if (GetGameTime() >= g_NextRepath[client])
    {
        BuildSimplePath(client, bPos);
        g_NextRepath[client] = GetGameTime() + 0.4;
    }
}

void EngUpdatePlaceYaw(int client, int enemy)
{
    // Prefer facing last known / current enemy so sentry points toward threat
    if (enemy > 0 && IsClientInGame(enemy) && IsPlayerAlive(enemy))
    {
        float myPos[3], epos[3], dir[3], ang[3];
        GetClientAbsOrigin(client, myPos);
        GetClientAbsOrigin(enemy, epos);
        SubtractVectors(epos, myPos, dir);
        dir[2] = 0.0;
        if (GetVectorLength(dir) > 1.0)
        {
            GetVectorAngles(dir, ang);
            g_EngPlaceYaw[client] = ang[1];
            return;
        }
    }

    if (g_HasLastKnownEnemy[client])
    {
        float myPos[3], dir[3], ang[3];
        GetClientAbsOrigin(client, myPos);
        SubtractVectors(g_LastKnownEnemyPos[client], myPos, dir);
        dir[2] = 0.0;
        if (GetVectorLength(dir) > 1.0)
        {
            GetVectorAngles(dir, ang);
            g_EngPlaceYaw[client] = ang[1];
            return;
        }
    }

    float ang[3];
    GetClientEyeAngles(client, ang);
    g_EngPlaceYaw[client] = ang[1];
}

void Eng_RunBuildSentryFSM(int client, int enemy, int metal)
{
    float now = GetGameTime();

    if (enemy > 0)
    {
        float myPos[3], enemyPos[3];
        GetClientAbsOrigin(client, myPos);
        GetClientAbsOrigin(enemy, enemyPos);
        float dist = GetVectorDistance(myPos, enemyPos);

        g_EngLastEnemy[client]     = enemy;
        g_EngLastEnemySeen[client] = now;

        if (dist < 450.0)
            g_EngDangerUntil[client] = now + 4.0;
        else if (dist < 850.0)
            g_EngDangerUntil[client] = now + 2.0;
    }

    if (now < g_EngDangerUntil[client])
        return;

    if (metal < 130)
    {
        int disp = FindFriendlyDispenser(client);
        if (disp > 0)
        {
            float pos[3];
            GetEntPropVector(disp, Prop_Send, "m_vecOrigin", pos);
            if (now >= g_NextRepath[client])
            {
                BuildSimplePath(client, pos);
                g_NextRepath[client] = now + 1.0;
            }
        }
        return;
    }

    if (FindFriendlySentry(client) > 0)
    {
        g_BuildState[client]    = 0;
        g_IsInBuildMode[client] = false;
        return;
    }

    EngUpdatePlaceYaw(client, enemy);

    // State 0: request build
    if (g_BuildState[client] == 0)
    {
        if (now < g_NextBuildTry[client])
            return;

        g_AIForwardMove[client] = 0.0;
        g_AISideMove[client]    = 0.0;
        g_AIButtons[client]    &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT);

        FakeClientCommand(client, "build 2");
        EngEquipBuilder(client);

        g_BuildState[client]     = 1;
        g_IsInBuildMode[client]  = false;
        g_NextBuildTry[client]   = now + 0.30;
        g_NextBuildCheck[client] = now + 1.6;
        g_EngStageUntil[client]  = now + 5.5;
        return;
    }

    // State 1: place
    if (g_BuildState[client] == 1)
    {
        // ALWAYS keep toolbox active while placing
        EngEquipBuilder(client);

        if (now >= g_NextBuildCheck[client] && !EngIsInBuildMode(client))
        {
            FakeClientCommand(client, "destroy 2"); // cleanup if partial
            FakeClientCommand(client, "build 0");
            g_IsInBuildMode[client] = false;
            g_BuildState[client]    = 0;
            g_NextBuildTry[client]  = now + 2.0;
            return;
        }

        if (!g_IsInBuildMode[client] && EngIsInBuildMode(client))
        {
            g_IsInBuildMode[client] = true;
            g_EngStageUntil[client] = now + 4.0;
        }

        if (!g_IsInBuildMode[client])
        {
            EngFacePlaceYaw(client);
            return;
        }

        EngFacePlaceYaw(client);

        g_AIForwardMove[client] = 0.0;
        g_AISideMove[client]    = 0.0;
        g_AIButtons[client]    &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_JUMP | IN_DUCK);

        float eye[3], end[3];
        GetClientEyePosition(client, eye);
        end[0] = eye[0];
        end[1] = eye[1];
        end[2] = eye[2] - 90.0;

        Handle tr = TR_TraceRayFilterEx(eye, end, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_NoPlayers, client);
        bool goodGround = TR_DidHit(tr);
        if (goodGround)
        {
            float normal[3];
            TR_GetPlaneNormal(tr, normal);
            if (normal[2] < 0.65)
                goodGround = false;
        }
        delete tr;

        if (now >= g_NextBuildTry[client])
        {
            if (goodGround)
                g_AIButtons[client] |= IN_ATTACK;
            g_NextBuildTry[client] = now + 0.28;
        }

        if (FindFriendlySentry(client) > 0)
        {
            g_BuildState[client]     = 0;
            g_IsInBuildMode[client]  = false;
            g_NextBuildTry[client]   = now + 3.5;
            g_EngDeployGuard[client] = now + 2.5;
            return;
        }

        if (now > g_EngStageUntil[client])
        {
            FakeClientCommand(client, "build 0");
            g_IsInBuildMode[client] = false;
            g_BuildState[client]    = 0;
            g_NextBuildTry[client]  = now + 1.8;

            // Small lateral nudge for next attempt
            float pos[3], ang[3], right[3];
            GetClientAbsOrigin(client, pos);
            GetClientEyeAngles(client, ang);
            GetAngleVectors(ang, NULL_VECTOR, right, NULL_VECTOR);
            float side = (GetRandomFloat(0.0, 1.0) > 0.5) ? 40.0 : -40.0;
            pos[0] += right[0] * side;
            pos[1] += right[1] * side;
            TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
        }
        return;
    }

    if (g_BuildState[client] == 2)
    {
        g_AIButtons[client] |= IN_ATTACK;
        if (now >= g_NextBuildTry[client])
        {
            g_BuildState[client] = 0;
            g_NextBuildTry[client] = now + (FindFriendlySentry(client) > 0 ? 6.0 : 2.5);
        }
    }
}

void AI_EngineerThink(int client, int enemy)
{
    float now = GetGameTime();
    float myPos[3];
    GetClientAbsOrigin(client, myPos);

    int  sentry   = FindFriendlySentry(client);
    int  metal    = GetEngineerMetal(client);
    bool carrying = EngIsCarrying(client);

    if ((g_BuildState[client] == 1 || g_EngStage[client] == ENG_STAGE_DEPLOY) &&
        EngIsInBuildMode(client))
    {
        g_AIForwardMove[client] = 0.0;
        g_AISideMove[client]    = 0.0;
        g_AIButtons[client]    &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_JUMP);
    }

    if (carrying && g_EngStage[client] < ENG_STAGE_HAUL)
        g_EngStage[client] = ENG_STAGE_HAUL;

    switch (g_EngStage[client])
    {
        case ENG_STAGE_SPAWN_BUILD:
        {
            if (sentry > 0)
            {
                g_EngStage[client] = ENG_STAGE_UPGRADE;
                return;
            }
            Eng_RunBuildSentryFSM(client, enemy, metal);
            return;
        }

        case ENG_STAGE_UPGRADE:
        {
            if (sentry <= 0)
            {
                g_EngStage[client] = ENG_STAGE_SPAWN_BUILD;
                return;
            }

            int level = GetEntProp(sentry, Prop_Send, "m_iUpgradeLevel");
            if (level >= 3)
            {
                g_EngStage[client]      = ENG_STAGE_PACK;
                g_EngStageUntil[client] = now + 7.0;
                return;
            }

            EngWrenchTarget(client, sentry);
            return;
        }

        case ENG_STAGE_PACK:
        {
            if (carrying)
            {
                g_EngStage[client] = ENG_STAGE_HAUL;

                if (FindFrontObjective(client, g_EngFrontGoal[client]))
                    g_EngHasFrontGoal[client] = true;
                else
                {
                    g_EngFrontGoal[client][0] = g_EgressGoal[client][0];
                    g_EngFrontGoal[client][1] = g_EgressGoal[client][1];
                    g_EngFrontGoal[client][2] = g_EgressGoal[client][2];
                    g_EngHasFrontGoal[client] = true;
                }
                return;
            }

            if (sentry <= 0)
            {
                g_EngStage[client] = ENG_STAGE_SPAWN_BUILD;
                return;
            }

            EngEquipWrench(client);
            EngFaceEntity(client, sentry);
            g_AIButtons[client]     |= IN_ATTACK2;
            g_AIForwardMove[client]  = 0.0;
            g_AISideMove[client]     = 0.0;

            if (now > g_EngStageUntil[client])
                g_EngStage[client] = ENG_STAGE_HOLD;
            return;
        }

        case ENG_STAGE_HAUL:
        {
            if (!carrying)
            {
                g_EngStage[client] = ENG_STAGE_HOLD;
                return;
            }

            float dest[3];
            if (g_EngHasFrontGoal[client])
            {
                dest[0] = g_EngFrontGoal[client][0];
                dest[1] = g_EngFrontGoal[client][1];
                dest[2] = g_EngFrontGoal[client][2];
            }
            else
            {
                dest[0] = myPos[0];
                dest[1] = myPos[1];
                dest[2] = myPos[2];
            }

            float d = GetVectorDistance(myPos, dest);
            if (d < 220.0)
            {
                g_EngStage[client]      = ENG_STAGE_DEPLOY;
                g_EngStageUntil[client] = now + 3.5;
                EngUpdatePlaceYaw(client, enemy);
                return;
            }

            if (now >= g_NextRepath[client])
            {
                BuildSimplePath(client, dest);
                g_NextRepath[client] = now + 0.9;
            }
            return;
        }

        case ENG_STAGE_DEPLOY:
        {
            if (!carrying)
            {
                g_EngStage[client] = ENG_STAGE_HOLD;
                return;
            }

            if (!EngIsInBuildMode(client))
            {
                FakeClientCommand(client, "build 2");
                EngEquipBuilder(client);
                g_IsInBuildMode[client] = false;
                g_EngStageUntil[client] = now + 2.0;
                return;
            }

            EngEquipBuilder(client);
            EngUpdatePlaceYaw(client, enemy);
            EngFacePlaceYaw(client);

            g_AIForwardMove[client] = 0.0;
            g_AISideMove[client]    = 0.0;
            g_AIButtons[client]    &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_JUMP);

            float eye[3], end[3];
            GetClientEyePosition(client, eye);
            end[0] = eye[0];
            end[1] = eye[1];
            end[2] = eye[2] - 90.0;

            Handle tr = TR_TraceRayFilterEx(eye, end, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_NoPlayers, client);
            bool canPlace = TR_DidHit(tr);
            if (canPlace)
            {
                float normal[3];
                TR_GetPlaneNormal(tr, normal);
                if (normal[2] < 0.65)
                    canPlace = false;
            }
            delete tr;

            if (now >= g_NextBuildTry[client])
            {
                if (canPlace)
                    g_AIButtons[client] |= IN_ATTACK;
                g_NextBuildTry[client] = now + 0.28;
            }

            if (FindFriendlySentry(client) > 0)
            {
                g_EngDeployGuard[client] = now + 3.5;
                g_EngStage[client]       = ENG_STAGE_HOLD;
                g_IsInBuildMode[client]  = false;
                return;
            }

            if (!canPlace && now > g_EngStageUntil[client] + 1.2)
            {
                float nudge[3], ang[3], right[3];
                GetClientAbsOrigin(client, nudge);
                GetClientEyeAngles(client, ang);
                GetAngleVectors(ang, NULL_VECTOR, right, NULL_VECTOR);
                float side = (GetRandomFloat(0.0, 1.0) > 0.5) ? 48.0 : -48.0;
                nudge[0] += right[0] * side;
                nudge[1] += right[1] * side;
                TeleportEntity(client, nudge, g_LookAt[client], NULL_VECTOR);
                g_EngStageUntil[client] = now + 1.2;
            }
            return;
        }

        case ENG_STAGE_HOLD:
        {
            if (sentry > 0)
            {
                GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", g_EngNestOrigin[client]);
                g_EngHasNest[client] = true;
                g_BuildState[client] = 0;

                float sPos[3];
                GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sPos);

                int hp    = GetEntProp(sentry, Prop_Send, "m_iHealth");
                int maxhp = GetEntProp(sentry, Prop_Send, "m_iMaxHealth");
                int level = GetEntProp(sentry, Prop_Send, "m_iUpgradeLevel");
                float d   = GetVectorDistance(myPos, sPos);

                bool wantUpgrade = (level < 3 && metal >= 25);
                bool wantRepair  = (hp < maxhp - 5);

                if (d > 100.0)
                {
                    if (now >= g_NextRepath[client])
                    {
                        BuildSimplePath(client, sPos);
                        g_NextRepath[client] = now + 0.45;
                    }
                    return;
                }

                if (wantRepair || wantUpgrade)
                {
                    EngWrenchTarget(client, sentry);
                    return;
                }
                return;
            }

            if (enemy > 0)
            {
                float epos[3];
                GetClientAbsOrigin(enemy, epos);
                if (GetVectorDistance(myPos, epos) < 380.0)
                {
                    g_BuildState[client] = 0;
                    if (g_NextBuildTry[client] < now + 2.0)
                        g_NextBuildTry[client] = now + 2.0;
                    return;
                }
            }

            if (metal < 130)
            {
                int disp = FindFriendlyDispenser(client);
                if (disp > 0)
                {
                    float dPos[3];
                    GetEntPropVector(disp, Prop_Send, "m_vecOrigin", dPos);
                    if (now >= g_NextRepath[client])
                    {
                        BuildSimplePath(client, dPos);
                        g_NextRepath[client] = now + 1.0;
                    }
                }
                return;
            }

            Eng_RunBuildSentryFSM(client, enemy, metal);
            return;
        }

        default:
        {
            g_EngStage[client] = ENG_STAGE_HOLD;
            return;
        }
    }
}

// =====================================================
// SPY
// =====================================================
void AI_SpyThink(int client, int enemy)
{
    float now = GetGameTime();
    float myPos[3];
    GetClientAbsOrigin(client, myPos);

    bool cloaked = TF2_IsPlayerInCondition(client, TFCond_Stealthed)
                || TF2_IsPlayerInCondition(client, TFCond_StealthedUserBuffFade)
                || TF2_IsPlayerInCondition(client, TFCond_Cloaked);

    bool disguised = TF2_IsPlayerInCondition(client, TFCond_Disguised);

    if (!disguised && now >= g_NextSlotCmd[client])
    {
        int myTeam    = GetClientTeam(client);
        int enemyTeam = (myTeam == view_as<int>(TFTeam_Red)) ? 2 : 1;
        int dcls = 3;
        int r = GetRandomInt(0, 2);
        if (r == 1) dcls = 5;
        if (r == 2) dcls = 7;

        char cmd[32];
        Format(cmd, sizeof(cmd), "disguise %d %d", dcls, enemyTeam);
        FakeClientCommand(client, cmd);
        g_NextSlotCmd[client] = now + 6.0;
    }

    float dist = 99999.0;
    bool canSee = false;
    if (enemy > 0)
    {
        float epos[3];
        GetClientAbsOrigin(enemy, epos);
        dist   = GetVectorDistance(myPos, epos);
        canSee = IsTargetVisible(client, enemy);
    }

    int revolver = GetPlayerWeaponSlot(client, 0);
    int knife    = GetPlayerWeaponSlot(client, 2);

    if (dist > 180.0)
    {
        if (revolver > 0 && IsValidEntity(revolver))
            SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", revolver);
    }
    else
    {
        if (knife > 0 && IsValidEntity(knife))
            SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", knife);
    }

    bool wantCloak = true;
    if (enemy > 0 && canSee && dist < 900.0)
        wantCloak = false;

    if (wantCloak && !cloaked)
        g_AIButtons[client] |= IN_ATTACK2;
}

// =====================================================
// PATH + LOCAL AVOIDANCE
// =====================================================

bool FindFrontObjective(int client, float outPos[3])
{
    float myPos[3];
    GetClientAbsOrigin(client, myPos);
    int myTeam = GetClientTeam(client);

    int   bestEnt  = -1;
    float bestScore = -999999.0;

    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "team_control_point")) != -1)
    {
        if (!IsValidEntity(ent))
            continue;

        float pos[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
        float dist  = GetVectorDistance(myPos, pos);
        float score = dist;
        if (dist < 400.0)
            score -= 2000.0;

        if (score > bestScore)
        {
            bestScore = score;
            bestEnt   = ent;
        }
    }

    ent = -1;
    while ((ent = FindEntityByClassname(ent, "item_teamflag")) != -1)
    {
        if (!IsValidEntity(ent))
            continue;
        if (GetEntProp(ent, Prop_Send, "m_iTeamNum") == myTeam)
            continue;

        float pos[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
        float score = 5000.0 - GetVectorDistance(myPos, pos);
        if (score > bestScore)
        {
            bestScore = score;
            bestEnt   = ent;
        }
    }

    if (bestEnt == -1)
        return false;

    GetEntPropVector(bestEnt, Prop_Send, "m_vecOrigin", outPos);
    return true;
}

bool TraceWalkClear(int client, const float origin[3], const float dirFlat[3], float dist, float &frac)
{
    float ndir[3];
    ndir[0] = dirFlat[0];
    ndir[1] = dirFlat[1];
    ndir[2] = 0.0;
    if (GetVectorLength(ndir) < 0.01)
    {
        frac = 1.0;
        return true;
    }
    NormalizeVector(ndir, ndir);

    // 3 horizontal offsets (center + left + right) at chest height
    // approximates a player hull without full hull traces
    float side[3];
    side[0] = -ndir[1];
    side[1] =  ndir[0];
    side[2] = 0.0;

    float offsets[3] = { 0.0, 16.0, -16.0 };
    float worstFrac = 1.0;
    bool anyHit = false;
    int doorHit = -1;

    for (int i = 0; i < 3; i++)
    {
        float start[3], end[3];
        start[0] = origin[0] + side[0] * offsets[i];
        start[1] = origin[1] + side[1] * offsets[i];
        start[2] = origin[2] + 36.0;

        end[0] = start[0] + ndir[0] * dist;
        end[1] = start[1] + ndir[1] * dist;
        end[2] = start[2];

        Handle tr = TR_TraceRayFilterEx(start, end, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_WorldAndDoors, client);
        float f = TR_GetFraction(tr);
        if (TR_DidHit(tr) && f < worstFrac)
        {
            worstFrac = f;
            anyHit = true;
            int hitEnt = TR_GetEntityIndex(tr);
            if (hitEnt > MaxClients && IsValidEntity(hitEnt))
            {
                char cls[64];
                GetEntityClassname(hitEnt, cls, sizeof(cls));
                if (StrContains(cls, "door", false) != -1
                    || StrEqual(cls, "func_door", false)
                    || StrEqual(cls, "func_door_rotating", false)
                    || StrEqual(cls, "prop_door_rotating", false)
                    || StrEqual(cls, "func_movelinear", false))
                {
                    doorHit = hitEnt;
                }
            }
        }
        delete tr;
    }

    // Knee-height check (catches low brushes / steps that chest misses)
    {
        float start[3], end[3];
        start[0] = origin[0];
        start[1] = origin[1];
        start[2] = origin[2] + 18.0;
        end[0] = start[0] + ndir[0] * dist;
        end[1] = start[1] + ndir[1] * dist;
        end[2] = start[2];

        Handle tr = TR_TraceRayFilterEx(start, end, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_WorldAndDoors, client);
        float f = TR_GetFraction(tr);
        if (TR_DidHit(tr) && f < worstFrac)
        {
            worstFrac = f;
            anyHit = true;
        }
        delete tr;
    }

    frac = worstFrac;

    if (doorHit > 0)
    {
        g_DoorEnt[client] = doorHit;
        if (g_DoorState[client] == 0)
        {
            g_DoorState[client] = 1; // approach
            g_DoorUseUntil[client] = GetGameTime() + 1.2;
        }
    }

    if (!anyHit || frac > 0.90)
        return true;
    if (frac > 0.82)
        return true;
    return false;
}

public bool TraceFilter_WorldAndDoors(int entity, int contentsMask, any data)
{
    if (entity == data)
        return false;
    if (entity > 0 && entity <= MaxClients)
        return false;
    // ignore non-solid clutter
    return true;
}

void TryUseNearbyDoor(int client)
{
    float now = GetGameTime();

    // Timed-out door attempt → reset
    if (g_DoorState[client] != 0 && now > g_DoorUseUntil[client] + 1.5)
    {
        g_DoorState[client] = 0;
        g_DoorEnt[client] = -1;
        return;
    }

    if (g_DoorState[client] == 0)
    {
        // Opportunistic probe in look direction
        float eye[3], ang[3], fwd[3], end[3];
        GetClientEyePosition(client, eye);
        GetClientEyeAngles(client, ang);
        GetAngleVectors(ang, fwd, NULL_VECTOR, NULL_VECTOR);
        end[0] = eye[0] + fwd[0] * 64.0;
        end[1] = eye[1] + fwd[1] * 64.0;
        end[2] = eye[2];

        Handle tr = TR_TraceRayFilterEx(eye, end, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_WorldAndDoors, client);
        if (TR_DidHit(tr))
        {
            int hit = TR_GetEntityIndex(tr);
            if (hit > MaxClients && IsValidEntity(hit))
            {
                char cls[64];
                GetEntityClassname(hit, cls, sizeof(cls));
                if (StrContains(cls, "door", false) != -1)
                {
                    g_DoorEnt[client] = hit;
                    g_DoorState[client] = 1;
                    g_DoorUseUntil[client] = now + 1.5;
                }
            }
        }
        delete tr;
        return;
    }

    int door = g_DoorEnt[client];
    if (door <= MaxClients || !IsValidEntity(door))
    {
        g_DoorState[client] = 0;
        g_DoorEnt[client] = -1;
        return;
    }

    float myPos[3], doorPos[3];
    GetClientAbsOrigin(client, myPos);
    GetEntPropVector(door, Prop_Send, "m_vecOrigin", doorPos);

    // Face the door
    float eye[3], dir[3], ang[3];
    GetClientEyePosition(client, eye);
    SubtractVectors(doorPos, eye, dir);
    dir[2] = 0.0;
    if (GetVectorLength(dir) > 1.0)
    {
        GetVectorAngles(dir, ang);
        g_LookAt[client][0] = 0.0;
        g_LookAt[client][1] = ang[1];
        g_LookAt[client][2] = 0.0;
    }

    float dist = GetVectorDistance(myPos, doorPos);

    if (g_DoorState[client] == 1) // approach
    {
        // Creep forward until close, then use
        if (dist > 80.0)
        {
            g_AIForwardMove[client] = 180.0;
            g_AIButtons[client] |= IN_FORWARD;
        }
        else
        {
            g_AIForwardMove[client] = 0.0;
            g_AISideMove[client] = 0.0;
            g_DoorState[client] = 2;
            g_DoorWaitUntil[client] = now + 0.35;
        }
        return;
    }

    if (g_DoorState[client] == 2) // use
    {
        g_AIForwardMove[client] = 0.0;
        g_AISideMove[client] = 0.0;
        g_AIButtons[client] |= IN_USE;

        if (now >= g_DoorWaitUntil[client])
        {
            g_DoorState[client] = 3;
            g_DoorWaitUntil[client] = now + 0.55;
        }
        return;
    }

    if (g_DoorState[client] == 3) // wait for open, then push through
    {
        g_AIButtons[client] |= IN_USE;
        g_AIForwardMove[client] = 220.0;
        g_AIButtons[client] |= IN_FORWARD;

        if (now >= g_DoorWaitUntil[client])
        {
            g_DoorState[client] = 0;
            g_DoorEnt[client] = -1;
            g_NextRepath[client] = 0.0; // repath after crossing
        }
        return;
    }
}

void BuildSimplePath(int client, const float goal[3])
{
    if (g_PathPositions[client] == null)
        return;

    g_PathPositions[client].Clear();
    g_PathIndex[client]     = -1;
    g_PathGoalIndex[client] = -1;

    float start[3];
    GetClientAbsOrigin(client, start);
    start[2] += 4.0;

    int team = GetClientTeam(client);

    CNavArea startArea = TheNavMesh.GetNearestNavArea(start, false, 500.0, false, true, team);
    CNavArea goalArea  = TheNavMesh.GetNearestNavArea(goal,  false, 500.0, false, true, team);

    if (startArea == NULL_AREA)
        startArea = TheNavMesh.GetNearestNavArea(start, true, 1000.0, false, false, team);
    if (goalArea == NULL_AREA)
        goalArea = TheNavMesh.GetNearestNavArea(goal, true, 1000.0, false, false, team);

    if (startArea == NULL_AREA || goalArea == NULL_AREA)
    {
        // Absolute fallback: single goal, local avoidance will steer
        g_PathPositions[client].PushArray(goal, 3);
        g_PathIndex[client] = 0;
        return;
    }

    if (startArea == goalArea)
    {
        float close[3];
        goalArea.GetClosestPointOnArea(goal, close);
        // Lift slightly so we don't aim into the floor lip
        close[2] += 2.0;
        g_PathPositions[client].PushArray(close, 3);
        g_PathPositions[client].PushArray(goal, 3);
        g_PathIndex[client] = 0;
        return;
    }

    CNavArea closest = NULL_AREA;
    if (!TheNavMesh.BuildPath(startArea, goalArea, goal, PathCostHeightAware, closest, 0.0, team, false)
        || closest == NULL_AREA)
    {
        g_PathPositions[client].PushArray(goal, 3);
        g_PathIndex[client] = 0;
        return;
    }

    // Walk parent chain into a temporary list (goal -> start)
    ArrayList areas = new ArrayList();
    CNavArea a = closest;
    while (a != NULL_AREA)
    {
        areas.Push(a);
        a = a.GetParent();
    }

    // areas is [goalArea ... startArea]. Reverse into path points using
    // closest-point stepping so we hug walkable space, not centers.
    float prevPt[3];
    GetClientAbsOrigin(client, prevPt);

    for (int i = areas.Length - 1; i >= 0; i--)
    {
        CNavArea cur = view_as<CNavArea>(areas.Get(i));
        if (cur == NULL_AREA)
            continue;

        // Skip blocked areas when possible
        if (cur.IsBlocked(team, false) && i > 0)
            continue;

        float pt[3], center[3];
        cur.GetCenter(center);
        cur.GetClosestPointOnArea(prevPt, pt);
        // Bias toward center so we don't hug walls
        pt[0] = pt[0] * 0.35 + center[0] * 0.65;
        pt[1] = pt[1] * 0.35 + center[1] * 0.65;
        pt[2] = center[2] + 2.0;

        if (g_PathPositions[client].Length > 0)
        {
            float last[3];
            g_PathPositions[client].GetArray(g_PathPositions[client].Length - 1, last, 3);
            if (GetVectorDistance(last, pt) < 40.0)
            {
                prevPt[0] = pt[0];
                prevPt[1] = pt[1];
                prevPt[2] = pt[2];
                continue;
            }
        }

        g_PathPositions[client].PushArray(pt, 3);
        prevPt[0] = pt[0];
        prevPt[1] = pt[1];
        prevPt[2] = pt[2];
    }

    float goalClose[3];
    goalArea.GetClosestPointOnArea(goal, goalClose);
    goalClose[2] += 2.0;
    g_PathPositions[client].PushArray(goalClose, 3);
    g_PathPositions[client].PushArray(goal, 3);

    delete areas;
    g_PathIndex[client] = 0;
}

public float PathCostHeightAware(CNavArea area, CNavArea fromArea, CNavLadder ladder, int elevator, float length)
{
    if (fromArea == NULL_AREA)
        return 0.0;

    float dist = length;
    if (dist <= 0.0)
    {
        float a[3], b[3];
        area.GetCenter(a);
        fromArea.GetCenter(b);
        dist = GetVectorDistance(a, b);
    }

    float cost = dist + fromArea.GetCostSoFar();

    float dz = fromArea.ComputeAdjacentConnectionHeightChange(area);
    if (dz > 0.0)
    {
        cost += dz * 2.0;
        if (dz > 72.0)
            cost += 220.0;
    }
    else if (dz < 0.0)
    {
        float drop = -dz;
        cost += drop * 0.55;
        if (drop > 200.0)
            cost += 450.0;
        else if (drop > 100.0)
            cost += 90.0;
    }

    if (ladder != NULL_LADDER_AREA)
        cost += ladder.Length * 0.45;

    if (area.HasAttributes(NAV_MESH_CROUCH))
        cost += 20.0;
    if (area.HasAttributes(NAV_MESH_JUMP))
        cost += 12.0;
    if (area.HasAttributes(NAV_MESH_AVOID))
        cost += 40.0;

    return cost;
}

bool GetPulledPathTarget(int client, float outPos[3])
{
    if (g_PathPositions[client] == null || g_PathIndex[client] < 0)
        return false;

    int len = g_PathPositions[client].Length;
    if (g_PathIndex[client] >= len)
        return false;

    float origin[3];
    GetClientAbsOrigin(client, origin);

    // Consume only when close in XY; keep Z separate so stairs aren't skipped
    while (g_PathIndex[client] < len)
    {
        float node[3];
        g_PathPositions[client].GetArray(g_PathIndex[client], node, 3);

        float dx = node[0] - origin[0];
        float dy = node[1] - origin[1];
        float flat = SquareRoot(dx * dx + dy * dy);
        float zDist = FloatAbs(node[2] - origin[2]);

        float need = 44.0;
        if (zDist > 18.0)
            need = 28.0;

        if (flat > need)
            break;

        g_PathIndex[client]++;
    }

    if (g_PathIndex[client] >= len)
        return false;

    // Do NOT skip ahead through walls: only advance along visible chain a little
    int best = g_PathIndex[client];
    int limit = best + 4; // was 10–12; that was skipping around corners into walls
    if (limit > len - 1)
        limit = len - 1;

    for (int i = best + 1; i <= limit; i++)
    {
        float node[3];
        g_PathPositions[client].GetArray(i, node, 3);
        if (!IsPointVisible(client, node))
            break;
        best = i;
    }

    g_PathGoalIndex[client] = best;
    g_PathPositions[client].GetArray(best, outPos, 3);

    if (best + 1 < len)
    {
        float next[3];
        g_PathPositions[client].GetArray(best + 1, next, 3);
        if (next[2] > outPos[2] + 12.0)
        {
            outPos[0] = outPos[0] * 0.4 + next[0] * 0.6;
            outPos[1] = outPos[1] * 0.4 + next[1] * 0.6;
            outPos[2] = next[2];
        }
    }
    return true;
}

void FollowCurrentPath(int client)
{
    g_AIForwardMove[client] = 0.0;
    g_AISideMove[client]    = 0.0;

    // Door state machine owns movement while active
    if (g_DoorState[client] != 0)
    {
        TryUseNearbyDoor(client);
        return;
    }

    float target[3];
    if (!GetPulledPathTarget(client, target))
        return;

    float origin[3];
    GetClientAbsOrigin(client, origin);

    float to[3];
    SubtractVectors(target, origin, to);
    float dz = to[2];
    to[2] = 0.0;

    float flatLen = GetVectorLength(to);
    if (flatLen < 1.0 && FloatAbs(dz) < 8.0)
        return;

    if (flatLen >= 1.0)
        NormalizeVector(to, to);
    else
    {
        to[0] = 0.0;
        to[1] = 0.0;
    }

    float frac = 1.0;
    bool clear = true;
    if (flatLen >= 1.0)
        clear = TraceWalkClear(client, origin, to, 52.0, frac);

    // Door detected during probe → hand off to door FSM
    if (g_DoorState[client] != 0)
    {
        TryUseNearbyDoor(client);
        return;
    }

    float moveDir[3];
    moveDir[0] = to[0];
    moveDir[1] = to[1];
    moveDir[2] = 0.0;

    if (!clear)
    {
        g_BlockCount[client]++;

        float left[3], right[3];
        left[0]  = -to[1]; left[1]  =  to[0]; left[2]  = 0.0;
        right[0] =  to[1]; right[1] = -to[0]; right[2] = 0.0;
        NormalizeVector(left, left);
        NormalizeVector(right, right);

        // Stronger side bias when blocked (less wall-hug)
        float tryL[3], tryR[3];
        tryL[0] = to[0] * 0.25 + left[0] * 0.75;
        tryL[1] = to[1] * 0.25 + left[1] * 0.75;
        tryL[2] = 0.0;
        tryR[0] = to[0] * 0.25 + right[0] * 0.75;
        tryR[1] = to[1] * 0.25 + right[1] * 0.75;
        tryR[2] = 0.0;
        NormalizeVector(tryL, tryL);
        NormalizeVector(tryR, tryR);

        float fL, fR;
        bool okL = TraceWalkClear(client, origin, tryL, 48.0, fL);
        bool okR = TraceWalkClear(client, origin, tryR, 48.0, fR);

        if (g_DoorState[client] != 0)
        {
            TryUseNearbyDoor(client);
            return;
        }

        if (okL && (!okR || fL >= fR))
        {
            moveDir[0] = tryL[0];
            moveDir[1] = tryL[1];
            g_AvoidYaw[client] = 40.0;
            g_BlockedUntil[client] = GetGameTime() + 0.45;
        }
        else if (okR)
        {
            moveDir[0] = tryR[0];
            moveDir[1] = tryR[1];
            g_AvoidYaw[client] = -40.0;
            g_BlockedUntil[client] = GetGameTime() + 0.45;
        }
        else
        {
            // Fully blocked: stop pushing into wall, back up, repath
            moveDir[0] = -to[0];
            moveDir[1] = -to[1];
            g_AIButtons[client] |= IN_JUMP;
            g_NextRepath[client] = GetGameTime() + 0.20;
            g_PathIndex[client] = -1;
            g_BlockCount[client] = 0;
            g_BlockedUntil[client] = GetGameTime() + 0.50;
        }

        // Persistent block → force full repath
        if (g_BlockCount[client] >= 8)
        {
            g_PathIndex[client] = -1;
            g_NextRepath[client] = 0.0;
            g_BlockCount[client] = 0;
        }
    }
    else
    {
        g_BlockCount[client] = 0;

        if (GetGameTime() < g_BlockedUntil[client])
        {
            float side = g_AvoidYaw[client] > 0.0 ? 1.0 : -1.0;
            float lat[3];
            lat[0] = -to[1] * side;
            lat[1] =  to[0] * side;
            lat[2] = 0.0;
            NormalizeVector(lat, lat);
            moveDir[0] = to[0] * 0.65 + lat[0] * 0.35;
            moveDir[1] = to[1] * 0.65 + lat[1] * 0.35;
            NormalizeVector(moveDir, moveDir);
        }
    }

    // Face path direction more aggressively when not shooting
    float moveAng[3];
    GetVectorAngles(moveDir, moveAng);

    float curAng[3];
    GetClientEyeAngles(client, curAng);

    float pathYawErr = FloatAbs(AngleDiff(moveAng[1], g_LookAt[client][1]));
    if (pathYawErr > 40.0 && g_CombatTarget[client] <= 0)
    {
        g_LookAt[client][1] = ApproachAngle(curAng[1], moveAng[1], 48.0);
        g_LookAt[client][0] = ApproachAngle(curAng[0], 0.0, 14.0);
        TeleportEntity(client, NULL_VECTOR, g_LookAt[client], NULL_VECTOR);
    }

    float angles[3];
    angles[0] = 0.0;
    angles[1] = g_LookAt[client][1];
    angles[2] = 0.0;

    float fwd[3], right[3];
    GetAngleVectors(angles, fwd, right, NULL_VECTOR);
    fwd[2] = 0.0;
    right[2] = 0.0;
    NormalizeVector(fwd, fwd);
    NormalizeVector(right, right);

    float fDot = GetVectorDotProduct(moveDir, fwd);
    float rDot = GetVectorDotProduct(moveDir, right);

    float speed = 400.0;
    TFClassType cls = TF2_GetPlayerClass(client);
    if (cls == TFClass_Heavy)        speed = 220.0;
    else if (cls == TFClass_Soldier) speed = 230.0;
    else if (cls == TFClass_DemoMan) speed = 270.0;
    else if (cls == TFClass_Spy)     speed = 290.0;

    // Slow down hard when almost blocked (reduces wall slide)
    if (!clear && frac < 0.55)
        speed *= 0.45;
    else if (!clear)
        speed *= 0.70;

    if (FloatAbs(rDot) > 0.7 && fDot < 0.25)
        speed *= 0.50;

    if (dz > 14.0)
    {
        speed *= 1.1;
        if (fDot < 0.2)
            fDot = 0.4;
        rDot *= 0.25;
    }

    g_AIForwardMove[client] = fDot * speed;
    g_AISideMove[client]    = rDot * speed;

    if (fDot > 0.08)  g_AIButtons[client] |= IN_FORWARD;
    if (fDot < -0.15) g_AIButtons[client] |= IN_BACK;
    if (rDot > 0.15)  g_AIButtons[client] |= IN_MOVERIGHT;
    if (rDot < -0.15) g_AIButtons[client] |= IN_MOVELEFT;

    if (dz > 10.0)
    {
        g_AIButtons[client] |= IN_JUMP;
        if (dz > 22.0)
            g_AIButtons[client] |= IN_DUCK;
    }

    // Only opportunistic door probe when not already in door FSM
    TryUseNearbyDoor(client);
}

bool IsPointVisible(int client, const float end[3])
{
    float start[3];
    GetClientEyePosition(client, start);

    float dest[3];
    dest[0] = end[0];
    dest[1] = end[1];
    dest[2] = end[2] + 20.0;

    Handle tr = TR_TraceRayFilterEx(start, dest, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_NoPlayers, client);
    bool ok = !TR_DidHit(tr);
    delete tr;
    return ok;
}

int FindBestEnemy(int client)
{
    int best = -1;
    float bestScore = -999999.0;
    float myPos[3];
    GetClientAbsOrigin(client, myPos);
    int myTeam = GetClientTeam(client);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
            continue;
        if (GetClientTeam(i) == myTeam)
            continue;

        float pos[3];
        GetClientAbsOrigin(i, pos);
        float d = GetVectorDistance(myPos, pos);
        if (d > 2800.0)
            continue;

        bool vis = IsTargetVisible(client, i);
        float score = 3000.0 - d;
        if (vis)
            score += 800.0;
        else if (d > 1600.0)
            continue;

        float dz = FloatAbs(pos[2] - myPos[2]);
        if (dz < 80.0)
            score += 120.0;
        else if (dz > 250.0)
            score -= 200.0;

        if (score > bestScore)
        {
            bestScore = score;
            best = i;
        }
    }
    return best;
}

int FindHurtTeammate(int client)
{
    int best = -1;
    float bestD = 999999.0;
    float myPos[3];
    GetClientAbsOrigin(client, myPos);
    int myTeam = GetClientTeam(client);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
            continue;
        if (GetClientTeam(i) != myTeam)
            continue;

        int hp    = GetClientHealth(i);
        int maxhp = GetEntProp(i, Prop_Data, "m_iMaxHealth");
        if (hp >= maxhp)
            continue;

        float pos[3];
        GetClientAbsOrigin(i, pos);
        float d = GetVectorDistance(myPos, pos);
        if (d < bestD && d < 1200.0)
        {
            bestD = d;
            best  = i;
        }
    }
    return best;
}

bool IsTargetVisible(int client, int target)
{
    float eye[3], targetPos[3];
    GetClientEyePosition(client, eye);
    GetClientEyePosition(target, targetPos);

    Handle trace = TR_TraceRayFilterEx(eye, targetPos, MASK_SHOT, RayType_EndPoint, TraceFilter_NoPlayers, client);
    bool visible = !TR_DidHit(trace) || TR_GetEntityIndex(trace) == target;
    delete trace;
    return visible;
}

public bool TraceFilter_NoPlayers(int entity, int contentsMask, any data)
{
    if (entity == data)
        return false;
    if (entity > 0 && entity <= MaxClients)
        return false;
    return true;
}

public Action Command_Force(int client, int args)
{
    if (client <= 0)
        return Plugin_Handled;

    if (args < 1)
    {
        TakeControl(client);
        return Plugin_Handled;
    }

    if (!CheckCommandAccess(client, "sm_afk_force", ADMFLAG_GENERIC, true))
    {
        TakeControl(client);
        ReplyToCommand(client, "[CubeNet] You can only force yourself.");
        return Plugin_Handled;
    }

    char arg[64];
    GetCmdArg(1, arg, sizeof(arg));
    int target = FindTarget(client, arg, true, false);
    if (target > 0)
        TakeControl(target);
    return Plugin_Handled;
}

public Action Command_Release(int client, int args)
{
    if (client <= 0)
        return Plugin_Handled;

    if (args < 1)
    {
        ReleaseControl(client);
        return Plugin_Handled;
    }

    if (!CheckCommandAccess(client, "sm_afk_release", ADMFLAG_GENERIC, true))
    {
        ReleaseControl(client);
        return Plugin_Handled;
    }

    char arg[64];
    GetCmdArg(1, arg, sizeof(arg));
    int target = FindTarget(client, arg, true, false);
    if (target > 0)
        ReleaseControl(target);
    return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
    ReplyToCommand(client, "[CubeNet] AI-controlled players:");
    bool any = false;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_IsAIControlled[i] && IsClientInGame(i))
        {
            ReplyToCommand(client, "  %N", i);
            any = true;
        }
    }
    if (!any)
        ReplyToCommand(client, "  (none)");
    return Plugin_Handled;
}

float ApproachAngle(float cur, float target, float speed)
{
    float delta = AngleDiff(target, cur);
    if (delta > speed)  delta = speed;
    else if (delta < -speed) delta = -speed;
    return Math_NormalizeYaw(cur + delta);
}

float AngleDiff(float a, float b)
{
    return Math_NormalizeYaw(a - b);
}

float Math_NormalizeYaw(float ang)
{
    while (ang > 180.0)  ang -= 360.0;
    while (ang < -180.0) ang += 360.0;
    return ang;
}
