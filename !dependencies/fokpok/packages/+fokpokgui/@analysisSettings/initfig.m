function initfig(obj)
% initializes gui
h = struct();
h.panel = struct();
h.chkBox = struct(); % uicontrol uistyle checkbox
h.edit = struct(); % uicontrol uistyle edit
h.popup = struct(); % uicontrol uistyle popupmenu

% init fig
h.fig = figure( ...
    'Color','white',...
    'Name', 'analysisSettings', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'Toolbar', 'none', ...
    'HandleVisibility', 'off',...
    'WindowStyle', 'modal',...
    'Resize',0);

figWidth = 410;
figHeight = 726;
h.fig.Position = [get(0,'PointerLocation')-[figWidth/2,figHeight],figWidth,figHeight];
if h.fig.Position(1) < 0
    h.fig.Position(1) = 1;
end
if h.fig.Position(2) < 0
    h.fig.Position(2) = 1;
end

% Arrange the main interface
mainLayout = uix.VBox('Parent', h.fig, 'Padding', 0, 'Spacing', 0);

% Create the panels
h.panel.denoise = uix.BoxPanel( ...
    'Parent', mainLayout, ...
    'Title', 'denoise', 'Padding', 5, 'FontSize', 10);
h.panel.roi = uix.BoxPanel( ...
    'Parent', mainLayout, ...
    'Title', 'roi', 'Padding', 5, 'FontSize', 10);
h.panel.fit = uix.BoxPanel( ...
    'Parent', mainLayout, ...
    'Title', 'fit', 'Padding', 5, 'FontSize', 10);
h.panel.moments = uix.BoxPanel( ...
    'Parent', mainLayout, ...
    'Title', 'imageMoments', 'Padding', 5, 'FontSize', 10);
h.panel.center = uix.BoxPanel( ...
    'Parent', mainLayout, ...
    'Title', 'imageTranslation', 'Padding', 5, 'FontSize', 10);
mainLayout.Heights = [-4,-1,-1,-1,-1];

% Denoise-Basic Panel
vBoxDenoiseMain = uix.VBox('Parent', h.panel.denoise, 'Padding', 0, 'Spacing', 5);
denoiseBasic = uix.Panel('Parent',vBoxDenoiseMain,'Title','main','FontSize',10,'Padding',5);
vBoxDenoise = uix.VBox('Parent', denoiseBasic, 'Padding', 0, 'Spacing', 0);
% top row: debug and debugALL button
HBox_tmp = uix.HBox('Parent', vBoxDenoise, 'Padding', 0, 'Spacing', 5);
h.chkBox.denoise.debug = uicontrol('Parent',HBox_tmp,'Style','checkbox','String','debug','FontSize',10);
h.chkBox.denoise.debugALL = uicontrol('Parent',HBox_tmp,'Style','checkbox','String','debug ALL','FontSize',10);
HBox_tmp.Widths = [60,100];
% bottom row: n stddev text + popup for value selection
HBoxdenoise = uix.HBox('Parent', vBoxDenoise, 'Padding', 0, 'Spacing', 5);
VBox_tmp = uix.VBox('Parent', HBoxdenoise, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
uicontrol('Parent',VBox_tmp,'Style','text','String','n stddev','HorizontalAlignment','left','FontSize',10);
VBox_tmp.Heights = [5,20];
VBox_tmp = uix.VBox('Parent', HBoxdenoise, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
h.popup.denoise.ndev = uicontrol(VBox_tmp,'Style','popupmenu','String',{'0','1','2','3','4'});
VBox_tmp.Heights = [2,-1];
HBoxdenoise.Widths = [60,60];
vBoxDenoise.Heights = [25,25];
% Denoise-Advanced Panel
denoiseAdvanced = uix.Panel('Parent',vBoxDenoiseMain,'Title','advanced','FontSize',10,'Padding',5);
vBoxDenoise = uix.VBox('Parent', denoiseAdvanced, 'Padding', 0, 'Spacing', 0);
% top row: debug and debugALL button
h.chkBox.denoise.freqfilt = uicontrol('Parent',vBoxDenoise,'Style','checkbox','String','FFT-Lowpass','FontSize',10);
% bottom row: median filt text + popup for value selection
HBoxdenoise = uix.HBox('Parent', vBoxDenoise, 'Padding', 0, 'Spacing', 5);
VBox_tmp = uix.VBox('Parent', HBoxdenoise, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
uicontrol('Parent',VBox_tmp,'Style','text','String','medianFilt [nxn]','HorizontalAlignment','left','FontSize',10);
VBox_tmp.Heights = [5,20];
VBox_tmp = uix.VBox('Parent', HBoxdenoise, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
h.popup.denoise.median = uicontrol(VBox_tmp,'Style','popupmenu','String',{'1','3','5'});
VBox_tmp.Heights = [2,-1];
HBoxdenoise.Widths = [105,60];
vBoxDenoise.Heights = [25,25];

% Denoise-Background Panel
denoiseBackground = uix.Panel('Parent',vBoxDenoiseMain,'Title','background','FontSize',10,'Padding',5);
vBoxDenoise = uix.VBox('Parent', denoiseBackground, 'Padding', 0, 'Spacing', 0);
% top row: remove tilted plane or DC offset
HBoxdenoise = uix.HBox('Parent', vBoxDenoise, 'Padding', 0, 'Spacing', 5);
h.chkBox.denoise.removeplane = uicontrol('Parent',HBoxdenoise,'Style','checkbox','String','Remove plane','FontSize',10);
h.chkBox.denoise.removeDCOffset = uicontrol('Parent',HBoxdenoise,'Style','checkbox','String','Remove DC offset','FontSize',10);
HBoxdenoise.Widths = [110,130];
% next row: fitsamples text + editbox [numeric]
HBoxdenoise = uix.HBox('Parent', vBoxDenoise, 'Padding', 0, 'Spacing', 5);
VBox_tmp = uix.VBox('Parent', HBoxdenoise, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
uicontrol('Parent',VBox_tmp,'Style','text','String','max. samples','HorizontalAlignment','left','FontSize',10);
VBox_tmp.Heights = [5,20];
VBox_tmp = uix.VBox('Parent', HBoxdenoise, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
h.edit.denoise.fitsamples = uicontrol(VBox_tmp,'Style','edit','String',[]);
VBox_tmp.Heights = [2,-1];
HBoxdenoise.Widths = [95,60];
% next row: algorithm text + editbox [eig,svd]
HBoxdenoise = uix.HBox('Parent', vBoxDenoise, 'Padding', 0, 'Spacing', 5);
VBox_tmp = uix.VBox('Parent', HBoxdenoise, 'Padding', 0, 'Spacing', 5);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
uicontrol('Parent',VBox_tmp,'Style','text','String','algorithm','HorizontalAlignment','left','FontSize',10);
VBox_tmp.Heights = [5,20];
VBox_tmp = uix.VBox('Parent', HBoxdenoise, 'Padding', 0, 'Spacing', 5);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
h.popup.denoise.fitvariant = uicontrol(VBox_tmp,'Style','popupmenu','String',{'eig','svd'});
VBox_tmp.Heights = [2,-1];
HBoxdenoise.Widths = [95,60];
% finalize
vBoxDenoise.Heights = [25,25,30];
vBoxDenoiseMain.Heights = [80,80,-1];

% ROI Panel: guiRoi and autoROI
vBoxROIMain = uix.VBox('Parent', h.panel.roi, 'Padding', 0, 'Spacing', 5);
panelBasicRoi = uix.Panel('Parent',vBoxROIMain,'Title','main','FontSize',10,'Padding',5);
h.chkBox.roi.debug = uicontrol('Parent',panelBasicRoi,'Style','checkbox','String','debug','FontSize',10);
panelGuiRoi = uix.Panel('Parent',vBoxROIMain,'Title','guiROI','FontSize',10,'Padding',5);
panelAutoRoi = uix.Panel('Parent',vBoxROIMain,'Title','autoROI','FontSize',10,'Padding',5);
% top row: checkbox guiROI
h.chkBox.roi.guiROI = uicontrol('Parent',panelGuiRoi,'Style','checkbox','String','enable','FontSize',10);
% next panel autoROI; init vbox
vBoxAutoROI = uix.VBox('Parent', panelAutoRoi, 'Padding', 0, 'Spacing', 0);
% first row: enable and shortcircuit
HBox_tmp = uix.HBox('Parent', vBoxAutoROI, 'Padding', 0, 'Spacing', 5);
h.chkBox.roi.autoROI = uicontrol('Parent',HBox_tmp,'Style','checkbox','String','enable','FontSize',10);
h.chkBox.roi.shortCircuit = uicontrol('Parent',HBox_tmp,'Style','checkbox','String','shortCircuit','FontSize',10);
HBox_tmp.Widths = [70,100];
% next row: sensitivity and offset [text,edit,edit,edit,text,popup]
HBox_tmp = uix.HBox('Parent', vBoxAutoROI, 'Padding', 0, 'Spacing', 5);
VBox_tmp = uix.VBox('Parent', HBox_tmp, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
uicontrol('Parent',VBox_tmp,'Style','text','String','[grad,dev,energy,offset]:','HorizontalAlignment','left','FontSize',10);
VBox_tmp.Heights = [3,-1];
VBox_tmp = uix.VBox('Parent', HBox_tmp, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
h.edit.roi.sensitivity_1 = uicontrol(VBox_tmp,'Style','edit','String',[]);
VBox_tmp.Heights = [2,20];
VBox_tmp = uix.VBox('Parent', HBox_tmp, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
h.edit.roi.sensitivity_2 = uicontrol(VBox_tmp,'Style','edit','String',[]);
VBox_tmp.Heights = [2,20];
VBox_tmp = uix.VBox('Parent', HBox_tmp, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
h.edit.roi.sensitivity_3 = uicontrol(VBox_tmp,'Style','edit','String',[]);
VBox_tmp.Heights = [2,20];
VBox_tmp = uix.VBox('Parent', HBox_tmp, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
h.edit.roi.offset = uicontrol(VBox_tmp,'Style','edit','String',[]);
VBox_tmp.Heights = [2,20];
HBox_tmp.Widths = [140,ones(1,4)*55];
% last row: update very n frames
HBox_tmp = uix.HBox('Parent', vBoxAutoROI, 'Padding', 0, 'Spacing', 5);
VBox_tmp = uix.VBox('Parent', HBox_tmp, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
uicontrol('Parent',VBox_tmp,'Style','text','String','update ROI every:','HorizontalAlignment','left','FontSize',10);
VBox_tmp.Heights = [3,-1];
VBox_tmp = uix.VBox('Parent', HBox_tmp, 'Padding', 0, 'Spacing', 0);
uix.Empty('Parent',VBox_tmp); % whitespace left, auto resize this
h.edit.roi.updateEveryNframes = uicontrol(VBox_tmp,'Style','edit','String',[]);
VBox_tmp.Heights = [2,20];
HBox_tmp.Widths = [105,55];
% finalize
vBoxROIMain.Heights = [50,50,115];

% fit panel
HBox_tmp = uix.HBox('Parent', h.panel.fit, 'Padding', 0, 'Spacing', 5);
h.chkBox.fit.weighted = uicontrol('Parent',HBox_tmp,'Style','checkbox','String','weighted','FontSize',10);
h.chkBox.fit.weightedVariance = uicontrol('Parent',HBox_tmp,'Style','checkbox','String','weightedVariance','FontSize',10);
h.chkBox.fit.fixEdgeCase = uicontrol('Parent',HBox_tmp,'Style','checkbox','String','fixEdgeCase','FontSize',10);
uix.Empty('Parent',HBox_tmp); % whitespace left, auto resize this
HBox_tmp.Widths = [80,130,100,-1];
% image moments panel
h.chkBox.moments.debug = uicontrol('Parent',h.panel.moments,'Style','checkbox','String','debug','FontSize',10);
% image translation panel
h.chkBox.center.debug = uicontrol('Parent',h.panel.center,'Style','checkbox','String','debug','FontSize',10);

% finalize main fig sizes
mainLayout.MinimumHeights = [315,260,50,50,50];
mainLayout.Heights = [1,1,1,1,1];

% export handles
obj.h = h;
end















