% This script allows a user to search through ADCP beam data and locate specific features in space
clear

basepath=[]; %directory where processed data is located

addterm=1; %set to 1 to add terminus line
termfolder='processed/Drone/Mavic3E/terminusPosition/'; %directory where terminus lines are located (should be under basepath)

%% Select a deployment to search
adcp=LoadDeployment(basepath);
%% Select terminus to plot
if addterm
    fprintf("\nDeployment begins "+string(datetime(adcp.nuc_time(1),'ConvertFrom','datenum'))+"\n\n")
    [termfile,termdate,termdt]=AddTerm(basepath,termfolder);
end

%% Remove rhib velocity from beam velocities
adcp=adcp_earth2beam(adcp);

%% Get locations for each beam observation
adcp=beamlocations(adcp);

%% Determine if data is from LeConte (to draw coastline on map)
% different variable names were used with different versions of processing code
if isfield(adcp,'gps')
    lon=adcp.gps.lon;
    lat=adcp.gps.lat;
else
    lon=adcp.vessel_lon;
    lat=adcp.vessel_lat;
end

minlon=min(lon,[],'omitnan'); maxlon=max(lon,[],'omitnan');
minlat=min(lat,[],'omitnan'); maxlat=max(lat,[],'omitnan');
if minlon>-133 && maxlon<-132 && minlat>56 && maxlat<57
    LC=1;
else
    LC=0;
end

%% Display an interactive plot
nb=adcp.config.n_beams;

c1=.05; c2=.6;
r=linspace(.99,.05,nb+1); r=r(2:end);
w1=.5; w2=.35; h1=.9*abs(diff(r(1:2))); h2=.97-r(end-1);

fig=figure('Position',[10 10 2000 1000]);

for i=1:nb
    time=adcp.nuc_time;
    depth=adcp.cell_depth;
    vel=squeeze(adcp.bvel_water(:,i,:));
    corr=squeeze(adcp.corr(:,i,:));
    echo=squeeze(adcp.echo_intens(:,i,:));
    axc(i)=axes('Position',[c1 r(i) w1 h1]);
    [hc(i),cbar_c]=PlotData(time,depth,corr,i,nb,parula,[64 128],"Correlation");
    axc(i).Visible='off'; cbar_c.Visible='off';
    axe(i)=axes('Position',[c1 r(i) w1 h1]);
    [he(i),cbar_e]=PlotData(time,depth,echo,i,nb,parula,[50 200],"Echo Intensity");
    axe(i).Visible='off'; cbar_e.Visible='off';
    ax(i)=axes('Position',[c1 r(i) w1 h1]);
    [h(i),cbar_v]=PlotData(time,depth,vel,i,nb,cmocean('balance'),[-1 1],"Beam Velocity (m/s)");
    if i==1
        title(string(datetime(time(1),'ConvertFrom','datenum')))
    end
end

ax(nb+1)=axes('Position',[c2 r(end-1) w2 h2]);
plot(adcp.vessel_lon,adcp.vessel_lat,'LineWidth',1,'Color',[.5 .5 .5])
hold on
scatter(adcp.vessel_lon(1),adcp.vessel_lat(1),80,[.4 .4 .4],'filled')
if LC
    if ~isempty(termfile)
        Draw_LeConteCoastline(termfile)
    else
        Draw_LeConteCoastline()
    end
    if addterm
        if maxlat<56.84
            maxlat=56.84;
        end
        if maxlon<-132.35
            maxlon=-132.36;
        end
    end
    % do some calculations to make sure there's plenty of map space
    lonext=maxlon-minlon;
    latext=maxlat-minlat;
    if lonext<2*latext
        xf=.4;
    else
        xf=.2;
    end
    xbuff=(lonext)*xf;
    ybuff=(latext)*.2;
    xlim([minlon-xbuff maxlon+xbuff])
    ylim([minlat-ybuff maxlat+ybuff])
end
text(.95,.95,"Terminus: "+string(termdt),'Units','normalized','HorizontalAlignment','right')
set(gca,'FontSize',16)

linkaxes([ax(1:nb) axe axc])
drawnow
for i=1:nb
    blat=squeeze(adcp.beam_loc_lat(:,i,:));
    blon=squeeze(adcp.beam_loc_lon(:,i,:));
    h(i).ButtonDownFcn={@ClickData blat blon ax(nb+1)};
    he(i).ButtonDownFcn={@ClickData blat blon ax(nb+1)};
    hc(i).ButtonDownFcn={@ClickData blat blon ax(nb+1)};
end

ClearPointsBTN=uicontrol(fig,'String','Clear Points','Callback',{@ClearPoints ax(nb+1) ax(1:nb) axe axc},'Position',[1580 150 120 40],'FontSize',16);
DataBTNs=uibuttongroup(fig,'SelectionChangedFcn',{@SwitchData ax(1:nb) axe axc h he hc cbar_v cbar_e cbar_c},'Position',[.57 .065 .08 .15],'BorderType','none');
BvelBTN=uicontrol(DataBTNs,'Style','togglebutton','String','Beam Velocity','Position',[10 86 120 40],'FontSize',16);
CorrBTN=uicontrol(DataBTNs,'Style','togglebutton','String','Correlation','Position',[10 45 120 40],'FontSize',16);
EchoBTN=uicontrol(DataBTNs,'Style','togglebutton','String','Echo Intensity','Position',[10 5 120 40],'FontSize',16);

%% local functions
function [h,cbar]=PlotData(time,depth,data,i,nb,cmap,vlim,clabel)
    h=pcolor(time,depth,data);
    shading flat; axis ij;
    ca=gca;
    colormap(ca,cmap)
    clim(vlim)
    text(1.01,.5,"Beam "+i,'FontSize',16,'FontWeight','bold','Units','normalized','Rotation',-90,'HorizontalAlignment','center')
    if i<nb
        xticklabels([]);
        cbar=[];
    else
        datetick('x','keeplimits')
        xlabel('Time')
        cbar=colorbar('southoutside','Position',[.57 .05 .1 .015]);
        cbar.Label.String=clabel;
        cbar.Label.FontSize=16;
    end
    ylabel('Depth (m)')
    set(gca,'FontSize',16)
end

function pt=ClickData(obj,event,blat,blon,mapax)
    x=obj.XData;
    y=obj.YData;
    pt=event.IntersectionPoint;
    [~,xi]=min(abs(pt(1)-x));
    [~,yi]=min(abs(pt(2)-y));
    sel_lat=blat(yi,xi);
    sel_lon=blon(yi,xi);
    scatter(mapax,sel_lat,sel_lon,80,'r','filled')
    delete(findall(gca,'Type','hggroup'))
end

function ClearPoints(src,event,mapax,datax1,datax2,datax3)
    delete(findobj(mapax,'type','scatter'))
    for i=1:length(datax1)
        delete(findall(datax1(i),'Type','hggroup'))
        delete(findall(datax2(i),'Type','hggroup'))
        delete(findall(datax3(i),'Type','hggroup'))
    end
end

function SwitchData(src,event,ax,axe,axc,h,he,hc,cbar,cbar_e,cbar_c)
    if strcmp(event.NewValue.String,"Beam Velocity")
        for i=1:length(ax)
            ax(i).Visible='on';
            axe(i).Visible='off';
            axc(i).Visible='off';
            h(i).Visible='on';
            he(i).Visible='off';
            hc(i).Visible='off';
            cbar.Visible='on';
            cbar_e.Visible='off';
            cbar_c.Visible='off';
        end
    elseif strcmp(event.NewValue.String,"Echo Intensity")
         for i=1:length(ax)
            ax(i).Visible='off';
            axe(i).Visible='on';
            axc(i).Visible='off';
            h(i).Visible='off';
            he(i).Visible='on';
            hc(i).Visible='off';
            cbar.Visible='off';
            cbar_e.Visible='on';
            cbar_c.Visible='off';
        end
    elseif strcmp(event.NewValue.String,"Correlation")
        for i=1:length(ax)
            ax(i).Visible='off';
            axe(i).Visible='off';
            axc(i).Visible='on';
            h(i).Visible='off';
            he(i).Visible='off';
            hc(i).Visible='on';
            cbar.Visible='off';
            cbar_e.Visible='off';
            cbar_c.Visible='on';
        end
    end
end




