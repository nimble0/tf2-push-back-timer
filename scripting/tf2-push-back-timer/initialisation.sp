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

	// For creating correct overtime conditions
	HookEvent("teamplay_point_startcapture", OnCaptureStarted, EventHookMode_Post);
	HookEvent("teamplay_capture_broken", OnCaptureBroken, EventHookMode_Post);
	HookEvent("teamplay_point_captured", OnCaptureCompleted, EventHookMode_Post);

	// Make fake clients as invisible as possible
	HookEvent("player_spawn", OnPlayerSpawn);
	// Prevent fake clients' team being changed for whatever reason
	HookEvent("player_team", OnPlayerTeamChange, EventHookMode_Post);
}

public void OnMapStart()
{
	// Reset map specific data
	is5Cp = Is5Cp();
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
				HookRoundTimer(entity);

		while((entity = FindEntityByClassname(entity, "team_control_point")) != INVALID_ENT_REFERENCE)
		{
			// m_iPointIndex seems to follow the pattern:
			// 0 - BLU last
			// 1 - BLU second
			// 2 - Mid
			// 3 - RED second
			// 4 - RED last
			int cpIndex = GetEntProp(entity, Prop_Data, "m_iPointIndex");

			if(cpIndex >= 0 && cpIndex < sizeof(controlPoints))
				controlPoints[cpIndex] = entity;
		}


		CreateTimer(0.0, CreateFakeClients);


		// Hide fake clients on scoreboard as much as possible
		int playerManager = FindEntityByClassname(INVALID_ENT_REFERENCE, "tf_player_manager");
		SDKHook(playerManager, SDKHook_ThinkPost, OnThinkPost);
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
		TF2_SetPlayerClass(entityIndex, TFClass_Scout);
	}

	return Plugin_Continue;
}

public void OnThinkPost(int entity)
{
	for(int i = 0; i < sizeof(fakeClients); ++i)
	{
		int fakeClient = EntRefToEntIndex(fakeClients[i]);

		if(fakeClient != INVALID_ENT_REFERENCE)
		{
			SetEntProp(entity, Prop_Send, "m_bAlive", false, 1, EntRefToEntIndex(fakeClients[i]));
			SetEntProp(entity, Prop_Send, "m_iTotalScore", -1, 4, EntRefToEntIndex(fakeClients[i]));
		}
	}
}

public Action OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	for(int i = 0; i < sizeof(fakeClients); ++i)
		if(EntRefToEntIndex(fakeClients[i]) == client)
		{
			SDKHook(client, SDKHook_SetTransmit, OnSetTransmit);
			SetEntProp(client, Prop_Send, "m_CollisionGroup", 2);
			SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
			
			float pos[] = {10000.0, 10000.0, 10000.0};
			TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
		}

	return Plugin_Continue;
}

public Action OnPlayerTeamChange(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	for(int i = 0; i < sizeof(fakeClients); ++i)
		if(EntRefToEntIndex(fakeClients[i]) == client)
		{
			CreateTimer(0.0, CorrectFakeClientTeam, i);

			return Plugin_Handled;
		}

	return Plugin_Continue;
}

public Action CorrectFakeClientTeam(Handle timer, int fakeClientIndex)
{
	int entityIndex = EntRefToEntIndex(fakeClients[fakeClientIndex]);

	if(entityIndex == INVALID_ENT_REFERENCE)
		return;

	if(GetClientTeam(entityIndex) != fakeClientIndex+2)
		ChangeClientTeam(entityIndex, fakeClientIndex+2);
}

public Action OnSetTransmit(int entity, int client)
{
	return Plugin_Handled;
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
	{
		int clientIndex = EntRefToEntIndex(fakeClients[i]);

		if(clientIndex != INVALID_ENT_REFERENCE)
			KickClient(clientIndex);
	}
}
