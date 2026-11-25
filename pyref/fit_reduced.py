import numpy as np, json, glob
from scipy.optimize import least_squares
from reduced import simulate
res = {}
for T in [0, 10, 25, 40]:
    data = []
    for soc in [30, 50, 70, 85, 95]:
        d = np.loadtxt(f"dfn_data/fit_T{T}_S{soc}.csv", delimiter=",", skiprows=1)
        data.append((soc / 100, d))
    def resid(p, which):
        Ro, Re, tau, Ra, gam = p
        r = []
        for soc, d in data:
            V, phi, _ = simulate(d[:, 0], d[:, 1], soc, T, (Ro, Re, tau, Ra, gam))
            r.append((V - d[:, 2]) if which == "V" else (phi - d[:, 3]))
        return np.concatenate(r)
    p0 = np.array([0.005, 0.005, 30.0, 0.002, 0.3])
    sv = least_squares(lambda x: resid([x[0], x[1], x[2], 0, 0], "V"), p0[:3],
                       bounds=([0, 0, 1], [0.1, 0.1, 500]))
    Ro, Re, tau = sv.x
    sp = least_squares(lambda x: resid([Ro, Re, tau, x[0], x[1]], "phi"), p0[3:],
                       bounds=([-0.05, -2], [0.1, 3]))
    Ra, gam = sp.x
    rv = resid([Ro, Re, tau, Ra, gam], "V"); rp = resid([Ro, Re, tau, Ra, gam], "phi")
    res[T] = dict(Ro=Ro, Re=Re, tau=tau, Ra=Ra, gamma=gam,
                  rmseV_mV=1e3 * np.sqrt(np.mean(rv ** 2)), rmsePhi_mV=1e3 * np.sqrt(np.mean(rp ** 2)),
                  maxPhi_mV=1e3 * np.max(np.abs(rp)))
    print(T, {k: round(v, 5) for k, v in res[T].items()})
json.dump(res, open("dfn_data/reduced_fit.json", "w"), indent=1)
