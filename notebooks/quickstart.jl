### A Pluto.jl notebook ###
# v0.19.9

using Markdown
using InteractiveUtils

# ╔═╡ 8510a2a5-77d7-40e2-b0b4-f54ccd6d6a8b
begin
	import Pkg
	Pkg.activate(pwd())
	Pkg.add([
			Pkg.PackageSpec(name="PowerModelsDistribution", version="0.11.4"),
			Pkg.PackageSpec(name="Ipopt", version="0.7.0"),
	])
	Pkg.develop("DSSE_SEND")
	import PowerModelsDistribution
	import Ipopt
	import Dates
	import DSSE_SEND

	const _DS  = DSSE_SEND
	const _PMD = PowerModelsDistribution
	@info "The notebook is all set, you can use it!"
	nothing
end

# ╔═╡ 0923ab80-a63a-11ed-22ce-61ff4e8e709d
md""" ## Quick starting guide to ⚡ DSSE_SEND ⚡ """

# ╔═╡ 7cc4668b-c4c2-44ee-9576-c84cdd91fb1b
md"Please run this notebook with julia 1.6. It might take a few minutes to upload the required packages. You cannot run the notebook before this is done. Please have some patience :)"

# ╔═╡ 9bcfa96e-4852-46fc-aef9-71b9b3d14095
md""" ### Description """

# ╔═╡ a01c7bac-c8d9-4580-bcad-79568b78103b
md"DSSE-SEND is a package containing methods and data for creating a `Digital Twin' of the electrical distribution network at Keele University's Smart Energy Network Demonstrator (SEND) using Distribution System State Estimation (DSSE). 

_Please check the package's_ [README](https:\\github.com/deakinmt/DSSE_SEND) _for more information!_
"

# ╔═╡ 53fd07cd-756a-4173-8caf-d0f5598f8d34
md" ### Use Dates to play with the measurement data"

# ╔═╡ 41e532f3-b516-434f-bb6b-0c32e12acd93
md"The package comes with a MV network model (model includes transformers and LV side of every substation) and some measurement data that refer to the model."

# ╔═╡ fb1b3983-7f25-4e5b-952c-8b3fc4bac24e
md"You can use the Dates.jl package from the Julia standard library to conveniently choose dates, times and granularity of the measurement data, which can be used as input of calculations, e.g., state estimation. The measurements have a default resolution of 30 seconds, but they can be made more coarse changing the value of the `resolution` variable below:"

# ╔═╡ 89ddabb6-a287-4689-a1de-9aa617663493
begin
	time_step_begin   = Dates.DateTime(2022, 07, 15, 12, 14, 30)
	resolution = Dates.Minute(2)
	time_step_end = time_step_begin+Dates.Minute(20)
	time_step_step = resolution
	time_range  = time_step_begin:time_step_step:time_step_end
	nothing
end

# ╔═╡ 20f02b60-9b3a-4765-a452-e4cb88b82e22
md"For example, let's plot the power of substation ss21"

# ╔═╡ 53594be6-0ee3-4ab4-860e-f53c3380d4a9
_DS.plot_powers("ss21", time_range)

# ╔═╡ 3156b632-6098-4424-a6ba-d0a4d2aac1eb
md"If we zoom in to active power measurements, we can observe how different resolutions impact the variation of the measurements. This will also have an impact on any calculation these are used as input for."

# ╔═╡ 3f2ef0ff-12a3-46da-94cf-85453a7268af
_DS.plot_powers("ss21", time_range, ylims=(60e3, 85e3))

# ╔═╡ 50097b1a-5993-48bc-a6d4-436f0774b117
md"If we use the original 30 seconds resolution (see plot below), of course the variations are more visible: using a coarser resolution inevitably \"averages\" the data."

# ╔═╡ 96773211-2b75-442f-b74e-be2f0b430097
begin
	new_resolution = Dates.Second(30)
	new_time_range  = time_step_begin:new_resolution:time_step_end
	_DS.plot_powers("ss21", new_time_range, ylims=(60e3, 85e3))
end

# ╔═╡ e8d907cd-00b2-4fd2-b9e7-fdc3c3588479
md" ### Run state estimation (SE)"

# ╔═╡ d235140c-df21-4b2c-83d2-4801394c41fd
md"State estimation is a statistical method that - in its standard form - takes as input 1) redundant (noisy) measurements and 2) a model of the network. The result is the _most likely_ state of the network: the measurement noise is filtered, and analyses on the SE output allow to identify gross measurement errors, network model errors, etc. The calculated state can also be use by itself, e.g., as input to state-aware operational actions."

# ╔═╡ 9324918d-81c0-44c5-9dfe-251a8cf0b9f7
md"First, the network data needs to be accessed, in a usable format. The format of choice is that of a [PowerModelsDistribution.jl](https://github.com/lanl-ansi/PowerModelsDistribution.jl) `MATHEMATICAL` dictionary model. Once loaded in the cell below, the dictionary can be inspected. The package comes with easy parser functions:"

# ╔═╡ 345054c4-4159-4e75-a75d-6bd2f6e2caaa
data = _DS.default_network_parser()

# ╔═╡ c48b6bfc-53b5-4b01-8d77-4846468fcbcf
md"Then, measurements need to be added. The package has an automatic parser that maps the measurements to the components they refer to. SE is in general performed sequentially, time step by time step. Let's pick a time step `ts` and assign the measurements relative to it:"

# ╔═╡ 9be2ba38-833d-4525-80d3-bb173bb031d5
begin 
	ts = time_step_begin
	_DS.add_measurements!(ts, data, resolution, exclude = ["ss02", "ss17"], add_ss13=true) 
end

# ╔═╡ b4e9203a-8d29-4b6f-950b-c1f75ac35961
md"Essentially, this adds a `data[\"meas\"]` that contains all the required measurement information. This default function \"uploads\" P, Q and |U| measurement at every measured substation. Users can create their own measurement parser if other features are required. SE calculations are based on the [PowerModelsDistributionStateEstimation.jl](https://github.com/Electa-Git/PowerModelsDistributionStateEstimation.jl) package. Interested users can check the package documentation for information on the measurement dictionary format/creation. DSSE_SEND functions are documented and documentation can be accessed both on the REPL and on the notebook itself. Just remove the hashtag (comment) in the cell below! to see it action" 

# ╔═╡ 4cdfbdc5-42dc-4031-b3e2-7a4f73a8a1ad
#?_DS.add_measurements!

# ╔═╡ 4227e157-a012-4ac6-b429-58ba6b6f693d
md"The add_measurements! function allows to `exclude` some substations, e.g., because they have corrupted data. In this case, \"ss02\" and \"ss17\" are excluded. `add_ss13` adds measurements for the voltage source-substation, which are otherwise not present by default.The measurement dictionary can be inspected:"

# ╔═╡ 878b9f2f-38bf-4c01-a03a-dba2123877d9
data["meas"]

# ╔═╡ 02d767e9-5f65-4869-9a2e-d9e7118ae752
md"To run SE there are several options available. The following assigns the default ones:"

# ╔═╡ d801fcfe-0d59-4f22-ba90-9993a7ff9a35
_DS.assign_se_settings!(data)

# ╔═╡ c1b744df-4b24-4dc1-8d5d-69733a61efa8
md"As SE is formulated as a generic optimization model, all variables can be bounded. An example function assigns upper and lower bounds to the bus voltage magnitude. Users can add their own bounds similarly."

# ╔═╡ 2d9f8a04-36c1-4692-8fe4-11ae98762cbf
_DS.assign_voltage_bounds!(data, vmin=0.5, vmax=1.5)

# ╔═╡ 3ad698fa-3bd0-410e-a5e8-6d49c613adbb
md"PowerModelsDistributionStateEstimation.jl _models_ the SE problem, and need a third-party solver to _solve_ it. As SE is a non-convex problem, here we use the open and well-known nonlinear interior-point method solver [Ipopt](https://github.com/jump-dev/Ipopt.jl). Several solver parameters can be tuned, but \"plain\" default values should also work:"

# ╔═╡ 8ced33f1-76d4-4d20-9acc-87912ce7353a
se_sol = _DS.solve_acr_mc_se(data, Ipopt.Optimizer)

# ╔═╡ 7df834fc-6d1d-4fac-bcd0-2b5ea34ae521
md"The solution dictionary can be inspected:"

# ╔═╡ 530e4b86-a810-4144-85e9-497ef512223e
se_sol

# ╔═╡ c3995a45-b4ef-4ab6-b7f7-ae286f5eb688
md"Some default post-processing functions are available, to rearrange the solution dictionary to have, e.g., interesting \"plottable\" information."

# ╔═╡ 017e08c6-84f9-4256-9a1d-49b63e9085e6
_DS.post_process_dsse_solution!(se_sol)

# ╔═╡ 23880f25-78b7-452c-9117-4196d252d9c1
md"For instance, now we can retrieve and plot the voltage _residuals_, i.e., the differences between the measured and estimated voltage magnitude _differences_ (no phase voltages measured):"

# ╔═╡ 955b7399-cf26-4215-8e1e-278f50d0e6f8
begin
	ρ = _DS.get_voltage_residuals_one_ts(data, se_sol, in_volts=false)
	p = _DS.plot_voltage_residuals_one_ts(ρ, in_volts=false, title="ts.: $(string(ts)[6:end]), aggr.: $resolution")
end

# ╔═╡ b4c32c57-910c-4f23-bf09-beebe85b0b3b
md"The lower the residuals, the higher the confidence that there is nothing wrong with the model/measurements and that the SE output is reliable. Residual analysis might be used to spot network model errors, and validate whether their correction has been effective. Below, we show how the residuals increase if the tap settings of the MV/LV transformers in the model are off."

# ╔═╡ 513b758c-ae1f-4228-a314-7a3dd4f533a5
md" ### SE for diagnostics: wrong tap settings"

# ╔═╡ e5f55199-fc99-4cc3-897e-abc8a34dc6a1
md"Let's take the case where the taps are simply assigned a flat ratio of [1.0, 1.0, 1.0] for every transformer. We know this does not correspond to reality."

# ╔═╡ 88a31177-028a-4ea9-a6cc-fd045bcfef75
data_off = _DS.default_network_parser(;adjust_tap_settings=false)

# ╔═╡ 36012b0e-b35c-4814-8d7e-4fc53f30f5d7
md"Performing the same calculations as before, on the _same time step_, we get:"

# ╔═╡ 39772bf4-767a-45c6-8cc5-215d97032f20
begin
	_DS.add_measurements!(ts, data_off, resolution, exclude = ["ss02", "ss17"], add_ss13=true)
	_DS.assign_se_settings!(data_off)
	_DS.assign_voltage_bounds!(data_off, vmin=0.5, vmax=1.5)
	se_sol_off = _DS.solve_acr_mc_se(data_off, Ipopt.Optimizer)
end

# ╔═╡ 70ccacb0-cdf6-4753-abb6-51a364ac4a4b
begin
	_DS.post_process_dsse_solution!(se_sol_off)
	ρ_off = _DS.get_voltage_residuals_one_ts(data_off, se_sol_off, in_volts=false)
	p_off = _DS.plot_voltage_residuals_one_ts(ρ_off, in_volts=false, title="ts.: $(string(ts)[6:end]), aggr.: $resolution")
end

# ╔═╡ 883f1d97-a3ba-4ddd-b6d8-1c321e5e027e
md"Now some residuals are _huge_, so we suspect there is something wrong. In practice, we have already established that the tap settings are not flat. As the residuals with the model in the previous section are lower across multiple time steps (i.e., it's not a coincidence), we are confident that the non-flat model is better. The reader is welcome to modify the resolution/time steps assigned in the cells above and repeat the calculations with different settings."

# ╔═╡ Cell order:
# ╟─8510a2a5-77d7-40e2-b0b4-f54ccd6d6a8b
# ╟─0923ab80-a63a-11ed-22ce-61ff4e8e709d
# ╟─7cc4668b-c4c2-44ee-9576-c84cdd91fb1b
# ╟─9bcfa96e-4852-46fc-aef9-71b9b3d14095
# ╟─a01c7bac-c8d9-4580-bcad-79568b78103b
# ╟─53fd07cd-756a-4173-8caf-d0f5598f8d34
# ╟─41e532f3-b516-434f-bb6b-0c32e12acd93
# ╟─fb1b3983-7f25-4e5b-952c-8b3fc4bac24e
# ╠═89ddabb6-a287-4689-a1de-9aa617663493
# ╟─20f02b60-9b3a-4765-a452-e4cb88b82e22
# ╟─53594be6-0ee3-4ab4-860e-f53c3380d4a9
# ╟─3156b632-6098-4424-a6ba-d0a4d2aac1eb
# ╟─3f2ef0ff-12a3-46da-94cf-85453a7268af
# ╟─50097b1a-5993-48bc-a6d4-436f0774b117
# ╟─96773211-2b75-442f-b74e-be2f0b430097
# ╟─e8d907cd-00b2-4fd2-b9e7-fdc3c3588479
# ╟─d235140c-df21-4b2c-83d2-4801394c41fd
# ╟─9324918d-81c0-44c5-9dfe-251a8cf0b9f7
# ╠═345054c4-4159-4e75-a75d-6bd2f6e2caaa
# ╟─c48b6bfc-53b5-4b01-8d77-4846468fcbcf
# ╠═9be2ba38-833d-4525-80d3-bb173bb031d5
# ╟─b4e9203a-8d29-4b6f-950b-c1f75ac35961
# ╠═4cdfbdc5-42dc-4031-b3e2-7a4f73a8a1ad
# ╟─4227e157-a012-4ac6-b429-58ba6b6f693d
# ╠═878b9f2f-38bf-4c01-a03a-dba2123877d9
# ╟─02d767e9-5f65-4869-9a2e-d9e7118ae752
# ╠═d801fcfe-0d59-4f22-ba90-9993a7ff9a35
# ╟─c1b744df-4b24-4dc1-8d5d-69733a61efa8
# ╠═2d9f8a04-36c1-4692-8fe4-11ae98762cbf
# ╟─3ad698fa-3bd0-410e-a5e8-6d49c613adbb
# ╠═8ced33f1-76d4-4d20-9acc-87912ce7353a
# ╟─7df834fc-6d1d-4fac-bcd0-2b5ea34ae521
# ╟─530e4b86-a810-4144-85e9-497ef512223e
# ╟─c3995a45-b4ef-4ab6-b7f7-ae286f5eb688
# ╠═017e08c6-84f9-4256-9a1d-49b63e9085e6
# ╟─23880f25-78b7-452c-9117-4196d252d9c1
# ╠═955b7399-cf26-4215-8e1e-278f50d0e6f8
# ╟─b4c32c57-910c-4f23-bf09-beebe85b0b3b
# ╟─513b758c-ae1f-4228-a314-7a3dd4f533a5
# ╟─e5f55199-fc99-4cc3-897e-abc8a34dc6a1
# ╟─88a31177-028a-4ea9-a6cc-fd045bcfef75
# ╟─36012b0e-b35c-4814-8d7e-4fc53f30f5d7
# ╠═39772bf4-767a-45c6-8cc5-215d97032f20
# ╠═70ccacb0-cdf6-4753-abb6-51a364ac4a4b
# ╟─883f1d97-a3ba-4ddd-b6d8-1c321e5e027e
