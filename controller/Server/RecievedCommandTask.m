function RecievedCommandTask(Connection2,event)

global TrialCounts;
% global Mess;
TrialCounts = fscanf(Connection2,'%f');
% disp(Eye);
% if length(Eye)>=2
%     if (Eye(1) == 999999)
%         fprintf(Connection,'Cheetah');
%     end
% end

end