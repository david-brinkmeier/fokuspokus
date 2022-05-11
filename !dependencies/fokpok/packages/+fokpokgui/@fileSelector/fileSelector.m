classdef fileSelector < handle
    
    properties (SetAccess = private, GetAccess = public)
        success                     (1,1) logical
        h                                 struct    % handles!
        
        pixelpitch                  (1,1) double    % in µm
        wavelength                  (1,1) double    % in nm
        roiFixed                    (1,1) logical   % when roi selection is done
        
        images                      (:,:,:) double  % 3d image stack
        images_export               (:,:,:) double
        zPos                        (:,1) double
        zPos_export                 (:,1) double
        idx                         (1,1) uint32    % index of selected image in stack
        overExposed                 (:,1) cell      % holds struct with information about overexposed pixels in each image
        
        filename                    (:,1) cell
        useIMG                      (:,1) logical
        workingFolder               (1,:) char
    end
    
    properties (SetAccess = private, GetAccess = public)       
        xIndexSelected              (1,1) double
        xPosSelected                (1,1) double
        yIndexSelected              (1,1) double
        yPosSelected                (1,1) double
        rectStart                   (1,2) double
        rectEnd                     (1,2) double
        inpaintX                    (:,1) double
        inpaintY                    (:,1) double
        stopInpaint                 (1,1) logical
        inpaintUndoIMGs             (:,1) cell
        spatial_string              (1,:) char
        spatial_scale               (1,1) double
        
        roiString                   (1,:) char
        useIMGString                (1,:) char
    end
    
    properties (Dependent, Access = public)        
        figexists                   (1,1) logical
        roiEnabled                  (1,1) logical
        inpaintingActive            (1,1) logical
        inpaintIDX                  (:,1) double
        len                         (1,1) uint32    % number of images
        
        zPos_table                  (:,1) cell
        useIMG_table                (:,1) cell
    end
    
    methods
        function obj = fileSelector()
            obj.success = 0;
            obj.rectStart = [nan,nan];
            obj.rectEnd = [nan,nan];
            obj.roiFixed = 0;
            obj.idx = 1;
            
            % init fig and draw initial rois
            abort = obj.askUserUnits();
            if abort
                return
            end
            
            obj.h = obj.initfig();
            
            % arm slider callbacks
            %set(obj.h.sliders.CAxisLO, 'Callback', @(hobj,event) obj.checkSliders('CAxisLO'))
            %set(obj.h.sliders.CAxisHI, 'Callback', @(hobj,event) obj.checkSliders('CAxisHI'))
            addlistener(obj.h.sliders.CAxisLO, 'Value', 'PostSet', @(hobj,event)  obj.checkSliders('CAxisLO'));
            addlistener(obj.h.sliders.CAxisHI, 'Value', 'PostSet', @(hobj,event)  obj.checkSliders('CAxisHI'));
            
            % arm popup callbacks
            set(obj.h.popup.colormap, 'Callback', @(hobj,event) obj.checkPopup('colormap'))            
            
            % arm button callbacks
            set(obj.h.pushbuttons.ReadFiles, 'Callback', @(hobj,event) obj.loadFileHandler())
            obj.armDragNDrop()
            set(obj.h.pushbuttons.sortTable, 'Callback', @(hobj,event) obj.sortData())
            set(obj.h.pushbuttons.OKExit, 'Callback', @(hobj,event) obj.requestExit())
            set(obj.h.pushbuttons.HideOverexposed, 'Callback', @(hobj,event) obj.updateImage())
            set(obj.h.pushbuttons.InpaintProcess, 'Callback', @(hobj,event) obj.makeInpaint())
            set(obj.h.pushbuttons.InpaintUndo, 'Callback', @(hobj,event) obj.undoInpaint())
            
            % arm uicontrol-edit input box callbacks
            set(obj.h.edit.pixelpitch, 'Callback', {@obj.checkEditBoxes,'pixelpitch'})
            set(obj.h.edit.wavelength, 'Callback', {@obj.checkEditBoxes,'wavelength'})
            
            % track mouse position
            set(obj.h.fig,'windowbuttonmotionfcn', @(hobj,event) obj.updateDataAtMousePosition());
            set(obj.h.fig,'windowbuttondownfcn', @obj.recordMousePosition)
            set(obj.h.fig,'WindowButtonUpFcn', @(hobj,event) obj.stopInpainting())
            set(obj.h.fig,'WindowScrollWheelFcn', @obj.mouseWheel);
            %set(obj.h.fig,'SizeChangedFcn', @(hobj,event) obj.checkAxSize());
            
            
            % table callbacks
            set(obj.h.table,'CellEditCallback', @obj.cellEdited);
            set(obj.h.table,'CellSelectionCallback', @obj.cellSelected);
            
            % arm help requests
            set(obj.h.panel.table, 'HelpFcn', @(hobj,event) obj.getHelp('table'))
            set(obj.h.panel.img, 'HelpFcn', @(hobj,event) obj.getHelp('img'))
            
            % handle close requests
            set(obj.h.fig,'CloseRequestFcn',@(hobj,event) obj.closeGui());
            
            % animate buttons for user
            obj.guideUserEyes()
            
            % block program execution until this gui is closed/deleted
            waitfor(obj.h.fig)
        end
        
        function val = get.inpaintingActive(obj)
           val = obj.h.pushbuttons.InpaintToggle.Value;
        end
        
        function val = get.inpaintIDX(obj)
            if ~isempty(obj.inpaintX)
               val = sub2ind(size(obj.images,1:2),obj.inpaintY,obj.inpaintX);
            else
                val = [];
            end
        end
                
        function set.idx(obj,val)
            obj.idx = val;
            obj.updateImage();
        end
        
        function set.images(obj,val)
            [szy,szx] = size(val,1:2);
            % make sure obj.images is of even length in x/y
            if ~bitget(szy,1)
                szy = szy-1;
            end
            if ~bitget(szx,1)
                szx = szx-1;
            end
            % save / update axis
            obj.images = val(1:szy,1:szx,:);
            obj.updateAxisLims();
            obj.updateImage();
        end
        
        function val = get.zPos_table(obj)
            if isempty(obj.zPos)
                val = {};
            else
                val = num2cell(obj.zPos*obj.spatial_scale);
            end
        end
        
        function val = get.useIMG_table(obj)
            if isempty(obj.useIMG)
                val = {};
            else
                val = num2cell(obj.useIMG);
            end
        end
        
        function val = get.idx(obj)
            if isempty(obj.images)
                val = 1;
            else
                val = obj.idx;
            end
        end
        
        function val = get.workingFolder(obj)
            if isempty(obj.workingFolder)
                val = '';
            else
                val = obj.workingFolder;
            end
        end
        
        function val = get.len(obj)
           if isempty(obj.images)
              val = 1;
           else
               val = size(obj.images,3);
           end
        end
        
        function val = get.roiEnabled(obj)
            if any(~isnan([obj.rectStart,obj.rectEnd]))
                val = true;
            else
                val = false;
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
                 
    end
    
    methods (Access = private)
        % declared externally
        success = loadFiles(obj,filename,pathname,fileext)
        
        function closeGui(obj)
            % kill fig
            if obj.figexists
                delete(obj.h.fig)
            end
        end
        
        function abort = askUserUnits(obj)
            abort = false;
            answer = questdlg('\fontsize{12}Specify units for z-Position...',...
                'fileSelector','m','mm','µm',...
                struct('Interpreter','tex','Default','mm'));
            switch answer
                case 'm'
                    obj.spatial_scale = 1;
                    obj.spatial_string = 'm';
                case 'mm'
                    obj.spatial_scale = 1e3;
                    obj.spatial_string = 'mm';
                case 'µm'
                    obj.spatial_scale = 1e6;
                    obj.spatial_string = 'µm';
                case ''
                    abort = true;
            end
        end
        
        function obj = getHelp(obj,type)
            switch type
                case 'table'
                    msgbox({'\fontsize{11}All Images to-be-used must have an associated z-Position.',...
                        ''},...
                        'IMGSelection - Table', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
                case 'img'
                    msgbox({'\fontsize{11}Using LMB/RMB an optional global ROI can be set for all images.',...
                        'Use mouse wheel to scroll through the image stack.'},...
                        'IMGSelection - IMG', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
            end
        end
        
        function obj = checkButtons(obj,type)
        end
        
        function checkEditBoxes(obj,hobj,event,type)
            % all edit boxes are for numeric scalars so check first
            input = str2num(strrep(hobj.String,',','.')); %#ok<ST2NM>
            if isempty(input) || ~isscalar(input) || ~isfinite(input)
                hobj.String = [];
                return
            else
                hobj.String = input;
            end
            
            switch type
                case 'pixelpitch'
                    obj.pixelpitch = input*1e-6;
                case 'wavelength'
                    obj.wavelength = input*1e-9;
            end
        end
        
        function obj = checkPopup(obj,type)
            switch type
                case 'colormap'
                    obj.updateColormap();
            end
        end
        
        function updateColormap(obj)
            cmap = obj.h.popup.colormap.String{obj.h.popup.colormap.Value};
            colormap(obj.h.ax,cmap);
                 switch cmap
                     case 'jet'
                         obj.h.rect.EdgeColor = 'm';
                         obj.h.overexposed.Color = 'm';
                         obj.h.overexposed.MarkerFaceColor = 'm';
                         obj.h.inpainting.Color = 'y';
                         obj.h.crosshair.x.Color = 'm';
                         obj.h.crosshair.y.Color = 'm';
                     case 'gray'
                         obj.h.rect.EdgeColor = 'g';
                         obj.h.overexposed.Color = 'r';
                         obj.h.overexposed.MarkerFaceColor = 'r';
                         obj.h.inpainting.Color = 'g';
                         obj.h.crosshair.x.Color = 'g';
                         obj.h.crosshair.y.Color = 'g';
                 end
        end
        
        function checkSliders(obj,type)
            % set value as slider value
            % then value setter verifies collision and updates rectangles
            % set slider value explicitly to value, ensuring valid value
            switch type
                case 'CAxisLO'
                    oldcaxis = caxis(obj.h.ax);
                    if obj.h.sliders.CAxisLO.Value >= oldcaxis(2)
                        obj.h.sliders.CAxisLO.Value = oldcaxis(2)-1e-3;
                    end
                    caxis(obj.h.ax,[obj.h.sliders.CAxisLO.Value, oldcaxis(2)]);
                case 'CAxisHI'
                    oldcaxis = caxis(obj.h.ax);
                    if obj.h.sliders.CAxisHI.Value <= oldcaxis(1)
                        obj.h.sliders.CAxisHI.Value = oldcaxis(1)+1e-3;
                    end
                    caxis(obj.h.ax,[oldcaxis(1), obj.h.sliders.CAxisHI.Value]);
            end
        end
                
        function updateTimerVals(obj)
        end
        
        function cellSelected(obj,hobj,event)
            if ~isempty(obj.images) && ~isempty(event.Indices)
                obj.idx = event.Indices(1);
            end
        end
        
        function cellEdited(obj,hobj,event)
            if ~isempty(obj.images) && ~isempty(event.Indices)
                if isa(event.EditData,'char')
                    if isempty(event.EditData)
                        input = nan;
                    else
                        input = str2num(strrep(event.EditData,',','.')); %#ok<ST2NM>
                        if isempty(input) || ~isfinite(input)
                            input = nan;
                        end
                    end
                    hobj.Data{event.Indices(1),event.Indices(2)} = input;
                else
                    input = event.NewData;
                end
                
                switch event.Indices(2)
                    case 2 % zPos
                        obj.zPos(event.Indices(1)) = input/obj.spatial_scale;
                    case 3 % useIMG / logical
                        obj.useIMG(event.Indices(1)) = logical(input);
                end
                obj.updateTable()
                obj.updateImage()
                
                if (event.Indices(2) == 2) && (event.Indices(1) < size(obj.images,3)) % is a number entered and not last index!
                    try %#ok<TRYNC> try to scroll to next row
                        jUIScrollPane = findjobj(obj.h.table);
                        jUITable = jUIScrollPane.getViewport.getView;
                        jUITable.changeSelection(event.Indices(1),event.Indices(2)-1, false, false); % row,col
                    end
                end
            end
        end
        
        function mouseWheel(obj,~,source)
            if ~isempty(obj.images)
                index = obj.idx;
                if source.VerticalScrollCount > 0
                    index = index+1;
                elseif source.VerticalScrollCount < 0
                    index = index-1;
                end
                if index < 1
                    return
                end
                if index > obj.len
                    return
                end
                obj.idx = index;
            end
        end
        
        function stopInpainting(obj)
            if obj.inpaintingActive
                obj.stopInpaint = true;
                unique_reduced = unique([obj.inpaintX,obj.inpaintY],'rows');
                obj.inpaintX = unique_reduced(:,1);
                obj.inpaintY = unique_reduced(:,2);
            end
        end
        
        function makeInpaint(obj)
            if ~isempty(obj.inpaintIDX)
                img = obj.images(:,:,obj.idx);
                
                if isempty(obj.inpaintUndoIMGs{obj.idx})
                    obj.inpaintUndoIMGs{obj.idx}(:,:,1) = img;
                else
                    obj.inpaintUndoIMGs{obj.idx}(:,:,end+1) = img;
                end
                img(obj.inpaintIDX) = nan;
                img = fillmissing(img,'nearest');
                if obj.overExposed{obj.idx}.ContainsMaxVal
                    logmask = ~ismember(obj.overExposed{obj.idx}.idx,obj.inpaintIDX);
                    for field = {'x','y','idx'}
                        obj.overExposed{obj.idx}.(field{:}) = obj.overExposed{obj.idx}.(field{:})(logmask);
                    end
                    if isempty(obj.overExposed{obj.idx}.idx)
                        obj.overExposed{obj.idx}.ContainsMaxVal = false;
                    end
                end
                obj.inpaintX = []; obj.inpaintY = [];
                set(obj.h.inpainting,'XData',nan,'YData',nan)
                oldXLim = obj.h.ax.XLim; oldYLim = obj.h.ax.YLim;
                obj.images(:,:,obj.idx) = img;
                obj.h.ax.XLim = oldXLim; obj.h.ax.YLim = oldYLim;
            end
        end
        
        function undoInpaint(obj)
            if isempty(obj.inpaintUndoIMGs{obj.idx})
                return
            end
            oldXLim = obj.h.ax.XLim; oldYLim = obj.h.ax.YLim;
            obj.images(:,:,obj.idx) = obj.inpaintUndoIMGs{obj.idx}(:,:,end);
            obj.h.ax.XLim = oldXLim; obj.h.ax.YLim = oldYLim;
            obj.inpaintUndoIMGs{obj.idx} = obj.inpaintUndoIMGs{obj.idx}(:,:,1:end-1);
        end
        
        function recordMousePosition(obj,hobj,~)
            obj.stopInpaint = false;
            if obj.isValidPosition()
                switch hobj.SelectionType
                    case 'normal' % left click
                        if ~obj.inpaintingActive
                            if ~obj.roiEnabled
                                obj.rectStart = [obj.xIndexSelected,obj.yIndexSelected];
                            elseif ~obj.roiFixed
                                obj.rectEnd = [obj.xIndexSelected,obj.yIndexSelected];
                                obj.roiFixed = true;
                            end
                            obj.updateRectangle()
                        else
                            while obj.inpaintingActive && ~obj.stopInpaint
                                obj.inpaintX = [obj.inpaintX; obj.xIndexSelected];
                                obj.inpaintY = [obj.inpaintY; obj.yIndexSelected];
                                set(obj.h.inpainting,'XData',obj.inpaintX,'YData',obj.inpaintY)
                                obj.h.inpainting.Visible = 1;
                                pause(1/30)
                            end
                        end
                    case 'alt' % right click
                        if ~obj.inpaintingActive
                            obj.h.rect.Visible = 0;
                            obj.rectStart = [nan,nan];
                            obj.rectEnd = [nan,nan];
                            obj.roiFixed = false;
                        else
                            set(obj.h.inpainting,'XData',nan,'YData',nan)
                            obj.inpaintX = []; obj.inpaintY = [];
                            obj.h.inpainting.Visible = 0;
                        end
                end
            end
        end
        
        function updateRectangle(obj)
            if obj.roiEnabled && ~obj.h.rect.Visible
                obj.h.rect.Visible = 1;
            end
            if obj.roiEnabled
                x1 = obj.rectStart(1);
                y1 = obj.rectStart(2);
                x2 = obj.rectEnd(1);
                y2 = obj.rectEnd(2);
                
                xstart = min([x1,x2]);
                xend = max([x1,x2]);
                ystart = min([y1,y2]);
                yend = max([y1,y2]);
                
                obj.h.rect.Position = [xstart, ystart, xend-xstart, yend-ystart];
            end
        end
        
        function updateDataAtMousePosition(obj)
            try
                obj.getcoordinates();
                if obj.isValidPosition()
                    obj.h.crosshair.x.Value = obj.xPosSelected;
                    obj.h.crosshair.y.Value = obj.yPosSelected;
                    obj.h.txt.Position = [obj.h.ax.XLim(1), obj.h.ax.YLim(1), 0];
                    obj.h.txt.String = sprintf('X: %i, Y: %i, Graylevel: %.2f',...
                                       obj.xIndexSelected,obj.yIndexSelected,obj.images(obj.yIndexSelected,obj.xIndexSelected,obj.idx));
                    if ~obj.h.txt.Visible
                       obj.h.txt.Visible = 1; 
                    end
                    if ~obj.h.crosshair.x.Visible
                        obj.h.crosshair.x.Visible = 1;
                        obj.h.crosshair.y.Visible = 1;
                    end
                    if obj.roiEnabled
                        if ~obj.roiFixed
                            obj.rectEnd = [obj.xIndexSelected,obj.yIndexSelected];
                            obj.updateRectangle()
                        end
                    end
                else
                    if obj.h.txt.Visible
                        obj.h.txt.Visible = 0;
                    end
                    if obj.h.crosshair.x.Visible
                        obj.h.crosshair.x.Visible = 0;
                        obj.h.crosshair.y.Visible = 0;
                    end
                end
            catch ME
                errorMessage = sprintf('Error in %s() at line %i.\n%s',...
                    ME.stack(1).name, ME.stack(1).line, ME.message);
                fprintf('%s\n', errorMessage);
            end
        end
        
        function getcoordinates(obj)
            if isempty(obj.images)
                return
            end
            
            [szy,szx] = size(obj.images(:,:,obj.idx));
            C = obj.h.ax.CurrentPoint;
            obj.xPosSelected = C(1,1);
            obj.yPosSelected = C(1,2);
            
            xTmp = round(obj.xPosSelected);
            if xTmp < 1
                xTmp = 1;
            elseif xTmp > szx
                xTmp = szx;
            end
            
            yTmp = round(obj.yPosSelected);
            if yTmp < 1
                yTmp = 1;
            elseif yTmp > szy
                yTmp = szy;
            end
            
            obj.xIndexSelected = xTmp;
            obj.yIndexSelected = yTmp;
        end
        
        function sortData(obj)
            if ~isempty(obj.images)
                [~,sortedIDX] = sort(obj.zPos);
                obj.filename = obj.filename(sortedIDX);
                obj.zPos = obj.zPos(sortedIDX);
                obj.useIMG = obj.useIMG(sortedIDX);
                obj.overExposed = obj.overExposed(sortedIDX);
                obj.inpaintUndoIMGs = obj.inpaintUndoIMGs(sortedIDX);
                
                obj.idx = 1;
                obj.updateTable();
                obj.images = obj.images(:,:,sortedIDX);
            end 
        end
        
        function loadFileHandler(obj)
            obj.idx = 1;
            flag = obj.loadFiles();
            if flag
                obj.sortData();
                obj.updateTable();
                obj.updateImage();
            end
        end
        
        function requestExit(obj)
            if obj.allDone
                obj.sortData();
                if obj.roiFixed
                    % ensure valid indexes..rectangle specification min/max
                    % might result in idxHigh:idxLow
                    xExport = [min([obj.rectStart(1),obj.rectEnd(1)]),max([obj.rectStart(1),obj.rectEnd(1)])];
                    yExport = [min([obj.rectStart(2),obj.rectEnd(2)]),max([obj.rectStart(2),obj.rectEnd(2)])];
                    % ensure output is odd X/Y len
                    dx = 0;
                    if mod(length(xExport(1):xExport(2)),2) == 0
                        dx = -1;
                    end
                    dy = 0;
                    if mod(length(yExport(1):yExport(2)),2) == 0
                        dy = -1;
                    end
                    % and export
                    obj.images_export = obj.images(yExport(1):(yExport(2)+dy),...
                                                   xExport(1):(xExport(2)+dx),...
                                                   obj.useIMG);
                else
                    obj.images_export = obj.images(:,:,obj.useIMG);
                end
                obj.zPos_export = obj.zPos(obj.useIMG);
                
                if ~isempty(obj.images_export)
                    obj.success = true;
                    obj.closeGui();
                else
                    warning('images_export is empty..this should not have happened');
                    return
                end
            end
        end
        
        function updateTable(obj)
            obj.h.table.Data(:,1) = obj.filename;
            obj.h.table.Data(:,2) = obj.zPos_table;
            obj.h.table.Data(:,3) = obj.useIMG_table;
        end
        
        function updateAxisLims(obj)
            szx = size(obj.images,2);
            szy = size(obj.images,1);
            obj.h.ax.XLim = [1,szx];
            obj.h.ax.YLim = [1,szy];
            obj.h.skipRect.Position = [1,1,szx-1,szy-1];
        end
        
        function updateImage(obj)
            if ~isempty(obj.images) && (obj.idx <= obj.len)
                if obj.useIMG(obj.idx) == false
                    obj.h.skipRect.Visible = 1;
                elseif obj.useIMG(obj.idx) == true
                    obj.h.skipRect.Visible = 0;
                end
                
                if obj.roiFixed
                    obj.roiString = 'enabled';
                else
                    obj.roiString = 'disabled';
                end
                if obj.useIMG(obj.idx)
                    obj.useIMGString = 'enabled';
                else
                    obj.useIMGString = 'disabled';
                end
                
                if obj.overExposed{obj.idx}.ContainsMaxVal
                    obj.h.pushbuttons.HideOverexposed.Visible = 1;
                    if obj.h.pushbuttons.HideOverexposed.Value
                        obj.h.overexposed.Visible = 0;
                    else
                        obj.h.overexposed.Visible = 1;
                        set(obj.h.overexposed,'XData',obj.overExposed{obj.idx}.x,'YData',obj.overExposed{obj.idx}.y)
                    end
                else
                    obj.h.overexposed.Visible = 0;
                    obj.h.pushbuttons.HideOverexposed.Visible = 0;
                end
                
                %update img
                obj.h.image.CData = obj.images(:,:,obj.idx);
                %update title
                obj.updateTitle(); 
            end
        end
        
        function updateTitle(obj)
            obj.h.panel.img.Title = sprintf('IMG [%i/%i], z = %.2f %s, IMGstate: %s, ROI: %s',...
                obj.idx,obj.len,obj.zPos(obj.idx)*obj.spatial_scale,obj.spatial_string,obj.useIMGString,obj.roiString);
        end
        
        function val = allDone(obj)
            val = true;
            if ~obj.figexists
                return
            end
            errorString = {};
            if isempty(obj.pixelpitch) || (obj.pixelpitch == 0)
                val = false;
                errorString{1} = '\fontsize{12}Pixelpitch must be set.';
            end
            if isempty(obj.wavelength) || (obj.wavelength == 0)
                val = false;
                errorString{2} = '\fontsize{12}Wavelength must be set.';
            end
            if any(~isfinite(obj.zPos(obj.useIMG)))
                val = false;
                errorString{3} = '\fontsize{12}All images to-be-used must have a finite z-position.';
            end
            if length(obj.zPos(obj.useIMG)) < 2
                val = false;
                errorString{4} = '\fontsize{12}At least two images are required to proceed.';
            end
            errorString = errorString(~cellfun(@isempty, errorString));
            if ~isempty(errorString)
                errordlg(errorString,'fileSelector',struct('Interpreter','tex','WindowStyle','modal'))
            end
        end
        
        function guideUserEyes(obj)
            info = rendererinfo(obj.h.ax);
            % if software renderer then dont alert bc of bad performance
            if strcmpi(info.GraphicsRenderer,'OpenGL Software')
                return
            end
            buttons = {'ReadFiles'};
            oldColor = obj.h.pushbuttons.ReadFiles.BackgroundColor;
            animC = linspace(oldColor(1),0,7); animC = [animC,flip(animC)];
            try
                for j = 1:4
                    for i = 1:length(animC)
                        for k = 1:length(buttons)
                            obj.h.pushbuttons.(buttons{k}).ForegroundColor = [1,1,1];
                            obj.h.pushbuttons.(buttons{k}).BackgroundColor = [animC(i),animC(i),0.94];
                        end
                        pause(1/90)
                    end
                end
                for k = 1:length(buttons)
                    obj.h.pushbuttons.(buttons{k}).ForegroundColor = [0,0,0];
                    obj.h.pushbuttons.(buttons{k}).BackgroundColor = oldColor;
                end
            catch
                % user might close gui while animation is running
                return
            end
        end
        
        function armDragNDrop(obj)
            % attempt to realize file drag and drop functionality
            try %#ok<TRYNC>
                warning('off','MATLAB:ui:javaframe:PropertyToBeRemoved')
                jFrame = get(handle(obj.h.fig), 'JavaFrame'); %#ok<JAVFM>
                jAxis = jFrame.getAxisComponent();
                % Add listener for drop operations
                DropListener(jAxis,'DropFcn', @obj.onDrop);
                warning('on','MATLAB:ui:javaframe:PropertyToBeRemoved')
            end
        end
        
        function onDrop(obj,~,event)
            try %#ok<TRYNC>
                data = event.GetTransferableData();
                % Is it transferable as a list of files
                if (data.IsTransferableAsFileList)
                    % Do whatever you need with this list of files
                    [pathname,file,fileext] = fileparts(data.TransferAsFileList);
                    pathname = strcat(pathname,'\');
                    file = strcat(file,fileext);
                    flag = obj.loadFiles(file(:),pathname{1});
                    if flag
                        obj.updateTable();
                        obj.updateImage();
                    end
                    % Indicate to the source that drop has completed
                    event.DropComplete(true);
                elseif (data.IsTransferableAsString)
                    % Not interested
                    event.DropComplete(false);
                else
                    % Not interested
                    event.DropComplete(false);
                end
            end
        end
        
    end
    
    methods (Access = private)
        
        function flag = isValidPosition(obj)
            % check selected index
            % check if current actual position is within current axis
            % limtis (weird behavior when zooming is active)
            flag =  all([obj.xIndexSelected,obj.yIndexSelected] > 0) &&...
                        (obj.h.ax.XLim(1) <= obj.xPosSelected) &&...
                        (obj.xPosSelected <= obj.h.ax.XLim(2)) &&...
                        (obj.h.ax.YLim(1) <= obj.yPosSelected) &&...
                        (obj.yPosSelected <= obj.h.ax.YLim(2));
        end
        
        function h = initfig(obj)
            dat = cell(1,3); % [obj.filename,obj.zPos,obj.useIMG]
            cols = {'file', sprintf('z [%s]',obj.spatial_string), 'use'};
            
            % initializes gui
            h = struct();
            h.sliders = struct();
            h.pushbuttons = struct();
            h.popup = struct();
            
            % init fig
            h.fig = figure( ...
                'Color','white',...
                'Name', 'IMG Selection', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'Toolbar', 'none', ...
                'HandleVisibility', 'off',...
                'WindowStyle', 'modal');
            h.fig.Position(3:4) = [800,400];
            
            % Arrange the main interface
            h.mainLayout = uix.HBoxFlex( 'Parent', h.fig, 'Spacing', 3, 'Padding', 0);
            
            % Create the panels
            h.panel.table = uix.BoxPanel( ...
                'Parent', h.mainLayout, ...
                'Title', 'data', 'Padding', 5, 'FontSize', 10);
            h.panel.img = uix.BoxPanel( ...
                'Parent', h.mainLayout, ...
                'Title', 'img', 'Padding', 5, 'FontSize', 10);
            % Adjust the main layout; auto sizing left twice as big
            h.mainLayout.Widths = [-1,-2];
            h.mainLayout.MinimumWidths = [400,400];
            
            % inside table boxpanel insert a vbox
            tableVbox = uix.VBox('Parent', h.panel.table);
            
            % make place for buttons/uicontrol inputs above table
            tableVboxHbox = uix.HBox('Parent', tableVbox, 'Padding', 5, 'Spacing', 5);
            
            % put a vbox with [text;uicontrol] inside the hbox
            tableUIcontrol_1 = uix.VBox('Parent', tableVboxHbox, 'Padding', 5, 'Spacing', 5); % wavelenght
            tableUIcontrol_2 = uix.VBox('Parent', tableVboxHbox, 'Padding', 5, 'Spacing', 5); % pixelpitch
            tableUIcontrol_3 = uix.VBox('Parent', tableVboxHbox, 'Padding', 5, 'Spacing', 5); % sort table button
            uix.Empty( 'Parent', tableVboxHbox); % whitespace left, auto resize this
            tableVboxHbox.MinimumWidths = [110,110,60,1];
            tableVboxHbox.Widths = [110,110,110,-1];
            
            uicontrol('Parent',tableUIcontrol_1,'Style','text','String','wavelength [nm]','HorizontalAlignment','left','FontSize',10);
            h.edit.wavelength = uicontrol('Parent',tableUIcontrol_1,'Style','edit','FontSize',10);
            uicontrol('Parent',tableUIcontrol_2,'Style','text','String','pixelpitch [µm]','HorizontalAlignment','left','FontSize',10);
            h.edit.pixelpitch = uicontrol('Parent',tableUIcontrol_2,'Style','edit','FontSize',10);
            uix.Empty( 'Parent', tableUIcontrol_3); % whitespace left to settings to limit sz of cmap popup
            h.pushbuttons.sortTable = uicontrol('Parent',tableUIcontrol_3,'Style','pushbutton','String','sort table','HorizontalAlignment','left','FontSize',10);
            
            tableUIcontrol_1.Heights = [20,25];
            tableUIcontrol_2.Heights = [20,25];
            tableUIcontrol_3.Heights = [1,25+19];
            
            % now make the table; put a little whitespace between buttons and table first
            uix.Empty( 'Parent', tableVbox); % whitespace left to settings to limit sz of cmap popup
            h.table = uitable(tableVbox,'Data', dat, 'ColumnName', cols, 'FontSize',10);
            h.table.ColumnWidth = {184,'auto','auto'};
            h.table.ColumnEditable = logical([0,1,1]);
            tableVbox.Heights = [80,10,-1];
            
            % inside table boxpanel insert a vbox
            imgVbox = uix.VBox('Parent', h.panel.img);
            imgHbox_1 = uix.HBox('Parent', imgVbox, 'Padding', 5, 'Spacing', 5);
            
            % make cmap selection top right
            h.pushbuttons.InpaintToggle = uicontrol(imgHbox_1,'Style','togglebutton','String','Inpainting');
            h.pushbuttons.InpaintProcess = uicontrol(imgHbox_1,'Style','pushbutton','String','Replace Selected');
            h.pushbuttons.InpaintUndo = uicontrol(imgHbox_1,'Style','pushbutton','String','Undo Inpaint');
            h.pushbuttons.HideOverexposed = uicontrol(imgHbox_1,'Style','togglebutton','String','Hide Overexposed','Visible',0);
            uix.Empty( 'Parent', imgHbox_1); % whitespace left to settings to limit sz of cmap popup
            h.popup.colormap = uicontrol(imgHbox_1,'Style','popupmenu','String',{'jet','gray'});
            imgHbox_1.Widths = [90,110,90,110,-1,60];
            
            % Create the axes on the left
            h.ax = axes( 'Parent', imgVbox);
                        
            h.image = imagesc(h.ax,nan);
            axis(h.ax,'image');
            hold(h.ax,'on')
            h.ax.Toolbar.Visible = 'on';
            colormap(h.ax,'jet');
            xlabel(h.ax,'pixel'), ylabel(h.ax,'pixel')
            h.axToolbar = axtoolbar(h.ax,'default');
            % init text for grayLevel
            h.txt = text(h.ax,1,1,'init','Color','k','FontSize',12,'VerticalAlignment','bottom','HorizontalAlignment','left','Visible',0);
            % init crosshair / position of mouse in image as invisible
            h.crosshair = struct();
            h.crosshair.x = xline(h.ax,1,'-.m','LineWidth',1.5,'Visible','off');
            h.crosshair.y = yline(h.ax,1,'-.m','LineWidth',1.5,'Visible','off');
            % init plot for highlighting overexposed pixels
            h.overexposed = plot(h.ax,1,1,'om','MarkerSize',6,'MarkerFaceColor','m','Visible','off');
            % init plot for highlighting inpainting
            h.inpainting = plot(h.ax,nan,nan,'+y','MarkerSize',8,'MarkerFaceColor','none','Visible','off');
            % init measurement line as nan (invisible)
            h.rect = rectangle(h.ax,'Position',[1,1,1,1],'Visible','off','LineStyle','-','LineWidth',1.5,'EdgeColor','m');
            h.skipRect = rectangle(h.ax,'Position',[1,1,1,1],'Visible','off','LineStyle','none','FaceColor',[1,0,0,0.3]);
            
            % put sliders below image
            % CAxis lo/hi slider
            uix.Empty('Parent', imgVbox);
            uicontrol('Parent', imgVbox,'Style','text',...
                'String','CAxis Low / High','FontSize',12);
            CAxisHBox = uix.HBox('Parent', imgVbox, 'Padding', 0, 'Spacing', 5);
            h.sliders.CAxisLO = uicontrol( 'Parent', CAxisHBox, 'Style','slider', 'Background', 'w',...
                'value',0,'min',0,'max',255);
            h.sliders.CAxisHI = uicontrol( 'Parent', CAxisHBox, 'Style','slider', 'Background', 'w',...
                'value',255,'min',0,'max',255);
            uix.Empty('Parent', imgVbox);
            
            IMGButtonBox = uix.HBox('Parent', imgVbox, 'Padding', 0, 'Spacing', 5);
            uix.Empty( 'Parent', IMGButtonBox); % whitespace left to settings to limit sz of cmap popup
            h.pushbuttons.ReadFiles = uicontrol('Parent',IMGButtonBox,'Style','pushbutton','String','Load files','HorizontalAlignment','left','FontSize',10);
            h.pushbuttons.OKExit = uicontrol('Parent',IMGButtonBox,'Style','pushbutton','String','OK / Exit','HorizontalAlignment','left','FontSize',10);
            IMGButtonBox.Widths = [-3,100,100];
            
            imgVbox.Heights = [33,-1,10,25,25,20,30];
            hold(h.ax,'off')
        end
        
    end
    
    methods(Static, Access = private)
        
        function n_out = nextSmallestOddInteger(n)
            % returns next smallest odd integer
            % works with arbitrary size numeric input
            n_out = 2*ceil(n/2) - 1;
        end
        
    end
    
end