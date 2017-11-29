void showServerLoadingMenu(int from, char[] message)
{
	char title[100];
	Format(title, 64, "[%s]", g_szChatPrefix);
	
	ReplaceString(message, 192, "\\n", "\n");
	
	Panel mSayPanel = new Panel();
	mSayPanel.SetTitle(title);
	mSayPanel.DrawItem("", ITEMDRAW_SPACER);
	mSayPanel.DrawText(message);
	mSayPanel.DrawItem("", ITEMDRAW_SPACER);
	mSayPanel.CurrentKey = GetMaxPageItems(GetPanelStyle(mSayPanel));
	mSayPanel.DrawItem("Exit", ITEMDRAW_CONTROL);
	mSayPanel.Send(from, Handler_DoNothing, 10);
	delete mSayPanel;
}
public int Handler_DoNothing(Menu menu, MenuAction action, int param1, int param2)
{
	/* Do nothing */
}

// Start timer
public void CL_OnStartTimerPress(int client)
{
	if (!IsValidClient(client))
		return;

	if (!IsFakeClient(client))
	{
		if (!g_bServerDataLoaded)
		{
			if (GetGameTime() - g_fErrorMessage[client] > 1.0)
			{
				PrintToChat(client, "[%c%s%c] The server hasn't finished loading it's settings, please wait.", MOSSGREEN, g_szChatPrefix, WHITE);
				showServerLoadingMenu(client, "The server hasn't finished loading it's settings, please wait.");
				ClientCommand(client, "play buttons\\weapon_cant_buy.wav");
				g_fErrorMessage[client] = GetGameTime();
			}
			return;
		}
		else if (g_bLoadingSettings[client])
		{
			if (GetGameTime() - g_fErrorMessage[client] > 1.0)
			{
				PrintToChat(client, "[%c%s%c] Your settings are currently being loaded, please wait.", MOSSGREEN, g_szChatPrefix, WHITE);
				showServerLoadingMenu(client, "Your settings are currently being loaded, please wait.");
				ClientCommand(client, "play buttons\\weapon_cant_buy.wav");
				g_fErrorMessage[client] = GetGameTime();
			}
			return;
		}
		else if (!g_bSettingsLoaded[client])
		{
			if (GetGameTime() - g_fErrorMessage[client] > 1.0)
			{
				PrintToChat(client, "[%c%s%c] The server hasn't finished loading your settings, please wait.", MOSSGREEN, g_szChatPrefix, WHITE);
				showServerLoadingMenu(client, "The server hasn't finished loading your settings, please wait.");
				ClientCommand(client, "play buttons\\weapon_cant_buy.wav");
				g_fErrorMessage[client] = GetGameTime();
			}
			return;
		}
	}
	if (g_bNewReplay[client] || g_bNewBonus[client]) // Don't allow starting the timer, if players record is being saved
		return;

	if (!g_bSpectate[client] && !g_bNoClip[client] && ((GetGameTime() - g_fLastTimeNoClipUsed[client]) > 2.0))
	{
		if (g_bActivateCheckpointsOnStart[client])
			g_bCheckpointsEnabled[client] = true;

		// Reset run variables
		tmpDiff[client] = 9999.0;
		g_fPauseTime[client] = 0.0;
		g_fStartPauseTime[client] = 0.0;
		g_bPause[client] = false;
		SetEntityMoveType(client, MOVETYPE_WALK);
		SetPlayerVisible(client);
		g_fStartTime[client] = GetGameTime();
		g_fCurrentRunTime[client] = 0.0;
		g_bPositionRestored[client] = false;
		g_bMissedMapBest[client] = true;
		g_bMissedBonusBest[client] = true;
		g_bTimeractivated[client] = true;

		if (!IsFakeClient(client))
		{	
			// Reset checkpoint times
			for (int i = 0; i < CPLIMIT; i++)
				g_fCheckpointTimesNew[g_iClientInZone[client][2]][client][i] = 0.0;

			// Set missed record time variables
			if (g_iClientInZone[client][2] == 0)
			{
				if (g_fPersonalRecord[client] > 0.0)
					g_bMissedMapBest[client] = false;
			}
			else
			{
				if (g_fPersonalRecordBonus[g_iClientInZone[client][2]][client] > 0.0)
					g_bMissedBonusBest[client] = false;

			}

			// If starting the timer for the first time, print average times
			if (g_bFirstTimerStart[client])
			{
				g_bFirstTimerStart[client] = false;
				Client_Avg(client, 0);
			}
		}
	}

	// Play start sound
	PlayButtonSound(client);

	// Start recording for record bot
	if ((!IsFakeClient(client) && GetConVarBool(g_hReplayBot)) || (!IsFakeClient(client) && GetConVarBool(g_hBonusBot)))
	{
		if (g_hRecording[client] != null)
		{
			StopRecording(client);
		}
		if (IsPlayerAlive(client) || GetClientTeam(client) > 1) // player must be alive and in a valid team (2 or 3)
		{
			StartRecording(client);
		}
	}
}

// End timer
public void CL_OnEndTimerPress(int client)
{
	if (!IsValidClient(client))
		return;

	float endTime = GetGameTime();
	char clientName[MAX_NAME_LENGTH];
	GetClientName(client, clientName, sizeof(clientName));
	// Print bot finishing message to spectators
	if (IsFakeClient(client) && g_bTimeractivated[client])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !IsPlayerAlive(i))
			{
				int SpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
				if (SpecMode == 4 || SpecMode == 5)
				{
					int Target = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
					if (Target == client)
					{
						if (Target == g_RecordBot)
							PrintToChat(i, "%t", "ReplayFinishingMsg", MOSSGREEN, g_szChatPrefix, WHITE, LIMEGREEN, g_szReplayName, GRAY, LIMEGREEN, g_szReplayTime, GRAY);
						if (Target == g_BonusBot)
							PrintToChat(i, "%t", "ReplayFinishingMsgBonus", MOSSGREEN, g_szChatPrefix, WHITE, LIMEGREEN, g_szBonusName, GRAY, YELLOW, g_szZoneGroupName[g_iClientInZone[g_BonusBot][2]], GRAY, LIMEGREEN, g_szBonusTime, GRAY);
					}
				}
			}
		}
		g_bTimeractivated[client] = false;
		PlayButtonSound(client);
		return;
	}

	// If timer is not on, play error sound and return
	if (!g_bTimeractivated[client])
	{
		ClientCommand(client, "play buttons\\button10.wav");
		return;
	}
	else
	{
		PlayButtonSound(client);
	}

	// Get runtime and format it to a string
	g_fFinalTime[client] = endTime - g_fStartTime[client] - g_fPauseTime[client];

	FormatTimeFloat(client, g_fFinalTime[client], 3, g_szFinalTime[client], 32);

	/*============================================
	=            Handle practice mode            =
	============================================*/
	if (g_bPracticeMode[client])
	{
		if (g_iClientInZone[client][2] > 0)
			PrintToChat(client, "[%c%s%c] %c%N %cfinished the bonus with a time of [%c%s%c] in practice mode!", MOSSGREEN, g_szChatPrefix, WHITE, MOSSGREEN, client, WHITE, LIGHTBLUE, g_szFinalTime[client], WHITE);
		else
			PrintToChat(client, "[%c%s%c] %c%N %cfinished the map with a time of [%c%s%c] in practice mode!", MOSSGREEN, g_szChatPrefix, WHITE, MOSSGREEN, client, WHITE, LIGHTBLUE, g_szFinalTime[client], WHITE);

		/* Start function call */
		Call_StartForward(g_PracticeFinishForward);

		/* Push parameters one at a time */
		Call_PushCell(client);
		Call_PushFloat(g_fFinalTime[client]);
		Call_PushString(g_szFinalTime[client]);

		/* Finish the call, get the result */
		Call_Finish();

		return;
	}

	// Set "Map Finished" overlay panel
	g_bOverlay[client] = true;
	g_fLastOverlay[client] = endTime;
	PrintHintText(client, "%t", "TimerStopped", g_szFinalTime[client]);

	// Get Zonegroup
	int zGroup = g_iClientInZone[client][2];

	/*==========================================
	=            Handling map times            =
	==========================================*/
	if (zGroup == 0)
	{
		// Make a new record bot?
		if (GetConVarBool(g_hReplaceReplayTime) && (g_fFinalTime[client] < g_fReplayTimes[0] || g_fReplayTimes[0] <= 0.1)) //never compare floats
		{
			if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client]) //if the replay bot is enabled and the client's position wasn't restored upon joining
			{
				g_fReplayTimes[0] = g_fFinalTime[client];
				g_bNewReplay[client] = true;
				CreateTimer(3.0, ReplayTimer, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
			}
		}

		char szDiff[54];
		float diff;

		// Record bools init
		g_bMapFirstRecord[client] = false;
		g_bMapPBRecord[client] = false;
		g_bMapSRVRecord[client] = false;

		g_OldMapRank[client] = g_MapRank[client];

		diff = g_fPersonalRecord[client] - g_fFinalTime[client];
		FormatTimeFloat(client, diff, 3, szDiff, sizeof(szDiff));
		if (diff > 0.0)
			Format(g_szTimeDifference[client], sizeof(szDiff), "-%s", szDiff);
		else
			Format(g_szTimeDifference[client], sizeof(szDiff), "+%s", szDiff);

		// Check for SR, even if there isn't one already
		if (!g_MapTimesCount || g_fFinalTime[client] < g_fRecordMapTime)
		{  // New fastest time in map
			g_bMapSRVRecord[client] = true;
			g_fRecordMapTime = g_fFinalTime[client];
			Format(g_szRecordPlayer, MAX_NAME_LENGTH, "%N", client);
			FormatTimeFloat(1, g_fRecordMapTime, 3, g_szRecordMapTime, 64);
			// Insert latest record
			db_InsertLatestRecords(g_szSteamID[client], clientName, g_fFinalTime[client]);
			// Update Checkpoints
			if (g_bCheckpointsEnabled[client] && !g_bPositionRestored[client])
			{
				for (int i = 0; i < CPLIMIT; i++)
				{
					g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
				}
				g_bCheckpointRecordFound[zGroup] = true;
			}

			if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client] && !g_bNewReplay[client])
			{
				g_bNewReplay[client] = true;
				g_fReplayTimes[0] = g_fFinalTime[client];
				CreateTimer(3.0, ReplayTimer, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
			}
		}

		// Check for personal record
		if (g_fPersonalRecord[client] <= 0.1)
		{  // Clients first record
			g_fPersonalRecord[client] = g_fFinalTime[client];
			g_pr_finishedmaps[client]++;
			g_MapTimesCount++;
			FormatTimeFloat(1, g_fPersonalRecord[client], 3, g_szPersonalRecord[client], 64);

			g_bMapFirstRecord[client] = true;
			g_pr_showmsg[client] = true;
			db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);
			db_selectRecord(client);
		}
		else if (diff > 0.0)
		{  // Client's new record
			g_fPersonalRecord[client] = g_fFinalTime[client];
			if (GetConVarInt(g_hExtraPoints) > 0)
				g_pr_multiplier[client] += 1; // Improved time, increase multip (how many times the player finished this map)
			FormatTimeFloat(1, g_fPersonalRecord[client], 3, g_szPersonalRecord[client], 64);

			g_bMapPBRecord[client] = true;
			g_pr_showmsg[client] = true;
			db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);

			db_selectRecord(client);

		}

		if (!g_bMapSRVRecord[client] && !g_bMapFirstRecord[client] && !g_bMapPBRecord[client])
		{
			// for ck_min_rank_announce
			db_currentRunRank(client);
		}

		//Challenge
		if (g_bChallenge[client])
		{
			char opponentName[MAX_NAME_LENGTH];

			SetEntityRenderColor(client, 255, 255, 255, 255);
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && i != client && i != g_RecordBot && i != g_BonusBot)
				{
					if (StrEqual(g_szSteamID[i], g_szChallenge_OpponentID[client]))
					{
						if (g_CountdownTime[client] <= 0)
						{
							g_bChallenge[client] = false;
							g_bChallenge[i] = false;
							SetEntityRenderColor(i, 255, 255, 255, 255);
							db_insertPlayerChallenge(client);
							GetClientName(i, opponentName, MAX_NAME_LENGTH);
							PrintToChatAll("%t", "ChallengeW", RED, g_szChatPrefix, WHITE, MOSSGREEN, clientName, WHITE, MOSSGREEN, opponentName, WHITE);
							for (int b = 1; b <= MaxClients; b++)
							{
								ClientCommand(b, "play weapons\\party_horn_01.wav");
							}									
							if (g_Challenge_Bet[client] > 0)
							{
								int lostpoints = g_Challenge_Bet[client] * g_pr_PointUnit;
								PrintToChatAll("%t", "ChallengeL", MOSSGREEN, g_szChatPrefix, WHITE, PURPLE, opponentName, GRAY, RED, lostpoints, GRAY);
								RequestFrame(UpdatePlayerProfile, GetClientSerial(i));
								g_pr_showmsg[client] = true;
							}
							break;
						}
						else
							PrintToChat(client, "[%c%s%c] %cCheater! %cFinishing the challenge before it began. %c Back to the start for you.", MOSSGREEN, g_szChatPrefix, WHITE, DARKRED, RED, DARKRED);
							
					}
				}
			}
		}
		//CS_SetClientAssists(client, 100);
	}
	else
	/*====================================
	=            Handle bonus            =
	====================================*/
	{
		if (GetConVarBool(g_hReplaceReplayTime) && (g_fFinalTime[client] < g_fReplayTimes[zGroup] || g_fReplayTimes[zGroup] <= 0.1)) //never compare floats
		{
			if (GetConVarBool(g_hBonusBot) && !g_bPositionRestored[client])
			{
				g_fReplayTimes[zGroup] = g_fFinalTime[client];
				g_bNewBonus[client] = true;
				Handle pack;
				CreateDataTimer(3.0, BonusReplayTimer, pack);
				WritePackCell(pack, GetClientUserId(client));
				WritePackCell(pack, zGroup);
			}
		}
		char szDiff[54];
		float diff;

		// Record bools init
		g_bBonusFirstRecord[client] = false;
		g_bBonusPBRecord[client] = false;
		g_bBonusSRVRecord[client] = false;

		g_OldMapRankBonus[zGroup][client] = g_MapRankBonus[zGroup][client];

		diff = g_fPersonalRecordBonus[zGroup][client] - g_fFinalTime[client];
		FormatTimeFloat(client, diff, 3, szDiff, sizeof(szDiff));
		if (diff > 0.0)
			Format(g_szBonusTimeDifference[client], sizeof(szDiff), "-%s", szDiff);
		else
			Format(g_szBonusTimeDifference[client], sizeof(szDiff), "+%s", szDiff);

		g_tmpBonusCount[zGroup] = g_iBonusCount[zGroup];

		if (g_iBonusCount[zGroup] > 0)
		{  // If the server already has a record
			if (g_fFinalTime[client] < g_fBonusFastest[zGroup])
			{  // New fastest time in current bonus
				g_fOldBonusRecordTime[zGroup] = g_fBonusFastest[zGroup];
				g_fBonusFastest[zGroup] = g_fFinalTime[client];
				Format(g_szBonusFastest[zGroup], MAX_NAME_LENGTH, "%N", client);
				FormatTimeFloat(1, g_fBonusFastest[zGroup], 3, g_szBonusFastestTime[zGroup], 64);

				// Update Checkpoints
				if (g_bCheckpointsEnabled[client] && !g_bPositionRestored[client])
				{
					for (int i = 0; i < CPLIMIT; i++)
					{
						g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
					}
					g_bCheckpointRecordFound[zGroup] = true;
				}

				g_bBonusSRVRecord[client] = true;
				if (GetConVarBool(g_hBonusBot) && !g_bPositionRestored[client] && !g_bNewBonus[client])
				{
					g_bNewBonus[client] = true;
					g_fReplayTimes[zGroup] = g_fFinalTime[client];
					Handle pack;
					CreateDataTimer(3.0, BonusReplayTimer, pack);
					WritePackCell(pack, GetClientUserId(client));
					WritePackCell(pack, zGroup);
				}
			}
		}
		else
		{  // Has to be the new record, since it is the first completion
			if (GetConVarBool(g_hBonusBot) && !g_bPositionRestored[client] && !g_bNewBonus[client])
			{
				g_bNewBonus[client] = true;
				g_fReplayTimes[zGroup] = g_fFinalTime[client];
				Handle pack;
				CreateDataTimer(3.0, BonusReplayTimer, pack);
				WritePackCell(pack, GetClientUserId(client));
				WritePackCell(pack, zGroup);
			}

			g_fOldBonusRecordTime[zGroup] = g_fBonusFastest[zGroup];
			g_fBonusFastest[zGroup] = g_fFinalTime[client];
			Format(g_szBonusFastest[zGroup], MAX_NAME_LENGTH, "%N", client);
			FormatTimeFloat(1, g_fBonusFastest[zGroup], 3, g_szBonusFastestTime[zGroup], 64);

			// Update Checkpoints
			if (g_bCheckpointsEnabled[client] && !g_bPositionRestored[client])
			{
				for (int i = 0; i < CPLIMIT; i++)
				{
					g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
				}
				g_bCheckpointRecordFound[zGroup] = true;
			}

			g_bBonusSRVRecord[client] = true;

			g_fOldBonusRecordTime[zGroup] = g_fBonusFastest[zGroup];
		}

		if (g_fPersonalRecordBonus[zGroup][client] == 0.0)
		{  // Clients first record
			g_fPersonalRecordBonus[zGroup][client] = g_fFinalTime[client];
			FormatTimeFloat(1, g_fPersonalRecordBonus[zGroup][client], 3, g_szPersonalRecordBonus[zGroup][client], 64);

			g_bBonusFirstRecord[client] = true;
			g_pr_showmsg[client] = true;
			db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);
			db_insertBonus(client, g_szSteamID[client], clientName, g_fFinalTime[client], zGroup);
		}
		else if (diff > 0.0)
		{  // client's new record
			g_fPersonalRecordBonus[zGroup][client] = g_fFinalTime[client];
			FormatTimeFloat(1, g_fPersonalRecordBonus[zGroup][client], 3, g_szPersonalRecordBonus[zGroup][client], 64);

			g_bBonusPBRecord[client] = true;
			g_pr_showmsg[client] = true;
			db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);
			db_updateBonus(client, g_szSteamID[client], clientName, g_fFinalTime[client], zGroup);
		}

		if (!g_bBonusSRVRecord[client] && !g_bBonusFirstRecord[client] && !g_bBonusPBRecord[client])
		{
			db_currentBonusRunRank(client, zGroup);
		}
	}
	Client_Stop(client, 1);
	db_deleteTmp(client);

	//set mvp star
	g_MVPStars[client] += 1;
	//CS_SetMVPCount(client, g_MVPStars[client]);
} 

public void StartStageTimer(int client)
{
	if (!g_bhasStages)
		return;
	if (!IsFakeClient(client))
	{
		if (!g_bServerDataLoaded)
		{
			return;
		}
		else if (g_bLoadingSettings[client])
		{
			return;
		}
		else if (!g_bSettingsLoaded[client])
		{
			return;
		}
	}

	if (g_bPracticeMode[client])
		return;

	int stage = g_Stage[0][client];

	float vPlayerVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vPlayerVelocity);

	/*if (g_fLastSpeed[client] > g_fStageMaxVelocity[stage] && g_fStageMaxVelocity[stage] > 0)
	{
		PrintToChat(client, "[%cSurf Timer%c] %cMax velocity exceeded to start stage %d.", MOSSGREEN, WHITE, LIGHTRED, g_Stage[0][client]);
		return;
	}

	if (g_PlayerJumpsInStage[client] > 1 && !g_bStageIgnorePrehop[stage])
	{
		PrintToChat(client, "[%cSurf Timer%c] %cPrehopping is not allowed on the stage records.", MOSSGREEN, WHITE, LIGHTRED);
		return;
	}*/

	/*Action result;
	Call_StartForward(g_OnTimerStartedForward);
	Call_PushCell(client);
	Call_PushCell(RT_Stage);

	Call_Finish(result);

	if (result == Plugin_Handled)
		return;*/

	g_bStageTimerRunning[client] = true;
	g_fStageStartTime[client] = GetGameTime();

	// Get player velocity
	float vecPlayerVelocity[3], fPlayerVelocity;

	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecPlayerVelocity);
	fPlayerVelocity = GetVectorLength(vecPlayerVelocity);

	g_fPlayerCurrentStartSpeed[client][stage] = fPlayerVelocity;

	// Build Speed difference message
	char speedDiffMsg[128];

	Format(speedDiffMsg, sizeof(speedDiffMsg), "[%c%s%c] Stage: %c%d %cu/s", MOSSGREEN, g_szChatPrefix, WHITE, YELLOW, RoundToCeil(fPlayerVelocity), WHITE);

	if (g_fPlayerStageRecStartSpeed[client][stage] != -1)
	{
		float fDiff = fPlayerVelocity - g_fPlayerStageRecStartSpeed[client][stage];
		char srDiff[16];

		if (fDiff < 0)
			Format(srDiff, sizeof(srDiff), "%c%d%c u/s", RED, RoundToCeil(fDiff), WHITE);
		else
			Format(srDiff, sizeof(srDiff), "%c+%d%c u/s", LIMEGREEN, RoundToCeil(fDiff), WHITE);

		Format(speedDiffMsg, sizeof(speedDiffMsg), "%s | PB: %s", speedDiffMsg, srDiff);
	}

	if (g_StageRecords[stage][srStartSpeed] != -1)
	{
		// Get difference between server record 
		float fDiff = fPlayerVelocity - g_StageRecords[stage][srStartSpeed];
		char srDiff[16];

		if (fDiff < 0)
			Format(srDiff, sizeof(srDiff), "%c%d%c u/s", RED, RoundToCeil(fDiff), WHITE);
		else
			Format(srDiff, sizeof(srDiff), "%c+%d%c u/s", LIMEGREEN, RoundToCeil(fDiff), WHITE);

		Format(speedDiffMsg, sizeof(speedDiffMsg), "%s | SR: %s", speedDiffMsg, srDiff);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		if (GetClientTeam(i) != CS_TEAM_SPECTATOR)
			continue;

		int ObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
		if (ObserverMode != 4 && ObserverMode != 5)
			continue;
			
		int ObserverTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
		if (ObserverTarget != client)
			continue;
		PrintToChat(i, speedDiffMsg);
	}

	PrintToChat(client, speedDiffMsg);
}


public void EndStageTimer(int client)
{
	if (IsFakeClient(client))
		return;

	// Make sure the player is not on the bonus
	if (g_iClientInZone[client][2] != 0)
		return;

	if (!g_bStageTimerRunning[client])
		return;

	// get final timer
	float final_time = GetGameTime();

	g_bStageTimerRunning[client] = false;

	// Calculate run time
	float runtime = final_time - g_fStageStartTime[client];


	int stage = g_Stage[0][client];


	// Get formatted run time
	char runtime_str[32], srdiff_str[32], pbdiff_str[32];
	FormatTimeFloat(client, runtime, 3, runtime_str, 32);

	// Get record diff
	float srdiff = g_StageRecords[stage][srRunTime] - runtime;
	float pbdiff = g_fStagePlayerRecord[client][stage] - runtime;
	
	FormatTimeFloat(client, srdiff, 3, srdiff_str, 32);
	FormatTimeFloat(client, pbdiff, 3, pbdiff_str, 32);

	if (g_StageRecords[stage][srRunTime] != 9999999.0)
	{
		if (srdiff > 0)	
			Format(srdiff_str, sizeof(srdiff_str), "-%s", srdiff_str);
		else
			Format(srdiff_str, sizeof(srdiff_str), "+%s", srdiff_str);
	}
	else if (!g_StageRecords[stage][srLoaded])
		Format(srdiff_str, sizeof(srdiff_str), "N/A");
	else
	{
		Format(srdiff_str, sizeof(srdiff_str), "Not loaded");
		db_loadStageServerRecords(stage);
	}

	if (g_fStagePlayerRecord[client][stage] != 9999999.0)
	{
		if (pbdiff > 0) Format(pbdiff_str, sizeof(pbdiff_str), "-%s", pbdiff_str);
		else
			Format(pbdiff_str, sizeof(pbdiff_str), "+%s", pbdiff_str);
	}
	else
		Format(pbdiff_str, sizeof(pbdiff_str), "N/A");
	char szName[MAX_NAME_LENGTH];
	GetClientName(client, szName, MAX_NAME_LENGTH);
	// Check if the player beaten the record
	if (g_StageRecords[stage][srRunTime] > runtime)
	{
		

		// Check if the stage records were loaded before sending the message
		if (!g_bLoadingStages) {
			// Send message to all players
			//{1:c},{2:s},{3:c},{4:c},{5:s},{6:c},{7:c},{8:D},{9:c},{10:c},{11:s},{12:c}
			//[{1}{2}{3}] {4}{5} {6}has beaten the {7}Stage {8} Record! {9}With a time of ({10}{11}{12})"
			PrintToChat(client, "%t", "StageRecord", MOSSGREEN,g_szChatPrefix, WHITE, LIMEGREEN, szName, GRAY, LIMEGREEN, stage, GRAY, LIMEGREEN, runtime_str, GRAY);

			// Play sound to everyone
			for (int i = 1; i <= MaxClients; i++)
				if (IsClientConnected(i) && IsValidClient(i) && !IsFakeClient(i))
					ClientCommand(i, "play buttons\\blip2");
		}

		if (g_fStagePlayerRecord[client][stage] != 9999999.0)
			db_updateStageRecord(client, stage, runtime);
		else
			db_insertStageRecord(client, stage, runtime);

		// Get player name
		char name[45];
		GetClientName(client, name, sizeof(name));

		strcopy(g_StageRecords[stage][srPlayerName], sizeof(name), name);
		g_StageRecords[stage][srRunTime] = runtime;
		g_StageRecords[stage][srLoaded] = true;
		g_StageRecords[stage][srStartSpeed] = g_fPlayerCurrentStartSpeed[client][stage];

		g_fStagePlayerRecord[client][stage] = runtime;

		//Stage_SaveRecording(client, stage, runtime_str);

		g_fPlayerStageRecStartSpeed[client][stage] = g_fPlayerCurrentStartSpeed[client][stage];

	}
	else if (g_fStagePlayerRecord[client][stage] > runtime)
	{
		// Player beaten his own record
		//"#format"   "{1:c},{2:s},{3:c},{4:c},{5:i},{6:c},{7:s},{8:c},{9:c},{10:s},{11:c},{12:c},{13:s}"
		//"en"        "[{1}{2}{3}] {4}Stage {5} {6}{7} {8}({9}SR {10}{11}) Improving PB by {12}{13}"            
		//                                         1          2               3      4          5      6          7            8      9           10         11    12    13
		PrintToChat(client, "%t", "StageImproved", MOSSGREEN ,g_szChatPrefix ,WHITE ,YELLOW, stage, LIMEGREEN, runtime_str, GRAY, YELLOW, srdiff_str, GRAY, GREEN, pbdiff_str);

		if (g_fStagePlayerRecord[client][stage] != 9999999.0)
			db_updateStageRecord(client, stage, runtime);
		else
			db_insertStageRecord(client, stage, runtime);

		g_fStagePlayerRecord[client][stage] = runtime;
		g_fPlayerStageRecStartSpeed[client][stage] = g_fPlayerCurrentStartSpeed[client][stage];
	}
	else
	{
		// missed sr and pb
		PrintToChat(client, "%t", "StageFinished", MOSSGREEN ,g_szChatPrefix ,WHITE ,YELLOW, stage, LIMEGREEN, runtime_str, GRAY, YELLOW, srdiff_str, GRAY, RED, pbdiff_str);
		
		return;
	}

}