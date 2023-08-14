function success = loadFiles(obj,filename,pathname)
success = false;

% filters for images and videos
filter_img = {'*.jpg; *.JPG; *.jpeg; *.JPEG; *.bmp; *.BMP; *.png; *.PNG; *.tif; *.TIF; *.tiff, *.TIFF',...
                'Image Files (*.bmp,*.png,*.tif, etc.)'}; ...

% prompt user to select image(s) or video(s)
if nargin == 1
    [filename, pathname] = uigetfile(filter_img,'MultiSelect','on','Select a file / files',obj.workingFolder);
end

% handle case if user aborts
if isequal(filename,0)
    % abort
    return
else
    filename = filename(:);
end

% user mightve selected only one file
if ~iscell(filename)
    msgbox('\fontsize{12}At least two images are required for analysis. Try again.','fileSelector',...
        struct('Interpreter','tex','WindowStyle','modal'))
    return
end
[~,filename,fileext] = cellfun(@fileparts,filename,'Un',false);
fullfilename = strcat(pathname,filename,fileext);
len = length(fullfilename);

% process / load images
img = cell(len,1);
overExposed = cell(len,1);
for i = 1:length(fullfilename)
    current_img = imread(fullfilename{i});
    current_img = checkIMGSize(current_img);
    overExposed{i} = checkImage(current_img);
    if ndims(current_img) == 3
        if size(current_img,3) == 4
            % drop alpha channel
            current_img = current_img(:,:,1:3);
        end
        current_img = mean(current_img,3); % rgb2gray's weighted sum might not be applicable to beam measurement application, just take raw
    end
    current_img = double(current_img);
    % normalize img to 0-255
    current_img = current_img-min(current_img(:));
    img{i} = 255*(current_img/max(current_img(:)));
end

if ~all(cell2mat(cellfun(@(x) isequal(size(x),size(current_img)),img,'Un',false)))
    msgbox('\fontsize{12}Selected images must have the exact same size in X and Y dimension. Aborting.','fileSelector',...
        struct('Interpreter','tex','WindowStyle','modal'))
    return
end

% else everything goes according to plan..
success = true;
obj.h.table.Data = cell(len,3);
obj.filename = filename;
obj.workingFolder = pathname;
obj.zPos = parseZpos(filename,obj.spatial_scale); % obj.zPos = nan(len,1);
obj.useIMG = true(len,1);
obj.overExposed = overExposed;
obj.inpaintUndoIMGs = cell(len,1);
% careful: obj.images setter calls updateImage, so this must be last
obj.images = cat(3,img{:});

% report problems
if any(cellfun(@(x) (x.ContainsMaxVal == true),overExposed))
    warndlg({sprintf('\\fontsize{12}%i/%i Images contain pixels with brightness equal to the maximum value of its class.',...
            sum(double(cellfun(@(x) (x.ContainsMaxVal == true),overExposed))),len),...
        'These pixels will be highlighted in the following. It is advised to use the "gray" colormap for checking.','',...
        '{\bfVariant 1:}If these pixels are bright dead pixels on the edges of the image, the image should be cropped or discarded.',...
        '{\bfVariant 2:}If these pixels are inside the beam region, they should either be inpainted or the image discarded.',...
        '{\bfVariant 3:}If these pixels are multiple (!) pixels inside the beam center, the image is overexposed and must be discarded.','',...
        'Note that GrayLevel values here are normalized float32 in range 0-255. Don''t use these values as a measure to manually overrule the decision whether the image is overexposed or not!',...
        },'fileSelector',...
        struct('Interpreter','tex','WindowStyle','modal'))
end
end

function result = checkImage(img)
% future idea: give user opportunity to infill these pixels?!
result = struct('ContainsMaxVal',false,'x',[],'y',[],'idx',[]);
if isfloat(img)
    maxVal = realmax(class(img));
else
    maxVal = intmax(class(img));
end
result.idx = find(img == maxVal);
if any(result.idx)
    result.ContainsMaxVal = true;
    [result.y,result.x] = ind2sub(size(img), result.idx);
end
end

function img = checkIMGSize(img)
[szy,szx] = size(img,1:2);
% make sure obj.images is of even length in x/y
if ~bitget(szy,1)
    szy = szy-1;
end
if ~bitget(szx,1)
    szx = szx-1;
end
% save / update axis
img = img(1:szy,1:szx,:);
end

function zPos = parseZpos(filename,scale)
% attempts to parse z-pos from filename if convertible to valid numeric
% if valid, then assume filename-value is given in [m,mm,µm] as user
% provided

len = length(filename);
zPos = nan(len,1);
for i = 1:len
    % extract all numbers, minus sign, dots and commas
    currentZpos = regexp(filename{i},'[-,0-9,.,,]','match');
    % replace commas with dots
    currentZpos = strrep(char(cell2mat(currentZpos)),',','.');
    % attempt conversion to numeric
    currentZpos = str2num(currentZpos); %#ok<ST2NM>
    if isnumeric(currentZpos) && isfinite(currentZpos)
        zPos(i) = currentZpos/scale;
    end
end
end