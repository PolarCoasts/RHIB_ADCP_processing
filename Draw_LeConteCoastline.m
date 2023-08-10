function Draw_LeConteCoastline

% get coastine
filepath=fileparts(mfilename('fullpath'));
coastfile=[filepath '/Alaska_Coast_63360_ln/Alaska_Coast.shp'];

bbox=[-132.65 -132.3; 56.7 56.9];
s=shaperead(coastfile,'BoundingBox',bbox');

for i=1:length(s)
    X=s(i).X;
    Y=s(i).Y;
    Y(isnan(X))=[];
    X(isnan(X))=[];
    coastline(i)=plot(X,Y,'k','LineWidth',1,'DisplayName','Coastline');
    hold on
end

set(gca,'dataaspectratio',[1 cos(2*pi*56.8/360) 1])


