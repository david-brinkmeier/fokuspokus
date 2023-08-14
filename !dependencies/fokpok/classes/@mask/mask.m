classdef mask
    % Defines mask for cropping and logical masks for image-roi
    % intended to be used with imstack but for the largest part general
    % purpose
    %
    % info: Rectangle specification is given by [xstart,ystart,lenx,leny]
    % usage: initialize a mask, e.g. test = mask();
    % provide referenze image, defining limits. test.refsz = img;
    % provide selection rectangle, test.selection = [xmin ymin lenx leny];
    % constraint handling is done by mask class
    
    properties
        selection           (1,4)   double      % [xstart,ystart,xend,yend]; matlab rect()
        refsz                       double      % provide size(img) where img is the to-be-to-masked source image
    end
    
    properties (SetAccess = protected)
        state               (1,1)   logical     % just a flag that stores info about whether a mask exists
        xstart              (1,1)   double      % name / identifier of the laser source
        lenx                (1,1)   double
        xcenter             (1,1)   double
        xend                (1,1)   double      
        
        ystart              (1,1)   double      
        leny                (1,1)   double
        ycenter             (1,1)   double
        yend                (1,1)   double      
        
        logmask                     logical     % stores radial logmask
        minOddEdgelen       (1,1)   double      % next largest odd integer square storage array size
    end
    
    properties (Access = private)
    end
    
    properties (Dependent) %(Dependent, SetAccess = private)
        xmax                (1,1)   double      % derived from refsz
        ymax                (1,1)   double      % derived from refsz
    end
    
    methods
        % constructor and/or resetter
        function obj = mask(varargin)
            obj.state =  false;
            obj.refsz = [];
            obj.xstart = NaN;
            obj.xcenter = NaN;
            obj.xend = NaN;
            obj.lenx = NaN;
            obj.ystart = NaN;
            obj.ycenter = NaN;
            obj.yend = NaN;
            obj.leny = NaN;
            obj.selection = NaN(1,4);
            obj.logmask = [];
            obj.minOddEdgelen = NaN;
        end
        
        %% setter
        function obj = set.refsz(obj,input)
            if isempty(input)
                obj.refsz = [NaN,NaN];
            else
                obj.refsz = size(input,1:2);
            end
        end
        
        function obj = set.selection(obj,value)
            if all(~isnan(value))
                obj.selection = round(value,0);
                obj = update(obj);
            else
                obj.selection = NaN(1,4);
            end
        end
        
        %% getter
        function xmax = get.xmax(obj)
            xmax = obj.refsz(2);
        end
        
        function ymax = get.ymax(obj)
            ymax = obj.refsz(1);
        end
        
    end
    
    %% private
    methods (Access = private)
        function obj = update(obj)
            % masking enabled
            obj.state =  true;
            
            % x vals
            obj.xstart = obj.selection(1);
            obj.lenx = obj.selection(3);
            obj.xend = obj.xstart + obj.lenx;
            
            % y vals
            obj.ystart = obj.selection(2);
            obj.leny = obj.selection(4);
            obj.yend = obj.ystart + obj.leny;
            
            % if complete mask is outside of image then reset + abort
            if ~isnan(obj.xmax) && ~isnan(obj.ymax)
                if ((obj.xstart > obj.xmax) || obj.xend < 1) || ((obj.ystart > obj.ymax) || obj.yend < 1)
                    warning('complete mask is outside of image, resetting!')
                    tmp = zeros(obj.refsz);
                    obj = mask();
                    obj.refsz = tmp;
                    return
                end
            end
            
            % enforce consraints x
            obj.xstart = max(obj.xstart, 1);
            if ~isnan(obj.xmax)
                obj.xend = min(obj.xend, obj.xmax);
            end
            obj.lenx = obj.xend - obj.xstart;
            obj.xcenter = obj.xstart +  obj.lenx/2;
            
            % enforce consraints y
            obj.ystart = max(obj.ystart, 1);
            if ~isnan(obj.ymax)
                obj.yend = min(obj.yend, obj.ymax);
            end
            obj.leny = obj.yend - obj.ystart;
            obj.ycenter = obj.ystart +  obj.leny/2;
            
            % get circ logical mask; note +1 offset
            [obj.logmask,~] = obj.radial_logmask([1+obj.leny, 1+obj.lenx]);
            
            % if we store the extracted image in a square array of odd edge length
            % then its next largest odd integer edge length is
            obj.minOddEdgelen = obj.ceilToOdd(max(size(obj.logmask)));
            
        end
    end
    
    %% static
    methods (Static)
        
        % debugplot defined in external file
        debugplot(mask,img,name)
        
        function n = ceilToOdd(n)
            % returns next largest odd integer
            n = 2*ceil((n+1)/2) - 1;
        end
        
        function sz = getminarraysize(masks)
            % masks is a cell array of masks
            % returns required size (x,y,z) of a compatible array such that
            % all selections/masks can fit
            % i.e. the largest selection/masks defines xy size
            % the number of selections/masks defines the z size / stack length
            % preallocates minimum size output array of masked image stack
            if ~(isa(masks,'cell') && all(cellfun(@(x) isa(x,'mask'),masks)))
               error('Input must be a cell array of masks!') 
            end
            % iterate over masks
            len = length(masks);
            sz = zeros(1,len);
            for i = 1:len
                sz(i) = masks{i}.minOddEdgelen;
            end
            edgelen = max(sz);
            % generate smallest possible odd quadratic output array
            sz = [edgelen,edgelen,len];
        end
        
        function [logmask,boundary] = radial_logmask(sz)
            % generates circular logical mask for 2D image where the longest side
            % defines its radius.
            % sz is size(img), i.e. vector [size_y, size_x]
            % purpose: denoising statistics, cf. ISOTR 11146-3 Ch. 3.4.2
            
            % generate logical mask
            [cols, rows] = meshgrid(1:sz(2), 1:sz(1));
            center = (sz+1)/2; % centroid of logical mask (y,x)
            radius = max(sz)/2; % note: should probably limit max(sz)/min(sz) to ~ < 4 or sth
            logmask = ((cols-center(2)).^2 + (rows-center(1)).^2) > radius^2; % x^2+y^2 > radius^2
            
            % calculate xy values of the circular boundary
            theta = linspace(0, 2*pi, 100);
            boundary = zeros(2,100);
            boundary(1,:) = radius.*cos(theta)+center(2); % x values
            boundary(2,:) = radius.*sin(theta)+center(1); % y values
        end
        
        function output = mask_image(img,mask)
            % returns the masked interior part of img based on the
            % specification given in class mask
            if ~isa(mask,'mask')
                error('mask variable must be of class mask')
            end
            if size(img,3) > 1
                error('image must be 2D')
            end
            if ~isequal(size(img),[mask.ymax, mask.xmax])
                error('to-be-masked image and mask specification do not mach')
            end
            output = zeros(size(img,1:2));
            output(mask.ystart:mask.yend, mask.xstart:mask.xend) = mask.crop_image(img,mask,[]);
        end
        
        function output = crop_image(img,mask,len)
            % crops img based on the specification of mask
            % e.g. call mask.crop(img,mask,[]);
            %
            % alternative, when len is provided, output will be of size
            % zeros(len,len), values inside of mask are pasted at the start
            % of the array in either direction
            % e.g. call mask.crop(img,mask,len)
            if nargin == 2
                len = [];
            end
            % input / error checking
            if ~isa(mask,'mask')
                error('mask variable must be of class mask')
            end
            if size(img,3) > 1
                error('image must be 2D')
            end
            if ~isequal(size(img),[mask.ymax, mask.xmax])
                error('to-be-cropped image and mask specification do not mach')
            end
            if ~isempty(len)
                if any(len < [mask.lenx+1, mask.leny+1])
                    error('len must exceed x/y dimensions of mask!')
                end
            end
            % cropping
            if mask.state == true
                if ~isempty(len)
                    output = zeros(len,len);
                    output(1:(mask.leny+1),1:(mask.lenx+1)) = img(mask.ystart:mask.yend,mask.xstart:mask.xend);
                else
                    output = img(mask.ystart:mask.yend,mask.xstart:mask.xend);
                end
            else
                warning('mask.state is false, mask.crop aborted')
                output = [];
            end
        end
    end
end