classdef plotsettings < handle
    % holds all settings specific to plots
    
    properties (Access = public)
        enable                  (1,1) logical   % disabled or enables plot
        name                    (1,:) char      % used to set figname
        name_compact            (1,:) char      % used for saving figs
        counter                 (1,1) uint32    % used to count frames
        interactive             (1,1) logical   % enables/disables plot interactivity upon creation / reset
        updateEveryNframes      (1,1) uint32    % used by imstack to decide whether or not to update this figure
        exportEveryNframes      (1,1) uint32    % stacks with updateEveryNframes; export fig/png every updateEveryNframes*exportEveryNframes
        updateView              (1,1) logical   % when view is written this is set to 1; when this is requested it is reset to 0
                                                % but user override is possible
        limitsType              (1,:) char      % e.g. when Xlim/Ylim can be affected
        exportFig               (1,1) logical
        exportPNG               (1,1) logical
        dpi                     (1,1) uint32    % dots per inch, only applies to PNG export
        timeStamp               (1,1) logical   % enables timestamp title
    end
    
    properties (SetAccess = protected, GetAccess = public)
        lineColor               (1,:) char
    end
    
    properties (Access = private)
        forceupdate             (1,1) logical   % internal boolean to control update_fig
        view_private            (1,2) double    % stores internal
        scale_private           (1,3) double    % stores internal
        colormap_private        (1,:) char      % stores internal
        data_aspect_private     (1,:) char      % stores internal
        transparency_private    (1,1) logical   % stores internal
    end
    
    properties (Dependent, Access = public)
        makeExport              (1,1) logical   % true if ~mod(obj.counter,obj.exportEveryNframes) or obj.counter = 1
        view                    (1,2) double    % view (az,el)
        update_fig              (1,1) logical   % forces redraw of fig; whenever major changes are required
        scale                   (1,3) double    % hold multiplier for lengths / angles [numeric]
        scale_string            (1,3) cell      % contains associated enumeration
        colormap                (1,:) char      % hold colormap specification; when colormap is changed force redraw
        data_aspect             (1,:) char      % changes data aspect; allowed is 'modified' and 'real'
        lspec                   (1,:) cell      % linespec, must adhere to matlab spec
        transparency            (1,1) logical   % if applicable enables transparency
    end
    
    methods
        % constructor and/or resetter
        function obj = plotsettings(name)
            obj.enable = false;
            obj.name = name;
            obj.name_compact = obj.makeCompact(obj.name);
            obj.counter = 1;
            obj.view = [nan,nan];
            obj.interactive = true;
            obj.scale = [1e6,1e3,1e3]; % [spatial,spatial,angular], here: [µm,mm,mrad]
            obj.colormap = 'jet';
            obj.data_aspect = 'modified';
            obj.limitsType = 'normal';
            obj.updateEveryNframes = 1;
            obj.exportEveryNframes = 1;
            obj.transparency = false;
            obj.exportFig = 0;
            obj.exportPNG = 0;
            obj.dpi = 300;
            obj.timeStamp = 1;
        end
        
        %% setter
        
        function set.exportEveryNframes(obj,val)
            if val < 1
                obj.exportEveryNframes = 1;
            else
                obj.exportEveryNframes = val;
            end
        end
        
        function val = get.makeExport(obj)
            % returns true if first frame OR every N frames
            if obj.counter > 1
                val = ~mod(obj.counter,obj.exportEveryNframes);
            else
                val = true;
            end
        end
        
        function set.limitsType(obj,val)
            if ismember(val,{'normal','tight'})
                obj.limitsType = val;
            else
                warning('limitsType must be "normal" or "tight", defaulting to "normal".');
                obj.limitsType = 'normal';
            end
        end
        
        function set.dpi(obj,val)
            if ismember(val,[150,300,600])
                obj.dpi = val;
            else
                warning('DPI must be [150,300,600], defaulting to 300');
                obj.dpi = 300;
            end
        end
        
        function val = get.view(obj)
            val = obj.view_private;
        end
        
        function val = get.updateView(obj)
           val = obj.updateView;
        end
        
        function set.updateView(obj,val)
           obj.updateView = val;
        end
        
        function set.view(obj,input)
           obj.view_private = input;
           obj.updateView = true;
        end
        
        function set.transparency(obj,input)
           obj.forceupdate = true; % forces redraw of fig
           obj.transparency_private = input; 
        end
        
        function set.data_aspect(obj,input)
            obj.forceupdate = true; % forces redraw of fig
            
            choice = lower(input);
            if ~ismember(choice,{'real','modified'})
                warning('Supported data aspect: "real" or "modified". Defaulting to "modified"')
                choice = 'modified';
            end
            obj.data_aspect_private = choice;
        end
        
        function set.colormap(obj,input)
            obj.forceupdate = true; % forces redraw of fig
            
            cmap = lower(input);
            if ~ismember(cmap,{'jet','gray','parula','turbo'})
                warning('Supported colormaps: jet, gray, parula. Defaulting to jet.')
                cmap = 'jet';
            end
            obj.colormap_private = cmap;
            switch obj.colormap
                case {'jet','parula','turbo'}
                    obj.lineColor = 'm';
                case 'gray'
                    obj.lineColor = 'g';
                otherwise
                    obj.lineColor = 'r';
            end
        end
        
        function set.scale(obj,input)
            obj.forceupdate = true; % forces redraw of fig
            
            length_mult = input(1);
            length_mult2 = input(2);
            angle_mult = input(3);
            mult_allowed = [1,1e3,1e6]; % [m, mm, µm] / [rad, mrad, µrad]
            if ~ismember(length_mult,mult_allowed)
                warning('scale multipler for length must be 1 (m), 1e3 (mm), 1e6 (µm)')
                warning('defaulting to µm')
                length_mult = 1e6;
            end
            if ~ismember(length_mult2,mult_allowed)
                warning('scale multipler for length must be 1 (m), 1e3 (mm), 1e6 (µm)')
                warning('defaulting to µm')
                length_mult2 = 1e6;
            end
            if ~ismember(angle_mult,mult_allowed)
                warning('scale multipler for angle must be 1 (rad), 1e3 (mrad), 1e6 (µrad)')
                warning('defaulting to mrad')
                angle_mult = 1e3;
            end
            obj.scale_private = [length_mult,length_mult2,angle_mult];
        end
        
        function set.update_fig(obj,input)
            obj.forceupdate = input;
        end
        
        function set.updateEveryNframes(obj,input)
            if input < 1
                input = 1;
            end
            obj.updateEveryNframes = input;
        end
        
        %% getter
        function val = get.transparency(obj)
           val = obj.transparency_private; 
        end
        
        function val = get.data_aspect(obj)
            val = obj.data_aspect_private;
        end
        
        function val = get.update_fig(obj)
            val = obj.forceupdate;
        end
        
        function val = get.colormap(obj)
            val = obj.colormap_private;
        end
        
        function val = get.scale(obj)
            val = obj.scale_private;
            if strcmpi(obj.data_aspect_private,'real')
                % in this case both spatial multipliers must be the same
                val(2) = val(1);
            end
        end
        
        function val = get.scale_string(obj)
            length_mult = obj.scale(1);
            if strcmpi(obj.data_aspect,'real')
                % in this case both spatial multipliers must be the same
                length_mult2 = length_mult;
            else
                length_mult2 = obj.scale(2);
            end
            angle_mult = obj.scale(3);
            
            switch length_mult
                case 1
                    length_mult_str = 'm';
                case 1e3
                    length_mult_str = 'mm';
                case 1e6
                    length_mult_str = 'µm';
            end
            switch length_mult2
                case 1
                    length_mult_str2 = 'm';
                case 1e3
                    length_mult_str2 = 'mm';
                case 1e6
                    length_mult_str2 = 'µm';
            end
            switch angle_mult
                case 1
                    angle_mult_str = 'rad';
                case 1e3
                    angle_mult_str = 'mrad';
                case 1e6
                    angle_mult_str = 'µrad';
            end
            
            val = {length_mult_str,length_mult_str2,angle_mult_str};
        end
        
    end
    
    %% private
    methods (Access = private)
%                 function obj = fun(obj,var)
%                 end
    end
    
    %% static
    methods (Static, Access = private)
        function stringOut = makeCompact(inputString)
            stringOut = strrep(inputString,' ','_');
            stringOut = strrep(stringOut,'(','');
            stringOut = strrep(stringOut,')','');
        end
        
        function flag = makeUpdate(counter,everyNframes)
            % returns true if first frame OR every N frames
            if counter > 1
                flag = ~mod(counter,everyNframes);
            else
                flag = true;
            end
        end
    end
    
end