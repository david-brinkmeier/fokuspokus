classdef fit < handle
    
    properties (Access = public)
        weighted            (1,1) logical
        weightedVariance    (1,1) logical
        minWeightVariance   (1,1) double    % < 1! if single measurement then weight 1, highest variance in set gets minWeightVariance!
        fixEdgeCase         (1,1) logical
    end
    
    properties (SetAccess = protected)
    end
    
    properties (Access = private)
    end
    
    properties (Dependent)
    end
    
    methods
        % constructor and/or resetter
        function obj = fit()
            obj.weighted = true;
            obj.weightedVariance = false;
            obj.minWeightVariance = 0.25;
            obj.fixEdgeCase = true;
        end
        
        function set.minWeightVariance(obj,val)
            if obj.isInRange(val,[0.25,1])
                obj.minWeightVariance = val;
            else
                warning('minWeightVariance must be in range 0.25-1; defaulting to 0.25');
                obj.minWeightVariance = 0.25;
            end
        end
    end
    
    %% private
    methods (Access = private)
    end
    
    %% static
    methods (Static)
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
    
end