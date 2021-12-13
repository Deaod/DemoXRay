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
    return "["$Left("      ", 6-Len(S))$S$"]";
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

function Print(coerce string S) {
    Log(S, 'DemoXRay');
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
            Print(FrameStamp(FrameCounter)@"1 - Over"@Target.PlayerReplicationInfo.PlayerName);
        } else {
            Print(FrameStamp(FrameCounter)@"1 - Left"@OldTarget.PlayerReplicationInfo.PlayerName);
        }
    } else if (Target != OldTarget) {
        Print(FrameStamp(FrameCounter)@"1 - Left"@OldTarget.PlayerReplicationInfo.PlayerName);
        Print(FrameStamp(FrameCounter)@"1 - Over"@Target.PlayerReplicationInfo.PlayerName);
    }

    if (Target == none)
        return;

    Print(FrameStamp(FrameCounter)@"2 - TargetAccuracy"@TargetAccuracy);

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

function PrintShot(int Frame, Pawn T, float Acc, bool bCover, vector MouseRPS) {
    if (T == none || bCover) {
        Print(FrameStamp(Frame)@"3 - Missed");
    } else if (Following != none) {
        if (Following.PlayerReplicationInfo.Team == T.PlayerReplicationInfo.Team) {
            Print(FrameStamp(Frame)@"3 - HitTeam"@T.PlayerReplicationInfo.PlayerName@"("$Acc$")"@"["$FormatFloat(MouseRPS.X,3)$","$FormatFloat(MouseRPS.Y,3)$"]");
        } else {
            Print(FrameStamp(Frame)@"3 - HitEnemy"@T.PlayerReplicationInfo.PlayerName@"("$Acc$")"@"["$FormatFloat(MouseRPS.X,3)$","$FormatFloat(MouseRPS.Y,3)$"]");
        }
    } else {
        Print(FrameStamp(Frame)@"3 - Hit"@T.PlayerReplicationInfo.PlayerName@"("$Acc$")"@"["$FormatFloat(MouseRPS.X,3)$","$FormatFloat(MouseRPS.Y,3)$"]");
    }
}

function DrawFireState(Canvas C) {
    local float X, Y;
    local string Text;
    local name AnimSeq;
    local float AnimFrame;
    local rotator MouseDelta;
    local vector MouseVel;

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
                // fired
                MouseDelta = (Following.ViewRotation - OldVR[1]);
                MouseVel.X = RotU2S(MouseDelta.Pitch) / (LastDelta[0]+LastDelta[1]) / 65535.0;
                MouseVel.Y = RotU2S(MouseDelta.Yaw) / (LastDelta[0]+LastDelta[1]) / 65535.0;

                PrintShot(FrameCounter, Target, TargetAccuracy, bTargetBehindCover, MouseVel);
            }
            // else not fired
        } else {
            // fired
            MouseDelta = OldVR[0] - OldVR[2];
            MouseVel.X = RotU2S(MouseDelta.Pitch) / (LastDelta[1]+LastDelta[2]) / 65535.0;
            MouseVel.Y = RotU2S(MouseDelta.Yaw) / (LastDelta[1]+LastDelta[2]) / 65535.0;

            PrintShot(FrameCounter - 1, OldTarget, OldTargetAccuracy, bOldTargetBehindCover, MouseVel);
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

simulated event PostRender( Canvas C ) {
    local Pawn P;
    local float X,Y;
    local Actor VT;

    VT = PlayerOwner;
    while (VT != none && VT.IsA('PlayerPawn') && PlayerPawn(VT).ViewTarget != none)
        VT = PlayerPawn(VT).ViewTarget;

    foreach AllActors(class'Pawn', P)
        if (P.IsA('Spectator') == false && P != VT)
            C.DrawActor(P, false, true);

    Following = Pawn(VT);

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
