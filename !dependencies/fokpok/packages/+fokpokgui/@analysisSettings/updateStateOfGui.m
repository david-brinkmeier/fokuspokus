function updateStateOfGui(obj)
% checkboxes
obj.h.chkBox.denoise.debug.Value = obj.settings.denoise.debug;
obj.h.chkBox.roi.debug.Value = obj.settings.ROI.debug;
obj.h.chkBox.center.debug.Value = obj.settings.center.debug;
obj.h.chkBox.moments.debug.Value = obj.settings.moments.debug;

if (obj.settings.denoise.debug && obj.settings.ROI.debug...
        && obj.settings.center.debug && obj.settings.moments.debug)
    obj.h.chkBox.denoise.debugALL.Value = 1;
else
    obj.h.chkBox.denoise.debugALL.Value = 0;
end

obj.h.chkBox.denoise.freqfilt.Value = obj.settings.denoise.freqfilt;
obj.h.chkBox.denoise.removeplane.Value = obj.settings.denoise.removeplane;
obj.h.chkBox.roi.guiROI.Value = obj.settings.ROI.guiROI;
obj.h.chkBox.roi.autoROI.Value = obj.settings.ROI.autoROI;
obj.h.chkBox.roi.shortCircuit.Value = obj.settings.ROI.shortCircuit;
obj.h.chkBox.fit.weighted.Value = obj.settings.fit.weighted;
obj.h.chkBox.fit.weightedVariance.Value = obj.settings.fit.weightedVariance;
obj.h.chkBox.fit.fixEdgeCase.Value = obj.settings.fit.fixEdgeCase;

% popupmenus
obj.h.popup.denoise.fitvariant.Value = find(ismember(obj.h.popup.denoise.fitvariant.String,obj.settings.denoise.fitvariant));
obj.h.popup.denoise.ndev.Value = find(str2double(obj.h.popup.denoise.ndev.String) == obj.settings.denoise.ndev);
obj.h.popup.denoise.median.Value = find(str2double(obj.h.popup.denoise.median.String) == obj.settings.denoise.median);

% edit boxes
obj.h.edit.denoise.fitsamples.String = obj.settings.denoise.fitsamples;
obj.h.edit.roi.sensitivity_1.String = obj.settings.ROI.sensitivity(1);
obj.h.edit.roi.sensitivity_2.String = obj.settings.ROI.sensitivity(2);
obj.h.edit.roi.sensitivity_3.String = obj.settings.ROI.sensitivity(3);
obj.h.edit.roi.offset.String = obj.settings.ROI.offset;
obj.h.edit.roi.updateEveryNframes.String = obj.settings.ROI.updateEveryNframes;
end