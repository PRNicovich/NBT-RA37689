function Dims = CZIDimensions(varargin)

fname = varargin{1};

fobj = fopen(fname);

%%%%% Read in primary file header

Header.FileSegmentID = fread(fobj, 16, 'uint8=>char')';
Header.AllocatedSize = fread(fobj, 1, 'int64')';
Header.UsedSize = fread(fobj, 1, 'int64')';

Header.MajorVersion = fread(fobj, 1, 'int');
Header.MinorVersion = fread(fobj, 1, 'int');
Header.Reserved1 = fread(fobj, 1, 'int');
Header.Reserved2 = fread(fobj, 1, 'int');
Header.PrimaryFileGuid = dec2hex(fread(fobj, 16, 'uint8')');
Header.FileGuid = dec2hex(fread(fobj, 16, 'uint8')');
Header.FilePart = fread(fobj, 1, 'int32');
Header.DirectoryPosition = fread(fobj, 1, 'int64');
Header.MetadataPosition = fread(fobj, 1, 'int64');
Header.UpdatePending = dec2bin(fread(fobj, 1, 'int32'));
Header.AttachmentDirectoryPosition = fread(fobj, 1, 'int64');


%%%%%%%%%%%%%%
% Find and read Directory Segment
fseek(fobj, Header.DirectoryPosition, 'bof');
Header.Directory.SegmentID = fread(fobj, 16, 'uint8=>char')';
Header.Directory.AllocatedSize = fread(fobj, 1, 'int64');
Header.Directory.UsedSize = fread(fobj, 1, 'int64');
Header.Directory.NumEntries = fread(fobj, 1, 'int');
fseek(fobj, 124, 'cof');
% Gotta loop over these, probably

for m = 1:Header.Directory.NumEntries
    
    Header.Directory.Entry(m).Entry = fread(fobj, 2, 'uint8=>char')';
    Header.Directory.Entry(m).PixelType = fread(fobj, 1, 'int32');
    Header.Directory.Entry(m).FilePosition = fread(fobj, 1, 'int64');
    Header.Directory.Entry(m).FilePart = fread(fobj, 1, 'int32');
    Header.Directory.Entry(m).Compression = fread(fobj, 1, 'int32');
    Header.Directory.Entry(m).PyramidType = fread(fobj, 1, 'uint8');
    ThrowawayBytes = fread(fobj, 5, 'uint8');
    Header.Directory.Entry(m).DimensionCount = fread(fobj, 1, 'int32');

    % Another loop here
    for k = 1:Header.Directory.Entry(m).DimensionCount
        
        Header.Directory.Entry(m).DimensionEntries(k).Dimension = fread(fobj, 4, 'uint8=>char')';
        Header.Directory.Entry(m).DimensionEntries(k).Start = fread(fobj, 1, 'int32');
        Header.Directory.Entry(m).DimensionEntries(k).Size = fread(fobj, 1, 'int32');
        Header.Directory.Entry(m).DimensionEntries(k).StartCoordinate = fread(fobj, 1, 'float32');
        Header.Directory.Entry(m).DimensionEntries(k).StoredSize = fread(fobj, 1, 'int32');
        
    end
    
end

% Pull out dimensions in X x Y x Z x T x C

% Z, T, and C are different entries.  Each Entry a single X x Y plane.
for k = 1:length(Header.Directory.Entry)
    
    % Dimensions here in bytes
    
    Dim.X(k) = Header.Directory.Entry(k).DimensionEntries(1).Size;
    Dim.Y(k) = Header.Directory.Entry(k).DimensionEntries(2).Size;
    Dim.Z(k) = Header.Directory.Entry(k).DimensionEntries(3).Start+1;
    Dim.T(k) = Header.Directory.Entry(k).DimensionEntries(4).Start+1;
    Dim.C(k) = Header.Directory.Entry(k).DimensionEntries(5).Start+1;
    
    Dim.FilePosition(k) = Header.Directory.Entry(k).FilePosition;
    


end

Dimensions.X = unique(Dim.X);
Dimensions.Y = unique(Dim.Y);
Dimensions.Z = numel(unique(Dim.Z));
Dimensions.T = numel(unique(Dim.T));
Dimensions.C = numel(unique(Dim.C));

fclose(fobj);

Dims = Dimensions;