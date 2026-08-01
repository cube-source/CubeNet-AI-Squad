/**
 * =====================================================
 * CubeNet AI Squad - AFK Possession (Phase 2.1)
 * Same-entity takeover via CBaseNPC navmesh.
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

#define PLUGIN_VERSION "4.2.1-phase2"

ConVar g_CvarAFKTime;
ConVar g_CvarCheckInterval;
ConVar g_CvarDebug;

float g_LastActivity[MAXPLAYERS + 1];
bool  g_IsAIControlled[MAXPLAYERS + 1];

ArrayList g_PathPositions[MAXPLAYERS + 1];
int   g_PathIndex[MAXPLAYERS + 1];
float g_NextRepath[MAXPLAYERS + 1];
float g_LookAt[MAXPLAYERS + 1][3];
int   g_AIButtons[MAXPLAYERS + 1];
float g_AIForwardMove[MAXPLAYERS + 1];
float g_AISideMove[MAXPLAYERS + 1];

int   g_CombatTarget[MAXPLAYERS + 1];
float g_EgressGoal[MAXPLAYERS + 1][3];
bool  g_HasEgress[MAXPLAYERS + 1];

float g_LastPos[MAXPLAYERS + 1][3];
float g_LastMovedAt[MAXPLAYERS + 1];
float g_UnstuckUntil[MAXPLAYERS + 1];
int   g_UnstuckDir[MAXPLAYERS + 1];

float g_NextBuildTry[MAXPLAYERS + 1];
int   g_BuildState[MAXPLAYERS + 1];
float g_NextSlotCmd[MAXPLAYERS + 1];

CNavMesh NavMesh;

public Plugin myinfo =
{
    name        = "[CubeNet] AFK Possession",
    author      = "CubeNet",
    description = "Same-entity AFK AI takeover (Phase 2.1)",
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
        g_PathPositions[i]  = new ArrayList(3);
        g_IsAIControlled[i] = false;
        g_LastActivity[i]   = GetGameTime();
        g_UnstuckDir[i]     = 1;
    }

    PrintToServer("[CubeNet] AFK Possession %s loaded", PLUGIN_VERSION);
}

public void OnMapStart() {}

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
    g_PathIndex[client]     = -1;
    g_NextRepath[client]    = 0.0;
    g_AIButtons[client]     = 0;
    g_AIForwardMove[client] = 0.0;
    g_AISideMove[client]    = 0.0;
    g_CombatTarget[client]  = -1;
    g_HasEgress[client]     = false;
    g_LastMovedAt[client]   = GetGameTime();
    g_UnstuckUntil[client]  = 0.0;
    g_UnstuckDir[client]    = 1;
    g_BuildState[client]    = 0;
    g_NextBuildTry[client]  = 0.0;
    g_NextSlotCmd[client]   = 0.0;

    if (client > 0 && client <= MaxClients && IsClientInGame(client))
        GetClientAbsOrigin(client, g_LastPos[client]);

    if (g_PathPositions[client] != null)
        g_PathPositions[client].Clear();
}

// =====================================================
// INPUT
// =====================================================
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;

    if (g_IsAIControlled[client])
    {
        // Human fire only — checked before AI buttons applied
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
        g_PathIndex[client]  = -1;
        g_NextRepath[client] = 0.0;
        if (g_PathPositions[client] != null)
            g_PathPositions[client].Clear();
        SeedEgressGoal(client);
    }
    return Plugin_Continue;
}

public Action Timer_CheckAFK(Handle timer)
{
    float now = GetGameTime();
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

// =====================================================
// TAKE / RELEASE
// =====================================================
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
    g_HasEgress[client]     = true;
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
    g_HasEgress[client]      = false;
    g_BuildState[client]     = 0;
    g_LastActivity[client]   = GetGameTime();

    if (g_PathPositions[client] != null)
        g_PathPositions[client].Clear();

    if (g_CvarDebug.BoolValue)
        PrintToChatAll("[CubeNet] %N took back control", client);

    PrintToChat(client, "\x04[CubeNet]\x01 You are back in control.");
}

// =====================================================
// UNSTUCK
// =====================================================
void UpdateUnstuck(int client)
{
    float now = GetGameTime();
    float pos[3];
    GetClientAbsOrigin(client, pos);

    if (GetVectorDistance(pos, g_LastPos[client]) > 20.0)
    {
        g_LastPos[client][0] = pos[0];
        g_LastPos[client][1] = pos[1];
        g_LastPos[client][2] = pos[2];
        g_LastMovedAt[client] = now;
        return;
    }

    if (now - g_LastMovedAt[client] > 0.9)
    {
        g_UnstuckUntil[client] = now + 1.0;
        if (TF2_GetPlayerClass(client) == TFClass_Heavy)
            g_UnstuckUntil[client] = now + 1.6;

        g_UnstuckDir[client]  = -g_UnstuckDir[client];
        g_LastMovedAt[client] = now;
        g_PathIndex[client]   = -1;
        g_NextRepath[client]  = 0.0;
    }
}

void ApplyUnstuck(int client)
{
    if (GetGameTime() > g_UnstuckUntil[client])
        return;

    g_AIButtons[client] |= IN_JUMP | IN_FORWARD;
    if (GetGameTime() < g_UnstuckUntil[client] - 0.4)
        g_AIButtons[client] |= IN_DUCK;

    g_AISideMove[client]    = 450.0 * float(g_UnstuckDir[client]);
    g_AIForwardMove[client] = 350.0;

    if (g_UnstuckDir[client] > 0)
        g_AIButtons[client] |= IN_MOVERIGHT;
    else
        g_AIButtons[client] |= IN_MOVELEFT;
}

// =====================================================
// AI TICK
// =====================================================
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

    int enemy = g_CombatTarget[client];
    if (enemy > 0)
    {
        if (!IsClientInGame(enemy) || !IsPlayerAlive(enemy) || GetClientTeam(enemy) == GetClientTeam(client))
        {
            enemy = -1;
            g_CombatTarget[client] = -1;
        }
    }

    if (enemy <= 0)
    {
        int cand = FindNearestEnemy(client);
        if (cand > 0)
        {
            float epos[3];
            GetClientAbsOrigin(cand, epos);
            float d = GetVectorDistance(origin, epos);
            if (d < 2000.0 || (d < 2500.0 && IsTargetVisible(client, cand)))
            {
                enemy = cand;
                g_CombatTarget[client] = cand;
                g_HasEgress[client] = false;
                g_PathIndex[client] = -1;
                g_NextRepath[client] = 0.0;
            }
        }
    }

    float goal[3];
    bool haveGoal = false;

    if (enemy > 0)
    {
        GetClientAbsOrigin(enemy, goal);
        goal[2] += 20.0;
        haveGoal = true;
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

    float now = GetGameTime();
    if (pathDone || now >= g_NextRepath[client])
    {
        BuildSimplePath(client, goal);
        g_NextRepath[client] = now + (enemy > 0 ? 1.0 : 2.5);
    }

    // Aim
    float curAng[3];
    GetClientEyeAngles(client, curAng);
    float wantPitch = 0.0;
    float wantYaw   = curAng[1];

    if (enemy > 0 && IsTargetVisible(client, enemy))
    {
        float tpos[3];
        // Aim at upper chest / eye line (not above the head)
        GetClientEyePosition(enemy, tpos);
        tpos[2] -= 8.0; // slightly below eyes = chest/head junction

        float dir[3];
        SubtractVectors(tpos, eye, dir);

        float ang[3];
        GetVectorAngles(dir, ang);

        // Source player pitch: do NOT double-invert
        wantPitch = -ang[0];
        wantYaw   = ang[1];

        // Clamp so they don't sky-stare or floor-stare
        if (wantPitch > 25.0)  wantPitch = 25.0;
        if (wantPitch < -25.0) wantPitch = -25.0;
    }
    else if (g_PathPositions[client] != null && g_PathIndex[client] >= 0
          && g_PathIndex[client] < g_PathPositions[client].Length)
    {
        float pt[3];
        g_PathPositions[client].GetArray(g_PathIndex[client], pt, 3);
        float dir[3];
        SubtractVectors(pt, eye, dir);
        dir[2] = 0.0;
        if (GetVectorLength(dir) > 1.0)
        {
            float ang[3];
            GetVectorAngles(dir, ang);
            wantYaw = ang[1];
        }
        wantPitch = 0.0;
    }

    g_LookAt[client][0] = ApproachAngle(curAng[0], wantPitch, 18.0);
    g_LookAt[client][1] = ApproachAngle(curAng[1], wantYaw, 28.0);
    g_LookAt[client][2] = 0.0;

    float yawErr = FloatAbs(AngleDiff(wantYaw, curAng[1]));
    if (yawErr > 3.0 || FloatAbs(wantPitch - curAng[0]) > 3.0)
        TeleportEntity(client, NULL_VECTOR, g_LookAt[client], NULL_VECTOR);

    FollowCurrentPath(client);
    UpdateUnstuck(client);
    ApplyUnstuck(client);

    if (GetGameTime() > g_UnstuckUntil[client]
        && FloatAbs(g_AIForwardMove[client]) < 50.0
        && FloatAbs(g_AISideMove[client]) < 50.0)
    {
        g_AIForwardMove[client] = 300.0;
        g_AIButtons[client] |= IN_FORWARD;
    }

    TFClassType cls = TF2_GetPlayerClass(client);
    if (cls == TFClass_Spy)
        AI_SpyThink(client, enemy);
    else if (cls == TFClass_Engineer)
        AI_EngineerThink(client, enemy);

    if (enemy > 0)
        AI_Combat(client, enemy, eye, goal, wantYaw);
    else
        AI_SupportIdle(client);
    {
        PrintHintText(client, "yaw=%.0f want=%.0f path=%d fwd=%.0f tgt=%d",
            g_LookAt[client][1], wantYaw, g_PathIndex[client], g_AIForwardMove[client], enemy);
    }
}

// =====================================================
// COMBAT
// =====================================================
void AI_Combat(int client, int enemy, const float eye[3], const float goal[3], float wantYaw)
{
    float dist = GetVectorDistance(eye, goal);
    float yawDiff = FloatAbs(AngleDiff(wantYaw, g_LookAt[client][1]));
    bool canSee = IsTargetVisible(client, enemy);
    TFClassType cls = TF2_GetPlayerClass(client);

    if (canSee && yawDiff < 40.0)
    {
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
            // Knife only when close; revolver mid-range (slot set in AI_SpyThink)
            if (dist < 150.0)
                g_AIButtons[client] |= IN_ATTACK;      // knife
            else if (dist < 900.0 && canSee)
                g_AIButtons[client] |= IN_ATTACK;      // revolver
            // no attack beyond that
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
    ang[0] = -ang[0];
    ang[2] = 0.0;

    float cur[3];
    GetClientEyeAngles(client, cur);
    g_LookAt[client][0] = ApproachAngle(cur[0], ang[0], 12.0);
    g_LookAt[client][1] = ApproachAngle(cur[1], ang[1], 18.0);
    g_LookAt[client][2] = 0.0;
    TeleportEntity(client, NULL_VECTOR, g_LookAt[client], NULL_VECTOR);

    float dist = GetVectorDistance(eye, tpos);
    if (dist > 400.0)
    {
        if (GetGameTime() >= g_NextRepath[client])
        {
            BuildSimplePath(client, matePos);
            g_NextRepath[client] = GetGameTime() + 1.5;
        }
    }
    else if (dist < 550.0)
        g_AIButtons[client] |= IN_ATTACK;
}

// =====================================================
// ENGINEER
// =====================================================
int FindFriendlySentry(int client)
{
    int myTeam = GetClientTeam(client);
    int best = -1;
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

        float pos[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
        float d = GetVectorDistance(myPos, pos);
        if (d < bestD)
        {
            bestD = d;
            best = ent;
        }
    }
    return best;
}

void AI_EngineerThink(int client, int enemy)
{
    float now = GetGameTime();
    int sentry = FindFriendlySentry(client);

    if (sentry > 0 && enemy <= 0)
    {
        float myPos[3], sPos[3];
        GetClientAbsOrigin(client, myPos);
        GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sPos);

        int hp = GetEntProp(sentry, Prop_Send, "m_iHealth");
        int maxhp = GetEntProp(sentry, Prop_Send, "m_iMaxHealth");
        int level = GetEntProp(sentry, Prop_Send, "m_iUpgradeLevel");
        bool needsWrench = (hp < maxhp) || (level < 3);

        float d = GetVectorDistance(myPos, sPos);
        if (d > 120.0)
        {
            if (now >= g_NextRepath[client])
            {
                BuildSimplePath(client, sPos);
                g_NextRepath[client] = now + 2.0;
            }
        }
        else if (needsWrench)
        {
            float eye[3], dir[3], ang[3];
            GetClientEyePosition(client, eye);
            SubtractVectors(sPos, eye, dir);
            GetVectorAngles(dir, ang);
            ang[0] = -ang[0];
            ang[2] = 0.0;
            g_LookAt[client][0] = ang[0];
            g_LookAt[client][1] = ang[1];
            TeleportEntity(client, NULL_VECTOR, g_LookAt[client], NULL_VECTOR);
            g_AIButtons[client] |= IN_ATTACK;
        }
        return;
    }

    if (sentry < 0 && enemy <= 0 && now >= g_NextBuildTry[client])
    {
        g_NextBuildTry[client] = now + 12.0;
        FakeClientCommand(client, "build 2");
        g_BuildState[client] = 2;
    }

    if (g_BuildState[client] == 2)
    {
        g_AIButtons[client] |= IN_ATTACK;
        if (now > g_NextBuildTry[client] - 8.0)
            g_BuildState[client] = 0;
    }
}

// =====================================================
// SPY
// =====================================================
void AI_SpyThink(int client, int enemy)
{
    float myPos[3];
    GetClientAbsOrigin(client, myPos);

    bool cloaked = TF2_IsPlayerInCondition(client, TFCond_Stealthed)
                || TF2_IsPlayerInCondition(client, TFCond_StealthedUserBuffFade)
                || TF2_IsPlayerInCondition(client, TFCond_Cloaked);

    float dist = 99999.0;
    bool canSee = false;

    if (enemy > 0)
    {
        float epos[3];
        GetClientAbsOrigin(enemy, epos);
        dist = GetVectorDistance(myPos, epos);
        canSee = IsTargetVisible(client, enemy);
    }

    // Weapon: revolver mid/long, knife only in melee range
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
// OBJECTIVES / PATH
// =====================================================
bool FindFrontObjective(int client, float outPos[3])
{
    float myPos[3];
    GetClientAbsOrigin(client, myPos);
    int myTeam = GetClientTeam(client);

    int bestEnt = -1;
    float bestScore = -999999.0;

    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "team_control_point")) != -1)
    {
        if (!IsValidEntity(ent))
            continue;
        float pos[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
        float dist = GetVectorDistance(myPos, pos);
        float score = dist;
        if (dist < 400.0)
            score -= 2000.0;
        if (score > bestScore)
        {
            bestScore = score;
            bestEnt = ent;
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
            bestEnt = ent;
        }
    }

    if (bestEnt == -1)
        return false;
    GetEntPropVector(bestEnt, Prop_Send, "m_vecOrigin", outPos);
    return true;
}

void BuildSimplePath(int client, const float goal[3])
{
    if (g_PathPositions[client] == null)
        return;

    g_PathPositions[client].Clear();
    g_PathIndex[client] = -1;

    float start[3];
    GetClientAbsOrigin(client, start);
    start[2] += 16.0;

    CNavArea startArea = NavMesh.GetNearestNavArea(start, true, 1000.0, false, true, GetClientTeam(client));
    CNavArea goalArea  = NavMesh.GetNearestNavArea(goal, true, 1000.0, false, true, GetClientTeam(client));

    if (startArea == NULL_AREA || goalArea == NULL_AREA || startArea == goalArea)
    {
        g_PathPositions[client].PushArray(goal, 3);
        g_PathIndex[client] = 0;
        return;
    }

    CNavArea closest = NULL_AREA;
    if (!NavMesh.BuildPath(startArea, goalArea, goal, PathCostShortest, closest, 0.0, GetClientTeam(client), false))
    {
        g_PathPositions[client].PushArray(goal, 3);
        g_PathIndex[client] = 0;
        return;
    }

    ArrayList temp = new ArrayList(3);
    CNavArea area = closest;
    while (area != NULL_AREA)
    {
        float center[3];
        area.GetCenter(center);
        temp.PushArray(center, 3);
        area = area.GetParent();
    }

    for (int i = temp.Length - 1; i >= 0; i--)
    {
        float pt[3];
        temp.GetArray(i, pt, 3);
        if (g_PathPositions[client].Length > 0)
        {
            float last[3];
            g_PathPositions[client].GetArray(g_PathPositions[client].Length - 1, last, 3);
            if (GetVectorDistance(last, pt) < 80.0)
                continue;
        }
        g_PathPositions[client].PushArray(pt, 3);
    }

    g_PathPositions[client].PushArray(goal, 3);
    delete temp;
    g_PathIndex[client] = 0;
}

public float PathCostShortest(CNavArea area, CNavArea fromArea, CNavLadder ladder, int elevator, float length)
{
    if (fromArea == NULL_AREA)
        return 0.0;
    float a[3], b[3];
    area.GetCenter(a);
    fromArea.GetCenter(b);
    return GetVectorDistance(a, b) + fromArea.GetCostSoFar();
}

void FollowCurrentPath(int client)
{
    g_AIForwardMove[client] = 0.0;
    g_AISideMove[client]    = 0.0;

    if (g_PathPositions[client] == null || g_PathIndex[client] < 0)
        return;
    if (g_PathIndex[client] >= g_PathPositions[client].Length)
        return;

    float target[3];
    g_PathPositions[client].GetArray(g_PathIndex[client], target, 3);

    float origin[3];
    GetClientAbsOrigin(client, origin);

    float dist = GetVectorDistance(origin, target);
    if (dist < 72.0)
    {
        g_PathIndex[client]++;
        if (g_PathIndex[client] >= g_PathPositions[client].Length)
            return;
        g_PathPositions[client].GetArray(g_PathIndex[client], target, 3);
    }

    float dir[3];
    SubtractVectors(target, origin, dir);
    dir[2] = 0.0;
    if (GetVectorLength(dir) < 1.0)
        return;
    NormalizeVector(dir, dir);

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

    float fDot = GetVectorDotProduct(dir, fwd);
    float rDot = GetVectorDotProduct(dir, right);
    float speed = 450.0;
    TFClassType cls = TF2_GetPlayerClass(client);
    if (cls == TFClass_Heavy)
        speed = 230.0;
    else if (cls == TFClass_Soldier)
        speed = 240.0;
    else if (cls == TFClass_DemoMan)
        speed = 280.0;
    else if (cls == TFClass_Spy)
        speed = 320.0;

    g_AIForwardMove[client] = fDot * speed;
    g_AISideMove[client]    = rDot * speed;

    if (fDot > 0.15)  g_AIButtons[client] |= IN_FORWARD;
    if (fDot < -0.15) g_AIButtons[client] |= IN_BACK;
    if (rDot > 0.15)  g_AIButtons[client] |= IN_MOVERIGHT;
    if (rDot < -0.15) g_AIButtons[client] |= IN_MOVELEFT;
    if (target[2] > origin[2] + 30.0)
        g_AIButtons[client] |= IN_JUMP;
}

// =====================================================
// HELPERS
// =====================================================
int FindNearestEnemy(int client)
{
    int best = -1;
    float bestDist = 999999.0;
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
        if (d < bestDist)
        {
            bestDist = d;
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
        int hp = GetClientHealth(i);
        int maxhp = GetEntProp(i, Prop_Data, "m_iMaxHealth");
        if (hp >= maxhp)
            continue;
        float pos[3];
        GetClientAbsOrigin(i, pos);
        float d = GetVectorDistance(myPos, pos);
        if (d < bestD && d < 1200.0)
        {
            bestD = d;
            best = i;
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

// =====================================================
// COMMANDS
// =====================================================
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
    if (delta > speed) delta = speed;
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
