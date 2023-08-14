classdef imgcontainer
    
    properties (Access = public)
        src             (:,:,:) double
        denoised        (:,:,:) double
        translated      (:,:,:) double
        lowpass_freqfilt(:,:,:) double
        ROI             (:,1)   cell    % cell of masks!
    end
    
    properties (SetAccess = private)
        ROIenabled      (1,1)   logical
    end
    
    properties (SetAccess = private, GetAccess = public, Hidden)
        % only required for xc,yc results output
        xstartOffset    (1,:)   double
        ystartOffset    (1,:)   double
    end
    
    properties (Dependent)
    end
    
    %%
    methods
        function obj = imgcontainer()
        end
        
        function obj = set.ROI(obj,val)
           obj.ROI = val;
           obj = obj.verifyChange();
        end
    end
       
    methods (Access = private)
        
        function obj = verifyChange(obj)
            if ~isempty(obj.ROI)
                obj.ROIenabled = true;
                obj.xstartOffset = cellfun(@(val) val.xstart-1, obj.ROI.');
                obj.ystartOffset = cellfun(@(val) val.ystart-1, obj.ROI.');
            else
                obj.ROIenabled = false;
                obj.xstartOffset = [];
                obj.ystartOffset = [];
            end
        end
        
    end
    
end