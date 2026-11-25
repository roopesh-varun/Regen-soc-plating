function vreport(fid, id, ok, msg)
%VREPORT  Print and log one verification line.
s = 'FAIL'; if ok, s = 'PASS'; end
fprintf('%s  %s  %s\n', id, s, msg); fprintf(fid, '%s  %s  %s\n', id, s, msg);
end
