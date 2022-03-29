classdef moments < handle
    % first and second centered moments in unit/pixel coordinates per
    % ISO 11146 specification
    
    properties (Access = public)
        debug           (1,1) logical
    end
    
    properties (SetAccess = protected)
    end
    
    properties (Access = private)
    end
    
    properties (Dependent)
    end
    
    methods
        % constructor and/or resetter
        function obj = moments()
            obj.debug = 0;
        end
    end
    
    %% private
    methods (Access = private)
        
    end
    
    %% static
    methods (Static)

    end
    
end