import pybamm, numpy as np, time
pybamm.set_logging_level("ERROR")
p=pybamm.ParameterValues("OKane2022")
# stoichiometry window
esoh = pybamm.lithium_ion.ElectrodeSOHSolver(p, pybamm.LithiumIonParameters())
Vmin,Vmax=p["Lower voltage cut-off [V]"],p["Upper voltage cut-off [V]"]
inp={"V_min":Vmin,"V_max":Vmax,"Q_n":p.evaluate(pybamm.LithiumIonParameters().n.Q_init),"Q_p":p.evaluate(pybamm.LithiumIonParameters().p.Q_init),"Q_Li":p.evaluate(pybamm.LithiumIonParameters().Q_Li_particles_init)}
sol=esoh.solve(inp)
for k in ["x_0","x_100","y_0","y_100","Q"]: print(k, sol[k])
m=pybamm.lithium_ion.DFN()
vars_=[v for v in m.variables.keys() if "potential difference" in v.lower() and "Negative" in v]
print(vars_[:20])
t=time.time()
exp=pybamm.Experiment(["Charge at 10 A for 10 seconds","Rest for 30 seconds"],period="0.5 seconds")
sim=pybamm.Simulation(m,parameter_values=p,experiment=exp)
s=sim.solve(initial_soc=0.9)
print("time",time.time()-t)
V=s["Voltage [V]"].entries; print(V[:3],V.max())
d=s["Negative electrode surface potential difference [V]"].entries; print(d.shape, d[-1,:5], d[0,:5])
