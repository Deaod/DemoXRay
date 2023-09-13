class DemoXRayLog extends StatLogFile;

enum EDemoEvent {
    DE_Over,
    DE_OnTarget,
    DE_OnTargetCover,
    DE_HitEnemy,
    DE_HitTeam,
    DE_Hit,
    DE_Missed,
    DE_Left,
    DE_TimeRemaining,
    DE_TimeElapsed,
};

var EDemoEvent PrevEvent;
var int EventRepeatCount;

static final operator(16) string *(coerce string A, coerce string B) {
    return A$","$B;
}

event BeginPlay() {
    // empty to override StatLog
}

function string PadTo2Digits(int A) {
    if (A < 10)
        return "0"$A;
    return string(A);
}

function string GetEventDescr(EDemoEvent E) {
    switch(E) {
        case DE_Over:
            return "over";
        case DE_OnTarget:
            return "target";
        case DE_OnTargetCover:
            return "target_cover";
        case DE_HitEnemy:
            return "hitenemy";
        case DE_HitTeam:
            return "hitteam";
        case DE_Hit:
            return "hit";
        case DE_Missed:
            return "missed";
        case DE_Left:
            return "left";
        case DE_TimeRemaining:
            return "remaining";
        case DE_TimeElapsed:
            return "elapsed";
    }
    return "unknown";
}

function StartLog() {
    local string FileName;

    bWorld = false;
    FileName = "../Logs/DemoXRay_"$Level.Year$PadTo2Digits(Level.Month)$PadTo2Digits(Level.Day)$"_"$PadTo2Digits(Level.Hour)$PadTo2Digits(Level.Minute);
    StatLogFile = FileName$".tmp.csv";
    StatLogFinal = FileName$".csv";

    OpenLog();

    // header
    FileLog("frame,timestamp,frame_ms,clock_stamp,eventid,event,event_repeat,mousedelta_x,mousedelta_y,target_name,target_accuracy,weapon_anim,weapon_animframe");
    Log("frame,timestamp,frame_ms,clock_stamp,eventid,event,event_repeat,mousedelta_x,mousedelta_y,target_name,target_accuracy,weapon_anim,weapon_animframe", 'DemoXRay');
}

function LogEvent(
    int Frame,
    float TimeStamp,
    float Delta,
    int ClockStamp,
    EDemoEvent E,
    optional rotator MouseDelta,
    optional string TargetName,
    optional float TargetAccuracy,
    optional name WeaponAnim,
    optional float WeaponAnimFrame
) {
    local string LogStr;

    if (PrevEvent != E) {
        PrevEvent = E;
        EventRepeatCount = 1;
    } else {
        EventRepeatCount += 1;
    }
    
    LogStr = string(Frame)*TimeStamp*(Delta*1000.0)*ClockStamp*E*GetEventDescr(E)*EventRepeatCount*MouseDelta.Yaw*MouseDelta.Pitch*TargetName*TargetAccuracy*WeaponAnim*WeaponAnimFrame;
    FileLog(LogStr);
    Log(LogStr, 'DemoXRay');
}

function LogEventString(string S) {
    FileLog(S);
}

defaultproperties {
    bWorld=False
}
