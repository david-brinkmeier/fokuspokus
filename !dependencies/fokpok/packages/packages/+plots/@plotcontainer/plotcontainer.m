classdef plotcontainer < handle
    % contains handles to plots and some variables
    % most important stuff is set through plot(num).plotsettings
    % plot interactivity can be updated through plot.interactive = true/false
    
    properties (Access = public)
        anonfuns        (1,1)   struct  % holds some function definitions for plotting
        interactive     (1,1)   logical % modifies all children plot interactivity
        callbacksActive (1,1)   logical     
        plot1           (1,1)   struct  % hold handles and required data for plot1
        plot2           (1,1)   struct  % hold handles and required data for plot1
        plot3           (1,1)   struct  % hold handles and required data for plot1
        plot4           (1,1)   struct  % hold handles and required data for plot1
    end
    
    properties (SetAccess = protected)
        outputFolder            (1,:)   char    % figs will be placed here
    end
    
    properties (SetAccess = private, Hidden)
        isnotplot               (1,:)   cell    % contains plotcontainer variables that are NOT plots
        isplot                  (1,:)   cell    % contains plotcontainer variables that are plots
        workingFolder_internal  (1,:)   char 
    end
    
    properties (Dependent, Access = public)
        workingFolder           (1,:)   char    % folder where results will be placed
    end
    
    methods
        % constructor and/or resetter
        function obj = plotcontainer
            % update this if more internal variables are added which are plots
            obj.isnotplot = {'anonfuns','interactive','workingFolder','outputFolder','callbacksActive'};
            % removes all fields from array that are saved in obj.isnotplot
            obj.isplot = setdiff(fieldnames(obj),obj.isnotplot);
            % default plot interactivity is enabled
            obj.interactive = 1;
            
            % add anon functions for plotting
            obj.anonfuns.caustic = @(z,d0,z0,zR) d0.*sqrt(1+((z-z0)./zR).^2); % beam radius as function of propagation length
            
            % intantiate defined plots(ettings)
            obj.plot1.settings = plots.plotsettings('3d caustic');
            obj.plot2.settings = plots.plotsettings('2d caustic');
            obj.plot3.settings = plots.plotsettings('2d beam (denoised)');
            obj.plot4.settings = plots.plotsettings('2d beam (src)');
        end
        
        function set.interactive(obj,input)
            obj.interactive = input;
            updatePlotInteractive(obj,input);
        end     
        
        function set.workingFolder(obj,input)
            if isfolder(input)
                obj.workingFolder_internal = input;
                obj.outputFolder = [obj.workingFolder_internal,'\results\figs\'];
                obj.generateOutputFolder();
            else
                h = warndlg('\fontsize{12}The working directory provided to plots.plotcontainer is not a valid directory. Select a valid directory upon next prompt.',...
                    'aioResults.requestFolder',struct('Interpreter','tex','WindowStyle','modal'));
                waitfor(h);
                obj.requestFolder();
            end
        end
        
        function val = get.workingFolder(obj)
            if isempty(obj.workingFolder_internal) || ~isfolder(obj.workingFolder_internal)
                obj.requestFolder();
            end
            val = obj.workingFolder_internal;
        end
        
        function val = get.outputFolder(obj)
            if ~isfolder(obj.outputFolder)
                [success,msg] = mkdir(obj.outputFolder);
                if ~success
                    h = errordlg(sprintf('Error generating folder: "%s". Error message: "%s"',obj.outputFolder,msg),...
                        'aioResults.requestFolder',struct('Interpreter','none','WindowStyle','modal'));
                    waitfor(h);
                end
            end
            val = obj.outputFolder;
        end
       
    end
    
    methods (Access = public)
        
        function plotAll(obj,enable)
            if enable
                obj.plot1.settings.enable = 1;
                obj.plot2.settings.enable = 1;
                obj.plot3.settings.enable = 1;
                obj.plot4.settings.enable = 1;
            else
                obj.plot1.settings.enable = 0;
                obj.plot2.settings.enable = 0;
                obj.plot3.settings.enable = 0;
                obj.plot4.settings.enable = 0;
            end
        end
        
        function resetCounter(obj)
            for i = 1:length(obj.isplot)
                obj.(obj.isplot{i}).settings.counter = 1;
            end
        end
    end
    
    methods (Access = private)
        
        function requestFolder(obj)
            selpath = uigetdir(path,'Select a folder for the results/export.');
            if selpath == 0
                h = warndlg('\fontsize{12}A working directory MUST be selected.',...
                    'aioResults.requestFolder',struct('Interpreter','tex','WindowStyle','modal'));
                waitfor(h);
                obj.requestFolder();
            else
                obj.workingFolder_internal = selpath;
            end
            obj.outputFolder = [obj.workingFolder_internal,'\results\figs\'];
            obj.generateOutputFolder();
        end
        
        function generateOutputFolder(obj)
            if ~isfolder(obj.outputFolder)
                [success,msg] = mkdir(obj.outputFolder);
                if ~success
                    h = errordlg(sprintf('Error generating folder: "%s". Error message: "%s"',obj.outputFolder,msg),...
                        'aioResults.requestFolder',struct('Interpreter','none','WindowStyle','modal'));
                    waitfor(h);
                end
            end
        end
        
        function updatePlotInteractive(obj,interactive)
            % iterates over all plots, checks if fig / ax exist,
            % enables/disables toolbars upon request if exist and updates
            % interactie value in plotsettings so that last setting is
            % maintained when reinitializing plot
            %
            % get field names that contain plot handles/structures
            plots = obj.isplot;
            % iterate over plots IFF fig/ax are valid handles (exit / not deleted)
            for i = 1:length(plots)
                obj.(plots{i}).settings.interactive = interactive;
                if all(isfield(obj.(plots{i}),{'fig','ax'})) && all(isvalid([obj.(plots{i}).fig,obj.(plots{i}).ax]))
                    % then fig currently exists, modify interactivity
                    if interactive == true
                        if isequal(class(obj.(plots{i}).fig),'matlab.ui.Figure')
                            obj.(plots{i}).ax.InteractionContainer.Enabled = 'on';
                            obj.(plots{i}).fig.ToolBar = 'auto';
                            obj.(plots{i}).fig.MenuBar = 'figure';
                        elseif isequal(class(obj.(plots{i}).fig),'uix.BoxPanel')
                            obj.(plots{i}).fig.Parent.ToolBar = 'figure';
                            obj.(plots{i}).ax.Toolbar.Visible = 'on';
                            enableDefaultInteractivity(obj.(plots{i}).ax);
                        end
                    elseif interactive == false
                        if isequal(class(obj.(plots{i}).fig),'matlab.ui.Figure')
                            obj.(plots{i}).ax.InteractionContainer.Enabled = 'off';
                            obj.(plots{i}).fig.ToolBar = 'none';
                            obj.(plots{i}).fig.MenuBar = 'none';
                        elseif isequal(class(obj.(plots{i}).fig),'uix.BoxPanel')
                            obj.(plots{i}).fig.Parent.ToolBar = 'none';
                            obj.(plots{i}).ax.Toolbar.Visible = 'off';
                            disableDefaultInteractivity(obj.(plots{i}).ax);
                        end
                    end
                end    
            end
        end
        
    end
    
    %% static
    methods (Static) 
    end
    
end

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    