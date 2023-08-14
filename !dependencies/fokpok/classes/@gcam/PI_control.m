function goalAchieved = PI_control(obj,variant,allowed_deviation,Kp,Ki,debug)
obj.wait4update(2); % make sure current values are correct

if ~obj.cliBox.figExists
    obj.cliBox = statusTextBox(4,30,12,'normal','info');
    obj.cliBox.exitButton = 0; % disable corner close
    obj.cliBox.killDelay = 1;
end

switch lower(variant)
    case 'blacklevel'
        str = 'BlackLevel';
        obj.cliBox.title = str;
        setPointLimits = obj.blackLevelRange;
        getCurrentSetpoint = @(obj) obj.blackLevel;
        getCurrentResult = @(obj) obj.cam.Average_Value;
        % goal for PI; cam manual says must be 240-400; 
        % it's somehow derived from histogram, possibly ADC amplification
        goal = 300;
        
        % if current result is zero then we may be way outside the acceptable range for setpoints
        if getCurrentResult(obj) < 10
           getReasonableBlackLevel(obj,getCurrentSetpoint,getCurrentResult,goal)
        end
        
    case 'exposure'
        str = 'Exposure';
        obj.cliBox.title = str;
        setPointLimits = obj.exposureRange;
        getCurrentSetpoint = @(obj) obj.exposure;
        getCurrentResult = @(obj) calcExposureResult(obj);
        goal = 0.825*obj.grayLevelLims(2); % goal for PI
        if getCurrentResult(obj) < 0.5*goal || (getCurrentResult(obj) == obj.blackLevelRange(2))
            getReasonablExposure(obj,getCurrentSetpoint,getCurrentResult,goal)
        end
        
    otherwise
        error('PI_control variant "%s" unknown!',variant)
end

% initialization
frame = 0;
I = 0; % init integrator with zero
timestep = 1; % 1 frame step
run = true; % breaks out of loop
iter_extra = 3; % extra iterations after reaching goal
iter = 0; % init
maxframes = 30+iter_extra;

% for debug plot
result = nan(1,maxframes);
sens_plot = nan(1,maxframes);

% init flag
goalAchieved = false;
while run
    % save last sens for comparisons
    oldSetPoint = getCurrentSetpoint(obj);
    % get current value
    current_result = getCurrentResult(obj);
    % output
    obj.cliBox.addText(sprintf('%s: %.1f, Result: %.1f, Goal: %.1f +/- %.1f\n',...
                       str,oldSetPoint,current_result,goal,goal*allowed_deviation/100));
    
    % get current error
    difference = goal - current_result;
    % update PI control
    P = Kp*difference;
    I = I + Ki*difference*timestep;
    newSetPoint = round(oldSetPoint + P + I);
    % if we're not in range but set value is integer then try this
    if isequal(oldSetPoint,newSetPoint)
        if abs(difference) > goal*(allowed_deviation/100)
            if newSetPoint > oldSetPoint
                newSetPoint = newSetPoint-1;
            else
                newSetPoint = newSetPoint+1;
            end
        end
    end
    
    % advance frame
    frame = frame+1;
    % when goal is achieved keep running for some extra frames
    if abs(difference) < goal*(allowed_deviation/100)
        iter = iter+1;
        if iter > iter_extra
            obj.cliBox.addText('Success & Done.')
            run = false;
            goalAchieved = true;
        end
    else
        iter = 0;
    end
    % abort after maxframes frames
    if frame > maxframes
        obj.cliBox.addText(sprintf('Cannot get a better result after %i frames. Exiting.\n',maxframes));
        obj.cliBox.type = 'warn';
        if strcmpi(variant,'exposure')
           obj.cliBox.addText('Too much / Not enough signal.');
        end
        run = false;
    end
    
    % error check out of range
    if newSetPoint <= setPointLimits(1)
        newSetPoint = setPointLimits(1);
        obj.cliBox.addText('TOO BRIGHT. MORE FILTERS!');
        obj.cliBox.type = 'error';
        run = false;
    end
    if newSetPoint >= setPointLimits(2)
        newSetPoint = setPointLimits(2);
        obj.cliBox.addText('NOT ENOUGH SIGNAL. LESS FILTERS!');
        obj.cliBox.type = 'error';
        run = false;
    end
    
    % set current sensitivity
    switch lower(variant)
        case 'blacklevel'
            obj.blackLevel = newSetPoint;
        case 'exposure'
            obj.exposure = newSetPoint;
    end
    % need to wait for camera to update stuff apparently
    obj.wait4update(1.2);
    
    % save data of debug is enabled
    if debug
        result(frame) = current_result;
        sens_plot(frame) = newSetPoint;
    end
end

if debug    
    % remove nans
    result = result(~isnan(result));
    sens_plot = sens_plot(~isnan(sens_plot));
    % make plot
    figure('name',sprintf('[%s pi-control]',str),'color','w');    
    plot(1:length(result),result,'-k'); hold on
    yline(goal,'-r','goal value');
    yyaxis right
    plot(1:length(sens_plot),sens_plot,'--k'); hold on
    legend('result','goal','setpoint','Location','SouthEast')
    ylabel('value a.u.')
    xlabel('frame')
    if run == false
        title(sprintf('%s: Success/Exit within goal range.',str))
    else
        title({sprintf('%s: Exit after reaching maximum iterations',str),...
               'Cannot get a better result.'})
    end
end

end

function getReasonableBlackLevel(obj,getCurrentSetpoint,getCurrentResult,goal)
% get a first guess for blacklevel
range = ceil(linspace(obj.blackLevelRange(1),obj.blackLevelRange(2),10));
result = nan(1,length(range));
obj.cliBox.addText('Testing some BlackLevelValues..\n')
for i = 1:length(range)
    obj.blackLevel = range(i);
    obj.wait4update(1);
    result(i) = obj.cam.Average_Value;
    obj.cliBox.addText('.')
end
idx = find(abs(goal-result) == min(abs(goal-result)),1);
if ~isempty(idx)
    obj.blackLevel = range(idx);
    obj.wait4update(1);
end
obj.cliBox.newLine;
obj.cliBox.addText(sprintf('\nInitial BlackLevel: %i, Result: %i\n',...
                            getCurrentSetpoint(obj),getCurrentResult(obj)));
end

function getReasonablExposure(obj,getCurrentSetpoint,getCurrentResult,goal)
% get a first guess for exposure
range = ceil(linspace(obj.exposureRange(2)/200,obj.exposureRange(2),10));
result = nan(1,length(range));
obj.cliBox.addText('Significantly overexposed / underexposed.\n');
obj.cliBox.addText('Testing some exposures, please wait..\n');
for i = 1:length(range)
    obj.exposure = range(i);
    if i == 1 % camera is weird
        pause(1.5)
    end
    obj.wait4update(1.2);
    result(i) = calcExposureResult(obj);
    obj.cliBox.addText('.')
end
idx = find(abs(goal-result) == min(abs(goal-result)),1);
if ~isempty(idx)
    obj.exposure = range(idx);
    obj.wait4update(1.2);
end
obj.cliBox.newLine;
obj.cliBox.addText(sprintf('\nInitial exposure: %i, Result: %i\n',...
                             getCurrentSetpoint(obj),getCurrentResult(obj)));
end