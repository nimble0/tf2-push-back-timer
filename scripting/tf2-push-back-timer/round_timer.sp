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

public OnRoundTimeLimitChanged(Handle cvar, const char[] oldValue, const char[] newValue)
{
	SetRoundTimeLimit();
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
