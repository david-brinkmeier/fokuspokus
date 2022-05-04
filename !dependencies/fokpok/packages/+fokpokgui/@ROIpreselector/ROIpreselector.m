classdef ROIpreselector < handle
    % gui for generation of x * y grid of ROIs
    % output cell of masks can be used to construct src imagestack for
    % imstack and be used in beam analysis
    %
    % call
    % obj = ROIpreselector(img,xnum,ynum)
    % this initializes a grid xnum*ynum ROIs w/ gui based in the provided
    % snapshot image "img"
    
    properties (SetAccess = private, GetAccess = public)
        abort                   (1,1) logical % use this flag to interpret save/exit vs. abort
        handles
        rois                           cell    % cell of masks/rois
        
        xIdx                    (:,1) double
        yIdx                    (:,1) double
        xIdxLookup              (:,1) double
        yIdxLookup              (:,1) double
    end
    
    properties (Access = private)
        xScale                  (1,1) double
        yScale                  (1,1) double
        xShear                  (1,1) double
        yShear                  (1,1) double
        xOffset                 (1,1) double
        yOffset                 (1,1) double
        roiSize                 (1,1) double
        
        img                     (:,:) double
        imbounds                      struct
        rects_x                 (1,:) double
        rects_y                 (1,:) double
        numOfPoints             (1,1) double
        points_src              (3,:) double
        
        collisionTimer          (1,1) uint64 % tic timer        
        figBeingResizedTimer    (1,1) uint64 % tic timer
        
        updateIMG               (1,1) logical % when img is a gcam class image can be continously updated
        timer                         timer
        frameCount              (1,1) uint32 
    end
    
    properties (Dependent, Access = private)
        figexists               (1,1) logical
        points                  (3,:) double % array of grid points
        shearmt                 (3,3) double % 2D shear/scale/translation matrix in homogeneous coordinates
        rects                         struct % internal storage for rectangle/roi specification
    end
    
    methods
        function obj = ROIpreselector(img,etalonSpec)
            % init abort as true and rois as cell of masks
            obj.abort = true;
            obj.collisionTimer = tic;
            obj.updateIMG = false;
            obj.frameCount = 0;
            
            % get img spec, init rois as cell of masks
            obj.numOfPoints = etalonSpec.xnum*etalonSpec.ynum;
            
            if isequal(class(img),'gcam')
                obj.updateIMG = true;
                obj.img = img.IMG;
            elseif isnumeric(img)
                obj.img = img;
            else
                error('img passed to ROIpreselector must be numeric/matrix/image or gcam object')
            end
            
            [ymax,xmax] = size(obj.img,1:2);
            
            obj.imbounds = struct('x',[1, xmax],'y',[1, ymax]);
            obj.rois = cell(obj.numOfPoints,1);
            obj.rois(:) = {mask()};

            % point grid / indices
            xnum = etalonSpec.xnum;
            ynum = etalonSpec.ynum;
            obj.xIdx = etalonSpec.xIdxLin;
            obj.yIdx = etalonSpec.yIdxLin;
            obj.xIdxLookup = etalonSpec.xIdxLookup;
            obj.yIdxLookup = etalonSpec.yIdxLookup;
            
            % init data structure required to apply transform matrix
            obj.points_src = [etalonSpec.xIdxLin.'; etalonSpec.yIdxLin.'; ones(1,obj.numOfPoints)];
            
            % set starting values for shear / points
            if isequal(class(img),'gcam')
                obj.xScale = etalonSpec.camSeparationX/img.pixelSize;
                obj.yScale = etalonSpec.camSeparationY/img.pixelSize;
                obj.roiSize = min([obj.xScale,obj.yScale])/2;
            else
                obj.xScale = xmax/xnum;
                obj.yScale = ymax/ynum;
                obj.roiSize = min([xmax,ymax])/(2*max([xnum,ynum]));
            end
                
            obj.xShear = 0;
            obj.yShear = 0;
            obj.xOffset = obj.roiSize/2;
            obj.yOffset = obj.roiSize/2;
            
            % init fig and draw initial rois
            obj.handles = obj.initfig(obj.img,xnum,ynum,obj.xScale,obj.yScale,obj.roiSize);
            obj = drawROIs(obj);
                        
            % arm listeners / callbacks
            addlistener(obj.handles.sliders.xScale, 'Value', 'PostSet', @(hobj,event) obj.checkSliders('xScale'));
            addlistener(obj.handles.sliders.yScale, 'Value', 'PostSet', @(hobj,event) obj.checkSliders('yScale'));
            addlistener(obj.handles.sliders.xShear, 'Value', 'PostSet', @(hobj,event) obj.checkSliders('xShear'));
            addlistener(obj.handles.sliders.yShear, 'Value', 'PostSet', @(hobj,event) obj.checkSliders('yShear'));
            addlistener(obj.handles.sliders.xOffset, 'Value', 'PostSet', @(hobj,event) obj.checkSliders('xOffset'));
            addlistener(obj.handles.sliders.yOffset, 'Value', 'PostSet', @(hobj,event) obj.checkSliders('yOffset'));
            addlistener(obj.handles.sliders.roiSize, 'Value', 'PostSet', @(hobj,event) obj.checkSliders('roiSize'));
            
            % arm button callbacks
            set(obj.handles.buttons.saveExit, 'Callback', @(hobj,event) obj.checkButtons('saveExit'))
            set(obj.handles.buttons.abort, 'Callback', @(hobj,event) obj.checkButtons('abort'))
            
            % arm help requests
            set(obj.handles.panel.view, 'HelpFcn', @(hobj,event) obj.getHelp('mainWindow'))
            
            % handle close requests
            set(obj.handles.fig,'CloseRequestFcn',@(hobj,event) obj.closeGui);
            % last ditch resort to avoid gui layout toolbox throwing errors
            % when resizing while other timers being executed
            set(obj.handles.fig,'SizeChangedFcn',@(hobj,event) obj.figSizeChanged);
            
            if obj.updateIMG
                % it's a gcam, update frame every so often...
                obj.timer = timer('TimerFcn',@(hObject,event) obj.updateTimerVals(img),...
                                  'StartDelay',1.5,'Period',1,'ExecutionMode','fixedDelay','BusyMode','queue');
                start(obj.timer);
            end
            
            % block program execution until this gui is closed/deleted
            obj.figBeingResizedTimer = tic;
            obj.handles.fig.WindowState = 'maximized';
            waitfor(obj.handles.fig)
        end        
        
        function set.xScale(obj,var)
            oldVar = obj.xScale;
            obj.xScale = var;
            if isValidTransform(obj)
                drawROIs(obj);
            else
                obj.xScale = oldVar;
            end
        end
        
        function set.yScale(obj,var)
            oldVar = obj.yScale;
            obj.yScale = var;
            if isValidTransform(obj)
                drawROIs(obj);
            else
                obj.yScale = oldVar;
            end
        end
        
        function set.xShear(obj,var)
            oldVar = obj.xShear;
            obj.xShear = var;
            if isValidTransform(obj)
                drawROIs(obj);
            else
                obj.xShear = oldVar;
            end
        end
        
        function set.yShear(obj,var)
            oldVar = obj.yShear;
            obj.yShear = var;
            if isValidTransform(obj)
                drawROIs(obj);
            else
                obj.yShear = oldVar;
            end
        end
        
        function set.xOffset(obj,var)
            oldVar = obj.xOffset;
            obj.xOffset = var;
            if isValidTransform(obj)
                drawROIs(obj);
            else
                obj.xOffset = oldVar;
            end
        end
        
        function set.yOffset(obj,var)
            oldVar = obj.yOffset;
            obj.yOffset = var;
            if isValidTransform(obj)
                drawROIs(obj);
            else
                obj.yOffset = oldVar;
            end
        end
        
        function set.roiSize(obj,var)
            oldVar = obj.roiSize;
            obj.roiSize = var;
            if isValidTransform(obj)
                drawROIs(obj);
            else
                obj.roiSize = oldVar;
            end
        end
        
        function var = get.rects(obj)
            var = struct('x',obj.points(1,:),'y',obj.points(2,:),...
                         'lenx',repelem(obj.roiSize,obj.numOfPoints),'leny',repelem(obj.roiSize,obj.numOfPoints));
        end
        
        function var = get.shearmt(obj)
            var = [obj.xScale, obj.xShear, obj.xOffset;...
                   obj.yShear, obj.yScale, obj.yOffset;...
                   0         , 0         , 1];
        end
        
        function var = get.points(obj)
            var = obj.shearmt * obj.points_src;
        end
        
        function var = get.figexists(obj)
            var = false;
            if isfield(obj.handles,'fig')
                if isvalid(obj.handles.fig)
                    var = true;
                end
            end
        end
        
        function figSizeChanged(obj)
            % restart ticwatch that detects figure change
            % this in turn affects execution of timer-dependent updates
            % why?? when fig is busy doing internal timers this can cause
            % errors because gui layout toolbox callbacks cannot be
            % executed
            if toc(obj.figBeingResizedTimer) > 0.3
                obj.figBeingResizedTimer = tic;
            end
        end
        
        function closeGui(obj)
            if obj.updateIMG
                % stop timer
                stop(obj.timer)
                delete(obj.timer)
            end
            % kill fig
            delete(obj.handles.fig)
        end
        
        function obj = getHelp(obj,type)
            switch type
                case 'mainWindow'
                    msgbox({'\fontsize{11}Make an approximate ROI Selection.',...
                        'At this stage it is better to overestimate ROI size than to underestimate!'},...
                        'ROI Selection', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
            end
        end
        
        function obj = checkButtons(obj,type)
            switch type
                case 'saveExit'
                    obj.abort = false;
                    % make sure actual roiSize is odd edge length
                    edgelen = min(mask.ceilToOdd(obj.rects.lenx(1)),mask.ceilToOdd(obj.rects.leny(1))) - 1;
                    for i = 1:obj.numOfPoints
                        obj.rois{i}.refsz = obj.img;
                        obj.rois{i}.selection = floor([obj.rects.x(i), obj.rects.y(i), edgelen, edgelen]);
                    end
                    obj.closeGui();
                case 'abort'
                    obj.closeGui();
            end
        end
        
        function checkSliders(obj,type)
            % set value as slider value
            % then value setter verifies collision and updates rectangles
            % set slider value explicitly to value, ensuring valid value
            switch type
                case 'xScale'
                    obj.xScale = obj.handles.sliders.xScale.Value;
                    obj.handles.sliders.xScale.Value = obj.xScale;
                case 'yScale'
                    obj.yScale = obj.handles.sliders.yScale.Value;
                    obj.handles.sliders.yScale.Value = obj.yScale;
                case 'xShear'
                    obj.xShear = obj.handles.sliders.xShear.Value;
                    obj.handles.sliders.xShear.Value = obj.xShear;
                case 'yShear'
                    obj.yShear = obj.handles.sliders.yShear.Value;
                    obj.handles.sliders.yShear.Value = obj.yShear;
                case 'xOffset'
                    obj.xOffset = obj.handles.sliders.xOffset.Value;
                    obj.handles.sliders.xOffset.Value = obj.xOffset;
                case 'yOffset'
                    obj.yOffset = obj.handles.sliders.yOffset.Value;
                    obj.handles.sliders.yOffset.Value = obj.yOffset;
                case 'roiSize'
                    obj.roiSize = obj.handles.sliders.roiSize.Value;
                    obj.handles.sliders.roiSize.Value = obj.roiSize;
            end
        end
        
        function updateTimerVals(obj,gcam)
            if toc(obj.figBeingResizedTimer) > 0.5
                gcam.grabFrame()
                obj.frameCount = obj.frameCount+1;
                obj.handles.image.CData = gcam.IMG;
                obj.handles.panel.view.Title = sprintf('Image (gige), frame: %i',obj.frameCount);
            end
        end
        
        function obj = drawROIs(obj)
            rectPos = @(rects,i) [rects.x(i), rects.y(i), rects.lenx(i), rects.leny(i)];
            if obj.figexists
                if ~isfield(obj.handles,'rects')
                    % gen struct for rectangles and labels
                    obj.handles.rects = struct('rect',cell(1,obj.numOfPoints),...
                                               'txt',cell(1,obj.numOfPoints));
                    % initialize ROIs
                    for i = 1:obj.numOfPoints
                        obj.handles.rects(i).rect = rectangle(obj.handles.ax,'Position',rectPos(obj.rects,i),...
                                                              'LineWidth',1.5,'EdgeColor','w');
                        obj.handles.rects(i).txt = text(obj.handles.ax,...
                                                        obj.rects.x(i),...
                                                        obj.rects.y(i),...
                                                        sprintf('[%i,%i] (%i)',obj.xIdxLookup(i),obj.yIdxLookup(i),i),...
                                                        'FontSize',11,'Color','w','VerticalAlignment','bottom');
                    end
                else
                    for i = 1:obj.numOfPoints
                        % update position of roi and label
                        obj.handles.rects(i).rect.Position = rectPos(obj.rects,i);
                        obj.handles.rects(i).txt.Position = [obj.rects.x(i), obj.rects.y(i)];
                    end
                end
            end
        end
                
        function isValid = isValidTransform(obj)
            isValid = true;
            % assume that if fig does not exist then this is just fig
            % initialization so we dont care
            if obj.figexists
                newPoints = obj.shearmt * obj.points_src;
                newRects = struct('x',newPoints(1,:),'y',newPoints(2,:),...
                                  'lenx',repelem(obj.roiSize,obj.numOfPoints),...
                                  'leny',repelem(obj.roiSize,obj.numOfPoints));
                
                CollideOrBreach = obj.checkCollision(newRects,obj.imbounds);
                if CollideOrBreach
                    isValid = false;
                    alertUserToCollision(obj)
                end
            end
        end
        
        function alertUserToCollision(obj)
            info = rendererinfo(obj.handles.ax);
            % if software renderer then dont alert bc of bad performance
            if ~strcmpi(info.GraphicsRenderer,'OpenGL Software')
                % animates collision, but not more often than every n sec
                if toc(obj.collisionTimer) > 0.7
                    collisionRect = rectangle(obj.handles.ax,'Position',...
                                              [1,1,obj.imbounds.x(2),obj.imbounds.y(2)],...
                        'LineStyle','none','FaceColor',[1,0,0,0]);
                    alpharange = [linspace(0.1,0.5,20), linspace(0.5,0.1,20)];
                    for i = 1:length(alpharange)
                        collisionRect.FaceColor = [1,0,0,alpharange(i)];
                        drawnow
                    end
                    delete(collisionRect)
                    obj.collisionTimer = tic;
                end
            end
        end
        
    end
    
    methods (Static, Access = private)
        
        function h = initfig(img,xnum,ynum,xScale,yScale,roiSize)
            % get img spec, required for slider value ranges
            [ymax,xmax] = size(img,1:2);
            
            % initializes gui
            h = struct();
            h.sliders = struct();
            h.buttons = struct();
            
            % init fig
            h.fig = figure( ...
                'Color','white',...
                'Name', 'ROI PreSelector', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'Toolbar', 'none', ...
                'WindowStyle', 'modal',...
                'HandleVisibility', 'off');
            
            % Arrange the main interface
            h.mainLayout = uix.HBoxFlex( 'Parent', h.fig, 'Spacing', 3 );
            
            % Create the panels
            h.panel.view = uix.BoxPanel( ...
                'Parent', h.mainLayout, ...
                'Title', 'Image (Snapshot)','FontSize', 10);
            h.panel.control = uix.BoxPanel( ...
                'Parent', h.mainLayout, ...
                'Title', 'Settings','FontSize', 10);
            % Adjust the main layout; auto sizing left twice as big
            set( h.mainLayout, 'Widths', [-2,-1]  );
            
            % inside right boxpanel insert a vbox
            h.panel.controlBox = uix.VBox( ...
                'Parent', h.panel.control);
            % inside left boxpanel insert an axes
            h.panel.viewcontainer = uicontainer( ...
                'Parent', h.panel.view );
            
            % Create the axes on the left
            h.ax = axes( 'Parent', h.panel.view );
            
            h.image = imagesc(h.ax,img);
            xlim(h.ax,[1, size(img,2)]), ylim(h.ax,[1, size(img,1)])
            xlabel(h.ax,'x [px]'), ylabel(h.ax,'y [px]')
            axis(h.ax,'image'); % must be set after imagesc
            colormap(h.ax,'jet');
            
            % init Sliders
            % xScale
            uicontrol('Parent', h.panel.controlBox,'Style','text',...
                'String','xDist','FontSize',12);
            h.sliders.xScale = uicontrol( 'Parent', h.panel.controlBox, 'Style','slider', 'Background', 'w',...
                'value',xScale,'min',0,'max',xmax/(xnum-1),'SliderStep',[0.001,0.05]);
            % yScale
            uicontrol('Parent', h.panel.controlBox,'Style','text',...
                'String','yDist','FontSize',12);
            h.sliders.yScale = uicontrol( 'Parent', h.panel.controlBox, 'Style','slider', 'Background', 'w',...
                'value',yScale,'min',0,'max',ymax/(ynum-1),'SliderStep',[0.001,0.05]);
            %xShear
            uicontrol('Parent', h.panel.controlBox,'Style','text',...
                'String','xShear','FontSize',12);
            h.sliders.xShear = uicontrol( 'Parent', h.panel.controlBox, 'Style','slider', 'Background', 'w',...
                'value',0,'min',-0.5*(xmax/(xnum-1)),'max',0.5*(xmax/(xnum-1)),'SliderStep',[0.001,0.05]);
            %yShear
            uicontrol('Parent', h.panel.controlBox,'Style','text',...
                'String','yShear','FontSize',12);
            h.sliders.yShear = uicontrol( 'Parent', h.panel.controlBox, 'Style','slider', 'Background', 'w',...
                'value',0,'min',-0.5*(ymax/(ynum-1)),'max',0.5*(ymax/(ynum-1)),'SliderStep',[0.001,0.05]);
            %xOffset
            uicontrol('Parent', h.panel.controlBox,'Style','text',...
                'String','xOffset','FontSize',12);
            h.sliders.xOffset = uicontrol( 'Parent', h.panel.controlBox, 'Style','slider', 'Background', 'w',...
                'value',0.5*min([xmax,ymax])/(2*max([xnum,ynum])),'min',1,'max',xmax,'SliderStep',[0.001,0.05]);
            %yOffset
            uicontrol('Parent', h.panel.controlBox,'Style','text',...
                'String','yOffset','FontSize',12);
            h.sliders.yOffset = uicontrol( 'Parent', h.panel.controlBox, 'Style','slider', 'Background', 'w',...
                'value',0.5*min([xmax,ymax])/(2*max([xnum,ynum])),'min',1,'max',ymax,'SliderStep',[0.001,0.05]);
            %roiSize
            uicontrol('Parent', h.panel.controlBox,'Style','text',...
                'String','roiSize','FontSize',12);
            h.sliders.roiSize = uicontrol( 'Parent', h.panel.controlBox, 'Style','slider', 'Background', 'w',...
                'value',roiSize,...
                'min',0.25*roiSize,...
                'max',max([xmax,ymax])/max([xnum,ynum]),...
                'SliderStep',[0.001,0.05]);
            
            % lower button grid
            h.panel.controlBoxTile = uix.HBox( ...
                'Parent', h.panel.controlBox, 'Padding', 5, 'Spacing', 5);
            
            h.buttons.saveExit = uicontrol( 'Parent', h.panel.controlBoxTile,'Style','pushbutton', 'String', 'Save/Exit' );
            h.buttons.abort = uicontrol( 'Parent', h.panel.controlBoxTile,'Style','pushbutton', 'String', 'Abort' );
            % adjust relative size of buttons
            set( h.panel.controlBoxTile, 'Widths', [-3,-1]);
            
            % every text/slider 18px and slider autoSize, lower button grid gets 50px
            set( h.panel.controlBox, 'Heights', [repmat([18,-1],[1,7]),50], 'Spacing', 10 );
        end
    end
    
    methods (Static, Access = private)
        
        function [CollideOrBreach,collisionMatrix,uniqueCollisions,boundaryBreach] = checkCollision(rects,bounds)
            % inspired by http://jeffreythompson.org/collision-detection/point-rect.php
            %
            % this function checks a number of squares (rects) for collision and additionally
            % determines if any edge point of a rectangle breaches defined boundaries (bounds)
            %
            % rect is a struct w/ rect.x, rect.y, rect.lenx, rect.leny, all of which must be of
            % equal length
            % rect.x is xStart, rect.y is yStart, rect.lenx is edge length x, rect.leny is edge length y
            %
            % bounds is a struct of bounds.x = [xStart xEnd], bounds.y = [yStart yEnd]
            % which defines the boundaries within which the rectangles must exist
            %
            % OUTPUT
            %
            % CollideOrBreach - boolean, if true then there is a Collision and / or Breach
            %
            % collisionMatrix - n*n matrix for n rectangles. nan if no Collision.
            % if there is a collision then rectangle of [row] collides with [column]
            %
            % uniqueCollisions - index list of rectangles which participate in a collision
            %
            % boundaryBreach - index list of rectangles which participate in a boundary breach
            
            % collect some info
            numOfRects = length(rects.x);
            range = 1:numOfRects;
            
            % 1st check: Check boundary breach
            boundaryBreach = false(1,numOfRects);
            for i = 1:numOfRects
                % get points for current rectangle
                px = [rects.x(i), rects.x(i)+rects.lenx(i), rects.x(i),                 rects.x(i)+rects.lenx(i)];
                py = [rects.y(i), rects.y(i),               rects.y(i)+rects.leny(i),   rects.y(i)+rects.leny(i)];
                
                if any((px < bounds.x(1)) | (px > bounds.x(2))) || any((py < bounds.y(1)) | (py > bounds.y(2)))
                    % then rectangle i is outisde of bounds
                    boundaryBreach(i) = true;
                end
            end
            
            % 2nd check: Check rectangle-rectangle collisions
            % collisionMatrix: rectangle in [row] collides with
            collisionMatrix = nan(numOfRects,numOfRects);
            
            for i = 1:numOfRects
                % get points for current rectangle
                px = [rects.x(i), rects.x(i)+rects.lenx(i), rects.x(i),                 rects.x(i)+rects.lenx(i)];
                py = [rects.y(i), rects.y(i),               rects.y(i)+rects.leny(i),   rects.y(i)+rects.leny(i)];
                % for all points check all rectangles but rectangle i
                collidesWith = nan(1,numOfRects);
                for j = range(range ~= i)
                    % rectangle X always collides with itself, range(range ~= i) ensures we skip self-collision chk
                    ptcheck = false(1,4);
                    for k = 1:4
                        % check if any edge point px/py is inside this rectangle
                        if     (px(k) >= rects.x(j) &&...                   %right of the left edge AND
                                px(k) <= rects.x(j) + rects.lenx(i) &&...   %left of the right edge AND
                                py(k) >= rects.y(j) &&...                   %below the top AND
                                py(k) <= rects.y(j) + rects.leny(i))        %above the bottom
                            
                            % then point is inside of the rectangle
                            ptcheck(k) = true;
                        else
                            ptcheck(k) = false;
                        end
                    end
                    if any(ptcheck)
                        collidesWith(j) = j;
                    end
                end
                collisionMatrix(i,:) = collidesWith;
            end
            % uniqueCollisions provides the rectangle indices which have at least one collision
            uniqueCollisions = unique(collisionMatrix(~isnan(collisionMatrix)));
            
            % CollideOrBreach is a bool in case we only care about if there is any collision/breach anywhere
            if any(uniqueCollisions) || any(boundaryBreach)
                CollideOrBreach = true;
            else
                CollideOrBreach = false;
            end
        end
    end
end