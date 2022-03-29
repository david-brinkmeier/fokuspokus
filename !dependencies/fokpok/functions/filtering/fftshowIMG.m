function data = fftshowIMG(img,pixelpitch,choice,makeplot,flipy)
% Copyright (c) 2022 David Brinkmeier
% davidbrinkmeier@gmail.com
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
% The Software is provided "as is", without warranty of any kind.
%%
% this function processes a 2D/3D image (imagestack)
% plot is interactive with 3D image stacks (scrollable)
% additional input arguments beyond fftshowIMG(img) are optional (see below)
%
% Inputs
% IMG:              2D or 3D image stack
% pixelpitch        in SI Units
% makeplot          bool
% flipy             reverses y direction in plot (as is convention when working with images vs. arrays)
% choice            switches between a.u. / normalized and real units
%
% choice "auto": axes are generated as best guess within
% the range of [Hz,kHz,MHz] for frequencies and [m,mm,µm] for spatial coordinates
%
%% Example: Possible calls
%
% fftshowIMG(img);                              % assumes Unit grid
% out = fftshowIMG(img);                        % export data (explained below)
% fftshowIMG(img,pixelpitch,'auto');            % provide pixelpitch in SI units, spatial/frequency in plot 
                                                % will be [Hz,kHz,MHz] / [m,mm,µm]
% out = fftshowIMG(img,pixelpitch,'auto',0);    % as above, but plot disabled
% fftshowIMG(img,pixelpitch,'auto',1,1);    	% y-axis in plot is flipped (use this with images)

%% EXAMPLE
%
% pixelpitch = 1e-3; % for example 1 mm
% pixel = 256;
% period = (0:2:256)/pixelpitch;
% 
% range = (-pixel/2:1:pixel/2-1)*pixelpitch;
% [xx,yy] = meshgrid(range);
% img1 = zeros([size(xx),length(period)]); % init
% img2 = img1; % init
% for i = 1:size(img1,3)
%     img1(:,:,i) = 4*sin(2*pi/pixel*period(i)*xx) + 2*sin(2*pi/pixel*period(i)*yy) +.3.*randn(size(xx)) + 3; % hor-ver
%     img2(:,:,i) = 4*sin(2*pi/pixel*period(i)*sqrt(xx.^2+yy.^2)) +.3.*randn(size(xx)) + 3; % radial
% end
% out = fftshowIMG(img1,pixelpitch,'auto'); % use real units
% fftshowIMG(img2,pixelpitch,'auto'); % use real units; fftshowIMG(img1);
%
%% data / output
%
% src_img             % source image
% pixelpitch          % pixelpitch
% fsample             % sampling frequency in Hz
% ax.fx / ax.fy       % frequency axes in Hz corresponding to fftimg_abs/normalized
% ax.sx / ax.sy       % spatial axes in pixelpitch units assuming image center = zero
% fftimg_abs          % fft2(src_img)
% fftimg_normalized   % normalized fft2 of img for visualization

%% START
% init output
data = struct();
data.src_img = img;

% error checks
if ~(isnumeric(img) && (ndims(img) <= 3) && ~isvector(img))
    error('img must be numeric 2D or 3D array');
end
% can't have NaN or inf
if any(~isfinite(img),"all")
    warning('Image cannot have NaN or inf. Setting to 0 for FFT. Plot may be affected.')
    img(~isfinite(img)) = 0;
end

% input checks / dont want to bother with varargin
if nargin <= 4, flipy = false; end
if nargin <= 3, makeplot = 1; end
if nargin <= 2, choice = 'normalized'; end
switch lower(choice)
    case 'auto'
        auto = true;
    case 'normalized'
        auto = false;
        pixelpitch = 1; % unit grid
    otherwise
    warning('choice "%s" unknown, must be "auto" or "normalized"!',choice);
    fprintf('defaulting to "normalized".\n');
    auto = false; 
    pixelpitch = 1;
end

% get img spec
[szy,szx,len] = size(img,1:3);
% sampling frequency
data.pixelpitch = pixelpitch;
data.fsample = 1/data.pixelpitch;
% frequency axis; max freqs. are +/- fs/2
data.ax.fx = data.fsample*(((1:szx)-(fix(szx/2)+1))/szx); % fft max is +/- fs/2
data.ax.fy = data.fsample*(((1:szy)-(fix(szy/2)+1))/szy); % fft max is +/- fs/2
% spatial axis
data.ax.sx = data.pixelpitch*(((1:szx)-(fix(szx/2)+1))); % assume center = middle not first index
data.ax.sy = data.pixelpitch*(((1:szy)-(fix(szy/2)+1))); % assume center = middle not first index

if auto
    knownfreq = [1e9,1e6,1e3]; % when larger than GHz, MHz, kHz, then scale, else use Hz
    knownfreq_label = {'GHz','MHz','kHz'};
    knownspatial = [1e-6,1e-3,1]; % when larger than µm / mm / m, then scale, else use m
    knownspatial_label = {'µm','mm','m'};
    % frequency axis multiplier...
    idx = find((data.fsample/2 > knownfreq),1,'first');
    if ~isempty(idx)
        frequency_mult = 1/knownfreq(idx);
        units.frequency = knownfreq_label{idx};
    else
        frequency_mult = 1;
        units.frequency = 'Hz';
    end
    % spatial axis multiplier...
    idx = find(max([data.ax.sx,data.ax.sy]) > knownspatial,1,'last');
    if ~isempty(idx)
        spatial_mult = 1/knownspatial(idx);
        units.spatial = knownspatial_label{idx};
    else
        spatial_mult = 1;
        units.spatial = 'm';
    end
else
    frequency_mult = 1;
    spatial_mult = 1;
    units.frequency = '1/f_{sample}';
    units.spatial = 'a.u.';
end

%% get frequencies
data.fftimg_abs = abs(fftshift(fft2(img)));
data.ffimg_normalized = zeros(size(img));

for i = 1:len
    current_img = img(:,:,i);
    fft_img = fftshift(fft2(current_img/max(current_img(:))));
    fft_img = log(1+abs(fft_img));
    fft_img = fft_img./max(fft_img(:));
    data.ffimg_normalized(:,:,i) = fft_img;
end

%% plot (optional)
if makeplot
    % store figstuff in struct
    handles = struct();
    % need some extra data in data struct for callbacks
    handles.figstr = 'Input image vs. frequency spectrum, Image: ';
    handles.len = len;
    idx = 1;
    
    % gen and init fig
    handles.fig = figure('name',sprintf('%s %i/%i',handles.figstr,1,handles.len),'color','w');
    handles.fig.Position(3) = handles.fig.Position(3)*1.5; 
    % handles.fig.WindowState = 'maximized';
    handles.ax = axes(handles.fig);
    if handles.len > 1, sgtitle(handles.fig,'Interactivity: Mouse wheel / Right mouse button!'), end
    handles.ax_a = subplot(1,2,1); box(handles.ax_a,'on')
    handles.ax_b = subplot(1,2,2); box(handles.ax_b,'on')
    hold(handles.ax_a,'on'); hold(handles.ax_b,'on');
    colormap(handles.ax_a,'jet')
    colormap(handles.ax_b,'gray')
    if flipy
       set(handles.ax_a,'YDir','reverse')
       set(handles.ax_b,'YDir','reverse')
    end
    
    % make input plot (left)
    handles.img_a = surf(handles.ax_a,data.ax.sx*spatial_mult,data.ax.sy*spatial_mult,data.src_img(:,:,idx));
    axis(handles.ax_a,'image')
    dz = max(abs(data.src_img(:,:,idx)),[],'all')-min(abs(data.src_img(:,:,idx)),[],'all');
    daspect(handles.ax_a,[1 1 3*dz/(spatial_mult*data.pixelpitch*max(size(data.src_img,1:2)))])
    shading(handles.ax_a,'flat')
    xlabel(handles.ax_a,sprintf('distance in %s',units.spatial));
    ylabel(handles.ax_a,sprintf('distance in %s',units.spatial));
    zlabel(handles.ax_a,'z')
    title(handles.ax_a,'Input')
    xlim(handles.ax_a,[min(data.ax.sx*spatial_mult),max(data.ax.sx*spatial_mult)])
    ylim(handles.ax_a,[min(data.ax.sy*spatial_mult),max(data.ax.sy*spatial_mult)])
    
    % make frequency spectrum plot (right)
    handles.img_b = surf(handles.ax_b,data.ax.fx*frequency_mult,data.ax.fy*frequency_mult,data.ffimg_normalized(:,:,idx));
    axis(handles.ax_b,'image')
    daspect(handles.ax_b,[1 1 3*data.pixelpitch/frequency_mult])
    shading(handles.ax_b,'flat')
    xlabel(handles.ax_b,sprintf('frequency in %s',units.frequency));
    ylabel(handles.ax_b,sprintf('frequency in %s',units.frequency));
    zlabel(handles.ax_b,'normalized amplitude')
    title(handles.ax_b,'normalized frequency')
    xlim(handles.ax_b,[min(data.ax.fx*frequency_mult),max(data.ax.fx*frequency_mult)])
    ylim(handles.ax_b,[min(data.ax.fy*frequency_mult),max(data.ax.fy*frequency_mult)])
    zlim(handles.ax_b,[0 1])
    
    % save data in fig which must be accessible and updated upon callback
    handles.fig.UserData.index = idx;
    handles.fig.UserData.view = 2;
    
    % assign mouse wheel and mouse button callbacks to fig
    set(handles.fig, 'WindowScrollWheelFcn', {@wheel, handles, data, spatial_mult});
    set(handles.fig, 'windowbuttondownfcn', {@mouseclick, handles});
end

end

function wheel(~, eventdata, handles, data, spatial_mult)
% get current index
idx = handles.fig.UserData.index;
% advance by scrollwheel
idx = idx + eventdata.VerticalScrollCount;
% constraints
if idx > handles.len
    idx = handles.len;
end
if idx < 1
    idx = 1;
end
% save new index
handles.fig.UserData.index = idx;

% update figname / title
handles.fig.Name = sprintf('%s %i/%i',handles.figstr,idx,handles.len);
% update plot / data
handles.img_a.ZData = data.src_img(:,:,idx);
handles.img_b.ZData = data.ffimg_normalized(:,:,idx);
dz = max(abs(data.src_img(:,:,idx)),[],'all')-min(abs(data.src_img(:,:,idx)),[],'all');
daspect(handles.ax_a,[1 1 3*dz/(spatial_mult*data.pixelpitch*max(size(data.src_img,1:2)))])
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
view(handles.ax_a,handles.fig.UserData.view)
view(handles.ax_b,handles.fig.UserData.view)
end