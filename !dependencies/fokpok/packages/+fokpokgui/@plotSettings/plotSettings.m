classdef plotSettings < handle
    
    properties (SetAccess = private, GetAccess = public)
        h                                 struct
        settings                          plots.plotsettings
    end
    
    properties (SetAccess = private, GetAccess = private)
    end
    
    properties (Dependent, Access = public)
        figexists                   (1,1) logical
    end
    
    properties (Constant, Access = private)
        scale_val = [1,1e3,1e6];
        scale_str = {'m','mm','µm';'rad','mrad','µrad'};
    end
    
    methods
        function obj = plotSettings(settings)
            if ~isa(settings,'plots.plotsettings')
                warning('plotSettings gui needs to be passed an instance of plots.plotsettings')
                return
            end
            obj.settings = settings;
            
            % init fig and draw initial rois
            obj.initfig();
            obj.updateStateOfGui();
            
            % arm callbacks 
            set(obj.h.chkBox.enable,'Callback',@(hobj,event) obj.guiSetCheckBox('enable'))
            set(obj.h.chkBox.timeStamp,'Callback',@(hobj,event) obj.guiSetCheckBox('timeStamp'))
            set(obj.h.edit.updateEveryNframe,'Callback',{@obj.guiSetEditBox,'updateEveryNframe'})
            set(obj.h.edit.exportEveryNframe,'Callback',{@obj.guiSetEditBox,'exportEveryNframe'})
            set(obj.h.chkBox.transparency,'Callback',@(hobj,event) obj.guiSetCheckBox('transparency'))
            set(obj.h.popup.scaleXY,'Callback',@(hobj,event) obj.guiSetPopup('scaleXY'))
            set(obj.h.popup.scaleZ,'Callback',@(hobj,event) obj.guiSetPopup('scaleZ'))
            set(obj.h.popup.scaleAngle,'Callback',@(hobj,event) obj.guiSetPopup('scaleAngle'))
            set(obj.h.popup.colormap,'Callback',@(hobj,event) obj.guiSetPopup('colormap'))
            set(obj.h.popup.data_aspect,'Callback',@(hobj,event) obj.guiSetPopup('data_aspect'))
            set(obj.h.popup.limitsType,'Callback',@(hobj,event) obj.guiSetPopup('limitsType'))
            set(obj.h.chkBox.fig,'Callback',@(hobj,event) obj.guiSetCheckBox('figExport'))
            set(obj.h.chkBox.png,'Callback',@(hobj,event) obj.guiSetCheckBox('pngExport'))
            set(obj.h.popup.dpi,'Callback',@(hobj,event) obj.guiSetPopup('dpi'))

            % arm help requests
            set(obj.h.panel.main, 'HelpFcn', @(hobj,event) obj.getHelp('main'))
            set(obj.h.panel.data, 'HelpFcn', @(hobj,event) obj.getHelp('data'))
            set(obj.h.panel.design, 'HelpFcn', @(hobj,event) obj.getHelp('design'))
            set(obj.h.panel.export, 'HelpFcn', @(hobj,event) obj.getHelp('export'))
            
            % block program execution until this gui is closed/deleted
            waitfor(obj.h.fig)
        end
        
        function var = get.figexists(obj)
            var = false;
            if isfield(obj.h,'fig')
                if isvalid(obj.h.fig)
                    var = true;
                end
            end
        end
        
        function obj = getHelp(obj,type)
            switch type
                case 'main'
                    msgbox({'\fontsize{11}Update every [n] means "figure is updated every n_{th} {\bfprocessed} frames".',...
                        ['Export every [n] means "if png/fig export is enabled, then every n_{th} {\bfupdated} frame is exported,',...
                        ' e.g. [update,export] = [2,5] means every second processed frame the figure is updated, and every 2*5 = 10th processed frame is exported.'],'',...
                        'Updating/Enabling CPU intensive figures can affect online analysis performance. Rendering and exporting figures as high resolution PNG heavily impacts performance!'},...
                        'plotSettings', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
                case 'data'
                    msgbox('\fontsize{11}In some circumstances XY and Z units may be linked. XY takes precedence.',...
                        'plotSettings', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
                case 'design'
                    msgbox('\fontsize{11}Not all settings apply to all plots.',...
                        'plotSettings', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
                case 'export'
                    msgbox('\fontsize{11}Exporting figures can affect online analysis performance. Files will be exported to {\bf"selectedFolder\\results\\figs"} every time the figure is updated.',...
                        'plotSettings', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
            end
        end
        
        function guiSetPopup(obj,type)
            switch type
                case 'scaleXY'
                    obj.settings.scale(1) = obj.scale_val(obj.h.popup.scaleXY.Value);
                case 'scaleZ'
                    obj.settings.scale(2) = obj.scale_val(obj.h.popup.scaleZ.Value);
                case 'scaleAngle'
                    obj.settings.scale(3) = obj.scale_val(obj.h.popup.scaleAngle.Value);
                case 'colormap'
                    obj.settings.colormap = obj.h.popup.colormap.String{obj.h.popup.colormap.Value};
                case 'data_aspect'
                    obj.settings.data_aspect = obj.h.popup.data_aspect.String{obj.h.popup.data_aspect.Value};
                case 'limitsType'
                    obj.settings.limitsType = obj.h.popup.limitsType.String{obj.h.popup.limitsType.Value};
                case 'dpi'
                    obj.settings.dpi = str2double(obj.h.popup.dpi.String{obj.h.popup.dpi.Value});
            end
            obj.updateStateOfGui();
        end
        
        function guiSetCheckBox(obj,type)
            switch type
                case 'enable'
                    obj.settings.enable = obj.h.chkBox.enable.Value;
                case 'timeStamp'
                    obj.settings.timeStamp = obj.h.chkBox.timeStamp.Value;
                case 'transparency'
                    obj.settings.transparency = obj.h.chkBox.transparency.Value;
                case 'figExport'
                    obj.settings.exportFig = obj.h.chkBox.fig.Value;
                case 'pngExport'
                    obj.settings.exportPNG = obj.h.chkBox.png.Value;
            end
            obj.updateStateOfGui();
        end
        
        function guiSetEditBox(obj,hobj,~,type)
            val = abs(str2double(hobj.String));
            if isfinite(val)
                switch type
                    case 'updateEveryNframe'
                        obj.settings.updateEveryNframes = val;
                    case 'exportEveryNframe'
                        obj.settings.exportEveryNframes = val;
                end
            end
            obj.updateStateOfGui();
        end
        
    end
    
    methods (Access = private)
        
        initfig(obj)
        updateStateOfGui(obj)
        
        function closeGui(obj)
            if obj.figexists
                delete(obj.h.fig)
            end
        end
        
    end
    
    methods (Access = private)
        
    end
    
    methods(Static, Access = private)
    end
    
end