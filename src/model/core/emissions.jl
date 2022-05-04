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
	emissions(EP::Model, inputs::Dict)

This function creates expression to add the CO2 emissions by plants in each zone, which is subsequently added to the total emissions
"""
function emissions!(EP::Model, inputs::Dict)

	println("Emissions Module (for CO2 Policy modularization")

	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	@expression(EP, eEmissionsByPlant[y=1:G,t=1:T],

		if y in inputs["COMMIT"]
			dfGen[y,:CO2_per_MWh]*EP[:vP][y,t]+dfGen[y,:CO2_per_Start]*EP[:vSTART][y,t]
		else
			dfGen[y,:CO2_per_MWh]*EP[:vP][y,t]
		end
	)
	@expression(EP, eEmissionsByZone[z=1:Z, t=1:T], sum(eEmissionsByPlant[y,t] for y in dfGen[(dfGen[!,:Zone].==z),:R_ID]))

end
