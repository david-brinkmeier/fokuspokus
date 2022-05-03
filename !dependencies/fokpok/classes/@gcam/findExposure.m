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
    abort = askUser();
end

iteration = 1;
maxIteration = 15;
done = false;
while ~done && ~abort
    % update title
    obj.cliBox.titlePersistent = 0;
    obj.cliBox.title = sprintf('AutoExposure: Iteration %i. Abort after %i Iterations.',...
                                iteration,maxIteration);
    obj.cliBox.titlePersistent = 1;
    
    % verify blackLevel / average value is OK for current exposure
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
    end
    
    % when avg value in range, try exposure
    if obj.isInRange(obj.cam.Average_Value,[240,400])
        success_exposure = obj.PI_control('exposure',15,50,0,0);
        if ~success_exposure
            abort = true;
            obj.cliBox.type = 'warn';
            obj.cliBox.addText('AutoExposure fail.\n')
            obj.cliBox.addText('Check Exposure report. Too much or too little signal.')
        else
            obj.cliBox.newLine();
        end
    end
    
    % if blacklevel and exposure is in range then we're done
    if success_exposure
        obj.wait4update(2)
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

% close cli
obj.cliBox.exitButton = 1;
obj.cliBox.kill
end

function abort = askUser()
abort = false;
answer = questdlg('\fontsize{12}Start AutoExposure?',...
    'AutoExposure','Yes','No',...
    struct('Interpreter','tex','Default','Yes'));
switch answer
    case {'No',''}
        abort = true;
end

if ~abort
    answer = questdlg('\fontsize{12}Aperture is open and Laser is on?',...
        'AutoExposure','Yes, start now!',...
        struct('Interpreter','tex','Default','Yes, start now!'));
    switch answer
        case '' % abort [x] click
            abort = true;
    end
end
end