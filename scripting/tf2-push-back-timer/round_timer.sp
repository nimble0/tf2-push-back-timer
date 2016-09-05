public void HookRoundTimer(int entity)
{
	roundTimerEntity = EntIndexToEntRef(entity);

	// For preventing stalemate round end
	HookSingleEntityOutput(
		entity,
		"OnFinished",
		OnActualRoundTimerExpired);

	// For creating correct overtime conditions
	HookSingleEntityOutput(
		entity,
		"On1SecRemain",
		OnRoundTimerAlmostExpired);

	SetRoundTimeLimit();
}

public void OnRoundTimerSpawned(int entity)
{
	if(is5Cp
	&& GetEntProp(entity, Prop_Send, "m_bShowInHUD")
	&& !GetEntProp(entity, Prop_Send, "m_bStopWatchTimer"))
		HookRoundTimer(entity);
}

public void SetRoundTimeLimit()
{
	if(EntRefToEntIndex(roundTimerEntity) == INVALID_ENT_REFERENCE)
		return;

	SetVariantInt(GetConVarInt(roundTimeLimitCvar));
	AcceptEntityInput(roundTimerEntity, "SetMaxTime");
}


public void OnRoundTimeLimitChanged(Handle cvar, const char[] oldValue, const char[] newValue)
{
	SetRoundTimeLimit();
}

public Action OnActualRoundTimerExpired(const char[] output, int caller, int activator, float delay)
{
	// Use normal timer behaviour if we couldn't find all 5 control points
	if(!AreCpsValid())
		return Plugin_Continue;

	// Use normal timer behaviour if not all control points are owned
	if(GetNumTeamOwnedCps(2) + GetNumTeamOwnedCps(3) != 5)
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action OnRoundTimerAlmostExpired(const char[] output, int caller, int activator, float delay)
{
	CreateTimer(1.0, OnRoundTimerExpired);

	return Plugin_Continue;
}

public Action OnRoundTimerExpired(Handle timer)
{
	int redOwned = GetNumTeamOwnedCps(2);
	int bluOwned = GetNumTeamOwnedCps(3);

	if(redOwned + bluOwned != 5)
		return Plugin_Continue;

	int cpDiff = redOwned - bluOwned;

	if(cpDiff > 0)
		pushBackTeam = 3;
	else if(cpDiff < 0)
		pushBackTeam = 2;

	pushBackCp = GetNextCapture(pushBackTeam);

	TryPushBackCapture();

	return Plugin_Continue;
}
