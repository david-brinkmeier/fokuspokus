function debugplot(ROIs,img)
% takes a mask and image and shows the result
%
% input / error checking
if ~isnumeric(img)
    error('img must be numeric 2D or 3D array')
end
if ~iscell(ROIs)
    ROIs = {ROIs};
end
if ~all(cellfun(@(x) isa(x,'mask'),ROIs))
    error('Input must be a cell array of masks or a single mask!')
end
% get length of image stack
len = size(img,3);
if ~isequal(len,length(ROIs))
    error('number of images and number of masks do not match')
end
for i = 1:len
    if ~isequal(size(img,1:2),[ROIs{i}.ymax, ROIs{i}.xmax])
        error('to-be-cropped image and mask specification refsz do not mach starting at mask %i',i)
    end
end

%% gen data struct of figdata
data = struct();
data.len = len;
data.img = img;
data.ROIs = ROIs;
data.clims = @(img,idx) [0, max(data.img(:,:,idx),[],'all')];
data.xlims = [0 size(img,2)+1];
data.ylims = [0 size(img,1)+1];
data.xlims_c = @(data,idx) [0, data.ROIs{idx}.lenx+2];
data.ylims_c = @(data,idx) [0, data.ROIs{idx}.leny+2];

% gen Colormap, make sure first value is white
cmap = jet(255); cmap(1,:) = ones(1,3);
% start at first image in image stack
idx = 1;

% gen handles struct
handles = struct();
handles.figstr = '[guiROI] Image:';

% gen and init fig
handles.fig = figure('name',sprintf('%s %i/%i',handles.figstr,idx,data.len),'color','w');
sgtitle(handles.fig,'Interactivity: Mouse wheel!')
handles.ax_a = subplot(1,3,1); box(handles.ax_a,'on')
handles.ax_b = subplot(1,3,2); box(handles.ax_b,'on')
handles.ax_c = subplot(1,3,3); box(handles.ax_c,'on')
axis(handles.ax_a,'image'); axis(handles.ax_b,'image'); axis(handles.ax_c,'image')
hold(handles.ax_a,'on'); hold(handles.ax_b,'on'); hold(handles.ax_c,'on');
colormap(handles.fig,cmap)
xlabel(handles.ax_a,'x [pixel]'), ylabel(handles.ax_a,'y [pixel]')
xlabel(handles.ax_b,'x [pixel]'), ylabel(handles.ax_b,'y [pixel]')
xlabel(handles.ax_c,'x [pixel]'), ylabel(handles.ax_c,'y [pixel]')
title(handles.ax_a,'Input')
title(handles.ax_b,'Masked')
title(handles.ax_c,'Selection')
xlim(handles.ax_a,data.xlims), ylim(handles.ax_a,data.ylims)
xlim(handles.ax_b,data.xlims), ylim(handles.ax_b,data.ylims)

% subplot 1
handles.imagesc_a = imagesc(handles.ax_a,data.img(:,:,idx));
caxis(handles.ax_a,data.clims(data.img,idx))

% subplot 2
handles.imagesc_b = imagesc(handles.ax_b,mask.mask_image(data.img(:,:,idx),data.ROIs{idx}));
handles.rectangle_b = rectangle(handles.ax_b,'Position', data.ROIs{idx}.selection,...
                                             'EdgeColor', 'r', 'FaceColor', 'none', 'LineWidth', 1.5);
caxis(handles.ax_b,data.clims(data.img,idx))

% subplot 3
handles.imagesc_c = imagesc(handles.ax_c,mask.crop_image(data.img(:,:,idx),data.ROIs{idx}));
caxis(handles.ax_c,data.clims(data.img,idx))
xlim(handles.ax_c,data.xlims_c(data,idx)), ylim(handles.ax_c,data.ylims_c(data,idx))

%% IMPORTANT: save current index in fig UserData for dynamic access
handles.fig.UserData.index = idx;
% callback for mouse wheel
set(handles.fig, 'WindowScrollWheelFcn', {@wheel, handles, data});

end

function wheel(hObject, eventdata, handles, data)
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

%% update fig(name)
handles.fig.Name = sprintf('%s %i/%i',handles.figstr,idx,data.len);

% update subplot 1
handles.imagesc_a.CData = data.img(:,:,idx);
caxis(handles.ax_a,data.clims(data.img,idx))
% update subplot 2
handles.imagesc_b.CData = mask.mask_image(data.img(:,:,idx),data.ROIs{idx});
handles.rectangle_b.Position = data.ROIs{idx}.selection;
caxis(handles.ax_b,data.clims(data.img,idx))
% update subplot 3
handles.imagesc_c.CData = mask.crop_image(data.img(:,:,idx),data.ROIs{idx});
caxis(handles.ax_c,data.clims(data.img,idx))
xlim(handles.ax_c,data.xlims_c(data,idx)), ylim(handles.ax_c,data.ylims_c(data,idx))

end



