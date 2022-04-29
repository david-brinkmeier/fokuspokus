function initfig(obj)
% initializes gui
h = struct();
h.chkBox = struct(); % uicontrol uistyle checkbox
h.pb = struct(); % uicontrol pushbutton
h.edit = struct(); % uicontrol uistyle edit

% init fig
h.fig = figure( ...
    'Color','white',...
    'Name', 'fokpokgui.etalonSpecSelector', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'Toolbar', 'none', ...
    'HandleVisibility', 'off',...
    'Resize',0,...
    'WindowStyle','modal');

figWidth = 240;
figHeight = 344;
h.fig.Position = [get(0,'PointerLocation')-[figWidth/2,figHeight],figWidth,figHeight];

if h.fig.Position(1) < 0
    h.fig.Position(1) = 1;
end
if h.fig.Position(2) < 0
    h.fig.Position(2) = 1;
end

% Arrange the main interface
h.mainLayout = uix.VBox('Parent', h.fig, 'Padding', 0, 'Spacing', 0);
% load defaults panel
h.panel.main = uix.BoxPanel('Parent', h.mainLayout,'Title','load.defaults','Padding',5,'FontSize',10);
% etalonspec panel
h.panel.spec = uix.BoxPanel('Parent', h.mainLayout,'Title','etalon.spec','Padding',5,'FontSize',10);
% save exit panel
h.panel.saveexit = uix.BoxPanel('Parent',h.mainLayout,'Title','save.exit','Padding',5,'FontSize',10);

% populate load defaults panel
mainHbox = uix.HBox('Parent', h.panel.main, 'Padding', 0, 'Spacing', 5);
h.pb.defaultMsquaredLo = uicontrol('Parent',mainHbox,'Style','pushbutton','String','Defaults M² = 1','FontSize',10,'FontWeight','normal');
h.pb.defaultMsquaredHi = uicontrol('Parent',mainHbox,'Style','pushbutton','String','Defaults M² >> 1','FontSize',10,'FontWeight','normal');

% populate spec panel
specVbox = uix.VBox('Parent', h.panel.spec, 'Padding', 0, 'Spacing', 5);
% // Laser Wavelength edit box
HboxTmp = uix.HBox('Parent',specVbox,'Padding',0,'Spacing',0);
VboxTmp1 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp1); % whitespace left, auto resize this
uicontrol('Parent',VboxTmp1,'Style','text','String','wavelength [nm]:','HorizontalAlignment','left','FontSize',10);
VboxTmp1.Heights = [2,20];
VboxTmp2 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp2); % whitespace left, auto resize this
h.txt.wavelength = uicontrol('Parent',VboxTmp2,'Style','text','FontSize',10);
VboxTmp2.Heights = [1,20];
% // xnum edit box
HboxTmp = uix.HBox('Parent',specVbox,'Padding',0,'Spacing',0);
VboxTmp1 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp1); % whitespace left, auto resize this
uicontrol('Parent',VboxTmp1,'Style','text','String','xnum:','HorizontalAlignment','left','FontSize',10);
VboxTmp1.Heights = [2,20];
VboxTmp2 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp2); % whitespace left, auto resize this
h.edit.xnum = uicontrol('Parent',VboxTmp2,'Style','edit','FontSize',10);
VboxTmp2.Heights = [1,20];
% // ynum edit box
HboxTmp = uix.HBox('Parent',specVbox,'Padding',0,'Spacing',0);
VboxTmp1 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp1); % whitespace left, auto resize this
uicontrol('Parent',VboxTmp1,'Style','text','String','ynum:','HorizontalAlignment','left','FontSize',10);
VboxTmp1.Heights = [2,20];
VboxTmp2 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp2); % whitespace left, auto resize this
h.edit.ynum = uicontrol('Parent',VboxTmp2,'Style','edit','FontSize',10);
VboxTmp2.Heights = [1,20];
% // dX edit box
HboxTmp = uix.HBox('Parent',specVbox,'Padding',0,'Spacing',0);
VboxTmp1 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp1); % whitespace left, auto resize this
uicontrol('Parent',VboxTmp1,'Style','text','String','dX [mm]:','HorizontalAlignment','left','FontSize',10);
VboxTmp1.Heights = [2,20];
VboxTmp2 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp2); % whitespace left, auto resize this
h.edit.dX = uicontrol('Parent',VboxTmp2,'Style','edit','FontSize',10);
VboxTmp2.Heights = [1,20];
% // dY edit box
HboxTmp = uix.HBox('Parent',specVbox,'Padding',0,'Spacing',0);
VboxTmp1 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp1); % whitespace left, auto resize this
uicontrol('Parent',VboxTmp1,'Style','text','String','dY [mm]:','HorizontalAlignment','left','FontSize',10);
VboxTmp1.Heights = [2,20];
VboxTmp2 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp2); % whitespace left, auto resize this
h.edit.dY = uicontrol('Parent',VboxTmp2,'Style','edit','FontSize',10);
VboxTmp2.Heights = [1,20];
% // wedgeAngle edit box
HboxTmp = uix.HBox('Parent',specVbox,'Padding',0,'Spacing',0);
VboxTmp1 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp1); % whitespace left, auto resize this
uicontrol('Parent',VboxTmp1,'Style','text','String','wedge angle [°]:','HorizontalAlignment','left','FontSize',10);
VboxTmp1.Heights = [2,20];
VboxTmp2 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp2); % whitespace left, auto resize this
h.edit.wedgeAngle = uicontrol('Parent',VboxTmp2,'Style','edit','FontSize',10);
VboxTmp2.Heights = [1,20];
% // flip X/Y chkbox
HboxTmp = uix.HBox('Parent',specVbox,'Padding',0,'Spacing',0);
h.chkBox.flipX = uicontrol('Parent',HboxTmp,'Style','checkbox','String','flip X','FontSize',10);
h.chkBox.flipY = uicontrol('Parent',HboxTmp,'Style','checkbox','String','flip Y','FontSize',10);

% populate saveexit
h.pb.saveexit = uicontrol('Parent',h.panel.saveexit,'Style','pushbutton','String','Save / Exit','FontSize',10,'FontWeight','normal');

% set heights
h.mainLayout.Heights = [62,220,62];

obj.h = h;
end