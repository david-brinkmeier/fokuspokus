function plot3(obj,dontCountOrSave)
% callback is an optional argument
% when the mouse wheel callback is active then figure saving is skipped
if nargin == 1
    dontCountOrSave = false;
end

% get shorthand to fig handles and fig settings
h = obj.figs.plot3;

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
if ~isfield(h,'image') || ~isvalid(h.image)
    initAllGraphics = true;
    h.settings.update_fig = true;
end

if h.settings.update_fig
    % when redraw is forced and fig exists then clear figure and all children
    if ~(isfield(h,'fig') && isvalid(h.fig))
        % then fig does not exist, generate
        h.fig = figure('name','redraw - plot3','Color','white','NumberTitle','off');
        h.fig.UserData = 1; % stores index
        set(h.fig,'units','normalized')
    end
    
    if isfield(h,'ax') && isvalid(h.ax)
        cla(h.ax,'reset')
        h.ax.YDir = 'reverse';
        caxis(h.ax,[0 1]);
        initAllGraphics = true;
    else
        % need to generate axes
        h.ax = axes(h.fig);
        h.ax.YDir = 'reverse';
        h.axToolbar = axtoolbar(h.ax,'default');
        caxis(h.ax,[0 1]);
    end
    axis(h.ax,'image')
    hold(h.ax,'on');
    h.ax.Box = 'on';
    colormap(h.ax,h.settings.colormap)

    % set labels
    xlabel(h.ax,sprintf('x in %s',len_str))
    ylabel(h.ax,sprintf('y in %s',len_str))
    
    % init title
    h.title = title(h.ax,'init','Visible',1);
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

% Important: get selection index for z slice / page
if ~isempty(h.fig.UserData) && (h.fig.UserData <= length(obj.zPos))
    idx = h.fig.UserData;
else
    h.fig.UserData = 1;
    idx = 1;
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

%% get data for plot
xc = interp1(obj.axis.denoised.x,obj.moments.translated.xc(idx));
yc = interp1(obj.axis.denoised.y,obj.moments.translated.yc(idx));
dx = obj.pixelpitch*obj.moments.translated.dx(idx);
dy = obj.pixelpitch*obj.moments.translated.dy(idx);
theta = obj.moments.denoised.theta(idx);

% 2nd moment ellipse
phi = linspace(0,2*pi,60).';
ellipseX = xc + (dy/2).*cos(phi).*sin(theta) + (dx/2).*sin(phi).*cos(theta);
ellipseY = yc + (dx/2).*sin(phi).*sin(theta) - (dy/2).*cos(phi).*cos(theta);
% principal axis closer to x
xaxX = xc + (dx/2).*(cos(theta).*[-1;1]-sin(theta).*[0;0]);
xaxY = yc + (dx/2).*(sin(theta).*[-1;1]+cos(theta).*[0;0]);
% principal axis closer to y
yaxX = xc + (dy/2).*(cos(theta).*[0;0]-sin(theta).*[-1;1]);
yaxY = yc + (dy/2).*(sin(theta).*[0;0]+cos(theta).*[-1;1]);

%% update data in plots or generate elemens if drawing figure
% plot/update caustic
if initAllGraphics
    % then either it has never been generated of fig was destroyed
    % -> init!
    h.image = imagesc(h.ax,len_mult*obj.axis.denoised.x([1,end]),...
                           len_mult*obj.axis.denoised.y([1,end]),...
                           obj.img.translated(:,:,idx));
    h.ellipse = plot(h.ax,len_mult*ellipseX,len_mult*ellipseY,'LineStyle','-','Color',h.settings.lineColor,'LineWidth',1.5);
    h.xax = plot(h.ax,len_mult*xaxX,len_mult*xaxY,'LineStyle','-.','Color',h.settings.lineColor,'LineWidth',1.5);
    h.yax = plot(h.ax,len_mult*yaxX,len_mult*yaxY,'LineStyle','-.','Color',h.settings.lineColor,'LineWidth',1.5);
else
    h.image.XData = len_mult*obj.axis.denoised.x([1,end]);
    h.image.YData = len_mult*obj.axis.denoised.y([1,end]);
    h.image.CData = obj.img.translated(:,:,idx);
    h.ellipse.XData = len_mult*ellipseX;
    h.ellipse.YData = len_mult*ellipseY;
    h.xax.XData = len_mult*xaxX;
    h.xax.YData = len_mult*xaxY;
    h.yax.XData = len_mult*yaxX;
    h.yax.YData = len_mult*yaxY;
end

%% need to update ylims? (significant beam diameter change)
switch h.settings.limitsType
    case 'normal'
        ylim(h.ax,len_mult*obj.axis.denoised.y([1,end]));
        xlim(h.ax,len_mult*obj.axis.denoised.x([1,end]));
    case 'tight'
        dx_cam = obj.pixelpitch*obj.moments.translated.dx_cam(idx);
        dy_cam = obj.pixelpitch*obj.moments.translated.dy_cam(idx);
        xlim(h.ax,len_mult*(xc+[-1.2,1.2]*dx_cam/2))
        ylim(h.ax,len_mult*(yc+[-1.2,1.2]*dy_cam/2))
end

%% update figure name
figname = sprintf('%s: [%i/%i] | z = %.2f %s, d[x,y] = [%.2f,%.2f] %s, theta = %.2f°, eps = %.2f | frame: %i, drawn: %i, time: %.2fs',...
                  h.settings.name,idx,length(obj.axis.src.z),len_mult2*obj.axis.src.z(idx),len_str2,...
                  len_mult*dx,len_mult*dy,len_str,rad2deg(theta),obj.results.ellipticity(idx),...
                  obj.counter,h.settings.counter,obj.time);

if isequal(class(h.fig),'matlab.ui.Figure')
    h.fig.Name = figname;
elseif isequal(class(h.fig),'uix.BoxPanel')
    h.fig.Title = figname;
else
    warning('Fighandle provided to plot1.m is neither matlab figure nor uix.boxpanel')
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
obj.figs.plot3 = h;

end