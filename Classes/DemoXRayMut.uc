class DemoXRayMut extends Mutator;

var PlayerPawn PlayerOwner;
var Pawn Following;
var PlayerPawn OldFollowing;
var rotator OldVR;
var int FrameCounter;
var ChallengeHUD HUD;

// convert rotation representation from signed to unsigned
static function int RotS2U(int A) {
    return A & 0xFFFF;
}

// convert rotation representation from unsigned to signed
static function int RotU2S(int A) {
    return A << 16 >> 16;
}

static function rotator RotS2UR(rotator R) {
    R.Yaw = RotS2U(R.Yaw);
    R.Pitch = RotS2U(R.Pitch);
    R.Roll = RotS2U(R.Roll);
    return R;
}

static function rotator RotU2SR(rotator R) {
    R.Yaw = RotU2S(R.Yaw);
    R.Pitch = RotU2S(R.Pitch);
    R.Roll = RotU2S(R.Roll);
    return R;
}

function DrawCameraDelta(Canvas C) {
    local float X,Y;
    local rotator CameraDelta;
    local string CamDeltaString;

    if (Following.IsA('PlayerPawn')) {
        if (Following == OldFollowing) {
            CameraDelta = PlayerPawn(Following).ViewRotation - OldVR;
            OldVR = PlayerPawn(Following).ViewRotation;
        } else {
            CameraDelta = rot(0,0,0);
            OldFollowing = PlayerPawn(Following);
            OldVR = PlayerPawn(Following).ViewRotation;
        }
    } else {
        CameraDelta = rot(0,0,0);
    }

    CamDeltaString = RotU2S(CameraDelta.Pitch)$","$RotU2S(CameraDelta.Yaw);

    C.TextSize(CamDeltaString, X, Y);
    C.SetPos(C.SizeX - X, Y);
    C.DrawText(CamDeltaString);
}

function DrawTarget(Canvas C) {
    local vector HitLocation, HitNormal;
    local float X, Y;
    local vector TraceStart, TraceEnd;
    local Actor HitActor;
    local string Name;
    local bool bThroughWall;

    if (Following == none) return;

    TraceStart = Following.Location + vect(0,0,1)*Following.EyeHeight;
    TraceEnd = TraceStart + vector(Following.ViewRotation)*200000.0;

    HitActor = Following;
    while (HitActor != none && HitActor != Following.Level && (HitActor == Following || HitActor.IsA('Pawn') == false || HitActor.IsA('Spectator') == true)) {
        TraceStart = HitLocation + vector(Following.ViewRotation)*16;
        HitActor = HitActor.Trace(HitLocation, HitNormal, TraceEnd, TraceStart, true);
    }

    if (HitActor != none && HitActor.IsA('Pawn')) {
        Name = Pawn(HitActor).PlayerReplicationInfo.PlayerName;

        C.TextSize(Name, X, Y);
        C.SetPos((C.SizeX - X) / 2, 0.8 * C.SizeY);
        C.DrawText(Name);
    }

    if (HitActor == Following.Level) {
        bThroughWall = true;
        while (HitActor != none && (HitActor == Following || HitActor.IsA('Pawn') == false || HitActor.IsA('Spectator') == true)) {
            TraceStart = HitLocation + vector(Following.ViewRotation)*16;
            HitActor = HitActor.Trace(HitLocation, HitNormal, TraceEnd, TraceStart, true);
        }
    }

    if (HitActor == none) return;
    if (Pawn(HitActor) == none) return;

    Name = Pawn(HitActor).PlayerReplicationInfo.PlayerName;

    if (bThroughWall) {
        C.DrawColor.R = 255;
        C.DrawColor.G = 0;
        C.DrawColor.B = 0;
    }

    C.TextSize(Name, X, Y);
    C.SetPos((C.SizeX - X) / 2, 0.85 * C.SizeY);
    C.DrawText(Name);

    if (bThroughWall) {
        C.DrawColor.R = 255;
        C.DrawColor.G = 255;
        C.DrawColor.B = 255;
    }
}

simulated event PostRender( Canvas C ) {
    local Pawn P;
    local vector Delta;
    local float X,Y;

    foreach AllActors(class'Pawn', P) {
        Delta = P.Location - PlayerOwner.Location;
        if (P.IsA('Spectator') == false) {
            if (VSize(Delta*vect(1,1,0)) > class'TournamentPlayer'.default.CollisionRadius || Abs(Delta.Z) > class'TournamentPlayer'.default.CollisionHeight) {
                C.DrawActor(P, false, true);
            } else {
                Following = P;
            }
        }
    }

    C.Font = HUD.MyFonts.GetSmallFont(C.ClipX);
    C.DrawColor.R = 255;
    C.DrawColor.G = 255;
    C.DrawColor.B = 255;
    C.DrawColor.A = 255;

    C.TextSize(FrameCounter, X, Y);
    C.SetPos(C.SizeX-X,0);
    C.DrawText(FrameCounter);
    ++FrameCounter;

    DrawCameraDelta(C);
    DrawTarget(C);
}

function Tick(float Delta) {
    //
    if (Following != none)
        PlayerOwner.SetLocation(Following.Location + vect(0,0,1)*Following.EyeHeight);
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
