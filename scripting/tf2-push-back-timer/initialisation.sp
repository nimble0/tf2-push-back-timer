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

	HookEntityOutput("team_round_timer", "On1SecRemain", OnRoundTimerAlmostExpired);
	HookEntityOutput("team_round_timer", "OnFinished", OnRoundTimerExpired);

	HookEvent("teamplay_point_startcapture", OnCaptureStarted, EventHookMode_Post);
	HookEvent("teamplay_capture_broken", OnCaptureBroken, EventHookMode_Post);
	HookEvent("teamplay_point_captured", OnCaptureCompleted, EventHookMode_Post);
}

public void OnMapStart()
{
	// Reset map specific data
	is5Cp = Is5Cp();
	roundTimerEntity = INVALID_ENT_REFERENCE;
	for(int i = 0; i < sizeof(controlPoints); ++i)
		controlPoints[i] = INVALID_ENT_REFERENCE;
	for(int i = 0; i < sizeof(controlPointStates); ++i)
		controlPointStates[i] = false;

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

public void OnEntityCreated(int entity, const char[] className)
{
	if(StrEqual(className, "team_control_point"))
		SDKHook(entity, SDKHook_SpawnPost, OnCpSpawned);
	else if(StrEqual(className, "team_round_timer"))
		SDKHook(entity, SDKHook_SpawnPost, OnRoundTimerSpawned);
}

public void OnPluginEnd()
{
	for(int i = 0; i < sizeof(fakeClients); ++i)
		KickClient(EntRefToEntIndex(fakeClients[i]));
}
