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
	morris(EP::Model, path::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString, OPTIMIZER)

We are in the process of implementing Method of Morris for global sensitivity analysis
"""
struct MatSpread{T1,T2}
    mat::T1
    spread::T2
end

struct MorrisResult{T1,T2}
    means::T1
    means_star::T1
    variances::T1
    elementary_effects::T2
end
function generate_design_matrix(p_range, p_steps, rng;len_design_mat,groups)
    ps = [range(p_range[i][1], stop=p_range[i][2], length=p_steps[i]) for i in 1:length(p_range)]
    indices = [rand(rng, 1:i) for i in p_steps]
    all_idxs_original = Vector{typeof(indices)}(undef,len_design_mat)
    
    for i in 1:len_design_mat
        j = rand(rng, 1:length(p_range))
        indices[j] += (rand(rng) < 0.5 ? -1 : 1)
        if indices[j] > p_steps[j]
            indices[j] -= 2
        elseif indices[j] < 1.0
            indices[j] += 2
        end
        all_idxs_original[i] = copy(indices)
    end

    df_all_idx_original = DataFrame(all_idxs_original,:auto)
    println(df_all_idx_original)
    all_idxs = similar(df_all_idx_original)
    for g in unique(groups)
        temp = findall(x->x==g, groups)
        for k in temp
            all_idxs[k,:] = df_all_idx_original[temp[1],:]
        end
    end
    println(all_idxs)

    B = Array{Array{Float64}}(undef,len_design_mat)
    for j in 1:len_design_mat
        cur_p = [ps[u][(all_idxs[:,j][u])] for u in 1:length(p_range)]
        B[j] = cur_p
    end
    reduce(hcat, B)
end

function calculate_spread(matrix)
    spread = 0.0
    for i in 2:size(matrix,2)
        spread += sqrt(sum(abs2.(matrix[:,i] - matrix[:,i-1])))
    end
    spread
end

function sample_matrices(p_range,p_steps, rng;num_trajectory,total_num_trajectory,len_design_mat,groups)
    matrix_array = []
    println(num_trajectory)
    println(total_num_trajectory)
    if total_num_trajectory<num_trajectory
        error("total_num_trajectory should be greater than num_trajectory preferably atleast 3-4 times higher")
    end
    for i in 1:total_num_trajectory
        mat = generate_design_matrix(p_range, p_steps, rng;len_design_mat,groups)
        spread = calculate_spread(mat)
        push!(matrix_array,MatSpread(mat,spread))
    end
    sort!(matrix_array,by = x -> x.spread,rev=true)
    matrices = [i.mat for i in matrix_array[1:num_trajectory]]
    reduce(hcat,matrices)
end

function my_gsa(f, p_steps, num_trajectory, total_num_trajectory, p_range::AbstractVector,len_design_mat,groups)
    rng = Random.default_rng()
    design_matrices_original = sample_matrices(p_range, p_steps, rng;num_trajectory,
                                        total_num_trajectory,len_design_mat,groups)
    println(design_matrices_original)
    L = DataFrame(design_matrices_original,:auto)
    println(L)

    distinct_trajectories = Array{Int64}(undef,num_trajectory)
    design_matrices = Matrix(DataFrame(unique(last, pairs(eachcol(L[!,1:len_design_mat])))))
    distinct_trajectories[1] = length(design_matrices[1,:])
    if num_trajectory > 1
        for i in 2:num_trajectory
            design_matrices = hcat(design_matrices, Matrix(DataFrame(unique(last, pairs(eachcol(L[!,(i-1)*len_design_mat+1:i*len_design_mat]))))))
            distinct_trajectories[i] = length(Matrix(DataFrame(unique(last, pairs(eachcol(L[!,(i-1)*len_design_mat+1:i*len_design_mat])))))[1,:])
        end
    end
    println(distinct_trajectories)
    println(design_matrices)

    multioutput = false
    desol = false
    local y_size
    
    _y = [f(design_matrices[:,i]) for i in 1:size(design_matrices,2)]
    multioutput = !(eltype(_y) <: Number)
    if eltype(_y) <: RecursiveArrayTools.AbstractVectorOfArray
        y_size = size(_y[1])
        _y = vec.(_y)
        desol = true
    end
    all_y = multioutput ? reduce(hcat,_y) : _y
    println(all_y)
    effects = []
    while(length(effects) < length(groups))
        push!(effects,Vector{Float64}[])
    end
    for i in 1:num_trajectory
        len_design_mat = distinct_trajectories[i]
        y1 = multioutput ? all_y[:,(i-1)*len_design_mat+1] : all_y[(i-1)*len_design_mat+1]
        for j in (i-1)*len_design_mat+1:(i*len_design_mat)-1
            y2 = y1
            del = design_matrices[:,j+1] - design_matrices[:,j]
            change_index = 0
            for k in 1:length(del)
                if abs(del[k]) > 0
                    change_index = k
                    break
                end
            end
            del = sum(del)
            y1 = multioutput ? all_y[:,j+1] : all_y[j+1]
            effect = @. (y1-y2)/(del)
            elem_effect = typeof(y1) <: Number ? effect : mean(effect, dims = 2)
            temp_g_index = findall(x->x==groups[change_index], groups)
            for g in temp_g_index
                println(effects)
                println(elem_effect)
                push!(effects[g],elem_effect)
            end
        end
    end
    means = eltype(effects[1])[]
    means_star = eltype(effects[1])[]
    variances = eltype(effects[1])[]
    for k in effects
        if !isempty(k)
            push!(means, mean(k))
            push!(means_star, mean(x -> abs.(x), k))
            push!(variances, var(k))
        else
            push!(means, zero(effects[1][1]))
            push!(means_star, zero(effects[1][1]))
            push!(variances, zero(effects[1][1]))
        end
    end
    if desol
        f_shape = x -> [reshape(x[:,i],y_size) for i in 1:size(x,2)]
        means = map(f_shape,means)
        means_star = map(f_shape,means_star)
        variances = map(f_shape,variances)
    end
    MorrisResult(reduce(hcat, means),reduce(hcat, means_star),reduce(hcat, variances),effects)
end
function morris(EP::Model, path::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString, OPTIMIZER)

    if setup["MacOrWindows"]=="Mac"
		sep = "/"
	else
		sep = "\U005c"
	end

    # Reading the input parameters
    Morris_range = DataFrame(CSV.File(string(path, sep,"Method_of_morris_range.csv"), header=true), copycols=true)
    groups = Morris_range[!,:Group]
    p_steps = Morris_range[!,:p_steps]
    total_num_trajectory=Morris_range[!,:total_num_trajectory][1]
    num_trajectory=Morris_range[!,:num_trajectory][1]
    len_design_mat=Morris_range[!,:len_design_mat][1]
    #save_parameters = zeros(length(Morris_range[!,:Parameter]))

    # Creating the range of uncertain parameters in terms of absolute values
    sigma_inv = [inputs["dfGen"][!,:Inv_Cost_per_MWyr] .* (1 .+ Morris_range[Morris_range[!,:Parameter] .== "Inv_Cost_per_MWyr", :Lower_bound] ./100) inputs["dfGen"][!,:Inv_Cost_per_MWyr] .* (1 .+ Morris_range[Morris_range[!,:Parameter] .== "Inv_Cost_per_MWyr", :Upper_bound] ./100)]
    sigma_fom = [inputs["dfGen"][!,:Fixed_OM_Cost_per_MWyr] .* (1 .+ Morris_range[Morris_range[!,:Parameter] .== "Fixed_OM_Cost_per_MWyr", :Lower_bound] ./100) inputs["dfGen"][!,:Fixed_OM_Cost_per_MWyr] .* (1 .+ Morris_range[Morris_range[!,:Parameter] .== "Fixed_OM_Cost_per_MWyr", :Upper_bound] ./100)]
    sigma = [sigma_inv; sigma_fom]
    p_range = mapslices(x->[x], sigma, dims=2)[:]

    # Creating a function for iteratively solving the model with different sets of input parameters
    f1 = function(sigma)
        #print(sigma)
        print("\n")
        #save_parameters = hcat(save_parameters, sigma)

        inv_index = findall(s -> s == "Inv_Cost_per_MWyr", Morris_range[!,:Parameter])
        inputs["dfGen"][!,:Inv_Cost_per_MWyr] = sigma[first(inv_index):last(inv_index)]

        fom_index = findall(s -> s == "Fixed_OM_Cost_per_MWyr", Morris_range[!,:Parameter])
        inputs["dfGen"][!,:Fixed_OM_Cost_per_MWyr] = sigma[first(fom_index):last(fom_index)]

        EP = generate_model(setup, inputs, OPTIMIZER)
        #EP, solve_time = solve_model(EP, setup)
        redirect_stdout((()->optimize!(EP)),open("/dev/null", "w"))
        [objective_value(EP)]
    end

    # Perform the method of morris analysis
    m = my_gsa(f1,p_steps,num_trajectory,total_num_trajectory,p_range,len_design_mat,groups)
    println(m.means)
    println(DataFrame(m.means', :auto))
    #save the mean effect of each uncertain variable on the objective fucntion
    Morris_range[!,:mean] = DataFrame(m.means', :auto)[!,:x1]
    println(DataFrame(m.variances', :auto))
    #save the variance of effect of each uncertain variable on the objective function
    Morris_range[!,:variance] = DataFrame(m.variances', :auto)[!,:x1]

    CSV.write(string(outpath,sep,"morris.csv"), Morris_range)

end
