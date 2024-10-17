function plot2(obj,dontCountOrSave)
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
if any(obj.results.badFit)
    warning('plot2 is discarded because the fit failed (obj.badFit).')
    % (plot1 fails gracefully, plot2 does not, so skip)
    return
end
h = obj.figs.plot2;

% init stuff
figname = sprintf('%s | R²[x,y] = [%.2f,%.2f] | frame: %i, drawn: %i, time: %.2fs',...
                  h.settings.name,obj.results.x.rsquared(2),obj.results.y.rsquared(2),...
                  obj.counter,h.settings.counter,obj.time);

% get length and angle multipliers
len_mult = h.settings.scale(1);
len_mult2 = h.settings.scale(2);
ang_mult = h.settings.scale(3);
len_str = h.settings.scale_string{1};
len_str2 = h.settings.scale_string{2};
ang_str = h.settings.scale_string{3};

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
if ~isfield(h,'lines') || ~isvalid(h.lines.zax)
    initAllGraphics = true;
    h.settings.update_fig = true;
end

if h.settings.update_fig
    % when redraw is forced and fig exists then clear figure and all children
    if ~(isfield(h,'fig') && isvalid(h.fig))
        % then fig does not exist, generate
        h.fig = figure('name','redraw','Color','white','NumberTitle','off');
        set(h.fig,'units','normalized')
    end
    
    if isfield(h,'ax') && isvalid(h.ax)
        cla(h.ax,'reset')
        initAllGraphics = true;
    else
        % need to generate axes
        h.ax = axes(h.fig);
        % make some room for annotation...
        if isequal(class(h.fig),'matlab.ui.Figure')
            h.ax.OuterPosition(3) = 0.875;
        end
    end
    hold(h.ax,'on');
    h.ax.Box = 'on';

    % set labels
    xlabel(h.ax,sprintf('z in %s',len_str2))
    ylabel(h.ax,sprintf('r_{x,y} in %s',len_str))
    
    % init title
    h.title = title(h.ax,'init','Visible',1);
    
    % set limits
    % round to next largest multiple of 25 units, 0.5 bc diam->radius
    axLim = 1.025*max(len_mult*0.5*[obj.results.dx_fit,obj.results.dy_fit]);
    ylim(h.ax,[-axLim,axLim]);
    %h.ax.YTickLabel = cellfun(@(x) num2str(abs(str2double(x))),h.ax.YTickLabel,'un',0);
    xlim(h.ax,len_mult2*[min(obj.axis.src.z), max(obj.axis.src.z)])
    
    % plot z-axis / this is is static
    if initAllGraphics
        h.lines.zax = yline(h.ax,0,'-.k');
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

%% need to update ylims? (significant beam diameter change)
if ~h.settings.update_fig
    updateLims = false;
    oldLim = max(h.ax.YLim);
    newLim = 1.025*max(len_mult*0.5*[obj.results.dx_fit,obj.results.dy_fit]); % round to next largest multiple of 25 units
    
    if ~(oldLim*0.9 < newLim && newLim < oldLim*1.1)
        % then difference > 10%, update limits
        updateLims = true;
    end
    
    if updateLims
        ylim(h.ax,[-newLim,newLim]);
        %h.ax.YTickLabel = cellfun(@(x) num2str(abs(str2double(x))),h.ax.YTickLabel,'un',0);
    end
end

%% update data in plots or generate elemens if drawing figure
% plot/update caustic
if initAllGraphics
    % then either it has never been generated of fig was destroyed
    % -> init!
    h.lines.causticMeasX = plot(h.ax,len_mult2*obj.results.z,...
                                     len_mult*0.5*[obj.results.dx; -obj.results.dx],'or','MarkerSize',5);
    h.lines.causticMeasY = plot(h.ax,len_mult2*obj.results.z,...
                                     len_mult*0.5*[obj.results.dy; -obj.results.dy],'ob','MarkerSize',5);
    h.lines.causticFitX = plot(h.ax,len_mult2*obj.results.z_fit,...
                                    len_mult*0.5*[obj.results.dx_fit; -obj.results.dx_fit],'-r');
    h.lines.causticFitY = plot(h.ax,len_mult2*obj.results.z_fit,...
                                    len_mult*0.5*[obj.results.dy_fit; -obj.results.dy_fit],'-b');
else
    % new condition: z positions can change if a measurement plane is
    % omitted for the fit bc of SNR concerns or something
    h.lines.causticMeasX(1).XData = len_mult2*obj.results.z;
    h.lines.causticMeasX(2).XData = len_mult2*obj.results.z;
    h.lines.causticMeasY(1).XData = len_mult2*obj.results.z;
    h.lines.causticMeasY(2).XData = len_mult2*obj.results.z;
    h.lines.causticFitX(1).XData = len_mult2*obj.results.z_fit;
    h.lines.causticFitX(2).XData = len_mult2*obj.results.z_fit;
    h.lines.causticFitY(1).XData = len_mult2*obj.results.z_fit;
    h.lines.causticFitY(2).XData = len_mult2*obj.results.z_fit;
    
    h.lines.causticMeasX(1).YData = len_mult*0.5*obj.results.dx;
    h.lines.causticMeasX(2).YData = -len_mult*0.5*obj.results.dx;
    h.lines.causticMeasY(1).YData = len_mult*0.5*obj.results.dy;
    h.lines.causticMeasY(2).YData = -len_mult*0.5*obj.results.dy;
    h.lines.causticFitX(1).YData = len_mult*0.5*obj.results.dx_fit;
    h.lines.causticFitX(2).YData = -len_mult*0.5*obj.results.dx_fit;
    h.lines.causticFitY(1).YData = len_mult*0.5*obj.results.dy_fit;
    h.lines.causticFitY(2).YData = -len_mult*0.5*obj.results.dy_fit;
end

%% errorbars if exist
if initAllGraphics
    h.errbar.x = errorbar(h.ax,nan,nan,nan,'r','LineStyle','none');
    h.errbar.y = errorbar(h.ax,nan,nan,nan,'b','LineStyle','none');
end
if ~isempty(obj.results.logmask)
    nnzidx = find(obj.results.dx_uniqueSTD);
    set(h.errbar.x,'XData',len_mult2*[obj.results.z_unique(nnzidx),obj.results.z_unique(nnzidx)],...
                   'YData',len_mult*0.5*[obj.results.dx_unique(nnzidx),-obj.results.dx_unique(nnzidx)],...
                   'YPositiveDelta',len_mult*0.5*[obj.results.dx_uniqueSTD(nnzidx),obj.results.dx_uniqueSTD(nnzidx)],...
                   'YNegativeDelta',len_mult*0.5*[obj.results.dx_uniqueSTD(nnzidx),obj.results.dx_uniqueSTD(nnzidx)]);
    set(h.errbar.y,'XData',len_mult2*[obj.results.z_unique(nnzidx),obj.results.z_unique(nnzidx)],...
                   'YData',len_mult*0.5*[obj.results.dy_unique(nnzidx),-obj.results.dy_unique(nnzidx)],...
                   'YPositiveDelta',len_mult*0.5*[obj.results.dy_uniqueSTD(nnzidx),obj.results.dy_uniqueSTD(nnzidx)],...
                   'YNegativeDelta',len_mult*0.5*[obj.results.dy_uniqueSTD(nnzidx),obj.results.dy_uniqueSTD(nnzidx)]);
end

%% update data in plots or generate elemens if drawing figure
% beam waist / rayleigh length positions x,y
if initAllGraphics
    h.pois.z0_x = xline(h.ax,len_mult2*obj.results.x.z0,...
        '-.r','Label','z_{0,x}','LabelOrientation','horizontal');
    h.pois.zR_x_pos = xline(h.ax,len_mult2*(obj.results.x.z0+obj.results.x.zR),...
        ':r','Label','+z_{R,x}','LabelOrientation','horizontal');
    h.pois.zR_x_neg = xline(h.ax,len_mult2*(obj.results.x.z0-obj.results.x.zR),...
        ':r','Label','-z_{R,x}','LabelOrientation','horizontal','LabelHorizontalAlignment','left');
    h.pois.z0_y = xline(h.ax,len_mult2*obj.results.y.z0,...
        '-.b','Label','z_{0,y}','LabelVerticalAlignment','bottom','LabelOrientation','horizontal');
    h.pois.zR_y_pos = xline(h.ax,len_mult2*(obj.results.y.z0+obj.results.y.zR),...
        ':b','Label','+z_{R,y}','LabelVerticalAlignment','bottom','LabelOrientation','horizontal');
    h.pois.zR_y_neg = xline(h.ax,len_mult2*(obj.results.y.z0-obj.results.y.zR),...
        ':b','Label','-z_{R,y}','LabelVerticalAlignment','bottom','LabelOrientation','horizontal','LabelHorizontalAlignment','left');
else
    % just need to update
    h.pois.z0_x.Value = len_mult2*obj.results.x.z0;
    h.pois.zR_x_pos.Value = len_mult2*(obj.results.x.z0+obj.results.x.zR);
    h.pois.zR_x_neg.Value = len_mult2*(obj.results.x.z0-obj.results.x.zR);
    h.pois.z0_y.Value = len_mult2*obj.results.y.z0;
    h.pois.zR_y_pos.Value = len_mult2*(obj.results.y.z0+obj.results.y.zR);
    h.pois.zR_y_neg.Value = len_mult2*(obj.results.y.z0-obj.results.y.zR);
end

%% update data in plots or generate elemens if drawing figure
% patch regions of caustic within +/- 1 rayleigh length

patchXzr_xdata = linspace(obj.results.x.z0-obj.results.x.zR,obj.results.x.z0+obj.results.x.zR,50);
patchXzr_ydata = obj.figs.anonfuns.caustic(patchXzr_xdata,obj.results.x.d0,obj.results.x.z0,obj.results.x.zR)/2;
patchYzr_xdata = linspace(obj.results.y.z0-obj.results.y.zR,obj.results.y.z0+obj.results.y.zR,50);
patchYzr_ydata = obj.figs.anonfuns.caustic(patchYzr_xdata,obj.results.y.d0,obj.results.y.z0,obj.results.y.zR)/2;

if initAllGraphics
    h.patch.X = fill(h.ax,len_mult2*[obj.results.z_fit, fliplr(obj.results.z_fit)],...
                        len_mult*0.5*[obj.results.dx_fit, fliplr(-obj.results.dx_fit)],...
                        'r', 'FaceAlpha', 0.05, 'EdgeAlpha', 0);
    h.patch.Y = fill(h.ax,len_mult2*[obj.results.z_fit, fliplr(obj.results.z_fit)],...
                        len_mult*0.5*[obj.results.dy_fit, fliplr(-obj.results.dy_fit)],...
                        'b', 'FaceAlpha', 0.05, 'EdgeAlpha', 0);
    h.patch.Xzr = fill(h.ax,len_mult2*[patchXzr_xdata, fliplr(patchXzr_xdata)],...
                        len_mult*[patchXzr_ydata, fliplr(-patchXzr_ydata)],...
                        'r', 'FaceAlpha', 0.15, 'EdgeAlpha', 0);
    h.patch.Yzr = fill(h.ax,len_mult2*[patchYzr_xdata, fliplr(patchYzr_xdata)],...
                        len_mult*[patchYzr_ydata, fliplr(-patchYzr_ydata)],...
                        'b', 'FaceAlpha', 0.15, 'EdgeAlpha', 0);
else
    h.patch.X.XData = len_mult2*[obj.results.z_fit, fliplr(obj.results.z_fit)];
    h.patch.X.YData = len_mult*0.5*[obj.results.dx_fit, fliplr(-obj.results.dx_fit)];
    h.patch.Y.XData = len_mult2*[obj.results.z_fit, fliplr(obj.results.z_fit)];
    h.patch.Y.YData = len_mult*0.5*[obj.results.dy_fit, fliplr(-obj.results.dy_fit)];
    h.patch.Xzr.XData = len_mult2*[patchXzr_xdata, fliplr(patchXzr_xdata)];
    h.patch.Xzr.YData = len_mult*[patchXzr_ydata, fliplr(-patchXzr_ydata)];
    h.patch.Yzr.XData = len_mult2*[patchYzr_xdata, fliplr(patchYzr_xdata)];
    h.patch.Yzr.YData = len_mult*[patchYzr_ydata, fliplr(-patchYzr_ydata)];
end

%% Text / Annotation
annotstr = struct();
annotstr.x = {strcat('\color{red}z_{0,x} =',sprintf(' %.3g %s',len_mult2*obj.results.x.z0,len_str2)),...
    sprintf('d_{0,x} = %.3g %s',len_mult*obj.results.x.d0,len_str),...
    sprintf('\\theta_{x} = %.3g %s',ang_mult*obj.results.x.divergence,ang_str),...
    sprintf('z_{R,x} = %.3g %s',len_mult2*obj.results.x.zR,len_str2),...
    sprintf('M^{2}_{x} = %.3g',obj.results.x.msquared),...
    };

annotstr.y = {strcat('\color{blue}z_{0,y} =',sprintf(' %.3g %s',len_mult2*obj.results.y.z0,len_str2)),...
    sprintf('d_{0,y} = %.3g %s',len_mult*obj.results.y.d0,len_str),...
    sprintf('\\theta_{y} = %.3g %s',ang_mult*obj.results.y.divergence,ang_str),...
    sprintf('z_{R,y} = %.3g %s',len_mult2*obj.results.y.zR,len_str2),...
    sprintf('M^{2}_{y} = %.3g',obj.results.y.msquared),...
    };

annotstr.global = {strcat('\color{black}M^{2}_{eff} =',sprintf(' %.3g',obj.results.msquared_effective)),...
    sprintf('\\Deltaz_{x,y} = %.3g %s',len_mult2*obj.results.deltaz_xy,len_str2),...
    '',...
    '',...
    '',...
    ''};

if obj.results.intrinsic_stigmatic
    annotstr.global{3} = 'intrinsic stigmatic';
else
    annotstr.global{3} = 'intrinsic astigmatic';
end

[ellipticity_min,idx] = min(obj.results.ellipticity_fit);
    annotstr.global{4} = sprintf('\\epsilon_{min} = %1.2f',ellipticity_min);
if ~any(isnan(obj.results.dminRound))
    annotstr.global{5} = sprintf('d_{min,\\epsilon<1.15} = %.3g %s',...
        len_mult*obj.results.dminRound(2),len_str);
    annotstr.global{6} = sprintf('z_{\\epsilon<1.15} = %.3g %s',...
        len_mult2*obj.results.dminRound(1),len_str2);
else
    annotstr.global{5} = sprintf('d_{\\epsilon_{min}} = %.3g %s',...
                                 len_mult*obj.results.diameterEffective(idx),len_str);
    annotstr.global{6} = sprintf('z_{\\epsilon_{min}} = %.3g %s',...
                                 len_mult2*obj.results.z_fit(idx),len_str2);
end

% switch x and y in text such that the "top" focal plane coincides with the
% "top" annotation
if obj.results.x.z0 < obj.results.y.z0
    annotstr.concat = [annotstr.x,annotstr.y,annotstr.global];
else
    annotstr.concat = [annotstr.y,annotstr.x,annotstr.global];
end

% position the text between the focal planes and shift outside of x axis
annotpos = [h.ax.XLim(end)*1.02,0];

if initAllGraphics
    h.annotation = text(h.ax,annotpos(1),annotpos(2),annotstr.concat);
    %set(h.annotation, 'Clipping', 'on');
else
    h.annotation.String = annotstr.concat.';
    h.annotation.Position = [annotpos(1),annotpos(2)];
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
obj.figs.plot2 = h;

% force view at the end
% view(h.ax,[45 45])
% camroll(h.ax,90)

end