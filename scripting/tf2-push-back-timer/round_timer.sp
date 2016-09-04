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

public Action OnRoundTimerExpired(const char[] output, int caller, int activator, float delay)
{
	if(caller == EntRefToEntIndex(roundTimerEntity))
	{
		CloseHandle(pushBackSecondaryTimer);
		pushBackSecondaryTimer = INVALID_HANDLE;

		return OnRoundTimerExpired_();
	}

	return Plugin_Continue;
}

public Action OnRoundTimerAlmostExpired(const char[] output, int caller, int activator, float delay)
{
	if(caller == EntRefToEntIndex(roundTimerEntity))
		pushBackSecondaryTimer = CreateTimer(1.0, OnRoundTimerExpiredB);

	return Plugin_Continue;
}

public Action OnRoundTimerExpiredB(Handle timer)
{
	OnRoundTimerExpired_();
	pushBackSecondaryTimer = INVALID_HANDLE;

	return Plugin_Continue;
}

public Action OnRoundTimerExpired_()
{
	if(pushBackTeam != -1
	|| !AreCpsValid())
		return Plugin_Continue;

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

	if(cpDiff != 0)
		return Plugin_Handled;
	else
		return Plugin_Continue;
}
