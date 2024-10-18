classdef resultsxy
    % manages data for xy-axes and executes hyperbola fit for orthogonal
    % beam axes
    
    properties (SetAccess = protected)
        x                       (1,1) fitresults.iso11146fit    % x fit
        y                       (1,1) fitresults.iso11146fit    % y fit
        deltaz_xy               (1,1) double                    % astigmatic waist difference
        msquared_effective      (1,1) double                    % effective M²
        intrinsic_stigmatic     (1,1) logical                   % if intrinsic stigmatic, then beam ellipctical beam can be made symmetric using astigmatic compensation
        possiblyGenAstigmatic   (1,1) logical                   % true if ISO11146-1 Ch. 9 applies; more than 10° variance of principal directions in set of measurement results
        ellipticity             (1,:) double                    % dmax/dmin meas values
        ellipticity_fit         (1,:) double                    % dmax/dmin fit values
        diameterEffective       (1,:) double                    % sqrt(dx*dy)
        dminRound               (1,2) double                    % [z position, miniumum diameter with ellipticity < 10%]
    end
    
    properties (SetAccess = private, GetAccess = public)
        logmask                 (:,:) logical                   % most of the stuff below is required to handle case of multiple measurements at identical z-pos
        z_internal              (1,:) double
        z_unique                (1,:) double
        dx_internal             (1,:) double
        dx_unique               (1,:) double
        dx_uniqueSTD            (1,:) double
        dy_internal             (1,:) double
        dy_unique               (1,:) double
        dy_uniqueSTD            (1,:) double
        theta_internal          (1,:) double
        theta_unique            (1,:) double
        
        weightedVarianceX       (1,:) double
        weightedVarianceY       (1,:) double
    end
    
    properties (Dependent)
        z                       (1,:) double                    % points to associated z positions
        z_fit                   (1,:) double                    % points to associated z positions with the fit
        dx                      (1,:) double                    % points to x diameter measurements used for fit
        dx_fit                  (1,:) double                    % points to x diameter fit
        dy                      (1,:) double                    % points to y diameter measurements used for fit
        dy_fit                  (1,:) double                    % points to y diameter fit
        badFit                  (1,1) logical                   % true if x or y fit yields imaginary numbers, check iso11146fit for explanation when this can happen
        thetaAVG                (1,1) double                    % USED / REQUIRED FOR PLOT1!!!
    end
    
    methods
        
        function obj = resultsxy()
            obj.x = fitresults.iso11146fit();
            obj.y = fitresults.iso11146fit();
        end
        
        function val = get.weightedVarianceX(obj)
           if isempty(obj.logmask)
               val = ones(size(obj.z_internal));
           else
               val = obj.weightedVarianceX;
           end
        end
        
        function val = get.weightedVarianceY(obj)
            if isempty(obj.logmask)
                val = ones(size(obj.z_internal));
            else
                val = obj.weightedVarianceY;
            end
        end
        
        function val = get.thetaAVG(obj)
            if ~isempty(obj.logmask)
                val = mean(obj.theta_unique);
            else
                val = mean(obj.theta_internal);
            end
        end
        
        function val = get.badFit(obj)
           if any([obj.x.badFit,obj.y.badFit])
               val = true;
           else
               val = false;
           end
        end
        
        function obj = set.z_internal(obj,val)
            if isequal(obj.z_internal,val)
                return
            else
                obj.z_internal = val;
                obj = obj.verifyZpos();
            end
        end
        
        function val = get.z(obj)
            val = obj.x.caustic.z;
        end
        
        function val = get.z_fit(obj)
            val = obj.x.caustic.zfit;
        end
        
        function val = get.dx(obj)
            val = obj.x.caustic.d;
        end
        
        function val = get.dx_fit(obj)
            val = obj.x.caustic.dfit;
        end
        
        function val = get.dy(obj)
           val = obj.y.caustic.d; 
        end
        
        function val = get.dy_fit(obj)
            val = obj.y.caustic.dfit;
        end
        
        function obj = fit_iso11146(obj,imstack) 
            if ~isa(imstack,'imgstack.imstack')
                warning('second argument is not the correct class')
                error('fit_iso11146 must be called with arguments (a,b) where a is class resultsxy and b is class imgstack.imstack')
            end
                        
            if imstack.logmaskIsValid
                obj.z_internal = imstack.axis.src.z(imstack.logmask); % setter triggers obj.verifyZpos
                obj.dx_internal = imstack.moments.denoised.dx(imstack.logmask)*imstack.pixelpitch;
                obj.dy_internal = imstack.moments.denoised.dy(imstack.logmask)*imstack.pixelpitch;
                obj.theta_internal = imstack.moments.denoised.theta(imstack.logmask);
            else
                obj.z_internal = imstack.axis.src.z; % setter triggers obj.verifyZpos
                obj.dx_internal = imstack.moments.denoised.dx*imstack.pixelpitch;
                obj.dy_internal = imstack.moments.denoised.dy*imstack.pixelpitch;
                obj.theta_internal = imstack.moments.denoised.theta;                    
            end
            
            % get ellipticity (ISO def)
            sortedDiameters = sort([obj.dx_internal; obj.dy_internal],1);
            obj.ellipticity = sortedDiameters(2,:)./sortedDiameters(1,:); % 1 means perfectly round, > 1 means elliptical
            
            % check for ISO edge case, might need to flip some X and Ys
            if imstack.settings.fit.fixEdgeCase
                [obj.possiblyGenAstigmatic,obj.dx_internal,obj.dy_internal,obj.theta_internal] = obj.checkThetaRange(obj.dx_internal,obj.dy_internal,obj.theta_internal,obj.ellipticity);
            else
                obj.possiblyGenAstigmatic = obj.checkThetaRange(obj.dx_internal,obj.dy_internal,obj.theta_internal,obj.ellipticity);
            end
            
            % now take mean of duplicate values and generate appropriate weights if required
            if ~isempty(obj.logmask)
                obj = obj.getUniqueMeasurments(imstack.settings.fit);
            end
            
            % fit caustic x and y
            if isempty(obj.logmask)
                obj.x = obj.x.fitcaustic(imstack.wavelength,obj.z_internal.',obj.dx_internal.',imstack.settings.fit.weighted);
                obj.y = obj.y.fitcaustic(imstack.wavelength,obj.z_internal.',obj.dy_internal.',imstack.settings.fit.weighted);
            else
                obj.x = obj.x.fitcaustic(imstack.wavelength,obj.z_unique.',obj.dx_unique.',imstack.settings.fit.weighted,obj.weightedVarianceX.');
                obj.y = obj.y.fitcaustic(imstack.wavelength,obj.z_unique.',obj.dy_unique.',imstack.settings.fit.weighted,obj.weightedVarianceY.');
            end
            
            % calc dependent variables
            % astigmatic waist distance (difference)
            obj.deltaz_xy = abs(obj.x.z0-obj.y.z0);
            % ISOTR 11146 eq. (49)
            obj.msquared_effective = sqrt(obj.x.msquared*obj.y.msquared);
            % ISOTR 11146-3 eq. (50), (52)
            obj.intrinsic_stigmatic = ((0.5*(obj.x.msquared-obj.y.msquared)^2)/obj.msquared_effective^2) < 0.039;
            
            % get effective beam diameter
            % THIS IS NOT the "generalized" beam diameter per ISO 11146-2, ch. 3.1, eq. (1)
            % this is pi*r² = pi*r_a*r_b solved for area-equivalent r, i.e.
            % this is what most people think of as the "average" beam
            % diameter for sufficiently round beams (here: ellipticity < 1.15)
            obj.diameterEffective = sqrt(obj.x.caustic.dfit.*obj.y.caustic.dfit);

            % get ellipticity of fit results
            sortedDiameters_fit = sort([obj.dx_fit; obj.dy_fit],1);
            obj.ellipticity_fit = sortedDiameters_fit(2,:)./sortedDiameters_fit(1,:); % 1 means perfectly round, > 1 means elliptical
            % check for the minimum beam diameter with ellipticity < 10%, e.g. minimum diameter where dmax/dmin < 1.1
            idx = find(obj.ellipticity_fit < 1.15);
            if ~isempty(idx)
                % get minimum
                [~,minD_idx] = min(obj.diameterEffective(idx));
                % z position and effective diameter
                obj.dminRound = [obj.z_fit(idx(minD_idx)),...
                                 obj.diameterEffective(idx(minD_idx))];
            else
                % there is no ellipticity < 1.1 anywhere
                obj.dminRound = [nan,nan];
            end
        end
        
        function obj = verifyZpos(obj)
            % z is updated: need to check if there are duplicate z-Positions
            if isequal(length(unique(obj.z_internal)),length(obj.z_internal))
                % no duplicates
                if ~isempty(obj.logmask)
                    obj.logmask = [];
                end
                return
            end
            % otherwise do all the required stuff when duplicates are present
            [groups,obj.z_unique] = findgroups(obj.z_internal);
            obj.logmask = false(max(groups),length(groups));
            for i = 1:max(groups)
                obj.logmask(i,:) = (groups == i);
            end
        end
        
        function obj = getUniqueMeasurments(obj,fitsettings)
            idx = find(obj.logmask);
            len = size(obj.logmask,1);
            
            dx_cp = repmat(obj.dx_internal,[len,1]);
            dxExtract = nan(size(obj.logmask));
            dxExtract(idx) = dx_cp(idx);
            
            dy_cp = repmat(obj.dy_internal,[len,1]);
            dyExtract = nan(size(obj.logmask));
            dyExtract(idx) = dy_cp(idx);
            
            theta_cp = repmat(obj.theta_internal,[len,1]);
            thetaExtract = nan(size(obj.logmask));
            thetaExtract(idx) = theta_cp(idx);
            
            % the mean along dim 2 (exluding nans) are the unique vals corresponding to obj.z_unique!
            obj.dx_unique = mean(dxExtract,2,'omitnan');
            obj.dx_uniqueSTD = std(dxExtract,[],2,'omitnan');
            obj.dy_unique = mean(dyExtract,2,'omitnan');
            obj.dy_uniqueSTD = std(dyExtract,[],2,'omitnan');
            obj.theta_unique = mean(thetaExtract,2,'omitnan');
            
            if (sum(logical(obj.dx_uniqueSTD)) > 1) && fitsettings.weightedVariance
                % ISO suggests weight inverse proportional variance
                % bc its the only logical thing to do this is applied here to NONZERO variances
                % and weights are normalized in range [settingsMIN,1]
                % --> (minimum variance gets weight 1, maximum variance gets weight settingsMIN < 1)
                weightsX = obj.dx_uniqueSTD;
                weightsX(weightsX == 0) = min(weightsX(weightsX > 0));
                weightsX = 1./weightsX;
                weightsY = obj.dy_uniqueSTD;
                weightsY(weightsY == 0) = min(weightsY(weightsY > 0));
                weightsY = 1./weightsY;
                obj.weightedVarianceX = normalize(weightsX,'range',[fitsettings.minWeightVariance,1]);
                obj.weightedVarianceY = normalize(weightsY,'range',[fitsettings.minWeightVariance,1]);
            else
                obj.weightedVarianceX = ones(size(obj.z_unique));
                obj.weightedVarianceY = ones(size(obj.z_unique));
            end
            
            if false % set to true for debug
                fig = figure('Name','STDEval','Color','w'); ax = axes(fig); %#ok<UNRCH>
                plot(ax,obj.z_internal,obj.dx_internal,'dr'), hold on
                plot(ax,obj.z_unique,obj.dx_unique,'or')
                plot(ax,obj.z_internal,obj.dy_internal,'db')
                plot(ax,obj.z_unique,obj.dy_unique,'ob')
                legend(ax,'x_{in}','x','y_{in}','y','AutoUpdate','off','Color','w','TextColor','k','EdgeColor','k');
                plot(ax,obj.z_unique,obj.dx_unique,'--r')
                plot(ax,obj.z_unique,obj.dy_unique,'--b')
                
                idx = find(obj.dx_uniqueSTD~=0);
                h = errorbar(ax,obj.z_unique(idx),obj.dx_unique(idx),obj.dx_uniqueSTD(idx),'r','LineStyle','none','LineWidth',2);
                set(h.Cap, 'EdgeColorType', 'truecoloralpha', 'EdgeColorData', [h.Cap.EdgeColorData(1:3); 255*0.5])
                set([h.Bar, h.Line], 'ColorType', 'truecoloralpha', 'ColorData', [h.Line.ColorData(1:3); 255*0.5])
                h = errorbar(ax,obj.z_unique(idx),obj.dy_unique(idx),obj.dy_uniqueSTD(idx),'b','LineStyle','none','LineWidth',2);
                set(h.Cap, 'EdgeColorType', 'truecoloralpha', 'EdgeColorData', [h.Cap.EdgeColorData(1:3); 255*0.5])
                set([h.Bar, h.Line], 'ColorType', 'truecoloralpha', 'ColorData', [h.Line.ColorData(1:3); 255*0.5])
                %set(ax,'Color','k','XColor','w','YColor','w')
            end
        end
        
    end
    
    methods (Static, Access = private)
        
        function [possiblyGenAstigmatic,dx,dy,theta] = checkThetaRange(dx,dy,theta,ellipticity)
            % theta is mapped to +/- 45°
            % ISO11146-1 Ch. 9 says more than 10° variance of principal direction
            % might SUGGEST general astigmatic beam and therefore requires
            % measurement of Wigner distribution for proper characterization
            %
            % numerical issue: dependent on orientation of camera coordinate system 
            % relative to beam one might get e.g. values ranging from +40° to -40°,
            % which in fact only represent a range of 10°.
            % one reason why this happens is the sign change / XY axis flip
            % per the ISO-2nd moment specification
            %
            % Hence the following assumption is made in the to address 
            % this issue: a) between two consecutive theta's (i.e.
            % directions between two consecutive images in the stack) the
            % beam cannot twist a full 90° / make a full quarter rotation.
            % b) Thus, of any two consecutive thetas, the correct second
            % theta is the theta such that the rotation from theta(1) to
            % theta(2) is minimized, the uncertainty being +/- pi/2.
            % This resolves the fringe case of beam orientation
            % at/close to +/-45° camera reference in presence of noise.
            % Note 1: This only addresses the problematic fringe case
            % mentioned. The condition >10° still works in all cases EXCEPT
            % when a full quarter rotation occurs between two measurement
            % planes. But if this occurs in the measurement set the
            % measurement planes are chosen badly anyway.
            % Note 2: This cannot be achieved using sign() from imMoments!
            skip = false;
            if (sum(ellipticity > 1.15) >= 2)
                % assume correct average theta is defined by those beams
                % with high enough ellipticity to reveal a robust determination of
                % principal direction from 2nd moment analysis
                logmask = (ellipticity > 1.15);
            else
                logmask = ones(size(theta));
                % too round, cannot rely on thetas / thetas are too volatile
                % but beam is so round everywhere one must assume stigmatic
                possiblyGenAstigmatic = false;
                skip = true;
            end
            
            % determine whether that average direction is closer to
            % octant -45° to 0° or octant 0° to 45°
            [~,idx] = max([sum(theta(logmask) > 0),sum(theta(logmask) < 0)]);
            if idx == 1
                ref = pi/8; % 22.5°
            elseif idx == 2
                ref = -pi/8; % -22.5°
            end
            
            % "thetaEffective" are those thetas flipped such that all
            % thetas are closer to reference value; the restrictions
            % mentioned before apply
            ischanged = false(size(theta));
            for i = 1:length(theta)
                [~,idx] = min(abs([theta(i),theta(i)+pi/2,theta(i)-pi/2]-ref));
                if idx == 2
                    theta(i) = theta(i) + pi/2;
                    ischanged(i) = true;
                elseif idx == 3
                    theta(i) = theta(i) - pi/2;
                    ischanged(i) = true;
                end
            end
            
            % check if data suggests genAstigmatic beam
            if ~skip
                % at least two thetas w/ ellipticity > 1.15 are present
                if (max(theta(logmask))-min(theta(logmask))) > (10*pi/180) % 10° ISO condition
                    possiblyGenAstigmatic = true;
                else
                    possiblyGenAstigmatic = false;
                end
            end
			
            % flip!
            if any(ischanged)
                dx_tmp = dx;
                dy_tmp = dy;
                dx(ischanged) = dy_tmp(ischanged);
                dy(ischanged) = dx_tmp(ischanged);
            end
        end
        
    end
end