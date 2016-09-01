#include <sourcemod>
#include <sdktools>
#include <tf2>


public Plugin myinfo =
{
	name = "5CP Push back timer",
	author = "Nimble",
	description = "Switches attacking team control point to defending (5CP only) when round timer runs out instead of stalemating",
	version = "0.1",
	url = "https://github.com/nimble0/tf2-push-back-timer"
};

Handle roundTimeLimitCvar = INVALID_HANDLE;
int roundTimerEntity = -1;
int controlPoints[] = {-1, -1, -1, -1, -1};


public void OnPluginStart()
{
	roundTimeLimitCvar = CreateConVar(
		"mp_roundtimelimit",
		"180",
		"time limit between round captures in seconds",
		FCVAR_NOTIFY|FCVAR_REPLICATED,
		true,
		1.0);
	HookConVarChange(roundTimeLimitCvar, RoundTimeLimitChanged);
	
	HookEvent("teamplay_round_start", RoundStarted, EventHookMode_Pre);
	HookEntityOutput("team_round_timer", "OnFinished", Event_RoundTimerExpired);
}

public SetRoundTimeLimit()
{
	SetVariantInt(GetConVarInt(roundTimeLimitCvar));
	AcceptEntityInput(roundTimerEntity, "SetMaxTime");
}

public RoundTimeLimitChanged(Handle cvar, const char[] oldValue, const char[] newValue)
{
	SetRoundTimeLimit();
}

public RoundStarted(Event event, const char[] name, bool dontBroadcast)
{
	SetRoundTimeLimit();
}

public void OnMapStart()
{
	// Check game type is CP
	if(GameRules_GetProp("m_nGameType") == 2)
	{
		int entity = -1;
		
		while((entity = FindEntityByClassname(entity, "team_round_timer")) != -1)
		{
			decl String:name[50];
			GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			
			if(GetEntProp(entity, Prop_Send, "m_bShowInHUD")
			&& !GetEntProp(entity, Prop_Send, "m_bStopWatchTimer")
			&& StrEqual(name, "game_timer"))
				roundTimerEntity = entity;
		}
	
		SetRoundTimeLimit();
		
		while((entity = FindEntityByClassname(entity, "team_control_point")) != -1)
		{
			// m_iPointIndex seems to follow the pattern:
			// 0 - BLU last
			// 1 - BLU second
			// 2 - Mid
			// 3 - RED second
			// 4 - RED last
			int cpIndex = GetEntProp(entity, Prop_Data, "m_iPointIndex");

			if(cpIndex < sizeof(controlPoints))
				controlPoints[cpIndex] = entity;
		}
	}
}

public Action Event_RoundTimerExpired(const char[] output, int caller, int activator, float delay)
{
	if(caller == roundTimerEntity)
	{
		int cpDiff = GetNumTeamOwnedCps(2) - GetNumTeamOwnedCps(3);
		
		if(cpDiff > 0)
			CaptureNext(3);
		else if(cpDiff < 0)
			CaptureNext(2);
	
		if(cpDiff != 0)
		{
			AcceptEntityInput(caller, "Pause");
			
			// Can't resume timer straight away or it breaks timer OnFinished hook
			CreateTimer(0.0, ResumeTimer);
			
			return Plugin_Handled;
		}
		else
			return Plugin_Continue;
	}

	return Plugin_Continue;
}

public Action ResumeTimer(Handle timer)
{
	SetVariantInt(GetConVarInt(roundTimeLimitCvar));
	AcceptEntityInput(roundTimerEntity, "SetTime");
	
	AcceptEntityInput(roundTimerEntity, "Resume");
}

public int GetNumTeamOwnedCps(int team)
{
	int count = 0;

	for(int i = 0; i < sizeof(controlPoints); ++i)
		if(GetEntProp(controlPoints[i], Prop_Data, "m_iTeamNum") == team)
			++count;
	
	return count;
}

public bool CaptureNext(int team)
{
	if(GetEntProp(controlPoints[0], Prop_Data, "m_iTeamNum") == team)
	{
		for(int i = 0; i < sizeof(controlPoints); ++i)
			if(GetEntProp(controlPoints[i], Prop_Data, "m_iTeamNum") != team)
			{
				SetVariantInt(team);
				AcceptEntityInput(controlPoints[i], "SetOwner", 0, 0);
			
				return true;
			}
	}
	else if(GetEntProp(controlPoints[sizeof(controlPoints)-1], Prop_Data, "m_iTeamNum") == team)
	{
		for(int i = sizeof(controlPoints)-1; i > -1; --i)
			if(GetEntProp(controlPoints[i], Prop_Data, "m_iTeamNum") != team)
			{
				SetVariantInt(team);
				AcceptEntityInput(controlPoints[i], "SetOwner", 0, 0);
			
				return true;
			}
	}
		
	return false;
}