function [fig,ax]=PlotTrack(adcp,options)

arguments
    adcp struct                         % structure containing adcp data 
    options.range (1,:) double=nan      % indices of data to plot (range has precedence over start/endtime)
    options.starttime=[]                % starting time of data to plot
    options.endtime=[]                  % ending time of data to plot
end

% This function plots the GPS track from the given ADCP record
% If the data was collected in LeConte Bay, it will include the local coastline and insert a simple map of the bay
%
% usage:
%   [fig,ax]=PlotTrack(adcp,options)

% use nuc_time if available
if isfield(adcp,'nuc_time')
    time=adcp.nuc_time;
else
    time=adcp.time;
end

% determine range of data from input
if isempty(options.starttime) 
    startI=1;
else
    [~,startI]=min(abs(datenum(options.starttime)-time));
end

if isempty(options.endtime)
    endI=length(time);
else
    [~,endI]=min(abs(datenum(options.endtime)-time));
end

if isnan(options.range)
    if endI<startI
        error('Starttime must precede endtime')
    end
    options.range=startI:endI;
end

% different variable names were used with different versions of processing code
if isfield(adcp,'gps')
    lon=adcp.gps.lon;
    lat=adcp.gps.lat;
else
    lon=adcp.vessel_lon;
    lat=adcp.vessel_lat;
end

% determine if data is from LeConte
minlon=min(lon,[],'omitnan'); maxlon=max(lon,[],'omitnan');
minlat=min(lat,[],'omitnan'); maxlat=max(lat,[],'omitnan');
if minlon>-133 && maxlon<-132 && minlat>56 && maxlat<57
    LC=1;
else
    LC=0;
end
% don't plot terminus line if data is far from terminus, even if user has set it to be added
if maxlat<56.83 || maxlon<-132.38
    options.addterm=0;
end

% plot the figure
fig=figure('Position',[10 10 1000 800]);
ax=axes('Position',[.08 .08 .86 .88]);
% For LeConte data, include coastline 
if LC
    Draw_LeConteCoastline
    if maxlat<56.84
        maxlat=56.84;
    end
    if maxlon<-132.35
        maxlon=-132.36;
    end
    xbuff=(maxlon-minlon)*.2;
    ybuff=(maxlat-minlat)*.2;
    xlim([minlon-xbuff maxlon+xbuff])
    ylim([minlat-ybuff maxlat+ybuff])
    text(maxlon+xbuff,maxlat+ybuff,'Terminus as of 8/28/2023','FontSize',16,'HorizontalAlignment','right','VerticalAlignment','top')
end
hold on
plot(lon(options.range),lat(options.range),'Color',[.5 .5 .5],'LineWidth',2)
tt=scatter(lon(options.range),lat(options.range),30,adcp.nuc_time(options.range),'filled');
cbar=colorbar;
clim([adcp.nuc_time(options.range(1)) adcp.nuc_time(options.range(end))])
datetick(cbar,'y')
cbar.Label.String='Deployment Time';
cbar.Label.FontSize=16;
set(gca,'FontSize',16)
title(string(datetime(adcp.nuc_time(1),'ConvertFrom','datenum')))

% For LeConte data, add insert of entire fjord
if LC
    if isMATLABReleaseOlderThan('R2022b')
        axpos=ax.Position;
    else
        axpos=tightPosition(ax);
    end
    ww=.12; hh=.12;
    xx=axpos(1)+.01; yy=axpos(2)+axpos(4)-.13;
    axb=axes('Position',[xx yy ww hh]);
    Draw_LeConteCoastline
    hold on
    xloc=(minlon+maxlon)/2;
    yloc=(minlat+maxlat)/2;
    plot(xloc,yloc,'rp','MarkerSize',12,'MarkerFaceColor','r')
    xticklabels([])
    yticklabels([])
end





