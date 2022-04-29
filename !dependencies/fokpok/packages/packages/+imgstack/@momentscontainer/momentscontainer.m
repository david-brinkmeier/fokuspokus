classdef momentscontainer
    
    properties (Access = public)
        denoised    imMoments
        translated  imMoments
    end
    
    properties (SetAccess = protected)
    end
    
    properties (Access = private)
    end
    
    properties (Dependent)
    end
    
    %%
    methods
        function obj = momentscontainer()
        end  
    end
    
end