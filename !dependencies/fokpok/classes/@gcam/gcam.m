classdef gcam < handle
    % helper class for gige cams
    % potentially specific to photon focus cam MV1-D2080-160-G2-12
    % also facilitates helper functions for cam as well as roi stuff for fokuspokus
    
    properties (Access = public)
        binning_factor      (1,1) uint32    % image binning, 2-3-4 etc.
        warnings_enabled    (1,1) logical   % disables / enables some internal warnings
    end
    
    properties (SetAccess = protected, GetAccess = public)
        cam                                 % gigecam object or empty
        camInfoString       (1,:) char      % header for figname w/ basic user info
        identifier          (1,:) char      % IP Address or Cam Serial number,
                                            % e.g. '030300016115' / '192.168.0.100'
        
        cliBox                    statusTextBox
        logmask             (:,:) logical   % derived from ROIs is provided
        logmask_binned      (:,:) logical   % + binning
        validpixels         (:,:) logical   % validpixels are those which are not Hotpixels
        hotpixelStats       (1,2) double    % [% of hotpixels, total number of hotpixels]
        validpixels_binned  (:,:) logical   % + binning
        
        pixelSize           (1,1) double    % pixel size in SI units, set by constructor. hardcoded bc cannot be requested from gige cam
        frameTime           (1,1) double    
        framerateMAX        (1,1) double    % internal fast access to obj.cam.AcquisitionFrameRateMax; updated w/ exposure
        caminfo             (1,1) struct    
        camTemperature      (1,1) double    % current cam temperature; updated by timer
        camTempDrift        (1,1) double    % updates upon timer callback
                                            % reference temp is set after each call to resetCounter
        exposureRange       (1,2) double
        blackLevelRange     (1,2) double
        referenceTemp       (1,1) double    % set upon executing obj.resetCounter
        currentGrayLevel    (1,1) double    % last normalizedExposure result polled by timer, if == 1 then overexposed
        
        OPDroi              (1,:) double    % optical path differences corresponding to linear index of ROIs
        OPDroiSorted        (1,:) double    % optical path differences corresponding to linear index of ROIsSorted
    end
    
    properties (Dependent)  
        roiIsActive          (1,1) logical  % true when valid ROIs exist
        hotpixelDetected     (1,1) logical  % true when validpixels exist / hotpixelDetection succesful
        BGcorrectionEnabled  (1,1) logical  % true when obj.cam.Correction_Mode = 'OffsetHotpixel';
        
        imSizeXY             (1,2) double
        pixelFormat          (1,:) char
        serialnumber         (1,:) char
        camIP                (1,:) char
        isconnected          (1,1) logical
        grayLevelLims        (1,2) double
        normalizedExposure   (1,1) double   % effective maximum detected gray level divided by maximum gray level. equal to 1 = overexposed
        
        IMG                  (:,:,1) double % just a pointer to obj.currentIMGsource
        IMGbinned            (:,:,1) double % takes currentIMGsource and applies binning
        IMGroi               (:,:,1) double % if ROIs are provided then this is currentIMGsource with applied rois
        IMGroiBinned         (:,:,1) double % if ROIs are provided then this is currentIMGsource with applied rois
        IMGroiCompact        (:,:,1) double % IMGroi but without whitespace..directly concatenated
        IMGroiInALine        (:,:,1) double % same as above but all beams in a column
        IMGstack             (:,:,:) double % if ROIs are provided then this is currentIMGsource 3D img stack
        IMGstackSorted       (:,:,:) double % "" sorted
        
        framerate            (1,1) double
        framecount           (1,1) int32
        time                 (1,1) double % time since resetCounter
        
        exposure             (1,1) double % cam exposure in µs, 10-419000 for MV1-D2080-160-G2-12
        blackLevel           (1,1) double % related to histogram range (cam.Average_Value); probably AD-DC amplifification, check cam manual
    end
    
    properties (SetAccess = protected, GetAccess = private)
       currentIMGsource     (:,:) double % written upon obj.grabFrame();
       ROIs                 (:,1) cell   % cell of masks of ROIs
       ROIsSorted           (:,1) cell   % cell of sorted masks of ROIs
       ROIspec                    struct % only holds xnum / ynum specification of ROI grid, hard coded in constructor
                                         % exists only when ROI spec is correct, no need for error checks, get/set

       timerFrame                        % for frame times / resettable               
       absoluteTimer                     % for cam temp change, set upon cam connect
       
       tempDriftWarning           matlab.ui.Figure % handle to warning, used to check to avoid multiple calls
       overExposedWarning         matlab.ui.Figure % handle to warning, used to check to avoid multiple calls
    end
    
    properties (Access = private)
       exposure_internal   (1,1) double 
    end
 
    methods 
        function obj = gcam(identifier)
            if nargin == 0
                obj.identifier = [];
            else
                obj.identifier = identifier; % can be S/N, IP or nothing (auto detect)
            end
            obj.warnings_enabled = true;
            obj.cliBox = statusTextBox;
            obj.binning_factor = 1;
            obj.pixelSize = 8e-6; % 8 µm; Photonfocus, A2080; photonfocus_datasheet_MV1-D2080-160-G2.pdf
            % variant is sn / ip / auto, identifier is IP Address or Serial Number
            obj.cam = [];
            obj.referenceTemp = nan;
            obj.camTempDrift = nan;
            % init camera specific ranges
            % unfortunately these ranges are only provided as cli-warnings
            % by the camera upon setting invalid values..so this happens
            % explicitly here and must be adjusted manually for different cameras
            obj.exposureRange = [10,419000];
            obj.blackLevelRange = [0,255];
            % init timer
            obj.timerFrame = tic;
            obj.absoluteTimer = nan;
        end
    end
    
    methods
               
        function val = get.warnings_enabled(obj)
            val = obj.warnings_enabled;
        end
        
        function set.warnings_enabled(obj,val)
            obj.warnings_enabled = val;
        end
        
        function set.framerateMAX(obj,val)
            % internal storage, updated by set.exposure
            obj.framerateMAX = val;
        end
        
        function val = get.framerateMAX(obj)
            if obj.isconnected
                if obj.framerateMAX == 0
                    obj.framerateMAX = obj.cam.AcquisitionFrameRateMax;
                end
            end
            val = obj.framerateMAX;
        end
        
        function set.exposure_internal(obj,val)
            % internal storage, used by set.exposure
            obj.exposure_internal = val;
        end
        
        function val = get.exposure_internal(obj)
            val = obj.exposure_internal;
        end
        
        function set.frameTime(obj,val)
            % used by method grabFrame(obj)
            obj.frameTime = val;
        end
        
        function val = get.frameTime(obj)
           val = obj.frameTime;
        end
        
        function set.currentIMGsource(obj,val)
            % used by method grabFrame(obj)
           obj.currentIMGsource = val; 
        end
        
        function val = get.normalizedExposure(obj)
            if obj.isconnected
               val = obj.calcExposureResult/obj.grayLevelLims(2);
            end
        end
        
        function val = get.BGcorrectionEnabled(obj)
           val = false;
           if strcmp(obj.cam.Correction_Mode,'OffsetHotpixel')
               val = true;
           end
        end
        
        function val = get.currentIMGsource(obj)
            val = obj.currentIMGsource;
        end
        
        function val = get.referenceTemp(obj)
           val = obj.referenceTemp; 
        end
        
        function val = get.caminfo(obj)
           val = obj.caminfo; 
        end
        
        function val = get.camInfoString(obj)
            if obj.isconnected
                if isempty(obj.camInfoString)
                    obj.updateCamInfoString()
                end
                val = obj.camInfoString;
            else
                val = 'not connected';
            end
        end
        
        function set.validpixels(obj,val)
            obj.validpixels = val;
            obj.updatehotpixelStats();
        end
        
        function val = get.validpixels(obj)
            val = obj.validpixels;
        end
        
        function set.validpixels_binned(obj,val)
            obj.validpixels_binned = val;
        end
        
        function val = get.validpixels_binned(obj)
            if (obj.hotpixelDetected == true) && (obj.binning_factor ~= 1)
                if ~isequal(obj.imSizeXY/obj.binning_factor,size(obj.validpixels_binned))
                    obj.validpixels_binned = obj.validpixels(1:obj.binning_factor:end,...
                                                             1:obj.binning_factor:end);
                end
            else
                obj.validpixels_binned = [];
            end
            val = obj.validpixels_binned;
        end
        
        function set.binning_factor(obj,val)
            if val < 1
                obj.binning_factor = 1;
            else
                obj.binning_factor = val;
            end
            % important - need to keep logmask up to date!
            obj.updateROIrelatedStuff();
        end
        
        function val = get.binning_factor(obj)
            val = double(obj.binning_factor);
        end
        
        function val = get.roiIsActive(obj)
            val = false;
            if obj.isconnected
                if ~isempty(obj.ROIs)
                    val = true;
                end
            end
        end
        
        function val = get.hotpixelDetected(obj)
            val = false;
            if obj.isconnected
                if ~isempty(obj.validpixels)
                    val = true;
                end
            end
        end
        
        function set.hotpixelStats(obj,val)
            obj.hotpixelStats = val;
        end
        
        function val = get.hotpixelStats(obj)
            val = [nan,nan];
            if obj.isconnected
                if obj.hotpixelDetected == true
                    val = obj.hotpixelStats;
                end
            end
        end
                
        function set.ROIs(obj,val)
            % must be cell of masks
            if ~isempty(val)
                if ~(all(cellfun(@(x) isa(x,'mask'),val)))
                    error('gcam rois input must be a cell array of masks!')
                else
                    obj.ROIs = val;
                end
            else
                obj.ROIs = cell(0,1);
            end
            obj.updateROIrelatedStuff(); % includes error checking etc
        end
        
        function set.ROIsSorted(obj,val)
            % only need to check it's cell of masks
            % this is set by method ROIselector after writing ROIs so if
            % ROIs are OK then this is aswell
            if ~isempty(val)
                if ~(all(cellfun(@(x) isa(x,'mask'),val)))
                    error('gcam rois input must be a cell array of masks!')
                else
                    obj.ROIsSorted = val;
                end
            else
                obj.ROIsSorted = cell(0,1);
            end
        end
        
        function val = get.imSizeXY(obj)
            if obj.isconnected
                val = double([obj.cam.Width,obj.cam.Height]);
            else
                val = [nan,nan];
            end
        end
        
        function set.camTemperature(obj,val)
            % timer writes this
            obj.camTemperature = val;
        end
        
        function val = get.camTemperature(obj)
            if obj.isconnected
                val = obj.camTemperature;
            end
        end
        
        function val = get.blackLevel(obj)
            if obj.isconnected
                val = obj.cam.BlackLevel;
            end
        end
        
        function set.blackLevel(obj,val)
            abort = false;
            if obj.isconnected
                if ~strcmpi(obj.cam.Correction_Mode,'off') && obj.warnings_enabled
                    answer = questdlg('\fontsize{11}Modifying BlackLevel disables OffsetHotpixelCorrection!',...
                        'BlackLevel-Hotpixel','OK fine, continue.','Abort',...
                        struct('Interpreter','tex','Default','Abort'));
                    switch answer
                        case {'Abort',''}
                            abort = true;
                        case 'OK fine, continue.'
                            obj.cam.Correction_Mode = 'Off';
                            obj.referenceTemp = nan;
                            obj.wait4update(1.1);
                    end
                end
                if abort == false
                    if obj.isInRange(val,obj.blackLevelRange)
                        obj.cam.BlackLevel = ceil(val);
                    else
                        fprintf('BlackLevel must be within Range %i to %i.',...
                            obj.blackLevelRange(1),obj.blackLevelRange(2))
                    end
                end
            end
        end
        
        function set.exposure(obj,val)
            if obj.isconnected
                abort = false;
                % if OffsetHotpixelCorrection ask User if we should abort
                if ~strcmpi(obj.cam.Correction_Mode,'off') && obj.warnings_enabled
                    answer = questdlg('\fontsize{11}Modifying exposure disables OffsetHotpixelCorrection!',...
                        'Exposure-Hotpixel','OK fine, continue.','Abort',...
                        struct('Interpreter','tex','Default','Abort'));
                    switch answer
                        case {'Abort',''}
                            abort = true;
                        case 'OK fine, continue.'
                            obj.cam.Correction_Mode = 'Off';
                            obj.referenceTemp = nan;
                            obj.wait4update(1.1);
                    end
                end
                % if we change exposure set it if within range and disable that
                % value-correction warning from the cam bc we dont care about it
                if abort == false
                    warning('off','imaq:gige:gigecam:genicamPropHealed')
                    val = round(val,0);
                    if obj.isInRange(val,obj.exposureRange)
                        if obj.isconnected
                            obj.cam.ExposureTime = val;
                            pause(0.05);
                        end
                    else
                        fprintf('Exposure time is not within supported range [%i-%i]\n',...
                            obj.exposureRange(1),obj.exposureRange(2));
                    end
                    warning('on','imaq:gige:gigecam:genicamPropHealed')
                end
                % update some relevant parametsr which depend on exposure
                obj.exposure_internal = obj.cam.ExposureTime;
                obj.framerateMAX = obj.cam.AcquisitionFrameRateMax;
                obj.updateCamInfoString();
            end
        end
        
        function val = get.grayLevelLims(obj)
            % returns expected intensity limits of image based on currently
            % selected PixelFormat
            if obj.isconnected
                switch obj.pixelFormat
                    case 'Mono8'
                        val = [0 2^8-1];
                    case {'Mono10','Mono10Packed'}
                        val = [0 2^10-1];
                    case {'Mono12','Mono12Packed'}
                        val = [0 2^12-1];
                    otherwise
                        error('Unknown pixelFormat provided by gigecam.')
                end
            end
        end
        
        function val = get.exposure(obj)
            % exposure time in µs
            if obj.isconnected
                if obj.exposure_internal == 0
                    obj.exposure_internal = obj.cam.ExposureTime;
                end
                val = obj.exposure_internal;
            else
                val = nan;
            end
        end
        
        function val = get.pixelFormat(obj)
            if obj.isconnected
                val = obj.cam.PixelFormat;
            else
                val = 'not connected';
            end
        end
        
        function set.pixelFormat(obj,val)
            if obj.isconnected
                if ismember(val,obj.cam.AvailablePixelFormats)
                    obj.cam.PixelFormat = val;
                else
                    fprintf(2,'Could not set this PixelFormat.\n')
                    obj.dispAvailablePixelFormats()
                end 
            end
        end
        
        function val = get.IMG(obj)
            if obj.isconnected
                if isempty(obj.currentIMGsource)
                    obj.grabFrame();
                end
                val = obj.currentIMGsource;
            else
                val = [];
            end
        end
        
        function val = get.IMGbinned(obj)
            if obj.isconnected && (obj.binning_factor ~= 1)
                val = obj.IMG(1:obj.binning_factor:end,...
                              1:obj.binning_factor:end);
            else
                val = [];
            end
        end
        
        function val = get.IMGroi(obj) 
            if obj.isconnected && (obj.roiIsActive == true)
                val = obj.IMG;
                val(obj.logmask == false) = 0;
            else
                val = [];
            end
        end
        
        function val = get.IMGroiBinned(obj)
            if obj.isconnected && (obj.roiIsActive == true) && (obj.binning_factor ~= 1)
                val = obj.IMGbinned;
                val(obj.logmask_binned == false) = 0;
            else
                val = [];
            end
        end
        
        function val = get.IMGroiCompact(obj)
            % this returns essentially IMGroi without "gaps" / whitespace
            if obj.isconnected && (obj.roiIsActive == true)
                % for readability grab some specifications
                xnum = obj.ROIspec.xnum;
                ynum = obj.ROIspec.ynum;
                edgelen = obj.ROIs{1}.minOddEdgelen;
                % get x and y starting values for indexing
                % note: might need these for offsetting imMoments later...
                % (if overlay is required)
                [xstart,ystart] = meshgrid(1+(0:1:xnum-1)*edgelen,1+(0:1:ynum-1)*edgelen);
                % init output array
                val = zeros(ynum*edgelen,xnum*edgelen,1);
                % fill based on ROI specification
                for i = 1:length(obj.ROIs)
                    val((1:edgelen)+ystart(i)-1,...
                        (1:edgelen)+xstart(i)-1) = mask.crop_image(obj.IMG,obj.ROIs{i});
                end
                % the following method is also possible and potentially
                % less error prone but slightly slower
                % imCell = num2cell(obj.IMG,[1 2]); % put each page of IMG into a cell
                % imCell_yx = reshape(imCell,[ynum,xnum]); % reshaped into cell grid [y,x]
                % val = cell2mat(imCell_yx); % and convert to matrix
            else
                val = [];
            end
        end
        
        function val = get.IMGroiInALine(obj)
            % reshapes IMGstack into a "long" 2D array
            if obj.isconnected && (obj.roiIsActive == true)
                val = permute(obj.IMGstack,[1 3 2]);
                val = reshape(val,[],size(obj.IMGstack,2),1);
            else
                val = [];
            end
        end
        
        function val = get.IMGstack(obj)
            if obj.isconnected && (obj.roiIsActive == true)
                % init 3d stack
                val = zeros(obj.ROIs{1}.minOddEdgelen,obj.ROIs{1}.minOddEdgelen,length(obj.ROIs));
                % populate
                for i = 1:length(obj.ROIs)
                  val(:,:,i) = mask.crop_image(obj.IMG,obj.ROIs{i});
                end
            else
                val = zeros(0,0,0);
            end
        end
        
        function val = get.IMGstackSorted(obj)
            if obj.isconnected && (obj.roiIsActive == true)
                % init 3d stack
                val = zeros(obj.ROIsSorted{1}.minOddEdgelen,obj.ROIsSorted{1}.minOddEdgelen,length(obj.ROIsSorted));
                % populate
                for i = 1:length(obj.ROIsSorted)
                    val(:,:,i) = mask.crop_image(obj.IMG,obj.ROIsSorted{i});
                end
            else
                val = zeros(0,0,0);
            end
        end
            
        function val = get.framerate(obj)
            if obj.isconnected
                val = double(obj.framecount)/obj.time;
            else
                val = nan;
            end
        end
        
        function val = get.time(obj)
            val = toc(obj.timerFrame);
        end
        
        function val = get.isconnected(obj)
            % returns true if cam is connected
            if ~isempty(obj.cam)
                val = true;
            else
                val = false;
            end
        end
        
        function val = get.framecount(obj)
            if obj.isconnected
               val = obj.cam.Counter_Image;
            end
        end
         
    end
    
    methods (Access = public) % set this private when done with it
        
        % declared externally
        connect(obj);
        disconnect(obj);
        
        % declared externally, helps user through the complete cam setup
        abort = camSetupWizard(obj,etalonSpec)
        % declared externally
        abort = findValidPixels(obj)
        % declared externally, etalonSpec isa etalons / hold beam splitter info
        abort = ROIselector(obj,etalonSpec)
        % declared externally
        abort = findExposure(obj)
        % declared externally
        abort = makeBackGroundCorrection(obj)
        
        % declared externally; when nargin = 1 then calcExposureResult
        % grabs a frame for itself, otherwise e.g. pass obj.IMGstack as
        % "exracted", then operation will be performed directly
        % the latter is intended for periodic exposure checks
        val = calcExposureResult(obj,extracted)
               
        function grabFrame(obj)
            if obj.isconnected
                obj.currentIMGsource = double(obj.cam.snapshot());
                obj.frameTime = toc(obj.timerFrame);
            else
                obj.currentIMGsource = [];
                obj.frameTime = nan;
            end
        end
        
        function resetCounter(obj)
            if obj.isconnected
                executeCommand(obj.cam,'Counter_ImageReset')
                [~] = obj.cam.snapshot();
                obj.timerFrame = tic;
            end
        end
        
    end
    
    methods (Access = private)
        
        % declared externally; used to adjust blacklevel / exposure
        goalAchieved = PI_control(obj,variant,allowed_deviation,Kp,Ki,debug)
        
        function updateTimerVals(obj)
            % corresponding timer is started by obj.connect()!
            % update the temperature -> write to internal variable
            obj.camTemperature = obj.cam.DeviceTemperature;
            % update current normalized gray level (check 4 overexposed)
            obj.currentGrayLevel = obj.normalizedExposure;
            % update current cam string
            obj.updateCamInfoString()
            % temperature and overexposure warning
            if ~isnan(obj.referenceTemp)
                % if a reference temp is set, then camera is setup in
                % working state for Laser Beam measurement.
                % verify temp has not drifted and image is not overexposed
                obj.camTempDrift = abs(obj.camTemperature - obj.referenceTemp);
                if obj.camTempDrift > 5
                    if isempty(obj.tempDriftWarning) || ~isvalid(obj.tempDriftWarning)
                        obj.tempDriftWarning = warndlg({sprintf('\\fontsize{11}Camera temperature has drifted %.1f °C from reference temperature! Recalibration of BlackLevelOffset advised.\n',obj.camTempDrift),...
                            'If you close this warning, it will reappear as long as the camera temperature deviates more than 5°C from the reference temperature.','The check is performed every 10 seconds.'},...
                            'gcam: Temperature Drift',struct('Interpreter','tex','WindowStyle','normal'));
                    end
                end
                
                % overexposure warning
                if obj.currentGrayLevel == 1
                    if isempty(obj.overExposedWarning) || ~isvalid(obj.overExposedWarning)
                        obj.overExposedWarning = warndlg({'\fontsize{11}The image is currently overexposed,','','If you close this warning, it will reappear as long as the image is overexposed. The check is performed every 10 seconds.'},...
                            'gcam: Overexposed',struct('Interpreter','tex','WindowStyle','normal'));
                    end
                end
            end
        end
        
        function updateROIrelatedStuff(obj)
            % init logmask as empty then generate logmask if ROIs are not empty
            % this (:,:) logmask is only required when user requests full
            % img w/ applied ROIs, generation of image stack handled by IMGstack
            obj.logmask = []; % this works bc it's of size [1,1] and logmask is (:,:)
            obj.logmask_binned = [];
            if ~isempty(obj.ROIs)
                % then rois exist and it is also ensured that each roi has the
                % same refsize equal to the cam img spec
                % and check whether alls rois share the same length
                % otherwise they can't fit in the same (:,:,n) stack
                if all(cellfun(@(input) isequal(obj.imSizeXY,input.refsz),obj.ROIs)) &&...
                        all(cellfun(@(input) isequal(obj.ROIs{1}.minOddEdgelen,input.minOddEdgelen),obj.ROIs))
                    % init logmask as empty array of image size
                    logMask = false(obj.imSizeXY);
                    for i = 1:length(obj.ROIs)
                        % inside rois logmask is true
                        % remember matlab is column major..y first
                        logMask(obj.ROIs{i}.ystart:(obj.ROIs{i}.ystart+obj.ROIs{i}.leny),...
                                obj.ROIs{i}.xstart:(obj.ROIs{i}.xstart+obj.ROIs{i}.lenx)) = true;
                    end
                    obj.logmask = logMask;
                    if (obj.binning_factor ~= 1)
                        obj.logmask_binned = logMask(1:obj.binning_factor:end,...
                                                     1:obj.binning_factor:end);
                    end
                end
            end
        end
        
        function updatehotpixelStats(obj)
            if obj.hotpixelDetected == 1
                defectAbsolute = sum(~obj.validpixels,'all');
                defectPercent = 100*defectAbsolute/(numel(obj.validpixels));
                obj.hotpixelStats = [defectPercent,defectAbsolute];
            else
                obj.hotpixelStats = [nan,nan];
            end
        end
        
        function wait4update(obj,n)
            % ensures that camera internal values (avg value etc. pp) are
            % in fact updated
            % liberal use in PI_control...
            waittime = n*1.1/obj.framerateMAX;
            if waittime < 0.1
                waittime = 0.1; 
            end
            pause(waittime);
        end
        
        function dispAvailablePixelFormats(obj)
            if obj.isconnected
                str = cellfun(@(x) [x,', '],obj.cam.AvailablePixelFormats,'un',0);
                str{end} = [str{end}(1:end-2),']',newline];
                fprintf('Allowed PixelFormats are: [')
                fprintf('%s',str{:})
                fprintf('\n')
            end
        end
                
        function updateCamInfoString(obj)
            % force generation of updated cam info string
            % generates camera info string for use in e.g. figure name header
            % some of these calls are surprisingly expensive..dont overdo it
            strings = cell(1,8);
            strings{1} = sprintf('%s, ',obj.caminfo.device);
            strings{2} = sprintf('Exposure: %3.2f ms, ',obj.exposure*1e-3);
            strings{3} = sprintf('FPS: %2.1f, ',obj.framerateMAX);
            strings{4} = sprintf('Temp: %.1f°C, ',obj.camTemperature);
            
            if ~isnan(obj.referenceTemp)
                strings{5} = sprintf('Reftemp: %.1f°C, ',obj.referenceTemp);
            else
                strings{5} = '';
            end
            
            if obj.hotpixelDetected
                strings{6} = sprintf('Hotpixels: %i, ',obj.hotpixelStats(2));
            else
                strings{6} = '';
            end
            strings{7} = sprintf('Correction: %s, ',obj.cam.Correction_Mode);
            strings{8} = sprintf('normalized GrayLevel: [%.2f/1].',obj.normalizedExposure);
            % return as char (1,:) array
            obj.camInfoString = [strings{:}];
        end
        
    end
    
    methods (Static, Access = private)
        function flag = isInRange(val,range)
            % checks if val lies within boundaries set by range
            if ~(length(range) == 2)
                error('range passed to isinrange must be of length 2')
            end
            if ~isscalar(val)
                error('val passed to isInRange must be a scalar')
            end
            if (range(1) <= val) && (val <= range(2))
                flag = true;
            else
                flag = false;
            end
        end
    end
        
    methods (Static, Access = public)
        function success = verifyPkgInstalled(showPrompt)
            if nargin == 0
                showPrompt = 1;
            end
            if isdeployed
                try
                    imaqhwinfo('gige');
                    success = true;
                catch
                    success = false;
                end
                return
            end
            % checks if required toolboxes / packages are installed
            success = false;
            pkgs = matlabshared.supportpkg.getInstalled;
            pkg_ref = 'Image Acquisition Toolbox Support Package for GigE Vision Hardware';
            if ~license('test','image_toolbox')
                warndlg('\fontsize{11}Image Processing Toolbox is not installed but required.',...
                    'gcam',struct('Interpreter','tex','WindowStyle','modal'))
            end
            if ~isempty(pkgs)
                for i = 1:length(pkgs)
                    if isequal(pkgs(i).Name,pkg_ref)
                        success = true;
                    end
                end
            end
            if ~success && showPrompt
                warndlg('\fontsize{11}gigecam package for Image Processing Toolbox is not installed but required. Aborting.',...
                    'gcam',struct('Interpreter','tex','WindowStyle','modal'))
            end
        end
    end
    
end