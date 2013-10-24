filename = 'L16-caud023.h5';
treatments = loadEntrainTreatments(filename);

%Treatment 1
data = loadEntrainData(filename,treatments,1);
data = findbursts_gui(data, 'threshold', [0.410379 0.225777 0.138209 ], ...
    'interburstdur', [0.200000 0.200000 0.200000 ], 'minspikes', [3.000000 3.000000 2.000000 ], 'quiet');

[mn1,R1] = angmean(2*pi*data.burstphase);
phasemn(1,:) = mod(mn1 / (2*pi), 1);
R(1,:) = R1;
stimfreq(1) = treatments.frequencyhz(1);
noiseamp(1) = treatments.noisestddeg(1);

%Treatment 3
data = loadEntrainData('L16-caud023.h5',treatments,3);

data = findbursts_gui(data, 'threshold', [0.456235 0.260716 0.18493], 'interburstdur', [0.2 0.2 0.2], 'minspikes', [4 2 4], 'quiet');

[mn1,R1] = angmean(2*pi*data.burstphase);
phasemn(3,:) = mod(mn1 / (2*pi), 1);
R(3,:) = R1;
stimfreq(3) = treatments.frequencyhz(1);
noiseamp(3) = treatments.noisestddeg(1);

%Treatment 5 - very short
data = loadEntrainData('L16-caud023.h5',treatments,5);

data = findbursts_gui(data, 'threshold', [0.41833 0.296844 0.188282], 'interburstdur', [0.2 0.15 0.17], 'minspikes', [4 2 2], 'quiet');

good=data.burstt>404;
[mn1,R1] = angmean(2*pi*data.burstphase(good(:,1),1));
phasemn(5,1) = mod(mn1 / (2*pi), 1);
R(5,1) = R1;
[mn1,R1] = angmean(2*pi*data.burstphase(good(:,2),2));
phasemn(5,2) = mod(mn1 / (2*pi), 1);
R(5,2) = R1;
[mn1,R1] = angmean(2*pi*data.burstphase(good(:,3),3));
phasemn(5,2) = mod(mn1 / (2*pi), 1);
R(5,3) = R1;

stimfreq(5) = treatments.frequencyhz(1);
noiseamp(5) = treatments.noisestddeg(1);
