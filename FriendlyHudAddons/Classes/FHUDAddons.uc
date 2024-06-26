class FHUDAddons extends FriendlyHUD
	config(FriendlyHUD);

var config string InteractionClassName, ReplicationInfoClassName;
var config int iVersionNum;

var repnotify string RepInteractionClassName;
var class<FriendlyHUDInteraction> InteractionClass;
var class<FriendlyHUDReplicationInfo> ReplicationInfoClass;
var int RetryCount;

replication
{
    if( bNetDirty )
        RepInteractionClassName;
}

simulated function ReplicatedEvent(name VarName)
{
	switch( VarName )
	{
		case 'RepInteractionClassName':
			InteractionClass = class<FriendlyHUDInteraction>(DynamicLoadObject(RepInteractionClassName, class'Class'));
			return;
		default:
			Super.ReplicatedEvent(VarName);
			return;
	}
}

simulated function PostBeginPlay()
{
	local int OldVersionNum;
	
    Super(Info).PostBeginPlay();

    if (bDeleteMe) return;

    `Log("[FriendlyHUD] Loaded mutator");

    if (Role == ROLE_Authority)
    {
		OldVersionNum = iVersionNum;
		
		if( iVersionNum <= 0 )
		{
			InteractionClassName = "FriendlyHudAddons.FriendlyHUDInteractionAddon";
			ReplicationInfoClassName = "FriendlyHudAddons.FriendlyHUDReplicationInfoAddon";
			iVersionNum++;
		}
		
		if( iVersionNum != OldVersionNum )
			SaveConfig();
			
		RepInteractionClassName = InteractionClassName;
			
		InteractionClass = class<FriendlyHUDInteraction>(DynamicLoadObject(InteractionClassName, class'Class'));
		ReplicationInfoClass = class<FriendlyHUDReplicationInfo>(DynamicLoadObject(ReplicationInfoClassName, class'Class'));
		
        UMLoaded = IsUMLoaded();

        RepInfo = Spawn(ReplicationInfoClass, Self);
        RepInfo.FHUD = Self;
        RepInfo.HUDConfig = HUDConfig;

        CDCompat = Spawn(class'FriendlyHUD.FriendlyHUDCDCompatController', Self);
        CDCompat.FHUD = Self;

        SetTimer(2.f, true, nameof(CheckBots));
    }

    if (WorldInfo.NetMode != NM_DedicatedServer)
    {
        InitializeHUD();
    }
}

simulated function InitializeDeferred()
{
	if( InteractionClass == None )
	{
		if( ++RetryCount >= 20 )
		{
			`Log("[FriendlyHUD] Interaction class could not be loaded; aborting.");
			return;
		}
		
		SetTimer(0.01f, false, nameof(InitializeDeferred));
        return;
	}
	
    HUD = KFGFxHudWrapper(KFPC.myHUD);
    if( HUD == None )
    {
        `Log("[FriendlyHUD] Incompatible HUD detected; aborting.");
        return;
    }

    FHUDInteraction = new(KFPC) InteractionClass;
    FHUDInteraction.FHUD = Self;
    FHUDInteraction.KFPlayerOwner = KFPC;
    FHUDInteraction.HUD = HUD;
    FHUDInteraction.HUDConfig = HUDConfig;
    KFPC.Interactions.InsertItem(0, FHUDInteraction);
    FHUDInteraction.Initialized();
    HUDConfig.FHUDInteraction = FHUDInteraction;

    InitializePartyChatHook();
    InitializeHUDChatHook();
    InitializeCompat();

    if( IsUMLoaded() )
        SetTimer(1.f, false, nameof(PrintNotification));
    else PrintNotification();

    KFPC.ConsoleCommand("exec cfg/OnLoadFHUD.cfg", false);
	
	OnFriendlyHUDInitialized(self);

    `Log("[FriendlyHUD] Initialized");
}

simulated function InitializeHUD()
{
    `Log("[FriendlyHUD] Initializing");

    KFPC = KFPlayerController(GetALocalPlayerController());

    if (KFPC == None || RepInfo == None)
    {
        SetTimer(0.5f, false, nameof(InitializeHUD));
        return;
    }

    `Log("[FriendlyHUD] Found KFPC");

    // Initialize the HUD configuration
    HUDConfig = new(KFPC) GetHUDConfigClass(self, KFPC);
    HUDConfig.FHUD = Self;
    HUDConfig.KFPlayerOwner = KFPC;
    KFPC.Interactions.AddItem(HUDConfig);
    HUDConfig.Initialized();

    // Give a chance for other mutators to initialize
    SetTimer(2.f, false, nameof(InitializeDeferred));
}

delegate class<FriendlyHUDConfig> GetHUDConfigClass(FHUDAddons FHUD, KFPlayerController PC)
{
    return class'FriendlyHUDConfig';
}

delegate OnFriendlyHUDInitialized(FriendlyHUD Mut);

simulated function WriteToChat(string Message, string HexColor)
{
    if (KFPC.MyGFxManager.PartyWidget != None)
    {
        KFPC.MyGFxManager.PartyWidget.ReceiveMessage(Message, HexColor);
    }

    if (HUD != None && HUD.HUDMovie != None && HUD.HUDMovie.HudChatBox != None)
    {
        HUD.HUDMovie.HudChatBox.AddChatMessage(Message, HexColor);
    }
}