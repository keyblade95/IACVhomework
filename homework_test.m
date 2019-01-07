%%  IMAGE ANALYSIS & COMPUTER VISION HOMEWORK
%   Federico Parroni 10636497
%   

close all; clear all; clc;
warning('off', 'images:initSize:adjustingMag');

%% 1. Ellipsis detection
% Load the original image and compute the normalization factor and matrix
% to bring coordinates in the interval [0,1]
original_im = imread('Image2.jpg');

norm_f = max((size(original_im)));
norm_mx = diag([1/norm_f, 1/norm_f, 1]);

maxw = length(original_im) * 1.2;   % used to draw lines over the image

%figure(); imshow(original_im); title('Original image');

%% 1.1 Preprocess the original image
% As first, enhance the contrast of the image by remapping pixels
% intensities. We will apply 2 different filters to detect both wheels of
% the car
gray_im = rgb2gray(original_im);
scale_factor = 4;
resized_gray_im = imresize(gray_im, 1/scale_factor);

%%
% Filter 1
imf1 = resized_gray_im;
threshold = adaptthresh(imf1, 0.7, 'NeighborhoodSize',19);
imf1 = imbinarize(imf1, threshold);
imf1 = edge(imf1,'Canny',0.95);

s1 = regionprops(imf1, {'Centroid','MajorAxisLength','MinorAxisLength','Orientation'});
s1 = s1(arrayfun(@(x) x.MajorAxisLength > 100 && x.MajorAxisLength < 110 ...
                      && x.MinorAxisLength > 30 && x.Orientation > 70, s1));
% fix
s1.Centroid(1) = s1.Centroid(1) + 1;
s1.Centroid(2) = s1.Centroid(2) - 7;
s1.Orientation = s1.Orientation + 2;
s1.MajorAxisLength = s1.MajorAxisLength - 5;
s1.MinorAxisLength = s1.MinorAxisLength - 7;

% t = linspace(0,2*pi,60);
% ellipsis = s1;
% figure(); imshow(resized_gray_im);
% for k=1:length(ellipsis)
%     drawEllipse(ellipsis(k),t);
% end

%%
% Filter 2
imf2 = imbinarize(resized_gray_im,'adaptive');
imf2 = imdilate(imf2, strel('disk',2,8));
s2 = regionprops(imf2, {'Centroid','MajorAxisLength','MinorAxisLength','Orientation'});
s2 = s2(arrayfun(@(x) x.MajorAxisLength < 170 && x.MajorAxisLength > 150 && x.MinorAxisLength > 60, s2));

%%
% Draw the ellipsis of interest
t = linspace(0,2*pi,60);
ellipsis = [s1; s2];
figure(); imshow(resized_gray_im); title('Ellipsis of interest');
for k=1:length(ellipsis)
    drawEllipse(ellipsis(k),t);
    % normalize the ellipsis
    ellipsis(k).Centroid = ellipsis(k).Centroid / norm_f * scale_factor;
    ellipsis(k).MajorAxisLength = ellipsis(k).MajorAxisLength / norm_f * scale_factor;
    ellipsis(k).MinorAxisLength = ellipsis(k).MinorAxisLength / norm_f * scale_factor;
end
clear s1; clear s2; clear t;

%% 2.1 Determine the ratio between the diameter of the wheel circles and the wheel-to-wheel distance 
%
wheel_ant = ellipsis(1);
wheel_post = ellipsis(2);
wheel_ant_coeffs = ellipseCoeff(wheel_ant);
wheel_post_coeffs = ellipseCoeff(wheel_post);
% Find the dual conics, inverting the matrices of the conics
dual_wheel_ant_coeffs = conicCoeffFromMatrix(inv(conicMatrixFromCoeff(wheel_ant_coeffs)));
dual_wheel_post_coeffs = conicCoeffFromMatrix(inv(conicMatrixFromCoeff(wheel_post_coeffs)));

% Get the 4 tangent lines and plot them with different colors
tangent_lines = intersectsconics(dual_wheel_ant_coeffs,dual_wheel_post_coeffs);
% Plot the 4 tangent lines
figure(); imshow(gray_im);
styles=['r-','m-','b-','y-']; widths=[1 2 2 1];
for k=1:length(tangent_lines)
    line = [tangent_lines(k,:), 1] * norm_mx;
    plotLine(line,[0 maxw], styles(k), widths(k));
end
clear line; clear styles; clear widths; clear k;

%% 2.1.1 Intersect lines and conics
% Intersects lines and conics
uppertangentline = [tangent_lines(2,:), 1];
lowertangentline = [tangent_lines(3,:), 1];
upperwheelpoint1 = real(intersectsconics(wheel_post_coeffs, [0 0 0 uppertangentline]));
lowerwheelpoint1 = real(intersectsconics(wheel_post_coeffs, [0 0 0 lowertangentline]));
upperwheelpoint2 = real(intersectsconics(wheel_ant_coeffs, [0 0 0 uppertangentline]));
lowerwheelpoint2 = real(intersectsconics(wheel_ant_coeffs, [0 0 0 lowertangentline]));
% Take only one of the 2 identically tangent points (molteplicity 2)
upperwheelpoint1 = upperwheelpoint1(1,:);
lowerwheelpoint1 = lowerwheelpoint1(1,:);
upperwheelpoint2 = upperwheelpoint2(1,:);
lowerwheelpoint2 = lowerwheelpoint2(1,:);
% Get vertical lines through tangency points of each wheel
line_vert_post_wheel = cross([lowerwheelpoint1, 1],[upperwheelpoint1, 1]);
line_vert_ant_wheel = cross([lowerwheelpoint2, 1],[upperwheelpoint2, 1]);
% Get the vanishing points
vanish_pointz = cross(uppertangentline, lowertangentline);
vanish_pointz = vanish_pointz / vanish_pointz(3);
vanish_pointz = vanish_pointz.';
vanish_pointy = cross(line_vert_post_wheel, line_vert_ant_wheel);
vanish_pointy = vanish_pointy / vanish_pointy(3);
vanish_pointy = vanish_pointy.';
% Get the 4 intersection points
middle_point = cross( [tangent_lines(1,:), 1], [tangent_lines(4,:), 1] );
middle_point = middle_point / middle_point(3);
middle_line = cross( vanish_pointz, middle_point' ).';
post_wheel_points = intersectsconics(wheel_post_coeffs, [0 0 0 middle_line]);
ant_wheel_points = intersectsconics(wheel_ant_coeffs, [0 0 0 middle_line]);

% Plot all tangency and vanishing points and lines
hold on;
plot(upperwheelpoint1(1)*norm_f,upperwheelpoint1(2)*norm_f,'m^','MarkerSize',6,'HandleVisibility','off');
plot(lowerwheelpoint1(1)*norm_f,lowerwheelpoint1(2)*norm_f,'m^','MarkerSize',6,'HandleVisibility','off');
plot(upperwheelpoint2(1)*norm_f,upperwheelpoint2(2)*norm_f,'m^','MarkerSize',6,'HandleVisibility','off');
plot(lowerwheelpoint2(1)*norm_f,lowerwheelpoint2(2)*norm_f,'m^','MarkerSize',6,'HandleVisibility','off');
plot(middle_point(1)*norm_f,middle_point(2)*norm_f,'r^','MarkerSize',6,'HandleVisibility','off');
plot(vanish_pointz(1)*norm_f,vanish_pointz(2)*norm_f,'b*','MarkerSize',6,'HandleVisibility','off');
plot(vanish_pointy(1)*norm_f,vanish_pointy(2)*norm_f,'b*','MarkerSize',6,'HandleVisibility','off');
plot(ant_wheel_points(1,1)*norm_f,ant_wheel_points(1,2)*norm_f,'r*','MarkerSize',6,'HandleVisibility','off');
plot(ant_wheel_points(2,1)*norm_f,ant_wheel_points(2,2)*norm_f,'r*','MarkerSize',6,'HandleVisibility','off');
plot(post_wheel_points(1,1)*norm_f,post_wheel_points(1,2)*norm_f,'r*','MarkerSize',6,'HandleVisibility','off');
plot(post_wheel_points(2,1)*norm_f,post_wheel_points(2,2)*norm_f,'r*','MarkerSize',6,'HandleVisibility','off');
plotLine(line_vert_post_wheel * norm_mx, [0 maxw],'-',2);
plotLine(line_vert_ant_wheel * norm_mx, [0 maxw],'-',2);

% Get the image of the line at the infinity
inf_point1 = cross( lowertangentline, uppertangentline );
inf_point2 = cross( line_vert_post_wheel, line_vert_ant_wheel );
line_infinity = cross( inf_point1, inf_point2 );
plotLine(line_infinity * norm_mx, [0 maxw], '-', 2);
% Get the image of the circular points by intersecting the ellipsis and the
% line at the infinity
circ_point1 = intersectsconics(wheel_post_coeffs, [0 0 0 line_infinity]);
circ_point2 = intersectsconics(wheel_ant_coeffs, [0 0 0 line_infinity]);
circ_points = (circ_point1 + circ_point2) ./ 2;
legend('line1','line2','line3','line4', 'vertical1','vertical2', 'infinity');
hold off;

%% 2.1.2 Rectify the image using the image of the degenerate dual conic
% The image of the degenerate dual conic can be computed by multiplying the
% images of the circular points:
% 
% $\omega_{\infty} = I*J' + J*I'$
% 
I = [circ_points(1,:)'; 1];
J = [circ_points(2,:)'; 1];
image_dual_conic = I*J.' + J*I.';
% When we have w, we can find the homography using SVD
[~, DC, H] = svd(image_dual_conic);
normalization = sqrt(DC); normalization(3,3)=1;
H_n = normalization * H;
H = inv(H_n);

% Find the rectified intersection wheel points
a = H \ [post_wheel_points(2,:), 1]'; a = a/a(3);
b = H \ [post_wheel_points(1,:), 1]'; b = b/b(3);
c = H \ [ant_wheel_points(2,:), 1]'; c = c/c(3);
d = H \ [ant_wheel_points(1,:), 1]'; d = d/d(3);

% Compute the ratio distance - diameter from the rectified points
ratio = norm( a-b, 2) / norm( a-c, 2)


%% 2.2 Camera calibration
figure(); imshow(original_im);

%% 2.2.1 Find another vanishing point
% Take 4 feature points beloging to parallel lines in order to find the
% last vanishing point
plate_point1 = [1047, 1939, 1];
plate_point2 = [733, 1725, 1];

stop_point1 =  [1692, 1213, 1];
stop_point2 =  [705, 820, 1];

line_lights = cross( stop_point1 * norm_mx, stop_point2 * norm_mx );
line_plate = cross( plate_point1 * norm_mx, plate_point2 * norm_mx );

plotLine(line_lights * norm_mx, [-maxw maxw],'g-',2);
plotLine(line_plate * norm_mx, [-maxw maxw],'g-',2);
hold on;
vanish_pointx = cross( line_lights, line_plate );
vanish_pointx = vanish_pointx.' / vanish_pointx(3);
plot(vanish_pointx(1)*norm_f,vanish_pointx(2)*norm_f,'b*','MarkerSize',6,'HandleVisibility','off');

%% 2.2.2 Compute K from w
% Get the image of the absolute conic (w) from the constraints on
% orthogonal directions
syms fx, syms fy, syms u0, syms v0;
K = [fx, 0, u0; ...
     0, fy, v0; ...
     0, 0, 1];
w_dual = K*K.';
w = inv(w_dual);
eqs = [ vanish_pointz.' * w * vanish_pointy;
        vanish_pointz.' * w * vanish_pointx;
        vanish_pointy.' * w * vanish_pointx;
        [circ_points(1,:) 1] * w * [circ_points(1,:) 1].';
      ];
res = solve(eqs);
fx = real(double(res.fx)); fx = fx(fx > 0); fx = fx(1);
fy = real(double(res.fy)); fy = fy(fy > 0); fy = fy(1);
u0 = real(double(res.u0)); u0 = u0(1);
v0 = real(double(res.v0)); v0 = v0(1);
clear K, clear eqs, clear res;
% Print the matrix K (normalized)
K = [fx, 0, u0; ...
     0, fy, v0; ...
     0, 0, 1]

