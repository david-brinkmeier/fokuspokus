function [resultImg, filter] = butterworth(img, pixelpitch, order, f0, f1, filter)
% Copyright (c) 2022 David Brinkmeier
% davidbrinkmeier@gmail.com
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, subject to the following conditions:
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
% The Software is provided "as is", without warranty of any kind.
%%
% This function applies butterworth bandpass filter of order [order] to img
% pixelpitch is either 1 for pixel units / normalized or SI unis
% f0: Highpass passes all frequencies above f0
% f1: Lowpass passes all frequencies below f1
%
% resultImg is filtered image
% filter is fftshift(filter); to visualize use e.g. imagesc(fftshift(filter))
% filter is shifted output so that repeated operations can directly use the
% without having to fftshift(fft(img)) every time
% when img is a 3D array, then
%
% for normalized units (pixelpitch = 1) Nyquist criterion is f0 = 1/2
% for SI units Nyquist criterion is 1/(2*pixelpitch),
% bewware: removal of DC term is equal to removing mean(img(:)), resulting
% in potentially unphysical negative values in the output image

% check number of input arguments
narginchk(5,6);
% input must be 2D or 3D array
if ndims(squeeze(img)) > 3
    error('img must not exceed 3 dimensions')
end
% input could be [n,1] or [1,m] array...verify
if isvector(img)
    error('img must at least be a 2D array, i.e. [n,m] array where n,m > 1')
end
% if filter is supplied then directly apply filter to img IFF sizes match
calcfilter = true;
if nargin == 6 && isequal(size(img),size(filter))
    calcfilter = false;
end
% now calculate actual filter if required
if calcfilter
    % get size
    [szy,szx,szz] = size(img,1:3);
    % sampling frequency
    fsample = 1/pixelpitch;
    % calculate axes in frequency domain
    fx = fsample*(((1:szx)-(fix(szx/2)+1))/szx); % -fs/2 to fs/2!
    fy = fsample*(((1:szy)-(fix(szy/2)+1))/szy); % -fs/2 to fs/2!
    % generate frequency meshgrid and get absolute frequency array
    [fxgrid,fygrid] = meshgrid(fx,fy);
    frequency = sqrt(fxgrid.^2 + fygrid.^2);
    % create filter; lowpass
    filter = 1 ./ (1 + (frequency ./ f1).^(2*order));
    if f0 ~= 0
        % if f0 = 0 then highpass is ALL frequencies
        % since f0 > 0 then highpass is not all ones, calculate highpass..
        highpass = 1 - (1 ./ (1 + (frequency ./ f0).^(2*order)));
        % pointwise multiplication of lowpass and highpass = bandpass
        filter = highpass.*filter;
    end
    % fftshift now
    filter = fftshift(filter);
    % repmat along 3rd dimensions if img is imagestack
    if szz > 1
        filter = repmat(filter,[1 1 size(img,3)]);
    end
end
% apply filter to fft(img), make ifft2 and enforce real input = real output
resultImg = ifft2(fft2(img).*filter,'symmetric');
% positivity constraint
resultImg(resultImg < 0) = 0;
end
