classdef denoiseGaussian < handle
    
    properties (Access = public)
        enable          (1,1) logical
        sigma           (1,1) double    % 0-3; 0 means disabled but thresholding still applied!
        percentile      (1,1) double    % all remaining values below [percentile] are set to zero; (percentile >= 0 & percentile <= 100)
    end
    
    properties (SetAccess = protected)
    end
    
    properties (Access = private)
    end
    
    properties (Dependent)
    end
    
    methods
        % constructor and/or resetter
        function obj = denoiseGaussian()
            obj.enable = 0;
            obj.sigma = 1;
            obj.percentile = 5;
        end
        
        function set.sigma(obj,input)
            if (input >= 0 && input <= 3)
                obj.sigma = input;
            else
                warning('sigma must be in range 0-3, ignoring input %i, value remains at %i',input,obj.sigma)
            end
        end
        
        function set.percentile(obj,input)
            if (input >= 0 && input <= 100)
                obj.percentile = input;
            else
                warning('percentile must be in range 0-100, ignoring input %i, value remains at %i',input,obj.percentile)
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