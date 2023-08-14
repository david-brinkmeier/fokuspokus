classdef etalonSpecSelector < handle
    
    properties (SetAccess = private, GetAccess = public)
        h                                 struct
    end
    
    properties (SetAccess = protected, GetAccess = public)
        etalonSpec                  (:,:) etalons
        
        wavelength                  (1,1) double % m
        xnum                        (1,1) uint32
        ynum                        (1,1) uint32
        flipX                       (1,1) logical
        flipY                       (1,1) logical
        dX                          (1,1) double % m
        dY                          (1,1) double % m
        wedgeAngleX                 (1,1) double % in deg
        wedgeAngleY                 (1,1) double % in deg

        success                     (1,1) logical = false
    end
    
    properties (Dependent, Access = public)
        figexists                   (1,1) logical
        specIsValid                 (1,1) logical
    end
    
    properties (Constant, Access = private)
    end
    
    methods
        
        function val = get.specIsValid(obj)
            val = true;
            if any(isnan([double(obj.xnum),double(obj.ynum),obj.dX,obj.dY,obj.wedgeAngleX,obj.wedgeAngleY]))
                val = false;
            end
        end
        
        function val = get.wedgeAngleX(obj)
            if obj.wedgeAngleX <= 0 || obj.wedgeAngleX >= 90 || isnan(obj.wedgeAngleX)
                val = nan;
            else
                val = obj.wedgeAngleX;
            end
        end
        
        function val = get.wedgeAngleY(obj)
            if obj.wedgeAngleY <= 0 || obj.wedgeAngleY >= 90 || isnan(obj.wedgeAngleY)
                val = nan;
            else
                val = obj.wedgeAngleY;
            end
        end
        
        function val = get.dX(obj)
            if obj.dX <= 0 || isnan(obj.dX)
                val = nan;
            else
                val = obj.dX;
            end
        end
        
        function val = get.dY(obj)
            if obj.dY <= 0 || isnan(obj.dY)
                val = nan;
            else
                val = obj.dY;
            end
        end
        
        function val = get.xnum(obj)
            if obj.xnum <= 1 || isnan(obj.xnum)
                val = nan;
            else
                val = obj.xnum;
            end
        end
        
        function val = get.ynum(obj)
            if obj.ynum <= 1 || isnan(obj.ynum)
                val = nan;
            else
                val = obj.ynum;
            end
        end
        
        function obj = etalonSpecSelector(input)
            if nargin == 0
                warndlg('\fontsize{11}etalonSpecSelector requires a wavelength scalar as input argument.',...
                    'etalonSpecSelector.warning',struct('Interpreter','tex','WindowStyle','modal'));
                return
            elseif nargin == 1
                if isa(input,'etalons')
                    obj.parseEtalonSpec(input);
                elseif isscalar(input) && isnumeric(input)
                    obj.wavelength = input;
                else
                    warndlg('\fontsize{11}etalonSpecSelector requires a wavelength scalar as input argument.',...
                        'etalonSpecSelector.warning',struct('Interpreter','tex','WindowStyle','modal'));
                end
            end
            
            % init fig and draw initial rois
            obj.initfig();
            
            % arm callbacks, pushbuttons
            set(obj.h.pb.defaultMsquaredLo,'Callback',@(hobj,event) obj.loadDefaults('msquaredLo'))
            set(obj.h.pb.defaultMsquaredHi,'Callback',@(hobj,event) obj.loadDefaults('msquaredHi'))
            set(obj.h.pb.saveexit,'Callback',@(hobj,event) obj.save())
            
            % chkboxes
            set(obj.h.chkBox.flipX,'Callback',@(hobj,event) obj.guiSetCheckBox('flipX'))
            set(obj.h.chkBox.flipY,'Callback',@(hobj,event) obj.guiSetCheckBox('flipY'))
            
            % editboxes
            set(obj.h.edit.xnum,'Callback',{@obj.guiSetEditBox,'xnum'})
            set(obj.h.edit.ynum,'Callback',{@obj.guiSetEditBox,'ynum'})
            set(obj.h.edit.dX,'Callback',{@obj.guiSetEditBox,'dX'})
            set(obj.h.edit.dY,'Callback',{@obj.guiSetEditBox,'dY'})
            set(obj.h.edit.wedgeAngleX,'Callback',{@obj.guiSetEditBox,'wedgeAngleX'})
            set(obj.h.edit.wedgeAngleY,'Callback',{@obj.guiSetEditBox,'wedgeAngleY'})
            
            % close request
            set(obj.h.fig,'CloseRequestFcn',@(hobj,event) obj.closeGui);
            
            % arm help requests
            set(obj.h.panel.main,'HelpFcn', @(hobj,event) obj.getHelp('main'))
            set(obj.h.panel.spec,'HelpFcn', @(hobj,event) obj.getHelp('spec'))
            
            % update gui
            obj.updateStateOfGui();
            
            % block program execution until this gui is closed/deleted
            waitfor(obj.h.fig)
        end
        
        function save(obj)
            if obj.specIsValid
                obj.etalonSpec = etalons(obj.wavelength,obj.xnum,obj.ynum,obj.flipX,obj.flipY,obj.dX,obj.dY,obj.wedgeAngleX,obj.wedgeAngleY);
                obj.success = true;
                obj.closeGui();
            else
                warndlg({'\fontsize{11}Specification is not valid.','','[xnum,ynum] >= 2','0° wedgeAngle < 90°','[dX,dY] > 0.'},...
                        'fokpokgui.etalonSpecSelector',struct('Interpreter','tex','WindowStyle','modal'));
            end
        end
        
        function var = get.figexists(obj)
            var = false;
            if isfield(obj.h,'fig')
                if isvalid(obj.h.fig)
                    var = true;
                end
            end
        end
        
        function closeGui(obj)
            if obj.figexists
                delete(obj.h.fig)
            end
        end
        
        function getHelp(obj,type)
            switch type
                case 'main'
                    msgbox({'\fontsize{11}','Load the defaults for the two existing beam splitter assemblies for high M² beams (small optical path length differences), and low M² beams (large optical path length differences).',...
                        'The defaults here are correct, when the beam splitter assembly "top" is aligned with the "top" marking of the camera.',...
                        'If SNR is bad, consider modifying xnum/ynum such that only high SNR beam profiles are evaluated.',...
                        },'fokpokgui.etalonSpecSelector', 'help',struct('Interpreter','tex','WindowStyle','modal'));
                case 'spec'
                    fig = figure('name','Example: Beam splitter configuration vs. camera coordinate system vs. settings.',...
                                 'color','w','ToolBar','none','MenuBar','none','NumberTitle','off');
                    imshow(imread('etalonSpec.png'),'Parent',axes(fig),'Border','tight')
            end
        end
    end
    
    methods (Access = private)
        % defined externally
        initfig(obj)
        updateStateOfGui(obj)
        
        function parseEtalonSpec(obj,etalonSpec)
            obj.wavelength = etalonSpec.laserWavelength;
            obj.xnum = etalonSpec.xnum;
            obj.ynum = etalonSpec.ynum;
            obj.flipX = etalonSpec.flipX;
            obj.flipY = etalonSpec.flipY;
            obj.dX = etalonSpec.dX;
            obj.dY = etalonSpec.dY;
            obj.wedgeAngleX = rad2deg(etalonSpec.wedgeAngleX);
            obj.wedgeAngleY = rad2deg(etalonSpec.wedgeAngleY);
        end
        
        function guiSetEditBox(obj,hobj,event,type)
            input = str2num(strrep(hobj.String,',','.')); %#ok<ST2NM>
            if isempty(input) || ~isscalar(input) || ~isfinite(input)
                hobj.String = [];
                return
            else
                hobj.String = input;
            end
            switch type
                case 'xnum'
                    obj.xnum = uint32(input);
                case 'ynum'
                    obj.ynum = uint32(input);
                case 'dX'
                    obj.dX = abs(input)*1e-3;
                case 'dY'
                    obj.dY = abs(input)*1e-3;
                case 'wedgeAngleX'
                    obj.wedgeAngleX = abs(input);
                case 'wedgeAngleY'
                    obj.wedgeAngleY = abs(input);
            end
            obj.updateStateOfGui();
        end
        
        function guiSetCheckBox(obj,type)
            switch type
                case 'flipX'
                    obj.flipX = obj.h.chkBox.flipX.Value;
                case 'flipY'
                    obj.flipY = obj.h.chkBox.flipY.Value;
                otherwise
                    error('Type %s undefined',type)
            end
            obj.updateStateOfGui();
        end
        
        function loadDefaults(obj,type)
            switch type
                case 'msquaredLo'
                    obj.xnum = 5;
                    obj.ynum = 5;
                    obj.flipX = true;
                    obj.flipY = false;
                    obj.dX = 3.05e-3;
                    obj.dY = 6.45e-3;
                    obj.wedgeAngleX = 11.367;
                    obj.wedgeAngleY = 7.68;
                case 'msquaredHi'
                    obj.xnum = 4;
                    obj.ynum = 5;
                    obj.flipX = true;
                    obj.flipY = false;
                    obj.dX = 3e-3;
                    obj.dY = 2e-3; % 2.1mm measured, 2mm theory?!
                    obj.wedgeAngleX = 45;
                    obj.wedgeAngleY = 45;
            end
            obj.updateStateOfGui();
        end
    end
    
    methods (Access = public)
    end
    
    methods (Static, Access = private)        
    end
    
    methods(Static, Access = public)
    end
end
