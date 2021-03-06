 public void OnCpSpawned(int entity)
{
	// m_iPointIndex may be wrong if we read it here
	CreateTimer(0.0, OnCpSpawned_, entity);
}

public Action OnCpSpawned_(Handle timer, int entity)
{
	// Sometimes this property is missing for some reason
	if(!HasEntProp(entity, Prop_Data, "m_iPointIndex"))
		return Plugin_Continue;

	int cpIndex = GetEntProp(entity, Prop_Data, "m_iPointIndex");

	if(cpIndex >= 0 && cpIndex < sizeof(controlPoints))
		controlPoints[cpIndex] = EntIndexToEntRef(entity);

	return Plugin_Continue;
}

public Action OnCaptureStarted(Event event, const char[] name, bool dontBroadcast)
{
	int cpIndex = event.GetInt("cp");

	if(cpIndex >= 0 && cpIndex < sizeof(controlPointStates))
		controlPointStates[cpIndex] = true;

	return Plugin_Continue;
}

public Action OnCaptureBroken(Event event, const char[] name, bool dontBroadcast)
{
	int cpIndex = event.GetInt("cp");

	if(cpIndex >= 0 && cpIndex < sizeof(controlPointStates))
	{
		controlPointStates[cpIndex] = false;

		TryPushBackCapture();
	}

	return Plugin_Continue;
}

public Action OnCaptureCompleted(Event event, const char[] name, bool dontBroadcast)
{
	int cpIndex = event.GetInt("cp");

	if(cpIndex >= 0 && cpIndex < sizeof(controlPointStates))
		controlPointStates[cpIndex] = false;

	pushBackTeam = -1;
	pushBackCp = -1;

	return Plugin_Continue;
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

	int validCps = 0;

	int entity = INVALID_ENT_REFERENCE;
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
			++validCps;
		else
			return false;
	}

	if(validCps != 5)
		return false;

	return true;
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

public void TryPushBackCapture()
{
	if(pushBackTeam == -1 || pushBackCp == -1)
		return;

	for(int i = 0; i < sizeof(controlPointStates); ++i)
		if(i != pushBackCp && controlPointStates[i])
			return;

	Capture(pushBackCp, pushBackTeam);

	pushBackTeam = -1;
	pushBackCp = -1;
}

public int GetNextCapture(int team)
{
	if(GetEntProp(controlPoints[0], Prop_Data, "m_iTeamNum") == team)
	{
		for(int i = 0; i < sizeof(controlPoints); ++i)
			if(GetEntProp(controlPoints[i], Prop_Data, "m_iTeamNum") != team)
				return i;
	}
	else if(GetEntProp(controlPoints[sizeof(controlPoints)-1], Prop_Data, "m_iTeamNum") == team)
	{
		for(int i = sizeof(controlPoints)-1; i > -1; --i)
			if(GetEntProp(controlPoints[i], Prop_Data, "m_iTeamNum") != team)
				return i;
	}

	return -1;
}

public bool Capture(int cp, int team)
{
	char cpName[50];
	GetEntPropString(controlPoints[cp], Prop_Data, "m_iName", cpName, sizeof(cpName));

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
