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
	piecewiseheatrate(EP::Model, inputs::Dict, UCommit::Int, Reserves::Int)
piecewiseheatrate module allows piecewise-linear fitting of input thermal energy at part load. When setup["PieceWiseHeatRate"] == 1 and setup["UCommit"] >= 1, this module is on.
"""

function piecewiseheatrate(EP::Model, inputs::Dict)
    println("Thermal (Piecewise heat rate) Resources Module")
    dfGen = inputs["dfGen"]
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"]
    THERM_COMMIT = inputs["THERM_COMMIT"]
    # create variable for fuel consumption
    @variable(EP, vFuel[y in THERM_COMMIT, t = 1:T])

    # Piecewise heat rate UC
    @constraint(EP, First_segement[y in THERM_COMMIT, t = 1:T],
        vFuel[y, t] >= EP[:vP][y, t] * dfGen[!, :Slope1][y] + EP[:vCOMMIT][y, t] * dfGen[!, :Intercept1][y])
    @constraint(EP, Second_segement[y in THERM_COMMIT, t = 1:T],
        vFuel[y, t] >= EP[:vP][y, t] * dfGen[!, :Slope2][y] + EP[:vCOMMIT][y, t] * dfGen[!, :Intercept2][y])
    @constraint(EP, Third_segement[y in THERM_COMMIT, t = 1:T],
        vFuel[y, t] >= EP[:vP][y, t] * dfGen[!, :Slope3][y] + EP[:vCOMMIT][y, t] * dfGen[!, :Intercept3][y])


    # mutiplying eFuel and the fuel cost
    @expression(EP, eCFuel_piecewise[y in THERM_COMMIT, t = 1:T], inputs["omega"][t] * vFuel[y, t] * (inputs["fuel_costs"][dfGen[!, :Fuel][y], t]))
    # sum up the fuel cost from each period to the plant level
    @expression(EP, ePlantCFuel_piecewise[y in THERM_COMMIT], sum(eCFuel_piecewise[y, t] for t in 1:T))
    # sum up the fuel cost to the zonal level
    @expression(EP, eZonalCFuel_piecewise[z in 1:Z], EP[:vZERO] + sum(ePlantCFuel_piecewise[y] for y in intersect(THERM_COMMIT, dfGen[dfGen[!, :Zone].==z, :R_ID])))
    # sum up the fuel cost to the system level
    @expression(EP, eCVar_fuel_piecewise, sum(eZonalCFuel_piecewise[z] for z in 1:Z))
    # add to objective function
    EP[:eObj] += eCVar_fuel_piecewise
    return EP
end
