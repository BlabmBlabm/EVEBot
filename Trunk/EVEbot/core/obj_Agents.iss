/*
    Agents class

    Object to contain members related to agents.

    -- GliderPro

*/

objectdef obj_AgentList
{
	variable string SVN_REVISION = "$Rev$"
	variable int Version

	variable string CONFIG_FILE = "${BaseConfig.CONFIG_PATH}/${_Me.Name} Agents.xml"
	variable string SET_NAME1 = "${_Me.Name} Agents"
	variable string SET_NAME2 = "${_Me.Name} Research Agents"
	variable iterator agentIterator
	variable iterator researchAgentIterator

	method Initialize()
	{
		LavishSettings[${This.SET_NAME1}]:Remove
		LavishSettings[${This.SET_NAME2}]:Remove

		LavishSettings:Import[${CONFIG_FILE}]
		LavishSettings[${This.SET_NAME1}]:GetSettingIterator[This.agentIterator]
		LavishSettings[${This.SET_NAME2}]:GetSettingIterator[This.researchAgentIterator]
		UI:UpdateConsole["obj_AgentList: Initialized.", LOG_MINOR]
	}

	method Shutdown()
	{
		LavishSettings[${This.SET_NAME1}]:Remove
		LavishSettings[${This.SET_NAME2}]:Remove
	}

	member:string FirstAgent()
	{
		if ${This.agentIterator:First(exists)}
		{
			return ${This.agentIterator.Key}
		}

		return NULL
	}

	member:string NextAgent()
	{
		if ${This.agentIterator:Next(exists)}
		{
			return ${This.agentIterator.Key}
		}
		elseif ${This.agentIterator:First(exists)}
		{
			return ${This.agentIterator.Key}
		}

		return NULL
	}

	member:string ActiveAgent()
	{
		return ${This.agentIterator.Key}
	}

	member:string NextAvailableResearchAgent()
	{
		if ${This.researchAgentIterator.Key.Length} > 0
		{
			do
			{
				variable time lastCompletionTime
				lastCompletionTime:Set[${Config.Agents.LastCompletionTime[${This.researchAgentIterator.Key}]}]
				UI:UpdateConsole["DEBUG: Last mission for ${This.researchAgentIterator.Key} was completed at ${lastCompletionTime} on ${lastCompletionTime.Date}."]
				lastCompletionTime.Hour:Inc[24]
				lastCompletionTime:Update
				if ${lastCompletionTime.Timestamp} < ${Time.Timestamp}
				{
					return ${This.researchAgentIterator.Key}
				}
			}
			while ${This.researchAgentIterator:Next(exists)}
			This.researchAgentIterator:First
		}

		return NULL
	}
}

objectdef obj_MissionBlacklist
{
	variable string SVN_REVISION = "$Rev$"
	variable int Version

	variable string CONFIG_FILE = "${BaseConfig.CONFIG_PATH}/${_Me.Name} Mission Blacklist.xml"
	variable string SET_NAME = "${_Me.Name} Mission Blacklist"
	variable iterator levelIterator

	method Initialize()
	{
		LavishSettings[${This.SET_NAME}]:Remove
		LavishSettings:Import[${CONFIG_FILE}]
		LavishSettings[${This.SET_NAME}]:GetSetIterator[This.levelIterator]
		UI:UpdateConsole["obj_MissionBlacklist: Initialized.", LOG_MINOR]
	}

	method Shutdown()
	{
		LavishSettings[${This.SET_NAME}]:Remove
	}

	member:bool IsBlacklisted(int level, string mission)
	{
		variable string levelString

		switch ${level}
		{
			case 1
				levelString:Set["Level One"]
				break
			case 2
				levelString:Set["Level Two"]
				break
			case 3
				levelString:Set["Level Three"]
				break
			case 4
				levelString:Set["Level Four"]
				break
			case 5
				levelString:Set["Level Five"]
				break
			default
				levelString:Set["Level One"]
				break
		}

		;;;UI:UpdateConsole["DEBUG: obj_MissionBlacklist: Searching for ${levelString} mission blacklist..."]

		if ${This.levelIterator:First(exists)}
		{
			do
			{
				if ${levelString.Equal[${This.levelIterator.Key}]}
				{
					;;;UI:UpdateConsole["DEBUG: obj_MissionBlacklist: Searching ${levelString} mission blacklist for ${mission}..."]

					variable iterator missionIterator

					This.levelIterator.Value:GetSettingIterator[missionIterator]
					if ${missionIterator:First(exists)}
					{
						do
						{
							if ${mission.Equal[${missionIterator.Key}]}
							{
								;;;UI:UpdateConsole["DEBUG: obj_MissionBlacklist: ${mission} is blacklisted!"]
								return TRUE
							}
						}
						while ${missionIterator:Next(exists)}
					}
				}
			}
			while ${This.levelIterator:Next(exists)}
		}

		return FALSE
	}
}

objectdef obj_Agents
{
	variable string BUTTON_REQUEST_MISSION = "Request Mission"
	variable string BUTTON_VIEW_MISSION = "View Mission"
	variable string BUTTON_BUY_DATACORES = "Buy Datacores"
	variable string BUTTON_COMPLETE_MISSION = "Complete Mission"

	variable string SVN_REVISION = "$Rev$"
	variable int Version

	variable string AgentName
	variable string MissionDetails
	variable int RetryCount = 0
	variable obj_AgentList AgentList
	variable obj_MissionBlacklist MissionBlacklist

    method Initialize()
    {
    	if ${This.AgentList.agentIterator:First(exists)}
    	{
    		This:SetActiveAgent[${This.AgentList.FirstAgent}]
    		UI:UpdateConsole["obj_Agents: Initialized", LOG_MINOR]
    	}
    	else
    	{
			UI:UpdateConsole["obj_Agents: Initialized (No Agents Found)", LOG_MINOR]
		}
    }

	method Shutdown()
	{
	}

	member:int AgentIndex()
	{
		return ${Config.Agents.AgentIndex[${This.AgentName}]}
	}

	member:int AgentID()
	{
		return ${Config.Agents.AgentID[${This.AgentName}]}
	}

	method SetActiveAgent(string name)
	{
		UI:UpdateConsole["obj_Agents: SetActiveAgent ${name}"]

		if ${Config.Agents.AgentIndex[${name}]} > 0
		{
			UI:UpdateConsole["obj_Agents: SetActiveAgent: Found agent data. (${Config.Agents.AgentIndex[${name}]})"]
			This.AgentName:Set[${name}]
		}
		else
		{
			variable int agentIndex = 0
			agentIndex:Set[${Agent[${name}].Index}]
		    if (${agentIndex} <= 0)
		    {
		        UI:UpdateConsole["obj_Agents: ERROR!  Cannot get Index for Agent ${name}.", LOG_CRITICAL]
				This.AgentName:Set[""]
		    }
			else
			{
				This.AgentName:Set[${name}]
				UI:UpdateConsole["obj_Agents: name: ${name}."]
				Config.Agents:SetAgentIndex[${name},${agentIndex}]
				Config.Agents:SetAgentID[${name},${Agent[${agentIndex}].ID}]
				Config.Agents:SetLastDecline[${name},0]
			}
		}
	}

	member:string ActiveAgent()
	{
		return ${This.AgentName}
	}

	member:bool InAgentStation()
	{
		return ${Station.DockedAtStation[${Agent[${This.AgentIndex}].StationID}]}
	}

	member:string PickupStation()
	{
		variable string rVal = ""

	    variable index:agentmission amIndex
	    variable index:bookmark mbIndex
		variable iterator amIterator
		variable iterator mbIterator

	    EVE:DoGetAgentMissions[amIndex]
		amIndex:GetIterator[amIterator]

		if ${amIterator:First(exists)}
		{
			do
			{
				if ${amIterator.Value.AgentID} == ${This.AgentID}
				{
					amIterator.Value:DoGetBookmarks[mbIndex]
					mbIndex:GetIterator[mbIterator]

					if ${mbIterator:First(exists)}
					{
						do
						{
							if ${mbIterator.Value.LocationType.Equal["objective.source"]}
							{
								variable int pos
								rVal:Set[${mbIterator.Value.Label}]
								pos:Set[${rVal.Find[" - "]}]
								rVal:Set[${rVal.Right[${Math.Calc[${rVal.Length}-${pos}-2]}]}]
								UI:UpdateConsole["obj_Agents: rVal = ${rVal}"]
								break
							}
						}
						while ${mbIterator:Next(exists)}
					}
				}

				if ${rVal.Length} > 0
				{
					break
				}
			}
			while ${amIterator:Next(exists)}
		}


		return ${rVal}
	}

	/*  1) Check for offered (but unaccepted) missions
	 *  2) Check the agent list for the first valid agent
	 */
	method PickAgent()
	{
	    variable index:agentmission amIndex
		variable iterator MissionInfo
		variable set skipList

		EVE:DoGetAgentMissions[amIndex]
		amIndex:GetIterator[MissionInfo]
		skipList:Clear

		UI:UpdateConsole["obj_Agents: DEBUG: amIndex.Used = ${amIndex.Used}"]
		if ${MissionInfo:First(exists)}
		{
			do
			{
				UI:UpdateConsole["obj_Agents: DEBUG: This.AgentID = ${This.AgentID}"]
				UI:UpdateConsole["obj_Agents: DEBUG: MissionInfo.AgentID = ${MissionInfo.Value.AgentID}"]
				UI:UpdateConsole["obj_Agents: DEBUG: MissionInfo.State = ${MissionInfo.Value.State}"]
				UI:UpdateConsole["obj_Agents: DEBUG: MissionInfo.Type = ${MissionInfo.Value.Type}"]
				if ${MissionInfo.Value.State} == 1
				{
					if ${MissionBlacklist.IsBlacklisted[${Agent[id,${MissionInfo.Value.AgentID}].Level},"${MissionInfo.Value.Name}"]} == FALSE
					{
						variable bool isLowSec
						variable bool avoidLowSec
						isLowSec:Set[${Missions.MissionCache.LowSec[${MissionInfo.Value.AgentID}]}]
						avoidLowSec:Set[${Config.Missioneer.AvoidLowSec}]
						if ${avoidLowSec} == FALSE || (${avoidLowSec} == TRUE && ${isLowSec} == FALSE)
						{
							if ${MissionInfo.Value.Type.Find[Courier](exists)} && ${Config.Missioneer.RunCourierMissions} == TRUE
							{
								This:SetActiveAgent[${Agent[id,${MissionInfo.Value.AgentID}]}]
								return
							}

							if ${MissionInfo.Value.Type.Find[Trade](exists)} && ${Config.Missioneer.RunTradeMissions} == TRUE
							{
								This:SetActiveAgent[${Agent[id,${MissionInfo.Value.AgentID}]}]
								return
							}

							if ${MissionInfo.Value.Type.Find[Mining](exists)} && ${Config.Missioneer.RunMiningMissions} == TRUE
							{
								This:SetActiveAgent[${Agent[id,${MissionInfo.Value.AgentID}]}]
								return
							}

							if ${MissionInfo.Value.Type.Find[Encounter](exists)} && ${Config.Missioneer.RunKillMissions} == TRUE
							{
								This:SetActiveAgent[${Agent[id,${MissionInfo.Value.AgentID}]}]
								return
							}
						}

						/* if we get here the mission is not acceptable */
						variable time lastDecline
						lastDecline:Set[${Config.Agents.LastDecline[${Agent[id,${MissionInfo.Value.AgentID}]}]}]
						UI:UpdateConsole["obj_Agents: DEBUG: lastDecline = ${lastDecline}"]
						lastDecline.Hour:Inc[4]
						lastDecline:Update
						if ${lastDecline.Timestamp} >= ${Time.Timestamp}
						{
							UI:UpdateConsole["obj_Agents: DEBUG: Skipping mission to avoid standing loss: ${MissionInfo.Value.Name}"]
							skipList:Add[${MissionInfo.Value.AgentID}]
							continue
						}
					}
				}
			}
			while ${MissionInfo:Next(exists)}
		}

		/* if we get here none of the missions in the journal are valid */
		variable string agentName
		agentName:Set[${This.AgentList.NextAvailableResearchAgent}]
		while ${agentName.NotEqual["NULL"]}
		{
			if ${skipList.Contains[${Config.Agents.AgentID[${agentName}]}]} == FALSE
			{
				UI:UpdateConsole["obj_Agents: DEBUG: Setting agent to ${agentName}"]
				This:SetActiveAgent[${agentName}]
				return
			}
			agentName:Set[${This.AgentList.NextAvailableResearchAgent}]
		}

		if ${This.AgentList.agentIterator:First(exists)}
		{
			do
			{
				if ${skipList.Contains[${Config.Agents.AgentID[${This.AgentList.agentIterator.Key}]}]} == FALSE
				{
					UI:UpdateConsole["obj_Agents: DEBUG: Setting agent to ${This.AgentList.agentIterator.Key}"]
					This:SetActiveAgent[${This.AgentList.agentIterator.Key}]
					return
				}
			}
			while ${This.AgentList.agentIterator:Next(exists)}
		}

		/* we should never get here */
		UI:UpdateConsole["obj_Agents.PickAgent: DEBUG: Script paused."]
		Script:Pause
	}

	member:string DropOffStation()
	{
		variable string rVal = ""

	    variable index:agentmission amIndex
	    variable index:bookmark mbIndex
		variable iterator amIterator
		variable iterator mbIterator

	    EVE:DoGetAgentMissions[amIndex]
		amIndex:GetIterator[amIterator]

		if ${amIterator:First(exists)}
		{
			do
			{
				if ${amIterator.Value.AgentID} == ${This.AgentID}
				{
					amIterator.Value:DoGetBookmarks[mbIndex]
					mbIndex:GetIterator[mbIterator]

					if ${mbIterator:First(exists)}
					{
						do
						{
							if ${mbIterator.Value.LocationType.Equal["objective.destination"]}
							{
								variable int pos
								rVal:Set[${mbIterator.Value.Label}]
								pos:Set[${rVal.Find[" - "]}]
								rVal:Set[${rVal.Right[${Math.Calc[${rVal.Length}-${pos}-2]}]}]
								UI:UpdateConsole["obj_Agents: rVal = ${rVal}"]
								break
							}
						}
						while ${mbIterator:Next(exists)}
					}
				}

				if ${rVal.Length} > 0
				{
					break
				}
			}
			while ${amIterator:Next(exists)}
		}


		return ${rVal}
	}

	member:bool HaveMission()
	{
	    variable index:agentmission amIndex
		variable iterator amIterator

		EVE:DoGetAgentMissions[amIndex]
		amIndex:GetIterator[amIterator]

		if ${amIterator:First(exists)}
		{
			do
			{
				if ${amIterator.Value.State} > 1
				{
					if ${MissionBlacklist.IsBlacklisted[${Agent[id,${amIterator.Value.AgentID}].Level},"${amIterator.Value.Name}"]} == FALSE
					{
						variable bool isLowSec
						variable bool avoidLowSec
						isLowSec:Set[${Missions.MissionCache.LowSec[${amIterator.Value.AgentID}]}]
						avoidLowSec:Set[${Config.Missioneer.AvoidLowSec}]
						if ${avoidLowSec} == FALSE || (${avoidLowSec} == TRUE && ${isLowSec} == FALSE)
						{
							if ${amIterator.Value.Type.Find[Courier](exists)} && ${Config.Missioneer.RunCourierMissions} == TRUE
							{
								return TRUE
							}

							if ${amIterator.Value.Type.Find[Trade](exists)} && ${Config.Missioneer.RunTradeMissions} == TRUE
							{
								return TRUE
							}

							if ${amIterator.Value.Type.Find[Mining](exists)} && ${Config.Missioneer.RunMiningMissions} == TRUE
							{
								return TRUE
							}

							if ${amIterator.Value.Type.Find[Encounter](exists)} && ${Config.Missioneer.RunKillMissions} == TRUE
							{
								return TRUE
							}
						}
					}
				}
			}
			while ${amIterator:Next(exists)}
		}

		return FALSE
	}

	function MoveToPickup()
	{
		variable string stationName
		stationName:Set[${EVEDB_Stations.StationName[${Me.StationID}]}]
		UI:UpdateConsole["obj_Agents: DEBUG: stationName = ${stationName}"]

		if ${stationName.Length} > 0
		{
			if ${stationName.NotEqual[${This.PickupStation}]}
			{
				call This.WarpToPickupStation
			}
		}
		else
		{
			call This.WarpToPickupStation
		}

		; sometimes Ship.WarpToBookmark fails so make sure we are docked
		if !${Station.Docked}
		{
			UI:UpdateConsole["obj_Agents.MoveToPickup: ERROR!  Not Docked."]
			call This.WarpToPickupStation
		}
	}

	function MoveToDropOff()
	{
		variable string stationName
		stationName:Set[${EVEDB_Stations.StationName[${Me.StationID}]}]
		UI:UpdateConsole["obj_Agents: DEBUG: stationName = ${stationName}"]

		if ${stationName.Length} > 0
		{
			if ${stationName.NotEqual[${This.DropOffStation}]}
			{
				call This.WarpToDropOffStation
			}
		}
		else
		{
			call This.WarpToDropOffStation
		}

		; sometimes Ship.WarpToBookmark fails so make sure we are docked
		if !${Station.Docked}
		{
			UI:UpdateConsole["obj_Agents.MoveToDropOff: ERROR!  Not Docked."]
			call This.WarpToDropOffStation
		}
	}

	function WarpToPickupStation()
	{
	    variable index:agentmission amIndex
	    variable index:bookmark mbIndex
		variable iterator amIterator
		variable iterator mbIterator

	    EVE:DoGetAgentMissions[amIndex]
		amIndex:GetIterator[amIterator]

		if ${amIterator:First(exists)}
		{
			do
			{
				if ${amIterator.Value.AgentID} == ${This.AgentID}
				{
					amIterator.Value:DoGetBookmarks[mbIndex]
					mbIndex:GetIterator[mbIterator]

					if ${mbIterator:First(exists)}
					{
						do
						{
							UI:UpdateConsole["obj_Agents: DEBUG: mbIterator.Value.LocationType = ${mbIterator.Value.LocationType}"]
							if ${mbIterator.Value.LocationType.Equal["objective.source"]}
							{
								call Ship.WarpToBookMark ${mbIterator.Value}
								return
							}
						}
						while ${mbIterator:Next(exists)}
					}
				}
			}
			while ${amIterator:Next(exists)}
		}
	}

	function WarpToDropOffStation()
	{
	    variable index:agentmission amIndex
	    variable index:bookmark mbIndex
		variable iterator amIterator
		variable iterator mbIterator

	    EVE:DoGetAgentMissions[amIndex]
		amIndex:GetIterator[amIterator]

		if ${amIterator:First(exists)}
		{
			do
			{
				if ${amIterator.Value.AgentID} == ${This.AgentID}
				{
					amIterator.Value:DoGetBookmarks[mbIndex]
					mbIndex:GetIterator[mbIterator]

					if ${mbIterator:First(exists)}
					{
						do
						{
							UI:UpdateConsole["obj_Agents: DEBUG: mbIterator.Value.LocationType = ${mbIterator.Value.LocationType}"]
							if ${mbIterator.Value.LocationType.Equal["objective.destination"]}
							{
								call Ship.WarpToBookMark ${mbIterator.Value}
								return
							}
						}
						while ${mbIterator:Next(exists)}
					}
				}
			}
			while ${amIterator:Next(exists)}
		}
	}

	function MoveTo()
	{
		if !${This.InAgentStation}
		{
			if ${Station.Docked}
			{
				call Station.Undock
			}

			;UI:UpdateConsole["obj_Agents: DEBUG: agentSystem (byname) = ${Universe[${Agent[${This.AgentName}].Solarsystem}].ID}"]
			;UI:UpdateConsole["obj_Agents: DEBUG: agentSystem = ${Universe[${Agent[${This.AgentIndex}].Solarsystem}].ID}"]
			;UI:UpdateConsole["obj_Agents: DEBUG: agentStation = ${Agent[${This.AgentIndex}].StationID}"]
			call Ship.TravelToSystem ${Universe[${Agent[${This.AgentIndex}].Solarsystem}].ID}
			wait 50
			call Station.DockAtStation ${Agent[${This.AgentIndex}].StationID}
		}
	}

	function MissionDetails()
	{
		;EVE:Execute[CmdCloseAllWindows]
		;wait 50

		EVE:Execute[OpenJournal]
		wait 50
		EVE:Execute[CmdCloseActiveWindow]
		wait 50

	    variable index:agentmission amIndex
		variable iterator amIterator

		EVE:DoGetAgentMissions[amIndex]
		amIndex:GetIterator[amIterator]

		if ${amIterator:First(exists)}
		{
			do
			{
				if ${amIterator.Value.AgentID} == ${This.AgentID}
				{
					break
				}
			}
			while ${amIterator:Next(exists)}
		}

		if !${amIterator.Value(exists)}
		{
			UI:UpdateConsole["obj_Agents: ERROR: Did not find mission!  Will retry...", LOG_CRITICAL]
			RetryCount:Inc
			if ${RetryCount} > 4
			{
				UI:UpdateConsole["obj_Agents: ERROR: Retry count exceeded!  Aborting...", LOG_CRITICAL]
				EVEBot.ReturnToStation:Set[TRUE]
			}
			return
		}

		RetryCount:Set[0]

		UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.AgentID = ${amIterator.Value.AgentID}"]
		UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.State = ${amIterator.Value.State}"]
		UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.Type = ${amIterator.Value.Type}"]
		UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.Name = ${amIterator.Value.Name}"]
		UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.Expires = ${amIterator.Value.Expires.DateAndTime}"]

		amIterator.Value:GetDetails
		wait 50
		variable string details
		variable string caption
		variable int left = 0
		variable int right = 0
		caption:Set["${amIterator.Value.Name.Escape}"]
		left:Set[${caption.Escape.Find["u2013"]}]

		if ${left} > 0
		{
			UI:UpdateConsole["obj_Agents: WARNING: Mission name contains u2013"]
			UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.Name.Escape = ${amIterator.Value.Name.Escape}"]

			caption:Set["${caption.Escape.Right[${Math.Calc[${caption.Escape.Length} - ${left} - 5]}]}"]

			UI:UpdateConsole["obj_Agents: DEBUG: caption.Escape = ${caption.Escape}"]
		}

		if !${EVEWindow[ByCaption,"${caption}"](exists)}
		{
			UI:UpdateConsole["obj_Agents: ERROR: Mission details window was not found!"]
			UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.Name.Escape = ${amIterator.Value.Name.Escape}"]
		}
		; The embedded quotes look odd here, but this is required to escape the comma that exists in the caption and in the resulting html.
		details:Set["${EVEWindow[ByCaption,"${caption}"].HTML.Escape}"]

		UI:UpdateConsole["obj_Agents: DEBUG: HTML.Length = ${EVEWindow[ByCaption,${caption}].HTML.Length}"]
		UI:UpdateConsole["obj_Agents: DEBUG: details.Length = ${details.Length}"]

		EVE:Execute[CmdCloseActiveWindow]

		variable file detailsFile
		detailsFile:SetFilename["./config/logs/${amIterator.Value.Expires.AsInt64.Hex} ${amIterator.Value.Name.Replace[",",""]}.html"]
		if ${detailsFile:Open(exists)}
		{
			detailsFile:Write["${details.Escape}"]
		}
		detailsFile:Close

		Missions.MissionCache:AddMission[${amIterator.Value.AgentID},"${amIterator.Value.Name}"]

		variable int factionID = 0
		left:Set[${details.Escape.Find["<img src=\\\"corplogo:"]}]
		if ${left} > 0
		{
			;UI:UpdateConsole["obj_Agents: DEBUG: Found \"corplogo\" at ${left}."]
			left:Inc[23]
			;UI:UpdateConsole["obj_Agents: DEBUG: Found \"corplogo\" at ${left}."]
			;UI:UpdateConsole["obj_Agents: DEBUG: corplogo substring = ${details.Escape.Mid[${left},16]}"]
			right:Set[${details.Escape.Mid[${left},16].Find["\" "]}]
			if ${right} > 0
			{
				right:Dec[2]
				;UI:UpdateConsole["obj_Agents: DEBUG: left = ${left}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: right = ${right}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: string = ${details.Escape.Mid[${left},${right}]}"]
				factionID:Set[${details.Escape.Mid[${left},${right}]}]
				UI:UpdateConsole["obj_Agents: DEBUG: factionID = ${factionID}"]
			}
			else
			{
				UI:UpdateConsole["obj_Agents: ERROR: Did not find end of \"corplogo\"!"]
			}
		}
		else
		{
			UI:UpdateConsole["obj_Agents: DEBUG: Did not find \"corplogo\".  Rogue Drones???"]
		}

		Missions.MissionCache:SetFactionID[${amIterator.Value.AgentID},${factionID}]

		variable int typeID = 0
		left:Set[${details.Escape.Find["<img src=\\\"typeicon:"]}]
		if ${left} > 0
		{
			;UI:UpdateConsole["obj_Agents: DEBUG: Found \"typeicon\" at ${left}."]
			left:Inc[20]
			;UI:UpdateConsole["obj_Agents: DEBUG: typeicon substring = ${details.Escape.Mid[${left},16]}"]
			right:Set[${details.Escape.Mid[${left},16].Find["\" "]}]
			if ${right} > 0
			{
				right:Dec[2]
				;UI:UpdateConsole["obj_Agents: DEBUG: left = ${left}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: right = ${right}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: string = ${details.Escape.Mid[${left},${right}]}"]
				typeID:Set[${details.Escape.Mid[${left},${right}]}]
				UI:UpdateConsole["obj_Agents: DEBUG: typeID = ${typeID}"]
			}
			else
			{
				UI:UpdateConsole["obj_Agents: ERROR: Did not find end of \"typeicon\"!"]
			}
		}
		else
		{
			UI:UpdateConsole["obj_Agents: DEBUG: Did not find \"typeicon\".  No cargo???"]
		}

		Missions.MissionCache:SetTypeID[${amIterator.Value.AgentID},${typeID}]

		variable float volume = 0

		right:Set[${details.Escape.Find["msup3"]}]
		if ${right} > 0
		{
			;UI:UpdateConsole["obj_Agents: DEBUG: Found \"msup3\" at ${right}."]
			right:Dec
			left:Set[${details.Escape.Mid[${Math.Calc[${right}-16]},16].Find[" ("]}]
			if ${left} > 0
			{
				left:Set[${Math.Calc[${right}-16+${left}+1]}]
				right:Set[${Math.Calc[${right}-${left}]}]
				;UI:UpdateConsole["obj_Agents: DEBUG: left = ${left}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: right = ${right}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: string = ${details.Escape.Mid[${left},${right}]}"]
				volume:Set[${details.Escape.Mid[${left},${right}]}]
				UI:UpdateConsole["obj_Agents: DEBUG: volume = ${volume}"]
			}
			else
			{
				UI:UpdateConsole["obj_Agents: ERROR: Did not find number before \"msup3\"!"]
			}
		}
		else
		{
			UI:UpdateConsole["obj_Agents: DEBUG: Did not find \"msup3\".  No cargo???"]
		}

		Missions.MissionCache:SetVolume[${amIterator.Value.AgentID},${volume}]

   		variable bool isLowSec = FALSE
		left:Set[${details.Escape.Find["(Low Sec Warning!)"]}]
        right:Set[${details.Escape.Find["(The route generated by current autopilot settings contains low security systems!)"]}]
		if ${left} > 0 || ${right} > 0
		{
            UI:UpdateConsole["obj_Agents: DEBUG: left = ${left}"]
            UI:UpdateConsole["obj_Agents: DEBUG: right = ${right}"]
			isLowSec:Set[TRUE]
			UI:UpdateConsole["obj_Agents: DEBUG: isLowSec = ${isLowSec}"]
		}
		Missions.MissionCache:SetLowSec[${amIterator.Value.AgentID},${isLowSec}]


  }

	function RequestMission()
	{
		variable index:dialogstring dsIndex
		variable iterator dsIterator

		;EVE:Execute[CmdCloseAllWindows]
		;wait 50

		UI:UpdateConsole["obj_Agents: Starting conversation with agent ${This.ActiveAgent}."]
		Agent[${This.AgentIndex}]:StartConversation
		do
		{
			UI:UpdateConsole["obj_Agents: Waiting for conversation window..."]
			wait 10
		}
		while !${EVEWindow[ByCaption,"Agent Conversation - ${This.ActiveAgent}"](exists)}

		;; The dialog caption fills in long before the details do.
		;; Wait for dialog strings to become valid before proceeding.
		variable int WaitCount
		for( WaitCount:Set[0]; ${WaitCount} < 6; WaitCount:Inc )
		{
			Agent[${This.AgentIndex}]:DoGetDialogResponses[dsIndex]
			if ${dsIndex.Used} > 0
			{
				break
			}
			wait 10
		}

		UI:UpdateConsole["${Agent[${This.AgentIndex}].Name} :: ${Agent[${This.AgentIndex}].Dialog}"]

;;;;  You now longer have to ask for work.  An agent will automatically offer work.  This may break
;;;;  with research or locator agents!
;;;;	    Agent[${This.AgentIndex}]:DoGetDialogResponses[dsIndex]
;;;;	    dsIndex:GetIterator[dsIterator]
;;;;
;;;;		if ${dsIterator:First(exists)}
;;;;		{
;;;;			; Assume the first item is the "ask for work" item.
;;;;			; This may break if you have agents with locator services.
;;;;			if ${Agent[${This.AgentIndex}].Division.Equal["R&D"]}
;;;;			{
;;;;				if ${dsIterator.Value.Text.Find["datacore"]}
;;;;				{
;;;;				    UI:UpdateConsole["WARNING: Research agent doesn't have a mission available"]
;;;;					variable time lastCompletionTime
;;;;					variable int  lastCompletionTimestamp
;;;;					lastCompletionTimestamp:Set[${Config.Agents.LastCompletionTime[${This.AgentName}]}]
;;;;					lastCompletionTime:Set[${lastCompletionTimestamp}]
;;;;					UI:UpdateConsole["DEBUG: RequestMission: ${lastCompletionTime} ${lastCompletionTime.Date}"]
;;;;					if ${lastCompletionTimestamp} == 0
;;;;					{
;;;;				    	;; this agent didn't have a valid LastCompletionTime
;;;;				    	;; set LastCompletionTime to lock out this agent for 24 hours
;;;;	    				Config.Agents:SetLastCompletionTime[${This.AgentName},${Time.Timestamp}]
;;;;	    			}
;;;;	    			else
;;;;	    			{
;;;;						lastCompletionTime.Hour:Inc[24]
;;;;						lastCompletionTime:Update
;;;;						if ${lastCompletionTime.Timestamp} < ${Time.Timestamp}
;;;;						{
;;;;					    	;; been more than 24 hours according to config data.  must be invalid.
;;;;					    	;; set LastCompletionTime to lock out this agent for 24 hours
;;;;		    				Config.Agents:SetLastCompletionTime[${This.AgentName},${Time.Timestamp}]
;;;;						}
;;;;					}
;;;;					return
;;;;				}
;;;;			}
;;;;
;;;;        	dsIterator.Value:Say[${This.AgentID}]
;;;;		}
;;;;
;;;;	    ; Now wait a couple of seconds and then get the new dialog options...and so forth.  The "Wait" needed may differ from person to person.
;;;;	    UI:UpdateConsole["Waiting for agent dialog to update..."]
;;;;	    wait 60
;;;;		UI:UpdateConsole["${Agent[${This.AgentIndex}].Name} :: ${Agent[${This.AgentIndex}].Dialog}"]
;;;;
		UI:UpdateConsole["obj_Agents: Refreshing Dialog Responses"]
		Agent[${This.AgentIndex}]:DoGetDialogResponses[dsIndex]
		dsIndex:GetIterator[dsIterator]

		/* Fix for locator agents that also have missions, by Stealthy */
		if (${dsIterator:First(exists)})
		{
			do
			{
				UI:UpdateConsole["obj_Agents: dsIterator.Value.Text: ${dsIterator.Value.Text}"]

				if (${dsIterator.Value.Text.Find["${This.BUTTON_VIEW_MISSION}"]} || ${dsIterator.Value.Text.Find["${This.BUTTON_REQUEST_MISSION}"]})
				{
					UI:UpdateConsole["obj_Agents: May be a locator agent, attempting to view mission..."]
					dsIterator.Value:Say[${This.AgentID}]
					break
				}
			}
			while (${dsIterator:Next(exists)})
			;UI:UpdateConsole["obj_Agents: Waiting for dialog to update..."]
			wait 100
		}

		UI:UpdateConsole["obj_Agents: Refreshing Dialog Responses"]
		Agent[${This.AgentIndex}]:DoGetDialogResponses[dsIndex]
		dsIndex:GetIterator[dsIterator]

		if ${dsIndex.Used} != 3
		{
			UI:UpdateConsole["obj_Agents: ERROR: Did not find expected dialog! (dsIndex.Used=${dsIndex.Used} Will retry...", LOG_CRITICAL]
			if ${dsIterator:First(exists)}
			{
				do
				{
					if ${dsIterator.Value.Text.Find["${This.BUTTON_BUY_DATACORES}"]}
					{
						UI:UpdateConsole["obj_Agents: Agent has no mission available"]
						This:SetActiveAgent[${This.AgentList.NextAgent}]
						return
					}
					;UI:UpdateConsole["obj_Agents: ${dsIterator.Value.Text}"]
				}
				while ${dsIterator:Next(exists)}
			}
			RetryCount:Inc
			if ${RetryCount} > 4
			{
				UI:UpdateConsole["obj_Agents: ERROR: Retry count exceeded!  Aborting...", LOG_CRITICAL]
				EVEBot.ReturnToStation:Set[TRUE]
			}
			EVE:Execute[CmdCloseActiveWindow]
			wait 10
			return
		}

		wait 10
		EVE:Execute[OpenJournal]
		wait 50
		EVE:Execute[CmdCloseActiveWindow]
		wait 50

		variable index:agentmission amIndex
		variable iterator amIterator

		EVE:DoGetAgentMissions[amIndex]
		amIndex:GetIterator[amIterator]

		if ${amIterator:First(exists)}
		{
			do
			{
				if ${amIterator.Value.AgentID} == ${This.AgentID}
				{
					break
				}
			}
			while ${amIterator:Next(exists)}
		}

		if !${amIterator.Value(exists)}
		{
			UI:UpdateConsole["obj_Agents: ERROR: Did not find mission!  Will retry...", LOG_CRITICAL]
			RetryCount:Inc
			if ${RetryCount} > 4
			{
				UI:UpdateConsole["obj_Agents: ERROR: Retry count exceeded!  Aborting...", LOG_CRITICAL]
				EVEBot.ReturnToStation:Set[TRUE]
			}
			return
		}

		RetryCount:Set[0]

		UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.AgentID = ${amIterator.Value.AgentID}"]
		UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.State = ${amIterator.Value.State}"]
		UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.Type = ${amIterator.Value.Type}"]
		UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.Name = ${amIterator.Value.Name}"]
		UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.Expires = ${amIterator.Value.Expires.DateAndTime}"]

		amIterator.Value:GetDetails
		wait 50
		variable string details
		variable string caption
		variable int left = 0
		variable int right = 0
		caption:Set["${amIterator.Value.Name.Escape}"]
		left:Set[${caption.Escape.Find["u2013"]}]

		if ${left} > 0
		{
			UI:UpdateConsole["obj_Agents: WARNING: Mission name contains u2013"]
			UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.Name.Escape = ${amIterator.Value.Name.Escape}"]

			caption:Set["${caption.Escape.Right[${Math.Calc[${caption.Escape.Length} - ${left} - 5]}]}"]

			UI:UpdateConsole["obj_Agents: DEBUG: caption.Escape = ${caption.Escape}"]
		}

		if !${EVEWindow[ByCaption,"${caption}"](exists)}
		{
			UI:UpdateConsole["obj_Agents: ERROR: Mission details window was not found!"]
			UI:UpdateConsole["obj_Agents: DEBUG: amIterator.Value.Name.Escape = ${amIterator.Value.Name.Escape}"]
		}
		; The embedded quotes look odd here, but this is required to escape the comma that exists in the caption and in the resulting html.
		details:Set["${EVEWindow[ByCaption,"${caption}"].HTML.Escape}"]

		UI:UpdateConsole["obj_Agents: DEBUG: HTML.Length = ${EVEWindow[ByCaption,${caption}].HTML.Length}"]
		UI:UpdateConsole["obj_Agents: DEBUG: details.Length = ${details.Length}"]

		EVE:Execute[CmdCloseActiveWindow]

		variable file detailsFile
		detailsFile:SetFilename["./config/logs/${amIterator.Value.Expires.AsInt64.Hex} ${amIterator.Value.Name.Replace[",",""]}.html"]
		if ${detailsFile:Open(exists)}
		{
			detailsFile:Write["${details.Escape}"]
		}
		detailsFile:Close

		Missions.MissionCache:AddMission[${amIterator.Value.AgentID},"${amIterator.Value.Name}"]

		variable int factionID = 0
		left:Set[${details.Escape.Find["<img src=\\\"corplogo:"]}]
		if ${left} > 0
		{
			;UI:UpdateConsole["obj_Agents: DEBUG: Found \"corplogo\" at ${left}."]
			left:Inc[23]
			;UI:UpdateConsole["obj_Agents: DEBUG: Found \"corplogo\" at ${left}."]
			;UI:UpdateConsole["obj_Agents: DEBUG: corplogo substring = ${details.Escape.Mid[${left},16]}"]
			right:Set[${details.Escape.Mid[${left},16].Find["\" "]}]
			if ${right} > 0
			{
				right:Dec[2]
				;UI:UpdateConsole["obj_Agents: DEBUG: left = ${left}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: right = ${right}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: string = ${details.Escape.Mid[${left},${right}]}"]
				factionID:Set[${details.Escape.Mid[${left},${right}]}]
				UI:UpdateConsole["obj_Agents: DEBUG: factionID = ${factionID}"]
			}
			else
			{
				UI:UpdateConsole["obj_Agents: ERROR: Did not find end of \"corplogo\"!"]
			}
		}
		else
		{
			UI:UpdateConsole["obj_Agents: DEBUG: Did not find \"corplogo\".  Rouge Drones???"]
		}

		Missions.MissionCache:SetFactionID[${amIterator.Value.AgentID},${factionID}]

		variable int typeID = 0
		left:Set[${details.Escape.Find["<img src=\\\"typeicon:"]}]
		if ${left} > 0
		{
			;UI:UpdateConsole["obj_Agents: DEBUG: Found \"typeicon\" at ${left}."]
			left:Inc[20]
			;UI:UpdateConsole["obj_Agents: DEBUG: typeicon substring = ${details.Escape.Mid[${left},16]}"]
			right:Set[${details.Escape.Mid[${left},16].Find["\" "]}]
			if ${right} > 0
			{
				right:Dec[2]
				;UI:UpdateConsole["obj_Agents: DEBUG: left = ${left}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: right = ${right}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: string = ${details.Escape.Mid[${left},${right}]}"]
				typeID:Set[${details.Escape.Mid[${left},${right}]}]
				UI:UpdateConsole["obj_Agents: DEBUG: typeID = ${typeID}"]
			}
			else
			{
				UI:UpdateConsole["obj_Agents: ERROR: Did not find end of \"typeicon\"!"]
			}
		}
		else
		{
			UI:UpdateConsole["obj_Agents: DEBUG: Did not find \"typeicon\".  No cargo???"]
		}

		Missions.MissionCache:SetTypeID[${amIterator.Value.AgentID},${typeID}]

		variable float volume = 0

		right:Set[${details.Escape.Find["msup3"]}]
		if ${right} > 0
		{
			;UI:UpdateConsole["obj_Agents: DEBUG: Found \"msup3\" at ${right}."]
			right:Dec
			left:Set[${details.Escape.Mid[${Math.Calc[${right}-16]},16].Find[" ("]}]
			if ${left} > 0
			{
				left:Set[${Math.Calc[${right}-16+${left}+1]}]
				right:Set[${Math.Calc[${right}-${left}]}]
				;UI:UpdateConsole["obj_Agents: DEBUG: left = ${left}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: right = ${right}"]
				;UI:UpdateConsole["obj_Agents: DEBUG: string = ${details.Escape.Mid[${left},${right}]}"]
				volume:Set[${details.Escape.Mid[${left},${right}]}]
				UI:UpdateConsole["obj_Agents: DEBUG: volume = ${volume}"]
			}
			else
			{
				UI:UpdateConsole["obj_Agents: ERROR: Did not find number before \"msup3\"!"]
			}
		}
		else
		{
			UI:UpdateConsole["obj_Agents: DEBUG: Did not find \"msup3\".  No cargo???"]
		}

		Missions.MissionCache:SetVolume[${amIterator.Value.AgentID},${volume}]

			variable bool isLowSec = FALSE
		left:Set[${details.Escape.Find["(Low Sec Warning!)"]}]
		right:Set[${details.Escape.Find["(The route generated by current autopilot settings contains low security systems!)"]}]
		if ${left} > 0 || ${right} > 0
		{
			UI:UpdateConsole["obj_Agents: DEBUG: left = ${left}"]
			UI:UpdateConsole["obj_Agents: DEBUG: right = ${right}"]
			isLowSec:Set[TRUE]
			UI:UpdateConsole["obj_Agents: DEBUG: isLowSec = ${isLowSec}"]
		}

		Missions.MissionCache:SetLowSec[${amIterator.Value.AgentID},${isLowSec}]

		variable time lastDecline
		lastDecline:Set[${Config.Agents.LastDecline[${This.AgentName}]}]
		lastDecline.Hour:Inc[4]
		lastDecline:Update

		if ${isLowSec} && ${Config.Missioneer.AvoidLowSec} == TRUE
		{
			if ${lastDecline.Timestamp} >= ${Time.Timestamp}
			{
				UI:UpdateConsole["obj_Agents: ERROR: You declined a mission less than four hours ago!  Switching agents...", LOG_CRITICAL]
				This:SetActiveAgent[${This.AgentList.NextAgent}]
				return
			}
			else
			{
				dsIndex.Get[2]:Say[${This.AgentID}]
				Config.Agents:SetLastDecline[${This.AgentName},${Time.Timestamp}]
				UI:UpdateConsole["obj_Agents: Declined low-sec mission."]
				Config:Save[]
			}
		}
		elseif ${MissionBlacklist.IsBlacklisted[${Agent[id,${amIterator.Value.AgentID}].Level},"${amIterator.Value.Name}"]} == TRUE
		{
			if ${lastDecline.Timestamp} >= ${Time.Timestamp}
			{
				UI:UpdateConsole["obj_Agents: ERROR: You declined a mission less than four hours ago!  Switching agents...", LOG_CRITICAL]
				This:SetActiveAgent[${This.AgentList.NextAgent}]
				return
			}
			else
			{
				dsIndex.Get[2]:Say[${This.AgentID}]
				Config.Agents:SetLastDecline[${This.AgentName},${Time.Timestamp}]
				UI:UpdateConsole["obj_Agents: Declined blacklisted mission."]
				Config:Save[]
			}
		}
		elseif ${amIterator.Value.Type.Find[Courier](exists)} && ${Config.Missioneer.RunCourierMissions} == TRUE
		{
			dsIndex.Get[1]:Say[${This.AgentID}]
		}
		elseif ${amIterator.Value.Type.Find[Trade](exists)} && ${Config.Missioneer.RunTradeMissions} == TRUE
		{
			dsIndex.Get[1]:Say[${This.AgentID}]
		}
		elseif ${amIterator.Value.Type.Find[Mining](exists)} && ${Config.Missioneer.RunMiningMissions} == TRUE
		{
			dsIndex.Get[1]:Say[${This.AgentID}]
		}
		elseif ${amIterator.Value.Type.Find[Encounter](exists)} && ${Config.Missioneer.RunKillMissions} == TRUE
		{
			dsIndex.Get[1]:Say[${This.AgentID}]
		}
		else
		{
			if ${lastDecline.Timestamp} >= ${Time.Timestamp}
			{
				UI:UpdateConsole["obj_Agents: ERROR: You declined a mission less than four hours ago!  Switching agents...", LOG_CRITICAL]
				This:SetActiveAgent[${This.AgentList.NextAgent}]
				return
			}
			else
			{
				dsIndex.Get[2]:Say[${This.AgentID}]
				Config.Agents:SetLastDecline[${This.AgentName},${Time.Timestamp}]
				UI:UpdateConsole["obj_Agents: Declined mission."]
				Config:Save[]
			}
		}

		UI:UpdateConsole["Waiting for mission dialog to update..."]
		wait 60
		UI:UpdateConsole["${Agent[${This.AgentIndex}].Name} :: ${Agent[${This.AgentIndex}].Dialog}"]

		EVE:Execute[OpenJournal]
		wait 50
		EVE:Execute[CmdCloseActiveWindow]
		wait 50

		EVEWindow[ByCaption,"Agent Conversation - ${This.ActiveAgent}"]:Close
	}

	function TurnInMission()
	{
		;EVE:Execute[CmdCloseAllWindows]
		;wait 50

		UI:UpdateConsole["obj_Agents: Starting conversation with agent ${This.ActiveAgent}."]
		Agent[${This.AgentIndex}]:StartConversation
        do
        {
			UI:UpdateConsole["obj_Agents: Waiting for conversation window..."]
            wait 10
        }
        while !${EVEWindow[ByCaption,"Agent Conversation - ${This.ActiveAgent}"](exists)}

		UI:UpdateConsole["${Agent[${This.AgentIndex}].Name} :: ${Agent[${This.AgentIndex}].Dialog}"]

	    ; display your dialog options
	    variable index:dialogstring dsIndex
	    variable iterator dsIterator

	    Agent[${This.AgentIndex}]:DoGetDialogResponses[dsIndex]
	    dsIndex:GetIterator[dsIterator]

		if (${dsIterator:First(exists)})
		{
			do
			{
				UI:UpdateConsole["obj_Agents:TurnInMission dsIterator.Value.Text: ${dsIterator.Value.Text}"]
				if (${dsIterator.Value.Text.Find["${This.BUTTON_VIEW_MISSION}"]})
				{
					dsIterator.Value:Say[${This.AgentID}]
					Config.Agents:SetLastCompletionTime[${This.AgentName},${Time.Timestamp}]
					break
				}
			}
			while (${dsIterator:Next(exists)})
		}

	    ; Now wait a couple of seconds and then get the new dialog options...and so forth.  The "Wait" needed may differ from person to person.
	    UI:UpdateConsole["Waiting for agent dialog to update..."]
	    wait 60

	    Agent[${This.AgentIndex}]:DoGetDialogResponses[dsIndex]
	    dsIndex:GetIterator[dsIterator]
	    UI:UpdateConsole["Completing Mission..."]
	    dsIndex.Get[1]:Say[${This.AgentID}]

		UI:UpdateConsole["Waiting for mission dialog to update..."]
		wait 60
		UI:UpdateConsole["${Agent[${This.AgentIndex}].Name} :: ${Agent[${This.AgentIndex}].Dialog}"]

		EVE:Execute[OpenJournal]
		wait 50
		EVE:Execute[CmdCloseActiveWindow]
		wait 50

		EVEWindow[ByCaption,"Agent Conversation - ${This.ActiveAgent}"]:Close
	}

	function QuitMission()
	{
		;EVE:Execute[CmdCloseAllWindows]
		;wait 50

		UI:UpdateConsole["obj_Agents: Starting conversation with agent ${This.ActiveAgent}."]
		Agent[${This.AgentIndex}]:StartConversation
		do
		{
			UI:UpdateConsole["obj_Agents: Waiting for conversation window..."]
			wait 10
		}
		while !${EVEWindow[ByCaption,"Agent Conversation - ${This.ActiveAgent}"](exists)}

		UI:UpdateConsole["${Agent[${This.AgentIndex}].Name} :: ${Agent[${This.AgentIndex}].Dialog}"]

		; display your dialog options
		variable index:dialogstring dsIndex
		variable iterator dsIterator

		Agent[${This.AgentIndex}]:DoGetDialogResponses[dsIndex]
		dsIndex:GetIterator[dsIterator]

		if ${dsIndex.Used} == 2
		{
			; Assume the second item is the "quit mission" item.
			dsIndex.Get[2]:Say[${This.AgentID}]
		}

		; Now wait a couple of seconds and then get the new dialog options...and so forth.  The "Wait" needed may differ from person to person.
		UI:UpdateConsole["Waiting for agent dialog to update..."]
		wait 60
		UI:UpdateConsole["${Agent[${This.AgentIndex}].Name} :: ${Agent[${This.AgentIndex}].Dialog}"]

		EVE:Execute[OpenJournal]
		wait 50
		EVE:Execute[CmdCloseActiveWindow]
		wait 50

		EVEWindow[ByCaption,"Agent Conversation - ${This.ActiveAgent}"]:Close
	}
}
