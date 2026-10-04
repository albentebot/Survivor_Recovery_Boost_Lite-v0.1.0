// SPDX-License-Identifier: GPL-3.0-or-later
if (!("RecoveryBoost" in getroottable()))
    IncludeScript("recovery_boost/core_new", getroottable());
::RecoveryBoost.Start();
