function debugplot(obj,img)
% get plot data
data = imMoments.genplotdata(obj,[],[],[],'normalized','xy');
data.theta = obj.theta;
data.len = obj.len;
data.figstr = '[moments] Image';
data.titlestr = 'Interactivity: Mouse wheel!';
data.lastx = @(img,idx) find(gradient(sum(img(:,:,idx),1)),1,'last'); % last relevant x index
data.lasty = @(img,idx) find(gradient(sum(img(:,:,idx),2)),1,'last'); % last relevant y index

% gen Colormap, make sure first value is white
cmap = jet(255); cmap(1,:) = ones(1,3);

%% instantiate fig
handles.fig = figure('name',sprintf('%s %i/%i',data.figstr,1,data.len),'color','w');
handles.ax = axes(handles.fig);
box(handles.ax,'on');
xlabel(handles.ax,'x [pixel]'), ylabel(handles.ax,'y [pixel]')
hold(handles.ax,'on');
axis(handles.ax,'image');
colormap(handles.fig,cmap)

% IMPORTANT: save current index in fig UserData for dynamic access
idx = 1;
handles.fig.UserData.index = idx;

% get last relevant x/y index
lastx = data.lastx(img,idx);
lasty = data.lasty(img,idx);

% instantiate plot
handles.img = imagesc(handles.ax,img(1:lasty,1:lastx,idx)); % remember: matlab ymajor..
handles.ellipse = plot(handles.ax,data.ellipse.XData(:,idx),data.ellipse.YData(:,idx),'-m','LineWidth',1.5);
handles.xax = plot(handles.ax,data.xax.XData(:,idx),data.xax.YData(:,idx),'-m','LineWidth',1.5);
handles.yax = plot(handles.ax,data.yax.XData(:,idx),data.yax.YData(:,idx),'-m','LineWidth',1.5);
handles.title = title({data.titlestr,...
                       sprintf('\\theta = %.1f°',rad2deg(data.theta(idx)))});
% adjust caxis and lims
caxis(handles.ax,[0,max(img(:,:,idx),[],'all')])
xlim(handles.ax,[0 lastx+1])
ylim(handles.ax,[0 lasty+1])

%% callback for mouse wheel
set(handles.fig, 'WindowScrollWheelFcn', {@wheel, handles, data, img});
end

function wheel(hObject, eventdata, handles, data, img)
% get current index
idx = handles.fig.UserData.index;
% advance by scrollwheel
idx = idx + eventdata.VerticalScrollCount;
% constraints
if idx > data.len
    idx = data.len;
end
if idx < 1
    idx = 1;
end
% save new index
handles.fig.UserData.index = idx;

% update figname / title
handles.fig.Name = sprintf('%s %i/%i',data.figstr,idx,data.len);
handles.title.String = {data.titlestr,sprintf('\\theta = %.1f°',rad2deg(data.theta(idx)))};

% get last relevant x/y index
lastx = data.lastx(img,idx);
lasty = data.lasty(img,idx);

% update plot / data
handles.img.CData = img(1:lasty,1:lastx,idx);
handles.ellipse.XData = data.ellipse.XData(:,idx);
handles.ellipse.YData = data.ellipse.YData(:,idx);
handles.xax.XData = data.xax.XData(:,idx);
handles.xax.YData = data.xax.YData(:,idx);
handles.yax.XData = data.yax.XData(:,idx);
handles.yax.YData = data.yax.YData(:,idx);

% adjust caxis and lims
caxis(handles.ax,[0,max(img(:,:,idx),[],'all')])
xlim(handles.ax,[0 lastx+1])
ylim(handles.ax,[0 lasty+1])
end