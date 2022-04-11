classdef statusTextBox < handle
    % Helper class / wrapper using msgbox as a reporting tool to give user
    % feedback, similar to command window but one-way
    %
    % e.g. fokpokgui.statusTextBox(2,30,12,'non-modal','info');
    % opens a non-modal text box with 2 extra lines, width 30, fontsize 12
    % icon can be [info,warn,error]
    %
    % modify title using obj.title = 'text';
    % append text using obj.addText('test');
    % make newline using obj.newLine();
    % or provide the string with \n; but in that case \n will ALWAYS
    % be applied AFTER the string. e.g. addText('\ntest') is the same as
    % addText('test\n') or addText(sprintf('test\n'))
    %
    % to kill the figure use obj.kill(); after killDelay figure closes
    % this only applies to type "info". if "warn" or "error" is set
    % initially or afterwards then this is probably something the user
    % should acknowledge!
    %
    % 'non-modal' doesnt halt execution and lets user do stuff in the
    % background
    % 'modal' doesn't allow user to interact while this fig exists
    %
    % if something (condition ) happens during execution which requires
    % user to acknowledge, set uiwait(obj.hfig) in your code
    % code will resume after user clicks OK / closes fig
    % when type is set to error then this is done automatically upon set
    %
    %
    % EXAMPLE
    %
    % cliBox = statusTextBox(1,21,12,'normal','info');    init
    % cliBox.title = 'proper title';
    % cliBox.addText('Line 1');
    % cliBox.addText(' - and this is appended!');
    % cliBox.newLine;
    % cliBox.addText('Line 2');
    % pause(2)
    % cliBox.type = 'error';                                        set error flag
    
    properties (Access = public)
       type                    (1,:) char       % depending on context may be changed to [info,warn,error]
       killDelay               (1,1) double     % delay in seconds applied when using statusTextBox.kill()
                                                % to close text box
       titlePersistent         (1,1) logical    % default true; disables title overwrite if title is not empty
    end
    
    properties (SetAccess = private)
        hfig                                % handle to fig; when user acknowledgement of sth is required
                                            % use this handle to call uiwait(obj.hfig) to halt execution of code
                                            % when required
    end
       
    properties (Access = private)
        htext                               % handle to text
        hbutton                             % handle to pushbutton
        hicon                               % handle to image/icondata
        
        userText             (:,1) cell     % stores user provided text
        currentLine          (1,1) uint32
        visibleLines         (1,1) uint32
        fontSizeStr          (1,:) char     
        modalType            (1,:) char
        
        iconData                   struct   % loaded from external mat file
        figIsCreated         (1,1) logical
    end
    
    properties (Dependent, Access = public)
        figExists            (1,1) logical
        exitButton           (1,1) logical    % enables/disables "close [x]" in top right corner
        title                (1,:) char 
    end
    
    properties (Dependent, Access = private)
       enableOkButton        (1,1) logical
    end
    
    methods
        function obj = statusTextBox(extraLines,charLen,fontSize,modalType,type)
            if nargin == 5
                % type: modal or non-modal; modal also means uiwait + OK button
                % nonmodal is meant just as an info window
                obj.titlePersistent = true;
                obj.figIsCreated = false;
                obj.killDelay = 0.25;
                obj.currentLine = 1;
                obj.modalType = modalType;
                
                % iconData contains icons and associated alphamap if exist
                obj.iconData = load(fullfile(fileparts((mfilename('fullpath'))),'icons.mat'));
                obj.type = type;
                
                if isscalar(fontSize)
                    obj.fontSizeStr = sprintf('\\fontsize{%i}',abs(fontSize));
                    obj.userText(obj.currentLine) = {obj.fontSizeStr};
                else
                    error('fontSize must be a scalar')
                end
                
                switch obj.modalType
                    case 'normal'
                        initStruct = struct('Interpreter','tex','WindowStyle','normal');
                    case 'modal'
                        initStruct = struct('Interpreter','tex','WindowStyle','modal');
                    otherwise
                        error('Modaltype must be "modal" or "non-modal"');
                end
                
                % empty character repelem is U+2003 / &#8195 / Em Space: <- this is it!
                % https://emptycharacter.com/
                obj.hfig = msgbox([{strcat(obj.fontSizeStr,repelem('‏‏‎ ‎‎',charLen))};...
                    cell(extraLines,1)],...
                    '',...
                    'custom', obj.iconData.ico.(obj.type), gray(255),...
                    initStruct);
                
                obj.hicon = imhandles(obj.hfig);
                obj.htext = findall(obj.hfig,'Type','Text');
                obj.hbutton = findall(obj.hfig,'style','pushbutton');
                obj.figIsCreated = true;
                obj.visibleLines = length(obj.htext.String);
                
                % update icon
                obj.updateFig()
            end
        end
        
        function set.killDelay(obj,var)
            obj.killDelay = abs(var);
        end
        
        function set.exitButton(obj,var)
            % force enables / disables corner exit button of fig
            if obj.figExists
                if var == true
                    obj.hfig.CloseRequestFcn = 'closereq';
                else
                    obj.hfig.CloseRequestFcn = '';
                end
            end
        end
        
        function var = get.exitButton(obj)
            if obj.figExists
                switch obj.hfig.CloseRequestFcn
                    case 'closereq'
                        var = true;
                    otherwise
                        var = false;
                end
            end
        end
        
        function set.modalType(obj,var)
           var = lower(var);
            if ~ismember(var,{'modal','normal'}) 
                warning('modalType must be "modal" or "normal". Defaulting to "normal".')
                obj.modalType = 'normal';
            else
                obj.modalType = var;
            end
            updateFig(obj)
        end
        
        function var = get.figExists(obj)
           var = false;
            if obj.figIsCreated
               if isvalid(obj.hfig)
                  var = true; 
               end
           end
        end
        
        function set.title(obj,var)
            if obj.figExists
                if isempty(obj.hfig.Name) || (obj.titlePersistent == false)
                    obj.hfig.Name = var;
                end
            end
        end
        
        function set.enableOkButton(obj,var)
            if obj.figExists
                if var == true
                    obj.hbutton.Enable = 'on';
                elseif var == false
                    obj.hbutton.Enable = 'off';
                end
            end
        end
        
        function var = get.enableOkButton(obj)
            if obj.hbutton.Visible == 'on' %#ok<BDSCA>
                var = true;
            elseif obj.hbutton.Visible == 'off' %#ok<BDSCA>
                var = false;
            end
        end
        
        function var = get.title(obj)
           var = obj.hfig.Name;
        end
        
        function set.type(obj,var)
            isAllowed = {'info','warn','error'};
            if ismember(lower(var),isAllowed)
                obj.type = var;
            else
                warning('type be one of [%s, %s, %s], defaulting to "info".',isAllowed{:})
                obj.type = 'info';
            end
            obj.updateFig();
            
            if strcmpi(obj.type,'error')
               obj.stopExecutionUntilClose()
            end
        end
    end
    
    methods (Access = public)
                
        function stopExecutionUntilClose(obj)
            if obj.figExists
                obj.modalType = 'modal';
                uiwait(obj.hfig);
            end
        end
        
        function addText(obj,string)
            if obj.figExists
                % make sure this fig is on top
                figure(obj.hfig)
                
                % if user provides a \n then call newline at the end
                % and remove \n from string
                userWantsNewLine = false;
                if contains(string,'\n')
                    userWantsNewLine = true;
                    string = erase(string,'\n');
                end
                
                % could also be the sprintf newline variant which is char(10)
                if contains(string,char(10))
                    userWantsNewLine = true;
                    string = erase(string,char(10));
                end
                
                % update text
                obj.userText(obj.currentLine) = {[obj.userText{obj.currentLine},string]};
                if obj.currentLine > length(obj.htext.String)
                    obj.htext.String = obj.userText((obj.currentLine-obj.visibleLines+1) : 1 : obj.currentLine);
                else
                    obj.htext.String(obj.currentLine) = obj.userText(obj.currentLine);
                end
                
                % add newline if required
                if userWantsNewLine == true
                   obj.newLine();
                end
                
                % force update fig
                drawnow
            end
        end
        
        function newLine(obj)
            obj.currentLine = obj.currentLine + 1;
            obj.userText(obj.currentLine,1) = {obj.fontSizeStr};
        end
        
        function kill(obj)
            if obj.figExists
                if strcmpi(obj.type,'info')
                    % note: "@(hObject,event) mycallback(c)" means
                    % discard of first to inputs (which are hobj and event, then call fcn with argument c
                    killTimer = timer('TimerFcn',@(hObject,event) delete(obj.hfig),...
                        'StartDelay',obj.killDelay,'ExecutionMode','singleShot');
                    start(killTimer);
                end
            end
        end
    end
    
    methods (Access = private)
        function updateFig(obj)
            if obj.figExists
                % make sure this fig is on top
                figure(obj.hfig)
                
                % modalType is set by user on creation, but it may be
                % triggered to 'modal' when obj.stopExecutionUntilClose
                % is called
                obj.hfig.WindowStyle = obj.modalType;
                
                % make sure correct info is displayed
                obj.hicon.CData = obj.iconData.ico.(obj.type);
                obj.hicon.AlphaData = obj.iconData.alpha.(obj.type);
                
                % do we need the button?
                % if fig is non-modal or icon is warn/error then killTimer
                % is ignored and button is enabled
                if any(ismember({obj.modalType,obj.type},{'warn','error','modal'}))
                        obj.enableOkButton = true;
                else
                        obj.enableOkButton = false;
                end
            end
        end
    end
    
    methods (Access = public, Static)
        function obj = initdefault()
            % initializes with some usable values
            obj = statusTextBox(1,30,12,'normal','info');
        end
    end
end