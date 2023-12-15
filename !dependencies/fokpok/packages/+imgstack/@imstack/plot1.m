function plot1(obj,dontCountOrSave)
% this works standalone in editor or within a gui
%
% when using gui explicitly make the following
% guifig = figure; % this is the gui figure handle
% guiax = axes(guifig); % this is the gui axis handle for this plot
% obj.figs.plot1.fig = guifig; % set/connect the generated guifig as plot1.fig parent
% obj.figs.plot1.ax = guiax; % set/connect the generated guiax as plot1.ax
% view(guiax,[40,20]) % upon generation we must set the initial view

%%
if nargin == 1
    dontCountOrSave = false;
end

%% get shorthand to fig handles and fig settings
h = obj.figs.plot1;
sz = size(obj.img.translated,1:2);

% init stuff
figname = sprintf('%s | frame %i, drawn: %i, time: %.2f s',h.settings.name,obj.counter,h.settings.counter,obj.time);
len = length(obj.axis.denoised.z);
lspec = {'Color',h.settings.lineColor,'LineWidth',1};

% get length and angle multipliers
len_mult = h.settings.scale(1);
len_mult2 = h.settings.scale(2);
len_str = h.settings.scale_string{1};
len_str2 = h.settings.scale_string{2};

%% Generation of figure
% check if redraw is off but figure is nonexistant
% in any event: update_fig will always be true if handles dont exist
% for more granular settings plot1 must be converted to a class
% here: either everything exists (update_fig = false) or nothing (update_fig = true)

initAllGraphics = false;
if ~h.settings.update_fig
    % check if figure actually exists
    if (isfield(h,'fig') && ~isvalid(h.fig))
        % field exists but handle is invalid, init everything
        h.settings.update_fig = true;
        initAllGraphics = true;
    end
end
% check if graphics objects exist or not, set flag if required
% this force-enables creation of all grpahics children
% otherwise they're just going to be updated (faster)
if ~isfield(h,'slice') || any(~isvalid(h.slice))
    initAllGraphics = true;
    h.settings.update_fig = true;
elseif ~h.settings.update_fig 
    szOld = size(h.slice(1).CData);
end

if h.settings.update_fig
    % when redraw is forced and fig exists then clear figure and all children
    if ~(isfield(h,'fig') && isvalid(h.fig))
        % then fig does not exist, generate
        h.settings.view = [40,20];
        h.fig = figure('name','redraw','Color','white','NumberTitle','off');
        set(h.fig,'units','normalized')
    end
    
    if isfield(h,'ax') && isvalid(h.ax)
        % then ax exists, backup view, clear figure and update figname
        [az,el] = view(h.ax);
        h.settings.view = [az,el];
        cla(h.ax,'reset')
        % need to kill old handles, might cause problems if number of
        % children change, i.e. imstack initialized with different amount of images
        h = rmfield(h,{'slice','ellipses','xax','yax'});
        initAllGraphics = true;
    else
        % need to generate axes
        h.ax = axes(h.fig);
    end

    hold(h.ax,'on');
    h.ax.Box = 'on';
    colormap(h.ax,h.settings.colormap)
    set(h.ax,'ZDir','reverse')
    
    % set labels
    xlabel(h.ax,sprintf('x in %s',len_str))
    ylabel(h.ax,sprintf('y in %s',len_str))
    zlabel(h.ax,sprintf('z in %s',len_str2))
    
    % set limits
    xlim(h.ax,len_mult.*[obj.axis.denoised.x(1) obj.axis.denoised.x(end)]);
    ylim(h.ax,len_mult.*[obj.axis.denoised.y(1) obj.axis.denoised.y(end)]);
    zlim(h.ax,len_mult2.*[obj.axis.denoised.z(1) obj.axis.denoised.z(end)]);
    
    % init title
    h.title = title(h.ax,'init','Visible',1);
    
    % fix data aspect ratio
    switch h.settings.data_aspect
        case 'modified'
            daspect(h.ax,[1 1 (len_mult2/len_mult)*0.2*abs(obj.axis.denoised.z(end)-obj.axis.denoised.z(1))/max([obj.axis.denoised.x,obj.axis.denoised.y])])
        case 'real'
            daspect(h.ax,[1 1 1])
    end
    % plot z-axis / this is is static
    if initAllGraphics
        h.zax = plot3(h.ax,[0,0],[0,0],len_mult2*obj.axis.denoised.z([1,end]),'-.',lspec{:});
    end
end

if isequal(class(h.fig),'matlab.ui.Figure') && ~h.settings.interactive
    % disable interactivity
    h.ax.InteractionContainer.Enabled = 'off';
    h.fig.ToolBar = 'none';
    h.fig.MenuBar = 'none';
elseif isequal(class(h.fig),'uix.BoxPanel')
    h.ax.Toolbar.Visible = 'off';
    disableDefaultInteractivity(h.ax)
end

% update figure name
if isequal(class(h.fig),'matlab.ui.Figure')
    h.fig.Name = figname;
elseif isequal(class(h.fig),'uix.BoxPanel')
    h.fig.Title = figname;
else
    warning('Fighandle provided to plot1.m is neither matlab figure nor uix.boxpanel')
end

% update figure title
if h.settings.timeStamp && ~isempty(obj.timeString)
    h.title.String = obj.timeString;
    if ~h.title.Visible
        h.title.Visible = 1;
    end
elseif (~h.settings.timeStamp || isempty(obj.timeString)) && h.title.Visible
    h.title.Visible = 0;
end

%% update data in plots or generate elemens if drawing figure
% plot z-slices of beam propagation / is dynamic
% note slice is a high level wrapper for surface, under the hood it's
%
% regardless of state of update_fig for slice/surface there are special
% checks required because the data structures need to be correct for
% surface()
%
% stuff below ensures fastest variant is chosen dependent on bc

updateLims = false;
if initAllGraphics
    % then either it has never been generated of fig was destroyed
    % -> init!
    for i = 1:length(obj.axis.denoised.z)
        h.slice(i) = surface(h.ax,len_mult*obj.axis.denoised.x,...
                            len_mult*obj.axis.denoised.y,...
                            len_mult2*obj.axis.denoised.z(i)*ones(size(obj.img.translated,1:2)),...
                            obj.img.translated(:,:,i));
    end
    % after slice we can set shading
    shading(h.ax,'interp'),
    % now set view
    view(h.ax,h.settings.view)
    
elseif isequal(sz,szOld)
    % then the only thing that needs to be updated is CData bc XYZ
    % spec/data structure is unaffected
    for i = 1:len
        h.slice(i).CData = obj.img.translated(:,:,i);
    end
else
    if ~((szOld(1)*0.9 < sz(1) && sz(1) < szOld(1)*1.1) &&...
            (szOld(2)*0.9 < sz(2) && sz(2) < szOld(2)*1.1))
        % when difference is more than 10% update X/Y limits in plot
        updateLims = true;
    end
    % plot exists but [x,y,z] axis specification has changed
    set(h.slice,'XData',len_mult*obj.axis.denoised.x,...
        'YData',len_mult*obj.axis.denoised.y,...
        'CData',nan(sz),...
        'ZData',nan(sz));
    % yes this works for all slice children/surfaces
    % but for CData/ZData we need loop
    for i = 1:len
        h.slice(i).CData = obj.img.translated(:,:,i);
        h.slice(i).ZData = repmat(len_mult2*obj.axis.denoised.z(i),sz);
    end
end

% if xlim / ylim must be updated it must be done now bc some other stuff
% depends on current limits for the fig
if updateLims
    xlim(h.ax,len_mult.*[obj.axis.denoised.x(1) obj.axis.denoised.x(end)]);
    ylim(h.ax,len_mult.*[obj.axis.denoised.y(1) obj.axis.denoised.y(end)]);
end

% view might be modified in settings, check for discrepancy and update if so
if h.settings.updateView
    view(h.ax,h.settings.view)
    h.settings.updateView = false;
end

% transparency can be set after slice exists
if h.settings.update_fig
    if all(isvalid(h.slice)) % idk why but sometimes transparency causes problems
        if h.settings.transparency == true
            set(h.slice,'FaceAlpha',0.75)
            %alpha(h.ax,'color')
            %alphamap(h.ax,[zeros(1,1),linspace(0.4,0.5,256)])
        else
            set(h.slice,'FaceAlpha',1)
        end
    end
end

%% update data in plots or generate elemens if drawing figure
% plot ellipses / caustic xaxes / caustic yaxes
pltmoments = imMoments.genplotdata(obj.moments.translated,[],obj.axis.denoised,obj.pixelpitch,'si-units','xyz');

if initAllGraphics
    % need to init
    h.ellipses = plot3(h.ax,len_mult*pltmoments.ellipse.XData,...
        len_mult*pltmoments.ellipse.YData,...
        len_mult2*pltmoments.ellipse.ZData,...
        '-',lspec{:});
    h.xax = plot3(h.ax,len_mult*pltmoments.xax.XData,...
        len_mult*pltmoments.xax.YData,...
        len_mult2*pltmoments.xax.ZData,...
        '-.',lspec{:});
    h.yax = plot3(h.ax,len_mult*pltmoments.yax.XData,...
        len_mult*pltmoments.yax.YData,...
        len_mult2*pltmoments.yax.ZData,...
        '-.',lspec{:});
else
    % just need to update
    % assume z-data must not change
    for i = 1:len
        % update ellipses
        h.ellipses(i).XData = len_mult*pltmoments.ellipse.XData(:,i);
        h.ellipses(i).YData = len_mult*pltmoments.ellipse.YData(:,i);
        % update caustic xaxes
        h.xax(i).XData = len_mult*pltmoments.xax.XData(:,i);
        h.xax(i).YData = len_mult*pltmoments.xax.YData(:,i);
        % update caustic yaxes
        h.yax(i).XData = len_mult*pltmoments.yax.XData(:,i);
        h.yax(i).YData = len_mult*pltmoments.yax.YData(:,i);
    end
end

%% update data in plots or generate elemens if drawing figure
% caustic lines + caustic planes + focal planes
% evaluate minor and major caustic along propagation direction
% dx/dy are major/minor axes of the iso11146 ellipses along propagation direction
% use these to construct 4 lines, i.e every 90 degree, this defines the beam caustic along minor/major axes
%
% causticz = linspace(obj.axis.denoised.z(1),obj.axis.denoised.z(end));
% dx = obj.figs.anonfuns.caustic(causticz,obj.results.x.d0,obj.results.x.z0,obj.results.x.zR);
% dy = obj.figs.anonfuns.caustic(causticz,obj.results.y.d0,obj.results.y.z0,obj.results.y.zR);
% dx = obj.results.dx_fit; % x diameters
% dy = obj.results.dy_fit; % y diameters
% causticz = obj.results.z_fit; % associated z positions

% now need to rotate these based on what we assume theta to be
% we assume the beam is simple astigmatic to one theta / not twisted
phi = linspace(0,2*pi*(1-1/4),4).';
causticx = 0 + 0.5.*obj.results.dy_fit.*cos(phi).*sin(obj.results.thetaAVG) +...
               0.5.*obj.results.dx_fit.*sin(phi).*cos(obj.results.thetaAVG);
causticy = 0 + 0.5.*obj.results.dx_fit.*sin(phi).*sin(obj.results.thetaAVG) -...
               0.5.*obj.results.dy_fit.*cos(phi).*cos(obj.results.thetaAVG);

% plot x and y caustic lines
if initAllGraphics
    h.caustic = plot3(h.ax,len_mult*causticx,len_mult*causticy,len_mult2*obj.results.z_fit,'-',lspec{:});
else
    for i = 1:length(phi)
        % note: ZData cannot change in normal operation unless also update_fig is true
        % ...so no need to update ZData
        h.caustic(i).XData = len_mult*causticx(i,:);
        h.caustic(i).YData = len_mult*causticy(i,:); 
    end
end

% highlight x/y plane
xplane_inBetween_x = len_mult*[causticx(1,:), flip(causticx(3,:))]; % x plane data (x-coordinates)
xplane_inBetween_y = len_mult*[causticy(1,:), flip(causticy(3,:))]; % x plane data (y-coordinates)
yplane_inBetween_x = len_mult*[causticx(2,:), flip(causticx(4,:))]; % y plane data (x-coordinates)
yplane_inBetween_y = len_mult*[causticy(2,:), flip(causticy(4,:))]; % y plane data (y-coordinates)

% draw x and y plane
if initAllGraphics
    xplane_yplane_z = len_mult2*[obj.results.z_fit, flip(obj.results.z_fit)];
    h.patch.caustic_x = patch(h.ax,xplane_inBetween_x, xplane_inBetween_y, xplane_yplane_z,...
        'r','EdgeColor','none','FaceAlpha',0.15);
    h.patch.caustic_y = patch(h.ax,yplane_inBetween_x, yplane_inBetween_y, xplane_yplane_z,...
        'b','EdgeColor','none','FaceAlpha',0.15);
else
    % note: ZData cannot change in normal operation unless also update_fig is true
    h.patch.caustic_x.XData = xplane_inBetween_x;
    h.patch.caustic_x.YData = xplane_inBetween_y;
    h.patch.caustic_y.XData = yplane_inBetween_x;
    h.patch.caustic_y.YData = yplane_inBetween_y;
end

% patch x and y focus plane
focus_x_Xdata = len_mult*obj.axis.denoised.x([1,end,end,1]);
focus_x_Ydata = len_mult*obj.axis.denoised.y([1,1,end,end]);
focus_x_Zdata = len_mult2*repelem(obj.results.x.z0,4);
focus_y_Xdata = len_mult*obj.axis.denoised.x([1,end,end,1]);
focus_y_Ydata = len_mult*obj.axis.denoised.y([1,1,end,end]);
focus_y_Zdata = len_mult2*repelem(obj.results.y.z0,4);

if initAllGraphics
    % x focus plane patch
    h.patch.focus_x = patch(h.ax,focus_x_Xdata,focus_x_Ydata,focus_x_Zdata,...
        'r','EdgeColor','none','FaceAlpha',0.1);
    % y focus plane patch
    h.patch.focus_y = patch(h.ax,focus_y_Xdata,focus_y_Ydata,focus_y_Zdata,...
        'b','EdgeColor','none','FaceAlpha',0.1);
else
    h.patch.focus_x.XData = focus_x_Xdata;
    h.patch.focus_x.YData = focus_x_Ydata;
    h.patch.focus_x.ZData = focus_x_Zdata;
    h.patch.focus_y.XData = focus_y_Xdata;
    h.patch.focus_y.YData = focus_y_Ydata;
    h.patch.focus_y.ZData = focus_y_Zdata;
end

%% Export PNG/FIG
if ~dontCountOrSave && h.settings.makeExport
    if ~isnan(obj.time)
        filename = sprintf('%s%i_%s_time%.2fs_%s',...
            obj.figs.outputFolder,h.settings.counter,h.settings.name_compact,obj.time,obj.uuid);
    else
        filename = sprintf('%s%i_%s_%s',...
            obj.figs.outputFolder,h.settings.counter,h.settings.name_compact,obj.uuid);
    end
    
    if h.settings.exportFig
        savefig(h.fig,strcat(filename,'.fig'),'compact')
    end
    
    if h.settings.exportPNG
        exportgraphics(h.ax,strcat(filename,'.png'),'Resolution',h.settings.dpi)
    end
end

%% Done with figure
if h.settings.update_fig
    hold(h.ax,'off')
end

% now disable redraw
h.settings.update_fig = false;

% advance counter
if ~dontCountOrSave
    h.settings.counter = h.settings.counter+1;
end

% save
obj.figs.plot1 = h;

% force view at the end
% view(h.ax,[45 45])
% camroll(h.ax,90)

end