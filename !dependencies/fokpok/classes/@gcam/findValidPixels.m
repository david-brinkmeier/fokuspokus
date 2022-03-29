function abort = findValidPixels(obj)
% this function attempts to determine which pixels are Hotpixels
% this is needed because otherwise it's impossible to set a proper exposure
% note that exposure, blacklevel and hotpixelcorrection are correlated, so finding
% exposure requires hotpixelcorrection off; but w/o hotpixelcorrection
% determination of exposure is bullshit
% conclusion: try to figure out which pixels are shit so we can exclude
% beforehand; turns out gige cam fpga-hotpixelcorrection essentially
% removes the same pixels we detect here (as it should/must be)

[abort,reset] = askUser();

% init info box
if ~abort && (reset == false)
    obj.cliBox = statusTextBox(4,30,12,'normal','info');
    obj.cliBox.exitButton = 0; % disable corner close
    obj.cliBox.killDelay = 1;
    obj.cliBox.title = 'Hotpixel Detection';
    obj.cliBox.addText('Starting Hotpixel Detection...\n')
end

% check cam connection status
if ~obj.isconnected
    abort = true;
    obj.cliBox.addText('Camera not connected.\n')
    obj.cliBox.type = 'error';
end

if ~abort
    getValidPixels(obj);
end

if reset
    obj.validpixels = [];
end
end

function getValidPixels(obj)
% pixels which are consistently brighter than neighbor pixels WHILE
% complete sensor should be illuminated at the same level (aperture
% closed!) must be Hotpixels. Determine these pixels. Pixels other than the
% latter are validpixels. Valid pixels are used to determine exposure later
% on.
abort = false;

% ocrrection mode must be off for this
if ~strcmpi(obj.cam.Correction_Mode,'off')
    obj.cliBox.addText('Setting Correction Mode to off...\n')
    obj.cam.Correction_Mode = 'Off';
    obj.wait4update(2);
end

% test 20 exposures
range = ceil(linspace(obj.exposureRange(2)/200,obj.exposureRange(2),20));

% init imgs, get img, set exposure, adjust blacklevel, repeat
imgs = zeros([obj.imSizeXY,length(range)]);
for i = 1:length(range)
    obj.exposure = range(i);
    obj.wait4update(2);
    obj.cliBox.addText(sprintf('Exposure [%i/%i], Setpoint %.1f / Framerate %2.2f\n',...
                       i,length(range),range(i),obj.framerateMAX));                   
    if ~obj.isInRange(obj.cam.Average_Value,[240,400])
        obj.cliBox.addText('BlackLevel is not within acceptable range..\n')
        success = obj.PI_control('blacklevel',10,0.025,0,0);
        obj.cliBox.newLine();
        if ~success
            abort = true;
            obj.cliBox.type = 'warn';
            break
        end
        obj.wait4update(2);
    end
    
    obj.grabFrame(); % important; update frame
    imgs(:,:,i) = obj.IMG; % save to stack
    
    % update title
    obj.cliBox.titlePersistent = 0;
    obj.cliBox.title = sprintf('Hotpixel Detection: %.0f%%',100*i/length(range));
    obj.cliBox.titlePersistent = 1;
end

if ~abort
    %get stats
    hotpixels = ones([obj.imSizeXY,length(range)]);
    for i = 1:length(range)
        currentmean = mean(imgs(:,:,i),'all');
        if currentmean > 0.85*obj.grayLevelLims(2)
            % give warning: too bright for analysis
            % probably redundant bc blacklevel should fail if this is the case anyway
            abort = true;
            obj.cliBox.type = 'warn';
        end
        currentstd = std(imgs(:,:,i),0,'all');
        % pixel indices which are not overexposed get a +1
        % so validpixel(index) is at best = length(range)
        % assume > .75*length(range) for valid pixels
        hotpixels(:,:,i) = (imgs(:,:,i) < currentmean+5*currentstd);
    end
    sum_hotpixel = sum(hotpixels,3);
end

% if images were valid then export validpixels
if ~abort
    obj.validpixels = sum_hotpixel > floor(0.75*length(range));
    obj.cliBox.addText('findValidPixels succesful!')
else
    obj.validpixels = [];
    obj.cliBox.addText('findValidPixels fail.\n')
    obj.cliBox.addText('TOO BRIGHT. CLOSE APERTURE!')
end

% close cli
obj.cliBox.title = 'Hotpixel Detection';
obj.cliBox.exitButton = 1;
obj.cliBox.kill
end

function [abort,reset] = askUser()
abort = false;
reset = false;

answer = questdlg('\fontsize{12}Start Hotpixel detection?',...
    'Hotpixel Detection','Yes','Later','Reset Hotpixels',...
    struct('Interpreter','tex','Default','Yes'));
switch answer
    case {'Later',''}
        abort = true;
    case 'Reset Hotpixels'
        abort = true;
        reset = true;
end

if ~abort
    answer = questdlg('\fontsize{12}Aperture is completely closed?',...
        'Hotpixel Detection','Yes, start now!',...
        struct('Interpreter','tex','Default','Yes, start now!'));
    switch answer
        case '' % abort [x] click
            abort = true;
    end
end
end