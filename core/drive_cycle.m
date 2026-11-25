function [t, v, grade, name] = drive_cycle(cycle, dt, opts)
%DRIVE_CYCLE  Speed (m/s) and road grade (rise/run) on a uniform time grid.
%   cycle = 'MIDC'     : 4 x ECE-15 + EUDC (low-power, 90 km/h cap), modal approximation
%           'HILL'     : ghat descent at 40 km/h, opts.grade (default -0.06) over opts.L_km (12 km)
%           'HARDSTOP' : 5 stops from 80 km/h at opts.decel m/s^2 (default 3)
%           '<file>.csv': two or three columns: time_s, speed_kmh[, grade]
%   NOTE: the MIDC here is built from the modal definition. For the report,
%   load the official ARAI/dieselnet 1 Hz trace via the CSV option.

if nargin < 2, dt = 0.1; end
if nargin < 3, opts = struct(); end
name = cycle;
grade_pts = [];

switch upper(cycle)
    case 'MIDC'
        ece = [0 0; 11 0; 15 15; 23 15; 25 10; 28 0; 49 0; 54 15; 56 15; 61 32; ...
               85 32; 93 10; 96 0; 117 0; 122 15; 124 15; 133 35; 135 35; 143 50; ...
               155 50; 163 35; 176 35; 178 35; 185 10; 188 0; 195 0];
        eudc = [0 0; 20 0; 25 15; 27 15; 36 35; 38 35; 46 50; 48 50; 61 70; ...
                111 70; 119 50; 188 50; 201 70; 251 70; 273 90; 346 90; 370 30; 380 0; 400 0];
        pts = ece;
        for r = 1:3
            pts = [pts; ece(2:end,1) + pts(end,1), ece(2:end,2)]; %#ok<AGROW>
        end
        pts = [pts; eudc(2:end,1) + pts(end,1), eudc(2:end,2)];
    case 'HILL'
        g  = getf(opts, 'grade', -0.06);
        L  = getf(opts, 'L_km', 12) * 1000;
        vc = 40;                          % km/h
        t_acc = 10; t_cru = L / (vc/3.6); t_dec = 8;
        pts = [0 0; 5 0; 5+t_acc vc; 5+t_acc+t_cru vc; 5+t_acc+t_cru+t_dec 0; 5+t_acc+t_cru+t_dec+10 0];
        grade_pts = [0 0; 5+t_acc g; 5+t_acc+t_cru g; 5+t_acc+t_cru+0.01 0; pts(end,1) 0];
    case 'HARDSTOP'
        a_b = getf(opts, 'decel', 3.0);   % m/s^2 braking
        a_a = 2.0;  vmax = 80;            % km/h
        t_up = (vmax/3.6)/a_a; t_dn = (vmax/3.6)/a_b;
        seg = [0 0; 10 0; 10+t_up vmax; 30+t_up vmax; 30+t_up+t_dn 0; 40+t_up+t_dn 0];
        pts = seg;
        for r = 1:4
            pts = [pts; seg(2:end,1) + pts(end,1), seg(2:end,2)]; %#ok<AGROW>
        end
    otherwise
        M = csvread(cycle, 1, 0);         % header row skipped
        pts = M(:, 1:2);
        if size(M, 2) >= 3, grade_pts = M(:, [1 3]); end
end

t = (0:dt:pts(end,1))';
v = interp1(pts(:,1), pts(:,2), t, 'linear') / 3.6;
if isempty(grade_pts)
    grade = zeros(size(t));
else
    grade = interp1(grade_pts(:,1), grade_pts(:,2), t, 'previous', 0);
end
end

function x = getf(s, f, d)
if isfield(s, f), x = s.(f); else, x = d; end
end
