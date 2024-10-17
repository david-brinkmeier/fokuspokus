classdef imstack
    % manages all data / structures for beam profile analysis
    
    properties (Access = public)
        pixelpitch      (1,1)   double
        wavelength      (1,1)   double
        settings        (1,1)   settings.settingscontainer
        figs            (1,1)   plots.plotcontainer
        dontCountOrSave (1,1)   logical % force disables counting / saving figs
        logmask         (:,1)   logical % an optional vector can be provided to select which frames within the stack should be used to analysis
    end
    
    properties (SetAccess = protected)
        img             (1,1)   imgstack.imgcontainer
        axis            (1,1)   imgstack.axiscontainer
        moments         (1,1)   imgstack.momentscontainer
        results         (1,1)   fitresults.resultsxy
        counter         (1,1)   uint32
        stats           (1,1)   imgstack.stats
        timeString      (1,:)   char
        uuid            (1,:)   char
        state           (1,1)   logical % true if all inputs OK, false if processing must be aborted bc of problem
        processed       (1,1)   logical % true if at least one frame has been processed
        uuid_internal   (1,:)   char
    end
    
    properties (SetAccess = private, GetAccess = protected)
        time_internal   (1,1)   double
    end
    
    properties(Dependent, Access = public)
        time            (1,1)   double
        zPos            (1,:)   double
        workingFolder   (1,:)   char
    end
    
    properties (Dependent, GetAccess = private)
        currentIMG          double % used to update/error check writing obj.img.src,
                                   % otherwise essentially pointer to obj.img.src
        denoisedIMG         double % used to update/error check writing obj.img.denoised
                                   % otherwise essentially pointer to obj.img.denoised
    end
    
    methods
        % constructor and/or resetter
        function obj = imstack()
            obj.dontCountOrSave = false;
            obj.counter = 1;
            obj.time = nan;
            obj.figs = plots.plotcontainer();
            obj.settings = settings.settingscontainer();
            obj.results = fitresults.resultsxy();
            obj.uuid = 'init';
            obj.uuid_internal = obj.mkNewUUID();
        end
        
        function obj = set.time(obj,val)
            obj.time_internal = val;
            if isnan(val)
                obj.timeString = [];
                return
            end
            if val < 3600
                obj.timeString = datestr(seconds(val),'MM:SS.FFF');
            else
                obj.timeString = datestr(seconds(val),'HH:MM:SS.FFF');
            end
        end
        
        function val = get.time(obj)
           val = obj.time_internal; 
        end
        
        function obj = set.workingFolder(obj,val)
            obj.figs.workingFolder = val;
        end
        
        function val = get.workingFolder(obj)
           val = obj.figs.workingFolder; 
        end
        
        function val = get.zPos(obj)
            val = obj.axis.src.z;
            if ~isempty(obj.logmask)
                if length(obj.axis.src.z) == length(obj.logmask)
                    val = obj.axis.src.z(obj.logmask);
                else
                    warning('Logmask is provided, but the length does not match the slices in the image stack. Ignoring.')
                end
            end
        end
        
        function obj = set.zPos(obj,input)
            if length(input) < 2
                error('At least two z-Positions are required to fit a beam caustic...')
            end
            if ~isequal(input,sort(input))
                warning('Provided z-Positions are not sorted in ascending order. If this is intentional, ignore this message.')
            end
            obj.axis.src.z = input;
            obj.axis.denoised.z = input;
            
            % spec mightve changed, force plot update whenever zpos updated
            for i = 1:length(obj.figs.isplot)
                obj.figs.(obj.figs.isplot{i}).settings.update_fig = true;
            end
        end
        
        function obj = set.pixelpitch(obj,input)
            obj.pixelpitch = abs(input);
            obj = obj.updateaxis();
        end
        
        function obj = set.wavelength(obj,input)
            obj.wavelength = abs(input);
        end
        
        function obj = set.currentIMG(obj,img)
            % used to update obj.img.src
            sz = size(img,1:2);
            obj.state = true;
            if ~all(bitget(sz,1))
                % then x and/or y dimension is of even length, can't have that
                errordlg('\fontsize{12}Cannot set currentIMG: x/y dimension must be of odd length for further processing.','imstack.set.currentIMG',...
                    struct('Interpreter','tex','WindowStyle','modal'))
                obj.state = false;
            end
            if any(~isfinite(img),'all')  
                errordlg('\fontsize{12}Image contains NaN or INF values. Not allowed for set.currentIMG.','imstack.set.currentIMG',...
                    struct('Interpreter','tex','WindowStyle','modal'))
                obj.state = false;
            end
            % ok then write to img.src
            obj.img.src = img;
            % when src axis does not fit src image then update src axis
            if ~isequal([length(obj.axis.src.y), length(obj.axis.src.x)],sz)
                [obj.axis.src.x,obj.axis.src.y] = obj.genaxis(sz,obj.pixelpitch);
                if obj.img.ROIenabled
                    % and also delete ROIs if they exist, they can't match new image!
                    warning('New input image(s) has different x/y dimensions. ROIs have been cleared!');
                    obj = obj.resetROI();
                end
            end
            % check if new image fits the exisiting z-pos definition
            if ~isequal(size(obj.img.src,3),length(obj.axis.src.z))
                warning('Image stack has %i images, but only %i z-positions are provided.',...
                    size(obj.img.src,3),length(obj.axis.src.z))
                errordlg('\fontsize{12}Image stack has more images than there are z-positions.','imstack.set.currentIMG',...
                    struct('Interpreter','tex','WindowStyle','modal'))
                obj.state = false;
            end
        end
        
        function val = get.currentIMG(obj)
            val = obj.img.src; % only handle to img.src
            if ~isempty(obj.logmask) && (length(obj.axis.src.z) == length(obj.logmask))
                val = obj.img.src(:,:,obj.logmask);    
            end
        end
        
        function obj = set.denoisedIMG(obj,img)
            % used to update obj.img.src
            sz = size(img,1:2);
            if ~all(bitget(sz,1))
                % then x and/or y dimension is of even length, can't have that
                errordlg('\fontsize{12}set.denoisedIMG: x/y dimension of img must be of odd length for further processing.','imstack',...
                    struct('Interpreter','tex','WindowStyle','modal'))
                error('x/y dimension of img.denoised must be of odd length for further processing')
            end
            obj.img.denoised = img;
            % when src axis does not fit src image then update src axis
            if ~isequal([length(obj.axis.denoised.y), length(obj.axis.denoised.x)],sz)
                [obj.axis.denoised.x,obj.axis.denoised.y] = obj.genaxis(sz,obj.pixelpitch);
            end
        end
        
        function denoisedIMG = get.denoisedIMG(obj)
            denoisedIMG = obj.img.denoised; % only handle to img.denoised
        end
    end
    
    %% private
    
    methods (Access = public)

        function updatePlots(obj)
            if obj.processed
                for i = 1:length(obj.figs.isplot)
                    if obj.figs.(obj.figs.isplot{i}).settings.enable
                        obj.(obj.figs.isplot{i})(true);
                    end
                end
            end
        end
        
        function obj = process(obj,img)
            % if plot callbacks are active they must be disabled because of
            % all the data will be exported if .fig is saved
            if obj.figs.callbacksActive
                obj.plotCallbacks(0);
                obj.figs.callbacksActive = 0;
            end
            
            % set image
            if nargin == 1 && isempty(obj.currentIMG)
                msgbox('\fontsize{12}Call to imstack.process() without provided image AND there exists no previous imstack.currentIMG. Aborting.','imstack.process',...
                    struct('Interpreter','tex','WindowStyle','modal'))
                return
            elseif nargin == 2
                obj.currentIMG = img;
                if ~obj.state
                    return
                end
            end
            obj.uuid = [datestr(now,'HHMMSS_FFF_'),obj.uuid_internal];
            
            % first run check 4 conflicts
            if obj.counter == 1
                abort = obj.settings.checkSettingsConflicts(obj);
                if abort
                    return
                end
            end
            
            % ROI stuff
            % note: ResetROI must be triggered by User if existing ROIs should be deleted
            % UNLESS the new image is of a different size, in that case
            % ROIs are deleted by set.currentIMG because old ROIs and image are incompatible!
            updateGuiROI = obj.settings.ROI.guiROI;
            if updateGuiROI
                obj = obj.guiROI();
            end
            % start timer
            timerVal = tic;
            
            % only update autoROI if enabeld AND every Nth frame
            updateAutoROI = (obj.settings.ROI.autoROI && obj.makeUpdate(obj.counter,obj.settings.ROI.updateEveryNframes));
            if updateAutoROI || (obj.settings.ROI.autoROI && isempty(obj.img.ROI))
                obj = obj.autoROI();
            end
            
            % Denoise
            obj = obj.denoise();
            % Moments
            obj = obj.calcmoments();
            % FIT
            obj = obj.makefit();
            % translate/center images for caustic plot
            obj = obj.center();
            
            % save time spent on analysis excluding guiROI/setcurrentIMG
            tAnalysis = toc(timerVal);
            
            % now check which plots to update
            % pretty verbose...basically this iterates over every plot specified in figs.isplot and
            % updates/draws every plot using obj.plot if it's the first frame or every nth frame
            % this requires that plot function obj.plot follows the same naming scheme as plot structs in obj.figs
            plotsUpdated = false;
            for i = 1:length(obj.figs.isplot)
                if obj.figs.(obj.figs.isplot{i}).settings.enable
                    if obj.makeUpdate(obj.counter,obj.figs.(obj.figs.isplot{i}).settings.updateEveryNframes)
                        plotsUpdated = true;
                        try
                            obj.(obj.figs.isplot{i})(obj.dontCountOrSave);
                        catch ME
                            warning('Something went wrong attempting to update "%s"',obj.figs.(obj.figs.isplot{i}).settings.name);
                            errorMessage = sprintf('Error %s\n in %s() at line %i.\n%s',ME.identifier, ME.stack(1).name, ME.stack(1).line, ME.message);
                            warndlg(errorMessage,[obj.figs.isplot{i},'.m']);
                        end
                    end
                end
            end
            % drawnow required?
            if plotsUpdated
                drawnow
            end
            % save time spent on plotting / other statistics
            tPlot = toc(timerVal)-tAnalysis;
            % update stats
            obj.stats = obj.stats.updatestats(tAnalysis,tPlot,updateGuiROI,updateAutoROI);
            % advance counter / set flag
            obj.counter = obj.counter+1;
            obj.processed = 1;
        end
        
        function obj = resetROI(obj)
            obj.img.ROI = [];
        end
        
        function obj = ForceAutoROI(obj)
            if ~isempty(obj.currentIMG)
                obj = obj.autoROI();
            else
                msgbox({'\fontsize{12}Cannot start autoROI because there is no image.',...
                        'Grab a frame / provide an image first!'},'imstack',...
                    struct('Interpreter','tex','WindowStyle','modal'))
            end
        end
        
        function obj = ForceGuiROI(obj)
            if ~isempty(obj.currentIMG)
                obj = obj.guiROI();
            else
                msgbox({'\fontsize{12}Cannot start guiROI because there is no image.',...
                        'Grab a frame / provide an image first!'},'imstack',...
                    struct('Interpreter','tex','WindowStyle','modal'))
            end
        end
        
        function obj = resetCounter(obj)
            obj.time = nan;
            obj.counter = 1;
            obj.figs.resetCounter()
            obj.uuid_internal = obj.mkNewUUID();
            obj.stats = imgstack.stats();
        end
        
        % plots
        % plot 1 / slice plot
        plot1(obj,dontCountOrSave); % slice plot, h are handles to plot1, i.e. h = obj.figs.plot1
        plot2(obj,dontCountOrSave); % 2d caustic plot, h are handles to plot1, i.e. h = obj.figs.plot1
        plot3(obj,dontCountOrSave); % plots a single beam profile with 2nd moments ellipse (denoised,centered)
        plot4(obj,dontCountOrSave); % plots a single beam profile with 2nd moments ellipse vs. src img + roi (if exist)
        
        function plotCallbacks(obj,enable)
            % enables callbacks for relevant figures; handling should be
            % done by external GUI based on timers and/or state of processing
            if (isfield(obj.figs.plot3,'fig') && isvalid(obj.figs.plot3.fig))
                % apparently cant set callback when axtoolbar is active...
                obj.disableToolbarButtons(obj.figs.plot3.axToolbar)
                if enable
                    obj.figs.callbacksActive = true;
                    set(obj.figs.plot3.fig,'WindowScrollWheelFcn', @obj.plot3Callback);
                elseif ~enable
                    set(obj.figs.plot3.fig,'WindowScrollWheelFcn', []);
                end
            end
            if (isfield(obj.figs.plot4,'fig') && isvalid(obj.figs.plot4.fig))
                % apparently cant set callback when axtoolbar is active...
                obj.disableToolbarButtons(obj.figs.plot4.axToolbar)
                if enable
                    obj.figs.callbacksActive = true;
                    set(obj.figs.plot4.fig,'WindowScrollWheelFcn', @obj.plot4Callback);
                elseif ~enable
                    set(obj.figs.plot4.fig,'WindowScrollWheelFcn', []);
                end
            end
        end
        
    end
       
    methods (Access = private)
        
        % callbacks for some interactive plots, trigger using obj.plotCallbacks(bool)
        plot3Callback(obj,event,source);
        plot4Callback(obj,event,source);
        
        % denoise image stack; declared in external file
        obj = denoise(obj)
        % guiROI - prompt user to refine ROI; declared in external file
        obj = guiROI(obj)
        % autoROI - auto refine ROI based on image statistics; declared in external file
        obj = autoROI(obj)
        
        % calculate image moments
        function obj = calcmoments(obj)
            obj.moments.denoised = imMoments(obj.img.denoised,'all',obj.settings.moments.debug);
            obj.settings.moments.debug = false; % reset
        end
        
        % center images
        function obj = center(obj)
            % essentially fcn handle to static private function centerimgs
            [obj.img.translated,obj.moments.translated] = obj.centerimgs(obj.img.denoised,...
                                                                         obj.moments.denoised,...
                                                                         obj.settings.center.debug,...
                                                                         obj.settings.center.normalize);
            obj.settings.center.debug = false; % reset
        end
        
        % get fitresults
        function obj = makefit(obj)
            obj.results = obj.results.fit_iso11146(obj);
        end
        
        function obj = updateaxis(obj)
            % forces update of axis, required when pixelpitch is changed
            if ~isempty(obj.img.src)
                [obj.axis.src.x,obj.axis.src.y] = obj.genaxis(size(obj.img.src),obj.pixelpitch);
            end
            if ~isempty(obj.img.denoised)
                [obj.axis.denoised.x,obj.axis.denoised.y] = obj.genaxis(size(obj.img.denoised),obj.pixelpitch);
            end
        end
    end
    
    methods (Static, Access = private)
        
        function [xaxis,yaxis] = genaxis(sz,pixelpitch)
            % generate x/y axis assuming image center is zero position
            xaxis = (-pixelpitch*(sz(2)-1)/2):pixelpitch:(pixelpitch*(sz(2)-1)/2);
            yaxis = (-pixelpitch*(sz(1)-1)/2):pixelpitch:(pixelpitch*(sz(1)-1)/2);
        end
        
        % rm background, takes img and logmask +
        [processed_img,data] = rmbackground(img,logmask,settings)
        % center images; declared in external file
        [images_centered,moments_centered] = centerimgs(images_in,moments_in,debug,normalize)
        
        function flag = makeUpdate(counter,everyNframes)
            % returns true if first frame OR every N frames
            if counter > 1
                flag = ~mod(counter,everyNframes);
            else
                flag = true;
            end
        end

    end
    
    %% static
    methods (Static, Access = public)
        
        function uuid = mkNewUUID()
            uuid_tmp = char(java.util.UUID.randomUUID.toString);
            uuid = uuid_tmp(1:8);
        end
        
        function disableToolbarButtons(hToolbar)
            % deselects any state button in the toolbar
            % cf. https://www.mathworks.com/matlabcentral/answers/463333-how-to-deselect-toolbarstatebutton-without-clicking-on-it#answer_412908
            for k = 1:numel(hToolbar.Children)
                if isa(hToolbar.Children(k),'matlab.ui.controls.ToolbarStateButton')
                    if strcmp(hToolbar.Children(k).Value,'on')
                        e = hToolbar.Children(k);
                        d = struct;
                        d.Source = e;
                        d.Axes = hToolbar.Parent;
                        d.EventName = 'ValueChanged';
                        d.Value = 'off';
                        d.PreviousValue = 'on';
                        feval(hToolbar.Children(k).ValueChangedFcn,e,d);
                    end
                end
            end
        end
        
    end
    
end