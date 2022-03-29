classdef imMoments
    % first and second centered moments in unit/pixel coordinates per
    % ISO 11146 specification
    
    properties (SetAccess = protected)
        type                char        % analysis can be "cog" or "all", CenterOfGravity skips 2nd moments
        dx          (1,:)   double      % "x" direction, i.e. ISO11146 diameter closest to reference x axis
        dy          (1,:)   double      % "y" direction, i.e. ISO11146 diameter closest to reference y axis
        theta       (1,:)   double      % azimuthal angle between principal beam axis which is closest to the reference x-axis
        dx_cam      (1,:)   double      % beam diameter in cam coordsys X axis, only relevant for axis def in plots
        dy_cam      (1,:)   double      % beam diameter in cam coordsys Y axis, only relevant for axis def in plots
    end
    
    properties (Access = private)
        len         (1,:)   double      % number of processed images
        xc_private  (1,:)   double      % centroid x direction, internal / size validation
        yc_private  (1,:)   double      % centroid y direction, internal / size validation
    end
    
    properties (Dependent)
        xc          (1,:)   double      % centroid x direction, user may overwrite (e.g. update after image translation)
        yc          (1,:)   double      % centroid y direction, user may overwrite (e.g. update after image translation)#
        dgen        (1,:)   double      % generalized diameter, ISO11146 (23), only applicable if ellipticity > .87: Info: see GETTER!
    end
    
    methods
        % constructor and/or resetter
        function obj = imMoments(img,type,debug)
            % img must be 3D image stack (x,y,z)
            % z pos can be associated z positions (optional /only needed for
            % generation of plot data)
            % type selects complete analysis 'all' or only centroid 'cog'
            %
            % e.g. call imMoments(img,'cog')
            % e.g. call imMoments(img,'all')
            %
            % parse inputs
            obj.type = type;
            obj.len = size(img,3);
            % preallocate
            obj.xc_private = nan(1,obj.len);
            obj.yc_private = nan(1,obj.len);
            obj.dx = nan(1,obj.len);
            obj.dy = nan(1,obj.len);
            obj.theta = nan(1,obj.len);
            % calculate moments
            obj = getMoments(obj,img);
            % generate debug plots if requested
            if debug
                if strcmp(obj.type,'all')
                    debugplot(obj,img)
                else
                    warning('imMoments debug is only available with type "all", not "cog"')
                end
            end
        end
        
        %% setter
        
        function obj = set.xc_private(obj,input)
            obj.xc_private = input;
        end
        
        function obj = set.yc_private(obj,input)
            obj.yc_private = input;
        end
        
        function obj = set.type(obj,input)
            input = lower(input);
            if ismember(input,{'cog','all'})
                obj.type = input;
            else
                obj.type = 'all';
            end
        end
        
        function obj = set.xc(obj,input)
            if length(input) == obj.len
                obj.xc_private = input;
            else
                warning('length of user defined xc does not fit requirements.')
            end
        end
        
        function obj = set.yc(obj,input)
            if length(input) == obj.len
                obj.yc_private = input;
            else
                warning('length of user defined yc does not fit requirements.')
            end
        end
        
        %% getter
        function val = get.xc(obj)
            val = obj.xc_private;
        end
        
        function val = get.yc(obj)
            val = obj.yc_private;
        end
        
        function val = get.dgen(obj)
            % note: ISO says dgeneralized =  2*sqrt(2)*sqrt(m20_central+m02_central);
            % if beam is roughly round (ellipticity > .87; (ISO11146 eq. 23)
            % this is equivalent to (1/sqrt(2))*sqrt(dx.^2+dy.^2)!
            % otherwise this parameter should probably be ignored?!
            val = (1/sqrt(2))*sqrt(obj.dx.^2+obj.dy.^2);
        end

    end
    
    %% private
    methods (Access = private)
        
        % methods defined in external files
        debugplot(obj,img) 
        
        function obj = getMoments(obj,img)
            %#ok<*PROPLC>
            % preallocate
            xc = nan(1,obj.len);
            yc = nan(1,obj.len);
            dx = nan(1,obj.len);
            dy = nan(1,obj.len);
            dx_cam = nan(1,obj.len);
            dy_cam = nan(1,obj.len);
            theta = nan(1,obj.len);
            
            % error check nan/inf values in image
            if any(~isfinite(img),'all')
                warndlg('Image passed to imMoments contains NaN or INF values. Something went wrong while denoising!')
                error('Moments are not defined for NaN or INF values.')
            end
            
            % get moments
            for i = 1:obj.len
                % get current image
                current_img = img(:,:,i);
                % get pixel coordinates where nonzero values are encountered
                idx = find(current_img);
                [y,x] = ind2sub(size(current_img), idx);
                % handle to compute the moments
                moment = @(p,q) sum((x.^p).*(y.^q).*current_img(idx));
                % calc moments
                m00 = moment(0,0);
                m10 = moment(1,0);
                m01 = moment(0,1);
                % barycenter / center of mass/gravity
                xc(i) = m10/m00;
                yc(i) = m01/m00;
                % if only center of mass required then done, else
                % calc additional required moments
                if strcmp(obj.type,'all')
                    m11 = moment(1,1);
                    m02 = moment(0,2);
                    m20 = moment(2,0);
                    % moments and central moments are related by
                    % https://en.wikipedia.org/wiki/Image_moment#Central_moments
                    m20_central = m20/m00 - xc(i)^2;
                    m02_central = m02/m00 - yc(i)^2;
                    m11_central = m11/m00 - xc(i)*yc(i);
                    % ISO 11146
                    signum = sign(m20_central-m02_central);
                    % diameters of principal axis closer to reference (cam)
                    % x-axis. THIS IS IN THE LOCAL COORDINATE SYSTEM OF VARIANCE ELLIPSE
                    dx(i) = 2*sqrt(2).*sqrt((m20_central+m02_central)...
                        + signum*sqrt((m20_central-m02_central)^2+4*m11_central^2));
                    dy(i) = 2*sqrt(2).*sqrt((m20_central+m02_central)...
                        - signum*sqrt((m20_central-m02_central)^2+4*m11_central^2));
                    % theta is the azimuthal angle between principal axis 
                    % which is closer to the x-axis and camera x-axis
                    theta(i) = 0.5*atan(2*m11_central/(m20_central-m02_central));
                    % diameters in cam coord system..only needed for plotting
                    dx_cam(i) = 4*sqrt(m20_central);
                    dy_cam(i) = 4*sqrt(m02_central);
                end
                % option: get index of maxmimum value
                % [~, maxidx] = max(current_img(:));
                % [y_max, x_max]= ind2sub(size(current_img), maxidx);
            end
            % write results
            obj.xc_private = xc;
            obj.yc_private = yc;
            obj.dx = dx;
            obj.dy = dy;
            obj.dx_cam = dx_cam;
            obj.dy_cam = dy_cam;
            obj.theta = theta;
        end
    end
    
    %% static
    methods (Static)
        
        function data = genplotdata(moments,offset,axis,pixelpitch,option1,option2)
            % option1: 'normalized', 'normalized-offset', 'si-units', 'si-units-centered'
            % options2: 'xy' or 'xyz'
            %
            % allowed calls
            % data = imMoments.genplotdata(moments,[],[],[],'normalized','xy')
            % data = imMoments.genplotdata(moments,[],axis,[],'normalized','xy');
            % data = imMoments.genplotdata(moments,offset,axis,[],'normalized-offset','xy');
            % data = imMoments.genplotdata(moments,offset,axis,[],'normalized-offset','xy');
            % data = imMoments.genplotdata(moments,[],axis,pixelpitch,'si-units','xyz');
            % data = imMoments.genplotdata(moments,[],axis,pixelpitch,'si-units-centered','xyz');
            
            if ~isa(moments,'imMoments')
                error('moments variable must be of class imMoments')
            end
            option1 = lower(option1); 
            option2 = lower(option2);
            % error checking
            if strcmp(option1,'normalized-offset') && isempty(offset)
                error('when offset is required, offset.x and offset.y must be provided')
            end
            if ismember(option1,{'si-units','si-units-centered'}) && (isempty(pixelpitch) || isempty(axis))
                error('when si-units are selected, pixelpitch and axis must be provided')
            end
            % gen output data struct
            data = struct('ellipse',struct('XData',[],'YData',[],'ZData',[]),...
                'xax',struct('XData',[],'YData',[],'ZData',[]),...
                'yax',struct('XData',[],'YData',[],'ZData',[]));
            % select centroid position units / definition
            switch option1
                case 'normalized'
                    xc = moments.xc;
                    yc = moments.yc;
                case 'normalized-offset'
                    % pixel offset
                    xc = offset.x + moments.xc;
                    yc = offset.y + moments.yc;
                case 'si-units-centered'
                    % then assume centered on position 0
                    xc = 0;
                    yc = 0;
                case 'si-units'
                    % interpolate normalized moments onto given axis definition
                    xc = interp1(axis.x,moments.xc);
                    yc = interp1(axis.y,moments.yc);
                otherwise
                    error('option1 "%s" undefined',option1)
            end
            % select diameter units
            switch option1
                case {'normalized','normalized-offset'}
                    dx = moments.dx;
                    dy = moments.dy;
                case {'si-units-centered','si-units'}
                    dx = pixelpitch*moments.dx;
                    dy = pixelpitch*moments.dy;
            end
            % check if z values are required
            switch option2
                case 'xy'
                    calczdata = false;
                case 'xyz'
                    calczdata = true;
                    if isempty(axis)
                        error('if plotdata xyz is selected then axis with axis.z must be provided')
                    end
                otherwise
                    error('option1 "%s" undefined',option2)
            end
            
            % for readability..get theta
            theta = moments.theta;
              
            % now ready to calculate plot data
            % get data for ellipse
            phi = linspace(0,2*pi,60).';
            data.ellipse.XData = xc + (dy/2).*cos(phi).*sin(theta) + (dx/2).*sin(phi).*cos(theta);
            data.ellipse.YData = yc + (dx/2).*sin(phi).*sin(theta) - (dy/2).*cos(phi).*cos(theta);
            if calczdata
                data.ellipse.ZData = axis.z.*ones(1,length(phi)).';
            end
            % ellipse x axis; init x as [-1 1] then rotate by theta, translate and scale by radius in x direction
            data.xax.XData = xc + (dx/2).*(cos(theta).*[-1;1]-sin(theta).*[0;0]);
            data.xax.YData = yc + (dx/2).*(sin(theta).*[-1;1]+cos(theta).*[0;0]);
            if calczdata
                data.xax.ZData = axis.z.*ones(1,2).';
            end
            % ellipse y axis; init x as [-1 1] then rotate by theta, translate and scale by radius in x direction
            data.yax.XData = xc + (dy/2).*(cos(theta).*[0;0]-sin(theta).*[-1;1]);
            data.yax.YData = yc + (dy/2).*(sin(theta).*[0;0]+cos(theta).*[-1;1]);
            if calczdata
                data.yax.ZData = axis.z.*ones(1,2).';
            end
        end
        
    end
    
end