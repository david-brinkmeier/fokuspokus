function initfig(obj)
% initializes gui
h = struct();
h.chkBox = struct(); % uicontrol uistyle checkbox
h.edit = struct(); % uicontrol uistyle edit
h.popup = struct(); % uicontrol uistyle popupmenu

% init fig
h.fig = figure( ...
    'Color','white',...
    'Name', 'plotSettings', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'Toolbar', 'none', ...
    'HandleVisibility', 'off',...
    'WindowStyle', 'modal',...
    'Resize',0);

figWidth = 220;
figHeight = 362;

h.fig.Position = [get(0,'PointerLocation')-[figWidth/2,figHeight],figWidth,figHeight];
if h.fig.Position(1) < 0
    h.fig.Position(1) = 1;
end
if h.fig.Position(2) < 0
    h.fig.Position(2) = 1;
end

% Arrange the main interface
h.mainLayout = uix.VBox('Parent', h.fig, 'Padding', 0, 'Spacing', 0);

% Create the panels
h.panel.main = uix.BoxPanel( ...
    'Parent', h.mainLayout, ...
    'Title', strcat('main |',32,obj.settings.name), 'Padding', 5, 'FontSize', 10);
h.panel.data = uix.BoxPanel( ...
    'Parent', h.mainLayout, ...
    'Title', 'data', 'Padding', 5, 'FontSize', 10);
h.panel.design = uix.BoxPanel( ...
    'Parent', h.mainLayout, ...
    'Title', 'design', 'Padding', 5, 'FontSize', 10);
h.panel.export = uix.BoxPanel( ...
    'Parent', h.mainLayout, ...
    'Title', 'export', 'Padding', 5, 'FontSize', 10);

% MAIN Panel
vBoxMain = uix.VBox('Parent', h.panel.main, 'Padding', 0, 'Spacing', 5);
HBoxMain = uix.HBox('Parent', vBoxMain, 'Padding', 0, 'Spacing', 5);
h.chkBox.enable = uicontrol('Parent',HBoxMain,'Style','checkbox','String','Enable','FontSize',10);
h.chkBox.timeStamp = uicontrol('Parent',HBoxMain,'Style','checkbox','String','Timestamp','FontSize',10);
uix.Empty( 'Parent', HBoxMain); % whitespace left, auto resize this
HBoxMain.Widths = [65,100,-1];
HBoxMain = uix.HBox('Parent', vBoxMain, 'Padding', 0, 'Spacing', 5);
uicontrol('Parent',HBoxMain,'Style','text','String','Update every','HorizontalAlignment','left','FontSize',10);
h.edit.updateEveryNframe = uicontrol('Parent',HBoxMain,'Style','edit','FontSize',10);
uicontrol('Parent',HBoxMain,'Style','text','String','export','HorizontalAlignment','left','FontSize',10);
h.edit.exportEveryNframe = uicontrol('Parent',HBoxMain,'Style','edit','FontSize',10);
uix.Empty( 'Parent', HBoxMain); % whitespace left, auto resize this
HBoxMain.Widths = [78,34,40,34,-1];
vBoxMain.Heights = [20,20];

% DATA Panel
HBoxData = uix.HBox('Parent', h.panel.data, 'Padding', 0, 'Spacing', 5);
% title / popup 1
vBoxData1 = uix.VBox('Parent', HBoxData, 'Padding', 0, 'Spacing', 0);
uicontrol('Parent',vBoxData1,'Style','text','String','xy','HorizontalAlignment','center','FontSize',10);
h.popup.scaleXY = uicontrol(vBoxData1,'Style','popupmenu','String',{'m','mm','µm'});
vBoxData1.Heights = [25,15];
% title / popup 2
vBoxData2 = uix.VBox('Parent', HBoxData, 'Padding', 0, 'Spacing', 0);
uicontrol('Parent',vBoxData2,'Style','text','String','z','HorizontalAlignment','center','FontSize',10);
h.popup.scaleZ = uicontrol(vBoxData2,'Style','popupmenu','String',{'m','mm','µm'});
vBoxData2.Heights = [25,15];
% title / popup 3
vBoxData3 = uix.VBox('Parent', HBoxData, 'Padding', 0, 'Spacing', 0);
uicontrol('Parent',vBoxData3,'Style','text','String','angle','HorizontalAlignment','center','FontSize',10);
h.popup.scaleAngle = uicontrol(vBoxData3,'Style','popupmenu','String',{'rad','mrad','µrad'});
vBoxData3.Heights = [25,15];

% DESIGN Panel
vBoxDesign = uix.VBox('Parent', h.panel.design, 'Padding', 0, 'Spacing', 0);
HBoxDesign = uix.HBox('Parent', vBoxDesign, 'Padding', 0, 'Spacing', 5);
% colormap
vBoxDesign1 = uix.VBox('Parent', HBoxDesign, 'Padding', 0, 'Spacing', 0);
uicontrol('Parent',vBoxDesign1,'Style','text','String','colormap','HorizontalAlignment','center','FontSize',10);

if isdeployed % for some reason error w/ turbo for compiled version
    availableCmaps = {'jet','gray','parula'};
else
    availableCmaps = {'jet','gray','parula','turbo'};
end
h.popup.colormap = uicontrol(vBoxDesign1,'Style','popupmenu','String',availableCmaps);
vBoxDesign1.Heights = [25,15];
% data_aspect
vBoxDesign2 = uix.VBox('Parent', HBoxDesign, 'Padding', 0, 'Spacing', 0);
uicontrol('Parent',vBoxDesign2,'Style','text','String','dataAR','HorizontalAlignment','center','FontSize',10);
h.popup.data_aspect = uicontrol(vBoxDesign2,'Style','popupmenu','String',{'real','modified'});
vBoxDesign2.Heights = [25,15];
% limits_type
vBoxDesign3 = uix.VBox('Parent', HBoxDesign, 'Padding', 0, 'Spacing', 0);
uicontrol('Parent',vBoxDesign3,'Style','text','String','axLimits','HorizontalAlignment','center','FontSize',10);
h.popup.limitsType = uicontrol(vBoxDesign3,'Style','popupmenu','String',{'normal','tight'});
vBoxDesign3.Heights = [25,15];
% % transparency
h.chkBox.transparency = uicontrol('Parent',vBoxDesign,'Style','checkbox','String','transparency','FontSize',10);
vBoxDesign.Heights = [50,30];

% EXPORT Panel
HBoxExport = uix.HBox('Parent', h.panel.export, 'Padding', 0, 'Spacing', 5);
vBoxExport1 = uix.VBox('Parent', HBoxExport, 'Padding', 0, 'Spacing', 0);
h.chkBox.fig = uicontrol('Parent',vBoxExport1,'Style','checkbox','String','fig','FontSize',10);
h.chkBox.png = uicontrol('Parent',vBoxExport1,'Style','checkbox','String','png','FontSize',10);
vBoxExport2 = uix.VBox('Parent', HBoxExport, 'Padding', 0, 'Spacing', 0);
uicontrol('Parent',vBoxExport2,'Style','text','String','DPI (png)','HorizontalAlignment','center','FontSize',10);
h.popup.dpi = uicontrol(vBoxExport2,'Style','popupmenu','String',{'150','300','600'});
vBoxExport1.Heights = [25,25];
vBoxExport2.Heights = [25,15];
uix.VBox('Parent', HBoxExport, 'Padding', 0, 'Spacing', 0);


h.mainLayout.Heights = [84,84,110,84];
obj.h = h;
end