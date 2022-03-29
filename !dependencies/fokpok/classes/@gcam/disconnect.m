function disconnect(obj)
if obj.isconnected
    % kill timer
    stop(obj.absoluteTimer)
    delete(obj.absoluteTimer)
    % reset reference temp
    obj.referenceTemp = nan;
    obj.camTempDrift = nan;
    
    % now kill cam
    obj.cam = [];
    fprintf('Disconnected!\n')
else
    fprintf('Cam is already disconnected...\n')
end
end