classdef axisdef
    
    properties (Access = public)
        x (1,:) double
        y (1,:) double
        z (1,:) double
    end
    
    properties (SetAccess = protected)
    end
    
    properties (Access = private)
    end
    
    properties (Dependent)
    end
    
    methods
        % constructor and/or resetter
        function obj = axisdef()
        end
    end
    
    %% private
    methods (Access = private)
        
    end
    
    %% static
    methods (Static)

    end
    
end