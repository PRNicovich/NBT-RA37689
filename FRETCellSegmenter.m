% FRETCellSegmenter - GUI cell outline segmenter with ratiometric output
% View and edit parameters for tracking of vesicles in two-channel 
% images with comparison of particle number over time and cross-channel
% nearest-neighbor distances between detected particles.
%
%
% Requires:
% Vector2Colormap
% freezeColors
% Vector2Colormap_setscale
% CZIImport

function FRETCellSegmenter

% Close out previous windows so no two are open at same time
close(findobj('Tag', 'TIFF viewer'));


scrsz = get(0,'ScreenSize');

Window_size = [150 100 690 690];


fig1 = figure('Name','FRET Cell Segmenter', 'Tag', 'TIFF viewer', 'Units', ...
    'normalized','Position',[Window_size(1)/scrsz(3) Window_size(2)/scrsz(4) Window_size(3)/scrsz(3) Window_size(4)/scrsz(4)], ...
    'NumberTitle', 'off', 'MenuBar', 'none', 'Toolbar', 'figure');
set(fig1, 'Color',[0.9 0.9 0.9]);

%%%%%%%%%%%%
% Set up toolbar
hToolbar = findall(fig1,'tag','FigureToolBar');
AllToolHandles = findall(hToolbar);
ToolBarTags = get(AllToolHandles,'Tag');
ToolsToKeep = {'FigureToolBar'; 'Exploration.DataCursor'; 'Exploration.Pan'; 'Exploration.ZoomOut'; 'Exploration.ZoomIn'};
WhichTools = ~ismember(ToolBarTags, ToolsToKeep);
delete(AllToolHandles(WhichTools));



%'Colormap', [1 1 1]);
% Yields figure position in form [left bottom width height].

fig1_size = get(fig1, 'Position');
set(fig1, 'DeleteFcn', @GUI_close_fcn);

bkg_color = [.9 .9 .9];

handles.handles.fig1 = fig1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize GUI data
handles.Load_file = '';
handles.N_frames = 2;
handles.N_channels = 2; % 1 or 2 for single, double channel data
handles.Primary_channel = 1;
handles.Img_stack = [];
handles.Left_color = 'cyan';
handles.Right_color = 'red';
handles.Load_file = [];
handles.Left_invert = 0;
handles.Right_invert = 0;
handles.scrsz_pixels = get(0, 'ScreenSize');
handles.Autoscale_left = 0;
handles.Autoscale_right = 0;
handles.Min_max_left = [1 255];
handles.Min_max_right = [1 255];
handles.Display_range_left = [0 1];
handles.Display_range_right = [0 1];
handles.Display_range_ROI = [0 1];

handles.BackgroundChannel = 1;
handles.BackgroundThreshold = 12;
handles.ErodeDiameter = 10;

handles.CenterChannel = 3;
handles.CenterIntensity = 20;
handles.FindCtrDilateDiameter = 5;

handles.PixelSize = 0.062; 

handles.SelectedFiles = [];
handles.ColorList = jet(20);
handles.ColorList = handles.ColorList(randperm(size(handles.ColorList, 1)), :);

handles.FRETAcceptorChannel = false;
handles.FRETDonorChannel = true;

guidata(fig1, handles);

Startup;

    function Startup(varargin)
        
        handles = guidata(fig1);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Define panels.  

        fig1_size_pixels = fig1_size.*scrsz;

        panel_border = fig1_size_pixels(4)/max(fig1_size_pixels);

        butt_panel = uipanel(fig1, 'Units', 'normalized', 'Position', [0 .95, 1, .05], ...
            'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'button_panel');

        ax_panel1 = uipanel(fig1, 'Units', 'normalized', 'Position', [0 .45 .5 .5], ...
            'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'axes_panel1');

        ax_panel2 = uipanel(fig1, 'Units', 'normalized', 'Position', [.5 .45 .5 .5], ...
            'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'axes_panel2');

        slider_panel = uipanel(fig1, 'Units', 'normalized', 'Position', [0 0 1 .45], ...
            'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'slider_panel');

        handles.handles.butt_panel = butt_panel;
        handles.handles.ax_panel1 = ax_panel1;
        handles.handles.ax_panel2 = ax_panel2;
        handles.handles.slider_panel = slider_panel;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Define axes positions


        ax1 = axes('Parent', ax_panel1, 'Position', [0.002 .005 .994 .994]);
        set(ax1, 'Tag', 'Left axis');


        path_here = mfilename('fullpath');
        %disp(path_here);

        % Find logo file

        if isdeployed

                logo_1 = BMIFLogoGenerate;
                fill_image = imagesc(Vector2Colormap(-logo_1,handles.Left_color), 'Parent', ax1);
                set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');


        else
            logo_file = fullfile(fileparts(path_here), 'BMIF_logo.jpg');


            if exist(logo_file, 'file') == 2;

                logo_hold = single(imread(logo_file));
                logo_1 = logo_hold(:,:,1);
                clear logo_hold  
                fill_image = imagesc(Vector2Colormap(-logo_1,handles.Left_color), 'Parent', ax1);
                set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');

            else

                % Dummy data to put into the axes on startup
                z=peaks(1000);
                z = z./max(abs(z(:)));
                fill_image = imshow(z, 'Parent', ax1, 'ColorMap', jet, 'DisplayRange', [min(z(:)) max(z(:))]);
                set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');
                freezeColors(ax1);

            end
        end

        % Get rid of tick labels
        set(ax1, 'xtick', [], 'ytick', [])
        axis image % Freezes axis aspect ratio to that of the initial image - disallows skewing due to figure reshaping.

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        ax2 = axes('Parent', ax_panel2, 'Position', [0.002 .005 .994 .994]);
        set(ax2, 'Tag', 'Axis2');

        if isdeployed

                logo_1 = BMIFLogoGenerate;
                fill_image = imagesc(Vector2Colormap(-logo_1,handles.Right_color), 'Parent', ax2);
                set(fill_image, 'Tag', 'fill_image_right', 'HitTest', 'on');

        else

            if exist(logo_file, 'file') == 2;

                logo_hold = single(imread(logo_file));
                logo_1 = logo_hold(:,:,1);
                clear logo_hold  
                fill_image = imagesc(Vector2Colormap(-logo_1, handles.Right_color), 'Parent', ax2);
                set(fill_image, 'Tag', 'fill_image_right', 'HitTest', 'on');

            else

                % Dummy data to put into the axes on startup
                z=peaks(1000);
                z = z./max(abs(z(:)));
                fill_image = imshow(z, 'Parent', ax2, 'ColorMap', jet, 'DisplayRange', [min(z(:)) max(z(:))]);
                set(fill_image, 'Tag', 'fill_image_right', 'HitTest', 'on');
                freezeColors(ax2);

            end
        end

        % Get rid of tick labels
        set(ax2, 'xtick', [], 'ytick', []);
        axis image % Freezes axis aspect ratio to that of the initial image - disallows skewing due to figure reshaping.

        handles.handles.ax1 = ax1;
        handles.handles.ax2 = ax2;


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Define button positions

        %%%%%%%%%%%%%%%%%%%%%%
        % Top Button panel buttons

        % Button
        Load_out =     uicontrol(butt_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Load Path',...
                'Position', [0 .05 .1 .9],...
                'Callback', @Load_pts, 'Tag', 'Load Path');

        % Button %%%%% 
        width = .2;
        Image_preferences_out =     uicontrol(butt_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Image Preferences',...
                'Position', [(1 - width) .05 width .9],...
                'Callback', @Image_prefs, 'Tag', 'Image_prefs');  

        handles.handles.Load_out = Load_out;
        handles.handles.Image_preferences_out = Image_preferences_out;


        % Button %%%%%
        width = .2;
        handles.handles.RunAnalysis =     uicontrol(slider_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'FRET Report',...
                'Position', [(.98 - width) .02 width .12], 'Enable', 'off',...
                'Callback', @RunAnalysis, 'Tag', 'FRETReportButton'); 
            
        handles.handles.IntensityReport =     uicontrol(slider_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Intensity Report',...
                'Position', [(.76 - width) .02 width .12], 'Enable', 'off',...
                'Callback', @IntensityReport, 'Tag', 'ImageReportButton'); 

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Define text box positions


        Load_text = uicontrol(butt_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position',[.11 .15 .6 .7], 'BackgroundColor', [1 1 1], ...
            'String', 'File', 'Callback', @Load_edit, 'Tag', 'Load_textbox');

        handles.handles.Load_text = Load_text;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Acceptor/Donor channel parameters
        
        handles.handles.channelIDText(1) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Channel 0', 'Position', [.1 .90 .3 .08], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'center', 'fontsize', 12);
        
        handles.handles.channelIDText(2) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Channel 1', 'Position', [.6 .90 .3 .08], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'center', 'fontsize', 12);
        
        handles.handles.FRETChannelIDText(1) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Acceptor', 'Position', [.1 .80 .3 .08], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'center', 'fontsize', 12);
        
        handles.handles.FRETChannelIDText(2) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Donor', 'Position', [.6 .80 .3 .08], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'center', 'fontsize', 12);
        
        handles.handles.FRETChannelIDSwap = uicontrol(slider_panel, 'Style', 'pushbutton', 'Units', 'normalized',...
            'String', '< -- Swap -- >', 'Position', [.40 .80 .2 .1], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'center', 'fontsize', 12, 'callback', @SwapFRETChannels);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Background Parameters

        handles.handles.bkgd_slider_text(1) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Cell Border Threshold', 'Position', [.02 .53 .3 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        
        handles.handles.bkgd_slider_text(2) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Channel :', 'Position', [.01 .45 .3 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        handles.handles.bkgdChannel = uibuttongroup('Parent',slider_panel,...
            'BorderType', 'none', ...
            'Position',[.081 .43 .15 .1], 'BackgroundColor', [.9 .9 .9], ...
            'SelectionChangeFcn', @bkgd_channel_group_change);
        
        handles.handles.bkgdChanButton(1) = uicontrol(handles.handles.bkgdChannel,'Style','toggle','String','1',...
                'Units','normalized',...
                'Position',[0 0 .4 .9]);
            
        handles.handles.bkgdChanButton(2) = uicontrol(handles.handles.bkgdChannel,'Style','toggle','String','2',...
                'Units','normalized',...
                'Position',[.5 0 .4 .9]);
            
        set(handles.handles.bkgdChannel,'SelectedObject', handles.handles.bkgdChanButton(handles.BackgroundChannel));
            
            
        handles.handles.bkgd_slider_text(3) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Intensity :', 'Position', [.235 .45 .2 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');

        handles.bkgd_slider_value = handles.Min_max_left(1);
        handles.bkgd_slider_step = 1/(handles.Min_max_left(2)+1);

        handles.handles.bkgd_slide_hand = uicontrol(slider_panel, 'Style', 'slider', 'Units', 'normalized',...  
            'SliderStep', [handles.bkgd_slider_value handles.bkgd_slider_value], 'Min', 0, 'Max', 1, ...
            'Value', handles.bkgd_slider_value, 'Position', [.31 .45 .38 .05],...
            'Callback', @bkgd_slider_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'Slider handle');

        handles.handles.bkgd_slide_listen = addlistener(handles.handles.bkgd_slide_hand, 'Value', 'PostSet', @bkgd_slider_listener);

        handles.handles.bkgd_slide_box = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.7 .43 .08 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.BackgroundThreshold), ...
            'Callback', @bkgd_slider_edit_call);


        handles.handles.bkgd_slider_text(4) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Erode Diameter :', 'Position', [.79 .45 .2 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        handles.handles.bkgd_dilate_box = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.913 .43 .08 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.ErodeDiameter), 'Callback', @bkgd_erode_dia_call);
        

        set(findobj('Parent', slider_panel, 'Type', 'uicontrol'), 'Enable', 'off');
%         set(handles.handles.ImportConfig, 'Enable', 'on');
        guidata(fig1, handles);
    end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Callback functions



%%%%%%%%%%%%%%%%%%%%%%
% Background thresholds uicontrol objects

    function bkgd_channel_group_change(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        handles.BackgroundChannel = find(get(handles.handles.bkgdChannel, 'SelectedObject') == flipud(get(handles.handles.bkgdChannel, 'Children')));
        guidata(handles.handles.fig1, handles);
        displayBkgdThresholdBndry;
%         calculateDetectedParticles('both');
    end

    function bkgd_slider_call(varargin)
        
       % listener handled
        
    end

    function bkgd_slider_listener(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
               
        set(handles.handles.bkgd_slide_box, 'String', num2str(round(get(handles.handles.bkgd_slide_hand, 'Value'))));
        handles.BackgroundThreshold = round(get(handles.handles.bkgd_slide_hand, 'Value'));
        guidata(handles.handles.fig1, handles);
        displayBkgdThresholdBndry;
%         calculateDetectedParticles('both');
    end

    function bkgd_slider_edit_call(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        inputVal = (get(handles.handles.bkgd_slide_box, 'String'));
        
        if all(isstrprop(inputVal, 'digit')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero, so change slider to
            % match
            set(handles.handles.bkgd_slide_hand, 'Value', round(str2double(inputVal)));
            handles.BackgroundThreshold = str2double(inputVal);
        else
            % Revert and set box to match slider
            set(handles.handles.bkgd_slide_box, 'String', num2str(round(get(handles.handles.bkgd_slide_hand, 'Value'))));
        end
            
        guidata(handles.handles.fig1, handles);
        displayBkgdThresholdBndry;
%         calculateDetectedParticles('both');
        
    end

    function bkgd_erode_dia_call(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        inputVal = (get(handles.handles.bkgd_dilate_box, 'String'));
        
        if all(isstrprop(inputVal, 'digit')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero
            % Keep value 
            handles.ErodeDiameter = str2double(inputVal);
        else
            % Revert and set box to match old value
            set(handles.handles.bkgd_dilate_box, 'String', num2str(handles.ErodeDiameter));
        end
        
        guidata(handles.handles.fig1, handles);
            
        displayBkgdThresholdBndry;
%         calculateDetectedParticles('both');
        
    end


%%%%%%%%%%%%%%%%%%%%%%
% Run analysis button

    function RunAnalysis(varargin)
        
     % Make a figure showing FRET values across image
     % Show border of cell and interior
     % Show ratiometric values in and out
     % Export button to send values in and out plus input parameters to
     % text file
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
     
         handles.handles.AnalysisFig = figure();
         resizeFig(handles.handles.AnalysisFig, [470 500]);
         set(handles.handles.AnalysisFig, 'color', [1 1 1]);

         handles.handles.AnalAx = axes('parent', handles.handles.AnalysisFig, ...
             'position', [-0.0123    0.210    1    0.7500]);

         if handles.FRETDonorChannel
            handles.ratioImg = double(handles.Img_stack(:,:,1))./double(handles.Img_stack(:,:,2));
         elseif handles.FRETAcceptorChannel
             handles.ratioImg = double(handles.Img_stack(:,:,2))./double(handles.Img_stack(:,:,1));
         end
         
         imagesc(handles.ratioImg, 'parent', handles.handles.AnalAx);
         set(handles.handles.AnalAx, 'xtick', [], 'ytick', []);
         axis(handles.handles.AnalAx, 'image');
         set(handles.handles.AnalAx, 'XLim', [0.5 size(handles.Img_stack, 1)+0.5], ...
             'YLim', [0.5 size(handles.Img_stack, 2)+0.5]);
        
         colormap(handles.handles.AnalAx, 'parula');
         
         handles.handles.colorbar = colorbar(handles.handles.AnalAx);
         ylabel(handles.handles.colorbar, 'Acceptor / Donor');
         
         % Draw in borders

         set(handles.handles.AnalAx, 'NextPlot', 'add');
         plot(handles.InnerBorder{1}(:,2), handles.InnerBorder{1}(:,1), 'k');
         plot(handles.OuterBorder{1}(:,2), handles.OuterBorder{1}(:,1), 'k--');
         
         % Output stats for ratio values in and out of bordered region
        innerSeg = poly2mask(handles.InnerBorder{1}(:,2), handles.InnerBorder{1}(:,1), ...
            size(handles.Img_stack, 1), size(handles.Img_stack, 2));
        outerSeg = poly2mask(handles.OuterBorder{1}(:,2), handles.OuterBorder{1}(:,1), ...
            size(handles.Img_stack, 1), size(handles.Img_stack, 2));
        
        outerSeg(innerSeg) = 0;
        
        ratioInnerStats = [mean(handles.ratioImg(innerSeg)) std(handles.ratioImg(innerSeg)), sum(innerSeg(:))];
        ratioOuterStats = [mean(handles.ratioImg(outerSeg)) std(handles.ratioImg(outerSeg)), sum(outerSeg(:))];
        
        % Add stats as text to figure
        handles.handles.textAx = axes('parent', handles.handles.AnalysisFig, ...
            'position', [0 0 1 0.210], 'xlim', [0 1], 'ylim', [0 1], 'visible', 'off');
        
        text(0.05, 0.82, '                     Mean           \sigma        NumPix', 'parent', handles.handles.textAx);
        text(0.05, 0.75, '___________________________________', 'parent', handles.handles.textAx, 'interpreter', 'none');
        text(0.05, 0.6, sprintf('Inner ROI      %.3f       %.3f       %d', ratioInnerStats), 'parent', handles.handles.textAx);
        text(0.05, 0.4, sprintf('Outer ROI     %.3f       %.3f       %d', ratioOuterStats), 'parent', handles.handles.textAx);
        
        
        % Export button
        % TIFF export saves image file
        % TXT export saves report w/ config and ratio output
         uicontrol('style', 'pushbutton', 'parent', handles.handles.AnalysisFig, 'String', 'Export', ...
             'position', [357     8   107    33], 'callback', @ExportRatioOutput);
         
        function ExportRatioOutput(varargin)
           
            [fname, pathname, filterindex] = uiputfile({'*.tif', 'TIFF Image File'; '*.txt', 'TXT Data file'});
                       
            if filterindex == 1
                % TIFF file export
                fileOut = fullfile(pathname, fname);
                
                paramComment = sprintf('File %s\nAccChan %d\nSegChan %d\nInt %d\nErodeDia %d', ...
                    handles.Load_file, double(handles.FRETAcceptorChannel), handles.BackgroundChannel, handles.BackgroundThreshold, handles.ErodeDiameter);
                
                t = Tiff(fileOut,'w');
                t.setTag('Photometric',Tiff.Photometric.MinIsBlack); % assume grayscale
                t.setTag('BitsPerSample',32);
                t.setTag('SamplesPerPixel',1);
                t.setTag('SampleFormat',Tiff.SampleFormat.IEEEFP);
                t.setTag('ImageLength',size(handles.ratioImg,1));
                t.setTag('ImageWidth',size(handles.ratioImg,2));
                t.setTag('PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);
                t.setTag('ImageDescription',paramComment);
                t.write(single(handles.ratioImg));
                t.close();
                
%                 imwrite(handles.ratioImg, fileOut, 'TIFF', 'Description', paramComment);
                
                
            elseif filterindex == 2
                % TXT file export
                fileOut = fullfile(pathname, fname);
                
                fID = fopen(fileOut, 'w+');
                fprintf(fID, '# FRET Report from FRET Cell Segmenter\r\n');
                fprintf(fID, '# File : %s\r\n', handles.Load_file);
                if handles.FRETDonorChannel
                    fprintf(fID, '# Donor Channel : 1\r\n');
                    fprintf(fID, '# Acceptor Channel : 0\r\n');
                elseif handles.FRETAcceptorChannel
                    fprintf(fID, '# Donor Channel : 0\r\n');
                    fprintf(fID, '# Acceptor Channel : 1\r\n');
                end
                fprintf(fID, '# Segmentation Channel : %d\r\n', handles.BackgroundChannel);
                fprintf(fID, '# Cell Border Threshold : %d\r\n', handles.BackgroundThreshold);
                fprintf(fID, '# Erode Diameter : %d\r\n', handles.ErodeDiameter);
                fprintf(fID, '#############################################\r\n');
                fprintf(fID, 'Region\tMean\tStdDev\tNPixels\r\n');
                fprintf(fID, '%s\t%.3f\t%.3f\t%d\r\n', 'Inner', ratioInnerStats);
                fprintf(fID, '%s\t%.3f\t%.3f\t%d\r\n', 'Outer', ratioOuterStats);
                fclose(fID);
                
            else
                return;
            end
            
            
        end
         
    end


    function IntensityReport(varargin)

       % Make a figure showing Intensity values across selected image
         % Show border of cell and interior
         % Show ratiometric values in and out
         % Export button to send values in and out plus input parameters to
         % text file
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
     
         handles.handles.AnalysisFig = figure();
         resizeFig(handles.handles.AnalysisFig, [470 500]);
         set(handles.handles.AnalysisFig, 'color', [1 1 1]);

         handles.handles.AnalAx = axes('parent', handles.handles.AnalysisFig, ...
             'position', [-0.0123    0.210    1    0.7500]);

         handles.ratioImg = double(handles.Img_stack(:,:,handles.BackgroundChannel));
         
         imagesc(handles.ratioImg, 'parent', handles.handles.AnalAx);
         set(handles.handles.AnalAx, 'xtick', [], 'ytick', []);
         axis(handles.handles.AnalAx, 'image');
         set(handles.handles.AnalAx, 'XLim', [0.5 size(handles.Img_stack, 1)+0.5], ...
             'YLim', [0.5 size(handles.Img_stack, 2)+0.5]);
        
         colormap(handles.handles.AnalAx, 'parula');
         
         handles.handles.colorbar = colorbar(handles.handles.AnalAx);
         ylabel(handles.handles.colorbar, sprintf('Channel %d Intensity', handles.BackgroundChannel));
         
         % Draw in borders

         set(handles.handles.AnalAx, 'NextPlot', 'add');
         plot(handles.InnerBorder{1}(:,2), handles.InnerBorder{1}(:,1), 'k');
         plot(handles.OuterBorder{1}(:,2), handles.OuterBorder{1}(:,1), 'k--');
         
         % Output stats for ratio values in and out of bordered region
        innerSeg = poly2mask(handles.InnerBorder{1}(:,2), handles.InnerBorder{1}(:,1), ...
            size(handles.Img_stack, 1), size(handles.Img_stack, 2));
        outerSeg = poly2mask(handles.OuterBorder{1}(:,2), handles.OuterBorder{1}(:,1), ...
            size(handles.Img_stack, 1), size(handles.Img_stack, 2));
        
        outerSeg(innerSeg) = 0;
        
        ratioInnerStats = [mean(handles.ratioImg(innerSeg)) std(handles.ratioImg(innerSeg)), sum(innerSeg(:))];
        ratioOuterStats = [mean(handles.ratioImg(outerSeg)) std(handles.ratioImg(outerSeg)), sum(outerSeg(:))];
        
        % Add stats as text to figure
        handles.handles.textAx = axes('parent', handles.handles.AnalysisFig, ...
            'position', [0 0 1 0.210], 'xlim', [0 1], 'ylim', [0 1], 'visible', 'off');
        
        text(0.05, 0.82, '                     Mean                \sigma             NumPix', 'parent', handles.handles.textAx);
        text(0.05, 0.75, '________________________________________', 'parent', handles.handles.textAx, 'interpreter', 'none');
        text(0.05, 0.6, sprintf('Inner ROI      %.3f       %.3f       %d', ratioInnerStats), 'parent', handles.handles.textAx);
        text(0.05, 0.4, sprintf('Outer ROI     %.3f       %.3f       %d', ratioOuterStats), 'parent', handles.handles.textAx);
        
        
        % Export button
        % TIFF export saves image file
        % TXT export saves report w/ config and ratio output
         uicontrol('style', 'pushbutton', 'parent', handles.handles.AnalysisFig, 'String', 'Export', ...
             'position', [357     8   107    33], 'callback', @ExportRatioOutput);
         
        function ExportRatioOutput(varargin)
           
            [fname, pathname, filterindex] = uiputfile({'*.tif', 'TIFF Image File'; '*.txt', 'TXT Data file'});
                       
            if filterindex == 1
                % TIFF file export
                fileOut = fullfile(pathname, fname);
                
                paramComment = sprintf('File %s\nSegChan %d\nInt %d\nErodeDia %d', ...
                    handles.Load_file, handles.Primary_channel, handles.BackgroundThreshold, handles.ErodeDiameter);
                
                t = Tiff(fileOut,'w');
                t.setTag('Photometric',Tiff.Photometric.MinIsBlack); % assume grayscale
                t.setTag('BitsPerSample',32);
                t.setTag('SamplesPerPixel',1);
                t.setTag('SampleFormat',Tiff.SampleFormat.IEEEFP);
                t.setTag('ImageLength',size(handles.ratioImg,1));
                t.setTag('ImageWidth',size(handles.ratioImg,2));
                t.setTag('PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);
                t.setTag('ImageDescription',paramComment);
                t.write(single(handles.ratioImg));
                t.close();
                
%                 imwrite(handles.ratioImg, fileOut, 'TIFF', 'Description', paramComment);
                
                
            elseif filterindex == 2
                % TXT file export
                fileOut = fullfile(pathname, fname);
                
                fID = fopen(fileOut, 'w+');
                fprintf(fID, '# Intensity Report from FRET Cell Segmenter\r\n');
                fprintf(fID, '# File : %s\r\n', handles.Load_file);
                fprintf(fID, '# Segmentation Channel : %d\r\n', handles.Primary_channel);
                fprintf(fID, '# Cell Border Threshold : %d\r\n', handles.BackgroundThreshold);
                fprintf(fID, '# Erode Diameter : %d\r\n', handles.ErodeDiameter);
                fprintf(fID, '#############################################\r\n');
                fprintf(fID, 'Region\tMean\tStdDev\tNPixels\r\n');
                fprintf(fID, '%s\t%.3f\t%.3f\t%d\r\n', 'Inner', ratioInnerStats);
                fprintf(fID, '%s\t%.3f\t%.3f\t%d\r\n', 'Outer', ratioOuterStats);
                fclose(fID);
                
            else
                return;
            end
            
            
        end
        
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Use uigetfile to load up a file

    function Load_pts(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        [fname, pathname, filterindex] = uigetfile({'*.czi', 'CZI File (*.czi)'});
        
        if filterindex == 1;
            
            if ~strcmp(fullfile(pathname, fname), handles.Load_file)
                % Reset stuff now that there is a new file being loaded (as long as
                % it's actually new).
                
                
                
            end
            
            if ~isequal(fname, 0) && ~isequal(pathname, 0)
                
                DoTheLoadThing(pathname, fname);
                
            end
            
        end
        
    end
    
%%%%%%%%%%%%%%%%%%%%%%
% Edit text box to load file

    function Load_edit(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        text_input = get(handles.handles.Load_text, 'String');
        %disp(text_input)
        
        if exist(text_input, 'file') == 2;
            
            [pN, fN, extN] = fileparts(text_input);
            
            DoTheLoadThing(pN, strcat(fN, extN));
            
        end
            

    end
    
%%%%%%%%%%%%%%%%%%%%%%
% General load function
    
    function DoTheLoadThing(pathname, fname)
            
        set(findobj('Parent', handles.handles.slider_panel, 'Type', 'uicontrol'), 'Enable', 'on');

        set(handles.handles.Load_text, 'String', fullfile(pathname, fname));
        handles.Load_file = fullfile(pathname, fname);
        
        load_wait = waitbar(0, 'Loading File');
       
        % Load CZI file, get rid of time and z stack dimensions, and cast
        % into a double
        handles.Img_stack = double(squeeze(CZIImport(handles.Load_file)));
        
      
        handles.N_frames = 1; % Hard-coding this to 1 since it'll always be a single time point.
                              % If/when this changes, this can be a
                              % variable if needed w/ return of frame
                              % slider
        
        handles.N_channels = size(handles.Img_stack, 3);
                              
        temp_left = reshape(handles.Img_stack(:,:,1), [], handles.N_frames);
        handles.Min_max_left = [min(temp_left)' max(temp_left)'];
        handles.Display_range_left = [min(temp_left(:)) max(temp_left(:))];
        
        if handles.N_channels == 2;
            temp_right = reshape(handles.Img_stack(:,:,2), [], handles.N_frames);
            handles.Min_max_right = [min(temp_right)' max(temp_right)'];
            handles.Display_range_right = [min(temp_right(:)) max(temp_right(:))];
                        
            
        else
            
            set(handles.handles.bkgdChanButton, 'enable', 'off');
            set(handles.handles.RunAnalysis, 'enable', 'off');
            handles.Primary_channel = 1;
            set(handles.handles.bkgdChannel, 'SelectedObject', handles.handles.bkgdChanButton(1));
            
        end
        
        clear temp_left temp_right
        
        % Set Intensity threshold levels
        minMax1 = [min(handles.Min_max_left(:,1)) max(handles.Min_max_left(:,2))];

        minMax2 = [min(handles.Min_max_right(:,1)) max(handles.Min_max_right(:,2))];

        minMax = [min([minMax1 minMax2]) max([minMax1 minMax2])];
        set(handles.handles.bkgd_slide_hand, 'Min', min(minMax), 'Max', max(minMax),...
            'SliderStep', [1/(diff(minMax)) 10/diff(minMax)]);
%         

        
        guidata(findobj('Tag', 'TIFF viewer'), handles);
        drawnow;
        displayBkgdThresholdBndry;

        Display_images_in_axes;
        
        
        set(handles.handles.IntensityReport, 'enable', 'on');
        
        waitbar(1, load_wait);
        close(load_wait)
        
        
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Display images in axes.  Used by multiple calls in GUI.

    function Display_images_in_axes(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
               
        if isempty(handles.Load_file) % No data loaded, just dummy images
            
            ax1 = handles.handles.ax1;
            ax2 = handles.handles.ax2;


            path_here = mfilename('fullpath');

            if isdeployed
                    logo_1 = BMIFLogoGenerate;
                    fill_image = imagesc(Vector2Colormap(-logo_1,handles.Left_color), 'Parent', ax1);
                    fill_image2 = imagesc(Vector2Colormap(-logo_1,handles.Right_color), 'Parent', ax2);
                    set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');
                    set(fill_image2, 'Tag', 'fill_image_right', 'HitTest', 'on');
            else
                logo_file = fullfile(fileparts(path_here), 'BMIF_logo.jpg');

                if exist(logo_file, 'file') == 2;

                    logo_hold = single(imread(logo_file));
                    logo_1 = logo_hold(:,:,1);
                    clear logo_hold  
                    fill_image = imagesc(Vector2Colormap(-logo_1,handles.Left_color), 'Parent', ax1);
                    fill_image2 = imagesc(Vector2Colormap(-logo_1,handles.Right_color), 'Parent', ax2);
                    set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');
                    set(fill_image2, 'Tag', 'fill_image_right', 'HitTest', 'on');

                else

                    % Dummy data to put into the axes on startup
                    z=peaks(1000);
                    z = z./max(abs(z(:)));
                    fill_image = imshow(z, 'Parent', ax1, 'ColorMap', jet, 'DisplayRange', [min(z(:)) max(z(:))]);
                    set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');
                    freezeColors(ax1);

                end
            end
                
        else        
                    
            if handles.N_channels == 1;

                % Pull slider value
%                 slide_frame = 1 + round((handles.N_frames - 1)*(get(slide_hand, 'Value')));


                    if handles.Autoscale_left == 0;
                        min_max_left = handles.Display_range_left;
                    else
                        min_max_left = handles.Min_max_left(slide_frame, :);
                    end
                    
                    OldXLimits = get(handles.handles.ax1, 'XLim');
                    OldYLimits = get(handles.handles.ax1, 'YLim');

                    % Set left axis to that frame
                 left_img = image(Vector2Colormap_setscale(handles.Img_stack(:,:,1), handles.Left_color, min_max_left), ...
                    'Parent', handles.handles.ax1, 'Tag', 'Left Image');
                    set(handles.handles.ax1, 'xtick', [], 'ytick', []);
                    axis(handles.handles.ax1, 'image');
                    set(handles.handles.ax1, 'XLim', [0.5 size(handles.Img_stack, 1)+0.5], ...
                        'YLim', [0.5 size(handles.Img_stack, 2)+0.5]);
                   
                     % Set right axis to dummy image
                     
                     
                    z=peaks(1000);
                    z = z./max(abs(z(:)));
                    fill_image = image(Vector2Colormap_setscale(z, handles.Right_color, [min(z(:)), max(z(:))]), ...
                        'Parent', handles.handles.ax2, 'Tag', 'Right Image');
                     

            elseif handles.N_channels == 2;

                
                    % Pull slider value
%                     handles.handles.slide_frame = 1 + round((handles.N_frames - 1)*(get(handles.handles.slide_hand, 'Value')));


                    % Set both axes to that frame


                    if handles.Autoscale_left == 0;
                        min_max_left = handles.Display_range_left;
                    else
                        min_max_left = handles.Min_max_right(handles.handles.slide_frame, :);
                    end

                    if handles.Autoscale_right == 0;
                        min_max_right = handles.Display_range_right;
                    else
                        min_max_right = handles.Min_max_right(handles.handles.slide_frame, :);
                    end
  
                    handles.handles.slide_frame = 1;
                    
                    left_img = image(Vector2Colormap_setscale(handles.Img_stack(:,:,1, handles.handles.slide_frame), handles.Left_color, min_max_left), ...
                        'Parent', handles.handles.ax1, 'Tag', 'Left Image');
                        set(handles.handles.ax1, 'xtick', [], 'ytick', []);
                        axis(handles.handles.ax1, 'image');
                        set(handles.handles.ax1, 'XLim', [0.5 size(handles.Img_stack, 1)+0.5], ...
                        'YLim', [0.5 size(handles.Img_stack, 2)+0.5]);

                    
%                     disp(handles.Right_color)
                    right_img = image(Vector2Colormap_setscale(handles.Img_stack(:,:,2,handles.handles.slide_frame), handles.Right_color, min_max_right), ...
                        'Parent', handles.handles.ax2, 'Tag', 'Right Image');
                         set(handles.handles.ax2, 'xtick', [], 'ytick', []);
                         axis(handles.handles.ax2, 'image');
                         set(handles.handles.ax2, 'XLim', [0.5 size(handles.Img_stack, 1)+0.5], ...
                        'YLim', [0.5 size(handles.Img_stack, 2)+0.5]);
                    
                    % Update segmentation sliders
                    set(handles.handles.bkgd_slide_hand, 'min', min_max_left(1), 'max', min_max_left(2), 'value', round(mean(min_max_left)));
%                     set(handles.handles.fndCtr_slide_hand, 'min', min_max_right(1), 'max', min_max_right(2), 'value', round(mean(min_max_right)));
                    

            end
            
            
            
            
            displayBkgdThresholdBndry;
            
            if handles.CenterChannel ~= 3
            
                displayCenterThreshold;
                
            end
            
        end
        
        if handles.Left_invert == 1;
            
            axis_handle = get(findobj('Tag', 'axes_panel1'), 'Children');
            set(axis_handle, 'XDir', 'reverse');
            
        end
        
        if handles.Right_invert == 1;
            
            axis_handle = get(findobj('Tag', 'axes_panel2'), 'Children');
            set(axis_handle, 'XDir', 'reverse');
            
        end

        
    end


%%%%%%%%%%%%%%%%%%%%%%
% Display Background threshold boundary

    function displayBkgdThresholdBndry(varargin)

        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        delete(findobj('Parent', handles.handles.ax1, 'Type', 'line', 'Color', 'w'));
        delete(findobj('Parent', handles.handles.ax2, 'Type', 'line', 'Color', 'w'));
        
        set(handles.handles.ax1, 'NextPlot', 'add')
        set(handles.handles.ax2, 'NextPlot', 'add')
        
%         frameNum = str2double(get(handles.handles.slide_box, 'String'));
        frameNum = 1;
        bkgdVal = str2double(get(handles.handles.bkgd_slide_box, 'String'));
        erodePixels = str2double(get(handles.handles.bkgd_dilate_box, 'String'));
        
        % Find cell border
        gT = (handles.Img_stack(:,:,handles.BackgroundChannel, frameNum) > (bkgdVal));
        gT = imfill(gT, 'holes');
        gT = bwmorph(gT, 'open');
        regs = regionprops(gT, 'area', 'PixelIdxList');
        rA = vertcat(regs.Area);
        regs(rA ~= max(rA)) = [];
        
        if length(regs) > 1
            regs = regs(1);
        end
        
        bwImg = zeros(size(handles.Img_stack, 1), size(handles.Img_stack, 2), 1);
        
        if isempty(regs)
            % No pixels are above threshold
            B = [];
            Bo = [];
            
        else
            
            bwImg(regs.PixelIdxList) = 1;
            bwImg = reshape(bwImg, size(handles.Img_stack, 1), size(handles.Img_stack, 2));

            Bo = bwboundaries(bwImg, 'noholes');

            bwImg = bwmorph(bwImg, 'erode', erodePixels);

            B = bwboundaries(bwImg, 'noholes');

            for m = 1:length(B)
                plot(handles.handles.ax1, B{m}(:,2), B{m}(:,1), 'w')

                if handles.N_channels == 2
                    plot(handles.handles.ax2, B{m}(:,2), B{m}(:,1), 'w')
                end

            end

            for m = 1:length(Bo)
                plot(handles.handles.ax1, Bo{1}(:,2), Bo{1}(:,1), 'w--')

                if handles.N_channels == 2
                    plot(handles.handles.ax2, Bo{1}(:,2), Bo{1}(:,1), 'w--')
                end

            end

            set(handles.handles.ax1, 'NextPlot', 'replace')
            set(handles.handles.ax2, 'NextPlot', 'replace')
        
        end
        
        handles.InnerBorder = B;
        handles.OuterBorder = Bo;
        handles.bwImg = bwImg;
        
        guidata(handles.handles.fig1, handles);
                   
    end

%%%%%%%%%%%%%%%%%%%%%%
% Display center threshold (if needed)

    function displayCenterThreshold(varargin)
        
       handles = guidata(findobj('Tag', 'TIFF viewer'));
       
       if handles.CenterChannel ~= 3
        
        delete(findobj('Parent', handles.handles.ax1, 'Type', 'line', 'Color', 'm'));
        delete(findobj('Parent', handles.handles.ax2, 'Type', 'line', 'Color', 'm'));
        
        set(handles.handles.ax1, 'NextPlot', 'add')
        set(handles.handles.ax2, 'NextPlot', 'add')
        
        frameNum = str2double(get(handles.handles.slide_box, 'String'));
        ctrVal = handles.CenterIntensity;
        dilatePixels = handles.FindCtrDilateDiameter;
        
%         disp(ctrVal)
        
        % Find cell border
        gT = (handles.Img_stack(:,:,handles.CenterChannel, frameNum) > (ctrVal));
        regs = regionprops(gT, 'area', 'PixelIdxList');
        rA = vertcat(regs.Area);
        regs(rA ~= max(rA)) = [];
        bwImg = false(size(handles.Img_stack, 1)*size(handles.Img_stack, 2), 1);
        bwImg(vertcat(regs.PixelIdxList)) = 1;
        bwImg = reshape(bwImg, size(handles.Img_stack, 1), size(handles.Img_stack, 2));

        Bo = bwboundaries(bwImg, 'noholes');

        bwImg = bwmorph(bwImg, 'dilate', dilatePixels);

        ctrMask = handles.bwImg;
        ctrMask(bwImg) = 0;
        B = bwboundaries(bwImg, 'noholes');
        
        for m = 1:length(B)
            plot(handles.handles.ax1, B{m}(:,2), B{m}(:,1), 'm')
            plot(handles.handles.ax2, B{m}(:,2), B{m}(:,1), 'm')
        end

        for m = 1:length(Bo)
            plot(handles.handles.ax1, Bo{1}(:,2), Bo{1}(:,1), 'm:')
            plot(handles.handles.ax2, Bo{1}(:,2), Bo{1}(:,1), 'm:')
        end
        
        set(handles.handles.ax1, 'NextPlot', 'replace')
        set(handles.handles.ax2, 'NextPlot', 'replace')
        
        guidata(handles.handles.fig1, handles);
        

       end
        
    end

    function SwapFRETChannels(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        handles.FRETAcceptorChannel = handles.FRETDonorChannel; % 0-indexed logical
        handles.FRETDonorChannel = ~handles.FRETDonorChannel;
        
        
        set(handles.handles.FRETChannelIDText(1), 'string', get(handles.handles.FRETChannelIDText(2), 'string'));
        if handles.FRETAcceptorChannel
            set(handles.handles.FRETChannelIDText(2), 'string', 'Acceptor');
        else
            set(handles.handles.FRETChannelIDText(2), 'string', 'Donor');
        end
       
        guidata(handles.handles.fig1, handles);
        
    end


%%%%%%%%%%%%%%%%%%%%%%
% Set parameters for image display

    function Image_prefs(varargin)
        
        % Make sure there isn't another one of these already open.  If so,
        % bring it to the front.  
        
        if ~isempty(findobj('Tag', 'GALAH_Image_prefs'))
        
            uistack(findobj('Tag', 'GALAH_Image_prefs'), 'top');
            
        else
            
            %fig1 = findobj('Tag', 'TIFF viewer');
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            mf_post = get(findobj('Tag', 'TIFF viewer'), 'Position').*([handles.scrsz_pixels(3) handles.scrsz_pixels(4) handles.scrsz_pixels(3) handles.scrsz_pixels(4)]);      
            fig2_size = [400 300];
            fig2_position = [(mf_post(1) + (mf_post(3) - fig2_size(1))/2) (mf_post(2) + (mf_post(4) - fig2_size(2))/2)];
            fig2 = figure('Name','Image Preferences', 'Tag', 'GALAH_Image_prefs', 'Units', 'pixels',...
                'Position',[fig2_position fig2_size], 'NumberTitle', 'off', 'Toolbar', 'none', 'Menu', 'none');
            set(fig2, 'Color',[0.9 0.9 0.9]);

            fig2_green = uipanel(fig2, 'Units', 'normalized', 'Position', [0 .45, 1, .44], ...
                'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'green_panel', 'Title', 'Channel 1');

            fig2_red = uipanel(fig2, 'Units', 'normalized', 'Position', [0 0, 1, .44], ...
                'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'red_panel', 'Title', 'Channel 2');

            fig2_top = uipanel(fig2, 'Units', 'normalized', 'Position', [0 .89, 1, .11], ...
                'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'none', 'Tag', 'top_panel');

            handles.handles.fig2_green = fig2_green;
            handles.handles.fig2_red = fig2_red;
            handles.handles.fig2_top = fig2_top;

            %%%%%%%%%%%%%%%%%%
            % Single/dual channel toggle

            dual_single_radio = uibuttongroup('visible', 'off', 'Parent', fig2_top, 'Units', 'normalized', ...
                'Position', [0 0 1 1], 'BorderType', 'none', 'BackgroundColor', [.9 .9 .9]);
            ds1 = uicontrol('Style', 'togglebutton', 'String', 'Single Channel', 'Parent', dual_single_radio, ...
                'Units', 'normalized', 'Position', [.05 .05 .4 .9]);
            ds2 = uicontrol('Style', 'togglebutton', 'String', 'Dual Channel', 'Parent', dual_single_radio, ...
                'Units', 'normalized', 'Position', [.55 .05 .4 .9]);
            set(dual_single_radio, 'SelectionChangeFcn', @dual_single_push);
            radio_handles = [ds1 ds2];
            set(dual_single_radio, 'SelectedObject', radio_handles(handles.N_channels));
            set(dual_single_radio, 'Visible', 'on');
            
            handles.handles.dual_single_radio.Single = ds1;
            handles.handles.dual_single_radio.Dual = ds2;
            handles.handles.dual_slingle_radio = dual_single_radio;

            %%%%%%%%%%%%%%%%%%
            % Channel 1 (green channel) sliders and such
            
             if isempty(handles.Load_file)
                 
                slider_step = 1;
                green_range = [0 1];
                green_max_slider_display = 1;
                green_min_slider_display = 0;
                slider_value_green_max = 1;
                slider_value_green_min = 0;
                
             elseif ~isempty(handles.Load_file)

                green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];

                slider_value_green_max = (handles.Display_range_left(2) - green_range(1))/(green_range(2) - green_range(1));
                slider_step = 1/((green_range(2)-green_range(1))-1);
                
                slider_value_green_min = (handles.Display_range_left(1) - green_range(1))/(green_range(2) - green_range(1));
                slider_step = 1/((green_range(2)-green_range(1))-1);
                
             end

            green_max_slide_hand = uicontrol(fig2_green, 'Style', 'slider', 'Units', 'normalized',...  
                'SliderStep', [slider_step slider_step], 'Min', 0, 'Max', 1, 'Value', slider_value_green_max, 'Position', [.30 .77 .68 .1],...
                'Callback', @slider_green_max_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'Green max');

            green_max_slide_listen = addlistener(green_max_slide_hand, 'Value', 'PostSet', @slider_green_max_listener);

            green_max_slide_box = uicontrol(fig2_green, 'Style', 'edit', 'Units', 'normalized', ...
                'Position', [.18 .71 .1 .25], 'BackgroundColor', [1 1 1], ...
                'String', num2str(handles.Display_range_left(2)), 'Callback', @edit_green_max_call);

            green_max_slide_text = uicontrol(fig2_green, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .75 .16 .14], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Display Max:');

            set(green_max_slide_hand, 'Enable', 'off');
            set(green_max_slide_box, 'Enable', 'off');

            green_min_slide_hand = uicontrol(fig2_green, 'Style', 'slider', 'Units', 'normalized',...  
                'SliderStep', [slider_step slider_step], 'Min', 0, 'Max', 1, 'Value', slider_value_green_min, 'Position', [.3 .46 .68 .1],...
                'Callback', @slider_green_min_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'Green max');

            green_min_slide_listen = addlistener(green_min_slide_hand, 'Value', 'PostSet', @slider_green_min_listener);

            green_min_slide_box = uicontrol(fig2_green, 'Style', 'edit', 'Units', 'normalized', ...
                'Position', [.18 .39 .1 .25], 'BackgroundColor', [1 1 1], ...
                'String', num2str(handles.Display_range_left(1)), 'Callback', @edit_green_min_call);

            green_min_slide_text = uicontrol(fig2_green, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .43 .16 .14], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Display Min:');

            Colormap_strings = {'Gray'; 'Jet'; 'Green'; 'Red'; 'Cyan'; 'Yellow'; 'Hot'; 'Cool'; 'Spring'; 'Summer'; 'Autumn'; 'Winter'};
            handles.Colormap_strings = Colormap_strings;
            left_value = find(strcmpi(handles.Left_color, Colormap_strings));

            green_colormap_listbox = uicontrol(fig2_green, 'Style', 'popupmenu', 'Units', 'normalized', ...
                'Position', [.18 .095 .22 .2], 'String', Colormap_strings, 'Value', left_value, 'Callback', @popup_green_colormap);

            green_colormap_text = uicontrol(fig2_green, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .05 .16 .2], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Colormap:');

            green_autoscale = uicontrol('Style', 'checkbox', 'String', 'Autoscale', 'Parent', fig2_green, ...
                'Units', 'normalized', 'Position', [.50 .06 .2 .25], 'BackgroundColor', [.9 .9 .9], ...
                'Value', handles.Autoscale_left, 'Callback', @autoscale_green);

            green_invert = uicontrol('Style', 'checkbox', 'String', 'Invert Image', 'Parent', fig2_green, ...
                'Units', 'normalized', 'Position', [.76 .06 .2 .25], 'BackgroundColor', [.9 .9 .9], ...
                'Value', handles.Left_invert, 'Callback', @invert_green);

            if handles.Autoscale_left == 1
                set(green_max_slide_hand, 'Enable', 'off');
                set(green_max_slide_box, 'Enable', 'off');
                set(green_min_slide_hand, 'Enable', 'off');
                set(green_min_slide_box, 'Enable', 'off');
            else
                set(green_max_slide_hand, 'Enable', 'on');
                set(green_max_slide_box, 'Enable', 'on');
                set(green_min_slide_hand, 'Enable', 'on');
                set(green_min_slide_box, 'Enable', 'on');
            end
            set(green_colormap_listbox, 'Enable', 'on');

            %%%%%%%%%%%%%%%%%%
            % Channel 2 (red channel) sliders and such
            
            if isempty(handles.Load_file)
                red_range = [0 1];
                slider_step = 1;
                red_max_slider_display = 1;
                red_min_slider_display = 0;
                slider_value_red_max = 1;
                slider_value_red_min = 0;
                
            else

                if handles.N_channels == 2
                    red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
                    slider_step = 1/((red_range(2)-red_range(1))-1);
                    red_max_slider_display = handles.Display_range_right(2);
                    red_min_slider_display = handles.Display_range_right(1);
                    slider_value_red_max = (handles.Display_range_right(2) - red_range(1))/(red_range(2) - red_range(1));
                    slider_value_red_min = (handles.Display_range_right(1) - red_range(1))/(red_range(2) - red_range(1));
                else
                    slider_step = 1;
                    red_range = [0 1];
                    red_max_slider_display = 1;
                    red_min_slider_display = 0;
                    slider_value_red_max = 1;
                    slider_value_red_min = 0;
                end
                
            end

            red_max_slide_hand = uicontrol(fig2_red, 'Style', 'slider', 'Units', 'normalized',...  
                'SliderStep', [slider_step slider_step], 'Min', 0, 'Max', 1, 'Value', slider_value_red_max, 'Position', [.30 .77 .68 .1],...
                'Callback', @slider_red_max_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'red max');

            red_max_slide_listen = addlistener(red_max_slide_hand, 'Value', 'PostSet', @slider_red_max_listener);

            red_max_slide_box = uicontrol(fig2_red, 'Style', 'edit', 'Units', 'normalized', ...
                'Position', [.18 .71 .1 .25], 'BackgroundColor', [1 1 1], ...
                'String', num2str(red_max_slider_display), 'Callback', @edit_red_max_call);

            red_max_slide_text = uicontrol(fig2_red, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .75 .16 .14], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Display Max:');

            set(red_max_slide_hand, 'Enable', 'off');
            set(red_max_slide_box, 'Enable', 'off');

            

            red_min_slide_hand = uicontrol(fig2_red, 'Style', 'slider', 'Units', 'normalized',...  
                'SliderStep', [slider_step slider_step], 'Min', 0, 'Max', 1, 'Value', slider_value_red_min, 'Position', [.3 .46 .68 .1],...
                'Callback', @slider_red_min_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'red max');

            red_min_slide_listen = addlistener(red_min_slide_hand, 'Value', 'PostSet', @slider_red_min_listener);

            red_min_slide_box = uicontrol(fig2_red, 'Style', 'edit', 'Units', 'normalized', ...
                'Position', [.18 .39 .1 .25], 'BackgroundColor', [1 1 1], ...
                'String', num2str(red_min_slider_display), 'Callback', @edit_red_min_call);

            red_min_slide_text = uicontrol(fig2_red, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .43 .16 .14], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Display Min:');

            right_value = find(strcmpi(handles.Right_color, Colormap_strings));

            red_colormap_listbox = uicontrol(fig2_red, 'Style', 'popupmenu', 'Units', 'normalized', ...
                'Position', [.18 .095 .22 .2], 'String', Colormap_strings, 'Value', right_value, 'Callback', @popup_red_colormap);

            red_colormap_text = uicontrol(fig2_red, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .05 .16 .2], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Colormap:');

            red_autoscale = uicontrol('Style', 'checkbox', 'String', 'Autoscale', 'Parent', fig2_red, ...
                'Units', 'normalized', 'Position', [.50 .06 .2 .25], 'BackgroundColor', [.9 .9 .9], ...
                'Value', handles.Autoscale_right, 'Callback', @autoscale_red);

            red_invert = uicontrol('Style', 'checkbox', 'String', 'Invert Image', 'Parent', fig2_red, ...
                'Units', 'normalized', 'Position', [.76 .06 .2 .25], 'BackgroundColor', [.9 .9 .9], ...
                'Value', handles.Right_invert, 'Callback', @invert_red);
            


            if handles.Autoscale_left == 1;
                set(green_max_slide_hand, 'Enable', 'off');
                set(green_max_slide_box, 'Enable', 'off');
                set(green_min_slide_hand, 'Enable', 'off');
                set(green_min_slide_box, 'Enable', 'off');
                set(green_min_slide_text, 'Enable', 'off');
                set(green_max_slide_text, 'Enable', 'off');
            else
                set(green_max_slide_hand, 'Enable', 'on');
                set(green_max_slide_box, 'Enable', 'on');
                set(green_min_slide_hand, 'Enable', 'on');
                set(green_min_slide_box, 'Enable', 'on');
                set(green_min_slide_text, 'Enable', 'on');
                set(green_max_slide_text, 'Enable', 'on');
            end

            set(red_colormap_listbox, 'Enable', 'on');

            if handles.Autoscale_right == 1;
                set(red_max_slide_hand, 'Enable', 'off');
                set(red_max_slide_box, 'Enable', 'off');
                set(red_min_slide_hand, 'Enable', 'off');
                set(red_min_slide_box, 'Enable', 'off');
                set(red_min_slide_text, 'Enable', 'off');
                set(red_max_slide_text, 'Enable', 'off');
            else
                set(red_max_slide_hand, 'Enable', 'on');
                set(red_max_slide_box, 'Enable', 'on');
                set(red_min_slide_hand, 'Enable', 'on');
                set(red_min_slide_box, 'Enable', 'on');
                set(red_min_slide_text, 'Enable', 'on');
                set(red_max_slide_text, 'Enable', 'on');
            end
            
            if handles.N_channels == 1;
                
                set(red_max_slide_hand, 'Enable', 'off');
                set(red_max_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_hand, 'Enable', 'off');
                set(red_min_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_text, 'Enable', 'off');
                set(red_max_slide_text, 'Enable', 'off');
                set(red_autoscale, 'Enable', 'off');
                set(red_invert, 'Enable', 'off');
                set(red_colormap_listbox, 'Enable', 'off');
                set(red_colormap_text, 'Enable', 'off');
                
            end
            
            if isempty(handles.Load_file)
                
                set(green_max_slide_hand, 'Enable', 'off');
                set(green_max_slide_box, 'Enable', 'off', 'String', []);
                set(green_min_slide_hand, 'Enable', 'off');
                set(green_min_slide_box, 'Enable', 'off', 'String', []);
                set(green_min_slide_text, 'Enable', 'off');
                set(green_max_slide_text, 'Enable', 'off');
                set(green_autoscale, 'Enable', 'off');

                set(red_max_slide_hand, 'Enable', 'off');
                set(red_max_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_hand, 'Enable', 'off');
                set(red_min_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_text, 'Enable', 'off');
                set(red_max_slide_text, 'Enable', 'off');
                set(red_autoscale, 'Enable', 'off');
                
            end
            
            if mod(handles.N_frames*handles.N_channels,2) == 1
                set(handles.handles.dual_single_radio.Single, 'Enable', 'off')
                set(handles.handles.dual_single_radio.Dual, 'Enable', 'off')
            end
            
            handles.handles.green_max_slide_hand = green_max_slide_hand;
            handles.handles.green_max_slide_box = green_max_slide_box;
            handles.handles.green_min_slide_hand = green_min_slide_hand;
            handles.handles.green_min_slide_box = green_min_slide_box;
            handles.handles.green_colormap_listbox = green_colormap_listbox;
            handles.handles.green_autoscale = green_autoscale;
            handles.handles.green_invert = green_invert;
            
            handles.handles.red_max_slide_hand = red_max_slide_hand;
            handles.handles.red_max_slide_box = red_max_slide_box;
            handles.handles.red_min_slide_hand = red_min_slide_box;
            handles.handles.red_min_slide_box = red_max_slide_box;
            handles.handles.red_colormap_listbox = red_colormap_listbox;
            handles.handles.red_autoscale = red_autoscale;
            handles.handles.red_invert = red_invert;
            

            guidata(findobj('Tag', 'TIFF viewer'), handles);
        end
            %%%% Big pile of callback functions

        function dual_single_push(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            
            channels_now = find(eventdata.NewValue == [handles.handles.dual_single_radio.Single handles.handles.dual_single_radio.Dual]);
            %disp(channels_now);
            
            if handles.N_frames*handles.N_channels == 1;
                
                % If there is only one frame, it can only be a
                % single-channel data set.  This forces that fact. 
                % There shouldn't ever be anything to change as the
                % single-frame/single-channel issue is addressed upon
                % loading.
                
                channels_now = 3;
                set(handles.handles.dual_slingle_radio, 'SelectedObject', handles.handles.dual_single_radio.Single);
                
                
            end
            
            if channels_now == 1;
            	handles.N_channels = 1;
            
                % Disable all of right channel
                
                set(red_max_slide_hand, 'Enable', 'off');
                set(red_max_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_hand, 'Enable', 'off');
                set(red_min_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_text, 'Enable', 'off');
                set(red_max_slide_text, 'Enable', 'off');
                set(red_autoscale, 'Enable', 'off');
                set(red_invert, 'Enable', 'off');
                set(red_colormap_listbox, 'Enable', 'off');
                set(red_colormap_text, 'Enable', 'off');

                if ~isempty(handles.Load_file)
                    
                    % Collapse Img_stack, Min_max_XXX down to a single dimension

                    green_frames = 1:2:(handles.N_frames*2);
                    red_frames = 2:2:(handles.N_frames*2);

                    Img_hold = zeros(size(handles.Img_stack,1), size(handles.Img_stack,2), 2*handles.N_channels, 1);
                    Img_hold(:,:,green_frames) = handles.Img_stack(:,:,:,1);
                    Img_hold(:,:,red_frames) = handles.Img_stack(:,:,:,2);

                    Min_max_hold = zeros(handles.N_frames, 2);
                    Min_max_hold(green_frames, :) = handles.Min_max_left;
                    Min_max_hold(red_frames, :) = handles.Min_max_right;

                    handles.Img_stack = Img_hold;
                    handles.Min_max_left = Min_max_hold;
                    handles.Min_max_right = [];
                    clear Img_hold Min_max_hold;

                    handles.N_frames = size(handles.Img_stack, 3);

                    if handles.Primary_channel > handles.N_channels
                        handles.Primary_channel = handles.N_channels;
                    end


                    % Figure out where slider should be with new N_channels

                    slider_step = 1/(handles.N_frames-1);

                    if handles.N_frames == 1;
                        set(slide_hand, 'SliderStep', [1 1]);
                    else
                        set(slide_hand, 'SliderStep', [1/(handles.N_frames-1) 1/(handles.N_frames-1)]);
                    end 
                    
                    set(slide_box, 'String', (1 + round((handles.N_frames - 1)*(get(slide_hand, 'Value')))));

                    green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
                    slider_step_green = 1/((green_range(2)-green_range(1))-1);

                    green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
                    slider_step_green = 1/((green_range(2)-green_range(1))-1);



                    set(green_max_slide_hand, 'SliderStep', [slider_step_green slider_step_green]);
                    set(green_min_slide_hand, 'SliderStep', [slider_step_green slider_step_green]); 

                    slide_string_max = str2num(get(green_max_slide_box, 'String'));
                    slide_set_max = ((slide_string_max - green_range(1))/(green_range(2) - green_range(1)));
                    slide_set_max = min([slide_set_max 1]); 
                    slider_value_max = (green_range(1) + slide_set_max*(green_range(2) - green_range(1)));
                    set(green_max_slide_box, 'String', num2str(slider_value_max));
                    set(green_max_slide_hand, 'Value', slide_set_max);

                    slide_string_min = str2num(get(green_min_slide_box, 'String'));
                    slide_set_min = ((slide_string_min - green_range(1))/(green_range(2) - green_range(1)));
                    slide_set_min = max([slide_set_min 0]);
                    slider_value_min = (green_range(1) + slide_set_min*(green_range(2) - green_range(1)));
                    set(green_min_slide_box, 'String', num2str(slider_value_min));
                    set(green_min_slide_hand, 'Value', slide_set_min);


                    % Fill in red channel with dummy image
                    path_here = mfilename('fullpath');
                    logo_file = fullfile(fileparts(path_here), 'BMIF_logo.jpg');

                    %disp(logo_file);

                    ax2 = handles.handles.ax2;

                    if exist(logo_file, 'file') == 2;

                        logo_hold = single(imread(logo_file));
                        logo_2 = logo_hold(:,:,1);
                        clear logo_hold
                        %disp(size(logo_2));
                        fill_image = imagesc(Vector2Colormap(-logo_2,handles.Right_color), 'Parent', ax2);
                        set(fill_image, 'Tag', 'fill_image_right', 'HitTest', 'on');

                    else

                        % Dummy data to put into the axes on startup
                        z=peaks(1000);
                        z = z./max(abs(z(:)));
                        fill_image = imshow(z, 'Parent', ax2, 'ColorMap', jet, 'DisplayRange', [min(z(:)) max(z(:))]);
                        set(fill_image, 'Tag', 'fill_image_right', 'HitTest', 'on');
                        freezeColors(ax2);

                    end

                    % Get rid of tick labels
                    set(ax2, 'xtick', [], 'ytick', []);

                    guidata(findobj('Tag', 'TIFF viewer'), handles);

                    Display_images_in_axes;
                    
                else
                    
                    guidata(findobj('Tag', 'TIFF viewer'), handles);
                
                end
                
            elseif channels_now == 2;
                handles.N_channels = 2;
                
                if ~isempty(handles.Load_file)
                
                % Enable right channel
                
                set(red_max_slide_hand, 'Enable', 'on');
                set(red_max_slide_box, 'Enable', 'on');
                set(red_min_slide_hand, 'Enable', 'on');
                set(red_min_slide_box, 'Enable', 'on');
                set(red_min_slide_text, 'Enable', 'on');
                set(red_max_slide_text, 'Enable', 'on');
                set(red_autoscale, 'Enable', 'on');
                set(red_invert, 'Enable', 'on');
                set(red_colormap_listbox, 'Enable', 'on');
                set(red_colormap_text, 'Enable', 'on');
                
                % Expand Img_stack to two channels
        
                    green_frames = 1:2:(handles.N_frames);
                    red_frames = 2:2:(handles.N_frames);

                    Img_hold = zeros(size(handles.Img_stack,1), size(handles.Img_stack,2), handles.N_frames/2, 2);
                    Img_hold(:,:,:,1) = handles.Img_stack(:,:,green_frames);
                    Img_hold(:,:,:,2) = handles.Img_stack(:,:,red_frames);

                    Min_max_hold_left = zeros(handles.N_frames, 2);
                    Min_max_hold_right = zeros(handles.N_frames, 2);
                    Min_max_hold_left = handles.Min_max_left(green_frames, :);
                    Min_max_hold_right = handles.Min_max_left(red_frames, :);

                    handles.Min_max_left = Min_max_hold_left;
                    handles.Min_max_right = Min_max_hold_right;
                    handles.Img_stack = Img_hold;
                    clear Img_hold Min_max_hold_left Min_max_hold_right

                    handles.N_frames = size(handles.Img_stack, 3);

                    if handles.Primary_channel > handles.N_channels
                        handles.Primary_channel = handles.N_channels;
                    end

                    % Figure out where sliders should be with new N_channels

                    slider_step = 1/(handles.N_frames-1);
                    slide_hand = handles.handles.slide_hand;
                    slide_box = handles.handles.slide_box;
                    
                    if handles.N_frames == 1;
                        set(slide_hand, 'SliderStep', [1 1]);
                    
                    else
                        set(slide_hand, 'SliderStep', [1/(handles.N_frames-1) 1/(handles.N_frames-1)]);
                    end
                    
                    set(slide_box, 'String', (1 + round((handles.N_frames - 1)*(get(slide_hand, 'Value')))));

                    green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
                    slider_step_green = 1/((green_range(2)-green_range(1))-1);

                    set(green_max_slide_hand, 'SliderStep', [slider_step_green slider_step_green]);
                    set(green_min_slide_hand, 'SliderStep', [slider_step_green slider_step_green]);

                    slide_string_max = str2num(get(green_max_slide_box, 'String'));
                    slide_set_max = ((slide_string_max - green_range(1))/(green_range(2) - green_range(1)));
                    slide_set_max = min([slide_set_max 1]); 
                    slider_value_max = (green_range(1) + slide_set_max*(green_range(2) - green_range(1)));
                    set(green_max_slide_box, 'String', num2str(slider_value_max));
                    set(green_max_slide_hand, 'Value', slide_set_max);

                    slide_string_min = str2num(get(green_min_slide_box, 'String'));
                    slide_set_min = ((slide_string_min - green_range(1))/(green_range(2) - green_range(1)));
                    slide_set_min = max([slide_set_min 0]); 
                    slider_value_min = (green_range(1) + slide_set_min*(green_range(2) - green_range(1)));
                    set(green_min_slide_box, 'String', num2str(slider_value_min));
                    set(green_min_slide_hand, 'Value', slide_set_min);


                    red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
                    slider_step_red = 1/((red_range(2)-red_range(1))-1);
                    set(red_max_slide_hand, 'SliderStep', [slider_step_red slider_step_red]);
                    set(red_min_slide_hand, 'SliderStep', [slider_step_red slider_step_red]);
                    set(red_max_slide_box, 'String', num2str(handles.Display_range_right(2)));
                    set(red_min_slide_box, 'String', num2str(handles.Display_range_right(1)));

                    % Replot channels
                    
                    NewXLim = [0.5 size(handles.Img_stack, 2)+0.5];
                    NewYLim = [0.5 size(handles.Img_stack, 1)+0.5];
                    set(handles.handles.ax2, 'XLim', NewXLim, 'YLim', NewYLim);


                    guidata(findobj('Tag', 'TIFF viewer'), handles);
                    Display_images_in_axes;
                    
                else
                    
                    set(red_invert, 'Enable', 'on');
                    set(red_colormap_listbox, 'Enable', 'on');
                    set(red_colormap_text, 'Enable', 'on');
                    
                   guidata(findobj('Tag', 'TIFF viewer'), handles); 
                
                end
            
            end
            
                    if handles.N_frames == 1
                        set(handles.handles.Unbind_out, 'Enable', 'off');
                        set(handles.handles.ExpFit_out, 'Enable', 'off');
                        set(slide_hand, 'Enable', 'off')
                        set(slide_box, 'Enable', 'off')
                    else
                        set(handles.handles.Unbind_out, 'Enable', 'on');
                        set(handles.handles.ExpFit_out, 'Enable', 'on');
                        set(slide_hand, 'Enable', 'on')
                        set(slide_box, 'Enable', 'on')
                        
                    end

        end

        function slider_green_max_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_green_here = get(green_max_slide_hand, 'Value');
            slider_check_here = get(green_min_slide_hand, 'Value');
            slider_step = get(green_max_slide_hand, 'SliderStep');
            
            if le(slider_green_here, slider_check_here)
                %disp('slider_check');
                slider_green_here = slider_check_here + slider_step(1);
                set(green_max_slide_hand, 'Value', slider_green_here);
            end    
            
            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            slider_value = round(slider_green_here*(green_range(2) - green_range(1)) + green_range(1));
            
            set(green_max_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_left(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
            
            
            

        end

        function slider_green_max_listener(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_green_here = get(green_max_slide_hand, 'Value');
            slider_check_here = get(green_min_slide_hand, 'Value');
            slider_step = get(green_max_slide_hand, 'SliderStep');
            
            if le(slider_green_here, slider_check_here)
                %disp('slider_check');
                slider_green_here = slider_check_here + slider_step(1);
                set(green_max_slide_hand, 'Value', slider_green_here);
            end 
            
            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            slider_value = round(slider_green_here*(green_range(2) - green_range(1)) + green_range(1));
            
            set(green_max_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_left(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
        
        end

        function edit_green_max_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slide_string = str2num(get(green_max_slide_box, 'String'));
            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            
            if length(slide_string) ~= 1
                slide_set = get(green_max_slide_hand, 'Value');
                slide_str2 = round(green_range(2)+slide_set*(green_range(2) - green_range(1)));
            
            else
        
            slide_set = ((slide_string - green_range(1))/(green_range(2) - green_range(1)));
            slide_range = [get(green_max_slide_hand, 'Min') get(green_max_slide_hand, 'Max')];

                if slide_set > slide_range(2)

                    slide_set = slide_range(2);
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));

                elseif slide_set < slide_range(1)

                    slide_set = slide_range(1);
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));
                    
                else 
                    
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));

                end
        
            end
            
            
            slider_value = slide_str2;
            
            set(green_max_slide_box, 'String', num2str(slider_value));
            set(green_max_slide_hand, 'Value', slide_set);
            
            handles.Display_range_left(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
     
        end

        function slider_green_min_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_green_here = get(green_min_slide_hand, 'Value');
            slider_check_here = get(green_max_slide_hand, 'Value');
            slider_step = get(green_min_slide_hand, 'SliderStep');
            
            if ge(slider_green_here, slider_check_here)
                %disp('slider_check');
                slider_green_here = slider_check_here - slider_step(1);
                set(green_min_slide_hand, 'Value', slider_green_here);
            end 
            

            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            slider_value = round(slider_green_here*(green_range(2) - green_range(1)) + green_range(1));
            
            set(green_min_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_left(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
            

        end

        function slider_green_min_listener(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_green_here = get(green_min_slide_hand, 'Value');
            slider_check_here = get(green_max_slide_hand, 'Value');
            slider_step = get(green_min_slide_hand, 'SliderStep');
            
            if ge(slider_green_here, slider_check_here)
                %disp('slider_check');
                slider_green_here = slider_check_here - slider_step(1);
                set(green_min_slide_hand, 'Value', slider_green_here);
            end 
            
            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            slider_value = round(slider_green_here*(green_range(2) - green_range(1)) + green_range(1));
            
            set(green_min_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_left(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
        
        end

        function edit_green_min_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slide_string = str2num(get(green_min_slide_box, 'String'));
            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            
            if length(slide_string) ~= 1
                slide_set = get(green_max_slide_hand, 'Value');
                slide_str2 = round(green_range(2)+slide_set*(green_range(2) - green_range(1)));
            
            else
        
            slide_set = ((slide_string - green_range(1))/(green_range(2) - green_range(1)));
            slide_range = [get(green_max_slide_hand, 'Min') get(green_max_slide_hand, 'Max')];

                if slide_set > slide_range(2)

                    slide_set = slide_range(2);
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));

                elseif slide_set < slide_range(1)

                    slide_set = slide_range(1);
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));
                    
                else 
                    
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));

                end
        
            end
            
            
            slider_value = slide_str2;
            
            set(green_min_slide_box, 'String', num2str(slider_value));
            set(green_min_slide_hand, 'Value', slide_set);
            
            handles.Display_range_left(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
      
        end

        function popup_green_colormap(hObj, eventdata, handles) %%%%
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            string_here = get(green_colormap_listbox, 'Value');
            handles.Left_color = lower(handles.Colormap_strings{string_here});

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function autoscale_green(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            handles.Autoscale_left = get(green_autoscale, 'Value');
            
            if handles.Autoscale_left == 1;
                set(green_max_slide_hand, 'Enable', 'off');
                set(green_max_slide_box, 'Enable', 'off');
                set(green_min_slide_hand, 'Enable', 'off');
                set(green_min_slide_box, 'Enable', 'off');
                set(green_min_slide_text, 'Enable', 'off');
                set(green_max_slide_text, 'Enable', 'off');
            else
                set(green_max_slide_hand, 'Enable', 'on');
                set(green_max_slide_box, 'Enable', 'on');
                set(green_min_slide_hand, 'Enable', 'on');
                set(green_min_slide_box, 'Enable', 'on');
                set(green_min_slide_text, 'Enable', 'on');
                set(green_max_slide_text, 'Enable', 'on');
            end

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
       
        end

        function invert_green(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            handles.Left_invert = get(green_invert, 'Value');

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function slider_red_max_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_right_here = get(red_max_slide_hand, 'Value');
            slider_check_here = get(red_min_slide_hand, 'Value');
            slider_step = get(red_max_slide_hand, 'SliderStep');
            
            if le(slider_right_here, slider_check_here)
                %disp('slider_check');
                slider_right_here = slider_check_here + slider_step(1);
                set(red_max_slide_hand, 'Value', slider_right_here);
            end 

            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            slider_value = round(slider_right_here*(red_range(2) - red_range(1)) + red_range(1));
            
            set(red_max_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_right(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function slider_red_max_listener(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_right_here = get(red_max_slide_hand, 'Value');
            slider_check_here = get(red_min_slide_hand, 'Value');
            slider_step = get(red_max_slide_hand, 'SliderStep');
            
            if le(slider_right_here, slider_check_here)
                %disp('slider_check');
                slider_right_here = slider_check_here + slider_step(1);
                set(red_max_slide_hand, 'Value', slider_right_here);
            end 
            
            
            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            slider_value = round(slider_right_here*(red_range(2) - red_range(1)) + red_range(1));
            
            set(red_max_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_right(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function edit_red_max_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slide_string = str2num(get(red_max_slide_box, 'String'));
            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            
            if length(slide_string) ~= 1
                slide_set = get(red_max_slide_hand, 'Value');
                slide_str2 = round(red_range(2)+slide_set*(red_range(2) - red_range(1)));
            
            else
        
            slide_set = ((slide_string - red_range(1))/(red_range(2) - red_range(1)));
            slide_range = [get(red_max_slide_hand, 'Min') get(red_max_slide_hand, 'Max')];

                if slide_set > slide_range(2)

                    slide_set = slide_range(2);
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));

                elseif slide_set < slide_range(1)

                    slide_set = slide_range(1);
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));
                    
                else 
                    
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));

                end
        
            end
            
            
            slider_value = slide_str2;
            
            set(red_max_slide_box, 'String', num2str(slider_value));
            set(red_max_slide_hand, 'Value', slide_set);
            
            handles.Display_range_right(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;          


        end

        function slider_red_min_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_right_here = get(red_min_slide_hand, 'Value');
            slider_check_here = get(red_max_slide_hand, 'Value');
            slider_step = get(red_min_slide_hand, 'SliderStep');
            
            if ge(slider_right_here, slider_check_here)
                %disp('slider_check');
                slider_right_here = slider_check_here - slider_step(1);
                set(red_min_slide_hand, 'Value', slider_right_here);
            end 
            
            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            slider_value = round(slider_right_here*(red_range(2) - red_range(1)) + red_range(1));
            
            set(red_min_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_right(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function slider_red_min_listener(hObj, eventdata, handles)
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_right_here = get(red_min_slide_hand, 'Value');
            slider_check_here = get(red_max_slide_hand, 'Value');
            slider_step = get(red_min_slide_hand, 'SliderStep');
            
            if ge(slider_right_here, slider_check_here)
                %disp('slider_check');
                slider_right_here = slider_check_here - slider_step(1);
                set(red_min_slide_hand, 'Value', slider_right_here);
            end 

            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            slider_value = round(slider_right_here*(red_range(2) - red_range(1)) + red_range(1));
            
            set(red_min_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_right(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
          
        end

        function edit_red_min_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slide_string = str2num(get(red_min_slide_box, 'String'));
            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            
            if length(slide_string) ~= 1
                slide_set = get(red_min_slide_hand, 'Value');
                slide_str2 = round(red_range(2)+slide_set*(red_range(2) - red_range(1)));
            
            else
        
            slide_set = ((slide_string - red_range(1))/(red_range(2) - red_range(1)));
            slide_range = [get(red_min_slide_hand, 'Min') get(red_min_slide_hand, 'Max')];

                if slide_set > slide_range(2)

                    slide_set = slide_range(2);
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));

                elseif slide_set < slide_range(1)

                    slide_set = slide_range(1);
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));
                    
                else 
                    
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));

                end
        
            end
            
            
            slider_value = slide_str2;
            
            set(red_min_slide_box, 'String', num2str(slider_value));
            set(red_min_slide_hand, 'Value', slide_set);
            
            handles.Display_range_right(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
          
        end

        function popup_red_colormap(hObj, eventdata, handles) 
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            string_here = get(red_colormap_listbox, 'Value');
            handles.Right_color = lower(handles.Colormap_strings{string_here});

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function autoscale_red(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            handles.Autoscale_right = get(red_autoscale, 'Value');

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            
            if handles.Autoscale_right == 1;
                set(red_max_slide_hand, 'Enable', 'off');
                set(red_max_slide_box, 'Enable', 'off');
                set(red_min_slide_hand, 'Enable', 'off');
                set(red_min_slide_box, 'Enable', 'off');
                set(red_min_slide_text, 'Enable', 'off');
                set(red_max_slide_text, 'Enable', 'off');
            else
                set(red_max_slide_hand, 'Enable', 'on');
                set(red_max_slide_box, 'Enable', 'on');
                set(red_min_slide_hand, 'Enable', 'on');
                set(red_min_slide_box, 'Enable', 'on');
                set(red_min_slide_text, 'Enable', 'on');
                set(red_max_slide_text, 'Enable', 'on');
            end
            
            Display_images_in_axes;

        end
        
        function invert_red(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            handles.Right_invert = get(red_invert, 'Value');

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
           
        end
        
        
        
    end

    function GUI_close_fcn(varargin)
        %
    end

end


