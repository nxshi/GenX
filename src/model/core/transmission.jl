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
	function transmission!(EP::Model, inputs::Dict, setup::Dict)
This function establishes decisions, expressions, and constraints related to transmission power flows between model zones and associated transmission losses (if modeled).
The function adds transmission reinforcement or construction costs to the objective function. Transmission reinforcement costs are equal to the sum across all lines of the product between the transmission reinforcement/construction cost, $pi^{TCAP}_{l}$, times the additional transmission capacity variable, $\bigtriangleup\varphi^{max}_{l}$.
```math
\begin{aligned}
& \sum_{l \in \mathcal{L}}\left(\pi^{TCAP}_{l} \times \bigtriangleup\varphi^{max}_{l}\right)
\end{aligned}
```
Note that fixed O\&M and replacement capital costs (depreciation) for existing transmission capacity is treated as a sunk cost and not included explicitly in the GenX objective function.
Power flow and transmission loss terms are also added to the power balance constraint for each zone:
```math
\begin{aligned}
&	- \sum_{l\in \mathcal{L}}{(\varphi^{map}_{l,z} \times \Phi_{l,t})} - \frac{1}{2} \sum_{l\in \mathcal{L}}{(\varphi^{map}_{l,z} \times \beta_{l,t}(\cdot))}
\end{aligned}
```
Power flows, $\Phi_{l,t}$, on each line $l$ into or out of a zone (defined by the network map $\varphi^{map}_{l,z}$), are considered in the demand balance equation for each zone. By definition, power flows leaving their reference zone are positive, thus the minus sign is used for this term. Losses due to power flows increase demand, and one-half of losses across a line linking two zones are attributed to each connected zone. The losses function $\beta_{l,t}(\cdot)$ will depend on the configuration used to model losses (see below).
**Accounting for Transmission and Network Expansion Between Zones**
Transmission flow constraints are modeled using a 'transport method','' where power flow, $\Phi_{l,t}$, on each line (or more likely a `path' aggregating flows across multiple parallel lines) is constrained to be less than or equal to the line's maximum power transfer capacity, $\varphi^{max}_{l}$, plus any transmission capacity added on that line (for lines eligible for expansion in the set $\mathcal{E}$). The additional transmission capacity, $\bigtriangleup\varphi^{max}_{l} $, is constrained by a maximum allowed reinforcement, $\overline{\bigtriangleup\varphi^{max}_{l}}$, for each line $l \in \mathcal{E}$.
```math
\begin{aligned}
	% trasmission constraints
	&-\varphi^{max}_{l} \leq  \Phi_{l,t} \leq \varphi^{max}_{l} , &\quad \forall l \in (\mathcal{L} \setminus \mathcal{E} ),\forall t  \in \mathcal{T}\\
	% trasmission expansion
	&-(\varphi^{max}_{l} + \bigtriangleup\varphi^{max}_{l} ) \leq  \Phi_{l,t} \leq (\varphi^{max}_{l} + \bigtriangleup\varphi^{max}_{l} ) , &\quad \forall l \in \mathcal{E},\forall t  \in \mathcal{T}\\
	& \bigtriangleup\varphi^{max}_{l}  \leq \overline{\bigtriangleup\varphi^{max}_{l}}, &\quad \forall l \in \mathcal{E}
\end{aligned}
```
**Accounting for Transmission Losses**
Transmission losses due to power flows can be accounted for in three different ways. The first option is to neglect losses entirely, setting the value of the losses function to zero for all lines at all hours. The second option is to assume that losses are a fixed percentage, $\varphi^{loss}_{l}$, of the magnitude of power flow on each line, $\mid \Phi_{l,t} \mid$ (e.g., losses are a linear function of power flows). Finally, the third option is to calculate losses, $\ell_{l,t}$, by approximating a quadratic-loss function of power flow across the line using a piecewise-linear function with total number of segments equal to the size of the set $\mathcal{M}$.
```math
\begin{aligned}
%configurable losses formulation
	& \beta_{l,t}(\cdot) = \begin{cases} 0 & \text{if~} \text{losses.~0} \\ \\ \varphi^{loss}_{l}\times \mid \Phi_{l,t} \mid & \text{if~} \text{losses.~1} \\ \\ \ell_{l,t} &\text{if~} \text{losses.~2} \end{cases}, &\quad \forall l \in \mathcal{L},\forall t  \in \mathcal{T}
\end{aligned}
```
For the second option, an absolute value approximation is utilized to calculate the magnitude of the power flow on each line (reflecting the fact that negative power flows for a line linking nodes $i$ and $j$ represents flows from node $j$ to $i$ and causes the same magnitude of losses as an equal power flow from $i$ to $j$). This absolute value function is linearized such that the flow in the line must be equal to the subtraction of the auxiliary variable for flow in the positive direction, $\Phi^{+}_{l,t}$, and the auxiliary variable for flow in the negative direction, $\Phi^{+}_{l,t}$, of the line. Then, the magnitude of the flow is calculated as the sum of the two auxiliary variables. The sum of positive and negative directional flows are also constrained by the maximum line flow capacity.
```math
\begin{aligned}
% trasmission losses simple
	&\Phi_{l,t} =  \Phi^{+}_{l,t}  - \Phi^{-}_{l,t}, &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	&\mid \Phi_{l,t} \mid =  \Phi^{+}_{l,t}  + \Phi^{-}_{l,t}, &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	&\Phi^{+}_{l,t}  + \Phi^{-}_{l,t} \leq \varphi^{max}_{l}, &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}
\end{aligned}
```
If discrete unit commitment decisions are modeled, ``phantom losses'' can be observed wherein the auxiliary variables for flows in both directions ($\Phi^{+}_{l,t}$ and $\Phi^{-}_{l,t}$) are both increased to produce increased losses so as to avoid cycling a thermal generator and incurring start-up costs or opportunity costs related to minimum down times. This unrealistic behavior can be eliminated via inclusion of additional constraints and a set of auxiliary binary variables, $ON^{+}_{l,t} \in {0,1} \forall l \in \mathcal{L}$. Then the following additional constraints are created:
```math
\begin{aligned}
	\Phi^{+}_{l,t} \leq TransON^{+}_{l,t},  &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	\Phi^{-}_{l,t} \leq (\varphi^{max}_{l} + \bigtriangleup\varphi^{max}_{l}) -TransON^{+}_{l,t}, &\quad  \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}
\end{aligned}
```
where $TransON^{+}_{l,t}$ is a continuous variable, representing the product of the binary variable $ON^{+}_{l,t}$ and the expression, $(\varphi^{max}_{l} + \bigtriangleup\varphi^{max}_{l})$. This product cannot be defined explicitly, since it will lead to a bilinear expression involving two variables. Instead, we enforce this definition via the Glover's Linearization as shown below (also referred McCormick Envelopes constraints for bilinear expressions, which is exact when one of the variables is binary).
```math
\begin{aligned}
	TransON^{+}_{l,t} \leq  (\varphi^{max}_{l} + \overline{\bigtriangleup\varphi^{max}_{l}}) \times TransON^{+}_{l,t},  &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T} \\
	TransON^{+}_{l,t} \leq  (\varphi^{max}_{l} + \bigtriangleup\varphi^{max}_{l}),  &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T} \\
	TransON^{+}_{l,t} \leq (\varphi^{max}_{l} + \bigtriangleup\varphi^{max}_{l}) - (\varphi^{max}_{l} + \overline{\bigtriangleup\varphi^{max}_{l}}) \times(1- TransON^{+}_{l,t}),  &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T} \\
\end{aligned}
```
These constraints permit only the positive or negative auxiliary flow variables to be non-zero at a given time period, not both.
For the third option, losses are calculated as a piecewise-linear approximation of a quadratic function of power flows. In order to do this, we represent the absolute value of the line flow variable by the sum of positive stepwise flow variables $(\mathcal{S}^{+}_{m,l,t}, \mathcal{S}^{-}_{m,l,t})$, associated with each partition of line losses computed using the corresponding linear expressions. This can be understood as a segmentwise linear fitting (or first order approximation) of the quadratic losses function. The first constraint below computes the losses a the accumulated sum of losses for each linear stepwise segment of the approximated quadratic function, including both positive domain and negative domain segments. A second constraint ensures that the stepwise variables do not exceed the maximum size per segment. The slope and maximum size for each segment are calculated as per the method in \cite{Zhang2013}.
```math
\begin{aligned}
	& \ell_{l,t} = \frac{\varphi^{ohm}_{l}}{(\varphi^{volt}_{l})^2}\bigg( \sum_{m \in \mathcal{M}}( S^{+}_{m,l}\times \mathcal{S}^{+}_{m,l,t} + S^{-}_{m,l}\times \mathcal{S}^{-}_{m,l,t}) \bigg), &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T} \\
	& \text{\quad Where:} \\
	& \quad S^{+}_{m,l} = \frac{2+4 \times \sqrt{2}\times (m-1)}{1+\sqrt{2} \times (2 \times M-1)} (\varphi^{max}_{l} + \overline{\bigtriangleup\varphi^{max}_{l}}) &\quad \forall m \in [1 \colon M], l \in \mathcal{L}  \\
	& \quad S^{-}_{m,l} = \frac{2+4 \times \sqrt{2}\times (m-1)}{1+\sqrt{2} \times (2 \times M-1)} (\varphi^{max}_{l} + \overline{\bigtriangleup\varphi^{max}_{l}}) &\quad \forall m \in [1 \colon M], l \in \mathcal{L}\\
	& \\
	& \mathcal{S}^{+}_{m,l,t}, \mathcal{S}^{-}_{m,l,t} <= \overline{\mathcal{S}_{m,l}} &\quad \forall m \in [1:M], l \in \mathcal{L}, t \in \mathcal{T} \\
	& \text{\quad Where:} \\
	& \quad \overline{S_{l,z}} =  \begin{cases} \frac{(1+\sqrt{2})}{1+\sqrt{2} \times (2 \times M-1)}  (\varphi^{max}_{l} + \overline{\bigtriangleup\varphi^{max}_{l}}) & \text{if~} m = 1 \\
	\frac{2 \times \sqrt{2} }{1+\sqrt{2} \times (2 \times M-1)} (\varphi^{max}_{l} + \overline{\bigtriangleup\varphi^{max}_{l}}) & \text{if~} m > 1 \end{cases}
\end{aligned}
```
Next, a constraint ensures that the sum of auxiliary segment variables ($m \geq 1$) minus the "zero" segment (which allows values to go into the negative domain) from both positive and negative domains must total the actual power flow across the line, and a constraint ensures that the sum of negative and positive flows do not exceed the maximum flow for the line.
```math
\begin{aligned}
	&\sum_{m \in [1:M]} (\mathcal{S}^{+}_{m,l,t}) - \mathcal{S}^{+}_{0,l,t} =  \Phi_{l,t}, &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	&\sum_{m \in [1:M]} (\mathcal{S}^{-}_{m,l,t}) - \mathcal{S}^{-}_{0,l,t}  =  - \Phi_{l,t}
\end{aligned}
```
As with losses option 2, this segment-wise approximation of a quadratic loss function also permits 'phantom losses' to avoid cycling thermal units when discrete unit commitment decisions are modeled. In this case, the additional constraints below are also added to ensure that auxiliary segments variables do not exceed maximum value per segment and that they are filled in order; i.e., one segment cannot be non-zero unless prior segment is at its maximum value. Binary constraints deal with absolute value of power flow on each line. If the flow is positive, $\mathcal{S}^{+}_{0,l,t}$ must be zero; if flow is negative, $\mathcal{S}^{+}_{0,l,t}$ must be positive and takes on value of the full negative flow, forcing all $\mathcal{S}^{+}_{m,l,t}$ other segments ($m \geq 1$) to be zero. Conversely, if the flow is negative, $\mathcal{S}^{-}_{0,l,t}$ must be zero; if flow is positive, $\mathcal{S}^{-}_{0,l,t}$ must be positive and takes on value of the full positive flow, forcing all $\mathcal{S}^{-}_{m,l,t}$ other segments ($m \geq 1$) to be zero. Requiring segments to fill in sequential order and binary variables to ensure variables reflect the actual direction of power flows are both necessary to eliminate ``phantom losses'' from the solution. These constraints and binary decisions are ommited if the model is fully linear.
```math
\begin{aligned}
	&\mathcal{S}^{+}_{m,l,t} <=    \overline{\mathcal{S}_{m,l}} \times ON^{+}_{m,l,t}, &\quad \forall m \in [1:M], \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	&\mathcal{S}^{-}_{m,l,t} <=    \overline{\mathcal{S}_{m,l}} \times ON^{-}_{m,l,t},  &\quad \forall m \in[1:M], \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	&\mathcal{S}^{+}_{m,l,t} \geq ON^{+}_{m+1,l,t} \times \overline{\mathcal{S}_{m,l}}, &\quad \forall m \in [1:M], \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	&\mathcal{S}^{-}_{m,l,t} \geq ON^{-}_{m+1,l,t} \times \overline{\mathcal{S}_{m,l}} , &\quad \forall m \in [1:M], \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	&\mathcal{S}^{+}_{0,l,t} \leq \varphi^{max}_{l} \times (1- ON^{+}_{1,l,t}), &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	&\mathcal{S}^{-}_{0,l,t} \leq \varphi^{max}_{l} \times (1- ON^{-}_{1,l,t}), &\quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}
\end{aligned}
```
"""
function transmission!(EP::Model, inputs::Dict, setup::Dict)

    println("Transmission Module")

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    L = inputs["L"]     # Number of transmission lines
    UCommit = setup["UCommit"]
    NetworkExpansion = setup["NetworkExpansion"]
    MultiStage = copy(setup["MultiStage"])
    ## sets and indices for transmission losses and expansion
    TRANS_LOSS_SEGS = inputs["TRANS_LOSS_SEGS"] # Number of segments used in piecewise linear approximations quadratic loss functions - can only take values of TRANS_LOSS_SEGS =1, 2
    LOSS_LINES = inputs["LOSS_LINES"] # Lines for which loss coefficients apply (are non-zero);
    if NetworkExpansion == 1
        # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
        EXPANSION_LINES = inputs["EXPANSION_LINES"]
    end

    ### Variables ###

    if MultiStage == 1
        @variable(EP, vTRANSMAX[l=1:L] >= 0)
    end

    # Power flow on each transmission line "l" at hour "t"
    @variable(EP, vFLOW[l=1:L, t=1:T])

    if NetworkExpansion == 1
        # Transmission network capacity reinforcements per line
        @variable(EP, vNEW_TRANS_CAP[l in EXPANSION_LINES] >= 0)
    end

    if (TRANS_LOSS_SEGS == 1)  #loss is a constant times absolute value of power flow
        # Positive and negative flow variables
        @variable(EP, vTAUX_NEG[l in LOSS_LINES, t=1:T] >= 0)
        @variable(EP, vTAUX_POS[l in LOSS_LINES, t=1:T] >= 0)

        if UCommit == 1
            # Single binary variable to ensure positive or negative flows only
            @variable(EP, vTAUX_POS_ON[l in LOSS_LINES, t=1:T], Bin)
            # Continuous variable representing product of binary variable (vTAUX_POS_ON) and avail transmission capacity
            @variable(EP, vPROD_TRANSCAP_ON[l in LOSS_LINES, t=1:T] >= 0)
        end
    else # TRANS_LOSS_SEGS>1
        # Auxiliary variables for linear piecewise interpolation of quadratic losses
        @variable(EP, vTAUX_NEG[l in LOSS_LINES, s=0:TRANS_LOSS_SEGS, t=1:T] >= 0)
        @variable(EP, vTAUX_POS[l in LOSS_LINES, s=0:TRANS_LOSS_SEGS, t=1:T] >= 0)
        if UCommit == 1
            # Binary auxilary variables for each segment >1 to ensure segments fill in order
            @variable(EP, vTAUX_POS_ON[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], Bin)
            @variable(EP, vTAUX_NEG_ON[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], Bin)
        end
    end

    # Transmission losses on each transmission line "l" at hour "t"
    @variable(EP, vTLOSS[l in LOSS_LINES, t=1:T] >= 0)

    ### Expressions ###

    if MultiStage == 1
        @expression(EP, eTransMax[l=1:L], vTRANSMAX[l])
    else
        @expression(EP, eTransMax[l=1:L], inputs["pTrans_Max"][l])
    end

    ## Transmission power flow and loss related expressions:
    # Total availabile maximum transmission capacity is the sum of existing maximum transmission capacity plus new transmission capacity
    if NetworkExpansion == 1
        @expression(EP, eAvail_Trans_Cap[l=1:L],
            if l in EXPANSION_LINES
                eTransMax[l] + vNEW_TRANS_CAP[l]
            else
                eTransMax[l] + EP[:vZERO]
            end
        )
    else
        @expression(EP, eAvail_Trans_Cap[l=1:L], eTransMax[l] + EP[:vZERO])
    end

    # Net power flow outgoing from zone "z" at hour "t" in MW
    @expression(EP, eNet_Export_Flows[z=1:Z, t=1:T], sum(inputs["pNet_Map"][l, z] * vFLOW[l, t] for l = 1:L))

    # Losses from power flows into or out of zone "z" in MW
    @expression(EP, eTransLossByZone[z=1:Z, t=1:T], sum(abs(inputs["pNet_Map"][l, z]) * vTLOSS[l, t] for l in LOSS_LINES))

    ## Objective Function Expressions ##

    if NetworkExpansion == 1
        @expression(EP, eTotalCNetworkExp, sum(vNEW_TRANS_CAP[l] * inputs["pC_Line_Reinforcement"][l] for l in EXPANSION_LINES))

        if MultiStage == 1
            # OPEX multiplier to count multiple years between two model stages
            # We divide by OPEXMULT since we are going to multiply the entire objective function by this term later,
            # and we have already accounted for multiple years between stages for fixed costs.
            EP[:eObj] += (1 / inputs["OPEXMULT"]) * eTotalCNetworkExp
        else
            EP[:eObj] += eTotalCNetworkExp
        end
    end

    ## End Objective Function Expressions ##

    ## Power Balance Expressions ##

    @expression(EP, ePowerBalanceNetExportFlows[t=1:T, z=1:Z],
        -eNet_Export_Flows[z, t])
    @expression(EP, ePowerBalanceLossesByZone[t=1:T, z=1:Z],
        -(1 / 2) * eTransLossByZone[z, t])

    EP[:ePowerBalance] += ePowerBalanceLossesByZone
    EP[:ePowerBalance] += ePowerBalanceNetExportFlows


    ### Constraints ###

    if MultiStage == 1
        # Linking constraint for existing transmission capacity
        @constraint(EP, cExistingTransCap[l=1:L], vTRANSMAX[l] == inputs["pTrans_Max"][l])
    end

    ## Power flow and transmission (between zone) loss related constraints

    # Maximum power flows, power flow on each transmission line cannot exceed maximum capacity of the line at any hour "t"
    # Allow expansion of transmission capacity for lines eligible for reinforcement
    @constraints(EP, begin
        cMaxFlow_out[l=1:L, t=1:T], vFLOW[l, t] <= eAvail_Trans_Cap[l]
        cMaxFlow_in[l=1:L, t=1:T], vFLOW[l, t] >= -eAvail_Trans_Cap[l]
    end)

    # If network expansion is used:
    if NetworkExpansion == 1
        # Transmission network related power flow and capacity constraints
        if MultiStage == 1
            # Constrain maximum possible flow for lines eligible for expansion regardless of previous expansions
            @constraint(EP, cMaxFlowPossible[l in EXPANSION_LINES], eAvail_Trans_Cap[l] <= inputs["pTrans_Max_Possible"][l])
        end
        # Constrain maximum single-stage line capacity reinforcement for lines eligible for expansion
        @constraint(EP, cMaxLineReinforcement[l in EXPANSION_LINES], vNEW_TRANS_CAP[l] <= inputs["pMax_Line_Reinforcement"][l])
    end
    #END network expansion contraints

    # Transmission loss related constraints - linear losses as a function of absolute value
    if TRANS_LOSS_SEGS == 1

        @constraints(EP, begin
            # Losses are alpha times absolute values
            cTLoss[l in LOSS_LINES, t=1:T], vTLOSS[l, t] == inputs["pPercent_Loss"][l] * (vTAUX_POS[l, t] + vTAUX_NEG[l, t])

            # Power flow is sum of positive and negative components
            cTAuxSum[l in LOSS_LINES, t=1:T], vTAUX_POS[l, t] - vTAUX_NEG[l, t] == vFLOW[l, t]

            # Sum of auxiliary flow variables in either direction cannot exceed maximum line flow capacity
            cTAuxLimit[l in LOSS_LINES, t=1:T], vTAUX_POS[l, t] + vTAUX_NEG[l, t] <= eAvail_Trans_Cap[l]
        end)

        if UCommit == 1
            # Constraints to limit phantom losses that can occur to avoid discrete cycling costs/opportunity costs due to min down
            @constraints(EP, begin
                cTAuxPosUB[l in LOSS_LINES, t=1:T], vTAUX_POS[l, t] <= vPROD_TRANSCAP_ON[l, t]

                # Either negative or positive flows are activated, not both
                cTAuxNegUB[l in LOSS_LINES, t=1:T], vTAUX_NEG[l, t] <= eAvail_Trans_Cap[l] - vPROD_TRANSCAP_ON[l, t]

                # McCormick representation of product of continuous and binary variable
                # (in this case, of: vPROD_TRANSCAP_ON[l,t] = eAvail_Trans_Cap[l] * vTAUX_POS_ON[l,t])
                # McCormick constraint 1
                [l in LOSS_LINES, t = 1:T], vPROD_TRANSCAP_ON[l, t] <= inputs["pTrans_Max_Possible"][l] * vTAUX_POS_ON[l, t]

                # McCormick constraint 2
                [l in LOSS_LINES, t = 1:T], vPROD_TRANSCAP_ON[l, t] <= eAvail_Trans_Cap[l]

                # McCormick constraint 3
                [l in LOSS_LINES, t = 1:T], vPROD_TRANSCAP_ON[l, t] >= eAvail_Trans_Cap[l] - (1 - vTAUX_POS_ON[l, t]) * inputs["pTrans_Max_Possible"][l]
            end)
        end

    end # End if(TRANS_LOSS_SEGS == 1) block

    # When number of segments is greater than 1
    if (TRANS_LOSS_SEGS > 1)
        ## between zone transmission loss constraints
        # Losses are expressed as a piecewise approximation of a quadratic function of power flows across each line
        # Eq 1: Total losses are function of loss coefficient times the sum of auxilary segment variables across all segments of piecewise approximation
        # (Includes both positive domain and negative domain segments)
        @constraint(EP, cTLoss[l in LOSS_LINES, t=1:T], vTLOSS[l, t] ==
                                                        (inputs["pTrans_Loss_Coef"][l] * sum((2 * s - 1) * (inputs["pTrans_Max_Possible"][l] / TRANS_LOSS_SEGS) * vTAUX_POS[l, s, t] for s = 1:TRANS_LOSS_SEGS)) +
                                                        (inputs["pTrans_Loss_Coef"][l] * sum((2 * s - 1) * (inputs["pTrans_Max_Possible"][l] / TRANS_LOSS_SEGS) * vTAUX_NEG[l, s, t] for s = 1:TRANS_LOSS_SEGS)))
        # Eq 2: Sum of auxilary segment variables (s >= 1) minus the "zero" segment (which allows values to go negative)
        # from both positive and negative domains must total the actual power flow across the line
        @constraints(EP, begin
            cTAuxSumPos[l in LOSS_LINES, t=1:T], sum(vTAUX_POS[l, s, t] for s = 1:TRANS_LOSS_SEGS) - vTAUX_POS[l, 0, t] == vFLOW[l, t]
            cTAuxSumNeg[l in LOSS_LINES, t=1:T], sum(vTAUX_NEG[l, s, t] for s = 1:TRANS_LOSS_SEGS) - vTAUX_NEG[l, 0, t] == -vFLOW[l, t]
        end)
        if UCommit == 0 || UCommit == 2
            # Eq 3: Each auxilary segment variables (s >= 1) must be less than the maximum power flow in the zone / number of segments
            @constraints(EP, begin
                cTAuxMaxPos[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], vTAUX_POS[l, s, t] <= (inputs["pTrans_Max_Possible"][l] / TRANS_LOSS_SEGS)
                cTAuxMaxNeg[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], vTAUX_NEG[l, s, t] <= (inputs["pTrans_Max_Possible"][l] / TRANS_LOSS_SEGS)
            end)
        else # Constraints that can be ommitted if problem is convex (i.e. if not using MILP unit commitment constraints)
            # Eqs 3-4: Ensure that auxilary segment variables do not exceed maximum value per segment and that they
            # "fill" in order: i.e. one segment cannot be non-zero unless prior segment is at it's maximum value
            # (These constraints are necessary to prevents phantom losses in MILP problems)
            @constraints(EP, begin
                cTAuxOrderPos1[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], vTAUX_POS[l, s, t] <= (inputs["pTrans_Max_Possible"][l] / TRANS_LOSS_SEGS) * vTAUX_POS_ON[l, s, t]
                cTAuxOrderNeg1[l in LOSS_LINES, s=1:TRANS_LOSS_SEGS, t=1:T], vTAUX_NEG[l, s, t] <= (inputs["pTrans_Max_Possible"][l] / TRANS_LOSS_SEGS) * vTAUX_NEG_ON[l, s, t]
                cTAuxOrderPos2[l in LOSS_LINES, s=1:(TRANS_LOSS_SEGS-1), t=1:T], vTAUX_POS[l, s, t] >= (inputs["pTrans_Max_Possible"][l] / TRANS_LOSS_SEGS) * vTAUX_POS_ON[l, s+1, t]
                cTAuxOrderNeg2[l in LOSS_LINES, s=1:(TRANS_LOSS_SEGS-1), t=1:T], vTAUX_NEG[l, s, t] >= (inputs["pTrans_Max_Possible"][l] / TRANS_LOSS_SEGS) * vTAUX_NEG_ON[l, s+1, t]
            end)

            # Eq 5: Binary constraints to deal with absolute value of vFLOW.
            @constraints(EP, begin
                # If flow is positive, vTAUX_POS segment 0 must be zero; If flow is negative, vTAUX_POS segment 0 must be positive
                # (and takes on value of the full negative flow), forcing all vTAUX_POS other segments (s>=1) to be zero
                cTAuxSegmentZeroPos[l in LOSS_LINES, t=1:T], vTAUX_POS[l, 0, t] <= inputs["pTrans_Max_Possible"][l] * (1 - vTAUX_POS_ON[l, 1, t])

                # If flow is negative, vTAUX_NEG segment 0 must be zero; If flow is positive, vTAUX_NEG segment 0 must be positive
                # (and takes on value of the full positive flow), forcing all other vTAUX_NEG segments (s>=1) to be zero
                cTAuxSegmentZeroNeg[l in LOSS_LINES, t=1:T], vTAUX_NEG[l, 0, t] <= inputs["pTrans_Max_Possible"][l] * (1 - vTAUX_NEG_ON[l, 1, t])
            end)
        end
    end # End if(TRANS_LOSS_SEGS > 0) block

    return EP
end
