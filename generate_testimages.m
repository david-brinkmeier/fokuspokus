clearvars
clc
close all

%% This script generates images for simulated (simple astigmatic )gaussian beam caustics
% simulate camera recording, add noise, evaluate impact of pixelpitch, etc.
% results are stored to \export\#exeriment#

% Grid and pixel pitch
cam.pixelpitch = 5.*1e-6; % in µm
cam.pixels = 300 * [1,1]; % must be even
cam.sensorsize = cam.pixels*cam.pixelpitch; % rectangular region
cam.addnoise = 0; % 0 or 1 to enable/disable noise
cam.wedge = 0; % if 1 then add a stray light "wedge" plane DC offset
cam.quantum_well_depth = 5e2; % models poisson noise; large values less noise
cam.sigma_read = 0.5; % models (gaussian) AC-DC read noise -- 0-100

% functions required for beam specification (dont touch)
% beam.anonfuns.zR = @(beam,idx) pi*beam.w0(idx).^2/(beam.wavelength*beam.msquared(idx)); % rayleigh length, paraxial
beam.anonfuns.zR = @(beam,idx) 2*beam.w0(idx)/tan((beam.msquared(idx)*4*beam.wavelength)/(2*beam.w0(idx)*pi)); % rayleigh length
beam.anonfuns.wz = @(beam,idx) beam.w0(idx).*sqrt(1+((beam.z-beam.z0(idx))./beam.zR(idx)).^2); % beam radius as function of propagation length

% beam z position specifications
beam.z = linspace(-10000,10000,25).*1e-6; % evaluation positions (scalar or vector)
% beam.z = [-5000 -4000 -3000 -2500 -1500 -1000 -500 -250 -50 -25 25 50 250 500 1000 1500 2500 3000 4000 5000].*1e-6; % evaluation positions (scalar or vector)
% beam.z = repelem([-5000 -4000 -3000 -2500 -1500 -1000 -500 -250 -50 -25 25 50 250 500 1000 1500 2500 3000 4000 5000],3).*1e-6; % evaluation positions (scalar or vector)
% beam.z = [-5000 -4000 -3000 -2500 repelem(-1500,5) -1000 -500 -250 -50 -25 25 repelem(50,8) 250 500 1000 1500 repelem(2500,5) 3000 4000 5000].*1e-6; % evaluation positions (scalar or vector)
beam.wavelength = 1030e-9; % 1030 nm
beam.msquared = [2.5, 1.5]; % x and y
beam.z0 = [0, -1000]*1e-6; % x and y
beam.w0 = [80, 40]*0.5*1e-6; % x and y focus beam radius size, this variant assumes that these are minimal diameters during experiment
beam.zR = [beam.anonfuns.zR(beam,1), beam.anonfuns.zR(beam,2)]; % x and y
beam.wz = [beam.anonfuns.wz(beam,1); beam.anonfuns.wz(beam,2)]; % first row x, second row y
% beam.wz = [beam.anonfuns.wz(beam,1); beam.anonfuns.wz(beam,2)].*((1.1-0.9).*rand([2,length(beam.z)])+0.9); % randomize (not phyiscal)
beam.len = length(beam.z); % helper variable
beam.offset = 0 * [randn(1,beam.len); randn(1,beam.len)].*1e-6; % spatial offset, can be vector (first row x, second row y)
beam.rotation_angle = repelem(-30,beam.len); % can be vector of length beam.z
% beam.rotation_angle = repelem(-20,beam.len).*(1-0.5*randn(1,beam.len)); % can be vector of length beam.z

gaussians = generateprofiles(cam,beam);

clf
hs = surf(gaussians.axis.x*1e6,gaussians.axis.y*1e6,gaussians.img(:,:,1));
ht = title(sprintf('z = %.0f µm',beam.z(1)*1e6));
view(2), shading interp, axis equal, axis tight, colormap turbo
for i = 1:size(gaussians.img,3)
    hs.ZData = gaussians.img(:,:,i);
    ht.String = sprintf('z = %.0f µm',beam.z(i)*1e6);
    drawnow
end

%% IMG EXPORT
export_folder = [pwd,'\export\',datestr(now,'yyyymmdd_HHMM.SS')]; %#ok<TNOW1>
mkdir(export_folder);
fid = fopen(sprintf('%s\\1_pixelpitch_%.2f_µm.txt',export_folder,cam.pixelpitch*1e6),'at'); % open mode append and text mode
fclose(fid);

for i = 1:size(gaussians.img,3)
    current_img = gaussians.img(:,:,i);
    unique_str = char(java.util.UUID.randomUUID);
    unique_str = unique_str(isstrprop(unique_str,'alpha'));
    unique_str = regexprep(unique_str,'^.{0,2}(.{0,6}).*$','$1');
    imwrite(uint8(current_img),[export_folder,sprintf('\\%i_%s.png',round(beam.z(i)*1e6),unique_str)]);
end

%% FCNs that actually generate each profile, add noise etc.
function gaussians = generateprofiles(cam,beam)
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
gaussians.img = inf([lenY, lenX, beam.len]);
gaussians.pixelpitch = cam.pixelpitch;
gaussians.wavelength = beam.wavelength;
gaussians.axis.x = xaxis;
gaussians.axis.y = yaxis;
gaussians.axis.z = beam.z;

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
    
    gaussians.img(:,:,i) = profile;
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