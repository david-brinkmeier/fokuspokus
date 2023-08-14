classdef denoise < handle
    
    properties (Access = public)
        freqfilt            (1,1) logical
        removeplane         (1,1) logical   % if enabled then assumes background is a tilted plane and this plane is removed
                                            % if disabled then just remove mean of the values inside mask
        fitsamples          (1,1) uint32    % limits samples used for plane fitting. heavy impact beyond ~ 250 samples or so
        fitvariant          (1,:) char      % selects algorithm for rmbackground; either eig (fast) or svd (slow)
        ndev                (1,1) double    % per iso11146: (ndev >= 0 & ndev <= 4)
        median              (1,1) double    % must be ismember(median,[1,3,5])
        gaussian            (1,1) settings.denoiseGaussian
        debug               (1,1) logical
    end
    
    properties (SetAccess = protected)
    end
    
    properties (Access = private)
    end
    
    properties (Dependent)
    end
    
    methods
        % constructor and/or resetter
        function obj = denoise()
            obj.freqfilt = 0;
            obj.removeplane = 1;
            obj.ndev = 1;
            obj.median = 1;
            obj.gaussian = settings.denoiseGaussian();
            obj.debug = 0;
            obj.fitsamples = 500;
            obj.fitvariant = 'eig';
        end
        
        function set.fitvariant(obj,input)
            input = lower(input);
            if ismember(input,{'eig','svd'})
                obj.fitvariant = input;
            else
                obj.fitvariant = 'eig';
                warning('Attempt to set fitvariant as "%s". Allowed are only "eig" and "svd". Defaulting to "eig".',input)
            end
        end
                
        function set.fitsamples(obj,input)
            if input <= 0
                warning('Attempt to set zero or negative number of fitsamples. Defaulting to 200.')
                obj.fitsamples = 500;
            elseif input < 10
                warning('Attempt to set < 10 fitsamples. Limiting to a minimum of 10. 200 recommended.')
                obj.fitsamples = 10;
            else
                obj.fitsamples = input;
            end
        end
        
        function set.ndev(obj,input)
            if (input >= 0 && input <= 4)
                obj.ndev = input;
            else
                warning('ndev out of ISO11146 sanctioned range 0-4, ndev remains at %.2f',obj.ndev)
            end
        end
        
        function set.median(obj,input)
            if ~isdeployed && (~contains(struct2array(ver),'Image Processing Toolbox') || ~license('test','image_toolbox')) % this confirms BOTH license and actual install of toolbox exists
                warndlg('\fontsize{11}2D Median filter is unavailable because Image Processing Toolbox is missing or unlicensed.','settings.denoise',struct('Interpreter','tex','WindowStyle','modal'));
                obj.median = 1;
                return
            end
            
            isallowed = [1,3,5];
            if ismember(input,isallowed)
                obj.median = input;
            else
                warning(sprintf('allowed values for median are [%i,%i,%i], ignoring user value %i, median remains at %i',...
                                isallowed,input,obj.median)); %#ok<SPWRN>
            end
        end
            
    end
    
    %% private
    methods (Access = private)
        
    end
    
    %% static
    methods (Static)

    end
    
end