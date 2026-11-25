"""Reference data from PyBaMM DFN (O'Kane 2022 / Chen 2020 LG M50 parameter set).
Writes CSV time series (current, terminal voltage, anode potential at the separator)
used to fit and validate the reduced cell model in core/cell_*.m.
Run: python3 dfn_reference.py   (needs pybamm, numpy)"""
import pybamm, numpy as np, json, os
pybamm.set_logging_level("ERROR")
out = "dfn_data"; os.makedirs(out, exist_ok=True)

def params(T_C):
    p = pybamm.ParameterValues("OKane2022")
    p.update({"Upper voltage cut-off [V]": 4.6, "Lower voltage cut-off [V]": 2.0,
              "Ambient temperature [K]": 273.15 + T_C, "Initial temperature [K]": 273.15 + T_C})
    return p

# stoichiometry window (SoC 0..1 maps linearly between these)
p0 = params(25)
lp = pybamm.LithiumIonParameters()
esoh = pybamm.lithium_ion.ElectrodeSOHSolver(p0, lp)
s = esoh.solve({"V_min": 2.5, "V_max": 4.2, "Q_n": p0.evaluate(lp.n.Q_init),
                "Q_p": p0.evaluate(lp.p.Q_init), "Q_Li": p0.evaluate(lp.Q_Li_particles_init)})
win = {k: float(s[k]) for k in ["x_0", "x_100", "y_0", "y_100", "Q"]}
json.dump(win, open(f"{out}/window.json", "w"), indent=1)
print(win)

def run(T_C, soc0, steps, tag):
    """steps: list of (duration_s, current_A) on the 5 Ah cell, current positive = CHARGE,
    or a 2-column array (t, I) for a drive cycle sampled at 0.5 s."""
    p = params(T_C)
    if isinstance(steps, np.ndarray):
        # PyBaMM convention: positive current = discharge
        exp = pybamm.Experiment([pybamm.step.current(np.c_[steps[:, 0], -steps[:, 1]])])
    else:
        exp = pybamm.Experiment([pybamm.step.current(-i, duration=d, period=0.5) if i != 0
                                 else pybamm.step.rest(duration=d, period=0.5) for d, i in steps])
    m = pybamm.lithium_ion.DFN()
    sim = pybamm.Simulation(m, parameter_values=p, experiment=exp)
    sol = sim.solve(initial_soc=soc0)
    tt = sol["Time [s]"].entries
    V = sol["Voltage [V]"].entries
    phi = sol["Negative electrode surface potential difference at separator interface [V]"].entries
    xs = sol["X-averaged negative particle surface stoichiometry"].entries
    xa = sol["Average negative particle stoichiometry"].entries
    I = -sol["Current [A]"].entries
    np.savetxt(f"{out}/{tag}.csv", np.c_[tt, I, V, phi, xs, xa], delimiter=",",
               header="t,I,V,phi_an_sep,x_surf_avg,x_avg", comments="", fmt="%.6g")
    return tt, V, phi

def pulse_profile():
    """Charge pulses 0.25-2C (10 s on, 40 s rest), one discharge pulse, then a 120 s 1C charge."""
    Q = 5.0; segs = []
    for c in [0.25, 0.5, 1.0, 1.5, 2.0]:
        segs += [(10, c * Q), (40, 0.0)]
    segs += [(10, -1.0 * Q), (30, 0.0), (120, 1.0 * Q), (60, 0.0)]
    return segs

if __name__ == "__main__":
    segs = pulse_profile()
    for T in [0, 10, 25, 40]:
        for soc in [0.3, 0.5, 0.7, 0.85, 0.95]:
            tag = f"fit_T{T}_S{int(soc*100)}"
            run(T, soc, segs, tag); print("done", tag)
