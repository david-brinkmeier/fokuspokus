function showcaustic(imstack,transparent)

if length(imstack.axis.src.z) == 1
    warning('cannot draw caustic if there is only one profile')
    return
end

if isempty(imstack.img.ROI)
    fignames = {'caustic unprocessed','caustic denoised / processed'};
else
    fignames = {'caustic unprocessed [masked]','caustic denoised / processed [masked]'};
end

for i = [1,2]
    % preallocate data structure for slice plot; permute from [y x z] to [z y x]
    if i == 1
        output_slice = permute(imstack.img.src,[3 1 2]);
        output_slice(output_slice <= 0) = NaN;
        xaxis = imstack.axis.src.x;
        yaxis = imstack.axis.src.y;
        zaxis = imstack.axis.src.z;
    elseif i == 2
        output_slice = permute(imstack.img.denoised,[3 1 2]);
        output_slice(output_slice <= 0) = NaN;
        xaxis = imstack.axis.denoised.x;
        yaxis = imstack.axis.denoised.y;
        zaxis = imstack.axis.denoised.z;
    end
    
    fig = genORselectfigbyname(fignames{i});
    clf(fig); set(fig,'units','pixel')
    ax = axes(fig); hold(ax,'on'), ax.Box = 'on'; colormap(ax,'jet')
    
    % make slice plot
    sliceplot = slice(ax,yaxis.*1e6,zaxis.*1e6,xaxis.*1e6,output_slice,[],zaxis.*1e6,[]);
    
    shading(ax,'flat')
    view(ax,40,10)
    alpha(ax,'color')
    
    % scale data
    daspect(ax,[1 .1*abs(zaxis(end)-zaxis(1))/max(xaxis) 1])
    % transparency
    if transparent(i) == 1
        alphamap(ax,[zeros(1,1),linspace(0.025,1,256)])
    else
        alphamap(ax,linspace(1,1,256));
    end
    
    % set limits [x y z] -> [z x y]; z->x, y->x, y->z
    zlim(ax,[xaxis(1) xaxis(end)].*1e6), zlabel('z distance in µm')
    xlim(ax,[yaxis(1) yaxis(end)].*1e6), xlabel('x distance in µm')
    ylim(ax,[zaxis(1) zaxis(end)].*1e6), ylabel('y distance in µm')
end

end