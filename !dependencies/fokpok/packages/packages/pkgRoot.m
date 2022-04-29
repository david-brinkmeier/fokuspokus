function folder = pkgRoot()
% helper function which returns the package root folder because
% matlab can't locate files in package folders (protected namespace)
%
% this is needed in essence to allow packaging dependencies of classes
% contained in a package within the same folder
% e.g. +pkg/@class/class.m has a dependency +pkg/@class/dependency.mat
% class.m cannot load dependency.mat because without the absolute path
% matlab can't find anything in the package folder until that code is
% executed, so this helper function returns the package root folder path so
% we can package dependencies in the same folder as the associated class inside
% a package and still load the depencies when required

folder = fileparts(mfilename('fullpath'));

end