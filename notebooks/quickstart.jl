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
	nothing
end

# ╔═╡ 0923ab80-a63a-11ed-22ce-61ff4e8e709d
md""" ## Quick starting guide to ⚡ DSSE_SEND ⚡ """

# ╔═╡ 7cc4668b-c4c2-44ee-9576-c84cdd91fb1b
md"Please run this notebook with julia 1.6"

# ╔═╡ 9bcfa96e-4852-46fc-aef9-71b9b3d14095
md""" ### Description """

# ╔═╡ a01c7bac-c8d9-4580-bcad-79568b78103b
md"DSSE-SEND is a package containing methods and data for creating a `Digital Twin' of the electrical distribution network at Keele University's Smart Energy Network Demonstrator (SEND) using Distribution System State Estimation (DSSE). 

_Please check the package's_ [README](https:\\github.com/deakinmt/DSSE_SEND) _for more information!_
"

# ╔═╡ 53fd07cd-756a-4173-8caf-d0f5598f8d34
md" ### Use Dates to play with the measurement data"

# ╔═╡ fb1b3983-7f25-4e5b-952c-8b3fc4bac24e
md"You can use the Dates.jl package from the Julia standard library to conveniently choose dates, times and granularity of the data:"

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

# ╔═╡ Cell order:
# ╟─8510a2a5-77d7-40e2-b0b4-f54ccd6d6a8b
# ╟─0923ab80-a63a-11ed-22ce-61ff4e8e709d
# ╟─7cc4668b-c4c2-44ee-9576-c84cdd91fb1b
# ╟─9bcfa96e-4852-46fc-aef9-71b9b3d14095
# ╟─a01c7bac-c8d9-4580-bcad-79568b78103b
# ╟─53fd07cd-756a-4173-8caf-d0f5598f8d34
# ╟─fb1b3983-7f25-4e5b-952c-8b3fc4bac24e
# ╠═89ddabb6-a287-4689-a1de-9aa617663493
# ╟─20f02b60-9b3a-4765-a452-e4cb88b82e22
# ╠═53594be6-0ee3-4ab4-860e-f53c3380d4a9
