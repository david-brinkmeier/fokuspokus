function obj = autoROI(obj)
% e.g. autoROI(imstack,[2,3,90],2,debug);
% gradient - deviation - energy
% sensitivity = [2,2,95]; % [grad,dev,energy] 0 to 100%

% nextsmallereven yields the next smaller even integer for a given input
% e.g. to answer "when a square rectangle is placed about the centroid, what is its maximum
% even length such that it does not exceed the image boundaries?"
nextsmallereven = @(n) 2*floor(n/2);

% parse inputs
img = obj.img.src;
len = size(img,3);
offset = obj.settings.ROI.offset;
sensitivity = obj.settings.ROI.sensitivity;

% lowpass filter image (if image is pre-filtered this has no effect beyond
% slightly enhancing fft artifacts
[img,~] = butterworth(img, 1, 15, 0, 0.55);

% output data structure
ROIs = cell(size(img,3),1);
ROIs(:) = {mask()};

% get an estimate for the centroid of the profile by extreme thresholdung
% (assumes there are no dead bright pixels left in the image)
cog_img = img;
for i = 1:len
    tmp = cog_img(:,:,i);
    tmp(tmp < .8*max(tmp(:))) = 0;
    cog_img(:,:,i) = tmp;
end

% now get centered first moments
moments = imMoments(cog_img,'cog',0);
xc = round(moments.xc,0); 
yc = round(moments.yc,0);

% remove DC using edges
logmask = mask.radial_logmask(size(img,1:2));

% generate settings for rmbackground
rmbsettings = struct('fitsamples',250,'fitvariant','eig','removeplane',true,'ndev',2,'debug',false);
for i = 1:len
    [img(:,:,i),~] = obj.rmbackground(img(:,:,i),logmask,rmbsettings);    
    if obj.settings.ImageProcessingToolbox
        img(:,:,i) = medfilt2(img(:,:,i),3*[1 1]);
    end
end

% preallocate rectangular logical mask
[ymax,xmax] = size(img,1:2);
[xx, yy] = meshgrid(1:xmax, 1:ymax);

% preallocate stuff for debugplot if required
if obj.settings.ROI.debug
    stitchedimg = @(img,obj,idx) [img(1:yc(idx),:,idx); obj.img.src(yc(idx)+1:end,:,idx)];
    data.stitchedimg = nan(size(img));
    data.rectpos = cell(1,len);
    data.bins = nan(1,len);
    data.len = len;
    data.energy = cell(1,len);
    data.dev = cell(1,len);
    data.imgrad = cell(1,len);
    data.limitcondstr = cell(1,len);
    data.offset = offset;
    data.xc = xc;
    data.yc = yc;
end

for i = 1:len
    condition = 0;
    % get current image
    current_img = img(:,:,i);
    eTot = sum(current_img(:));
    % determine maximum square rectangle length for current image
    maxlen = 2.*min([xmax-xc(i), ymax-yc(i),xc(i)-1, yc(i)-1]);
    % determine integration rectangle length stepping such each "ring"
    % rectangle has a width of one pixel
    vect = unique([0, nextsmallereven(linspace(2,maxlen,maxlen/2))]);
    
    % preallocate
    dev = nan(1,length(vect)-1);
    imintegral = nan(1,length(vect)-1);
    
    energy = nan(1,length(vect)-1);
    devgrad = nan(1,length(vect)-1);
    imgrad = nan(1,length(vect)-1);
    
    for j = 1:length(vect)-1
        outer = xx < xc(i)-vect(j+1)/2 | xx > xc(i)+vect(j+1)/2 | yy < yc(i)-vect(j+1)/2 | yy > yc(i)+vect(j+1)/2; % outer selection
        inner = xx < xc(i)-vect(j)/2 | xx > xc(i)+vect(j)/2 | yy < yc(i)-vect(j)/2 | yy > yc(i)+vect(j)/2; % inner selection
        rectmask = inner & ~outer;
        % get statistics
        energy(j) = sum(current_img(~outer))/eTot; % normalized total energy contained in between center and outer rectangle
        dev(j) = std(current_img(rectmask)); % std of masked values
        imintegral(j) = sum(current_img(rectmask))./sum(rectmask(:)); % normalized integral of masked values
        
        if (j > 1) && obj.settings.ROI.shortCircuit && (energy(j) > sensitivity(3)/100)
            % dont want repeated calls to external functions so this stuff
            % is just copy pasted
            devgrad(1:end-1) = abs(diff(dev-min(dev))); % smallest value should be 0
            devgrad = devgrad/max(devgrad); % normalize
            imgrad(1:end-1) = abs(diff(imintegral)); % dont care about negative values
            imgrad = imgrad/max(imgrad); % normalize
            cond1 = imgrad < sensitivity(1)/100;
            cond2 = devgrad < sensitivity(2)/100;
            cond3 = energy > sensitivity(3)/100;
            condition = cond1 & cond2 & cond3;
            if any(condition)
                break
            end
        end
    end
    
    if ~obj.settings.ROI.shortCircuit
        devgrad(1:end-1) = abs(diff(dev-min(dev))); % smallest value should be 0
        devgrad = devgrad/max(devgrad); % normalize
        imgrad(1:end-1) = abs(diff(imintegral)); % dont care about negative values
        imgrad = imgrad/max(imgrad); % normalize
        cond1 = imgrad < sensitivity(1)/100;
        cond2 = devgrad < sensitivity(2)/100;
        cond3 = energy > sensitivity(3)/100;
        condition = cond1 & cond2 & cond3;
    end
    
    % when autoROI was not succesful default to MAXLEN
    % else take first index where cond==true and offset idx unless this results in > length(vect)
    if any(condition)
        index_threshold = min([double(find(condition,1))+offset, length(vect)]);
    else
        index_threshold = length(vect);
    end
    % handle special conditions
    if (vect(index_threshold) == vect(1)) && (length(vect) > 1)
        index_threshold = index_threshold+1;
    end
    
    % get edge length
    edgelen = vect(index_threshold);
   
    % save roi/dask for current image
    ROIs{i}.refsz = img;
    ROIs{i}.selection = [xc(i)-edgelen/2, yc(i)-edgelen/2, edgelen, edgelen];
    
    % below is only for debugging / plot
    if obj.settings.ROI.debug
        data.stitchedimg(:,:,i) = stitchedimg(img,obj,i);
        data.index_threshold(i) = index_threshold;
        data.rectpos{i} = ROIs{i}.selection;
        data.bins(i) = length(vect)-1;
        data.energy{i} = energy;
        data.dev{i} = devgrad;
        data.imgrad{i} = imgrad;
        [~,cond_crit] = max([find(cond1,1),find(cond2,1),find(cond3,1)]);
        if isempty(cond_crit), cond_crit = 0; end
        switch cond_crit
            case 0
                data.limitcondstr{i} = 'fail - MAXSZ';
            case 1
                data.limitcondstr{i} = 'gradient';
            case 2
                data.limitcondstr{i} = 'deviation';
            case 3
                data.limitcondstr{i} = 'energy';
        end
    end
end

% save ROIs
obj.img.ROI = ROIs;
% preallocate denoised array based on mask requirements
obj.denoisedIMG = zeros(mask.getminarraysize(ROIs));

if obj.settings.ROI.debug
    debugplot(data,sensitivity)
end

% reset debug flag
obj.settings.ROI.debug = false;
end

function debugplot(data,sensitivity)
% start figure off with first image
idx = 1;

% gen Colormap, make sure first value is white
cmap = jet(255); cmap(1,:) = [1,1,1];

% gen handles struct
handles = struct();
handles.figstr = '[autoROI] Image';
handles.titlestr_a = 'decisive cond.:';

% gen and init fig
handles.fig = figure('name',sprintf('%s %i/%i',handles.figstr,idx,data.len),'color','w');
sgtitle(handles.fig,'Interactivity: Mouse wheel!')
handles.ax_a = subplot(1,2,1); box(handles.ax_a,'on')
handles.ax_b = subplot(1,2,2); box(handles.ax_b,'on')
axis(handles.ax_b,'image')
hold(handles.ax_a,'on'); hold(handles.ax_b,'on');
pbaspect(handles.ax_a,[1 1 1])
colormap(handles.fig,cmap)
xlabel(handles.ax_a,'bin / dist. from centroid'), ylabel(handles.ax_a,'value a.u.')
xlabel(handles.ax_b,'x [pixel]'), ylabel(handles.ax_b,'y [pixel]')

% make plot 1 (statistics), left
handles.imgrad = plot(handles.ax_a,data.imgrad{idx},'-k');
handles.dev = plot(handles.ax_a,data.dev{idx},'-r');
handles.energy = plot(handles.ax_a,data.energy{idx},'-b');
xlim(handles.ax_a,[1 data.bins(idx)])
ylim(handles.ax_a,[0 1])
handles.title_a = title(handles.ax_a,sprintf('%s %s',handles.titlestr_a,data.limitcondstr{idx}));
legend(handles.ax_a,{'gradient','deviation','energy'},'AutoUpdate','off','Location','best')

handles.index_threshold = xline(handles.ax_a,data.index_threshold(idx),'-m','Label','idx_{th}');
yline(handles.ax_a,sensitivity(1)/100,'--k','Label','imgrad < !')  % static
yline(handles.ax_a,sensitivity(2)/100,'--r','Label','dev < !')  % static
yline(handles.ax_a,sensitivity(3)/100,'--b','Label','energy > !') % static

% make plot 2 (image with roi rectangle)
xlim(handles.ax_b,[0 size(data.stitchedimg,2)+1])
ylim(handles.ax_b,[0 size(data.stitchedimg,1)+1])
title(handles.ax_b,{'top: source images','bottom: what autoROI sees',sprintf('offset: %i bins',data.offset)})
handles.imagesc = imagesc(handles.ax_b,data.stitchedimg(:,:,idx));
handles.centerx = xline(handles.ax_b,data.xc(idx),'-.r','LineWidth',2);
handles.centery = yline(handles.ax_b,data.yc(idx),'-.r','LineWidth',2);
handles.rectangle = rectangle(handles.ax_b,'Position', data.rectpos{idx},...
                                            'EdgeColor', 'r', 'FaceColor', 'none', 'LineWidth', 2);                                     

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
handles.index_threshold.Value = data.index_threshold(idx);
handles.imgrad.YData = data.imgrad{idx};
handles.dev.YData = data.dev{idx};
handles.energy.YData = data.energy{idx};
xlim(handles.ax_a,[1 data.bins(idx)])
handles.title_a.String = sprintf('%s %s',handles.titlestr_a,data.limitcondstr{idx});

% update subplot 2
% plot circular region of logmask
handles.centerx.Value = data.xc(idx);
handles.centery.Value = data.yc(idx);
handles.rectangle.Position = data.rectpos{idx};
handles.imagesc.CData = data.stitchedimg(:,:,idx);

end