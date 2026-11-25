"""Figures for the v2 report and slides. Run from the v2 folder: python3 scripts/make_figures_v2.py"""
import json, os, numpy as np, pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
R = "results"; FIG = os.path.join(R, "figures"); os.makedirs(FIG, exist_ok=True)
C = {"teal": "#1B83AD", "orange": "#E08A2C", "red": "#C93F57", "purple": "#6C4FB8", "green": "#2AA88F",
     "ink": "#1F2933", "muted": "#61748A", "grid": "#E3E8EE"}
TC = {0: C["purple"], 10: C["teal"], 25: C["orange"], 40: C["red"]}
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9.5, "axes.edgecolor": C["muted"],
    "axes.labelcolor": C["ink"], "xtick.color": C["muted"], "ytick.color": C["muted"], "axes.grid": True,
    "grid.color": C["grid"], "grid.linewidth": 0.8, "axes.spines.top": False, "axes.spines.right": False,
    "legend.frameon": False, "lines.linewidth": 2, "figure.dpi": 160, "savefig.bbox": "tight"})
def save(fig, name): fig.savefig(os.path.join(FIG, name)); plt.close(fig); print("wrote", name)
def have(f): return os.path.exists(os.path.join(R, f))

# ---------------- G1 model validation against the DFN ----------------
def g1():
    base = "pyref/dfn_data/"
    cases = [("val_HARDSTOP_E3_T10_S92_reduced.csv", "Hard stops, 10 °C, start 92 %"),
             ("val_hill95_bias+0_T25_S90_reduced.csv", "Ghat descent, 25 °C, start 90 %")]
    fig, ax = plt.subplots(2, 2, figsize=(9.5, 5.2), sharex="col")
    for j, (f, title) in enumerate(cases):
        d = pd.read_csv(base + f)
        if "hill" in f: d = d[d.t <= 600]
        ax[0, j].plot(d.t, d.V_dfn, color=C["muted"], lw=3, alpha=.55, label="DFN (PyBaMM)")
        ax[0, j].plot(d.t, d.V_red, color=C["teal"], lw=1.4, label="Reduced model")
        ax[1, j].plot(d.t, 1e3 * d.phi_dfn, color=C["muted"], lw=3, alpha=.55)
        ax[1, j].plot(d.t, 1e3 * d.phi_red, color=C["teal"], lw=1.4)
        ax[1, j].axhline(0, color=C["red"], lw=1, ls="--")
        rm = 1e3 * np.sqrt(np.mean((d.phi_red - d.phi_dfn) ** 2))
        ax[0, j].set_title(title, fontsize=10, loc="left")
        ax[1, j].text(0.02, 0.92, f"RMSE {rm:.1f} mV; lowest point: DFN {1e3*d.phi_dfn.min():.1f}, reduced {1e3*d.phi_red.min():.1f} mV",
                      transform=ax[1, j].transAxes, fontsize=8, color=C["ink"])
        ax[1, j].set_xlabel("Time (s)")
    ax[0, 0].set_ylabel("Terminal voltage (V)"); ax[1, 0].set_ylabel("Anode potential at separator (mV)")
    ax[0, 0].legend(loc="lower right")
    save(fig, "G1_model_validation.png")

# ---------------- G2 graphite OCP and plating limit map ----------------
def g2():
    d = pd.read_csv(f"{R}/X0_maps.csv")
    fig, ax = plt.subplots(1, 2, figsize=(9.5, 3.6))
    ax[0].plot(100 * d.soc, 1e3 * d.U_n, color=C["teal"])
    ax[0].axvspan(60, 70, color=C["orange"], alpha=.12)
    ax[0].text(61, 1e3 * d.U_n.max() * 0.93, "graphite stage\ntransition", fontsize=8, color=C["ink"])
    ax[0].set_xlabel("State of charge (%)"); ax[0].set_ylabel("Graphite open-circuit potential (mV)")
    ax[0].set_title("Anode potential at rest", loc="left", fontsize=10)
    for T, c in [(0, "Ipl_0C"), (10, "Ipl_10C"), (25, "Ipl_25C"), (40, "Ipl_40C")]:
        ax[1].plot(100 * d.soc, d[c] / 86, color=TC[T], label=f"{T} °C")
        ax[1].text(100 * d.soc.iloc[-1] + 0.5, d[c].iloc[-1] / 86, f"{T} °C", fontsize=8, va="center", color=C["ink"])
    ax[1].axvspan(60, 70, color=C["orange"], alpha=.12)
    ax[1].set_xlabel("State of charge (%)"); ax[1].set_ylabel("Plating-free charge current (C-rate)")
    ax[1].set_title("10 s plating limit from rest", loc="left", fontsize=10); ax[1].set_xlim(30, 103)
    save(fig, "G2_plating_map.png")

def x1():
    d = pd.read_csv(f"{R}/X1_accuracy.csv"); d["bias"] = d.bias.round(3); d["soc0"] = d.soc0.round(2)
    b = d[d.bias == 0].set_index(["T", "soc0"])
    d = d.join(b[["E_regen"]].rename(columns={"E_regen": "E0"}), on=["T", "soc0"])
    d["loss"] = 100 * (1 - d.E_regen / d.E0)
    return d

# ---------------- G3 asymmetry ----------------
def g3():
    d = x1()
    fig, ax = plt.subplots(1, 2, figsize=(9.5, 3.8))
    for s, c in [(0.70, C["purple"]), (0.90, C["teal"]), (0.95, C["red"])]:
        x = d[(d["T"] == 25) & (d.soc0 == s)].sort_values("bias")
        xp = x[x.bias >= 0]; xn = x[x.bias <= 0]
        ax[0].plot(100 * xp.bias, xp.loss, color=c, marker="o", ms=3, label=f"start {int(100*s)} %")
        ax[1].plot(100 * xn.bias, xn.phimin, color=c, marker="o", ms=3, label=f"start {int(100*s)} %")
    ax[0].set_xlabel("SoC overestimate (percentage points)"); ax[0].set_ylabel("Regen energy lost vs perfect SoC (%)")
    ax[0].set_title("Overestimate: energy is lost", loc="left", fontsize=10)
    ax[1].axhline(0, color=C["red"], lw=1, ls="--"); ax[1].text(-9.8, -1.6, "plating starts below 0 mV", fontsize=8, color=C["red"])
    ax[1].set_xlabel("SoC underestimate (percentage points)"); ax[1].set_ylabel("Lowest anode potential (mV)")
    ax[1].set_title("Underestimate: the plating margin is used up", loc="left", fontsize=10)
    ax[0].legend(loc="upper left"); fig.suptitle("Hard stops at 2 m/s², one cell, 25 °C", x=0.01, ha="left", fontsize=10, color=C["muted"])
    save(fig, "G3_asymmetry.png")

# ---------------- G4 accuracy map ----------------
def accuracy_table():
    d = x1(); rows = []
    for T in sorted(d["T"].unique()):
        for s in sorted(d.soc0.unique()):
            x = d[(d["T"] == T) & (d.soc0 == s)].sort_values("bias")
            over = 0.0
            for bb in x[x.bias > 0].bias:
                if x[x.bias == bb].loss.iloc[0] <= 1.0: over = bb
                else: break
            under = 0.0
            for bb in sorted(x[x.bias < 0].bias, reverse=True):
                if x[x.bias == bb].phimin.iloc[0] >= -0.1 and x[x.bias == bb].t_ceil.iloc[0] == 0: under = bb
                else: break
            ok0 = x[x.bias == 0].phimin.iloc[0] >= -0.1
            rows.append(dict(T=T, soc0=s, max_over=100 * over, max_under=-100 * under, base_safe=ok0))
    t = pd.DataFrame(rows); t.to_csv(f"{R}/accuracy_map_v2.csv", index=False); return t

def g4():
    t = accuracy_table()
    fig, ax = plt.subplots(1, 2, figsize=(9.5, 3.7), sharey=True)
    for T in [0, 10, 25, 40]:
        x = t[t["T"] == T]
        ax[0].plot(100 * x.soc0, x.max_over, color=TC[T], marker="o", ms=3, label=f"{T} °C")
        ax[1].plot(100 * x.soc0, x.max_under, color=TC[T], marker="o", ms=3, label=f"{T} °C")
    ax[0].set_title("Largest overestimate with < 1 % regen loss", loc="left", fontsize=10)
    ax[1].set_title("Largest underestimate with no breach", loc="left", fontsize=10)
    for a in ax: a.set_xlabel("Start SoC (%)"); a.set_ylim(-0.3, 10.5); a.axvspan(62, 72, color=C["orange"], alpha=.1)
    ax[0].set_ylabel("Allowed SoC error (percentage points)"); ax[1].legend(loc="upper left", ncol=2)
    save(fig, "G4_accuracy_map.png")


# ---------------- G5 driving patterns ----------------
def g5():
    d = pd.read_csv(f"{R}/X2_scenarios.csv"); d["bias"] = d.bias.round(3); d["soc0"] = d.soc0.round(2)
    b = d[d.bias == 0].set_index(["cycle", "T", "soc0"])
    d = d.join(b[["E_regen"]].rename(columns={"E_regen": "E0"}), on=["cycle", "T", "soc0"])
    d["loss"] = 100 * (1 - d.E_regen / d.E0)
    names = {1: "Hard stops\n1 m/s²", 2: "Hard stops\n2 m/s²", 3: "Hard stops\n3 m/s²", 4: "MIDC\ncity", 5: "Ghat\ndescent"}
    x = d[(d["T"] == 25)]
    fig, ax = plt.subplots(1, 2, figsize=(9.5, 3.7))
    w = 0.38; xs = np.arange(5)
    for j, (s, c) in enumerate([(0.90, C["teal"]), (0.95, C["red"])]):
        y = [x[(x.cycle == k) & (x.soc0 == s) & (x.bias == 0.02)].loss.iloc[0] for k in range(1, 6)]
        bars = ax[0].bar(xs + (j - .5) * w, y, w * .92, color=c, label=f"start {int(100*s)} %")
        for xi, yi in zip(xs + (j - .5) * w, y): ax[0].text(xi, yi + 1.5, f"{yi:.0f}", ha="center", fontsize=7.5, color=C["ink"])
    ax[0].set_xticks(xs, [names[k] for k in range(1, 6)], fontsize=8); ax[0].set_ylabel("Regen lost with +2 % overestimate (%)")
    ax[0].set_title("Overestimate cost by driving pattern (25 °C)", loc="left", fontsize=10); ax[0].legend(loc="upper left")
    h = d[(d.cycle == 5) & (d.soc0 == 0.95)]
    for T in [10, 25, 40]:
        y = h[h["T"] == T].sort_values("bias")
        ax[1].plot(100 * y.bias, y.t_ceil / 60, color=TC[T], marker="o", ms=4, label=f"{T} °C")
    ax[1].set_xlabel("SoC bias (percentage points)"); ax[1].set_ylabel("Minutes above the 97 % ceiling")
    ax[1].set_title("Ghat descent from 95 %: underestimate overfills", loc="left", fontsize=10); ax[1].legend()
    save(fig, "G5_scenarios.png")

# ---------------- G6 pack spread ----------------
def wilson(k, n, z=1.96):
    if n == 0: return (np.nan, np.nan, np.nan)
    p = k / n; den = 1 + z**2 / n; cen = (p + z**2 / (2 * n)) / den; hw = z * np.sqrt(p * (1 - p) / n + z**2 / (4 * n**2)) / den
    return p, max(cen - hw, 0), min(cen + hw, 1)

def g6():
    d = pd.read_csv(f"{R}/X3_spread.csv"); d["breach_pl"] = (d.phimin < -0.1).astype(int)
    labels = [l.strip() for l in open(f"{R}/X3_labels.txt") if not l.startswith("policies")]
    pol = {1: "SOP", 2: "SOPM", 3: "ROBUST-A", 4: "ORACLE"}; pc = {1: C["red"], 2: C["orange"], 3: C["teal"], 4: C["purple"]}
    fig, ax = plt.subplots(1, 2, figsize=(10.5, 3.9), gridspec_kw={"wspace": 0.45})
    # left: lowest anode potential across packs vs spread multiplier (10 C)
    mult = [0, 0.5, 1, 2]
    for p in [1, 2, 3, 4]:
        med, lo, hi = [], [], []
        for c in range(1, 5):
            x = d[(d["case"] == c) & (d["T"] == 10) & (d.policy == p)].phimin
            med.append(x.median()); lo.append(x.quantile(.05)); hi.append(x.quantile(.95))
        off = (p - 2.5) * 0.04
        ax[0].errorbar(np.array(mult) + off, med, yerr=[np.array(med) - lo, np.array(hi) - med], color=pc[p], marker="o", ms=5, capsize=3, label=pol[p])
    ax[0].axhline(0, color=C["red"], lw=1, ls="--")
    ax[0].set_xlabel("Cell-to-cell spread (× baseline)"); ax[0].set_ylabel("Lowest anode potential in pack (mV)")
    ax[0].set_title("Spread alone pushes the weakest cell to plating", loc="left", fontsize=10)
    ax[0].legend(loc="lower left", fontsize=8); ax[0].text(0.98, 0.97, "10 °C, 60 packs, median and 5-95 %", transform=ax[0].transAxes, ha="right", va="top", fontsize=8, color=C["muted"])
    # right: which spread matters: SOP lowest potential, one spread at a time
    names = ["kinetics", "temperature", "SoC imbalance", "capacity", "resistance"]
    keys = {"capacity": "only cap", "resistance": "only R", "kinetics": "only kin", "SoC imbalance": "only z", "temperature": "only T"}
    vals = []
    for n in names:
        c = labels.index(keys[n]) + 1
        x = d[(d["case"] == c) & (d["T"] == 10) & (d.policy == 1)].phimin
        o = d[(d["case"] == 1) & (d["T"] == 10) & (d.policy == 1)].phimin
        vals.append(o.median() - x.median())
    ax[1].barh(names, vals, color=C["teal"], height=.55)
    for i, v in enumerate(vals): ax[1].text(v + 0.1, i, f"{v:.1f} mV", va="center", fontsize=8, color=C["ink"])
    ax[1].set_xlabel("Drop in lowest anode potential vs identical cells (mV)"); ax[1].invert_yaxis()
    ax[1].set_title("Which spread matters (SOP, 10 °C, 1× each)", loc="left", fontsize=10)
    save(fig, "G6_pack_spread.png")

# ---------------- G7 case study ----------------
def g7():
    pols = [("SOP", C["red"]), ("ROBUST", C["orange"]), ("ROBUSTA", C["teal"]), ("ORACLE", C["purple"])]
    fig, ax = plt.subplots(3, 1, figsize=(9.5, 7.2), sharex=True)
    for p, c in pols:
        f = f"{R}/X4_{p}.csv"
        if not os.path.exists(f): continue
        d = pd.read_csv(f); t = d.t / 60
        lab = "ROBUST-A" if p == "ROBUSTA" else p
        ax[0].plot(t, d.I / 86, color=c, lw=1.4, label=lab)
        ax[1].plot(t, 1e3 * d.phimin, color=c, lw=1.4, label=lab)
        if p == "SOP":
            ax[2].plot(t, 100 * d.zbar, color=C["ink"], lw=2, label="true pack-mean SoC")
            ax[2].plot(t, 100 * d.zest, color=C["red"], lw=1.4, ls="--", label="EKF estimate")
        if p == "ROBUSTA":
            ax[2].plot(t, 100 * d.zp, color=C["teal"], lw=1.2, label="ROBUST-A pessimistic SoC")
    ax[0].set_ylabel("Regen charge\ncurrent (C-rate)"); ax[0].set_ylim(0, 0.42); ax[0].legend(ncol=4, loc="upper center", bbox_to_anchor=(0.5, 1.32), fontsize=8.5)
    ax[1].axhline(0, color=C["red"], lw=1, ls="--"); ax[1].set_ylabel("Weakest cell anode\npotential (mV)")
    ax[1].set_ylim(-8, 30)
    ax[2].set_ylabel("SoC (%)"); ax[2].set_xlabel("Time (min)"); ax[2].legend(fontsize=8, loc="upper right")
    fig.suptitle("Aged pack (SoH 85 %), five hard stops at 5 °C, EKF starts 3 % low", x=0.01, ha="left", fontsize=10.5, y=1.02)
    save(fig, "G7_case_study.png")

# ---------------- Monte Carlo ----------------
PN_TEST = {1: "ORACLE", 2: "SOP", 3: "SOPM", 4: "ROBUST", 5: "LEANHIGH", 6: "ROBUST-A"}
CYC = {1: "Hard stops", 2: "MIDC city", 3: "Ghat descent"}
def mc_summary():
    d = pd.read_csv(f"{R}/X5_test.csv"); d["breach_pl"] = (d.phimin < -0.1).astype(int)
    o = d[d.run == 1].set_index(["cycle", "trip"]).E_regen
    d = d.join(o.rename("E_or"), on=["cycle", "trip"])
    rows = []
    for r in range(1, 7):
        x = d[d.run == r]; n = len(x); k = int(x.breach_pl.sum()); kc = int(x.breach_ceil.sum()); ka = int((x.breach_pl | x.breach_ceil).sum())
        p, lo, hi = wilson(ka, n)
        rows.append(dict(policy=PN_TEST[r], n=n, plating=k, ceiling=kc, any=ka, p_any=100 * p, lo=100 * lo, hi=100 * hi,
                         retained=100 * x.E_regen.sum() / x.E_or.sum(), Qpl_mean=x.Qpl.mean(), Qpl_p99=x.Qpl.quantile(.99),
                         phimin_p1=x.phimin.quantile(.01)))
        for c in [1, 2, 3]:
            y = x[x.cycle == c]
            rows[-1][f"ret_{c}"] = 100 * y.E_regen.sum() / y.E_or.sum()
            rows[-1][f"br_{c}"] = int((y.breach_pl | y.breach_ceil).sum())
    t = pd.DataFrame(rows); t.to_csv(f"{R}/X5_summary.csv", index=False); return t, d

def g8():
    t, d = mc_summary()
    fig, ax = plt.subplots(figsize=(8.6, 4.2))
    col = {"ORACLE": C["purple"], "SOP": C["red"], "SOPM": C["orange"], "ROBUST": C["muted"], "LEANHIGH": C["green"], "ROBUST-A": C["teal"]}
    for _, r in t.iterrows():
        ax.errorbar(r.retained, r.p_any, yerr=[[r.p_any - r.lo], [r.hi - r.p_any]], fmt="o", ms=8, color=col[r.policy], capsize=4)
        off = {"ROBUST": (8, 4), "LEANHIGH": (-62, 4)}.get(r.policy, (7, 6))
        ax.annotate(r.policy, (r.retained, r.p_any), xytext=off, textcoords="offset points", fontsize=9, color=C["ink"])
    ax.set_xlabel("Regen energy kept vs ORACLE (%)"); ax.set_ylabel("Trips with a plating or ceiling breach (%)")
    ax.set_title(f"Monte Carlo test set: {int(t.n.iloc[0])} random trips per policy, 96-cell packs (95 % Wilson intervals)", loc="left", fontsize=10)
    ax.set_ylim(-3, max(t.hi) * 1.12 + 2)
    save(fig, "G8_mc_tradeoff.png")

def g9():
    d = pd.read_csv(f"{R}/X5_train.csv"); d["breach_pl"] = (d.phimin < -0.1).astype(int)
    o = d[d.run == 1].set_index(["cycle", "trip"]).E_regen
    d = d.join(o.rename("E_or"), on=["cycle", "trip"]); x = d[d.run > 1]
    rows = []
    for kA, g in x.groupby("kA"):
        k = int((g.breach_pl | g.breach_ceil).sum()); p, lo, hi = wilson(k, len(g))
        rows.append((kA, 100 * p, 100 * lo, 100 * hi, 100 * g.E_regen.sum() / g.E_or.sum()))
    r = np.array(rows)
    fig, ax = plt.subplots(1, 2, figsize=(9.5, 3.4))
    ax[0].errorbar(r[:, 0], r[:, 1], yerr=[r[:, 1] - r[:, 2], r[:, 3] - r[:, 1]], color=C["teal"], marker="o", capsize=3)
    ax[0].axhline(1, color=C["red"], ls="--", lw=1); ax[0].text(r[0, 0], 1.15, "1 % target", color=C["red"], fontsize=8)
    ax[0].set_xlabel("SoC margin kₐ (adaptive sigmas)"); ax[0].set_ylabel("Training trips with a breach (%)")
    ax[1].plot(r[:, 0], r[:, 4], color=C["teal"], marker="o")
    ax[1].set_xlabel("SoC margin kₐ (adaptive sigmas)"); ax[1].set_ylabel("Regen kept vs ORACLE (%)")
    ax[0].set_title("Tuning ROBUST-A on 600 training trips", loc="left", fontsize=10)
    save(fig, "G9_mc_tuning.png")

# ---------------- G10 real-world translation ----------------
TARIFF = 8.0; GRID = 0.727; CONS = 13.0     # Rs/kWh (assumed), kg CO2/kWh (CEA v20, FY2023-24), kWh/100 km
PATTERNS = {  # trips per year of each test pattern (cycle id -> trips)
    "City commuter\n(12,000 km/yr, MIDC)": {2: 12000 / 10.52},
    "Hill-route driver\n(8,000 km city + 2 ghat descents/week)": {2: 8000 / 10.52, 3: 104},
    "Ride-hailing car\n(45,000 km/yr, stop-go)": {1: 0.5 * 45000 / 3.46, 2: 0.5 * 45000 / 10.52},
}
def realworld():
    t, d = mc_summary()
    per = d.groupby(["run", "cycle"]).agg(E=("E_regen", "mean"), Eo=("E_or", "mean"), br=("breach_pl", "mean"), Q=("Qpl", "mean")).reset_index()
    rows = []
    for name, trips in PATTERNS.items():
        for r in [2, 3, 4, 6]:
            lost = sum(n * (per[(per.run == r) & (per.cycle == c)].Eo.iloc[0] - per[(per.run == r) & (per.cycle == c)].E.iloc[0]) for c, n in trips.items())
            ev = sum(n * per[(per.run == r) & (per.cycle == c)].br.iloc[0] for c, n in trips.items())
            q = sum(n * per[(per.run == r) & (per.cycle == c)].Q.iloc[0] for c, n in trips.items())
            rows.append(dict(pattern=name.replace("\n", " "), policy=PN_TEST[r], kWh_lost=lost, rupees=lost * TARIFF / 0.9,
                             km_range=lost / CONS * 100, kgCO2=lost * GRID / 0.9, plating_trips=ev, plated_mAh=q))
    w = pd.DataFrame(rows); w.to_csv(f"{R}/X6_realworld.csv", index=False); return w

def g10():
    w = realworld()
    fig, ax = plt.subplots(1, 2, figsize=(10, 3.9))
    pats = list(dict.fromkeys(w.pattern)); xs = np.arange(len(pats)); bw = 0.2
    col = {"SOP": C["red"], "SOPM": C["orange"], "ROBUST": C["muted"], "ROBUST-A": C["teal"]}
    for j, p in enumerate(["SOP", "SOPM", "ROBUST", "ROBUST-A"]):
        y = [w[(w.pattern == q) & (w.policy == p)].kWh_lost.iloc[0] for q in pats]
        z = [w[(w.pattern == q) & (w.policy == p)].plating_trips.iloc[0] for q in pats]
        ax[0].bar(xs + (j - 1.5) * bw, y, bw * .9, color=col[p], label=p)
        ax[1].bar(xs + (j - 1.5) * bw, z, bw * .9, color=col[p], label=p)
    short = [p.split(" (")[0] for p in pats]
    for a in ax: a.set_xticks(xs, short, fontsize=8.5)
    ax[0].set_ylabel("Regen given up vs ORACLE (kWh / year)"); ax[1].set_ylabel("Trips with plating (per year)")
    ax[0].set_title("Energy cost of each policy", loc="left", fontsize=10); ax[1].set_title("Plating exposure of each policy", loc="left", fontsize=10)
    ax[1].legend(fontsize=8)
    ax[0].axhline(0, color=C["ink"], lw=0.8)
    ax[0].text(0.01, 0.03, "below zero = took more than ORACLE, by plating", transform=ax[0].transAxes, fontsize=7.5, color=C["muted"])
    for i, q in enumerate(pats):
        ax[1].text(i + 1.5 * bw, 40, "0", ha="center", fontsize=8, color=C["teal"]) if w[(w.pattern == q) & (w.policy == "ROBUST-A")].plating_trips.iloc[0] < 0.5 else None
    save(fig, "G10_realworld.png")

if __name__ == "__main__":
    import sys
    which = sys.argv[1:] or ["g1", "g2", "g3", "g4", "g5", "g6", "g7", "g8", "g9", "g10"]
    for w in which:
        f = globals().get(w)
        if f is None: continue
        try: f()
        except FileNotFoundError as e: print("skip", w, e)
