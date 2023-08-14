classdef analysisSettings < handle
    
    properties (SetAccess = private, GetAccess = public)
        h                                 struct
        settings                          settings.settingscontainer
    end
    
    properties (SetAccess = private, GetAccess = private)
    end
    
    properties (Dependent, Access = public)
        figexists                   (1,1) logical
    end
    
    properties (Constant, Access = private)
    end
    
    methods
        function obj = analysisSettings(settings)
            if ~isa(settings,'settings.settingscontainer')
                warning('analysisSettings gui needs to be passed an instance of settings.settingscontainer')
                return
            end
            obj.settings = settings;
            
            % init fig and draw initial rois
            obj.initfig();
            obj.updateStateOfGui();
            
            % arm callbacks, chkboxes
            set(obj.h.chkBox.denoise.debug,'Callback',@(hobj,event) obj.guiSetCheckBox('debug-denoise'))
            set(obj.h.chkBox.roi.debug,'Callback',@(hobj,event) obj.guiSetCheckBox('debug-roi'))
            set(obj.h.chkBox.center.debug,'Callback',@(hobj,event) obj.guiSetCheckBox('debug-center'))
            set(obj.h.chkBox.moments.debug,'Callback',@(hobj,event) obj.guiSetCheckBox('debug-moments'))
            set(obj.h.chkBox.denoise.debugALL,'Callback',@(hobj,event) obj.guiSetCheckBox('debug-all'))
            set(obj.h.chkBox.denoise.freqfilt,'Callback',@(hobj,event) obj.guiSetCheckBox('freqfilt'))
            set(obj.h.chkBox.denoise.removeplane,'Callback',@(hobj,event) obj.guiSetCheckBox('removeplane'))
            set(obj.h.chkBox.roi.guiROI,'Callback',@(hobj,event) obj.guiSetCheckBox('guiROI'))
            set(obj.h.chkBox.roi.autoROI,'Callback',@(hobj,event) obj.guiSetCheckBox('autoROI'))
            set(obj.h.chkBox.roi.shortCircuit,'Callback',@(hobj,event) obj.guiSetCheckBox('shortCircuit'))
            set(obj.h.chkBox.fit.weighted,'Callback',@(hobj,event) obj.guiSetCheckBox('weighted'))
            set(obj.h.chkBox.fit.weightedVariance,'Callback',@(hobj,event) obj.guiSetCheckBox('weightedVariance'))
            set(obj.h.chkBox.fit.fixEdgeCase,'Callback',@(hobj,event) obj.guiSetCheckBox('fixEdgeCase'))
            
            % popups
            set(obj.h.popup.denoise.fitvariant,'Callback',@(hobj,event) obj.guiSetPopup('fitvariant'))
            set(obj.h.popup.denoise.ndev,'Callback',@(hobj,event) obj.guiSetPopup('ndev'))
            set(obj.h.popup.denoise.median,'Callback',@(hobj,event) obj.guiSetPopup('median'))
            
            % editboxes
            set(obj.h.edit.denoise.fitsamples,'Callback',{@obj.guiSetEditBox,'fitsamples'})
            set(obj.h.edit.roi.sensitivity_1,'Callback',{@obj.guiSetEditBox,'sensitivity_1'})
            set(obj.h.edit.roi.sensitivity_2,'Callback',{@obj.guiSetEditBox,'sensitivity_2'})
            set(obj.h.edit.roi.sensitivity_3,'Callback',{@obj.guiSetEditBox,'sensitivity_3'})
            set(obj.h.edit.roi.offset,'Callback',{@obj.guiSetEditBox,'offset'})
            set(obj.h.edit.roi.updateEveryNframes,'Callback',{@obj.guiSetEditBox,'updateEveryNframes'})
              
            % arm help requests
            set(obj.h.panel.denoise,'HelpFcn', @(hobj,event) obj.getHelp('denoise'))
            set(obj.h.panel.roi,'HelpFcn', @(hobj,event) obj.getHelp('roi'))
            set(obj.h.panel.fit,'HelpFcn', @(hobj,event) obj.getHelp('fit'))
            set(obj.h.panel.moments,'HelpFcn', @(hobj,event) obj.getHelp('imageMoments'))
            set(obj.h.panel.center,'HelpFcn', @(hobj,event) obj.getHelp('imageTranslation'))
            
            % block program execution until this gui is closed/deleted
            waitfor(obj.h.fig)
        end
        
        function var = get.figexists(obj)
            var = false;
            if isfield(obj.h,'fig')
                if isvalid(obj.h.fig)
                    var = true;
                end
            end
        end
        
        function obj = getHelp(obj,type)
            % matlab TeX https://de.mathworks.com/help/matlab/ref/matlab.graphics.primitive.text-properties.html#budt_bq-1_sep_shared-Interpreter
            switch type
                case 'denoise'
                    msgbox({'\fontsize{11}{\bfMain}','\color{red}nstddev\color{black} - Determines how many standard deviations of the background noise is removed, cf. ISO11146-3 ch. 3.4.2, n <= 4.',...
                        '(with good SNR less is more!)','',...
                        '{\bfAdvanced}',['\color{red}FFT-Lowpass (not sanctioned by norm)\color{black} - Butterworth lowpass fixed at 0.7*Nyquist (DC is passthrough!). ',...
                        'Harmless for all measurements within ISO definition (i.e. minimum illuminated pixels according to norm...), but removes high frequency noise.'],...
                        '\color{red}2D Median Filter (not sanctioned by norm)\color{black} - should only be used with extremely bad SNR and lots of speckle noise, 1 means disabled.','',...
                        '{\bfBackground} - Addresses ISO11146-3 ch. 3 using custom implementation',...
                        ['\color{red}Assume tilted plane\color{black} - If enabled, background is assumed to be a tilted plane (happens w/ off-axis stray light), cf. ISO11146-3 eq. (54). ',...
                        'If disabled, background is an offset plane orthogonal to camera/XY plane, also known as DC-Offset.'],...
                        ['\color{red}[Samples,Algorithm]\color{black} - If background is tilted plane, then use max [samples] using [algorithm] to determine the background plane',...
                        ' which is then subsequently removed from the image. For online analysis performance <= 500 samples using Eigenvector method is recommended.'],...
                        },...
                        'analysisSettings','help',struct('Interpreter','tex','WindowStyle','modal'))                        
                case 'roi'
                    msgbox({'\fontsize{11}{\bfPreface}',...
                        '(As mentioned in ISO11146 ch. 7.2) The choice of integration limits/area can heavily influence the solution, as noise can dominate the result of the second moments.',...
                        'To that end the norm suggests an iterative scheme of varying integration limits until convergence is reached. The intent is that the solution converges if the signal (beam) is fully contained within the integration limits.',...
                        'However, it is easy to imagine, as well as experimentally generate, sufficiently compromised data/images in which this method is unreliable.','',...
                        ['This is also the reason why users don''t get the option to provide a background map in the "Standalone" GUI. Generating and subtracting a correct background map is not trivial,',...
                        ' and subtracting an inappropriate background map does more harm than good, to the point where it''s preferable to have complete data with bad SNR instead of compromised data with assumed good SNR.',...
                        ' [Standalone mode] If you know what you''re doing, subtract your background maps beforehand. In FokusPokus mode an appropriate background map is used.'],'',...
                        '{\bfguiROI}',...
                        ['If enabled, the user is prompted to define a rectangular ROI for each image. In the case of FokusPokus/online analysis mode the user defines the ROIs once and they will be used',...
                        ' for all subsequent frames unless both autoROI and guiROI are explicitly disabled in the analysisSettings.'],'',...
                        '{\bfautoROI}',...
                        ['Uses a radial integration scheme starting at the suspected centroid. Due to the integration this method is robust in the presence of noise.',...
                        ' The energy criterion \color{red}energy\color{black} is essentially the same merit as the norm suggests.',...
                        ' The gradient of the standard deviation \color{red}dev\color{black} of the values inside the integration region tend to zero in regions of homogeneous noise, i.e. outside of the region of interest.',...
                        ' The gradient of the integral \color{red}grad\color{black} is a robust criterion to detect changes in the signal, i.e. outside of the region of the signal (beam) this tends to zero.',...
                        ' Together, these criteria yield a robust and relatively efficent scheme for ROI-determination for practically all beam shapes in the presence of even heavy noise. All values except "offset" are specified in percent (0-100).'],...
                        '\color{red}During online analysis autoROI should be updated as often as necessary and as rarely as possible in order to reduce CPU time.\color{black}',...
                        },'analysisSettings','help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
                case 'fit'
                    msgbox({'\fontsize{11}{\bfweighted}',...
                        'Values are weighted such that x% error has an identical impact on the fit result regardless of its absolute value, cf. ISO11146-1 ch. 9, annotation 2 after eq. (29).',...
                        'If this is not done, measurements far from the waist dominate the result of the fit.','',...
                        '{\bfweightedVariance}',...
                        'If multiple measurements for a single location (z-Position) are available, their mean is taken and the fit can be weighted inverse proportional to the measurement uncertainty at that location, cf. ISO11146-1 ch. 9, annotation 3 after eq. (29).',...
                        'If not selected the mean is taken but all weights are unity. Locations which have only one associated measurement always get unit weight.','',...
                        '{\bffixEdgeCase}',['The definition of the principal axis direction ISO11146-1 eq. (15) along with the xy "flip" eq. (17-19) result in an ungraceful failure of the analysis following the ISO definition',...
                        ' in the special cirumstance of elliptic beam profiles oriented at +/- 45° w.r.t. the camera coordinate system in the presence of noise. What happens is an unintended mixing of the principal axes of the beam',...
                        ', subsequently leading to a fit result which is affected by the physical orientation of the measurement system relative to the incident beam. This setting resolves the issue.',...
                        ' The only reason why this setting can be disabled is because it is not {\itstandard} within ISO specification.']
                        },'analysisSettings','help',struct('Interpreter','tex','WindowStyle','modal'))
                case 'imageMoments'
                    msgbox({'\fontsize{10}The uncentered moments of order p,q for the Image with coordinates x,y and graylevel I(x,y) are defined as',...
                        '{\bfm_{p,q} = \int\int {x^{p}\cdoty^{q}\cdotI(x,y)}}.',...
                        'The 0_{th} moment is thus the sum of all graylevel values.',...
                        'The centroids are x_{c} = m_{1,0}/m_{0,0} and y_{c} = m_{0,1}/m_{0,0}.',...
                        'The centered 2nd moments can can be formulated as','',...
                        'm''_{2,0} = (m_{2,0}/m_{0,0}) - x_{c}^{2}, and',...
                        'm''_{0,2} = (m_{0,2}/m_{0,0}) - y_{c}^{2}, and',...
                        'm''_{1,1} = (m_{1,1}/m_{0,0}) - x_{c}\cdoty_{c}','',...
                        'The centered second moments (variances) define the covariance matrix of the 2D distribution',...
                        '{\bfcov(I(x,y)) = [m''_{2,0},m''_{1,1}; m''_{1,1},m''_{0,2}].}','Matrix cov(I(x,y)) is symmetric and (in general) non-diagonal. This matrix encodes the spread (variance) and orientation (covariance) of the data.',...
                        ['Disregarding special cases (1D-Distributions and 2D distributions with identical Eigenvalues), the covariance matrix expresses',...
                        ' the {\bforthogonal} and {\bfconclusive/unique} principal directions (cf. PCA), as well as extent (variance) of the data along those directions, however expressed in terms of the camera coordinate system.'],'',...
                        ['In the local coordinate system of the distribution (its orthogonal Eigenbasis defined by the Eigenvectors of cov(I(x,y)), the covariance matrix cov*(I(x,y)) is diagonal, i.e. has zero correlations with respect to different variables.',...
                        ', the xy-covariances vanish. The eigenvectors of cov(I(x,y)) correspond to the major and minor axes of the equivalent ellipse. The variances m*_{2,0} and m*_{0,2} of this diagonal covariance matrix define the extent of the orthogonal beam diameters per ISO11146 as 4 standard deviations in each principal axis, hence {\bfD4\sigma}.',...
                        ' As the covariances encode the orientation of the data, cov and cov* as well as cov and the reference coordinates is rotated by'],...
                        '{\bf\theta = 0.5\cdottan^{-1}[2\cdotm''_{1,1}/(m''_{2,0} - m''_{0,2})]}, which is the orientation of the ellipse major axis in the reference coordinates.','',...
                        ['{\bf\color{red}This definition works for ARBITRARY images/distributions and will ALWAYS yield "beam diameters".',...
                        ' \color{black}The "problem" with this definition \itin practice\rm\bf is its lack of robustness (lack of bias) in the presence of measurement uncertainty (noise).',...
                        ' As a result, post processing and good signal data is crucial. This includes an appropriate aberration free optical setup!}'],'',...
                        'moreover...if a part of the distribution I(x,y), i.e. its background, is instead interpreted as an unweighted point cloud [x,y,z], where x,y,z are column vectors, then {\bfsimilarly} its resulting [3x3] (centered) covariance matrix'...
                        ['{\bfcov([x,y,z]) = [x,y,z]^{t}\times[x,y,z]} (where t denotes transposition),',...
                        ' yields information of the orientation of the 3-D distribution. This is in fact the method used to (efficiently!) determine the tilted background offset plane.'],'',...
                        },'analysisSettings', 'help',...
                        struct('Interpreter','tex','WindowStyle','modal')); 
                case 'imageTranslation'
                    msgbox({'\fontsize{11}The images are centered based on the calculated FIRST moments such that no interpolation is required.',...
                        'Therefore the accuracy is limited to (2*pixelpitch^2)^{0.5} to reduce CPU load.',...
                        'This image-centering is only done in order to be able to approximately reconstruct the beam caustic along the beam axis for a 3D plot.'},...
                        'analysisSettings','help',...
                        struct('Interpreter','tex','WindowStyle','modal'))
            end
        end
        
        function guiSetPopup(obj,type)
            switch type
                case 'fitvariant'
                    obj.settings.denoise.fitvariant = obj.h.popup.denoise.fitvariant.String{obj.h.popup.denoise.fitvariant.Value};
                case 'ndev'
                    obj.settings.denoise.ndev = str2double(obj.h.popup.denoise.ndev.String{obj.h.popup.denoise.ndev.Value});
                case 'median'
                    obj.settings.denoise.median = str2double(obj.h.popup.denoise.median.String{obj.h.popup.denoise.median.Value});
                otherwise
                    error('Type %s undefined',type)
            end
            obj.updateStateOfGui();
        end
        
        function guiSetCheckBox(obj,type)
            switch type
                case 'debug-denoise'
                    obj.settings.denoise.debug = obj.h.chkBox.denoise.debug.Value;
                case 'debug-roi'
                    obj.settings.ROI.debug = obj.h.chkBox.roi.debug.Value;
                case 'debug-center'
                    obj.settings.center.debug = obj.h.chkBox.center.debug.Value;
                case 'debug-moments'
                    obj.settings.moments.debug = obj.h.chkBox.moments.debug.Value;
                case 'debug-all'
                    obj.settings.debugAll(obj.h.chkBox.denoise.debugALL.Value)
                case 'freqfilt'
                    obj.settings.denoise.freqfilt = obj.h.chkBox.denoise.freqfilt.Value;
                case 'removeplane'
                    obj.settings.denoise.removeplane = obj.h.chkBox.denoise.removeplane.Value;
                case 'guiROI'
                    obj.settings.ROI.guiROI = obj.h.chkBox.roi.guiROI.Value;
                case 'autoROI'
                    obj.settings.ROI.autoROI = obj.h.chkBox.roi.autoROI.Value;
                case 'shortCircuit'
                    obj.settings.ROI.shortCircuit = obj.h.chkBox.roi.shortCircuit.Value;
                case 'weighted'
                    obj.settings.fit.weighted = obj.h.chkBox.fit.weighted.Value;
                case 'weightedVariance'
                    obj.settings.fit.weightedVariance = obj.h.chkBox.fit.weightedVariance.Value;
                case 'fixEdgeCase'
                    obj.settings.fit.fixEdgeCase = obj.h.chkBox.fit.fixEdgeCase.Value;
                otherwise
                    error('Type %s undefined',type)
            end
            obj.updateStateOfGui();
        end
        
        function guiSetEditBox(obj,hobj,~,type)
            val = abs(str2double(hobj.String));
            if ~isfinite(val)
                obj.updateStateOfGui();
                return
            end
            switch type
                case 'fitsamples'
                    obj.settings.denoise.fitsamples = val;
                case 'sensitivity_1'
                    obj.settings.ROI.sensitivity(1) = val;
                case 'sensitivity_2'
                    obj.settings.ROI.sensitivity(2) = val;
                case 'sensitivity_3'
                    obj.settings.ROI.sensitivity(3) = val;
                case 'offset'
                    obj.settings.ROI.offset = val;
                case 'updateEveryNframes'
                    obj.settings.ROI.updateEveryNframes = val;
                otherwise
                    error('Type %s undefined',type)
            end            
            obj.updateStateOfGui();
        end
        
    end
    
    methods (Access = private)
        
        initfig(obj)
        updateStateOfGui(obj)
        
        function closeGui(obj)
            if obj.figexists
                delete(obj.h.fig)
            end
        end
        
    end
    
    methods (Access = private)
        
    end
    
    methods(Static, Access = private)
    end
    
end