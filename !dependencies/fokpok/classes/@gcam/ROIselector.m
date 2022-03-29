function abort = ROIselector(obj,etalonSpec)
% this is a wrapper for fokpokgui.ROIpreselector
abort = false;

% error checks
assert(isa(etalonSpec,'etalons'),'etalonSpec must be of class "etalons"');
assert(~isempty(etalonSpec.laserWavelength),'etalonSpec laserWavelength must be specified when calling ROIselector');

% check cam connection status
if ~obj.isconnected
    abort = true;
end

if obj.roiIsActive && ~abort
    % ask user
    abort = askUser();
end

if ~abort
    abort = askUser2(); % make user acknowlede aperture open, laser ON
end

if ~abort
    obj.grabFrame(); % makre sure frame is up2date
    if check4SoftwareRenderer()
        result = fokpokgui.ROIpreselector(obj.IMG,etalonSpec.xnum,etalonSpec.ynum,...
                                                  etalonSpec.flipX,etalonSpec.flipY);
    else    
        result = fokpokgui.ROIpreselector(obj,etalonSpec.xnum,etalonSpec.ynum,...
                                              etalonSpec.flipX,etalonSpec.flipY);
    end
    
    if result.abort == false
        obj.ROIspec = struct('xnum',etalonSpec.xnum,'ynum',etalonSpec.ynum);
        % linIDX
        obj.ROIs = result.rois;
        obj.OPDroi = (result.xIdxLookup*etalonSpec.OPDx) + (result.yIdxLookup*etalonSpec.OPDy);
        % sorted stuff
        [OPDroiSorted,sortedIDX] = sort(obj.OPDroi);
        OPDroiSorted = OPDroiSorted - 0.5*max(OPDroiSorted);
        obj.OPDroiSorted = OPDroiSorted;
        obj.ROIsSorted = result.rois(sortedIDX);
    elseif result.abort == true
        obj.ROIspec = struct('xnum',[],'ynum',[]);
        obj.ROIs = [];
        obj.OPDroi = [];
        obj.ROIsSorted = [];
        obj.OPDroiSorted = [];
    end
    abort = result.abort;
end

end

function abort = askUser()
abort = false;
answer = questdlg('\fontsize{12}ROIs already exist. If you continue, current ROIs will be cleared.',...
    'ROIpreselector','Continue','Abort',...
    struct('Interpreter','tex','Default','Continue'));
switch answer
    case {'Abort',''}
        abort = true;
    case 'Yes'
        abort = false;
end
end

function abort = askUser2()
abort = false;
if ~abort
    answer = questdlg('\fontsize{12}Aperture is open and Laser is on?',...
        'ROIpreselector','Yes, start now!',...
        struct('Interpreter','tex','Default','Yes, start now!'));
    switch answer
        case '' % abort [x] click
            abort = true;
    end
end
end

function flag = check4SoftwareRenderer()
h = figure('Name','CheckRenderer','WindowState','normal','NumberTitle','off','Position',[1,1,2,2]); 
ax = axes(h);
info = rendererinfo(ax); 
close(h);
flag = false;
if strcmpi(info.GraphicsRenderer,'OpenGL Software')
    flag = true;
    warning('Software Rendering is active.')
end
end
