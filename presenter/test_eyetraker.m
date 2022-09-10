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
connectToEyeTracker         = true;
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
%% Isaw Connection Initialization
%     if useIsaw
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