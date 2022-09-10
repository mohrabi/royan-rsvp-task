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
connectToControllerServer   = false;
connectToEyeTracker         = false;
connectToRewardPump         = false;
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
% ioObj = io64;
% status = io64(ioObj);
% ioAddress = hex2dec('0378');

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

fixSize = ang2pix(5, monitorDistance, monitorWidth / screenWidth);    % in pixels

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


isFixated = false;
isChanged = true;
isPumpStateChanged = false;

       stmSize = ang2pix(10, monitorDistance, monitorWidth / screenWidth);
        stmRect = CenterRect([0, 0, stmSize, stmSize], winRect);
        
            
        
                    
                    
  for    iTrial = 1: nTrial         
        
                    
                    trials(iTrial).stmSize = stmSize;
                    Screen('DrawTexture', ...
                        winPtr, ...
                        stimTextures(char(trials(iTrial).name)), ...
                        [], ...
                        stmRect);
                    Screen('Flip', winPtr);
                    WaitSecs(duration.fixation);
                    
%                     sendtrig(sendTriggers, ioAddress, shTag, trials(iTrial).index)
                    Screen('FillRect', winPtr, fixCrossColor, fixCross');
                    Screen('Flip', winPtr);
%                     sendtrig(sendTriggers, ioAddress, shTag, STM_OFFSET)
                                        WaitSecs(duration.fixation);
  
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