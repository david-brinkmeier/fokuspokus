function connect(obj)
if ~obj.verifyPkgInstalled()
    return
end

obj.cliBox = statusTextBox(0,30,12,'normal','info');
obj.cliBox.title = 'Gige cam connect';
obj.cliBox.killDelay = 1;

% if identifier is provided then it is used else auto try
if obj.isconnected == false
    if ~isempty(obj.identifier)
        obj.cliBox.addText(sprintf('Trying to connect to gigecam %s\n',obj.identifier))
        try
            obj.cam = gigecam(obj.identifier);
            obj.cliBox.newLine;
            obj.cliBox.addText('Success!')
        catch
            obj.cliBox.addText(sprintf('Could not connect to gigecam with IP/Serialnumber: %s.\n',...
                obj.identifier))
            obj.cliBox.type = 'error';
        end
    else
        obj.cliBox.addText('Trying to connect to gigecam using auto-connect.\n')
        try
            obj.cam = gigecam;
        catch
            obj.cliBox.addText('Could not connect to gigecam.\n')
            obj.cliBox.addText('Does it work in PFViewer / PF eBUSPlayer?\n')
            obj.cliBox.addText('Is Matlab UDP Firewall off / Port forwarding on?\n')
            obj.cliBox.type = 'error';
        end
    end
else
    obj.cliBox.addText('Gigecam is already connected.')
    obj.cliBox.type = 'warn';
    obj.cliBox.kill
end

% upon connection start timer: this is for determination of temperature variation of cam
if obj.isconnected
    if isdeployed
        obj.cliBox.addText('Gigecam support package is buggy in compiled mode.\n');
        obj.cliBox.addText('Cannot determine if connection established.\n');
        obj.cliBox.addText('Camera may or may not be connected...');
    else
        obj.cliBox.addText('Success!');
    end
    fprintf('Cam is connected or was already connected!\n')
    % note: "@(hObject,event) mycallback(c)" means
    % discard of first to inputs (which are hobj and event, then call fcn with argument c
    obj.absoluteTimer = timer('TimerFcn',@(hObject,event) obj.updateTimerVals(),...
        'StartDelay',2,'Period',10,'ExecutionMode','fixedRate');
    start(obj.absoluteTimer);
    
    % init caminfo struct
    fields = {'device','SN','IP'};
    values = cell(1,length(fields));
    args = [fields; values];
    obj.caminfo = struct(args{:});
    % try to populate
    camfields = {'DeviceModelName','SerialNumber','IPAddress'};
    for i = 1:length(camfields)
        try
            obj.caminfo.(fields{i}) = obj.cam.(camfields{i});
        catch
            obj.caminfo.(fields{i}) = 'nan';
        end
    end
    
    if ~strcmpi(obj.cam.Correction_Mode,'off')
        obj.cam.Correction_Mode = 'Off';
        pause(0.05);
    end
    
    % update resetCounter
    obj.resetCounter();
end
% close info box
obj.cliBox.kill
end