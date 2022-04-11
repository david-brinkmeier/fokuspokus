classdef center < handle
    
    properties (Access = public)
        debug           (1,1) logical
        normalize       (1,1) logical % if true then each image is normalized by its corresponding maximum value
    end
    
    properties (SetAccess = protected)
    end
    
    properties (Access = private)
    end
    
    properties (Dependent)
    end
    
    methods
        % constructor and/or resetter
        function obj = center()
            obj.debug = 0;
            obj.normalize = 1;
        end
    end
    
    %% private
    methods (Access = private)
        
    end
    
    %% static
    methods (Static)

    end
    
end