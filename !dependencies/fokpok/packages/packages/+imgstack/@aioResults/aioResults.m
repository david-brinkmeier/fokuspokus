classdef aioResults
    % the idea here was to ensure that saving the results won't slow down
    % gradually but apparently preallocation in matlab OOP doesn't work
    % that way...even just using all the getters slows execution down
    % massively
    % current variant: write tmp files every k measurements
    % generate complete files upon trigger
    
    % --- USAGE ---
    % step 1) init results, additional 4th argument can be workingFolder
    % results = imgstack.aioResults(wavelength,pixelpitch,zPos,[workingFolder]); % init results
    % step 2) record data every iteration
    % results = results.record(imstack);
    % step 3) export results to .mat and .xlsx
    % results = results.exportResults();
    % --- /USAGE ---
    
    properties (SetAccess = protected, GetAccess = public)
        workingFolder           (1,:) char  % must be set, required to store tmp files
        
        % must be set @ initialization
        wavelength              (1,1) double
        pixelpitch              (1,1) double
        zPos                    (1,:) double
        
        % general, updated continously
        uuid                    (:,1) cell
        time                    (:,1) double
        MsquaredEffective       (:,1) double
        delta_z0_xy             (:,1) double
        intrinsicStigmatic      (:,1) logical
        possiblyGenAstigmatic   (:,1) logical
        
        % xData, Table1
        z0x                     (:,1) double
        zRx                     (:,1) double
        d0x                     (:,1) double
        divergenceX             (:,1) double
        MsquaredX               (:,1) double
        RsquaredFitX            (:,1) double
        MeasCountsXa            (:,1) uint32
        MeasCountsXb            (:,1) uint32
        
        % yData, Table1
        z0y                     (:,1) double
        zRy                     (:,1) double
        d0y                     (:,1) double
        divergenceY             (:,1) double
        MsquaredY               (:,1) double
        RsquaredFitY            (:,1) double
        MeasCountsYa            (:,1) uint32
        MeasCountsYb            (:,1) uint32
                
        % data Table2
        theta                   (:,:) double % [Time,zPos]
        dx                      (:,:) double % [Time,zPos]
        xc                      (:,:) double % [Time,zPos]
        dy                      (:,:) double % [Time,zPos]
        yc                      (:,:) double % [Time,zPos]
    end
    
    properties (SetAccess = protected, GetAccess = protected)
        idx                     (1,1) uint32
        initialHeight           (1,1) uint32
        currentHeight           (1,1) uint32 % used to determine whether preallocated arrays must be dynamically grown
        
        tmpFolder               (1,:) char   % here are tmp structs saved
        tmpFilenames            (:,1) cell   % these are the struct filenames
        saveCounter             (1,1) uint32
        uuid_internal           (1,:) char
        
        cliBox                        statusTextBox
    end
    
    properties (Dependent, SetAccess = protected, GetAccess = protected)
        width                (1,1) uint32
    end
    
    methods
        function obj = aioResults(imstack)
            % wavelength,pixelpitch,zPos,workingFolder
            obj.wavelength = imstack.wavelength;
            obj.pixelpitch = imstack.pixelpitch;
            obj.zPos = imstack.zPos;
            obj.workingFolder = imstack.figs.workingFolder;
            obj = obj.mkNewUUID();
            
            obj.idx = 1;
            obj.saveCounter = 1;
            
            obj.initialHeight = 1e3;
            obj.currentHeight = obj.initialHeight;
            obj = obj.preallocate();
        end
                
        function val = get.width(obj)
            val = length(obj.zPos);
        end
    end
    
    methods (Access = public)
        
        function obj = record(obj,imstack)
            assert(isa(imstack,'imgstack.imstack'),'imstack passed to aioResults must be a imgstack.imstack')
            if imstack.processed == 0
                warning('call to aioResults.record(obj,imstack), but imstack is empty');
                return
            end
            
            if isempty(obj.workingFolder) || ~isfolder(obj.workingFolder)
                obj = obj.requestFolder();
            end
            
            % general
            obj.uuid{obj.idx} = imstack.uuid;
            obj.time(obj.idx) = imstack.time;
            obj.MsquaredEffective(obj.idx) = imstack.results.msquared_effective;
            obj.delta_z0_xy(obj.idx) = imstack.results.deltaz_xy;
            if ~imstack.results.badFit
                obj.intrinsicStigmatic(obj.idx) = imstack.results.intrinsic_stigmatic;
                obj.possiblyGenAstigmatic(obj.idx) = imstack.results.possiblyGenAstigmatic;
            end
            
            % xData, Table1
            if ~imstack.results.x.badFit
                obj.z0x(obj.idx) = imstack.results.x.z0;
                obj.zRx(obj.idx) = imstack.results.x.zR;
                obj.d0x(obj.idx) = imstack.results.x.d0;
                obj.divergenceX(obj.idx) = imstack.results.x.divergence;
                obj.MsquaredX(obj.idx) = imstack.results.x.msquared;
                obj.RsquaredFitX(obj.idx) = imstack.results.x.rsquared(2);
                obj.MeasCountsXa(obj.idx) = imstack.results.x.counts(1);
                obj.MeasCountsXb(obj.idx) = imstack.results.x.counts(2);
            else
                obj.z0x(obj.idx) = nan;
                obj.zRx(obj.idx) = nan;
                obj.d0x(obj.idx) = nan;
                obj.divergenceX(obj.idx) = nan;
                obj.MsquaredX(obj.idx) = nan;
                obj.RsquaredFitX(obj.idx) = nan;
                obj.MeasCountsXa(obj.idx) = nan;
                obj.MeasCountsXb(obj.idx) = nan;
            end
            
            % yData, Table1
            if ~imstack.results.y.badFit
                obj.z0y(obj.idx) = imstack.results.y.z0;
                obj.zRy(obj.idx) = imstack.results.y.zR;
                obj.d0y(obj.idx) = imstack.results.y.d0;
                obj.divergenceY(obj.idx) = imstack.results.y.divergence;
                obj.MsquaredY(obj.idx) = imstack.results.y.msquared;
                obj.RsquaredFitY(obj.idx) = imstack.results.y.rsquared(2);
                obj.MeasCountsYa(obj.idx) = imstack.results.y.counts(1);
                obj.MeasCountsYb(obj.idx) = imstack.results.y.counts(2);
            else
                obj.z0y(obj.idx) = nan;
                obj.zRy(obj.idx) = nan;
                obj.d0y(obj.idx) = nan;
                obj.divergenceY(obj.idx) = nan;
                obj.MsquaredY(obj.idx) = nan;
                obj.RsquaredFitY(obj.idx) = nan;
                obj.MeasCountsYa(obj.idx) = nan;
                obj.MeasCountsYb(obj.idx) = nan;
            end
            
            % data (Table2), only available in output struct file
            obj.theta(obj.idx,:) = imstack.results.theta_internal;
            obj.dx(obj.idx,:) = imstack.results.dx_internal;
            obj.dy(obj.idx,:) = imstack.results.dy_internal;
            if imstack.img.ROIenabled
                obj.xc(obj.idx,:) = interp1(imstack.axis.src.x, imstack.img.xstartOffset + imstack.moments.denoised.xc);
                obj.yc(obj.idx,:) = interp1(imstack.axis.src.y, imstack.img.ystartOffset + imstack.moments.denoised.yc);
            else
                obj.xc(obj.idx,:) = interp1(imstack.axis.src.x, imstack.moments.denoised.xc);
                obj.yc(obj.idx,:) = interp1(imstack.axis.src.y, imstack.moments.denoised.yc);
            end
            
            % advance index, save if necessary
            obj.idx = obj.idx+1;
            if obj.idx > obj.currentHeight
                obj = obj.saveResults();
            end
        end
                
        function obj = exportResults(obj)
            if (obj.idx == 1) && (obj.saveCounter == 1)
                % there is nothing to save
                obj.cliBox = statusTextBox(1,30,12,'normal','info');
                obj.cliBox.exitButton = 0; % disable corner close
                obj.cliBox.killDelay = 1.5;
                obj.cliBox.title = 'aioResults.exportResults';
                obj.cliBox.addText('There is nothing to save! Exiting!')
                obj.cliBox.kill
                return
            end
            
            if obj.idx ~= 1
                obj = saveResults(obj);
                % now idx is reset to 1 anyway
            end
            
            % load all result structs into cell array
            len = length(obj.tmpFilenames);
            allResults = cell(len,1);
            for i = 1:len
                allResults{i} = load(obj.tmpFilenames{i});
            end
            % concatenate in struct array
            combined_struct = allResults{1};
            for i = 2:len
                combined_struct = cat(1,combined_struct, allResults{i});
            end
            % loop over fields and concat the values
            final_struct = struct;
            for field = fieldnames(combined_struct)'
                fname = field{1};
                final_struct.(fname) = vertcat(combined_struct.(fname));
            end
            
            exportSuccess = true;
            % init info box
            obj.cliBox = statusTextBox(1,30,12,'normal','info');
            obj.cliBox.exitButton = 0; % disable corner close
            obj.cliBox.killDelay = 1.5;
            obj.cliBox.title = 'aioResults.exportResults';
            % save struct to mat file
            obj.cliBox.addText(sprintf('Exporting results\\_%s.mat\n',obj.uuid_internal))
            try
                save(sprintf('%s\\results\\results_%s.mat',obj.workingFolder,obj.uuid_internal),'-struct','final_struct')
            catch
                exportSuccess = false;
                obj.cliBox.addText('Failure, but tmp files still exist!\n')
                obj.cliBox.type = 'warn';
            end
            % export table
            obj.cliBox.addText(sprintf('Exporting results\\_%s.xlsx\n',obj.uuid_internal))
            try
                writetable(obj.mkTable(final_struct),sprintf('%s\\results\\results_%s.xlsx',obj.workingFolder,obj.uuid_internal))
            catch
                exportSuccess = false;
                obj.cliBox.addText('Failure, but tmp files still exist!\n')
                obj.cliBox.type = 'warn';
            end
            % close cliBox
            if exportSuccess
                obj.cliBox.addText('Deleting temporary files...\n')
                rmdir(obj.tmpFolder,'s')
                obj.cliBox.addText('All done!\n')
            end
            
            obj.cliBox.kill
            obj = obj.mkNewUUID();
            obj.saveCounter = 1; % note: obj.idx is set to 1 now anyway
            obj.tmpFilenames = {};
        end
        
    end
    
    methods (Access = private)
         
        function obj = saveResults(obj)
            if isempty(obj.tmpFolder) || ~isfolder(obj.tmpFolder)
                obj = obj.mktmpFolder();
            end
            % saves struct to .mat file in obj.tmpFolder
            obj.tmpFilenames{obj.saveCounter} = strcat(obj.tmpFolder,sprintf('\\res_%i.mat',obj.saveCounter));
            % clear some fields if not required
            results = obj.getStruct();
            if obj.saveCounter ~= 1
                results.wavelength = [];
                results.pixelpitch = [];
                results.zPos = [];
            end
            % save
            save(obj.tmpFilenames{obj.saveCounter},'-struct','results')
            % advance
            obj.saveCounter = obj.saveCounter+1;
            obj.idx = 1;
        end
        
        function obj = preallocate(obj)
            if isempty(obj.zPos)
                warning('Call to aioResults.preallocate but imstack.zPos is empty. Set values first.');
                return
            end
            % general, updated continously
            obj.uuid = cell(obj.initialHeight,1);
            obj.time(obj.initialHeight,1) = 0;
            obj.MsquaredEffective(obj.initialHeight,1) = 0;
            obj.delta_z0_xy(obj.initialHeight,1) = 0;
            obj.intrinsicStigmatic(obj.initialHeight,1) = false;
            obj.possiblyGenAstigmatic(obj.initialHeight,1) = false;
            % xData, Table1
            obj.z0x(obj.initialHeight,1) = 0;
            obj.zRx(obj.initialHeight,1) = 0;
            obj.d0x(obj.initialHeight,1) = 0;
            obj.divergenceX(obj.initialHeight,1) = 0;
            obj.MsquaredX(obj.initialHeight,1) = 0;
            obj.RsquaredFitX(obj.initialHeight,1) = 0;
            obj.MeasCountsXa(obj.initialHeight,1) = 0;
            obj.MeasCountsXb(obj.initialHeight,1) = 0;
            % yData, Table1
            obj.z0y(obj.initialHeight,1) = 0;
            obj.zRy(obj.initialHeight,1) = 0;
            obj.d0y(obj.initialHeight,1) = 0;
            obj.divergenceY(obj.initialHeight,1) = 0;
            obj.MsquaredY(obj.initialHeight,1) = 0;
            obj.RsquaredFitY(obj.initialHeight,1) = 0;
            obj.MeasCountsYa(obj.initialHeight,1) = 0;
            obj.MeasCountsYb(obj.initialHeight,1) = 0;
            % data Table2, skip bc too much data copying / time cost
            obj.theta(obj.initialHeight,obj.width) = 0;
            obj.dx(obj.initialHeight,obj.width) = 0;
            obj.xc(obj.initialHeight,obj.width) = 0;
            obj.dy(obj.initialHeight,obj.width) = 0;
            obj.yc(obj.initialHeight,obj.width) = 0;
        end
        
        function data = getStruct(obj)
            % for data export, so that user doesn't require classdef to
            % work/share data
            data = struct();
            fns = fieldnames(obj);
            fns = fns(~ismember(fns,'workingFolder'));
            for i = 1:length(fns)
                if ~isscalar(obj.(fns{i})) && ~strcmp(fns{i},'zPos')
                    data.(fns{i}) = obj.(fns{i})(1:obj.idx-1,:);
                else
                    data.(fns{i}) = obj.(fns{i});
                end
            end
        end
        
        function obj = requestFolder(obj)
            selpath = uigetdir(path,'Select a folder for the results/export.');
            if selpath == 0
                h = warndlg('\fontsize{12}A working directory MUST be selected.',...
                    'aioResults.requestFolder',struct('Interpreter','tex','WindowStyle','modal'));
                waitfor(h);
                obj = obj.requestFolder();
            else
                obj.workingFolder = selpath;
                obj = obj.mktmpFolder();
            end
        end
        
        function obj = mktmpFolder(obj)
            if isempty(obj.workingFolder)
                obj = obj.requestFolder();
            end
            obj.tmpFolder = [obj.workingFolder,'\results',strcat('\tmp_',obj.uuid_internal)];
            if ~isfolder(obj.tmpFolder)
                [success,msg] = mkdir(obj.tmpFolder);
                if ~success
                    h = errordlg(sprintf('Error generating folder: "%s". Error message: "%s"',obj.tmpFolder,msg),...
                        'aioResults.requestFolder',struct('Interpreter','none','WindowStyle','modal'));
                    waitfor(h);
                end
            end
        end
        
        function obj = mkNewUUID(obj)
            uuid_tmp = char(java.util.UUID.randomUUID.toString);
            obj.uuid_internal = uuid_tmp(1:5);
        end
        
    end
    
    methods (Access = private, Static)
        
        function tbl = mkTable(inputStruct)
            fns = fieldnames(inputStruct);
            fns = fns(~ismember(fns,{'zPos','theta','dx','dy','workingFolder'}));
            vars = length(fns);
            len = length(inputStruct.uuid);
            
            out = cell(len,vars);
            logmask = true(vars,1); % used to exlude anything else that's not scalar or vector
            for i = 1:vars
                if isvector(inputStruct.(fns{i}))
                    if ~isscalar(inputStruct.(fns{i}))
                        current_var = inputStruct.(fns{i})(1:len,1);
                    else
                        current_var = inputStruct.(fns{i});
                    end
                    if ~iscell(current_var)
                        current_var = num2cell(current_var);
                    end
                    out(1:length(current_var),i) = current_var;
                else
                    logmask(i) = false;
                end
            end
            fns = fns(logmask); % remove non scalar/vectors
            out = out(:,logmask); % remove non scalar/vectors
            
            % write each column separately so we get access to variable names
            tbl = table(out(:,1),'VariableNames',{'Var1'});
            for i = 2:size(out,2)
                tbl = [tbl,table(out(:,i),'VariableNames',{sprintf('Var%i',i)})]; %#ok<AGROW>
            end
            
            % set variable names and done
            spatial = {'wavelength','pixelpitch','delta_z0_xy','z0x','zRx','d0x','z0y','zRy','d0y'};
            angular = {'divergenceX','divergenceY'};
            bool = {'possiblyGenAstigmatic','intrinsicStigmatic'};
            fns_varname = cell(length(fns),1);
            for i = 1:length(fns)
                switch fns{i}
                    case spatial
                        fns_varname{i} = [fns{i},32,'[m]'];
                    case angular
                        fns_varname{i} = [fns{i},32,'[rad]'];
                    case bool
                        fns_varname{i} = [fns{i},32,'[boolean]'];
                    case 'uuid'
                        fns_varname{i} = [fns{i},32,'[hhmmss.fff]'];
                    case 'time'
                        fns_varname{i} = [fns{i},32,'[s]'];
                    otherwise
                        fns_varname{i} = fns{i};
                end
            end
            % and write
            tbl.Properties.VariableNames = fns_varname;
        end
    end    

end