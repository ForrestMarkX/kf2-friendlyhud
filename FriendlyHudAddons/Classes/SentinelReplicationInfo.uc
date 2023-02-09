class SentinelReplicationInfo extends KFPlayerReplicationInfo;

var KFPawn_AutoTurret TurretOwner;
var SentinelController DummyController;

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
		DummyController = Spawn(class'SentinelController');
        DummyController.PlayerReplicationInfo = self;
        DummyController.Pawn = TurretOwner;
        KFGameInfo(WorldInfo.Game).SetTeam(DummyController, KFGameInfo(WorldInfo.Game).Teams[0]);
        
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
            
        DummyController.PlayerReplicationInfo = None;
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

defaultproperties
{
	bIsInactive=true
    Avatar=None
}