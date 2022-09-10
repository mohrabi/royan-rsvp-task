function StringOut=TextRolling(StringOut,NewMess)

WindowSize=8;
MessAdded=0;
for i=1:WindowSize
    if strcmp(StringOut{i},'')
        StringOut{i}=NewMess;
        MessAdded=1;
        break
    end
end

if MessAdded==0
    for i=2:WindowSize
        StringOut{i-1}=StringOut{i};
    end
    StringOut{WindowSize}=NewMess;
end
