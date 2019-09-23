class FriendlyHUDMutator extends KFMutator;

var KFPlayerController KFPC;
var KFGFxHudWrapper HUD;
var FriendlyHUDInteraction FHUDInteraction;
var FriendlyHUDConfig HUDConfig;
var FriendlyHUDReplicationInfo RepInfo;
var bool UMLoaded, CDLoaded;
var bool ForceShowAsFriend;
var int PriorityCount;

var FriendlyHUDCDCompatController CDCompat;

var GFxClikWidget ChatInputField, PartyChatInputField;

const HelpURL = "https://steamcommunity.com/sharedfiles/filedetails/?id=1827646464";
const WhatsNewURL = "https://steamcommunity.com/sharedfiles/filedetails/?id=1827646464#3177485";
const GFxListenerPriority = 80000;

replication
{
    if (bNetDirty)
        RepInfo, UMLoaded, CDLoaded;
}

simulated function PostBeginPlay()
{
    super.PostBeginPlay();

    if (bDeleteMe) return;

    `Log("[FriendlyHUD] Loaded mutator");

    if (Role == ROLE_Authority)
    {
        UMLoaded = IsUMLoaded();

        RepInfo = Spawn(class'FriendlyHUD.FriendlyHUDReplicationInfo', Self);
        RepInfo.FHUDMutator = Self;
        RepInfo.HUDConfig = HUDConfig;

        CDCompat = new class'FriendlyHUD.FriendlyHUDCDCompatController';
        CDCompat.FHUDMutator = Self;

        SetTimer(2.f, true, nameof(CheckBots));
    }

    if (WorldInfo.NetMode != NM_DedicatedServer)
    {
        InitializeHUD();
    }
}

simulated event Destroyed()
{
    if (WorldInfo.NetMode != NM_DedicatedServer)
    {
        KFPC.ConsoleCommand("exec cfg/OnUnloadFHUD.cfg", false);
    }

    super.Destroyed();
}

function CheckBots()
{
    local KFPawn_Human KFPH;

    foreach WorldInfo.AllPawns(class'KFGame.KFPawn_Human', KFPH)
    {
        if (KFAIController(KFPH.Controller) != None && !RepInfo.IsPlayerRegistered(KFPH.Controller))
        {
            RepInfo.NotifyLogin(KFPH.Controller);
        }
    }
}

function NotifyLogin(Controller NewPlayer)
{
    RepInfo.NotifyLogin(NewPlayer);

    super.NotifyLogin(NewPlayer);
}

function NotifyLogout(Controller Exiting)
{
    RepInfo.NotifyLogout(Exiting);

    super.NotifyLogout(Exiting);
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
    HUDConfig = new (KFPC) class'FriendlyHUD.FriendlyHUDConfig';
    HUDConfig.FHUDMutator = Self;
    HUDConfig.KFPlayerOwner = KFPC;
    KFPC.Interactions.AddItem(HUDConfig);
    HUDConfig.Initialized();

    // Give a chance for other mutators to initialize
    SetTimer(2.f, false, nameof(InitializeDeferred));
}

simulated function InitializeDeferred()
{
    HUD = KFGFxHudWrapper(KFPC.myHUD);
    if (HUD == None)
    {
        `Log("[FriendlyHUD] Incompatible HUD detected; aborting.");
        return;
    }

    // Initialize the HUD interaction
    FHUDInteraction = new (KFPC) class'FriendlyHUD.FriendlyHUDInteraction';
    FHUDInteraction.FHUDMutator = Self;
    FHUDInteraction.KFPlayerOwner = KFPC;
    FHUDInteraction.HUD = HUD;
    FHUDInteraction.HUDConfig = HUDConfig;
    KFPC.Interactions.InsertItem(0, FHUDInteraction);
    FHUDInteraction.Initialized();
    HUDConfig.FHUDInteraction = FHUDInteraction;

    InitializeChatHook();
    InitializeCompat();

    if (IsUMLoaded())
    {
        // Defer the printing because we want our message to show up last
        SetTimer(1.f, false, nameof(PrintNotification));
    }
    else
    {
        PrintNotification();
    }

    KFPC.ConsoleCommand("exec cfg/OnLoadFHUD.cfg", false);

    `Log("[FriendlyHUD] Initialized");
}

simulated function bool IsUMLoaded()
{
    local Mutator Mut;

    if (Role != ROLE_Authority)
    {
        return UMLoaded;
    }

    for (Mut = WorldInfo.Game.BaseMutator; Mut != None; Mut = Mut.NextMutator)
    {
        if (PathName(Mut.class) ~= "UnofficialMod.UnofficialModMut") return true;
    }

    return false;
}


simulated function InitializeCompat()
{
    local UMCompatInteraction UMInteraction;

    if (!IsUMLoaded()) return;

    `Log("[FriendlyHUD] UnofficialMod detected");

    HUDConfig.InitUMCompat();

    UMInteraction = new (KFPC) class'FriendlyHUD.UMCompatInteraction';
    UMInteraction.KFPlayerOwner = KFPC;
    UMInteraction.HUD = HUD;
    UMInteraction.HUDConfig = HUDConfig;
    KFPC.Interactions.AddItem(UMInteraction);
    UMInteraction.Initialized();
}

simulated delegate OnChatInputKeyDown(GFxClikWidget.EventData Data)
{
    OnChatKeyDown(ChatInputField, Data);
}

simulated delegate OnPartyChatInputKeyDown(GFxClikWidget.EventData Data)
{
    OnChatKeyDown(PartyChatInputField, Data);
}

simulated function OnChatKeyDown(GFxClikWidget InputField, GFxClikWidget.EventData Data)
{
    local int KeyCode;
    local string Text;
    local OnlineSubsystem OS;

    OS = class'GameEngine'.static.GetOnlineSubsystem();

    //local array<GFxMoviePlayer.ASValue> Params;
    //`Log("[FriendlyHUD] OnKeyDown:" @ Data._this.Invoke("toString", Params).s);

    KeyCode = Data._this.GetInt("keyCode");

    `if(`isdefined(debug))
    `Log("[FriendlyHUD] OnKeyDown:" @ KeyCode);
    `endif

    // Enter
    if (KeyCode == 13)
    {
        Text = InputField.GetText();
        switch (Locs(Text))
        {
            case "!fhudhelp":
                if (OS == None) return;
                OS.OpenURL(HelpURL);
                break;
            case "!fhudnews":
            case "!fhudwhatsnew":
            case "!fhudchangelog":
                if (OS == None) return;

                // Update the changelog version so that we stop nagging the user
                HUDConfig.UpdateChangeLogVersion();

                OS.OpenURL(WhatsNewURL);
                break;
            case "!fhudversion":
                WriteToChat("[FriendlyHUD]" @ HUDConfig.GetVersionInfo(), "B986E9");
                break;
            default:
                return;
        }

        // Clear the field before letting the default event handler process it
        // This prevents the command from showing up in chat
        InputField.SetText("");
    }
}

simulated function InitializeChatHook()
{
    // Retry until the HUD is fully initialized
    if (KFPC.MyGFxHUD == None
        || KFPC.MyGFxManager == None
        || KFPC.MyGFxManager.PartyWidget == None
        || KFPC.MYGFxManager.PartyWidget.PartyChatWidget == None
        || HUD.HUDMovie == None
        || HUD.HUDMovie.KFGXHUDManager == None
        || HUD.HUDMovie.KFGXHUDManager.GetObject("ChatBoxWidget") == None
    )
    {
        `Log("[FriendlyHUD] Failed initializing chat hook; retrying.");
        SetTimer(1.f, false, nameof(InitializeChatHook));
        return;
    }

    // Force the chat to show up in solo
    KFPC.MyGFxManager.PartyWidget.PartyChatWidget.SetVisible(true);

    ChatInputField = GFxClikWidget(HUD.HUDMovie.KFGXHUDManager.GetObject("ChatBoxWidget").GetObject("ChatInputField", class'GFxClikWidget'));
    PartyChatInputField = GFxClikWidget(KFPC.MyGFxManager.PartyWidget.PartyChatWidget.GetObject("ChatInputField", class'GFxClikWidget'));
    ChatInputField.AddEventListener('CLIK_keyDown', OnChatInputKeyDown, false, GFxListenerPriority, false);
    PartyChatInputField.AddEventListener('CLIK_keyDown', OnPartyChatInputKeyDown, false, GFxListenerPriority, false);

    `Log("[FriendlyHUD] Initialized chat hook");
}

simulated function WriteToChat(string Message, string HexColor)
{
    if (KFPC.MyGFxManager.PartyWidget != None && KFPC.MyGFxManager.PartyWidget.PartyChatWidget != None)
    {
        KFPC.MyGFxManager.PartyWidget.PartyChatWidget.AddChatMessage(Message, HexColor);
    }

    if (HUD != None && HUD.HUDMovie != None && HUD.HUDMovie.HudChatBox != None)
    {
        HUD.HUDMovie.HudChatBox.AddChatMessage(Message, HexColor);
    }
}

simulated function PrintNotification()
{
    WriteToChat("[FriendlyHUD] type !FHUDHelp to open the command list.", "B986E9");
    if (HUDConfig.LastChangeLogVersion < HUDConfig.CurrentVersion)
    {
        WriteToChat("[FriendlyHUD] was updated, type !FHUDNews to see the changelog.", "FFFF00");
    }
}

simulated function ForceUpdateNameCache()
{
    local FriendlyHUDReplicationInfo CurrentRepInfo;
    local int I;

    CurrentRepInfo = RepInfo;
    while (CurrentRepInfo != None)
    {
        for (I = 0; I < class'FriendlyHUD.FriendlyHUDReplicationInfo'.const.REP_INFO_COUNT; I++)
        {
            if (CurrentRepInfo.KFPRIArray[I] == None) continue;
            CurrentRepInfo.ShouldUpdateNameArray[I] = 1;
        }
        CurrentRepInfo = CurrentRepInfo.NextRepInfo;
    }
}

defaultproperties
{
    Role = ROLE_Authority;
    RemoteRole = ROLE_SimulatedProxy;
    bAlwaysRelevant = true;
    PriorityCount = 1;
}