class SentinelController extends PlayerController;

simulated function PreBeginPlay()
{
	Super(Actor).PreBeginPlay();
}
simulated function PostBeginPlay()
{
	Super(Actor).PostBeginPlay();
}
function InitPlayerReplicationInfo();

defaultproperties
{
    bIsPlayer=false
}