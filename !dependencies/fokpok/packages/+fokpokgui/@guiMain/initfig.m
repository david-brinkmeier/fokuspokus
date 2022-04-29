function initfig(obj)
% initializes gui
h = struct();
h.chkBox = struct(); % uicontrol uistyle checkbox
h.pb = struct(); % uicontrol pushbutton
h.edit = struct(); % uicontrol uistyle edit
h.popup = struct(); % uicontrol uistyle popupmenu

% init fig
h.fig = figure( ...
    'Color','white',...
    'Name', 'fokpokgui.guiMain', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'Toolbar', 'none', ...
    'HandleVisibility', 'off',...
    'Resize',0);

figWidth = 260;
figHeight = 565;
screenpos = get(0,'screensize')/2;
h.fig.Position = [screenpos(3)-figHeight/2,screenpos(4)-figHeight/2,figWidth,figHeight];

if h.fig.Position(1) < 0
    h.fig.Position(1) = 1;
end
if h.fig.Position(2) < 0
    h.fig.Position(2) = 1;
end

% Arrange the main interface
h.mainLayout = uix.VBox('Parent', h.fig, 'Padding', 0, 'Spacing', 0);
% input panel
h.panel.inputMain = uix.BoxPanel('Parent', h.mainLayout,'Title', 'input','Padding',5,'FontSize',10);
h.panel.inputTab = uix.TabPanel('Parent',h.panel.inputMain,'Padding',0,'FontSize',10);
h.panel.FokPok = uix.VBox('Parent', h.panel.inputTab, 'Padding', 0, 'Spacing', 5);
h.panel.Standalone = uix.VBox('Parent', h.panel.inputTab, 'Padding', 0, 'Spacing', 0);
h.panel.inputTab.TabWidth = 85;
h.panel.inputTab.TabTitles = {'FokusPokus', 'Standalone'};
% settings panel
h.panel.settingsMain = uix.BoxPanel('Parent', h.mainLayout,'Title','settings','Padding',5,'FontSize',10);
settingsMainVbox = uix.VBox('Parent', h.panel.settingsMain, 'Padding', 0, 'Spacing', 5);
settingsAnalysis = uix.Panel('Parent',settingsMainVbox,'Title','analysis','FontSize',10,'Padding',5);
settingsPlots = uix.Panel('Parent',settingsMainVbox,'Title','plots','FontSize',10,'Padding',5);
settingsMainVbox.Heights = [55,85];
% record panel
h.panel.record = uix.BoxPanel('Parent',h.mainLayout,'Title','record','Padding',5,'FontSize',10);

% populate inputTab-fokuspokus
% // Laser Wavelength edit box
HboxTmp = uix.HBox('Parent',h.panel.FokPok,'Padding',0,'Spacing',5);
VboxTmp1 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp1); % whitespace left, auto resize this
uicontrol('Parent',VboxTmp1,'Style','text','String','Laser Wavelength [nm]:','HorizontalAlignment','left','FontSize',10);
VboxTmp1.Heights = [16,20];
VboxTmp2 = uix.VBox('Parent',HboxTmp,'Padding',0,'Spacing',0);
uix.Empty( 'Parent', VboxTmp2); % whitespace left, auto resize this
h.edit.wavelength = uicontrol('Parent',VboxTmp2,'Style','edit','FontSize',10);
VboxTmp2.Heights = [15,20];
HboxTmp.Widths = [139,-1];
% // Connect gige button
h.pb.connect = uicontrol('Parent',h.panel.FokPok,'Style','pushbutton','String','Connect','FontSize',10,'FontWeight','normal');
h.pb.camPreview = uicontrol('Parent',h.panel.FokPok,'Style','pushbutton','String','Cam Preview / Viewer','FontSize',10);
h.pb.etalonSpec = uicontrol('Parent',h.panel.FokPok,'Style','pushbutton','String','Beam Splitter Configuration','FontSize',10,'FontWeight','normal');
h.pb.camWizard = uicontrol('Parent',h.panel.FokPok,'Style','pushbutton','String','Cam Wizard','FontSize',10,'FontWeight','normal');
h.pb.roiSelector = uicontrol('Parent',h.panel.FokPok,'Style','pushbutton','String','ROI Selector','FontSize',10);
h.pb.workingFolder = uicontrol('Parent',h.panel.FokPok,'Style','pushbutton','String','Select Output Directory','FontSize',10,'FontWeight','normal');
h.pb.disconnect = uicontrol('Parent',h.panel.FokPok,'Style','pushbutton','String','Disconnect','FontSize',10);
h.panel.FokPok.Heights = [35,25,25,25,25,25,25,25];
% populate inputTab-Standalone
uix.Empty( 'Parent', h.panel.Standalone); % whitespace left, auto resize this
h.pb.selectFiles = uicontrol('Parent',h.panel.Standalone,'Style','pushbutton','String','Select Files','FontSize',10,'FontWeight','normal');
h.panel.Standalone.Heights = [5,25];

% populate settingsAnalysis
h.pb.analysisSettings = uicontrol('Parent',settingsAnalysis,'Style','pushbutton','String','Settings','FontSize',10);
% populate settingsPlots
VboxTmp = uix.VBox('Parent',settingsPlots,'Padding',0,'Spacing',5);
HboxTmp = uix.HBox('Parent',VboxTmp,'Padding',0,'Spacing',0);
h.pb.enablePlot1 = uicontrol('Parent',HboxTmp,'Style','togglebutton','String','On','FontSize',10);
h.pb.settingsPlot1 = uicontrol('Parent',HboxTmp,'Style','pushbutton','String','Caustic3D','FontSize',10);
uix.Empty( 'Parent', HboxTmp); % whitespace
h.pb.enablePlot2 = uicontrol('Parent',HboxTmp,'Style','togglebutton','String','On','FontSize',10);
h.pb.settingsPlot2 = uicontrol('Parent',HboxTmp,'Style','pushbutton','String','Caustic2D','FontSize',10);
HboxTmp.Widths = [35,-1,5,35,-1];
HboxTmp = uix.HBox('Parent',VboxTmp,'Padding',0,'Spacing',0);
h.pb.enablePlot3 = uicontrol('Parent',HboxTmp,'Style','togglebutton','String','On','FontSize',10);
h.pb.settingsPlot3 = uicontrol('Parent',HboxTmp,'Style','pushbutton','String','BeamOut','FontSize',10);
uix.Empty( 'Parent', HboxTmp); % whitespace
h.pb.enablePlot4 = uicontrol('Parent',HboxTmp,'Style','togglebutton','String','On','FontSize',10);
h.pb.settingsPlot4 = uicontrol('Parent',HboxTmp,'Style','pushbutton','String','BeamIn','FontSize',10);
HboxTmp.Widths = [35,-1,5,35,-1];
VboxTmp.Heights = [25,25];

% populate record panel
VboxTmp = uix.VBox('Parent',h.panel.record,'Padding',0,'Spacing',5);
HboxTmp = uix.HBox('Parent',VboxTmp,'Padding',0,'Spacing',5);
h.pb.process = uicontrol('Parent',HboxTmp,'Style','togglebutton','String','Process','FontSize',10);
h.pb.processFrame = uicontrol('Parent',HboxTmp,'Style','pushbutton','String','Test / Single Shot','FontSize',10);
h.pb.saveResults = uicontrol('Parent',VboxTmp,'Style','pushbutton','String','Save / Export Results','FontSize',10);
VboxTmp.Heights = [25,25];

% set heights
h.mainLayout.Heights = [300,180,90]; % height 85 for standalone

obj.h = h;
end