classdef guiMain < handle
    
    properties (SetAccess = private, GetAccess = public)
        h                                 struct
    end
    
    properties (SetAccess = protected, GetAccess = public)
        wavelength                  (1,1) double
        imstack                           imgstack.imstack
        results                           imgstack.aioResults
        gige                              gcam
        etalonSpec                        etalons
        
        workingFolder               (1,:) char
    end
    
    properties (Dependent, Access = public)
        figexists                   (1,1) logical
        guiState                    (1,:) char
        
        imstackReady                (1,1) logical
        resultsReady                (1,1) logical
        gcamReady                   (1,1) logical
        etalonsReady                (1,1) logical
    end
    
    properties (Constant, Access = private)
    end
    
    methods
        function obj = guiMain()                     
            % init fig and draw initial rois
            obj.initfig();
            obj.updateStateOfGui();
            obj.warnOldVersion();
            
            % adaptive fig resizing
            set(obj.h.panel.inputTab,'SelectionChangedFcn',@(hobj,event) obj.SelectionChanged());
            if ~gcam.verifyPkgInstalled(0)
                obj.h.panel.inputTab.Selection = 2;
            end
            
            % input tab
            set(obj.h.edit.wavelength,'Callback',{@obj.checkEditBoxes,'wavelength'});
            set(obj.h.pb.connect,'Callback',@(hobj,event) obj.connectCam());
            set(obj.h.pb.camPreview,'Callback',@(hobj,event) obj.camPreview());
            set(obj.h.pb.etalonSpec,'Callback',@(hobj,event) obj.initEtalonSpec());
            set(obj.h.pb.camWizard,'Callback',@(hobj,event) obj.camWizard());
            set(obj.h.pb.roiSelector,'Callback',@(hobj,event) obj.roiSelector());
            set(obj.h.pb.workingFolder,'Callback',@(hobj,event) obj.requestFolder());
            set(obj.h.pb.disconnect,'Callback',@(hobj,event) obj.disconnectCam());
            set(obj.h.pb.selectFiles,'Callback',@(hobj,event) obj.startFileSelector());
            set(obj.h.pb.analysisSettings,'Callback',@(hobj,event) obj.analysisSettings());
            set(obj.h.pb.settingsPlot1,'Callback',@(hobj,event) obj.plotSettings('plot1'));
            set(obj.h.pb.settingsPlot2,'Callback',@(hobj,event) obj.plotSettings('plot2'));
            set(obj.h.pb.settingsPlot3,'Callback',@(hobj,event) obj.plotSettings('plot3'));
            set(obj.h.pb.settingsPlot4,'Callback',@(hobj,event) obj.plotSettings('plot4'));
            set(obj.h.pb.enablePlot1,'Callback',{@obj.plotQuickEnable,'plot1'});
            set(obj.h.pb.enablePlot2,'Callback',{@obj.plotQuickEnable,'plot2'});
            set(obj.h.pb.enablePlot3,'Callback',{@obj.plotQuickEnable,'plot3'});
            set(obj.h.pb.enablePlot4,'Callback',{@obj.plotQuickEnable,'plot4'});

            % record tab
            set(obj.h.pb.process,'Callback',@(hobj,event) obj.process());
            set(obj.h.pb.processFrame,'Callback',@(hobj,event) obj.processFrame());
            set(obj.h.pb.saveResults,'Callback',@(hobj,event) obj.saveResults());
            
            % arm help requests
            set(obj.h.panel.inputMain,'HelpFcn', @(hobj,event) obj.getHelp('input'))
            set(obj.h.panel.settingsMain,'HelpFcn', @(hobj,event) obj.getHelp('settings'))
            set(obj.h.panel.record,'HelpFcn', @(hobj,event) obj.getHelp('record'))
            
            % close request
            set(obj.h.fig,'CloseRequestFcn',@(hobj,event) obj.closeGui);
        end
        
        function var = get.guiState(obj)
            switch obj.h.panel.inputTab.Selection
                case 1
                    var = 'fokuspokus';
                case 2
                    var = 'standalone';
            end
        end
        
        function var = get.imstackReady(obj)
            var = false;
            if ~isempty(obj.imstack)
                var = true;
            end
        end
        
        function var = get.resultsReady(obj)
            var = false;
            if ~isempty(obj.results)
                var = true;
            end
        end
        
        function var = get.gcamReady(obj)
            var = false;
            if ~isempty(obj.gige)
                if obj.gige.isconnected && obj.gige.hotpixelDetected &&...
                        obj.gige.roiIsActive && obj.gige.BGcorrectionEnabled && isfolder(obj.workingFolder)
                    var = true;
                end
            end
        end
        
        function var = get.etalonsReady(obj)
            var = false;
            if ~isempty(obj.etalonSpec)
                var = true;
            end
        end
        
        function var = get.figexists(obj)
            var = false;
            if isfield(obj.h,'fig')
                if isvalid(obj.h.fig)
                    var = true;
                end
            end
        end
        
        function val = get.wavelength(obj)
            if obj.wavelength <= 0
                val = [];
            else
                val = obj.wavelength;
            end
        end
        
        function analysisSettings(obj)
            fokpokgui.analysisSettings(obj.imstack.settings);
            if obj.imstackReady
                if ~obj.imstack.settings.ROI.autoROI &&...
                        ~obj.imstack.settings.ROI.guiROI &&...
                        ~isempty(obj.imstack.img.ROI)
                    answer = questdlg(['\fontsize{12}Neither autoROI nor guiROI is enabled, but ROIs exist from a previous evaluation. ',...
                        'As long as these ROIs exist, they will be used during processing. ',...
                        'Do you wish to delete all existing ROIs?'],'fileSelector','Delete ROIs','Keep ROIs',...
                        struct('Interpreter','tex','Default','Keep ROIs'));
                    switch answer
                        case 'Delete ROIs'
                            obj.imstack = obj.imstack.resetROI();
                        case {'Keep ROIs',''}
                            return
                    end
                end
            end 
        end
        
        function plotSettings(obj,type)
            fokpokgui.plotSettings(obj.imstack.figs.(type).settings);
            % if user enabled a FIG and the required data exists then
            % generate that plot based on the existing data once the
            % settings gui is closed
            if obj.imstackReady && obj.imstack.processed
                dontCount = true; % for readability
                if obj.imstack.figs.(type).settings.enable
                    % this is nasty but it works because "type" is identical to the method name
                    obj.imstack.(type)(dontCount);
                end
                obj.imstack.plotCallbacks(true);
                
                % update quick enable buttons
                obj.h.pb.enablePlot1.Value = obj.imstack.figs.plot1.settings.enable;
                obj.h.pb.enablePlot2.Value = obj.imstack.figs.plot2.settings.enable;
                obj.h.pb.enablePlot3.Value = obj.imstack.figs.plot3.settings.enable;
                obj.h.pb.enablePlot4.Value = obj.imstack.figs.plot4.settings.enable;
            end
        end
        
        function plotQuickEnable(obj,src,~,type)
            if obj.imstackReady
                obj.imstack.figs.(type).settings.enable = src.Value;
                if obj.imstack.processed
                    dontCount = true; % for readability
                    if obj.imstack.figs.(type).settings.enable
                        % this is nasty but it works because "type" is identical to the method name
                        obj.imstack.(type)(dontCount);
                    end
                    obj.imstack.plotCallbacks(true);
                end
            end
            src.Value = obj.imstack.figs.(type).settings.enable;
        end
                
        function getHelp(obj,type)
            switch type
                case 'input'
                    switch obj.guiState
                        case 'fokuspokus'
                            msgbox({'\fontsize{11}{\bfConnect} \color{red}Mandatory to proceed\color{black} Establish connection to gigecam PhotonFocus MV1-D2080.','',...
                                '{\bfWavelength} \color{red}Mandatory to proceed','\color{black}Required to calculate beam splitter optical path lengths as function of refractive index. Wavelength is required to evaluate Sellmeier equation.','',...
                                '{\bfCamViewer} Optional / use during adjustment procedure. Available settings depend on state of camera.','',...
                                '{\bfBeam Splitter Configuration} \color{red}Mandatory to proceed','\color{black}Specify the beam splitter that is currently installed using defaults / specify custom beam splitter / specify ROI Grid.','',...
                                ['{\bfCamWizard} \color{red}Mandatory to proceed',char(10),'\color{black}Guides user through complete setup.',...
                                ' After wizard completion the camera background correction / exposure / blacklevel MUST NOT be modified, otherwise you will be forced to re-run the wizard.',...
                                ' Hotpixeldetection and ROI Selection are required only on first run. If needed, refine the ROI using ROISelector separately',char(10),...
                                '{\bfImportant:} AutoExposure only uses values INSIDE ROIs which are NOT HotPixels. Ensure that the beams are inside the ROIs when attempting AutoExposure',char(10),...
                                '\color{magenta}If the wizard fails during AutoExposure, try to re-run the wizard after modifying the optical setup and/or modify blacklevel/exposure using CamViewer.\color{black}'],'',...
                                '{\bfROISelector}','Allows user to adjust ROIs independent of CamWizard. CamWizard should be run first because ROISelector is a part of CamWizard.','',...
                                '{\bfOutputDir} \color{red}Mandatory to proceed','\color{black}All output files (results,figures) will be placed here.','',...
                                '{\bfDisconnect}','Clears and disconnects camera. Must be used if camera is to be accessed in another application while MATLAB engine is running.',...
                                },'fokpokgui.guiMain', 'help',struct('Interpreter','tex','WindowStyle','modal'))
                        case 'standalone'
                            msgbox({'\fontsize{11}In this mode image files can be selected for analysis.',...
                                'All output files (results,figures) will be placed in subfolder \\results\\ inside the directory of the image files.',...
                                '','The code attempts to extract the z-position from the filename by removing all non-numeric characters and converting to numeric value + correcting for the scale [m,mm,µm].',...
                                '','e.g.: "abcd\_z-0.5mm\_abcd.bmp" is converted to -0.5, but "1\_1030nm\_z0.5.bmp" gets converted to 110300.5.',...
                                },...
                                'fokpokgui.guiMain', 'help',...
                                struct('Interpreter','tex','WindowStyle','modal'))
                    end
                case 'settings'
                    msgbox({'\fontsize{11}{\bfAnalysis}','For online analysis consider the CPU time impact of some settings (especially AutoROI update interval and median filter).','',...
                        ['{\bfPlots}',char(10),'The same applies here: Avoid exporting/updating plots often during online analysis. Rendering the graphics and saving figs/png is a major time expense.',...
                        ' Consider e.g. updating figures rarely and/or record the screen using external software like OBS Studio / ShareX.'],...
                        },'fokpokgui.guiMain', 'help',struct('Interpreter','tex','WindowStyle','modal'))
                case 'record'
                    str = {'\fontsize{11}{\bfProcess}','\color{red}FokusPokus\color{black} = Process frames and record data indefinitely. If you pause and start again results will be appended.',...
                        '\color{red}Standalone\color{black} = Process and record data.','',...
                        ['\fontsize{11}{\bfTest / Single Shot}',char(10),'This will process one single frame but will not record results internally.',...
                        'This is meant for debugging and/or setting up your figures.'],'',...
                        '\fontsize{11}{\bfSave/Export Results}','Export all collected results as .mat and .xlsx. This will also reset all counters and timers in case of FokusPokus mode.',...
                        'The .mat file contains additional data which is not available in the .xlsx table.',...
                        };
                    if obj.imstackReady && obj.imstack.processed && (obj.imstack.counter > 1)
                        str = [str,{''},{'{\bfStats}',sprintf('Time spent on calculation: %2.1f%%, plots: %2.1f%%.\nAverage evaluation = %.2f Hz, effective = %.2f Hz.',...
                                                                 obj.imstack.stats.AnalysisVSPlot(1),obj.imstack.stats.AnalysisVSPlot(2),1/obj.imstack.stats.tcalcAnalysisAVG,1/(obj.imstack.stats.tcalcAnalysisAVG+obj.imstack.stats.tcalcPlotAVG))}];
                    end
                    msgbox(str,...
                        'fokpokgui.guiMain', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
            end
        end
        
        function guiSetPopup(obj,type)
            switch type
                case 'scaleXY'
                    obj.settings.scale(1) = obj.scale_val(obj.h.popup.scaleXY.Value);
            end
        end
        
        function guiSetCheckBox(obj,type)
            switch type
                case 'enable'
                    obj.settings.enable = obj.h.chkBox.enable.Value;
            end
        end
        
    end
    
    methods (Access = private)
        
        % defined externally
        initfig(obj)
        updateStateOfGui(obj);
        
        function process(obj,attemptRestart)
            if nargin == 1
                attemptRestart = 1;
            end
            obj.changeAllButtonState(false,{'process'})
            obj.imstack.plotCallbacks(false);
            obj.imstack.figs.interactive = 0;
            obj.imstack.dontCountOrSave = 0;
            try
                switch obj.guiState
                    case 'fokuspokus'
                        if obj.h.pb.process.Value && (obj.imstack.counter == 1)
                            obj.gige.resetCounter();
                        end
                        % profile on
                        while obj.h.pb.process.Value
                            obj.h.fig.Name = sprintf('%i',obj.imstack.counter);
                            obj.gige.grabFrame();
                            obj.imstack.time = obj.gige.time;
                            obj.imstack = obj.imstack.process(obj.gige.IMGstackSorted);
                            obj.results = obj.results.record(obj.imstack);
                        end
                        % profile viewer
                    case 'standalone'
                        obj.imstack = obj.imstack.process();
                        obj.results = obj.results.record(obj.imstack);
                        obj.h.pb.process.Value = 0;
                end
            catch ME
                if attemptRestart
                    attemptString = 'Attempting to start processing again ONCE.';
                elseif ~attemptRestart
                    attemptString = 'Attempt to restart processing has failed. Aborting.';
                end
                errorMessage = sprintf('Error in %s() at line %i.\n%s\n%s',...
                                        ME.stack(1).name, ME.stack(1).line, ME.message, attemptString);
                warndlg(errorMessage,'guiMain.m');
                fprintf(1, '%s\n', errorMessage);
                if attemptRestart
                    pause(1)
                    obj.process(0);
                end
            end
            obj.imstack.plotCallbacks(true);
            obj.imstack.figs.interactive = 1;
            obj.changeAllButtonState(true,{'process'})
            obj.h.fig.Name = 'fokpokgui';
        end
        
        function processFrame(obj)
            obj.imstack.plotCallbacks(false);
            obj.changeAllButtonState(false,{''})
            obj.imstack.dontCountOrSave = 1;
            try
                switch obj.guiState
                    case 'fokuspokus'
                        obj.gige.grabFrame();
                        obj.imstack = obj.imstack.process(obj.gige.IMGstackSorted);
                    case 'standalone'
                        obj.imstack = obj.imstack.process();
                end
            catch ME
                errorMessage = sprintf('Error in function %s() at line %i.\n%s', ...
                                        ME.stack(1).name, ME.stack(1).line, ME.message);
                fprintf(1, '%s\n', errorMessage);
                warndlg(errorMessage);
            end
            obj.imstack = obj.imstack.resetCounter();
            obj.imstack.plotCallbacks(true);
            obj.imstack.figs.interactive = 1;
            obj.h.pb.process.Value = 0;
            obj.changeAllButtonState(true,{''})
        end
        
        function saveResults(obj)
            obj.results = obj.results.exportResults();
            obj.imstack = obj.imstack.resetCounter();
        end
        
        function initFokPok(obj)
            % this is called by obj.updateStateOfGui() if all conditions
            % for succesful fokuspokus mode are met
            
            % there are some conditions when special care must be taken
            % a) everything was already initialized, maybe nothing
            % important has changed and we can skip initializtion
            % b) workgingFolder changed, since results need to be
            % initialized with a linked folder (tmp files), we must ask
            % user first if existing stuff should be exported
            % c) wavelength changed, since it affects zpos same applies
            % d) pixelpitch is static, so no need
            if obj.imstackReady && obj.resultsReady
                if ~isequal(obj.imstack.workingFolder,obj.workingFolder) || ~isequal(obj.imstack.wavelength,obj.etalonSpec.laserWavelength) || ~isequal(obj.imstack.zPos,obj.gige.OPDroiSorted)
                    obj.askUserExportResultsBeforeReinitialize();
                else
                    % nothing changed, don't do anything
                    return
                end
            end
            
            % this must be done ONCE
            if isempty(obj.imstack)
                obj.imstack = imgstack.imstack();
                obj.imstack.figs.plot2.settings.enable = 1;
            end
            
            obj.imstack.pixelpitch = obj.gige.pixelSize;
            obj.imstack.wavelength = obj.etalonSpec.laserWavelength;
            obj.imstack.zPos = obj.gige.OPDroiSorted;
            obj.imstack.workingFolder = obj.workingFolder;
            obj.results = imgstack.aioResults(obj.imstack);
        end
        
        function askUserExportResultsBeforeReinitialize(obj)
            export = false;
            answer = questdlg({'\fontsize{12}The output {\bfdirectory} and/or {\bfwavelength} and/or {\bfbeam splitter configuration} has changed. Internal data structures must be reinitialized, unsaved progress will be lost!','',...
                'Do you wish to export existing unsaved results to the previous directory first?'},...
                'guiMain.askUser','Export and continue','Continue',...
                struct('Interpreter','tex','Default','Continue'));
            switch answer
                case 'Export and continue'
                    export = true;
            end
            if export
                obj.saveResults()
            end
        end
        
        function startFileSelector(obj)
            out = fokpokgui.fileSelector;
            if out.success
                if isempty(obj.imstack)
                    obj.imstack = imgstack.imstack();
                end
                obj.imstack.wavelength = out.wavelength;
                obj.imstack.zPos = out.zPos_export;
                obj.imstack.pixelpitch = out.pixelpitch;
                obj.imstack.workingFolder = out.workingFolder;
                obj.imstack.currentIMG = out.images_export;
                obj.imstack.figs.plotAll(true);
                obj.imstack.settings.ROI.updateEveryNframes = 1;
                obj.imstack.settings.denoise.freqfilt = 1;
                obj.results = imgstack.aioResults(obj.imstack);
            end
            updateStateOfGui(obj);
        end
        
        function checkEditBoxes(obj,hobj,event,type)
            input = str2num(strrep(hobj.String,',','.')); %#ok<ST2NM>
            if isempty(input) || ~isscalar(input) || ~isfinite(input)
                hobj.String = [];
                return
            else
                hobj.String = input;
            end
            switch type
                case 'wavelength'
                    obj.wavelength = input*1e-9;
                    if obj.etalonsReady
                        obj.etalonSpec.laserWavelength = obj.wavelength;
                    end
                    if obj.imstackReady && obj.resultsReady
                        warndlg({['\fontsize{11}You have modified the wavelength \lambda after a previous analysis.',...
                                 ' This changes the optical path distances, as the refractive index n of the beam splitters is a function of the wavelength \lambda.'],...
                                 'Beam splitter configuration has been updated with the new wavelength. You must re-do ROI Selection in order to update the z-Positions of the caustic and the wavelength used for the fit!'},...
                            'fokpokgui.guiMain',struct('Interpreter','tex','WindowStyle','modal'));
                    end
            end
        end
        
        function closeGui(obj)
            if obj.figexists
                if ~isempty(obj.gige) && obj.gige.isconnected
                    obj.gige.disconnect()
                end
                delete(obj.h.fig)
            end
        end
        
        function SelectionChanged(obj)
            % first change figsize
            val = obj.h.panel.inputTab.Selection; % 1: fokpok, 2: standalone
            if val == 1 % 1 = fokpok
                obj.h.fig.Position(4) = 565;
                obj.h.mainLayout.Heights = [300,180,90];
                obj.h.fig.Position(2) = obj.h.fig.Position(2)+355-565;
            elseif val == 2 % 2 = standalone
                obj.h.fig.Position(4) = 355;
                obj.h.mainLayout.Heights = [85,180,90];
                obj.h.fig.Position(2) = obj.h.fig.Position(2)+565-355;
            end
            obj.updateStateOfGui();
        end
        
        function connectCam(obj)
           if isempty(obj.gige)
              obj.gige = gcam(); 
           end
           obj.gige.connect();
           obj.updateStateOfGui()
        end
        
        function camPreview(obj)
           if ~isempty(obj.gige) && obj.gige.isconnected
              fokpokgui.camPreview(obj.gige);
           else
               warndlg('\fontsize{11}Camera is not connected.','fokpokgui.guiMain',struct('Interpreter','tex','WindowStyle','modal'));
           end
           obj.updateStateOfGui()
        end
        
        function initEtalonSpec(obj)
            if isempty(obj.wavelength)
                warndlg({['\fontsize{11}Wavelength \lambda must be set first.',...
                    ' The refractive index n of the beam splitters is a function of the wavelength \lambda.'],...
                    'The optical path lenghts are calculated as internal variables at this point, the wavelength is required!'},...
                    'fokpokgui.guiMain',struct('Interpreter','tex','WindowStyle','modal'));
                return
            end
            if ~obj.etalonsReady
                userSpec = fokpokgui.etalonSpecSelector(obj.wavelength);
            else
                userSpec = fokpokgui.etalonSpecSelector(obj.etalonSpec);
            end
            if userSpec.success
                if obj.etalonsReady
                    warndlg({'\fontsize{11}You have modified an existing beam splitter / ROI grid configuration.','',...
                        'This changes the optical path distances, as the refractive index n of the beam splitters is a function of the wavelength \lambda.',...
                        'Beam splitter configuration has been updated.','','\color{red}You must re-do ROI Selection in order to update the z-Positions of the caustic and the wavelength used for the fit!'},...
                        'fokpokgui.guiMain',struct('Interpreter','tex','WindowStyle','modal'));
                end
                obj.etalonSpec = userSpec.etalonSpec;
                obj.updateStateOfGui();
            end
        end
        
        function camWizard(obj)
            if ~isempty(obj.gige) && obj.gige.isconnected && obj.etalonsReady
                obj.gige.camSetupWizard(obj.etalonSpec);
            else
                warndlg(obj.getErrorString('cam'),'fokpokgui.guiMain',struct('Interpreter','tex','WindowStyle','modal'));
            end
            obj.updateStateOfGui()
        end
        
        function roiSelector(obj)
            if ~isempty(obj.gige) && obj.gige.isconnected && obj.etalonsReady
                abort = obj.gige.ROIselector(obj.etalonSpec);
                
                % if image correction is enabled then user had already completet cam wizard
                % data in the new ROIs might be over/underexposed, prompt warning / todos for user
                currentExposureResult = obj.gige.calcExposureResult;
                if ~abort && obj.gige.BGcorrectionEnabled && ((currentExposureResult > 0.9*obj.gige.grayLevelLims(2)) || (currentExposureResult < 0.5*obj.gige.grayLevelLims(2)))
                    warndlg({'\fontsize{11}You have modified an existing ROI grid configuration while camera Background/Hotpixel detection is active.','',...
                        'The image/beam profiles inside the new ROIs are (or are close to) being overexposed or underexposed.','','\color{red}You must re-run the Cam Wizard in order to find the correct exposure/blacklevel and re-do the Background/Hotpixel correction!'},...
                        'fokpokgui.guiMain',struct('Interpreter','tex','WindowStyle','modal'));
                end
            else
                warndlg(obj.getErrorString('cam'),'fokpokgui.guiMain',struct('Interpreter','tex','WindowStyle','modal'));
            end
            obj.updateStateOfGui()
        end
        
        function requestFolder(obj)
            selpath = uigetdir(path,'Select a folder for the results/export.');
            if selpath == 0
                hfig = warndlg('\fontsize{11}A working directory MUST be selected.',...
                    'fokpokgui.guiMain',struct('Interpreter','tex','WindowStyle','modal'));
                waitfor(hfig);
                obj.requestFolder();
            else
                obj.workingFolder = selpath;
            end
            obj.updateStateOfGui()
        end
        
        function disconnectCam(obj)
            if ~isempty(obj.gige)
                obj.gige.disconnect();
                obj.gige = gcam.empty;
            end
            obj.updateStateOfGui();
        end
        
    end
    
    methods (Access = public)
        function changeAllButtonState(obj,flag,exception)
            if nargin < 3
                exception = '';
            end
            % disables buttons except "exception" button(s)
            switch flag
                case true
                    buttonState = 'on';
                case false
                    buttonState = 'off';
            end
            fns = fieldnames(obj.h.pb);
            fns = fns(~ismember(fns,exception));
            for field = fns.'
                obj.h.pb.(field{:}).Enable = buttonState;
            end
            obj.h.edit.wavelength.Enable = buttonState;
        end
        
        function string = getErrorString(obj,type)
            string = {};
            switch type
                case 'cam'
                    if isempty(obj.gige) || ~obj.gige.isconnected
                        string{1} = '\fontsize{11}Camera is not connected.';
                    end
                    if ~obj.etalonsReady
                        string{2} = '\fontsize{11}Beam splitter configuration is required.';
                    end
                case 'standalone'
                    % not used atm
            end
            string = string(~cellfun(@isempty, string));
        end
    end
    
    methods (Static, Access = private)        
    end
    
    methods(Static, Access = public)
        function promptError(err)
            errordlg(sprintf('Error during fokpokgui.guiMain.process. Processing has been disabled.\nMessage: %s.\nIdentifier: %s.',err.message,err.identifier),...
                    'fokpokgui.guiMain.process','modal')
        end
        
        function warnOldVersion()
            if isMATLABReleaseOlderThan("R2021a")
                developVersion = '9.10.0.1669831 (R2021a) Update 2';
                errordlg(sprintf('This Software was written with MATLAB %s. Your current version is Matlab %s. Running this Software with an outdated MATLAB installation may produce unexpected errors. Use at your own risk.',...
                    developVersion,version),...
                    'fokpokgui.guiMain.warnOldVersion','modal')
            end
        end
    end
    
end
