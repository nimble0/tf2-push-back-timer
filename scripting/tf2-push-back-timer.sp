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


#include "tf2-push-back-timer/initialisation.sp"
#include "tf2-push-back-timer/round_timer.sp"
#include "tf2-push-back-timer/control_points.sp"
