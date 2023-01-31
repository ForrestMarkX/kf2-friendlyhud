class SentinelReplicationInfo extends KFPlayerReplicationInfo;

var KFPawn_AutoTurret TurretOwner;
var KFAIController DummyController;

replication
{
    if( bNetDirty && Role==ROLE_Authority )
        TurretOwner;
}

simulated function PostBeginPlay()
{
	local FriendlyHudAddons Mut;
	
    Super.PostBeginPlay();
	
    TurretOwner = KFPawn_AutoTurret(Owner);
	
	if( Role == ROLE_Authority )
	{
		DummyController = Spawn(class'KFAIController');
		DummyController.SetTickIsDisabled(true);
		DummyController.bIsPlayer = false;
		DummyController.Role = ROLE_Authority;
		DummyController.RemoteRole = ROLE_None;
		DummyController.Pawn = TurretOwner;
		DummyController.PlayerReplicationInfo = self;
		
		foreach WorldInfo.DynamicActors(class'FriendlyHudAddons', Mut)
			Mut.NotifyLogin(DummyController);
	}
}

simulated function Tick(float DT)
{
	Super.Tick(DT);
	if( TurretOwner == None )
		Destroy();
}

simulated function Destroyed()
{
	local FriendlyHudAddons Mut;
	
	Super.Destroyed();
	
	if( Role == ROLE_Authority && DummyController != None )
	{
		foreach WorldInfo.DynamicActors(class'FriendlyHudAddons', Mut)
			Mut.NotifyLogout(DummyController);
			
		if( DummyController != None )
			DummyController.Destroy();
	}
}

simulated function bool ShouldBroadCastWelcomeMessage(optional bool bExiting)
{
	return false;
}

simulated function string GetHumanReadableName()
{
    return "Sentinel";
}

simulated function Texture2D GetCurrentIconToDisplay()
{
	return Texture2D'ui_firemodes_tex.UI_FireModeSelect_Drone';
}

simulated function byte GetTeamNum()
{
	return 255;
}

defaultproperties
{
	bIsInactive=true
	bTickIsDisabled=true
	bOnlySpectator=true
    Avatar=None
}