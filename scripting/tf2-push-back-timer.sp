#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>


public Plugin myinfo =
{
	name = "TF2 5CP Push back timer",
	author = "Nimble",
	description = "Switches attacking team control point to defending (5CP only) when round timer runs out instead of stalemating",
	version = "0.1",
	url = "https://github.com/nimble0/tf2-push-back-timer"
};

int is5Cp = -1;
Handle roundTimeLimitCvar = INVALID_HANDLE;
int roundTimerEntity = INVALID_ENT_REFERENCE;
int controlPoints[] =
{
	INVALID_ENT_REFERENCE,
	INVALID_ENT_REFERENCE,
	INVALID_ENT_REFERENCE,
	INVALID_ENT_REFERENCE,
	INVALID_ENT_REFERENCE
};

int fakeClients[] =
{
	INVALID_ENT_REFERENCE,
	INVALID_ENT_REFERENCE
};


public void OnPluginStart()
{
	roundTimeLimitCvar = CreateConVar(
		"mp_roundtimelimit",
		"180",
		"time limit between round captures in seconds",
		FCVAR_NOTIFY|FCVAR_REPLICATED,
		true,
		1.0);
	HookConVarChange(roundTimeLimitCvar, OnRoundTimeLimitChanged);

	HookEntityOutput("team_round_timer", "OnFinished", OnRoundTimerExpired);
}

public void OnPluginEnd()
{
	for(int i = 0; i < sizeof(fakeClients); ++i)
		KickClient(EntRefToEntIndex(fakeClients[i]));
}


public OnRoundTimeLimitChanged(Handle cvar, const char[] oldValue, const char[] newValue)
{
	SetRoundTimeLimit();
}


public void OnMapStart()
{
	// Reset map specific data
	is5Cp = Is5Cp();
	roundTimerEntity = INVALID_ENT_REFERENCE;
	for(int i = 0; i < sizeof(controlPoints); ++i)
		controlPoints[i] = INVALID_ENT_REFERENCE;

	if(is5Cp)
	{
		int entity = INVALID_ENT_REFERENCE;

		while((entity = FindEntityByClassname(entity, "team_round_timer")) != INVALID_ENT_REFERENCE)
			if(GetEntProp(entity, Prop_Send, "m_bShowInHUD")
			&& !GetEntProp(entity, Prop_Send, "m_bStopWatchTimer"))
				roundTimerEntity = EntIndexToEntRef(entity);

		SetRoundTimeLimit();


		while((entity = FindEntityByClassname(entity, "team_control_point")) != INVALID_ENT_REFERENCE)
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


		CreateTimer(0.0, CreateFakeClients);
	}
}

public Action CreateFakeClients(Handle timer)
{
	fakeClients[0] = EntIndexToEntRef(CreateFakeClient("RED"));
	fakeClients[1] = EntIndexToEntRef(CreateFakeClient("BLU"));

	for(int i = 0; i < sizeof(fakeClients); ++i)
	{
		int entityIndex = EntRefToEntIndex(fakeClients[i]);

		ChangeClientTeam(entityIndex, i+2);
		TF2_SetPlayerClass(entityIndex, TF2_GetClass("scout"));
		TF2_RespawnPlayer(entityIndex);
	}
}

public bool Is5Cp()
{
	if(GameRules_GetProp("m_nGameType") != 2
	|| GameRules_GetProp("m_bIsInTraining")
	|| GameRules_GetProp("m_bIsInItemTestingMode")
	|| GameRules_GetProp("m_bPlayingSpecialDeliveryMode")
	|| GameRules_GetProp("m_bPlayingMannVsMachine")
	|| GameRules_GetProp("m_bPlayingKoth"))
		return false;

	int roundCp = -1;
	int roundCount = 0;
	while((roundCp = FindEntityByClassname(roundCp, "team_control_point_round")) != -1)
		++roundCount;

	if(roundCount != 0)
		return false;

	int masterCp = FindEntityByClassname(-1, "team_control_point_master");

	if(masterCp == -1)
		return false;

	if(GetEntProp(masterCp, Prop_Data, "m_iInvalidCapWinner") > 1)
		return false;

	return true;
}


public void OnEntityCreated(int entity, const char[] className)
{
	if(StrEqual(className, "team_control_point"))
		SDKHook(entity, SDKHook_SpawnPost, OnCpSpawned);
	else if(StrEqual(className, "team_round_timer"))
		SDKHook(entity, SDKHook_SpawnPost, OnRoundTimerSpawned);
}

public void OnCpSpawned(int entity)
{
	// m_iPointIndex may be wrong if we read it here
	CreateTimer(0.0, OnCpSpawned_, entity);
}

public Action OnCpSpawned_(Handle timer, int entity)
{
	int cpIndex = GetEntProp(entity, Prop_Data, "m_iPointIndex");

	if(cpIndex < sizeof(controlPoints))
		controlPoints[cpIndex] = EntIndexToEntRef(entity);
}

public void OnRoundTimerSpawned(int entity)
{
	if(is5Cp
	&& GetEntProp(entity, Prop_Send, "m_bShowInHUD")
	&& !GetEntProp(entity, Prop_Send, "m_bStopWatchTimer"))
	{
		roundTimerEntity = EntIndexToEntRef(entity);

		SetRoundTimeLimit();
	}
}


public SetRoundTimeLimit()
{
	if(EntRefToEntIndex(roundTimerEntity) == INVALID_ENT_REFERENCE)
		return;

	SetVariantInt(GetConVarInt(roundTimeLimitCvar));
	AcceptEntityInput(roundTimerEntity, "SetMaxTime");
}


public Action OnRoundTimerExpired(const char[] output, int caller, int activator, float delay)
{
	if(caller == EntRefToEntIndex(roundTimerEntity))
	{
		if(!AreCpsValid())
			return Plugin_Continue;

		int redOwned = GetNumTeamOwnedCps(2);
		int bluOwned = GetNumTeamOwnedCps(3);

		if(redOwned + bluOwned != 5)
			return Plugin_Continue;

		int cpDiff = redOwned - bluOwned;

		if(cpDiff > 0)
			CaptureNext(3);
		else if(cpDiff < 0)
			CaptureNext(2);

		if(cpDiff != 0)
			return Plugin_Handled;
		else
			return Plugin_Continue;
	}

	return Plugin_Continue;
}


public bool AreCpsValid()
{
	for(int i = 0; i < sizeof(controlPoints); ++i)
		if(EntRefToEntIndex(controlPoints[i]) == INVALID_ENT_REFERENCE)
			return false;

	return true;
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
				return Capture(controlPoints[i], team);
	}
	else if(GetEntProp(controlPoints[sizeof(controlPoints)-1], Prop_Data, "m_iTeamNum") == team)
	{
		for(int i = sizeof(controlPoints)-1; i > -1; --i)
			if(GetEntProp(controlPoints[i], Prop_Data, "m_iTeamNum") != team)
				return Capture(controlPoints[i], team);
	}

	return false;
}

public bool Capture(int cp, int team)
{
	char cpName[50];
	GetEntPropString(cp, Prop_Data, "m_iName", cpName, sizeof(cpName));

	int entity = INVALID_ENT_REFERENCE;
	while((entity = FindEntityByClassname(entity, "trigger_capture_area")) != INVALID_ENT_REFERENCE)
	{
		char cpRefName[50];
		GetEntPropString(entity, Prop_Data, "m_iszCapPointName", cpRefName, sizeof(cpRefName));

		if(StrEqual(cpName, cpRefName))
		{
			int fakeClient = fakeClients[team-2];

			AcceptEntityInput(entity, "StartTouch", 0, fakeClient);
			AcceptEntityInput(entity, "CaptureCurrentCP", 0, 0);
			AcceptEntityInput(entity, "EndTouch", 0, fakeClient);

			return true;
		}
	}

	return false;
}
