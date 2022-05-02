classdef etalons
    % this class holds physical information of the beam splitters in the
    % experimental setup
    %
    % class "etalons" is passed to class "ROIpreselector" through method
    % ROIselector of class "gcam"
    % information contained in "etalons" is used to initialize the ROI beam
    % grid
    %
    % X axis is formally taken to be the FIRST beam splitter / etalon
    % -- first meaning the laser beam passes through this element first --
    % Y axis is formally taken to be the SECOND beam splitter / etalon
    %
    % IMPORTANT: Camera orientation could be rotated such that "first" and
    % "second" is switched. This cannot be checked programmatically,
    % because of this camera and beam splitter cubes have a matching label
    % which must point in the same drection.
    % --> camera coordinate system X-axis must coincide with the first beam
    % splitter, i.e. correspond to the "x" spec of this class
    %
    %
    % ToDo: Currently, etalons is passed partially to ROIpreselector via
    % method ROIselector of class gige. ROIs and OPDs are sorted in method
    % ROIselector of class gige after user specified ROI positions.
    % All of this should be moved to class etalons!
    
    properties
        laserWavelength (1,1) double    % laser wavelength in SI units / meter
        
        xnum            (1,1) uint32    % number of visible beams on the chip in X
                                        % corresponding to the first splitter
        ynum            (1,1) uint32    % number of visible beams on the chip in Y
                                        % corresponding to the second splitter
        flipX           (1,1) logical   % flip specification on camera
                                        % dont touch this if you dont know
                                        % what you're doing
        flipY           (1,1) logical   % flip specification on camera
        
        dX              (1,1) double    % gap thickness of first/X etalon
        dY              (1,1) double    % gap thickness of second/Y etalon
        wedgeAngle      (1,1) double    % etalon wedge angle in rad
    end
    
    properties (Dependent)
       OPDx             (1,1) double    % optical path difference of adjacent beams in X split direction
       OPDy             (1,1) double    % optical path difference of adjacent beams in Y split direction
       camSeparationX   (1,1) double    % expected lateral separation of adjacent spots on camera sensor
       camSeparationY   (1,1) double    % expected lateral separation of adjacent spots on camera sensor
       refractiveIndex  (1,1) double    % calculated using sellmeier formula for fused silica
    end
    
    methods
        function obj = etalons(wavelength,xnum,ynum,flipX,flipY,dX,dY,wedgeAngle)
            % Defaults highMsquared: [lambda, 4, 5, true, false, 3e-3, 2e-3, 45deg];
            % etalons(1030e-9, 4, 5, true, false, 3e-3, 2e-3, 45)
            
            obj.laserWavelength = wavelength;
            obj.xnum = xnum;
            obj.ynum = ynum;
            obj.flipX = flipX;
            obj.flipY = flipY;
            obj.dX = dX;
            obj.dY = dY;
            obj.wedgeAngle = deg2rad(wedgeAngle);
        end
        
        function val = get.xnum(obj)
           val = double(obj.xnum); 
        end
        
        function val = get.ynum(obj)
           val = double(obj.ynum); 
        end
        
        function val = get.OPDx(obj)
            if ~isempty(obj.refractiveIndex)
                val = 2*obj.dX*cos(obj.wedgeAngle)/obj.refractiveIndex;
            else
                val = nan;
            end
        end
        
        function val = get.OPDy(obj)
            if ~isempty(obj.refractiveIndex)
                val = 2*obj.dY*cos(obj.wedgeAngle)/obj.refractiveIndex;
            else
                val = nan;
            end
        end
        
        function val = get.camSeparationX(obj)
            val = 2*obj.dX*cos(obj.wedgeAngle);
        end
        
        function val = get.camSeparationY(obj)
            val = 2*obj.dY*cos(obj.wedgeAngle);
        end
        
        function val = get.refractiveIndex(obj)
           % note: below is sellmeier formula for fused silica specified for µm input
		   lambda = obj.laserWavelength*1e6; % m -> µm
           val = sqrt((0.6961663*lambda^2/(lambda^2-0.06840432^2)) +...
                      (0.4079426*lambda^2/(lambda^2-0.11624142^2)) +...
                      (0.8974794*lambda^2/(lambda^2-9.8961612^2)) +...
                      1);
        end
        
    end
end

