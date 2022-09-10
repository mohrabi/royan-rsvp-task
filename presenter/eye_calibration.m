function eye_calibration(eyetracker, windowRect, window, subjectName)
    eyetrack.ipAddress             = '127.0.0.1';
    eyetrack.setting               = {
    {'RECORDED_EYE', 'L'},...
    {'SCREEN_ORIGIN', 'Center'},...
    {'TRACKER_ORIGIN', 'Center'},...
    {'SCREEN_WIDTH', 1920},...
    {'SCREEN_HEIGHT', 1080},...
    {'VIEWING_DISTANCE', 57.3},...
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
    if eyetracker
        cx = windowRect(3)/2;
        cy = windowRect(4)/2;
        
        param = SimpleGazeTracker('Initialize', window, windowRect);
        
        param.sendPort = 10000;
        param.recvPort = 10001;
        
        param.IPAddress = eyetrack.ipAddress;
        param.imageWidth = cx;
        param.imageHeight = cy;
        param.calArea = windowRect;
        param.calTargetPos = [0    , 0    ;
            -400 , -300 ;
            0    , -300 ;
            400  , -300 ;
            -400 , 0    ;
            0    , 0    ;
            400  , 0    ;
            -400 , 300  ;
            0    , 300  ;
            400  , 300
            ];
        for i=1:length(param.calTargetPos)
            param.calTargetPos(i,:) = param.calTargetPos(i,:)+[cx,cy];
        end
        result = SimpleGazeTracker('UpdateParameters',param);
        if result{1} < 0 %failed
            disp('Could not update parameter. Abort.');
            Screen('CloseAll');
            return;
        end
        
        % Connect to SimpleGazeTracker and open data file
        res = SimpleGazeTracker('Connect');
        if res==-1 %connection failed
            Screen('CloseAll');
            return;
        end
        SimpleGazeTracker('OpenDataFile', ['eye_data_', subjectName, '.csv'], 0); %datafile is not overwritten.
%         SimpleGazeTracker('OpenDataFile','data.csv',0); %datafile is not overwritten.
        % Update camera image buffer (NEW in 0.4.0)
        imgsize = SimpleGazeTracker('GetCameraImageSize');
        param.imageWidth = imgsize(1);
        param.imageHeight = imgsize(2);
        result = SimpleGazeTracker('UpdateParameters',param);
        if result{1} < 0 %failed
            disp('Could not update parameter. Abort.');
            Screen('CloseAll');
            return;
        end
        
        % Send settings (NEW in 0.4.0)
        res = SimpleGazeTracker('SendSettings', eyetrack.setting);
        
        % Perform calibration.
        while 1
            res = SimpleGazeTracker('CalibrationLoop');
            if res{1}=='q'
                %Quit if calibrationloop is finished by 'q' key.
                SimpleGazeTracker('CloseConnection');
                Screen('CloseAll');
                return;
            end
            if strcmp(res{1}, 'ESCAPE') && res{2}==1
                %Leave from loop if calibration has been performed (res{2}==1).
                break;
            end
        end
    end
end

