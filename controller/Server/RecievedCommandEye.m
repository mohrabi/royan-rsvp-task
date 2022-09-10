function RecievedCommandEye(Connection1, event)

global Eye;
Eye = fscanf(Connection1, '%f');

% disp(Eye);
if length(Eye)>=2
    if (Eye(1) == 999999)
%         fprintf(Connection1,'CerePlex');
    end
end

end