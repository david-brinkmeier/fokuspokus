function [processed_img,data] = rmbackground(img,logmask,settings)
% INPUTS
% ------------------------------------------------------------------------
% img: 2D image
% logmask: 2D image / logical array of size(image)
% settings is struct with settings.fitsamples = num
%                         settings.fitvariant = 'eig' or 'svd'
%                         settings.removeplane = 'true' or 'false' (false implies plane is perpendicular to xy plane)
%                         settings.ndev = 0...4 remove 0..4 stddevs from img
%                         settings.debug = 'true' or 'false' disables/enables generation of data struct
%
%
% DESCRIPTION
% ------------------------------------------------------------------------
% This function takes an Image and a logical mask of the same size.
% values of img, as specified in logmask, are assumed to lie in a plane.
% This plane is subtracted from the image. Furthermore n standard deviations
% of the values inside logmask AFTER plane correction is removed as suggested in ISO11146.
% The image is assumed to contain intensities which cannot be negative, therefore
% a positivity contraint is enforced, i.e. values below zero are set to zero.
%
%
% DOCUMENTATION / LINKS
% ------------------------------------------------------------------------
% LEAST SQUARE PLANE OF POINT CLOUD VIA SVD
% https://math.stackexchange.com/questions/2378198/computing-least-squares-error-from-plane-fitting-svd
% https://math.stackexchange.com/questions/2810048/plane-fitting-using-svd-normal-vector
% -- tldr --
% third column of the right singular vectors is the normal of the plane in
% the last squares sense to the (centered) point cloud ([x,y,z]-center);

% GET PLANE VALUES
% normal vector n of the plane is (A,B,C), the plane is given by
% Ax + By + Cz + d = 0
% we know that the normal n and the centroid p satisfy this eq.
% therefore we know that n*p + d = 0; and thus d = -n*p;
% hence, solving Ax + By + Cz + d = 0 for z gives
% z = -(Ax + By + d) / C
%
% alternatively one could solve
% A(x-xc) + B(y-yc) + C(z-zc)  = 0
% for z, which is -((A*(x-xc) + B.*(y-yc))/C) + zc;
% i.e. lsqplane = -((normal(1).*(xx-centroid(1)) + normal(2).*(yy-centroid(2)))/normal(3)) + centroid(3);
% ------------------------------------------------------------------------

% internal debug flags / error check
internaldebug = false; % set true to force debug plots
if ~isequal(size(img),size(logmask))
    error('Img and logmask passed to rmbackground must be of the same size.')
end

% get img spec
[leny,lenx] = size(img);
% generate meshgrid, required to evaluate plane later
[xx,yy] = meshgrid(1:lenx,1:leny);
% grab all indices relevant for the fit
idx = find(logmask);
idx_sampled = 1:length(idx);
% if removeplane enabled limit number of samples if beyond limit
if settings.removeplane && (length(idx) > settings.fitsamples)
    % randomly select settings.limitfitsamples from idx
    % i.e. undersample idx to decrease cpu time
    idx_sampled = randperm(length(idx),settings.fitsamples);
end
% grab corresponding x/y positions
[y,x] = ind2sub(size(img), idx);
% grab z "positions" / intensity values
z = img(idx);

if settings.removeplane == true
    % get a known point on the plane, e.g. center of the points in the mask
    center = mean([x(idx_sampled),y(idx_sampled),z(idx_sampled)],1);
    switch lower(settings.fitvariant)
        case 'eig'
            % VARIANT: Eigenvector of covariance matrix corresponding to smallest Eigenvalue
            % --- FASTER THAN SVD ---
            % get principal directions as eigenvectors of the centered covariance matrix
            A = [x(idx_sampled),y(idx_sampled),z(idx_sampled)]-center;
            [V,D] = eig(A'*A); % this is equal to eig(cov(A))
            % plane normal is eigenvector corresponding to the smallest eigenvalue -> sort based on eigenvalues
            [~,sorted] = sort(diag(D));
            % sort eigenvectors
            V = V(:,sorted);
            % get normal vector
            normal = V(:,1);
            
        case 'svd'
            % VARIANT SVD: right singular vector is plane normal
            % its squared singular value is the residual of the fit, but we don't care about it
            % (i.e. When s is the singular value, ||A-A_est||^2 = s^2, where A are the values, A_est the plane
            % and ||M|| is the norm(M,'fro') or sqrt(sum(M(:).^2))
            % get right singular vectors of mean centered SVD
            [~,~,V] = svd([x(idx_sampled),y(idx_sampled),z(idx_sampled)]-center);
            % third column of the right singular vectors is the normal of the least square plane to the points
            normal = V(:,3);
            
        otherwise
            error('settings.variant must be either "eig" or "svd"');
    end
    
    % calculate least squares plane so we can subtract from image
    d = -dot(normal,center);
    lsqplane = -(normal(1).*xx + normal(2).*yy + d)/normal(3);
    % get the standard deviation of the relevant values inside the mask AFTER the plane correction
    stddev = std(z-lsqplane(idx)); % note: z is already z(idx), cf. line 68
    % subtract plane from image and subtract n standard devs
    processed_img = img - lsqplane - settings.ndev*stddev;
else
    % get a known point on the plane, e.g. center of the points in the mask
    center = mean([x,y,z],1);
    % assume constant DC offset based on mask values / "constant level plane" in z direction
    normal = [0;0;1]; % only needed for plot of plane
    d = -dot(normal,center); % only needed for plot of plane
    lsqplane = mean(z); % then the plane is just a constant value everywhere...
    stddev = std(z-mean(z));
    processed_img = img - lsqplane - settings.ndev*stddev;
end

% enforce positivity constraint, negative energy not allowed bc not physical
processed_img(processed_img < 0) = 0;
% DONE!

%% if debug is on then all relevant plotdata is returned
if settings.debug
    data = struct(); % this contains plot / debug data if requested
    data.normal.str = sprintf('abs(n) = [%.2g,%.2g,%.2g]',abs(normal)); % for title dont care about signs
    data.normal.vect = normal; % x=y=0 means only DC offset w/o intensity wedge
    
    data.points.x = x(idx_sampled); % use for scatter of pts
    data.points.y = y(idx_sampled); % use for scatter of pts
    data.points.z = z(idx_sampled); % use for scatter of pts
    
    data.vertices.x = [1,lenx,lenx,1] + 0.*[-1,1,1,-1]; % Generate data for x vertices
    data.vertices.y = [1,1,leny,leny] + 0.*[-1,-1,1,1]; % Generate data for y vertices
    data.vertices.z = -(normal(1).*data.vertices.x...
        + normal(2).*data.vertices.y + d)/normal(3); % Solve plane for z vertices data
    
    linepts = (max(z)-min(z))*[-.25,.25].*normal + center.';
    data.normal.line.x = linepts(1,:); % use for plotting the normal vector through the plane
    data.normal.line.y = linepts(2,:); % use for plotting the normal vector through the plane
    data.normal.line.z = linepts(3,:); % use for plotting the normal vector through the plane
    
    data.img = img; % main img and associated stuff
    dz = max(img(:))-min(img(:));
    data.daspect{1} = [1, 1, 3*dz/(max(size(img,1:2)))]; % for input+plane
    data.caxis{1} = [0, max(img(:))];
    
    data.img_processed = processed_img; % processed img and associated stuff
    dz = max(processed_img(:))-min(processed_img(:));
    data.daspect{2} = [1, 1, 3*dz/(max(size(processed_img,1:2)))]; % for output processed w/o plane
    data.caxis{2} = [0, max(processed_img(:))];
    
    cmap = jet(255); cmap(1,:) = ones(1,3);
    data.colormap{1} = jet(255);
    data.colormap{2} = cmap;
    data.colormap{3} = cmap;
    
    data.xlims{1} = [min(data.vertices.x), max(data.vertices.x)];
    data.ylims{1} = [min(data.vertices.y), max(data.vertices.y)];
    data.xlims{2} = [1, size(img,2)];
    data.ylims{2} = [1, size(img,1)];
else
    data = [];
end

if internaldebug == true
    figure;
    % least square plane and the fit points
    subplot(1,3,1)
    scatter3(data.points.x,data.points.y,data.points.z,30,data.points.z,...
        'filled','MarkerEdgeColor','none','MarkerFaceAlpha',0.5)
    axis image, hold on, box on
    patch(data.vertices.x, data.vertices.y, data.vertices.z, 'k', 'FaceAlpha', .4);
    plot3(data.normal.line.x,data.normal.line.y,data.normal.line.z,'-.k','Linewidth',2)
    daspect([1 1 1]), colormap(data.colormap{1})
    xlabel('x [pixel]'), ylabel('y [pixel]'), zlabel('z [energy, a.u.]')
    title({'bg plane',data.normal.str})
    % input image and the least square fit plane
    subplot(1,3,2)
    surf(data.img), shading flat, box on
    patch(data.vertices.x, data.vertices.y, data.vertices.z, 'm', 'FaceAlpha', .5);
    xlim(data.xlims{1}), ylim(data.ylims{1})
    caxis(data.caxis{1}), colormap(data.colormap{2})
    daspect(data.daspect{1})
    xlabel('x [pixel]'), ylabel('y [pixel]'), zlabel('z [energy, a.u.]')
    title('input vs. bg plane')
    % beam after plane correction and removal of stddev + pos. constraint
    subplot(1,3,3)
    surf(data.img_processed), shading flat, box on
    xlim(data.xlims{2}), ylim(data.ylims{2})
    caxis(data.caxis{2}), colormap(data.colormap{3})
    daspect(data.daspect{2})
    xlabel('x [pixel]'), ylabel('y [pixel]'), zlabel('z [energy, a.u.]')
    title('input-(bgplane+n*std)')
end
end