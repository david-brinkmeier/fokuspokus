function abort = makeBackGroundCorrection(obj)
% check with user
abort = askUser();

% check cam connection status
if ~obj.isconnected
    abort = true;
    obj.cliBox.addText('Camera not connected.\n')
    obj.cliBox.type = 'error';
end

if ~abort
    % init info box
    obj.cliBox = statusTextBox(1,30,12,'normal','info');
    obj.cliBox.exitButton = 0; % disable corner close
    obj.cliBox.killDelay = 1.5;
    obj.cliBox.title = 'Hotpixel Offset Correction';
    obj.cliBox.addText('Starting Hotpixel Offset Correction...\n')
    
    if ~obj.isInRange(obj.cam.Average_Value,[240,400])
        % warn blacklevel is not in range
        obj.cliBox.type = 'warn';
        obj.cliBox.addText('BlackLevel is not within acceptable range. Re-run AutoExposure!\n')
        abort = true;
    end
    
    if strcmpi(obj.cam.Correction_Mode,'OffsetHotpixel')
        obj.cliBox.type = 'warn';
        obj.cliBox.addText('OffsetHotpixel Correction is already on!\n')
        obj.cliBox.addText('If you wish to reset HotpixelCorrection simply re-run AutoExposure!')
        abort = true;
    end
end

if ~abort
    executeBackGroundCorrection(obj);
end

% kill info box
obj.cliBox.exitButton = 1; % disable corner close
obj.cliBox.kill;
end

function executeBackGroundCorrection(obj)
% set currrent temperature as reference temperature
obj.referenceTemp = obj.camTemperature;
% calibrate blacklevel
executeCommand(obj.cam, 'Correction_CalibrateBlack')

pause(0.1)
while obj.cam.Correction_Busy
   obj.cliBox.addText('.')
   pause(0.1)
end
pause(0.1)

% important: now is the time to update the reference temperature
obj.referenceTemp = obj.camTemperature;

obj.cliBox.newLine();
obj.cliBox.addText('Success & Done!\n')
obj.cliBox.addText('enabling OffsetHotpixel Correction.')
obj.cam.Correction_Mode = 'OffsetHotpixel';
obj.wait4update(2);

%% possible variants
% obj.cam.Correction_Mode = 'Off';
% obj.cam.Correction_Mode = 'Offset';
% obj.cam.Correction_Mode = 'Hotpixel';
% obj.cam.Correction_Mode = 'OffsetHotpixel';
end

function abort = askUser()
abort = false;

answer = questdlg('\fontsize{12}Start HotpixelOffset Correction?',...
    'HotpixelOffset Correction','Yes','No',...
    struct('Interpreter','tex','Default','Yes'));
switch answer
    case {'No',''}
        abort = true;
    case 'Yes'
        abort = false;
end

if ~abort
    answer = questdlg('\fontsize{12}Aperture is open and Laser is off?',...
        'HotpixelOffset Correction','Yes, start now!',...
        struct('Interpreter','tex','Default','Yes, start now!'));
    switch answer
        case '' % abort [x] click
            abort = true;
    end
end
end