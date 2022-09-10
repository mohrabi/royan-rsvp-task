function sendtrig(sendTrigger, connectToEyeTracker, sessionHandler, sig)

global FIX_START FIX_BREAK STM_OFFSET TRL_SUCCESS TRL_FAILURE SESSION_START

if connectToEyeTracker
    if sig < 200
        SimpleGazeTracker('SendMessage', char(strcat("Trial Onset: ", num2str(sig))));
    elseif sig == FIX_START
        SimpleGazeTracker('SendMessage', char("Fixation Initiation"));
    elseif sig == FIX_BREAK
        SimpleGazeTracker('SendMessage', char("Fixation Break"));
    elseif sig == STM_OFFSET
        SimpleGazeTracker('SendMessage', char("Stimulus Offset"));
    elseif sig == TRL_SUCCESS
        SimpleGazeTracker('SendMessage', char("Trial Success"));
    elseif sig == TRL_FAILURE
        SimpleGazeTracker('SendMessage', char("Trial Failure"));
    elseif sig == SESSION_START
        SimpleGazeTracker('SendMessage', char("Session Start"));
    end
end

if sendTrigger
    sig_bin = decimalToBinaryVector(sig, 8, 'LSBFirst');
    outputSingleScan(sessionHandler, sig_bin)
end

end

