%% Refreshing the Workspace
close all
clear hidden
clc

addpath('Task Functions')
%% Specify Directory for Writing Data
recordingDir = 'Recording';

mi = input('Please Enter the Monkey Name: ', 's');

if ~isfolder(fullfile(recordingDir, mi))
    mkdir(fullfile(recordingDir, mi))
end

sessionDateTime = datestr(datetime('now'), 'yyyymmdd-HHMM');
sessionDir = fullfile(recordingDir, mi, sessionDateTime);
mkdir(sessionDir)
%% Create File Descriptors for Data Recordings
eyeDataFileName = fullfile(sessionDir, ...
    strcat(sessionDateTime, '-eye', '.txt'));
resultsFileName = fullfile(sessionDir, ...
    strcat(sessionDateTime, '-res', '.txt'));

global eyeFd
eyeFd = fopen(eyeDataFileName, 'a');
resFd = fopen(resultsFileName, 'a');

fprintf(eyeFd, 'Time,X,Y,Pupil\n');
fprintf(resFd, '#,#Block,Stimulus,#Failure,Time Tags\n');
%% Declare Golabal Variables
% ---- Do Not Change ------------------------------------------------------
global Params gazeLoc
Params.isStarted            = false;
Params.isPaused             = false;
Params.isStopped            = false;
Params.manualReward         = false;
Params.fillPipe             = false;
Params.isCerePlexConnected  = false;
Params.xOffset              = 0;
Params.yOffset              = 0;
Params.fixationRadius       = 0;
Params.rewardInterval       = 0;
Params.rewardDuration       = 0;
Params.acceptDuration       = 0;
Params.waitPunish           = 0;
% -------------------------------------------------------------------------
%% Task Parameters and Constants
% ---- Do Not Change ------------------------------------------------------
PsychDefaultSetup(1);
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'TextRenderer', 1);
Screen('Preference', 'TextAntiAliasing', 1);
Screen('Preference', 'TextAlphaBlending', 0);
Screen('Preference', 'DefaultTextYPositionIsBaseline', 1);
% -------------------------------------------------------------------------

% Connections
useServer   = true;
useIsaw     = true;
% useRwd      = true;
% assert(useRwd == true)

% Paradigm Constants
duration.presentation = .3;
duration.fixation = 0.5;
duration.rest = 0.7;
duration.punish = 1.;

nBlock = 10;
nTrial = 9;

% Environment Constants
monitorWidth = 525;                                                         % in milimeters
monitorDistance = 500;                                                      % in milimeters

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
if useServer
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
%% Isaw Connection Initialization
if useIsaw
    addpath('sgttoolbox')
    
    % ---- Configuration --------------------------------------------------
    ipAddress = '127.0.0.1';
    
    % ---- Do Not Change --------------------------------------------------
    settings = {
        {'RECORDED_EYE', 'L'},...
        {'SCREEN_ORIGIN', 'Center'},...
        {'TRACKER_ORIGIN', 'Center'},...
        {'SCREEN_WIDTH', 1920},...
        {'SCREEN_HEIGHT', 1080},...
        {'VIEWING_DISTANCE', 50.0},...
        {'DOTS_PER_CENTIMETER_H', 36},...
        {'DOTS_PER_CENTIMETER_V', 36},...
        {'SACCADE_VELOCITY_THRESHOLD', 20.0},...
        {'SACCADE_ACCELERATION_THRESHOLD', 3800.0},...
        {'SACCADE_MINIMUM_DURATION', 12},...
        {'SACCADE_MINIMUM_AMPLITUDE', 0.2},...
        {'FIXATION_MINIMUM_DURATION', 12},...
        {'BLINK_MINIMUM_DURATION', 50},...
        {'RESAMPLING', 0},...
        {'FILTER_TYPE', 'identity'},...
        {'FILTER_WN', 0.2},...
        {'FILTER_SIZE', 5},...
        {'FILTER_ORDER', 3}
        };
    
    try
        [winPtr, winRect] = Screen('OpenWindow',screenPtr );
        cX = winRect(3)/2;
        cY = winRect(4)/2;
        
        param = SimpleGazeTracker('Initialize',winPtr,winRect);
        
        param.IPAddress = ipAddress;
        param.calArea = winRect;
        param.calTargetPos = [
            0       ,   0;
            -200    ,-200;
            0       ,-200;
            200     ,-200;
            -200    ,   0;
            0       ,   0;
            200     ,   0;
            -200    , 200;
            0       , 200;
            200     , 200
            ];
        for i=1:length(param.calTargetPos)
            param.calTargetPos(i,:) = param.calTargetPos(i,:)+[cX,cY];
        end
        result = SimpleGazeTracker('UpdateParameters',param);
        if result{1} < 0 %failed
            disp('Could not update parameter. Abort.');
            Screen('CloseAll');
            return;
        end
        
        res = SimpleGazeTracker('Connect');
        if res==-1 %connection failed
            Screen('CloseAll');
            return;
        end
        
        SimpleGazeTracker('OpenDataFile','data.csv',0); %datafile is not overwritten.
        
        imgsize = SimpleGazeTracker('GetCameraImageSize');
        param.imageWidth = imgsize(1);
        param.imageHeight = imgsize(2);
        result = SimpleGazeTracker('UpdateParameters',param);
        if result{1} < 0 %failed
            disp('Could not update parameter. Abort.');
            Screen('CloseAll');
            return;
        end
        
        res = SimpleGazeTracker('SendSettings', settings);
        
                while 1
                    res = SimpleGazeTracker('CalibrationLoop');
                    if res{1}=='q'
                        %Quit if calibrationloop is finished by 'q' key.
                        SimpleGazeTracker('CloseConnection');
                        Screen('CloseAll');
                        return;
                    end
                    if strcmp(res{1},'ESCAPE') && res{2}==1
                        %Leave from loop if calibration has been performed (res{2}==1).
                        break;
                    end
                end
    catch ME
        SimpleGazeTracker('CloseConnection');
        Screen('CloseAll');
        psychrethrow(psychlasterror);
    end
end
%% Connect to Reward Pump
% sessionHandler = daq.createSession('ni');
shTag = daq.createSession('ni');
[chTag, idxTag] = addDigitalChannel(shTag, ...
    'Dev1', 'Port0/Line0:7', 'OutputOnly');
shReward = daq.createSession('ni');
[chReward, idxReward] = addDigitalChannel(shReward, ...
    'Dev1', 'Port1/Line0', 'OutputOnly');
%% Psychtoolbox Initialization

stmSize = 8;                                                                % in visual angles
stmSize = ang2pix(stmSize, monitorDistance, monitorWidth / screenWidth);    % in pixels

fixSize = 1;

[cX, cY] = WindowCenter(winPtr);
[normBoundsRect, ~, textHeight, xAdvance] = Screen('TextBounds', ...
    winPtr, ...
    'Paused', ...
    cX, ...
    cY);

clear resolution nScreenBuffers pixelDepth ans
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
%% Creating the Condition Map
trials = cell(nBlock, 1);
for iBlock = 1:nBlock
    stimOrder = randperm(nTrial);
    trials{iBlock} = dlnode(stimNames(stimOrder(1), :), 1);
    for iStim = 2:nTrial
        nNode = dlnode(stimNames(stimOrder(iStim), :), iStim);
        nNode.insertLast(trials{iBlock})
    end
end
clear iBlock nNode iStim stimOrder
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

global gazTimer;

gazTimer = tic;
fixTimer = tic;
stmTimer = tic;
punTimer = tic;
rstTimer = tic;
daqTimer = tic;                                                             % Timer for transfering eye data to daq system
pmpTimer = tic;                                                             % Timer for reward duration
rewTimer = tic;                                                             % Timer for automatic rewards

% global isGazeDataFresh
gazeLoc  = [0, 0];

stmRect = CenterRect([0, 0, stmSize, stmSize], winRect);

fixCross = [cX - 2, cY - 10, cX + 2, cY + 10; ...
    cX - 10, cY - 2, cX + 10, cY + 2];
fixCrossColor = [50 50 50]; %WhiteIndex(winPtr) / 2 - 0.05;

tag = zeros(1, 8);

SimpleGazeTracker('StartRecording','Test trial',0.1);

Screen('FillRect', winPtr, [128 128 128]);
Screen('Flip', winPtr);

ntrial=0;

for iBlock = 1:nBlock
    if useServer
        taskState = PAUSING;
    else
        taskState = IDLE;
    end
    pumpState = USURPING;
    
    isFixated = false;
    isTaskStateChanged = true;
    isPumpStateChanged = false;
    
    currentNode = trials{iBlock};
    
    while taskState ~= FINISHING && ~Params.isStopped
        %         [x, y, buttons, ~, ~, ~] = GetMouse(winPtr);
        %gazeLoc = [x, y];
        % Debugger: Jumps out of task if wheel key is pressed
        %         if buttons(2)
        %             sca
        %         end
        
        pos = SimpleGazeTracker('GetEyePosition', 1, 0.015);
        gazeLoc = pos{1};
        
        
        if (gazeLoc(1) <= -9000)
            isFixated = false;
        end
        gazeLoc = gazeLoc - floor([screenWidth, screenHeight] / 2) + ...
            [Params.xOffset, Params.yOffset];
        %     gazeLoc = [0, 0];
        %disp([gazeLoc, toc(fixTimer)])
        
        if(toc(daqTimer) > 0.1)
            daqTimer = tic;
            fprintf(Connection1, num2str(gazeLoc));
        end
        
        % Check for Eye Fixation
        fixSize = ang2pix(Params.fixationRadius, ...
            monitorDistance, monitorWidth / screenWidth);                   % in pixels
        if norm(gazeLoc) < fixSize
            if ~isFixated
                isFixated = true;
                fixTimer = tic;
            end
        else
            isFixated = false;
        end
        
        if ~isFixated
            rewTimer = tic;
            fixTimer = tic;
            % disp('Fixation Break')
        end
        
        % Check durations for automatic reward
        if isFixated && toc(rewTimer) > Params.rewardInterval
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
                    isTaskStateChanged = true;
                    taskState = PAUSING;
                elseif ~Params.isPaused && isFixated && Params.isStarted
                    isTaskStateChanged = true;
                    taskState = FIXATING;
                else
                    taskState = IDLE;
                end
                
            case FIXATING
                if Params.isPaused
                    isTaskStateChanged = true;
                    taskState = PAUSING;
                elseif ~Params.isPaused && ~isFixated
                    isTaskStateChanged = true;
                    punTimer  = tic;
                    taskState = PUNISHING;
                elseif ~Params.isPaused && isFixated && ...
                        toc(fixTimer) >= duration.fixation
                    isTaskStateChanged = true;
                    stmTimer  = tic;
                    tag = flip(decimalToBinaryVector(currentNode.index, 8));
                    outputSingleScan(shTag, tag)
                    taskState = PRESENTING;
                else
                    taskState = FIXATING;
                end
                
            case PRESENTING
                if Params.isPaused
                    isTaskStateChanged = true;
                    taskState = PAUSING;
                elseif ~Params.isPaused && ~isFixated
                    isTaskStateChanged = true;
                    punTimer  = tic;
                    
                    currentNode.nFailures = currentNode.nFailures + 1;
                    if ~isempty(currentNode.Next)
                        nextNode = currentNode.Next;
                        
                        if isempty(currentNode.Prev)
                            trials{iBlock} = currentNode.Next;
                        end
                        
                        currentNode.insertLast(nextNode);
                        currentNode = nextNode;
                    end
                    
                    taskState = PUNISHING;
                elseif ~Params.isPaused && isFixated && ...
                        toc(stmTimer) >= duration.presentation
                    isTaskStateChanged = true;
                    rstTimer  = tic;
                    currentNode = currentNode.Next;
                    taskState = RESTING;
                else
                    taskState = PRESENTING;
                end
                
            case RESTING
                if Params.isPaused
                    isTaskStateChanged = true;
                    taskState = PAUSING;
                elseif ~Params.isPaused && isempty(currentNode)
                    taskState = FINISHING;
                elseif ~Params.isPaused && ~isempty(currentNode) && ...
                        ~isFixated
                    isTaskStateChanged = true;
                    punTimer = tic;
                    taskState = PUNISHING;
                elseif ~Params.isPaused && ~isempty(currentNode) && ...
                        isFixated && toc(rstTimer) >= duration.rest
                    isTaskStateChanged = true;
                    stmTimer  = tic;
                    tag = flip(decimalToBinaryVector(currentNode.index, 8));
                    outputSingleScan(shTag, tag)
                    taskState = PRESENTING;
                end
                
            case PUNISHING
                if Params.isPaused
                    isTaskStateChanged = true;
                    taskState = PAUSING;
                elseif ~Params.isPaused && toc(punTimer) >= duration.punish
                    isTaskStateChanged = true;
                    taskState = IDLE;
                end
                
            case PAUSING
                if Params.isStarted
                    isTaskStateChanged = true;
                    taskState = IDLE;
                else
                    taskState = PAUSING;
                end
                
            otherwise
                error('Unexpected task state!')
        end
        
        % Handle Task's Graphical Window
        if isTaskStateChanged
            switch taskState
                case IDLE
                    Screen('FillRect', winPtr, fixCrossColor, fixCross');
                    Screen('Flip', winPtr);
                case FIXATING
                    Screen('FillRect', winPtr, fixCrossColor, fixCross');
                    Screen('Flip', winPtr);
                case PRESENTING
                    Screen('DrawTexture', ...
                        winPtr, ...
                        stimTextures(currentNode.condition), ...
                        [], ...
                        stmRect);
                    Screen('Flip', winPtr);
                    ntrial = ntrial+1;
                    disp ([iBlock ntrial]);
                case RESTING
                    Screen('FillRect', winPtr, fixCrossColor, fixCross');
                    Screen('Flip', winPtr);
                case PUNISHING
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
            isTaskStateChanged = false;
        end
        
        %         if useRwd
        if isPumpStateChanged
            isPumpStateChanged = false;
            switch pumpState
                case GRANTING
                    outputSingleScan(shReward, 1)
                case USURPING
                    outputSingleScan(shReward, 0)
            end
        end
        %         end
    end
    
    if Params.isStopped
        break
    end
end
SimpleGazeTracker('StopRecording','',0.1)
outputSingleScan(shReward, 0)

%%
% currentNode = trials{1};
% n = 0;
% while ~isempty(currentNode)
%     n = n+1;
%     disp(currentNode.nFailures)
%     currentNode = currentNode.Next;
% end
%%
Screen('CloseAll');

for iBlock = 1:nBlock
    currentNode = trials{iBlock};
    n = 0;
    while ~isempty(currentNode)
        n = n+1;
        fprintf(resFd, '%d,%d,%s,%d\n', n, iBlock, ...
            currentNode.condition, currentNode.nFailures);
        currentNode = currentNode.Next;
    end
end


if useServer
    fclose(Connection1);
    fclose(Connection2);
    
    delete(Connection1);
    delete(Connection2);
    
    clear Connection1 Connection2
end

if useIsaw
    SimpleGazeTracker('CloseDataFile');
    SimpleGazeTracker('CloseConnection');
end

