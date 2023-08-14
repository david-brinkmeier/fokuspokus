classdef ROI < handle
    
    properties (Access = public)
        sensitivity         (3,1) double    % [grad,dev,energy] 0 to 100%
        shortCircuit        (1,1) logical   % attempt to exit autoROI early
        offset              (1,1) uint32    % pixel offset applies to autoROI
        updateEveryNframes  (1,1) uint32    % only applies to autoROI
        debug               (1,1) logical
    end
    
    properties (Access = public, Hidden)
    end
    
    properties (SetAccess = protected)
    end
    
    properties (Access = private)
        guiROIenabled       (1,1) logical   % internal: check conflicts if both methods are enabled
        autoROIenabled      (1,1) logical   % internal: check conflicts if both methods are enabled
    end
    
    properties (Dependent)
        guiROI              (1,1) logical   % enables guiROI
        autoROI             (1,1) logical   % enables autoROI
    end
    
    methods
        % constructor and/or resetter
        function obj = ROI()
            obj.debug = 0;
            obj.guiROI = 0;
            obj.autoROI = 1;
            obj.sensitivity = [1.5,2.5,95];
            obj.shortCircuit = true;
            obj.offset = 3;
            obj.updateEveryNframes = 30;
            obj.debug = 0;
        end
        
        function set.updateEveryNframes(obj,input)
            if input < 1
                input = 1;
            end
            obj.updateEveryNframes = input;
        end
        
        function set.sensitivity(obj,input)
            % limit input to 0-100 for each element
            sens = nan(1,length(input));
            last = obj.sensitivity;
            isinrange = (input >= 0) & (input <= 100);
            sens(isinrange) = input(isinrange);
            sens(~isinrange) = last(~isinrange);
            obj.sensitivity = sens;
        end
        
        function set.guiROI(obj,input)
            obj.guiROIenabled = input;
            if obj.guiROIenabled == true
                obj.autoROIenabled = false;
            end
        end
        
        function set.autoROI(obj,input)
            obj.autoROIenabled = input;
            if obj.autoROIenabled == true
                obj.guiROIenabled = false;
            end
        end
        
        function val = get.guiROI(obj)
            val = obj.guiROIenabled;
        end
        
        function val = get.autoROI(obj)
            val = obj.autoROIenabled;
        end
        
    end
    
    %% private
    methods (Access = private)
    end
    
    %% static
    methods (Static)

    end
    
end