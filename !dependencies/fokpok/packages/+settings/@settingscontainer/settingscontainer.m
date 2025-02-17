classdef settingscontainer < handle
    % holds all settings
    
    properties (Access = public)
        ROI             (1,1)   settings.ROI
        denoise         (1,1)   settings.denoise
        moments         (1,1)   settings.moments
        center          (1,1)   settings.center
        fit             (1,1)   settings.fit
    end
    
    properties (SetAccess = protected)
        ImageProcessingToolbox (1,1) logical
    end
    
    properties (Access = private)
    end
    
    properties (Dependent)
    end
    
    methods
        % constructor and/or resetter
        function obj = settingscontainer()
            obj.ROI = settings.ROI();
            obj.denoise = settings.denoise();
            obj.moments = settings.moments();
            obj.center = settings.center();
            obj.fit = settings.fit();
            obj.ImageProcessingToolbox = true;
            
            if ~isdeployed && ~license('test','image_toolbox') % this confirms BOTH license and actual install of toolbox exists
                obj.ImageProcessingToolbox = false;
                warndlg('\fontsize{11}Image Processing Toolbox is missing or unlicensed. Some features have been disabled. Some debugging features will lead to unexpected errors when enabled.',...
                        'settings',struct('Interpreter','tex','WindowStyle','modal'));
            end
        end
    end
    
    %% private
    methods (Access = public)
        
        function debugAll(obj,enable)
            if enable
                obj.ROI.debug = 1;
                obj.denoise.debug = 1;
                obj.moments.debug = 1;
                obj.center.debug = 1;
            else
                obj.ROI.debug = 0;
                obj.denoise.debug = 0;
                obj.moments.debug = 0;
                obj.center.debug = 0;
            end
        end
        
        function abort = checkSettingsConflicts(obj,imstack)
            if ~isa(imstack,'imgstack.imstack')
                error('settingscontainer requires imstack to be passed')
            end
            abort = false;
            if isempty(imstack.img.ROI)
                if ~obj.ROI.autoROI && ~obj.ROI.guiROI && obj.denoise.freqfilt
                    answer = questdlg({'\fontsize{12}Frequency domain filtering is active but ROI is/are disabled/nonexistant.',...
                        'FFT-boundary effects can massively impact the analysis. It is advised to use ROIs or disable FFT-filtering.'},...
                        'imgstack.settingscontainer','Continue anyway','Abort',...
                        struct('Interpreter','tex','Default','Continue anyway'));
                    if strcmp(answer,'Abort')
                        abort = true;
                    end
                end
            end
        end
    end
    
    methods (Access = private)
    end
    
    %% static
    methods (Static)
    end
    
end