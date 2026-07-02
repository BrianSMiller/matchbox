function s = tf(cond, yes, no)
% TF  Tiny ternary for tidy status strings.
if cond, s = yes; else, s = no; end
end
