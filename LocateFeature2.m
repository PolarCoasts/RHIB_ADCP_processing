function [ax,axc,axe]=LocateFeature2(adcp,term)
%This is similar to the script LocateFeature, but set up for use during post-processing
%   it is expected that adcp_earth2beam and CalculateBeamLocations have already been run on input adcp

%set new origin (these numbers are based on 2018 terminus location)
xorig=661423.22262933;
yorig=6301938.85082928;

trackx=adcp.vessel_X-xorig;
tracky=adcp.vessel_Y-yorig;

termx=term.X-xorig;
termy=term.Y-yorig;

%% Display an interactive plot
nb=adcp.config.n_beams;

c1=.05; c2=.6;
r=linspace(.99,.05,nb+1); r=r(2:end);
w1=.5; w2=.35; h1=.9*abs(diff(r(1:2))); h2=.97-r(end-1);

fig=figure('Position',[10 10 2200 1200]);

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
plot(trackx,tracky,'LineWidth',1,'Color',[.5 .5 .5])
hold on
scatter(trackx(1),tracky(1),80,[.4 .4 .4],'filled')
plot(termx,termy,'b','LineWidth',2)

xlim([-1200 -200])
ylim([-500 1000])
axis equal

linkaxes([ax(1:nb) axe axc])
drawnow
for i=1:nb
    by=squeeze(adcp.beam_locations(:,i,:,2))-yorig;
    bx=squeeze(adcp.beam_locations(:,i,:,1))-xorig;
    h(i).ButtonDownFcn={@ClickData by bx ax(nb+1)};
    he(i).ButtonDownFcn={@ClickData by bx ax(nb+1)};
    hc(i).ButtonDownFcn={@ClickData by bx ax(nb+1)};
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

function pt=ClickData(obj,event,by,bx,mapax)
    x=obj.XData;
    y=obj.YData;
    pt=event.IntersectionPoint;
    [~,xi]=min(abs(pt(1)-x));
    [~,yi]=min(abs(pt(2)-y));
    sel_x=bx(yi,xi);
    sel_y=by(yi,xi);
    scatter(mapax,sel_x,sel_y,80,'r','filled')
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


end

