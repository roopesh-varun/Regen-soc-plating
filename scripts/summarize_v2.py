"""Collect the key numbers quoted in the report and slides into results/key_numbers.json."""
import json, numpy as np, pandas as pd, sys
sys.path.insert(0, "scripts")
import make_figures_v2 as F
R = "results"; K = {}
import os
# merge the split Monte Carlo files (baseline policies and ROBUST-A were run in separate processes)
if os.path.exists(f"{R}/X5_test_base.csv") and os.path.exists(f"{R}/X5_test_robusta.csv"):
    pd.concat([pd.read_csv(f"{R}/X5_test_base.csv"), pd.read_csv(f"{R}/X5_test_robusta.csv")]).to_csv(f"{R}/X5_test.csv", index=False)
if False and os.path.exists(f"{R}/X5_train_old.csv") and os.path.exists(f"{R}/X5_train_robusta.csv"):
    o = pd.read_csv(f"{R}/X5_train_old.csv"); pd.concat([o[o.run == 1], pd.read_csv(f"{R}/X5_train_robusta.csv")]).to_csv(f"{R}/X5_train.csv", index=False)
# verification lines
K["verify"] = []
what = {"V1": "True-cell charge balance (SoC = Coulomb count)", "V2": "MATLAB reduced model = Python reduced model", "V3": "Reduced model vs PyBaMM DFN, lowest anode potential",
        "V4": "Time-step convergence (0.2 s vs 0.05 s)", "V5": "ORACLE never breaches (96-cell packs)", "V6": "Perfect-SoC single cell never plates under SOP",
        "V7": "Monotone response to SoC bias", "V8": "EKF converges from +3 % initial error", "V9": "Energy bookkeeping closes"}
for line in open(f"{R}/verify_v2.txt"):
    p = line.split("  ", 2)
    K["verify"].append(dict(id=p[0], what=what[p[0]], ok=p[1], result=p[1] + ": " + p[2].strip().split(": ", 1)[-1][:70]))
# X1 asymmetry / accuracy
d = F.x1()
def loss(T, s, b): return float(d[(d["T"] == T) & (d.soc0 == s) & (d.bias == b)].loss.iloc[0])
def phi(T, s, b): return float(d[(d["T"] == T) & (d.soc0 == s) & (d.bias == b)].phimin.iloc[0])
K["x1"] = {f"loss_T{T}_S{int(100*s)}_b{int(round(1000*b))}": round(loss(T, s, b), 1)
           for T in [0, 10, 25, 40] for s in [0.65, 0.7, 0.9, 0.95] for b in [0.01, 0.02, 0.03, 0.05, 0.1]}
K["x1_phi"] = {f"phi_T{T}_S{int(100*s)}_b{int(round(1000*b))}": round(phi(T, s, b), 1)
               for T in [0, 10, 25, 40] for s in [0.65, 0.7, 0.75, 0.9, 0.95] for b in [-0.1, -0.05, -0.03, -0.02, 0.0]}
t = F.accuracy_table(); K["accuracy"] = t.round(2).to_dict(orient="records")
# X0 map
m = pd.read_csv(f"{R}/X0_maps.csv")
K["map"] = {f"Ipl_{T}C_S{s}": round(float(m[np.isclose(m.soc, s / 100)][f"Ipl_{T}C"].iloc[0]) / 86, 2) for T in [0, 10, 25, 40] for s in [50, 60, 70, 90, 95]}
# X2
x = pd.read_csv(f"{R}/X2_scenarios.csv"); x["bias"] = x.bias.round(3); x["soc0"] = x.soc0.round(2)
b0 = x[x.bias == 0].set_index(["cycle", "T", "soc0"])
x = x.join(b0[["E_regen"]].rename(columns={"E_regen": "E0"}), on=["cycle", "T", "soc0"]); x["loss"] = 100 * (1 - x.E_regen / x.E0)
K["x2"] = {f"c{c}_T{T}_S{int(100*s)}_b{int(round(1000*b))}": dict(loss=round(float(r.loss), 1), tceil_min=round(float(r.t_ceil) / 60, 1), phimin=round(float(r.phimin), 1))
           for (c, T, s, b), r in x.set_index(["cycle", "T", "soc0", "bias"]).iterrows() if b in (-0.05, -0.02, -0.01, 0.02, 0.05)}
# X3
s3 = pd.read_csv(f"{R}/X3_spread.csv"); s3["breach_pl"] = (s3.phimin < -0.1).astype(int); lab = [l.strip() for l in open(f"{R}/X3_labels.txt") if not l.startswith("policies")]
pol = {1: "SOP", 2: "SOPM", 3: "ROBUSTA", 4: "ORACLE"}; K["x3"] = {}
for (c, T, p), g in s3.groupby(["case", "T", "policy"]):
    o = s3[(s3["case"] == c) & (s3["T"] == T) & (s3.policy == 4)].E_regen.mean()
    K["x3"][f"{lab[c-1]}|T{T}|{pol[p]}"] = dict(breach=int(g.breach_pl.sum()), n=len(g), phimin_med=round(g.phimin.median(), 1),
        phimin_min=round(g.phimin.min(), 1), Qpl_mean=round(g.Qpl.mean(), 2), regen=round(g.E_regen.mean(), 3), ret=round(100 * g.E_regen.mean() / o, 1))
h = pd.read_csv(f"{R}/X3_spread_hill.csv"); h["breach_pl"] = (h.phimin < -0.1).astype(int)
for (T, p), g in h.groupby(["T", "policy"]):
    o = h[(h["T"] == T) & (h.policy == 4)].E_regen.mean()
    K["x3"][f"HILL|T{T}|{pol[p]}"] = dict(breach=int(g.breach_pl.sum()), n=len(g), phimin_med=round(g.phimin.median(), 1), regen=round(g.E_regen.mean(), 3), ret=round(100 * g.E_regen.mean() / o, 1))
# X4
K["x4"] = {}
for p in ["SOP", "ROBUST", "ROBUSTA", "ORACLE"]:
    z = pd.read_csv(f"{R}/X4_{p}.csv")
    K["x4"][p] = dict(phimin=round(1e3 * z.phimin.min(), 1), t_plate=round(float((z.phimin < 0).sum() * 0.2), 1), err_start=round(100 * (z.zest.iloc[0] - z.zbar.iloc[0]), 1))
# X5
try:
    tt, dd = F.mc_summary(); K["mc"] = tt.round(2).to_dict(orient="records")
    K["kA"] = float(open(f"{R}/X5_kA.txt").read())
    tr = pd.read_csv(f"{R}/X5_train.csv"); tr["breach_pl"] = (tr.phimin < -0.1).astype(int); o = tr[tr.run == 1].set_index(["cycle", "trip"]).E_regen
    tr = tr.join(o.rename("E_or"), on=["cycle", "trip"])
    K["mc_train"] = [dict(kA=float(kA), breach=int((g.breach_pl | g.breach_ceil).sum()), n=len(g), ret=round(100 * g.E_regen.sum() / g.E_or.sum(), 1)) for kA, g in tr[tr.run > 1].groupby("kA")]
    K["ekf_err"] = dict(p5=round(100 * dd[dd.run == 2].err_mean.quantile(.05), 1), p95=round(100 * dd[dd.run == 2].err_mean.quantile(.95), 1),
                        min_p5=round(100 * dd[dd.run == 2].err_min.quantile(.05), 1), max_p95=round(100 * dd[dd.run == 2].err_max.quantile(.95), 1))
    w = F.realworld(); K["realworld"] = w.round(2).to_dict(orient="records")
except FileNotFoundError as e:
    print("MC not ready:", e)
json.dump(K, open(f"{R}/key_numbers.json", "w"), indent=1)
print("ok")
# short texts used on slides
K["mc_note"] = ("ROBUST-A: 3 breaches in 600 unseen trips (all shallow, cold aged packs on the descent) and 87 % of ORACLE's regen. "
                "The industry-style fixed 10 mV margin keeps all the energy but breaches on 14 % of trips; SoC-only margins (ROBUST, LEANHIGH) breach on a third, "
                f"because on the graphite plateau a SoC shift barely moves the plating limit. kA = {K.get('kA', '?'):g} chosen on 600 separate training trips.")
K["rw_note"] = ("ROBUST-A's price: about Rs 300-430 a year for a private car and Rs 3,400 for a ride-hailing car. "
                "In return it removes almost every plating trip, of which SOP has 150-180 a year for a private car and about 4,500 for a ride-hailing car.").replace("Rs ", "₹")
K["conclusions"] = [
    ["Asymmetry", "Overestimate loses regen (+2 % → 10 %, +5 % → 87 % from 95 % SoC); underestimate eats a 4-9 mV plating margin."],
    ["Two bands", "Accuracy matters near full and at the graphite step (65-75 % SoC); below 60 %, ±10 % is harmless."],
    ["The pack", "With a perfect SoC, cell spread alone plates the weakest cell in nearly every pack; kinetics and temperature spread dominate."],
    ["ROBUST-A", "0.5 % of unseen trips breached (95 % CI 0.2-1.5 %) vs 14-45 % for the alternatives; keeps 87 % of the oracle's regen."],
    ["In India", "About ₹300-430 a year for a private car, ₹3,400 for a ride-hailing car, to avoid hundreds to thousands of plating trips."]]
json.dump(K, open(f"{R}/key_numbers.json", "w"), indent=1, ensure_ascii=False)
print("notes added")
