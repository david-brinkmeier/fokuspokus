% This sample script is intended to guide user through analysis of data which
% is neither a fixed set of images nor analyzed using the FokusPokus setup.

%% add dependencies to path
addpath(genpath('!dependencies'))

%% initialize
if ~exist('imstack','var')
    imstack = imgstack.imstack();
end

%% change plot settings using gui
fokpokgui.plotSettings(imstack.figs.plot1.settings)
% fokpokgui.plotSettings(imstack.figs.plot2.settings)
% fokpokgui.plotSettings(imstack.figs.plot3.settings)
% fokpokgui.plotSettings(imstack.figs.plot4.settings)

%% change analysis settings using gui
% (there are even more settings available through CLI)
fokpokgui.analysisSettings(imstack.settings);

%% ---------------------- LOAD YOUR DATA ----------------------
% 0) research the pixelpitch of your camera system
% 1) generate a vector of unique z-positions that correspond to each image
% 2) from your videos/images generate a 3D stack (:,:,Zpos), i.e. a 3D
% array whose 3rd dimension corresponds to the z-Position defined by your
% vector 1).
% Note that X/Y dimensions of 3D array must be of odd length.
% Images must be finite, nonzero and positive.

%% Assign required values, NOTE: ALL UNITS SI-Units [m].
% In fact the only units used in the code (except for plots) are exlusively
% SI-Units [m,rad] and normalized units (pixel-units).

imstack.wavelength = yourLaserWavelength;
imstack.zPos = yourZpositionVector;
imstack.pixelpitch = yourPixelpitch;

%% Declare an output folder for your results. The following will prompt a request upon first call.
imstack.workingFolder;

%% Initialize the results structure.
results = imgstack.aioResults(imstack);

%% Process your images / loop over the frames of your video
imstack = imstack.resetCounter(); % optional, but required to start counting at 1 after repeated calls to imstack.process()

for i = 1:frames
    currentimageStack = yourImageStack(i); % for readability, load this from your data
    imstack.time = time(i); % optional, assign timestamp for this frame
    imstack = imstack.process(currentimageStack); % make actual calculations
    results = results.record(imstack); % record current state
end

imstack.plotCallbacks(1); % this enables the scrolling functionality of plot3/4

%% export results to imstack.workingFolder
results = results.exportResults();
