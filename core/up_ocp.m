function U = up_ocp(y)
%UP_OCP  NMC811 open-circuit potential vs stoichiometry (Chen et al. 2020 fit).
U = -0.8090 * y + 4.4875 - 0.0428 * tanh(18.5138 * (y - 0.5542)) ...
    - 17.7326 * tanh(15.7890 * (y - 0.3117)) + 17.5842 * tanh(15.9308 * (y - 0.3120));
end
