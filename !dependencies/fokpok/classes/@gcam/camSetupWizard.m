function abort = camSetupWizard(obj,etalonSpec)
% helps user through the complete cam setup
%
% 1a) determine Hotpixels
% obj.findValidPixels();
% 1b) determine ROIs 
% obj.ROIselector();
% 2) iteratively determine blackLevel / exposure
% obj.findExposure();
% 3) apply HotpixelOffset Correction; Aperture Open + Laser OFF!
% obj.makeBackGroundCorrection();

if nargin < 2
    error('etalonSpec not provided to camSetupWizard...')
end

if ~obj.isconnected
    abort = true;
    warndlg('\fontsize{12}Connect camera first.',...
        'gcam.camSetupWizard',struct('Interpreter','tex','WindowStyle','modal'))
    return
end

abort = askUser();

if ~abort
    cliBox = statusTextBox(4,30,12,'normal','info');
    cliBox.exitButton = 0; % disable corner close
    cliBox.killDelay = 1;
    cliBox.title = 'camSetupWizard';
    cliBox.addText('Starting camSetupWizard...\n')
end

% step1: detect hotpixels
if ~abort
    cliBox.addText('Starting Hotpixel Detection...\n')
    pause(0.5)
    if obj.hotpixelDetected
        % previously already successfully determined!
        abort = false;
    else
        abort = obj.findValidPixels();
    end
    if ~abort
        cliBox.addText('[1/4] Hotpixel Detection succesful.\n')
    else
        cliBox.addText('[1/4] Hotpixel Detection fail / abort.\n')
        cliBox.type = 'error';
    end
end

% step2: determine ROIs; Aperture Open + Laser ON!
if ~abort
    cliBox.addText('Starting ROI Selector...\n')
    pause(0.5)
    if obj.roiIsActive
        abort = false;
    else
        abort = obj.ROIselector(etalonSpec);
    end
    if ~abort
        cliBox.addText('[2/4] BeamGrid-ROIs selected.\n')
    else
        cliBox.addText('[2/4] BeamGrid-ROIs selection fail / abort.\n')
        cliBox.type = 'error';
    end
end

% step3: find correct blacklevel/exposure; Aperture Open + Laser ON!
if ~abort
    cliBox.addText('Starting AutoExposure...\n')
    cliBox.addText('Optimization criteria: Validpixels inside ROIs!\n')
    pause(0.5)
    abort = obj.findExposure();
    if ~abort
        cliBox.addText('[3/4] AutoExposure succesful.\n')
    else
        cliBox.addText('[3/4] AutoExposure fail / abort.\n')
        cliBox.type = 'error';
    end
end

% step4: apply/execute blacklevel correction; Aperture Open + Laser OFF!
if ~abort
    cliBox.addText('Starting Background/Hotpixel correction...\n')
    pause(0.5)
    abort = obj.makeBackGroundCorrection();
    if ~abort
        cliBox.addText('[4/4] Background/Hotpixel correction succesful.\n')
    else
        cliBox.addText('[4/4] Background/Hotpixel correction fail / abort.\n')
        cliBox.type = 'error';
    end
end

if exist('cliBox','var')
    cliBox.exitButton = 1;
    cliBox.kill
end
end

function abort = askUser()
abort = false;
answer = questdlg('\fontsize{12}Start cam setup wizard?',...
    'camWizard','Yes','No',...
    struct('Interpreter','tex','Default','Yes'));
switch answer
    case {'No',''}
        abort = true;
end
end