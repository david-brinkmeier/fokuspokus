function val = calcExposureResult(obj,extracted)
% returns the optimization criteria for exposure setting
% when calling this ideally cam.Average_Value is in range [240,400]
% and the return value should be well below maximum pixel brightness
% (grayLevelLims(2)!)

if nargin == 1 || ~isnumeric(extracted)
    obj.grabFrame(); % important: update frame
    if (obj.roiIsActive == true) && (obj.hotpixelDetected == true)
        % extract pixels in ROI which are also not Hotpixels
        extracted = obj.IMG(obj.logmask & obj.validpixels);
    elseif (obj.roiIsActive == true) && (obj.hotpixelDetected == false)
        % extract pixels in ROI
        extracted = obj.IMG(obj.logmask);
    elseif (obj.roiIsActive == false) && (obj.hotpixelDetected == true)
        % extract pixels which are not Hotpixels
        extracted = obj.IMG(obj.validpixels);
    else
        % just take the image
        extracted = obj.IMG;
    end
end
sorted = sort(extracted(:),'descend');
% assume mean of top 30 values is optimization objective
val = mean(sorted(1:30));
end