class FriendlyHUDInteractionAddon extends FriendlyHUDInteraction;

function UpdateRuntimeVars(optional Canvas Canvas)
{
    local float LineHeightOffset;
    local float Temp;

    // If no canvas is passed, we schedule the update for the next render
    if (Canvas == None)
    {
        RuntimeInitialized = false;
        return;
    }

    RuntimeInitialized = true;

    CachedScreenWidth = Canvas.SizeX;
    CachedScreenHeight = Canvas.SizeY;

    Canvas.Font = GetCanvasFont(self, HUD);
    R.ResScale = class'FriendlyHUD.FriendlyHUDHelper'.static.GetResolutionScale(Canvas);
    R.Scale = R.ResScale * HUDConfig.Scale;

    R.NameScale = GetCanvasFontScale(self, HUD) * HUDConfig.NameScale * R.Scale;
    Canvas.TextSize(ASCIICharacters, Temp, R.TextHeight, R.NameScale, R.NameScale);

    R.BuffOffset = HUDConfig.BuffOffset * R.Scale;
    R.BuffIconSize = HUDConfig.BuffSize * R.Scale;
    R.BuffPlayerIconMargin = HUDConfig.BuffMargin * R.Scale;
    R.BuffPlayerIconGap = HUDConfig.BuffGap * R.Scale;

    R.FriendIconSize = HUDConfig.FriendIconSize * R.Scale;
    R.FriendIconGap = HUDConfig.FriendIconGap * R.Scale;
    R.FriendIconOffsetY = HUDConfig.FriendIconOffsetY * R.Scale;

    R.LineHeight = HUDConfig.FriendIconEnabled ? FMax(R.FriendIconSize, R.TextHeight) : R.TextHeight;

    R.ArmorBlockGap = HUDConfig.ArmorBlockGap * R.Scale;
    R.HealthBlockGap = HUDConfig.HealthBlockGap * R.Scale;
    R.BarGap = HUDConfig.BarGap * R.Scale;

    // TODO: apply outline restrictions for different block textures
    R.ArmorBlockOutline = HUDConfig.ArmorBlockOutline;
    R.HealthBlockOutline = HUDConfig.HealthBlockOutline;

    UpdateBlockSizeOverrides(
        R.ArmorBlockSizeOverrides,
        R.ArmorBarWidth,
        R.ArmorBarHeight,
        HUDConfig.ArmorBlockSizeOverrides,
        HUDConfig.ArmorBlockCount,
        HUDConfig.ArmorBlockWidth,
        HUDConfig.ArmorBlockHeight,
        HUDConfig.ArmorBlockGap,
        R.ArmorBlockOutline
    );

    UpdateBlockSizeOverrides(
        R.HealthBlockSizeOverrides,
        R.HealthBarWidth,
        R.HealthBarHeight,
        HUDConfig.HealthBlockSizeOverrides,
        HUDConfig.HealthBlockCount,
        HUDConfig.HealthBlockWidth,
        HUDConfig.HealthBlockHeight,
        HUDConfig.HealthBlockGap,
        R.HealthBlockOutline
    );

    UpdateBlockRatioOverrides(
        R.ArmorBlockRatioOverrides,
        HUDConfig.ArmorBlockRatioOverrides,
        HUDConfig.ArmorBlockCount
    );

    UpdateBlockRatioOverrides(
        R.HealthBlockRatioOverrides,
        HUDConfig.HealthBlockRatioOverrides,
        HUDConfig.HealthBlockCount
    );

    UpdateBlockOffsetOverrides(
        R.ArmorBlockOffsetOverrides,
        HUDConfig.ArmorBlockOffsetOverrides,
        HUDConfig.ArmorBlockCount
    );

    UpdateBlockOffsetOverrides(
        R.HealthBlockOffsetOverrides,
        HUDConfig.HealthBlockOffsetOverrides,
        HUDConfig.HealthBlockCount
    );

    R.NameMarginX = HUDConfig.NameMarginX * R.Scale;
    R.NameMarginY = HUDConfig.NameMarginY * R.Scale;
    R.ItemMarginX = HUDConfig.ItemMarginX * R.Scale;
    R.ItemMarginY = HUDConfig.ItemMarginY * R.Scale;

    R.BarWidthMin = FMax(
        FMax(R.ArmorBarWidth, R.HealthBarWidth),
        HUDConfig.BarWidthMin * R.Scale
    );

    LineHeightOffset = (R.LineHeight + R.NameMarginY) / 2.f;

    R.PlayerIconSize = HUDConfig.IconSize * R.Scale;
    R.PlayerIconGap = HUDConfig.IconGap * R.Scale;
    R.PlayerIconOffset = HUDConfig.IconOffset * R.Scale + LineHeightOffset;

    R.TotalItemWidth = R.PlayerIconSize + R.PlayerIconGap + R.BarWidthMin + R.ItemMarginX;
    R.TotalItemHeight = FMax(
        // Bar (right side)
        R.ArmorBarHeight + R.HealthBarHeight
            // Bar gap
            + R.BarGap
            // Player name
            + R.LineHeight + R.NameMarginY,
        // Icon (left side)
        R.PlayerIconSize + R.PlayerIconOffset
    ) + R.ItemMarginY;

    // BuffLayout: Left or Right
    if (HUDConfig.BuffLayout == 1 || HUDConfig.BuffLayout == 2)
    {
        R.TotalItemWidth += FMax(R.BuffPlayerIconMargin + R.BuffIconSize, 0.f);
    }
    else if (HUDConfig.BuffLayout == 3 || HUDConfig.BuffLayout == 4)
    {
        R.TotalItemHeight += FMax(R.BuffPlayerIconMargin + R.BuffIconSize, 0.f);
    }
}

function bool DrawHealthBarItem(Canvas Canvas, const out PlayerItemInfo ItemInfo, float PosX, float PosY)
{
    local float SelectionPosX, SelectionPosY, SelectionWidth, SelectionHeight;
    local float PlayerNamePosX, PlayerNamePosY;
    local float FriendIconPosX, FriendIconPosY;
    local float PlayerIconPosX, PlayerIconPosY;
    local float AvatarIconPosX, AvatarIconPosY;
    local float ChatIconPosX, ChatIconPosY;
    local FontRenderInfo TextFontRenderInfo;
    local float ArmorRatio, HealthRatio, RegenRatio, TotalRegenRatio;
    local KFPlayerReplicationInfo KFPRI;
	local SentinelReplicationInfo SRI;
    local string PlayerName;
    local FriendlyHUDReplicationInfo.BarInfo ArmorInfo, HealthInfo;
    local FriendlyHUDReplicationInfo.MedBuffInfo BuffInfo;
    local FriendlyHUDReplicationInfo.EPlayerReadyState PlayerState;
    local float PreviousBarWidth, PreviousBarHeight;
    local int HealthToRegen;
    local bool ForceShowBuffs;
    local int BuffLevel;
    local byte IsFriend;

    TextFontRenderInfo = Canvas.CreateFontRenderInfo(true);

    ItemInfo.RepInfo.GetPlayerInfo(ItemInfo.RepIndex, KFPRI, PlayerName, ArmorInfo, HealthInfo, HealthToRegen, BuffInfo, IsFriend, PlayerState);

	SRI = SentinelReplicationInfo(KFPRI);

    TotalRegenRatio = HealthInfo.MaxValue > 0 ? FMin(FMax(float(HealthToRegen) / float(HealthInfo.MaxValue), 0.f), 1.f) : 0.f;
    HealthToRegen = HealthToRegen > 0 ? Max(HealthToRegen - HealthInfo.Value, 0) : 0;

    ArmorRatio = ArmorInfo.MaxValue > 0 ? FMin(FMax(float(ArmorInfo.Value) / float(ArmorInfo.MaxValue), 0.f), 1.f) : 0.f;
    HealthRatio = HealthInfo.MaxValue > 0 ? FMin(FMax(float(HealthInfo.Value) / float(HealthInfo.MaxValue), 0.f), 1.f) : 0.f;
    RegenRatio = HealthInfo.MaxValue > 0 ? FMin(FMax(float(HealthToRegen) / float(HealthInfo.MaxValue), 0.f), 1.f) : 0.f;

    BuffLevel = Min(Max(BuffInfo.DamageBoost, Max(BuffInfo.DamageResistance, BuffInfo.SpeedBoost)), HUDConfig.BuffCountMax);

    ForceShowBuffs = HUDConfig.ForceShowBuffs && BuffLevel > 0;

    // If we're in select mode, bypass all visibility checks
    if (ManualModeActive || SRI != None) { }
    // Only apply render restrictions if we don't have a special state
    else if (PlayerState == PRS_Default || !FHUDMutator.CDReadyEnabled)
    {
        // Don't render if CD trader-time only mode is enabled
        if (HUDConfig.CDOnlyTraderTime) return false;

        // If enabled, don't render dead teammates
        if (HUDConfig.IgnoreDeadTeammates && HealthRatio <= 0.f) return false;

        // If enabled, don't render teammates above a certain health threshold
        if (HealthRatio > HUDConfig.MinHealthThreshold && !ForceShowBuffs) return false;
    }

    R.Opacity = FMin(
            FCubicInterp(
                HUDConfig.DynamicOpacity.P0,
                HUDConfig.DynamicOpacity.T0,
                HUDConfig.DynamicOpacity.P1,
                HUDConfig.DynamicOpacity.T1,
                HealthRatio
            ), 1.f
        ) * HUDConfig.Opacity;

    SelectionPosX = PosX;
    SelectionPosY = PosY;
    SelectionWidth = R.TotalItemWidth - R.ItemMarginX;
    SelectionHeight = R.TotalItemHeight - R.ItemMarginY;

    PlayerIconPosX = PosX;
    PlayerIconPosY = PosY + R.PlayerIconOffset;

    PlayerNamePosX = PosX + R.PlayerIconSize + R.PlayerIconGap + R.NameMarginX;
    PlayerNamePosY = PosY + FMax(R.LineHeight - R.TextHeight, 0);

    FriendIconPosX = PlayerNamePosX;
    FriendIconPosY = PosY + R.LineHeight - R.FriendIconSize + R.FriendIconOffsetY;

    // Draw drop shadow behind the player icon
    SetCanvasColor(Canvas, HUDConfig.ShadowColor);
    DrawPlayerIcon(Canvas, ItemInfo, PlayerIconPosX + 1, PlayerIconPosY);

    // Draw player icon
    SetCanvasColor(Canvas, HUDConfig.IconColor);
    DrawPlayerIcon(Canvas, ItemInfo, PlayerIconPosX, PlayerIconPosY);

    // Draw buffs
    DrawBuffs(Canvas, BuffLevel, PlayerIconPosX, PlayerIconPosY);

    // BuffLayout: Left
    if (HUDConfig.BuffLayout == 1)
    {
        SelectionPosX -= FMax(R.BuffPlayerIconMargin + R.BuffIconSize, 0.f);
    }
    // BuffLayout: Right
    else if (HUDConfig.BuffLayout == 2)
    {
        // This ensures that we don't render the buffs over the player name
        PlayerNamePosX += FMax(R.BuffPlayerIconMargin + R.BuffIconSize, 0.f);

        // This ensures that we don't render the buffs over the bars
        PosX += FMax(R.BuffPlayerIconMargin + R.BuffIconSize, 0.f);
    }
    // BuffLayout: Top
    else if (HUDConfig.BuffLayout == 3)
    {
        SelectionPosY -= FMax(R.BuffPlayerIconMargin + R.BuffIconSize, 0.f);
    }

    if (IsFriend != 0 && HUDConfig.FriendIconEnabled)
    {
        // Draw drop shadow behind the friend icon
        SetCanvasColor(Canvas, HUDConfig.ShadowColor);
        Canvas.SetPos(FriendIconPosX, FriendIconPosY + 1);
        Canvas.DrawTile(default.FriendIconTexture, R.FriendIconSize, R.FriendIconSize, 0, 0, 256, 256);

        // Draw friend icon
        SetCanvasColor(Canvas, HUDConfig.FriendIconColor);
        Canvas.SetPos(FriendIconPosX, FriendIconPosY);
        Canvas.DrawTile(default.FriendIconTexture, R.FriendIconSize, R.FriendIconSize, 0, 0, 256, 256);

        PlayerNamePosX += R.FriendIconSize + R.FriendIconGap;
    }
	
	if( GetPlayerIsChatting(self, KFPRI, HUD) )
	{
		ChatIconPosX = PlayerNamePosX;
		ChatIconPosY = PosY + FMax(R.LineHeight - R.TextHeight, 0);
		
		DrawPlayerChatIcon(self, KFPRI, HUD, Canvas, ChatIconPosX, ChatIconPosY, PlayerNamePosX);
	}
	
	if( KFPRI.Avatar != None )
	{
		AvatarIconPosX = PlayerNamePosX;
		AvatarIconPosY = PosY + FMax(R.LineHeight - R.TextHeight, 0);
	
		SetCanvasColor(Canvas, HUDConfig.ShadowColor);
        Canvas.SetPos(AvatarIconPosX, AvatarIconPosY + 1);
        Canvas.DrawTile(KFPRI.Avatar, R.TextHeight, R.TextHeight, 0, 0, KFPRI.Avatar.SizeX, KFPRI.Avatar.SizeY);
		
		SetCanvasColor(Canvas, HUD.WhiteColor);
        Canvas.SetPos(AvatarIconPosX, AvatarIconPosY);
        Canvas.DrawTile(KFPRI.Avatar, R.TextHeight, R.TextHeight, 0, 0, KFPRI.Avatar.SizeX, KFPRI.Avatar.SizeY);
		
		PlayerNamePosX += R.TextHeight + R.FriendIconGap;
	}
	else
	{
		// Try to obtain avatar.
		if( !KFPRI.bBot )
			KFPRI.Avatar = FindAvatar(KFPRI.UniqueId);
	}

	if( !OverridePlayerNameDraw(self, KFPRI, HUD, Canvas, PlayerNamePosX, PlayerNamePosY, PlayerName, TextFontRenderInfo, ItemInfo, IsFriend) )
	{
		// Draw drop shadow behind the player name
		SetCanvasColor(Canvas, HUDConfig.ShadowColor);
		Canvas.SetPos(PlayerNamePosX, PlayerNamePosY + 1);
		Canvas.DrawText(PlayerName, , R.NameScale, R.NameScale, TextFontRenderInfo);

		// Draw player name
		SetCanvasColor(
			Canvas,
			((IsFriend != 0 || FHUDMutator.ForceShowAsFriend) && HUDConfig.FriendNameColorEnabled)
				? HUDConfig.FriendNameColor
				: HUDConfig.NameColor
		);
		Canvas.SetPos(PlayerNamePosX, PlayerNamePosY);
		Canvas.DrawText(PlayerName, , R.NameScale, R.NameScale, TextFontRenderInfo);
	}

	if( SentinelReplicationInfo(KFPRI) != None )
	{
        // Draw ammo bar
        DrawBarEx(
            Canvas,
            BT_Health,
            HealthRatio,
            0.f,
            0.f,
            PosX + R.PlayerIconSize + R.PlayerIconGap,
            PosY + R.LineHeight + R.NameMarginY,
            PreviousBarWidth,
            PreviousBarHeight,
			true
        );
	}
	else
	{
		// Draw armor bar
		DrawBar(
			Canvas,
			BT_Armor,
			ArmorRatio,
			0.f,
			0.f,
			PosX + R.PlayerIconSize + R.PlayerIconGap,
			PosY + R.LineHeight + R.NameMarginY,
			PreviousBarWidth,
			PreviousBarHeight
		);

		// Draw health bar
		DrawBar(
			Canvas,
			BT_Health,
			HealthRatio,
			RegenRatio,
			TotalRegenRatio,
			PosX + R.PlayerIconSize + R.PlayerIconGap,
			PosY + PreviousBarHeight + R.BarGap + R.LineHeight + R.NameMarginY,
			PreviousBarWidth,
			PreviousBarHeight
		);
	}

    if (ManualModeActive)
    {
        if (KFPRI == KFPlayerOwner.PlayerReplicationInfo
            ? HUDConfig.IgnoreSelf
            : ItemInfo.RepInfo.ManualVisibilityArray[ItemInfo.RepIndex] == 0
        )
        {
            Canvas.DrawColor = MakeColor(255, 0, 0, 40);
            Canvas.SetPos(SelectionPosX, SelectionPosY);
            Canvas.DrawTile(default.BarBGTexture, SelectionWidth, SelectionHeight, 0, 0, 32, 32);
        }

        if (ManualModeCurrentPRI.KFPRI == ItemInfo.KFPRI)
        {
            class'FriendlyHUD.FriendlyHUDHelper'.static.DrawSelection(
                Canvas,
                SelectionPosX,
                SelectionPosY,
                SelectionWidth,
                SelectionHeight,
                (KFPRI == KFPlayerOwner.PlayerReplicationInfo && HUDConfig.SelfSortStrategy != 0)
                    // Use a different color when self is selected and we can't move it
                    ? default.SelfCornerColor
                    : (MoveModeActive ? default.MoveCornerColor : default.SelectCornerColor),
                default.SelectLineColor
            );
        }
    }

    return true;
}

function DrawBarEx(
    Canvas Canvas,
    EBarType BarType,
    float BarRatio,
    float BufferRatio,
    float TotalBufferRatio,
    float PosX,
    float PosY,
    out float TotalWidth,
    out float TotalHeight,
	optional bool bDrawingAmmo
)
{
    local int BlockCount, BlockGap, BlockRoundingStrategy, BarHeight, BlockVerticalAlignment;
    local array<FriendlyHUDConfig.BlockSizeOverride> BlockSizeOverrides;
    local array<FriendlyHUDConfig.BlockRatioOverride> BlockRatioOverrides;
    local array<FriendlyHUDConfig.BlockOffsetOverride> BlockOffsetOverrides;
    local FriendlyHUDConfig.BlockOutline BlockOutline;
    local float BlockOutlineH, BlockOutlineV;
    local float BlockOffsetX, BlockOffsetY;
    local Color BarColor, BufferColor, BGColor, EmptyBGColor, AmmoFull, AmmoEmpty;
    local float CurrentBlockPosX, CurrentBlockPosY, CurrentBlockWidth, CurrentBlockHeight;
    local float BarBlockWidth, BufferBlockWidth;
    local float P1, P2;
    local float BlockRatio;
    local string DebugRatioText;
    local float DebugRatioWidth, DebugRatioHeight;
    local FontRenderInfo DebugTextFontRenderInfo;
    local int I;

    TotalWidth = 0.f;
    TotalHeight = 0.f;

    CurrentBlockPosX = PosX;
    CurrentBlockPosY = PosY;

    if (BarType == BT_Armor)
    {
        BlockCount = HUDConfig.ArmorBlockCount;
        BlockGap = R.ArmorBlockGap;
        BlockRoundingStrategy = HUDConfig.ArmorBlockRoundingStrategy;
        BarHeight = R.ArmorBarHeight;
        BlockVerticalAlignment = HUDConfig.ArmorBlockVerticalAlignment;
        BlockSizeOverrides = R.ArmorBlockSizeOverrides;
        BlockRatioOverrides = R.ArmorBlockRatioOverrides;
        BlockOffsetOverrides = R.ArmorBlockOffsetOverrides;
        BlockOutline = R.ArmorBlockOutline;

        BarColor = HUDConfig.ArmorColor;
        BGColor = HUDConfig.ArmorBGColor;
        EmptyBGColor = HUDConfig.ArmorEmptyBGColor;
    }
    else
    {
        BlockCount = HUDConfig.HealthBlockCount;
        BlockGap = R.HealthBlockGap;
        BlockRoundingStrategy = HUDConfig.HealthBlockRoundingStrategy;
        BarHeight = R.HealthBarHeight;
        BlockVerticalAlignment = HUDConfig.HealthBlockVerticalAlignment;
        BlockSizeOverrides = R.HealthBlockSizeOverrides;
        BlockRatioOverrides = R.HealthBlockRatioOverrides;
        BlockOffsetOverrides = R.HealthBlockOffsetOverrides;
        BlockOutline = R.HealthBlockOutline;

        if( bDrawingAmmo )
        {
            AmmoFull = MakeColor(20, 175, 20, 255);
            AmmoEmpty = MakeColor(175, 0, 0, 255);
        
            BarColor.R = Approach(AmmoEmpty.R, AmmoFull.R, Abs(AmmoEmpty.R - AmmoFull.R) * BarRatio);
            BarColor.G = Approach(AmmoEmpty.G, AmmoFull.G, Abs(AmmoEmpty.G - AmmoFull.G) * BarRatio);
            BarColor.B = Approach(AmmoEmpty.B, AmmoFull.B, Abs(AmmoEmpty.B - AmmoFull.B) * BarRatio);
            BarColor.A = HUDConfig.HealthColor.A;
        
            BGColor = HUDConfig.HealthBGColor;
            EmptyBGColor = HUDConfig.HealthEmptyBGColor;
        }
        else
		{
			BarColor = HUDConfig.HealthColor;
			BufferColor = HUDConfig.HealthRegenColor;

			BGColor = HUDConfig.HealthBGColor;
			EmptyBGColor = HUDConfig.HealthEmptyBGColor;

			if (HUDConfig.DynamicColorsStrategy > 0)
			{
				BarColor = GetHealthColor(BarRatio, HUDConfig.HealthColor, HUDConfig.ColorThresholds, HUDConfig.DynamicColorsStrategy > 1);
			}

			// Lerp the health regen
			if (HUDConfig.DynamicRegenColorsStrategy > 0)
			{
				BufferColor = HUDConfig.DynamicRegenColorsStrategy != 2
					// Lerp using the total regen ratio
					? GetHealthColor(TotalBufferRatio, HUDConfig.HealthRegenColor, HUDConfig.RegenColorThresholds, HUDConfig.DynamicRegenColorsStrategy > 1)
					// Lerp using the current health ratio
					: GetHealthColor(BarRatio, HUDConfig.HealthRegenColor, HUDConfig.RegenColorThresholds, HUDConfig.DynamicRegenColorsStrategy > 1);
			}
		}
    }

    // These don't modify the original values because of struct copy semantics
    BlockOutline.Left *= R.Scale;
    BlockOutline.Right *= R.Scale;
    BlockOutline.Top *= R.Scale;
    BlockOutline.Bottom *= R.Scale;
    BlockOutlineH = BlockOutline.Left + BlockOutline.Right;
    BlockOutlineV = BlockOutline.Top + BlockOutline.Bottom;

    for (I = 0; I < BlockCount; I++)
    {
        CurrentBlockWidth = BlockSizeOverrides[I].Width;
        CurrentBlockHeight = BlockSizeOverrides[I].Height;

        TotalWidth += CurrentBlockWidth + BlockGap + BlockOutlineH;
        TotalHeight = FMax(TotalHeight, CurrentBlockHeight + BlockOutlineV);

        BlockRatio = BlockRatioOverrides[I].Ratio;
        BlockOffsetX = BlockOffsetOverrides[I].X;
        BlockOffsetY = BlockOffsetOverrides[I].Y;

        // Handle empty blocks so that we don't get DBZ errors
        if (BlockRatio <= 0.f)
        {
            P1 = 0.f;
            P2 = 0.f;
        }
        else
        {
            BarRatio -= BlockRatio;
            P1 = BarRatio < 0.f
                // We overflowed, so we have to subtract it
                ? FMax((BlockRatio + BarRatio) / BlockRatio, 0.f)
                // We can fill the block up to 100%
                : 1.f;
            P2 = 0.f;

            // Once we've "drained" (rendered) all of the primary bar, start draining the buffer
            if (BufferRatio > 0.f && P1 < 1.f)
            {
                // Try to fill the rest of the block (that's not occupied by the first bar)
                P2 = 1.f - P1;
                BufferRatio -= P2 * BlockRatio;

                // If we overflowed, subtract the overflow from the buffer (P2)
                if (BufferRatio < 0.f)
                {
                    // BufferRatio is negative, so we need to add it to P2
                    P2 += BufferRatio / BlockRatio;
                }
            }
        }

        BarBlockWidth = GetInnerBarWidth(BarType, CurrentBlockWidth, P1);

        // Second condition is to prevent rendering over a rounded-up block
        BufferBlockWidth = (P2 > 0.f && !(BlockRoundingStrategy != 0 && BarBlockWidth >= 1.f))
            ? GetInnerBarWidth(BarType, CurrentBlockWidth, P2, P1)
            : 0.f;

        // Adjust the Y pos to align the different block heights
        switch (BlockVerticalAlignment)
        {
            // Alignment: Bottom
            case 1:
                CurrentBlockPosY = PosY + BarHeight - (CurrentBlockHeight + BlockOutlineV);
                break;
            // Alignment: Middle
            case 2:
                CurrentBlockPosY = PosY - ((CurrentBlockHeight + BlockOutlineV) - BarHeight) / 2.f;
                break;
            // Alignment: Top
            case 0:
            default:
                CurrentBlockPosY = PosY;
        }

        // Draw background
        SetCanvasColor(Canvas, ((BarBlockWidth + BufferBlockWidth) / CurrentBlockWidth) <= HUDConfig.EmptyBlockThreshold ? EmptyBGColor : BGColor);
        Canvas.SetPos(BlockOffsetX + CurrentBlockPosX, BlockOffsetY + CurrentBlockPosY);
        Canvas.DrawTile(default.BarBGTexture, CurrentBlockWidth + BlockOutlineH, CurrentBlockHeight + BlockOutlineV, 0, 0, 32, 32);

        CurrentBlockPosX += BlockOutline.Left;
        CurrentBlockPosY += BlockOutline.Top;

        // Draw main bar
        if (BarBlockWidth > 0.f)
        {
            SetCanvasColor(Canvas, BarColor);
            Canvas.SetPos(BlockOffsetX + CurrentBlockPosX, BlockOffsetY + CurrentBlockPosY);
            Canvas.DrawTile(default.BarBGTexture, BarBlockWidth, CurrentBlockHeight, 0, 0, 32, 32);
        }

        // Draw the buffer after the main bar
        if (BufferBlockWidth > 0.f)
        {
            SetCanvasColor(Canvas, BufferColor);
            Canvas.SetPos(BlockOffsetX + CurrentBlockPosX + BarBlockWidth, BlockOffsetY + CurrentBlockPosY);
            Canvas.DrawTile(default.BarBGTexture, BufferBlockWidth, CurrentBlockHeight, 0, 0, 32, 32);
        }

        if (HUDConfig.DrawDebugRatios)
        {
            DebugRatioText = class'FriendlyHUD.FriendlyHUDHelper'.static.FloatToString(P1 * BlockRatio, 2) $ "/" $ class'FriendlyHUD.FriendlyHUDHelper'.static.FloatToString(BlockRatio, 2);
            SetCanvasColor(Canvas, MakeColor(202, 44, 146, 255));
            Canvas.TextSize(DebugRatioText, DebugRatioWidth, DebugRatioHeight, 0.6f, 0.6f);
            Canvas.SetPos(BlockOffsetX + CurrentBlockPosX, BlockOffsetY + CurrentBlockPosY + CurrentBlockHeight - DebugRatioHeight);
            Canvas.DrawText(DebugRatioText, , 0.6f, 0.6f, DebugTextFontRenderInfo);
        }

        CurrentBlockPosX += CurrentBlockWidth + BlockOutline.Right + BlockGap;
    }
}

function DrawPlayerIcon(Canvas Canvas, const out PlayerItemInfo ItemInfo, float PlayerIconPosX, float PlayerIconPosY)
{
    local KFPlayerReplicationInfo KFPRI;
    local Texture2D PlayerIcon, PrestigeIcon;
    local byte PrestigeLevel;
    local bool IsPlayerIcon;

    KFPRI = ItemInfo.KFPRI;

    Canvas.SetPos(PlayerIconPosX, PlayerIconPosY);

    if( HUDConfig.CDCompatEnabled && SentinelReplicationInfo(KFPRI) == None )
    {
        switch( ItemInfo.RepInfo.PlayerStateArray[ItemInfo.RepIndex] )
        {
            case PRS_Ready:
                SetCanvasColor(Canvas, HUDConfig.CDReadyIconColor);
                Canvas.DrawTile(default.PlayerReadyIconTexture, R.PlayerIconSize, R.PlayerIconSize, 0, 0, 256, 256);
                return;
            case PRS_NotReady:
                SetCanvasColor(Canvas, HUDConfig.CDNotReadyIconColor);
                Canvas.DrawTile(default.PlayerNotReadyIconTexture, R.PlayerIconSize, R.PlayerIconSize, 0, 0, 256, 256);
                return;
            case PRS_Default:
            default:
                break;
        }
    }

    PrestigeLevel = KFPRI.GetActivePerkPrestigeLevel();

	IsPlayerIcon = KFPRI.CurrentVoiceCommsRequest == VCT_NONE && KFPRI.CurrentPerkClass != None;
    PlayerIcon = KFPRI.GetCurrentIconToDisplay();

    if( IsPlayerIcon && PrestigeLevel > 0 )
    {
		PrestigeIcon = GetPrestigeIcon(self, HUD, KFPRI, PrestigeLevel);
		
        Canvas.DrawTile(PrestigeIcon, R.PlayerIconSize, R.PlayerIconSize, 0, 0, 256, 256);
        Canvas.SetPos(PlayerIconPosX + (R.PlayerIconSize * (1 - PrestigeIconScale)) / 2.f, PlayerIconPosY + R.PlayerIconSize * 0.05f);
        Canvas.DrawTile(PlayerIcon, R.PlayerIconSize * PrestigeIconScale, R.PlayerIconSize * PrestigeIconScale, 0, 0, 256, 256);
    }
    else Canvas.DrawTile(PlayerIcon, R.PlayerIconSize, R.PlayerIconSize, 0, 0, 256, 256);
}

function bool IsPRIRenderable(FriendlyHUDReplicationInfo RepInfo, int RepIndex)
{
    local KFPlayerReplicationInfo KFPRI;
    local SentinelReplicationInfo SRI;

    KFPRI = RepInfo.KFPRIArray[RepIndex];
    if (KFPRI == None) return false;
    
    SRI = SentinelReplicationInfo(KFPRI);
    if( SRI != None && SRI.TurretOwner != None && SRI.TurretOwner.Instigator != None && SRI.TurretOwner.Instigator.PlayerReplicationInfo == KFPlayerOwner.PlayerReplicationInfo ) return true;

    // Don't render inactive players
    if (KFPRI.bIsInactive) return false;

    // Don't render spectators
    if (KFPRI.bOnlySpectator) return false;
    if (KFPRI.Team == None) return false;

    // Don't render non-human players (shouldn't happen since UpdatePRIARray filters out non-players)
    if (KFPRI.Team != KFPlayerOwner.PlayerReplicationInfo.Team) return false;

    // Only render players that have Spawned in once already
    if (RepInfo.HasSpawnedArray[RepIndex] == 0) return false;

    // If enabled, don't render ourselves
    if (HUDConfig.IgnoreSelf && KFPRI == KFPlayerOwner.PlayerReplicationInfo && !ManualModeActive) return false;

    // Don't render players that were manually hidden
    if (!VisibilityOverride
        && RepInfo.ManualVisibilityArray[RepIndex] == 0
        && KFPRI != KFPlayerOwner.PlayerReplicationInfo
        && !ManualModeActive) return false;

    return true;
}

delegate Texture2D GetPrestigeIcon(FriendlyHUDInteractionAddon FHUDInfo, HUD HUDInterface, KFPlayerReplicationInfo KFPRI, byte PrestigeLevel)
{
	return KFPRI.CurrentPerkClass.default.PrestigeIcons[PrestigeLevel - 1];
}

delegate int SortKFPRI(PRIEntry A, PRIEntry B)
{
    if( SentinelReplicationInfo(A.KFPRI) != None && SentinelReplicationInfo(B.KFPRI) != None ) return 0;
    else if( SentinelReplicationInfo(A.KFPRI) != None ) return -1;
    else if( SentinelReplicationInfo(B.KFPRI) != None ) return 1;
	
    return Super.SortKFPRI(A, B);
}

delegate int SortKFPRIByHealthDescending(PRIEntry A, PRIEntry B)
{
    if( SentinelReplicationInfo(A.KFPRI) != None && SentinelReplicationInfo(B.KFPRI) != None ) return 0;
    else if( SentinelReplicationInfo(A.KFPRI) != None ) return -1;
    else if( SentinelReplicationInfo(B.KFPRI) != None ) return 1;
	
    return Super.SortKFPRIByHealthDescending(A, B);
}

delegate int SortKFPRIByHealth(PRIEntry A, PRIEntry B)
{
    if( SentinelReplicationInfo(A.KFPRI) != None && SentinelReplicationInfo(B.KFPRI) != None ) return 0;
    else if( SentinelReplicationInfo(A.KFPRI) != None ) return -1;
    else if( SentinelReplicationInfo(B.KFPRI) != None ) return 1;
	
    return Super.SortKFPRIByHealth(A, B);
}

delegate int SortKFPRIByRegenHealthDescending(PRIEntry A, PRIEntry B)
{
    if( SentinelReplicationInfo(A.KFPRI) != None && SentinelReplicationInfo(B.KFPRI) != None ) return 0;
    else if( SentinelReplicationInfo(A.KFPRI) != None ) return -1;
    else if( SentinelReplicationInfo(B.KFPRI) != None ) return 1;
	
    return Super.SortKFPRIByRegenHealthDescending(A, B);
}

delegate int SortKFPRIByRegenHealth(PRIEntry A, PRIEntry B)
{
    if( SentinelReplicationInfo(A.KFPRI) != None && SentinelReplicationInfo(B.KFPRI) != None ) return 0;
    else if( SentinelReplicationInfo(A.KFPRI) != None ) return -1;
    else if( SentinelReplicationInfo(B.KFPRI) != None ) return 1;
	
    return Super.SortKFPRIByRegenHealth(A, B);
}

delegate bool OverridePlayerNameDraw(FriendlyHUDInteractionAddon FHUDInfo, KFPlayerReplicationInfo KFPRI, HUD HUDInterface, Canvas Canvas, float PlayerNamePosX, float PlayerNamePosY, string PlayerName, FontRenderInfo TextFontRenderInfo, const PlayerItemInfo ItemInfo, optional byte IsFriend)
{
	return false;
}

delegate bool GetPlayerIsChatting(FriendlyHUDInteractionAddon FHUDInfo, KFPlayerReplicationInfo KFPRI, HUD HUDInterface)
{
	return false;
}

delegate DrawPlayerChatIcon(FriendlyHUDInteractionAddon FHUDInfo, KFPlayerReplicationInfo KFPRI, HUD HUDInterface, Canvas Canvas, float ChatIconPosX, float ChatIconPosY, out float PlayerNamePosX)
{
	return;
}

delegate Font GetCanvasFont(FriendlyHUDInteractionAddon FHUDInfo, HUD HUDInterface)
{
	return class'KFGameEngine'.static.GetKFCanvasFont();
}

delegate float GetCanvasFontScale(FriendlyHUDInteractionAddon FHUDInfo, HUD HUDInterface)
{
	return class'KFGameEngine'.static.GetKFFontScale();
}

static final function float Approach( float Cur, float Target, float Inc )
{
	Inc = Abs(Inc);

	if( Cur < Target )
		return FMin(Cur + Inc, Target);
	else if( Cur > Target )
		return FMax(Cur - Inc, Target);

	return Target;
}

final function Texture2D FindAvatar( UniqueNetId ClientID )
{
	local string S;
	
	S = KFPlayerOwner.GetSteamAvatar(ClientID);
	if( S=="" )
		return None;
	return Texture2D(FindObject(S,class'Texture2D'));
}