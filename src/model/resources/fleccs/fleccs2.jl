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
	FLECCS2(EP::Model, inputs::Dict, UCommit::Int, Reserves::Int)

The FLECCS2 module creates decision variables, expressions, and constraints related to NGCC-CCS coupled with solvent storage systems. In this module, we will write up all the constraints formulations associated with the power plant.

This module uses the following 'helper' functions in separate files: FLECCS2_commit() for FLECCS subcompoents subject to unit commitment decisions and constraints (if any) and FLECCS2_no_commit() for FLECCS subcompoents not subject to unit commitment (if any).
"""

function fleccs2(EP::Model, inputs::Dict, FLECCS::Int, UCommit::Int, Reserves::Int)

	println("FLECCS2, NGCC coupled with solvent storage Resources Module - with Aux boiler")

	T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G_F = inputs["G_F"] # Number of FLECCS generator
	FLECCS_ALL = inputs["FLECCS_ALL"] # set of FLECCS generator
	dfGen_ccs = inputs["dfGen_ccs"] # FLECCS general data
	#dfGen_ccs = inputs["dfGen_ccs"] # FLECCS specific parameters
	# get number of flexible subcompoents
	N_F = inputs["N_F"]
	n = length(N_F)
 


	NEW_CAP_ccs = inputs["NEW_CAP_FLECCS"] #allow for new capcity build
	RET_CAP_ccs = inputs["RET_CAP_FLECCS"] #allow for retirement

	START_SUBPERIODS = inputs["START_SUBPERIODS"] #start
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"] #interiors

    hours_per_subperiod = inputs["hours_per_subperiod"]

	fuel_type = collect(skipmissing(dfGen_ccs[!,:Fuel]))

	fuel_CO2 = inputs["fuel_CO2"]
	fuel_costs = inputs["fuel_costs"]



	STARTS = 1:inputs["H"]:T
    # Then we record all time periods that do not begin a sub period
    # (these will be subject to normal time couping constraints, looking back one period)
    INTERIORS = setdiff(1:T,STARTS)

	# capacity decision variables


	# variales related to power generation/consumption
    @variables(EP, begin
        # Continuous decision variables
        vP_gt[y in FLECCS_ALL, 1:T]  >= 0 # generation from combustion TURBINE (gas TURBINE)
        vP_ccs_net[y in FLECCS_ALL, 1:T]  >= 0 # net generation from NGCC-CCS coupled with solvent storage
    end)

	# variales related to CO2 and solvent
	@variables(EP, begin
        vCAPTURE[y in FLECCS_ALL,1:T] >= 0 # captured CO2
        vREGEN[y in FLECCS_ALL,1:T] >= 0 # regenerated CO2
        vSTORE_rich[y in FLECCS_ALL,1:T] >= 0 # rich solvent
        vSTORE_lean[y in FLECCS_ALL,1:T] >= 0 # lean solvent
		vSTEAM_in[y in FLECCS_ALL,1:T] >= 0 #MMBTU of steam generated by auxiliary	boiler
	end)

	# the order of those variables must follow the order of subcomponents in the "FLECCS_data.csv"
	# 1. gas turbine
	# 2. steam turbine 
	# 3. ABSORBER
	# 4. compressor
	# 5. regenerator
	# 6. Rich tank
	# 7. lean tank
	# 8. BOP

	# get the ID of each subcompoents 
	# gas turbine 
	NGCT_id = inputs["NGCT_id"]
	# steam turbine
	NGST_id = inputs["NGST_id"]
	# absorber 
	Absorber_id = inputs["Absorber_id"]
	# regenerator 
	Regen_id = inputs["Regen_id"]
	# compressor
	Comp_id = inputs["Comp_id"]
	#Rich tank
	Rich_id = inputs["Rich_id"]
	#lean tank
	Lean_id = inputs["Lean_id"]
	# AUX ID 
	AUX_id = inputs["AUX_id"]
	#BOP 
	BOP_id = inputs["BOP_id"]

	# Specific constraints for FLECCS system
    # Thermal Energy input of combustion TURBINE (or oxyfuel power cycle) at hour "t" [MMBTU]
    @expression(EP, eFuel[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pHeatRate_gt][1+n*(y-1)] * vP_gt[y,t])
    # CO2 generated by combustion TURBINE (or oxyfuel power cycle) at hour "t" [tonne]
    @expression(EP, eCO2_flue[y in FLECCS_ALL,t=1:T], inputs["CO2_per_MMBTU_FLECCS"][y,NGCT_id] * eFuel[y,t])
	# Thermal Energy output of steam generated by HRSG at hour "t" [MWh], high pressure steam

    ### Fangwei 1/22/2022
	# Power consumbed by axu boiler is proportional to vSTEAM_in  
	@expression(EP, ePower_use_boiler[y in FLECCS_ALL,t=1:T], vSTEAM_in[y,t]/3.412)


	### flexible solvent storage
	# vCAPTURE must less than eCO2_flue
	@constraint(EP, cMaxCapture_2[y in FLECCS_ALL,t=1:T], vCAPTURE[y,t] <= dfGen_ccs[!,:pCO2CapRate][1+n*(y-1)]*eCO2_flue[y,t] )
	#CO2 vented at time "t" [tonne]
    @expression(EP, eCO2_vent[y in FLECCS_ALL,t=1:T], eCO2_flue[y,t] - vCAPTURE[y,t])
    #steam used by post-combustion carbon capture (PCC) unit [MMBTU], since steam generated by auxiliary boiler could be used to regenerate solvent, vSTEAM_in is incorporated into this equation.
    @expression(EP, eSteam_use_pcc[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamUseRate][1+n*(y-1)] * vREGEN[y,t] - vSTEAM_in[y,t])
    #power used by post-combustion carbon capture (PCC) unit [MWh]
    @expression(EP, ePower_use_pcc[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pPowerUseRate][1+n*(y-1)]  * vCAPTURE[y,t])
    #mass of compressed CO2 [tonne CO2]
    @expression(EP, eCO2_compressed[y in FLECCS_ALL,t=1:T], vREGEN[y,t])
    #power used by compressor unit [MWh]
    @expression(EP, ePower_use_comp[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pCO2CompressRate][1+n*(y-1)] * eCO2_compressed[y,t])
	#power used by auxiliary [MWh]
	@expression(EP, ePower_use_other[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pPowerUseRate_Other][1+n*(y-1)] * vP_gt[y,t])


	# stema generated by high, mid, low, pressure turbine
	@expression(EP, eSteam_high[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamRate_high][1+n*(y-1)] * eFuel[y,t])
	# mid pressure steam
	@expression(EP, eSteam_mid[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamRate_mid][1+n*(y-1)] * eSteam_high[y,t] - eSteam_use_pcc[y,t])
	# low pressure steam
	@expression(EP, eSteam_low[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamRate_low][1+n*(y-1)] * eSteam_mid[y,t])
	



	#Power generated by steam turbine [MWh]
	@expression(EP, ePower_st[y in FLECCS_ALL,t=1:T], eSteam_high[y,t]/dfGen_ccs[!,:pHeatRate_st_high][1+n*(y-1)] +
	eSteam_mid[y,t]/dfGen_ccs[!,:pHeatRate_st_mid][1+n*(y-1)]+ (eSteam_low[y,t]- eSteam_use_pcc[y,t])/dfGen_ccs[!,:pHeatRate_st_low][1+n*(y-1)])


	# NGCC-CCS net power output = vP_gt + ePower_st - ePower_use_comp - ePower_use_pcc
	@expression(EP, eCCS_net[y in FLECCS_ALL,t=1:T], vP_gt[y,t] + ePower_st[y,t] - ePower_use_comp[y,t]- ePower_use_pcc[y,t] - ePower_use_other[y,t] - ePower_use_boiler[y,t])

	@expression(EP, ePowerBalanceFLECCS[t=1:T, z=1:Z], sum(eCCS_net[y,t] for y in unique(dfGen_ccs[(dfGen_ccs[!,:Zone].==z),:R_ID])))

	#solvent storage mass balance
	# dynamic of rich solvent storage system, normal [tonne solvent/sorbent]
	@constraint(EP, cStore_rich[y in FLECCS_ALL, t in INTERIOR_SUBPERIODS],vSTORE_rich[y, t] == vSTORE_rich[y, t-1] + vCAPTURE[y,t]/dfGen_ccs[!,:pCO2Loading][1+n*(y-1)] - vREGEN[y,t]/dfGen_ccs[!,:pCO2Loading][1+n*(y-1)])
	# dynamic of rich solvent system, wrapping [tonne solvent/sorbent]
	@constraint(EP, cStore_richwrap[y in FLECCS_ALL, t in START_SUBPERIODS],vSTORE_rich[y, t] == vSTORE_rich[y,t+hours_per_subperiod-1] + vCAPTURE[y,t]/dfGen_ccs[!,:pCO2Loading][1+n*(y-1)] - vREGEN[y,t]/dfGen_ccs[!,:pCO2Loading][1+n*(y-1)])
	# dynamic of lean solvent storage system, normal [tonne solvent/sorbent]
	@constraint(EP, cStore_lean[y in FLECCS_ALL, t in INTERIOR_SUBPERIODS],vSTORE_lean[y, t] == vSTORE_lean[y, t-1] - vCAPTURE[y,t]/dfGen_ccs[!,:pCO2Loading][1+n*(y-1)] + vREGEN[y,t]/dfGen_ccs[!,:pCO2Loading][1+n*(y-1)])
	# dynamic of lean solvent system, wrapping [tonne solvent/sorbent]
	@constraint(EP, cStore_leanwrap[y in FLECCS_ALL, t in START_SUBPERIODS],vSTORE_lean[y, t] == vSTORE_lean[y,t+hours_per_subperiod-1] - vCAPTURE[y,t]/dfGen_ccs[!,:pCO2Loading][1+n*(y-1)] + vREGEN[y,t]/dfGen_ccs[!,:pCO2Loading][1+n*(y-1)])


	## Power Balance##
	EP[:ePowerBalance] += ePowerBalanceFLECCS

	# create a container for FLECCS output.
	@constraints(EP, begin
	    [y in FLECCS_ALL, i in NGCT_id, t = 1:T],EP[:vFLECCS_output][y,i,t] == vP_gt[y,t]
		[y in FLECCS_ALL, i in NGST_id,t = 1:T],EP[:vFLECCS_output][y,i,t] == ePower_st[y,t]	
		[y in FLECCS_ALL, i in Absorber_id,t = 1:T],EP[:vFLECCS_output][y,i,t] == vCAPTURE[y,t]
		[y in FLECCS_ALL, i in Comp_id, t =1:T],EP[:vFLECCS_output][y,i,t] == ePower_use_comp[y,t]	
		[y in FLECCS_ALL, i in Regen_id,t = 1:T],EP[:vFLECCS_output][y,i,t] == vREGEN[y,t]
		[y in FLECCS_ALL, i in Rich_id, t =1:T],EP[:vFLECCS_output][y,i,t] == vSTORE_rich[y,t]
		[y in FLECCS_ALL, i in Lean_id, t =1:T],EP[:vFLECCS_output][y,i,t] == vSTORE_lean[y,t]	
		[y in FLECCS_ALL, i in AUX_id, t =1:T],EP[:vFLECCS_output][y,i,t] == ePower_use_boiler[y,t]	

		[y in FLECCS_ALL, i in BOP_id, t =1:T],EP[:vFLECCS_output][y,i,t] == eCCS_net[y,t]			
	end)

	@constraint(EP, [y in FLECCS_ALL], EP[:eTotalCapFLECCS][y, BOP_id] == EP[:eTotalCapFLECCS][y, NGCT_id]+ EP[:eTotalCapFLECCS][y,NGST_id])






	###########variable cost
	#fuel
	@expression(EP, eCVar_fuel[y in FLECCS_ALL, t = 1:T],(inputs["omega"][t]*fuel_costs[fuel_type[1]][t]*eFuel[y,t]))

	# CO2 sequestration cost applied to sequestrated CO2
	@expression(EP, eCVar_CO2_sequestration[y in FLECCS_ALL, t = 1:T],(inputs["omega"][t]*vREGEN[y,t]*dfGen_ccs[!,:pCO2_sequestration][1+n*(y-1)]))


	# start variable O&M
	# variable O&M for all the teams: combustion turbine (or oxfuel power cycle)
	@expression(EP,eCVar_gt[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].==NGCT_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*vP_gt[y,t])
	# variable O&M for NGCC-based teams: VOM of steam turbine and co2 compressor
	# variable O&M for steam turbine
	@expression(EP,eCVar_st[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].==NGST_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*ePower_st[y,t])
	 # variable O&M for compressor
	@expression(EP,eCVar_comp[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].== Comp_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*(eCO2_flue[y,t] - eCO2_vent[y,t]))


	# specfic variable O&M formulations for each team
	# variable O&M for rich solvent storage
	@expression(EP,eCVar_rich[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].== Rich_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*(vSTORE_rich[y,t]))
	# variable O&M for lean solvent storage
	@expression(EP,eCVar_lean[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].== Lean_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*(vSTORE_lean[y,t]))
	# variable O&M for adsorber
	@expression(EP,eCVar_absorber[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].== Absorber_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*(vCAPTURE[y,t]))
	# variable O&M for regenerator
	@expression(EP,eCVar_regen[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].== Regen_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*(vREGEN[y,t]))


	#adding up variable cost

	@expression(EP,eVar_FLECCS[t = 1:T], sum(eCVar_fuel[y,t] + eCVar_CO2_sequestration[y,t] + eCVar_gt[y,t] + eCVar_st[y,t] + eCVar_comp[y,t] + eCVar_absorber[y,t] + eCVar_regen[y,t] + eCVar_rich[y,t] +eCVar_lean[y,t] for y in FLECCS_ALL))

	@expression(EP,eTotalCVar_FLECCS, sum(eVar_FLECCS[t] for t in 1:T))


	EP[:eObj] += eTotalCVar_FLECCS



	return EP
end