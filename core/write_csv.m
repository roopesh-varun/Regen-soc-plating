function write_csv(file, names, A)
%WRITE_CSV  Write a numeric matrix with a header row (works in MATLAB and Octave).
fid = fopen(file, 'w');
fprintf(fid, '%s\n', strjoin(names, ','));
fmt = [repmat('%.6g,', 1, size(A, 2) - 1), '%.6g\n'];
fprintf(fid, fmt, A');
fclose(fid);
end
