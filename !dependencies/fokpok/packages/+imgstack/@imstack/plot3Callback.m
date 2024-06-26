function plot3Callback(obj,~,source) % obj,event,source
idx = obj.figs.plot3.fig.UserData;
maxlen = length(obj.axis.src.z);

if source.VerticalScrollCount > 0
    idx = idx+1;
elseif source.VerticalScrollCount < 0
    idx = idx-1;
end

if idx < 1
    return
end

if idx > maxlen
    return
end

obj.figs.plot3.fig.UserData = idx;
obj.plot3(true)
end