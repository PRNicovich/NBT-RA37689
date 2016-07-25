function resizeFig(figHand, newSize)
% Set size of figure.  Keeps figure center position in the same place

currPost = get(figHand, 'position');
currCenter = [currPost(1) + floor(currPost(3)/2), currPost(2) + floor(currPost(4)/2)];
newPost = [currCenter(1) - floor(newSize(1)/2), currCenter(2) - floor(newSize(2)/2)];

scrnSize = get(0, 'ScreenSize');
if (newPost(1)+newSize(1)) > (scrnSize(3) - 100)
    newPost(1) = scrnSize(3) - newSize(1) - 100;
end

if (newPost(2)+newSize(2)) > (scrnSize(4) - 100)
    newPost(2) = scrnSize(4) - newSize(2) - 100;
end


set(figHand, 'position', [newPost, newSize]);
