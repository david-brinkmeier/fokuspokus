classdef axiscontainer
    
    properties (Access = public)
        src         (1,1) imgstack.axisdef
        denoised    (1,1) imgstack.axisdef
    end
    
    properties (SetAccess = protected)
    end
    
    properties (Access = private)
    end
    
    properties (Dependent)
    end
    
    %%
    methods
        function obj = axiscontainer()
        end  
    end
    
end