% Calculate IMU preintegration between poses in the sliding window
% Reset all temporary variables
residual = [];
r_R = zeros(window_size-1, 3); % attitude error preintegration between poses
r_V = zeros(window_size-1, 3); % velocity error preintegration between poses
r_P = zeros(window_size-1, 3); % position error preintegration between poses

for vertice=1:window_size-1
    imu_sample_from = ((window_range_from - 1) + (vertice - 1)) * kf_interval_imu + 1;
    imu_sample_to = ((window_range_from - 1) + vertice) * kf_interval_imu;
    
    deltaR = eye(3);
    deltaV = zeros(3,1);
    deltaP = zeros(3,1);
    
    for i=imu_sample_from:imu_sample_to
        % DeltaR
        omega = gyro.Data(i,:);
        omega_an = norm(omega)*imu_sampling_time; % rotation angle
        if (omega_an < 0.005)
            omega_ax = [1 0 0];
        else
            omega_ax = omega/omega_an;
        end
        deltaRik = axang2rotm([omega_ax omega_an]);
        % DeltaV
        vel = accel.Data(i,:);
        deltaVelik = deltaR*(accel.Data(i,:))'*imu_sampling_time;
        % DeltaP
        deltaPik1 = 3/2 * deltaR * (accel.Data(i,:))' * (imu_sampling_time.^2);
        deltaPik = deltaV * imu_sampling_time + 1/2 * deltaR * (accel.Data(i,:))' * (imu_sampling_time.^2);
        deltaP = deltaP + deltaPik;
        % After calculating DeltaV and DeltaP, it is possible to update
        % deltaR, deltaV
        deltaR = deltaR * deltaRik;
        deltaV = deltaV + deltaVelik;
    end
    
    att_axang = rotm2axang(deltaR);
    att = att_axang(4)*(att_axang(1:3));
    r_R(vertice,:) = att;
    r_V(vertice,:) = deltaV';
    r_P(vertice,:) = deltaP';
    
end

% Calculate residual vector
for i=1:(window_size-1)
    % Residual of attitude error between keyframes
    dR = Ro(:,:,i)'*Ro(:,:,i+1);
    dr = rotm2axang(dR);
    dr_an = dr(4);
    dr_ax = dr(1:3);
    dr = dr_ax * dr_an; % log of attitude difference between keyframe i and i+1
    ddr = dr - r_R(i,:); 
    residual=[residual ddr];
    % Residual of velocity error between keyframes
    dv = Ro(:,:,i)' * (Vo(i+1,:)-Vo(i,:)-[0 0 9.81]*imu_sampling_time*kf_interval_imu)';
    ddv = dv' - r_V(i,:);
    residual=[residual ddv];
    % Residual of position error between keyframes
    dp = Ro(:,:,i)' * (Po(i+1,:)-Po(i,:)-Vo(i,:)*imu_sampling_time*kf_interval_imu-0.5*[0 0 9.81]*(imu_sampling_time*kf_interval_imu).^2)';
    ddp = dp' - r_P(i,:);
    residual=[residual ddp];
    % Residual of photometric error of keyframes
    for lm=1:num_of_landmarks
        xyzl = Ro(:,:,i)'*(Lo(lm,:) - Po(i,:))'; % Predicted landmark's position in camera's frame
        lmip = focal_length*[xyzl(1)/xyzl(3) xyzl(2)/xyzl(3)]; % projection to image plan eq, using focal length 0.024m
        % lmip is predicted location of landmark in the image plane
        cam_sample = ((window_range_from - 1) + (i - 1)) * kf_interval_cam + 1; % the keyframe corresponds to the camera frame of cam_sample
        switch lm
            case 1
                lmip_m = feature.Data(cam_sample,:); % measurement of landmark at the currennt keyframe time
            case 2 
                lmip_m = feature1.Data(cam_sample,:); % measurement of landmark at the currennt keyframe time
            case 3
                lmip_m = feature2.Data(cam_sample,:); % measurement of landmark at the currennt keyframe time
        end
        ephoto = lmip - lmip_m;
        residual=[residual ephoto];
    end
end

% Residual of photometric error of keyframes
i = window_size;
for lm=1:num_of_landmarks
        xyzl = Ro(:,:,i)'*(Lo(lm,:) - Po(i,:))'; % Predicted landmark's position in camera's frame
        lmip = focal_length*[xyzl(1)/xyzl(3) xyzl(2)/xyzl(3)]; % projection to image plan eq, using focal length 0.024m
        % lmip is predicted location of landmark in the image plane
        cam_sample = ((window_range_from - 1) + (i - 1)) * kf_interval_cam + 1; % the keyframe corresponds to the camera frame of cam_sample
        switch lm
            case 1
                lmip_m = feature.Data(cam_sample,:); % measurement of landmark at the currennt keyframe time
            case 2 
                lmip_m = feature1.Data(cam_sample,:); % measurement of landmark at the currennt keyframe time
            case 3
                lmip_m = feature2.Data(cam_sample,:); % measurement of landmark at the currennt keyframe time
        end
        ephoto = lmip - lmip_m;
        residual=[residual ephoto];
    end