function abort = findExposure(obj)
abort = false;

% init info box
obj.cliBox = statusTextBox(4,30,12,'normal','info');
obj.cliBox.exitButton = 0; % disable corner close
obj.cliBox.killDelay = 1.5;
obj.cliBox.title = 'AutoExposure';
obj.cliBox.addText('Starting AutoExposure...\n')

% check cam connection status
if ~obj.isconnected
    abort = true;
    obj.cliBox.addText('Camera not connected.\n')
    obj.cliBox.type = 'error';
end

if ~abort
    % ocrrection mode must be off for this
    if ~strcmpi(obj.cam.Correction_Mode,'off')
        obj.cliBox.addText('Setting Correction Mode to "Off"...\n')
        obj.cam.Correction_Mode = 'Off';
        obj.referenceTemp = nan;
        obj.wait4update(2);
    end
    
    if obj.hotpixelDetected == false
        obj.cliBox.addText('Warning: Run HotpixelDetection first!\n')
        obj.cliBox.type = 'warn';
        abort = true;
    end
    
    if obj.roiIsActive == false
        obj.cliBox.addText('Warning: ROIs should be set before AutoExposure!\n')
        obj.cliBox.type = 'warn';
        abort = true;
    end
end

if ~abort
    [abort,tryShutter] = askUser(obj.shutter);
end

% init
iteration = 1;
maxIteration = 15;
done = false;
apertureOpen = true;

while ~done && ~abort
    % update title
    obj.cliBox.titlePersistent = 0;
    obj.cliBox.title = sprintf('AutoExposure: Iteration %i. Abort after %i Iterations.',...
                                iteration,maxIteration);
    obj.cliBox.titlePersistent = 1;
    
    % verify blackLevel / average value is OK for current exposure
    if apertureOpen
        apertureOpen = askUserBlockAperture(obj.shutter, tryShutter);
    end
    
    if ~obj.isInRange(obj.cam.Average_Value,[240,400])
        obj.cliBox.addText('BlackLevel is not within acceptable range..\n')
        success_blacklevel = obj.PI_control('blacklevel',10,0.025,0,0);
        if ~success_blacklevel
            abort = true;
            obj.cliBox.type = 'warn';
            obj.cliBox.addText('AutoExposure fail.\n')
            obj.cliBox.addText('Check BlackLevel report. Too much or too little signal.')
        else
            obj.cliBox.newLine();
        end
    else
        obj.cliBox.addText('\nBlacklevel is within acceptable parameters.\n')
        pause(1) % without this delay user tends to think nothing happened IF blacklevel was fine already (instant jump to open aperture request)
    end
    
    % try exposure
    if ~apertureOpen
        apertureOpen = askUserOpenAperture(obj.shutter, tryShutter);
    end
    
    success_exposure = obj.PI_control('exposure',15,50,0,0);
    if ~success_exposure
        abort = true;
        obj.cliBox.type = 'warn';
        obj.cliBox.addText('AutoExposure fail.\n')
        obj.cliBox.addText('Check Exposure report. Too much or too little signal.')
    else
        obj.cliBox.newLine();
    end
    
    % if blacklevel and exposure is in range then we're done
    if success_exposure
        obj.wait4update(2)
        
        if apertureOpen
            apertureOpen = askUserBlockAperture(obj.shutter, tryShutter);
        end
        
        if obj.isInRange(obj.cam.Average_Value,[240,400])
            done = true;
            obj.cliBox.addText('AutoExposure success.\n')
            obj.cliBox.addText('Exposure / Blacklevel within acceptable parameters.')
        end
    end
    
    iteration = iteration + 1;
    if iteration > maxIteration
        abort = true;
        obj.cliBox.addText(sprintf('Aborting AutoExposure after %i iterations.\n',iteration))
        obj.cliBox.type = 'warn';
    end
end

% attempt to move shutter open if device is available
if tryShutter
    obj.shutter.moveShutter('open');
end

% close cli
obj.cliBox.exitButton = 1;
obj.cliBox.kill
end

function [abort,tryShutter] = askUser(shutter)
abort = false;
answer = questdlg('\fontsize{12}Start AutoExposure?',...
    'AutoExposure','Yes','No',...
    struct('Interpreter','tex','Default','Yes'));
switch answer
    case {'No',''}
        abort = true;
end

if ~abort
    
    shutter.connect; % try to establish connection to ThorlabsELL6K  
    if shutter.isConnected
        tryShutter = true;
        str = {'\fontsize{12}The laser must be ON now.','The shutter will OPEN and BLOCK the aperture until convergence is reached.'};
    else
        tryShutter = false;
        str = {'\fontsize{12}The laser must be ON now and you must manually, and in an alternating fashion, OPEN and BLOCK the aperture until convergence is reached.','',...
            'You will be prompted to OPEN and BLOCK the aperture.'}; 
    end
    
    answer = questdlg(str,...
        'AutoExposure','OK, start now!',...
        struct('Interpreter','tex','Default','OK, start now!'));
    switch answer
        case '' % abort [x] click
            abort = true;
    end
end

end

function [apertureOpen,abort] = askUserBlockAperture(shutter, tryShutter)
abort = false;

% try automatic shutter
if tryShutter % if we dont use this then each call to moveshutter costs > 1s
    shutter.moveShutter('closed');
    if shutter.isInPositionClosed
        apertureOpen = false;
        return
    end
end

% otherwise manual
answer = questdlg('\fontsize{12}The aperture is blocked / closed? [Enter = Yes]',...
    'AutoExposure: BlackLevel','Yes',...
    struct('Interpreter','tex','Default','Yes'));
switch answer
    case {''}
        abort = true;
end
apertureOpen = false;
end

function [apertureOpen,abort] = askUserOpenAperture(shutter, tryShutter)
abort = false;

% try automatic shutter
if tryShutter % if we dont use this then each call to moveshutter costs > 1s
    shutter.moveShutter('open');
    if shutter.isInPositionOpen
        apertureOpen = true;
        return
    end
end

% otherwise manual
answer = questdlg('\fontsize{12}The aperture is open? [Enter = Yes]',...
    'AutoExposure: Exposure','Yes',...
    struct('Interpreter','tex','Default','Yes'));
switch answer
    case {''}
        abort = true;
end
apertureOpen = true;
end

