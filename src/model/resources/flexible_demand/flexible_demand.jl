"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
    flexible_demand!(EP::Model, inputs::Dict, setup::Dict)
This function defines the operating constraints for flexible demand resources. As implemented, flexible demand resources ($y \in \mathcal{DF}$) are characterized by: a) maximum deferrable demand as a fraction of available capacity in a particular time step $t$, $\rho^{max}_{y,z,t}$, b) the maximum time this demand can be advanced and delayed, defined by parameters, $\tau^{advance}_{y,z}$ and $\tau^{delay}_{y,z}$, respectively and c) the energy losses associated with shifting demand, $\eta_{y,z}^{dflex}$.
**Tracking total deferred demand**
The operational constraints governing flexible demand resources are as follows.
The first two constraints model keep track of inventory of deferred demand in each time step.  Specifically, the amount of deferred demand remaining to be served ($\Gamma_{y,z,t}$) depends on the amount in the previous time step minus the served demand during time step $t$ ($\Theta_{y,z,t}$) while accounting for energy losses associated with demand flexibility, plus the demand that has been deferred during the current time step ($\Pi_{y,z,t}$). Note that variable $\Gamma_{y,z,t} \in \mathbb{R}$, $\forall y \in \mathcal{DF}, t  \in \mathcal{T}$. Similar to hydro inventory or storage state of charge constraints, for the first time step of the year (or each representative period), we define the deferred demand level based on level of deferred demand in the last time step of the year (or each representative period).
```math
\begin{aligned}
\Gamma_{y,z,t} = \Gamma_{y,z,t-1} -\eta_{y,z}^{dflex}\Theta_{y,z,t} +\Pi_{y,z,t} \hspace{4 cm}  \forall y \in \mathcal{DF}, z \in \mathcal{Z}, t \in \mathcal{T}^{interior} \\
\Gamma_{y,z,t} = \Gamma_{y,z,t +\tau^{period}-1} -\eta_{y,z}^{dflex}\Theta_{y,z,t} +\Pi_{y,z,t} \hspace{4 cm}  \forall y \in \mathcal{DF}, z \in \mathcal{Z}, t \in \mathcal{T}^{start}
\end{aligned}
```
**Bounds on available demand flexibility**
At any given time step, the amount of demand that can be shifted or deferred cannot exceed the maximum deferrable demand, defined by product of the availability factor ($\rho^{max}_{y,t}$) times the available capacity($\Delta^{total}_{y,z}$).
```math
\begin{aligned}
\Pi_{y,t} \leq \rho^{max}_{y,z,t}\Delta_{y,z} \hspace{4 cm}  \forall y \in \mathcal{DF}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
**Maximum time delay and advancements**
Delayed demand must then be served within a fixed number of time steps. This is done by enforcing the sum of demand satisfied ($\Theta_{y,z,t}$) in the following $\tau^{delay}_{y,z}$ time steps (e.g., t + 1 to t + $\tau^{delay}_{y,z}$) to be greater than or equal to the level of energy deferred during time step $t$.
```math
\begin{aligned}
\sum_{e=t+1}^{t+\tau^{delay}_{y,z}}{\Theta_{y,z,e}} \geq \Gamma_{y,z,t}
    \hspace{4 cm}  \forall y \in \mathcal{DF},z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
A similar constraints maximum time steps of demand advancement. This is done by enforcing the sum of demand deferred ($\Pi_{y,t}$) in the following $\tau^{advance}_{y}$ time steps (e.g., t + 1 to t + $\tau^{advance}_{y}$) to be greater than or equal to the total level of energy deferred during time $t$ (-$\Gamma_{y,t}$). The negative sign is included to account for the established sign convention that treat demand deferred in advance of the actual demand is defined to be negative.
```math
\begin{aligned}
\sum_{e=t+1}^{t+\tau^{advance}_{y,z}}{\Pi_{y,z,e}} \geq -\Gamma_{y,z,t}
    \hspace{4 cm}  \forall y \in \mathcal{DF}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
If $t$ is first time step of the year (or the first time step of the representative period), then the above two constraints are implemented to look back over the last n time steps, starting with the last time step of the year (or the last time step of the representative period). This time-wrapping implementation is similar to the time-wrapping implementations used for defining the storage balance constraints for hydropower reservoir resources and energy storage resources.
"""
function flexible_demand!(EP::Model, inputs::Dict, setup::Dict)
## Flexible demand resources available during all hours and can be either delayed or advanced (virtual storage-shiftable demand) - DR ==1

println("Flexible Demand Resources Module")

dfGen = inputs["dfGen"]

T = inputs["T"]     # Number of time steps (hours)
Z = inputs["Z"]     # Number of zones
FLEX = inputs["FLEX"] # Set of flexible demand resources

START_SUBPERIODS = inputs["START_SUBPERIODS"]
INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]

hours_per_subperiod = inputs["hours_per_subperiod"] # Total number of hours per subperiod

END_HOURS = START_SUBPERIODS .+ hours_per_subperiod .- 1 # Last subperiod of each representative period

### Variables ###

# Variable tracking total advanced (negative) or deferred (positive) demand for demand flex resource y in period t
@variable(EP, vS_FLEX[y in FLEX, t=1:T]);

# Variable tracking demand deferred by demand flex resource y in period t
@variable(EP, vCHARGE_FLEX[y in FLEX, t=1:T] >= 0);

### Expressions ###

## Power Balance Expressions ##
@expression(EP, ePowerBalanceDemandFlex[t=1:T, z=1:Z],
    sum(-EP[:vP][y,t]+EP[:vCHARGE_FLEX][y,t] for y in intersect(FLEX, dfGen[(dfGen[!,:Zone].==z),:][!,:R_ID])))

EP[:ePowerBalance] += ePowerBalanceDemandFlex

# Capacity Reserves Margin policy
if setup["CapacityReserveMargin"] > 0
    @expression(EP, eCapResMarBalanceFlex[res=1:inputs["NCapacityReserveMargin"], t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * (EP[:vCHARGE_FLEX][y,t] - EP[:vP][y,t]) for y in FLEX))
    EP[:eCapResMarBalance] += eCapResMarBalanceFlex
end

## Objective Function Expressions ##

# Variable costs of "charging" for technologies "y" during hour "t" in zone "z"
@expression(EP, eCVarFlex_in[y in FLEX,t=1:T], inputs["omega"][t]*dfGen[!,:Var_OM_Cost_per_MWh_In][y]*vCHARGE_FLEX[y,t])

# Sum individual resource contributions to variable charging costs to get total variable charging costs
@expression(EP, eTotalCVarFlexInT[t=1:T], sum(eCVarFlex_in[y,t] for y in FLEX))
@expression(EP, eTotalCVarFlexIn, sum(eTotalCVarFlexInT[t] for t in 1:T))
EP[:eObj] += eTotalCVarFlexIn

### Constraints ###

## Flexible demand is available only during specified hours with time delay or time advance (virtual storage-shiftable demand)
for z in 1:Z
    # NOTE: Flexible demand operates by zone since capacity is now related to zone demand
    FLEX_Z = intersect(FLEX, dfGen[dfGen.Zone .== z, :R_ID])

    @constraints(EP, begin
        # State of "charge" constraint (equals previous state + charge - discharge)
        # NOTE: no maximum energy "stored" or deferred for later hours
        # NOTE: Flexible_Demand_Energy_Eff corresponds to energy loss due to time shifting
        [y in FLEX_Z, t in 1:T], EP[:vS_FLEX][y,t] == EP[:vS_FLEX][y, hoursbefore(hours_per_subperiod, t, 1)] - dfGen[y, :Flexible_Demand_Energy_Eff] * EP[:vP][y,t] + EP[:vCHARGE_FLEX][y,t]

        # Maximum charging rate
        # NOTE: the maximum amount that can be shifted is given by hourly availability of the resource times the maximum capacity of the resource
        [y in FLEX_Z, t=1:T], EP[:vCHARGE_FLEX][y,t] <= inputs["pP_Max"][y,t]*EP[:eTotalCap][y]
        # NOTE: no maximum discharge rate unless constrained by other factors like transmission, etc.
    end)


    for y in FLEX_Z

        # Require deferred demands to be satisfied within the specified time delay
        max_flexible_demand_delay = Int(floor(dfGen[y,:Max_Flexible_Demand_Delay]))

        # Require advanced demands to be satisfied within the specified time period
        max_flexible_demand_advance = Int(floor(dfGen[y,:Max_Flexible_Demand_Advance]))

        @constraint(EP, [t in 1:T],
            # cFlexibleDemandDelay: Constraints looks forward over next n hours, where n = max_flexible_demand_delay
            sum(EP[:vP][y,e] for e=hoursafter(hours_per_subperiod, t, 1:max_flexible_demand_delay)) >= EP[:vS_FLEX][y,t])

        @constraint(EP, [t in 1:T],
            # cFlexibleDemandAdvance: Constraint looks forward over next n hours, where n = max_flexible_demand_advance
            sum(EP[:vCHARGE_FLEX][y,e] for e=hoursafter(hours_per_subperiod, t, 1:max_flexible_demand_advance)) >= -EP[:vS_FLEX][y,t])

    end
end

return EP
end

@doc raw"""
    hoursafter(p::Int, t::Int, a::Int)

Determines the time index a hours after index t in
a landscape starting from t=1 which is separated
into distinct periods of length p.

For example, if p = 10,
1 hour after t=9 is t=10,
1 hour after t=10 is t=1,
1 hour after t=11 is t=2
"""
function hoursafter(p::Int, t::Int, a::Int)::Int
    period = div(t - 1, p)
    return period * p + mod1(t + a, p)
end

@doc raw"""
    hoursafter(p::Int, t::Int, b::UnitRange)

This is a generalization of hoursafter(... b::Int)
to allow for example a=1:3 to fetch a Vector{Int} of the three hours after
time index t.
"""
function hoursafter(p::Int, t::Int, a::UnitRange{Int})::Vector{Int}
    period = div(t - 1, p)
    return period * p .+ mod1.(t .+ a, p)

end
