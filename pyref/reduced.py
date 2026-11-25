"""Reduced cell model (single-particle + lumped electrolyte/non-uniformity terms).
Identical equations are implemented in MATLAB in core/cell_params.m and core/cell_step.m.
Currents are for ONE 5.11 Ah LG M50 cell, positive = charge."""
import numpy as np, json
Rg, F = 8.314, 96485.0
win = json.load(open("dfn_data/window.json"))
ocp = np.loadtxt("dfn_data/graphite_ocp.csv", delimiter=",", skiprows=1)
A = 0.065 * 1.58
neg = dict(R=5.86e-6, eps=0.75, L=8.52e-5, cmax=33133.0, D=3.3e-14, ED=30300.0, k=6.48e-7, Ek=35000.0)
pos = dict(R=5.22e-6, eps=0.665, L=7.56e-5, cmax=63104.0, D=4e-15, ED=25000.0, k=3.42e-6, Ek=17800.0)
for e in (neg, pos):
    e["a"] = 3 * e["eps"] / e["R"]; e["S"] = e["a"] * e["L"] * A   # total active area [m2]
ce = 1000.0

def Un(x): return np.interp(x, ocp[:, 0], ocp[:, 1])
def Up(y):
    return (-0.8090 * y + 4.4875 - 0.0428 * np.tanh(18.5138 * (y - 0.5542))
            - 17.7326 * np.tanh(15.7890 * (y - 0.3117)) + 17.5842 * np.tanh(15.9308 * (y - 0.3120)))
def arr(E, T): return np.exp(E / Rg * (1 / 298.15 - 1 / T))
def eta(e, I, cs, T):
    j0 = e["k"] * arr(e["Ek"], T) * np.sqrt(ce) * np.sqrt(cs) * np.sqrt(e["cmax"] - cs)
    return 2 * Rg * T / F * np.arcsinh(I / (2 * e["S"] * j0))

def simulate(t, I, soc0, T_C, th):
    """th = (Ro, Re, tau_e, Ra, gamma) at this temperature. Returns V, phi_an_sep, x_surf."""
    Ro, Re, tau, Ra, gam = th
    T = 273.15 + T_C
    st = {}
    for nm, e, th0 in (("n", neg, win["x_0"] + soc0 * (win["x_100"] - win["x_0"])),
                       ("p", pos, win["y_0"] + soc0 * (win["y_100"] - win["y_0"]))):
        st[nm] = [th0 * e["cmax"], 0.0]
    ve = 0.0; n = len(t)
    V = np.zeros(n); phi = np.zeros(n); xs = np.zeros(n)
    for k in range(n):
        dt = t[k] - t[k - 1] if k else 0.0
        Ik = I[k]
        # current applied over (t[k-1], t[k]] is I[k] (sample-and-hold, as in PyBaMM output)
        out = {}
        for nm, e, sgn in (("n", neg, +1.0), ("p", pos, -1.0)):
            Jin = sgn * Ik / (F * e["S"])          # mol/m2/s into the particle
            D = e["D"] * arr(e["ED"], T)
            c, q = st[nm]
            c = c + 3 * Jin / e["R"] * dt
            a = 30 * D / e["R"] ** 2; b = 45 / (2 * e["R"] ** 2) * Jin
            q = q * np.exp(-a * dt) + b / a * (1 - np.exp(-a * dt))
            st[nm] = [c, q]
            cs = c + 8 * e["R"] / 35 * q + e["R"] / (35 * D) * Jin
            cs = np.clip(cs, 1e-3 * e["cmax"], 0.999 * e["cmax"])
            out[nm] = cs
        ve = ve * np.exp(-dt / tau) + Re * Ik * (1 - np.exp(-dt / tau))
        xn = out["n"] / neg["cmax"]; yp = out["p"] / pos["cmax"]
        phin = Un(xn) - eta(neg, Ik, out["n"], T)
        phip = Up(yp) + eta(pos, Ik, out["p"], T)
        V[k] = phip - phin + Ik * Ro + ve
        phi[k] = phin - Ik * Ra - gam * ve
        xs[k] = xn
    return V, phi, xs
