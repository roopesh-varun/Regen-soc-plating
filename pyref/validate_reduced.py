"""Validate the reduced model against the DFN on drive-like current profiles it was NOT fitted to."""
import numpy as np, json
from dfn_reference import run
from reduced import simulate
fit = json.load(open("dfn_data/reduced_fit.json"))
S = 86.0 / json.load(open("dfn_data/window.json"))["Q"]
src = "/home/claude/ed5361_regen_soc/results/final/"
cases = [("TS_HARDSTOP_E3.csv", 10, 0.92), ("TS_HARDSTOP_E3.csv", 25, 0.80),
         ("TS_hill95_bias+0.csv", 25, 0.90), ("TS_hill95_bias+0.csv", 10, 0.75)]
out = []
for f, T, soc in cases:
    d = np.genfromtxt(src + f, delimiter=",", names=True)
    t = d["t"][::5]; I = d["I"][::5] / S          # 1 s samples, 5 Ah cell current
    if "hill" in f: t, I = t[t <= 600], I[t <= 600]
    tag = f"val_{f[3:-4]}_T{T}_S{int(soc*100)}"
    run(T, soc, np.c_[t, I], tag)
    r = np.loadtxt(f"dfn_data/{tag}.csv", delimiter=",", skiprows=1)
    th = [fit[str(T)][k] for k in ["Ro", "Re", "tau", "Ra", "gamma"]]
    V, phi, _ = simulate(r[:, 0], r[:, 1], soc, T, th)
    eV = 1e3 * (V - r[:, 2]); eP = 1e3 * (phi - r[:, 3])
    row = dict(case=tag, rmseV_mV=float(np.sqrt(np.mean(eV**2))), rmsePhi_mV=float(np.sqrt(np.mean(eP**2))),
               maxAbsPhi_mV=float(np.max(np.abs(eP))), minPhiDFN_mV=float(1e3*r[:, 3].min()),
               minPhiRed_mV=float(1e3*phi.min()))
    out.append(row); print(row)
    np.savetxt(f"dfn_data/{tag}_reduced.csv", np.c_[r[:, 0], r[:, 1], r[:, 2], V, r[:, 3], phi],
               delimiter=",", header="t,I,V_dfn,V_red,phi_dfn,phi_red", comments="", fmt="%.6g")
json.dump(out, open("dfn_data/validation.json", "w"), indent=1)
