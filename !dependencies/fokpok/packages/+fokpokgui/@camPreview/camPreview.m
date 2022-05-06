classdef camPreview < handle
    % gige cam preview / analysis
    
    properties (SetAccess = private, GetAccess = public)
        handles                           struct
        cam                               gcam
    end
    
    properties (Access = private)
        timer                             timer
        imgVariant                  (1,:) char
        axisUpdate                  (1,1) logical
        forceImageLimitsUpdate      (1,1) logical
        
        xaxis_px                    (1,:) double
        xaxis_mm                    (1,:) double
        yaxis_px                    (1,:) double
        yaxis_mm                    (1,:) double
        
        xIndexSelected              (1,1) double
        xPosSelected                (1,1) double
        yIndexSelected              (1,1) double
        yPosSelected                (1,1) double
        
        xMeasurement                (1,:) double
        yMeasurement                (1,:) double
        lenOfLine                   (1,:) double
        
        firstCamFrame               (1,1) uint32
        drawnFrames                 (1,1) uint32
    end
    
    properties (Dependent, Access = private)
        figexists                   (1,1) logical
    end
    
    methods
        function obj = camPreview(gcam)           
            if ~gcam.isconnected
                warndlg('\fontsize{12}Connect camera first.',...
                    'gcam.camSetupWizard',struct('Interpreter','tex','WindowStyle','modal'))
                return
            end
            lastBinning = gcam.binning_factor;
            
            % init fig and draw initial rois
            obj.cam = gcam;
            obj.handles = obj.initfig();
            obj.updateSpatialAxes()
            
            % arm listeners / callbacks
            % addlistener(obj.handles.sliders.xScale, 'Value', 'PostSet', @(hobj,event) obj.checkSliders('xScale'));
            % arm slider callbacks
            set(obj.handles.sliders.CAxisLO, 'Callback', @(hobj,event) obj.checkSliders(gcam,'CAxisLO'))
            set(obj.handles.sliders.CAxisHI, 'Callback', @(hobj,event) obj.checkSliders(gcam,'CAxisHI'))
            set(obj.handles.sliders.Exposure, 'Callback', @(hobj,event) obj.checkSliders(gcam,'Exposure'))
            set(obj.handles.sliders.BlackLevel, 'Callback', @(hobj,event) obj.checkSliders(gcam,'BlackLevel'))
            % arm button callbacks
            set(obj.handles.popup.colormap, 'Callback', @(hobj,event) obj.checkPopup('colormap'))
            set(obj.handles.popup.imgType, 'Callback', @(hobj,event) obj.checkPopup('imgType'))
            set(obj.handles.popup.binning, 'Callback', @(hobj,event) obj.checkPopup('binning'))
            set(obj.handles.popup.histogram, 'Callback', @(hobj,event) obj.checkPopup('histogram'))
            if isfield(obj.handles.popup,'correction')
                set(obj.handles.popup.correction, 'Callback', @(hobj,event) obj.checkPopup('correction'))
            end
            % track mouse position
            set(obj.handles.fig,'windowbuttonmotionfcn', @(hobj,event) obj.updateDataAtMousePosition());
            set(obj.handles.fig,'windowbuttondownfcn', @obj.recordMousePosition)
            
            % arm help requests
            set(obj.handles.panel.view, 'HelpFcn', @(hobj,event) obj.getHelp('mainWindow'))
            set(obj.handles.panel.histogram, 'HelpFcn', @(hobj,event) obj.getHelp('histogram'))
            
            % handle close requests
            set(obj.handles.fig,'CloseRequestFcn',@(hobj,event) obj.closeGui());
            
            % arm timer
            obj.timer = timer('TimerFcn',@(hObject,event) obj.updateTimerVals(),...
                'StartDelay',3,'Period',3,'ExecutionMode','fixedRate','BusyMode','drop');
            start(obj.timer);
            % block program execution until this gui is closed/deleted
            obj.firstCamFrame = uint32(obj.cam.framecount);
            
            while obj.figexists
                try
                    obj.update()
                catch
                    % user mustve closed gui
                    % keep running until fig is closed
                    continue
                end
            end
            % set binning to initial value
            obj.cam.binning_factor = lastBinning;
        end        
               
        function var = get.figexists(obj)
            var = false;
            if isfield(obj.handles,'fig')
                if isvalid(obj.handles.fig)
                    var = true;
                end
            end
        end
        
        function val = get.imgVariant(obj)
           if isempty(obj.imgVariant)
              val = 'IMG';
           else
               val = obj.imgVariant;
           end
        end
        
        function set.imgVariant(obj,val)
            obj.checkForXYlimUpdate(val)
            obj.imgVariant = val;
        end
                 
    end
    
    
    methods (Access = private)
        
        function checkForXYlimUpdate(obj,val)
            % when changing from {'IMG','ROI','HotPX'} to 'ROIc' or
            % 'ROIc' to {'IMG','ROI','HotPX'} then force-update xlim/ylim
            if (ismember(obj.imgVariant,{'IMG','ROI','HotPX'}) && strcmp(val,'ROIc')) ||...
                    (strcmp(obj.imgVariant,'ROIc') && ismember(val,{'IMG','ROI','HotPX'}))
                obj.forceImageLimitsUpdate = true;
            end
        end
        
        function update(obj)
            % draw new img
            obj.cam.grabFrame();
            
            switch obj.imgVariant
                case 'IMG'
                    if obj.cam.binning_factor == 1
                        img = obj.cam.IMG;
                    else
                        img = obj.cam.IMGbinned;
                    end
                case 'ROI'
                    if obj.cam.binning_factor ~= 1
                        img = obj.cam.IMGroiBinned;
                    else
                        img = obj.cam.IMGroi;
                    end
                case 'ROIc'
                    img = obj.cam.IMGroiCompact;
                case 'HotPX'
                    if obj.cam.binning_factor == 1
                        img = obj.cam.grayLevelLims(2).*uint32(~obj.cam.validpixels);
                    else
                        img = obj.cam.grayLevelLims(2).*uint32(~obj.cam.validpixels_binned);
                    end
            end
            
            % write data to figure
            obj.handles.image.CData = img;
            if obj.handles.buttons.histogram.Value
                xvals = round(interp1(obj.xaxis_mm,obj.xaxis_px,obj.handles.ax.XLim));
                yvals = round(interp1(obj.yaxis_mm,obj.yaxis_px,obj.handles.ax.YLim));
                if ~any(isnan([xvals,yvals]))
                    % calc histogram only inside visible range!
                    obj.handles.histogram.hist.Data = img(yvals(1):yvals(2),xvals(1):xvals(2));
                else
                    obj.handles.histogram.hist.Data = img;
                end
                obj.handles.histogram.xmin.Value = min(obj.handles.histogram.hist.Data(:));
                obj.handles.histogram.xmax.Value = max(obj.handles.histogram.hist.Data(:));
            end
            
            % when IMG type is changed then this must be executed
            if obj.axisUpdate % IMG popup callback must set this
                obj.updateSpatialAxes()
                obj.axisUpdate = false;
            end
            
            % when mouse is within image then put some info            
            if obj.isValidPosition()
                obj.handles.txt.Position = [obj.handles.ax.XLim(1), obj.handles.ax.YLim(1), 0];
                obj.handles.txt.String = sprintf('XY: [%i,%i] px | [%.2f,%.2f] mm | Z: %i | Length: %.2f [mm]',...
                                                obj.xIndexSelected,obj.yIndexSelected,...
                                                obj.xPosSelected,obj.yPosSelected,...
                                                obj.handles.image.CData(obj.yIndexSelected,obj.xIndexSelected),...
                                                obj.lenOfLine);
                if ~obj.handles.txt.Visible
                    obj.handles.txt.Visible = 1;
                end
            else
                if obj.handles.txt.Visible
                    obj.handles.txt.Visible = 0;
                end
            end
            
            obj.drawnFrames = obj.drawnFrames + 1;
            drawnow % note: not needed, note 2: definitely needed...
        end
        
        function closeGui(obj)
            % stop timer
            stop(obj.timer)
            delete(obj.timer)
            
            % kill fig
            delete(obj.handles.fig)
        end
        
        function obj = getHelp(obj,type)
            switch type
                case 'mainWindow'
                    msgbox({'\fontsize{11}Available settings change dynamically.',...
                        'If you want to preview HotPixels, ROI extraction etc., start camSetupWizard first!'},...
                        'CamViewer - Main', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
                case 'histogram'
                    msgbox({'\fontsize{11}Histogram [min/max] Values should be placed within the boundaries of the dynamic range of the camera.',...
                        'Note that Exposure, BlackLevel and HotPixels affect the result.',...
                        'Check CamViewer again after camSetupWizard / HotPixelDetection + AutoExposure.'},...
                        'CamViewer - Histogram', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
            end
        end
        
        function obj = checkButtons(obj,type)
        end
        
        function obj = checkPopup(obj,type)
            switch type
                case 'colormap'
                    obj.updateColormap();
                case 'binning'
                    obj.cam.binning_factor = str2double(obj.handles.popup.binning.String{obj.handles.popup.binning.Value});
                    obj.axisUpdate = true;
                case 'imgType'
                    % the consequences are processed in obj.update()
                    obj.imgVariant = obj.handles.popup.imgType.String{obj.handles.popup.imgType.Value};
                    obj.axisUpdate = true;
                    % force gray colormap if hotpixel
                    if strcmp(obj.imgVariant,'HotPX')
                            obj.handles.popup.colormap.Value = 2; % gray
                            obj.updateColormap();
                    end
                case 'histogram'
                    obj.handles.ax2.YScale = obj.handles.popup.histogram.String{obj.handles.popup.histogram.Value};
                case 'correction'
                    obj.cam.cam.Correction_Mode = obj.handles.popup.correction.String{obj.handles.popup.correction.Value};
            end
        end
        
        function updateColormap(obj)
            colormap(obj.handles.ax,...
                obj.handles.popup.colormap.String{obj.handles.popup.colormap.Value});
            switch obj.handles.popup.colormap.String{obj.handles.popup.colormap.Value}
                case 'jet'
                    clr = 'm';
                case 'gray'
                    clr = 'g';
            end
            obj.handles.crosshair.x.Color = clr;
            obj.handles.crosshair.y.Color = clr;
            obj.handles.measLine.Color = clr;
            obj.handles.measLine.MarkerFaceColor = clr;
        end
        
        function checkSliders(obj,gcam,type)
            % set value as slider value
            % then value setter verifies collision and updates rectangles
            % set slider value explicitly to value, ensuring valid value
            switch type
                case 'Exposure'
                    gcam.exposure = round(obj.handles.sliders.Exposure.Value);
                    obj.handles.fig.Name = gcam.camInfoString;
                case 'BlackLevel'
                    gcam.blackLevel = round(obj.handles.sliders.BlackLevel.Value);
                case 'CAxisLO'
                    oldcaxis = caxis(obj.handles.ax);
                    val = round(obj.handles.sliders.CAxisLO.Value);
                    if val >= oldcaxis(2)
                        val = oldcaxis(2)-eps;
                        obj.handles.sliders.CAxisLO.Value = val;
                    end
                    caxis(obj.handles.ax,[val, oldcaxis(2)]);
                    xlim(obj.handles.ax2,[val, oldcaxis(2)]);
                case 'CAxisHI'
                    oldcaxis = caxis(obj.handles.ax);
                    val = round(obj.handles.sliders.CAxisHI.Value);
                    if val <= oldcaxis(1)
                        val = oldcaxis(1)+eps;
                        obj.handles.sliders.CAxisHI.Value = val;
                    end
                    caxis(obj.handles.ax,[oldcaxis(1), val]);
                    xlim(obj.handles.ax2,[oldcaxis(1), val]);
            end
        end
        
        function updateSpatialAxes(obj)
            [ysize,xsize] = size(obj.handles.image.CData);
            
            % actual pixel size must be written now
            obj.xaxis_px = 1:xsize;
            obj.yaxis_px = 1:ysize;
            
            % but spatial axis must be corrected for binning if applied
            % if binning is applied, multiply by binning factor
            scale = 1;
            if any(strcmp(obj.imgVariant,{'IMG','ROI','HotPX'}))
                scale = obj.cam.binning_factor;
            end
            obj.xaxis_mm = xsize*scale*obj.cam.pixelSize*1e3*(((1:xsize)-(fix(xsize/2)+1))/xsize);
            obj.yaxis_mm = ysize*scale*obj.cam.pixelSize*1e3*(((1:ysize)-(fix(ysize/2)+1))/ysize);
            
            % write to imagesc
            obj.handles.image.XData = obj.xaxis_mm;
            obj.handles.image.YData = obj.yaxis_mm;
            
            % when chaging from {'IMG','ROI','HotPX'} to 'ROIc' or
            % 'ROIc' to {'IMG','ROI','HotPX'} then force-update xlim/ylim
            if obj.forceImageLimitsUpdate
                obj.handles.ax.XLim = [obj.xaxis_mm(1),obj.xaxis_mm(end)];
                obj.handles.ax.YLim = [obj.yaxis_mm(1),obj.yaxis_mm(end)];
                obj.forceImageLimitsUpdate = false;
                obj.handles.ax.XLimMode = 'auto'; 
                obj.handles.ax.YLimMode = 'auto';
            end
            
        end
        
        function strings = checkAvailableIMGtypes(obj)
            strings = {'IMG','ROI','ROIc','HotPX'};
            if obj.cam.roiIsActive == 0
                strings = erase(strings,{'ROIc','ROI'});
            end
            if obj.cam.hotpixelDetected == 0
                strings = erase(strings,'HotPX');
            end
            strings = strings(~cellfun('isempty',strings));
        end
        
        function updateTimerVals(obj)
            obj.handles.fig.Name = sprintf('Frame %i, drawn %i | %s',uint32(obj.cam.framecount)-obj.firstCamFrame,obj.drawnFrames,obj.cam.camInfoString);
        end
        
        function recordMousePosition(obj,hobj,~)
            obj.getcoordinates();
            
            switch hobj.SelectionType
                case 'normal' % left click
                    if obj.isValidPosition()
                        obj.xMeasurement = [obj.xMeasurement, obj.xPosSelected];
                        obj.yMeasurement = [obj.yMeasurement, obj.yPosSelected];
                        % length of the line are length of individual line segments
                        % which is sqrt(diff) and taken the sum over the
                        % 2nd dimension using the following data structure
                        %
                        % diff operates along first dimension, then square,
                        % sum along 2nd dimension, make sqrt, sum again and
                        % done
                        if length(obj.xMeasurement) > 1
                            obj.lenOfLine = sum(sqrt(sum(diff([obj.xMeasurement(:), obj.yMeasurement(:)]).^2,2)));
                        end
                    end
                case 'alt' % right click
                    obj.xMeasurement = [];
                    obj.yMeasurement = [];
                    obj.lenOfLine = nan;
            end
            set(obj.handles.measLine,'XData',obj.xMeasurement,'YData',obj.yMeasurement);
        end
        
        function updateDataAtMousePosition(obj)
            obj.getcoordinates();
            
            if obj.isValidPosition()
                obj.handles.crosshair.x.Value = obj.xPosSelected;
                obj.handles.crosshair.y.Value = obj.yPosSelected;
                if ~obj.handles.crosshair.x.Visible
                    obj.handles.crosshair.x.Visible = 1;
                    obj.handles.crosshair.y.Visible = 1;
                end
            else
                if obj.handles.crosshair.x.Visible
                    obj.handles.crosshair.x.Visible = 0;
                    obj.handles.crosshair.y.Visible = 0;
                end
            end
        end
        
        function getcoordinates(obj)
            % returns x y coordinates
            C = obj.handles.ax.CurrentPoint; % C(1,1) is X pos, C(1,2) is Y pos
            % interpolate from mm to px values
            obj.xPosSelected = C(1,1);
            obj.yPosSelected = C(1,2);
            obj.xIndexSelected = round(interp1(obj.xaxis_mm,obj.xaxis_px,C(1,1)));
            obj.yIndexSelected = round(interp1(obj.yaxis_mm,obj.yaxis_px,C(1,2)));
        end
    end
    
    methods (Access = private)
        
        function flag = isValidPosition(obj)
            % check selected index
            % check if current actual position is within current axis
            % limtis (weird behavior when zooming is active)
            flag =  all([obj.xIndexSelected,obj.yIndexSelected] > 0) &&...
                        (obj.handles.ax.XLim(1) <= obj.xPosSelected) &&...
                        (obj.xPosSelected <= obj.handles.ax.XLim(2)) &&...
                        (obj.handles.ax.YLim(1) <= obj.yPosSelected) &&...
                        (obj.yPosSelected <= obj.handles.ax.YLim(2));
        end
        
        function h = initfig(obj)
            % get img spec, required for slider value ranges
            obj.cam.binning_factor = 2;
            obj.cam.grabFrame;
            img = obj.cam.IMGbinned;

            % cam image axes in mm
            xsize = obj.cam.imSizeXY(1);
            ysize = obj.cam.imSizeXY(2);
            sx = xsize*obj.cam.pixelSize*1e3*[-0.5,0.5];
            sy = ysize*obj.cam.pixelSize*1e3*[-0.5,0.5];
                       
            % initializes gui
            h = struct();
            h.sliders = struct();
            h.text = struct();
            h.buttons = struct();
            h.popup = struct();
            
            enableCorrectionPopup = false;
            if ~isequal('Off',obj.cam.cam.Correction_Mode)
                enableCorrectionPopup = true;
            end
            
            % init fig
            h.fig = figure( ...
                'Color','white',...
                'Name', obj.cam.camInfoString, ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'Toolbar', 'figure', ...
                'HandleVisibility', 'off',...
                'WindowStyle', 'modal');
            
            % Arrange the main interface
            h.mainLayout = uix.HBoxFlex( 'Parent', h.fig, 'Spacing', 3, 'Padding', 0);
            
            % Create the panels
            h.panel.view = uix.BoxPanel( ...
                'Parent', h.mainLayout, ...
                'Title', 'Image (Snapshot)', 'Padding', 5, 'FontSize', 10);
            h.panel.histogram = uix.BoxPanel( ...
                'Parent', h.mainLayout, ...
                'Title', 'Histogram', 'Padding', 5, 'FontSize', 10);
            % Adjust the main layout; auto sizing left twice as big
            set( h.mainLayout, 'Widths', [-2.5,-1]  );
            
            % inside left boxpanel insert a vbox
            h.panel.viewVbox = uix.VBox( ...
                'Parent', h.panel.view);
            
            % first insert a popupmenu for colormap
            % the first vertical box will be filled with
            % [empty space], [button], [botton],...
            % each button is placed in a VBox with [name;button]           
            h.panel.viewVboxHbox = uix.HBox('Parent', h.panel.viewVbox, 'Padding', 0, 'Spacing', 5);
            uix.Empty( 'Parent', h.panel.viewVboxHbox); % whitespace left to settings to limit sz of cmap popup
            
            % Correction_Mode
            if enableCorrectionPopup
                tempVBox = uix.VBox('Parent', h.panel.viewVboxHbox, 'Padding', 0, 'Spacing', 0);
                uicontrol('Parent',tempVBox,'Style','text','String','Correction','HorizontalAlignment','left');
                h.popup.correction = uicontrol(tempVBox,'Style','popupmenu','String',{'Off','Offset','Hotpixel','OffsetHotpixel'});
                % find which correction mode is currently set so that
                % popupmenu is initialized accordingly
                idx = find(cellfun(@isequal,...
                           repelem({obj.cam.cam.Correction_Mode},4),...
                           {'Off','Offset','Hotpixel','OffsetHotpixel'}));
                h.popup.correction.Value = idx;
                set(tempVBox, 'Heights', [20,30]);
            end
            
            % imgtype
            tempVBox = uix.VBox('Parent', h.panel.viewVboxHbox, 'Padding', 0, 'Spacing', 0);
            uicontrol('Parent',tempVBox,'Style','text','String','Image','HorizontalAlignment','left');
            h.popup.imgType = uicontrol(tempVBox,'Style','popupmenu','String',obj.checkAvailableIMGtypes());
            set(tempVBox, 'Heights', [20,30]);
            
            % binning
            tempVBox = uix.VBox('Parent', h.panel.viewVboxHbox, 'Padding', 0, 'Spacing', 0);
            uicontrol('Parent',tempVBox,'Style','text','String','Binning','HorizontalAlignment','left');
            h.popup.binning = uicontrol(tempVBox,'Style','popupmenu','String',{'1','2','4','8'});
            set(h.popup.binning,'Value',2);
            set(tempVBox, 'Heights', [20,30]);
            
            % cmap
            tempVBox = uix.VBox('Parent', h.panel.viewVboxHbox, 'Padding', 0, 'Spacing', 0);
            uicontrol('Parent',tempVBox,'Style','text','String','Colormap','HorizontalAlignment','left');
            h.popup.colormap = uicontrol(tempVBox,'Style','popupmenu','String',{'jet','gray'});
            set(tempVBox, 'Heights', [20,30]);
                        
            % now we can set the widths in the first horizontal HBox: [empty space], [button], [botton],...
            if enableCorrectionPopup
                set(h.panel.viewVboxHbox, 'Widths', [-1,60,50,50,50]);
            else
                set(h.panel.viewVboxHbox, 'Widths', [-1,50,50,50]);
            end
            
            % Create the axes on the left
            h.ax = axes( 'Parent', h.panel.viewVbox );
            h.image = imagesc(h.ax,sx,sy,img);
            hold(h.ax,'on')
            axis(h.ax,'image'); % must be set after imagesc
            h.ax.Toolbar.Visible = 'on';
            
            colormap(h.ax,'jet');
            caxis(h.ax,obj.cam.grayLevelLims);
            xlim(h.ax,[sx(1), sx(2)]), ylim(h.ax,[sy(1), sy(2)])
            set(h.ax,'XLimMode','auto','YLimMode','auto')
            xlabel(h.ax,'x [mm]'), ylabel(h.ax,'y [mm]')
            h.axToolbar = axtoolbar(h.ax,'default');
            
            % init text for grayLevel
            h.txt = text(h.ax,1,1,'init','Color','k','FontSize',10,'VerticalAlignment','bottom','HorizontalAlignment','left','Visible',0);
            
            % init crosshair / position of mouse in image as invisible
            h.crosshair = struct();
            h.crosshair.x = xline(h.ax,obj.xPosSelected,'-m','Visible','off');
            h.crosshair.y = yline(h.ax,obj.yPosSelected,'-m','Visible','off');
            % init measurement line as nan (invisible)
            h.measLine = plot(h.ax,nan,nan,'--om','LineWidth',1,'MarkerFaceColor','m');
            
            % Exposure slider
            uicontrol('Parent', h.panel.viewVbox,'Style','text',...
                'String','Exposure','FontSize',11);
            h.sliders.Exposure = uicontrol( 'Parent', h.panel.viewVbox, 'Style','slider', 'Background', 'w',...
                'value',obj.cam.exposure,'min',obj.cam.exposureRange(1)-1,'max',obj.cam.exposureRange(2)+1);
            % blackLevel slider
            uicontrol('Parent', h.panel.viewVbox,'Style','text',...
                'String','BlackLevel','FontSize',11);
            h.sliders.BlackLevel = uicontrol( 'Parent', h.panel.viewVbox, 'Style','slider', 'Background', 'w',...
                'value',obj.cam.blackLevel,'min',obj.cam.blackLevelRange(1),'max',obj.cam.blackLevelRange(2));
            % CAxis lo/hi slider
            uicontrol('Parent', h.panel.viewVbox,'Style','text',...
                'String','CAxis Low / High','FontSize',11);
            h.panel.viewVboxHbox2 = uix.HBox('Parent', h.panel.viewVbox, 'Padding', 0, 'Spacing', 5);
            h.sliders.CAxisLO = uicontrol( 'Parent', h.panel.viewVboxHbox2, 'Style','slider', 'Background', 'w',...
                'value',obj.cam.grayLevelLims(1),'min',obj.cam.grayLevelLims(1),'max',obj.cam.grayLevelLims(2));
            h.sliders.CAxisHI = uicontrol( 'Parent', h.panel.viewVboxHbox2, 'Style','slider', 'Background', 'w',...
                'value',obj.cam.grayLevelLims(2),'min',obj.cam.grayLevelLims(1),'max',obj.cam.grayLevelLims(2));
            
            % axis gets autosize weight 1; text gets 18px, sliders get 30px, spacing 10
            set(h.panel.viewVbox, 'Heights', [42,-1,repmat([17,17],[1,3])], 'Spacing', 5, 'Padding', 10);
            
            % Histogram panel gets a VBox
            h.panel.histVbox = uix.VBox('Parent', h.panel.histogram);
            % and a HBox to limit w/ empty to limit whitespace
            h.panel.histVboxHbox = uix.HBox('Parent', h.panel.histVbox, 'Padding', 0, 'Spacing', 5);
            uix.Empty('Parent', h.panel.histVboxHbox); % whitespace left to settings to limit sz of cmap popup

            
            % histogram - enable button
            tempVBox = uix.VBox('Parent', h.panel.histVboxHbox, 'Padding', 0, 'Spacing', 0);
            uix.Empty('Parent', tempVBox); % whitespace left to settings to limit sz of cmap popup
            h.buttons.histogram = uicontrol(tempVBox,'Style','togglebutton','String','Enable','Value',1);
            set(tempVBox, 'Heights', [20,23]);
            % histogram - popup
            tempVBox = uix.VBox('Parent', h.panel.histVboxHbox, 'Padding', 0, 'Spacing', 0);
            uicontrol('Parent',tempVBox,'Style','text','String','Histogram','HorizontalAlignment','left');
            h.popup.histogram = uicontrol(tempVBox,'Style','popupmenu','String',{'linear','log'});
            set(tempVBox, 'Heights', [20,30]);
            h.panel.histVboxHbox.Widths = [-1,50,50];
            
            % inside right boxpanel insert axis for histogram
            h.ax2 = axes( 'Parent', h.panel.histVbox);
            h.histogram.hist = histogram(h.ax2,img,50,'LineStyle','none','FaceColor','k');
            h.histogram.xmin = xline(h.ax2,min(img(:)),'r','Label','min',"LabelHorizontalAlignment","right");
            h.histogram.xmax = xline(h.ax2,max(img(:)),'r','Label','max',"LabelHorizontalAlignment","left");
            xlim(h.ax2,obj.cam.grayLevelLims)
            hold(h.ax,'off')
            
            set(h.panel.histVbox, 'Heights', [42,-1], 'Spacing', 5, 'Padding', 10);
            
        end
        
    end
    
end