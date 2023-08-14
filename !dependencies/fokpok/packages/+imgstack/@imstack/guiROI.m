function obj = guiROI(obj)
% parse inputs / get img sz
img = obj.img.src;
[ylimit_ref,xlimit_ref] = size(img,1:2);

% setup fig
fig = figure('name','FastCrop','color','w');
set(fig, 'Position', get(0, 'Screensize'));
set(fig, 'MenuBar', 'none');
ax = axes(fig);

% draw first image
handles.image = imagesc(ax,img(:,:,1));
colormap(ax,'jet'), axis(ax,'image'), hold(ax,'on')
title(ax,{sprintf('Image %i/%i',1,size(img,3)),'User Interface: ROI (Left,Right,Wheel), Next/Last (Enter,Backspace), Zoom in/out (PgUp/PgDown), Escape (abort)'},'FontSize',18)
xlabel('Pixel','FontSize',16), ylabel('Pixel','FontSize',16)
ax.FontSize = 16;

% handle to compute clims
getclims = @(img,idx,xstart,xend,ystart,yend) [min(img(ystart:yend,xstart:xend,idx),[],'all'), max(img(ystart:yend,xstart:xend,idx),[],'all')];
caxis(ax,getclims(img,1,1,xlimit_ref,1,ylimit_ref))
colorbar(ax,'FontSize',16);

% Set up crosshairs on each axis at the edges
handles.crosshair(1,1) = xline(ax(1),mean(xlim(ax)), 'w-.', 'LineWidth', 2, 'FontSize', 14);
handles.crosshair(1,2) = yline(ax(1),mean(ylim(ax)), 'w-.', 'LineWidth', 2, 'FontSize', 14);
xlim(ax,[1 xlimit_ref]); ylim(ax,[1 ylimit_ref])
xlim(ax,'manual'); ylim(ax,'manual');

% setup selection rectangle
edgelen = min(size(img,1:2))/1.5;
xstart = mean(xlim(ax))-edgelen/2;
ystart = mean(ylim(ax))-edgelen/2;
scrollmultiplier = max(size(img))/50;
handles.selection = rectangle(ax,'Position', [xstart, ystart, edgelen, edgelen], 'EdgeColor', 'w', 'FaceColor', 'none', 'LineWidth', 2);

% some required internal variables
ax.UserData.interactive = true; % true for centroid selection active
ax.UserData.index = 1; % true for centroid selection active
ax.UserData.lastindex = size(img,3); % true for centroid selection active
ax.UserData.scrollmultiplier = scrollmultiplier; % rectangle stepping

% output data structure
ROIs = cell(size(img,3),1);
ROIs(:) = {mask()};
done = false;
abort = false;

% Assign windowbuttonmotion fcn on axis #1
set(fig,'windowbuttonmotionfcn', {@mouseMove, ax, handles}); % disable for default off
% Assign mouse button functions to start/stop tracking
set(fig,'windowbuttondownfcn', {@startStopMouseMove, {@mouseMove, ax, handles}})
% mouse wheel; resize selection rectangle
set(fig, 'WindowScrollWheelFcn', {@wheel, ax, handles});
% setup keypress callback
set(fig, 'KeyPressFcn', @keypressed);
% setup close request
set(fig,'CloseRequestFcn',@closeRequest);

    function keypressed(hObject,event)
        % acts upon button presses enter and backspace
        done = false;
        switch event.Key
            case 'return'
                adjusted = adjustrectangle(ax,handles.crosshair,handles.selection);
                if ~adjusted
                    % save data for current image
                    ROIs{ax.UserData.index}.refsz = img;
                    ROIs{ax.UserData.index}.selection = handles.selection.Position;
                    
                    % advance index
                    ax.UserData.index = ax.UserData.index+1;
                    if ax.UserData.index > ax.UserData.lastindex
                        % finished, close
                        done = true;
                        % save
                        obj.img.ROI = ROIs;
                        % preallocate denoised array based on mask requirements
                        obj.denoisedIMG = zeros(mask.getminarraysize(ROIs));
                        % disable GUI ROI
                        obj.settings.ROI.guiROI = false;
                        % now close
                        closeRequest(hObject,event)
                    end
                end
            case 'backspace'
                ax.UserData.index = ax.UserData.index-1;
                if ax.UserData.index < 1
                    ax.UserData.index = 1;
                end
                
            case 'pagedown'
                % reset limits
                ax.XLim = [1 xlimit_ref];
                ax.YLim = [1 ylimit_ref];
            
            case 'pageup'
                adjustrectangle(ax,handles.crosshair,handles.selection);
                pos = handles.selection.Position;
                % zoom in on rectangle / set limits
                ax.XLim = [floor(pos(1)) ceil(pos(1)+pos(3))]+[-3,3];
                ax.YLim = [floor(pos(2)) ceil(pos(2)+pos(4))]+[-3,3];
                
            case 'escape'
                abort = true;
                closeRequest(hObject,event)
        end
        % draw current image
        if ~done && ~abort
            handles.image.CData = img(:,:,ax.UserData.index);
            ax.Title.String{1} = sprintf('Image %i/%i',ax.UserData.index,ax.UserData.lastindex);
            % set stuff based on current limits
            ax.UserData.scrollmultiplier = max([ax.XLim(2)-ax.XLim(1), ax.YLim(2)-ax.YLim(1)])/50;
            caxis(ax,getclims(img,ax.UserData.index,ax.XLim(1),ax.XLim(2),ax.YLim(1),ax.YLim(2)))
        end
    end

    function closeRequest(hObject,event)
        if abort
            warndlg('\fontsize{12}Disabling guiROI because process was aborted. Enable guiROI again if you want user specified ROIs!',...
                'imstack.guiROI',struct('Interpreter','tex','WindowStyle','modal'))
        end
        obj.settings.ROI.guiROI = false;
        delete(hObject);
        if ~done
            obj.img.ROI = []; % user must crop all images or nothing
            obj.axis.denoised = obj.axis.src;
        end
        if obj.settings.ROI.debug && done
            obj.settings.ROI.debug = false; % reset
            mask.debugplot(ROIs,img);          
        end
    end

% important, need to wait
uiwait(fig);
end

function startStopMouseMove(hObject,event,input)
% note: input is actually a cell array of {@mouseMove, ax, handles}
% enable/disable mouse tracking upon mouseclick
% when disabled the callback is simply removed
buttonID = hObject.SelectionType;
switch buttonID
    case 'normal' %left mouse button
        % Start interactivity
        if ~isempty(get(hObject,'windowbuttonmotionfcn'))
            set(hObject,'windowbuttonmotionfcn', []);
            % provide axis and rectangle to adjustrectangle function
            % this ensures that boundary outside image cannot occur
            % adjustrectangle(ax,crosshair,selection)
            adjustrectangle(input{2},input{3}.crosshair,input{3}.selection);
        else
            set(hObject,'windowbuttonmotionfcn', input);
        end
    case 'alt' % right mouse button
        % invert ax.UserData.interactive
        input{2}.UserData.interactive = ~input{2}.UserData.interactive;
end
end

function adjusted = adjustrectangle(ax,crosshair,selection)
% this function limits selection rectangle to within the image
adjusted = false;

safezone = 3; % leave px on either side
xCenter = crosshair(1,1).Value;
yCenter = crosshair(1,2).Value;
xlims = ax.XLim + [safezone -safezone];
ylims = ax.YLim + [safezone -safezone];

edgelen_x = selection.Position(3);
edgelen_y = selection.Position(4);
edgelen_x_max = min(abs([(xlims(1)-xCenter)*2,(xlims(2)-xCenter)*2]));
edgelen_y_max = min(abs([(ylims(1)-yCenter)*2,(ylims(2)-yCenter)*2]));

if edgelen_x > edgelen_x_max
    adjusted = true;
    edgelen_x = edgelen_x_max;
end
if edgelen_y > edgelen_y_max
    adjusted = true;
    edgelen_y = edgelen_y_max;
end

% update selection
xstart = xCenter-edgelen_x/2;
ystart = yCenter-edgelen_y/2;
selection.Position = [xstart,ystart,edgelen_x,edgelen_y];

end

function wheel(hObject, event, ax, handles)
% get current scrollmultiplier
scrollmultiplier = ax.UserData.scrollmultiplier;

% Get crosshair coordinates
xCenter = handles.crosshair(1,1).Value;
yCenter = handles.crosshair(1,2).Value;

% get current endge length of selection
edgelen_old_x = handles.selection.Position(3);
edgelen_old_y = handles.selection.Position(4);

% modify edge length based on scroll wheel
if event.VerticalScrollCount > 0
    edgelen_x = edgelen_old_x+1*scrollmultiplier;
    edgelen_y = edgelen_old_y+1*scrollmultiplier;
elseif event.VerticalScrollCount < 0
    edgelen_x = edgelen_old_x-1*scrollmultiplier;
    edgelen_y = edgelen_old_y-1*scrollmultiplier;
end

if edgelen_x < 2*scrollmultiplier
    edgelen_x = 2*scrollmultiplier;
end
if edgelen_y < 2*scrollmultiplier
    edgelen_y = 2*scrollmultiplier;
end

% if right mouse click then only change y direction
if ~ax.UserData.interactive
    edgelen_x = edgelen_old_x;
end

% update selection
xstart = xCenter-edgelen_x/2;
ystart = yCenter-edgelen_y/2;
handles.selection.Position = [xstart,ystart,edgelen_x,edgelen_y];

% limit rectangle
% adjustrectangle(ax,handles.crosshair,handles.selection)

end

function mouseMove(hObject,event,ax,handles)
% Responds to mouse movement in axis #1
% Get mouse coordinate
[x,y] = getcoordinates(ax,true);

% If mouse isn't on axis #1, do nothing.
if x < ax.XLim(1) || x > ax.XLim(2) || y < ax.YLim(1) || y > ax.YLim(2)
    return
end
% Update crosshairs (cross hairs in ax 2 are yoked).
handles.crosshair(1,1).Value = x;
handles.crosshair(1,1).Label = x;
handles.crosshair(1,2).Value = y;
handles.crosshair(1,2).Label = y;

% update selection
edgelen_x = handles.selection.Position(3);
edgelen_y = handles.selection.Position(4);
xLeft = x-edgelen_x/2;
yBottom = y-edgelen_y/2;
handles.selection.Position = [xLeft,yBottom,edgelen_x,edgelen_y];

end

function [x,y] = getcoordinates(ax,integer)
% returns x y coordinates
C = ax.CurrentPoint;
if integer == true
    C = round(C,0);
end
x = C(1,1);
y = C(1,2);
end