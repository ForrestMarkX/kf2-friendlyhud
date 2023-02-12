class FriendlyHUDReplicationInfoAddon extends FriendlyHUDReplicationInfo;

function UpdateInfo()
{
    local KFPawn_Human KFPH;
    local KFPlayerReplicationInfo KFPRI;
    local float DmgBoostModifier, DmgResistanceModifier;
    local int I;
    local bool ShouldSimulateReplication;
	local KFPawn_AutoTurret Turret;
    local KFGameReplicationInfo KFGRI;
    
    KFGRI = KFGameReplicationInfo(WorldInfo.GRI);

    for (I = 0; I < REP_INFO_COUNT; I++)
    {
        if (PCArray[I] == None) continue;

        KFPH = KFPawn_Human(PCArray[I].Pawn);
        KFPRI = KFPlayerReplicationInfo(PCArray[I].PlayerReplicationInfo);
        KFPHArray[I] = KFPH;

		if( SentinelReplicationInfo(KFPRI) != None )
			Turret = SentinelReplicationInfo(KFPRI).TurretOwner;

        ShouldSimulateReplication = KFPRIArray[I] == None && WorldInfo.NetMode != NM_DedicatedServer;
        KFPRIArray[I] = KFPRI;
        
        // Replicated events don't work in singleplayer, so we need to simulate it here
        if (ShouldSimulateReplication)
        {
            ReplicatedEvent(nameof(KFPRIArray));
        }

        if (KFPRI != None)
        {
            if( Turret != None )
            {
                HasSpawnedArray[I] = 1;
                PlayerStateArray[I] = PRS_Default;
                CDPlayerReadyArray[I] = 0;
            }
            else 
            {
                // HasHadInitialSpawn() doesn't work on bots
                HasSpawnedArray[I] = (KFAIController(PCArray[I]) != None || KFPRI.HasHadInitialSpawn()) ? 1 : 0;

                // StateName was always None for me for some reason so lets just use the GRI values - FMX
                if (!KFGRI.bMatchHasBegun)
                {
                    PlayerStateArray[I] = KFPRI.bReadyToPlay ? PRS_Ready : PRS_NotReady;
                }
                else if (KFGRI.bTraderIsOpen && FHUDMutator.CDReadyEnabled)
                {
                    PlayerStateArray[I] = CDPlayerReadyArray[I] != 0 ? PRS_Ready : PRS_NotReady;
                }
                else
                {
                    PlayerStateArray[I] = PRS_Default;
                    CDPlayerReadyArray[I] = 0;
                }
            }
        }

        if (KFPH != None)
        {
            // Update health info
            HealthInfoArray[I].Value = KFPH.Health;
            HealthInfoArray[I].MaxValue = KFPH.HealthMax;

            // Update armor info
            ArmorInfoArray[I].Value = KFPH.Armor;
            ArmorInfoArray[I].MaxValue = KFPH.MaxArmor;

            // Update med buffs
            DmgBoostModifier = (KFPH.GetHealingDamageBoostModifier() - 1) * 100;
            DmgResistanceModifier = (1 - KFPH.GetHealingShieldModifier()) * 100;

            MedBuffArray[I].DamageBoost = Round(DmgBoostModifier / class'KFPerk_FieldMedic'.static.GetHealingDamageBoost());
            MedBuffArray[I].DamageResistance = Round(DmgResistanceModifier / class'KFPerk_FieldMedic'.static.GetHealingShield());
            UpdateSpeedBoost(I);

            if (KFPH.Health > 0)
            {
                RegenHealthArray[I] = KFPH.Health + KFPH.HealthToRegen;
            }
        }
		else if(Turret != None)
		{
            // Update health info
            HealthInfoArray[I].Value = Turret.TurretWeapon.AmmoCount[0];
            HealthInfoArray[I].MaxValue = Turret.TurretWeapon.MagazineCapacity[0];
		}
        else
        {
            HealthInfoArray[I] = EMPTY_BAR_INFO;
            ArmorInfoArray[I] = EMPTY_BAR_INFO;
            MedBuffArray[I] = EMPTY_BUFF_INFO;
            RegenHealthArray[I] = 0;
            SpeedBoostTimerArray[I] = TIMER_RESET_VALUE;
        }
    }
}

function NotifyLogin(Controller C)
{
    local int I;
    
    if (PlayerController(C) == None && (KFPawn_Human(C.Pawn) == None && SentinelController(C) == None)) return;

    // Find empty spot
    for (I = 0; I < REP_INFO_COUNT; I++)
    {
        if (PCArray[I] == None)
        {
            PCArray[I] = C;

            if (KFPlayerController(C) != None)
            {
                RepLinkArray[I] = Spawn(class'FriendlyHUD.FriendlyHUDReplicationLink', C);
                RepLinkArray[I].KFPC = KFPlayerController(C);
            }

            SpeedBoostTimerArray[I] = TIMER_RESET_VALUE;
            return;
        }
    }

    // No empty spot, pass to NextRepInfo
    if (NextRepInfo == None)
    {
        NextRepInfo = Spawn(FriendlyHudAddons(FHUDMutator).ReplicationInfoClass, Owner);
        NextRepInfo.FHUDMutator = FHUDMutator;
        NextRepInfo.HUDConfig = HUDConfig;
        NextRepInfo.PreviousRepInfo = Self;
    }

    NextRepInfo.NotifyLogin(C);
}

function NotifyLogout(Controller C)
{
    local int I;

    if (PlayerController(C) == None && (KFPawn_Human(C.Pawn) == None && SentinelController(C) == None)) return;
    
    for (I = 0; I < REP_INFO_COUNT; I++)
    {
        if (PCArray[I] == C)
        {
            PCArray[I] = None;
            RepLinkArray[I] = None;
            KFPHArray[I] = None;
            KFPRIArray[I] = None;
            HasSpawnedArray[I] = 0;
            HealthInfoArray[I] = EMPTY_BAR_INFO;
            ArmorInfoArray[I] = EMPTY_BAR_INFO;
            RegenHealthArray[I] = 0;
            MedBuffArray[I] = EMPTY_BUFF_INFO;
            SpeedBoostTimerArray[I] = TIMER_RESET_VALUE;
            PlayerStateArray[I] = PRS_Default;
            return;
        }
    }

    // Didn't find it, check with NextRepInfo if it exists
    if (NextRepInfo != None)
    {
        NextRepInfo.NotifyLogout(C);
    }
}