function CheckRecievedCommands(Connection, ~)

global Params
global ServerCommand

ServerCommand = fscanf(Connection,'%s');
% disp(ServerCommand)
if length(ServerCommand) >= 2
    if strcmp(ServerCommand, 'ManualReward')
        Params.manualReward = true;
    elseif strcmp(ServerCommand(1:2), 'XO')
        Params.xOffset = str2double(ServerCommand(3:end));
    elseif strcmp(ServerCommand(1:2), 'YO')
        Params.yOffset = str2double(ServerCommand(3:end));
    elseif strcmp(ServerCommand(1:2), 'FR')
        Params.fixationRadius = str2double(ServerCommand(3:end));
        Params.fixationArea = Params.fixationRadius * 22.5;
    elseif strcmp(ServerCommand(1:2), 'RI')
        Params.rewardInterval = str2double(ServerCommand(3:end));
    elseif strcmp(ServerCommand(1:2), 'RD')
        Params.rewardDuration = str2double(ServerCommand(3:end));
    elseif strcmp(ServerCommand(1:2), 'AD')
        Params.acceptDuration = str2double(ServerCommand(3:end));
    elseif strcmp(ServerCommand(1:2), 'WA')
        Params.waitPunish = str2double(ServerCommand(3:end));
    elseif strcmp(ServerCommand(1:2), 'SS')
        Params.stimulusSize = str2double(ServerCommand(3:end));
    elseif strcmp(ServerCommand, 'CerePlex')
        fprintf(Connection, '999999 999999');
        Params.isCerePlexConnected = 1;
    elseif strcmp(ServerCommand, 'Start')
        Params.isStarted = true;
        Params.isPaused  = false;
    elseif strcmp(ServerCommand, 'Pause')
        Params.isPaused  = true;
        Params.isStarted = false;
    elseif strcmp(ServerCommand, 'Stop')
        Params.isStopped = true;
    end
else
    %     NewCommand = '';
end

end