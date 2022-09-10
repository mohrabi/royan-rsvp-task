close all
clear
clc

devs = daq.getDevices;
sessionHandler = daq.createSession('ni');
[ch, idx] = addDigitalChannel(sessionHandler, ...
    'Dev1', 'Port1/Line0', 'OutputOnly');
outputSingleScan(sessionHandler, 1)
%%
outputSingleScan(sessionHandler, 0)
removeChannel(sessionHandler, idx)