function [images_centered,moments_centered] = centerimgs(images_in,moments_in,debug,normalize)
% this function centers the image stack such that their center of mass
% "roughly" aligns along the third dimension of the image stack
% only integer pixel shifts are realized for faster computation
% but residual x/y offsets are exported via moments_centered
%
% images is a 3d image stack
% moments are image moments, where moments.xc and moments.yc are vectors of
% length (1,size(imagestack,3)) representing the centroids in pixel
% coordinates (default coordinates 1:1:end)

% how many images are in the stack
len = size(images_in,3);

% prallocate centered output image stack
images_centered = zeros(size(images_in));

% get center in pixel coordinates (first two dimenisions must be of odd
% size, otherwise there is no well-defined center (subpixel center!)
center = (size(images_in,1:2)+1)/2; % yields [img_ycenter, img_xcenter] in px coordinates
imcenter.x = center(2); % for readability
imcenter.y = center(1); % for readability

% prallocate
xc_centered = nan(1,len);
yc_centered = nan(1,len);

for i = 1:len
    % where is the center of the image
    shifts = [imcenter.x-moments_in.xc(i),...
              imcenter.y-moments_in.yc(i)]; % img translation offset vector [x,y]
    % integer shifts for fast image translation by indexing
    shifts_int = round(shifts,0);
    % remaining shifts / actual barycenter in normalized (pixel) coordinates
    shifts_rem = rem((shifts_int-shifts),1) + [imcenter.x,imcenter.y];
    % update moments_out
    xc_centered(i) = shifts_rem(1);
    yc_centered(i) = shifts_rem(2);
    % translate and process image (fast)
    images_centered(:,:,i) = imtranslate_integer(images_in(:,:,i),shifts_int(1),shifts_int(2));
    % normalize...when doing plots this means all images can share same
    % caxis with the intensity profile being visible
    if normalize
        images_centered(:,:,i) = images_centered(:,:,i)./max(images_centered(:,:,i),[],'all');
    end
    
    if debug
        translated_image_legacy = imtranslate(images_in(:,:,i),shifts_int,'FillValues',0);
        check_1 = isequal(images_centered(:,:,i),translated_image_legacy);
        a = interp2(images_in(:,:,i),moments_in.xc(i),moments_in.yc(i));
        b = interp2(images_centered(:,:,i),shifts_rem(1),shifts_rem(2));
        check_2 = abs(a-b) < 1e4*eps(min(abs(a),abs(b))); % isequal w/ tolerance
        fprintf('%i, %i | ',check_1,check_2)        
    end
end

% after imtranslate we can set zeros to NaN (making them transparent in subsequent plots)
images_centered(images_centered <= 0) = NaN;

if debug
    fprintf('\n')
    debugplot(images_in,images_centered,moments_in.xc,moments_in.yc,xc_centered,yc_centered)
end

% update moments out
moments_centered = moments_in;
moments_centered.xc = xc_centered;
moments_centered.yc = yc_centered;

end

function output = imtranslate_integer(img,shift_x,shift_y)
% this function replicates the functionality of imtranslate(img,[shift_x, shift_y])
% no error checking (e.g. out of boundary) etc.
% much faster than imtranslate!
% shift_x and shift_y must be integers

% get dimensions
[ymax,xmax] = size(img);
% preallocate
output = zeros(ymax,xmax);

% conditions for positive or negative shift, x-axis
if shift_x >= 0
    x_out = (1 + shift_x) : xmax;
    x_src = 1 : (xmax - shift_x);
elseif shift_x < 0
    x_out = 1 : (xmax - abs(shift_x));
    x_src = (1 + abs(shift_x)) : xmax;
end
% conditions for positive or negative shift, y-axis
if shift_y >= 0
    y_out = (1 + shift_y) : ymax;
    y_src = 1 : (ymax - shift_y);
elseif shift_y < 0
    y_out = 1 : (ymax - abs(shift_y));
    y_src = (1 + abs(shift_y)) : ymax;
end

% assign
output(y_out,x_out) = img(y_src,x_src);
end

function debugplot(src_img,out_img,xc_in,yc_in,xc_out,yc_out)
% get image size
[szy,szx,szz] = size(src_img);

% gen data struct
data = struct();
data.src_img = src_img;
data.out_img = out_img;
data.xc_in = xc_in;
data.yc_in = yc_in;
data.xc_out = xc_out;
data.yc_out = yc_out;
data.len = szz;
data.xaxis = -1+(1:szx)-(szx-1)/2; % image center = 0
data.yaxis = -1+(1:szy)-(szy-1)/2; % image center = 0
data.xinterp = @(val) interp1(data.xaxis,val);
data.yinterp = @(val) interp1(data.yaxis,val);

% gen Colormap, make sure first value is white
cmap = jet(255); %cmap(1,:) = [1 1 1];
lwidth = {'LineWidth',1.5};
clr = 'w';
lspec_a = sprintf('%s%s','-',clr);
lspec_b = sprintf('%s%s',':',clr);

% gen and init fig
handles.fig = figure('name',sprintf('Image %i/%i',1,data.len),'color','w');
sgtitle(handles.fig,'Interactivity: Mouse wheel!')
handles.ax_a = subplot(1,2,1); %handles.ax_a.Visible = false;
handles.ax_b = subplot(1,2,2); %handles.ax_b.Visible = false;
hold(handles.ax_a,'on'); hold(handles.ax_b,'on');
axis(handles.ax_a,'image'); axis(handles.ax_b,'image')
colormap(handles.fig,cmap)

% init source plot (left)
handles.img_a = imagesc(handles.ax_a,data.xaxis,data.yaxis,src_img(:,:,1));
caxis(handles.ax_a,[0 max(src_img(:,:,1),[],'all')])
handles.xl_a = xline(handles.ax_a,data.xinterp(xc_in(1)),lspec_a,lwidth{:},'Label',sprintf('%.1f',data.xinterp(xc_in(1))));
handles.yl_a = yline(handles.ax_a,data.yinterp(yc_in(1)),lspec_a,lwidth{:},'Label',sprintf('%.1f',data.yinterp(yc_in(1))));
plot(handles.ax_a,data.xaxis([1,end]),data.yaxis([1,end]),lspec_b,lwidth{:})
plot(handles.ax_a,data.xaxis([1,end]),data.yaxis([end,1]),lspec_b,lwidth{:})
title(handles.ax_a,'source')

% init translated plot (right)
handles.img_b = imagesc(handles.ax_b,data.xaxis,data.yaxis,out_img(:,:,1));
caxis(handles.ax_b,[0 max(out_img(:,:,1),[],'all')])
handles.xl_b = xline(handles.ax_b,data.xinterp(xc_out(1)),lspec_a,lwidth{:},'Label',sprintf('%.1f',data.xinterp(xc_out(1))));
handles.yl_b = yline(handles.ax_b,data.xinterp(yc_out(1)),lspec_a,lwidth{:},'Label',sprintf('%.1f',data.xinterp(yc_out(1))));
plot(handles.ax_b,data.xaxis([1,end]),data.yaxis([1,end]),lspec_b,lwidth{:})
plot(handles.ax_b,data.xaxis([1,end]),data.yaxis([end,1]),lspec_b,lwidth{:})
title(handles.ax_b,'translated')

% IMPORTANT: save current index in fig UserData for dynamic access
handles.fig.UserData.index = 1;
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

% update figname
handles.fig.Name = sprintf('Image %i/%i',idx,data.len);
% update subplot 1
handles.img_a.CData = data.src_img(:,:,idx);
caxis(handles.ax_a,[0 max(data.src_img(:,:,idx),[],'all')])
handles.xl_a.Value = data.xinterp(data.xc_in(idx));
handles.xl_a.Label = sprintf('%.1f',data.xinterp(data.xc_in(idx)));
handles.yl_a.Value = data.yinterp(data.yc_in(idx));
handles.yl_a.Label = sprintf('%.1f',data.yinterp(data.yc_in(idx)));
% update subplot 2
handles.img_b.CData = data.out_img(:,:,idx);
caxis(handles.ax_b,[0 max(data.out_img(:,:,idx),[],'all')])
handles.xl_b.Value = data.xinterp(data.xc_out(idx));
handles.xl_b.Label = sprintf('%.1f',data.xinterp(data.xc_out(idx)));
handles.yl_b.Value = data.yinterp(data.yc_out(idx));
handles.yl_b.Label = sprintf('%.1f',data.yinterp(data.yc_out(idx)));
end
