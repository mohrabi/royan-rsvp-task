 
%% init
close all hidden;
fclose ('all');
if exist('Connection1','var')
    delete(Connection1);
end
if exist('Connection2','var')
    delete(Connection2);
end

clear classes;
clc;
warning off all;
%% parameters
global Eye;
Presenter = 999999;
Eye = [5000,5000,0,0];
OldEye = [5000,5000];  
Start = 1;
pixelPerDegree = 38; % calculated based on presenter monitor. for this one it would be 37
Color='k';
Command=[];
RewardOver =1;
Mess_Pres = '';

 global TrialCounts
TrialCounts=[0,0];
oldTC=[0,0];

%% read last saved data
fid=fopen('LastSavedData.txt','r');
if fid>0
    Out.XOffset=str2double(fgetl(fid));
    Out.YOffset=str2double(fgetl(fid));
%     Out.TrialCount=str2double(fgetl(fid));
    Out.FixationRadius=str2double(fgetl(fid));
    Out.RewardInterval=str2double(fgetl(fid));
    Out.RewardDuration=str2double(fgetl(fid));
    Out.AcceptDuration=str2double(fgetl(fid));
    Out.WaitAfter=str2double(fgetl(fid));
    Out.StimulusSize=str2double(fgetl(fid));
    fclose(fid);
end

if RewardOver == 1
    RewardDuration = 0.13;
end
%% Graph Initialize 
Out.SuccesiveReward = [];
Out.MeanSuccesiveReward = [];
Out.RewardNum = 0;
Out.CurrentBlock = 0;
Out.PassedTrials = 0;
Out.MessageCnt = 0;
% FixationArea = (Out.FixationRadius * pixelPerDegree)-20; % -20 is for match eye plot to presenter computer only 
FixationArea = (Out.FixationRadius * pixelPerDegree);
Out.Stim = 0;
Out.StringOut{10} = '';
%% Run the GUI 
Handles=ProtocolController;
Handles_Param=guidata(Handles);
set(Handles_Param.text5,'String',num2str(Out.XOffset));
set(Handles_Param.text6,'String',num2str(Out.YOffset));
% set(Handles_Param.text7,'String',num2str(Out.TrialCount));
set(Handles_Param.text10,'String',num2str(Out.FixationRadius));
set(Handles_Param.edit2,'String',num2str(Out.RewardInterval));
set(Handles_Param.edit3,'String',num2str(Out.RewardDuration));
set(Handles_Param.edit4,'String',num2str(Out.AcceptDuration));
set(Handles_Param.edit5,'String',num2str(Out.WaitAfter));
set(Handles_Param.edit6,'String',num2str(Out.StimulusSize));
set(Handles_Param.axes1,'XTick',[])
set(Handles_Param.axes1,'YTick',[])
axis(Handles_Param.axes1,[-960 960 -540 540]);
i=0;
%% Connection to Presenter
pcIp = '192.168.0.1';
if ~exist('Connection1','var')
    Connection1=udp(pcIp, 'RemotePort', 3002, 'LocalPort', 3005);
    Connection1.Timeout=0.1;
    Connection1.BytesAvailableFcn=@RecievedCommandEye;
    set(Connection1, 'OutputBufferSize',64);
    set(Connection1, 'InputBufferSize',64);
end

if strcmp (Connection1.Status,'closed')
    fopen(Connection1);
end

if ~exist('Connection2','var')
    Connection2=udp(pcIp, 'RemotePort', 6022, 'LocalPort', 6025);
    Connection2.Timeout=0.1;
    Connection2.BytesAvailableFcn=@RecievedCommandTask;
    set(Connection2, 'OutputBufferSize',64);
    set(Connection2, 'InputBufferSize',64);
end

if strcmp (Connection2.Status,'closed')
    fopen(Connection2);
end

PresenterPresent=0;
AnalyzerPresent=0;
%% Empty Lan Buffers 
MessRecieved=get(Connection1,'BytesAvailable');
while MessRecieved~=0
    fread(Connection1);
    MessRecieved=get(Connection1,'BytesAvailable');
end

MessRecieved2=get(Connection2,'BytesAvailable');
while MessRecieved2~=0
    fread(Connection2);
    MessRecieved2=get(Connection2,'BytesAvailable');
end 
%% Check Lan Connection

while (PresenterPresent==0)
    fprintf(Connection1,'CerePlex');
    pause(1);
%     clc
    disp('Presenter Not Running!');
    
    if (Eye(1) == Presenter)
        Out.PresenterType='Passive';
        PresenterPresent=1;
        fprintf(Connection1,'%s\n',['FR' num2str(Out.FixationRadius)]);
        fprintf(Connection1,'%s\n',['XO' num2str(Out.XOffset)]);
        fprintf(Connection1,'%s\n',['YO' num2str(Out.YOffset)]);
        fprintf(Connection1,'%s\n',['RI' num2str(Out.RewardInterval)]);
        fprintf(Connection1,'%s\n',['RD' num2str(Out.RewardDuration)]);
        fprintf(Connection1,'%s\n',['AD' num2str(Out.AcceptDuration)]);
        fprintf(Connection1,'%s\n',['WA' num2str(Out.WaitAfter)]);
        fprintf(Connection1,'%s\n',['SS' num2str(Out.StimulusSize)]);
    end
end

Eye = [999998, 999998];



%% conected

disp ('Connected to Presenter!');



%% Data Acquisition

LastEventSample=clock; 
EventReady=0;
LastEyeX = 0 ;
LastEyeY = 0 ;

while(Start == 1)

    

    %% Display Events 
    if EventReady == 1
        EventReady = 0;
        for rv=1:length(ttlValueArray)
            if  RecievedEvent(rv) > 0
                if RecievedEvent(rv) > 36 &&  RecievedEvent(rv) < 73
                    Mess_Pres = 'Trial';
                elseif RecievedEvent(rv) == 255
                    Mess_Pres='Reward';
                elseif RecievedEvent(rv) == 250
                    Mess_Pres = 'Block';
                end
                Out=ViewMessage(Handles_Param,Mess_Pres,Out);
            end
            Mess_Pres = '';
        end
    end
% global Block_to_Type
% global Trial_to_Type
% 
% Block_to_Type
% Trial_to_Type

    %% Send commands to presenter 
    [Handles_Param]=guidata(Handles);
    if Handles_Param.NewCommand==1
        Handles_Param.NewCommand=0;
        if Handles_Param.FillPipe==1
            Handles_Param.FillPipe=0;
            Command='FillPipe';
            fprintf(Connection1,'%s\n',Command);
            Mess=Command; 
            [Out]=ViewMessage(Handles_Param,Mess,Out);

        elseif Handles_Param.ManualReward==1
            Handles_Param.ManualReward=0;
            Command='ManualReward';
            fprintf(Connection1,'%s\n',Command);
            Mess=Command; [Out]=ViewMessage(Handles_Param,Mess,Out);
            [Out]=ViewMessage(Handles_Param,['X: ',num2str(EyePositionX)],Out);
            [Out]=ViewMessage(Handles_Param,['Y: ',num2str(EyePositionY)],Out);
            

        elseif Handles_Param.DecreaseRadius==1
            Handles_Param.DecreaseRadius=0;
            if FixationArea > 29.5;
                FixationArea = FixationArea - (pixelPerDegree/2);
                Out.FixationRadius = Out.FixationRadius - 0.5;
                fprintf(Connection1,'%s\n',['FR' num2str(Out.FixationRadius)]);
                set(Handles_Param.text10,'String',num2str(Out.FixationRadius));
            end
        elseif Handles_Param.IncreaseRadius==1
            Handles_Param.IncreaseRadius=0;
            if FixationArea < 295;
                FixationArea = FixationArea + (pixelPerDegree/2);
                Out.FixationRadius = Out.FixationRadius + 0.5;
             
                fprintf(Connection1,'%s\n',['FR' num2str(Out.FixationRadius)]);
                set(Handles_Param.text10,'String',num2str(Out.FixationRadius));
            end

        elseif Handles_Param.RewardInterval==1
            Handles_Param.RewardInterval=0;
            Out.RewardInterval=str2double(get(Handles_Param.edit2,'string'));
            fprintf(Connection1,'%s\n',['RI' num2str(Out.RewardInterval)]);

        elseif Handles_Param.RewardDuration==1
            Handles_Param.RewardDuration=0;
            Out.RewardDuration=str2double(get(Handles_Param.edit3,'string'));
            fprintf(Connection1,'%s\n',['RD' num2str(Out.RewardDuration)]);
        
        elseif Handles_Param.StimulusSize==1
            Handles_Param.StimulusSize=0;
            Out.StimulusSize=str2double(get(Handles_Param.edit6,'string'));
            fprintf(Connection1,'%s\n',['SS' num2str(Out.StimulusSize)]);

        elseif Handles_Param.XOffsetLeft==1
            Handles_Param.XOffsetLeft=0;
            Out.XOffset=Out.XOffset-5;
            fprintf(Connection1,'%s\n',['XO' num2str(Out.XOffset)]);
            set(Handles_Param.text5,'String',num2str(Out.XOffset));

        elseif Handles_Param.XOffsetRight==1
            Handles_Param.XOffsetRight=0;
            Out.XOffset=Out.XOffset+5;
            fprintf(Connection1,'%s\n',['XO' num2str(Out.XOffset)]);
            set(Handles_Param.text5,'String',num2str(Out.XOffset));

        elseif Handles_Param.YOffsetUp==1
            Handles_Param.YOffsetUp=0;
            Out.YOffset=Out.YOffset-5;
            fprintf(Connection1,'%s\n',['YO' num2str(Out.YOffset)]);
            set(Handles_Param.text6,'String',num2str(Out.YOffset));

        elseif Handles_Param.YOffsetDown==1
            Handles_Param.YOffsetDown=0;
            Out.YOffset=Out.YOffset+5;
            fprintf(Connection1,'%s\n',['YO' num2str(Out.YOffset)]);
            set(Handles_Param.text6,'String',num2str(Out.YOffset));

        elseif Handles_Param.AcceptDuration==1
            Handles_Param.AcceptDuration=0;
            Out.AcceptDuration=str2double(get(Handles_Param.edit4,'string'));
            fprintf(Connection1,'%s\n',['AD' num2str(Out.AcceptDuration)]);

        elseif Handles_Param.WaitAfter==1
            Handles_Param.WaitAfter=0;
            Out.WaitAfter=str2double(get(Handles_Param.edit5,'string'));
            fprintf(Connection1,'%s\n',['WA' num2str(Out.WaitAfter)]);

        elseif Handles_Param.Reset==1
            Handles_Param.Reset=0;
            Out.XOffset=0;
            Out.YOffset=0;
            fprintf(Connection1,'%s\n',['XO' num2str(Out.XOffset)]);
            set(Handles_Param.text5,'String',num2str(Out.XOffset));
            fprintf(Connection1,'%s\n',['YO' num2str(Out.YOffset)]);
            set(Handles_Param.text6,'String',num2str(Out.YOffset));
 

        elseif Handles_Param.StopPres==1
            Handles_Param.StopPres=0;
            Command='Pause';
            fprintf(Connection1,'%s\n',Command)
            Mess=Command; [Out]=ViewMessage(Handles_Param,Mess,Out);

        elseif Handles_Param.StartPres==1
            Handles_Param.StartPres=0;
            Command='Start';
            ParadigmStarted=1;
            pause(0.1);
            fprintf(Connection1,'%s\n',Command);
            Mess=Command; [Out]=ViewMessage(Handles_Param,Mess,Out);

        elseif Handles_Param.EndProg==1
            Handles_Param.EndProg=0;
            Command='Stop';
            fprintf(Connection1,'%s\n',Command);
            Mess=Command; 
            [Out]=ViewMessage(Handles_Param,Mess,Out);
            pause(0.5);
            pause(0.5);
            break
        elseif Handles_Param.AxesReset == 1 
            Handles_Param.AxesReset = 0;
            disp( [ 'Last Refreshed Eye in Plot : X =' num2str(LastEyeX) ' Y =' num2str(LastEyeY) ] ) 
            EyePositionY = -Eye(2);
            EyePositionX = Eye(1);
            hold(Handles_Param.axes1,'off')
            plot(Handles_Param.axes1,[-FixationArea FixationArea],[FixationArea FixationArea],'k');
            hold(Handles_Param.axes1,'on')
            line([-FixationArea FixationArea],[-FixationArea -FixationArea],'Color','k');
            line([-FixationArea -FixationArea],[-FixationArea FixationArea],'Color','k');
            line([FixationArea FixationArea],[-FixationArea FixationArea],'Color','k');
            line(EyePositionX,EyePositionY,'Color',Color,'LineWidth',1,'Marker','x');
            set(Handles_Param.axes1,'XTickLabel','')
            set(Handles_Param.axes1,'YTickLabel','')     
            axis(Handles_Param.axes1,[-960 960 -540 540]);
        end
      
        guidata(Handles,Handles_Param);
    end
    
    

    if (Eye(1) == 888888)
        Command='Stop';
        Mess=Command; 
        [Out]=ViewMessage(Handles_Param,Mess,Out);
        Eye = [5000,5000,0,0];
        Out.CurrentBlock = 0;
        Out.PassedTrials = 0;
    end
    
    if length(TrialCounts)>=2 && (oldTC(1) ~= TrialCounts(1) || oldTC(2) ~= TrialCounts(2)) 
        Block=TrialCounts(1);
        Trial=TrialCounts(2);
        oldTC(1)=TrialCounts(1);
        oldTC(2)=TrialCounts(2);
        clc;
        disp(['Block ',num2str(Block),' : ','Trial ',num2str(Trial)]); 
    end

    %% plot eye position 
    
    if  length(Eye) >= 2 && (OldEye(1) ~= Eye(1) || OldEye(2) ~= Eye(2)) && ( ( Eye(1) < 800) && ( Eye(1) > -800 ) && ( Eye(2) <500 ) && ( Eye(2) > -500 ) ) 
        EyePositionY = -Eye(2);
        EyePositionX = Eye(1);
        hold(Handles_Param.axes1,'off')
        plot(EyePositionX, EyePositionY, 'Color', Color, 'LineWidth', 1, 'Marker', 'x');
        set(Handles_Param.axes1, 'Color', [.5, .5, .5])
        hold(Handles_Param.axes1,'on')
        plot(Out.XOffset + Out.FixationRadius * pixelPerDegree * cos(0:0.01*pi:2*pi), ...
            -Out.YOffset + Out.FixationRadius * pixelPerDegree * sin(0:0.01*pi:2*pi), ...
            'LineWidth', 1.25, ...
            'LineStyle', '--', ...
            'Color', 'red')
        stmSize = Out.StimulusSize * pixelPerDegree / 2;
        line(Handles_Param.axes1, [-stmSize  stmSize],[stmSize stmSize], 'Color', 'k');
        line(Handles_Param.axes1, [-stmSize stmSize],[-stmSize -stmSize],'Color','k');
        line(Handles_Param.axes1, [-stmSize -stmSize],[-stmSize stmSize],'Color','k');
        line(Handles_Param.axes1, [stmSize stmSize],[-stmSize stmSize],'Color','k');
        set(Handles_Param.axes1,'XTickLabel','')
        set(Handles_Param.axes1,'YTickLabel','')
        OldEye(1) = Eye(1);
        OldEye(2) = Eye(2);
        %Out.PassedTrials = Eye(3);
        %Out.CurrentBlock = Eye(4);
        LastEyeX = EyePositionX ;
        LastEyeY = EyePositionY ;
        
        axis(Handles_Param.axes1,[-960 960 -540 540]);
        

    end
    pause(0.02)
end

fid=fopen('LastSavedData.txt','w');
fprintf(fid,'%s \n',num2str(Out.XOffset));
fprintf(fid,'%s \n',num2str(Out.YOffset));
fprintf(fid,'%s \n',num2str(Out.FixationRadius));
fprintf(fid,'%s \n',num2str(Out.RewardInterval));
fprintf(fid,'%s \n',num2str(Out.RewardDuration));
fprintf(fid,'%s \n',num2str(Out.AcceptDuration));
fprintf(fid,'%s \n',num2str(Out.WaitAfter));
fprintf(fid,'%s \n',num2str(Out.StimulusSize));
fclose(fid);

close all hidden;
fclose(Connection1);
fclose ('all');
delete(Connection1);
clear Connection1;

fclose(Connection2);
delete(Connection2);
clear Connection2;
clc;