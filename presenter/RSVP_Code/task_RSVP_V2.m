%% Refreshing the Workspace
close all
clear
clc

addpath('Task Functions')

%% Subject Information
recordingDir = 'E:\Code\RSVP\recording';

subjectName = inputdlg("Enter Subject Name");
subjectName = subjectName{1};
SessionName = inputdlg("Enter Session");
SessionName = SessionName{1};
%subjectName = "Test";

if ~isfolder(fullfile(recordingDir, subjectName,SessionName))
    mkdir(fullfile(recordingDir, subjectName,SessionName))
end

sessionDateTime = datestr(datetime('now'), 'yyyymmdd-HHMM');
sessionDir = fullfile(recordingDir, subjectName,SessionName);
mkdir(sessionDir)

%% Declare Global Variables
global Params
Params.isStarted            = false;
Params.isPaused             = false;
Params.isStopped            = false;
Params.manualReward         = false;
Params.fillPipe             = false;
Params.isCerePlexConnected  = false;
Params.xOffset              = 0;
Params.yOffset              = 0;
Params.fixationRadius       = 2;
Params.fixationArea         = 0;
Params.rewardInterval       = 0;
Params.rewardDuration       = 0;
Params.acceptDuration       = 0;
Params.waitPunish           = 0;
Params.stimulusSize         = 5;

%%
global FIX_START FIX_BREAK STM_OFFSET TRL_SUCCESS TRL_FAILURE SESSION_START
FIX_START   = 220;
FIX_BREAK   = 221;
STM_OFFSET  = 222;
TRL_SUCCESS = 223;
TRL_FAILURE = 224;
SESSION_START = 225;

%% Task Parameters and Constants
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'TextRenderer', 1);
Screen('Preference', 'TextAntiAliasing', 1);
Screen('Preference', 'TextAlphaBlending', 0);
Screen('Preference', 'DefaultTextYPositionIsBaseline', 1);

% Connections
connectToControllerServer   = true;
connectToEyeTracker         = false;
connectToRewardPump         = true;
sendTriggers                = true;

% Paradigm Constants
global duration
duration.triggerPulseWidth = .01;
duration.presentation = .2  - duration.triggerPulseWidth;
duration.fixation = .5;
duration.rest = 0.8 - duration.triggerPulseWidth;
duration.punish = 0.5 - duration.triggerPulseWidth;

% Environment Constants
monitorWidth = 525;                                                         % in milimeters
monitorDistance = 600;                                                      % in milimeters

screenPtr = 1;

resolution      = Screen('Resolution', screenPtr);
screenWidth     = resolution.width;
screenHeight    = resolution.height;
pixelDepth      = resolution.pixelSize;
screenHz        = resolution.hz;
nScreenBuffers  = 2;

%% Connect To Controller Server
daqIp = '192.168.1.12';
Params.isCerePlexConnected  = false;
if connectToControllerServer
    if ~exist('Connection1', 'var')
        Connection1 = udp(daqIp, 'RemotePort', 3005, 'LocalPort', 3002);
        Connection1.Timeout=0.1;
        Connection1.BytesAvailableFcn = @CheckRecievedCommands;
        set(Connection1, 'InputBufferSize', 64);
        set(Connection1, 'OutputBufferSize', 64);
    else
        fclose(Connection2);
    end
    
    if ~exist('Connection2','var')
        Connection2 = udp(daqIp, 'RemotePort', 6025, 'LocalPort', 6022);
        Connection2.Timeout=0.1;
        Connection2.BytesAvailableFcn = @CheckRecievedCommands;
        set(Connection2, 'InputBufferSize', 64);
        set(Connection2, 'OutputBufferSize', 64);
    else
        fclose(Connection2);
    end
    
    if strcmp(Connection2.Status, 'closed')
        fopen(Connection2);
    end
    
    if strcmp(Connection1.Status, 'closed')
        fopen(Connection1);
    end
    
    while ~Params.isCerePlexConnected
        disp("Cannot connect to Data-Acquisition System")
        WaitSecs(1);
    end
    
    clc
    disp('Connected to Controller Server!')
    
    %     fprintf(Connection1, num2str(monitorDistance));
    %     fprintf(Connection1, num2str(monitorWidth));
    %     fprintf(Connection1, num2str(screenWidth));
    %     fprintf(Connection1, num2str(screenHeight));
else
    Params.isStarted = true;
end

%% Connect to Reward Pump
if connectToRewardPump
    shReward = daq.createSession('ni');
    [chReward, idxReward] = addDigitalChannel(shReward, ...
        'Dev1', 'Port1/Line0', 'OutputOnly');
end

if sendTriggers
    shTag = daq.createSession('ni');
    [chTag, idxTag] = addDigitalChannel(shTag, ...
        'Dev1', 'Port0/Line0:7', 'OutputOnly');
end

%% Create io64 Object
ioObj = io64;
status = io64(ioObj);
ioAddress = hex2dec('0378');

%% Psychtoolbox Initialization
[winPtr, winRect] = PsychImaging(...
    'OpenWindow', ...
    screenPtr, ...
    WhiteIndex(screenPtr) / 2, ...
    floor([0, 0, screenWidth, screenHeight] / 1), ...
    pixelDepth, ...
    nScreenBuffers, ...
    [], ...
    [], ...
    kPsychNeed32BPCFloat...
    );

% stmSize = 5;                                                                % in visual angles

fixSize = ang2pix(Params.fixationRadius, monitorDistance, monitorWidth / screenWidth);    % in pixels

[cX, cY] = WindowCenter(winPtr);
[normBoundsRect, ~, textHeight, xAdvance] = Screen('TextBounds', ...
    winPtr, ...
    'Paused', ...
    cX, ...
    cY);

clear resolution nScreenBuffers pixelDepth ans\
%% Loading the Conditions
stimDir = 'stimulus';
stimNames = ls(fullfile(pwd, stimDir, '*.tif'));

stimTextures = containers.Map;
for stim = 1:size(stimNames, 1)
    stimImg = imread(fullfile(pwd, stimDir, stimNames(stim, :)));
    stimTextures(stimNames(stim, :)) = Screen('MakeTexture', ...
        winPtr, ...
        stimImg);
end

clear stimImg stim stimDir

%%
nRep     = 1;
nStimuli = length(stimTextures);
assert(nStimuli < 200);

%% Creating the Condition Map
stimNames = string(stimNames);
clear trials
for iStimuli = 1:nStimuli
    trials(iStimuli).name = stimNames(iStimuli); %#ok<SAGROW>
    trials(iStimuli).onset = NaN; %#ok<SAGROW>
    trials(iStimuli).index = iStimuli; %#ok<SAGROW>
    trials(iStimuli).stmSize = NaN;
end
trials = repmat(trials, 1, nRep);
trials = trials(randperm(length(trials)));

nTrial = length(trials);

%% Eye Tracker Initialization
eye_calibration(connectToEyeTracker, winRect, winPtr, subjectName);

%% Task Body
IDLE        = 0;
FIXATING    = 1;
PRESENTING  = 2;
RESTING     = 3;
PUNISHING   = 4;
FINISHING   = 5;
PAUSING     = 6;

GRANTING    = 20;
USURPING    = 21;

% fixPoint = [winRect(3) / 2, winRect(4) / 2];
gazeLoc  = [winRect(3) / 2, winRect(4) / 2];

fixTimer = tic;
stmTimer = tic;
punTimer = tic;
rstTimer = tic;
daqTimer = tic;
rewTimer = tic;
pmpTimer = tic;

fixCross = [cX - 2, cY - 10, cX + 2, cY + 10; ...
    cX - 10, cY - 2, cX + 10, cY + 2];
fixCrossColor = WhiteIndex(screenPtr) / 2 - 0.4;

if connectToControllerServer
    taskState = PAUSING;
else
    taskState = IDLE;
end
isFixated = false;
isChanged = true;
isPumpStateChanged = false;

nReward = 0;
try
    SimpleGazeTracker('StartRecording', 'Start Session', 0.1);
    
    sendtrig(sendTriggers, connectToEyeTracker, shTag, SESSION_START)
    onsetTimer = tic;
    
    pumpState = USURPING;
    iBlock = 1;
    iTrial = 1;
    while taskState ~= FINISHING && ~Params.isStopped
        stmSize = ang2pix(Params.stimulusSize, monitorDistance, monitorWidth / screenWidth);
        stmRect = CenterRect([0, 0, stmSize, stmSize], winRect);
        
        if connectToEyeTracker
            pos = SimpleGazeTracker('GetEyePosition', 1, 0.01);
            x = pos{1}(1);
            y = pos{1}(2);
            [~, ~, buttons, ~, ~, ~] = GetMouse(winPtr);
        else
            [x, y, buttons, ~, ~, ~] = GetMouse(winPtr);
        end
        
        if buttons(2)
            sca
        end
        
        gazeLoc  = [x, y];
        gazeLoc  = gazeLoc - floor([screenWidth, screenHeight] / 2) - ...
            [Params.xOffset, Params.yOffset];
        
        % Check for Eye Fixation
        if norm(gazeLoc) < fixSize
            if ~isFixated
                isFixated = true;
                fixTimer = tic;
                rewTimer = tic;
                sendtrig(sendTriggers, connectToEyeTracker, shTag, FIX_START)
            end
        else
            isFixated = false;
        end
        
        if(toc(daqTimer) > 0.1)
            daqTimer = tic;
            fprintf(Connection1, num2str(gazeLoc));
        end
        
        % Check durations for automatic reward
        if isFixated && toc(rewTimer) > Params.rewardInterval && (taskState ~= PAUSING)
            rewTimer = tic;
            Params.manualReward = true;                                     % This a not the ideal notion to grant reward
        end                                                                 % but to avoid more variable e.g. isAutoReward I used the manualReward flag.
        if Params.fillPipe
            while Params.fillPipe
                outputSingleScan(shReward, 1);
            end
            outputSingleScan(shReward, 0);
        end
        % Update Pump States
        if Params.manualReward
            Params.manualReward = false;
            pumpState = GRANTING;
            pmpTimer  = tic;
            isPumpStateChanged = true;
        end
        if toc(pmpTimer) > Params.rewardDuration && pumpState == GRANTING
            pumpState = USURPING;
            isPumpStateChanged = true;
        end
        
        % Update Task State and Trial List [if Necessary]
        switch taskState
            case IDLE
                if Params.isPaused
                    isChanged = true;
                    taskState = PAUSING;
                elseif ~Params.isPaused && isFixated && Params.isStarted
                    isChanged = true;
                    taskState = FIXATING;
                else
                    taskState = IDLE;
                end
                
            case FIXATING
                if Params.isPaused
                    isChanged = true;
                    taskState = PAUSING;
                elseif ~Params.isPaused && ~isFixated
                    isChanged = true;
                    punTimer  = tic;
                    taskState = PUNISHING;
                elseif ~Params.isPaused && isFixated && ...
                        toc(fixTimer) >= duration.fixation
                    isChanged = true;
                    stmTimer  = tic;
                    taskState = PRESENTING;
                else
                    taskState = FIXATING;
                end
                
            case PRESENTING
                if Params.isPaused
                    isChanged = true;
                    taskState = PAUSING;
                elseif ~Params.isPaused && ~isFixated
                    isChanged = true;
                    punTimer  = tic;
                    
                    trials(iTrial).onset = NaN;
                    trials = [trials, trials(iTrial)]; %#ok<AGROW>
                    trials(iTrial) = [];
                    
                    taskState = PUNISHING;
                elseif ~Params.isPaused && isFixated && ...
                        toc(stmTimer) >= duration.presentation
                    isChanged = true;
                    rstTimer  = tic;
                    taskState = RESTING;
                else
                    taskState = PRESENTING;
                end
                
            case RESTING
                if Params.isPaused
                    isChanged = true;
                    taskState = PAUSING;
                elseif ~Params.isPaused && (iTrial <= nTrial) && ~isFixated
                    isChanged = true;
                    punTimer = tic;
                    
                    trials(iTrial).onset = NaN;
                    trials(iTrial).stmSize = NaN;
                    trials = [trials, trials(iTrial)]; %#ok<AGROW>
                    trials(iTrial) = [];
                    
                    taskState = PUNISHING;
                elseif ~Params.isPaused && (iTrial <= nTrial) && ...
                        isFixated && toc(rstTimer) >= duration.rest
                    isChanged = true;
                    stmTimer  = tic;
                    iTrial = iTrial + 1;
                    fprintf(Connection2, num2str([iBlock, iTrial, nReward]));
                    
                    sendtrig(sendTriggers, connectToEyeTracker, shTag, TRL_SUCCESS)
                    
                    if (iTrial > nTrial)
                        taskState = FINISHING;
                    else
                        taskState = PRESENTING;
                    end
                end
                
            case PUNISHING
                if Params.isPaused
                    isChanged = true;
                    taskState = PAUSING;
                elseif ~Params.isPaused && toc(punTimer) >= duration.punish
                    isChanged = true;
                    taskState = IDLE;
                end
                
            case PAUSING
                if Params.isStarted
                    isChanged = true;
                    taskState = IDLE;
                else
                    taskState = PAUSING;
                end
                
            otherwise
                error('Unexpected task state!')
        end
        
        % Handle Task's Graphical Window
        if isChanged
            switch taskState
                case IDLE
                    Screen('FillRect', winPtr, fixCrossColor, fixCross');
                    Screen('Flip', winPtr);
                case FIXATING
                    Screen('FillRect', winPtr, fixCrossColor, fixCross');
                    Screen('Flip', winPtr);
                case PRESENTING
                    trials(iTrial).stmSize = Params.stimulusSize;
                    trials(iTrial).onset = toc(onsetTimer);
                    Screen('DrawTexture', ...
                        winPtr, ...
                        stimTextures(char(trials(iTrial).name)), ...
                        [], ...
                        stmRect);
                    Screen('Flip', winPtr);
                    sendtrig(sendTriggers, connectToEyeTracker, shTag, trials(iTrial).index)
                case RESTING
                    Screen('FillRect', winPtr, fixCrossColor, fixCross');
                    Screen('Flip', winPtr);
                    sendtrig(sendTriggers, connectToEyeTracker, shTag, STM_OFFSET)
                case PUNISHING
                    sendtrig(sendTriggers, connectToEyeTracker, shTag, FIX_BREAK)
                    sendtrig(sendTriggers, connectToEyeTracker, shTag, TRL_FAILURE)
                    Screen('Flip', winPtr);
                case PAUSING
                    Screen('FrameRect', ...
                        winPtr, ...
                        fixCrossColor, ...
                        CenterRect(1.5 * normBoundsRect, winRect), ...
                        2);
                    Screen('DrawText', ...
                        winPtr, ...
                        'Paused', ...
                        cX - floor(xAdvance / 2), ...
                        cY + floor(normBoundsRect(4) / 2), ...
                        fixCrossColor, ...
                        WhiteIndex(winPtr) / 2);
                    Screen('Flip', winPtr);
            end
            isChanged = false;
        end
                
        if isPumpStateChanged
            isPumpStateChanged = false;
            switch pumpState
                case GRANTING
                    nReward = nReward + 1;
                    outputSingleScan(shReward, 1)
                case USURPING
                    outputSingleScan(shReward, 0)
            end
        end
        
    end
catch ME
    disp(ME.message)
end

%%
save(fullfile(sessionDir,'\', strcat(sessionDateTime, '_TaskData.mat')), 'trials')

Screen('CloseAll');

if connectToControllerServer
    fclose(Connection1);
    fclose(Connection2);
    
    delete(Connection1);
    delete(Connection2);
    
    clear Connection1 Connection2
end

if connectToEyeTracker
    msg = SimpleGazeTracker('GetWholeEyePositionList', 1, 1);
    save(fullfile(sessionDir,'\', strcat(sessionDateTime, '_EyePositionList.mat')), 'msg')

    msg = SimpleGazeTracker('GetWholeMessageList', 3.0);
    save(fullfile(sessionDir,'\', strcat(sessionDateTime, '_EyeMessageList.mat')), 'msg')

    SimpleGazeTracker('StopRecording','',0.1);
    SimpleGazeTracker('CloseDataFile');
    SimpleGazeTracker('CloseConnection');
end