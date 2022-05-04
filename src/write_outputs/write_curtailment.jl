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
	write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the curtailment values of the different variable renewable resources.
"""
function write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    VRE = inputs["VRE"]
    dfCurtailment = DataFrame(Resource=inputs["RESOURCES"], Zone=dfGen[!, :Zone], AnnualSum = zeros(G))
    curtailment = zeros(G, T)
    curtailment[VRE, :] = ((value.(EP[:eTotalCap][VRE]) .* inputs["pP_Max"][VRE, :]) .- value.(EP[:vP][VRE, :]))
    if setup["ParameterScale"] == 1
        curtailment *= ModelScalingFactor
    end
    dfCurtailment.AnnualSum = curtailment * inputs["omega"]
    dfCurtailment = hcat(dfCurtailment, DataFrame(curtailment, :auto))
    auxNew_Names = [Symbol("Resource"); Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
    rename!(dfCurtailment, auxNew_Names)

    total = DataFrame(["Total" 0 sum(dfCurtailment.AnnualSum) fill(0.0, (1, T))], auxNew_Names)
    total[:, 4:T+3] .= sum(curtailment, dims=1)
    dfCurtailment = vcat(dfCurtailment, total)
	
    CSV.write(joinpath(path, "curtail.csv"), dftranspose(dfCurtailment, false), writeheader=false)
    return dfCurtailment
end
