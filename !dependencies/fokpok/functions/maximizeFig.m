function maximizeFig(figh,screenNum)
% maximizes figure on monitor (second monitor if exist!)
MP = get(0, 'MonitorPositions');
if nargin == 2
    N = screenNum;
else
    N = size(MP, 1);
end
newPosition = MP(1,:);
if size(MP, 1) == 1
    % Single monitor -- do nothing.
else
    % Multiple monitors - shift to the Nth monitor.
    newPosition(1) = newPosition(1) + MP(N,1);
end
figh.set('Position', newPosition, 'units', 'normalized');
figh.WindowState = 'maximized'; % Maximize with respect to current monitor.
figh.Units = 'pixel';
end