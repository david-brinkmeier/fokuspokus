classdef iso11146fit
    % fits beam caustic hyperbola to measurement data
    
    properties (SetAccess = protected)
        z0              (1,1) double    % waist position in m
        d0              (1,1) double    % waist diameter in m
        divergence      (1,1) double    % Divergence in rad
        zR              (1,1) double    % Rayleigh length in m
        msquared        (1,1) double    % M²
        rsquared        (1,2) double    % rsquared and rsquared (adjusted for number of model arguments)
        counts          (1,2) uint32    % [num of measurements within 1 zR, num of measurements outside of 2 zR]; wrt. z0!
        badFit          (1,1) logical   % the fit fails for impossible hyperbolas (this can happen with much noise and bad ROIs)
                                        % if this happens this flag is used to break code execution before ungraceful failure (e.g. when plotting)
    end
    
    properties (Hidden)
        caustic         (1,1) struct % holds evaluated caustic, accessed by parent class "resultsxy"
    end
    
    properties (Dependent, Access = public)
    end
    
    methods
        % constructor and/or resetter
        function obj = iso11146fit()
            obj.caustic = struct('z',[],'d',[],'zfit',nan(1,300),'dfit',nan(1,300));
        end
        
    end
    
    %% private
    methods (Access = private)
    end
    
    %% static
    methods (Access = public)
        
        function obj = fitcaustic(obj,wavelength,pos,d_meas,weighted,weightedVariance)
            % wavelength is wavelength in SI units
            % pos are measurement positions in SI units
            % d_meas are measurement values of diameters (from 2nd moments) in SI units
            % weighted is boolean
            %
            % (weighted) linear least squares
            % d(x)^2 = A + Bx + Cx^2 modeled as A*x = y and solve for "x" in the least-squares sense
            % A is design matrix, y are measurements, x are "A,B,C" in d(x)^2 = A + Bx + Cx^2
            
            % error checks
            if any([~isvector(pos),~isvector(d_meas)])
                error('fitcaustic requires position and diameter measurements to be vectors')
            end
            if ~isequal(size(pos),size(d_meas))
                error('fitcaustic position vector and diameter measurements must be of equal size.')
            end
            
            % prepare input for generation of design matrix
            if isrow(pos)
                x = pos.';
                y = d_meas.';
            else
                x = pos;
                y = d_meas;
            end
            
            % generate weights
            if weighted == 1
                % weight inverse proportional to abs value
                wRel = min(y)./y; % correct weights given design matrix for equal (normalized) impact
            else
                % unweighted, measurement error far from focus has overrated impact
                % on result since __absolute__ deviation squared is considered
                wRel = ones(length(x),1);
            end
            
			% calc total resulting weights
            if nargin > 5
                % note: both weight vectors are in range [0,1], cf. resultsxy
                w = wRel.*weightedVariance;
            else
                w = wRel;
            end
            
            % generate design/regressor matrix and solve for fit values
            A = [ones(size(x)), x, x.^2]; % design matrix
            coeff = (w.*A)\(w.*y.^2); % solve (w.*A)*x = w.*y for x, i.e. solve for x for argmin(sum((w.*A*x - w.*y).^2))
            y_est = sqrt(coeff(1)+coeff(2).*x+coeff(3).*x.^2); % required for R squared
            
            %% ISO11146-1 eq. 25-29, get beam parameters
            % note: msquare_effective = sqrt(msquare_x^2 * msquare_y^2); % ISOTR 11146-3 eq. 48
            % also use intrinsic astigmatism per eq. 52 ISOTR 11146-3
            a = coeff(1); b = coeff(2); c = coeff(3);
            
            obj.z0 = -b/(2*c);
            obj.d0 = sqrt(a-(b^2/(4*c))); % equivalent to (1/(2*sqrt(c)))*sqrt(4*a*c-b^2)
            obj.divergence = sqrt(c); % note: full divergence
            obj.zR = (1/(2*c))*sqrt(4*a*c-b^2);
            obj.msquared = (obj.d0*obj.divergence*pi)/(4*wavelength);
            obj.rsquared = obj.calcrsquared(y,y_est,3);
            
            % ISO 11146-1 Ch. 9;  Measurement counts inside of range [z0-zR,z0+zR] should be > 5
            % ISO 11146-1 Ch. 9; Measurement counts outside of range [z0-2*zR,z0+2*zR] should be > 5
            obj.counts = [sum((pos > (obj.z0-obj.zR)) & (pos < (obj.z0+obj.zR))),...
                          sum((pos < (obj.z0-2*obj.zR)) | (pos > (obj.z0+2*obj.zR)))];
            
            %% now save caustic data for plotting
            % beamdiameter = @(z,a,b,c) sqrt(a + b*z + c*z.^2);
            % beamdiameter = @(z,d0,z0,zR) d0.*sqrt(1+((z-z0)./zR).^2); % beam diameter as fcn of beam spec
            obj.caustic.z = pos.';
            obj.caustic.d = d_meas.';
            obj.caustic.zfit = linspace(pos(1),pos(end),300);
            obj.caustic.dfit = obj.d0.*sqrt(1+((obj.caustic.zfit-obj.z0)./obj.zR).^2);
            
            %% check for failure
            if ~isreal([obj.d0,obj.divergence])
                obj.badFit = true;
            else
                obj.badFit = false;
            end
        end
		
    end
    
    methods (Static)
	
        function rsq = calcrsquared(y,y_estimate,p)
            % calculate R-squared (adjusted = false)
            % calculate R-squared adjusted (adjusted = true)
            %
            % R² = SSR/SST = 1 - SSE/SST
            % R²_adj = 1 - (n-1)/(n-p) * SSE/SST
            %
            % n: Number of observations
            % p: Number of regression coefficients (for ISO11146, p = 3)
            % w: Weights
            % SSE: Sum of squared errors
            % SSR: Sum of squared regression
            % SST: Sum of squared total
            %
            % note 20220318: no idea how to incorporate weights in R² calc atm, literature is confusing
            % https://stats.stackexchange.com/questions/439590/how-does-r-compute-r-squared-for-weighted-least-squares?noredirect=1&lq=1
            
            SSE = sum((y-y_estimate).^2); % = norm(d_meas - d_fit).^2
            SST = sum((y-mean(y)).^2);
            n = length(y);
            % p = 3; % model d(x)^2 = A + Bx + Cx^2 has 3 vars (A,B,C)
            
            rsq = nan(1,2); % init
            rsq(1) = 1 - SSE/SST; % regular
            rsq(2) = 1 - (n-1)/(n-p) * SSE/SST; % adjusted
        end
    end
    
end