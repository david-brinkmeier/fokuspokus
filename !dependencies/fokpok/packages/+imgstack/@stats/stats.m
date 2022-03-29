classdef stats
    % holds settings specific to plots
    
    properties (Access = public)
    end
    
    properties (SetAccess = protected)
        tcalcAnalysisTotal      (1,1) double
        tcalcAnalysisLastIter   (1,1) double
        tcalcPlotTotal          (1,1) double
        tcalcPlotLastIter       (1,1) double
        guiROIcounter           (1,1) uint32
        autoROIcounter          (1,1) uint32
    end
    
    properties (Access = private)
        counter                 (1,1) uint32
    end
    
    properties (Dependent, GetAccess = public)
        tcalcAnalysisAVG        (1,1) double
        tcalcPlotAVG            (1,1) double
        AnalysisVSPlot          (1,2) double
    end
    
    methods
        % constructor and/or resetter
        function obj = stats()
            obj.counter = 0;
            obj.tcalcAnalysisTotal = 0;
            obj.tcalcAnalysisLastIter = 0;
            obj.tcalcPlotTotal = 0;
            obj.guiROIcounter = 0;
            obj.autoROIcounter = 0;
        end
        
        %% setter
        
        
        %% getter
        function val = get.tcalcAnalysisAVG(obj)
            val = obj.tcalcAnalysisTotal/double(obj.counter);
        end
        
        function val = get.tcalcPlotAVG(obj)
            val = obj.tcalcPlotTotal/double(obj.counter);
        end
        
        function val = get.AnalysisVSPlot(obj)
           val = 100*[obj.tcalcAnalysisTotal/(obj.tcalcAnalysisTotal+obj.tcalcPlotTotal),...
                      obj.tcalcPlotTotal/(obj.tcalcAnalysisTotal+obj.tcalcPlotTotal)];
           
        end
        
    end
    
    %% private
    methods (Access = public)
        function obj = updatestats(obj,tAnalysis,tPlot,guiROIdone,autoROIdone)
            % analysis times
            obj.tcalcAnalysisTotal = obj.tcalcAnalysisTotal + tAnalysis;
            obj.tcalcAnalysisLastIter = tAnalysis;            
            % plots times
            obj.tcalcPlotTotal = obj.tcalcPlotTotal + tPlot;
            obj.tcalcPlotLastIter = tPlot;
            % count calls to guiROI/autoROI
            if guiROIdone
                obj.guiROIcounter = obj.guiROIcounter+1;
            end
            if autoROIdone
                obj.autoROIcounter = obj.autoROIcounter+1;
            end
            % advance ocunter
            obj.counter = obj.counter+1;
        end
        
    end
    
    %% static
    methods (Static)
    end
    
end