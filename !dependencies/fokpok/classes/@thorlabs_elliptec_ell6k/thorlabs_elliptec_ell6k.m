classdef thorlabs_elliptec_ell6k < handle
    % Serial communication with Thorlabs ELL6K dual position slider which
    % is (ab)used as a shutter for IFSW FokusPokus.
    
    properties
        com_handle                    internal.Serialport
        serial_identifier       (1,:) char = 'VCP0'; % virtual com port 0 | Thorlabs ELL6K
        consoleOutput           (1,1) logical
    end
    
    properties (SetAccess = private)
        com_port                (1,:) char
        isInPositionOpen        (1,1) logical
        isInPositionClosed      (1,1) logical
    end
    
    properties (SetAccess = public, GetAccess = public)
        isTrained               (1,1) logical
        trainTimer              (1,1) uint64
        releaseConnectionTimer        timer
    end
    
    properties (Dependent)
        isConnected             (1,1) logical
    end
    
    methods (Access = private)
        
        function delete(obj)
            % destructor called upon clear variable
            obj.disconnect();
        end
        
    end
    
    methods
        
        function obj = thorlabs_elliptec_ell6k() % constructor
            obj.consoleOutput = true;
            obj.isTrained = false;
        end
        
        function var = get.isConnected(obj)
            var = false;
            try
                writeline(obj.com_handle,"0in") % initialize
                result = readline(obj.com_handle);
                if obj.consoleOutput
                    fprintf('VCP0: %s\n',strtrim(result));
                end
                if strtrim(result) == "0IN061060005120170801001F00000000"
                    if obj.consoleOutput
                        fprintf('Thorlabs ELL6K is connected and responds as expected.\n');
                    end
                    var = true;
                    % reset disconnect timer
                    stop(obj.releaseConnectionTimer);
                    set(obj.releaseConnectionTimer, 'StartDelay', 15);
                    start(obj.releaseConnectionTimer);
                end
            catch
                if obj.consoleOutput
                    warning('Thorlabs ELL6K is not responding / connected, something went wrong.');
                end
            end
            obj.consoleOutput = true;
        end
        
    end
    
    methods
        
        function [obj,success] = connect(obj)
            obj.consoleOutput = false;
            success = false;
            if obj.isConnected
                fprintf('Device is already connected at port %s.\n',obj.com_port);
                success = true;
                return
            end
            
            % RS232 specification for Thorlabs ELL6K
            BAUD_RATE = 9600;
            DATA_BITS = 8;
            STOP_BITS = 1;
            PARITY = 'none';
            HANDSHAKE = false; %#ok<NASGU>
            ENDIAN = 'little-endian';
            TERMINATOR = 'CR/LF';
            PORT = []; % to be determined
            
            % Identify ELL6K Com Port (Assume only 1 device using VCP)
            serialdevices = obj.comports();
            for port = 1:length(serialdevices)
                if strcmpi(serialdevices(port).type,'VCP0')
                    PORT = serialdevices(port).port;
                    obj.com_port = PORT;
                end
            end
            
            if ~isempty(PORT)
                try
                    obj.com_handle = serialport(PORT,...
                        BAUD_RATE,...
                        'DataBits', DATA_BITS,...
                        'ByteOrder', ENDIAN,...
                        'Parity', PARITY,...
                        'StopBits', STOP_BITS,...
                        'Timeout', 10);
                    obj.com_handle.configureTerminator(TERMINATOR);
                catch ME
                    callstack = dbstack;
                    warndlg(['\fontsize{12}',ME.message],[callstack.file,': ',ME.identifier],...
                        struct('WindowStyle','non-modal','Interpreter','tex'));
                end
            else
                warning('Cannot find Thorlabs ELL6K. COM device using virtual com port 0 (VCP0) is not connected.');
            end
            
            % need to flush, if ELL6K hardware buttons are used then
            % com port is littered with old information
            pause(0.1)
            try  %#ok<TRYNC>
                flush(obj.com_handle);
            end
            
            % verify connection
            obj.consoleOutput = false;
            if obj.isConnected
                success = true;
                fprintf('Connection established to VCP0 @ %s successfully!\n',PORT);
            else
                if ~isempty(PORT)
                    fprintf('Could not connect to VCP0 @ Port %s!\n',PORT);
                else
                    fprintf('Could not connect to VCP0 because there is no available serial device using virtual com port 0!\n');
                end
            end
            
            % start timer if successfully connected
            obj.releaseConnectionTimer = timer('TimerFcn',@(hObject,event) obj.disconnect(),...
                'StartDelay',10,'ExecutionMode','singleShot');
            start(obj.releaseConnectionTimer)
        end
        
        function obj = disconnect(obj)
            obj.consoleOutput = false;
            if obj.isConnected
                obj.com_handle = internal.Serialport.empty;
                fprintf('Device disconnected. Serial Port %s has been released to the system.\n',obj.com_port)
            end
            obj.com_port = [];
            
            % kill timer
            stop(obj.releaseConnectionTimer);
            delete(obj.releaseConnectionTimer);
            obj.releaseConnectionTimer = timer.empty;
        end
        
        function obj = moveShutter(obj, command, retry)
            % sticker "A"
            if nargin == 2
                retry = false;
            end
            
            % reset some variables, ensure connection etc. pp.
            [obj, success]= obj.movePrerequisites(retry);
            if ~success
                return
            end
            
            % ELL6K commands: Open and Closed
            switch lower(command)
                
                case 'open'
                    fprintf('ELL6K moving to position "Shutter Open"...');
                    writeline(obj.com_handle,"0fw")
                    result = readline(obj.com_handle);
                    if strcmpi(result,'0PO0000001F')
                        obj.isInPositionOpen = true;
                        fprintf('ELL6K Moved to position "Shutter Open"!\n');
                    elseif retry == false
                        retry = true;
                        warning('Retrying...')
                        obj.moveShutter(command,retry);
                    else
                        warning('Something is wrong, cannot move ELL6K to position "Shutter Open"');
                    end
                    
                case 'closed'
                    fprintf('ELL6K moving to position "Shutter Closed"...');
                    writeline(obj.com_handle,"0bw")
                    result = readline(obj.com_handle);
                    if strcmpi(result,'0PO00000000')
                        obj.isInPositionClosed = true;
                        fprintf('ELL6K moved to position "Shutter Closed"!\n');
                    elseif retry == false
                        retry = true;
                        warning('Retrying...')
                        obj.moveShutter(command,retry);
                    else
                        warning('Something is wrong, cannot move ELL6K to position "Shutter Closed"');
                    end
                    
                otherwise
                    warning('moveShutter: Command "%s" unknown.',command);
            end
        end
        
        function [obj, success] = movePrerequisites(obj, retry)
            % reset all position flags
            obj.isInPositionOpen = false;
            obj.isInPositionClosed = false;
            
            % verify connection & piezo trained
            success = true;
            obj.consoleOutput = false;
            if ~obj.isConnected
                [~,success] = obj.connect;
                if ~success
                    warning('Could not connect to ELL6K, cannot execute move command');
                    return
                end
            end
            if ~obj.isTrained || retry || (obj.isTrained && (toc(obj.trainTimer) > 60))
                fprintf('Training piezo frequencies...\n');
                obj.trainFreq();
            end
        end
        
        function obj = trainFreq(obj)
            obj.consoleOutput = false;
            if ~obj.isConnected
                [~,success] = obj.connect;
                if ~success
                    warning('Could not connect to ELL6K, cannot execute train piezo frequencies command');
                    return
                end
            end
            % train Piezo frequencies (@ startup or when pos A/B cant be reached)
            writeline(obj.com_handle,"0s1")
            result = readline(obj.com_handle);
            if strcmpi(result,'0GS00')
                disp('Piezo frequencies trained successfully.')
                obj.isTrained = true;
                obj.trainTimer = tic;
            else
                warning('Piezo frequencies could not be trained.')
            end
        end
        
    end
    
    methods (Access = public, Static)
        
        function serial_devices = comports()
            % lists available com port friendly names (windows only)
            [err,str] = system('REG QUERY HKEY_LOCAL_MACHINE\HARDWARE\DEVICEMAP\SERIALCOMM');
            if err
                serial_devices = [];
            else
                serial_devices = regexp(str,'\\Device\\(?<type>[^ ]*) *REG_SZ *(?<port>COM.*?)\n','names');
                cmd = 'REG QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\ /s /f "FriendlyName" /t "REG_SZ"';
                [~,str] = system(cmd);
                names = regexp(str,'FriendlyName *REG_SZ *(?<name>[^\n]*?) \((?<port>COM.*?)\)','names');
                [i,j] = ismember({serial_devices.port},{names.port});
                [serial_devices(i).name] = names(j(i)).name;
            end
        end
        
        function list = available_serial_devices()
            fprintf('Listing available COM ports, this takes a few seconds...\n')
            list = serialportlist("available");
            fprintf('%s\n',list);
        end
        
    end
end