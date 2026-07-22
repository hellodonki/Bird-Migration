import threading

import numpy as np

# skmisc.loess wraps Cleveland's original Fortran `loess` library, which relies on
# static/shared work arrays and isn't reentrant. Streamlit runs each script rerun in its
# own thread and can start a new rerun before a prior one's native call has fully unwound
# (rerun "interruption" only takes effect at the next Python bytecode, not mid-C-call), so
# two overlapping loess calls can race on that shared state and segfault the process. A
# process-wide lock serializes all native calls and avoids that race.
_LOESS_LOCK = threading.Lock()


def loess_predict(x, y, newx, span=0.75):
    """Faithful port of R's loess() via the same underlying C code (skmisc)."""
    from skmisc.loess import loess

    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    mask = ~(np.isnan(x) | np.isnan(y))
    x, y = x[mask], y[mask]
    if len(x) < 5:
        return np.full(len(newx), np.nan)
    try:
        with _LOESS_LOCK:
            model = loess(x, y, span=span)
            model.control.surface = "direct"  # R's loess tolerates extrapolation; skmisc's default "interpolate" blending doesn't
            model.fit()
            pred = model.predict(np.asarray(newx, dtype=float), stderror=False)
        return np.maximum(pred.values, 0)
    except Exception:
        return np.full(len(newx), np.nan)


def gam_predict(x, y, newx, n_splines=10):
    """Smooths x/y with LOESS as a stand-in for R's mgcv gam(y ~ s(x, bs='cs', k=10))."""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    if len(np.unique(x[~np.isnan(x)])) < 5 or len(x) < 10:
        return np.full(len(newx), np.nan)
    return loess_predict(x, y, newx, span=0.5)


def find_50pct_descent(x, y, peak_x):
    """First x past the peak where y descends to <=50% of peak value."""
    peak_val = np.nanmax(y)
    if not np.isfinite(peak_val) or peak_val <= 0:
        return None
    threshold = peak_val * 0.5
    for xi, yi in zip(x, y):
        if xi > peak_x and np.isfinite(yi) and yi <= threshold:
            return xi
    return None
