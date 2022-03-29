function updateStateOfGui(obj)
enable = false;
switch obj.guiState
    case 'fokuspokus'
        if obj.gcamReady && obj.etalonsReady
            enable = true;
            obj.initFokPok();
        end
    case 'standalone'
        if obj.imstackReady && obj.resultsReady && obj.imstack.state
            enable = true;
        end
    otherwise
        error('Case %s unknown.',obj.guiState);
end

switch enable
    case true
        buttonState = 'on';
    case false
        buttonState = 'off';
end

if obj.imstackReady
    obj.h.pb.enablePlot1.Value = obj.imstack.figs.plot1.settings.enable;
    obj.h.pb.enablePlot2.Value = obj.imstack.figs.plot2.settings.enable;
    obj.h.pb.enablePlot3.Value = obj.imstack.figs.plot3.settings.enable;
    obj.h.pb.enablePlot4.Value = obj.imstack.figs.plot4.settings.enable;
end

obj.h.pb.analysisSettings.Enable = buttonState;

obj.h.pb.settingsPlot1.Enable = buttonState;
obj.h.pb.settingsPlot2.Enable = buttonState;
obj.h.pb.settingsPlot3.Enable = buttonState;
obj.h.pb.settingsPlot4.Enable = buttonState;

obj.h.pb.enablePlot1.Enable = buttonState;
obj.h.pb.enablePlot2.Enable = buttonState;
obj.h.pb.enablePlot3.Enable = buttonState;
obj.h.pb.enablePlot4.Enable = buttonState;

obj.h.pb.updatePlots.Enable = buttonState;
obj.h.pb.process.Enable = buttonState;
obj.h.pb.processFrame.Enable = buttonState;
obj.h.pb.saveResults.Enable = buttonState;

end