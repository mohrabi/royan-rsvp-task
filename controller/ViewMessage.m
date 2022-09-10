function [Out]=ViewMessage(handles_Stat,Mess,Out)
if strcmp(Mess,'Reward')
    Out.RewardNum=Out.RewardNum+1;
    set(handles_Stat.text7,'String',num2str(Out.RewardNum))
elseif strcmp(Mess,'Trial')
    Out.PassedTrials=Out.PassedTrials+1;
    set(handles_Stat.text13,'String',num2str(Out.PassedTrials))
elseif strcmp(Mess,'Block')
    Out.CurrentBlock=Out.CurrentBlock+1;
    set(handles_Stat.text8,'String',num2str(Out.CurrentBlock))
elseif strcmp(Mess,'')==0 
    Out.MessageCnt=Out.MessageCnt+1;
    Out.StringOut = TextRolling(Out.StringOut,[num2str(Out.MessageCnt),' ',Mess]);  
    set(handles_Stat.text11,'String',Out.StringOut)
end