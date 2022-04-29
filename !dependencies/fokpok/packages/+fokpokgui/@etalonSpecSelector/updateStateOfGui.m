function updateStateOfGui(obj)
% checkboxes
obj.h.chkBox.flipX.Value = obj.flipX;
obj.h.chkBox.flipY.Value = obj.flipY;

% txt boxes
obj.h.txt.wavelength.String = obj.wavelength*1e9;

% edit boxes
obj.h.edit.wedgeAngle.String = obj.wedgeAngle;
obj.h.edit.dX.String = obj.dX*1e3;
obj.h.edit.dY.String = obj.dY*1e3;
obj.h.edit.xnum.String = obj.xnum;
obj.h.edit.ynum.String = obj.ynum;
end