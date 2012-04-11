/*
	Hauler Class
	
	Primary Hauler behavior module for EVEBot
	
	-- Tehtsuo
	
	(Recycled mainly from GliderPro I believe)
*/

objectdef obj_FullMiner
{
	variable int64 FleetMemberID
	variable int64 SystemID
	variable int64 BeltID

	method Initialize(int64 arg_FleetMemberID, int64 arg_SystemID, int64 arg_BeltID)
	{
		FleetMemberID:Set[${arg_FleetMemberID}]
		SystemID:Set[${arg_SystemID}]
		BeltID:Set[${arg_BeltID}]
		UI:UpdateConsole[ "DEBUG: obj_OreHauler:FullMiner: FleetMember: ${FleetMemberID} System: ${SystemID} Belt: ${Entity[${BeltID}].Name}", LOG_DEBUG]
	}
}

	
objectdef obj_OreHauler inherits obj_Hauler
{
	;	Versioning information
	variable string SVN_REVISION = "$Rev$"
	variable int Version

	variable collection:obj_FullMiner FullMiners

	;	State information (What we're doing)
	variable string CurrentState

	;	Pulse tracking information
	variable time NextPulse
	variable int PulseIntervalInSeconds = 2

	variable index:bookmark SafeSpots
	variable iterator SafeSpotIterator

	variable queue:fleetmember FleetMembers
	variable queue:entity     Entities

	variable bool PickupFailed = FALSE

	
/*	
;	Step 1:  	Get the module ready.  This includes init and shutdown methods, as well as the pulse method that runs each frame.
;				Adjust PulseIntervalInSeconds above to determine how often the module will SetState.
*/	
	
	method Initialize(string player, string corp)
	{
		m_CheckedCargo:Set[FALSE]
		UI:UpdateConsole["obj_OreHauler: Initialized", LOG_MINOR]
		Event[EVENT_ONFRAME]:AttachAtom[This:Pulse]
		LavishScript:RegisterEvent[EVEBot_Miner_Full]
		Event[EVEBot_Miner_Full]:AttachAtom[This:MinerFull]
		BotModules:Insert["Hauler"]
	}


	method Pulse()
	{
		if ${EVEBot.Paused}
		{
			return
		}

		if !${Config.Common.BotModeName.Equal[Hauler]}
		{
			return
		}

	    if ${Time.Timestamp} >= ${This.NextPulse.Timestamp}
		{
			This:SetState[]

    		This.NextPulse:Set[${Time.Timestamp}]
    		This.NextPulse.Second:Inc[${This.PulseIntervalInSeconds}]
    		This.NextPulse:Update
		}
	}

	method Shutdown()
	{
		Event[EVENT_ONFRAME]:DetachAtom[This:Pulse]
		Event[EVEBot_Miner_Full]:DetachAtom[This:MinerFull]
	}


/*	
;	Step 2:  	SetState:  This is the brain of the module.  Every time it is called - See Step 1 - this method will determine
;				what the module should be doing based on what's going on around you.  This will be used when EVEBot calls your module to ProcessState.
*/		
	
	/* NOTE: The order of these if statements is important!! */
	method SetState()
	{
		;	First, we need to check to find out if I should "HARD STOP" - dock and wait for user intervention.  Reasons to do this:
		;	*	If someone targets us
		;	*	They're lower than acceptable Min Security Status on the Miner tab
		;	*	I'm in a pod.  Oh no!
		if (${Social.PossibleHostiles} || ${Ship.IsPod}) && !${EVEBot.ReturnToStation}
		{
			This.CurrentState:Set["HARDSTOP"]
			UI:UpdateConsole["HARD STOP: Possible hostiles, cargo hold not changing, or ship in a pod!"]
			EVEBot.ReturnToStation:Set[TRUE]
			return
		}

		;	If we're in a station HARD STOP has been called for, just idle until user intervention
		if ${EVEBot.ReturnToStation} && ${Me.InStation}
		{
			This.CurrentState:Set["IDLE"]
			return
		}
		
		;	If we're in space and HARD STOP has been called for, try to get to a station
		if ${EVEBot.ReturnToStation} && !${Me.InStation}
		{
			This.CurrentState:Set["HARDSTOP"]
			return
		}

		;	Find out if we should "SOFT STOP" and flee.  Reasons to do this:
		;	*	Pilot lower than Min Acceptable Standing on the Fleeing tab
		;	*	Pilot is on Blacklist ("Run on Blacklisted Pilot" enabled on Fleeing tab)
		;	*	Pilot is not on Whitelist ("Run on Non-Whitelisted Pilot" enabled on Fleeing tab)
		;	This checks for both In Station and out, preventing spam if you're in a station.
		if !${Social.IsSafe}  && !${EVEBot.ReturnToStation} && !${Me.InStation}
		{
			This.CurrentState:Set["FLEE"]
			UI:UpdateConsole["FLEE: Low Standing player or system unsafe, fleeing"]
			return
		}
		if !${Social.IsSafe}  && !${EVEBot.ReturnToStation} && ${Me.InStation}
		{
			This.CurrentState:Set["IDLE"]
			return
		}
		
				;	If I'm in a station, I need to perform what I came there to do
		if ${Me.InStation} == TRUE
		{
	  		This.CurrentState:Set["BASE"]
	  		return
		}

		;	If I'm not in a station and I'm full, I should head to a station to unload - Ignore dropoff if Orca Delivery is disabled.
	    if ${This.MinerFull}
		{
			This.CurrentState:Set["DROPOFF"]
			return
		}

		if ${Me.InStation}
		{
	  		This.CurrentState:Set["INSTATION"]
		}
		elseif ${This.PickupFailed} || ${Ship.CargoFreeSpace} < 1000
		{
			This.CurrentState:Set["CARGOFULL"]
		}
		elseif ${Ship.CargoFreeSpace} > ${Ship.CargoMinimumFreeSpace}
		{
		 	This.CurrentState:Set["HAUL"]
		}
		else
		{
			This.CurrentState:Set["Unknown"]
		}
	}


	
	/* A miner's jetcan is full.  Let's go get the ore.  */
	method MinerFull(string haulParams)
	{
		variable int64 charID = -1
		variable int64 systemID = -1
		variable int64 beltID = -1

		if !${Config.Common.BotModeName.Equal[Hauler]}
		{
			return
		}

		charID:Set[${haulParams.Token[1,","]}]
		systemID:Set[${haulParams.Token[2,","]}]
		beltID:Set[${haulParams.Token[3,","]}]

		; Logging is done by obj_FullMiner initialize
		FullMiners:Set[${charID},${charID},${systemID},${beltID}]
	}

	
	/* this function is called repeatedly by the main loop in EveBot.iss */
	function ProcessState()
	{
		switch ${This.CurrentState}
		{
			case IDLE
				Ship:Activate_Gang_Links
				break
			case FLEE
				if ${Me.InStation}
				{
					break
				}
				if ${EVE.Bookmark[${Config.Miner.DeliveryLocation}](exists)} && ${EVE.Bookmark[${Config.Miner.DeliveryLocation}].SolarSystemID} == ${Me.SolarSystemID}
				{
					call Station.DockAtStation ${EVE.Bookmark[${Config.Miner.DeliveryLocation}].ItemID}
					break
				}
				if ${Me.ToEntity.Mode} != 3
				{
					call Safespots.WarpTo
					wait 30
				}
				; Call Station.Dock
				; Call This.Abort_Check
				break
			case INSTATION
				call Cargo.TransferCargoToHangar
				call Station.Undock
				break
			case HAUL
				if ${EVE.Bookmark[${Config.Hauler.MiningSystemBookmark}](exists)} && ${EVE.Bookmark[${Config.Miner.MiningSystemBookmark}].SolarSystemID} != ${Me.SolarSystemID}
				{
					call Ship.TravelToSystem ${EVE.Bookmark[${Config.Hauler.MiningSystemBookmark}].SolarSystemID}
				}
			
				Ship:Activate_Gang_Links
				call This.Haul
				break
			case CARGOFULL
				Ship:Activate_Gang_Links
				call This.DropOff
				This.PickupFailed:Set[FALSE]
				break
		}
	}


	function LootEntity(int64 id, int leave = 0)
	{
		variable index:item ContainerCargo
		variable iterator Cargo
		variable int QuantityToMove

		if ${id.Equal[0]}
		{
			return
		}

		UI:UpdateConsole["obj_OreHauler.LootEntity ${Entity[${id}].Name}(${id}) - Leaving ${leave} units"]

		Entities.Peek:OpenCargo
		wait 20
		Entity[${id}]:GetCargo[ContainerCargo]
		ContainerCargo:GetIterator[Cargo]
		if ${Cargo:First(exists)}
		{
			do
			{
				UI:UpdateConsole["Hauler: Found ${Cargo.Value.Quantity} x ${Cargo.Value.Name} - ${Math.Calc[${Cargo.Value.Quantity} * ${Cargo.Value.Volume}]}m3"]
				if (${Cargo.Value.Quantity} * ${Cargo.Value.Volume}) > ${Ship.CargoFreeSpace}
				{
					/* Move only what will fit, minus 1 to account for CCP rounding errors. */
					QuantityToMove:Set[${Math.Calc[${Ship.CargoFreeSpace} / ${Cargo.Value.Volume}]}]
					if ${QuantityToMove} <= 0
					{
						This.PickupFailed:Set[TRUE]
					}
				}
				else
				{
					QuantityToMove:Set[${Math.Calc[${Cargo.Value.Quantity} - ${leave}]}]
					leave:Set[0]
				}

				UI:UpdateConsole["Hauler: Moving ${QuantityToMove} units: ${Math.Calc[${QuantityToMove} * ${Cargo.Value.Volume}]}m3"]
				if ${QuantityToMove} > 0
				{
					Cargo.Value:MoveTo[MyShip,CargoHold,${QuantityToMove}]
					wait 30
					if ${Ship.CargoFreeSpace} < 1000
					{
						break
					}
				}

				if ${Ship.CargoFreeSpace} < 1000
				{
					/* TODO - this needs to keep a queue of bookmarks, named for the can ie, "Can CORP hh:mm", of partially looted cans */
					/* Be sure its names, and not ID.  We shouldn't store anything in a bookmark name that we shouldnt know */

					UI:UpdateConsole["DEBUG: obj_Hauler.LootEntity: Ship Cargo Free Space: ${Ship.CargoFreeSpace} < ${Ship.CargoMinimumFreeSpace}"]
					break
				}
			}
			while ${Cargo:Next(exists)}
		}

		EVEWindow[ByName,${MyShip.ID}]:StackAll
		wait 10
		EVEWindow[ByName,${MyShip.ID}]:Close
		wait 10
	}


	function Haul()
	{
		switch ${Config.Hauler.HaulerModeName}
		{
			case Service On-Demand
				call This.HaulOnDemand
				break
			case Service Gang Members
			case Service Fleet Members
				call This.HaulForFleet
				break
			case Service All Belts
				call This.HaulAllBelts
				break
			case Service Orca
				call This.ServiceOrca
				break
		}
	}

	function DropOff()
	{
		if !${EVE.Bookmark[${Config.Miner.DeliveryLocation}](exists)}
		{
			UI:UpdateConsole["ERROR: ORE Delivery location & type must be specified (on the miner tab) - docking"]
			EVEBot.ReturnToStation:Set[TRUE]
			return
		}
		switch ${Config.Miner.DeliveryLocationTypeName}
		{
			case Station
				call Ship.TravelToSystem ${EVE.Bookmark[${Config.Miner.DeliveryLocation}].SolarSystemID}
				call Station.DockAtStation ${EVE.Bookmark[${Config.Miner.DeliveryLocation}].ItemID}
				break
			case Hangar Array
				call Ship.WarpToBookMarkName "${Config.Miner.DeliveryLocation}"
				call Cargo.TransferOreToCorpHangarArray
				break
			case Large Ship Assembly Array
				call Ship.WarpToBookMarkName "${Config.Miner.DeliveryLocation}"
				call Cargo.TransferOreToLargeShipAssemblyArray
				break
			case XLarge Ship Assembly Array
				call Ship.WarpToBookMarkName "${Config.Miner.DeliveryLocation}"
				call Cargo.TransferOreToXLargeShipAssemblyArray
				break
			case Jetcan
				UI:UpdateConsole["ERROR: ORE Delivery location may not be jetcan when in hauler mode - docking"]
				EVEBot.ReturnToStation:Set[TRUE]
				break
			Default
				UI:UpdateConsole["ERROR: Delivery Location Type ${Config.Miner.DeliveryLocationTypeName} unknown"]
				EVEBot.ReturnToStation:Set[TRUE]
				break
		}
	}

	/* The HaulOnDemand function will be called repeatedly   */
	/* until we leave the HAUL state due to downtime,        */
	/* agression, or a full cargo hold.  The Haul function   */
	/* should do one (and only one) of the following actions */
	/* each it is called.									 */
	/*                                                       */
	/* 1) Warp to fleet member and loot nearby cans           */
	/* 2) Warp to next safespot                              */
	/* 3) Travel to new system (if required)                 */
	/*                                                       */
	function HaulOnDemand()
	{
		while ${CurrentState.Equal[HAUL]} && ${FullMiners.FirstValue(exists)}
		{
			UI:UpdateConsole["${FullMiners.Used} cans to get! Picking up can at ${FullMiners.FirstKey}", LOG_DEBUG]
			if ${FullMiners.CurrentValue.SystemID} == ${Me.SolarSystemID}
			{
				call This.WarpToFleetMemberAndLoot ${FullMiners.CurrentValue.FleetMemberID}
			}
			else
			{
				FullMiners:Erase[${FullMiners.FirstKey}]
			}
		}

		call This.WarpToNextSafeSpot
	}

	/* 1) Warp to fleet member and loot nearby cans           */
	/* 2) Repeat until cargo hold is full                    */
	/*                                                       */
	function HaulForFleet()
	{
		if ${FleetMembers.Used} == 0
		{
			This:BuildFleetMemberList
			call This.WarpToNextSafeSpot
		}
		else
		{
			if ${FleetMembers.Peek(exists)} && ${Local[${FleetMembers.Peek.ToPilot.Name}](exists)}
			{
				call This.WarpToFleetMemberAndLoot ${FleetMembers.Peek.CharID}
			}
			FleetMembers:Dequeue
		}
	}

	function HaulAllBelts()
	{
    	UI:UpdateConsole["Service All Belts mode not implemented!"]
		EVEBot.ReturnToStation:Set[TRUE]
	}
	
	function ServiceOrca()
	{
						variable string Orca
						Orca:Set[Name = "${Config.Hauler.HaulerPickupName}"]
						if !${Local[${Config.Hauler.HaulerPickupName}](exists)}
						{
							UI:UpdateConsole["ALERT:  The specified orca isn't in local - it may be incorrectly configured or out of system doing a dropoff."]
							return
						}
						
						if ${Me.ToEntity.Mode} == 3
						{
							return
						}				
						
						if !${Entity[${Orca.Escape}](exists)} && ${Local[${Config.Hauler.HaulerPickupName}].ToFleetMember}
						{
							UI:UpdateConsole["ALERT:  The orca is not nearby.  Warping there first to unload."]
							Local[${Config.Hauler.HaulerPickupName}].ToFleetMember:WarpTo
							return
						}

						;	Find out if we need to approach this target
						if ${Entity[${Orca.Escape}].Distance} > LOOT_RANGE && ${This.Approaching} == 0
						{
							UI:UpdateConsole["ALERT:  Approaching to within loot range."]
							Entity[${Orca.Escape}]:Approach
							This.Approaching:Set[${Entity[${Orca.Escape}]}]
							return
						}
						
						;	If we're approaching a target, find out if we need to stop doing so 
						if ${Entity[${This.Approaching}](exists)} && ${Entity[${This.Approaching}].Distance} <= LOOT_RANGE && ${This.Approaching} != 0
						{
							UI:UpdateConsole["ALERT:  Within loot range."]
							EVE:Execute[CmdStopShip]
							This.Approaching:Set[0]
							return
						}
						
						;	Open the Orca if it's not open yet
						if ${Entity[${Orca.Escape}](exists)} && ${Entity[${Orca.Escape}].Distance} <= LOOT_RANGE && !${EVEWindow[ByName, ${Entity[${Orca.Escape}]}](exists)}
						{
							UI:UpdateConsole["ALERT:  Open Hangar."]
							Entity[${Orca.Escape}]:OpenCorpHangars
							return
						}
						
						if ${Entity[${Orca.Escape}](exists)} && ${Entity[${Orca.Escape}].Distance} <= LOOT_RANGE && ${EVEWindow[ByName, ${Entity[${Orca.Escape}]}](exists)}
						{
							UI:UpdateConsole["ALERT:  Transferring Cargo"]
							call Cargo.TransferListFromShipCorporateHangar ${Entity[${Orca.Escape}]}
						}	
						return
			

	}
	
	
	
	
	function WarpToFleetMemberAndLoot(int64 charID)
	{
		variable int64 id = 0

		if ${Ship.CargoFreeSpace} < ${Ship.CargoMinimumFreeSpace}
		{	/* if we are already full ignore this request */
			return
		}

		if !${Entity["OwnerID = ${charID} && CategoryID = 6"](exists)}
		{
			call Ship.WarpToFleetMember ${charID}
		}

		if ${Entity["OwnerID = ${charID} && CategoryID = 6"].Distance} > CONFIG_MAX_SLOWBOAT_RANGE
		{
			if ${Entity["OwnerID = ${charID} && CategoryID = 6"].Distance} < WARP_RANGE
			{
				UI:UpdateConsole["Fleet member is too far for approach; warping to a bounce point"]
				call This.WarpToNextSafeSpot
			}
			call Ship.WarpToFleetMember ${charID}
		}

		call Ship.OpenCargo

		This:BuildJetCanList[${charID}]
		while ${Entities.Peek(exists)}
		{
			variable int64 PlayerID
			variable bool PopCan = FALSE

			; Find the player who owns this can
			if ${Entity["OwnerID = ${charID} && CategoryID = 6"](exists)}
			{
				PlayerID:Set[${Entity["OwnerID = ${charID} && CategoryID = 6"].ID}]
			}
			
			call Ship.Approach ${PlayerID} LOOT_RANGE

			if ${Entities.Peek.Distance} >= ${LOOT_RANGE} && \
				(!${Entity[${PlayerID}](exists)} || ${Entity[${PlayerID}].DistanceTo[${Entities.Peek.ID}]} > LOOT_RANGE)
			{
				UI:UpdateConsole["Checking: ID: ${Entities.Peek.ID}: ${Entity[${PlayerID}].Name} is ${Entity[${PlayerID}].DistanceTo[${Entities.Peek.ID}]}m away from jetcan"]
				PopCan:Set[TRUE]

				if !${Entities.Peek(exists)}
				{
					Entities:Dequeue
					continue
				}
				Entities.Peek:Approach

				; approach within tractor range and tractor entity
				variable float ApproachRange = ${Ship.OptimalTractorRange}
				if ${ApproachRange} > ${Ship.OptimalTargetingRange}
				{
					ApproachRange:Set[${Ship.OptimalTargetingRange}]
				}

				if ${Ship.OptimalTractorRange} > 0
				{
					variable int Counter
					if ${Entities.Peek.Distance} > ${Ship.OptimalTargetingRange}
					{
						call Ship.Approach ${Entities.Peek.ID} ${Ship.OptimalTargetingRange}
					}
					if !${Entities.Peek(exists)}
					{
						Entities:Dequeue
						continue
					}
					Entities.Peek:Approach
					Entities.Peek:LockTarget
					wait 10 ${Entities.Peek.BeingTargeted} || ${Entities.Peek.IsLockedTarget}
					if !${Entities.Peek.BeingTargeted} && !${Entities.Peek.IsLockedTarget}
					{
						if !${Entities.Peek(exists)}
						{
							Entities:Dequeue
							continue
						}
						UI:UpdateConsole["Hauler: Failed to target, retrying"]
						Entities.Peek:LockTarget
						wait 10 ${Entities.Peek.BeingTargeted} || ${Entities.Peek.IsLockedTarget}
					}
					if ${Entities.Peek.Distance} > ${Ship.OptimalTractorRange}
					{
						call Ship.Approach ${Entities.Peek.ID} ${Ship.OptimalTractorRange}
					}
					if !${Entities.Peek(exists)}
					{
						Entities:Dequeue
						continue
					}
					Counter:Set[0]
					while !${Entities.Peek.IsLockedTarget} && ${Counter:Inc} < 300
					{
						wait 1
					}
					Entities.Peek:MakeActiveTarget
					Counter:Set[0]
					while !${Me.ActiveTarget.ID.Equal[${Entities.Peek.ID}]} && ${Counter:Inc} < 300
					{
						wait 1
					}
					Ship:Activate_Tractor
				}
			}

			if !${Entities.Peek(exists)}
			{
				Entities:Dequeue
				continue
			}
			if ${Entities.Peek.Distance} >= ${LOOT_RANGE}
			{
				call Ship.Approach ${Entities.Peek.ID} LOOT_RANGE
			}
			Ship:Deactivate_Tractor
			EVE:Execute[CmdStopShip]

			if ${Entities.Peek.ID.Equal[0]}
			{
				UI:Updateconsole["Hauler: Jetcan disappeared suddently. WTF?"]
				Entities:Dequeue
				continue
			}
			
			call Ship.Approach ${Entities.Peek.ID} LOOT_RANGE
			
			if ${PopCan}
			{
				call This.LootEntity ${Entities.Peek.ID} 0
			}
			else
			{
				call This.LootEntity ${Entities.Peek.ID} 1
			}

			Entities:Dequeue
			if ${Ship.CargoFreeSpace} < ${Ship.CargoMinimumFreeSpace}
			{
				break
			}
		}

		FullMiners:Erase[${charID}]
	}

	method BuildFleetMemberList()
	{
		variable index:fleetmember myfleet
		FleetMembers:Clear
		Me.Fleet:GetMembers[myfleet]

		variable int idx
		idx:Set[${myfleet.Used}]

		while ${idx} > 0
		{
			if ${myfleet.Get[${idx}].CharID} != ${Me.CharID}
			{
				if ${myfleet.Get[${idx}].ToPilot(exists)}
				{
					FleetMembers:Queue[${myfleet.Get[${idx}]}]
				}
			}
			idx:Dec
		}

		UI:UpdateConsole["BuildFleetMemberList found ${FleetMembers.Used} other fleet members."]
	}


	method BuildSafeSpotList()
	{
		SafeSpots:Clear
		EVE:GetBookmarks[SafeSpots]

		variable int idx
		idx:Set[${SafeSpots.Used}]

		while ${idx} > 0
		{
			variable string Prefix
			Prefix:Set["${Config.Labels.SafeSpotPrefix}"]

			variable string Label
			Label:Set["${SafeSpots.Get[${idx}].Label.Escape}"]
			if ${Label.Left[${Prefix.Length}].NotEqual[${Prefix}]}
			{
				SafeSpots:Remove[${idx}]
			}
			elseif ${SafeSpots.Get[${idx}].SolarSystemID} != ${Me.SolarSystemID}
			{
				SafeSpots:Remove[${idx}]
			}

			idx:Dec
		}
		SafeSpots:Collapse
		SafeSpots:GetIterator[SafeSpotIterator]

		UI:UpdateConsole["BuildSafeSpotList found ${SafeSpots.Used} safespots in this system."]
	}

	function WarpToNextSafeSpot()
	{
		if ${SafeSpots.Used} == 0 || \
			${SafeSpots.Get[1].SolarSystemID} != ${Me.SolarSystemID}
		{
			This:BuildSafeSpotList
		}

		if !${SafeSpotIterator:Next(exists)}
		{
			SafeSpotIterator:First
		}

		if ${SafeSpotIterator.Value(exists)}
		{
			call Ship.WarpToBookMark ${SafeSpotIterator.Value.ID}

			/* open cargo hold so the CARGOFULL detection has a chance to work */
			call Ship.OpenCargo
		}
	}

	method BuildJetCanList(int64 id)
	{
		variable index:entity cans
		variable int idx

		EVE:QueryEntities[cans,"GroupID = 12"]
		idx:Set[${cans.Used}]
		Entities:Clear

		while ${idx} > 0
		{
			if ${id.Equal[${cans.Get[${idx}].Owner.CharID}]}
			{
				Entities:Queue[${cans.Get[${idx}]}]
			}
			idx:Dec
		}

		UI:UpdateConsole["BuildJetCanList found ${Entities.Used} cans nearby."]
	}
	
	method BuildCorpJetCanList()
	{
		variable index:entity cans
		variable int idx

		EVE:QueryEntities[cans,"GroupID = 12"]
		idx:Set[${cans.Used}]
		Entities:Clear

		while ${idx} > 0
		{

			if ${cans.Get[${idx}].IsOwnedByCorpMember}
			{
				Entities:Queue[${cans.Get[${idx}]}]
			}
			idx:Dec
		}

		UI:UpdateConsole["BuildCorpJetCanList found ${Entities.Used} cans nearby."]
	}
	
	member:int64 NearestMatchingJetCan(int64 id)
	{
		variable index:entity JetCans
		variable int JetCanCounter
		variable string tempString

		JetCanCounter:Set[0]
		EVE.QueryEntities[JetCans,"GroupID = 12"]
		while ${JetCanCounter:Inc} <= ${JetCans.Used}
		{
			if ${JetCans.Get[${JetCanCounter}](exists)}
			{
 				if ${JetCans.Get[${JetCanCounter}].Owner.CharID} == ${id}
 				{
					return ${JetCans.Get[${JetCanCounter}].ID}
 				}
			}
			else
			{
				echo "No jetcans found"
			}
		}

		return 0	/* no can found */
	}	

	;	This member is used to determine if our hauler is full based on a number of factors:
	;	*	Config.Miner.CargoThreshold
	;	*	Are our miners ice mining
	member:bool HaulerFull()
	{
		if ${Config.Miner.IceMining}
		{
			if ${Ship.CargoFreeSpace} < 1000 || ${Me.Ship.UsedCargoCapacity} > ${Config.Miner.CargoThreshold}
			{
				return TRUE
			}
		}
		else
		{
			if ${Ship.CargoFreeSpace} < ${Ship.CargoMinimumFreeSpace} || ${Me.Ship.UsedCargoCapacity} > ${Config.Miner.CargoThreshold}
			{
				return TRUE
			}
		}	
		return FALSE
	}
	
}

