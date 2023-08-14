function plot4(obj,dontCountOrSave)
% callback is an optional argument
% when the mouse wheel callback is active then figure saving is skipped
if nargin == 1
    dontCountOrSave = false;
end
% get shorthand to fig handles and fig settings
h = obj.figs.plot4;

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
        h.fig = figure('name','redraw - plot4','Color','white','NumberTitle','off');
        h.fig.UserData = 1; % stores index
        set(h.fig,'units','normalized')
    end
    
    if isfield(h,'ax') && isvalid(h.ax)
        cla(h.ax,'reset')
        h.ax.YDir = 'reverse';
        initAllGraphics = true;
    else
        % need to generate axes
        h.ax = axes(h.fig);
        h.ax.YDir = 'reverse';
        h.axToolbar = axtoolbar(h.ax,'default');
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
if obj.img.ROIenabled
    xq = interp1(obj.axis.src.x,...
        [obj.img.ROI{idx}.xstart,...
        obj.img.ROI{idx}.xend,...
        (obj.img.ROI{idx}.xstart-1)+obj.moments.denoised.xc(idx)]);
    yq = interp1(obj.axis.src.y,...
        [obj.img.ROI{idx}.ystart,...
        obj.img.ROI{idx}.yend,...
        (obj.img.ROI{idx}.ystart-1)+obj.moments.denoised.yc(idx)]);
    xstart = xq(1);
    ystart = yq(1);
    xend = xq(2);
    yend = yq(2);
    xc = xq(3);
    yc = yq(3);
else
    xstart = obj.axis.src.x(1);
    xend = obj.axis.src.x(end);
    ystart = obj.axis.src.y(1);
    yend = obj.axis.src.y(end);
    xc = interp1(obj.axis.src.x,obj.moments.denoised.xc(idx));
    yc = interp1(obj.axis.src.y,obj.moments.denoised.yc(idx));
end

dx = obj.pixelpitch*obj.moments.denoised.dx(idx);
dy = obj.pixelpitch*obj.moments.denoised.dy(idx);
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
    % then either it has never been generated of fig was destroyed -> init!
    h.image = imagesc(h.ax,len_mult*obj.axis.src.x([1,end]),...
                           len_mult*obj.axis.src.y([1,end]),...
                           obj.img.src(:,:,idx));
    h.rect = rectangle(h.ax,'Position',len_mult*[xstart, ystart, xend-xstart, yend-ystart],...
                            'EdgeColor',h.settings.lineColor,'LineWidth',1.5);
    h.ellipse = plot(h.ax,len_mult*ellipseX,len_mult*ellipseY,'LineStyle','-','Color',h.settings.lineColor,'LineWidth',1.5);
    h.xax = plot(h.ax,len_mult*xaxX,len_mult*xaxY,'LineStyle','-.','Color',h.settings.lineColor,'LineWidth',1.5);
    h.yax = plot(h.ax,len_mult*yaxX,len_mult*yaxY,'LineStyle','-.','Color',h.settings.lineColor,'LineWidth',1.5);
else
    h.image.XData = len_mult*obj.axis.src.x([1,end]);
    h.image.YData = len_mult*obj.axis.src.y([1,end]);
    h.image.CData = obj.img.src(:,:,idx);
    h.rect.Position = len_mult*[xstart, ystart, xend-xstart, yend-ystart];
    h.ellipse.XData = len_mult*ellipseX;
    h.ellipse.YData = len_mult*ellipseY;
    h.xax.XData = len_mult*xaxX;
    h.xax.YData = len_mult*xaxY;
    h.yax.XData = len_mult*yaxX;
    h.yax.YData = len_mult*yaxY;
end

%% update limits
if initAllGraphics || h.settings.update_fig
    xlim(h.ax,len_mult*obj.axis.src.x([1,end]))
    ylim(h.ax,len_mult*obj.axis.src.y([1,end]))
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
        filename = sprintf('%s%i_%s_time%.2fsec_%s',...
            obj.figs.outputFolder,h.settings.counter,h.settings.name_compact,obj.time,obj.uuid_internal);
    else
        filename = sprintf('%s%i_%s_%s',...
            obj.figs.outputFolder,h.settings.counter,h.settings.name_compact,obj.uuid_internal);
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
obj.figs.plot4 = h;

end