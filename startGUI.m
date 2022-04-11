function fk = startGUI()
if ~isdeployed
    addpath(genpath(fileparts(mfilename('fullpath'))))
end
disp('Loading FokusPokus GUI...plase wait')
fk = fokpokgui.guiMain();
end