function sendtrig(send, ioObj, ioAddress, sig)

global FIX_START FIX_BREAK STM_OFFSET TRL_SUCCESS TRL_FAILURE SESSION_START
global duration

if send
    if sig < 200
        SimpleGazeTracker('SendMessage', strcat('Trial Onset: ', num2str(sig)));
    elseif sig == FIX_START
        SimpleGazeTracker('SendMessage', "Fixation Initiation");
    elseif sig == FIX_BREAK
        SimpleGazeTracker('SendMessage', "Fixation Break");
    elseif sig == STM_OFFSET
        SimpleGazeTracker('SendMessage', "Stimulus Offset");
    elseif sig == TRL_SUCCESS
        SimpleGazeTracker('SendMessage', "Trial Success");
    elseif sig == TRL_FAILURE
        SimpleGazeTracker('SendMessage', "Trial Failure");
    elseif sig == SESSION_START
        SimpleGazeTracker('SendMessage', "Session Start");
    end
    
    io64(ioObj, ioAddress, sig)
    WaitSecs(duration.triggerPulseWidth)
    io64(ioObj, ioAddress, 0)
    
end
end

