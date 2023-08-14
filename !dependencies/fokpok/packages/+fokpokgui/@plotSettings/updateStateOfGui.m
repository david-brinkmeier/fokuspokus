function updateStateOfGui(obj)
% read values into gui from parent class
% main panel
obj.h.chkBox.enable.Value = obj.settings.enable;
obj.h.chkBox.timeStamp.Value = obj.settings.timeStamp;
obj.h.edit.updateEveryNframe.String = obj.settings.updateEveryNframes;
obj.h.edit.exportEveryNframe.String = obj.settings.exportEveryNframes;

% data panel xy z angle
obj.h.popup.scaleXY.Value = find(obj.settings.scale(1) == obj.scale_val);
obj.h.popup.scaleZ.Value = find(obj.settings.scale(2) == obj.scale_val);
obj.h.popup.scaleAngle.Value = find(obj.settings.scale(3) == obj.scale_val);

% design panel
obj.h.popup.colormap.Value = find(ismember(obj.h.popup.colormap.String,obj.settings.colormap));
obj.h.popup.data_aspect.Value = find(ismember(obj.h.popup.data_aspect.String,obj.settings.data_aspect));
obj.h.popup.limitsType.Value = find(ismember(obj.h.popup.limitsType.String,obj.settings.limitsType));
obj.h.chkBox.transparency.Value = obj.settings.transparency;

% export panel
obj.h.chkBox.fig.Value = obj.settings.exportFig;
obj.h.chkBox.png.Value = obj.settings.exportPNG;
obj.h.popup.dpi.Value = find(ismember(str2double(obj.h.popup.dpi.String),obj.settings.dpi));
end