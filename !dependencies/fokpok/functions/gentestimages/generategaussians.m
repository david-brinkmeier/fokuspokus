function imstack = generategaussians(cam,beam)
% generates beam caustic for processing
rangex = [-cam.pixelpitch*cam.pixels(1)/2, cam.pixelpitch*cam.pixels(1)/2];
rangey = [-cam.pixelpitch*cam.pixels(2)/2, cam.pixelpitch*cam.pixels(2)/2];

xaxis = rangex(1):cam.pixelpitch:rangex(2);
yaxis = rangey(1):cam.pixelpitch:rangey(2);

[Xgrid,Ygrid] = meshgrid(xaxis,yaxis);

% size of images, note matlab is column major -> [y x z]
lenX = length(xaxis); lenY = length(yaxis);

% fcn handle to compute planar intensity wedges / e.g simulate stray light
xwedge = @(val) val+(val/max(xaxis))*Xgrid;
ywedge = @(val) val+(val/max(yaxis))*Ygrid;

% initialize result array
imstack.img = inf([lenY, lenX, beam.len]);
imstack.pixelpitch = cam.pixelpitch;
imstack.wavelength = beam.wavelength;
imstack.axis.x = xaxis;
imstack.axis.y = yaxis;
imstack.axis.z = beam.z;

% fcn handle Elliptical gaussian
rotated_elliptical_gaussian = @(A,Xgrid,Ygrid) A(1)*exp( -2*(...
    ( Xgrid*cos(A(6))-Ygrid*sin(A(6)) - A(2)*cos(A(6))+A(4)*sin(A(6)) ).^2/(A(3)^2) + ...
    ( Xgrid*sin(A(6))+Ygrid*cos(A(6)) - A(2)*sin(A(6))-A(4)*cos(A(6)) ).^2/(A(5)^2) ) );

for i = 1:beam.len
    % parameters = [Amplitude,x_offset,w0x,y_offset,w0y,-rotation_angle*pi/180];
    parameters = [225,beam.offset(1,i),beam.wz(1,i),beam.offset(2,i),...
                  beam.wz(2,i),-beam.rotation_angle(i)*pi/180];
    profile = rotated_elliptical_gaussian(parameters,Xgrid,Ygrid);

    if cam.addnoise == 1
        profile = ShotAndReadNoise(profile,cam);
        profile(profile > 250) = 250;
    end
    
    if cam.wedge == true
       profile = profile + xwedge(randi([0,15])) + ywedge(randi([0,15]));
    end
    
    imstack.img(:,:,i) = profile;
end

end

function output_image = ShotAndReadNoise(input_image,cam)
quantum_well_depth = cam.quantum_well_depth; % configures poisson / shot noise [recommended: 1e1-1e5] (high - low)
sigma_read = cam.sigma_read; % configures readout noise / gaussian white noise [recommended: 0-50] (off - high)

input_image_photoelectrons = round(input_image*quantum_well_depth/2^8);

% shot noise
image_shot_noise = poissrnd(input_image_photoelectrons);
corrfact = max(abs(image_shot_noise(:)))/max(input_image(:));
image_shot_noise = image_shot_noise./corrfact;
% read noise
image_read_noise = sigma_read*randn(size(image_shot_noise));
read_bias = -min(image_read_noise(:));
image_read_noise = image_read_noise+read_bias;
% combined normalized
image_shot_noise_read_noise = image_shot_noise + image_read_noise;
corrfact = max(abs(image_shot_noise_read_noise(:)))/max(input_image(:));
image_shot_noise_read_noise = image_shot_noise_read_noise./corrfact;
% output
output_image = image_shot_noise_read_noise;

end