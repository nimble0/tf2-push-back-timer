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
