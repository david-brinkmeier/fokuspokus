function obj = denoise(obj)
% prepare output arrays
len = size(obj.img.src,3);
% make internal copy of img src: img may be pre-filtered using lowpass
img = obj.img.src;

% apply lowpass filter which passes frequencies below 0 (DC) and nyquist frequency
if obj.settings.denoise.freqfilt == true
    [img,obj.img.lowpass_freqfilt] = butterworth(obj.img.src, 1, 15, 0, 0.5*0.7, obj.img.lowpass_freqfilt);
end

% get axes, mask, preallocate
if isempty(obj.img.ROI)
    sz = size(obj.img.src(:,:,1));
    logmask = mask.radial_logmask(sz(1:2));
    % generate empty output array and generate axes if necessary
    % (if ROIs exist then this has already happened by autoROI / guiROI)
    if isempty(obj.img.denoised) || ~isequal(size(obj.img.denoised),sz)
        obj.denoisedIMG = zeros(size(obj.img.src));
    end
else
    % reset; NECESSARY if ROI is used!
    obj.denoisedIMG = 0.*obj.img.denoised;
end

% use temporary internal variable (verified faster than iteratively writing to obj; OOP overhead?!)
denoised = obj.img.denoised;
% preallocate
plotdata = struct();
bgplotdata = cell(len,1);

%% denosing starts here
for i = 1:len
    if isempty(obj.img.ROI)
        % feed image and logmask to rmbackground
        [processed_img,bgplotdata{i,1}] = obj.rmbackground(img(:,:,i),logmask,obj.settings.denoise); 
    else
        % when ROIs are provided process partial image based on ROI spec.
        [processed_img,bgplotdata{i,1}] = obj.rmbackground(mask.crop_image(img(:,:,i),obj.img.ROI{i},[]),...
                                                           obj.img.ROI{i}.logmask,...
                                                           obj.settings.denoise); 
    end
    % apply median filter
    if obj.settings.denoise.median ~= 1
        processed_img = medfilt2(processed_img,obj.settings.denoise.median.*[1 1]);
    end
    % apply averaging (gaussian) and thresholding
    if obj.settings.denoise.gaussian.enable
        if i == 1; nthpercentile = @(data,percent) interp1(linspace(1/numel(data),1,numel(data)), sort(data(:)), percent/100); end
        % set all values to zero that
        threshold = nthpercentile(processed_img(logical(processed_img)),obj.settings.denoise.gaussian.percentile);
        if obj.settings.denoise.gaussian.sigma > 0
            processed_img = conv2(processed_img,fspecial('gaussian',9,abs(obj.settings.denoise.gaussian.sigma)),'same');
        end
        processed_img(processed_img < threshold) = 0;
    end
    % done
    if isempty(obj.img.ROI)
        denoised(:,:,i) = processed_img;
    else
        denoised(1:(obj.img.ROI{i}.leny+1), 1:(obj.img.ROI{i}.lenx+1),i) = processed_img;
    end
end
% write result
obj.denoisedIMG = denoised;
% done

%% debug plot
if  obj.settings.denoise.debug
    % reset debug flag
    obj.settings.denoise.debug = false;
    % make debug plot
    plotdata.bg = bgplotdata;
    plotdata.len = size(img,3);
    plotdata.src_img = obj.img.src;
    plotdata.img = img;
    plotdata.denoised_img = obj.img.denoised;
    plotdata.ROI = obj.img.ROI;
    if isempty(obj.img.ROI)
        plotdata.logmask = logmask;
    end
    debugplot(plotdata);
    fftshowIMG(obj.img.src,obj.pixelpitch,'auto');
    fftshowIMG(img,obj.pixelpitch,'auto');
    fftshowIMG(denoised,obj.pixelpitch,'auto');
end

end

%% only debugging stuff starting here

function debugplot(data)
% start figure off with first image
idx = 1;

% gen Colormap, make sure first value is white
cmap = jet(255); cmap(1,:) = ones(1,3);

% gen and init fig
handles = struct();
handles.fig = figure('name',sprintf('[Denoise] Image %i/%i',idx,data.len),'color','w');
handles.fig.Position(3) = handles.fig.Position(3)*1.5; 

handles.ax_a = subplot(2,3,1); box(handles.ax_a,'on')
handles.ax_b = subplot(2,3,2); box(handles.ax_b,'on')
handles.ax_c = subplot(2,3,3); box(handles.ax_c,'on')

handles.ax_d = subplot(2,3,4); box(handles.ax_d,'on') % rmbackground
handles.ax_e = subplot(2,3,5); box(handles.ax_e,'on') % rmbackground
handles.ax_f = subplot(2,3,6); box(handles.ax_f,'on') % rmbackground

hold(handles.ax_a,'on'); hold(handles.ax_b,'on'); hold(handles.ax_c,'on');
hold(handles.ax_d,'on'); hold(handles.ax_e,'on'); hold(handles.ax_f,'on');

axis(handles.ax_a,'image'); axis(handles.ax_b,'image'); axis(handles.ax_c,'image')
daspect(handles.ax_d,[1 1 1])

xlabel(handles.ax_a,'x [pixel]'), ylabel(handles.ax_a,'y [pixel]')
xlabel(handles.ax_b,'x [pixel]'), ylabel(handles.ax_b,'y [pixel]')
xlabel(handles.ax_c,'x [pixel]'), ylabel(handles.ax_c,'y [pixel]')
xlabel(handles.ax_d,'x [pixel]'), ylabel(handles.ax_d,'y [pixel]'), zlabel(handles.ax_d,'z [energy, a.u.]')
xlabel(handles.ax_e,'x [pixel]'), ylabel(handles.ax_e,'y [pixel]'), zlabel(handles.ax_e,'z [energy, a.u.]')
xlabel(handles.ax_f,'x [pixel]'), ylabel(handles.ax_f,'y [pixel]'), zlabel(handles.ax_f,'z [energy, a.u.]')

title(handles.ax_a,'Input')
title(handles.ax_b,'Statistics Mask')
title(handles.ax_c,'final Output')
handles.img_d.title = title(handles.ax_d,{'bg plane',data.bg{idx}.normal.str});
title(handles.ax_e,'input vs. bg plane')
title(handles.ax_f,'input-(bgplane+n*std) & >= 0')

colormap(handles.fig,cmap)
colormap(handles.ax_d,'jet')

%% init mask plot / extracted part for statistics, subplot(2,3,2)
% need to make middle plot first bc we need correct boundary for plot 1 as well
if isempty(data.ROI)
    data.getmaskedimg = @(data,idx) data.img(:,:,idx).*double(data.logmask);
else
    data.getmaskedimg = @(data,idx) mask.crop_image(data.img(:,:,idx),data.ROI{idx},[]).*double(data.ROI{idx}.logmask);
end
% get data
masked_img = data.getmaskedimg(data,idx);
[~,boundary] = mask.radial_logmask(size(masked_img));
% plot circular region of logmask
handles.img_b.imagesc = imagesc(handles.ax_b,masked_img);
handles.img_b.plot = plot(handles.ax_b,boundary(1,:),boundary(2,:),'-k','LineWidth',2);
% adjust limits
xlim(handles.ax_b,[0 size(masked_img,2)+1])
ylim(handles.ax_b,[0 size(masked_img,1)+1])

%% init input image plot, subplot(2,3,1)
handles.img_a.imagesc = imagesc(handles.ax_a,data.src_img(:,:,idx));
if ~isempty(data.ROI)
    handles.img_a.rectangle = rectangle(handles.ax_a,'Position', [data.ROI{idx}.xstart, data.ROI{idx}.ystart, data.ROI{idx}.lenx, data.ROI{idx}.leny],...
        'EdgeColor', 'r', 'FaceColor', 'none', 'LineWidth', 1.5);
    data.getboundary_img_a = @(data,idx,boundary) [boundary(1,:)+data.ROI{idx}.xstart-1; boundary(2,:)+data.ROI{idx}.ystart-1];
else
    data.getboundary_img_a = @(data,idx,boundary) boundary;
end
boundary_img_a = data.getboundary_img_a(data,idx,boundary);
handles.img_a.plot = plot(handles.ax_a,boundary_img_a(1,:),boundary_img_a(2,:),'--r','LineWidth',2);
caxis(handles.ax_a,[0 max(data.src_img(:,:,idx),[],'all')])
xlim(handles.ax_a,[0,size(data.src_img(:,:,idx),2)])
ylim(handles.ax_a,[0,size(data.src_img(:,:,idx),1)])

%% init result plot, subplot(2,3,3); % generate fcn handles based on existence of ROIs
if isempty(data.ROI)   
    data.getImageData_img_c = @(data,idx) data.denoised_img(:,:,idx);
    data.getxlims_img_c = @(data,idx) [0 size(data.denoised_img,2)+1];
    data.getylims_img_c = @(data,idx) [0 size(data.denoised_img,1)+1];
else
    data.getImageData_img_c = @(data,idx) data.denoised_img(1:(data.ROI{idx}.leny+1),1:(data.ROI{idx}.lenx+1),idx);
    xlim([0 data.ROI{idx}.lenx+2]), ylim([0 data.ROI{idx}.leny+2])
    data.getxlims_img_c = @(data,idx) [0 data.ROI{idx}.lenx+2];
    data.getylims_img_c = @(data,idx) [0 data.ROI{idx}.leny+2];
end
% make plot
handles.img_c.imagesc = imagesc(handles.ax_c,data.getImageData_img_c(data,idx));
xlim(handles.ax_c,data.getxlims_img_c(data,idx))
ylim(handles.ax_c,data.getylims_img_c(data,idx))
caxis(handles.ax_c,[0 max(data.denoised_img(:,:,idx),[],'all')])

%% init background plane fit vs logmask values, subplot(2,3,4)
handles.img_d.scatter = scatter3(handles.ax_d,data.bg{idx}.points.x,data.bg{idx}.points.y,data.bg{idx}.points.z,30,data.bg{idx}.points.z,...
    'filled','MarkerEdgeColor','none','MarkerFaceAlpha',0.5);
handles.img_d.patch = patch(handles.ax_d,data.bg{idx}.vertices.x, data.bg{idx}.vertices.y, data.bg{idx}.vertices.z, 'k', 'FaceAlpha', .4);
handles.img_d.plot = plot3(handles.ax_d,data.bg{idx}.normal.line.x,data.bg{idx}.normal.line.y,data.bg{idx}.normal.line.z,'-.k','Linewidth',2);
xlim(handles.ax_d,data.bg{idx}.xlims{1})
ylim(handles.ax_d,data.bg{idx}.ylims{1})
view(handles.ax_d,3)

%% init input image + least square fit plane plot, subplot(2,3,5)
handles.img_e.surf = surf(handles.ax_e,data.bg{idx}.img);
shading(handles.ax_e,'flat')
handles.img_e.patch = patch(handles.ax_e,data.bg{idx}.vertices.x, data.bg{idx}.vertices.y, data.bg{idx}.vertices.z, 'm', 'FaceAlpha', .5);
xlim(handles.ax_e,data.bg{idx}.xlims{1})
ylim(handles.ax_e,data.bg{idx}.ylims{1})
caxis(handles.ax_e,data.bg{idx}.caxis{1})
daspect(handles.ax_e,data.bg{idx}.daspect{1})
view(handles.ax_e,3)

%% init beam after plane correction and removal of stddev + positivity constraint, subplot(2,3,6)
handles.img_f.surf = surf(handles.ax_f,data.bg{idx}.img_processed);
shading(handles.ax_f,'flat')
xlim(handles.ax_f,data.bg{idx}.xlims{2}+[-1,1])
ylim(handles.ax_f,data.bg{idx}.ylims{2}+[-1,1])
caxis(handles.ax_f,data.bg{idx}.caxis{2})
daspect(handles.ax_f,data.bg{idx}.daspect{2})
view(handles.ax_f,3)

%% IMPORTANT: save current index in fig UserData for dynamic access
handles.fig.UserData.index = idx;
handles.fig.UserData.view = 3;
% callback for mouse wheel
set(handles.fig, 'WindowScrollWheelFcn', {@wheel, handles, data});
set(handles.fig, 'windowbuttondownfcn', {@mouseclick, handles});
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
handles.fig.Name = sprintf('[Denoise] Image: %i/%i',idx,data.len);

% get data
masked_img = data.getmaskedimg(data,idx);
[~,boundary] = mask.radial_logmask(size(masked_img));

%% update subplot 1
handles.img_a.imagesc.CData = data.src_img(:,:,idx);
boundary_img_a = data.getboundary_img_a(data,idx,boundary);
if ~isempty(data.ROI)
    handles.img_a.rectangle.Position = [data.ROI{idx}.xstart, data.ROI{idx}.ystart, data.ROI{idx}.lenx, data.ROI{idx}.leny];
end
handles.img_a.plot.XData = boundary_img_a(1,:);
handles.img_a.plot.YData = boundary_img_a(2,:);
caxis(handles.ax_a,[0 max(data.src_img(:,:,idx),[],'all')])

%% update subplot 2
% plot circular region of logmask
handles.img_b.imagesc.CData = masked_img;
handles.img_b.plot.XData = boundary(1,:);
handles.img_b.plot.YData = boundary(2,:);
% adjust limits
xlim(handles.ax_b,[0 size(masked_img,2)+1])
ylim(handles.ax_b,[0 size(masked_img,1)+1])

%% update subplot 3
handles.img_c.imagesc.CData = data.getImageData_img_c(data,idx);
xlim(handles.ax_c,data.getxlims_img_c(data,idx))
ylim(handles.ax_c,data.getylims_img_c(data,idx))
caxis(handles.ax_c,[0 max(data.denoised_img(:,:,idx),[],'all')])

%% update subplot 4
handles.img_d.title.String = {'bg plane',data.bg{idx}.normal.str};

handles.img_d.scatter.XData = data.bg{idx}.points.x;
handles.img_d.scatter.YData = data.bg{idx}.points.y;
handles.img_d.scatter.ZData = data.bg{idx}.points.z;
handles.img_d.scatter.CData = data.bg{idx}.points.z;

handles.img_d.patch.XData = data.bg{idx}.vertices.x;
handles.img_d.patch.YData = data.bg{idx}.vertices.y;
handles.img_d.patch.ZData = data.bg{idx}.vertices.z;

handles.img_d.plot.XData = data.bg{idx}.normal.line.x;
handles.img_d.plot.YData = data.bg{idx}.normal.line.y;
handles.img_d.plot.ZData = data.bg{idx}.normal.line.z;

xlim(handles.ax_d,data.bg{idx}.xlims{1})
ylim(handles.ax_d,data.bg{idx}.ylims{1})

%% update subplot 5
handles.img_e.surf.ZData = data.bg{idx}.img;

handles.img_e.patch.XData = data.bg{idx}.vertices.x;
handles.img_e.patch.YData = data.bg{idx}.vertices.y;
handles.img_e.patch.ZData = data.bg{idx}.vertices.z;

xlim(handles.ax_e,data.bg{idx}.xlims{1})
ylim(handles.ax_e,data.bg{idx}.ylims{1})
caxis(handles.ax_e,data.bg{idx}.caxis{1})
daspect(handles.ax_e,data.bg{idx}.daspect{1})

%% update subplot 6
handles.img_f.surf.ZData = data.bg{idx}.img_processed;
xlim(handles.ax_f,data.bg{idx}.xlims{2}+[-1,1])
ylim(handles.ax_f,data.bg{idx}.ylims{2}+[-1,1])
caxis(handles.ax_f,data.bg{idx}.caxis{2})
daspect(handles.ax_f,data.bg{idx}.daspect{2})

end

function mouseclick(hObject, ~, handles)
% right mouse click switches view 2D / 3D
switch hObject.SelectionType
    case 'alt' % right mouse button
        if handles.fig.UserData.view == 2
            handles.fig.UserData.view = 3;
        elseif handles.fig.UserData.view == 3
            handles.fig.UserData.view = 2;
        end
    otherwise
        return
end
view(handles.ax_d,handles.fig.UserData.view)
view(handles.ax_e,handles.fig.UserData.view)
view(handles.ax_f,handles.fig.UserData.view)
end
