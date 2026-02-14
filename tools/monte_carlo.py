import numpy as np
from scipy.stats import norm

Ns = 32   # signal-present trials
Nn = 58   # signal-absent trials
n_sims = 500_000

rng = np.random.default_rng(1)

H  = rng.binomial(Ns, 0.5, size=n_sims)
FA = rng.binomial(Nn, 0.5, size=n_sims)

HR  = (H  + 0.5) / (Ns + 1)   # loglinear correction
FAR = (FA + 0.5) / (Nn + 1)

dprime = norm.ppf(HR) - norm.ppf(FAR)

dcrit_95  = np.quantile(dprime, 0.95)   # one-sided 95%
dcrit_975 = np.quantile(dprime, 0.975)
dcrit_99  = np.quantile(dprime, 0.99)

print(dcrit_95, dcrit_975, dcrit_99)
