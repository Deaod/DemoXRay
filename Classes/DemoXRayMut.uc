class DemoXRayMut extends Mutator;

#exec Texture Import File=Textures\Dot.pcx Name=Dot Mips=Off

var PlayerPawn PlayerOwner;
var Pawn Following;
var Pawn OldFollowing;
var rotator OldVR[3];
var vector OldLoc, OldVel;
var float OldEyeHeight;
var name OldAnimSeq;
var float OldAnimFrame;

var Pawn Target;
var bool bTargetBehindCover;
var float TargetAccuracy;
var Pawn OldTarget;
var bool bOldTargetBehindCover;
var float OldTargetAccuracy;

var int FrameCounter;
var ChallengeHUD HUD;
var float LastDelta[3];
var bool bHaveLineHeight;
var float LineHeight;

var DemoXRayLog Logger;
var bool bOvertime;
var int OvertimeStart;
var int ClockTime;

var vector TempVec;
var DemoXRayDummy Dummy[32];

// convert rotation representation from signed to unsigned
static final function int RotS2U(int A) {
    return A & 0xFFFF;
}

// convert rotation representation from unsigned to signed
static final function int RotU2S(int A) {
    return A << 16 >> 16;
}

static final function string FrameStamp(int Frame) {
    local string S;
    S = string(Frame);
    return "["$Left("       ", 7-Len(S))$S$"]";
}

static final function string FormatFloat(float F, optional int Decimals) {
    local string Result;
    local int T;

    if (Decimals <= 0)
        return string(int(F));

    if (Decimals <= 6) {
        Result = string(F);
        Result = Left(Result, Len(Result) - 6 + Decimals);
        return Result;
    }

    Result = int(F) $ ".";
    F -= int(F);
    while(Decimals > 0) {
        F *= 10;
        T = int(F);
        Result = Result $ T;
        F -= T;
        Decimals--;
    }
    return Result;
}

event PostBeginPlay() {
    local int i;

    super.PostBeginPlay();

    Logger = Spawn(class'DemoXRayLog');
    Logger.StartLog();

    for (i = 0; i < arraycount(Dummy); i++) {
        Dummy[i] = Spawn(class'DemoXRayDummy');
        Dummy[i].bCollideWorld = false;
        Dummy[i].SetCollision(false, false, false);
        Dummy[i].SetCollisionSize(0.0, 0.0);
        Dummy[i].DrawType = DT_Mesh;
    }
}

function LogEventCurFrame(DemoXRayLog.EDemoEvent E) {
    local string TargetName;
    local name WeaponAnim;
    local float WeaponAnimFrame;
    local rotator MouseDelta;
    local int ClockStamp;

    if (Following != none)
        MouseDelta = (Following.ViewRotation - OldVR[0]);
    if (Target != none)
        TargetName = Target.PlayerReplicationInfo.PlayerName;
    if (Following != none && Following.Weapon != none)
        WeaponAnim = Following.Weapon.AnimSequence;
    if (Following != none && Following.Weapon != none)
        WeaponAnimFrame = Following.Weapon.AnimFrame;

    if (PlayerOwner.GameReplicationInfo != none) {
        if (bOvertime)
            ClockStamp = PlayerOwner.GameReplicationInfo.ElapsedTime - OvertimeStart;
        else
            ClockStamp = PlayerOwner.GameReplicationInfo.RemainingTime;
    }

    Logger.LogEvent(
        FrameCounter,
        Level.TimeSeconds,
        LastDelta[0],
        ClockStamp,
        E,
        MouseDelta,
        TargetName,
        TargetAccuracy,
        WeaponAnim,
        WeaponAnimFrame
    );
}

function LogEventPrevFrame(DemoXRayLog.EDemoEvent E) {
    local string TargetName;
    local name WeaponAnim;
    local float WeaponAnimFrame;
    local int ClockStamp;

    if (OldTarget != none)
        TargetName = OldTarget.PlayerReplicationInfo.PlayerName;
    if (Following != none && Following.Weapon != none)
        WeaponAnim = Following.Weapon.AnimSequence;
    if (Following != none && Following.Weapon != none)
        WeaponAnimFrame = Following.Weapon.AnimFrame;

    if (PlayerOwner.GameReplicationInfo != none) {
        if (bOvertime)
            ClockStamp = PlayerOwner.GameReplicationInfo.ElapsedTime - OvertimeStart;
        else
            ClockStamp = PlayerOwner.GameReplicationInfo.RemainingTime;
    }

    Logger.LogEvent(
        FrameCounter - 1,
        Level.TimeSeconds - LastDelta[0],
        LastDelta[1],
        ClockStamp,
        E,
        (OldVR[0] - OldVR[1]),
        TargetName,
        TargetAccuracy,
        WeaponAnim,
        WeaponAnimFrame
    );
}

function DrawCameraDelta(Canvas C) {
    local float X,Y;
    local rotator CameraRotation;
    local rotator CameraDelta;
    local string CamDeltaString;

    if (Following.IsA('PlayerPawn')) {
        if (Following == OldFollowing) {
            CameraRotation = PlayerPawn(Following).ViewRotation;
            CameraDelta = CameraRotation - OldVR[0];
        } else {
            CameraDelta = rot(0,0,0);
        }
    } else {
        CameraDelta = rot(0,0,0);
    }

    CamDeltaString = CameraRotation.Pitch$","$CameraRotation.Yaw@"("$RotU2S(CameraDelta.Pitch)$","$RotU2S(CameraDelta.Yaw)$")";

    C.TextSize(CamDeltaString, X, Y);
    C.SetPos(C.SizeX - X, Y*2);
    C.DrawText(CamDeltaString);
}

function float CalcTargetAccuracy(Actor HitActor, vector HitLocation, vector TraceDir) {
    if (HitActor == none) return 0.0;
    return Abs(Normal(TraceDir) Dot Normal(HitActor.Location - HitLocation)) ** 2.0;
}

function DetermineTarget() {
    local vector HitLocation, HitNormal;
    local vector TraceDir, TraceStart, TraceEnd;
    local Actor HitActor;
    local bool bCollideWorldSave;
    local int Iterations;

    if (Following == none) {
        Target = none;
        TargetAccuracy = -1;
        return;
    }

    TraceDir = vector(Following.ViewRotation);
    TraceStart = Following.Location + vect(0,0,1)*Following.EyeHeight;
    TraceEnd = TraceStart + TraceDir*200000.0;

    HitActor = Following.Trace(HitLocation, HitNormal, TraceEnd, TraceStart, true);

    if (HitActor != none && HitActor.IsA('Pawn')) {
        Target = Pawn(HitActor);
        bTargetBehindCover = false;
        TargetAccuracy = CalcTargetAccuracy(HitActor, HitLocation, TraceDir);

        return;
    }

    if (HitActor == Following.Level) {
        bCollideWorldSave = Following.bCollideWorld;
        Following.bCollideWorld = false;
        HitActor = Following.Trace(HitLocation, HitNormal, TraceEnd, TraceStart, true);
        while(HitActor != none && Pawn(HitActor) == none && Iterations < 64) {
            ++Iterations;
            TraceStart = HitLocation + TraceDir*32;
            HitActor = Following.Trace(HitLocation, HitNormal, TraceEnd, TraceStart, true);
        }
        Following.bCollideWorld = bCollideWorldSave;
    }

    if ((HitActor == none) ||
        (Pawn(HitActor) == none)
    ) {
        Target = none;
        TargetAccuracy = -1;
        return;
    }

    Target = Pawn(HitActor);
    bTargetBehindCover = true;
    TargetAccuracy = CalcTargetAccuracy(HitActor, HitLocation, TraceDir);
}

function DrawTarget(Canvas C) {
    local float X, Y;
    local string Name;

    DetermineTarget();

    if ((Target == none) != (OldTarget == none)) {
        if (Target != none) {
            LogEventCurFrame(DE_Over);
        } else {
            LogEventPrevFrame(DE_Left);
        }
    } else if (Target != OldTarget) {
        LogEventPrevFrame(DE_Left);
        LogEventCurFrame(DE_Over);
    }

    if (Target == none)
        return;

    if (bTargetBehindCover) {
        LogEventCurFrame(DE_OnTargetCover);
    } else {
        LogEventCurFrame(DE_OnTarget);
    }

    Name = Target.PlayerReplicationInfo.PlayerName@"("$int(TargetAccuracy*100.0+0.5)$"%)";

    if (bTargetBehindCover) {
        C.DrawColor.R = 255;
        C.DrawColor.G = 0;
        C.DrawColor.B = 0;

        C.TextSize(Name, X, Y);
        C.SetPos((C.SizeX - X) / 2, 0.8 * C.SizeY + Y);
        C.DrawText(Name);

        C.DrawColor.R = 255;
        C.DrawColor.G = 255;
        C.DrawColor.B = 255;
    } else {
        C.TextSize(Name, X, Y);
        C.SetPos((C.SizeX - X) / 2, 0.8 * C.SizeY);
        C.DrawText(Name);
    }
}

function LogShotCurFrame(Pawn T, bool bCover) {
    if (T == none || bCover) {
        LogEventCurFrame(DE_Missed);
    } else if (Following != none) {
        if (Following.PlayerReplicationInfo.Team == T.PlayerReplicationInfo.Team)
            LogEventCurFrame(DE_HitTeam);
        else
            LogEventCurFrame(DE_HitEnemy);
    } else {
        LogEventCurFrame(DE_Hit);
    }
}

function LogShotPrevFrame(Pawn T, bool bCover) {
    if (T == none || bCover) {
        LogEventPrevFrame(DE_Missed);
    } else if (Following != none) {
        if (Following.PlayerReplicationInfo.Team == T.PlayerReplicationInfo.Team)
            LogEventPrevFrame(DE_HitTeam);
        else
            LogEventPrevFrame(DE_HitEnemy);
    } else {
        LogEventPrevFrame(DE_Hit);
    }
}

function DrawFireState(Canvas C) {
    local float X, Y;
    local string Text;
    local name AnimSeq;
    local float AnimFrame;

    if (Following == none) return;
    if (Following.Weapon == none) return;

    AnimSeq = Following.Weapon.AnimSequence;
    AnimFrame = Following.Weapon.AnimFrame;
    Text = AnimSeq@"("$AnimFrame$")";

    C.TextSize(Text, X, Y);
    C.SetPos(C.SizeX - X, Y*3);
    C.DrawText(Text);

    if (Left(string(AnimSeq), 4) ~= "Fire") {
        // maybe fired
        if (Left(string(OldAnimSeq), 4) ~= "Fire") {
            if (AnimFrame < OldAnimFrame) {
                LogShotCurFrame(Target, bTargetBehindCover);
            }
            // else not fired
        } else {
            LogShotPrevFrame(OldTarget, bOldTargetBehindCover);
        }
    }
}

function DrawDelta(Canvas C) {
    local float X, Y;

    C.TextSize(LastDelta[0]*1000.0, X, Y);
    C.SetPos(C.SizeX - X, Y);
    C.DrawText(LastDelta[0]*1000.0);
}

function DrawCrosshairDot(Canvas C) {
    class'CanvasUtils'.static.SaveCanvas(C);

    C.Style = 1;
    C.SetPos(C.SizeX/2-1,C.SizeY/2-1);
    C.DrawTile(Texture'Dot',2,2,0,0,1,1);

    class'CanvasUtils'.static.RestoreCanvas(C);
}

function DrawMovement(Canvas C) {
    local float X, Y;
    local vector Loc, DeltaLoc;
    local string LocationText;
    local vector Vel, DeltaVel;
    local string VelocityText;

    if (Following == none) return;

    Loc = Following.Location;
    DeltaLoc = Loc - OldLoc;
    LocationText = "Loc:"@int(Loc.X)$","$int(Loc.Y)$","$int(Loc.Z)@"("$FormatFloat(DeltaLoc.X, 3)$","$FormatFloat(DeltaLoc.Y, 3)$","$FormatFloat(DeltaLoc.Z, 3)$")";
    C.TextSize(LocationText, X, Y);
    C.SetPos(C.SizeX-X,Y*4);
    C.DrawText(LocationText);

    Vel = Following.Velocity;
    DeltaVel = Vel - OldVel;

    VelocityText = "Vel:"@int(Vel.X)$","$int(Vel.Y)$","$int(Vel.Z)@"("$FormatFloat(DeltaVel.X, 3)$","$FormatFloat(DeltaVel.Y, 3)$","$FormatFloat(DeltaVel.Z, 3)$")";
    C.TextSize(VelocityText, X, Y);
    C.SetPos(C.SizeX-X,Y*5);
    C.DrawText(VelocityText);
}

function DrawXRay(Canvas C) {
    local Pawn P;
    local int i;
    local ENetRole TempRole;
    local vector ServerLoc;

    for (i = 0; i < arraycount(PlayerOwner.GameReplicationInfo.PRIArray); i++) {
        if (PlayerOwner.GameReplicationInfo.PRIArray[i] == none) break; // end of array
        P = Pawn(PlayerOwner.GameReplicationInfo.PRIArray[i].Owner);
        if (P == none) continue;
        if (P == Following) continue;

        C.DrawActor(P, false, true);

        if (P.IsA('bbPlayer') == false) continue;

        TempVec = vect(0.0, 0.0, 0.0);

        TempRole = P.Role;
        P.Role = ROLE_Authority;
        SetPropertyText("TempVec", P.GetPropertyText("IGPlus_LocationOffsetFix_ServerLocation"));
        P.Role = TempRole;

        ServerLoc = TempVec;
        if (ServerLoc dot ServerLoc == 0) continue;

        Dummy[i].SetLocation(ServerLoc);
        Dummy[i].SetRotation(P.Rotation);
        Dummy[i].Mesh = P.Mesh;
        Dummy[i].AnimSequence = P.AnimSequence;
        Dummy[i].AnimFrame = P.AnimFrame;

        Dummy[i].bHidden = false;
        C.DrawActor(Dummy[i], true, false);
        Dummy[i].bHidden = true;
    }

    // foreach AllActors(class'Pawn', P)
    //     if (P.IsA('Spectator') == false && P != Following)
    //         C.DrawActor(P, false, true);
}

simulated event PostRender( Canvas C ) {
    local float X,Y;
    local Actor VT;

    if (PlayerOwner.GameReplicationInfo != none) {
        if (PlayerOwner.GameReplicationInfo.GameEndedComments != "") {
            if (Logger != none) {
                Logger.StopLog();
                Logger.Destroy();
                Logger = none;
            }
            return;
        }
        if (PlayerOwner.GameReplicationInfo.RemainingTime == 0) {
            bOvertime = true;
            OvertimeStart = PlayerOwner.GameReplicationInfo.ElapsedTime;
        }
    }

    VT = PlayerOwner;
    while (VT != none && VT.IsA('PlayerPawn') && PlayerPawn(VT).ViewTarget != none)
        VT = PlayerPawn(VT).ViewTarget;

    Following = Pawn(VT);

    DrawXRay(C);

    C.Font = HUD.MyFonts.GetSmallFont(C.ClipX);
    C.DrawColor.R = 255;
    C.DrawColor.G = 255;
    C.DrawColor.B = 255;
    C.DrawColor.A = 255;

    if (bHaveLineHeight == false)
        C.TextSize("TEST", X, LineHeight);

    C.TextSize(FrameCounter, X, Y);
    C.SetPos(C.SizeX-X,0);
    C.DrawText(FrameCounter);
    ++FrameCounter;

    DrawDelta(C);
    DrawCameraDelta(C);
    DrawTarget(C);
    DrawFireState(C);
    DrawCrosshairDot(C);
    DrawMovement(C);

    OldFollowing = Following;
    if (Following != none) {
        OldVR[2] = OldVR[1];
        OldVR[1] = OldVR[0];
        OldVR[0] = Following.ViewRotation;
        OldLoc = Following.Location;
        OldVel = Following.Velocity;
        OldEyeHeight = Following.EyeHeight;
        if (Following.Weapon != none) {
            OldAnimSeq = Following.Weapon.AnimSequence;
            OldAnimFrame = Following.Weapon.AnimFrame;
        }
        OldTarget = Target;
        bOldTargetBehindCover = bTargetBehindCover;
        OldTargetAccuracy = TargetAccuracy;
    }
}

function Tick(float Delta) {
    LastDelta[2] = LastDelta[1];
    LastDelta[1] = LastDelta[0];
    LastDelta[0] = Delta;

    if (Following != none) {
        if (Following.IsInState('Dying') && Left(Following.Class, 13) == "InstaGibPlus3") {
            Following.RotationRate = rot(0,0,0);
            Following.ViewRotation = rot(0,0,0);
        } else {
            Following.RotationRate = Following.default.RotationRate;
        }
        PlayerOwner.SetLocation(Following.Location + vect(0,0,1)*Following.EyeHeight);
    }
}

function RegisterHUDMutator() {
    local PlayerPawn P;

    ForEach AllActors( class'PlayerPawn', P) {
        if (P.myHUD != none) {
            NextHUDMutator = P.myHud.HUDMutator;
            P.myHUD.HUDMutator = self;
            bHUDMutator = true;
            PlayerOwner = P;
            HUD = ChallengeHUD(P.myHUD);
            SetOwner(PlayerOwner);
        }
    }
}
