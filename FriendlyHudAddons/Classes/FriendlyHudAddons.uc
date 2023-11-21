class FriendlyHudAddons extends FriendlyHUDMutator;

event PreBeginPlay()
{
    Super(KFMutator).PreBeginPlay();

    if (WorldInfo.NetMode == NM_Client) return;

    foreach WorldInfo.DynamicActors(class'FriendlyHUD', FriendlyHUD)
    {
        break;
    }

    if (FriendlyHUD == None)
    {
        FriendlyHUD = WorldInfo.Spawn(class'FHUDAddons');
    }

    if (FriendlyHUD == None)
    {
        `Log("[FriendlyHUD] Can't Spawn 'FriendlyHUD'");
        SafeDestroy();
    }
}

function bool CheckReplacement(Actor Other) 
{
	local KFPawn_AutoTurret Turret;
	
	Turret = KFPawn_AutoTurret(Other);
    if( Turret != None )
	{
        Turret.PlayerReplicationInfo = Spawn(class'SentinelReplicationInfo', Turret,, vect(0,0,0), rot(0,0,0));
        if( Turret.PlayerReplicationInfo.PlayerName == "" )
            Turret.PlayerReplicationInfo.PlayerName = class'GameInfo'.default.DefaultPlayerName;
	}
		
    return Super.CheckReplacement(Other);
}