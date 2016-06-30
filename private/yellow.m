function Y = yellow(m)
%YELLOW  Yellow Colormap
%   YELLOW(M) is an M-by-3 matrix colormap for increasing yellow intensity.
%   YELLOW, by itself, is the same length as the current figure's
%   colormap. If no figure exists, MATLAB creates one.
%
%   See also GREEN, RED, JET, HSV, HOT, PINK, FLAG, COLORMAP, RGBPLOT.


if nargin < 1
   m = size(get(gcf,'colormap'),1);
end

Y = zeros(m,3);
Y(:,[1 2]) = repmat((0:(1/(m-1)):1), 2, 1)';